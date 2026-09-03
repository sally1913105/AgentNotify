import AppKit

/// Owns the on-screen stack of cards: placement in the chosen screen corner,
/// slide-in animation, auto-dismiss timers, and Esc handling.
final class ToastManager {
    private struct Entry {
        let id: String
        let panel: ToastPanel
        var timer: Timer?
    }

    /// Newest first; index 0 sits closest to the screen corner.
    private var entries: [Entry] = []

    var settings: Settings
    /// Fired when the human explicitly acknowledged a card (click / ✕).
    /// Esc only hides, so a stray Esc never clears the unread badge.
    var onAcknowledge: (String) -> Void = { _ in }

    init(settings: Settings) {
        self.settings = settings
    }

    var hasVisibleToasts: Bool { !entries.isEmpty }

    // MARK: - Showing

    func show(_ message: AgentMessage) {
        if entries.contains(where: { $0.id == message.id }) {
            remove(id: message.id, animated: false)
        }

        let width = CGFloat(settings.cardWidth)
        let card = ToastCardView(message: message, width: width)
        let panel = ToastPanel(card: card,
                               width: width,
                               height: card.frame.height,
                               alwaysOnTop: settings.alwaysOnTop)

        card.onDismiss = { [weak self] in
            self?.acknowledge(id: message.id)
        }
        panel.onEscape = { [weak self] in
            guard let self else { return }
            if self.settings.escClosesAll {
                self.hideAll()
            } else {
                self.hide(id: message.id)
            }
        }

        entries.insert(Entry(id: message.id, panel: panel, timer: nil), at: 0)

        while entries.count > settings.maxVisible, let oldest = entries.last {
            remove(id: oldest.id, animated: true)
        }

        relayout(newest: panel)

        if settings.stealFocus {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }

        if let delay = message.dismissDelay(defaultSeconds: settings.autoDismissSeconds) {
            let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.remove(id: message.id, animated: true)
            }
            if let i = entries.firstIndex(where: { $0.id == message.id }) {
                entries[i].timer = timer
            }
        }
    }

    // MARK: - Dismissing

    /// The human clicked the card: close it and count it as read.
    func acknowledge(id: String) {
        guard entries.contains(where: { $0.id == id }) else { return }
        remove(id: id, animated: true)
        onAcknowledge(id)
    }

    /// Get out of the way, but stay unread. Esc lands here, because Esc is a
    /// key people hit constantly for unrelated reasons.
    func hide(id: String) {
        remove(id: id, animated: true)
    }

    func hideAll() {
        for id in entries.map(\.id) {
            remove(id: id, animated: true)
        }
    }

    private func remove(id: String, animated: Bool) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let entry = entries.remove(at: index)
        entry.timer?.invalidate()

        let panel = entry.panel
        guard animated else {
            panel.orderOut(nil)
            panel.close()
            relayout(newest: nil)
            return
        }

        let dx: CGFloat = settings.position.isRight ? 24 : -24
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(panel.frame.offsetBy(dx: dx, dy: 0), display: true)
        }, completionHandler: {
            panel.orderOut(nil)
            panel.close()
        })

        relayout(newest: nil)
    }

    // MARK: - Placement

    private func relayout(newest: ToastPanel?) {
        guard let screen = targetScreen() else { return }
        let visible = screen.visibleFrame
        let margin = CGFloat(settings.margin)
        let gap = CGFloat(settings.gap)
        var offset: CGFloat = 0

        for entry in entries {
            let panel = entry.panel
            let size = panel.frame.size
            let x = settings.position.isRight
                ? visible.maxX - margin - size.width
                : visible.minX + margin
            let y = settings.position.isTop
                ? visible.maxY - margin - size.height - offset
                : visible.minY + margin + offset
            let target = NSRect(x: x, y: y, width: size.width, height: size.height)

            if panel === newest {
                let dx: CGFloat = settings.position.isRight ? 28 : -28
                panel.setFrame(target.offsetBy(dx: dx, dy: 0), display: false)
                panel.alphaValue = 0
                panel.orderFrontRegardless()
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.24
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    panel.animator().setFrame(target, display: true)
                    panel.animator().alphaValue = 1
                }
            } else if panel.frame != target {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.18
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().setFrame(target, display: true)
                }
            }

            offset += size.height + gap
        }
    }

    /// Default: the display the mouse is on, so the card lands where you're
    /// looking instead of on a monitor you're not watching.
    private func targetScreen() -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        switch settings.screen.lowercased() {
        case "main", "primary":
            return NSScreen.main ?? screens[0]
        default:
            if let index = Int(settings.screen), screens.indices.contains(index) {
                return screens[index]
            }
            let mouse = NSEvent.mouseLocation
            return screens.first { NSMouseInRect(mouse, $0.frame, false) }
                ?? NSScreen.main
                ?? screens[0]
        }
    }
}
