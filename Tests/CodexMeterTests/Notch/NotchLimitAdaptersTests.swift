import Foundation
import XCTest
@testable import CodexMeter

@MainActor
final class NotchLimitAdaptersTests: XCTestCase {

    // MARK: - Pure mapping

    func testWindowMapsPercentToFractionAndLabel() {
        let mapped = NotchLimitMapping.window(win(id: "codex", minutes: 300, usedPercent: 73))
        XCTAssertEqual(mapped.id, "codex")
        XCTAssertEqual(mapped.label, "5 hours")
        XCTAssertEqual(mapped.usedFraction ?? -1, 0.73, accuracy: 0.0001)
        XCTAssertEqual(mapped.duration ?? -1, 300 * 60, accuracy: 0.5)
    }

    func testWindowFractionClampsAtZeroAndAllowsSlightOverspend() {
        XCTAssertEqual(NotchLimitMapping.window(win(id: "a", minutes: 300, usedPercent: -5)).usedFraction ?? -1,
                       0, accuracy: 0.0001)
        XCTAssertEqual(NotchLimitMapping.window(win(id: "b", minutes: 300, usedPercent: 210)).usedFraction ?? -1,
                       1.5, accuracy: 0.0001)
    }

    func testHeadlineIsTheTightestWindow() {
        let windows = [win(id: "five", minutes: 300, usedPercent: 20),
                       win(id: "weekly", minutes: 10_080, usedPercent: 80)]
        XCTAssertEqual(NotchLimitMapping.headlineID(windows), "weekly")
    }

    func testHeadlineIsNilWithoutWindows() {
        XCTAssertNil(NotchLimitMapping.headlineID([]))
    }

    /// The tooltip's "Today" line — CodexMeter's local token count, which the
    /// ring's percentage never gives. Nil for no store and for a zero total.
    func testTodaysTokensReflectsLocalAccounting() {
        XCTAssertNil(NotchLimitMapping.todaysTokens(nil))
        XCTAssertNil(NotchLimitMapping.todaysTokens(UsageStore(automaticallyRefresh: false)),
                     "a fresh store has spent nothing")

        var snapshot = UsageSnapshot.empty
        snapshot.today = TokenUsage(inputTokens: 1000, cachedInputTokens: 100, outputTokens: 350)
        let store = UsageStore(initialSnapshot: snapshot, automaticallyRefresh: false)
        XCTAssertEqual(NotchLimitMapping.todaysTokens(store), 1350)
    }

    // MARK: - Codex adapter over a stub store

    func testCodexAdapterMapsAReadySnapshot() async throws {
        let defaults = try makeDefaults()
        defaults.set(true, forKey: "accountLimitsEnabled")
        let snapshot = AccountLimitsSnapshot(
            windows: [win(id: "primary", minutes: 300, usedPercent: 40),
                      win(id: "secondary", minutes: 10_080, usedPercent: 12)],
            resetCredits: nil,
            fetchedAt: Date(timeIntervalSince1970: 1)
        )
        let store = AccountLimitStore(provider: OneShotLimitProvider(snapshot),
                                      defaults: defaults, pollingInterval: nil)
        await store.refresh()

        let provider = CodexNotchProvider(limits: store, accounts: CodexAccountStore(vault: EmptyVault()))
        let ps = try await provider.fetchSnapshot()

        XCTAssertEqual(ps.id, "codex")
        XCTAssertEqual(ps.windows.count, 2)
        XCTAssertEqual(ps.headlineID, "primary")
        XCTAssertEqual(ps.headline?.usedFraction ?? -1, 0.40, accuracy: 0.0001)
        XCTAssertEqual(ps.status, .ok)
    }

    func testCodexAdapterReportsNeedsAuthWhenLimitsDisabled() async throws {
        let defaults = try makeDefaults()
        defaults.set(false, forKey: "accountLimitsEnabled")
        let store = AccountLimitStore(provider: OneShotLimitProvider(nil),
                                      defaults: defaults, pollingInterval: nil)
        let provider = CodexNotchProvider(limits: store, accounts: CodexAccountStore(vault: EmptyVault()))
        let ps = try await provider.fetchSnapshot()
        XCTAssertTrue(ps.windows.isEmpty)
        XCTAssertEqual(ps.status, .needsAuth)
        XCTAssertFalse(ps.hasReading)
    }

    // MARK: - Helpers

    private func win(id: String, minutes: Int, usedPercent: Double) -> AccountLimitWindow {
        AccountLimitWindow(id: id, limitID: id, displayName: id,
                           windowDurationMinutes: minutes, usedPercent: usedPercent, resetsAt: nil)
    }

    private func makeDefaults() throws -> UserDefaults {
        let name = "NotchLimitAdaptersTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

private struct OneShotLimitProvider: AccountLimitProviding {
    let snapshot: AccountLimitsSnapshot?
    init(_ snapshot: AccountLimitsSnapshot?) { self.snapshot = snapshot }
    func readLimits() async throws -> AccountLimitsSnapshot {
        guard let snapshot else { throw AccountLimitError.malformedResponse }
        return snapshot
    }
}

private struct EmptyVault: AccountVault {
    func load() throws -> [SavedCodexAccount] { [] }
    func save(_ accounts: [SavedCodexAccount]) throws {}
}
