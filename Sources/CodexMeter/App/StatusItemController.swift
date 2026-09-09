import AppKit

/// The one always-present entry point once the menu-bar popover is gone: a
/// small status-bar item whose menu reaches Settings, the Usage window, and the
/// notch toggle. Everything the popover's footer used to offer, minus the
/// popover itself — the readings live in the notch and the Usage pane now.
///
/// Deliberately a plain `NSMenu`, not a second `MenuBarExtra`: a menu costs
/// almost nothing when closed, and the notch is where a glanceable reading is
/// meant to be.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem?

    private override init() { super.init() }

    /// Called once from `AppDelegate.applicationDidFinishLaunching`.
    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "diamond",
            accessibilityDescription: "CodexMeter"
        )
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        // Manage `isEnabled` directly (the updates item) rather than through
        // menu validation — there is no responder chain to validate against.
        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.autoenablesItems = false
        menu.removeAllItems()

        let notchItem = NSMenuItem(
            title: "Show Notch",
            action: #selector(toggleNotch),
            keyEquivalent: ""
        )
        notchItem.target = self
        notchItem.state = notchIsOn ? .on : .off
        menu.addItem(notchItem)

        menu.addItem(.separator())

        let usageItem = NSMenuItem(title: "Usage…", action: #selector(openUsage), keyEquivalent: "")
        usageItem.target = self
        menu.addItem(usageItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updatesItem.target = self
        updatesItem.isEnabled = UpdateService.shared.isAvailable
        menu.addItem(updatesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit CodexMeter",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
    }

    private var notchIsOn: Bool {
        UserDefaults.standard.object(forKey: "showEdgeNotch") as? Bool
            ?? AppPreferences.defaultShowEdgeNotch
    }

    @objc private func toggleNotch() {
        let next = !notchIsOn
        UserDefaults.standard.set(next, forKey: "showEdgeNotch")
        NotchController.shared.setVisible(next)
    }

    @objc private func openUsage() {
        SettingsWindowController.shared.present(selecting: .category(.usage))
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.present()
    }

    @objc private func checkForUpdates() {
        UpdateService.shared.checkForUpdates()
    }
}
