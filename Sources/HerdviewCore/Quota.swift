import Foundation

/// An account one coding agent CLI is signed in to on this Mac. A Provider
/// belongs to no Host: agents on every Host spend the same Quota.
public enum QuotaProvider: String, CaseIterable, Sendable {
    case claude
    case codex
    case opencodeGo
    case grok

    public var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .opencodeGo: return "OpenCode Go"
        case .grok: return "Grok"
        }
    }

    /// What to run to bring an expired sign-in back. Herdview never refreshes a
    /// token itself (ADR 0005); the CLI does it the next time it runs.
    public var signInCommand: String {
        switch self {
        case .claude: return "claude"
        case .codex: return "codex"
        case .opencodeGo: return "opencode"
        case .grok: return "grok"
        }
    }

    /// The agent family whose icon the Quota card borrows.
    public var agentKind: AgentKind {
        switch self {
        case .claude: return .claude
        case .codex: return .codex
        case .opencodeGo: return .opencode
        case .grok: return .grok
        }
    }
}

/// One limit within a Quota over a period, as the Provider reports it. Always
/// percent used, never percent remaining.
public struct QuotaWindow: Equatable, Sendable {
    public let label: String
    public let usedPercent: Double
    public let resetsAt: Date?
    /// How long the Window runs from start to Reset, when the Provider says or
    /// its kind fixes it. `nil` rather than a guess — a month has no one length.
    public let duration: TimeInterval?

    public init(label: String, usedPercent: Double, resetsAt: Date?, duration: TimeInterval? = nil) {
        self.label = label
        self.usedPercent = min(100, max(0, usedPercent))
        self.resetsAt = resetsAt
        self.duration = duration.flatMap { $0 > 0 ? $0 : nil }
    }
}

/// Every Window one Provider reported in one successful fetch.
public struct QuotaReport: Equatable, Sendable {
    public let provider: QuotaProvider
    public let windows: [QuotaWindow]
    public let fetchedAt: Date

    public init(provider: QuotaProvider, windows: [QuotaWindow], fetchedAt: Date) {
        self.provider = provider
        self.windows = windows
        self.fetchedAt = fetchedAt
    }
}
