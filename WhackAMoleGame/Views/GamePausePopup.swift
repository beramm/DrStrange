import SwiftUI

/// Pause pop-up shared by every game: "Game paused" on a cream panel over the dimmed game, with
/// Home, Restart and Play, and a close button that also carries on playing.
///
/// - Home: end the game and go back to the start of the app.
/// - Restart: a fresh game of the same kind.
/// - Play (or close): carry on where the game stopped.
struct GamePausePopup: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onHome: () -> Void

    /// Set by the first button tap, so repeated taps cannot act twice.
    @State private var hasChosen = false

    /// The layout was drawn on a 1366 × 1024 point screen (iPad Pro 12.9" in landscape).
    private static let design = CGSize(width: 1366, height: 1024)
    /// `SettingsCard` is 1933 × 1405 pixels.
    private static let panelAspect: CGFloat = 1933 / 1405
    private static let ink = Color(red: 0.24, green: 0.13, blue: 0.06)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let s = min(size.width / Self.design.width, size.height / Self.design.height)
            let panel = CGSize(width: 720 * s, height: 720 * s / Self.panelAspect)
            let button = 134 * s

            ZStack {
                Color.black.opacity(0.4)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
                ZStack {
                    Image("SettingsCard")
                        .resizable()
                        .accessibilityHidden(true)
                    VStack(spacing: 56 * s) {
                        Text("Game paused")
                            .textCase(.uppercase)
                            .font(.custom("DoodleChalkDemoRegular", size: 76 * s))
                            .tracking(76 * s * 0.025)
                            .foregroundStyle(Self.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .accessibilityAddTraits(.isHeader)
                        HStack(spacing: 64 * s) {
                            roundButton("FinishScreen/ButtonHome", label: "Home", width: button, action: onHome)
                            roundButton("FinishScreen/ButtonRestart", label: "Restart", width: button, action: onRestart)
                            roundButton("FinishScreen/ButtonPlay", label: "Play", width: button, action: onResume)
                        }
                    }
                    .offset(y: -8 * s)
                }
                .frame(width: panel.width, height: panel.height)
                .overlay(alignment: .topTrailing) {
                    roundButton("FinishScreen/ButtonClose", label: "Close", width: 54 * s, action: onResume)
                        .padding(.top, 34 * s)
                        .padding(.trailing, 40 * s)
                }
                .shadow(color: .black.opacity(0.18), radius: 18 * s, y: 10 * s)
                .position(x: size.width / 2, y: size.height / 2)
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
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
        .buttonStyle(PausePopupButtonStyle())
        .disabled(hasChosen)
        .frame(minWidth: 64, minHeight: 64)
        .accessibilityLabel(label)
    }
}

/// Shrinks a round painted button a little while it is held down.
private struct PausePopupButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview(traits: .landscapeLeft) {
    ZStack {
        Color.green
        GamePausePopup(onResume: {}, onRestart: {}, onHome: {})
    }
}
