import AppKit
import HerdPetCore

/// What the pet window shows: the current mood's clip and an optional bubble.
@MainActor
final class PetModel: ObservableObject {
    static let bubbleSeconds: UInt64 = 8

    @Published var mood: Mood = .idle
    @Published private(set) var bubbleText: String?

    let pack: ImagePetPack?
    private let clips: [Mood: Int]
    private var hideTask: Task<Void, Never>?

    init(pack: ImagePetPack?, clips: [Mood: Int]) {
        self.pack = pack
        self.clips = clips
    }

    /// Frames of the clip bound to `mood`. `ImagePetPack.clip` clamps to the
    /// last row when the pack has fewer rows than the binding asks for.
    func frames(for mood: Mood) -> [NSImage] {
        guard let pack else { return [] }
        return pack.clip(clips[mood] ?? HerdPetConfig.defaultClips[mood] ?? 0)
    }

    func fps(for mood: Mood) -> Double {
        mood == .working ? 6 : 3
    }

    /// Shows `text` above the pet for `bubbleSeconds`, replacing any bubble.
    func showBubble(_ text: String) {
        bubbleText = text
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: PetModel.bubbleSeconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.bubbleText = nil
        }
    }
}
