import Foundation
import HerdviewCore

enum ProcessRunnerError: Error, CustomStringConvertible {
    case launchFailed(String)
    case nonZeroExit(Int32, String)

    var description: String {
        switch self {
        case .launchFailed(let why): return "launch failed: \(why)"
        case .nonZeroExit(let code, let stderr): return "exit \(code): \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
    }
}

/// Runs a `HostCommand` to completion off the main thread and returns stdout.
enum ProcessRunner {
    static func run(_ command: HostCommand, timeoutSeconds: Double = 20) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: command.executable)
                process.arguments = command.arguments
                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr
                process.standardInput = FileHandle.nullDevice

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: ProcessRunnerError.launchFailed(error.localizedDescription))
                    return
                }

                let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: killer)

                var errData = Data()
                let errDone = DispatchSemaphore(value: 0)
                DispatchQueue.global(qos: .utility).async {
                    errData = stderr.fileHandleForReading.readDataToEndOfFile()
                    errDone.signal()
                }
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                killer.cancel()
                errDone.wait()

                if process.terminationStatus != 0 {
                    continuation.resume(throwing: ProcessRunnerError.nonZeroExit(process.terminationStatus, String(data: errData, encoding: .utf8) ?? ""))
                } else {
                    continuation.resume(returning: outData)
                }
            }
        }
    }
}
