import XCTest
@testable import HerdviewCore

final class QuotaRequestsTests: XCTestCase {
    private func header(_ request: URLRequest, _ name: String) -> String? {
        request.value(forHTTPHeaderField: name)
    }

    func testClaude() {
        let request = QuotaRequests.request(for: .claude, credential: QuotaCredential(token: "t"))
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/api/oauth/usage")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(header(request, "Authorization"), "Bearer t")
        XCTAssertEqual(header(request, "anthropic-beta"), "oauth-2025-04-20")
        XCTAssertEqual(header(request, "User-Agent"), "claude-code/2.1.0")
        XCTAssertEqual(request.timeoutInterval, 10)
    }

    func testCodexSendsTheAccountWhenItHasOne() {
        let request = QuotaRequests.request(for: .codex, credential: QuotaCredential(token: "t", accountId: "acct"))
        XCTAssertEqual(request.url?.absoluteString, "https://chatgpt.com/backend-api/wham/usage")
        XCTAssertEqual(header(request, "Authorization"), "Bearer t")
        XCTAssertEqual(header(request, "User-Agent"), "codex-cli")
        XCTAssertEqual(header(request, "OpenAI-Beta"), "codex-1")
        XCTAssertEqual(header(request, "originator"), "Codex Desktop")
        XCTAssertEqual(header(request, "ChatGPT-Account-Id"), "acct")

        let bare = QuotaRequests.request(for: .codex, credential: QuotaCredential(token: "t"))
        XCTAssertNil(header(bare, "ChatGPT-Account-Id"))
    }

    func testOpenCodeGo() {
        let request = QuotaRequests.request(for: .opencodeGo, credential: QuotaCredential(token: "k"))
        XCTAssertEqual(request.url?.absoluteString, "https://opencode.ai/zen/go/v1/usage")
        XCTAssertEqual(header(request, "Authorization"), "Bearer k")
    }

    func testGrokSendsTheUserWhenItHasOne() {
        let request = QuotaRequests.request(for: .grok, credential: QuotaCredential(token: "k", accountId: "u1"))
        XCTAssertEqual(request.url?.absoluteString, "https://cli-chat-proxy.grok.com/v1/billing?format=credits")
        XCTAssertEqual(header(request, "Authorization"), "Bearer k")
        XCTAssertEqual(header(request, "X-XAI-Token-Auth"), "xai-grok-cli")
        XCTAssertEqual(header(request, "Accept"), "application/json")
        XCTAssertEqual(header(request, "x-userid"), "u1")

        let bare = QuotaRequests.request(for: .grok, credential: QuotaCredential(token: "k"))
        XCTAssertNil(header(bare, "x-userid"))
    }
}
