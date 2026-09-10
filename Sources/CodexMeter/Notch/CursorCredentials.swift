import CSQLite
import Foundation

/// The session the Cursor editor keeps for itself, read from its SQLite store.
///
/// CodexMeter only ever reads it, the same bargain as Claude Code's token: the
/// editor mints and rotates it, we borrow the current value. The store is
/// opened read-only (never `immutable`, so a rotated token is not served from a
/// stale checkpoint — see `SQLiteStore`).
///
/// `/api/usage-summary` wants `WorkosCursorSessionToken={accountID}::{accessToken}`.
/// The editor stores those two halves in `state.vscdb`. A token-only cookie, or
/// a Bearer header, is 401 — the pair is required.
///
/// Ported from the MIT-licensed Codenotch (`CursorCredentials`), trimmed to the
/// editor path; the `cursor-agent` CLI fallback is a follow-up.
struct CursorCredentials {
    let accountID: String
    let accessToken: String
    /// The web API wants the pair as one cookie.
    var sessionCookie: String { "WorkosCursorSessionToken=\(accountID)::\(accessToken)" }

    static var storeURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }

    /// Minted by ToDesktop, who build Cursor — stable across updates, but not
    /// across Cursor leaving ToDesktop or rebranding. Kept here beside the store
    /// path so the two facts about a Cursor installation change together.
    static let bundleID = "com.todesktop.230313mzl4w4u92"

    /// Identity, read from the same store as the session. Non-secret: the email
    /// and plan the editor caches for its own UI.
    static func account() -> ProviderAccount? {
        account(from: storeURL)
    }

    static func account(from url: URL) -> ProviderAccount? {
        guard let db = SQLiteStore.open(url) else { return nil }
        defer { sqlite3_close(db) }
        guard let email = value(forKey: "cursorAuth/cachedEmail", in: db), !email.isEmpty else {
            return nil
        }
        return ProviderAccount(
            label: email,
            plan: value(forKey: "cursorAuth/stripeMembershipType", in: db),
            source: "Cursor",
            manageURL: URL(string: "https://cursor.com/dashboard")
        )
    }

    static func load() throws -> CursorCredentials {
        try load(from: storeURL)
    }

    /// Editor store only. The path is pinned so a missing editor cannot
    /// silently become something else.
    static func load(from url: URL) throws -> CursorCredentials {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NotchProviderError.needsAuth
        }
        guard let db = SQLiteStore.open(url) else { throw NotchProviderError.needsAuth }
        defer { sqlite3_close(db) }

        guard let token = value(forKey: "cursorAuth/accessToken", in: db), !token.isEmpty else {
            throw NotchProviderError.needsAuth
        }

        // Prefer the editor's cached WorkOS id; recent builds (Auth0 /
        // enterprise) often omit `stripeMembershipAuthId` even while signed in,
        // and the JWT `sub` is the same value the cookie needs.
        let account = value(forKey: "cursorAuth/stripeMembershipAuthId", in: db)
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? subject(fromJWT: token)
        guard let account, !account.isEmpty else { throw NotchProviderError.needsAuth }

        return CursorCredentials(accountID: account, accessToken: token)
    }

    /// Open the editor when it is installed; otherwise name the CLI command.
    static func signInRoute(editorInstalled: Bool) -> SignInRoute {
        if editorInstalled {
            return .openApp(bundleID: bundleID, name: "Cursor")
        }
        return .guidance(
            "Sign in to the Cursor editor — the notch reads that session. "
            + "`cursor-agent login` works the same way, if you use the CLI."
        )
    }

    /// `sub` claim from an unsigned JWT payload — Cursor's access token is a
    /// standard three-part JWT whose subject is the WorkOS / Auth0 user id.
    static func subject(fromJWT token: String) -> String? {
        guard let sub = claims(inJWT: token)?["sub"] as? String, !sub.isEmpty else { return nil }
        return sub
    }

    static func claims(inJWT token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)

        guard let data = Data(base64Encoded: payload) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func value(forKey key: String, in db: OpaquePointer?) -> String? {
        SQLiteStore.rows(in: db, sql: "SELECT value FROM ItemTable WHERE key = ?", bind: key).first
    }
}
