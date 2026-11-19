import XCTest
@testable import DrStrange

final class FoxPathSessionTests: XCTestCase {
    private let step = 1.0 / 60
    private let feet = CGPoint(x: 700, y: 500)
    private var walk: WalkProgress { WalkProgress(distanceLeft: 2000, feet: feet) }

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

    /// Stops following until a thief comes.
    private func waitForThief(_ session: inout FoxPathSession) {
        for _ in 0..<Int(60 / step) where session.thief == nil {
            session.advance(by: step, attention: .notFollowing, walk: walk)
        }
    }

    private func appearances(in events: [FoxPathSessionEvent]) -> Int {
        events.filter { if case .thiefAppeared = $0 { true } else { false } }.count
    }

    private func livesLost(in events: [FoxPathSessionEvent]) -> [FoxPathSessionEvent] {
        events.filter { if case .lifeLost = $0 { true } else { false } }
    }

    // MARK: - Roles

    func testEveryCharacterCanTakeEitherRoleButNeverBoth() {
        var primaries = Set<PathCharacter>()
        var thieves = Set<PathCharacter>()
        var generator = SeededGenerator(seed: 1)
        for _ in 0..<300 {
            let roles = CharacterRoles.random(using: &generator)
            XCTAssertNotEqual(roles.primary, roles.thief)
            primaries.insert(roles.primary)
            thieves.insert(roles.thief)
        }
        XCTAssertEqual(primaries, Set(PathCharacter.allCases))
        XCTAssertEqual(thieves, Set(PathCharacter.allCases))
    }

    func testThiefIsTheOtherCharacterOfTheWalk() {
        for seed: UInt64 in 1...20 {
            var session = makeSession(seed: seed)
            waitForThief(&session)
            XCTAssertEqual(session.thief?.character, session.roles.thief)
            XCTAssertNotEqual(session.thief?.character, session.roles.primary)
        }
    }

    func testRolesAreDrawnAgainForEachNewWalk() {
        var session = makeSession(seed: 3)
        var seen = Set<String>()
        for _ in 0..<30 {
            seen.insert("\(session.roles.primary)-\(session.roles.thief)")
            session.walkFinished()
            session.prepareWalk()
            session.walkStarted()
        }
        XCTAssertGreaterThan(seen.count, 3, "roles change between walks")
    }

