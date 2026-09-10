import AppKit
import XCTest
@testable import CodexMeter

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    private func makeEnvironment() -> SettingsEnvironment {
        SettingsEnvironment(
            limitStore: AccountLimitStore(provider: SettingsTestLimitProvider(), pollingInterval: nil)
        )
    }

    func testSettingsWindowKeepsOneContentControllerAcrossPresentations() {
        _ = NSApplication.shared
        let controller = SettingsWindowController()
        defer { controller.closeSettingsForTesting() }
        controller.configure(environment: makeEnvironment())

        controller.present()
        let first = controller.settingsContentViewForTesting
        controller.present()
        XCTAssertTrue(first === controller.settingsContentViewForTesting)
    }

    func testSettingsWindowTitleHasNoProviderSuffix() {
        _ = NSApplication.shared
        let controller = SettingsWindowController()
        defer { controller.closeSettingsForTesting() }
        controller.configure(environment: makeEnvironment())

        controller.present()
        let window = controller.settingsContentViewForTesting?.window
        window?.layoutIfNeeded()
        let title = window?.title ?? ""
        // The provider-scoped "— Claude Code" suffix is gone; the title is either the
        // default or the selected pane name, never a per-provider window.
        XCTAssertFalse(title.contains("—"))
        XCTAssertFalse(title.contains("Claude Code"))
        XCTAssertTrue(["CodexMeter Settings", "Usage", "General"].contains(title), title)
    }

    func testSettingsWindowBecomesVisibleAndCanReopen() {
        _ = NSApplication.shared
        let controller = SettingsWindowController()
        defer { controller.closeSettingsForTesting() }
        controller.configure(environment: makeEnvironment())

        controller.present()
        XCTAssertTrue(controller.isSettingsWindowVisible)
        XCTAssertTrue(controller.settingsWindowIsResizableForTesting)
        // A real window, not a per-provider sliver.
        XCTAssertGreaterThanOrEqual(controller.settingsWindowContentSizeForTesting?.width ?? 0, 840)
        XCTAssertGreaterThanOrEqual(controller.settingsWindowContentSizeForTesting?.height ?? 0, 560)
        let firstContentController = controller.settingsContentViewForTesting

        controller.closeSettingsForTesting()
        XCTAssertFalse(controller.isSettingsWindowVisible)

        controller.present()
        XCTAssertTrue(controller.isSettingsWindowVisible)
        XCTAssertTrue(firstContentController === controller.settingsContentViewForTesting)
    }
}

private struct SettingsTestLimitProvider: AccountLimitProviding {
    func readLimits() async throws -> AccountLimitsSnapshot {
        throw AccountLimitError.trustedAppServerNotFound
    }
}
