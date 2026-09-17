import Foundation

/// The words and numbers the Quota card prints.
public enum QuotaFormat {
    /// From here up a Window is drawn in the warning colour.
    public static let warningPercent: Double = 90

    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    /// Time left until a Reset: `4d`, `1d5h`, `1h36m`, `5h`, `36m`, `<1m`.
    /// A Reset already past reads `reset pending` until the next fetch brings
    /// the new Window; `nil` when the Provider gave no Reset.
    public static func untilReset(_ reset: Date?, now: Date) -> String? {
        guard let reset else { return nil }
        let seconds = Int(reset.timeIntervalSince(now))
        if seconds <= 0 { return "reset pending" }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days >= 2 { return "\(days)d" }
        if days == 1 { return hours == 0 ? "1d" : "1d\(hours)h" }
        if hours > 0 { return minutes == 0 ? "\(hours)h" : "\(hours)h\(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "<1m"
    }

    /// How old the numbers on a row with a problem are.
    public static func updatedAgo(_ fetchedAt: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(fetchedAt)))
        if seconds < 60 { return "updated just now" }
        if seconds < 3_600 { return "updated \(seconds / 60)m ago" }
        if seconds < 86_400 { return "updated \(seconds / 3_600)h ago" }
        return "updated \(seconds / 86_400)d ago"
    }
}
