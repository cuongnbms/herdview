import Foundation

/// Reads AgentPet-format pet packs from `~/.agentpet/pets/<id>/`.
enum PetPackLoader {
    static let petsDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".agentpet/pets")

    /// Every installed pack that has a readable `pet.json`, sorted by display
    /// name. Reads manifests only; nothing is sliced.
    static func listPacks() -> [PetPackSummary] {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: petsDir.path)) ?? []
        return entries
            .compactMap { SpriteSlicer.summary(directory: petsDir.appendingPathComponent($0)) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// The pack with `id`, or when `id` is nil the first listed pack.
    /// Nil when nothing loads.
    static func load(id: String?) -> ImagePetPack? {
        let packs = listPacks()
        if let id, let match = packs.first(where: { $0.id == id }) {
            return SpriteSlicer.loadPack(directory: match.directory)
        }
        for summary in packs {
            if let pack = SpriteSlicer.loadPack(directory: summary.directory) {
                return pack
            }
        }
        return nil
    }
}
