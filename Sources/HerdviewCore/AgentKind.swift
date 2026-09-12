import Foundation

/// Agent families Herdview has an icon for. Case names match AgentPet's so the
/// copied `AgentIcons.swift` compiles unchanged.
public enum AgentKind: String, Sendable, CaseIterable, Equatable {
    case claude
    case codex
    case gemini
    case cursor
    case opencode
    case windsurf
    case antigravity
    case copilot
    case kiroCLI
    case droid
    case pi
    case grok
    case cli
    case unknown

    /// Maps Herdr's `agent` label (its `--kind` vocabulary) to a kind.
    public static func from(label: String?) -> AgentKind {
        switch label?.lowercased() {
        case "claude", "claude-code": return .claude
        case "codex": return .codex
        case "gemini": return .gemini
        case "cursor": return .cursor
        case "opencode": return .opencode
        case "windsurf": return .windsurf
        case "cli": return .cli
        case "copilot", "github-copilot": return .copilot
        case "kiro": return .kiroCLI
        case "droid": return .droid
        case "pi": return .pi
        case "grok": return .grok
        case "agy", "antigravity", "antigravity-cli": return .antigravity
        default: return .unknown
        }
    }
}
