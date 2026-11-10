import Foundation
import PowerSync
import RelocDomain

// Usage: SyncSpike <command> [--device NAME] [options]
//
//   user                                  Create/sign in the local test user
//   write-offline --expenses N            Offline: create a move + N expenses, edit 20, delete 5, then SIGKILL
//   sync [--timeout S]                    Online: connect, upload the queue, download, wait until idle
//   verify                                Compare this device's rows with the server's (exit 1 on mismatch)
//   edit-offline --id ID [--merchant M] [--amount C]   Offline edit of one expense, then close
//   server-edit --id ID [--merchant M] [--notes N]     Edit through PostgREST, as the web app would
//   server-insert --merchant M            Insert an expense through PostgREST
//   show --id ID                          Print one expense from this device
//   status                                Print local row and queue counts
//
// Set RELO_OFFLINE=1 to make every endpoint unreachable.

let args = CommandLine.arguments.dropFirst()
let command = args.first ?? "help"

func option(_ name: String) -> String? {
    guard let index = args.firstIndex(of: "--\(name)"), args.index(after: index) < args.endIndex else { return nil }
    return args[args.index(after: index)]
}

let env = SpikeEnvironment.load()
let api = SupabaseAPI(env: env)
let device = option("device") ?? "A"
let quietLogger = DefaultLogger(minSeverity: .warning)

func openDatabase() -> PowerSyncDatabaseProtocol {
    PowerSyncDatabase(schema: reloSchema, dbFilename: env.databasePath(device: device), logger: quietLogger)
}

func count(_ db: PowerSyncDatabaseProtocol, _ sql: String) async throws -> Int64 {
    try await db.get(sql: sql, parameters: []) { try $0.getInt64(index: 0) }
}

func printStatus(_ db: PowerSyncDatabaseProtocol, label: String) async throws {
    let moves = try await count(db, "SELECT count(*) FROM moves")
    let expenses = try await count(db, "SELECT count(*) FROM expenses")
    let queued = try await count(db, "SELECT count(*) FROM ps_crud")
    print("[\(device)] \(label): moves=\(moves) expenses=\(expenses) queued-writes=\(queued)")
}

/// Waits until the upload queue is empty and the sync stream is connected and idle.
func waitUntilIdle(_ db: PowerSyncDatabaseProtocol, timeout: TimeInterval) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    var stableTicks = 0
    var lastError = ""
    while Date() < deadline {
        let status = db.currentStatus
        let queued = try await count(db, "SELECT count(*) FROM ps_crud")
        if let error = status.anyError.map({ String(describing: $0) }), error != lastError {
            print("[\(device)] sync error (will retry): \(error.prefix(200))")
            lastError = error
        }
        let idle = queued == 0 && status.connected && !status.uploading && !status.downloading && (status.hasSynced ?? false)
        stableTicks = idle ? stableTicks + 1 : 0
        if stableTicks >= 4 { return }
        try await Task.sleep(for: .milliseconds(500))
    }
    fail("Timed out after \(Int(timeout))s waiting for sync to go idle")
}

