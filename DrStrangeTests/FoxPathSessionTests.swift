import XCTest
@testable import DrStrange

final class FoxPathSessionTests: XCTestCase {
    private let step = 1.0 / 60
    private let hole = CGPoint(x: 660, y: 506)
    private var walk: WalkProgress { WalkProgress(distanceLeft: 2000, bagHole: hole) }

    /// A session on its first walk, with the clock running.
    private func makeSession(seed: UInt64 = 5, thief: ThiefSettings = ThiefSettings(), duration: TimeInterval = 120) -> FoxPathSession {
        var session = FoxPathSession(seed: seed, thiefSettings: thief, duration: duration)
        session.prepareWalk()
        session.walkStarted()
        return session
    }

    /// Feeds the same attention for `seconds` and returns every event.
    @discardableResult
    private func run(
        _ session: inout FoxPathSession,
        _ attention: PlayerAttentionState,
        for seconds: Double,
        walk: WalkProgress?? = nil
    ) -> [FoxPathSessionEvent] {
        let current = walk ?? self.walk
        var events: [FoxPathSessionEvent] = []
        for _ in 0..<Int((seconds / step).rounded()) {
            events += session.advance(by: step, attention: attention, walk: current)
        }
        return events
    }

    /// Stops following until a mole comes.
    private func waitForMole(_ session: inout FoxPathSession) {
        for _ in 0..<Int(60 / step) where session.thief == nil {
            session.advance(by: step, attention: .notFollowing, walk: walk)
        }
    }

    /// Keeps feeding `attention` until the mole is in `state` (or 10 s pass).
    private func run(_ session: inout FoxPathSession, _ attention: PlayerAttentionState, until state: ThiefState) -> [FoxPathSessionEvent] {
        var events: [FoxPathSessionEvent] = []
        for _ in 0..<Int(10 / step) where session.thief?.state != state {
            events += session.advance(by: step, attention: attention, walk: walk)
        }
        return events
    }

    private func appearances(in events: [FoxPathSessionEvent]) -> Int {
        events.filter { $0 == .thiefAppeared }.count
    }

    private func livesLost(in events: [FoxPathSessionEvent]) -> [FoxPathSessionEvent] {
        events.filter { if case .lifeLost = $0 { true } else { false } }
    }

    // MARK: - Who to follow

    func testEveryFriendCanBeTheOneToFollow() {
        var primaries = Set<PathCharacter>()
        var generator = SeededGenerator(seed: 1)
        for _ in 0..<300 {
            primaries.insert(CharacterRoles.random(using: &generator).primary)
        }
        XCTAssertEqual(primaries, [.fox, .bunny, .raccoon])
    }

    func testOneFriendIsFollowedPerWalkAndItIsDrawnAgainForEachNewWalk() {
        var session = makeSession(seed: 3)
        var seen = Set<PathCharacter>()
        for _ in 0..<30 {
            seen.insert(session.roles.primary)
            session.walkFinished()
            session.prepareWalk()
            session.walkStarted()
        }
        XCTAssertGreaterThan(seen.count, 1, "the friend to follow changes between walks")
    }

    func testThePlayersCharacterIsAlwaysTheOneFollowed() {
        for player in PathCharacter.allCases {
            // The thief is always the mole, so only the one to follow is fixed.
            var session = FoxPathSession(seed: 3, player: player)
            for _ in 0..<30 {
                session.prepareWalk()
                session.walkStarted()
                XCTAssertEqual(session.roles.primary, player)
                session.walkFinished()
            }
        }
    }

    // MARK: - Clock

    func testClockStartsAtTheFirstLookAndStopsAfterTwoMinutes() {
        var session = FoxPathSession(seed: 1)
        session.prepareWalk()
        XCTAssertEqual(session.remainingTime, 120)
        XCTAssertTrue(run(&session, .notFollowing, for: 10).isEmpty, "nothing runs before the first look")
        XCTAssertEqual(session.remainingTime, 120)

        session.walkStarted()
        let events = run(&session, .following, for: 125)
        XCTAssertEqual(events.filter { $0 == .timeUp }.count, 1)
        XCTAssertEqual(session.phase, .completed)
        XCTAssertEqual(session.clock, 120, accuracy: 1e-9)
        XCTAssertEqual(session.remainingTime, 0)
        XCTAssertNil(session.thief, "no mole is left on the map")
        XCTAssertTrue(run(&session, .notFollowing, for: 10).isEmpty, "nothing happens after the end")
        XCTAssertEqual(session.result.endReason, .timeUp)
    }

