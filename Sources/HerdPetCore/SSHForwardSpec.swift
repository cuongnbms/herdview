import Foundation

/// Everything needed to spawn `ssh -N -L local:remote target`.
public struct SSHForwardSpec: Equatable, Sendable {
    public static let executable = "/usr/bin/ssh"

    public let sshTarget: String
    public let localSocketPath: String
    public let remoteSocketPath: String

    public init(sshTarget: String, localSocketPath: String, remoteSocketPath: String) {
        self.sshTarget = sshTarget
        self.localSocketPath = localSocketPath
        self.remoteSocketPath = remoteSocketPath
    }

    public var arguments: [String] {
        [
            "-N",
            "-o", "ExitOnForwardFailure=yes",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3",
            "-o", "BatchMode=yes",
            "-L", "\(localSocketPath):\(remoteSocketPath)",
            sshTarget,
        ]
    }

    /// `<baseDir>/<host>-<session>.sock` with anything outside `[A-Za-z0-9.-]`
    /// replaced by `_`. Keep `baseDir` short: macOS caps socket paths at 104 bytes.
    public static func localSocketPath(baseDir: String, host: String, session: String) -> String {
        func clean(_ s: String) -> String {
            String(s.map { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "-" || $0 == "." ? $0 : "_" })
        }
        return "\(baseDir)/\(clean(host))-\(clean(session)).sock"
    }
}
