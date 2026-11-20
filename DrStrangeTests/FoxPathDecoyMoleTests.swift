import XCTest
@testable import DrStrange

/// The decoy moles that pop up on the grass to tempt the eyes away.
final class FoxPathDecoyMoleTests: XCTestCase {
    private let step = 1.0 / 60

    private func makeMap(seed: UInt64 = 22) -> FoxPathMap {
        FoxPathGenerator.makeMap(seed: seed, settings: .standard)
    }

    private func feet(on map: FoxPathMap, at fraction: CGFloat = 0.4) -> CGPoint {
        map.route.sample(at: map.route.length * fraction).point
    }

    func testDecoysPopUpOnlyWhileTheChildFollows() {
        let map = makeMap()
        var spawner = DecoyMoleSpawner(seed: 1)
        for _ in 0..<Int(60 / step) {
            spawner.advance(by: step, canSpawn: false, feet: feet(on: map), map: map)
            XCTAssertNil(spawner.decoy, "no decoy while the child is not following, or a thief is around")
        }
        var appeared = false
        for _ in 0..<Int(10 / step) where !appeared {
            spawner.advance(by: step, canSpawn: true, feet: feet(on: map), map: map)
            appeared = spawner.decoy != nil
        }
        XCTAssertTrue(appeared)
    }

    func testFirstDecoyComesAtARandomTimeWithinTheRange() {
        let settings = DecoyMoleSettings()
        var waits = Set<Int>()
        for seed: UInt64 in 1...20 {
            let spawner = DecoyMoleSpawner(seed: seed)
            XCTAssertTrue(settings.firstDelay.contains(spawner.countdown), "seed \(seed)")
            waits.insert(Int(spawner.countdown * 10))
        }
        XCTAssertGreaterThan(waits.count, 5, "the wait is random")
    }

    func testDecoysComeOneAtATimeAndAtRandomIntervals() {
        let map = makeMap()
        var spawner = DecoyMoleSpawner(seed: 3)
        var appearances: [TimeInterval] = []
        var clock: TimeInterval = 0
        var wasUp = false
        for _ in 0..<Int(90 / step) {
            spawner.advance(by: step, canSpawn: true, feet: feet(on: map), map: map)
            clock += step
            let isUp = spawner.decoy != nil
            if isUp, !wasUp { appearances.append(clock) }
            wasUp = isUp
        }
        XCTAssertGreaterThan(appearances.count, 5)
        let gaps = zip(appearances.dropFirst(), appearances).map { $0 - $1 }
        let settings = DecoyMoleSettings()
        let visit = settings.holeOpenDuration + settings.emergeDuration + settings.peekDuration
            + settings.sinkDuration + settings.holeCloseDuration
        for gap in gaps {
            XCTAssertGreaterThanOrEqual(gap, visit + settings.interval.lowerBound - 0.1, "never two at once")
            XCTAssertLessThanOrEqual(gap, visit + settings.interval.upperBound + 0.1)
        }
        XCTAssertGreaterThan(Set(gaps.map { Int($0 * 10) }).count, 2, "the gaps vary")
    }

    func testDecoyPopsUpGoesBackDownAndLeavesNothing() throws {
        var decoy = DecoyMole(hole: CGPoint(x: 400, y: 600), settings: DecoyMoleSettings())
        var phases: [DecoyMole.Phase] = [decoy.phase]
        var highest = 0.0
        for _ in 0..<Int(10 / step) where decoy.phase != .gone {
            decoy.advance(by: step)
            if phases.last != decoy.phase { phases.append(decoy.phase) }
            highest = max(highest, decoy.rise)
        }
        XCTAssertEqual(phases, [.openingHole, .emerging, .peeking, .sinking, .closingHole, .gone])
        XCTAssertEqual(highest, 1, accuracy: 1e-9)
        XCTAssertEqual(decoy.holeOpenness, 0)
    }

    func testDecoysPopUpOnOpenGrassNearTheCharacter() {
        let settings = DecoyMoleSettings()
        for seed: UInt64 in [3, 22, 40, 62] {
            let map = makeMap(seed: seed)
            let line = FoxPathGenerator.pathLine(for: map.route)
            var generator = SeededGenerator(seed: seed)
            var found = 0
            for fraction in stride(from: CGFloat(0.05), through: 0.95, by: 0.05) {
                let feet = feet(on: map, at: fraction)
                guard let spot = DecoyMoleSpawner.spot(near: feet, on: map, settings: settings, using: &generator) else { continue }
                found += 1
                let distance = hypot(spot.x - feet.x, spot.y - feet.y)
                XCTAssertTrue(settings.distance.contains(distance), "near the character, but not under its basket")
                XCTAssertGreaterThan(line.distance(to: spot), FoxPathMetrics.pathHalfWidth + 40, "off the path")
                XCTAssertTrue(CGRect(origin: .zero, size: map.size).insetBy(dx: 50, dy: 20).contains(spot), "on the map")
                let body = CGRect(x: spot.x - 50, y: spot.y - 95, width: 100, height: 110)
                XCTAssertFalse(map.standingSprites.contains { $0.frame.intersects(body) }, "clear of houses and lamps")
            }
            XCTAssertGreaterThanOrEqual(found, 9, "seed \(seed): room for decoys along much of the walk")
        }
    }

    func testANewWalkClearsTheDecoy() {
        let map = makeMap()
        var spawner = DecoyMoleSpawner(seed: 5)
        for _ in 0..<Int(15 / step) where spawner.decoy == nil {
            spawner.advance(by: step, canSpawn: true, feet: feet(on: map), map: map)
        }
        XCTAssertNotNil(spawner.decoy)
        spawner.reset()
        XCTAssertNil(spawner.decoy)
        XCTAssertTrue(DecoyMoleSettings().firstDelay.contains(spawner.countdown))
    }

    func testSameSeedReplaysTheSameDecoys() {
        let map = makeMap()
        var first = DecoyMoleSpawner(seed: 9)
        var second = DecoyMoleSpawner(seed: 9)
        for _ in 0..<Int(30 / step) {
            first.advance(by: step, canSpawn: true, feet: feet(on: map), map: map)
            second.advance(by: step, canSpawn: true, feet: feet(on: map), map: map)
            XCTAssertEqual(first.decoy, second.decoy)
        }
    }
}
