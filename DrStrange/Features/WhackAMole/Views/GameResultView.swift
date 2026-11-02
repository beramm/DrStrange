import SwiftUI

/// End-of-session summary. A big friendly result for the child, details for the adult below.
struct GameResultView: View {
    let session: GameSessionRecord
    let score: Int
    let onPlayAgain: () -> Void
    let onDone: () -> Void

    var body: some View {
        ZStack {
            WhackAMolePalette.meadow.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    celebration
                    metrics
                    disclaimer
                    buttons
                }
                .padding(40)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var celebration: some View {
        HStack(spacing: 24) {
            Image(FoxHammerView.assetName(1))
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(session.hits > 0 ? "Great job!" : "Nice try!")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                Label("\(score)", systemImage: "star.fill")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(WhackAMolePalette.accent)
                    .accessibilityLabel("Score \(score)")
            }
            .foregroundStyle(WhackAMolePalette.ink)
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
            MetricTile(title: "Characters", value: "\(session.targetsSpawned)")
            MetricTile(title: "Hits", value: "\(session.hits)")
            MetricTile(title: "Missed", value: "\(session.misses)")
            MetricTile(title: "Accuracy", value: session.accuracy.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "–")
            MetricTile(title: "Avg. response", value: session.averageResponseTime.map { String(format: "%.2f s", $0) } ?? "–")
            MetricTile(title: "Play time", value: SessionProgressView.format(Int(session.activePlayDuration.rounded())))
            MetricTile(title: "Level", value: levelText)
            MetricTile(title: "Mode", value: session.configuration.therapy.viewingMode == .anaglyph ? "Red/cyan" : "Standard")
            if session.decoysShown > 0 {
                MetricTile(title: "Sleepy left alone", value: "\(session.decoysShown - session.decoyTaps) / \(session.decoysShown)")
            }
        }
    }

    private var levelText: String {
        let start = session.configuration.startingLevel.rawValue
        let end = session.finalLevel.rawValue
        return start == end ? "\(end)" : "\(start) → \(end)"
    }

    private var disclaimer: some View {
        Label(
            "These numbers describe how the game went. They are not an eye test or a measure of treatment progress. Please follow your eye doctor's treatment plan, and rest your eyes before playing again.",
            systemImage: "info.circle"
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.6)))
    }

    private var buttons: some View {
        HStack(spacing: 20) {
            Button(action: onDone) {
                Label("Done", systemImage: "house.fill").frame(minWidth: 160, minHeight: 60)
            }
            .buttonStyle(.bordered)
            Button(action: onPlayAgain) {
                Label("Play again", systemImage: "arrow.clockwise").frame(minWidth: 200, minHeight: 60)
            }
            .buttonStyle(.borderedProminent)
            .tint(WhackAMolePalette.accent)
        }
        .font(.title2.weight(.bold))
    }
}

private struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(WhackAMolePalette.ink)
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(RoundedRectangle(cornerRadius: 20).fill(WhackAMolePalette.cream))
        .accessibilityElement(children: .combine)
    }
}
