import AppKit
import HerdPetCore

/// What the pet window shows: which pack, the current mood's clip, a chatter
/// line that follows the mood, an optional short-lived alert on top, and how
/// big the whole thing is drawn.
@MainActor
final class PetModel: ObservableObject {
    static let alertSeconds: UInt64 = 8
    /// Idle chatter is re-picked this often; working flashes a line this often.
    static let idleRotateSeconds: UInt64 = 120
    static let workingFlashEverySeconds: UInt64 = 40
    static let workingFlashSeconds: UInt64 = 6

    /// A bubble that replaces the chatter for `alertSeconds`.
    struct Alert: Equatable {
        var text: String
        var detail: String?
    }

    @Published var mood: Mood = .idle {
        didSet { if mood != oldValue { moodDidChange() } }
    }
    @Published private(set) var pack: ImagePetPack?
    @Published private(set) var packs: [PetPackSummary] = []
    @Published private(set) var selectedPetID: String?
    /// The persistent line for the current mood. Empty while working, where the
    /// bubble shows a compact "…" instead.
    @Published private(set) var moodLine: String = "" {
        didSet { updatePanelSize() }
    }
    @Published private(set) var alert: Alert? {
        didSet { updatePanelSize() }
    }

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

    private static let selectedPetKey = "herdpet.selectedPetID"
    private static let petSizeKey = "herdpet.petSize"
    private let clips: [Mood: Int]
    private let messages: [Mood: [String]]
    private var pickCounter = Int.random(in: 0..<1_000)
    private var alertTask: Task<Void, Never>?
    private var chatterTask: Task<Void, Never>?

    /// `config.pet` is the default; a pet picked in the menu wins over it.
    init(config: HerdPetConfig, defaults: UserDefaults = .standard) {
        clips = config.clips
        messages = config.messages
        packs = PetPackLoader.listPacks()
        let saved = defaults.string(forKey: Self.selectedPetKey)
        let wanted = saved.flatMap { id in packs.contains { $0.id == id } ? id : nil } ?? config.pet
        pack = PetPackLoader.load(id: wanted)
        selectedPetID = pack?.id
        if let storedSize = defaults.object(forKey: Self.petSizeKey) as? Double {
            petPoint = PetSize.clamp(storedSize)
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
        UserDefaults.standard.set(loaded.id, forKey: Self.selectedPetKey)
    }

    // MARK: Sprite

    /// Frames of the clip bound to `mood`. `ImagePetPack.clip` clamps to the
    /// last row when the pack has fewer rows than the binding asks for.
    func frames(for mood: Mood) -> [NSImage] {
        guard let pack else { return [] }
        return pack.clip(clips[mood] ?? HerdPetConfig.defaultClips[mood] ?? 0)
    }

    func fps(for mood: Mood) -> Double {
        mood == .working ? 6 : 3
    }

    // MARK: Layout

    /// Lines the bubble draws right now, which is what the panel's height is
    /// built from. Zero means no bubble at all.
    private var bubbleLines: Int {
        if let alert { return alert.detail == nil ? 1 : 2 }
        if !moodLine.isEmpty { return 1 }
        return mood == .working ? 1 : 0
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

    /// Shows an alert above the pet for `alertSeconds`, replacing any alert.
    func showAlert(_ alert: Alert) {
        self.alert = alert
        alertTask?.cancel()
        alertTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.alertSeconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.alert = nil
        }
    }

    /// The bubble for an agent transition: a pool line for the new status,
    /// with "name @ host" underneath. Nil for statuses without a bubble.
    static func alert(for transition: Transition, using model: PetModel) -> Alert? {
        let mood: Mood
        switch transition.to {
        case .blocked: mood = .blocked
        case .done: mood = .done
        default: return nil
        }
        return Alert(text: model.nextLine(for: mood),
                     detail: "\(transition.agent.info.displayName) @ \(transition.agent.host)")
    }

    private func moodDidChange() {
        chatterTask?.cancel()
        moodLine = mood == .working ? "" : nextLine(for: mood)
        updatePanelSize()
        switch mood {
        case .idle:
            chatterTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: Self.idleRotateSeconds * 1_000_000_000)
                    guard !Task.isCancelled, let model = self else { return }
                    model.moodLine = model.nextLine(for: .idle)
                }
            }
        case .working:
            chatterTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: Self.workingFlashEverySeconds * 1_000_000_000)
                    guard !Task.isCancelled, let model = self else { return }
                    model.moodLine = model.nextLine(for: .working)
                    try? await Task.sleep(nanoseconds: Self.workingFlashSeconds * 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    model.moodLine = ""
                }
            }
        case .blocked, .done:
            break
        }
    }
}
