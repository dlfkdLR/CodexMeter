import SwiftUI

/// The edge notch: a floating usage ring welded to a screen edge, ported from
/// the MIT-licensed Codenotch. Everything that shapes it lives here rather than
/// in the Menu Bar pane — the two are separate surfaces.
struct NotchSettingsView: View {
    @AppStorage("showEdgeNotch") private var showEdgeNotch = AppPreferences.defaultShowEdgeNotch
    @AppStorage("notchVisibility") private var visibility = AppPreferences.defaultNotchVisibility
    @AppStorage("notchEdge") private var notchEdge = AppPreferences.defaultNotchEdge
    @AppStorage("notchSize") private var notchSize = AppPreferences.defaultNotchSize
    @AppStorage("notchAccent") private var notchAccent = AppPreferences.defaultNotchAccent
    @AppStorage("notchResetTimeFormat") private var resetTimeFormat = AppPreferences.defaultNotchResetTimeFormat
    @AppStorage("notchShowUsagePace") private var showUsagePace = AppPreferences.defaultNotchShowUsagePace

    @AppStorage("notchAnnounceSessionEnd") private var announceSessionEnd = AppPreferences.defaultNotchAnnounceSessionEnd
    @AppStorage("notchSessionEndSound") private var sessionEndSound = AppPreferences.defaultNotchSessionEndSound
    @AppStorage("notchSessionEndSoundName") private var finishedSoundName = "Glass"
    @AppStorage("notchSessionBlockedSoundName") private var blockedSoundName = "Funk"

    @AppStorage("notchThresholdAlerts") private var thresholdAlerts = AppPreferences.defaultNotchThresholdAlerts

    @State private var ollamaKeyDraft = ""
    @State private var ollamaKeyStored = false
    @State private var ollamaEnvActive = false


