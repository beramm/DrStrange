import XCTest
@testable import DrStrange

final class FoxAttackTests: XCTestCase {
    private let timing = FoxAttackTiming()

    private func makeEngine(level: DifficultyLevel = .beginner) -> WhackAMoleEngine {
        var configuration = GameConfiguration()
        configuration.randomSeed = 21
        configuration.sessionDuration = 60
        configuration.startingLevel = level
        configuration.adaptiveDifficulty.isEnabled = false
        return WhackAMoleEngine(configuration: configuration)
    }

    private func advanceToSpawn(_ engine: inout WhackAMoleEngine) -> ActiveTarget? {
        for _ in 0..<2000 {
            for event in engine.advance(by: 0.02) {
                if case let .spawned(target) = event { return target }
            }
        }
        return nil
    }

    /// Advances in small steps and collects every event.
    private func run(_ engine: inout WhackAMoleEngine, for duration: TimeInterval) -> [EngineEvent] {
        var events: [EngineEvent] = []
        var elapsed: TimeInterval = 0
        while elapsed < duration - 1e-9 {
            events += engine.advance(by: 0.01)
            elapsed += 0.01
        }
        return events
    }

    func testFoxStaysHomeUntilAValidTap() throws {
        var engine = makeEngine()
        XCTAssertNil(engine.attack)
        XCTAssertEqual(engine.interactionState, .idle)
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        XCTAssertEqual(engine.interactionState, .targetAppearing)
        _ = run(&engine, for: 0.5)
        XCTAssertEqual(engine.interactionState, .targetActive)
        XCTAssertNil(engine.attack)

        let events = engine.tapHole(target.holeIndex)
        XCTAssertTrue(events.contains(.attackStarted(engine.targets[0])))
        XCTAssertEqual(engine.attack?.targetID, target.id, "The fox attacks the tapped character")
        XCTAssertEqual(engine.attack?.holeIndex, target.holeIndex)
        XCTAssertEqual(engine.interactionState, .foxEmerging)
    }

    func testEmptyHoleTapDoesNotStartAttack() throws {
        var engine = makeEngine()
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        let emptyHole = try XCTUnwrap(engine.settings.activeHoleIndices.first { $0 != target.holeIndex })
        XCTAssertTrue(engine.tapHole(emptyHole).isEmpty)
        XCTAssertNil(engine.attack)
        XCTAssertEqual(engine.session.offTargetTaps, 1)
    }

    func testSequenceRunsInOrderAndTargetWaitsForImpact() throws {
        var engine = makeEngine()
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        engine.tapHole(target.holeIndex)
        XCTAssertEqual(engine.targets.first?.phase, .targeted)

        // Before the hammer lands the character is still there and not yet reacting.
        _ = run(&engine, for: timing.impactOffset - 0.02)
        XCTAssertEqual(engine.interactionState, .foxAttacking)
        XCTAssertEqual(engine.targets.first?.phase, .targeted)

        let impactEvents = run(&engine, for: 0.03)
        XCTAssertTrue(impactEvents.contains { if case .attackImpact = $0 { true } else { false } })
        XCTAssertEqual(engine.interactionState, .targetHit)
        guard case .hit? = engine.targets.first?.phase else { return XCTFail("character should react on impact") }

        _ = run(&engine, for: timing.hitReaction)
        XCTAssertTrue(engine.targets.isEmpty, "character is gone once its reaction ends")
        XCTAssertEqual(engine.interactionState, .foxReturning)

        let endEvents = run(&engine, for: timing.returnHome)
        XCTAssertTrue(endEvents.contains(.attackFinished))
        XCTAssertNil(engine.attack)
        XCTAssertEqual(engine.interactionState, .nextTarget)
    }

    func testRapidTapsStartOnlyOneAttack() throws {
        var engine = makeEngine()
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        var started = 0
        for _ in 0..<10 {
            started += engine.tapHole(target.holeIndex).filter { if case .attackStarted = $0 { true } else { false } }.count
            engine.advance(by: 0.01)
        }
        XCTAssertEqual(started, 1)
        XCTAssertEqual(engine.session.hits, 1)
    }

    func testNoSpawnDuringAttackAndSpawningResumesAfter() throws {
        var engine = makeEngine()
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        engine.tapHole(target.holeIndex)
        // Force the next spawn to be due immediately: spawning must still wait for the fox.
        let duringAttack = run(&engine, for: timing.total)
        XCTAssertFalse(duringAttack.contains { if case .spawned = $0 { true } else { false } })

        let after = run(&engine, for: 5)
        XCTAssertTrue(after.contains { if case .spawned = $0 { true } else { false } }, "random spawning continues")
    }

