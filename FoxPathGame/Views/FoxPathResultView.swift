import SwiftUI

/// Finish screen shown when a Veggie Dash game ends with carrots left: a cream sign hanging on two vines, three gold
/// stars on its top edge with light shining from behind them, a "Great job" ribbon, the carrots left
/// under "Life Remaining", and three round buttons to play again, go on to another game or go home.
struct FoxPathResultView: View {
    /// Carrots (lives) left at the end, 0…`FoxPathConfiguration.initialLives`.
    let livesLeft: Int
    let onRestart: () -> Void
    /// Goes on to another game. Nil where there is no other game to go to (the standalone app),
    /// which hides the button.
    let onNext: (() -> Void)?
    let onHome: () -> Void

    /// Set by the first button tap, so repeated taps cannot start two navigations.
    @State private var hasChosen = false

    /// The layout was drawn on a 1366 × 1024 point screen (iPad Pro 12.9" in landscape).
    private static let design = CGSize(width: 1366, height: 1024)
    /// `SettingsCard` is 1933 × 1405 pixels; `LobbyRope` is 748 × 737; the carrots are 400 × 123.
    private static let panelAspect: CGFloat = 1933 / 1405
    private static let ropeAspect: CGFloat = 748 / 737
    private static let carrotsAspect: CGFloat = 400 / 123
    private static let sky = Color(red: 0.90, green: 0.96, blue: 0.99)
    private static let ink = Color(red: 0.24, green: 0.13, blue: 0.06)
    private static let ribbonText = Color(red: 0.99, green: 0.96, blue: 0.90)

    /// Lives shown, kept within the painted carrot states.
    private var lives: Int { Self.clampedLives(livesLeft) }

    static func clampedLives(_ livesLeft: Int) -> Int {
        min(max(livesLeft, 0), FoxPathConfiguration.initialLives)
    }

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
                FoxPathFinishShine(scale: s)
                    .position(at(0, -337))
                // The right vine ends higher in the picture (674 of 737 pixels) than the left one
                // (728), so the vines are lowered until both ends are tucked behind the panel.
                Image("LobbyRope")
                    .resizable()
                    .frame(width: 760 * s, height: 760 * s / Self.ropeAspect)
                    .position(x: c.x, y: c.y - panel.height / 2 + 20 * s - 760 * s / Self.ropeAspect * (674 / 737 - 0.5))
                    .accessibilityHidden(true)
                Image("SettingsCard")
                    .resizable()
                    .frame(width: panel.width, height: panel.height)
                    .shadow(color: .black.opacity(0.12), radius: 14 * s, y: 8 * s)
                    .position(c)
                    .accessibilityHidden(true)

                star(width: 150 * s).position(at(-197, -311))
                star(width: 150 * s).position(at(197, -311))
                star(width: 200 * s).position(at(0, -337))

                ribbon(scale: s)
                    .position(at(0, -137))
                Text("Life Remaining")
                    .font(.custom("DaysOne-Regular", size: 38 * s))
                    .foregroundStyle(Self.ink)
                    .position(at(0, -38))
                Image("FoxPath/Carrots\(lives)")
                    .resizable()
                    .frame(width: 327 * s, height: 327 * s / Self.carrotsAspect)
                    .position(at(0, 60))
                    .accessibilityLabel("\(lives) of \(FoxPathConfiguration.initialLives) carrots left")

                buttons(scale: s)
                    .position(at(0, 205))
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }

    // MARK: - Stars, shine and ribbon

    /// The stars stay gold whatever the result.
    private func star(width: CGFloat) -> some View {
        Image("FinishScreen/Star")
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .accessibilityHidden(true)
    }

    private func ribbon(scale s: CGFloat) -> some View {
        let width = 570 * s
        return Image("FinishScreen/Ribbon")
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .overlay {
                Text("Great job")
                    .textCase(.uppercase)
                    .font(.custom("DoodleChalkDemoRegular", size: 56 * s))
                    .tracking(56 * s * 0.025)
                    .foregroundStyle(Self.ribbonText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: width * 0.7)
                    // The flat middle of the band sits a little above the picture's centre.
                    .offset(y: -width * 0.035)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Great job")
            .accessibilityAddTraits(.isHeader)
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
        .buttonStyle(RoundArtButtonStyle())
        .disabled(hasChosen)
        // Small buttons still get a 64-point square to tap.
        .frame(minWidth: 64, minHeight: 64, alignment: .bottom)
        .accessibilityLabel(label)
    }
}

