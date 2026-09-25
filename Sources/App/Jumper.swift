import AppKit
import HerdviewCore

/// Takes a person to an Agent: cmux in front, on a Terminal Tab of the Agent's
/// Session, with Herdr focused on the Agent's pane.
///
/// The world is read afresh on every Jump — tabs, ttys and workspaces move all
/// the time and a Jump is rare — and Jumps run one at a time. A new tab's Herdr
/// client takes a moment to show up in `ps`, so a Jump right after one that
/// opened a tab or workspace for the same Session skips cmux's create step
/// (see `RecentCreations`): a double click opens one tab, not two.
@MainActor
final class Jumper {
    private let hosts: [HostConfig]
    private var last: Task<Void, Never>?
    private var recentCreations = RecentCreations()

    init(hosts: [HostConfig]) {
        self.hosts = hosts
    }

    func jump(to agent: TrackedAgent) {
        let previous = last
        last = Task {
            await previous?.value
            await run(agent: agent)
        }
    }

    /// Every step that can fail is tried; the failures are logged in one line
    /// with one beep at the end.
    private func run(agent: TrackedAgent) async {
        guard let host = hosts.first(where: { $0.name == agent.host }) else {
            return Self.report(["no host named \(agent.host) in the config"])
        }
        let localHerdrPath = hosts.first(where: \.isLocal)?.herdrPath ?? "herdr"
        var failures: [String] = []

        // Herdr focus runs alongside the reads, so a failed read does not stop
        // it. Focus is state on the Herdr server, so once it lands a tab opened
        // below attaches straight onto the Agent's pane.
        async let focusFailure = Self.focus(agent: agent, on: host)

        var plan: JumpPlan?
        do {
            async let ps = ProcessRunner.run(HerdrAttachment.listCommand)
            async let tree = ProcessRunner.run(CmuxCommand.tree)
            let (psOutput, treeOutput) = try await (ps, tree)
            let attachments = String(decoding: psOutput, as: UTF8.self)
                .split(separator: "\n")
                .compactMap { HerdrAttachment.parse(psLine: String($0)) }
            do {
                plan = JumpPlanner.plan(host: host, session: agent.session, attachments: attachments,
                                        tree: try CmuxTree.decode(treeOutput), localHerdrPath: localHerdrPath)
            } catch {
                failures.append("decoding cmux's tree: \(error)")
            }
        } catch {
            failures.append("reading ps and cmux's tree: \(error)")
        }

        // The Herdr focus finishes before cmux acts. Landing on the right tab
        // with the wrong pane is still most of the way, so a failure here does
        // not stop the cmux step.
        if let failure = await focusFailure {
            failures.append(failure)
        }

        // When the last Jump just created a tab for this Session, that tab is on
        // its way: skip the create and only bring cmux forward.
        if let plan, !(plan.creates && recentCreations.covers(host: host.name, session: agent.session, now: Date())) {
            do {
                _ = try await ProcessRunner.run(CmuxCommand.perform(plan))
                if plan.creates {
                    recentCreations.record(host: host.name, session: agent.session, now: Date())
                }
            } catch {
                failures.append("\(plan) in cmux: \(error)")
                return Self.report(failures)
            }
        }

        // Also when the reads failed: cmux may just not be running, and opening
        // it is the most a Jump can do then.
        if let failure = await Self.bringCmuxForward() {
            failures.append(failure)
        }
        Self.report(failures)
    }

    /// Moves Herdr's focus onto the Agent's pane; the failure, if any.
    private static func focus(agent: TrackedAgent, on host: HostConfig) async -> String? {
        do {
            _ = try await ProcessRunner.run(HostCommand.agentFocus(for: host, session: agent.session,
                                                                   paneId: agent.info.paneId))
            return nil
        } catch {
            return "focusing \(agent.key) in Herdr: \(error)"
        }
    }

    /// Opens cmux and puts it in front; the failure, if any.
    private static func bringCmuxForward() async -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: CmuxCommand.bundleIdentifier) else {
            return "cmux is not installed"
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            return nil
        } catch {
            return "opening cmux: \(error)"
        }
    }

    /// One log line naming every failed step, and one beep; nothing when all
    /// went well.
    private static func report(_ failures: [String]) {
        guard !failures.isEmpty else { return }
        NSLog("herdview: jump: \(failures.joined(separator: "; "))")
        NSSound.beep()
    }
}
