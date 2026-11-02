import SwiftUI

/// Named positions on screen that the fox needs: its window and every hole.
enum FoxAnchorID: Hashable {
    case window
    case hole(Int)
}

struct FoxAnchorKey: PreferenceKey {
    static let defaultValue: [FoxAnchorID: Anchor<CGRect>] = [:]

    static func reduce(value: inout [FoxAnchorID: Anchor<CGRect>], nextValue: () -> [FoxAnchorID: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Draws the fox on top of the board: waiting in its window, or flying to the tapped character,
/// swinging so the hammer head lands on the character's head, and flying back.
///
/// Position, size and animation frame are computed from the engine's attack progress (game
/// time), so the impact frame lines up with the character's hit reaction and pausing freezes
/// the fox exactly. It never receives touches.
struct AttackAnimationView: View {
    let pose: FoxPose?
    let targetScale: Double
    let anchors: [FoxAnchorID: Anchor<CGRect>]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            if let windowAnchor = anchors[.window] {
                let window = proxy[windowAnchor]
                let target = pose.flatMap { anchors[.hole($0.holeIndex)] }.map { proxy[$0] }
                let placement = Self.placement(for: pose, window: window, hole: target, targetScale: targetScale, reduceMotion: reduceMotion)

                FoxCharacterView(frame: FoxCharacterView.frame(for: pose), mirrored: placement.mirrored)
                    .frame(width: placement.size, height: placement.size)
                    .position(placement.center)

                FoxWindowSill()
                    .frame(width: window.width * 0.9, height: window.height * 0.24)
                    .position(x: window.midX, y: window.maxY - window.height * 0.14)
            }
        }
        .allowsHitTesting(false)
    }

    struct Placement: Equatable {
        var center: CGPoint
        var size: CGFloat
        var mirrored: Bool
    }

    /// Pure layout maths, kept static so it is easy to reason about and test.
    static func placement(for pose: FoxPose?, window: CGRect, hole: CGRect?, targetScale: Double, reduceMotion: Bool) -> Placement {
        // Home: card centred in the window and sunk a little so the sill hides its bottom.
        let homeSize = window.width * 0.95
        let home = CGPoint(
            x: window.midX - (FoxCharacterView.cardCenter.x - 0.5) * homeSize,
            y: window.midY - (FoxCharacterView.cardCenter.y - 0.5) * homeSize + window.height * 0.02
        )
        let homePlacement = Placement(center: home, size: homeSize, mirrored: false)
        guard let pose, let hole, !reduceMotion else { return homePlacement }

        // Strike: hammer head on the character's head.
        let character = MoleHoleView.characterRect(in: hole.size, targetScale: targetScale)
            .offsetBy(dx: hole.minX, dy: hole.minY)
        let head = CGPoint(x: character.midX, y: character.minY + character.height * 0.35)
        // Fox stands on the side with more room: left of characters in the right-hand column.
        let mirrored = pose.holeIndex % SpawnManager.gridColumns == SpawnManager.gridColumns - 1
        let strikeSize = max(character.height * 1.1, homeSize)
        let impactX = mirrored ? 1 - FoxCharacterView.impactPoint.x : FoxCharacterView.impactPoint.x
        let strike = CGPoint(
            x: head.x + (0.5 - impactX) * strikeSize,
            y: head.y + (0.5 - FoxCharacterView.impactPoint.y) * strikeSize
        )
        let raised = CGPoint(x: home.x, y: home.y - window.height * 0.4)
        let raisedSize = homeSize * 1.05

        let t = pose.progress
        switch pose.phase {
        case .emerging:
            return Placement(center: lerp(home, raised, easeOut(t)), size: lerp(homeSize, raisedSize, t), mirrored: mirrored)
        case .attacking:
            return Placement(center: lerp(raised, strike, easeInOut(t)), size: lerp(raisedSize, strikeSize, easeInOut(t)), mirrored: mirrored)
        case .hitting:
            // Small recoil after the hit.
            let lift = sin(.pi * t) * strikeSize * 0.04
            return Placement(center: CGPoint(x: strike.x, y: strike.y - lift), size: strikeSize, mirrored: mirrored)
        case .returning:
            return Placement(center: lerp(strike, home, easeInOut(t)), size: lerp(strikeSize, homeSize, easeInOut(t)), mirrored: mirrored)
        }
    }

    private static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat { a + (b - a) * t }
    private static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t))
    }
    private static func easeOut(_ t: Double) -> Double { 1 - (1 - t) * (1 - t) }
    private static func easeInOut(_ t: Double) -> Double { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }
}
