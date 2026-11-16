import SwiftUI

/// Top bar: exit, time left, hearts, zoom and pause. Icons first, minimal text.
struct FoxPathHUDView: View {
    let viewModel: FoxPathGameViewModel
    let onExit: () -> Void

    private let ink = FoxPathPalette.ink

    var body: some View {
        HStack(spacing: 20) {
            HUDButton(systemImage: "xmark", label: "Exit game", ink: ink, action: onExit)

            CountdownView(seconds: viewModel.remainingSeconds, ink: ink)

            LivesView(lives: viewModel.lives, total: FoxPathConfiguration.initialLives)

            Spacer(minLength: 0)

            HUDButton(systemImage: "minus.magnifyingglass", label: "Zoom out", ink: ink) {
                viewModel.zoomOut()
            }
            .disabled(!viewModel.camera.canZoomOut)
            .opacity(viewModel.camera.canZoomOut ? 1 : 0.5)

            HUDButton(systemImage: "plus.magnifyingglass", label: "Zoom in", ink: ink) {
                viewModel.zoomIn()
            }
            .disabled(!viewModel.camera.canZoomIn)
            .opacity(viewModel.camera.canZoomIn ? 1 : 0.5)

            HUDButton(systemImage: "pause.fill", label: "Pause", ink: ink) {
                viewModel.pause()
            }
            .disabled(viewModel.phase != .playing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

/// Time left in the game as MM:SS.
private struct CountdownView: View {
    let seconds: Int
    let ink: Color

    var body: some View {
        Label {
            Text(Self.format(seconds))
                .font(.system(.title, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: seconds)
        } icon: {
            Image(systemName: "timer")
                .font(.title2.weight(.bold))
        }
        .foregroundStyle(seconds <= 10 ? FoxPathPalette.danger : ink)
        .padding(.horizontal, 20)
        .frame(height: 60)
        .background(Capsule().fill(.white.opacity(0.75)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time left")
        .accessibilityValue("\(seconds / 60) minutes \(seconds % 60) seconds")
    }

    static func format(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

/// One heart per life. A lost heart turns into an outline with a short, gentle shrink.
private struct LivesView: View {
    let lives: Int
    let total: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                let isFull = index < lives
                Image(systemName: isFull ? "heart.fill" : "heart")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(isFull ? FoxPathPalette.heart : FoxPathPalette.heart.opacity(0.45))
                    .scaleEffect(isFull ? 1 : 0.85)
                    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6), value: isFull)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 60)
        .background(Capsule().fill(.white.opacity(0.75)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hearts")
        .accessibilityValue("\(lives) of \(total)")
    }
}
