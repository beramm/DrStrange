import Foundation

struct SpawnRequest: Equatable {
    let holeIndex: Int
    let position: BoardPoint
    let artIndex: Int
    let variant: CharacterVariant
    let role: TargetRole
    let visibleDuration: TimeInterval
}

/// Decides where, when and what spawns. Pure logic with a seeded generator, so it is fully testable
/// and every session can be reproduced from `seed`.
///
/// Rules (all configurable, see `SpawnRules` and `DifficultySettings`):
/// - Position: first a free, active zone of the board (a hidden 3 x 3 grid) that was not used in the
///   last `noRepeatWindow` spawns and is between `minimumGridDistance` and `maximumGridDistance`
///   cells from the previous spawn (spaced out, but no corner-to-corner jumps). Among those,
///   less-used zones are weighted higher so coverage evens out without becoming a fixed rotation.
///   Constraints are relaxed one at a time until at least two zones qualify, so the next spawn is
///   never certain. Then a random spot inside that zone, at least `minimumHoleSeparation` from other
///   open holes and the previous hole. Nothing is shown until the hole opens there.
/// - Timing: uniform draw from `spawnIntervalRange`; visibility = `visibleDuration` +/- jitter.
/// - Look: shuffle bag over the board's character variants, so each look appears equally often.
/// - Role: decoys with `decoyProbability`, never more than two in a row.
struct SpawnManager {
    static let gridColumns = 3

    let seed: UInt64
    let settings: DifficultySettings
    let rules: SpawnRules

    private var generator: SeededGenerator
    private var variantBag: ShuffleBag<CharacterVariant>
    private var artBag = ShuffleBag([0, 1, 2])
    private var previousPosition: BoardPoint?
    private(set) var recentHoles: [Int] = []
    private(set) var holeCounts: [Int: Int] = [:]
    private var consecutiveDecoys = 0

    init(settings: DifficultySettings, rules: SpawnRules, seed: UInt64) {
        self.seed = seed
        self.settings = settings
        self.rules = rules
        self.generator = SeededGenerator(seed: seed)
        self.variantBag = ShuffleBag(Self.variants(for: settings))
    }

    mutating func nextInterval() -> TimeInterval {
        Double.random(in: settings.spawnIntervalRange, using: &generator)
    }

    /// Returns `nil` when every active zone is occupied.
    /// `openPositions` are the holes currently on the board, which the new one must keep clear of.
    mutating func makeSpawn(occupiedHoles: Set<Int>, openPositions: [BoardPoint] = []) -> SpawnRequest? {
        guard let hole = chooseHole(occupied: occupiedHoles) else { return nil }
        recentHoles.append(hole)
        if recentHoles.count > max(rules.noRepeatWindow, 1) { recentHoles.removeFirst() }
        holeCounts[hole, default: 0] += 1

        let jitter = settings.visibleDurationJitter
        let duration = settings.visibleDuration * Double.random(in: (1 - jitter)...(1 + jitter), using: &generator)

        let position = choosePosition(inZone: hole, openPositions: openPositions)
        previousPosition = position

        return SpawnRequest(
            holeIndex: hole,
            position: position,
            artIndex: artBag.next(using: &generator),
            variant: variantBag.next(using: &generator),
            role: chooseRole(),
            visibleDuration: duration
        )
    }

    static func gridDistance(_ a: Int, _ b: Int) -> Double {
        let dx = Double(a % gridColumns - b % gridColumns)
        let dy = Double(a / gridColumns - b / gridColumns)
        return (dx * dx + dy * dy).squareRoot()
    }

    // MARK: - Private

    /// A random spot inside the zone, spread over the part of the board this level uses. If no spot
    /// clears everything, staying clear of open holes matters most, then the previous hole.
    private mutating func choosePosition(inZone zone: Int, openPositions: [BoardPoint]) -> BoardPoint {
        let rows = Array(Set(settings.activeHoleIndices.map { $0 / Self.gridColumns })).sorted()
        let rowIndex = rows.firstIndex(of: zone / Self.gridColumns) ?? 0
        let column = zone % Self.gridColumns
        let spread = settings.boardSpread
        let separation = rules.minimumHoleSeparation
        var best = BoardPoint(x: 0.5, y: 0.5)
        var bestScore = -Double.infinity
        for _ in 0..<64 {
            let x = (Double(column) + Double.random(in: 0..<1, using: &generator)) / Double(Self.gridColumns)
            let y = (Double(rowIndex) + Double.random(in: 0..<1, using: &generator)) / Double(rows.count)
            let candidate = BoardPoint(x: 0.5 + (x - 0.5) * spread, y: 0.5 + (y - 0.5) * spread)
            let fromOpen = openPositions.map { $0.distance(to: candidate) }.min() ?? .infinity
            let fromPrevious = previousPosition?.distance(to: candidate) ?? .infinity
            if fromOpen >= separation && fromPrevious >= separation { return candidate }
            let score = min(fromOpen, separation) * 2 + min(fromPrevious, separation)
            if score > bestScore {
                best = candidate
                bestScore = score
            }
        }
        return best
    }

    private mutating func chooseHole(occupied: Set<Int>) -> Int? {
        let free = settings.activeHoleIndices.filter { !occupied.contains($0) }
        guard !free.isEmpty else { return nil }

        let recent = Set(recentHoles.suffix(rules.noRepeatWindow))
        let previous = recentHoles.last
        let minimumDistance = rules.minimumGridDistance
        let maximumDistance = rules.maximumGridDistance ?? .infinity
        let comfortablySpaced: (Int) -> Bool = { hole in
            guard let previous else { return true }
            let distance = Self.gridDistance(hole, previous)
            return distance >= minimumDistance && distance <= maximumDistance
        }

        // Strictest first, then relax: spacing, then repetition. A rule set that leaves only one
        // hole would make the next spawn fully predictable (with 3 holes and a window of 2 it
        // becomes a fixed A-B-C rotation), so prefer the strictest set that still offers a choice.
        let candidateSets = [
            free.filter { !recent.contains($0) && comfortablySpaced($0) },
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
}
