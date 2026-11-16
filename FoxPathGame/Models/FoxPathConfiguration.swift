import Foundation

/// Walking and following parameters for Follow the Fox. Every value is a `.gameDesign`
/// placeholder that is subject to clinical review; none of them implies a therapeutic intensity.
struct FoxPathSettings: Codable, Equatable {
    /// Walking speed in map units per second. One path tile is 128 units wide.
    var foxSpeed: Double
    /// How far from the character (screen points) the gaze may be and still count as following
    /// it. The radius grows with the character when the map is zoomed in.
    var followRadius: Double
    /// Seconds the gaze may leave the character before it stops and the warning shows.
    var lookAwayGrace: Double
    /// Seconds the gaze must rest on the character again before it walks on.
    var refocusDwell: Double
    /// Tiles the path runs straight between two turns.
    var straightRunRange: ClosedRange<Int>
    /// Rows the path climbs or drops in one turn.
    var turnHeightRange: ClosedRange<Int>

    /// The one setting every game uses (there are no levels).
    static let standard = FoxPathSettings(
        foxSpeed: 100,
        followRadius: 190,
        lookAwayGrace: 0.55,
        refocusDwell: 0.4,
        straightRunRange: 2...3,
        turnHeightRange: 1...3
    )
}

/// How the thief behaves. `.gameDesign` placeholders, subject to clinical review.
///
/// A thief only ever comes because the child stopped following; there is no timer that sends
/// one. Missing gaze readings never bring a thief.
struct ThiefSettings: Codable, Equatable {
    /// Seconds the child must keep not following (on top of the look-away grace) before a
    /// thief comes, so a quick glance away does not bring one.
    var triggerDelay: Double = 0.5
    /// Seconds after a thief has left before another one can come.
    var cooldown: Double = 4
    /// No new thief comes when fewer seconds than this are left in the game.
    var minimumTimeLeft: Double = 3
    /// No new thief comes when the character the child follows is this close to the stall
    /// (map units), because the walk is about to end.
    var minimumWalkLeft: Double = 100
    /// Seconds the thief takes to come into view.
    var appearDuration: Double = 1
    /// Seconds of not following that take the thief from where it lurks to the character. Short,
    /// so the thief rushes in.
    var approachDuration: Double = 1
    /// While the child follows, the thief backs away at this fraction of its approach speed.
    var backOffRate: Double = 0.6
    /// Seconds of following without a break that chase a thief off before it reaches the
    /// character.
    var chasedOffAfter: Double = 2.5
    /// Seconds the thief stays around without reaching the character before it gives up and
    /// leaves.
    var patience: Double = 14
    /// Seconds the thief takes to run off.
    var retreatDuration: Double = 2
}

/// Everything needed to start one Follow the Fox game.
struct FoxPathConfiguration: Codable, Equatable {
    /// Every game lasts 2 minutes, counted from the first look at the character (pauses
    /// excluded). The length of one game, not a recommended play or patching time.
    static let sessionDuration: TimeInterval = 120
    /// Hearts at the start of a game. A successful theft costs one.
    static let initialLives = 3

    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    /// Shows a small dot where the tracker thinks the child is looking.
    var showsGazeMarker: Bool = true
    /// Fixed seed for reproducible maps, roles and thieves (research / QA). `nil` draws new ones
    /// every game.
    var randomSeed: UInt64?

    var settings: FoxPathSettings { .standard }
    var thief: ThiefSettings { ThiefSettings() }

    static let settingsProvenance = ParameterProvenance.gameDesign
}

extension FoxPathConfiguration {
    /// Missing keys fall back to defaults, so settings saved by an older version still load.
    /// The level saved by older versions is ignored.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = FoxPathConfiguration()
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
