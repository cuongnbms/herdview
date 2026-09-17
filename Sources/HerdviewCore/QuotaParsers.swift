import Foundation

/// Turns each Provider's usage response into Windows.
///
/// Every endpoint is undocumented and can change without notice, so parsing is
/// lenient: a Window that cannot be read is skipped rather than failing the
/// rest. An empty result means nothing could be read at all.
public enum QuotaParsers {
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
            switch limit["kind"] as? String {
            case "session":
                label = "5h"
            case "weekly_all":
                label = "week"
            case "weekly_scoped":
                let scope = limit["scope"] as? [String: Any]
                let model = scope?["model"] as? [String: Any]
                guard let name = model?["display_name"] as? String, !name.isEmpty else { continue }
                label = "week · \(name)"
            default:
                continue
            }
            windows.append(QuotaWindow(label: label, usedPercent: percent,
                                       resetsAt: QuotaDates.parse(any: limit["resets_at"])))
        }
        if !windows.isEmpty { return windows }

        for (key, label) in [("five_hour", "5h"), ("seven_day", "week")] {
            guard let window = json[key] as? [String: Any],
                  let percent = number(window["utilization"]) ?? number(window["used_percentage"]) else { continue }
            windows.append(QuotaWindow(label: label, usedPercent: percent,
                                       resetsAt: QuotaDates.parse(any: window["resets_at"])))
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
            return QuotaWindow(label: durationLabel(seconds: number(window["limit_window_seconds"])),
                               usedPercent: percent,
                               resetsAt: number(window["reset_at"]).map(QuotaDates.parse(epoch:)))
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
        return [("rolling", "5h"), ("weekly", "week"), ("monthly", "month")].compactMap { key, label in
            guard let window = usage[key] as? [String: Any],
                  let percent = number(window["percent"]) else { return nil }
            return QuotaWindow(label: label, usedPercent: percent,
                               resetsAt: QuotaDates.parse(any: window["resetsAt"]))
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
        let reset = QuotaDates.parse(any: period?["end"]) ?? QuotaDates.parse(any: config["billingPeriodEnd"])
        return [QuotaWindow(label: label, usedPercent: percent, resetsAt: reset)]
    }

    // MARK: -

    private static func number(_ value: Any?) -> Double? {
        QuotaDates.jsonNumber(value)
    }
}
