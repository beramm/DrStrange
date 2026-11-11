import SwiftUI

/// Star and running score shown in the HUD.
struct ScoreView: View {
    let score: Int

    var body: some View {
        Label {
            Text("\(score)")
                .font(.system(.title, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: score)
        } icon: {
            Image(systemName: "star.fill")
                .foregroundStyle(WhackAMolePalette.star)
        }
        .font(.title)
        .foregroundStyle(WhackAMolePalette.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score)")
    }
}
