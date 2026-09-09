import SwiftUI

/// The menu bar's diamond mark. Its interior fills from the bottom to show how
/// much of the tightest account-limit window is still available, and eases
/// toward a new level rather than snapping. `nil` draws the outline only.
struct DiamondLimitMeter: View {
    var remaining: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let side: CGFloat = 12.5
    private static let lineWidth: CGFloat = 1.3

    private var fraction: Double { remaining.map { min(1, max(0, $0)) } ?? 0 }

    var body: some View {
        ZStack {
            DiamondEdge()
                .strokeBorder(.primary, lineWidth: Self.lineWidth)
            if remaining != nil {
                DiamondBottomFill(fraction: fraction)
                    .fill(.primary)
            }
        }
        .frame(width: Self.side, height: Self.side)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.55), value: fraction)
        .accessibilityHidden(true)
    }
}

private struct DiamondEdge: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        path.move(to: CGPoint(x: r.midX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        path.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.midY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> DiamondEdge {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

/// The diamond, clipped to a bottom band whose height is `fraction` of the
/// bounds. `animatableData` drives a smooth fill change.
private struct DiamondBottomFill: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let f = min(1, max(0, fraction))
        guard f > 0 else { return Path() }

        var diamond = Path()
        diamond.move(to: CGPoint(x: rect.midX, y: rect.minY))
        diamond.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        diamond.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        diamond.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        diamond.closeSubpath()

        let bandHeight = rect.height * f
        let band = CGRect(x: rect.minX, y: rect.maxY - bandHeight, width: rect.width, height: bandHeight)
        return diamond.intersection(Path(band))
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
