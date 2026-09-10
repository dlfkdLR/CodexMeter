import Foundation

/// The notch's providers by id and display name, in the order
/// `NotchController` registers them. One list so the Settings pane's
/// per-provider controls do not drift from what actually runs.
enum NotchProviderCatalog {
    static let all: [(id: String, name: String)] = [
        ("codex", "Codex"),
        ("claude", "Claude Code"),
        ("copilot", "GitHub Copilot"),
        ("cursor", "Cursor"),
        ("grok", "Grok"),
        ("opencode", "OpenCode"),
        ("commandcode", "Command Code"),
        ("glm", "GLM"),
        ("ollama", "Ollama Cloud"),
        ("gemini", "Antigravity"),
    ]
}
