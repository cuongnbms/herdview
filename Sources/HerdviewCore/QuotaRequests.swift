import Foundation

/// The one GET each Provider answers with its Quota. None of these endpoints is
/// documented; the URLs and headers match what each CLI sends, and each was
/// checked against a real account on 2026-09-17.
public enum QuotaRequests {
    public static let timeout: TimeInterval = 10

    public static func request(for provider: QuotaProvider, credential: QuotaCredential) -> URLRequest {
        var request: URLRequest
        switch provider {
        case .claude:
            request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            request.setValue("claude-code/2.1.0", forHTTPHeaderField: "User-Agent")
        case .codex:
            request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
            request.setValue("codex-cli", forHTTPHeaderField: "User-Agent")
            request.setValue("codex-1", forHTTPHeaderField: "OpenAI-Beta")
            request.setValue("Codex Desktop", forHTTPHeaderField: "originator")
            if let account = credential.accountId {
                request.setValue(account, forHTTPHeaderField: "ChatGPT-Account-Id")
            }
        case .opencodeGo:
            request = URLRequest(url: URL(string: "https://opencode.ai/zen/go/v1/usage")!)
        case .grok:
            request = URLRequest(url: URL(string: "https://cli-chat-proxy.grok.com/v1/billing?format=credits")!)
            request.setValue("xai-grok-cli", forHTTPHeaderField: "X-XAI-Token-Auth")
            if let user = credential.accountId {
                request.setValue(user, forHTTPHeaderField: "x-userid")
            }
        }
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
