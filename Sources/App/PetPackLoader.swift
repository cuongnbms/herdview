import Foundation

/// Reads AgentPet-format pet packs from `~/.agentpet/pets/<id>/`.
enum PetPackLoader {
    static let petsDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".agentpet/pets")

    /// The pack with `id`, or when `id` is nil the alphabetically first pack
    /// that has a `pet.json`. Nil when nothing loads.
    static func load(id: String?) -> ImagePetPack? {
        if let id {
            return SpriteSlicer.loadPack(directory: petsDir.appendingPathComponent(id))
        }
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: petsDir.path)) ?? []
        for name in entries.sorted() {
            let dir = petsDir.appendingPathComponent(name)
            if SpriteSlicer.manifestID(directory: dir) != nil, let pack = SpriteSlicer.loadPack(directory: dir) {
                return pack
            }
        }
        return nil
    }
}
