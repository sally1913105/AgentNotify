import AppKit

/// The same binary doubles as the sender. `AgentNotify send --title ...` writes
/// a JSON file into the inbox and exits, which means agents never have to
/// hand-escape JSON or know a port number.
enum CLI {
    static let version = "1.0.0"

    /// Returns an exit code when these arguments were a CLI invocation, or
    /// `nil` when the process should boot the menu bar UI instead.
    static func handle(_ args: [String]) -> Int32? {
        // Invoked through the `agent-notify` symlink? Then everything is a send
        // unless it's an explicit subcommand, so `agent-notify "title" "description"`
        // works without a verb.
        let invokedName = (CommandLine.arguments.first as NSString?)?.lastPathComponent ?? ""
        let senderAlias = invokedName == "agent-notify" || invokedName == "notify"

        guard let first = args.first else {
            return senderAlias ? runSend([]) : nil
        }
        if first.hasPrefix("-psn") || first == "--ui" { return nil }

        switch first {
        case "send", "notify", "msg", "-s":
            return runSend(Array(args.dropFirst()))
        case "doctor":
            return runDoctor()
        case "help", "--help", "-h":
            printUsage()
            return 0
        case "version", "--version", "-v":
            print("agent-notify \(version)")
            return 0
        default:
            // Flag-first form: `AgentNotify --title "done" --body "..."`
            if first.hasPrefix("-") || senderAlias { return runSend(args) }
            return nil
        }
    }

    // MARK: - send

