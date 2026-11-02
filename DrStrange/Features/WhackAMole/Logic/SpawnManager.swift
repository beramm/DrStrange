import Foundation

struct SpawnRequest: Equatable {
    let holeIndex: Int
    let variant: CharacterVariant
    let role: TargetRole
    let stimulus: StimulusAssignment
    let visibleDuration: TimeInterval
}

/// Decides where, when and what spawns. Pure logic with a seeded generator, so it is fully testable
/// and every session can be reproduced from `seed`.
///
/// Rules (all configurable, see `SpawnRules` and `DifficultySettings`):
/// - Position: a free, active hole that was not used in the last `noRepeatWindow` spawns and is at
///   least `minimumGridDistance` cells from the previous spawn. Among those, less-used holes are
///   weighted higher so coverage evens out without becoming a fixed rotation. Constraints are
///   relaxed one at a time until at least two holes qualify, so the next spawn is never certain.
/// - Timing: uniform draw from `spawnIntervalRange`; visibility = `visibleDuration` +/- jitter.
/// - Look: shuffle bag over the level's character variants, so each look appears equally often.
/// - Role: decoys with `decoyProbability`, never more than two in a row.
/// - Eye assignment: shuffle bag sized so the share of features sent to the amblyopic eye matches
///   `criticalFeatureAmblyopicShare` over every block of 10 spawns.
struct SpawnManager {
    static let gridColumns = 3
    static let eyeBlockSize = 10

    let seed: UInt64
    private(set) var settings: DifficultySettings
    let rules: SpawnRules
    let therapy: TherapyConfiguration

    private var generator: SeededGenerator
    private var variantBag: ShuffleBag<CharacterVariant>
    private var featureEyeBag: ShuffleBag<Eye>
    private(set) var recentHoles: [Int] = []
    private(set) var holeCounts: [Int: Int] = [:]
    private var consecutiveDecoys = 0

    init(settings: DifficultySettings, rules: SpawnRules, therapy: TherapyConfiguration, seed: UInt64) {
        self.seed = seed
        self.settings = settings
        self.rules = rules
        self.therapy = therapy
        self.generator = SeededGenerator(seed: seed)
        self.variantBag = ShuffleBag(Self.variants(for: settings))
        self.featureEyeBag = ShuffleBag(Self.featureEyeBlock(for: therapy))
    }

    mutating func update(settings newSettings: DifficultySettings) {
        if newSettings.characterVariantCount != settings.characterVariantCount {
            variantBag = ShuffleBag(Self.variants(for: newSettings))
        }
        settings = newSettings
    }

    mutating func nextInterval() -> TimeInterval {
        Double.random(in: settings.spawnIntervalRange, using: &generator)
    }

    /// Returns `nil` when every active hole is occupied.
    mutating func makeSpawn(occupiedHoles: Set<Int>) -> SpawnRequest? {
        guard let hole = chooseHole(occupied: occupiedHoles) else { return nil }
        recentHoles.append(hole)
        if recentHoles.count > max(rules.noRepeatWindow, 1) { recentHoles.removeFirst() }
        holeCounts[hole, default: 0] += 1

        let jitter = settings.visibleDurationJitter
        let duration = settings.visibleDuration * Double.random(in: (1 - jitter)...(1 + jitter), using: &generator)

        return SpawnRequest(
            holeIndex: hole,
            variant: variantBag.next(using: &generator),
            role: chooseRole(),
            stimulus: StimulusAssignment(featureEye: featureEyeBag.next(using: &generator)),
            visibleDuration: duration
        )
    }

    static func gridDistance(_ a: Int, _ b: Int) -> Double {
        let dx = Double(a % gridColumns - b % gridColumns)
        let dy = Double(a / gridColumns - b / gridColumns)
        return (dx * dx + dy * dy).squareRoot()
    }

    // MARK: - Private

    private mutating func chooseHole(occupied: Set<Int>) -> Int? {
        let free = settings.activeHoleIndices.filter { !occupied.contains($0) }
        guard !free.isEmpty else { return nil }

        let recent = Set(recentHoles.suffix(rules.noRepeatWindow))
        let previous = recentHoles.last
        let minimumDistance = rules.minimumGridDistance
        let farEnough: (Int) -> Bool = { hole in
            guard let previous else { return true }
            return Self.gridDistance(hole, previous) >= minimumDistance
        }

        // Strictest first, then relax: spacing, then repetition. A rule set that leaves only one
        // hole would make the next spawn fully predictable (with 3 holes and a window of 2 it
        // becomes a fixed A-B-C rotation), so prefer the strictest set that still offers a choice.
        let candidateSets = [
            free.filter { !recent.contains($0) && farEnough($0) },
            free.filter { !recent.contains($0) },
            free.filter { $0 != previous },
            free,
        ]
        let candidates = candidateSets.first { $0.count >= 2 } ?? candidateSets.first { !$0.isEmpty } ?? free
        return weightedPick(candidates)
    }

    /// Less-used holes are more likely, which balances coverage while staying unpredictable.
    private mutating func weightedPick(_ holes: [Int]) -> Int {
        let weights = holes.map { 1.0 / Double(1 + holeCounts[$0, default: 0]) }
        var roll = Double.random(in: 0..<weights.reduce(0, +), using: &generator)
        for (hole, weight) in zip(holes, weights) {
            if roll < weight { return hole }
            roll -= weight
        }
        return holes[holes.count - 1]
    }

    private mutating func chooseRole() -> TargetRole {
        guard settings.decoyProbability > 0, consecutiveDecoys < 2,
              Double.random(in: 0..<1, using: &generator) < settings.decoyProbability else {
            consecutiveDecoys = 0
            return .target
        }
        consecutiveDecoys += 1
        return .decoy
    }

    private static func variants(for settings: DifficultySettings) -> [CharacterVariant] {
        let count = min(max(settings.characterVariantCount, 1), CharacterVariant.allCases.count)
        return Array(CharacterVariant.allCases.prefix(count))
    }

    /// One block of feature-eye assignments. Without an amblyopic eye set, left and right are equal.
    static func featureEyeBlock(for therapy: TherapyConfiguration) -> [Eye] {
        guard let amblyopicEye = therapy.amblyopicEye else {
            return Array(repeating: .left, count: eyeBlockSize / 2) + Array(repeating: .right, count: eyeBlockSize / 2)
        }
        let share = min(max(therapy.criticalFeatureAmblyopicShare, 0), 1)
        let amblyopicCount = Int((share * Double(eyeBlockSize)).rounded())
        return Array(repeating: amblyopicEye, count: amblyopicCount)
            + Array(repeating: amblyopicEye.other, count: eyeBlockSize - amblyopicCount)
    }
}
