import AppKit

/// Menu bar presence: a bell with an unread count, plus the message history.
/// The menu is rebuilt lazily every time it opens.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let historyInMenu = 15

    var messagesProvider: () -> [AgentMessage] = { [] }
    var unreadProvider: () -> Int = { 0 }

    var onSelectMessage: (String) -> Void = { _ in }
    var onShowUnread: () -> Void = {}
    var onMarkAllRead: () -> Void = {}
    var onClearHistory: () -> Void = {}
    var onOpenInbox: () -> Void = {}
    var onOpenConfig: () -> Void = {}
    var onReloadSettings: () -> Void = {}
    var onSendTest: () -> Void = {}
    var onQuit: () -> Void = {}

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refresh()
    }

    /// Update the bell + unread badge.
    func refresh() {
        guard let button = statusItem.button else { return }
        let unread = unreadProvider()
        let symbol = unread > 0 ? "bell.badge.fill" : "bell"

        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "AgentNotify") {
            image.isTemplate = true
            button.image = image.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 13.5, weight: .regular)) ?? image
            button.title = unread > 0 ? " \(unread)" : ""
            button.imagePosition = unread > 0 ? .imageLeading : .imageOnly
        } else {
            button.image = nil
            button.title = unread > 0 ? "🔔 \(unread)" : "🔔"
            button.imagePosition = .noImage
        }
        button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        button.toolTip = unread > 0 ? "AgentNotify · \(unread) unread" : "AgentNotify"
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu)
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        let messages = messagesProvider()
        let unread = unreadProvider()

        menu.addItem(disabled(unread > 0 ? "AgentNotify · \(unread) unread" : "AgentNotify · All read"))
        menu.addItem(.separator())

        if messages.isEmpty {
            menu.addItem(disabled("No messages"))
        } else {
            for message in messages.prefix(historyInMenu) {
                let item = NSMenuItem(title: "", action: #selector(selectMessage(_:)), keyEquivalent: "")
                item.target = self
                item.attributedTitle = menuTitle(for: message)
                item.representedObject = message.id
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        add(to: menu, "Show unread messages", #selector(showUnread), enabled: unread > 0)
        add(to: menu, "Mark all as read", #selector(markAllRead), enabled: unread > 0)
        add(to: menu, "Clear history", #selector(clearHistory), enabled: !messages.isEmpty)
        menu.addItem(.separator())
        add(to: menu, "Send test message", #selector(sendTest))
        add(to: menu, "Open inbox folder", #selector(openInbox))
        add(to: menu, "Edit config file", #selector(openConfig))
        add(to: menu, "Reload configuration", #selector(reloadSettings))
        menu.addItem(.separator())
        add(to: menu, "Quit AgentNotify", #selector(quit), key: "q")
    }

    private func menuTitle(for message: AgentMessage) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 1
        paragraph.lineBreakMode = .byTruncatingTail

        let titleLine = "\(message.level.glyph) \(short(message.title, 46))"
        let result = NSMutableAttributedString(string: titleLine + "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: message.isRead ? .regular : .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ])

        var detail = "\(message.displayAgent) · \(message.timeString)"
        if let project = message.project, !project.isEmpty {
            detail = "\(message.displayAgent) · \((project as NSString).lastPathComponent) · \(message.timeString)"
        }
        result.append(NSAttributedString(string: "      " + short(detail, 52), attributes: [
            .font: NSFont.systemFont(ofSize: 10.5),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ]))
        return result
    }

    private func short(_ text: String, _ limit: Int) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return flat.count <= limit ? flat : String(flat.prefix(limit)) + "…"
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @discardableResult
    private func add(to menu: NSMenu, _ title: String, _ action: Selector,
                     key: String = "", enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.isEnabled = enabled
        menu.addItem(item)
        return item
    }

    // MARK: - Actions

    @objc private func selectMessage(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        onSelectMessage(id)
    }

    @objc private func showUnread() { onShowUnread() }
    @objc private func markAllRead() { onMarkAllRead() }
    @objc private func clearHistory() { onClearHistory() }
    @objc private func openInbox() { onOpenInbox() }
    @objc private func openConfig() { onOpenConfig() }
    @objc private func reloadSettings() { onReloadSettings() }
    @objc private func sendTest() { onSendTest() }
    @objc private func quit() { onQuit() }
}
