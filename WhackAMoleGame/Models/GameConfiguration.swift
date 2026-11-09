import Foundation

/// Where a default value comes from. Every tunable number in the game carries one of these
/// so a clinical reviewer can tell gameplay choices apart from values that need validation.
enum ParameterProvenance: String, Codable {
    /// Pure gameplay / usability choice. No therapeutic meaning is implied.
    case gameDesign
    /// Entered by a parent or caregiver from the child's eye-care plan. The app suggests no value.
    case caregiverEntered
    /// Placeholder that must be set or approved by an ophthalmologist or orthoptist before clinical use.
    case requiresClinicalValidation
}

/// Game difficulty. This is a gameplay setting only and must not be read as therapeutic intensity.
enum DifficultyLevel: Int, CaseIterable, Codable, Identifiable, Comparable {
    case beginner = 1
    case intermediate = 2
    case advanced = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
    }

    var next: DifficultyLevel? { DifficultyLevel(rawValue: rawValue + 1) }
    var previous: DifficultyLevel? { DifficultyLevel(rawValue: rawValue - 1) }

    static func < (lhs: DifficultyLevel, rhs: DifficultyLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Per-level gameplay parameters. All values are `.gameDesign` placeholders unless noted.
struct DifficultySettings: Codable, Equatable {
    /// Zones of the board (a hidden 3 x 3 grid, 0 = top-left, 8 = bottom-right) where holes may open.
    /// No hole is shown until a mole is about to appear, at a random spot inside its zone.
    var activeHoleIndices: [Int]
    /// How much of the board (0...1, centred) holes may open in. Smaller keeps eye movements short.
    var boardSpread: Double
    /// Size of the hole and its mole, relative to the largest size. Larger is easier to see.
    var targetScale: Double
    /// Seconds between one spawn and the next, drawn uniformly from this range.
    var spawnIntervalRange: ClosedRange<Double>
    /// Seconds a character stays up before it hides again.
    var visibleDuration: Double
    /// Random +/- fraction applied to `visibleDuration` so timing is not perfectly predictable.
    var visibleDurationJitter: Double
    /// Maximum characters up at the same time. Kept low to avoid overwhelming the child.
    var maxSimultaneousTargets: Int
    /// How many of the available character looks are mixed in at this level.
    var characterVariantCount: Int
    /// Chance that a spawn is a sleeping mole (decoy) that should be left alone (no penalty if tapped).
    var decoyProbability: Double

    static func defaults(for level: DifficultyLevel) -> DifficultySettings {
        switch level {
        case .beginner:
            DifficultySettings(
                activeHoleIndices: [3, 4, 5],
                boardSpread: 0.75,
                targetScale: 0.95,
                spawnIntervalRange: 2.6...3.6,
                visibleDuration: 3.2,
                visibleDurationJitter: 0.1,
                maxSimultaneousTargets: 1,
                characterVariantCount: 1,
                decoyProbability: 0
            )
        case .intermediate:
            DifficultySettings(
                activeHoleIndices: [0, 1, 2, 3, 4, 5],
                boardSpread: 0.9,
                targetScale: 0.8,
                spawnIntervalRange: 1.9...2.9,
                visibleDuration: 2.6,
                visibleDurationJitter: 0.1,
                maxSimultaneousTargets: 2,
                characterVariantCount: 3,
                decoyProbability: 0
            )
        case .advanced:
            DifficultySettings(
                activeHoleIndices: Array(0..<9),
                boardSpread: 1,
                targetScale: 0.68,
                spawnIntervalRange: 1.5...2.5,
                visibleDuration: 2.2,
                visibleDurationJitter: 0.15,
                maxSimultaneousTargets: 2,
                characterVariantCount: 4,
                decoyProbability: 0.25
            )
        }
    }
}

/// Rules for where characters may appear. All `.gameDesign`.
struct SpawnRules: Codable, Equatable {
    /// A hole used in the last `noRepeatWindow` spawns is skipped when another hole is free.
    var noRepeatWindow: Int = 2
    /// Minimum grid distance (in cells) from the previous spawn. 1.0 = any other cell, 2.0 = not adjacent.
    var minimumGridDistance: Double = 1.0
    /// Maximum grid distance from the previous spawn, so the eye never has to jump corner to
    /// opposite corner (2.83 cells). `nil` removes the limit.
    var maximumGridDistance: Double? = 2.3
    /// Minimum distance between a new hole and other open holes or the previous hole, as a fraction
    /// of the board, so holes never overlap or reappear in the same spot.
    var minimumHoleSeparation: Double = 0.42
    /// Seconds a hole takes to open before its mole starts climbing out.
    var holeOpenDuration: Double = 0.28
    /// Seconds a hole takes to close after its mole has gone.
    var holeCloseDuration: Double = 0.25
    /// Delay before the first character of a session.
    var leadInDelay: Double = 1.0
    /// Retry delay when every allowed hole is busy.
    var busyRetryDelay: Double = 0.25
    /// Seconds a mole takes to climb out of its hole (the rise frames, played forwards).
    var moleRiseDuration: Double = 0.55
    /// Seconds a mole takes to go back down (the same frames, played backwards).
    var exitAnimationDuration: Double = 0.45
}

/// Performance-based level changes. Thresholds are `.gameDesign` placeholders.
struct AdaptiveDifficultyRules: Codable, Equatable {
    var isEnabled: Bool = true
    /// Number of recent real targets used to compute accuracy.
    var evaluationWindow: Int = 10
    /// Move up a level when recent accuracy is at or above this.
    var promoteAccuracy: Double = 0.85
    /// Move down a level when recent accuracy is at or below this.
    var demoteAccuracy: Double = 0.5
}

/// Everything needed to start one Whack-a-Mole session.
struct GameConfiguration: Codable, Equatable {
    var startingLevel: DifficultyLevel = .beginner
    /// Length of one game session in seconds, entered by a parent or caregiver to match the play
    /// time the child's eye doctor advised (`.caregiverEntered`). The default only makes the game
    /// playable out of the box; it is not a recommendation.
    var sessionDuration: TimeInterval = 120
    var adaptiveDifficulty = AdaptiveDifficultyRules()
    var spawnRules = SpawnRules()
    var foxAttack = FoxAttackTiming()
    var patching = PatchingConfiguration()
    /// Engineering switch for testing gaze control without a patch. Production behavior defaults on.
    var oneEyeEnforcerEnabled = true
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    /// Fixed seed for reproducible sessions (research / QA). `nil` picks a fresh seed each session.
    var randomSeed: UInt64?

    func settings(for level: DifficultyLevel) -> DifficultySettings {
        DifficultySettings.defaults(for: level)
    }

    static let sessionDurationProvenance = ParameterProvenance.caregiverEntered
    /// Allowed session lengths in minutes for the caregiver stepper.
    static let sessionMinutesRange = 1...60
}

extension GameConfiguration {
    /// Missing keys fall back to defaults, so settings saved by an older version of the game
    /// (for example before `foxAttack` existed) still load instead of being reset.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = GameConfiguration()
        startingLevel = try container.decodeIfPresent(DifficultyLevel.self, forKey: .startingLevel) ?? defaults.startingLevel
        sessionDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .sessionDuration) ?? defaults.sessionDuration
        adaptiveDifficulty = try container.decodeIfPresent(AdaptiveDifficultyRules.self, forKey: .adaptiveDifficulty) ?? defaults.adaptiveDifficulty
        spawnRules = (try? container.decodeIfPresent(SpawnRules.self, forKey: .spawnRules)) ?? defaults.spawnRules
        // Timing saved by an older version has different fields; fall back to the defaults.
        foxAttack = (try? container.decodeIfPresent(FoxAttackTiming.self, forKey: .foxAttack)) ?? defaults.foxAttack
        patching = try container.decodeIfPresent(PatchingConfiguration.self, forKey: .patching) ?? defaults.patching
        oneEyeEnforcerEnabled = try container.decodeIfPresent(Bool.self, forKey: .oneEyeEnforcerEnabled) ?? defaults.oneEyeEnforcerEnabled
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? defaults.soundEnabled
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? defaults.hapticsEnabled
        randomSeed = try container.decodeIfPresent(UInt64.self, forKey: .randomSeed)
    }
}
