import XCTest
@testable import HerdviewCore

final class QuotaCredentialsTests: XCTestCase {
    private func parse(_ provider: QuotaProvider, _ json: String) -> QuotaCredential? {
        QuotaCredentials.parse(provider, Data(json.utf8))
    }

    func testClaudeReadsTheAccessTokenFromTheKeychainJSON() {
        let json = #"{"claudeAiOauth":{"accessToken":"sk-ant-oat","refreshToken":"r","expiresAt":1}}"#
        XCTAssertEqual(parse(.claude, json), QuotaCredential(token: "sk-ant-oat"))
    }

    func testCodexReadsTokenAndAccount() {
        let json = #"{"auth_mode":"chatgpt","tokens":{"access_token":"eyJ","account_id":"acct-1","refresh_token":"r"}}"#
        XCTAssertEqual(parse(.codex, json), QuotaCredential(token: "eyJ", accountId: "acct-1"))
    }

    func testCodexWithoutAccountStillHasAToken() {
        let json = #"{"tokens":{"access_token":"eyJ"}}"#
        XCTAssertEqual(parse(.codex, json), QuotaCredential(token: "eyJ", accountId: nil))
    }

    /// An API-key login leaves `tokens` out; that is not a plan with a Quota.
    func testCodexWithAnAPIKeyOnlyIsNotSignedIn() {
        XCTAssertNil(parse(.codex, #"{"OPENAI_API_KEY":"sk-proj"}"#))
    }

    /// OpenCode's file holds every provider it knows; only the Go key matters.
    func testOpenCodeGoReadsOnlyTheGoKey() {
        let json = #"{"nvidia":{"type":"api","key":"nv"},"opencode-go":{"type":"api","key":"go-key"}}"#
        XCTAssertEqual(parse(.opencodeGo, json), QuotaCredential(token: "go-key"))
        XCTAssertNil(parse(.opencodeGo, #"{"nvidia":{"type":"api","key":"nv"}}"#))
    }

    func testGrokPrefersXAIsIssuerWithAnIdSuffix() {
        let json = #"""
        {"https://other.example":{"key":"other","user_id":"u0"},
         "https://auth.x.ai::b1a0":{"key":"xai","user_id":"u1"}}
        """#
        XCTAssertEqual(parse(.grok, json), QuotaCredential(token: "xai", accountId: "u1"))
    }

    func testGrokFallsBackToAnotherIssuer() {
        let json = #"{"https://other.example":{"key":"other"}}"#
        XCTAssertEqual(parse(.grok, json), QuotaCredential(token: "other", accountId: nil))
    }

    func testEmptyTokensAndMalformedFilesAreNotSignedIn() {
        XCTAssertNil(parse(.claude, #"{"claudeAiOauth":{"accessToken":""}}"#))
        XCTAssertNil(parse(.codex, "not json"))
        XCTAssertNil(parse(.grok, "[]"))
    }

    func testFilePaths() {
        XCTAssertNil(QuotaCredentials.filePath(for: .claude, home: "/Users/me"))
        XCTAssertEqual(QuotaCredentials.filePath(for: .codex, home: "/Users/me"), "/Users/me/.codex/auth.json")
        XCTAssertEqual(QuotaCredentials.filePath(for: .opencodeGo, home: "/Users/me"), "/Users/me/.local/share/opencode/auth.json")
        XCTAssertEqual(QuotaCredentials.filePath(for: .grok, home: "/Users/me"), "/Users/me/.grok/auth.json")
    }
}
