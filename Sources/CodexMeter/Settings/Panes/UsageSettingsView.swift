import SwiftUI

/// Token history, project and session analytics — the numbers the menu-bar
/// popover used to show. Hosted here so they survive the notch taking the
/// popover's place. The popover view itself is reused in `embedded` mode
/// rather than reimplemented.
struct UsageSettingsView: View {
    @EnvironmentObject private var env: SettingsEnvironment
    @AppStorage("usageProvider") private var usageProvider = UsageProvider.codex.rawValue

    private var provider: UsageProvider {
        UsageProvider(rawValue: usageProvider) ?? .codex
    }

    var body: some View {
        MenuPopoverView(accounts: env.codexAccounts, embedded: true)
            .id(provider)
            .environmentObject(env.usageStore(for: provider))
            .environmentObject(env.profileStore)
            .environmentObject(env.limitStore)
            .environmentObject(env.claude)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .task(id: provider) {
                env.profileStore.synchronizeEnabledPreference()
                await env.usageStore(for: provider).refresh()
            }
    }
}
