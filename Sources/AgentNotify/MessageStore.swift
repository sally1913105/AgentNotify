import Foundation

/// In-memory history backing the menu bar list, persisted to `history.json`
/// so a restart doesn't lose what you haven't read yet.
final class MessageStore {
    private(set) var messages: [AgentMessage] = []   // newest first
    var onChange: () -> Void = {}
    var limit: Int

    init(limit: Int) {
        self.limit = limit
    }

    var unreadCount: Int { messages.lazy.filter { !$0.isRead }.count }
    var unread: [AgentMessage] { messages.filter { !$0.isRead } }

    func message(id: String) -> AgentMessage? { messages.first { $0.id == id } }

    func add(_ message: AgentMessage) {
        messages.removeAll { $0.id == message.id }
        messages.insert(message, at: 0)
        if messages.count > limit { messages.removeLast(messages.count - limit) }
        changed()
    }

    func markRead(id: String) {
        guard let i = messages.firstIndex(where: { $0.id == id }), !messages[i].isRead else { return }
        messages[i].isRead = true
        changed()
    }

    func markAllRead() {
        guard messages.contains(where: { !$0.isRead }) else { return }
        for i in messages.indices { messages[i].isRead = true }
        changed()
    }

    func clear() {
        guard !messages.isEmpty else { return }
        messages.removeAll()
        changed()
    }

    private func changed() {
        save()
        onChange()
    }

    // MARK: - Persistence

    func load() {
        guard let data = try? Data(contentsOf: Paths.historyFile),
              let raw = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
        else { return }
        messages = raw.compactMap { AgentMessage(json: $0) }
        if messages.count > limit { messages.removeLast(messages.count - limit) }
    }

    func save() {
        let raw = messages.map { $0.jsonObject }
        guard let data = try? JSONSerialization.data(withJSONObject: raw,
                                                    options: [.prettyPrinted]) else { return }
        try? data.write(to: Paths.historyFile, options: .atomic)
    }
}
