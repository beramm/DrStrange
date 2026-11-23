import XCTest
@testable import DrStrange

final class WhackAMoleEngineTests: XCTestCase {
    private func makeConfiguration(seed: UInt64 = 11) -> GameConfiguration {
        var configuration = GameConfiguration()
        configuration.randomSeed = seed
        return configuration
    }

    /// Advances until the next spawn and returns it.
    private func advanceToSpawn(_ engine: inout WhackAMoleEngine, step: TimeInterval = 0.05) -> ActiveTarget? {
        for _ in 0..<2000 {
            for event in engine.advance(by: step) {
                if case let .spawned(target) = event { return target }
            }
            if engine.isFinished { return nil }
        }
        return nil
    }

    func testFirstSpawnWaitsForLeadIn() {
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        engine.advance(by: 0.5)
        XCTAssertTrue(engine.targets.isEmpty)
        let target = advanceToSpawn(&engine)
        XCTAssertNotNil(target)
        XCTAssertGreaterThanOrEqual(target!.spawnedAt, 1.0)
    }

    func testHitRecordsResponseTime() throws {
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        engine.advance(by: 0.8)
        let events = engine.tapHole(target.holeIndex)
        guard case let .hit(_, responseTime)? = events.first else { return XCTFail("expected hit, got \(events)") }
        XCTAssertEqual(responseTime, 0.8, accuracy: 1e-6)
        XCTAssertEqual(engine.session.hits, 1)
        XCTAssertEqual(engine.session.averageResponseTime ?? 0, 0.8, accuracy: 1e-6)
    }

    func testProximityPointsAreRecordedInSessionScore() throws {
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        let target = try XCTUnwrap(advanceToSpawn(&engine))

        _ = engine.tapHole(target.holeIndex, awardedPoints: 30)

        XCTAssertEqual(engine.session.score, 30)
        XCTAssertEqual(engine.session.trials.last?.pointsAwarded, 30)
        XCTAssertEqual(engine.targets.first(where: { $0.id == target.id })?.pointsAwarded, 30)
    }

    func testCharacterCannotBeHitTwice() throws {
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        XCTAssertFalse(engine.tapHole(target.holeIndex).isEmpty)
        // The fox is attacking: a second tap is ignored, neither a hit nor an off-target tap.
        XCTAssertTrue(engine.tapHole(target.holeIndex).isEmpty)
        XCTAssertEqual(engine.session.hits, 1)
        XCTAssertEqual(engine.session.offTargetTaps, 0)
    }

    func testExpiredTargetIsMissedWithoutPenalty() throws {
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        _ = try XCTUnwrap(advanceToSpawn(&engine))
        for _ in 0..<200 where engine.session.misses == 0 {
            engine.advance(by: 0.05)
        }
        XCTAssertEqual(engine.session.misses, 1)
        XCTAssertEqual(engine.session.hits, 0)
        XCTAssertEqual(engine.session.accuracy, 0)
    }

    func testEmptyHoleTapIsCountedOnly() {
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        XCTAssertTrue(engine.tapHole(4).isEmpty)
        XCTAssertEqual(engine.session.offTargetTaps, 1)
        XCTAssertEqual(engine.session.targetsSpawned, 0)
    }

    func testRespectsMaxSimultaneousTargets() {
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        for _ in 0..<1000 {
            engine.advance(by: 0.05)
            XCTAssertLessThanOrEqual(engine.targets.filter { $0.phase.isUp }.count, 2)
            XCTAssertEqual(Set(engine.targets.map(\.holeIndex)).count, engine.targets.count, "two characters in one hole")
        }
    }

