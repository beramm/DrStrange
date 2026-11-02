import XCTest
@testable import DrStrange

final class WhackAMoleEngineTests: XCTestCase {
    private func makeConfiguration(seed: UInt64 = 11, adaptive: Bool = false) -> GameConfiguration {
        var configuration = GameConfiguration()
        configuration.randomSeed = seed
        configuration.sessionDuration = 60
        configuration.adaptiveDifficulty.isEnabled = adaptive
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

    func testCharacterCannotBeHitTwice() throws {
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        XCTAssertFalse(engine.tapHole(target.holeIndex).isEmpty)
        XCTAssertTrue(engine.tapHole(target.holeIndex).isEmpty)
        XCTAssertEqual(engine.session.hits, 1)
        XCTAssertEqual(engine.session.offTargetTaps, 1)
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
        var configuration = makeConfiguration()
        configuration.startingLevel = .intermediate
        var engine = WhackAMoleEngine(configuration: configuration)
        for _ in 0..<1000 {
            engine.advance(by: 0.05)
            XCTAssertLessThanOrEqual(engine.targets.filter { $0.phase.isUp }.count, 2)
            XCTAssertEqual(Set(engine.targets.map(\.holeIndex)).count, engine.targets.count, "two characters in one hole")
        }
    }

    func testSessionFinishesAtDurationAndIgnoresInput() {
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        var finished = false
        for _ in 0..<1300 where !finished {
            finished = engine.advance(by: 0.05).contains(.finished)
        }
        XCTAssertTrue(finished)
        XCTAssertTrue(engine.session.completed)
        XCTAssertNotNil(engine.session.endedAt)
        XCTAssertEqual(engine.session.activePlayDuration, 60, accuracy: 0.06)
        XCTAssertTrue(engine.advance(by: 1).isEmpty)
        XCTAssertTrue(engine.tapHole(4).isEmpty)
    }

    func testEarlyExitIsNotCompleted() {
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        engine.advance(by: 5)
        engine.end()
        XCTAssertTrue(engine.isFinished)
        XCTAssertFalse(engine.session.completed)
    }

    func testPerfectPlayPromotesLevel() {
        var engine = WhackAMoleEngine(configuration: makeConfiguration(adaptive: true))
        var changes: [EngineEvent] = []
        for _ in 0..<1200 where !engine.isFinished {
            engine.advance(by: 0.05)
            for target in engine.targets where target.phase.isUp {
                changes += engine.tapHole(target.holeIndex).filter {
                    if case .levelChanged = $0 { true } else { false }
                }
            }
        }
        XCTAssertEqual(changes.first, .levelChanged(from: .beginner, to: .intermediate))
        XCTAssertGreaterThan(engine.session.finalLevel, .beginner)
    }

    func testNoPlayDemotesButNotBelowBeginner() throws {
        var configuration = makeConfiguration(adaptive: true)
        configuration.startingLevel = .intermediate
        configuration.sessionDuration = 120
        var engine = WhackAMoleEngine(configuration: configuration)
        while !engine.isFinished { engine.advance(by: 0.05) }
        let change = try XCTUnwrap(engine.session.levelChanges.first)
        XCTAssertEqual(change.from, .intermediate)
        XCTAssertEqual(change.to, .beginner)
        XCTAssertEqual(engine.session.finalLevel, .beginner)
    }

    func testSessionRecordRoundTripsThroughJSON() throws {
        var engine = WhackAMoleEngine(configuration: makeConfiguration())
        while !engine.isFinished { engine.advance(by: 0.1) }
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = SessionStore(directory: directory)
        try store.save(engine.session)
        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.trials, engine.session.trials)
        XCTAssertEqual(loaded.first?.configuration.randomSeed, 11)
        try? FileManager.default.removeItem(at: directory)
    }
}

final class DifficultyProgressionTests: XCTestCase {
    func testWaitsForFullWindow() {
        var progression = DifficultyProgression(rules: AdaptiveDifficultyRules(), startingLevel: .beginner)
        for _ in 0..<9 { XCTAssertNil(progression.record(hit: true)) }
        XCTAssertEqual(progression.record(hit: true), .intermediate)
    }

    func testMiddleAccuracyKeepsLevel() {
        var progression = DifficultyProgression(rules: AdaptiveDifficultyRules(), startingLevel: .intermediate)
        for index in 0..<40 {
            XCTAssertNil(progression.record(hit: index % 3 != 0)) // ~67 %
        }
        XCTAssertEqual(progression.level, .intermediate)
    }

    func testDisabledNeverChanges() {
        var rules = AdaptiveDifficultyRules()
        rules.isEnabled = false
        var progression = DifficultyProgression(rules: rules, startingLevel: .beginner)
        for _ in 0..<50 { XCTAssertNil(progression.record(hit: true)) }
    }

    func testStaysWithinBounds() {
        var progression = DifficultyProgression(rules: AdaptiveDifficultyRules(), startingLevel: .advanced)
        for _ in 0..<30 { _ = progression.record(hit: true) }
        XCTAssertEqual(progression.level, .advanced)
    }
}

final class AnaglyphRendererTests: XCTestCase {
    func testInkRoutesToCorrectEye() {
        let renderer = AnaglyphRenderer(glasses: AnaglyphGlasses(redFilterEye: .left), backgroundLevel: 1)
        // Element for the left (red-filter) eye must be cyan: no red component.
        let leftInk = UIColor(renderer.ink(for: .only(.left), standardColor: .black, contrast: 1))
        let rightInk = UIColor(renderer.ink(for: .only(.right), standardColor: .black, contrast: 1))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        leftInk.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0, accuracy: 0.01)
        XCTAssertEqual(g, 1, accuracy: 0.01)
        rightInk.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1, accuracy: 0.01)
        XCTAssertEqual(g, 0, accuracy: 0.01)
    }

    func testLowerContrastIsLighterInk() {
        let renderer = AnaglyphRenderer(glasses: AnaglyphGlasses(), backgroundLevel: 1)
        let ink = UIColor(renderer.ink(for: .only(.right), standardColor: .black, contrast: 0.3))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ink.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(g, 0.7, accuracy: 0.01)
    }

    func testContrastPerEyeUsesClinicalSettingsOnlyWhenEyeSet() {
        var therapy = TherapyConfiguration()
        therapy.fellowEyeContrast = 0.4
        XCTAssertEqual(therapy.contrast(for: .left), 1)
        therapy.amblyopicEye = .left
        XCTAssertEqual(therapy.contrast(for: .left), 1)
        XCTAssertEqual(therapy.contrast(for: .right), 0.4)
    }
}