/// Game Over screen shown when the last carrot is gone: the same cream sign on two vines with the
/// sunlight behind it, a red "Game over" ribbon, "Let's Try Again!", and buttons to play again or go
/// home. There is no "Next" here: the child tries this game again or leaves.
struct FoxPathGameOverView: View {
    let onRestart: () -> Void
    let onHome: () -> Void

    /// Set by the first button tap, so repeated taps cannot start two navigations.
    @State private var hasChosen = false

    /// The layout was drawn on a 1366 × 1024 point screen (iPad Pro 12.9" in landscape).
    private static let design = CGSize(width: 1366, height: 1024)
    private static let panelAspect: CGFloat = 1933 / 1405
    private static let ropeAspect: CGFloat = 748 / 737
    private static let sky = Color(red: 0.90, green: 0.96, blue: 0.99)
    private static let ink = Color(red: 0.24, green: 0.13, blue: 0.06)
    private static let ribbonText = Color(red: 0.99, green: 0.96, blue: 0.90)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let s = min(size.width / Self.design.width, size.height / Self.design.height)
            let panel = CGSize(width: 892 * s, height: 892 * s / Self.panelAspect)
            let c = CGPoint(x: size.width / 2, y: size.height / 2 + 25 * s)
            let at = { (dx: CGFloat, dy: CGFloat) in CGPoint(x: c.x + dx * s, y: c.y + dy * s) }

            ZStack {
                Self.sky
                FoxPathFinishShine(scale: s)
                    .position(at(0, -415))
                // Same vines as the finish screen, ends tucked behind the panel.
                Image("LobbyRope")
                    .resizable()
                    .frame(width: 760 * s, height: 760 * s / Self.ropeAspect)
                    .position(x: c.x, y: c.y - panel.height / 2 + 20 * s - 760 * s / Self.ropeAspect * (674 / 737 - 0.5))
                    .accessibilityHidden(true)
                Image("SettingsCard")
                    .resizable()
                    .frame(width: panel.width, height: panel.height)
                    .shadow(color: .black.opacity(0.12), radius: 14 * s, y: 8 * s)
                    .position(c)
                    .accessibilityHidden(true)

                ribbon(scale: s)
                    .position(at(0, -284))
                Text("Let\u{2019}s Try Again!")
                    .font(.custom("DaysOne-Regular", size: 58 * s))
                    .foregroundStyle(Self.ink)
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 3 * s)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: panel.width * 0.85)
                    .position(at(0, -42))

                HStack(alignment: .center, spacing: 85 * s) {
                    roundButton("FinishScreen/ButtonRestart", label: "Restart", width: 124 * s, action: onRestart)
                    roundButton("FinishScreen/ButtonHome", label: "Home", width: 128 * s, action: onHome)
                }
                .position(at(0, 190))
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }

    private func ribbon(scale s: CGFloat) -> some View {
        let width = 955 * s
        return Image("FoxPath/GameOver/Ribbon")
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .overlay {
                Text("Game over")
                    .textCase(.uppercase)
                    .font(.custom("DoodleChalkDemoRegular", size: 84 * s))
                    .tracking(84 * s * 0.16)
                    .foregroundStyle(Self.ribbonText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: width * 0.7)
                    .offset(y: -width * 0.035)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Game over")
            .accessibilityAddTraits(.isHeader)
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
        .buttonStyle(RoundArtButtonStyle())
        .disabled(hasChosen)
        .frame(minWidth: 64, minHeight: 64)
        .accessibilityLabel(label)
    }
}

/// Soft rays turning slowly behind the top of the sign, over a warm glow that gently breathes.
private struct FoxPathFinishShine: View {
    let scale: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let sunlight = Color(red: 1.0, green: 0.86, blue: 0.35)

    var body: some View {
        let s = scale
        let radius = 470 * s
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let breath = 1 + 0.06 * sin(time * 2.2)
            ZStack {
                FinishSunRays(count: 14)
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
}

/// Rays fanning out from the centre, like light behind the stars.
private struct FinishSunRays: Shape {
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

/// Shrinks a round painted button a little while it is held down.
private struct RoundArtButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview(traits: .landscapeLeft) {
    FoxPathResultView(livesLeft: 2, onRestart: {}, onNext: {}, onHome: {})
}

#Preview("Game over", traits: .landscapeLeft) {
    FoxPathGameOverView(onRestart: {}, onHome: {})
}
