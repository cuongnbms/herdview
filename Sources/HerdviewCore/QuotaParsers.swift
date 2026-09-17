import Foundation

/// Turns each Provider's usage response into Windows.
///
/// Every endpoint is undocumented and can change without notice, so parsing is
/// lenient: a Window that cannot be read is skipped rather than failing the
/// rest. An empty result means nothing could be read at all.
public enum QuotaParsers {
    static let fiveHours: TimeInterval = 18_000
    static let week: TimeInterval = 604_800

    public static func windows(for provider: QuotaProvider, from data: Data) -> [QuotaWindow] {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [] }
        switch provider {
        case .claude: return claude(json)
        case .codex: return codex(json)
        case .opencodeGo: return opencodeGo(json)
        case .grok: return grok(json)
        }
    }

    // MARK: Claude

    /// `limits[]` is the current shape and the only one that carries the
    /// per-model weekly limits. `five_hour` and `seven_day` are the older shape,
    /// read only when `limits` yields nothing.
    private static func claude(_ json: [String: Any]) -> [QuotaWindow] {
        var windows: [QuotaWindow] = []
        for limit in json["limits"] as? [[String: Any]] ?? [] {
            guard let percent = number(limit["percent"]) else { continue }
            let label: String
            let duration: TimeInterval
            switch limit["kind"] as? String {
            case "session":
                (label, duration) = ("5h", fiveHours)
            case "weekly_all":
                (label, duration) = ("week", week)
            case "weekly_scoped":
                let scope = limit["scope"] as? [String: Any]
                let model = scope?["model"] as? [String: Any]
                guard let name = model?["display_name"] as? String, !name.isEmpty else { continue }
                (label, duration) = ("week · \(name)", week)
            default:
                continue
            }
            windows.append(QuotaWindow(label: label, usedPercent: percent,
                                       resetsAt: QuotaDates.parse(any: limit["resets_at"]), duration: duration))
        }
        if !windows.isEmpty { return windows }

        for (key, label, duration) in [("five_hour", "5h", fiveHours), ("seven_day", "week", week)] {
            guard let window = json[key] as? [String: Any],
                  let percent = number(window["utilization"]) ?? number(window["used_percentage"]) else { continue }
            windows.append(QuotaWindow(label: label, usedPercent: percent,
                                       resetsAt: QuotaDates.parse(any: window["resets_at"]), duration: duration))
        }
        return windows
    }

    // MARK: Codex

    /// The plan's own limits only. `additional_rate_limits` (per-model limits
    /// such as Spark) are deliberately left out.
    private static func codex(_ json: [String: Any]) -> [QuotaWindow] {
        guard let limits = json["rate_limit"] as? [String: Any] else { return [] }
        return ["primary_window", "secondary_window"].compactMap { key in
            guard let window = limits[key] as? [String: Any],
                  let percent = number(window["used_percent"]) else { return nil }
            let seconds = number(window["limit_window_seconds"])
            return QuotaWindow(label: durationLabel(seconds: seconds),
                               usedPercent: percent,
                               resetsAt: number(window["reset_at"]).map(QuotaDates.parse(epoch:)),
                               duration: seconds)
        }
    }

    /// `5h` and `week` for the two windows plans have today; anything else as a
    /// compact duration, so a new window still gets an honest name.
    static func durationLabel(seconds: Double?) -> String {
        guard let seconds, seconds > 0 else { return "limit" }
        let whole = Int(seconds.rounded())
        switch whole {
        case 18_000: return "5h"
        case 604_800: return "week"
        default:
            if whole % 86_400 == 0 { return "\(whole / 86_400)d" }
            if whole % 3_600 == 0 { return "\(whole / 3_600)h" }
            return "\(max(1, whole / 60))m"
        }
    }

    // MARK: OpenCode Go

    private static func opencodeGo(_ json: [String: Any]) -> [QuotaWindow] {
        guard let usage = json["usage"] as? [String: Any] else { return [] }
        let kinds: [(String, String, TimeInterval?)] = [("rolling", "5h", fiveHours), ("weekly", "week", week),
                                                         ("monthly", "month", nil)]
        return kinds.compactMap { key, label, duration in
            guard let window = usage[key] as? [String: Any],
                  let percent = number(window["percent"]) else { return nil }
            return QuotaWindow(label: label, usedPercent: percent,
                               resetsAt: QuotaDates.parse(any: window["resetsAt"]), duration: duration)
        }
    }

    // MARK: Grok

    /// One Window for the current billing period. proto3 JSON leaves out a
    /// field whose value is zero, so an *absent* `creditUsagePercent` with a
    /// period is a period with nothing used yet. A present but non-numeric
    /// value is malformed rather than zero: reading it as 0% would claim credit
    /// the response does not support, so no Window is produced.
    private static func grok(_ json: [String: Any]) -> [QuotaWindow] {
        let config = json["config"] as? [String: Any] ?? json
        let period = config["currentPeriod"] as? [String: Any]
        let percent: Double
        if let raw = config["creditUsagePercent"] {
            guard let parsed = number(raw) else { return [] }
            percent = parsed
        } else if period != nil {
            percent = 0
        } else {
            return []
        }
        let label: String
        switch period?["type"] as? String {
        case "USAGE_PERIOD_TYPE_WEEKLY": label = "week"
        case "USAGE_PERIOD_TYPE_MONTHLY": label = "month"
        default: label = "period"
        }
        // Start and end are taken as a pair, so a length is never measured
        // from one period's start to another period's end.
        let bounds = [(period?["start"], period?["end"]), (config["billingPeriodStart"], config["billingPeriodEnd"])]
        let reset = bounds.lazy.compactMap { QuotaDates.parse(any: $0.1) }.first
        let duration = bounds.lazy.compactMap { start, end -> TimeInterval? in
            guard let start = QuotaDates.parse(any: start), let end = QuotaDates.parse(any: end) else { return nil }
            return end.timeIntervalSince(start)
        }.first
        return [QuotaWindow(label: label, usedPercent: percent, resetsAt: reset, duration: duration)]
    }

    // MARK: -

    private static func number(_ value: Any?) -> Double? {
        QuotaDates.jsonNumber(value)
    }
}
