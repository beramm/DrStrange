import Foundation

/// How long each part of the fox's attack takes, in seconds of game time (pauses excluded).
/// All values are `.gameDesign`.
struct FoxAttackTiming: Codable, Equatable {
    /// Fox rises out of its window.
    var emerge: TimeInterval = 0.28
    /// Fox travels to the tapped character while swinging the hammer; ends at the moment of impact.
    var swing: TimeInterval = 0.42
    /// Character reacts to the hit, then sinks into its hole.
    var hitReaction: TimeInterval = 0.38
    /// Fox flies back into its window.
    var returnHome: TimeInterval = 0.34
    /// Pause after the fox is home before the next character may appear.
    var nextTargetDelay: TimeInterval = 0.4

    var impactOffset: TimeInterval { emerge + swing }
    var total: TimeInterval { emerge + swing + hitReaction + returnHome }
}

enum FoxAttackPhase: Equatable {
    case emerging
    case attacking
    case hitting
    case returning
}

/// One attack on the character the child tapped. Only one can run at a time.
struct FoxAttack: Equatable {
    let targetID: Int
    let holeIndex: Int
    let startedAt: TimeInterval

    /// Phase and progress (0...1) within it, or `nil` once the attack is over.
    func state(at clock: TimeInterval, timing: FoxAttackTiming) -> (phase: FoxAttackPhase, progress: Double)? {
        let elapsed = clock - startedAt
        let phases: [(FoxAttackPhase, TimeInterval)] = [
            (.emerging, timing.emerge),
            (.attacking, timing.swing),
            (.hitting, timing.hitReaction),
            (.returning, timing.returnHome),
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
    case foxEmerging
    case foxAttacking
    case targetHit
    case foxReturning
    case nextTarget
}

/// Where the fox is in its attack, for drawing. `nil` in the view model means it is home.
struct FoxPose: Equatable {
    let phase: FoxAttackPhase
    /// 0...1 within `phase`.
    let progress: Double
    /// Hole of the character being attacked.
    let holeIndex: Int
}
