import Foundation
import HerdviewCore

/// Owns one `HostRunner` per configured host.
@MainActor
final class Monitor {
    static let socketBaseDir = NSHomeDirectory() + "/.herdview/sock"

    private let runners: [HostRunner]

    init(config: HerdviewConfig, store: AgentStore) {
        try? FileManager.default.createDirectory(atPath: Monitor.socketBaseDir, withIntermediateDirectories: true)
        store.setHostOrder(config.hosts.map(\.name))
        runners = config.hosts.map { HostRunner(host: $0, store: store, socketBaseDir: Monitor.socketBaseDir) }
    }

    func start() {
        for runner in runners { runner.start() }
    }

    func stop() {
        for runner in runners { runner.stop() }
    }
}