switch command {
case "user":
    let session = try await api.ensureTestUser()
    print("Test user ready: \(session.userId)")

case "write-offline":
    guard env.offline else { fail("write-offline must run with RELO_OFFLINE=1") }
    let n = Int(option("expenses") ?? "50") ?? 50
    let session = try await api.currentSession()
    let db = openDatabase()
    // Connect anyway, like an app that's running with no signal: sync keeps failing and retrying.
    try await db.connect(connector: SupabaseConnector(api: api), options: ConnectOptions(retryDelay: 1))

    let moveId = UUID().uuidString.lowercased()
    try await db.execute(
        sql: "INSERT INTO moves (id, user_id, name, is_active) VALUES (?, ?, ?, 1)",
        parameters: [moveId, session.userId, "Spike move \(Date().formatted(.iso8601))"]
    )
    var expenseIds: [String] = []
    let day = CalendarDate(year: 2026, month: 12, day: 1)
    for i in 1 ... n {
        let id = UUID().uuidString.lowercased()
        expenseIds.append(id)
        // One write per statement, like a user adding receipts one at a time.
        try await db.execute(
            sql: """
            INSERT INTO expenses (id, user_id, move_id, amount_cents, currency, occurred_on, merchant, category_id, payer, missing_receipt)
            VALUES (?, ?, ?, ?, 'USD', ?, ?, ?, 'me', 0)
            """,
            parameters: [id, session.userId, moveId, Int64(i * 137), day.description, "Store \(i)", i % 2 == 0 ? "packing" : "fuel"]
        )
    }
    for id in expenseIds.prefix(20) {
        try await db.execute(sql: "UPDATE expenses SET merchant = merchant || ' (edited)', missing_receipt = 1 WHERE id = ?", parameters: [id])
    }
    for id in expenseIds.suffix(5) {
        try await db.execute(sql: "DELETE FROM expenses WHERE id = ?", parameters: [id])
    }
    try await printStatus(db, label: "after offline writes")
    print("[\(device)] first expense id: \(expenseIds[0])")
    print("[\(device)] simulating force-quit (SIGKILL) without disconnecting or closing")
    fflush(stdout)
    kill(getpid(), SIGKILL)

case "sync":
    let timeout = TimeInterval(option("timeout") ?? "60") ?? 60
    let db = openDatabase()
    try await printStatus(db, label: "before sync")
    let started = Date()
    try await db.connect(connector: SupabaseConnector(api: api), options: ConnectOptions(retryDelay: 1))
    try await waitUntilIdle(db, timeout: timeout)
    print("[\(device)] synced in \(String(format: "%.1f", Date().timeIntervalSince(started)))s")
    try await printStatus(db, label: "after sync")
    try await db.disconnect()
    try await db.close()

case "verify":
    let token = try await api.currentSession().accessToken
    let db = openDatabase()
    struct Row: Hashable { let id: String; let amount: Int64; let merchant: String; let missingReceipt: Int64; let notes: String }
    let local = try await db.getAll(
        sql: "SELECT id, amount_cents, merchant, missing_receipt, coalesce(notes, '') FROM expenses ORDER BY id",
        parameters: []
    ) { Row(id: try $0.getString(index: 0), amount: try $0.getInt64(index: 1), merchant: try $0.getString(index: 2),
            missingReceipt: try $0.getInt64(index: 3), notes: try $0.getString(index: 4)) }
    let remote = try await api.select(table: "expenses", columns: "id,amount_cents,merchant,missing_receipt,notes", token: token).map {
        Row(id: $0["id"] as! String, amount: ($0["amount_cents"] as! NSNumber).int64Value, merchant: $0["merchant"] as! String,
            missingReceipt: ($0["missing_receipt"] as! Bool) ? 1 : 0, notes: ($0["notes"] as? String) ?? "")
    }
    let localMoves = try await count(db, "SELECT count(*) FROM moves")
    let remoteMoves = try await api.select(table: "moves", columns: "id", token: token).count
    let onlyLocal = Set(local).subtracting(remote)
    let onlyRemote = Set(remote).subtracting(local)
    if onlyLocal.isEmpty && onlyRemote.isEmpty && localMoves == Int64(remoteMoves) {
        print("[\(device)] MATCH: \(local.count) expenses and \(localMoves) moves identical on device and server")
    } else {
        print("[\(device)] MISMATCH: device-only=\(onlyLocal.count) server-only=\(onlyRemote.count) moves device=\(localMoves) server=\(remoteMoves)")
        onlyLocal.prefix(5).forEach { print("  device: \($0)") }
        onlyRemote.prefix(5).forEach { print("  server: \($0)") }
        exit(1)
    }
    try await db.close()

case "edit-offline":
    guard env.offline else { fail("edit-offline must run with RELO_OFFLINE=1") }
    guard let id = option("id") else { fail("--id required") }
    let db = openDatabase()
    if let merchant = option("merchant") {
        try await db.execute(sql: "UPDATE expenses SET merchant = ? WHERE id = ?", parameters: [merchant, id])
    }
    if let amount = option("amount").flatMap(Int64.init) {
        try await db.execute(sql: "UPDATE expenses SET amount_cents = ? WHERE id = ?", parameters: [amount, id])
    }
    try await printStatus(db, label: "after offline edit")
    try await db.close()

case "server-edit":
    guard let id = option("id") else { fail("--id required") }
    let token = try await api.currentSession().accessToken
    var fields: JsonParam = [:]
    if let merchant = option("merchant") { fields["merchant"] = .string(merchant) }
    if let notes = option("notes") { fields["notes"] = .string(notes) }
    try await api.update(table: "expenses", id: id, fields: fields, token: token)
    print("server: updated expense \(id) with \(fields.keys.sorted())")

case "server-insert":
    let session = try await api.currentSession()
    let moves = try await api.select(table: "moves", columns: "id", token: session.accessToken)
    guard let moveId = moves.first?["id"] as? String else { fail("No move on the server yet") }
    let id = UUID().uuidString.lowercased()
    try await api.upsert(table: "expenses", row: [
        "id": .string(id), "move_id": .string(moveId), "amount_cents": .int(4200),
        "occurred_on": .string("2026-12-02"), "merchant": .string(option("merchant") ?? "Web entry"),
        "category_id": .string("meals"),
    ], token: session.accessToken)
    print("server: inserted expense \(id)")

case "insert-invalid":
    // A write the server will reject (category_id violates a CHECK constraint).
    let session = try await api.currentSession()
    let db = openDatabase()
    let moveId = try await db.get(sql: "SELECT id FROM moves LIMIT 1", parameters: []) { try $0.getString(index: 0) }
    let id = UUID().uuidString.lowercased()
    try await db.execute(
        sql: """
        INSERT INTO expenses (id, user_id, move_id, amount_cents, currency, occurred_on, merchant, category_id, payer, missing_receipt)
        VALUES (?, ?, ?, 100, 'USD', '2026-12-03', 'Invalid category', 'Not A Valid Category!', 'me', 0)
        """,
        parameters: [id, session.userId, moveId]
    )
    print("[\(device)] inserted invalid expense \(id) locally")
    try await printStatus(db, label: "before sync")
    try await db.connect(connector: SupabaseConnector(api: api), options: ConnectOptions(retryDelay: 1))
    try await waitUntilIdle(db, timeout: 60)
    let stillThere = try await count(db, "SELECT count(*) FROM expenses WHERE id = '\(id)'")
    print("[\(device)] after sync: invalid row still on device? \(stillThere == 1 ? "yes" : "no (removed to match server)")")
    try await printStatus(db, label: "after sync")
    try await db.disconnect()
    try await db.close()

case "show":
    guard let id = option("id") else { fail("--id required") }
    let db = openDatabase()
    let row = try await db.getOptional(
        sql: "SELECT merchant, amount_cents, coalesce(notes, '') FROM expenses WHERE id = ?", parameters: [id]
    ) { "merchant=\"\(try $0.getString(index: 0))\" amount_cents=\(try $0.getInt64(index: 1)) notes=\"\(try $0.getString(index: 2))\"" }
    print("[\(device)] \(row ?? "not found")")
    try await db.close()

case "status":
    let db = openDatabase()
    try await printStatus(db, label: "status")
    try await db.close()

default:
    print("Unknown command \(command). See the usage comment in main.swift.")
    exit(2)
}
