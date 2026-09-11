import Foundation
import HerdPetCore

/// Keeps one `ssh -N -L` forward alive. Respawns with backoff 2, 4, 8 ... 60s;
/// the backoff resets only after a forward that lived at least 30 seconds.
@MainActor
final class SSHForwardProcess {
    private let spec: SSHForwardSpec
    private var process: Process?
    private var stopped = false
    private var backoff: Double = 2
    private var startedAt = Date.distantPast

    init(spec: SSHForwardSpec) {
        self.spec = spec
    }

    func start() {
        stopped = false
        spawn()
    }

    func stop() {
        stopped = true
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        unlink(spec.localSocketPath)
    }

    private func spawn() {
        unlink(spec.localSocketPath)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: SSHForwardSpec.executable)
        p.arguments = spec.arguments
        p.standardInput = FileHandle.nullDevice
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        p.terminationHandler = { [weak self] proc in
            let code = proc.terminationStatus
            Task { @MainActor in self?.handleExit(code: code) }
        }
        do {
            try p.run()
            process = p
            startedAt = Date()
        } catch {
            NSLog("herdpet: cannot spawn ssh for %@: %@", spec.sshTarget, error.localizedDescription)
            scheduleRespawn()
        }
    }

    private func handleExit(code: Int32) {
        process = nil
        guard !stopped else { return }
        if Date().timeIntervalSince(startedAt) >= 30 { backoff = 2 }
        NSLog("herdpet: ssh forward to %@ exited (%d), retrying in %.0fs", spec.sshTarget, code, backoff)
        scheduleRespawn()
    }

    private func scheduleRespawn() {
        let delay = backoff
        backoff = min(backoff * 2, 60)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !self.stopped else { return }
            self.spawn()
        }
    }
}
