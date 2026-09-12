import Foundation
import HerdviewCore

/// Discovers running sessions on one host every 30 seconds and keeps one
/// `SessionWatcher` per running session.
@MainActor
final class HostRunner {
    static let discoveryIntervalNanos: UInt64 = 30 * 1_000_000_000

    let host: HostConfig
    private let store: AgentStore
    private let socketBaseDir: String
    private var watchers: [String: SessionWatcher] = [:]
    private var task: Task<Void, Never>?

    init(host: HostConfig, store: AgentStore, socketBaseDir: String) {
        self.host = host
        self.store = store
        self.socketBaseDir = socketBaseDir
    }

    func start() {
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.discover()
                try? await Task.sleep(nanoseconds: HostRunner.discoveryIntervalNanos)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        for watcher in watchers.values { watcher.stop() }
        watchers = [:]
    }

    private func discover() async {
        let sessions: [HerdrSession]
        do {
            let output = try await ProcessRunner.run(HostCommand.sessionList(for: host))
            sessions = try SessionDiscovery.parse(output)
        } catch {
            NSLog("herdview: discovery failed on %@: %@", host.name, String(describing: error))
            store.setReachable(host: host.name, false)
            return
        }
        store.setReachable(host: host.name, true)

        let diff = SessionDiff.compute(watching: Set(watchers.keys), discovered: sessions)
        for name in diff.stop {
            watchers[name]?.stop()
            watchers[name] = nil
        }
        for session in diff.start {
            let watcher = SessionWatcher(host: host, session: session, store: store, socketBaseDir: socketBaseDir)
            watchers[session.name] = watcher
            watcher.start()
        }
    }
}
