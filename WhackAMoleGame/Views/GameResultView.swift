import SwiftUI

/// Finish screen shown when a Whack-a-Mole game ends: a cream sign hanging on two vines with
/// sunlight shining from behind it, a wide green "Great job" ribbon, the final score with the
/// Whack-a-Mole high score, and three round buttons to play again, go on to another game or go
/// home.
///
/// The session itself is still saved for caregivers by the game; this screen only shows the score.
struct GameResultView: View {
    /// Final score of this game, from `WhackAMoleGameViewModel.score`.
    let score: Int
    /// Best Whack-a-Mole score on this device before this game.
    let previousHighScore: Int
    /// `true` when this game set a new high score.
    let isNewHighScore: Bool
    let onRestart: () -> Void
    /// Goes on to another game. Nil where there is no other game to go to (the standalone app),
    /// which hides the button.
    let onNext: (() -> Void)?
    let onHome: () -> Void

    /// Set by the first button tap, so repeated taps cannot start two navigations.
    @State private var hasChosen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The layout was drawn on a 1366 × 1024 point screen (iPad Pro 12.9" in landscape).
    private static let design = CGSize(width: 1366, height: 1024)
    /// `SettingsCard` is 1933 × 1405 pixels; `LobbyRope` is 748 × 737.
    private static let panelAspect: CGFloat = 1933 / 1405
    private static let ropeAspect: CGFloat = 748 / 737
    private static let sky = Color(red: 0.90, green: 0.96, blue: 0.99)
    private static let ink = Color(red: 0.24, green: 0.13, blue: 0.06)
    private static let ribbonText = Color(red: 0.99, green: 0.96, blue: 0.90)
    private static let sunlight = Color(red: 1.0, green: 0.86, blue: 0.35)

    /// High score to show: the saved best including this game.
    static func highScore(previous: Int, score: Int) -> Int { max(previous, score) }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let s = min(size.width / Self.design.width, size.height / Self.design.height)
            let panel = CGSize(width: 892 * s, height: 892 * s / Self.panelAspect)
            // Points on the panel are given from its centre, as measured on the design.
            let c = CGPoint(x: size.width / 2, y: size.height / 2 + 25 * s)
            let at = { (dx: CGFloat, dy: CGFloat) in CGPoint(x: c.x + dx * s, y: c.y + dy * s) }

            ZStack {
                Self.sky
                // Same sunlight as the Veggie Dash finish screen: its glow peeks over the ribbon.
                shine(scale: s)
                    .position(at(0, -370))
                // The right vine ends higher in the picture (674 of 737 pixels) than the left one
                // (728), so the vines are lowered until both ends are tucked behind the panel.
                ropes(scale: s)
                    .position(x: c.x, y: c.y - panel.height / 2 + 20 * s - 760 * s / Self.ropeAspect * (674 / 737 - 0.5))
                Image("SettingsCard")
                    .resizable()
                    .frame(width: panel.width, height: panel.height)
                    .shadow(color: .black.opacity(0.12), radius: 14 * s, y: 8 * s)
                    .position(c)
                    .accessibilityHidden(true)

                ribbon(scale: s)
                    .position(at(0, -297))
                Text("Your Score")
                    .font(.custom("DaysOne-Regular", size: 54 * s))
                    .foregroundStyle(Self.ink)
                    .shadow(color: Self.ink.opacity(0.25), radius: 0, x: 0, y: 3 * s)
                    .position(at(0, -157))
                Text("\(score)")
                    .font(.custom("DaysOne-Regular", size: 118 * s))
                    .monospacedDigit()
                    .foregroundStyle(Self.ink)
                    .shadow(color: Self.ink.opacity(0.25), radius: 0, x: 0, y: 3 * s)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: panel.width * 0.8)
                    .position(at(0, -62))
                    .accessibilityLabel("Your score \(score)")
                highScoreLine(scale: s)
                    .position(at(0, 83))

                buttons(scale: s)
                    .position(at(0, 205))
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }

    // MARK: - Shine, ropes and ribbon

