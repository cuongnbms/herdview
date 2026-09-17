import Foundation

/// The four Providers spell a Reset three ways: ISO-8601 with up to six
/// fractional digits and a `Z` or an offset, epoch seconds, and epoch
/// milliseconds. Every parser turns them into a `Date` here, so nothing past
/// the parsers ever sees the difference.
public enum QuotaDates {
    /// `ISO8601DateFormatter` accepts fractional seconds only with exactly
    /// three digits, so the fraction is cut off, parsed separately, and added
    /// back.
    public static func parse(iso text: String) -> Date? {
        var whole = text
        var fraction = 0.0
        if let dot = text.firstIndex(of: "."), let tee = text.firstIndex(of: "T"), dot > tee {
            let digits = text[text.index(after: dot)...].prefix { $0.isNumber }
            fraction = Double("0." + digits) ?? 0
            whole = String(text[..<dot]) + String(text[text.index(after: dot)...].dropFirst(digits.count))
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: whole).map { $0.addingTimeInterval(fraction) }
    }

    /// Epoch seconds, or milliseconds when the value is too large to be seconds.
    public static func parse(epoch value: Double) -> Date {
        Date(timeIntervalSince1970: value > 1e10 ? value / 1000 : value)
    }

    /// A JSON value that may be an ISO string, a numeric string, or a number.
    public static func parse(any value: Any?) -> Date? {
        if let number = jsonNumber(value) {
            return parse(epoch: number)
        }
        guard let text = value as? String, !text.isEmpty else { return nil }
        if let number = Double(text) {
            return parse(epoch: number)
        }
        return parse(iso: text)
    }

    /// A JSON number, but not a JSON boolean. `JSONSerialization` hands both
    /// back as `NSNumber`, and `is Bool` cannot tell them apart: a `0` or a `1`
    /// passes it. Only the CoreFoundation type ID says which one the JSON held.
    static func jsonNumber(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return number.doubleValue
    }
}
