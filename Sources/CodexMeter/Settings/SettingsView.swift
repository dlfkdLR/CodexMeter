import SwiftUI

struct SettingsView: View {
    var onPaneTitleChange: (String) -> Void = { _ in }

    @EnvironmentObject private var env: SettingsEnvironment
    @EnvironmentObject private var claude: ClaudeIntegrationStore
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
                    if !visibleProviders.isEmpty || !visibleNotchProviders.isEmpty {
                        Section {
                            ForEach(visibleProviders) { provider in
                                SettingsChipLabel(
                                    title: provider.title,
                                    logoProvider: provider,
                                    statusDot: providerIsOn(provider) ? .green : nil,
                                    dimmed: !providerIsOn(provider)
                                )
                                .tag(SettingsPane.provider(provider))
                            }
                            ForEach(visibleNotchProviders, id: \.id) { entry in
                                SettingsChipLabel(
                                    title: entry.name,
                                    systemImage: "circle.dotted",
                                    tint: .secondary,
                                    statusDot: notchProviderConnected(entry.id) ? .green : nil,
                                    dimmed: !notchProviderConnected(entry.id)
                                )
                                .tag(SettingsPane.notchProvider(id: entry.id))
                            }
                        } header: {
                            HStack {
                                Text("Providers")
                                Spacer()
                                Text("\(onCount) on")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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

    private func providerIsOn(_ provider: UsageProvider) -> Bool {
        provider == .codex ? true : claude.isAvailable
    }

    @ObservedObject private var notch = NotchController.shared

    private func notchProviderConnected(_ id: String) -> Bool {
        notch.snapshot(for: id)?.hasReading == true
    }

    private var onCount: Int {
        1 + (claude.isAvailable ? 1 : 0)
            + NotchProviderCatalog.all
                .filter { $0.id != "codex" && $0.id != "claude" && notchProviderConnected($0.id) }
                .count
    }

    private var visibleCategories: [SettingsCategory] {
        SettingsCategory.allCases.filter { SettingsPane.category($0).matches(search) }
    }

    private var visibleProviders: [UsageProvider] {
        UsageProvider.allCases.filter { SettingsPane.provider($0).matches(search) }
    }

    private var visibleNotchProviders: [(id: String, name: String)] {
        NotchProviderCatalog.all
            .filter { $0.id != "codex" && $0.id != "claude" }
            .filter { SettingsPane.notchProvider(id: $0.id).matches(search) }
    }
}
