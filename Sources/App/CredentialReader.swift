import Foundation
import HerdviewCore

enum CredentialLookup {
    case found(QuotaCredential)
    case notSignedIn
    case failed(String)
}

/// Reads the credential each CLI stores on this Mac. Read-only (ADR 0005).
///
/// Nothing read here is ever logged. That is also why Claude's Keychain item is
/// not read through `ProcessRunner`: it folds a failed command's output into
/// its error, and callers log errors — here that output is a token.
enum CredentialReader {
    /// `security` exits with this when the item does not exist.
    private static let itemNotFound: Int32 = 44

    static func read(_ provider: QuotaProvider) async -> CredentialLookup {
        if let path = QuotaCredentials.filePath(for: provider, home: NSHomeDirectory()) {
            guard let data = FileManager.default.contents(atPath: path),
                  let credential = QuotaCredentials.parse(provider, data) else { return .notSignedIn }
            return .found(credential)
        }
        return await readClaudeKeychain()
    }

    /// Claude Code writes this item with `/usr/bin/security` itself, so reading
    /// it with the same binary is not expected to raise an access prompt. If
    /// macOS asks anyway, "Always Allow" answers it for good; "Deny" lands in
    /// `.failed`.
    private static func readClaudeKeychain() async -> CredentialLookup {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
                process.arguments = ["find-generic-password", "-s", QuotaCredentials.claudeKeychainService, "-w"]
                let stdout = Pipe()
                process.standardOutput = stdout
                process.standardError = FileHandle.nullDevice
                process.standardInput = FileHandle.nullDevice
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: .failed("Keychain unavailable"))
                    return
                }
                // A prompt left unanswered must not hold a fetch forever.
                let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: killer)
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                killer.cancel()

                switch process.terminationStatus {
                case 0:
                    if let credential = QuotaCredentials.parse(.claude, data) {
                        continuation.resume(returning: .found(credential))
                    } else {
                        continuation.resume(returning: .notSignedIn)
                    }
                case itemNotFound:
                    continuation.resume(returning: .notSignedIn)
                default:
                    continuation.resume(returning: .failed("Keychain access denied"))
                }
            }
        }
    }
}