    /// Soft rays turning slowly behind the top of the sign, over a warm glow that gently breathes.
    private func shine(scale s: CGFloat) -> some View {
        let radius = 470 * s
        return TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let breath = 1 + 0.06 * sin(time * 2.2)
            ZStack {
                SunRays(count: 14)
                    .fill(
                        RadialGradient(
                            colors: [Self.sunlight.opacity(0.45), Self.sunlight.opacity(0.18), .clear],
                            center: .center,
                            startRadius: 40 * s,
                            endRadius: radius
                        )
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .rotationEffect(.degrees(time.truncatingRemainder(dividingBy: 360) * 8))
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Self.sunlight.opacity(0.95), Self.sunlight.opacity(0.45), .clear],
                            center: .center,
                            startRadius: 10 * s,
                            endRadius: 190 * s
                        )
                    )
                    .frame(width: 380 * s, height: 380 * s)
                    .scaleEffect(breath)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The two vines from the lobby sign, hanging from above the screen down behind the panel.
    private func ropes(scale s: CGFloat) -> some View {
        Image("LobbyRope")
            .resizable()
            .frame(width: 760 * s, height: 760 * s / Self.ropeAspect)
            .accessibilityHidden(true)
    }

    private func ribbon(scale s: CGFloat) -> some View {
        let width = 950 * s
        return Image("FinishScreen/Ribbon")
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .overlay {
                Text("Great job")
                    .textCase(.uppercase)
                    .font(.custom("DoodleChalkDemoRegular", size: 92 * s))
                    .tracking(92 * s * 0.2)
                    .foregroundStyle(Self.ribbonText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: width * 0.75)
                    // The flat middle of the band sits a little above the picture's centre.
                    .offset(y: -width * 0.035)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Great job")
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - High score

    @ViewBuilder
    private func highScoreLine(scale s: CGFloat) -> some View {
        let best = Self.highScore(previous: previousHighScore, score: score)
        HStack(spacing: 8 * s) {
            if isNewHighScore {
                Image("FinishScreen/Star")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32 * s)
                    .accessibilityHidden(true)
                Text("New High Score: \(best)")
            } else {
                Text("High Score: \(best)")
            }
        }
        .font(.custom("DaysOne-Regular", size: 30 * s))
        .foregroundStyle(Self.ink.opacity(isNewHighScore ? 0.9 : 0.6))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Buttons

    private func buttons(scale s: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 18 * s) {
            roundButton("FinishScreen/ButtonRestart", label: "Restart", width: 86 * s, action: onRestart)
            if let onNext {
                roundButton("FinishScreen/ButtonNext", label: "Next game", width: 124 * s, action: onNext)
            }
            roundButton("FinishScreen/ButtonHome", label: "Home", width: 86 * s, action: onHome)
        }
    }

    private func roundButton(_ asset: String, label: String, width: CGFloat, action: @escaping () -> Void) -> some View {
        Button {
            guard !hasChosen else { return }
            hasChosen = true
            action()
        } label: {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: width)
                .contentShape(Circle())
        }
        .buttonStyle(FinishButtonStyle())
        .disabled(hasChosen)
        // Small buttons still get a 64-point square to tap.
        .frame(minWidth: 64, minHeight: 64, alignment: .bottom)
        .accessibilityLabel(label)
    }
}

/// Rays fanning out from the centre, like light behind the sign.
private struct SunRays: Shape {
    let count: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let step = 2 * Double.pi / Double(count)
        let halfWidth = step * 0.28
        for index in 0..<count {
            let angle = Double(index) * step
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + radius * cos(angle - halfWidth), y: center.y + radius * sin(angle - halfWidth)))
            path.addLine(to: CGPoint(x: center.x + radius * cos(angle + halfWidth), y: center.y + radius * sin(angle + halfWidth)))
            path.closeSubpath()
        }
        return path
    }
}

/// Shrinks the round button a little while it is held down.
private struct FinishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview(traits: .landscapeLeft) {
    GameResultView(score: 100, previousHighScore: 120, isNewHighScore: false, onRestart: {}, onNext: {}, onHome: {})
}
