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
                    sessionRecord
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
            Image(FoxCharacterView.assetName(1))
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(headline)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                Text(encouragement)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                Label("\(score)", systemImage: "star.fill")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(WhackAMolePalette.accent)
                    .accessibilityLabel("Score \(score)")
            }
            .foregroundStyle(WhackAMolePalette.ink)
        }
    }

    private var headline: String {
        if session.endReason == .restBreak { return "Time to rest!" }
        return session.hits > 0 ? "Great job!" : "Nice try!"
    }

    private var encouragement: String {
        if session.endReason == .restBreak { return "Resting your eyes was a good choice." }
        switch session.hits {
        case 0: return "The moles will be back next time."
        case 1: return "You got 1 mole!"
        default: return "You got \(session.hits) moles!"
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
            MetricTile(title: "Session length", value: SessionProgressView.format(Int(session.configuration.sessionDuration)))
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

    /// Patching details for the caregiver's records. Shown only as entered; never inferred.
    private var sessionRecord: some View {
        let patching = session.configuration.patching
        return VStack(alignment: .leading, spacing: 10) {
            Text("Session record")
                .font(.headline)
            RecordRow(title: "Started", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
            RecordRow(title: "Ended", value: session.endedAt?.formatted(date: .omitted, time: .shortened) ?? "–")
            RecordRow(title: "Ended because", value: endReasonText)
            RecordRow(title: "Patched eye", value: patching.patchedEye?.title ?? "Not recorded")
            RecordRow(title: "Playing eye", value: patching.playingEye?.title ?? "Not recorded")
        }
        .foregroundStyle(WhackAMolePalette.ink)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(WhackAMolePalette.cream))
    }

    private var endReasonText: String {
        switch session.endReason {
        case .timeUp: "Time was up"
        case .stopped: "Stopped early"
        case .restBreak: "Rest break (eyes tired or uncomfortable)"
        case nil: "–"
        }
    }

    private var disclaimer: some View {
        Label(
            "These numbers describe how the game went. They are not an eye test and do not show whether treatment is working. Keep following your eye doctor's patching plan and check-ups, and rest your eyes before playing again.",
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

private struct RecordRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .accessibilityElement(children: .combine)
    }
}
