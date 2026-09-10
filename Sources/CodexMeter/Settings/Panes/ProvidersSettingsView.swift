import AppKit
import SwiftUI

/// Every provider in one list, modelled on Codenotch's account pane: a
/// **Connected** group whose rows can be dragged to reorder the notch rings,
/// and a **Not connected** group of sign-in prompts. Codex and Claude Code —
/// the two CodexMeter meters locally — open their fuller pane from a row; the
/// borrowed-credential providers open the usage pane added for them.
struct ProvidersSettingsView: View {
    @EnvironmentObject private var env: SettingsEnvironment

    var body: some View {
        ProvidersSettingsContent(
            claude: env.claude,
            limits: env.limitStore,
            codexAccounts: env.codexAccounts
        )
    }
}

private struct ProvidersSettingsContent: View {
    @ObservedObject var claude: ClaudeIntegrationStore
    @ObservedObject var limits: AccountLimitStore
    @ObservedObject var codexAccounts: CodexAccountStore
    @ObservedObject private var notch = NotchController.shared

    @AppStorage("notchThresholdAlerts") private var thresholdAlerts = AppPreferences.defaultNotchThresholdAlerts
    @AppStorage(AppPreferences.mutedAlertProvidersKey) private var mutedAlerts = ""

    @State private var openDetail: String?
    @State private var dragging: String?

    var body: some View {
        Group {
            if let openDetail {
                detail(for: openDetail)
            } else {
                list
            }
        }
        // A drag released in the pane but off any row fires no row drop; clear
        // the drag state here so the row it came from does not stay dimmed.
        .onDrop(of: [.text], isTargeted: nil) { _ in
            dragging = nil
            return false
        }
        .task {
            codexAccounts.load()
            notch.refreshProvidersForSettings()
            if claude.isEnabled { await claude.refresh() }
        }
    }

    // MARK: Detail

    @ViewBuilder
    private func detail(for id: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                openDetail = nil
            } label: {
                Label("All Providers", systemImage: "chevron.left")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 4)

