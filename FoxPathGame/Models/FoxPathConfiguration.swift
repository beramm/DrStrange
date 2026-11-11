import Foundation

/// Per-level gameplay parameters for Follow the Fox. Every value is a `.gameDesign` placeholder
/// that is subject to clinical review; none of them implies a therapeutic intensity.
struct FoxPathSettings: Codable, Equatable {
    /// Walking speed in map units per second. One path tile is 128 units wide.
    var foxSpeed: Double
    /// How far from the fox (screen points) the gaze may be and still count as following it.
    /// The radius grows with the fox when the map is zoomed in.
    var followRadius: Double
    /// Seconds the gaze may leave the fox before the fox stops and the warning shows.
    var lookAwayGrace: Double
    /// Seconds the gaze must rest on the fox again before it walks on.
    var refocusDwell: Double
    /// Tiles the path runs straight between two turns.
    var straightRunRange: ClosedRange<Int>
    /// Rows the path climbs or drops in one turn.
    var turnHeightRange: ClosedRange<Int>

    static func defaults(for level: DifficultyLevel) -> FoxPathSettings {
        switch level {
        case .beginner:
            FoxPathSettings(
                foxSpeed: 48,
                followRadius: 230,
                lookAwayGrace: 0.7,
                refocusDwell: 0.35,
                straightRunRange: 2...3,
                turnHeightRange: 1...2
            )
        case .intermediate:
            FoxPathSettings(
                foxSpeed: 68,
                followRadius: 190,
                lookAwayGrace: 0.55,
                refocusDwell: 0.4,
                straightRunRange: 2...3,
                turnHeightRange: 1...3
            )
        case .advanced:
            FoxPathSettings(
                foxSpeed: 90,
                followRadius: 160,
                lookAwayGrace: 0.4,
                refocusDwell: 0.45,
                straightRunRange: 1...2,
                turnHeightRange: 2...4
            )
        }
    }
}

/// Everything needed to start one Follow the Fox game.
struct FoxPathConfiguration: Codable, Equatable {
    var level: DifficultyLevel = .beginner
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    /// Shows a small dot where the tracker thinks the child is looking.
    var showsGazeMarker: Bool = true
    /// Fixed seed for a reproducible map (research / QA). `nil` draws a new map every game.
    var randomSeed: UInt64?

    func settings(for level: DifficultyLevel) -> FoxPathSettings {
        FoxPathSettings.defaults(for: level)
    }

    static let settingsProvenance = ParameterProvenance.gameDesign
}

extension FoxPathConfiguration {
    /// Missing keys fall back to defaults, so settings saved by an older version still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = FoxPathConfiguration()
        level = try container.decodeIfPresent(DifficultyLevel.self, forKey: .level) ?? defaults.level
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? defaults.soundEnabled
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? defaults.hapticsEnabled
        showsGazeMarker = try container.decodeIfPresent(Bool.self, forKey: .showsGazeMarker) ?? defaults.showsGazeMarker
        randomSeed = try container.decodeIfPresent(UInt64.self, forKey: .randomSeed)
    }
}

/// Remembers the last used Follow the Fox settings on this device. Only settings are stored:
/// no gaze data and no results.
struct FoxPathConfigurationStore {
    private static let key = "foxPath.configuration"
    let defaults: UserDefaults

    static let standard = FoxPathConfigurationStore(defaults: .standard)

    func load() -> FoxPathConfiguration {
        guard let data = defaults.data(forKey: Self.key),
              let configuration = try? JSONDecoder().decode(FoxPathConfiguration.self, from: data) else {
            return FoxPathConfiguration()
        }
        return configuration
    }

    func save(_ configuration: FoxPathConfiguration) {
        defaults.set(try? JSONEncoder().encode(configuration), forKey: Self.key)
    }
}
