import Foundation

/// Saves finished sessions as JSON files so a future progress dashboard can read them.
struct SessionStore {
    let directory: URL

    static let standard = SessionStore(
        directory: URL.applicationSupportDirectory.appending(path: "Sessions/WhackAMole", directoryHint: .isDirectory)
    )

    func save(_ record: GameSessionRecord) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(record.id.uuidString).json")
        try Self.encoder.encode(record).write(to: url, options: .atomic)
    }

    func loadAll() -> [GameSessionRecord] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { try? Self.decoder.decode(GameSessionRecord.self, from: Data(contentsOf: $0)) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

/// Remembers the last used configuration on this device.
struct ConfigurationStore {
    private static let key = "whackAMole.configuration"
    let defaults: UserDefaults

    static let standard = ConfigurationStore(defaults: .standard)

    func load() -> GameConfiguration {
        guard let data = defaults.data(forKey: Self.key),
              let configuration = try? JSONDecoder().decode(GameConfiguration.self, from: data) else {
            return GameConfiguration()
        }
        return configuration
    }

    func save(_ configuration: GameConfiguration) {
        defaults.set(try? JSONEncoder().encode(configuration), forKey: Self.key)
    }
}
