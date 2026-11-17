import SwiftUI

/// Top bar: stars, time progress and pause. Stopping early is offered from the pause screen.
struct GameHUDView: View {
    let viewModel: WhackAMoleGameViewModel

    /// Height of the pause button; the stars and the time bar are sized to match it.
    static let controlSize: CGFloat = 64

    private let ink = WhackAMolePalette.ink

    var body: some View {
        HStack(spacing: 20) {
            ScoreView(score: viewModel.score)

            SessionProgressView(progress: viewModel.progress, remainingSeconds: viewModel.remainingSeconds, ink: ink)
                .frame(maxWidth: .infinity)

            PauseButton {
                viewModel.pause()
            }
            .disabled(viewModel.phase == .paused || viewModel.phase == .finished)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

/// The painted wooden pause button (`PauseButton` asset).
struct PauseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("PauseButton")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: GameHUDView.controlSize, height: GameHUDView.controlSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pause")
    }
}

/// Round icon button. Whack-a-Mole's top bar no longer uses it, but the shared Fox Path top bar
/// on `development` still does.
struct HUDButton: View {
    let systemImage: String
    let label: String
    let ink: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(ink)
                .frame(width: 60, height: 60)
                .background(Circle().fill(.white.opacity(0.75)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct SessionProgressView: View {
    let progress: Double
    let remainingSeconds: Int
    let ink: Color

    var body: some View {
        HStack(spacing: 16) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    // Outlined so the track stays visible over the painted clouds.
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
            Text(Self.format(remainingSeconds))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time left")
        .accessibilityValue(Self.format(remainingSeconds))
    }

    static func format(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Dots for a game level. Used by games that offer levels.
struct LevelIndicatorView: View {
    let level: DifficultyLevel
    let ink: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DifficultyLevel.allCases) { candidate in
                Circle()
                    .fill(candidate <= level ? ink : ink.opacity(0.2))
                    .frame(width: 14, height: 14)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level.rawValue) of \(DifficultyLevel.allCases.count)")
    }
}
