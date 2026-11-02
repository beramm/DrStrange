import SwiftUI

/// Top bar: exit, score, time progress, level, sound and pause. Icons first, minimal text.
struct GameHUDView: View {
    let viewModel: WhackAMoleGameViewModel
    let onExit: () -> Void

    private let ink = WhackAMolePalette.ink

    var body: some View {
        @Bindable var viewModel = viewModel
        HStack(spacing: 20) {
            HUDButton(systemImage: "xmark", label: "Exit game", ink: ink, action: onExit)

            ScoreView(score: viewModel.score)

            SessionProgressView(progress: viewModel.progress, remainingSeconds: viewModel.remainingSeconds, ink: ink)
                .frame(maxWidth: .infinity)

            LevelIndicatorView(level: viewModel.level, ink: ink)

            HUDButton(
                systemImage: viewModel.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                label: viewModel.soundEnabled ? "Mute sound" : "Turn sound on",
                ink: ink
            ) {
                viewModel.soundEnabled.toggle()
            }

            HUDButton(systemImage: "pause.fill", label: "Pause", ink: ink) {
                viewModel.pause()
            }
            .disabled(viewModel.phase == .paused || viewModel.phase == .finished)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

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
        HStack(spacing: 12) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.7))
                    Capsule()
                        .fill(ink.opacity(0.55))
                        .frame(width: max(proxy.size.height, proxy.size.width * progress))
                        .animation(.linear(duration: 0.2), value: progress)
                }
            }
            .frame(height: 18)
            Text(Self.format(remainingSeconds))
                .font(.system(.title3, design: .rounded).weight(.bold))
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
