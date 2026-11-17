import SwiftUI

/// Top bar: carrots for the lives, the time bar and pause. Zooming is done with a pinch, and
/// stopping early is offered from the pause screen.
struct FoxPathHUDView: View {
    let viewModel: FoxPathGameViewModel

    /// Height of the pause button; the carrots and the time bar are sized to match it.
    static let controlSize: CGFloat = 64

    var body: some View {
        HStack(spacing: 20) {
            CarrotLivesView(lives: viewModel.lives, total: FoxPathConfiguration.initialLives)

            TimeBarView(
                remainingSeconds: viewModel.remainingSeconds,
                totalSeconds: Int(FoxPathConfiguration.sessionDuration),
                ink: FoxPathPalette.ink
            )
            .frame(maxWidth: .infinity)

            FoxPathPauseButton {
                viewModel.pause()
            }
            .disabled(viewModel.phase != .playing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

/// The painted carrot panel (`FoxPath/Carrots0…3`): one orange carrot per life left, grey for
/// the ones lost.
private struct CarrotLivesView: View {
    let lives: Int
    let total: Int

    var body: some View {
        Image("FoxPath/Carrots\(min(max(lives, 0), 3))")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(height: FoxPathHUDView.controlSize)
            .accessibilityLabel("Carrots")
            .accessibilityValue("\(lives) of \(total)")
    }
}

/// How much of the game is left: a bar that fills up as time passes, and the time left as M:SS.
private struct TimeBarView: View {
    let remainingSeconds: Int
    let totalSeconds: Int
    let ink: Color

    private var progress: Double {
        guard totalSeconds > 0 else { return 1 }
        return min(max(1 - Double(remainingSeconds) / Double(totalSeconds), 0), 1)
    }

    var body: some View {
        HStack(spacing: 16) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    // Outlined so the track stays visible over the grass.
                    Capsule()
                        .fill(.white.opacity(0.85))
                        .overlay(Capsule().stroke(ink.opacity(0.35), lineWidth: 2.5))
                    Capsule()
                        .fill(ink.opacity(0.55))
                        .frame(width: max(proxy.size.height, proxy.size.width * progress))
                        .animation(.linear(duration: 0.2), value: progress)
                }
            }
            .frame(height: 26)
            Text(String(format: "%d:%02d", remainingSeconds / 60, remainingSeconds % 60))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(remainingSeconds <= 10 ? FoxPathPalette.danger : ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time left")
        .accessibilityValue("\(remainingSeconds / 60) minutes \(remainingSeconds % 60) seconds")
    }
}

/// The painted wooden pause button (`FoxPath/PauseButton`).
private struct FoxPathPauseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("FoxPath/PauseButton")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: FoxPathHUDView.controlSize, height: FoxPathHUDView.controlSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pause")
    }
}
