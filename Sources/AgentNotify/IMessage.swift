import Foundation

/// Sends selected notifications through the macOS Messages app.
/// This is intentionally opt-in because Messages automation requires a user
/// permission and creates a normal conversation entry for every forwarded card.
enum IMessage {
    static func send(title: String, body: String, recipient: String) -> Bool {
        let message = body.isEmpty ? title : "\(title)\n\(body)"
        // Keep the generated AppleScript small and avoid turning a notification
        // into an accidental bulk-message channel.
        let boundedMessage = String(message.prefix(2_000))
        let script = """
        on run argv
            tell application "Messages"
                set targetService to first service whose service type is iMessage
                set targetBuddy to buddy (item 1 of argv) of targetService
                send (item 2 of argv) to targetBuddy
            end tell
        end run
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, recipient, boundedMessage]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

}
