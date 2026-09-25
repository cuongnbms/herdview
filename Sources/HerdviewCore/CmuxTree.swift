import Foundation

/// What cmux has open, as `cmux --json tree --all` reports it: every workspace in
/// every window, in the order cmux lists them, with the terminals inside.
///
/// Only terminals that already have a tty are kept. A Jump finds a Terminal Tab
/// by its tty, so a browser, or a terminal that has not started its shell yet,
/// can never be one.
public struct CmuxTree: Equatable, Sendable {
    public struct Workspace: Equatable, Sendable {
        public let ref: String
        public let title: String
        public let surfaces: [Surface]

        public init(ref: String, title: String, surfaces: [Surface]) {
            self.ref = ref
            self.title = title
            self.surfaces = surfaces
        }
    }

    public struct Surface: Equatable, Sendable {
        public let ref: String
        public let tty: String

        public init(ref: String, tty: String) {
            self.ref = ref
            self.tty = tty
        }
    }

    public let workspaces: [Workspace]

    public init(workspaces: [Workspace]) {
        self.workspaces = workspaces
    }

    public static func decode(_ data: Data) throws -> CmuxTree {
        let raw = try JSONDecoder().decode(RawTree.self, from: data)
        let workspaces = raw.windows.flatMap { $0.workspaces ?? [] }.map { workspace in
            Workspace(
                ref: workspace.ref,
                title: workspace.title ?? "",
                surfaces: (workspace.panes ?? []).flatMap { $0.surfaces ?? [] }.compactMap { surface in
                    guard surface.type == "terminal", let tty = surface.tty, !tty.isEmpty else { return nil }
                    return Surface(ref: surface.ref, tty: tty)
                })
        }
        return CmuxTree(workspaces: workspaces)
    }

    private struct RawTree: Decodable {
        let windows: [RawWindow]
    }

    private struct RawWindow: Decodable {
        let workspaces: [RawWorkspace]?
    }

    private struct RawWorkspace: Decodable {
        let ref: String
        let title: String?
        let panes: [RawPane]?
    }

    private struct RawPane: Decodable {
        let surfaces: [RawSurface]?
    }

    private struct RawSurface: Decodable {
        let ref: String
        let type: String?
        let tty: String?
    }
}