    func testTimeUpRemovesAMoleThatIsStillAround() {
        var session = makeSession(duration: 9)
        while session.catches == 0, !session.phase.isOver {
            session.advance(by: step, attention: .notFollowing, walk: walk)
        }
        XCTAssertEqual(session.catches, 1)
        XCTAssertEqual(session.thief?.state, .sinking, "still going back down")
        let events = run(&session, .notFollowing, for: 9)
        XCTAssertEqual(events.last, .timeUp)
        XCTAssertNil(session.thief)
    }

    func testStoppingEndsEverything() {
        var session = makeSession()
        run(&session, .following, for: 5)
        session.stop()
        XCTAssertEqual(session.phase, .stopped)
        XCTAssertTrue(run(&session, .notFollowing, for: 60).isEmpty)
        XCTAssertEqual(session.lives, 3)
        XCTAssertEqual(session.result.endReason, .stopped)
    }

    // MARK: - When the mole comes

    func testNoMoleWhileTheChildKeepsFollowing() {
        var session = makeSession()
        let events = run(&session, .following, for: 115)
        XCTAssertEqual(appearances(in: events), 0, "no timer ever sends a mole")
        XCTAssertNil(session.thief)
    }

    func testMissingGazeNeverBringsAMoleOrCostsAHeart() {
        var session = makeSession()
        let events = run(&session, .trackingUnavailable, for: 60)
        XCTAssertEqual(appearances(in: events), 0)
        XCTAssertTrue(livesLost(in: events).isEmpty)
        XCTAssertEqual(session.lives, 3)
    }

    func testAMoleComesOnlyAfterAStretchOfNotFollowing() {
        let delay = ThiefSettings().triggerDelay
        var session = makeSession()
        XCTAssertEqual(appearances(in: run(&session, .notFollowing, for: delay * 0.8)), 0, "a quick glance away brings no mole")
        run(&session, .following, for: 1)
        XCTAssertEqual(appearances(in: run(&session, .notFollowing, for: delay * 0.8)), 0, "following again starts the count over")
        run(&session, .trackingUnavailable, for: 1)
        XCTAssertEqual(appearances(in: run(&session, .notFollowing, for: delay * 0.8)), 0, "so does a missing reading")
        XCTAssertEqual(appearances(in: run(&session, .notFollowing, for: delay * 0.4)), 1)
        XCTAssertNotNil(session.thief)
    }

    func testStillNotFollowingNeverBringsASecondMoleAtOnce() {
        var session = makeSession(seed: 9)
        var active = 0
        var appeared = 0
        for _ in 0..<Int(115 / step) where !session.phase.isOver {
            for event in session.advance(by: step, attention: .notFollowing, walk: walk) {
                if event == .thiefAppeared { active += 1; appeared += 1 }
                if event == .thiefLeft { active -= 1 }
            }
            XCTAssertLessThanOrEqual(active, 1)
        }
        XCTAssertGreaterThan(appeared, 1, "a new mole can come once the last one has gone")
    }

    func testNoNewMoleUntilTheCooldownHasPassed() {
        var session = makeSession()
        waitForMole(&session)
        // Following again sends this one away before it takes a carrot; the cooldown starts once
        // its hole has closed.
        var events = run(&session, .following, for: 1)
        XCTAssertTrue(events.contains(.thiefLeft))
        events = run(&session, .notFollowing, for: ThiefSettings().cooldown - 1.5)
        XCTAssertEqual(appearances(in: events), 0, "still cooling down")
        events = run(&session, .notFollowing, for: 2)
        XCTAssertEqual(appearances(in: events), 1)
    }

    func testNoMoleCloseToTheEndOfTheGameOrOfTheWalk() {
        let settings = ThiefSettings()
        var nearStall = makeSession(thief: settings)
        run(&nearStall, .notFollowing, for: 5, walk: WalkProgress(distanceLeft: settings.minimumWalkLeft - 1, bagHole: hole))
        XCTAssertNil(nearStall.thief)

        var late = makeSession(thief: settings, duration: settings.minimumTimeLeft + 0.2)
        run(&late, .notFollowing, for: 1)
        XCTAssertNil(late.thief, "fewer than \(settings.minimumTimeLeft) s left")

        var between = makeSession(thief: settings)
        run(&between, .notFollowing, for: 5, walk: .some(nil))
        XCTAssertNil(between.thief, "no mole between walks")
    }

    // MARK: - What the mole does

