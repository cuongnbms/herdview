import XCTest
@testable import HerdviewCore

/// Fixtures are real responses from 2026-09-17, trimmed, with every
/// identifier removed.
final class QuotaParsersTests: XCTestCase {
    private func windows(_ provider: QuotaProvider, _ json: String) -> [QuotaWindow] {
        QuotaParsers.windows(for: provider, from: Data(json.utf8))
    }

    private func date(_ seconds: Double) -> Date { Date(timeIntervalSince1970: seconds) }

    // MARK: Claude

    private let claudeResponse = #"""
    {"five_hour":{"utilization":16.0,"resets_at":"2026-09-17T14:00:00.996301+00:00"},
     "seven_day":{"utilization":28.0,"resets_at":"2026-09-22T02:00:00.996324+00:00"},
     "seven_day_opus":null,
     "extra_usage":{"is_enabled":false,"utilization":null},
     "limits":[
      {"kind":"session","group":"session","percent":19,"severity":"normal","resets_at":"2026-09-17T14:00:00+00:00","scope":null,"is_active":false},
      {"kind":"weekly_all","group":"weekly","percent":28,"severity":"normal","resets_at":"2026-09-22T02:00:00+00:00","scope":null,"is_active":true},
      {"kind":"weekly_scoped","group":"weekly","percent":10,"severity":"normal","resets_at":"2026-09-22T01:59:59+00:00","scope":{"model":{"id":null,"display_name":"Fable"},"surface":null},"is_active":false}
     ]}
    """#

    func testClaudeReadsLimitsIncludingPerModelWeeks() {
        XCTAssertEqual(windows(.claude, claudeResponse), [
            QuotaWindow(label: "5h", usedPercent: 19, resetsAt: date(1_789_653_600)),
            QuotaWindow(label: "week", usedPercent: 28, resetsAt: date(1_790_042_400)),
            QuotaWindow(label: "week · Fable", usedPercent: 10, resetsAt: date(1_790_042_399)),
        ])
    }

    func testClaudeSkipsUnknownKindsAndScopedLimitsWithoutAModelName() {
        let json = #"""
        {"limits":[
          {"kind":"session","percent":5,"resets_at":null},
          {"kind":"daily_mystery","percent":50,"resets_at":null},
          {"kind":"weekly_scoped","percent":7,"resets_at":null,"scope":{"model":null}}
        ]}
        """#
        XCTAssertEqual(windows(.claude, json), [QuotaWindow(label: "5h", usedPercent: 5, resetsAt: nil)])
    }

    func testClaudeFallsBackToTheOlderShapeWithoutLimits() {
        let json = #"""
        {"five_hour":{"utilization":16.0,"resets_at":"2026-09-17T14:00:00.996301+00:00"},
         "seven_day":{"utilization":28.0,"resets_at":"2026-09-22T02:00:00.996324+00:00"}}
        """#
        let result = windows(.claude, json)
        XCTAssertEqual(result.map(\.label), ["5h", "week"])
        XCTAssertEqual(result.map(\.usedPercent), [16, 28])
        XCTAssertEqual(result[0].resetsAt?.timeIntervalSince1970 ?? 0, 1_789_653_600.996, accuracy: 0.001)
    }

    // MARK: Codex

    private let codexResponse = #"""
    {"plan_type":"prolite",
     "rate_limit":{"allowed":true,"limit_reached":false,
       "primary_window":{"used_percent":0,"limit_window_seconds":604800,"reset_after_seconds":602704,"reset_at":1790250529},
       "secondary_window":null},
     "additional_rate_limits":[{"limit_name":"GPT-5.3-Codex-Spark","rate_limit":{
       "primary_window":{"used_percent":40,"limit_window_seconds":18000,"reset_at":1789665826}}}]}
    """#

    func testCodexReadsThePlanWindowAndIgnoresPerModelLimits() {
        XCTAssertEqual(windows(.codex, codexResponse), [
            QuotaWindow(label: "week", usedPercent: 0, resetsAt: date(1_790_250_529)),
        ])
    }

    func testCodexReadsBothWindows() {
        let json = #"""
        {"rate_limit":{
          "primary_window":{"used_percent":42.5,"limit_window_seconds":18000,"reset_at":1789665826},
          "secondary_window":{"used_percent":12,"limit_window_seconds":604800,"reset_at":1790250529}}}
        """#
        XCTAssertEqual(windows(.codex, json), [
            QuotaWindow(label: "5h", usedPercent: 42.5, resetsAt: date(1_789_665_826)),
            QuotaWindow(label: "week", usedPercent: 12, resetsAt: date(1_790_250_529)),
        ])
    }

    func testDurationLabels() {
        XCTAssertEqual(QuotaParsers.durationLabel(seconds: 18_000), "5h")
        XCTAssertEqual(QuotaParsers.durationLabel(seconds: 604_800), "week")
        XCTAssertEqual(QuotaParsers.durationLabel(seconds: 172_800), "2d")
        XCTAssertEqual(QuotaParsers.durationLabel(seconds: 10_800), "3h")
        XCTAssertEqual(QuotaParsers.durationLabel(seconds: 5_400), "90m")
        XCTAssertEqual(QuotaParsers.durationLabel(seconds: nil), "limit")
    }

    // MARK: OpenCode Go

    func testOpenCodeGoReadsRollingWeeklyAndMonthly() {
        let json = #"""
        {"usage":{"rolling":{"status":"ok","percent":0,"resetsAt":"2026-09-17T17:23:46.000Z"},
                  "weekly":{"status":"ok","percent":19,"resetsAt":"2026-09-21T00:00:00.000Z"},
                  "monthly":{"status":"rate-limited","percent":100,"resetsAt":"2026-10-17T01:46:02.000Z"}}}
        """#
        XCTAssertEqual(windows(.opencodeGo, json), [
            QuotaWindow(label: "5h", usedPercent: 0, resetsAt: date(1_789_665_826)),
            QuotaWindow(label: "week", usedPercent: 19, resetsAt: date(1_789_948_800)),
            QuotaWindow(label: "month", usedPercent: 100, resetsAt: date(1_792_201_562)),
        ])
    }

    // MARK: Grok

    func testGrokReadsTheWeeklyCreditPeriod() {
        let json = #"""
        {"config":{"currentPeriod":{"type":"USAGE_PERIOD_TYPE_WEEKLY","start":"2026-09-13T01:30:30.900554+00:00","end":"2026-09-20T01:30:30+00:00"},
          "creditUsagePercent":100.0,"onDemandCap":{"val":0},"isUnifiedBillingUser":true,
          "billingPeriodStart":"2026-09-13T01:30:30.900554+00:00","billingPeriodEnd":"2026-09-20T01:30:30.900554+00:00"}}
        """#
        XCTAssertEqual(windows(.grok, json), [
            QuotaWindow(label: "week", usedPercent: 100, resetsAt: date(1_789_867_830)),
        ])
    }

    /// proto3 JSON drops zero values: a period without a percent is 0% used.
    func testGrokWithoutAPercentButWithAPeriodIsZero() {
        let json = #"""
        {"config":{"currentPeriod":{"type":"USAGE_PERIOD_TYPE_MONTHLY","end":"2026-09-20T01:30:30+00:00"}}}
        """#
        XCTAssertEqual(windows(.grok, json), [
            QuotaWindow(label: "month", usedPercent: 0, resetsAt: date(1_789_867_830)),
        ])
    }

    /// A present-but-malformed percent is not an omitted proto3 zero: reading
    /// it as 0% would report availability the response does not support.
    func testGrokWithAPeriodButAMalformedPercentHasNoWindow() {
        for malformed in ["true", "null", "\"100\""] {
            let json = #"""
            {"config":{"currentPeriod":{"type":"USAGE_PERIOD_TYPE_WEEKLY","end":"2026-09-20T01:30:30+00:00"},
              "creditUsagePercent":\#(malformed)}}
            """#
            XCTAssertEqual(windows(.grok, json), [], malformed)
        }
    }

    func testGrokFallsBackToTheBillingPeriodEnd() {
        let json = #"{"creditUsagePercent":3,"billingPeriodEnd":"2026-09-20T01:30:30Z"}"#
        XCTAssertEqual(windows(.grok, json), [
            QuotaWindow(label: "period", usedPercent: 3, resetsAt: date(1_789_867_830)),
        ])
    }

    func testGrokWithNeitherPercentNorPeriodHasNoWindow() {
        XCTAssertEqual(windows(.grok, #"{"config":{"prepaidBalance":{"val":0}}}"#), [])
    }

    // MARK: Shared

    func testPercentIsClampedAndBooleansAreNotNumbers() {
        let json = #"""
        {"usage":{"rolling":{"percent":130,"resetsAt":null},
                  "weekly":{"percent":-4,"resetsAt":null},
                  "monthly":{"percent":true,"resetsAt":null}}}
        """#
        XCTAssertEqual(windows(.opencodeGo, json), [
            QuotaWindow(label: "5h", usedPercent: 100, resetsAt: nil),
            QuotaWindow(label: "week", usedPercent: 0, resetsAt: nil),
        ])
    }

    func testUnreadableBodiesHaveNoWindows() {
        for provider in QuotaProvider.allCases {
            XCTAssertEqual(windows(provider, "<html>"), [], "\(provider)")
            XCTAssertEqual(windows(provider, "{}"), [], "\(provider)")
        }
    }
}
