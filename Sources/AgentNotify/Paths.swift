import Foundation

/// All on-disk locations used by AgentNotify.
///
/// The inbox is the only IPC channel: a sender drops a `.json` file in
/// `inbox/`, the running UI instance picks it up and archives it. No ports,
/// no sockets, and messages survive the app not running yet.
enum Paths {
    static let appSupport: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("AgentNotify", isDirectory: true)
    }()

    static let inbox = appSupport.appendingPathComponent("inbox", isDirectory: true)
    static let archive = appSupport.appendingPathComponent("archive", isDirectory: true)
    static let configFile = appSupport.appendingPathComponent("config.json")
    static let historyFile = appSupport.appendingPathComponent("history.json")
    static let lockFile = appSupport.appendingPathComponent("agentnotify.lock")
    /// Touched on every successful send. Stop-hooks read it to avoid firing a
    /// generic "task finished" popup right after the agent sent a real one.
    static let lastSentFile = appSupport.appendingPathComponent("last_sent")

    static func ensureDirectories() {
        let fm = FileManager.default
        for dir in [appSupport, inbox, archive] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
