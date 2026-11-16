import Foundation

enum FoxPathSessionPhase: Equatable {
    /// Before the first look at the character. The clock has not started.
    case ready
    case playing
    /// All hearts were lost.
    case gameOver
    /// The 2 minutes are up.
    case completed
    /// Stopped early (exit or rest break).
    case stopped

    var isOver: Bool { self == .gameOver || self == .completed || self == .stopped }
}

enum FoxPathSessionEvent: Equatable {
    case thiefAppeared(PathCharacter)
    case thiefReachedVegetables
    case lifeLost(remaining: Int)
    case thiefLeft
    case timeUp
    case gameOver
}

/// Gameplay summary of one game. These numbers describe the game only; they are not a
/// measurement of vision or attention and are not stored.
struct FoxPathResult: Equatable {
    enum EndReason: Equatable {
        case timeUp
        case noLivesLeft
        case stopped
    }

    let endReason: EndReason
    /// Seconds of play, from the first look at the character (pauses excluded).
    let playTime: TimeInterval
    let livesLeft: Int
    /// Walks that reached the veggie stall.
    let walksCompleted: Int
    /// How many times the character had to stop and wait.
    let offTrackCount: Int
    let thefts: Int
}

/// The game around the walks: the 2-minute clock, the hearts, who plays which role, and when a
/// thief comes. Driven by a game clock so it can be tested without a screen; it never reads
/// the pointer itself.
struct FoxPathSession {
    let duration: TimeInterval
    let initialLives: Int
    let thiefSettings: ThiefSettings

    private(set) var phase: FoxPathSessionPhase = .ready
    /// Seconds of play since the first look at the character.
    private(set) var clock: TimeInterval = 0
    private(set) var lives: Int
    private(set) var roles: CharacterRoles
    private(set) var thief: FoxPathThief?
    private(set) var walksCompleted = 0
    private(set) var offTrackCount = 0
    private(set) var thefts = 0
    /// Clock time at which the next thief may appear; `nil` when none is due.
    private(set) var nextThiefAt: TimeInterval?

    private var thiefRoute: ThiefRoute?
    private var generator: SeededGenerator

    init(
        seed: UInt64,
        thiefSettings: ThiefSettings = ThiefSettings(),
        duration: TimeInterval = FoxPathConfiguration.sessionDuration,
        initialLives: Int = FoxPathConfiguration.initialLives
    ) {
        self.duration = duration
        self.initialLives = initialLives
        self.thiefSettings = thiefSettings
        lives = initialLives
        generator = SeededGenerator(seed: seed)
        roles = CharacterRoles.random(using: &generator)
    }

    var remainingTime: TimeInterval { max(duration - clock, 0) }

    var result: FoxPathResult {
        FoxPathResult(
            endReason: phase == .gameOver ? .noLivesLeft : (phase == .completed ? .timeUp : .stopped),
            playTime: clock,
            livesLeft: lives,
            walksCompleted: walksCompleted,
            offTrackCount: offTrackCount,
            thefts: thefts
        )
    }

    /// A seed for the next map, drawn from the session's own generator so a fixed game seed
    /// reproduces every map.
    mutating func nextMapSeed() -> UInt64 {
        UInt64.random(in: .min ... .max, using: &generator)
    }

    /// A new walk on a new map. The first walk keeps the roles drawn at the start; every later
    /// walk draws them again, so any character can be followed or be the thief.
    mutating func prepareWalk(thiefRoute: ThiefRoute) {
        if walksCompleted > 0 { roles = CharacterRoles.random(using: &generator) }
        self.thiefRoute = thiefRoute
        thief = nil
        nextThiefAt = nil
    }

    /// The character started walking (the child looked at it). The first time, the clock starts.
    mutating func walkStarted() {
        guard !phase.isOver else { return }
        phase = .playing
        nextThiefAt = clock + Double.random(in: thiefSettings.firstAppearanceRange, using: &generator)
    }

    /// The character reached the stall. A thief still on its way runs off.
    mutating func walkFinished() {
        guard !phase.isOver else { return }
        walksCompleted += 1
        thief?.chaseAway()
        nextThiefAt = nil
    }

    mutating func recordOffTrack() {
        guard !phase.isOver else { return }
        offTrackCount += 1
    }

    /// Ends the game early (exit or rest break). Nothing changes afterwards.
    mutating func stop() {
        guard !phase.isOver else { return }
        phase = .stopped
        nextThiefAt = nil
    }

    /// - Parameters:
    ///   - walkLeft: map units the followed character still has to walk; `nil` between walks.
    mutating func advance(by delta: TimeInterval, attention: PlayerAttentionState, walkLeft: Double?) -> [FoxPathSessionEvent] {
        guard delta > 0, phase == .playing else { return [] }
        clock = min(clock + delta, duration)
        var events: [FoxPathSessionEvent] = []

        if var current = thief {
            for event in current.advance(by: delta, attention: attention) {
                switch event {
                case .reachedVegetables:
                    events.append(.thiefReachedVegetables)
                case .stole:
                    thefts += 1
                    lives = max(lives - 1, 0)
                    events.append(.lifeLost(remaining: lives))
                case .left:
                    events.append(.thiefLeft)
                }
            }
            if current.state == .inactive {
                thief = nil
                if walkLeft != nil { nextThiefAt = clock + Double.random(in: thiefSettings.appearanceIntervalRange, using: &generator) }
            } else {
                thief = current
            }
        }

        if lives == 0 {
            phase = .gameOver
            nextThiefAt = nil
            events.append(.gameOver)
            return events
        }
        if clock >= duration {
            phase = .completed
            thief = nil
            nextThiefAt = nil
            events.append(.timeUp)
            return events
        }

        if thief == nil, let due = nextThiefAt, clock >= due, let route = thiefRoute {
            if remainingTime < thiefSettings.minimumTimeLeft {
                nextThiefAt = nil
            } else if let walkLeft, walkLeft >= thiefSettings.minimumWalkLeft {
                thief = FoxPathThief(character: roles.thief, route: route, settings: thiefSettings)
                nextThiefAt = nil
                events.append(.thiefAppeared(roles.thief))
            } else {
                // Too close to the stall or between walks: wait for the next walk.
                nextThiefAt = nil
            }
        }
        return events
    }
}
