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

    /// How far through its Window `now` is, from 0 at the start to 1 at the
    /// Reset, for the marker on the bar: a bar ahead of the marker is Quota
    /// spent faster than time. `nil` without both a Reset and a length.
    public static func elapsedFraction(resetsAt: Date?, duration: TimeInterval?, now: Date) -> Double? {
        guard let resetsAt, let duration, duration > 0 else { return nil }
        let remaining = resetsAt.timeIntervalSince(now)
        return min(1, max(0, 1 - remaining / duration))
    }

    /// The one Window a collapsed card shows for a Provider: the shortest, the
    /// one that runs out and comes back soonest. The first Window when none
    /// has a length.
    public static func summaryWindow(of windows: [QuotaWindow]) -> QuotaWindow? {
        windows.filter { $0.duration != nil }.min { $0.duration! < $1.duration! } ?? windows.first
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