            switch id {
            case "codex":  ProviderSettingsView(provider: .codex)
            case "claude": ProviderSettingsView(provider: .claude)
            default:       NotchProviderSettingsView(providerID: id)
            }
        }
    }

    // MARK: List

    private var list: some View {
        SettingsForm {
            let rows = providerRows
            let connected = rows.filter(\.connected)
            let offline = rows.filter { !$0.connected }

            SettingsSection(title: "Connected") {
                if connected.isEmpty {
                    SettingsInfoRow(text: "Nothing is connected yet — sign in to a tool below and its ring joins the notch.",
                                    systemImage: "circle.dashed", tint: .secondary)
                } else {
                    ForEach(connected) { row in
                        ProviderAccountRow(
                            row: row,
                            orderable: connected.count > 1,
                            isMuted: isMuted(row.id),
                            alertsOn: thresholdAlerts,
                            toggleMute: { toggleMute(row.id) },
                            primaryAction: { perform(row.primary, for: row) }
                        )
                        .opacity(dragging == row.id ? 0.4 : 1)
                        .onDrag {
                            dragging = row.id
                            return NSItemProvider(object: row.id as NSString)
                        }
                        .onDrop(of: [.text], delegate: ReorderDrop(
                            target: row.id,
                            current: { dragging },
                            move: { moved in move(moved, before: row.id) },
                            end: { dragging = nil }
                        ))
                    }
                }
            }
            if connected.count > 1 {
                SettingsNote("Drag a row by its handle to change the order the notch draws its rings.")
            }

            if !offline.isEmpty {
                SettingsSection(title: "Not connected") {
                    ForEach(offline) { row in
                        ProviderAccountRow(
                            row: row,
                            orderable: false,
                            isMuted: false,
                            alertsOn: thresholdAlerts,
                            toggleMute: {},
                            primaryAction: { perform(row.primary, for: row) }
                        )
                    }
                }
            }

            SettingsNote("CodexMeter never signs in to these tools. Each reading is borrowed from a tool already signed in on this Mac — switching accounts or signing out is done there, and the notch follows. macOS asks once per keychain-backed tool; choose Always Allow.")
        }
    }

    // MARK: Rows

    private var providerRows: [ProviderRowModel] {
        let order = notch.providerOrder
        // Sort by the user's order, then by catalogue position as a stable
        // tie-break — `Array.sorted` is not a stable sort, so without the
        // second key the providers nobody has dragged would reshuffle on
        // every render.
        let ordered = NotchProviderCatalog.all.enumerated().sorted { lhs, rhs in
            let li = order.firstIndex(of: lhs.element.id) ?? Int.max
            let ri = order.firstIndex(of: rhs.element.id) ?? Int.max
            return li != ri ? li < ri : lhs.offset < rhs.offset
        }.map(\.element)
        return ordered.map { entry in
            switch entry.id {
            case "codex":  return codexRow(name: entry.name)
            case "claude": return claudeRow(name: entry.name)
            default:       return notchRow(id: entry.id, name: entry.name)
            }
        }
    }

    private func codexRow(name: String) -> ProviderRowModel {
        let account = codexAccounts.accounts.first { $0.id == codexAccounts.currentID }
        return ProviderRowModel(
            id: "codex", name: name, glyph: .openai, connected: true,
            statusLine: headline(from: limits.snapshot) ?? "Signed in",
            accountLine: account?.menuTitle(in: codexAccounts.accounts) ?? "Signed in to the Codex app",
            wasRefused: false, primary: .details
        )
    }

    private func claudeRow(name: String) -> ProviderRowModel {
        if claude.isAvailable {
            return ProviderRowModel(
                id: "claude", name: name, glyph: .claude, connected: true,
                statusLine: headline(from: claude.snapshot) ?? claude.statusMessage,
                accountLine: claude.account.map { acc in
                    [acc.displayName, acc.planName].compactMap { $0 }.joined(separator: " · ")
                },
                wasRefused: false, primary: .details
            )
        }
        return ProviderRowModel(
            id: "claude", name: name, glyph: .claude, connected: false,
            statusLine: claude.isEnabled ? claude.statusMessage : "Not connected",
            accountLine: claude.detectedAccount.map { "Detected: \($0.displayName)" },
            wasRefused: false, primary: .details
        )
    }

    private func notchRow(id: String, name: String) -> ProviderRowModel {
        let snapshot = notch.snapshot(for: id)
        let summary = notch.summary(for: id)
        let connected = snapshot?.hasReading == true
        let refused = summary?.wasRefusedAccess == true
        return ProviderRowModel(
            id: id,
            name: name,
            glyph: NotchProviderCatalog.glyph(for: id),
            connected: connected,
            statusLine: notchStatus(snapshot: snapshot, refused: refused),
            accountLine: summary?.account.map(\.summary),
            hint: connected ? nil : (summary?.signIn).map(shortHint),
            wasRefused: refused,
            primary: refused ? .allowAccess : (connected ? .details : .signIn(summary?.signIn))
        )
    }

    private func shortHint(_ route: SignInRoute) -> String {
        switch route {
        case let .openApp(_, name): return "Sign in with \(name)"
        case let .modal(name):      return "Sign in to \(name)"
        case let .guidance(text):   return text
        }
    }

    private func notchStatus(snapshot: ProviderSnapshot?, refused: Bool) -> String {
        guard let snapshot else { return "Not connected" }
        if refused { return "Keychain access was denied" }
        if snapshot.hasReading, let headline = snapshot.headline {
            return "\(snapshot.headlineText) of \(headline.label)"
        }
        switch snapshot.status {
        case .ok:                  return "Connected — no reading yet"
        case .stale(let since):    return since == .distantPast ? "Checking…" : "Last read \(ElapsedCopy.ago(since: since))"
        case .needsAuth:           return "Not connected"
        case .accessDenied:        return "Keychain access was denied"
        case .unsupported(let w):  return w
        case .error(let m):        return m
        }
    }

    private func headline(from snapshot: AccountLimitsSnapshot?) -> String? {
        guard let window = snapshot?.windows.min(by: { $0.remainingPercent < $1.remainingPercent }) else { return nil }
        return "\(Int(window.usedPercent.rounded()))% of \(window.windowLabel)"
    }

    // MARK: Actions

    private func perform(_ action: ProviderRowModel.Primary, for row: ProviderRowModel) {
        switch action {
        case .details:
            openDetail = row.id
        case .allowAccess:
            notch.refresh(providerID: row.id)
        case .signIn(let route):
            switch route {
            case let .openApp(bundleID, _):
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    NSWorkspace.shared.open(url)
                }
            case .modal, .none:
                if row.id == "claude" {
                    openDetail = "claude"
                } else {
                    notch.refresh(providerID: row.id)
                }
            case .guidance:
                openDetail = row.id
            }
        }
    }

    private func isMuted(_ id: String) -> Bool {
        _ = mutedAlerts
        return AppPreferences.isAlertMuted(id)
    }

    private func toggleMute(_ id: String) {
        AppPreferences.setAlertMuted(!AppPreferences.isAlertMuted(id), for: id)
    }

    private func move(_ moved: String, before target: String) {
        guard moved != target else { return }
        // Start from the current order, backfilled with any provider that has
        // never been dragged so every row has a place.
        var ids = notch.providerOrder
        for row in providerRows where !ids.contains(row.id) { ids.append(row.id) }
        guard let from = ids.firstIndex(of: moved) else { return }
        ids.remove(at: from)
        guard let to = ids.firstIndex(of: target) else { return }
        ids.insert(moved, at: to)
        notch.setProviderOrder(ids)
    }
}

