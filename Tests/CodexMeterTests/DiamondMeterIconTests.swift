import AppKit
import SwiftUI
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

    @MainActor
    func testFillLevelChangesTheRenderedPixels() throws {
        let empty = try coverage(of: DiamondLimitMeter(remaining: 0))
        let half = try coverage(of: DiamondLimitMeter(remaining: 0.5))
        let full = try coverage(of: DiamondLimitMeter(remaining: 1))
        let outline = try coverage(of: DiamondLimitMeter(remaining: nil))

        XCTAssertGreaterThan(half, empty, "A half-full diamond covers more than an empty one.")
        XCTAssertGreaterThan(full, half, "A full diamond covers more than a half-full one.")
        XCTAssertEqual(outline, empty, accuracy: 0.03, "nil and 0 both draw only the outline.")
    }

    @MainActor
    func testCaptureSwatchesWhenRequested() throws {
        guard let dir = ProcessInfo.processInfo.environment["CODEXMETER_LAYOUT_CAPTURE_DIR"] else {
            throw XCTSkip("Set CODEXMETER_LAYOUT_CAPTURE_DIR to write diamond swatches.")
        }
        for fraction: Double? in [nil, 0, 0.15, 0.4, 0.75, 1] {
            let renderer = ImageRenderer(content:
                DiamondLimitMeter(remaining: fraction)
                    .foregroundStyle(.black)
                    .scaleEffect(10)
                    .frame(width: 150, height: 150)
                    .background(Color.white)
            )
            renderer.scale = 2
            let name = fraction.map { "diamond-\(Int($0 * 100)).png" } ?? "diamond-outline.png"
            let url = URL(fileURLWithPath: dir).appendingPathComponent(name)
            let rep = try XCTUnwrap(renderer.nsImage?.tiffRepresentation.flatMap(NSBitmapImageRep.init))
            try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: url)
        }
    }

    // MARK: - Helpers

    private func window(minutes: Int, usedPercent: Double) -> AccountLimitWindow {
        AccountLimitWindow(id: "\(minutes)", limitID: "codex", displayName: "Codex",
                           windowDurationMinutes: minutes, usedPercent: usedPercent, resetsAt: nil)
    }

    /// Fraction of pixels with any ink, so a fuller diamond scores higher.
    @MainActor
    private func coverage<V: View>(of view: V) throws -> Double {
        let renderer = ImageRenderer(content: view.foregroundStyle(.black).frame(width: 40, height: 40))
        renderer.scale = 1
        let cg = try XCTUnwrap(renderer.cgImage)
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let ctx = try XCTUnwrap(CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        var inked = 0
        for i in stride(from: 3, to: pixels.count, by: 4) where pixels[i] > 12 { inked += 1 }
        return Double(inked) / Double(width * height)
    }
}