    func testMoleComesUpUnderTheBasketAndStaysInItsHole() throws {
        var session = makeSession()
        waitForMole(&session)
        XCTAssertEqual(try XCTUnwrap(session.thief).hole, hole, "the hole opens under the basket")
        // The hole stays where it opened, even if the character later walks on.
        let elsewhere = WalkProgress(distanceLeft: 1500, bagHole: CGPoint(x: 900, y: 400))
        run(&session, .notFollowing, for: 0.5, walk: .some(elsewhere))
        XCTAssertEqual(try XCTUnwrap(session.thief).hole, hole)
    }

    func testHoleStaysOnTheMap() throws {
        var session = makeSession()
        let size = FoxPathMetrics.mapSize
        for _ in 0..<Int(60 / step) where session.thief == nil {
            session.advance(by: step, attention: .notFollowing, walk: WalkProgress(distanceLeft: 2000, bagHole: CGPoint(x: -40, y: size.height + 30)))
        }
        let opened = try XCTUnwrap(session.thief).hole
        XCTAssertTrue((0...size.width).contains(opened.x))
        XCTAssertTrue((0...size.height).contains(opened.y))
    }

    func testMoleOpensItsHoleComesUpTakesOneCarrotAndGoesBackDown() {
        var session = makeSession()
        waitForMole(&session)
        var events: [FoxPathSessionEvent] = []
        var states: [ThiefState] = []
        var carrotWhileSinking = false
        for _ in 0..<Int(10 / step) where !events.contains(.thiefLeft) {
            events += session.advance(by: step, attention: .notFollowing, walk: walk)
            guard let mole = session.thief else { continue }
            if states.last != mole.state { states.append(mole.state) }
            if mole.state == .sinking, mole.hasStolen { carrotWhileSinking = true }
        }
        XCTAssertEqual(states, [.openingHole, .emerging, .reaching, .sinking, .closingHole])
        XCTAssertTrue(carrotWhileSinking, "it goes back down holding the carrot")
        XCTAssertEqual(livesLost(in: events), [.lifeLost(remaining: 2)], "exactly one carrot, one heart")
        XCTAssertNil(session.thief, "nothing is left on the map once the hole has closed")
        XCTAssertEqual(session.lives, 2)
        XCTAssertEqual(session.catches, 1)

        // Still not following: the next mole comes once the cooldown is over.
        let next = run(&session, .notFollowing, for: ThiefSettings().cooldown + 1)
        XCTAssertEqual(appearances(in: next), 1)
    }

    func testMoleRisesSteadilyOutOfTheHoleAndBackIn() {
        var session = makeSession()
        waitForMole(&session)
        let settings = ThiefSettings()
        let fastest = 1 / min(settings.emergeDuration, settings.sinkDuration)
        var last = session.thief?.rise ?? 0
        var highest = 0.0
        for _ in 0..<Int(5 / step) {
            session.advance(by: step, attention: .notFollowing, walk: walk)
            guard let mole = session.thief else { break }
            XCTAssertLessThanOrEqual(abs(mole.rise - last), fastest * step + 1e-9, "never jumps")
            last = mole.rise
            highest = max(highest, mole.rise)
        }
        XCTAssertEqual(highest, 1, accuracy: 1e-9)
        XCTAssertNil(session.thief)
    }

    func testTheMoleShowingUpDoesNotCostAHeart() {
        var session = makeSession()
        waitForMole(&session)
        let events = run(&session, .notFollowing, until: .reaching)
        XCTAssertTrue(livesLost(in: events).isEmpty)
        XCTAssertEqual(session.lives, 3, "up and reaching, but no carrot yet")
    }

    func testLookingBackBeforeTheTheftSendsTheMoleAwayEmptyHanded() throws {
        var session = makeSession()
        waitForMole(&session)
        run(&session, .notFollowing, until: .reaching)
        run(&session, .notFollowing, for: ThiefSettings().reachDuration * 0.5)
        session.advance(by: step, attention: .following, walk: walk)
        let mole = try XCTUnwrap(session.thief)
        XCTAssertEqual(mole.state, .sinking, "it goes straight back down")
        XCTAssertFalse(mole.hasStolen)
        XCTAssertTrue(mole.wasChasedOff)
        // Even if the child looks away again while it goes down, it does not come back up.
        let events = run(&session, .notFollowing, for: 2)
        XCTAssertTrue(livesLost(in: events).isEmpty)
        XCTAssertTrue(events.contains(.thiefLeft))
        XCTAssertEqual(session.lives, 3)
        XCTAssertEqual(session.catches, 0)
    }

