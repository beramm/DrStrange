import Foundation

/// What the pointer (gaze, or a finger in practice mode) is doing in one frame.
enum FoxPointerReading: Equatable {
    /// On or near the fox.
    case onFox
    /// Somewhere else on the screen.
    case away
    /// No usable reading, for example the tracker lost the eye. Never counted as looking away.
    case unavailable
}

enum FoxTrackingState: Equatable {
    /// Before the first look at the fox. The fox waits and nothing is counted yet.
    case waiting
    case following
    /// The pointer left the fox for longer than the grace time. The fox stands still until
    /// the pointer rests on it again.
    case offTrack
    case finished
}

enum FoxPathEvent: Equatable {
    case started
    case wentOffTrack
    case refocused
    case finished
}

/// Gameplay summary of one walk. These numbers describe the game only; they are not a
/// measurement of vision and are not stored.
struct FoxPathResult: Equatable {
    /// Seconds from the first look at the fox to the finish.
    let elapsedTime: TimeInterval
    /// Seconds the fox was walking.
    let followingTime: TimeInterval
    /// How many times the fox had to stop and wait.
    let offTrackCount: Int
    let reachedEnd: Bool

    /// 1 to 3 stars for the result screen. `.gameDesign` thresholds.
    var stars: Int {
        guard reachedEnd else { return 1 }
        switch offTrackCount {
        case ...1: return 3
        case ...4: return 2
        default: return 1
        }
    }
}

/// Rules of Follow the Fox, driven by a game clock so it can be tested without a screen:
/// the fox walks along the route while the pointer stays on it and stops when the pointer
/// leaves for too long.
struct FoxPathEngine {
    /// Seconds without a usable reading before the game asks for the eyes to be found again.
    static let unavailableHintDelay: TimeInterval = 0.6
    /// How fast refocus progress drains while the pointer is off the fox, relative to filling.
    private static let refocusDrainRate = 2.0

    let settings: FoxPathSettings
    let routeLength: Double

    private(set) var state: FoxTrackingState = .waiting
    /// Distance walked along the route, in map units.
    private(set) var distance: Double = 0
    /// `true` when the fox moved in the last step.
    private(set) var isWalking = false
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var followingTime: TimeInterval = 0
    private(set) var offTrackCount = 0

    private var awayTime: TimeInterval = 0
    private var dwellTime: TimeInterval = 0
    private var unavailableTime: TimeInterval = 0

    init(settings: FoxPathSettings, routeLength: Double) {
        self.settings = settings
        self.routeLength = max(routeLength, 1)
    }

    /// 0 at the start of the path, 1 at the end.
    var progress: Double { min(distance / routeLength, 1) }

    /// 0...1 while the pointer is settling on a waiting fox; 1 lets it walk.
    var refocusProgress: Double {
        guard state == .waiting || state == .offTrack else { return 0 }
        return min(dwellTime / max(settings.refocusDwell, 0.01), 1)
    }

    /// `true` once readings have been missing long enough to tell the player.
    var needsPointer: Bool { unavailableTime >= Self.unavailableHintDelay }

    var result: FoxPathResult {
        FoxPathResult(
            elapsedTime: elapsedTime,
            followingTime: followingTime,
            offTrackCount: offTrackCount,
            reachedEnd: state == .finished
        )
    }

    mutating func advance(by delta: TimeInterval, reading: FoxPointerReading) -> [FoxPathEvent] {
        guard delta > 0, state != .finished else { return [] }
        isWalking = false
        unavailableTime = reading == .unavailable ? unavailableTime + delta : 0
        if state != .waiting { elapsedTime += delta }

        switch state {
        case .waiting:
            return settle(delta, reading: reading) ? [.started] : []
        case .offTrack:
            return settle(delta, reading: reading) ? [.refocused] : []
        case .following:
            switch reading {
            case .onFox:
                awayTime = 0
            case .unavailable:
                // Hold still without blame until the tracker sees the eye again.
                return []
            case .away:
                awayTime += delta
                if awayTime >= settings.lookAwayGrace {
                    state = .offTrack
                    offTrackCount += 1
                    dwellTime = 0
                    return [.wentOffTrack]
                }
            }
            return walk(delta)
        case .finished:
            return []
        }
    }

    /// Fills the dwell while the pointer rests on the fox. Returns `true` when the fox may walk.
    private mutating func settle(_ delta: TimeInterval, reading: FoxPointerReading) -> Bool {
        switch reading {
        case .onFox:
            dwellTime += delta
        case .away:
            dwellTime = max(0, dwellTime - delta * Self.refocusDrainRate)
        case .unavailable:
            break
        }
        guard dwellTime >= settings.refocusDwell else { return false }
        state = .following
        awayTime = 0
        dwellTime = 0
        return true
    }

    private mutating func walk(_ delta: TimeInterval) -> [FoxPathEvent] {
        distance = min(distance + settings.foxSpeed * delta, routeLength)
        followingTime += delta
        isWalking = true
        guard distance >= routeLength else { return [] }
        state = .finished
        isWalking = false
        return [.finished]
    }
}
