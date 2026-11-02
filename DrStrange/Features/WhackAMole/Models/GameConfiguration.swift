import Foundation

/// Where a default value comes from. Every tunable number in the game carries one of these
/// so a clinical reviewer can tell gameplay choices apart from values that need validation.
enum ParameterProvenance: String, Codable {
    /// Pure gameplay / usability choice. No therapeutic meaning is implied.
    case gameDesign
    /// The *direction* follows published dichoptic-game designs; the exact value is still a placeholder.
    case literatureInformed
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
    /// Indices into the 3 x 3 hole grid (0 = top-left, 8 = bottom-right) that can spawn characters.
    var activeHoleIndices: [Int]
    /// Character height as a fraction of a hole cell. Larger is easier to see.
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
    /// Chance that a spawn is a "sleepy" decoy that should be left alone (no penalty if tapped).
    var decoyProbability: Double
    /// Static, low-contrast decorations around the board (extra visual elements at higher levels).
    var showsBackgroundDecorations: Bool

    static func defaults(for level: DifficultyLevel) -> DifficultySettings {
        switch level {
        case .beginner:
            DifficultySettings(
                activeHoleIndices: [3, 4, 5],
                targetScale: 0.95,
                spawnIntervalRange: 2.6...3.6,
                visibleDuration: 3.2,
                visibleDurationJitter: 0.1,
                maxSimultaneousTargets: 1,
                characterVariantCount: 1,
                decoyProbability: 0,
                showsBackgroundDecorations: false
            )
        case .intermediate:
            DifficultySettings(
                activeHoleIndices: [0, 1, 2, 3, 4, 5],
                targetScale: 0.8,
                spawnIntervalRange: 1.9...2.9,
                visibleDuration: 2.6,
                visibleDurationJitter: 0.1,
                maxSimultaneousTargets: 2,
                characterVariantCount: 3,
                decoyProbability: 0,
                showsBackgroundDecorations: false
            )
        case .advanced:
            DifficultySettings(
                activeHoleIndices: Array(0..<9),
                targetScale: 0.68,
                spawnIntervalRange: 1.5...2.5,
                visibleDuration: 2.2,
                visibleDurationJitter: 0.15,
                maxSimultaneousTargets: 2,
                characterVariantCount: 4,
                decoyProbability: 0.25,
                showsBackgroundDecorations: true
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
    /// Delay before the first character of a session.
    var leadInDelay: Double = 1.0
    /// Retry delay when every allowed hole is busy.
    var busyRetryDelay: Double = 0.25
    /// Seconds a hidden or hit character stays on the board for its exit animation.
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
    /// Session length in seconds. Placeholder: wear time and session length are clinical decisions.
    var sessionDuration: TimeInterval = 120
    var adaptiveDifficulty = AdaptiveDifficultyRules()
    var spawnRules = SpawnRules()
    var therapy = TherapyConfiguration()
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    /// Fixed seed for reproducible sessions (research / QA). `nil` picks a fresh seed each session.
    var randomSeed: UInt64?

    func settings(for level: DifficultyLevel) -> DifficultySettings {
        DifficultySettings.defaults(for: level)
    }

    static let sessionDurationProvenance = ParameterProvenance.requiresClinicalValidation
    static let sessionDurationOptions: [TimeInterval] = [60, 120, 180, 300]
}
