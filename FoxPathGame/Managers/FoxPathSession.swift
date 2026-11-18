import CoreGraphics
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
    /// The mole's hole opened under the basket.
    case thiefAppeared
    case lifeLost(remaining: Int)
    case thiefLeft
    case timeUp
    case gameOver
}

/// Where the walk stands in one frame, as far as the thief is concerned.
struct WalkProgress: Equatable {
    /// Map units the followed character still has to walk to the stall.
    let distanceLeft: Double
    /// Where a mole's hole would open: on the ground under the followed character's basket
    /// (`FoxWalkPose.bagHolePoint`), in map units.
    let bagHole: CGPoint
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
    /// Carrots the mole took (one heart each).
    let catches: Int
}

/// The game around the walks: the 2-minute clock, the hearts, who the child follows, and when the
/// mole comes. A mole comes only when
/// the child has stopped following for a moment; never because of a timer and never because
/// gaze readings are missing. Driven by a game clock so it can be tested without a screen; it
/// never reads the pointer itself.
struct FoxPathSession {
    let duration: TimeInterval
    let initialLives: Int
    let thiefSettings: ThiefSettings
    let mapSize: CGSize

    private(set) var phase: FoxPathSessionPhase = .ready
    /// Seconds of play since the first look at the character.
    private(set) var clock: TimeInterval = 0
    private(set) var lives: Int
    private(set) var roles: CharacterRoles
    private(set) var thief: FoxPathThief?
    private(set) var walksCompleted = 0
    private(set) var offTrackCount = 0
    private(set) var catches = 0
    /// Seconds the child has been not following without a break, while no mole is around.
    private(set) var notFollowingTime: TimeInterval = 0
    /// Clock time before which no new mole can come.
    private(set) var thiefCooldownUntil: TimeInterval = 0

    private var isWalking = false
    private var generator: SeededGenerator

    init(
        seed: UInt64,
        thiefSettings: ThiefSettings = ThiefSettings(),
        duration: TimeInterval = FoxPathConfiguration.sessionDuration,
        initialLives: Int = FoxPathConfiguration.initialLives,
        mapSize: CGSize = FoxPathMetrics.mapSize
    ) {
        self.duration = duration
        self.initialLives = initialLives
        self.thiefSettings = thiefSettings
        self.mapSize = mapSize
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
            catches: catches
        )
    }

    /// A seed for the next map, drawn from the session's own generator so a fixed game seed
    /// reproduces every map.
    mutating func nextMapSeed() -> UInt64 {
        UInt64.random(in: .min ... .max, using: &generator)
    }

    /// A new walk on a new map. The first walk keeps the character drawn at the start; every later
    /// walk draws it again, so any of the three friends can be the one to follow.
    mutating func prepareWalk() {
        if walksCompleted > 0 { roles = CharacterRoles.random(using: &generator) }
        thief = nil
        notFollowingTime = 0
        isWalking = false
    }

    /// The character started walking (the child looked at it). The first time, the clock starts.
    mutating func walkStarted() {
        guard !phase.isOver else { return }
        phase = .playing
        isWalking = true
    }

    /// The character reached the stall. A mole that has not taken a carrot yet goes back down.
    mutating func walkFinished() {
        guard !phase.isOver else { return }
        walksCompleted += 1
        isWalking = false
        thief?.chaseAway()
        notFollowingTime = 0
    }

    mutating func recordOffTrack() {
        guard !phase.isOver else { return }
        offTrackCount += 1
    }

    /// Ends the game early (exit or rest break). Nothing changes afterwards.
    mutating func stop() {
        guard !phase.isOver else { return }
        phase = .stopped
    }

    /// - Parameter walk: where the walk stands; `nil` between walks.
    mutating func advance(by delta: TimeInterval, attention: PlayerAttentionState, walk: WalkProgress?) -> [FoxPathSessionEvent] {
        guard delta > 0, phase == .playing else { return [] }
        clock = min(clock + delta, duration)
        var events: [FoxPathSessionEvent] = []

        if var current = thief {
            for event in current.advance(by: delta, attention: attention) {
                switch event {
                case .stoleCarrot:
                    catches += 1
                    lives = max(lives - 1, 0)
                    events.append(.lifeLost(remaining: lives))
                case .left:
                    events.append(.thiefLeft)
                }
            }
            if current.state == .inactive {
                thief = nil
                thiefCooldownUntil = clock + thiefSettings.cooldown
            } else {
                thief = current
            }
        }

        if lives == 0 {
            phase = .gameOver
            events.append(.gameOver)
            return events
        }
        if clock >= duration {
            phase = .completed
            thief = nil
            events.append(.timeUp)
            return events
        }

        // Only a stretch of not following counts; following or a missing reading starts it over.
        if thief == nil, isWalking, attention == .notFollowing {
            notFollowingTime += delta
        } else {
            notFollowingTime = 0
        }
        if let walk, notFollowingTime >= thiefSettings.triggerDelay, canSendThief(walkLeft: walk.distanceLeft) {
            thief = FoxPathThief(hole: onMap(walk.bagHole), settings: thiefSettings)
            notFollowingTime = 0
            events.append(.thiefAppeared)
        }
        return events
    }

    /// Keeps the hole, and the mole above it, on the map.
    private func onMap(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 50), mapSize.width - 50),
            y: min(max(point.y, 130), mapSize.height - 20)
        )
    }

    private func canSendThief(walkLeft: Double) -> Bool {
        thief == nil
            && clock >= thiefCooldownUntil
            && remainingTime >= thiefSettings.minimumTimeLeft
            && walkLeft >= thiefSettings.minimumWalkLeft
    }
}
