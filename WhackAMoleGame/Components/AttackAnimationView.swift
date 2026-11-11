import SwiftUI

/// Named positions on screen that the fox needs: its corner and every hole.
enum FoxAnchorID: Hashable {
    case home
    case hole(Int)
}

struct FoxAnchorKey: PreferenceKey {
    static let defaultValue: [FoxAnchorID: Anchor<CGRect>] = [:]

    static func reduce(value: inout [FoxAnchorID: Anchor<CGRect>], nextValue: () -> [FoxAnchorID: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Fixed spot in the bottom corner where the fox waits. Invisible; it only reports its position.
struct FoxHomeAnchor: View {
    var body: some View {
        Color.clear
            .anchorPreference(key: FoxAnchorKey.self, value: .bounds) { [.home: $0] }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Draws the fox on top of the board and runs its attack, always in this order:
///
/// 1. idle: fox in the bottom corner, no card
/// 2. frame appearing: the fox's yellow card opens beside the tapped character: it grows from its
///    centre as a rounded square with a slight spring and a square ring ripples out; the corner fox
///    fades away
/// 3. fox emerging: the fox rises up from the bottom of the card, its hammer still hidden
/// 4. attacking: the fox leans in and swings, the hammer sliding out from behind the card; it lands
///    on the mole's helmet at the end
/// 5. target hit: the character reacts; the fox holds the pose
/// 6. fox retracting: the hammer slides back behind the card, then the fox sinks down out of its
///    bottom
/// 7. frame disappearing: the empty card shrinks away; the fox reappears in its corner
///
/// Every value is computed from the engine's attack progress (game time) each frame, so each step
/// starts exactly when the previous one ends, the impact frame lines up with the character's
/// reaction, and pausing freezes everything. It never receives touches.
struct AttackAnimationView: View {
    let pose: FoxPose?
    let anchors: [FoxAnchorID: Anchor<CGRect>]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            if let homeAnchor = anchors[.home] {
                let home = proxy[homeAnchor]
                let hole = pose.flatMap { anchors[.hole($0.holeIndex)] }.map { proxy[$0] }
                let scene = Self.scene(for: pose, home: home, hole: hole, reduceMotion: reduceMotion)

                if let corner = scene.cornerFox {
                    fox(corner, frame: 1)
                }
                // The card sits behind the fox; the fox's own card covers it exactly.
                if let card = scene.card {
                    FoxWindowView(reveal: card.reveal, ring: card.ring)
                        .frame(width: card.rect.width, height: card.rect.height)
                        .scaleEffect(card.scale)
                        .position(x: card.rect.midX, y: card.rect.midY)
                }
                // While rising or sinking, only the inside of the fox's card is drawn, clipped to the
                // inside of the drawn card, so the fox appears to come up from the card's bottom edge.
                if let rising = scene.risingFox, let card = scene.card {
                    let inner = Self.interior(of: card.rect)
                    FoxCharacterView(frame: FoxCharacterView.frame(for: pose), mirrored: rising.mirrored, visibility: .cardInterior)
                        .frame(width: rising.size, height: rising.size)
                        .position(rising.center)
                        .mask {
                            Rectangle()
                                .frame(width: inner.width, height: inner.height)
                                .position(x: inner.midX, y: inner.midY)
                        }
                }
                fox(scene.fox, frame: FoxCharacterView.frame(for: pose))
            }
        }
        .allowsHitTesting(false)
    }

    private func fox(_ placement: FoxPlacement, frame: Int) -> some View {
        FoxCharacterView(frame: frame, mirrored: placement.mirrored, visibility: .cardAndHammer(placement.hammerReveal))
            .frame(width: placement.size, height: placement.size)
            .position(placement.center)
            .opacity(placement.opacity)
    }

    // MARK: - Layout maths (static, so it is easy to test)

    struct FoxPlacement: Equatable {
        var center: CGPoint
        var size: CGFloat
        var mirrored = false
        var opacity: Double = 1
        /// How far the hammer has come out from behind the card, 0...1.
        var hammerReveal: Double = 1
    }

    struct CardPlacement: Equatable {
        var rect: CGRect
        var scale: CGFloat = 1
        /// Square reveal (the card's own scale), 0...1, overshooting slightly while it opens.
        var reveal: Double = 1
        /// Ripple ring progress while opening.
        var ring: Double?
    }

    struct Scene: Equatable {
        /// The fox doing the attack (or waiting in its corner when idle).
        var fox: FoxPlacement
        /// The yellow card beside the character.
        var card: CardPlacement?
        /// The corner fox while it fades out (card opening) or back in (card closing).
        var cornerFox: FoxPlacement?
        /// The fox rising up from (or sinking into) the bottom of the card, clipped to its inside.
        var risingFox: FoxPlacement?
    }

    /// Inside of the drawn card's border.
    static func interior(of card: CGRect) -> CGRect {
        let inset = card.width * FoxWindowView.borderRatio
        return card.insetBy(dx: inset, dy: inset)
    }

    /// Fox waiting in the bottom corner: card centred on the home spot.
    static func homePlacement(in home: CGRect) -> FoxPlacement {
        let size = home.width * 0.95
        return FoxPlacement(
            center: CGPoint(
                x: home.midX - (FoxCharacterView.cardCenter.x - 0.5) * size,
                y: home.midY - (FoxCharacterView.cardCenter.y - 0.5) * size
            ),
            size: size
        )
    }

    /// Key positions for an attack on the character in `hole`.
    struct AttackGeometry: Equatable {
        /// Fox at impact: hammer head on the character's head.
        var strike: FoxPlacement
        /// Fox sitting on its card, leaning back before the swing.
        var emerged: FoxPlacement
        /// Where the yellow card opens: exactly under the fox's own card at `emerged`.
        var card: CGRect
    }

    static func attackGeometry(holeIndex: Int, artIndex: Int = 0, hole: CGRect, home: CGRect) -> AttackGeometry {
        let character = MoleHoleView.characterRect(artIndex: artIndex, in: hole.size)
            .offsetBy(dx: hole.minX, dy: hole.minY)
        // Hammer lands on the top of the mole's helmet.
        let head = CGPoint(
            x: character.minX + character.width * CharacterView.strikePoint.x,
            y: character.minY + character.height * CharacterView.strikePoint.y
        )
        // The fox stands on the side with more room: left of characters in the right-hand column.
        let mirrored = holeIndex % SpawnManager.gridColumns == SpawnManager.gridColumns - 1
        let size = max(character.height * 1.1, homePlacement(in: home).size)
        let impactX = mirrored ? 1 - FoxCharacterView.impactPoint.x : FoxCharacterView.impactPoint.x
        let strikeCenter = CGPoint(
            x: head.x + (0.5 - impactX) * size,
            y: head.y + (0.5 - FoxCharacterView.impactPoint.y) * size
        )
        // Before the swing the fox leans away from the character, then lunges in.
        let lean = size * 0.08 * (mirrored ? -1 : 1)
        let emergedCenter = CGPoint(x: strikeCenter.x + lean, y: strikeCenter.y)

        let unit = FoxCharacterView.cardRect
        let unitX = mirrored ? 1 - unit.maxX : unit.minX
        let card = CGRect(
            x: emergedCenter.x - size / 2 + unitX * size,
            y: emergedCenter.y - size / 2 + unit.minY * size,
            width: unit.width * size,
            height: unit.height * size
        )
        return AttackGeometry(
            strike: FoxPlacement(center: strikeCenter, size: size, mirrored: mirrored),
            emerged: FoxPlacement(center: emergedCenter, size: size, mirrored: mirrored),
            card: card
        )
    }

    static func scene(for pose: FoxPose?, home: CGRect, hole: CGRect?, reduceMotion: Bool) -> Scene {
        let idle = homePlacement(in: home)
        guard let pose, let hole, !reduceMotion else { return Scene(fox: idle) }

        let geometry = attackGeometry(holeIndex: pose.holeIndex, artIndex: pose.artIndex, hole: hole, home: home)
        let t = pose.progress
        var hidden = geometry.emerged
        hidden.opacity = 0

        switch pose.phase {
        case .frameAppearing:
            // Card opens first; the fox fades out of its corner. Nobody in the card yet.
            var corner = idle
            let fade = min(t / 0.6, 1)
            corner.opacity = 1 - fade
            corner.size *= 1 - 0.2 * fade
            return Scene(
                fox: hidden,
                card: CardPlacement(rect: geometry.card, reveal: easeOutBack(t), ring: t),
                cornerFox: corner
            )
        case .foxEmerging:
            // The fox rises up from the bottom of the card, hammer hidden.
            var rising = geometry.emerged
            rising.center.y += geometry.card.height * (1 - easeOut(t))
            return Scene(fox: hidden, card: CardPlacement(rect: geometry.card), risingFox: rising)
        case .attacking:
            // Lunge in while the swing speeds up; contact at the end. The hammer slides out from
            // behind the card early in the swing. The fox's own card moves with it (it sits exactly
            // on the drawn card at the start), so the drawn card is not shown.
            var fox = lerp(geometry.emerged, geometry.strike, easeIn(t))
            fox.hammerReveal = easeOut(min(t / 0.45, 1))
            return Scene(fox: fox)
        case .hitting:
            // Small recoil after the hit.
            var fox = geometry.strike
            fox.center.y -= sin(.pi * t) * fox.size * 0.04
            return Scene(fox: fox)
        case .foxRetracting:
            // Back onto the card with the hammer sliding behind it, then down out of the card's bottom.
            if t < 0.5 {
                var fox = lerp(geometry.strike, geometry.emerged, easeInOut(t / 0.5))
                fox.hammerReveal = 1 - easeIn(t / 0.5)
                return Scene(fox: fox)
            }
            var rising = geometry.emerged
            rising.center.y += geometry.card.height * easeIn((t - 0.5) / 0.5)
            return Scene(fox: hidden, card: CardPlacement(rect: geometry.card), risingFox: rising)
        case .frameDisappearing:
            // The empty card shrinks away; the fox comes back in its corner.
            var corner = idle
            let back = max(0, (t - 0.4) / 0.6)
            corner.opacity = back
            corner.size *= 0.8 + 0.2 * back
            return Scene(
                fox: hidden,
                card: CardPlacement(rect: geometry.card, reveal: 1 - easeIn(t)),
                cornerFox: corner
            )
        }
    }

    /// Interpolates position and size; opacity is set by the caller.
    private static func lerp(_ a: FoxPlacement, _ b: FoxPlacement, _ t: Double) -> FoxPlacement {
        FoxPlacement(
            center: CGPoint(x: a.center.x + (b.center.x - a.center.x) * t, y: a.center.y + (b.center.y - a.center.y) * t),
            size: a.size + (b.size - a.size) * t,
            mirrored: b.mirrored
        )
    }

    private static func easeIn(_ t: Double) -> Double { t * t }
    private static func easeOut(_ t: Double) -> Double { 1 - (1 - t) * (1 - t) }
    private static func easeInOut(_ t: Double) -> Double { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }
    /// Slight overshoot, like a gentle spring.
    private static func easeOutBack(_ t: Double) -> Double {
        let c1 = 1.2, c3 = c1 + 1
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
    }
}
