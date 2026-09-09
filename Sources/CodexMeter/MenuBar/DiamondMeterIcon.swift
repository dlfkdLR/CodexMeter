import AppKit

/// The menu bar's diamond mark, drawn as a template image whose interior fills
/// from the bottom to show how much of the tightest account limit is still
/// available. A `nil` fraction draws the outline only (limits off or unknown).
enum DiamondMeterIcon {
    private static let side: CGFloat = 15
    private static let lineWidth: CGFloat = 1.3

    static func image(remainingFraction: Double?) -> NSImage {
        let size = NSSize(width: side, height: side)
        let image = NSImage(size: size, flipped: false) { _ in
            let bounds = NSRect(origin: .zero, size: size)
            let inset = bounds.insetBy(dx: lineWidth, dy: lineWidth)

            let diamond = NSBezierPath()
            diamond.move(to: NSPoint(x: inset.midX, y: inset.maxY))
            diamond.line(to: NSPoint(x: inset.maxX, y: inset.midY))
            diamond.line(to: NSPoint(x: inset.midX, y: inset.minY))
            diamond.line(to: NSPoint(x: inset.minX, y: inset.midY))
            diamond.close()

            if let remainingFraction {
                let clamped = min(1, max(0, remainingFraction))
                NSGraphicsContext.saveGraphicsState()
                diamond.setClip()
                // Template images ignore the fill color and keep the alpha, so
                // AppKit tints the result for the current menu bar appearance.
                NSColor.black.setFill()
                NSRect(x: inset.minX,
                       y: inset.minY,
                       width: inset.width,
                       height: inset.height * clamped).fill()
                NSGraphicsContext.restoreGraphicsState()
            }

            diamond.lineWidth = lineWidth
            NSColor.black.setStroke()
            diamond.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}

enum MenuBarLimitMeter {
    /// Fraction (0...1) of the tightest limit window still available, or `nil`
    /// when no window is usable — the diamond then shows only its outline.
    static func remainingFraction(windows: [AccountLimitWindow]?) -> Double? {
        guard let windows, !windows.isEmpty else { return nil }
        let tightest = windows.map(\.remainingPercent).min() ?? 100
        return min(1, max(0, tightest / 100))
    }
}
