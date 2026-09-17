import XCTest
@testable import HerdviewCore

final class QuotaOutcomeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_789_650_000)

    private func classify(_ provider: QuotaProvider, _ status: Int, _ body: String = "",
                          retryAfter: String? = nil) -> QuotaOutcome {
        QuotaOutcome.classify(provider: provider, status: status, body: Data(body.utf8),
                              retryAfter: retryAfter, now: now)
    }

    func testA200WithWindowsIsAReport() {
        let body = #"{"usage":{"weekly":{"percent":19,"resetsAt":null}}}"#
        XCTAssertEqual(classify(.opencodeGo, 200, body),
                       .report([QuotaWindow(label: "week", usedPercent: 19, resetsAt: nil)]))
    }

    /// A 200 the parser cannot read means the endpoint changed shape. Saying so
    /// beats showing an empty row that looks like no limits at all.
    func testA200WithNothingReadableFails() {
        XCTAssertEqual(classify(.claude, 200, "{}"), .failed("unreadable response"))
    }

    func testUnauthorizedIsAnExpiredSignIn() {
        for provider in QuotaProvider.allCases {
            XCTAssertEqual(classify(provider, 401), .signInExpired, "\(provider)")
            XCTAssertEqual(classify(provider, 403), .signInExpired, "\(provider)")
        }
    }

    func testOpenCodeWithoutAGoSubscription() {
        let body = #"{"type":"error","error":{"type":"EntitlementError","message":"OpenCode Go subscription required."}}"#
        XCTAssertEqual(classify(.opencodeGo, 403, body), .noSubscription)
        XCTAssertEqual(classify(.grok, 403, body), .signInExpired)
    }

    func testRateLimitedHonoursRetryAfter() {
        XCTAssertEqual(classify(.claude, 429, retryAfter: "120"), .rateLimited(until: now.addingTimeInterval(120)))
    }

    func testRateLimitedDefaultsAndCaps() {
        XCTAssertEqual(classify(.claude, 429), .rateLimited(until: now.addingTimeInterval(15 * 60)))
        XCTAssertEqual(classify(.claude, 429, retryAfter: "Wed, 21 Oct 2026 07:28:00 GMT"),
                       .rateLimited(until: now.addingTimeInterval(15 * 60)))
        XCTAssertEqual(classify(.claude, 429, retryAfter: "0"), .rateLimited(until: now.addingTimeInterval(15 * 60)))
        XCTAssertEqual(classify(.claude, 429, retryAfter: "86400"), .rateLimited(until: now.addingTimeInterval(60 * 60)))
    }

    func testAnyOtherStatusFailsWithIt() {
        XCTAssertEqual(classify(.codex, 500), .failed("HTTP 500"))
        XCTAssertEqual(classify(.grok, 404), .failed("HTTP 404"))
    }

    /// The log line is the one place a response could leak into a log file, so
    /// every Outcome's description must be built from the outcome alone: no
    /// body text, no token, and no Window labels (which come from the body).
    func testLogDescriptionsCarryNothingFromTheBody() {
        let entitlement = #"{"type":"error","error":{"type":"EntitlementError","message":"token sk-abc123"}}"#
        XCTAssertEqual(classify(.grok, 500, "sk-abc123").logDescription, "failed: HTTP 500")
        XCTAssertEqual(classify(.claude, 200, "sk-abc123").logDescription, "failed: unreadable response")
        XCTAssertEqual(classify(.opencodeGo, 403, entitlement).logDescription, "no subscription")
        XCTAssertEqual(classify(.claude, 401).logDescription, "sign-in expired")
        XCTAssertEqual(classify(.opencodeGo, 200, #"{"usage":{"weekly":{"percent":19}}}"#).logDescription,
                       "ok, 1 window(s)")
        XCTAssertEqual(classify(.claude, 429).logDescription,
                       "rate limited until \(now.addingTimeInterval(15 * 60))")
    }
}
