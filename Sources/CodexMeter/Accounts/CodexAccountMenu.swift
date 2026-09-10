import AppKit

/// The Codex account switcher as an `NSMenu` item — the same "switch, add,
/// manage" the menu-bar popover used to carry, so it is reachable from the
/// notch's context menu and the status-bar menu now that the popover is gone.
@MainActor
enum CodexAccountMenu {
    /// A "Codex Account" submenu item: the saved logins (checkmark on the
    /// active one), then Add / Manage. Switching quits and reopens Codex, so it
    /// asks first.
    static func item(store: CodexAccountStore = .shared) -> NSMenuItem {
        store.load()
        let root = NSMenuItem(title: "Codex Account", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        if store.accounts.isEmpty {
            let none = NSMenuItem(title: "No saved accounts", action: nil, keyEquivalent: "")
            none.isEnabled = false
            submenu.addItem(none)
        } else {
            for account in store.accounts {
                let item = NSMenuItem(
                    title: account.menuTitle(in: store.accounts),
                    action: #selector(Target.switchTo(_:)),
                    keyEquivalent: ""
                )
                item.state = account.id == store.currentID ? .on : .off
                item.isEnabled = !store.isBusy && account.id != store.currentID
                item.representedObject = account.id
                item.target = target
                submenu.addItem(item)
            }
        }

        submenu.addItem(.separator())

        if store.currentID == nil, !store.accounts.isEmpty {
            let save = NSMenuItem(title: "Save Current Account",
                                  action: #selector(Target.saveCurrent), keyEquivalent: "")
            save.target = target
            save.isEnabled = !store.isBusy
            submenu.addItem(save)
        }

        let add = NSMenuItem(title: "Add Account…", action: #selector(Target.addAccount), keyEquivalent: "")
        add.target = target
        add.isEnabled = !store.isBusy && !store.isSigningIn
        submenu.addItem(add)

        let manage = NSMenuItem(title: "Manage Accounts…", action: #selector(Target.manage), keyEquivalent: "")
        manage.target = target
        submenu.addItem(manage)

        root.submenu = submenu
        return root
    }

    private static let target = Target()

    /// Menu items need an Objective-C target.
    private final class Target: NSObject {
        @MainActor @objc func switchTo(_ sender: NSMenuItem) {
            guard let id = sender.representedObject as? String else { return }
            let store = CodexAccountStore.shared
            let name = store.accounts.first { $0.id == id }?.menuTitle(in: store.accounts) ?? "this account"
            let alert = NSAlert()
            alert.messageText = "Switch Codex account?"
            alert.informativeText = "Codex will quit and reopen as \(name). Finish any running tasks and save your work first — other Codex processes must also be closed."
            alert.addButton(withTitle: "Quit Codex & Switch")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            Task { await store.switchAccount(to: id) }
        }

        @MainActor @objc func saveCurrent() {
            Task { await CodexAccountStore.shared.saveCurrent() }
        }

        @MainActor @objc func addAccount() {
            CodexAccountsWindowController.shared.show()
            CodexAccountStore.shared.addAccount()
        }

        @MainActor @objc func manage() {
            CodexAccountsWindowController.shared.show()
        }
    }
}
