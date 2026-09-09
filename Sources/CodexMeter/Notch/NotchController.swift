import AppKit
import Combine

/// Owns the edge notch: one `NotchWindowController`, a `NotchUsageStore` fed by
/// the Codex and Claude adapters, the session monitors that light the activity
/// arcs, and the wiring between them. Modelled on `SettingsWindowController` —
/// a `@MainActor` singleton created from the app's `init`, shown or hidden from
/// a preference.
///
/// Phase 1–2: single screen, hover-to-expand, live session activity + a peek
/// and a chime when an agent finishes. Multi-monitor and the full notch
/// settings pane come later.
@MainActor
final class NotchController {
    static let shared = NotchController()

    private let window = NotchWindowController()
    private var store: NotchUsageStore?
    private var monitors: [String: any AgentActivityMonitor] = [:]
    private var completions = SessionCompletionWatcher()
    private let thresholds = ThresholdNotifier(
        isMuted: { id in
            let defaults = UserDefaults.standard
            let enabled = defaults.object(forKey: "notchThresholdAlerts") as? Bool
                ?? AppPreferences.defaultNotchThresholdAlerts
            return !enabled || AppPreferences.isAlertMuted(id)
        },
        deliver: { ThresholdAlerts.deliver($0) }
    )
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
                self.thresholds.observe(snapshots)
            }
            .store(in: &cancellables)

        // Live agent activity — one monitor per provider ring. Built once and
        // started/stopped with the notch's visibility.
        let claudeHome = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude")
        monitors = [
            "claude": ClaudeSessionMonitor(
                directory: claudeHome.appendingPathComponent("sessions"),
                projects: claudeHome.appendingPathComponent("projects")
            ),
            "codex": CodexActivityMonitor(),
        ]
        for (id, monitor) in monitors {
            monitor.sessionsPublisher
                .receive(on: RunLoop.main)
                .sink { [weak self] live in
                    guard let self else { return }
                    self.window.model.sessions[id] = live
                    self.window.model.now = Date()
                    self.announceCompletions()
                }
                .store(in: &cancellables)
        }
        store.isBusy = { [weak self] in
            self?.monitors.values.contains { m in m.sessions.contains { $0.state == .busy } } ?? false
        }

        if let saved = UserDefaults.standard.object(forKey: offsetKey) as? Double {
            window.model.alongOffset = CGFloat(saved)
        }
        // Appearance that lives on the model rather than the panel is safe to
        // set now, before the panel exists.
        window.model.accentColor = storedAccent()
        window.model.resetTimeFormat = storedResetTimeFormat()
    }

    /// Bound to `@AppStorage("showEdgeNotch")`.
    func setVisible(_ on: Bool) {
        guard configured, on != visible else { return }
        visible = on
        if on {
            window.model.edge = storedEdge()
            window.show()
            window.apply(size: storedSize())
            window.apply(storedVisibility())
            store?.start()
            monitors.values.forEach { $0.start() }
        } else {
            monitors.values.forEach { $0.stop() }
            store?.stop()
            window.apply(.hidden)
        }
    }

    /// Bound to `@AppStorage("notchEdge")`.
    func apply(edge: NotchEdge) {
        guard configured else { return }
        window.apply(edge: edge)
    }

    // MARK: - Appearance (the Notch settings pane)

    /// Pinned-open vs hover. Only meaningful while the notch is shown; `hidden`
    /// is reached through the master toggle, not this.
    func apply(visibility: NotchVisibility) {
        guard configured, visible else { return }
        window.apply(visibility)
    }

    func apply(size: NotchSize) {
        guard configured else { return }
        window.apply(size: size)
    }

    func apply(accent: NotchAccentChoice) {
        guard configured else { return }
        window.model.accentColor = accent
    }

    func apply(resetTimeFormat: ResetTimeFormat) {
        guard configured else { return }
        window.model.resetTimeFormat = resetTimeFormat
    }

    /// Drop the ⌥-drag offset and sit the notch back at the centre of its edge.
    func recentre() {
        guard configured else { return }
        window.model.alongOffset = 0
        UserDefaults.standard.set(0.0, forKey: offsetKey)
    }

    // MARK: - Completion peek + chime

    private func announceCompletions() {
        let events = completions.absorb(window.model.sessions)
        guard let event = events.first else { return }
        NotchLog.sessions.info("session \(event.session.name, privacy: .public) \(String(describing: event.reason), privacy: .public)")

        let defaults = UserDefaults.standard
        if defaults.object(forKey: "notchSessionEndSound") as? Bool ?? AppPreferences.defaultNotchSessionEndSound {
            let name = event.reason == .blocked
                ? (defaults.string(forKey: "notchSessionBlockedSoundName") ?? "Funk")
                : (defaults.string(forKey: "notchSessionEndSoundName") ?? "Glass")
            SessionChime.play(name)
        }
        guard defaults.object(forKey: "notchAnnounceSessionEnd") as? Bool
            ?? AppPreferences.defaultNotchAnnounceSessionEnd else { return }
        window.peek(for: 5, focusing: event.session.processID)
    }

    private func storedEdge() -> NotchEdge {
        NotchEdge(rawValue: UserDefaults.standard.string(forKey: "notchEdge") ?? "")
            ?? NotchEdge(rawValue: AppPreferences.defaultNotchEdge) ?? .right
    }

    private func storedVisibility() -> NotchVisibility {
        NotchVisibility(rawValue: UserDefaults.standard.string(forKey: "notchVisibility") ?? "")
            ?? NotchVisibility(rawValue: AppPreferences.defaultNotchVisibility) ?? .onHover
    }

    private func storedSize() -> NotchSize {
        NotchSize(rawValue: UserDefaults.standard.string(forKey: "notchSize") ?? "")
            ?? NotchSize(rawValue: AppPreferences.defaultNotchSize) ?? .medium
    }

    private func storedAccent() -> NotchAccentChoice {
        NotchAccentChoice(rawValue: UserDefaults.standard.string(forKey: "notchAccent") ?? "")
            ?? NotchAccentChoice(rawValue: AppPreferences.defaultNotchAccent) ?? .system
    }

    private func storedResetTimeFormat() -> ResetTimeFormat {
        ResetTimeFormat(rawValue: UserDefaults.standard.string(forKey: "notchResetTimeFormat") ?? "")
            ?? .automatic
    }
}
