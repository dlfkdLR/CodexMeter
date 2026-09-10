import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private static let frameAutosaveName = "CodexMeterSettingsWindowV3"
    private static let minimumContentSize = NSSize(width: 840, height: 560)
    private static let defaultContentSize = NSSize(width: 960, height: 620)

    private var settingsWindow: NSWindow?
    private var environment: SettingsEnvironment?

    var isSettingsWindowVisible: Bool {
        settingsWindow?.isVisible == true
    }

    /// Wired once at launch from `CodexMeterApp` with the app's real stores.
    func configure(environment: SettingsEnvironment) {
        self.environment = environment
    }

    /// Posted with a `SettingsPane` object when something outside the window
    /// asks it to open on a particular pane (the status-bar menu's "Usage…").
    static let selectPaneNotification = Notification.Name("CodexMeterSettingsSelectPane")

    func present() {
        let environment = self.environment ?? SettingsEnvironment()
        let window = settingsWindow ?? makeWindow(environment: environment)
        // An accessory app is restricted from compositing its own windows —
        // a transparent one can be "visible" by AppKit's bookkeeping and still
        // never drawn. Promote to a regular app for as long as settings is up,
        // and restore accessory on close.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        layoutTrafficLights(in: window)
    }

    func present(selecting pane: SettingsPane) {
        present()
        NotificationCenter.default.post(name: Self.selectPaneNotification, object: pane)
    }

    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        layoutTrafficLights(in: window)
    }

    private func makeWindow(environment: SettingsEnvironment) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultContentSize),
            // `fullSizeContentView` runs the sidebar flush under the traffic
            // lights — the sidebar is a plain `HStack`, so there is no toolbar
            // strip to reserve room for.
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // Kept for the Window menu and Mission Control; hidden from the bar, where
        // the sidebar already names what you are looking at.
        window.title = "CodexMeter Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        // The rounded shape is drawn by the content; the window must stop
        // painting its own square one behind it.
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: SettingsView()
                .environmentObject(environment)
                .environmentObject(environment.claude)
        )
        window.contentMinSize = Self.minimumContentSize
        window.delegate = self
        if !window.setFrameUsingName(Self.frameAutosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(Self.frameAutosaveName)
        settingsWindow = window
        layoutTrafficLights(in: window)
        return window
    }

    /// Sit the traffic lights in the middle of the panel's header band, in from
    /// the left edge — their default place crowds them into the corner of the
    /// sidebar card. Re-run whenever the window comes forward; AppKit resets
    /// them on some window events. Ported from Codenotch.
    private func layoutTrafficLights(in window: NSWindow) {
        let buttons = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton]
            .compactMap { window.standardWindowButton($0) }
        guard let container = buttons.first?.superview else { return }
        for (index, button) in buttons.enumerated() {
            var frame = button.frame
            frame.origin.x = Self.firstLightCentreX
                + CGFloat(index) * Self.lightSpacing - frame.width / 2
            frame.origin.y = container.bounds.height
                - SettingsView.headerHeight / 2 - frame.height / 2
            button.frame = frame
        }
    }

    private static let firstLightCentreX: CGFloat = 24
    private static let lightSpacing: CGFloat = 20

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
