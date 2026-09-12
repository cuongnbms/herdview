import AppKit
import HerdPetCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = AgentStore()
    private var monitor: Monitor?
    private var statusBar: StatusBarController?
    private var mainWindow: MainWindowController?
    private var menuItems: MainMenu.Items?

    func applicationWillFinishLaunching(_ notification: Notification) {
        menuItems = MainMenu.install()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        var config = HerdPetConfig(hosts: [])
        do {
            config = try ConfigLoader.load()
        } catch {
            store.configError = "\(ConfigLoader.defaultPath): \(error)"
        }

        let window = MainWindowController(store: store, keepOnTopItem: menuItems?.keepOnTop)
        mainWindow = window
        window.show()

        let bar = StatusBarController(store: store) { [weak self] in
            self?.mainWindow?.toggle()
        }
        statusBar = bar
        bar.start()

        let monitor = Monitor(config: config, store: store)
        self.monitor = monitor
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
    }

    /// Closing the window hides it. The herd keeps being polled and the menu bar
    /// item keeps working, so the last window closing must not end the app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Clicking the Dock icon of an app with no visible windows asks for one.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindow?.show()
        return true
    }
}
