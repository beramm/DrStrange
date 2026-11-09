import Foundation

/// Outcome of one character appearance.
enum TrialOutcome: Codable, Equatable {
    case hit(responseTime: TimeInterval)
    case missed
    case decoyTapped
    case decoyIgnored
}

struct TrialRecord: Codable, Equatable, Identifiable {
    let id: Int
    let holeIndex: Int
    let variant: CharacterVariant
    let role: TargetRole
    let level: DifficultyLevel
    /// Seconds of active play (pauses excluded) when the character appeared.
    let spawnedAt: TimeInterval
    var outcome: TrialOutcome?
    /// Optional for backwards compatibility with session files saved before proximity scoring.
    var pointsAwarded: Int?
}

enum SessionEndReason: String, Codable {
    /// The configured session length was reached.
    case timeUp
    /// Stopped from the exit button.
    case stopped
    /// Stopped from the pause screen to rest the eyes (discomfort, headache, tiredness).
    case restBreak
}

struct LevelChange: Codable, Equatable {
    let at: TimeInterval
    let from: DifficultyLevel
    let to: DifficultyLevel
}

/// Gameplay record of one session.
///
/// These are game performance indicators only. They are not diagnostic measurements and are not
/// evidence of clinical improvement.
struct GameSessionRecord: Codable, Equatable, Identifiable {
    static let defaultPointsPerHit = 10

    let id: UUID
    let gameIdentifier: String
    let startedAt: Date
    var endedAt: Date?
    var completed: Bool = false
    var endReason: SessionEndReason?
    let configuration: GameConfiguration
    var finalLevel: DifficultyLevel
    var activePlayDuration: TimeInterval = 0
    var trials: [TrialRecord] = []
    var offTargetTaps: Int = 0
    var levelChanges: [LevelChange] = []

    init(configuration: GameConfiguration, startedAt: Date, id: UUID = UUID()) {
        self.id = id
        self.gameIdentifier = "whack-a-mole"
        self.startedAt = startedAt
        self.configuration = configuration
        self.finalLevel = configuration.startingLevel
    }

    private var realTargets: [TrialRecord] { trials.filter { $0.role == .target && $0.outcome != nil } }

    var targetsSpawned: Int { realTargets.count }

    var hits: Int {
        realTargets.filter { if case .hit = $0.outcome { true } else { false } }.count
    }

    var misses: Int { realTargets.filter { $0.outcome == .missed }.count }

    var decoysShown: Int { trials.filter { $0.role == .decoy && $0.outcome != nil }.count }

    var decoyTaps: Int { trials.filter { $0.outcome == .decoyTapped }.count }

    /// Saved per-hit points, with the original 10-point rule retained for legacy sessions.
    var score: Int {
        realTargets.reduce(into: 0) { total, trial in
            if case .hit = trial.outcome {
                total += trial.pointsAwarded ?? Self.defaultPointsPerHit
            }
        }
    }

    /// Hits divided by real targets that finished (hit or missed). `nil` before any target finishes.
    var accuracy: Double? {
        targetsSpawned == 0 ? nil : Double(hits) / Double(targetsSpawned)
    }

    /// Mean time from a character starting to appear until it was tapped.
    var averageResponseTime: TimeInterval? {
        let times = realTargets.compactMap { trial -> TimeInterval? in
            if case let .hit(responseTime) = trial.outcome { responseTime } else { nil }
        }
        return times.isEmpty ? nil : times.reduce(0, +) / Double(times.count)
    }

    /// Wall-clock time from start to end, including pauses.
    var elapsedDuration: TimeInterval? {
        endedAt.map { $0.timeIntervalSince(startedAt) }
    }
}
