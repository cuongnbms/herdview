import Foundation
import Darwin

public enum HerdrClientError: Error, Equatable, Sendable {
    /// The socket file is missing or nothing is listening on it.
    case serverNotRunning
    case transport(String)
    case timeout
}

/// One-shot request over a Unix domain socket: connect, write one line, read
/// one line, close. Blocking; call it off the main thread.
public enum HerdrSocketClient {
    private static let sunPathCapacity = 104

    public static func exchange(line: Data, socketPath: String, timeoutSeconds: Int = 3) throws -> Data {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw HerdrClientError.transport("socket(): \(String(cString: strerror(errno)))") }
        defer { close(fd) }

        var timeout = timeval(tv_sec: timeoutSeconds, tv_usec: 0)
        let tvSize = socklen_t(MemoryLayout<timeval>.size)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, tvSize)
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, tvSize)
        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))

        guard socketPath.utf8.count < sunPathCapacity else {
            throw HerdrClientError.transport("socket path too long: \(socketPath)")
        }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: sunPathCapacity) { _ = strncpy($0, socketPath, sunPathCapacity - 1) }
        }
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, addrLen) }
        }
        if connected != 0 {
            let code = errno
            if code == ENOENT || code == ECONNREFUSED { throw HerdrClientError.serverNotRunning }
            throw HerdrClientError.transport("connect(): \(String(cString: strerror(code)))")
        }

        var sent = 0
        try line.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            while sent < line.count {
                let n = write(fd, raw.baseAddress! + sent, line.count - sent)
                if n <= 0 {
                    let code = errno
                    if code == EAGAIN || code == EWOULDBLOCK { throw HerdrClientError.timeout }
                    throw HerdrClientError.transport("write(): \(String(cString: strerror(code)))")
                }
                sent += n
            }
        }

        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 65_536)
        while true {
            let n = read(fd, &chunk, chunk.count)
            if n < 0 {
                let code = errno
                if code == EAGAIN || code == EWOULDBLOCK { throw HerdrClientError.timeout }
                throw HerdrClientError.transport("read(): \(String(cString: strerror(code)))")
            }
            if n == 0 { break }
            buffer.append(chunk, count: n)
            if let newline = buffer.firstIndex(of: 0x0A) {
                return buffer.prefix(upTo: newline)
            }
        }
        guard !buffer.isEmpty else { throw HerdrClientError.transport("connection closed before a response") }
        return buffer
    }
}
