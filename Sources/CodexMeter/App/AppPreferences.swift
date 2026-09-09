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
    private static let legacyIconOnlyDisplay = "iconOnly"

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
                "notchSessionBlockedSoundName": "Funk"
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
