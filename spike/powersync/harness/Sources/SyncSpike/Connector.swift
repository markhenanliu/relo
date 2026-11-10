import Foundation
import PowerSync

/// Connects PowerSync to Supabase:
/// - credentials: the signed-in user's Supabase access token (PowerSync verifies it via JWKS);
/// - uploads: replays the local write queue against PostgREST, one transaction at a time.
final class SupabaseConnector: PowerSyncBackendConnectorProtocol {
    let api: SupabaseAPI

    init(api: SupabaseAPI) {
        self.api = api
    }

    func fetchCredentials() async throws -> PowerSyncCredentials? {
        let session = try await api.currentSession()
        return PowerSyncCredentials(endpoint: api.env.powerSyncURL, token: session.accessToken)
    }

    func uploadData(database: PowerSyncDatabaseProtocol) async throws {
        guard let transaction = try await database.getNextCrudTransaction() else { return }
        let token = try await api.currentSession().accessToken

        for entry in transaction.crud {
            do {
                switch entry.op {
                case .put:
                    var row: JsonParam = entry.opDataTyped ?? [:]
                    row["id"] = .string(entry.id)
                    try await api.upsert(table: entry.table, row: row, token: token)
                case .patch:
                    try await api.update(table: entry.table, id: entry.id, fields: entry.opDataTyped ?? [:], token: token)
                case .delete:
                    try await api.delete(table: entry.table, id: entry.id, token: token)
                }
            } catch let APIError.permanent(status, body) {
                // Retrying can't fix bad data, and a stuck entry would block every later write.
                // Record it and move on. (The real app would surface these to the user.)
                let line = "\(Date()) \(entry.op.rawValue) \(entry.table)/\(entry.id) HTTP \(status): \(body)\n"
                appendRejected(line)
            }
            // Transient errors propagate: PowerSync keeps the transaction and retries later.
        }
        try await transaction.complete()
    }

    private func appendRejected(_ line: String) {
        let url = api.env.rejectedLog
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
        print("REJECTED: \(line)", terminator: "")
    }
}
