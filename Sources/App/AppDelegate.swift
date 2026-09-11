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

        let model = PetModel(config: config)
        petModel = model
        let window = PetWindowController(model: model)
        petWindow = window
        window.show()

        let bar = StatusBarController(store: store, pet: model)
        statusBar = bar
        bar.start()

        store.onTransition = { transition in
            switch transition.to {
            case .blocked, .done: model.flash(agentKey: transition.agent.key)
            default: break
            }
        }
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
}
