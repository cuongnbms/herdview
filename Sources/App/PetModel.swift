import AppKit
import HerdPetCore

/// What the pet window shows: which pack, the current mood's clip, the agents
/// it is reporting on, a chatter line for when there are none, and how big the
/// whole thing is drawn.
@MainActor
final class PetModel: ObservableObject {
    /// Idle chatter is re-picked this often.
    static let idleRotateSeconds: UInt64 = 120
    /// How long a row stays highlighted after its agent turns blocked or done.
    static let highlightSeconds: UInt64 = 3

    @Published var mood: Mood = .idle {
        didSet { if mood != oldValue { moodDidChange() } }
    }
    @Published private(set) var pack: ImagePetPack?
    @Published private(set) var packs: [PetPackSummary] = []
    @Published private(set) var selectedPetID: String?
    /// Which clip of the current pack each mood animates. Per pack, since clip
    /// numbering is the pack's own.
    @Published private(set) var bindings = ClipBindings()
    /// The line shown when no agent is doing anything; the agent list replaces
    /// it as soon as there is one.
    @Published private(set) var moodLine: String = "" {
        didSet { updatePanelSize() }
    }
    /// The agents the bubble names, blocked first. Empty when the herd is idle.
    @Published private(set) var bubble: AgentBubbleContent = .empty {
        didSet { updatePanelSize() }
    }
    /// Rows flashing because their agent just turned blocked or done.
    @Published private(set) var highlighted: Set<String> = []

    /// The sprite's edge length in points. Clamped to `PetSize`'s range and
    /// remembered across launches.
    @Published var petPoint: Double = PetSize.defaultPoint {
        didSet {
            let clamped = PetSize.clamp(petPoint)
            if clamped != petPoint {
                petPoint = clamped
                return
            }
            UserDefaults.standard.set(petPoint, forKey: Self.petSizeKey)
            updatePanelSize()
        }
    }
    /// The size the panel must have to hold the sprite and the current bubble.
    @Published private(set) var panelSize: CGSize = .zero

    /// Multiplier on every mood's frame rate, set in the settings page and
    /// remembered across launches.
    @Published var animationSpeed: Double = AnimationSpeed.defaultMultiplier {
        didSet {
            let clamped = AnimationSpeed.clamp(animationSpeed)
            if clamped != animationSpeed {
                animationSpeed = clamped
                return
            }
            UserDefaults.standard.set(animationSpeed, forKey: Self.animationSpeedKey)
        }
    }

    private static let selectedPetKey = "herdpet.selectedPetID"
    private static let petSizeKey = "herdpet.petSize"
    private static let animationSpeedKey = "herdpet.animationSpeed"
    private static func bindingsKey(_ packID: String) -> String { "herdpet.clips.\(packID)" }
    private let clips: [Mood: Int]
    private let messages: [Mood: [String]]
    private var pickCounter = Int.random(in: 0..<1_000)
    private var chatterTask: Task<Void, Never>?
    private var highlightTasks: [String: Task<Void, Never>] = [:]

    /// `config.pet` is the default; a pet picked in the menu wins over it.
    init(config: HerdPetConfig, defaults: UserDefaults = .standard) {
        clips = config.clips
        messages = config.messages
        packs = PetPackLoader.listPacks()
        let saved = defaults.string(forKey: Self.selectedPetKey)
        let wanted = saved.flatMap { id in packs.contains { $0.id == id } ? id : nil } ?? config.pet
        pack = PetPackLoader.load(id: wanted)
        selectedPetID = pack?.id
        bindings = Self.loadBindings(packID: pack?.id, defaults: defaults)
        if let storedSize = defaults.object(forKey: Self.petSizeKey) as? Double {
            petPoint = PetSize.clamp(storedSize)
        }
        if let storedSpeed = defaults.object(forKey: Self.animationSpeedKey) as? Double {
            animationSpeed = AnimationSpeed.clamp(storedSpeed)
        }
        moodDidChange()
        updatePanelSize()
    }

    // MARK: Pet selection

