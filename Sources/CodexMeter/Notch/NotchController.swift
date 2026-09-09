import AppKit
import Combine

/// Owns the edge notch: one `NotchWindowController`, a `NotchUsageStore` fed by
/// the Codex and Claude adapters, and the wiring between them. Modelled on
/// `SettingsWindowController` — a `@MainActor` singleton created from the app's
/// `init`, shown or hidden from a preference.
///
/// Phase 1: single screen, hover-to-expand, no session activity, no multi-monitor.
@MainActor
final class NotchController {
    static let shared = NotchController()

    private let window = NotchWindowController()
    private var store: NotchUsageStore?
    private var cancellables = Set<AnyCancellable>()
    private var configured = false
    private var visible = false

    private let offsetKey = "notchAlongOffset"

    private init() {}

    /// Called once from `CodexMeterApp.init`, after the stores exist.
    func configure(codexLimits: AccountLimitStore,
                   claudeIntegration: ClaudeIntegrationStore,
                   codexAccounts: CodexAccountStore) {
        guard !configured else { return }
        configured = true

        let providers: [any NotchProvider] = [
            CodexNotchProvider(limits: codexLimits, accounts: codexAccounts),
            ClaudeNotchProvider(claude: claudeIntegration),
        ]
        let store = NotchUsageStore(providers: providers)
        self.store = store

        window.onRefresh = { [weak store] in store?.refreshNow() }
        window.onRefreshProvider = { [weak store] id in store?.refresh(providerID: id) }
        window.onOpenSettings = { SettingsWindowController.shared.present() }
        window.onReposition = { [offsetKey] offset in
            UserDefaults.standard.set(Double(offset), forKey: offsetKey)
        }

        // The notch mirrors the notch store, which mirrors the two underlying
        // limit stores. Re-run the adapters whenever either underlying store
        // publishes, so the rings never lag the popover.
        codexLimits.objectWillChange
            .merge(with: claudeIntegration.objectWillChange)
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak store] in store?.refreshNow() }
            .store(in: &cancellables)

        store.$snapshots
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshots in
                guard let self else { return }
                self.window.model.snapshots = snapshots
                self.window.model.now = Date()
                self.window.relocate(cellCount: snapshots.count)
            }
            .store(in: &cancellables)

        if let saved = UserDefaults.standard.object(forKey: offsetKey) as? Double {
            window.model.alongOffset = CGFloat(saved)
        }
    }

    /// Bound to `@AppStorage("showEdgeNotch")`.
    func setVisible(_ on: Bool) {
        guard configured, on != visible else { return }
        visible = on
        if on {
            window.model.edge = storedEdge()
            window.show()
            window.apply(.onHover)
            store?.start()
        } else {
            store?.stop()
            window.apply(.hidden)
        }
    }

    /// Bound to `@AppStorage("notchEdge")`.
    func apply(edge: NotchEdge) {
        guard configured else { return }
        window.apply(edge: edge)
    }

    private func storedEdge() -> NotchEdge {
        NotchEdge(rawValue: UserDefaults.standard.string(forKey: "notchEdge") ?? "")
            ?? NotchEdge(rawValue: AppPreferences.defaultNotchEdge) ?? .right
    }
}
