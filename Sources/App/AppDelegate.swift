import AppKit
import Combine
import HerdPetCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = AgentStore()
    private var monitor: Monitor?
    private var statusBar: StatusBarController?
    private var petModel: PetModel?
    private var petWindow: PetWindowController?
    private var mainWindow: MainWindowController?
    private var moodCancellable: AnyCancellable?

    func applicationWillFinishLaunching(_ notification: Notification) {
        MainMenu.install()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        var config = HerdPetConfig(pet: nil, clips: HerdPetConfig.defaultClips, hosts: [])
        do {
            config = try ConfigLoader.load()
        } catch {
            store.configError = "\(ConfigLoader.defaultPath): \(error)"
        }

        // Named for what it is: the pet's own window is a local `window` further
        // down until the pet goes.
        let mainWindowController = MainWindowController(store: store)
        mainWindow = mainWindowController
        mainWindowController.show()

        let model = PetModel(config: config)
        petModel = model
        let window = PetWindowController(model: model)
        petWindow = window
        window.show()

        let bar = StatusBarController(store: store) { [weak self] in
            self?.mainWindow?.toggle()
        }
        statusBar = bar
        bar.start()

        moodCancellable = store.$agents.sink { agents in
            model.mood = MoodResolver.resolve(agents)
            model.update(agents: agents)
        }

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
