import Foundation

/// The score earned from a confirmed gaze hit, based on distance from the character's centre.
enum GazeProximityTier: Int, Equatable {
    case outer = 20
    case middle = 30
    case inner = 60

    var points: Int { rawValue }

    init(normalizedDistance: Double) {
        switch normalizedDistance {
        case ...0.35: self = .inner
        case ...0.70: self = .middle
        default: self = .outer
        }
    }
}

/// One active character close enough to continue a dwell.
struct GazeFocusCandidate: Equatable {
    let targetID: Int
    let holeIndex: Int
    /// Distance from the character's centre divided by the outer activation radius.
    let normalizedDistance: Double
}

struct GazeActivation: Equatable {
    let targetID: Int
    let holeIndex: Int
    let tier: GazeProximityTier
}

struct GazeDwellUpdate: Equatable {
    var progress: Double = 0
    var tier: GazeProximityTier?
    var activation: GazeActivation?
}

/// Converts continuous gaze near one character into one deliberate, proximity-scored activation.
/// Distance samples are held only for the current dwell and are discarded immediately afterwards.
struct GazeDwellSelector {
    static let defaultDwellNanoseconds: UInt64 = 1_000_000_000
    static let defaultScoringWindowNanoseconds: UInt64 = 400_000_000

    private let dwellNanoseconds: UInt64
    private let scoringWindowNanoseconds: UInt64
    private var focusedTargetID: Int?
    private var focusedHoleIndex: Int?
    private var focusStartedAt: UInt64?
    private var distanceSamples: [(timestamp: UInt64, distance: Double)] = []
    private var latchedTargetID: Int?

    init(
        dwellNanoseconds: UInt64 = Self.defaultDwellNanoseconds,
        scoringWindowNanoseconds: UInt64 = Self.defaultScoringWindowNanoseconds
    ) {
        self.dwellNanoseconds = dwellNanoseconds
        self.scoringWindowNanoseconds = scoringWindowNanoseconds
    }

    mutating func consume(
        candidate: GazeFocusCandidate?,
        timestampNanoseconds: UInt64,
        isUsable: Bool
    ) -> GazeDwellUpdate {
        guard isUsable, let candidate else {
            clearFocus()
            latchedTargetID = nil
            return GazeDwellUpdate()
        }

        if latchedTargetID == candidate.targetID { return GazeDwellUpdate() }
        if latchedTargetID != nil { latchedTargetID = nil }

        guard focusedTargetID == candidate.targetID,
              let focusStartedAt,
              timestampNanoseconds >= focusStartedAt else {
            beginFocus(on: candidate, at: timestampNanoseconds)
            return GazeDwellUpdate(tier: GazeProximityTier(normalizedDistance: candidate.normalizedDistance))
        }

        distanceSamples.append((timestampNanoseconds, candidate.normalizedDistance))
        pruneSamples(at: timestampNanoseconds)

        let elapsed = timestampNanoseconds - focusStartedAt
        let progress = dwellNanoseconds == 0 ? 1 : min(Double(elapsed) / Double(dwellNanoseconds), 1)
        let tier = scoringTier()

        guard elapsed >= dwellNanoseconds else {
            return GazeDwellUpdate(progress: progress, tier: tier)
        }

        let activation = GazeActivation(
            targetID: candidate.targetID,
            holeIndex: focusedHoleIndex ?? candidate.holeIndex,
            tier: tier
        )
        latchedTargetID = candidate.targetID
        clearFocus()
        return GazeDwellUpdate(progress: 1, tier: tier, activation: activation)
    }

    mutating func reset() {
        clearFocus()
        latchedTargetID = nil
    }

    private mutating func beginFocus(on candidate: GazeFocusCandidate, at timestamp: UInt64) {
        focusedTargetID = candidate.targetID
        focusedHoleIndex = candidate.holeIndex
        focusStartedAt = timestamp
        distanceSamples = [(timestamp, candidate.normalizedDistance)]
    }

    private mutating func pruneSamples(at timestamp: UInt64) {
        let earliest = timestamp > scoringWindowNanoseconds ? timestamp - scoringWindowNanoseconds : 0
        distanceSamples.removeAll { $0.timestamp < earliest }
    }

    private func scoringTier() -> GazeProximityTier {
        let sorted = distanceSamples.map(\.distance).sorted()
        guard !sorted.isEmpty else { return .outer }
        let middle = sorted.count / 2
        let median = sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
        return GazeProximityTier(normalizedDistance: median)
    }

    private mutating func clearFocus() {
        focusedTargetID = nil
        focusedHoleIndex = nil
        focusStartedAt = nil
        distanceSamples.removeAll(keepingCapacity: true)
    }
}
