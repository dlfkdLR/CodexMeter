import SwiftUI

struct MenuBarSettingsView: View {
    @AppStorage("menuBarDisplay") private var display = AppPreferences.defaultMenuBarDisplay
    @AppStorage("menuBarPeriod") private var period = UsagePeriod.today.rawValue
    @AppStorage("numberStyle") private var numberStyle = TokenNumberStyle.compact.rawValue
    @AppStorage("showCachedInput") private var showCachedInput = true
    @AppStorage("showLastUpdated") private var showLastUpdated = true
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = AppPreferences.defaultShowMenuBarIcon
    @AppStorage("showMenuBarText") private var showMenuBarText = AppPreferences.defaultShowMenuBarText
    @AppStorage("showEdgeNotch") private var showEdgeNotch = AppPreferences.defaultShowEdgeNotch
    @AppStorage("notchEdge") private var notchEdge = AppPreferences.defaultNotchEdge
    @AppStorage("notchAnnounceSessionEnd") private var announceSessionEnd = AppPreferences.defaultNotchAnnounceSessionEnd
    @AppStorage("notchSessionEndSound") private var sessionEndSound = AppPreferences.defaultNotchSessionEndSound
    @AppStorage("notchSessionEndSoundName") private var finishedSoundName = "Glass"
    @AppStorage("notchSessionBlockedSoundName") private var blockedSoundName = "Funk"

    var body: some View {
        SettingsForm {
            SettingsSection(title: "Menu Bar") {
                SettingsToggleRow("Show icon", isOn: iconVisibility, isEnabled: showMenuBarText)
                SettingsToggleRow("Show token text", isOn: textVisibility)
            }

            SettingsSection(title: "Edge Notch") {
                SettingsToggleRow(
                    "Show edge notch",
                    get: { showEdgeNotch },
                    set: { newValue in
                        showEdgeNotch = newValue
                        NotchController.shared.setVisible(newValue)
                    }
                )
                SettingsPickerRow(title: "Edge", selection: Binding(
                    get: { notchEdge },
                    set: { newValue in
                        notchEdge = newValue
                        if let edge = NotchEdge(rawValue: newValue) {
                            NotchController.shared.apply(edge: edge)
                        }
                    }
                )) {
                    ForEach(NotchEdge.allCases) { edge in
                        Text(edge.title).tag(edge.rawValue)
                    }
                }
                .disabled(!showEdgeNotch)
            }
            SettingsNote("A floating usage ring welded to a screen edge, shown alongside the menu bar. Early preview.")

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

            SettingsSection(title: "Token Text") {
                SettingsPickerRow(title: "Content", selection: $display) {
                    ForEach(MenuBarDisplay.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                SettingsPickerRow(title: "Period", selection: $period) {
                    Text("Today").tag(UsagePeriod.today.rawValue)
                    Text("This Week").tag(UsagePeriod.week.rawValue)
                    Text("This Month").tag(UsagePeriod.month.rawValue)
                }
                SettingsPickerRow(title: "Number format", selection: $numberStyle) {
                    Text("Compact").tag(TokenNumberStyle.compact.rawValue)
                    Text("Detailed").tag(TokenNumberStyle.detailed.rawValue)
                }
            }
            .disabled(!showMenuBarText)

            SettingsSection(title: "Popover") {
                SettingsToggleRow("Show cached input", isOn: $showCachedInput)
                SettingsToggleRow("Show last updated", isOn: $showLastUpdated)
            }
        }
    }

    private var iconVisibility: Binding<Bool> {
        Binding(
            get: { showMenuBarIcon },
            set: { newValue in
                showMenuBarIcon = newValue
                if !newValue && !showMenuBarText {
                    showMenuBarText = true
                }
            }
        )
    }

    private var textVisibility: Binding<Bool> {
        Binding(
            get: { showMenuBarText },
            set: { newValue in
                showMenuBarText = newValue
                if !newValue && !showMenuBarIcon {
                    showMenuBarIcon = true
                }
            }
        )
    }
}
