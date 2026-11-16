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
        _ = run(&engine, for: 0.7)
        XCTAssertEqual(engine.interactionState, .targetActive)
        XCTAssertNil(engine.attack)

        let events = engine.tapHole(target.holeIndex)
        XCTAssertTrue(events.contains(.attackStarted(engine.targets[0])))
        XCTAssertEqual(engine.attack?.targetID, target.id, "The fox attacks the tapped character")
        XCTAssertEqual(engine.attack?.holeIndex, target.holeIndex)
        XCTAssertEqual(engine.interactionState, .frameAppearing, "the frame comes first")
    }

    func testEmptyHoleTapDoesNotStartAttack() throws {
        var engine = makeEngine()
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        let emptyHole = try XCTUnwrap(engine.settings.activeHoleIndices.first { $0 != target.holeIndex })
        XCTAssertTrue(engine.tapHole(emptyHole).isEmpty)
        XCTAssertNil(engine.attack)
        XCTAssertEqual(engine.session.offTargetTaps, 1)
    }

    func testSequenceRunsInExactOrder() throws {
        var engine = makeEngine()
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        engine.tapHole(target.holeIndex)
        var seen: [GameInteractionState] = []
        for _ in 0..<Int((timing.total + 0.2) / 0.01) {
            engine.advance(by: 0.01)
            let state = engine.interactionState
            if seen.last != state { seen.append(state) }
        }
        XCTAssertEqual(Array(seen.prefix(7)), [
            .frameAppearing, .foxEmerging, .foxAttacking, .targetHit, .foxRetracting, .frameDisappearing, .nextTarget,
        ])
    }

    func testTargetWaitsForImpact() throws {
        var engine = makeEngine()
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        engine.tapHole(target.holeIndex)
        XCTAssertEqual(engine.targets.first?.phase, .targeted)

        // Until the hammer lands the character is still there and not yet reacting.
        _ = run(&engine, for: timing.impactOffset - 0.02)
        XCTAssertEqual(engine.interactionState, .foxAttacking)
        XCTAssertEqual(engine.targets.first?.phase, .targeted)

        let impactEvents = run(&engine, for: 0.03)
        XCTAssertTrue(impactEvents.contains { if case .attackImpact = $0 { true } else { false } })
        XCTAssertEqual(engine.interactionState, .targetHit)
        guard case .hit? = engine.targets.first?.phase else { return XCTFail("character should react on impact") }

        _ = run(&engine, for: timing.hitReaction)
        XCTAssertEqual(engine.interactionState, .foxRetracting)
        XCTAssertFalse(engine.targets.isEmpty, "the mole goes back down after reacting")
        _ = run(&engine, for: engine.configuration.spawnRules.exitAnimationDuration + 0.02)
        XCTAssertTrue(engine.targets.isEmpty, "gone once it is back down")

        let endEvents = run(&engine, for: timing.retract + timing.frameDisappear - engine.configuration.spawnRules.exitAnimationDuration)
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
        func frame(_ phase: FoxAttackPhase, _ progress: Double) -> Int {
            FoxCharacterView.frame(for: FoxPose(phase: phase, progress: progress, holeIndex: 0))
        }
        XCTAssertEqual(FoxCharacterView.frame(for: nil), 1)
        XCTAssertEqual(frame(.frameAppearing, 0.5), 1)
        XCTAssertEqual(frame(.foxEmerging, 0.5), 1)
        XCTAssertEqual(frame(.attacking, 1), FoxCharacterView.frameCount)
        XCTAssertEqual(frame(.hitting, 0.3), FoxCharacterView.frameCount)
        XCTAssertEqual(frame(.foxRetracting, 0.5), 1, "hammer raised again once back on the card")
        XCTAssertEqual(frame(.foxRetracting, 1), 1)
        XCTAssertEqual(frame(.frameDisappearing, 0.5), 1)
    }

    private let home = CGRect(x: 16, y: 690, width: 130, height: 130)
    private let hole = CGRect(x: 500, y: 300, width: 240, height: 240)

    private func scene(_ phase: FoxAttackPhase, _ progress: Double, hole holeIndex: Int = 4, reduceMotion: Bool = false) -> AttackAnimationView.Scene {
        AttackAnimationView.scene(
            for: FoxPose(phase: phase, progress: progress, holeIndex: holeIndex),
            home: home, hole: hole, reduceMotion: reduceMotion
        )
    }

    func testIdleFoxIsInTheCornerWithNoFrame() {
        let idle = AttackAnimationView.scene(for: nil, home: home, hole: nil, reduceMotion: false)
        XCTAssertNil(idle.card)
        XCTAssertNil(idle.cornerFox)
        XCTAssertEqual(idle.fox, AttackAnimationView.homePlacement(in: home))
    }

    func testCardOpensBeforeFoxAppears() {
        let start = scene(.frameAppearing, 0)
        let end = scene(.frameAppearing, 1)
        XCTAssertEqual(start.card?.reveal ?? -1, 0, accuracy: 0.001, "circle reveal starts closed")
        XCTAssertEqual(end.card?.reveal ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(end.card?.scale ?? 0, 1, accuracy: 0.001)
        XCTAssertNotNil(start.card?.ring, "ripple ring plays while opening")
        XCTAssertEqual(start.fox.opacity, 0, "no fox in the card yet")
        XCTAssertEqual(end.fox.opacity, 0)
        XCTAssertEqual(start.cornerFox?.opacity, 1, "corner fox is still there as the card starts")
        XCTAssertEqual(end.cornerFox?.opacity ?? 1, 0, accuracy: 0.001)
    }

    func testFoxRisesFromTheBottomOfTheCard() {
        let geometry = AttackAnimationView.attackGeometry(holeIndex: 4, hole: hole, home: home)
        let start = scene(.foxEmerging, 0)
        XCTAssertEqual(start.fox.opacity, 0, accuracy: 0.001, "hammer not shown while rising")
        let rising = try! XCTUnwrap(start.risingFox)
        XCTAssertEqual(rising.center.y - geometry.emerged.center.y, geometry.card.height, accuracy: 0.5, "starts one card below")
        let middle = try! XCTUnwrap(scene(.foxEmerging, 0.4).risingFox)
        XCTAssertGreaterThan(middle.center.y, geometry.emerged.center.y)
        XCTAssertLessThan(middle.center.y, rising.center.y, "moves up")
        let up = scene(.foxEmerging, 1)
        XCTAssertEqual(up.risingFox?.center.y ?? 0, geometry.emerged.center.y, accuracy: 0.5)
        XCTAssertEqual(up.fox.opacity, 0, accuracy: 0.001, "hammer stays hidden until the swing")

        // The swing starts with the fox's own card on the drawn card and the hammer still hidden.
        let swingStart = scene(.attacking, 0)
        XCTAssertEqual(swingStart.fox.opacity, 1, accuracy: 0.001)
        XCTAssertEqual(swingStart.fox.hammerReveal, 0, accuracy: 0.001)
        XCTAssertGreaterThan(scene(.attacking, 0.2).fox.hammerReveal, 0)
        XCTAssertEqual(scene(.attacking, 0.5).fox.hammerReveal, 1, accuracy: 0.001, "fully out before impact")

        // The fox's own card sits exactly on the drawn card.
        let fox = swingStart.fox
        let unit = FoxCharacterView.cardRect
        let foxCard = CGRect(
            x: fox.center.x - fox.size / 2 + unit.minX * fox.size,
            y: fox.center.y - fox.size / 2 + unit.minY * fox.size,
            width: unit.width * fox.size,
            height: unit.height * fox.size
        )
        XCTAssertEqual(foxCard.minX, geometry.card.minX, accuracy: 0.5)
        XCTAssertEqual(foxCard.minY, geometry.card.minY, accuracy: 0.5)
        XCTAssertEqual(foxCard.width, geometry.card.width, accuracy: 0.5)
    }

    func testHammerLandsOnTheTappedCharacter() {
        for holeIndex in [3, 5] {
            let fox = scene(.hitting, 0, hole: holeIndex).fox
            let impactX = fox.mirrored ? 1 - FoxCharacterView.impactPoint.x : FoxCharacterView.impactPoint.x
            let hammer = CGPoint(
                x: fox.center.x + (impactX - 0.5) * fox.size,
                y: fox.center.y + (FoxCharacterView.impactPoint.y - 0.5) * fox.size
            )
            let character = MoleHoleView.characterRect(artIndex: 0, in: hole.size).offsetBy(dx: hole.minX, dy: hole.minY)
            XCTAssertTrue(character.contains(hammer), "hammer \(hammer) should be on \(character)")
            XCTAssertEqual(fox.mirrored, holeIndex == 5, "fox stands left of right-column characters")
            // The attack moves the fox towards the character.
            let before = scene(.attacking, 0, hole: holeIndex).fox
            XCTAssertLessThan(abs(fox.center.x - character.midX), abs(before.center.x - character.midX))
        }
    }

    func testFoxSinksIntoCardThenCardClosesAndFoxIsHome() {
        let geometry = AttackAnimationView.attackGeometry(holeIndex: 4, hole: hole, home: home)
        let halfway = scene(.foxRetracting, 0.49)
        XCTAssertEqual(halfway.fox.center.x, geometry.emerged.center.x, accuracy: 1, "back on the card first")
        XCTAssertLessThan(halfway.fox.hammerReveal, 0.1, "hammer has slid back behind the card")
        let retracted = scene(.foxRetracting, 1)
        XCTAssertEqual(retracted.fox.opacity, 0, accuracy: 0.001)
        XCTAssertEqual((retracted.risingFox?.center.y ?? 0) - geometry.emerged.center.y, geometry.card.height, accuracy: 0.5,
                       "sinks out of the card's bottom")
        XCTAssertEqual(retracted.card?.reveal, 1, "card stays open until the fox is gone")

        let closed = scene(.frameDisappearing, 1)
        XCTAssertEqual(closed.card?.reveal ?? 1, 0, accuracy: 0.001)
        XCTAssertEqual(closed.fox.opacity, 0)
        XCTAssertEqual(closed.cornerFox?.center, AttackAnimationView.homePlacement(in: home).center)
        XCTAssertEqual(closed.cornerFox?.opacity ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(closed.cornerFox?.size ?? 0, AttackAnimationView.homePlacement(in: home).size, accuracy: 0.001)
    }

    func testReduceMotionKeepsFoxInCorner() {
        let reduced = scene(.attacking, 0.8, reduceMotion: true)
        XCTAssertEqual(reduced.fox, AttackAnimationView.homePlacement(in: home))
        XCTAssertNil(reduced.card)
    }

    func testOldSavedSettingsStillLoad() throws {
        let old = #"{"startingLevel":2,"sessionDuration":300,"patching":{"patchedEye":"left"},"soundEnabled":false}"#
        let configuration = try JSONDecoder().decode(GameConfiguration.self, from: Data(old.utf8))
        XCTAssertEqual(configuration.startingLevel, .intermediate)
        XCTAssertEqual(configuration.sessionDuration, 300)
        XCTAssertEqual(configuration.patching.patchedEye, .left)
        XCTAssertFalse(configuration.soundEnabled)
        XCTAssertEqual(configuration.foxAttack, FoxAttackTiming())
        XCTAssertTrue(configuration.oneEyeEnforcerEnabled)
    }

    func testSettingsWithOlderFoxTimingStillLoad() throws {
        let old = #"{"startingLevel":3,"foxAttack":{"emerge":0.28,"swing":0.42,"hitReaction":0.38,"returnHome":0.34,"nextTargetDelay":0.4},"patching":{"playingEye":"right"}}"#
        let configuration = try JSONDecoder().decode(GameConfiguration.self, from: Data(old.utf8))
        XCTAssertEqual(configuration.startingLevel, .advanced)
        XCTAssertEqual(configuration.patching.playingEye, .right, "other settings are kept")
        XCTAssertEqual(configuration.foxAttack, FoxAttackTiming())
    }

    // MARK: - Mole animation

    func testMoleClimbsOutFrameByFrame() throws {
        var engine = makeEngine()
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        var last = engine.moleVisual(for: engine.targets[0]).frame
        XCTAssertLessThanOrEqual(last, 2, "starts with just the helmet tip")
        for _ in 0..<60 {
            engine.advance(by: 0.01)
            let frame = engine.moleVisual(for: engine.targets.first { $0.id == target.id }!).frame
            XCTAssertGreaterThanOrEqual(frame, last)
            last = frame
        }
        XCTAssertEqual(last, MoleVisual.frameCount)
    }

    func testPunchedMoleReactsThenPlaysFramesBackwards() throws {
        var engine = makeEngine()
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        _ = run(&engine, for: 0.7)
        engine.tapHole(target.holeIndex)
        func visual() -> MoleVisual? { engine.targets.first { $0.id == target.id }.map { engine.moleVisual(for: $0) } }

        // Waiting for the hammer: fully up, no reaction yet.
        _ = run(&engine, for: timing.impactOffset - 0.05)
        XCTAssertEqual(visual()?.frame, MoleVisual.frameCount)
        XCTAssertNil(visual()?.hitProgress)

        // Reacting: still fully up, with reaction progress.
        _ = run(&engine, for: 0.05 + timing.hitReaction / 2)
        XCTAssertEqual(visual()?.frame, MoleVisual.frameCount)
        XCTAssertEqual(visual()?.hitProgress ?? 0, 0.5, accuracy: 0.1)

        // Then the rise plays backwards until it is gone.
        _ = run(&engine, for: timing.hitReaction / 2 + 0.02)
        var last = visual()?.frame ?? 0
        XCTAssertNil(visual()?.hitProgress)
        var frames = 0
        while let frame = visual()?.frame {
            XCTAssertLessThanOrEqual(frame, last)
            last = frame
            frames += 1
            engine.advance(by: 0.01)
        }
        XCTAssertLessThanOrEqual(last, 2, "back down to the helmet tip before disappearing")
        XCTAssertGreaterThan(frames, 10)
    }

    func testUntappedMoleAlsoGoesBackDown() throws {
        var engine = makeEngine()
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        while engine.targets.first(where: { $0.id == target.id })?.phase.isUp == true { engine.advance(by: 0.01) }
        let start = try XCTUnwrap(engine.targets.first { $0.id == target.id })
        XCTAssertEqual(engine.moleVisual(for: start).frame, MoleVisual.frameCount)
        engine.advance(by: engine.configuration.spawnRules.exitAnimationDuration * 0.9)
        let later = try XCTUnwrap(engine.targets.first { $0.id == target.id })
        XCTAssertLessThan(engine.moleVisual(for: later).frame, 6)
    }

    // MARK: - Random holes

    func testBoardStartsWithNoHoles() {
        var engine = makeEngine()
        XCTAssertTrue(engine.holeVisuals.isEmpty)
        engine.advance(by: 0.5)
        XCTAssertTrue(engine.holeVisuals.isEmpty, "nothing shows where the first mole will be")
    }

    func testHoleOpensBeforeItsMole() throws {
        var engine = makeEngine()
        while engine.holeVisuals.isEmpty { engine.advance(by: 0.01) }
        XCTAssertTrue(engine.targets.isEmpty, "the hole comes first")
        let opening = try XCTUnwrap(engine.holeVisuals.first)
        XCTAssertLessThan(opening.openness, 0.2)
        _ = run(&engine, for: engine.configuration.spawnRules.holeOpenDuration + 0.02)
        XCTAssertEqual(engine.targets.count, 1)
        XCTAssertEqual(engine.targets[0].holeIndex, opening.holeIndex)
        XCTAssertEqual(engine.holeVisuals.first?.openness ?? 0, 1, accuracy: 0.001)
    }

    func testHoleClosesAfterItsMoleHasGone() throws {
        var engine = makeEngine()
        let target = try XCTUnwrap(advanceToSpawn(&engine))
        engine.tapHole(target.holeIndex)
        let rules = engine.configuration.spawnRules
        // Still open until the mole has gone back down.
        _ = run(&engine, for: timing.impactOffset + timing.hitReaction + rules.exitAnimationDuration - 0.05)
        XCTAssertEqual(engine.holeVisuals.first?.openness ?? 0, 1, accuracy: 0.001)
        _ = run(&engine, for: 0.05 + rules.holeCloseDuration / 2)
        XCTAssertLessThan(engine.holeVisuals.first?.openness ?? 1, 1)
        _ = run(&engine, for: rules.holeCloseDuration / 2 + 0.02)
        XCTAssertTrue(engine.holeVisuals.isEmpty, "the board is empty again")
    }

    func testTrialRecordsWhereTheHoleOpened() throws {
        var engine = makeEngine()
        _ = try XCTUnwrap(advanceToSpawn(&engine))
        XCTAssertNotNil(engine.session.trials[0].position)
    }

    func testHolesOpenAtManyDifferentSpots() {
        var engine = makeEngine(level: .advanced)
        var spots: [BoardPoint] = []
        var seen = Set<Int>()
        for _ in 0..<12000 where !engine.isFinished {
            engine.advance(by: 0.02)
            for hole in engine.holeVisuals where seen.insert(hole.id).inserted { spots.append(hole.position) }
        }
        XCTAssertGreaterThan(spots.count, 10)
        for (a, b) in zip(spots, spots.dropFirst()) {
            XCTAssertGreaterThan(a.distance(to: b), 0.01, "never the same spot twice in a row")
        }
    }

    func testHoleAndMoleStayOnTheBoard() {
        let board = CGSize(width: 900, height: 700)
        let cell = GameBoardView.cellSize(board: board, targetScale: 0.95)
        for point in [BoardPoint(x: 0, y: 0), BoardPoint(x: 1, y: 1), BoardPoint(x: 0.5, y: 0.5)] {
            let center = GameBoardView.center(of: point, board: board, cell: cell)
            XCTAssertGreaterThanOrEqual(center.x - cell.width / 2, -0.001)
            XCTAssertLessThanOrEqual(center.x + cell.width / 2, board.width + 0.001)
            XCTAssertGreaterThanOrEqual(center.y - cell.height / 2, -0.001)
            XCTAssertLessThanOrEqual(center.y + cell.height / 2, board.height + 0.001)
        }
        let mole = MoleHoleView.characterRect(artIndex: 0, in: cell)
        XCTAssertGreaterThanOrEqual(mole.minY, -1, "the whole mole fits in its area")

        // A mole at the very top still leaves room for the fox's card on the board.
        for scale in [0.95, 0.8, 0.68] {
            let size = GameBoardView.cellSize(board: board, targetScale: scale)
            let center = GameBoardView.center(of: BoardPoint(x: 0.5, y: 0), board: board, cell: size)
            let rect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
            let fox = AttackAnimationView.attackGeometry(holeIndex: 1, hole: rect, home: home).strike
            let cardTop = fox.center.y - fox.size / 2 + FoxCharacterView.cardRect.minY * fox.size
            XCTAssertGreaterThanOrEqual(cardTop, 0, "fox card must not cover the top bar at scale \(scale)")
        }
    }

    // MARK: - Background

    func testHolesStayOnTheGrass() {
        // iPad Pro 11-inch, iPad mini and iPad Pro 13-inch screens.
        for screen in [CGSize(width: 1210, height: 834), CGSize(width: 1133, height: 744), CGSize(width: 1376, height: 1032)] {
            let boardTop: CGFloat = 84
            let board = CGSize(width: screen.width - 308, height: screen.height - boardTop - 44)
            let grass = GameBackgroundView.grassBand(screen: screen)
            let ground = (grass.lowerBound - boardTop)...(grass.upperBound - boardTop)
            for scale in [0.95, 0.8, 0.68] {
                let cell = GameBoardView.cellSize(board: board, targetScale: scale)
                for y in [0.0, 0.5, 1.0] {
                    let center = GameBoardView.center(of: BoardPoint(x: 0.5, y: y), board: board, cell: cell, ground: ground)
                    let frontEdge = center.y + cell.height / 2
                    XCTAssertGreaterThanOrEqual(frontEdge - cell.width * 0.42, ground.lowerBound - 0.5, "\(screen) \(scale) \(y)")
                    XCTAssertLessThanOrEqual(frontEdge + cell.width * 0.12, ground.upperBound + 0.5, "\(screen) \(scale) \(y)")
                }
            }
        }
    }
}
