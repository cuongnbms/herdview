import Foundation

/// One machine running Herdr. `ssh == nil` means the local machine.
public struct HostConfig: Equatable, Sendable {
    public var name: String
    public var ssh: String?
    public var herdrPath: String
    public var pollSeconds: Int

    public init(name: String, ssh: String?, herdrPath: String, pollSeconds: Int) {
        self.name = name
        self.ssh = ssh
        self.herdrPath = herdrPath
        self.pollSeconds = pollSeconds
    }

    public var isLocal: Bool { ssh == nil }
}

public struct HerdPetConfig: Equatable, Sendable {
    public var pet: String?
    public var clips: [Mood: Int]
    public var hosts: [HostConfig]

    public static let defaultClips: [Mood: Int] = [.idle: 0, .working: 1, .blocked: 2, .done: 3]

    public init(pet: String?, clips: [Mood: Int], hosts: [HostConfig]) {
        self.pet = pet
        self.clips = clips
        self.hosts = hosts
    }

    public func clipIndex(for mood: Mood) -> Int {
        clips[mood] ?? HerdPetConfig.defaultClips[mood] ?? 0
    }
}

public enum ConfigError: Error, Equatable {
    case parse(String)
    case missingField(host: Int, field: String)
    case invalidType(String)
}

public enum ConfigLoader {
    public static let defaultPath = NSHomeDirectory() + "/.config/herdpet/config.toml"
    public static let defaultPollSeconds = 2

    public static func load(path: String = defaultPath) throws -> HerdPetConfig {
        guard let data = FileManager.default.contents(atPath: path),
              let text = String(data: data, encoding: .utf8) else {
            throw ConfigError.parse("cannot read \(path)")
        }
        return try parse(text)
    }

    public static func parse(_ text: String) throws -> HerdPetConfig {
        let doc: TOMLDocument
        do {
            doc = try TOMLSubset.parse(text)
        } catch let TOMLSubsetError.syntax(line, message) {
            throw ConfigError.parse("line \(line): \(message)")
        }

        let pet = doc.root["pet"]?.stringValue

        var clips = HerdPetConfig.defaultClips
        for (key, value) in doc.tables["clips"] ?? [:] {
            guard let mood = Mood(rawValue: key) else { continue }
            guard let index = value.intValue else { throw ConfigError.invalidType("clips.\(key) must be an integer") }
            clips[mood] = index
        }

        var hosts: [HostConfig] = []
        for (index, entry) in (doc.arrays["hosts"] ?? []).enumerated() {
            guard let name = entry["name"]?.stringValue else { throw ConfigError.missingField(host: index, field: "name") }
            guard let herdrPath = entry["herdr_path"]?.stringValue else { throw ConfigError.missingField(host: index, field: "herdr_path") }
            let ssh = entry["ssh"]?.stringValue
            var poll = defaultPollSeconds
            if let raw = entry["poll_seconds"] {
                guard let value = raw.intValue, value >= 1 else { throw ConfigError.invalidType("hosts[\(index)].poll_seconds must be an integer >= 1") }
                poll = value
            }
            hosts.append(HostConfig(name: name, ssh: ssh, herdrPath: herdrPath, pollSeconds: poll))
        }

        return HerdPetConfig(pet: pet, clips: clips, hosts: hosts)
    }
}
