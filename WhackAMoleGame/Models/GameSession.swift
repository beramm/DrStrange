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
    /// Seconds of active play (pauses excluded) when the character appeared.
    let spawnedAt: TimeInterval
    /// Where on the board the hole opened. Missing in sessions saved before holes were random.
    var position: BoardPoint?
    var outcome: TrialOutcome?
}

enum SessionEndReason: String, Codable {
    /// The configured session length was reached.
    case timeUp
    /// Stopped from the exit button.
    case stopped
    /// Stopped from the pause screen to rest the eyes (discomfort, headache, tiredness).
    case restBreak
}

/// Gameplay record of one session.
///
/// These are game performance indicators only. They are not diagnostic measurements and are not
/// evidence of clinical improvement.
struct GameSessionRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let gameIdentifier: String
    let startedAt: Date
    var endedAt: Date?
    var completed: Bool = false
    var endReason: SessionEndReason?
    let configuration: GameConfiguration
    var activePlayDuration: TimeInterval = 0
    var trials: [TrialRecord] = []
    var offTargetTaps: Int = 0

    init(configuration: GameConfiguration, startedAt: Date, id: UUID = UUID()) {
        self.id = id
        self.gameIdentifier = "whack-a-mole"
        self.startedAt = startedAt
        self.configuration = configuration
    }

    private var realTargets: [TrialRecord] { trials.filter { $0.role == .target && $0.outcome != nil } }

    var targetsSpawned: Int { realTargets.count }

    var hits: Int {
        realTargets.filter { if case .hit = $0.outcome { true } else { false } }.count
    }

    var misses: Int { realTargets.filter { $0.outcome == .missed }.count }

    var decoysShown: Int { trials.filter { $0.role == .decoy && $0.outcome != nil }.count }

    var decoyTaps: Int { trials.filter { $0.outcome == .decoyTapped }.count }

    /// Hits divided by real targets that finished (hit or missed). `nil` before any target finishes.
    var accuracy: Double? {
        targetsSpawned == 0 ? nil : Double(hits) / Double(targetsSpawned)
    }

    /// Rating of each hit, in the order the characters appeared.
    var hitRatings: [HitRating] {
        realTargets.compactMap { trial -> HitRating? in
            if case let .hit(responseTime) = trial.outcome {
                configuration.scoring.rating(forResponseTime: responseTime)
            } else {
                nil
            }
        }
    }

    /// Points from every hit: Perfect 30, Great 20, Good 10. Misses and sleepy taps cost nothing.
    var score: Int { hitRatings.reduce(0) { $0 + $1.points } }

    func count(of rating: HitRating) -> Int { hitRatings.filter { $0 == rating }.count }

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
