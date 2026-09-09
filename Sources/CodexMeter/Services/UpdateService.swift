import AppKit
import Darwin
import Foundation
import Sparkle

@MainActor
final class UpdateService: NSObject, SPUUpdaterDelegate {
    static let shared = UpdateService()

    private var updaterController: SPUStandardUpdaterController?
    /// The app executable's file identity captured when the updater started. If it
    /// no longer matches on disk, an update was already applied and only a restart
    /// can pick it up — Sparkle would fail trying to install from the stale image.
    private var launchExecutableIdentity: ExecutableIdentity?
    private var isPromptingRestart = false

    private override init() { super.init() }

    var isAvailable: Bool {
        updaterController != nil || Self.canStartUpdater(bundle: .main)
    }

    var automaticallyChecksForUpdates: Bool {
        updaterController?.updater.automaticallyChecksForUpdates
            ?? (Bundle.main.object(forInfoDictionaryKey: "SUEnableAutomaticChecks") as? Bool ?? false)
    }

    func start() {
        guard updaterController == nil, Self.canStartUpdater(bundle: .main) else { return }
        launchExecutableIdentity = Self.currentExecutableIdentity()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        start()
        updaterController?.updater.automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() {
        start()
        if pendingUpdateNeedsRestart {
            promptRestartToFinishUpdate()
            return
        }
        updaterController?.checkForUpdates(nil)
    }

    /// True once a newer build already sits on disk (from an earlier automatic
    /// update) while this older process keeps running.
    var pendingUpdateNeedsRestart: Bool {
        Self.bundleWasReplaced(sinceLaunch: launchExecutableIdentity, current: Self.currentExecutableIdentity())
    }

    // MARK: - SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        let nsError = error as NSError
        guard nsError.domain == SUSparkleErrorDomain,
              Self.installerLaunchFailureCodes.contains(nsError.code) else { return }
        // Defer past Sparkle's own error alert and the rest of this callback so
        // our recovery prompt is the last thing the user sees, not a nested modal.
        Task { @MainActor in self.promptRestartToFinishUpdate() }
    }

    /// `SUSparkleErrorDomain` codes that mean "the download is fine, but the
    /// installer or relaunch could not be started from this running process."
    /// A clean restart resolves every one of these.
    nonisolated static let installerLaunchFailureCodes: Set<Int> = [
        Int(SUError.missingInstallerToolError.rawValue),
        Int(SUError.relaunchError.rawValue),
        Int(SUError.installationError.rawValue),
    ]

    // MARK: - Restart recovery

    private func promptRestartToFinishUpdate() {
        guard !isPromptingRestart else { return }
        isPromptingRestart = true
        defer { isPromptingRestart = false }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Restart CodexMeter to finish updating"
        alert.informativeText = "The update downloaded, but it can't be applied while CodexMeter is running — "
            + "usually because an earlier update is still waiting. Restarting now applies it."
        alert.addButton(withTitle: "Restart Now")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            Self.relaunch()
        }
    }

    /// Waits for this process to exit, then reopens the app bundle. The wait is
    /// required because the app forbids a second instance while this one lives.
    private static func relaunch() {
        let bundlePath = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        let quoted = "'" + bundlePath.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let script = "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done; exec /usr/bin/open \(quoted)"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script]
        do {
            try task.run()
        } catch {
            NSSound.beep()
            return
        }
        NSApp.terminate(nil)
    }

    // MARK: - Executable identity

    struct ExecutableIdentity: Equatable {
        let device: UInt64
        let inode: UInt64
        let modified: Int64
        let size: Int64
    }

    nonisolated static func currentExecutableIdentity() -> ExecutableIdentity? {
        guard let path = Bundle.main.executableURL?.path else { return nil }
        var info = stat()
        guard stat(path, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { return nil }
        return ExecutableIdentity(
            device: UInt64(UInt32(bitPattern: info.st_dev)),
            inode: info.st_ino,
            modified: Int64(info.st_mtimespec.tv_sec),
            size: Int64(info.st_size)
        )
    }

    /// Only reports a replacement when both readings are present and differ. A
    /// missing reading (unbundled test host, unreadable path) is never a prompt.
    nonisolated static func bundleWasReplaced(sinceLaunch launchIdentity: ExecutableIdentity?,
                                              current: ExecutableIdentity?) -> Bool {
        guard let launchIdentity, let current else { return false }
        return launchIdentity != current
    }

    // MARK: - Availability

    nonisolated static func canStartUpdater(bundle: Bundle) -> Bool {
        canStartUpdater(
            bundleURL: bundle.bundleURL,
            infoDictionary: bundle.infoDictionary ?? [:]
        )
    }

    nonisolated static func canStartUpdater(
        bundleURL: URL,
        infoDictionary: [String: Any]
    ) -> Bool {
        guard bundleURL.pathExtension == "app",
              let feed = infoDictionary["SUFeedURL"] as? String,
              let feedURL = URL(string: feed),
              feedURL.scheme == "https",
              feedURL.host != nil,
              let publicKey = infoDictionary["SUPublicEDKey"] as? String,
              !publicKey.isEmpty else {
            return false
        }
        return true
    }
}
