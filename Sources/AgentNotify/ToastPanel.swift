import AppKit

/// Borderless floating panel that hosts one card.
///
/// `.nonactivatingPanel` keeps the popup from yanking your app out of the
/// foreground, and `.canJoinAllSpaces` means it shows up on whichever Space
/// you're on when the agent finishes.
final class ToastPanel: NSPanel {
    var onEscape: (() -> Void)?

    init(card: ToastCardView, width: CGFloat, height: CGFloat, alwaysOnTop: Bool) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isFloatingPanel = true
        // `.statusBar` (25) clears the Dock (20) and every normal window, so an
        // editor in the bottom-right corner can't bury the card.
        level = alwaysOnTop ? .statusBar : .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let backdrop = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        backdrop.material = .hudWindow
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = 14
        backdrop.layer?.cornerCurve = .continuous
        backdrop.layer?.masksToBounds = true
        backdrop.layer?.borderWidth = 1
        backdrop.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor

        card.autoresizingMask = [.width, .height]
        backdrop.addSubview(card)
        contentView = backdrop
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // esc
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }
}
