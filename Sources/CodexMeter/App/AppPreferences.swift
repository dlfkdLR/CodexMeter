import Foundation

enum AppPreferences {
    static let defaultMenuBarDisplay = MenuBarDisplay.total.rawValue
    static let defaultShowMenuBarIcon = true
    static let defaultShowMenuBarText = false
    static let defaultProfileSyncEnabled = false
    static let defaultAccountLimitsEnabled = true
    static let defaultAnalyticsEnabled = true
    static let defaultCostEstimatesEnabled = true
    static let defaultAdditionalLimitsEnabled = true
    static let defaultResetCreditsEnabled = true
    static let defaultClaudeEnabled = false
    static let defaultProjectsEnabled = true
    static let defaultSessionsEnabled = true
    static let defaultAgentDetailsEnabled = true
    static let defaultAttachmentMetadataEnabled = true
    static let defaultShowEdgeNotch = false
    static let defaultNotchEdge = NotchEdge.right.rawValue
    static let defaultNotchSessionEndSound = true
    static let defaultNotchAnnounceSessionEnd = true
    static let defaultNotchThresholdAlerts = true
    private static let legacyIconOnlyDisplay = "iconOnly"

    // MARK: Threshold alerts

    /// Providers whose 80%/100% alerts are muted, stored as the muted set (a
    /// comma-joined id list) so a provider added later alerts by default.
    static let mutedAlertProvidersKey = "notchMutedAlertProviders"

    static func mutedAlertProviders(in defaults: UserDefaults = .standard) -> Set<String> {
        Set((defaults.string(forKey: mutedAlertProvidersKey) ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
    }

    static func isAlertMuted(_ providerID: String, in defaults: UserDefaults = .standard) -> Bool {
        mutedAlertProviders(in: defaults).contains(providerID)
    }

    static func setAlertMuted(_ muted: Bool, for providerID: String,
                              in defaults: UserDefaults = .standard) {
        var set = mutedAlertProviders(in: defaults)
        if muted { set.insert(providerID) } else { set.remove(providerID) }
        defaults.set(set.sorted().joined(separator: ","), forKey: mutedAlertProvidersKey)
    }

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(
            defaults: [
                "menuBarDisplay": defaultMenuBarDisplay,
                "showMenuBarIcon": defaultShowMenuBarIcon,
                "showMenuBarText": defaultShowMenuBarText,
                "profileSyncEnabled": defaultProfileSyncEnabled,
                "accountLimitsEnabled": defaultAccountLimitsEnabled,
                "analyticsEnabled": defaultAnalyticsEnabled,
                "costEstimatesEnabled": defaultCostEstimatesEnabled,
                "additionalLimitsEnabled": defaultAdditionalLimitsEnabled,
                "resetCreditsEnabled": defaultResetCreditsEnabled,
                "claudeEnabled": defaultClaudeEnabled,
                "projectsEnabled": defaultProjectsEnabled,
                "sessionsEnabled": defaultSessionsEnabled,
                "agentDetailsEnabled": defaultAgentDetailsEnabled,
                "attachmentMetadataEnabled": defaultAttachmentMetadataEnabled,
                "showEdgeNotch": defaultShowEdgeNotch,
                "notchEdge": defaultNotchEdge,
                "notchSessionEndSound": defaultNotchSessionEndSound,
                "notchAnnounceSessionEnd": defaultNotchAnnounceSessionEnd,
                "notchSessionEndSoundName": "Glass",
                "notchSessionBlockedSoundName": "Funk",
                "notchThresholdAlerts": defaultNotchThresholdAlerts,
                mutedAlertProvidersKey: ""
            ]
        )
        migrateLegacyIconOnlyPreference(in: defaults)
    }

    static func shouldShowMenuBarIcon(
        display _: String,
        showIcon: Bool,
        showText: Bool
    ) -> Bool {
        showIcon || !showText
    }

    static func shouldShowMenuBarText(
        display _: String,
        showText: Bool,
        text: String
    ) -> Bool {
        showText && !text.isEmpty
    }

    private static func migrateLegacyIconOnlyPreference(in defaults: UserDefaults) {
        guard defaults.string(forKey: "menuBarDisplay") == legacyIconOnlyDisplay else { return }
        defaults.set(MenuBarDisplay.total.rawValue, forKey: "menuBarDisplay")
        defaults.set(true, forKey: "showMenuBarIcon")
        defaults.set(false, forKey: "showMenuBarText")
    }
}