    var body: some View {
        SettingsForm {
            SettingsSection(title: "Edge Notch") {
                SettingsToggleRow(
                    "Show edge notch",
                    get: { showEdgeNotch },
                    set: { newValue in
                        showEdgeNotch = newValue
                        NotchController.shared.setVisible(newValue)
                    }
                )
            }
            SettingsNote("A floating usage ring welded to a screen edge, shown alongside the menu bar. ⌥-drag the pill to slide it along the edge; Recentre puts it back.")

            SettingsSection(title: "Placement") {
                SettingsPickerRow(title: "Behaviour", selection: Binding(
                    get: { visibility },
                    set: { newValue in
                        visibility = newValue
                        if let mode = NotchVisibility(rawValue: newValue) {
                            NotchController.shared.apply(visibility: mode)
                        }
                    }
                )) {
                    Text("Show on hover").tag(NotchVisibility.onHover.rawValue)
                    Text("Always show").tag(NotchVisibility.alwaysShow.rawValue)
                }
                SettingsPickerRow(title: "Edge", selection: Binding(
                    get: { notchEdge },
                    set: { newValue in
                        notchEdge = newValue
                        if let edge = NotchEdge(rawValue: newValue) {
                            NotchController.shared.apply(edge: edge)
                        }
                    }
                )) {
                    ForEach(NotchEdge.allCases) { Text($0.title).tag($0.rawValue) }
                }
                SettingsPickerRow(title: "Size", selection: Binding(
                    get: { notchSize },
                    set: { newValue in
                        notchSize = newValue
                        if let size = NotchSize(rawValue: newValue) {
                            NotchController.shared.apply(size: size)
                        }
                    }
                )) {
                    ForEach(NotchSize.allCases) { Text($0.title).tag($0.rawValue) }
                }
                SettingsButtonRow(title: "Recentre", systemImage: "arrow.up.and.down.and.arrow.left.and.right") {
                    NotchController.shared.recentre()
                }
            }
            .disabled(!showEdgeNotch)

            SettingsSection(title: "Appearance") {
                SettingsPickerRow(title: "Ring colour", selection: Binding(
                    get: { notchAccent },
                    set: { newValue in
                        notchAccent = newValue
                        if let accent = NotchAccentChoice(rawValue: newValue) {
                            NotchController.shared.apply(accent: accent)
                        }
                    }
                )) {
                    ForEach(NotchAccentChoice.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
            }
            .disabled(!showEdgeNotch)
            SettingsNote("Only the healthy end of the scale takes this colour — the 80% and 100% warning bands stay fixed, since their job is to interrupt.")

            SettingsSection(title: "Readings") {
                SettingsPickerRow(title: "Reset time", selection: Binding(
                    get: { resetTimeFormat },
                    set: { newValue in
                        resetTimeFormat = newValue
                        if let format = ResetTimeFormat(rawValue: newValue) {
                            NotchController.shared.apply(resetTimeFormat: format)
                        }
                    }
                )) {
                    ForEach(ResetTimeFormat.allCases) { Text($0.title).tag($0.rawValue) }
                }
                SettingsToggleRow(
                    "Show usage pace",
                    get: { showUsagePace },
                    set: { showUsagePace = $0 }
                )
            }
            .disabled(!showEdgeNotch)

            SettingsSection(title: "When a Session Ends") {
                SettingsToggleRow(
                    "Peek the notch open",
                    get: { announceSessionEnd },
                    set: { announceSessionEnd = $0 }
                )
                SettingsToggleRow(
                    "Play a sound",
                    get: { sessionEndSound },
                    set: { sessionEndSound = $0 }
                )
                SettingsPickerRow(title: "Finished", selection: Binding(
                    get: { finishedSoundName },
                    set: { finishedSoundName = $0; SessionChime.play($0) }
                )) {
                    ForEach(SessionChime.available, id: \.self) { Text($0).tag($0) }
                }
                .disabled(!sessionEndSound)
                SettingsPickerRow(title: "Blocked on you", selection: Binding(
                    get: { blockedSoundName },
                    set: { blockedSoundName = $0; SessionChime.play($0) }
                )) {
                    ForEach(SessionChime.available, id: \.self) { Text($0).tag($0) }
                }
                .disabled(!sessionEndSound)
            }
            .disabled(!showEdgeNotch)
            SettingsNote("A running agent spins its ring; one waiting on you pulses amber. When it finishes, the notch drops open for five seconds — click it to raise that agent's terminal.")

            SettingsSection(title: "Limit Alerts") {
                SettingsToggleRow(
                    "Notify at 80% and 100%",
                    get: { thresholdAlerts },
                    set: { thresholdAlerts = $0 }
                )
            }
            .disabled(!showEdgeNotch)
            SettingsNote("A single macOS notification each time a limit window crosses 80%, then 100% — once per crossing, and again only after the window resets. Mute an individual provider from its row in Settings ▸ Providers.")

            SettingsSection(title: "Ollama Cloud") {
                SettingsRow(title: "API key") {
                    SecureField("ollama_…", text: $ollamaKeyDraft)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                        .onSubmit(saveOllamaKey)
                }
                SettingsButtonRow(title: ollamaKeyStored ? "Replace" : "Save",
                                  isEnabled: !ollamaKeyDraft.isEmpty, action: saveOllamaKey)
                if ollamaKeyStored {
                    SettingsButtonRow(title: "Remove", role: .destructive) {
                        _ = OllamaCredentials.delete()
                        ollamaKeyStored = false
                        ollamaKeyDraft = ""
                    }
                }
            }
            .disabled(!showEdgeNotch)
            SettingsNote(ollamaEnvActive
                ? "OLLAMA_API_KEY is set in the environment and takes precedence over a key entered here."
                : "Kept in the login Keychain. The Ollama ring appears once a key is present.")
        }
        .onAppear {
            ollamaKeyStored = OllamaCredentials.hasStoredKey
            ollamaEnvActive = ProcessInfo.processInfo.environment["OLLAMA_API_KEY"]?.isEmpty == false
        }
    }

    private func saveOllamaKey() {
        guard !ollamaKeyDraft.isEmpty else { return }
        if OllamaCredentials.store(ollamaKeyDraft) {
            ollamaKeyStored = true
            ollamaKeyDraft = ""
        }
    }
}

private extension NotchAccentChoice {
    var title: String {
        switch self {
        case .system: return "System"
        case .green:  return "Green"
        case .blue:   return "Blue"
        case .purple: return "Purple"
        case .pink:   return "Pink"
        case .orange: return "Orange"
        }
    }
}
