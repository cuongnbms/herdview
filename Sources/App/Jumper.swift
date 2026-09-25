import AppKit
import HerdviewCore

/// Takes a person to an Agent: cmux in front, on a Terminal Tab of the Agent's
/// Session, with Herdr focused on the Agent's pane.
///
/// The world is read afresh on every Jump — tabs, ttys and workspaces move all
/// the time and a Jump is rare — and Jumps run one at a time, so a double click
/// on a Session with no Terminal Tab opens one tab and then focuses it.
@MainActor
final class Jumper {
    private let hosts: [HostConfig]
    private var last: Task<Void, Never>?

    init(hosts: [HostConfig]) {
        self.hosts = hosts
    }

    func jump(to agent: TrackedAgent) {
        let previous = last
        last = Task { [hosts] in
            await previous?.value
            await Self.run(agent: agent, hosts: hosts)
        }
    }

    private static func run(agent: TrackedAgent, hosts: [HostConfig]) async {
        guard let host = hosts.first(where: { $0.name == agent.host }) else {
            return fail("no host named \(agent.host) in the config")
        }
        let localHerdrPath = hosts.first(where: \.isLocal)?.herdrPath ?? "herdr"

        let psOutput: Data
        let treeOutput: Data
        do {
            async let ps = ProcessRunner.run(HerdrAttachment.listCommand)
            async let tree = ProcessRunner.run(CmuxCommand.tree)
            (psOutput, treeOutput) = try await (ps, tree)
        } catch {
            return fail("reading ps and cmux's tree: \(error)")
        }

        let attachments = String(decoding: psOutput, as: UTF8.self)
            .split(separator: "\n")
            .compactMap { HerdrAttachment.parse(psLine: String($0)) }
        let tree: CmuxTree
        do {
            tree = try CmuxTree.decode(treeOutput)
        } catch {
            return fail("decoding cmux's tree: \(error)")
        }
        let plan = JumpPlanner.plan(host: host, session: agent.session, attachments: attachments,
                                    tree: tree, localHerdrPath: localHerdrPath)

        // Herdr first: focus is state on its server, so a tab opened below
        // attaches straight onto the Agent's pane. Landing on the right tab with
        // the wrong pane is still most of the way, so a failure here does not
        // stop the cmux step.
        do {
            _ = try await ProcessRunner.run(HostCommand.agentFocus(for: host, session: agent.session,
                                                                   paneId: agent.info.paneId))
        } catch {
            fail("focusing \(agent.key) in Herdr: \(error)")
        }

        do {
            _ = try await ProcessRunner.run(CmuxCommand.perform(plan))
        } catch {
            return fail("\(plan) in cmux: \(error)")
        }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: CmuxCommand.bundleIdentifier) else {
            return fail("cmux is not installed")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        } catch {
            fail("opening cmux: \(error)")
        }
    }

    private static func fail(_ what: String) {
        NSLog("herdview: jump: \(what)")
        NSSound.beep()
    }
}
