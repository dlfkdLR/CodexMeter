import Foundation

/// Reads Ollama Cloud usage from `https://ollama.com/api/usage`, authenticating
/// with `OLLAMA_API_KEY` from the environment. No key, no ring.
///
/// Codenotch also lets the user paste a key into Settings (stored in the login
/// keychain) and monitors a local `ollama serve` model listing; both are
/// follow-ups here — the first needs a keychain helper, the second a data model
/// the notch does not carry.
///
/// Ported from the MIT-licensed Codenotch (`OllamaProvider`).
@MainActor
final class OllamaNotchProvider: NotchProvider {
    let id = "ollama"
    let displayName = "Ollama"
    let glyph: ProviderGlyph = .ollama
    var isVisibleWhenAbsent: Bool { false }

    private let endpoint = URL(string: "https://ollama.com/api/usage")!
    private let session: URLSession
    private let key: @Sendable () -> String?

    init(session: URLSession = .shared,
         key: (@Sendable () -> String?)? = nil) {
        self.session = session
        self.key = key ?? { OllamaCredentials.load() }
    }

    var signInRoute: SignInRoute {
        .guidance("Export OLLAMA_API_KEY in your shell — the notch reads it.")
    }

    func account() -> ProviderAccount? {
        guard key() != nil else { return nil }
        return ProviderAccount(label: nil, plan: nil, source: "Ollama",
                               manageURL: URL(string: "https://ollama.com/settings"))
    }

    func fetchSnapshot() async throws -> ProviderSnapshot {
        guard let key = key() else { throw NotchProviderError.needsAuth }

        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { throw NotchProviderError.needsAuth }
        guard (200..<300).contains(status) else {
            throw NotchProviderError.badResponse(status: status)
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        NotchLog.usage.debug("ollama usage -> \(body.prefix(900), privacy: .public)")

        let result = try OllamaUsage.parse(body)
        return ProviderSnapshot(
            id: id, displayName: displayName, glyph: glyph,
            fidelity: .official, status: .ok,
            windows: result.windows, headlineID: result.headlineID
        )
    }
}

/// The Ollama Cloud API key. Environment only for now — a keychain-stored key
/// entered in Settings is a follow-up.
enum OllamaCredentials {
    static func load() -> String? {
        guard let env = ProcessInfo.processInfo.environment["OLLAMA_API_KEY"], !env.isEmpty
        else { return nil }
        return env
    }

    static var isPresent: Bool { load() != nil }
}