    func testThePlayersCharacterIsAlwaysTheOneFollowed() {
        for player in PathCharacter.allCases {
            var session = FoxPathSession(seed: 3, player: player)
            var thieves = Set<PathCharacter>()
            for _ in 0..<30 {
                session.prepareWalk()
                session.walkStarted()
                XCTAssertEqual(session.roles.primary, player)
                XCTAssertNotEqual(session.roles.thief, player)
                thieves.insert(session.roles.thief)
                session.walkFinished()
            }
            XCTAssertEqual(thieves.count, 2, "both other characters get to be the thief")
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
        XCTAssertNil(session.thief, "no thief is left on the map")
        XCTAssertTrue(run(&session, .notFollowing, for: 10).isEmpty, "nothing happens after the end")
        XCTAssertEqual(session.result.endReason, .timeUp)
    }

    func testTimeUpRemovesAThiefThatIsStillAround() {
        var session = makeSession(duration: 9)
        while session.catches == 0, !session.phase.isOver {
            session.advance(by: step, attention: .notFollowing, walk: walk)
        }
        XCTAssertEqual(session.catches, 1)
        XCTAssertEqual(session.thief?.state, .retreating, "still running off")
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

    // MARK: - When a thief comes

    func testNoThiefWhileTheChildKeepsFollowing() {
        var session = makeSession()
        let events = run(&session, .following, for: 115)
        XCTAssertEqual(appearances(in: events), 0, "no timer ever sends a thief")
        XCTAssertNil(session.thief)
    }

    func testMissingGazeNeverBringsAThiefOrCostsAHeart() {
        var session = makeSession()
        let events = run(&session, .trackingUnavailable, for: 60)
        XCTAssertEqual(appearances(in: events), 0)
        XCTAssertEqual(session.lives, 3)
    }

    func testAThiefComesOnlyAfterAStretchOfNotFollowing() {
        let delay = ThiefSettings().triggerDelay
        var session = makeSession()
        XCTAssertEqual(appearances(in: run(&session, .notFollowing, for: delay * 0.8)), 0, "a quick glance away brings no thief")
        run(&session, .following, for: 1)
        XCTAssertEqual(appearances(in: run(&session, .notFollowing, for: delay * 0.8)), 0, "following again starts the count over")
        run(&session, .trackingUnavailable, for: 1)
        XCTAssertEqual(appearances(in: run(&session, .notFollowing, for: delay * 0.8)), 0, "so does a missing reading")
        XCTAssertEqual(appearances(in: run(&session, .notFollowing, for: delay * 0.4)), 1)
        XCTAssertNotNil(session.thief)
    }

    func testStillNotFollowingNeverBringsASecondThiefAtOnce() {
        var session = makeSession(seed: 9)
        var active = 0
        var appeared = 0
        for _ in 0..<Int(115 / step) where !session.phase.isOver {
            for event in session.advance(by: step, attention: .notFollowing, walk: walk) {
                if case .thiefAppeared = event { active += 1; appeared += 1 }
                if event == .thiefLeft { active -= 1 }
            }
            XCTAssertLessThanOrEqual(active, 1)
        }
        XCTAssertGreaterThan(appeared, 1, "a new thief can come once the last one has gone")
    }

    func testNoNewThiefUntilTheCooldownHasPassed() {
        var session = makeSession()
        waitForThief(&session)
        // Following again chases this one off before it reaches the character.
        var events = run(&session, .following, for: 6)
        XCTAssertTrue(events.contains(.thiefLeft))
        events = run(&session, .notFollowing, for: ThiefSettings().cooldown - 1.5)
        XCTAssertEqual(appearances(in: events), 0, "still cooling down")
        events = run(&session, .notFollowing, for: 2)
        XCTAssertEqual(appearances(in: events), 1)
    }

    func testNoThiefCloseToTheEndOfTheGameOrOfTheWalk() {
        let settings = ThiefSettings()
        var nearStall = makeSession(thief: settings)
        run(&nearStall, .notFollowing, for: 5, walk: WalkProgress(distanceLeft: settings.minimumWalkLeft - 1, feet: feet))
        XCTAssertNil(nearStall.thief)

        var late = makeSession(thief: settings, duration: settings.minimumTimeLeft + 0.2)
        run(&late, .notFollowing, for: 1)
        XCTAssertNil(late.thief, "fewer than \(settings.minimumTimeLeft) s left")

        var between = makeSession(thief: settings)
        run(&between, .notFollowing, for: 5, walk: .some(nil))
        XCTAssertNil(between.thief, "no thief between walks")
    }

    // MARK: - What the thief does

    func testStandardLookAwayReachesTheCharacterInAboutTwoPointFourFourSeconds() {
        let settings = FoxPathSettings.standard
        var engine = FoxPathEngine(settings: settings, routeLength: 10_000)
        var session = makeSession()
        for _ in 0..<Int((settings.refocusDwell + 2 * step) / step) {
            _ = engine.advance(by: step, reading: .onFox)
        }
        XCTAssertEqual(engine.state, .following)

        var appearedAt: TimeInterval?
        var caughtAt: TimeInterval?
        for tick in 1...Int(4 / step) {
            _ = engine.advance(by: step, reading: .away)
            let attention: PlayerAttentionState = engine.state == .offTrack ? .notFollowing : .following
            for event in session.advance(by: step, attention: attention, walk: walk) {
                if case .thiefAppeared = event { appearedAt = Double(tick) * step }
                if case .lifeLost = event { caughtAt = Double(tick) * step }
            }
            if caughtAt != nil { break }
        }

        XCTAssertEqual(appearedAt ?? .nan, 0.84, accuracy: 2 * step)
        XCTAssertEqual(caughtAt ?? .nan, 2.44, accuracy: 2 * step)
        XCTAssertEqual(session.lives, FoxPathConfiguration.initialLives - 1)
    }

    func testThiefGoesForTheCharacterNotTheStall() throws {
        var session = makeSession()
        waitForThief(&session)
        let thief = try XCTUnwrap(session.thief)
        let start = thief.position(around: feet)
        XCTAssertEqual(hypot(start.x - feet.x, start.y - feet.y), ThiefApproach.startDistance, accuracy: 160)

        run(&session, .notFollowing, for: ThiefSettings().appearDuration + ThiefSettings().approachDuration - 0.05)
        XCTAssertEqual(session.thief?.state, .approaching)
        let near = try XCTUnwrap(session.thief).position(around: feet)
        XCTAssertLessThan(hypot(near.x - feet.x, near.y - feet.y), 120, "close beside the character")

        // The thief keeps to the character wherever it goes.
        let elsewhere = CGPoint(x: 300, y: 260)
        let moved = try XCTUnwrap(session.thief).position(around: elsewhere)
        XCTAssertEqual(moved.x - elsewhere.x, near.x - feet.x, accuracy: 1e-9)
        XCTAssertEqual(moved.y - elsewhere.y, near.y - feet.y, accuracy: 1e-9)
    }

    func testFollowingAgainMakesTheThiefBackOffAndLeave() throws {
        var session = makeSession()
        waitForThief(&session)
        run(&session, .notFollowing, for: 1.3)
        let closer = try XCTUnwrap(session.thief).progress
        XCTAssertGreaterThan(closer, FoxPathThief.lurkProgress)

        run(&session, .following, for: 1)
        XCTAssertLessThan(try XCTUnwrap(session.thief).progress, closer, "it backs off")

        let events = run(&session, .following, for: ThiefSettings().chasedOffAfter + ThiefSettings().retreatDuration)
        XCTAssertTrue(events.contains(.thiefLeft), "following long enough chases it away")
        XCTAssertTrue(livesLost(in: events).isEmpty)
        XCTAssertEqual(session.lives, 3)
    }

    func testMissingGazeMakesTheThiefWait() throws {
        var session = makeSession()
        waitForThief(&session)
        run(&session, .notFollowing, for: 1.3)
        let before = try XCTUnwrap(session.thief)
        let events = run(&session, .trackingUnavailable, for: ThiefSettings().patience + 1)
        XCTAssertTrue(livesLost(in: events).isEmpty)
        XCTAssertEqual(session.lives, 3)
        let thief = try XCTUnwrap(session.thief)
        XCTAssertEqual(thief.state, .approaching)
        XCTAssertEqual(thief.progress, before.progress, accuracy: 1e-9, "the thief holds still while tracking is unavailable")
        XCTAssertEqual(thief.age, before.age, accuracy: 1e-9, "missing tracking does not use up its patience")
        XCTAssertEqual(thief.stateTime, before.stateTime, accuracy: 1e-9)
    }

    func testMissingGazeFreezesAThiefWhileItAppears() throws {
        var session = makeSession()
        waitForThief(&session)
        let before = try XCTUnwrap(session.thief)

        let events = run(&session, .trackingUnavailable, for: ThiefSettings().patience + 1)

        XCTAssertTrue(livesLost(in: events).isEmpty)
        let thief = try XCTUnwrap(session.thief)
        XCTAssertEqual(thief.state, .appearing)
        XCTAssertEqual(thief.progress, before.progress, accuracy: 1e-9)
        XCTAssertEqual(thief.visibility, before.visibility, accuracy: 1e-9)
        XCTAssertEqual(thief.age, before.age, accuracy: 1e-9)
        XCTAssertEqual(thief.stateTime, before.stateTime, accuracy: 1e-9)
    }

    func testThiefNeverJumps() {
        var session = makeSession()
        waitForThief(&session)
        let settings = ThiefSettings()
        let fastest = 1 / min(
            settings.approachDuration / (1 - FoxPathThief.lurkProgress),
            settings.retreatDuration,
            settings.appearDuration / FoxPathThief.lurkProgress
        )
        var last = session.thief?.progress ?? 0
        for _ in 0..<Int(20 / step) {
            session.advance(by: step, attention: .notFollowing, walk: walk)
            guard let thief = session.thief else { break }
            XCTAssertLessThanOrEqual(abs(thief.progress - last), fastest * step + 1e-9)
            last = thief.progress
        }
    }

    // MARK: - Hearts

    func testReachingTheCharacterCostsExactlyOneHeart() throws {
        var session = makeSession()
        waitForThief(&session)
        var events: [FoxPathSessionEvent] = []
        var states: [ThiefState] = []
        // Until this thief has gone.
        for _ in 0..<Int(10 / step) where !events.contains(.thiefLeft) {
            events += session.advance(by: step, attention: .notFollowing, walk: walk)
            if let thief = session.thief, states.last != thief.state { states.append(thief.state) }
        }
        XCTAssertEqual(states, [.appearing, .approaching, .retreating], "it rushes up, then runs off; no stealing")
        XCTAssertEqual(livesLost(in: events), [.lifeLost(remaining: 2)])
        XCTAssertTrue(events.contains(.thiefLeft))
        XCTAssertEqual(session.lives, 2)
        XCTAssertEqual(session.catches, 1)

        // Still not following: the next thief comes once the cooldown is over.
        let next = run(&session, .notFollowing, for: ThiefSettings().cooldown + 1)
        XCTAssertEqual(appearances(in: next), 1)
    }

    func testHeartIsLostTheMomentTheThiefIsCloseEnough() throws {
        var session = makeSession()
        waitForThief(&session)
        let settings = ThiefSettings()
        var elapsed: TimeInterval = 0
        var caughtAt: TimeInterval?
        var progressAtCatch: Double?
        while caughtAt == nil, elapsed < 10 {
            let before = session.thief?.progress ?? 0
            let events = session.advance(by: step, attention: .notFollowing, walk: walk)
            elapsed += step
            if !livesLost(in: events).isEmpty {
                caughtAt = elapsed
                progressAtCatch = before
            }
        }
        let caught = try XCTUnwrap(caughtAt)
        // Fade in, then a quick rush: the heart goes as soon as the thief arrives.
        XCTAssertLessThanOrEqual(caught, settings.appearDuration + settings.approachDuration + 2 * step)
        XCTAssertGreaterThan(try XCTUnwrap(progressAtCatch), 0.9, "lost on arrival, not before")
        XCTAssertEqual(session.thief?.state, .retreating)
        XCTAssertTrue(try XCTUnwrap(session.thief).hasCaught)
    }

    func testThreeCatchesEndTheGameAndNothingHappensAfter() {
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

    func testReachingTheStallChasesTheThiefAway() throws {
        var session = makeSession()
        waitForThief(&session)
        run(&session, .notFollowing, for: 1.2)
        XCTAssertEqual(session.lives, 3, "not reached yet")
        session.walkFinished()
        XCTAssertEqual(try XCTUnwrap(session.thief).state, .retreating)
        let events = run(&session, .notFollowing, for: 5, walk: .some(nil))
        XCTAssertTrue(livesLost(in: events).isEmpty)
        XCTAssertNil(session.thief)
        XCTAssertEqual(appearances(in: events), 0, "no new thief until the next walk starts")
        XCTAssertEqual(session.walksCompleted, 1)
    }

    // MARK: - Way in

    func testThiefComesIntoViewOnTheMapBesideTheCharacter() {
        var generator = SeededGenerator(seed: 4)
        let size = FoxPathMetrics.mapSize
        for _ in 0..<300 {
            let feet = CGPoint(
                x: CGFloat.random(in: FoxPathMetrics.routeInset...(size.width - FoxPathMetrics.routeEndInset), using: &generator),
                y: CGFloat.random(in: 240...(size.height - 120), using: &generator)
            )
            let approach = ThiefApproach.make(around: feet, mapSize: size, using: &generator)
            let start = CGPoint(x: feet.x + approach.start.dx, y: feet.y + approach.start.dy)
            XCTAssertTrue((70...(size.width - 70)).contains(start.x), "\(feet): starts at \(start)")
            XCTAssertTrue((236...(size.height - 12)).contains(start.y), "\(feet): starts at \(start)")
            XCTAssertEqual(abs(approach.stand.dx), ThiefApproach.catchDistance)
            XCTAssertEqual(approach.side, approach.start.dx < 0 ? -1 : 1, "it stays on the side it came from")
        }
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

    func testWalkIsFasterThanBefore() {
        XCTAssertGreaterThan(FoxPathSettings.standard.foxSpeed, 68, "faster than the earlier 68 units/s")
        XCTAssertLessThanOrEqual(FoxPathSettings.standard.foxSpeed, 120, "still easy to follow")
    }
}
