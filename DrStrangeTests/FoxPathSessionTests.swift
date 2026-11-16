import XCTest
@testable import DrStrange

final class FoxPathSessionTests: XCTestCase {
    private let step = 1.0 / 60
    private let route = ThiefRoute(start: CGPoint(x: 1700, y: 1300), target: CGPoint(x: 1400, y: 300))

    /// A session on its first walk, with the clock running.
    private func makeSession(seed: UInt64 = 5, thief: ThiefSettings = ThiefSettings()) -> FoxPathSession {
        var session = FoxPathSession(seed: seed, thiefSettings: thief)
        session.prepareWalk(thiefRoute: route)
        session.walkStarted()
        return session
    }

    /// Feeds the same attention for `seconds` and returns every event.
    @discardableResult
    private func run(
        _ session: inout FoxPathSession,
        _ attention: PlayerAttentionState,
        for seconds: Double,
        walkLeft: Double? = 2000
    ) -> [FoxPathSessionEvent] {
        var events: [FoxPathSessionEvent] = []
        for _ in 0..<Int((seconds / step).rounded()) {
            events += session.advance(by: step, attention: attention, walkLeft: walkLeft)
        }
        return events
    }

    /// Runs until a thief is on the map.
    private func waitForThief(_ session: inout FoxPathSession) {
        for _ in 0..<Int(60 / step) where session.thief == nil {
            session.advance(by: step, attention: .following, walkLeft: 2000)
        }
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
            session.prepareWalk(thiefRoute: route)
            session.walkStarted()
        }
        XCTAssertGreaterThan(seen.count, 3, "roles change between walks")
    }

    // MARK: - Clock

    func testClockStartsAtTheFirstLookAndStopsAfterTwoMinutes() {
        var session = FoxPathSession(seed: 1)
        session.prepareWalk(thiefRoute: route)
        XCTAssertEqual(session.remainingTime, 120)
        XCTAssertTrue(run(&session, .following, for: 10).isEmpty, "nothing runs before the first look")
        XCTAssertEqual(session.remainingTime, 120)

        session.walkStarted()
        let events = run(&session, .following, for: 125)
        XCTAssertEqual(events.filter { $0 == .timeUp }.count, 1)
        XCTAssertEqual(session.phase, .completed)
        XCTAssertEqual(session.clock, 120, accuracy: 1e-9)
        XCTAssertEqual(session.remainingTime, 0)
        XCTAssertNil(session.thief, "no thief is left on the map")
        XCTAssertNil(session.nextThiefAt, "no thief is due")
        XCTAssertTrue(run(&session, .notFollowing, for: 10).isEmpty, "nothing happens after the end")
        XCTAssertEqual(session.result.endReason, .timeUp)
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

    // MARK: - Thief

    func testFirstThiefComesAtARandomTimeInTheConfiguredRange() {
        let range = ThiefSettings().firstAppearanceRange
        var times = Set<Int>()
        for seed: UInt64 in 1...30 {
            var session = makeSession(seed: seed)
            waitForThief(&session)
            XCTAssertTrue(range.contains(session.clock - step) || range.contains(session.clock), "seed \(seed): \(session.clock)")
            times.insert(Int(session.clock * 10))
        }
        XCTAssertGreaterThan(times.count, 10, "appearance times vary")
    }

    func testOnlyOneThiefAtATime() {
        var session = makeSession(seed: 9)
        var active = 0
        var appeared = 0
        for index in 0..<Int(115 / step) {
            // Alternate between following and not following so thieves come and go.
            let attention: PlayerAttentionState = (index / 600).isMultiple(of: 2) ? .following : .notFollowing
            for event in session.advance(by: step, attention: attention, walkLeft: 2000) {
                if case .thiefAppeared = event { active += 1; appeared += 1 }
                if event == .thiefLeft { active -= 1 }
            }
            XCTAssertLessThanOrEqual(active, 1)
            if session.phase.isOver { break }
        }
        XCTAssertGreaterThan(appeared, 1)
    }

    func testThiefOnlyGetsCloserWhileTheChildIsNotFollowing() throws {
        var session = makeSession()
        waitForThief(&session)
        run(&session, .following, for: 5)
        let lurking = try XCTUnwrap(session.thief)
        XCTAssertEqual(lurking.state, .approaching)
        XCTAssertEqual(lurking.progress, FoxPathThief.lurkProgress, accuracy: 1e-9, "following keeps the thief back")

        run(&session, .notFollowing, for: 2)
        let closer = try XCTUnwrap(session.thief).progress
        XCTAssertGreaterThan(closer, lurking.progress)

        run(&session, .following, for: 1)
        XCTAssertLessThan(try XCTUnwrap(session.thief).progress, closer, "following again makes it back off")
    }

    func testThiefNeverJumps() {
        var session = makeSession()
        waitForThief(&session)
        let settings = ThiefSettings()
        let fastest = 1 / min(settings.approachDuration, settings.retreatDuration, settings.appearDuration / FoxPathThief.lurkProgress)
        var last = session.thief?.progress ?? 0
        for _ in 0..<Int(20 / step) {
            session.advance(by: step, attention: .notFollowing, walkLeft: 2000)
            guard let thief = session.thief else { break }
            XCTAssertLessThanOrEqual(abs(thief.progress - last), fastest * step + 1e-9)
            last = thief.progress
        }
    }

    func testMissingGazeNeverCostsAHeart() throws {
        var session = makeSession()
        waitForThief(&session)
        run(&session, .notFollowing, for: 2)
        let heldAt = try XCTUnwrap(session.thief).progress
        let events = run(&session, .trackingUnavailable, for: 8)
        XCTAssertFalse(events.contains { if case .lifeLost = $0 { true } else { false } })
        XCTAssertEqual(session.lives, 3)
        if let thief = session.thief, thief.state == .approaching {
            XCTAssertEqual(thief.progress, heldAt, accuracy: 1e-9, "the thief waits while tracking is unavailable")
        }
    }

    func testATheftCostsExactlyOneHeart() {
        var session = makeSession()
        waitForThief(&session)
        let events = run(&session, .notFollowing, for: 12)
        let lost = events.filter { if case .lifeLost = $0 { true } else { false } }
        XCTAssertEqual(lost, [.lifeLost(remaining: 2)])
        XCTAssertTrue(events.contains(.thiefReachedVegetables))
        XCTAssertTrue(events.contains(.thiefLeft))
        XCTAssertEqual(session.lives, 2)
        XCTAssertEqual(session.thefts, 1)
    }

    func testThreeTheftsEndTheGameAndNothingHappensAfter() {
        var session = makeSession()
        var events: [FoxPathSessionEvent] = []
        for _ in 0..<Int(115 / step) where !session.phase.isOver {
            events += session.advance(by: step, attention: .notFollowing, walkLeft: 2000)
        }
        XCTAssertEqual(session.phase, .gameOver)
        XCTAssertEqual(session.lives, 0)
        XCTAssertEqual(events.filter { if case .lifeLost = $0 { true } else { false } }.count, 3)
        XCTAssertEqual(events.filter { $0 == .gameOver }.count, 1)
        XCTAssertNil(session.nextThiefAt)
        XCTAssertTrue(run(&session, .notFollowing, for: 30).isEmpty)
        XCTAssertEqual(session.lives, 0, "never below zero")
        XCTAssertEqual(session.result.endReason, .noLivesLeft)
    }

    func testReachingTheStallChasesTheThiefAway() throws {
        var session = makeSession()
        waitForThief(&session)
        run(&session, .notFollowing, for: 2)
        session.walkFinished()
        XCTAssertEqual(try XCTUnwrap(session.thief).state, .retreating)
        let events = run(&session, .notFollowing, for: 5, walkLeft: nil)
        XCTAssertFalse(events.contains { if case .lifeLost = $0 { true } else { false } })
        XCTAssertNil(session.thief)
        XCTAssertNil(session.nextThiefAt, "no new thief until the next walk starts")
        XCTAssertEqual(session.walksCompleted, 1)
    }

    func testNoThiefCloseToTheEndOfTheGameOrOfTheWalk() {
        var settings = ThiefSettings()
        settings.firstAppearanceRange = 1...1
        var nearStall = makeSession(thief: settings)
        run(&nearStall, .following, for: 3, walkLeft: settings.minimumWalkLeft - 1)
        XCTAssertNil(nearStall.thief)

        var late = FoxPathSession(seed: 2, thiefSettings: settings, duration: 10)
        late.prepareWalk(thiefRoute: route)
        late.walkStarted()
        run(&late, .following, for: 3)
        XCTAssertNil(late.thief, "fewer than \(settings.minimumTimeLeft) s left")
    }

    // MARK: - Thief route

    func testThiefComesFromOffTheMapToTheStall() throws {
        for seed: UInt64 in 1...40 {
            let map = FoxPathGenerator.makeMap(seed: seed, settings: .standard)
            var generator = SeededGenerator(seed: seed)
            let route = ThiefRoute.make(for: map, using: &generator)
            let stall = try XCTUnwrap(map.standingSprites.first { $0.kind == .finishStall })
            XCTAssertGreaterThanOrEqual(route.length, ThiefRoute.minimumLength, "seed \(seed)")
            XCTAssertFalse(CGRect(origin: .zero, size: map.size).insetBy(dx: -60, dy: -200).contains(route.start), "seed \(seed): starts out of sight")
            XCTAssertEqual(route.target.y, stall.baseline + 6, accuracy: 0.001)
            XCTAssertTrue((stall.frame.minX...stall.frame.maxX).contains(route.target.x), "seed \(seed)")
            // The widest character (146 units) stays on the map at the stall.
            XCTAssertLessThanOrEqual(route.target.x + 73, map.size.width, "seed \(seed)")
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
}
