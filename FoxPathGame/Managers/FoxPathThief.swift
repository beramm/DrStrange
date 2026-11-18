import CoreGraphics
import Foundation

/// Whether the child is following the character, as far as the game can tell.
enum PlayerAttentionState: Equatable {
    case following
    /// The pointer has been off the character for longer than the look-away grace.
    case notFollowing
    /// No usable gaze reading (camera starting, face lost, poor light). Never counted as
    /// not following: no mole comes and a mole that is around holds still.
    case trackingUnavailable
}

/// What the mole is doing. The thief is always a mole: it comes up out of a hole under the
/// vegetable basket on the followed character's back, takes one carrot and goes back down.
enum ThiefState: Equatable {
    case inactive
    /// The hole opens in the ground under the basket.
    case openingHole
    /// The mole comes up out of the hole.
    case emerging
    /// The mole reaches up to the basket. At the end it has the carrot.
    case reaching
    /// The mole goes back down the hole, with the carrot if it got one.
    case sinking
    /// The hole closes again.
    case closingHole
}

enum ThiefEvent: Equatable {
    /// The mole took a carrot from the basket: one heart is lost. Sent at most once per mole.
    case stoleCarrot
    /// The mole is underground again and its hole has closed.
    case left
}

/// One mole visit, driven by the game clock and the child's attention. It has no knowledge of
/// how attention is measured, so the same rules work with gaze, a finger or a test.
///
/// The hole stays where it opened: the followed character is standing still there (the mole only
/// comes while the child is not following), and if the child looks back the character walks on
/// while the mole goes back down the same hole.
struct FoxPathThief: Equatable {
    /// Where the hole opens on the map: on the ground under the basket.
    let hole: CGPoint
    let settings: ThiefSettings

    private(set) var state: ThiefState = .openingHole
    /// Seconds since the mole's hole started to open.
    private(set) var age: TimeInterval = 0
    /// Seconds spent in the current state.
    private(set) var stateTime: TimeInterval = 0
    /// `true` once the mole has the carrot (and the heart is lost).
    private(set) var hasStolen = false
    /// `true` when the child looked back before the carrot was taken.
    private(set) var wasChasedOff = false
    /// How far out of the hole the mole was when it started to go back down.
    private var sinkFrom: Double = 1

    init(hole: CGPoint, settings: ThiefSettings) {
        self.hole = hole
        self.settings = settings
    }

    /// 0 inside the hole, 1 all the way up.
    var rise: Double {
        switch state {
        case .inactive, .openingHole, .closingHole:
            0
        case .emerging:
            fraction(of: settings.emergeDuration)
        case .reaching:
            1
        case .sinking:
            max(sinkFrom - stateTime / max(settings.sinkDuration, 0.01), 0)
        }
    }

    /// 0...1 while the mole reaches up to the basket; 1 once it has the carrot.
    var reach: Double {
        switch state {
        case .reaching: fraction(of: settings.reachDuration)
        case .sinking, .closingHole: hasStolen ? 1 : 0
        default: 0
        }
    }

    /// 0...1: how open the hole is.
    var holeOpenness: Double {
        switch state {
        case .inactive: 0
        case .openingHole: fraction(of: settings.holeOpenDuration)
        case .emerging, .reaching, .sinking: 1
        case .closingHole: 1 - fraction(of: settings.holeCloseDuration)
        }
    }

    private func fraction(of duration: TimeInterval) -> Double {
        min(stateTime / max(duration, 0.01), 1)
    }

