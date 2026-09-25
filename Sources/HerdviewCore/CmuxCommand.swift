import Foundation

/// The `cmux` invocations a Jump makes. cmux's CLI is its public interface; see
/// docs/adr/0006 for why Herdview drives it instead of cmux's socket.
public enum CmuxCommand {
    public static let executable = "/Applications/cmux.app/Contents/Resources/bin/cmux"
    public static let bundleIdentifier = "com.cmuxterm.app"

    /// Every workspace, pane and terminal in every window, as JSON.
    public static let tree = HostCommand(executable: executable, arguments: ["--json", "tree", "--all"])

    public static func perform(_ plan: JumpPlan) -> HostCommand {
        switch plan {
        case .focus(let surface):
            // Focusing a surface also selects its workspace and window.
            return HostCommand(executable: executable,
                               arguments: ["rpc", "surface.focus", #"{"surface_id":"\#(surface)"}"#])
        case .newTab(let workspace, let command):
            return HostCommand(executable: executable,
                               arguments: ["new-surface", "--workspace", workspace, "--command", command, "--focus", "true"])
        case .newWorkspace(let name, let command):
            return HostCommand(executable: executable,
                               arguments: ["new-workspace", "--name", name, "--command", command, "--focus", "true"])
        }
    }
}
