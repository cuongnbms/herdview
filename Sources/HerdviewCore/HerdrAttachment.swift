import Foundation

/// A Herdr client running in a terminal on this Mac: the tty it runs on and the
/// Session it shows. It is how a Jump learns which Terminal Tab holds which
/// Session — neither cmux nor Herdr records that link, but the client's own
/// arguments do.
public struct HerdrAttachment: Equatable, Sendable {
    public let tty: String
    /// The ssh target after `--remote`, or nil for a Session on this Mac.
    public let remote: String?
    public let session: String

    public init(tty: String, remote: String?, session: String) {
        self.tty = tty
        self.remote = remote
        self.session = session
    }

    /// Every process with its terminal, one per line: `ttys004 herdr --session x`.
    public static let listCommand = HostCommand(executable: "/bin/ps", arguments: ["-axo", "tty=,args="])

    /// One line of `listCommand`'s output, or nil when it is not a Herdr client.
    ///
    /// A client is `herdr` with nothing but `--remote` and `--session`, or
    /// `herdr session attach <name>`. Everything else Herdr runs — `herdr
    /// client`, `herdr server`, `remote-client-bridge`, `herdr agent list` — is a
    /// helper or a one-shot command, not a tab showing a Session.
    public static func parse(psLine: String) -> HerdrAttachment? {
        let fields = psLine.split(whereSeparator: \.isWhitespace).map(String.init)
        guard fields.count >= 2, fields[0] != "??" else { return nil }
        guard (fields[1] as NSString).lastPathComponent == "herdr" else { return nil }

        var remote: String?
        var session: String?
        var positional: [String] = []
        var rest = fields.dropFirst(2)
        while let arg = rest.popFirst() {
            switch arg {
            case "--remote":
                guard let value = rest.popFirst() else { return nil }
                remote = value
            case "--session":
                guard let value = rest.popFirst() else { return nil }
                session = value
            default:
                if arg.hasPrefix("-") { return nil }
                positional.append(arg)
            }
        }

        if positional.isEmpty {
            return HerdrAttachment(tty: fields[0], remote: remote, session: session ?? "default")
        }
        if positional.count == 3, positional[0] == "session", positional[1] == "attach",
           remote == nil, session == nil {
            return HerdrAttachment(tty: fields[0], remote: nil, session: positional[2])
        }
        return nil
    }
}
