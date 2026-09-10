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
        // The popover view caps its own width (it is a reading column, not a
        // full-bleed form). Pin it to the top-leading corner like every other
        // pane and paint the whole pane behind it, so the space beside it is
        // ordinary empty background — not a bare void with a hard seam where the
        // column's own background stops, and not a column stranded mid-pane.
        MenuPopoverView(accounts: env.codexAccounts, embedded: true)
            .id(provider)
            .environmentObject(env.usageStore(for: provider))
            .environmentObject(env.profileStore)
            .environmentObject(env.limitStore)
            .environmentObject(env.claude)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.background)
            .task(id: provider) {
                env.profileStore.synchronizeEnabledPreference()
                await env.usageStore(for: provider).refresh()
            }
    }
}
