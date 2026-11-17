import CoreGraphics
import Foundation

/// Whether the child is following the character, as far as the game can tell.
enum PlayerAttentionState: Equatable {
    case following
    /// The pointer has been off the character for longer than the look-away grace.
    case notFollowing
    /// No usable gaze reading (camera starting, face lost, poor light). Never counted as
    /// not following: no thief comes and a thief that is around holds still.
    case trackingUnavailable
}

enum ThiefState: Equatable {
    case inactive
    /// Coming into view a little way from the character.
    case appearing
    /// Rushes at the character while the child is not following and backs off while the child
    /// follows.
    case approaching
    /// Running away.
    case retreating
}

enum ThiefEvent: Equatable {
    /// The thief got within `ThiefApproach.catchDistance` of the character: one heart is lost.
    /// Sent at most once per thief, which then runs off.
    case caughtCharacter
    /// The thief is out of sight again.
    case left
}

/// How a thief comes at the character. Both points are offsets from the character's feet, so
/// the thief keeps its distance however the character moves, and it always ends up beside it.
struct ThiefApproach: Equatable {
    /// Where the thief comes into view.
    let start: CGVector
    /// Where it is when it reaches the character, `catchDistance` beside it.
    let stand: CGVector

    /// How far from the character the thief comes into view (map units).
    static let startDistance: CGFloat = 430
    /// Distance between the two characters' feet at which the thief has reached the character
    /// and a heart is lost.
    static let catchDistance: CGFloat = 92

    /// Which side the thief comes from: -1 from the left, 1 from the right.
    var side: CGFloat { stand.dx < 0 ? -1 : 1 }

    /// 0 where the thief comes into view, 1 beside the character.
    func offset(at progress: Double) -> CGVector {
        let t = CGFloat(min(max(progress, 0), 1))
        return CGVector(dx: start.dx + (stand.dx - start.dx) * t, dy: start.dy + (stand.dy - start.dy) * t)
    }

    /// A way in from the left or right, a little below the character so the thief walks on
    /// open grass in front of the scenery behind the path. The side with room on the map wins.
    static func make(around feet: CGPoint, mapSize: CGSize, using generator: inout SeededGenerator) -> ThiefApproach {
        let margin: CGFloat = 70
        var side: CGFloat = Bool.random(using: &generator) ? 1 : -1
        if !(margin...(mapSize.width - margin)).contains(feet.x + side * startDistance) { side = -side }
        // The whole body (about 230 units tall) stays on the map where the thief comes into view.
        let lowest = mapSize.height - 12 - feet.y
        let highest = 236 - feet.y
        let drop = min(max(CGFloat.random(in: -20...150, using: &generator), highest), max(lowest, highest))
        return ThiefApproach(
            start: CGVector(dx: side * startDistance, dy: drop),
            stand: CGVector(dx: side * catchDistance, dy: 4)
        )
    }
}

/// One thief visit, driven by the game clock and the child's attention. It has no knowledge of
/// how attention is measured, so the same rules work with gaze, a finger or a test.
struct FoxPathThief: Equatable {
    /// How far along its way the thief walks while coming into view.
    static let lurkProgress = 0.18

    let character: PathCharacter
    let approach: ThiefApproach
    let settings: ThiefSettings

    private(set) var state: ThiefState = .appearing
    /// 0 where the thief comes into view, 1 beside the character.
    private(set) var progress: Double = 0
    /// Seconds since the thief appeared.
    private(set) var age: TimeInterval = 0
    /// Seconds spent in the current state.
    private(set) var stateTime: TimeInterval = 0
    /// Seconds the child has been following without a break while the thief is near.
    private(set) var followingTime: TimeInterval = 0
    /// `true` once the thief has reached the character.
    private(set) var hasCaught = false
    private var retreatFrom: Double = 0

    init(character: PathCharacter, approach: ThiefApproach, settings: ThiefSettings) {
        self.character = character
        self.approach = approach
        self.settings = settings
    }

    /// Where the thief stands, given where the character it is after stands.
    func position(around feet: CGPoint) -> CGPoint {
        let offset = approach.offset(at: progress)
        return CGPoint(x: feet.x + offset.dx, y: feet.y + offset.dy)
    }

    /// 0...1: how far the thief has faded in, or out while it leaves.
    var visibility: Double {
        switch state {
        case .inactive: 0
        case .appearing: min(stateTime / max(settings.appearDuration, 0.01), 1)
        case .approaching: 1
        case .retreating: min((1 - retreatFraction) / 0.3, 1)
        }
    }

    private var retreatFraction: Double {
        min(stateTime / max(settings.retreatDuration, 0.01), 1)
    }

    mutating func advance(by delta: TimeInterval, attention: PlayerAttentionState) -> [ThiefEvent] {
        guard delta > 0, state != .inactive else { return [] }
        // A missing reading is nobody's fault. Freeze the whole visit, including appearance,
        // patience and retreat timers, until tracking is usable again.
        guard attention != .trackingUnavailable else { return [] }
        age += delta
        stateTime += delta

        switch state {
        case .inactive:
            return []
        case .appearing:
            progress = Self.lurkProgress * min(stateTime / max(settings.appearDuration, 0.01), 1)
            if stateTime >= settings.appearDuration { enter(.approaching) }
            return []
        case .approaching:
            let speed = (1 - Self.lurkProgress) / max(settings.approachDuration, 0.01)
            switch attention {
            case .notFollowing:
                followingTime = 0
                progress = min(progress + delta * speed, 1)
            case .following:
                followingTime += delta
                progress = max(progress - delta * speed * settings.backOffRate, Self.lurkProgress)
            case .trackingUnavailable:
                break // Handled before any timers advance.
            }
            if progress >= 1 {
                // Close enough: the heart is lost at once and the thief runs off. There is no
                // stealing animation.
                hasCaught = true
                retreat()
                return [.caughtCharacter]
            }
            // Following again chases the thief off; so does waiting too long.
            if followingTime >= settings.chasedOffAfter || age >= settings.patience { retreat() }
            return []
        case .retreating:
            progress = retreatFrom * (1 - retreatFraction)
            guard retreatFraction >= 1 else { return [] }
            enter(.inactive)
            return [.left]
        }
    }

    /// The character the child follows reached the stall: a thief that has not reached it yet
    /// runs off.
    mutating func chaseAway() {
        guard state == .appearing || state == .approaching else { return }
        retreat()
    }

    private mutating func retreat() {
        retreatFrom = progress
        enter(.retreating)
    }

    private mutating func enter(_ newState: ThiefState) {
        state = newState
        stateTime = 0
    }
}
