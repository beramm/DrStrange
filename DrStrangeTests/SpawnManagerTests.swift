import XCTest
@testable import DrStrange

final class SpawnManagerTests: XCTestCase {
    private func makeManager(
        level: DifficultyLevel = .advanced,
        rules: SpawnRules = SpawnRules(),
        seed: UInt64 = 42
    ) -> SpawnManager {
        SpawnManager(settings: .defaults(for: level), rules: rules, seed: seed)
    }

    func testSameSeedProducesSameSequence() {
        var a = makeManager(seed: 7)
        var b = makeManager(seed: 7)
        for _ in 0..<200 {
            XCTAssertEqual(a.makeSpawn(occupiedHoles: []), b.makeSpawn(occupiedHoles: []))
            XCTAssertEqual(a.nextInterval(), b.nextInterval())
        }
    }

    func testDifferentSeedsProduceDifferentSequences() {
        var a = makeManager(seed: 1)
        var b = makeManager(seed: 2)
        let holesA = (0..<50).compactMap { _ in a.makeSpawn(occupiedHoles: [])?.holeIndex }
        let holesB = (0..<50).compactMap { _ in b.makeSpawn(occupiedHoles: [])?.holeIndex }
        XCTAssertNotEqual(holesA, holesB)
    }

    func testHolesStayWithinActiveSetAndAvoidOccupied() {
        for level in DifficultyLevel.allCases {
            var manager = makeManager(level: level)
            let active = Set(DifficultySettings.defaults(for: level).activeHoleIndices)
            for _ in 0..<300 {
                let occupied: Set<Int> = active.count > 1 ? [active.sorted()[0]] : []
                let spawn = try! XCTUnwrap(manager.makeSpawn(occupiedHoles: occupied))
                XCTAssertTrue(active.contains(spawn.holeIndex))
                XCTAssertFalse(occupied.contains(spawn.holeIndex))
            }
        }
    }

    func testNoImmediateRepeatsAndMinimumSpacing() {
        var rules = SpawnRules()
        rules.noRepeatWindow = 2
        rules.minimumGridDistance = 1.5
        rules.maximumGridDistance = nil
        var manager = makeManager(level: .advanced, rules: rules)
        var history: [Int] = []
        for _ in 0..<500 {
            history.append(manager.makeSpawn(occupiedHoles: [])!.holeIndex)
        }
        for index in 1..<history.count {
            XCTAssertNotEqual(history[index], history[index - 1])
            XCTAssertGreaterThanOrEqual(SpawnManager.gridDistance(history[index], history[index - 1]), 1.5)
            if index >= 2 { XCTAssertNotEqual(history[index], history[index - 2]) }
        }
    }

    func testCoverageIsBalanced() {
        var manager = makeManager(level: .advanced)
        var counts: [Int: Int] = [:]
        let draws = 900
        for _ in 0..<draws {
            counts[manager.makeSpawn(occupiedHoles: [])!.holeIndex, default: 0] += 1
        }
        let expected = Double(draws) / 9
        for hole in 0..<9 {
            XCTAssertEqual(Double(counts[hole, default: 0]), expected, accuracy: expected * 0.25, "hole \(hole)")
        }
    }

    func testSequenceIsNotAFixedRotation() {
        var manager = makeManager(level: .beginner)
        let holes = (0..<60).map { _ in manager.makeSpawn(occupiedHoles: [])!.holeIndex }
        let period3 = zip(holes, holes.dropFirst(3)).allSatisfy { $0 == $1 }
        XCTAssertFalse(period3, "Spawn order should not cycle with a fixed period")
    }

    func testFallsBackWhenOnlyOneHoleIsFree() {
        var manager = makeManager(level: .beginner)
        _ = manager.makeSpawn(occupiedHoles: [])
        let last = manager.recentHoles.last!
        let others = Set([3, 4, 5]).subtracting([last])
        // Only the hole just used is free: constraints must relax instead of stalling.
        XCTAssertEqual(manager.makeSpawn(occupiedHoles: others)?.holeIndex, last)
        XCTAssertNil(manager.makeSpawn(occupiedHoles: [3, 4, 5]))
    }

    func testVariantsAreEquallyFrequent() {
        var manager = makeManager(level: .advanced)
        var counts: [CharacterVariant: Int] = [:]
        for _ in 0..<400 {
            counts[manager.makeSpawn(occupiedHoles: [])!.variant, default: 0] += 1
        }
        XCTAssertEqual(Set(counts.values), [100])
    }

    func testBeginnerUsesOneVariantAndNoDecoys() {
        var manager = makeManager(level: .beginner)
        for _ in 0..<100 {
            let spawn = manager.makeSpawn(occupiedHoles: [])!
            XCTAssertEqual(spawn.variant, .sunny)
            XCTAssertEqual(spawn.role, .target)
        }
    }

    func testDecoysNeverMoreThanTwoInARow() {
        var manager = makeManager(level: .advanced)
        var run = 0
        var decoys = 0
        for _ in 0..<1000 {
            if manager.makeSpawn(occupiedHoles: [])!.role == .decoy {
                run += 1
                decoys += 1
                XCTAssertLessThanOrEqual(run, 2)
            } else {
                run = 0
            }
        }
        XCTAssertGreaterThan(decoys, 150)
        XCTAssertLessThan(decoys, 300)
    }

    func testNoCornerToCornerJumps() {
        var manager = makeManager(level: .advanced)
        var previous: Int?
        for _ in 0..<1000 {
            let hole = manager.makeSpawn(occupiedHoles: [])!.holeIndex
            if let previous {
                XCTAssertLessThanOrEqual(SpawnManager.gridDistance(hole, previous), 2.3, "\(previous) -> \(hole)")
            }
            previous = hole
        }
    }

    func testTimingStaysInConfiguredRanges() {
        let settings = DifficultySettings.defaults(for: .intermediate)
        var manager = makeManager(level: .intermediate)
        for _ in 0..<200 {
            XCTAssertTrue(settings.spawnIntervalRange.contains(manager.nextInterval()))
            let duration = manager.makeSpawn(occupiedHoles: [])!.visibleDuration
            XCTAssertEqual(duration, settings.visibleDuration, accuracy: settings.visibleDuration * settings.visibleDurationJitter + 1e-9)
        }
    }
}

final class ShuffleBagTests: XCTestCase {
    func testEachElementOncePerBagAndNoRepeatAcrossRefill() {
        var generator = SeededGenerator(seed: 3)
        var bag = ShuffleBag([1, 2, 3, 4])
        var previous: Int?
        for _ in 0..<50 {
            let round = (0..<4).map { _ in bag.next(using: &generator) }
            XCTAssertEqual(Set(round), [1, 2, 3, 4])
            XCTAssertNotEqual(round.first, previous)
            previous = round.last
        }
    }
}