    mutating func advance(by delta: TimeInterval, attention: PlayerAttentionState) -> [ThiefEvent] {
        guard delta > 0, state != .inactive else { return [] }
        // A missing reading is nobody's fault. Freeze the whole visit until tracking is usable again.
        guard attention != .trackingUnavailable else { return [] }
        // Looking back at the character before the carrot is taken sends the mole away with nothing.
        if attention == .following { chaseAway() }
        age += delta
        stateTime += delta

        switch state {
        case .inactive:
            return []
        case .openingHole:
            if stateTime >= settings.holeOpenDuration { enter(.emerging) }
            return []
        case .emerging:
            if stateTime >= settings.emergeDuration { enter(.reaching) }
            return []
        case .reaching:
            guard stateTime >= settings.reachDuration else { return [] }
            // The carrot is out of the basket: the heart is lost now, once, and the mole goes back
            // down holding it.
            hasStolen = true
            sinkFrom = 1
            enter(.sinking)
            return [.stoleCarrot]
        case .sinking:
            if stateTime >= sinkFrom * settings.sinkDuration { enter(.closingHole) }
            return []
        case .closingHole:
            guard stateTime >= settings.holeCloseDuration else { return [] }
            enter(.inactive)
            return [.left]
        }
    }

    /// The child looked back, or the character reached the stall: a mole that has not taken the
    /// carrot yet goes back down the hole empty-handed. A carrot already taken stays taken.
    mutating func chaseAway() {
        guard !hasStolen else { return }
        switch state {
        case .openingHole:
            wasChasedOff = true
            // Nothing has come up yet: the hole just closes again from where it is.
            let openness = holeOpenness
            enter(.closingHole)
            stateTime = (1 - openness) * settings.holeCloseDuration
        case .emerging, .reaching:
            wasChasedOff = true
            sinkFrom = rise
            enter(.sinking)
        case .inactive, .sinking, .closingHole:
            break
        }
    }

    private mutating func enter(_ newState: ThiefState) {
        state = newState
        stateTime = 0
    }
}

extension FoxWalkPose {
    /// Where the mole's hole opens: on the ground under the vegetable basket the character wears
    /// on its back, so the mole comes up right below it.
    ///
    /// - Side view: the basket is on the back, behind the body, so the hole is behind the feet and
    ///   the mole comes up in front of the tail.
    /// - Back view (walking up the map): the basket faces the player, so the hole is just in front
    ///   of the feet and the mole comes up in front of the legs.
    /// - Front view (walking down the map): the basket is hidden behind the body, so the hole is
    ///   beside and slightly behind the character, where the mole can still be seen.
    var bagHolePoint: CGPoint {
        let width = character.size(facing: facing).width
        switch facing {
        case .side:
            let behind: CGFloat = isMirrored ? 1 : -1
            return CGPoint(x: feet.x + behind * width * 0.32, y: feet.y + 6)
        case .back:
            return CGPoint(x: feet.x, y: feet.y + 22)
        case .front:
            return CGPoint(x: feet.x + width * 0.45, y: feet.y - 12)
        }
    }
}

/// What the map shows of the mole in one frame.
struct MoleThiefVisual: Equatable {
    /// Ground point of the hole, in map units.
    let hole: CGPoint
    /// 0...1: how open the hole is.
    let holeOpenness: Double
    /// 0 inside the hole, 1 all the way up.
    let rise: Double
    /// 0...1 while the mole reaches up to the basket.
    let reach: Double
    /// The mole has the carrot.
    let holdsCarrot: Bool
    /// Which way the basket is from the hole: -1 left, 1 right, 0 straight above.
    let towardBasket: CGFloat

    /// Drawn size of the mole standing, in map units (from the 702 × 1149-pixel picture).
    static let standingSize = CGSize(width: 68.1, height: 110.9)
    /// Drawn size of the mole holding the carrot over its head. That picture was drawn at a smaller
    /// scale, so it is enlarged 1.6× to keep the mole's body the same size.
    static let carrotSize = CGSize(width: 66.8, height: 111.5)
    /// How far the mole comes out of its hole at most, as a share of its height: its feet stay in
    /// the hole.
    static let highestRise: CGFloat = 0.84

    init(thief: FoxPathThief, basketX: CGFloat) {
        hole = thief.hole
        holeOpenness = (thief.holeOpenness * 20).rounded() / 20
        rise = (thief.rise * 40).rounded() / 40
        reach = (thief.reach * 20).rounded() / 20
        holdsCarrot = thief.hasStolen
        let dx = basketX - thief.hole.x
        towardBasket = abs(dx) < 8 ? 0 : (dx < 0 ? -1 : 1)
    }
}
