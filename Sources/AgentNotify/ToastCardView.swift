import AppKit

/// The card content: accent strip, "agent · project · time" header, task title,
/// task description, and a hint line. Laid out with explicit frames in a
/// flipped coordinate space so the height is computable before the window exists.
final class ToastCardView: NSView {
    // Layout constants
    private static let accentWidth: CGFloat = 4
    private static let padLeft: CGFloat = 14
    private static let padRight: CGFloat = 14
    private static let padTop: CGFloat = 13
    private static let padBottom: CGFloat = 12
    private static let closeSize: CGFloat = 16
    private static let titleMaxLines = 2
    private static let bodyMaxLines = 6

    private static let headerFont = NSFont.systemFont(ofSize: 11.5, weight: .medium)
    private static let titleFont = NSFont.systemFont(ofSize: 13.5, weight: .semibold)
    private static let bodyFont = NSFont.systemFont(ofSize: 12.5, weight: .regular)
    private static let footerFont = NSFont.systemFont(ofSize: 10.5, weight: .regular)

    let message: AgentMessage
    var onDismiss: (() -> Void)?

    override var isFlipped: Bool { true }

    init(message: AgentMessage, width: CGFloat) {
        self.message = message
        let layout = Self.layout(for: message, width: width)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: layout.totalHeight))
        build(layout: layout, width: width)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Height of the card for a given message. Used to stack cards before they
    /// are instantiated.
    static func height(for message: AgentMessage, width: CGFloat) -> CGFloat {
        layout(for: message, width: width).totalHeight
    }

    // MARK: - Layout model

    private struct Layout {
        var contentWidth: CGFloat
        var headerWidth: CGFloat
        var headerText: String
        var headerHeight: CGFloat
        var titleText: String
        var titleHeight: CGFloat
        var bodyText: String
        var bodyHeight: CGFloat
        var footerText: String
        var footerHeight: CGFloat
        var totalHeight: CGFloat
    }

    private static func layout(for message: AgentMessage, width: CGFloat) -> Layout {
        let contentWidth = width - accentWidth - padLeft - padRight
        let headerWidth = contentWidth - closeSize - 6

        var headerParts = ["\(message.level.glyph)  \(message.displayAgent)"]
        if let project = message.project, !project.isEmpty {
            headerParts.append((project as NSString).lastPathComponent)
        }
        headerParts.append(message.timeString)
        let headerText = clampSingleLine(headerParts.joined(separator: "  ·  "),
                                        font: headerFont, width: headerWidth)

        let titleText = TextKit.clamp(collapse(message.title),
                                      font: titleFont, width: contentWidth, maxLines: titleMaxLines)
        let bodyText = TextKit.clamp(message.body.trimmingCharacters(in: .whitespacesAndNewlines),
                                     font: bodyFont, width: contentWidth, maxLines: bodyMaxLines)
        let footerText = message.level.isSticky
            ? "Esc hides (still unread) · Click card to mark read · Menu bar keeps it"
            : "Esc hides (still unread) · Click card to mark read"

        let headerHeight = TextKit.lineHeight(headerFont)
        let titleHeight = TextKit.height(titleText, font: titleFont, width: contentWidth)
        let bodyHeight = TextKit.height(bodyText, font: bodyFont, width: contentWidth)
        let footerHeight = TextKit.lineHeight(footerFont)

        var total = padTop + headerHeight + 7 + titleHeight
        if bodyHeight > 0 { total += 4 + bodyHeight }
        total += 9 + footerHeight + padBottom

        return Layout(contentWidth: contentWidth,
                      headerWidth: headerWidth,
                      headerText: headerText,
                      headerHeight: headerHeight,
                      titleText: titleText,
                      titleHeight: titleHeight,
                      bodyText: bodyText,
                      bodyHeight: bodyHeight,
                      footerText: footerText,
                      footerHeight: footerHeight,
                      totalHeight: ceil(total))
    }

    private static func collapse(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func clampSingleLine(_ s: String, font: NSFont, width: CGFloat) -> String {
        TextKit.clamp(collapse(s), font: font, width: width, maxLines: 1)
    }

    // MARK: - View building

    private func build(layout: Layout, width: CGFloat) {
        let contentX = Self.accentWidth + Self.padLeft

        let accent = NSView(frame: NSRect(x: 0, y: 0, width: Self.accentWidth, height: layout.totalHeight))
        accent.wantsLayer = true
        accent.layer?.backgroundColor = message.level.accent.cgColor
        accent.autoresizingMask = [.height]
        addSubview(accent)

        var y = Self.padTop

        let header = TextKit.label(layout.headerText, font: Self.headerFont, color: .secondaryLabelColor)
        header.frame = NSRect(x: contentX, y: y, width: layout.headerWidth, height: layout.headerHeight)
        addSubview(header)

        let close = NSButton(title: "", target: self, action: #selector(dismissClicked))
        close.isBordered = false
        close.setButtonType(.momentaryChange)
        close.attributedTitle = NSAttributedString(string: "✕", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ])
        close.frame = NSRect(x: width - Self.padRight - Self.closeSize,
                             y: y - 2,
                             width: Self.closeSize,
                             height: Self.closeSize)
        close.toolTip = "Close"
        addSubview(close)

        y += layout.headerHeight + 7

        let title = TextKit.label(layout.titleText, font: Self.titleFont, color: .labelColor)
        title.frame = NSRect(x: contentX, y: y, width: layout.contentWidth, height: layout.titleHeight)
        addSubview(title)
        y += layout.titleHeight

        if layout.bodyHeight > 0 {
            y += 4
            let body = TextKit.label(layout.bodyText, font: Self.bodyFont, color: .secondaryLabelColor)
            body.frame = NSRect(x: contentX, y: y, width: layout.contentWidth, height: layout.bodyHeight)
            addSubview(body)
            y += layout.bodyHeight
        }

        y += 9
        let footer = TextKit.label(layout.footerText, font: Self.footerFont, color: .tertiaryLabelColor)
        footer.frame = NSRect(x: contentX, y: y, width: layout.contentWidth, height: layout.footerHeight)
        addSubview(footer)
    }

    // MARK: - Interaction

    @objc private func dismissClicked() {
        onDismiss?()
    }

    override func mouseDown(with event: NSEvent) {
        onDismiss?()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
