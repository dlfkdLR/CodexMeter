import SwiftUI

struct SettingsView: View {
    var onPaneTitleChange: (String) -> Void = { _ in }

    @EnvironmentObject private var env: SettingsEnvironment
    @State private var selection: SettingsPane? = .category(.usage)
    @State private var search = ""

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SettingsSidebarSearchField(text: $search)
                    .padding(8)
                Divider()
                List(selection: $selection) {
                    Section {
                        ForEach(visibleCategories) { category in
                            SettingsChipLabel(
                                title: category.title,
                                systemImage: category.systemImage,
                                tint: category.chipTint
                            )
                            .tag(SettingsPane.category(category))
                        }
                    }
                }
                .listStyle(.sidebar)
                .accessibilityLabel("Settings sections")
                .accessibilityHint("Use the arrow keys to choose a section, then press Tab to change its settings.")
            }
            .navigationSplitViewColumnWidth(min: 224, ideal: 250, max: 300)
            .navigationTitle("CodexMeter")
        } detail: {
            detailPane
                .navigationTitle(selection?.title ?? "Settings")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: 840, idealWidth: 980, maxWidth: .infinity,
            minHeight: 560, idealHeight: 680, maxHeight: .infinity
        )
        .onChange(of: selection) { _, newValue in
            onPaneTitleChange(newValue?.title ?? "CodexMeter Settings")
        }
        .onAppear { onPaneTitleChange(selection?.title ?? "CodexMeter Settings") }
        .onReceive(NotificationCenter.default.publisher(for: SettingsWindowController.selectPaneNotification)) { note in
            if let pane = note.object as? SettingsPane {
                selection = pane
                search = ""
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        switch selection {
        case .category(.general): GeneralSettingsView()
        case .category(.usage): UsageSettingsView()
        case .category(.providers): ProvidersSettingsView()
        case .category(.notch): NotchSettingsView()
        case .category(.advanced): AdvancedSettingsView()
        case .category(.about): AboutSettingsView()
        case .provider(let provider): ProviderSettingsView(provider: provider)
        case .notchProvider(let id): NotchProviderSettingsView(providerID: id)
        case nil:
            ContentUnavailableView(
                "Choose a Section",
                systemImage: "sidebar.left",
                description: Text("Select a section from the sidebar to view its settings.")
            )
        }
    }

    private var visibleCategories: [SettingsCategory] {
        SettingsCategory.allCases.filter { category in
            SettingsPane.category(category).matches(search)
                // "claude", "cursor", "grok"… land on the Providers pane, which
                // is where every provider now lives.
                || (category == .providers && matchesAnyProvider)
        }
    }

    private var matchesAnyProvider: Bool {
        let trimmed = search.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return UsageProvider.allCases.contains { SettingsPane.provider($0).matches(search) }
            || NotchProviderCatalog.all.contains { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}