    private static func runSend(_ args: [String]) -> Int32 {
        var title = ""
        var body = ""
        var agent = "agent"
        var project: String?
        var level = "info"
        var timeout: Double?
        var sticky = false
        var launch = true
        var quiet = false
        var positional: [String] = []

        var i = 0
        func next(_ flag: String) -> String? {
            guard i + 1 < args.count else {
                FileHandle.standardError.write(Data("agent-notify: \(flag) requires a value\n".utf8))
                return nil
            }
            i += 1
            return args[i]
        }

        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--title", "-t":
                guard let v = next(arg) else { return 2 }
                title = v
            case "--body", "-b", "--message", "-m":
                guard let v = next(arg) else { return 2 }
                body = (v == "-") ? readStdin() : v
            case "--body-file":
                guard let v = next(arg) else { return 2 }
                body = (try? String(contentsOfFile: v, encoding: .utf8)) ?? ""
            case "--stdin":
                body = readStdin()
            case "--agent", "-a", "--from":
                guard let v = next(arg) else { return 2 }
                agent = v
            case "--project", "-p", "--cwd":
                guard let v = next(arg) else { return 2 }
                project = v
            case "--level", "-l":
                guard let v = next(arg) else { return 2 }
                level = v
            case "--timeout":
                guard let v = next(arg) else { return 2 }
                timeout = Double(v)
            case "--sticky":
                sticky = true
            case "--no-launch":
                launch = false
            case "--quiet", "-q":
                quiet = true
            case "--help", "-h":
                printUsage()
                return 0
            default:
                if arg.hasPrefix("-") {
                    FileHandle.standardError.write(Data("agent-notify: unknown option \(arg)\n".utf8))
                    return 2
                }
                positional.append(arg)
            }
            i += 1
        }

        if title.isEmpty, let first = positional.first { title = first }
        if body.isEmpty, positional.count > 1 { body = positional[1...].joined(separator: " ") }

        guard !title.isEmpty || !body.isEmpty else {
            FileHandle.standardError.write(Data("agent-notify: --title or --body is required\n".utf8))
            printUsage()
            return 2
        }
        if title.isEmpty { title = "Agent message" }

        var payload: [String: Any] = [
            "id": UUID().uuidString,
            "title": title,
            "body": body,
            "agent": agent,
            "level": MessageLevel(lenient: level).rawValue,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
        ]
        if let project { payload["project"] = project }
        if sticky {
            payload["timeout"] = 0
        } else if let timeout {
            payload["timeout"] = timeout
        }

        guard let url = write(payload: payload) else {
            FileHandle.standardError.write(Data("agent-notify: failed to write inbox file \(Paths.inbox.path)\n".utf8))
            return 1
        }

        touchLastSent(agent: agent)
        if launch { launchAppIfNeeded() }
        if !quiet { print("queued \(url.lastPathComponent)") }
        return 0
    }

    /// Marker for Stop-hooks: "an agent already said something useful just now,
    /// don't add a generic one on top". Records who sent it, so a hook can tell
    /// its own automatic popups apart from ones an agent wrote deliberately.
    private static func touchLastSent(agent: String) {
        let stamp = String(format: "%.0f\t%@\n", Date().timeIntervalSince1970, agent)
        try? stamp.write(to: Paths.lastSentFile, atomically: true, encoding: .utf8)
    }

    private static func write(payload: [String: Any]) -> URL? {
        Paths.ensureDirectories()
        guard let data = try? JSONSerialization.data(withJSONObject: payload,
                                                     options: [.prettyPrinted]) else { return nil }

        let stamp = String(format: "%013.0f", Date().timeIntervalSince1970 * 1000)
        let name = "\(stamp)-\(UUID().uuidString.prefix(8)).json"
        let final = Paths.inbox.appendingPathComponent(name)
        // Hidden + non-.json while being written, so a concurrent drain skips it.
        let temp = Paths.inbox.appendingPathComponent(".\(name).tmp")

        do {
            try data.write(to: temp, options: .atomic)
            try FileManager.default.moveItem(at: temp, to: final)
            return final
        } catch {
            try? FileManager.default.removeItem(at: temp)
            return nil
        }
    }

    private static func readStdin() -> String {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - app launching

    static func appBundleURL() -> URL? {
        let bundle = Bundle.main.bundleURL
        if bundle.pathExtension == "app" { return bundle }

        if let exe = Bundle.main.executableURL?.resolvingSymlinksInPath() {
            var candidate = exe
            for _ in 0..<3 { candidate = candidate.deletingLastPathComponent() }
            if candidate.pathExtension == "app" { return candidate }
        }
        for path in ["/Applications/AgentNotify.app",
                     NSHomeDirectory() + "/Applications/AgentNotify.app"] {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    /// `open -g -a` is a no-op when the app already runs, and `-g` keeps it from
    /// stealing focus on first launch.
    private static func launchAppIfNeeded() {
        guard !isDaemonRunning(), let app = appBundleURL() else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-g", "-a", app.path]
        try? process.run()
        process.waitUntilExit()
    }

    static func isDaemonRunning() -> Bool {
        guard let text = try? String(contentsOf: Paths.lockFile, encoding: .utf8),
              let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return false }
        return kill(pid, 0) == 0
    }

    // MARK: - doctor

    private static func runDoctor() -> Int32 {
        Paths.ensureDirectories()
        let fm = FileManager.default
        let pending = ((try? fm.contentsOfDirectory(atPath: Paths.inbox.path)) ?? [])
            .filter { $0.hasSuffix(".json") }.count
        let history = ((try? Data(contentsOf: Paths.historyFile))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [[String: Any]])?.count ?? 0

        let settings = Settings.load()
        print("""
        agent-notify \(version)
          app bundle   : \(appBundleURL()?.path ?? "(AgentNotify.app not found)")
          UI process    : \(isDaemonRunning() ? "running" : "not running")
          inbox         : \(Paths.inbox.path)  (pending \(pending))
          archive       : \(Paths.archive.path)
          config        : \(Paths.configFile.path)  (\(fm.fileExists(atPath: Paths.configFile.path) ? "present" : "missing"))
          history       : \(history) messages
          position      : \(settings.position.rawValue) · margin \(Int(settings.margin)) · width \(Int(settings.cardWidth))
          window level  : \(settings.alwaysOnTop ? "statusBar (above Dock and normal windows)" : "floating")
          target screen : \(settings.screen)
        """)

        for (index, screen) in NSScreen.screens.enumerated() {
            let f = screen.frame
            let v = screen.visibleFrame
            let margin = CGFloat(settings.margin)
            let originX = settings.position.isRight
                ? v.maxX - margin - CGFloat(settings.cardWidth)
                : v.minX + margin
            print(String(format: "  screen[%d]    : frame %.0fx%.0f@(%.0f,%.0f) · visible %.0fx%.0f@(%.0f,%.0f) · card x=%.0f",
                         index, f.width, f.height, f.minX, f.minY,
                         v.width, v.height, v.minX, v.minY, originX))
        }
        return 0
    }

    // MARK: - usage

    private static func printUsage() {
        print("""
        agent-notify \(version) — send an agent message to the macOS corner and menu bar

        Usage:
          agent-notify send --title <title> [--body <description>] [options]
          agent-notify send "title" "description"
          agent-notify doctor
          agent-notify --version

        Options:
          -t, --title <s>      Short conclusion, usually what was completed
          -b, --body <s>       Task description; use - to read from stdin
              --body-file <f>  Read the description from a file
          -a, --agent <s>      Source agent name, for example codex or claude-code
          -p, --project <s>    Project path or name shown on the card
          -l, --level <s>      info | success | action | error (default: info)
                               action / error cards stay visible until dismissed
              --timeout <s>    Auto-dismiss delay; 0 = sticky
              --sticky         Same as --timeout 0
              --no-launch      Do not start AgentNotify.app automatically
          -q, --quiet          Suppress the queue confirmation

        Examples:
          agent-notify send -a kiro -l success \\
            -t "Auth refactor complete" \\
            -b "Changed four files; all tests pass. Please review the src/auth diff." \\
            -p "$PWD"

          agent-notify send -a claude-code -l action --sticky \\
            -t "Confirmation required" -b "The migration removes the old table. I will continue after confirmation."
        """)
    }
}
