import AppKit
import SwiftUI

/// The settings window's content: a fixed-width sidebar of subjects beside a
/// scrolling pane, drawn as a floating rounded panel. Ported from Codenotch's
/// `SettingsView` — a plain `HStack`, not a `NavigationSplitView`, so AppKit
/// installs no toolbar strip and the sidebar can float as its own card.
struct SettingsView: View {
    @EnvironmentObject private var env: SettingsEnvironment

    @State private var selection: SettingsCategory = .usage
    @State private var isSidebarVisible = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    static let headerHeight: CGFloat = 52
    static let cornerRadius: CGFloat = 20
    static let sidebarInset: CGFloat = 4
    static let sidebarCornerRadius: CGFloat = 14
    static let sidebarWidth: CGFloat = 208
    /// Roughly the width the three traffic lights take, for the one layout that
    /// has to start clear of them — the collapsed pane's header.
    static let trafficLightWidth: CGFloat = 66

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                sidebar
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            pane(for: selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 840, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
        .background {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                SettingsWindowVibrancy(material: .underWindowBackground)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            }
        }
        // Under `fullSizeContentView` SwiftUI still insets by a title bar's
        // height that this window does not really have; take the channel away.
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for: SettingsWindowController.selectPaneNotification)) { note in
            guard let pane = note.object as? SettingsPane else { return }
            switch pane {
            case .category(let category): selection = category
            // Deep-links to a specific provider land on the Providers pane,
            // which is where every provider now lives.
            case .provider, .notchProvider: selection = .providers
            }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(SettingsCategory.allCases, selection: $selection) { category in
            Label {
                Text(category.title)
            } icon: {
                SidebarIcon(systemName: category.systemImage, tint: category.chipTint)
            }
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10))
            .tag(category)
        }
        .listStyle(.sidebar)
        .environment(\.defaultMinListRowHeight, 24)
        .scrollContentBackground(.hidden)
        // The band the traffic lights sit in — the toggle takes its right end,
        // the one part nothing else claims.
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                sidebarToggle
            }
            .padding(.trailing, 14)
            .frame(height: Self.headerHeight - Self.sidebarInset)
        }
        .frame(width: Self.sidebarWidth)
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: Self.sidebarCornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: Self.sidebarCornerRadius, style: .continuous)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: Self.sidebarCornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            }
        }
        .padding(Self.sidebarInset)
        .accessibilityLabel("Settings sections")
    }

    private var sidebarToggle: some View {
        Button(action: toggleSidebar) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Hide Sidebar")
    }

    private var collapsedSidebarToggle: some View {
        Button(action: toggleSidebar) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background {
                    if reduceTransparency {
                        Circle().fill(Color(nsColor: .controlBackgroundColor))
                            .overlay(Circle().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1))
                    } else {
                        Circle().fill(.regularMaterial)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Show Sidebar")
    }

    private func toggleSidebar() {
        withAnimation(.snappy(duration: 0.22)) { isSidebarVisible.toggle() }
    }

    // MARK: Pane

    private func pane(for category: SettingsCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                if !isSidebarVisible {
                    Color.clear.frame(width: Self.trafficLightWidth, height: 1)
                    collapsedSidebarToggle
                }
                Text(category.title)
                    .font(.title2.weight(.semibold))
                Spacer(minLength: 0)
            }
            .frame(height: Self.headerHeight)
            .padding(.leading, isSidebarVisible ? 22 : 12)
            .padding(.trailing, 22)

            paneContent(for: category)
        }
    }

    @ViewBuilder
    private func paneContent(for category: SettingsCategory) -> some View {
        switch category {
        case .usage: UsageSettingsView()
        case .providers: ProvidersSettingsView()
        case .notch: NotchSettingsView()
        case .general: GeneralSettingsView()
        case .advanced: AdvancedSettingsView()
        case .about: AboutSettingsView()
        }
    }
}