    func testSessionAlwaysLastsTwoMinutesAndThenIgnoresInput() {
        XCTAssertEqual(GameConfiguration.sessionDuration, 120)
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        XCTAssertEqual(engine.remainingTime, 120)
        var finished = false
        for _ in 0..<2500 where !finished {
            finished = engine.advance(by: 0.05).contains(.finished)
        }
        XCTAssertTrue(finished)
        XCTAssertTrue(engine.session.completed)
        XCTAssertEqual(engine.session.endReason, .timeUp)
        XCTAssertNotNil(engine.session.endedAt)
        XCTAssertEqual(engine.session.activePlayDuration, 120, accuracy: 0.06)
        XCTAssertTrue(engine.advance(by: 1).isEmpty)
        XCTAssertTrue(engine.tapHole(4).isEmpty)
    }

    func testEarlyExitIsNotCompleted() {
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        engine.advance(by: 5)
        engine.end()
        XCTAssertTrue(engine.isFinished)
        XCTAssertFalse(engine.session.completed)
        XCTAssertEqual(engine.session.endReason, .stopped)
    }

    func testRestBreakIsRecorded() {
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        engine.advance(by: 5)
        engine.end(reason: .restBreak)
        XCTAssertEqual(engine.session.endReason, .restBreak)
        XCTAssertFalse(engine.session.completed)
        XCTAssertTrue(engine.tapHole(4).isEmpty)
    }

    func testScoreAddsTheAwardedPointsOfEveryHit() throws {
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        var expected = 0
        // Proximity tiers from gaze (60, 30, 20), then a hit with the default points.
        for points in [60, 30, 20, nil] as [Int?] {
            let target = try XCTUnwrap(advanceToSpawn(&engine))
            engine.advance(by: 0.8)
            if let points {
                engine.tapHole(target.holeIndex, awardedPoints: points)
            } else {
                engine.tapHole(target.holeIndex)
            }
            expected += points ?? GameSessionRecord.defaultPointsPerHit
            XCTAssertEqual(engine.session.score, expected)
            engine.advance(by: FoxAttackTiming().total + 0.05)
        }
        XCTAssertEqual(engine.session.score, 120)
    }

    func testMissesScoreNothing() throws {
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        while !engine.isFinished { engine.advance(by: 0.05) }
        XCTAssertGreaterThan(engine.session.misses, 0)
        XCTAssertEqual(engine.session.score, 0)
    }

    func testHighScoreKeepsOnlyTheBest() throws {
        let suite = "WhackAMoleHighScoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HighScoreStore(defaults: defaults)
        XCTAssertEqual(store.best, 0)
        XCTAssertFalse(store.submit(0), "a score of 0 is never a high score")
        XCTAssertTrue(store.submit(120))
        XCTAssertFalse(store.submit(90))
        XCTAssertFalse(store.submit(120), "a tie is not a new high score")
        XCTAssertEqual(store.best, 120)
        XCTAssertTrue(store.submit(150))
        XCTAssertEqual(store.best, 150)
    }

    func testSavedSettingsAlwaysUseTheCurrentBoard() throws {
        let suite = "WhackAMoleConfigurationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ConfigurationStore(defaults: defaults)
        var configuration = GameConfiguration()
        configuration.board.activeHoleIndices = [4]
        configuration.soundEnabled = false
        store.save(configuration)
        let loaded = store.load()
        XCTAssertEqual(loaded.board, .standard)
        XCTAssertFalse(loaded.soundEnabled)
    }

    func testSessionRecordRoundTripsThroughJSON() throws {
        var configuration = makeConfiguration()
        configuration.patching = PatchingConfiguration(patchedEye: .right, playingEye: .left)
        var engine = WhackAMoleEngine(configuration: configuration)
        while !engine.isFinished { engine.advance(by: 0.1) }
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = SessionStore(directory: directory)
        try store.save(engine.session)
        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.trials, engine.session.trials)
        XCTAssertEqual(loaded.first?.configuration.randomSeed, 11)
        XCTAssertEqual(loaded.first?.configuration.patching.patchedEye, .right)
        XCTAssertEqual(loaded.first?.endReason, .timeUp)
        try? FileManager.default.removeItem(at: directory)
    }
}
