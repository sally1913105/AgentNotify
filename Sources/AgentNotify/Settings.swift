import AppKit

enum Corner: String {
    case bottomRight, topRight, bottomLeft, topLeft

    init(lenient raw: String?) {
        switch (raw ?? "").lowercased().replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "") {
        case "topright":    self = .topRight
        case "bottomleft":  self = .bottomLeft
        case "topleft":     self = .topLeft
        default:            self = .bottomRight
        }
    }

    var isTop: Bool { self == .topRight || self == .topLeft }
    var isRight: Bool { self == .bottomRight || self == .topRight }
}

/// User preferences, read from `~/Library/Application Support/AgentNotify/config.json`.
/// Every field is optional in the file; missing keys fall back to these defaults.
struct Settings {
    /// Focus the popup when it appears. `true` makes Esc work instantly but
    /// takes keyboard focus away from whatever you were typing in.
    var stealFocus = false
    /// Auto-dismiss delay for non-sticky levels (info / success).
    var autoDismissSeconds: Double = 15
    /// How many cards can be stacked on screen at once.
    var maxVisible = 3
    var sound = true
    var soundName = "Ping"
    var cardWidth: Double = 380
    var position: Corner = .bottomRight
    /// Float above the Dock and every normal window. Turn off if you'd rather
    /// the card sit at the ordinary floating level.
    var alwaysOnTop = true
    /// Which display to pop on: `mouse` (where you're looking), `main`, or an
    /// index into the screen list.
    var screen = "mouse"
    /// Margin from the screen edges.
    var margin: Double = 16
    /// Vertical gap between stacked cards.
    var gap: Double = 10
    var historyLimit = 60
    /// Esc closes every visible card, not just the newest one.
    var escClosesAll = true
    /// Optional forwarding to the macOS Messages app. Disabled by default.
    var iMessageEnabled = false
    var iMessageRecipient = ""
    var iMessageLevels = ["action", "error"]

    static func load() -> Settings {
        var s = Settings()
        guard let data = try? Data(contentsOf: Paths.configFile),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return s }

        if let v = json["stealFocus"] as? Bool { s.stealFocus = v }
        if let v = json["autoDismissSeconds"] as? Double { s.autoDismissSeconds = v }
        if let v = json["autoDismissSeconds"] as? Int { s.autoDismissSeconds = Double(v) }
        if let v = json["maxVisible"] as? Int { s.maxVisible = max(1, min(8, v)) }
        if let v = json["sound"] as? Bool { s.sound = v }
        if let v = json["soundName"] as? String, !v.isEmpty { s.soundName = v }
        if let v = json["cardWidth"] as? Double { s.cardWidth = max(260, min(620, v)) }
        if let v = json["cardWidth"] as? Int { s.cardWidth = max(260, min(620, Double(v))) }
        if let v = json["position"] as? String { s.position = Corner(lenient: v) }
        if let v = json["alwaysOnTop"] as? Bool { s.alwaysOnTop = v }
        if let v = json["screen"] as? String, !v.isEmpty { s.screen = v }
        if let v = json["screen"] as? Int { s.screen = String(v) }
        if let v = json["margin"] as? Double { s.margin = max(0, min(200, v)) }
        if let v = json["margin"] as? Int { s.margin = max(0, min(200, Double(v))) }
        if let v = json["gap"] as? Double { s.gap = max(0, min(60, v)) }
        if let v = json["gap"] as? Int { s.gap = max(0, min(60, Double(v))) }
        if let v = json["historyLimit"] as? Int { s.historyLimit = max(5, min(500, v)) }
        if let v = json["escClosesAll"] as? Bool { s.escClosesAll = v }
        if let messages = json["imessage"] as? [String: Any] {
            if let v = messages["enabled"] as? Bool { s.iMessageEnabled = v }
            if let v = messages["recipient"] as? String { s.iMessageRecipient = v.trimmingCharacters(in: .whitespacesAndNewlines) }
            if let v = messages["levels"] as? [String] {
                s.iMessageLevels = v.map { MessageLevel(lenient: $0).rawValue }
            }
        }
        return s
    }

    /// Create the config on first launch, and backfill keys added by later
    /// versions, so the file always shows every option you can tune.
    /// Values you have already set are never touched.
    static func writeTemplateIfMissing() {
        let d = Settings()
        let defaults: [String: Any] = [
            "stealFocus": d.stealFocus,
            "autoDismissSeconds": d.autoDismissSeconds,
            "maxVisible": d.maxVisible,
            "sound": d.sound,
            "soundName": d.soundName,
            "cardWidth": d.cardWidth,
            "position": d.position.rawValue,
            "alwaysOnTop": d.alwaysOnTop,
            "screen": d.screen,
            "margin": d.margin,
            "gap": d.gap,
            "historyLimit": d.historyLimit,
            "escClosesAll": d.escClosesAll,
            "imessage": [
                "enabled": d.iMessageEnabled,
                "recipient": d.iMessageRecipient,
                "levels": d.iMessageLevels,
            ],
        ]

        var merged: [String: Any] = defaults
        var changed = true
        if let data = try? Data(contentsOf: Paths.configFile),
           let existing = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            changed = !defaults.keys.allSatisfy { existing.keys.contains($0) }
            merged = defaults.merging(existing) { _, mine in mine }
        }
        guard changed else { return }

        if let data = try? JSONSerialization.data(withJSONObject: merged,
                                                 options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: Paths.configFile, options: .atomic)
        }
    }

    func shouldSendIMessage(level: String) -> Bool {
        iMessageEnabled && !iMessageRecipient.isEmpty && iMessageLevels.contains(MessageLevel(lenient: level).rawValue)
    }
}
