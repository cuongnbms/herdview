import Foundation
import HerdPetCore

/// Polls one running Herdr session with `agent.list` every `pollSeconds`.
@MainActor
final class SessionWatcher {
    let host: HostConfig
    let session: HerdrSession
    private let socketPath: String
    private let store: AgentStore
    private var forward: SSHForwardProcess?
    private var task: Task<Void, Never>?

    init(host: HostConfig, session: HerdrSession, store: AgentStore, socketBaseDir: String) {
        self.host = host
        self.session = session
        self.store = store
        if let ssh = host.ssh {
            let local = SSHForwardSpec.localSocketPath(baseDir: socketBaseDir, host: host.name, session: session.name)
            socketPath = local
            forward = SSHForwardProcess(spec: SSHForwardSpec(sshTarget: ssh, localSocketPath: local, remoteSocketPath: session.socketPath))
        } else {
            socketPath = session.socketPath
        }
    }

    func start() {
        forward?.start()
        let interval = UInt64(max(1, host.pollSeconds)) * 1_000_000_000
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        forward?.stop()
        store.removeSession(host: host.name, session: session.name)
    }

    private func poll() async {
        let path = socketPath
        let outcome = await Task.detached(priority: .utility) {
            Result { try HerdrClient.agentList(socketPath: path) }
        }.value

        switch outcome {
        case .success(let agents):
            store.apply(host: host.name, session: session.name, snapshot: agents)
        case .failure(let error):
            if case HerdrClientError.serverNotRunning = error {
                store.apply(host: host.name, session: session.name, snapshot: [])
            } else {
                NSLog("herdpet: %@/%@ poll failed: %@", host.name, session.name, String(describing: error))
            }
        }
    }
}
