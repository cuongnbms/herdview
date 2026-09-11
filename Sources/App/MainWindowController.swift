import AppKit
import SwiftUI

/// The app's one window: the agent list in a normal title bar window that can be
/// resized, minimized and closed. Closing it must not quit the app — polling and
/// the menu bar item carry on — so `isReleasedWhenClosed` is off and
/// `AppDelegate` refuses to terminate with it.
@MainActor
final class MainWindowController {
    private static let frameAutosaveName = "herdpet.mainWindow"

    private let window: NSWindow

    init(store: AgentStore) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "HerdPet"
        window.contentMinSize = NSSize(width: 360, height: 240)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: AgentListView(store: store))
        // Remember where the user put it. Without a saved frame the window lands
        // in the bottom-left corner, so the first launch centres it instead.
        if !window.setFrameUsingName(Self.frameAutosaveName) {
            window.center()
        }
        _ = window.setFrameAutosaveName(Self.frameAutosaveName)
    }

    var isVisible: Bool { window.isVisible }

    func show() {
        window.makeKeyAndOrderFront(nil)
        // `activate(ignoringOtherApps:)` is deprecated from macOS 14, and this
        // package still deploys to 13.
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func hide() {
        window.orderOut(nil)
    }

    /// The menu bar item's action: show the window unless the user is already
    /// looking at it, in which case get out of the way.
    func toggle() {
        if isVisible && NSApp.isActive {
            hide()
        } else {
            show()
        }
    }
}
