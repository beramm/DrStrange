import SwiftUI

/// Star and running score shown in the HUD, sized to sit level with the pause button.
struct ScoreView: View {
    let score: Int

    var body: some View {
        HStack(spacing: 10) {
            // The painted star (`ScoreStar` asset), the same size as the earlier star icon.
            Image("ScoreStar")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 51, height: 51)
            Text("\(score)")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: score)
                .foregroundStyle(WhackAMolePalette.ink)
        }
        .frame(height: GameHUDView.controlSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score)")
    }
}
