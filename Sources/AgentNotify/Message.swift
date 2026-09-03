import AppKit

/// Severity / intent of a message. Drives accent color, icon and whether the
/// toast auto-dismisses.
enum MessageLevel: String {
    case info
    case success
    case action
    case error

    /// Forgiving parser: agents write whatever word feels natural.
    init(lenient raw: String?) {
        switch (raw ?? "").lowercased() {
        case "success", "done", "ok", "complete", "completed", "finish", "finished":
            self = .success
        case "action", "action_required", "actionrequired", "input", "ask",
             "need_input", "needinput", "blocked", "waiting", "todo":
            self = .action
        case "error", "err", "fail", "failed", "failure", "warn", "warning", "crash":
            self = .error
        default:
            self = .info
        }
    }

    var accent: NSColor {
        switch self {
        case .info:    return .systemBlue
        case .success: return .systemGreen
        case .action:  return .systemOrange
        case .error:   return .systemRed
        }
    }

    var glyph: String {
        switch self {
        case .info:    return "💬"
        case .success: return "✅"
        case .action:  return "✋"
        case .error:   return "⚠️"
        }
    }

    /// Sticky levels never auto-dismiss: they need a human decision.
    var isSticky: Bool { self == .action || self == .error }
}

/// One popup-worthy event produced by an agent.
struct AgentMessage {
    let id: String
    let title: String
    let body: String
    let agent: String
    let project: String?
    let level: MessageLevel
    let createdAt: Date
    /// Seconds before auto-dismiss. `nil` = decide from level, `0` = sticky.
    let timeout: Double?
    var isRead: Bool

    var displayAgent: String {
        agent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "agent" : agent
    }

    var timeString: String { Self.timeFormatter.string(from: createdAt) }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Effective auto-dismiss delay given user settings. `nil` = stay forever.
    func dismissDelay(defaultSeconds: Double) -> Double? {
        if let t = timeout {
            return t <= 0 ? nil : t
        }
        return level.isSticky ? nil : max(2, defaultSeconds)
    }
}

// MARK: - JSON

extension AgentMessage {
    /// Lenient decode. Accepts common aliases so a hand-rolled `echo > json`
    /// from any agent still lands.
    init?(json: [String: Any]) {
        func str(_ keys: [String]) -> String? {
            for k in keys {
                if let v = json[k] as? String {
                    let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty { return t }
                }
            }
            return nil
        }

        let title = str(["title", "subject", "headline"]) ?? ""
        let body = str(["body", "message", "text", "detail", "description", "summary"]) ?? ""
        guard !title.isEmpty || !body.isEmpty else { return nil }

        self.id = str(["id", "uuid"]) ?? UUID().uuidString
        self.title = title.isEmpty ? "Agent message" : title
        self.body = body
        self.agent = str(["agent", "from", "source", "sender", "app"]) ?? "agent"
        self.project = str(["project", "cwd", "repo", "workspace"])
        self.level = MessageLevel(lenient: str(["level", "type", "kind", "severity"]))

        if let n = json["createdAt"] as? Double {
            self.createdAt = Date(timeIntervalSince1970: n)
        } else if let s = json["createdAt"] as? String,
                  let d = Self.isoFormatter.date(from: s) {
            self.createdAt = d
        } else {
            self.createdAt = Date()
        }

        if let n = json["timeout"] as? Double {
            self.timeout = n
        } else if let n = json["timeout"] as? Int {
            self.timeout = Double(n)
        } else if let s = json["timeout"] as? String, let n = Double(s) {
            self.timeout = n
        } else if (json["sticky"] as? Bool) == true {
            self.timeout = 0
        } else {
            self.timeout = nil
        }

        self.isRead = (json["isRead"] as? Bool) ?? false
    }

    var jsonObject: [String: Any] {
        var o: [String: Any] = [
            "id": id,
            "title": title,
            "body": body,
            "agent": agent,
            "level": level.rawValue,
            "createdAt": Self.isoFormatter.string(from: createdAt),
            "isRead": isRead,
        ]
        if let project { o["project"] = project }
        if let timeout { o["timeout"] = timeout }
        return o
    }
}
