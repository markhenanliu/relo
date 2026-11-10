import Foundation

/// Spike configuration from environment variables, plus a local state folder
/// (git-ignored) for the test user's session and each simulated device's database.
struct SpikeEnvironment: Sendable {
    let supabaseURL: URL
    let supabaseKey: String
    let powerSyncURL: String
    /// When true, every network endpoint points at a closed port: the "device" is offline.
    let offline: Bool
    let stateDirectory: URL

    static let unreachable = "http://127.0.0.1:9"

    static func load() -> SpikeEnvironment {
        let env = ProcessInfo.processInfo.environment
        guard let key = env["SUPABASE_KEY"], !key.isEmpty else {
            fail("Set SUPABASE_KEY to the local publishable key (see `supabase status`).")
        }
        let offline = env["RELO_OFFLINE"] == "1"
        let state = URL(filePath: env["SPIKE_STATE_DIR"] ?? FileManager.default.currentDirectoryPath)
            .appending(path: ".state")
        try? FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
        return SpikeEnvironment(
            supabaseURL: URL(string: offline ? unreachable : env["SUPABASE_URL"] ?? "http://127.0.0.1:54321")!,
            supabaseKey: key,
            powerSyncURL: offline ? unreachable : env["POWERSYNC_URL"] ?? "http://127.0.0.1:8080",
            offline: offline,
            stateDirectory: state
        )
    }

    func databasePath(device: String) -> String {
        stateDirectory.appending(path: "device-\(device).sqlite").path
    }

    var sessionFile: URL { stateDirectory.appending(path: "session.json") }
    var rejectedLog: URL { stateDirectory.appending(path: "rejected-uploads.log") }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(2)
}
