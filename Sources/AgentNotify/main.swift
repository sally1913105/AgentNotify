import AppKit

// One binary, two roles: a short-lived sender (`send`, `doctor`, ...) or the
// resident menu bar UI when launched with no arguments.
let arguments = Array(CommandLine.arguments.dropFirst())

if let code = CLI.handle(arguments) {
    exit(code)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
