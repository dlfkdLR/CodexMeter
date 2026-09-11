import AppKit
import SwiftUI
import XCTest
@testable import CodexMeter

@MainActor
final class NotchControlsTests: XCTestCase {
    func testAccountButtonFollowsSettingsAndFitsEveryEdgeAndSize() {
        let model = NotchViewModel()
        model.screenSize = CGSize(width: 1440, height: 900)
        model.snapshots = [ProviderSnapshot(id: "codex", displayName: "Codex", glyph: .openai,
            fidelity: .official, status: .ok, windows: [LimitWindow(id: "weekly", label: "Weekly", usedFraction: 0.59)])]
        for edge in NotchEdge.allCases {
            for size in NotchSize.allCases {
                model.edge = edge
                model.sizeScale = size.scale
                let panel = CGRect(origin: .zero, size: model.panelSize)
                XCTAssertTrue(panel.contains(model.accountOrbRect), "\(edge) \(size): \(model.accountOrbRect) exceeds \(panel)")
                XCTAssertGreaterThan(model.accountOrbAlong - NotchLayout.orbHotZone / 2,
                                     model.orbAlong + NotchLayout.orbHotZone / 2)
                XCTAssertGreaterThanOrEqual(model.trailingExtent,
                    model.accountOrbAlong + NotchLayout.orbHotZone / 2 - model.shapeLength)
            }
        }
    }

    func testAccountMenuHoldsHoverNotchOpenWithoutChangingThePin() {
        let model = NotchViewModel()
        model.isPresentingAccountMenu = true
        XCTAssertTrue(model.staysOpen)
        XCTAssertFalse(model.isPinned)
        model.isPresentingAccountMenu = false
        XCTAssertFalse(model.staysOpen)
    }

    func testSettingsAndAccountActionsReachTheSwiftUIControls() {
        let controller = NotchWindowController()
        var settingsOpens = 0
        var accountID: String?
        controller.onOpenSettings = { settingsOpens += 1 }
        controller.onSwitchAccount = { accountID = $0 }
        controller.model.onOpenSettings?()
        controller.model.onSwitchAccount?("codex")
        XCTAssertEqual(settingsOpens, 1)
        XCTAssertEqual(accountID, "codex")
        controller.onOpenSettings = nil
        XCTAssertNil(controller.model.onOpenSettings)
    }

    func testProviderSelectionMigratesExistingProvidersAndPersistsAnEmptyList() throws {
        let suite = "CodexMeter.ProviderSelection.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(NotchProviderSelection.load(defaults: defaults, existing: ["codex", "claude", "copilot", "ollama-local", "unknown"]),
                       ["codex", "claude", "copilot", "ollama-local"])
        XCTAssertEqual(NotchProviderSelection.load(defaults: defaults, existing: []),
                       ["codex", "claude", "copilot", "ollama-local"])
        NotchProviderSelection.save(["claude"], defaults: defaults)
        XCTAssertEqual(NotchProviderSelection.load(defaults: defaults, existing: ["codex", "copilot"]), ["claude"])
        NotchProviderSelection.save([], defaults: defaults)
        XCTAssertTrue(NotchProviderSelection.load(defaults: defaults, existing: ["codex", "claude"]).isEmpty)
    }

    func testTooltipBudgetContainsItsActualContentIncludingTodayPlanAndActions() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        for grouped in [false, true] {
            for sessionCount in [0, 1, 7] {
                for hasToday in [false, true] {
                    let windows = (0..<3).map { index in
                        LimitWindow(id: "window-\(index)", group: grouped ? (index < 2 ? "Codex" : "GPT-5.3-Codex-Spark") : nil,
                            label: index == 0 ? "Weekly" : "5 hours", usedFraction: 0.5,
                            resetsAt: now.addingTimeInterval(86_400), duration: 604_800)
                    }
                    let snapshot = ProviderSnapshot(id: "codex", displayName: "Codex", glyph: .openai,
                        fidelity: .official, status: .ok, windows: windows,
                        todaysTokens: hasToday ? 12_556_351 : nil, accountPlan: "Pro 20x")
                    let sessions = (0..<sessionCount).map { index in
                        AgentSession(id: "session-\(index)", name: "Workspace with a long name \(index)",
                            detail: "Terminal · CodexMeter", state: .busy, waitingFor: nil, since: now)
                    }
                    let activity = sessionCount == 0 ? nil : ActivitySummary(sessions: sessions)
                    let card = TooltipCard(snapshot: snapshot, activity: activity, now: now,
                                           sessionCap: 4, onSwitchAccount: {})
                    let natural = ImageRenderer(content: card.cardContent.frame(width: NotchLayout.cardTextWidth))
                    let naturalImage = try XCTUnwrap(natural.nsImage)
                    let budget = NotchLayout.cardHeight(for: snapshot, sessionCount: sessionCount,
                        sessionCap: 4, now: now, showsAccountAction: true)
                    XCTAssertLessThanOrEqual(naturalImage.size.height + 2 * NotchLayout.cardPadding, budget + 1,
                        "grouped=\(grouped), sessions=\(sessionCount), today=\(hasToday): natural content extends under the mask")
                    if hasToday, let directory = ProcessInfo.processInfo.environment["CODEXMETER_NOTCH_CAPTURE_DIR"] {
                        let url = URL(fileURLWithPath: directory, isDirectory: true)
                        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                        let renderer = ImageRenderer(content: card.padding(16).background(Color.gray))
                        renderer.scale = 3
                        let image = try XCTUnwrap(renderer.nsImage)
                        let tiff = try XCTUnwrap(image.tiffRepresentation)
                        let png = try XCTUnwrap(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
                        try png.write(to: url.appendingPathComponent("tooltip-\(grouped ? "grouped" : "plain")-sessions\(sessionCount).png"))
                    }
                }
            }
        }
    }
}
