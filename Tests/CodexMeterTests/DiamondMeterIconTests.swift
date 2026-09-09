import AppKit
import XCTest
@testable import CodexMeter

final class DiamondMeterIconTests: XCTestCase {
    func testRemainingFractionUsesTheTightestWindow() {
        let fiveHour = window(minutes: 300, usedPercent: 80)   // 20% left
        let weekly = window(minutes: 10_080, usedPercent: 30)  // 70% left
        XCTAssertEqual(MenuBarLimitMeter.remainingFraction(windows: [weekly, fiveHour]) ?? -1, 0.2, accuracy: 0.0001)
    }

    func testRemainingFractionIsNilWithoutWindows() {
        XCTAssertNil(MenuBarLimitMeter.remainingFraction(windows: nil))
        XCTAssertNil(MenuBarLimitMeter.remainingFraction(windows: []))
    }

    func testRemainingFractionClampsOutOfRangeUsage() {
        XCTAssertEqual(MenuBarLimitMeter.remainingFraction(windows: [window(minutes: 300, usedPercent: 130)]) ?? -1,
                       0, accuracy: 0.0001)
        XCTAssertEqual(MenuBarLimitMeter.remainingFraction(windows: [window(minutes: 300, usedPercent: -10)]) ?? -1,
                       1, accuracy: 0.0001)
    }

    func testIconIsATemplateImageAtTheExpectedSize() {
        let image = DiamondMeterIcon.image(remainingFraction: 0.5)
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.size.width, 15, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 15, accuracy: 0.5)
    }

    func testCaptureSwatchesWhenRequested() throws {
        guard let dir = ProcessInfo.processInfo.environment["CODEXMETER_LAYOUT_CAPTURE_DIR"] else {
            throw XCTSkip("Set CODEXMETER_LAYOUT_CAPTURE_DIR to write diamond swatches.")
        }
        for fraction: Double? in [nil, 0, 0.15, 0.4, 0.75, 1] {
            let image = DiamondMeterIcon.image(remainingFraction: fraction)
            let scale: CGFloat = 16
            let rep = try XCTUnwrap(NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(image.size.width * scale),
                pixelsHigh: Int(image.size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            ))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh).fill()
            NSColor.black.set()
            image.draw(in: NSRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh))
            NSGraphicsContext.restoreGraphicsState()
            let name = fraction.map { "diamond-\(Int($0 * 100)).png" } ?? "diamond-outline.png"
            try rep.representation(using: .png, properties: [:])?
                .write(to: URL(fileURLWithPath: dir).appendingPathComponent(name))
        }
    }

    func testFillLevelChangesTheRenderedPixels() throws {
        let empty = try alphaCoverage(of: DiamondMeterIcon.image(remainingFraction: 0))
        let half = try alphaCoverage(of: DiamondMeterIcon.image(remainingFraction: 0.5))
        let full = try alphaCoverage(of: DiamondMeterIcon.image(remainingFraction: 1))
        let outline = try alphaCoverage(of: DiamondMeterIcon.image(remainingFraction: nil))

        XCTAssertGreaterThan(half, empty, "A half-full diamond covers more than an empty one.")
        XCTAssertGreaterThan(full, half, "A full diamond covers more than a half-full one.")
        XCTAssertEqual(outline, empty, accuracy: 0.02, "nil and 0 both draw only the outline.")
    }

    // MARK: - Helpers

    private func window(minutes: Int, usedPercent: Double) -> AccountLimitWindow {
        AccountLimitWindow(id: "\(minutes)", limitID: "codex", displayName: "Codex",
                           windowDurationMinutes: minutes, usedPercent: usedPercent, resetsAt: nil)
    }

    /// Fraction of pixels with any ink, so a fuller diamond scores higher.
    private func alphaCoverage(of image: NSImage) throws -> Double {
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 30, pixelsHigh: 30,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: 30, height: 30))
        NSGraphicsContext.restoreGraphicsState()

        var inked = 0
        for x in 0..<30 {
            for y in 0..<30 where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                inked += 1
            }
        }
        return Double(inked) / 900
    }
}