    func testOtherCharacterDoesNotExpireWhileFoxAttacks() throws {
        var engine = makeEngine(level: .intermediate)
        // Wait until two awake characters are up at once.
        var pair: [ActiveTarget] = []
        for _ in 0..<5000 where pair.count < 2 {
            engine.advance(by: 0.02)
            pair = engine.targets.filter { $0.phase.isUp && $0.role == .target }
        }
        XCTAssertEqual(pair.count, 2)
        let other = pair[1]
        let remaining = other.expiresAt - engine.clock
        engine.tapHole(pair[0].holeIndex)
        _ = run(&engine, for: timing.total)
        let otherNow = try XCTUnwrap(engine.targets.first { $0.id == other.id })
        XCTAssertTrue(otherNow.phase.isUp)
        XCTAssertEqual(otherNow.expiresAt - engine.clock, remaining, accuracy: 0.02)
    }

    func testDecoyTapDoesNotTriggerFox() throws {
        var engine = makeEngine(level: .advanced)
        var decoy: ActiveTarget?
        for _ in 0..<20000 where decoy == nil {
            engine.advance(by: 0.02)
            decoy = engine.targets.first { $0.phase.isUp && $0.role == .decoy }
        }
        let sleepy = try XCTUnwrap(decoy)
        XCTAssertEqual(engine.tapHole(sleepy.holeIndex), [.decoyTapped(engine.targets.first { $0.id == sleepy.id }!)])
        XCTAssertNil(engine.attack)
    }

    func testStoppingDuringAttackClearsIt() throws {
        var engine = makeEngine()
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        engine.tapHole(target.holeIndex)
        engine.advance(by: 0.1)
        engine.end(reason: .restBreak)
        XCTAssertNil(engine.attack)
        XCTAssertTrue(engine.targets.isEmpty)
        XCTAssertEqual(engine.session.hits, 1, "the tap counts even if the hammer had not landed")
    }

    func testFoxPoseFramesFollowTheSwing() {
        XCTAssertEqual(FoxCharacterView.frame(for: nil), 1)
        XCTAssertEqual(FoxCharacterView.frame(for: FoxPose(phase: .emerging, progress: 0.5, holeIndex: 0)), 1)
        XCTAssertEqual(FoxCharacterView.frame(for: FoxPose(phase: .attacking, progress: 1, holeIndex: 0)), FoxCharacterView.frameCount)
        XCTAssertEqual(FoxCharacterView.frame(for: FoxPose(phase: .hitting, progress: 0.3, holeIndex: 0)), FoxCharacterView.frameCount)
        XCTAssertEqual(FoxCharacterView.frame(for: FoxPose(phase: .returning, progress: 1, holeIndex: 0)), 1)
    }

    func testHammerLandsOnTheTappedCharacter() {
        let window = CGRect(x: 16, y: 690, width: 130, height: 130)
        let hole = CGRect(x: 500, y: 300, width: 240, height: 240)
        for holeIndex in [3, 5] {
            let pose = FoxPose(phase: .hitting, progress: 0, holeIndex: holeIndex)
            let placement = AttackAnimationView.placement(for: pose, window: window, hole: hole, targetScale: 1, reduceMotion: false)
            let impactX = placement.mirrored ? 1 - FoxCharacterView.impactPoint.x : FoxCharacterView.impactPoint.x
            let hammer = CGPoint(
                x: placement.center.x + (impactX - 0.5) * placement.size,
                y: placement.center.y + (FoxCharacterView.impactPoint.y - 0.5) * placement.size
            )
            let character = MoleHoleView.characterRect(in: hole.size, targetScale: 1).offsetBy(dx: hole.minX, dy: hole.minY)
            XCTAssertTrue(character.contains(hammer), "hammer \(hammer) should be on \(character)")
            XCTAssertEqual(placement.mirrored, holeIndex == 5, "fox stands left of right-column characters")
        }
    }

    func testFoxStaysHomeWhenIdleOrReduceMotion() {
        let window = CGRect(x: 16, y: 690, width: 130, height: 130)
        let hole = CGRect(x: 500, y: 300, width: 240, height: 240)
        let home = AttackAnimationView.placement(for: nil, window: window, hole: nil, targetScale: 1, reduceMotion: false)
        let reduced = AttackAnimationView.placement(
            for: FoxPose(phase: .attacking, progress: 0.8, holeIndex: 4), window: window, hole: hole, targetScale: 1, reduceMotion: true
        )
        XCTAssertEqual(home, reduced)
        let returned = AttackAnimationView.placement(
            for: FoxPose(phase: .returning, progress: 1, holeIndex: 4), window: window, hole: hole, targetScale: 1, reduceMotion: false
        )
        XCTAssertEqual(returned.center.x, home.center.x, accuracy: 0.001)
        XCTAssertEqual(returned.center.y, home.center.y, accuracy: 0.001)
    }

    func testOldSavedSettingsStillLoad() throws {
        let old = #"{"startingLevel":2,"sessionDuration":300,"patching":{"patchedEye":"left"},"soundEnabled":false}"#
        let configuration = try JSONDecoder().decode(GameConfiguration.self, from: Data(old.utf8))
        XCTAssertEqual(configuration.startingLevel, .intermediate)
        XCTAssertEqual(configuration.sessionDuration, 300)
        XCTAssertEqual(configuration.patching.patchedEye, .left)
        XCTAssertFalse(configuration.soundEnabled)
        XCTAssertEqual(configuration.foxAttack, FoxAttackTiming())
    }
}
