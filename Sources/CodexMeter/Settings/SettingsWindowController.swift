import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private static let frameAutosaveName = "CodexMeterSettingsWindowV2"
    private static let minimumContentSize = NSSize(width: 840, height: 560)
    private static let defaultContentSize = NSSize(width: 980, height: 680)

    private var settingsWindow: NSWindow?
    private var environment: SettingsEnvironment?
    private let navigation = SettingsNavigation()

    var isSettingsWindowVisible: Bool {
        settingsWindow?.isVisible == true
    }

    /// Wired once at launch from `CodexMeterApp` with the app's real stores.
    func configure(environment: SettingsEnvironment) {
        self.environment = environment
    }

    func present() {
        navigation.columnVisibility = .all
        let environment = self.environment ?? SettingsEnvironment()
        let window = settingsWindow ?? makeWindow(environment: environment)
        // An accessory app is restricted from activating and compositing its
        // own windows, which is how "Settings…" can look like it did nothing.
        // Be a regular app for as long as the window is up; `windowWillClose`
        // puts the policy back.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        // Off any connected screen — a display reconfigured since it was last
        // placed — is the other way it opens invisibly.
        if !NSScreen.screens.contains(where: { $0.frame.intersects(window.frame) }) {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func present(selecting pane: SettingsPane) {
        navigation.select(pane)
        present()
    }

    private func makeWindow(environment: SettingsEnvironment) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CodexMeter Settings"
        window.contentMinSize = Self.minimumContentSize
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: SettingsView(navigation: navigation)
                .environmentObject(environment)
                .environmentObject(environment.claude)
        )
        window.delegate = self
        if !window.setFrameUsingName(Self.frameAutosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(Self.frameAutosaveName)
        settingsWindow = window
        return window
    }

#if DEBUG
    var settingsWindowContentSizeForTesting: NSSize? {
        settingsWindow?.contentView?.bounds.size
    }

    var settingsWindowIsResizableForTesting: Bool {
        settingsWindow?.styleMask.contains(.resizable) ?? false
    }

    var settingsWindowMinimumContentSizeForTesting: NSSize? {
        settingsWindow?.contentMinSize
    }

    var settingsContentViewControllerForTesting: NSViewController? {
        settingsWindow?.contentViewController
    }

    func closeSettingsForTesting() {
        settingsWindow?.close()
    }
#endif
}
