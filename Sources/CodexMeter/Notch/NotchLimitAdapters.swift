import Foundation

// The bridge: CodexMeter already polls Codex limits (`AccountLimitStore`, via the
// signed app-server RPC) and Claude limits (`ClaudeIntegrationStore`, via the
// status-line helper), both publishing `AccountLimitsSnapshot?`. These adapters
// reflect that published state into the notch's `ProviderSnapshot` shape — they
// add no keychain or network traffic of their own.

// MARK: - Shared mapping

enum NotchLimitMapping {
    /// `AccountLimitWindow` (CodexMeter) → `LimitWindow` (notch).
    static func window(_ w: AccountLimitWindow) -> LimitWindow {
        LimitWindow(
            id: w.limitID,
            label: w.windowLabel,
            usedFraction: max(0, min(1.5, w.usedPercent / 100)),
            resetsAt: w.resetsAt,
            duration: TimeInterval(w.windowDurationMinutes) * 60
        )
    }

    /// The tightest window's id — the one with the least remaining — so the ring
    /// means what actually constrains you. Matches
    /// `MenuBarLimitMeter.remainingFraction`'s "tightest window" choice.
    static func headlineID(_ windows: [AccountLimitWindow]) -> String? {
        windows.max(by: { $0.usedPercent < $1.usedPercent })?.limitID
    }
}

// MARK: - Codex

@MainActor
final class CodexNotchProvider: NotchProvider {
    let id = "codex"
    let displayName = "Codex"
    let glyph: ProviderGlyph = .openai

    private let limits: AccountLimitStore
    private let accounts: CodexAccountStore

    init(limits: AccountLimitStore, accounts: CodexAccountStore = .shared) {
        self.limits = limits
        self.accounts = accounts
    }

    var signInRoute: SignInRoute { .openApp(bundleID: "com.openai.chat", name: "Codex") }

    func account() -> ProviderAccount? {
        guard let current = accounts.accounts.first(where: { $0.id == accounts.currentID }) else {
            return nil
        }
        return ProviderAccount(label: current.email, plan: nil, source: "Codex", manageURL: nil)
    }

    func fetchSnapshot() async throws -> ProviderSnapshot {
        // The underlying store polls on its own; ask it to refresh and read the
        // freshest published value.
        await limits.refresh()

        let windows = (limits.snapshot?.windows ?? []).map(NotchLimitMapping.window)
        let status: ProviderStatus
        switch limits.status {
        case .ready:       status = .ok
        case .stale:       status = .stale(since: limits.snapshot?.fetchedAt ?? Date())
        case .loading:     status = windows.isEmpty ? .stale(since: .distantPast) : .ok
        case .disabled:    status = .needsAuth
        case .unavailable: status = .error(limits.statusMessage)
        }

        return ProviderSnapshot(
            id: id, displayName: displayName, glyph: glyph,
            fidelity: .official, status: status,
            windows: windows,
            headlineID: NotchLimitMapping.headlineID(limits.snapshot?.windows ?? [])
        )
    }
}

// MARK: - Claude

@MainActor
final class ClaudeNotchProvider: NotchProvider {
    let id = "claude"
    let displayName = "Claude Code"
    let glyph: ProviderGlyph = .claude

    private let claude: ClaudeIntegrationStore

    init(claude: ClaudeIntegrationStore) {
        self.claude = claude
    }

    /// No ring at all when the whole Claude integration is switched off.
    var isVisibleWhenAbsent: Bool { claude.isEnabled }

    var signInRoute: SignInRoute {
        .guidance("Enable Claude Code in Settings and add the account signed in to the claude CLI.")
    }

    func account() -> ProviderAccount? {
        guard let account = claude.account else { return nil }
        return ProviderAccount(label: account.email, plan: account.planName,
                               source: "Claude Code", manageURL: nil)
    }

    func fetchSnapshot() async throws -> ProviderSnapshot {
        if claude.isEnabled { await claude.refresh() }

        let windows = (claude.snapshot?.windows ?? []).map(NotchLimitMapping.window)
        let status: ProviderStatus
        switch claude.status {
        case .ready:            status = .ok
        case .stale:            status = .stale(since: claude.snapshot?.fetchedAt ?? Date())
        case .checking:         status = windows.isEmpty ? .stale(since: .distantPast) : .ok
        case .waitingForLimits: status = windows.isEmpty ? .stale(since: .distantPast) : .ok
        case .needsAccount:     status = .needsAuth
        case .disabled:         status = .needsAuth
        case .unavailable:      status = .error(claude.statusMessage)
        }

        return ProviderSnapshot(
            id: id, displayName: displayName, glyph: glyph,
            fidelity: .official, status: status,
            windows: windows,
            headlineID: NotchLimitMapping.headlineID(claude.snapshot?.windows ?? [])
        )
    }
}