// MARK: - Row model

struct ProviderRowModel: Identifiable {
    enum Primary {
        case details
        case allowAccess
        case signIn(SignInRoute?)
    }

    let id: String
    let name: String
    let glyph: ProviderGlyph
    let connected: Bool
    let statusLine: String
    let accountLine: String?
    /// Shown under a not-connected row instead of a bare "Not connected".
    var hint: String? = nil
    let wasRefused: Bool
    let primary: Primary
}

// MARK: - Row view

private struct ProviderAccountRow: View {
    let row: ProviderRowModel
    let orderable: Bool
    let isMuted: Bool
    let alertsOn: Bool
    let toggleMute: () -> Void
    let primaryAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if orderable {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 26, height: 26)
                .overlay(
                    ProviderGlyphView(glyph: row.glyph, size: 15)
                        .foregroundStyle(row.connected ? Color.primary : Color.secondary)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                    .foregroundStyle(row.connected ? .primary : .secondary)
                Text(secondaryLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if row.connected {
                Button(action: toggleMute) {
                    Image(systemName: isMuted ? "bell.slash" : "bell")
                        .foregroundStyle(isMuted ? .tertiary : .secondary)
                }
                .buttonStyle(.borderless)
                .disabled(!alertsOn)
                .help(isMuted ? "Alerts for \(row.name) are muted" : "Alert at 80% and 100% of a limit")
                .accessibilityLabel(isMuted ? "Unmute \(row.name) alerts" : "Mute \(row.name) alerts")
            }

            primaryButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.name), \(row.statusLine)")
    }

    private var secondaryLine: String {
        if let account = row.accountLine, !account.isEmpty {
            let generic: Set<String> = ["Connected", "Signed in", "Not connected"]
            return generic.contains(row.statusLine) ? account : "\(account) · \(row.statusLine)"
        }
        if !row.connected, row.statusLine == "Not connected", let hint = row.hint {
            return hint
        }
        return row.statusLine
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch row.primary {
        case .details:
            Button("Details", action: primaryAction)
                .controlSize(.small)
        case .allowAccess:
            Button("Allow Access…", action: primaryAction)
                .controlSize(.small)
                .tint(.orange)
        case .signIn(let route):
            Button(signInTitle(route), action: primaryAction)
                .controlSize(.small)
        }
    }

    private func signInTitle(_ route: SignInRoute?) -> String {
        switch route {
        case let .openApp(_, name): return "Open \(name)"
        case let .modal(name):      return "Sign in to \(name)"
        case .guidance, .none:      return "Set Up…"
        }
    }
}

// MARK: - Drop delegate

private struct ReorderDrop: DropDelegate {
    let target: String
    let current: () -> String?
    let move: (String) -> Void
    let end: () -> Void

    func dropEntered(info: DropInfo) {
        guard let moved = current(), moved != target else { return }
        move(moved)
    }

    func performDrop(info: DropInfo) -> Bool {
        end()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