    /// Re-reads `~/.agentpet/pets`, for when the picker opens.
    func refreshPacks() {
        packs = PetPackLoader.listPacks()
    }

    func selectPet(id: String) {
        guard id != selectedPetID, let loaded = PetPackLoader.load(id: id) else { return }
        pack = loaded
        selectedPetID = loaded.id
        bindings = Self.loadBindings(packID: loaded.id)
        UserDefaults.standard.set(loaded.id, forKey: Self.selectedPetKey)
    }

    // MARK: Clip bindings

    /// Clips the current pack offers; 0 when no pack is loaded.
    var clipCount: Int { pack?.clipCount ?? 0 }

    /// Binds a clip to a mood for the current pack and remembers it.
    func bindClip(_ clip: Int, to mood: Mood) {
        guard let packID = selectedPetID else { return }
        bindings.bind(clip, to: mood)
        UserDefaults.standard.set(bindings.stored, forKey: Self.bindingsKey(packID))
    }

    /// The clip a mood animates, as the picker shows it.
    func clip(for mood: Mood) -> Int {
        bindings.clip(for: mood, fallback: configClip(for: mood), clipCount: clipCount)
    }

    private func configClip(for mood: Mood) -> Int {
        clips[mood] ?? HerdPetConfig.defaultClips[mood] ?? 0
    }

    private static func loadBindings(packID: String?, defaults: UserDefaults = .standard) -> ClipBindings {
        guard let packID, let stored = defaults.dictionary(forKey: bindingsKey(packID)) as? [String: Int] else {
            return ClipBindings()
        }
        return ClipBindings(stored: stored)
    }

    // MARK: Sprite

    /// Frames of the clip bound to `mood`: the menu's binding when there is
    /// one, else the config's, clamped to what the pack has.
    func frames(for mood: Mood) -> [NSImage] {
        guard let pack else { return [] }
        return pack.clip(clip(for: mood))
    }

    /// Working animates at twice the calm rate, before the speed multiplier.
    private static func baseFps(for mood: Mood) -> Double {
        mood == .working ? 6 : 3
    }

    func fps(for mood: Mood) -> Double {
        AnimationSpeed.fps(base: Self.baseFps(for: mood), multiplier: animationSpeed)
    }

    // MARK: Layout

    /// Lines the bubble draws right now, which is what the panel's height is
    /// built from. Zero means no bubble at all.
    private var bubbleLines: Int {
        if bubble.lineCount > 0 { return bubble.lineCount }
        return moodLine.isEmpty ? 0 : 1
    }

    private func updatePanelSize() {
        panelSize = PetLayout.panelSize(petPoint: petPoint, bubbleLines: bubbleLines)
    }

    // MARK: Bubbles

    /// A fresh line from `mood`'s pool, never the same as the previous pick
    /// when the pool has more than one line.
    func nextLine(for mood: Mood) -> String {
        pickCounter += 1
        return BubbleLines.line(for: mood, custom: messages, seed: pickCounter)
    }

    // MARK: Agent list

    /// Rebuilds the bubble from the current agents.
    func update(agents: [TrackedAgent]) {
        bubble = AgentBubbleRows.content(from: agents)
    }

    /// Flashes one agent's row for `highlightSeconds`, for when it has just
    /// turned blocked or done. Several rows can flash at once.
    func flash(agentKey: String) {
        highlighted.insert(agentKey)
        highlightTasks[agentKey]?.cancel()
        highlightTasks[agentKey] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.highlightSeconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.highlighted.remove(agentKey)
            self?.highlightTasks[agentKey] = nil
        }
    }

    /// Only idle keeps a chatter line rotating; every other mood has agents to
    /// name, and the list takes the bubble.
    private func moodDidChange() {
        chatterTask?.cancel()
        moodLine = nextLine(for: mood)
        updatePanelSize()
        guard mood == .idle else { return }
        chatterTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.idleRotateSeconds * 1_000_000_000)
                guard !Task.isCancelled, let model = self else { return }
                model.moodLine = model.nextLine(for: .idle)
            }
        }
    }
}
