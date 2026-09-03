import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings = Settings.load()
    private lazy var store = MessageStore(limit: settings.historyLimit)
    private let inbox = Inbox()
    private var toasts: ToastManager!
    private var status: StatusItemController!

    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var lockDescriptor: CInt = -1

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Paths.ensureDirectories()
        Settings.writeTemplateIfMissing()

        guard acquireSingleInstanceLock() else {
            // Another UI instance already owns the menu bar; that one will pick
            // up whatever is in the inbox.
            NSApp.terminate(nil)
            return
        }

        settings = Settings.load()
        store.limit = settings.historyLimit
        store.load()

        toasts = ToastManager(settings: settings)
        toasts.onAcknowledge = { [weak self] id in
            self?.store.markRead(id: id)
        }

        status = StatusItemController()
        wireStatusItem()

        store.onChange = { [weak self] in
            self?.status.refresh()
        }
        status.refresh()

        inbox.onMessage = { [weak self] message in
            self?.present(message)
        }
        inbox.start()

        installKeyMonitors()
    }

    func applicationWillTerminate(_ notification: Notification) {
        inbox.stop()
        if let m = localKeyMonitor { NSEvent.removeMonitor(m) }
        if let m = globalKeyMonitor { NSEvent.removeMonitor(m) }
        store.save()
        releaseSingleInstanceLock()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: - Message flow

    private func present(_ message: AgentMessage) {
        store.add(message)
        toasts.show(message)
        if settings.sound {
            NSSound(named: NSSound.Name(settings.soundName))?.play()
        }
        status.refresh()
    }

    private func reshow(id: String) {
        guard let message = store.message(id: id) else { return }
        toasts.show(message)
    }

    // MARK: - Status item wiring

    private func wireStatusItem() {
        status.messagesProvider = { [weak self] in self?.store.messages ?? [] }
        status.unreadProvider = { [weak self] in self?.store.unreadCount ?? 0 }

        status.onSelectMessage = { [weak self] id in self?.reshow(id: id) }

        status.onShowUnread = { [weak self] in
            guard let self else { return }
            for message in self.store.unread.prefix(self.settings.maxVisible).reversed() {
                self.toasts.show(message)
            }
        }

        status.onMarkAllRead = { [weak self] in
            self?.store.markAllRead()
            self?.toasts.hideAll()
        }

        status.onClearHistory = { [weak self] in
            self?.store.clear()
            self?.toasts.hideAll()
        }

        status.onOpenInbox = {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: Paths.inbox.path)
        }

        status.onOpenConfig = {
            Settings.writeTemplateIfMissing()
            NSWorkspace.shared.open(Paths.configFile)
        }

        status.onReloadSettings = { [weak self] in
            guard let self else { return }
            self.settings = Settings.load()
            self.toasts.settings = self.settings
            self.store.limit = self.settings.historyLimit
            self.present(AgentMessage(
                id: UUID().uuidString,
                title: "Configuration reloaded",
                body: "Position \(self.settings.position.rawValue) · Card width \(Int(self.settings.cardWidth)) · "
                    + "Auto-dismiss \(Int(self.settings.autoDismissSeconds))s · "
                    + "Steal focus \(self.settings.stealFocus ? "on" : "off")",
                agent: "AgentNotify",
                project: nil,
                level: .info,
                createdAt: Date(),
                timeout: nil,
                isRead: false))
        }

        status.onSendTest = { [weak self] in
            self?.present(AgentMessage(
                id: UUID().uuidString,
                title: "Auth refactor complete",
                body: "Changed four files and added two tests; all pass. Please review the src/auth diff. "
                    + "The legacy token field in config is unchanged pending your confirmation.",
                agent: "kiro",
                project: "message_window",
                level: .action,
                createdAt: Date(),
                timeout: nil,
                isRead: false))
        }

        status.onQuit = { NSApp.terminate(nil) }
    }

    // MARK: - Esc handling

    /// Three layers, because macOS routes keys to the frontmost app:
    /// - local monitor: works when AgentNotify itself has focus
    /// - panel `cancelOperation`: works when the card is the key window
    /// - global monitor: works from any app, but only once Accessibility
    ///   permission is granted (silently inert otherwise)
    ///
    /// All three only *hide* the card. Esc is a key people press for unrelated
    /// reasons, so it must not be able to silently clear the unread badge.
    private func installKeyMonitors() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53, self.toasts.hasVisibleToasts else { return event }
            self.toasts.hideAll()
            return nil
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53, self.toasts.hasVisibleToasts else { return }
            self.toasts.hideAll()
        }
    }

    // MARK: - Single instance

    private func acquireSingleInstanceLock() -> Bool {
        let fd = open(Paths.lockFile.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return true }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            return false
        }
        lockDescriptor = fd
        ftruncate(fd, 0)
        let pid = "\(ProcessInfo.processInfo.processIdentifier)\n"
        _ = pid.withCString { write(fd, $0, strlen($0)) }
        return true
    }

    private func releaseSingleInstanceLock() {
        guard lockDescriptor >= 0 else { return }
        flock(lockDescriptor, LOCK_UN)
        close(lockDescriptor)
        lockDescriptor = -1
    }
}
