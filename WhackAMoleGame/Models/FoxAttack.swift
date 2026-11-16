import Foundation

/// How long each part of the fox's attack takes, in seconds of game time (pauses excluded).
/// All values are `.gameDesign`.
struct FoxAttackTiming: Codable, Equatable {
    /// The fox's yellow card grows open beside the tapped character (square reveal with a ripple),
    /// while the fox fades out of its corner. No fox in the card yet.
    var frameAppear: TimeInterval = 0.34
    /// The fox rises up from the bottom of the card.
    var emerge: TimeInterval = 0.36
    /// The fox leans in and swings its hammer; this phase ends at the moment of impact.
    var swing: TimeInterval = 0.36
    /// The mole reacts to the hit (squash, wobble, dizzy stars) before going back down its hole.
    var hitReaction: TimeInterval = 0.45
    /// The fox lowers its hammer, settles back onto the card and sinks down out of its bottom.
    var retract: TimeInterval = 0.36
    /// The empty card shrinks away; the fox reappears in its corner.
    var frameDisappear: TimeInterval = 0.28
    /// Pause after the sequence before the next character may appear.
    var nextTargetDelay: TimeInterval = 0.3

    var impactOffset: TimeInterval { frameAppear + emerge + swing }
    var total: TimeInterval { frameAppear + emerge + swing + hitReaction + retract + frameDisappear }
}

/// The fox's animation states, in the order they always run.
enum FoxAttackPhase: Equatable, CaseIterable {
    case frameAppearing
    case foxEmerging
    case attacking
    case hitting
    case foxRetracting
    case frameDisappearing
}

/// One attack on the character the child tapped. Only one can run at a time.
struct FoxAttack: Equatable {
    let targetID: Int
    let holeIndex: Int
    var artIndex = 0
    let startedAt: TimeInterval

    /// Phase and progress (0...1) within it, or `nil` once the attack is over.
    func state(at clock: TimeInterval, timing: FoxAttackTiming) -> (phase: FoxAttackPhase, progress: Double)? {
        let elapsed = clock - startedAt
        let phases: [(FoxAttackPhase, TimeInterval)] = [
            (.frameAppearing, timing.frameAppear),
            (.foxEmerging, timing.emerge),
            (.attacking, timing.swing),
            (.hitting, timing.hitReaction),
            (.foxRetracting, timing.retract),
            (.frameDisappearing, timing.frameDisappear),
        ]
        var start: TimeInterval = 0
        for (phase, duration) in phases {
            if elapsed < start + duration {
                return (phase, duration > 0 ? max(elapsed - start, 0) / duration : 1)
            }
            start += duration
        }
        return nil
    }
}

/// What the game is doing right now, as one value for the UI and tests.
enum GameInteractionState: Equatable {
    case idle
    case targetAppearing
    case targetActive
    case frameAppearing
    case foxEmerging
    case foxAttacking
    case targetHit
    case foxRetracting
    case frameDisappearing
    case nextTarget
}

/// The fox on its own, for the views: idle in its corner, or one of the attack phases.
enum FoxAnimationState: Equatable {
    case idle
    case frameAppearing
    case foxEmerging
    case attacking
    case targetHit
    case foxRetracting
    case frameDisappearing

    init(_ pose: FoxPose?) {
        switch pose?.phase {
        case nil: self = .idle
        case .frameAppearing: self = .frameAppearing
        case .foxEmerging: self = .foxEmerging
        case .attacking: self = .attacking
        case .hitting: self = .targetHit
        case .foxRetracting: self = .foxRetracting
        case .frameDisappearing: self = .frameDisappearing
        }
    }
}

/// Where the fox is in its attack, for drawing. `nil` in the view model means it is home.
struct FoxPose: Equatable {
    let phase: FoxAttackPhase
    /// 0...1 within `phase`.
    let progress: Double
    /// Hole of the character being attacked.
    let holeIndex: Int
    /// Which hole image it is, for placing the hammer on the mole.
    var artIndex = 0
}
