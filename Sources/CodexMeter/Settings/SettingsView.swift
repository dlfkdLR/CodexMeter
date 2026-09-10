import SwiftUI

/// The settings window: a sidebar of subjects beside one scrolling pane.
///
/// Deliberately a `NavigationSplitView` rather than a hand-built split. An
/// earlier rewrite used a plain `HStack` with a floating sidebar card — it
/// renders in a preview and leaves the sidebar blank in a real transparent
/// window, which is a bad trade for a surface people actually use. The
/// Codenotch look that survives is the part that is only styling: System
/// Settings' tinted icon badges in the sidebar, and panes made of grouped
/// rounded cards.
struct SettingsView: View {
    @EnvironmentObject private var env: SettingsEnvironment

    @State private var selection: SettingsCategory? = .usage

    var body: some View {
        NavigationSplitView {
            List(SettingsCategory.allCases, selection: $selection) { category in
                Label {
                    Text(category.title)
                } icon: {
                    SidebarIcon(systemName: category.systemImage, tint: category.chipTint)
                }
                .padding(.vertical, 3)
                .tag(category)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 216, max: 260)
            .accessibilityLabel("Settings sections")
            .accessibilityHint("Choose a section to change its settings.")
        } detail: {
            pane
                .navigationTitle(selection?.title ?? "Settings")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: 840, idealWidth: 960, maxWidth: .infinity,
            minHeight: 560, idealHeight: 640, maxHeight: .infinity
        )
        .onReceive(NotificationCenter.default.publisher(for: SettingsWindowController.selectPaneNotification)) { note in
            guard let pane = note.object as? SettingsPane else { return }
            switch pane {
            case .category(let category): selection = category
            // Deep links to one provider land on the Providers pane, which is
            // where every provider lives.
            case .provider, .notchProvider: selection = .providers
            }
        }
    }

    @ViewBuilder
    private var pane: some View {
        switch selection {
        case .usage: UsageSettingsView()
        case .providers: ProvidersSettingsView()
        case .notch: NotchSettingsView()
        case .general: GeneralSettingsView()
        case .advanced: AdvancedSettingsView()
        case .about: AboutSettingsView()
        case nil:
            ContentUnavailableView(
                "Choose a Section",
                systemImage: "sidebar.left",
                description: Text("Select a section from the sidebar to view its settings.")
            )
        }
    }
}
