import SwiftUI

/// End-of-game summary. A big friendly result for the child, details for the adult below.
struct FoxPathResultView: View {
    let result: FoxPathResult
    /// The character the child was following last, shown on the result.
    let character: PathCharacter
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
            Image(character.standingAsset)
                .resizable()
                .scaledToFit()
                .frame(height: 220)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                Text(headline)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                Text(message)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                if result.endReason != .stopped {
                    HStack(spacing: 10) {
                        ForEach(0..<FoxPathConfiguration.initialLives, id: \.self) { index in
                            Image(systemName: index < result.livesLeft ? "heart.fill" : "heart")
                        }
                    }
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundStyle(FoxPathPalette.heart)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(result.livesLeft) of \(FoxPathConfiguration.initialLives) hearts left")
                }
            }
            .foregroundStyle(FoxPathPalette.ink)
        }
    }

    private var headline: String {
        switch result.endReason {
        case .timeUp: "Time's up!"
        case .noLivesLeft: "Game over"
        case .stopped: "Time to rest!"
        }
    }

    private var message: String {
        switch result.endReason {
        case .timeUp:
            result.catches == 0 ? "You kept every veggie safe!" : "Great following! Let's guard the veggies again."
        case .noLivesLeft:
            "The veggies are gone this time. Try again!"
        case .stopped:
            "Resting your eyes was a good choice."
        }
    }

    private var metrics: some View {
        HStack(spacing: 16) {
            MetricCard(title: "Time played", value: Self.format(result.playTime), systemImage: "clock.fill")
            MetricCard(title: "Paths finished", value: "\(result.walksCompleted)", systemImage: "storefront.fill")
            MetricCard(title: "Had to wait", value: "\(result.offTrackCount)×", systemImage: "exclamationmark.circle.fill")
        }
    }

    private var disclaimer: some View {
        ClinicalNote("These numbers describe this game only. They are not a vision test, they are not saved, and they do not show whether treatment is working.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 620)
    }

    private var buttons: some View {
        HStack(spacing: 20) {
            Button(action: onDone) {
                Label("Done", systemImage: "house.fill")
                    .frame(minWidth: 180, minHeight: 64)
            }
            .buttonStyle(.bordered)
            Button(action: onPlayAgain) {
                Label("Play again", systemImage: "arrow.clockwise")
                    .frame(minWidth: 220, minHeight: 64)
            }
            .buttonStyle(.borderedProminent)
            .tint(FoxPathPalette.accent)
        }
        .font(.title2.weight(.bold))
    }

    static func format(_ time: TimeInterval) -> String {
        let seconds = Int(time.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(FoxPathPalette.accent)
            Text(value)
                .font(.system(.title, design: .rounded).weight(.heavy))
                .monospacedDigit()
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(FoxPathPalette.ink)
        .frame(maxWidth: .infinity, minHeight: 130)
        .background(RoundedRectangle(cornerRadius: 24).fill(FoxPathPalette.cream))
        .accessibilityElement(children: .combine)
    }
}
