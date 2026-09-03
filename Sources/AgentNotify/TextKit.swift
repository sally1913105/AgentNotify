import AppKit

/// Deterministic text measuring so cards can be laid out with plain frames
/// instead of auto layout. Long bodies are truncated to a line budget up front,
/// which keeps every card a predictable size.
enum TextKit {
    static func lineHeight(_ font: NSFont) -> CGFloat {
        ceil(NSLayoutManager().defaultLineHeight(for: font))
    }

    static func height(_ text: String, font: NSFont, width: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font])
        return ceil(rect.height)
    }

    /// Trim `text` until it fits `maxLines`, appending an ellipsis when cut.
    static func clamp(_ text: String, font: NSFont, width: CGFloat, maxLines: Int) -> String {
        let budget = lineHeight(font) * CGFloat(maxLines) + 1
        guard height(text, font: font, width: width) > budget else { return text }

        let chars = Array(text)
        var lo = 0
        var hi = chars.count
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            let candidate = String(chars[0..<mid]) + "…"
            if height(candidate, font: font, width: width) <= budget {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        let cut = String(chars[0..<lo]).trimmingCharacters(in: .whitespacesAndNewlines)
        return cut.isEmpty ? "…" : cut + "…"
    }

    static func label(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font
        field.textColor = color
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.isSelectable = false
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        return field
    }
}
