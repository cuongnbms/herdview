import Foundation

public enum TOMLValue: Equatable, Sendable {
    case string(String)
    case integer(Int)
    case bool(Bool)

    public var stringValue: String? { if case let .string(s) = self { return s } else { return nil } }
    public var intValue: Int? { if case let .integer(i) = self { return i } else { return nil } }
}

public struct TOMLDocument: Equatable, Sendable {
    public var root: [String: TOMLValue] = [:]
    public var tables: [String: [String: TOMLValue]] = [:]
    public var arrays: [String: [[String: TOMLValue]]] = [:]
    public init() {}
}

public enum TOMLSubsetError: Error, Equatable {
    case syntax(line: Int, String)
}

/// A deliberately small TOML reader: root keys, `[table]`, `[[array]]`, and
/// values that are basic strings, integers, or booleans. Nothing else.
public enum TOMLSubset {
    private enum Cursor {
        case root
        case table(String)
        case array(String)
    }

    public static func parse(_ text: String) throws -> TOMLDocument {
        var doc = TOMLDocument()
        var cursor = Cursor.root

        for (offset, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineNumber = offset + 1
            let line = stripComment(String(rawLine)).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("[[") {
                guard line.hasSuffix("]]") else { throw TOMLSubsetError.syntax(line: lineNumber, "unterminated [[array]]") }
                let name = String(line.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
                doc.arrays[name, default: []].append([:])
                cursor = .array(name)
                continue
            }
            if line.hasPrefix("[") {
                guard line.hasSuffix("]") else { throw TOMLSubsetError.syntax(line: lineNumber, "unterminated [table]") }
                let name = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                if doc.tables[name] == nil { doc.tables[name] = [:] }
                cursor = .table(name)
                continue
            }

            guard let eq = line.firstIndex(of: "=") else {
                throw TOMLSubsetError.syntax(line: lineNumber, "expected key = value")
            }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            let rawValue = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { throw TOMLSubsetError.syntax(line: lineNumber, "empty key") }
            let value = try parseValue(rawValue, line: lineNumber)

            switch cursor {
            case .root:
                doc.root[key] = value
            case .table(let name):
                doc.tables[name, default: [:]][key] = value
            case .array(let name):
                let last = doc.arrays[name]!.count - 1
                doc.arrays[name]![last][key] = value
            }
        }
        return doc
    }

    /// Removes a `#` comment that is not inside a double-quoted string.
    private static func stripComment(_ line: String) -> String {
        var inString = false
        var escaped = false
        var result = ""
        for ch in line {
            if inString {
                result.append(ch)
                if escaped { escaped = false } else if ch == "\\" { escaped = true } else if ch == "\"" { inString = false }
                continue
            }
            if ch == "#" { break }
            if ch == "\"" { inString = true }
            result.append(ch)
        }
        return result
    }

    private static func parseValue(_ raw: String, line: Int) throws -> TOMLValue {
        if raw == "true" { return .bool(true) }
        if raw == "false" { return .bool(false) }
        if raw.hasPrefix("\"") {
            guard raw.count >= 2, raw.hasSuffix("\"") else { throw TOMLSubsetError.syntax(line: line, "unterminated string") }
            var out = ""
            var escaped = false
            for ch in raw.dropFirst().dropLast() {
                if escaped {
                    switch ch {
                    case "n": out.append("\n")
                    case "t": out.append("\t")
                    default: out.append(ch)
                    }
                    escaped = false
                } else if ch == "\\" {
                    escaped = true
                } else {
                    out.append(ch)
                }
            }
            return .string(out)
        }
        if let i = Int(raw) { return .integer(i) }
        throw TOMLSubsetError.syntax(line: line, "unsupported value: \(raw)")
    }
}
