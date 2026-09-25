import Foundation

/// What a Jump does in cmux once it knows what is open.
public enum JumpPlan: Equatable, Sendable {
    /// Focus the Terminal Tab already attached to the Session.
    case focus(surface: String)
    /// Open a Terminal Tab in the Matching Workspace, running `command`.
    case newTab(workspace: String, command: String)
    /// Create a workspace named after the Session, running `command` in it.
    case newWorkspace(name: String, command: String)
}

/// Decides where a Jump lands. Pure: it is handed the Herdr clients `ps` found
/// and the tree cmux reported, and never looks at either itself.
public enum JumpPlanner {
    public static func plan(host: HostConfig, session: String, attachments: [HerdrAttachment],
                            tree: CmuxTree, localHerdrPath: String) -> JumpPlan {
        let ttys = Set(attachments.filter { $0.session == session && $0.remote == host.ssh }.map(\.tty))
        let matching = matchingWorkspace(for: session, in: tree)

        let tabs = tree.workspaces.flatMap { workspace in
            workspace.surfaces.filter { ttys.contains($0.tty) }.map { (workspace: workspace.ref, surface: $0.ref) }
        }
        if let tab = tabs.first(where: { $0.workspace == matching?.ref }) ?? tabs.first {
            return .focus(surface: tab.surface)
        }

        let command = attachCommand(host: host, session: session, localHerdrPath: localHerdrPath)
        if let matching {
            return .newTab(workspace: matching.ref, command: command)
        }
        return .newWorkspace(name: session, command: command)
    }

    /// The workspace that belongs to a Session by name. A title spelled exactly
    /// like the Session beats one that only normalises to it, so "blue-matrix"
    /// wins over "Blue Matrix" when both exist; otherwise cmux's order decides.
    public static func matchingWorkspace(for session: String, in tree: CmuxTree) -> CmuxTree.Workspace? {
        let candidates = tree.workspaces.filter { normalizedTitle($0.title) == session }
        return candidates.first { $0.title == session } ?? candidates.first
    }

    /// Lowercased, with each run of whitespace turned into one `-`: how a
    /// workspace title is compared with a Session name.
    public static func normalizedTitle(_ title: String) -> String {
        title.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: "-")
    }

    /// The command a new Terminal Tab runs. It always runs on this Mac, so it is
    /// the local Herdr binary even for a remote Session.
    public static func attachCommand(host: HostConfig, session: String, localHerdrPath: String) -> String {
        if let ssh = host.ssh {
            return "\(localHerdrPath) --remote \(ssh) --session \(session)"
        }
        return "\(localHerdrPath) --session \(session)"
    }
}
