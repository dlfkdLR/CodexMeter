import XCTest
@testable import CodexMeter

/// Parses `GET /api/usage`, covering modern (Pro 20/60/100/500) and legacy
/// plan shapes.
final class NotchOllamaUsageTests: XCTestCase {
    private let modernResponse = """
    {
      "activity": { "cost": "0.00000",
        "period": { "type": "last_4_weeks",
          "starting_at": "2026-08-17T00:00:00Z",
          "ending_at": "2026-09-08T08:28:05.581584229Z" }, "models": [] },
      "limits": { "monthly": { "usage": 0.152, "models": [
        { "name": "glm-5.3", "request_count": 468 },
        { "name": "glm-5.3-flash", "request_count": 1176 },
        { "name": "deepseek-v4-flash:0731", "request_count": 3415 } ] } }
    }
    """

    private let legacyResponse = """
    {
      "limits": {
        "session": { "usage": 0.12, "models": [{ "name": "gpt-oss:120b", "request_count": 7 }] },
        "weekly":  { "usage": 0.41, "models": [{ "name": "gpt-oss:120b", "request_count": 86 }] }
      },
      "activity": { "cost": "0.10", "period": { "type": "last_4_weeks" } }
    }
    """

    func testModernHeadlineIsMonthlyUsageFraction() throws {
        let result = try OllamaUsage.parse(modernResponse)
        XCTAssertEqual(result.headlineID, "monthly")
        XCTAssertEqual(result.windows.first { $0.id == "monthly" }?.usedFraction, 0.152)
    }

    func testModernPerModelRows() throws {
        let result = try OllamaUsage.parse(modernResponse)
        let modelRows = result.windows.filter { $0.id.hasPrefix("monthly.") }
        XCTAssertEqual(modelRows.count, 3)
        XCTAssertEqual(modelRows.first?.label, "glm-5.3")
        XCTAssertEqual(modelRows.first?.used, 468)
        XCTAssertNil(modelRows.first?.usedFraction)
    }

    func testModernHasNoResetDateBecauseApiDoesNotExposeBillingCycle() throws {
        let result = try OllamaUsage.parse(modernResponse)
        XCTAssertNil(result.windows.first { $0.id == "monthly" }?.resetsAt)
    }

    func testLegacyHasSessionAndWeeklyWindows() throws {
        let result = try OllamaUsage.parse(legacyResponse)
        XCTAssertNotNil(result.windows.first { $0.id == "session" })
        XCTAssertNotNil(result.windows.first { $0.id == "weekly" })
        XCTAssertNil(result.windows.first { $0.id == "monthly" })
    }

    func testLegacyHeadlineIsWeekly() throws {
        XCTAssertEqual(try OllamaUsage.parse(legacyResponse).headlineID, "weekly")
    }

    func testLegacyModelRows() throws {
        let result = try OllamaUsage.parse(legacyResponse)
        XCTAssertEqual(result.windows.first { $0.id == "session.gpt-oss:120b" }?.used, 7)
        XCTAssertEqual(result.windows.first { $0.id == "weekly.gpt-oss:120b" }?.used, 86)
    }

    func testEmptyUsageThrowsNothingMetered() {
        let empty = """
        { "activity": { "cost": "0.00", "period": {}, "models": [] },
          "limits": { "monthly": { "usage": 0, "models": [] } } }
        """
        XCTAssertThrowsError(try OllamaUsage.parse(empty)) { error in
            guard case NotchProviderError.nothingMetered = error else {
                return XCTFail("expected nothingMetered, got \(error)")
            }
        }
    }

    func testModelsOnlyWithZeroUsage() throws {
        let noFraction = """
        { "activity": { "period": { "ending_at": "2026-09-08T08:28:05Z" } },
          "limits": { "monthly": { "usage": 0,
            "models": [ { "name": "tiny", "request_count": 3 } ] } } }
        """
        let result = try OllamaUsage.parse(noFraction)
        XCTAssertNil(result.headlineID)
        XCTAssertEqual(result.windows.count, 1)
        XCTAssertEqual(result.windows.first?.label, "tiny")
        XCTAssertEqual(result.windows.first?.used, 3)
    }

    func testGarbageThrowsBadResponse() {
        XCTAssertThrowsError(try OllamaUsage.parse("not json")) { error in
            guard case NotchProviderError.badResponse = error else {
                return XCTFail("expected badResponse, got \(error)")
            }
        }
    }
}

@MainActor
final class NotchOllamaProviderTests: XCTestCase {
    func testStaysHiddenWithoutAKey() async {
        let provider = OllamaNotchProvider(key: { nil })
        XCTAssertFalse(provider.isVisibleWhenAbsent)
        XCTAssertNil(provider.account())
        do {
            _ = try await provider.fetchSnapshot()
            XCTFail("expected needsAuth")
        } catch NotchProviderError.needsAuth {
        } catch {
            XCTFail("expected needsAuth, got \(error)")
        }
    }

    func testAccountAppearsOnceAKeyIsPresent() {
        let provider = OllamaNotchProvider(key: { "sk-ollama" })
        XCTAssertEqual(provider.account()?.source, "Ollama")
    }
}

final class NotchKeychainTests: XCTestCase {
    private let service = "dev.codexmeter.test-\(UUID().uuidString)"
    private let account = "codexmeter"

    /// Opt-in, like `CodexAccountSwitchingTests`' keychain round-trip: a test
    /// must never prompt for or touch a real login keychain on CI or another
    /// developer's machine. Uses a unique synthetic service that is deleted
    /// afterwards.
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CODEXMETER_NOTCH_KEYCHAIN_INTEGRATION"] == "1",
                          "Set CODEXMETER_NOTCH_KEYCHAIN_INTEGRATION=1 to exercise a synthetic Keychain item.")
    }

    override func tearDown() {
        NotchKeychain.delete(service: service, account: account)
        super.tearDown()
    }

    func testStoreReadDelete() {
        XCTAssertNil(NotchKeychain.read(service: service, account: account))

        XCTAssertTrue(NotchKeychain.store("ollama_secret", service: service, account: account))
        XCTAssertEqual(NotchKeychain.read(service: service, account: account), "ollama_secret")

        // Replace in place.
        XCTAssertTrue(NotchKeychain.store("ollama_rotated", service: service, account: account))
        XCTAssertEqual(NotchKeychain.read(service: service, account: account), "ollama_rotated")

        XCTAssertTrue(NotchKeychain.delete(service: service, account: account))
        XCTAssertNil(NotchKeychain.read(service: service, account: account))
        XCTAssertTrue(NotchKeychain.delete(service: service, account: account), "deleting nothing is not an error")
    }

    func testOllamaCredentialsRoundTripsThroughTheStore() {
        defer { OllamaCredentials.delete() }
        // Guard: only meaningful without the env var set.
        try? XCTSkipIf(ProcessInfo.processInfo.environment["OLLAMA_API_KEY"] != nil)

        XCTAssertFalse(OllamaCredentials.hasStoredKey)
        XCTAssertTrue(OllamaCredentials.store("  ollama_pasted  "))
        XCTAssertEqual(OllamaCredentials.load(), "ollama_pasted", "trimmed on the way in")
        XCTAssertTrue(OllamaCredentials.hasStoredKey)

        OllamaCredentials.delete()
        XCTAssertNil(OllamaCredentials.load())
    }
}
