import AppKit
import HerdPetCore
import SwiftUI

/// The app's one window: the agent list in a normal title bar window that can be
/// resized, minimized and closed. Closing it must not quit the app — polling and
/// the menu bar item carry on — so `isReleasedWhenClosed` is off and
/// `AppDelegate` refuses to terminate with it.
///
/// It can also be kept on top: at `.floating` the window stays above other
/// apps' windows, so the herd is readable while you work in an editor. That is
/// off by default and remembered between launches.
@MainActor
final class MainWindowController: NSObject {
    private static let frameAutosaveName = "herdpet.mainWindow"

    private let window: NSWindow
    private let preferences: WindowPreferences
    private let keepOnTopItem: NSMenuItem?

    init(store: AgentStore,
         preferences: WindowPreferences = WindowPreferences(),
         keepOnTopItem: NSMenuItem? = nil) {
        self.preferences = preferences
        self.keepOnTopItem = keepOnTopItem
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

        super.init()

        keepOnTopItem?.target = self
        keepOnTopItem?.action = #selector(toggleAlwaysOnTop)
        applyAlwaysOnTop(preferences.isAlwaysOnTop)
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

    /// The Window menu's `Keep on Top`: float above other apps, or stop.
    @objc func toggleAlwaysOnTop() {
        let onTop = !preferences.isAlwaysOnTop
        preferences.isAlwaysOnTop = onTop
        applyAlwaysOnTop(onTop)
    }

    private func applyAlwaysOnTop(_ onTop: Bool) {
        window.level = onTop ? .floating : .normal
        keepOnTopItem?.state = onTop ? .on : .off
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