    func testLookingBackWhileTheHoleOpensClosesItAgain() throws {
        var session = makeSession()
        waitForMole(&session)
        run(&session, .notFollowing, for: ThiefSettings().holeOpenDuration * 0.6)
        XCTAssertEqual(try XCTUnwrap(session.thief).state, .openingHole)
        session.advance(by: step, attention: .following, walk: walk)
        XCTAssertEqual(try XCTUnwrap(session.thief).state, .closingHole)
        let events = run(&session, .following, for: 1)
        XCTAssertTrue(events.contains(.thiefLeft))
        XCTAssertTrue(livesLost(in: events).isEmpty)
    }

    func testLookingBackAfterTheTheftDoesNotGiveTheHeartBack() throws {
        var session = makeSession()
        waitForMole(&session)
        let stolen = run(&session, .notFollowing, until: .sinking)
        XCTAssertEqual(livesLost(in: stolen).count, 1)
        let after = run(&session, .following, for: 3)
        XCTAssertTrue(livesLost(in: after).isEmpty, "never a second heart for the same carrot")
        XCTAssertEqual(session.lives, 2)
    }

    func testMissingGazeFreezesTheMoleAndCostsNothing() throws {
        var session = makeSession()
        waitForMole(&session)
        run(&session, .notFollowing, until: .reaching)
        let before = try XCTUnwrap(session.thief)
        let events = run(&session, .trackingUnavailable, for: 10)
        XCTAssertTrue(livesLost(in: events).isEmpty)
        let mole = try XCTUnwrap(session.thief)
        XCTAssertEqual(mole.state, .reaching)
        XCTAssertEqual(mole.stateTime, before.stateTime, accuracy: 1e-9, "the mole holds still while tracking is unavailable")
        XCTAssertEqual(mole.age, before.age, accuracy: 1e-9)
        XCTAssertFalse(mole.wasChasedOff, "a missing reading is not looking back")
    }

    // MARK: - Hearts

    func testThreeTheftsEndTheGameAndNothingHappensAfter() {
        var session = makeSession()
        var events: [FoxPathSessionEvent] = []
        for _ in 0..<Int(115 / step) where !session.phase.isOver {
            events += session.advance(by: step, attention: .notFollowing, walk: walk)
        }
        XCTAssertEqual(session.phase, .gameOver)
        XCTAssertEqual(session.lives, 0)
        XCTAssertEqual(livesLost(in: events).count, 3)
        XCTAssertEqual(events.filter { $0 == .gameOver }.count, 1)
        XCTAssertTrue(run(&session, .notFollowing, for: 30).isEmpty)
        XCTAssertEqual(session.lives, 0, "never below zero")
        XCTAssertEqual(session.result.endReason, .noLivesLeft)
    }

    func testReachingTheStallSendsTheMoleAway() throws {
        var session = makeSession()
        waitForMole(&session)
        run(&session, .notFollowing, until: .reaching)
        XCTAssertEqual(session.lives, 3, "no carrot yet")
        session.walkFinished()
        XCTAssertEqual(try XCTUnwrap(session.thief).state, .sinking)
        let events = run(&session, .notFollowing, for: 5, walk: .some(nil))
        XCTAssertTrue(livesLost(in: events).isEmpty)
        XCTAssertNil(session.thief)
        XCTAssertEqual(appearances(in: events), 0, "no new mole until the next walk starts")
        XCTAssertEqual(session.walksCompleted, 1)
    }

    // MARK: - Settings

    func testOldSavedSettingsWithALevelStillLoad() throws {
        let old = #"{"level":3,"soundEnabled":false,"showsGazeMarker":false}"#
        let configuration = try JSONDecoder().decode(FoxPathConfiguration.self, from: Data(old.utf8))
        XCTAssertFalse(configuration.soundEnabled)
        XCTAssertFalse(configuration.showsGazeMarker)
        XCTAssertEqual(configuration.settings, .standard)
        XCTAssertEqual(FoxPathConfiguration.sessionDuration, 120)
        XCTAssertEqual(FoxPathConfiguration.initialLives, 3)
    }

    func testMoleTimingsKeepTheExistingTriggerAndCooldown() {
        let settings = ThiefSettings()
        XCTAssertEqual(settings.triggerDelay, 0.5)
        XCTAssertEqual(settings.cooldown, 4)
    }

    func testWalkIsFasterThanBefore() {
        XCTAssertGreaterThan(FoxPathSettings.standard.foxSpeed, 68, "faster than the earlier 68 units/s")
        XCTAssertLessThanOrEqual(FoxPathSettings.standard.foxSpeed, 120, "still easy to follow")
    }
}
