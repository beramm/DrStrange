//
//  RandomizerView.swift
//  The "Game Map": picks which mini-game the child plays.
//  A highlight hops across the three game cards. The highlighted card pops up
//  to full size while the others shrink back. It slows down, stops on the
//  chosen game, and after a short pause opens that game by itself.
//
//  Every position below is taken from the 1194 × 834 Figma frame and then
//  scaled to the real screen (same approach as LobbyView).
//

import SwiftUI

struct RandomizerView: View {
    /// Called with the chosen game once the highlight has stopped.
    let onChosen: (MiniGame) -> Void
    /// Called when the settings button is tapped.
    let onSettings: () -> Void

    /// The last game picked, saved so the same game isn't picked twice in a row.
    @AppStorage(MiniGame.lastGameStorageKey) private var lastGameID = ""
    /// When disabled, the cards become direct choices and no spin runs.
    @AppStorage(MiniGame.randomSpinEnabledStorageKey) private var randomSpinEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    /// The card that is popped up right now (nil before the spin starts).
    @State private var highlighted: MiniGame?
    @State private var manualSelectionPending = false
    @State private var manualSelectionTask: Task<Void, Never>?

    /// Size of the Figma frame the design was made in.
    private let design = CGSize(width: 1194, height: 834)
    /// Card centres in the design, left to right (same order as `MiniGame.allCases`).
    private let cardCentersX: [CGFloat] = [207, 596, 976]
    private let cardCenterY: CGFloat = 428
    /// Size of the cards that aren't popped up, compared with the popped-up one.
    private let smallCardScale: CGFloat = 0.765

    var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width / design.width
            let sy = geo.size.height / design.height
            let s = min(sx, sy)

            ZStack {
                LobbyScenery()

                // Top bar: back, title, settings.
                RoundIconButton(systemImage: "arrowtriangle.backward.fill", label: "Back", size: 62 * s) {
                    dismiss()
                }
                .position(x: 68 * sx, y: 83 * sy)

                Text(randomSpinEnabled ? "Game map" : "Choose a game")
                    .textCase(.uppercase)
                    .font(.doodle(80 * s))
                    .foregroundStyle(Color.titleBrown)
                    .position(x: 598 * sx, y: 80 * sy)
                    .accessibilityAddTraits(.isHeader)

                RoundIconButton(systemImage: "gearshape.fill", label: "Settings", size: 62 * s, action: onSettings)
                    .position(x: 1128 * sx, y: 83 * sy)

                // The three game cards. The highlighted one is full size and in front.
                ForEach(Array(MiniGame.allCases.enumerated()), id: \.element) { index, game in
                    let isPopped = game == highlighted
                    Group {
                        if randomSpinEnabled {
                            MiniGameCard(game: game, scale: s)
                        } else {
                            Button {
                                chooseManually(game)
                            } label: {
                                MiniGameCard(game: game, scale: s)
                            }
                            .buttonStyle(.plain)
                            .disabled(manualSelectionPending)
                            .accessibilityHint("Play \(game.title)")
                        }
                    }
                        .scaleEffect(isPopped ? 1 : smallCardScale)
                        .zIndex(isPopped ? 1 : 0)
                        .position(x: cardCentersX[index] * sx, y: cardCenterY * sy)
                        .accessibilityAddTraits(isPopped ? .isSelected : [])
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: highlighted)
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        // A small tap feeling each time a card pops up.
        .sensoryFeedback(.selection, trigger: highlighted)
        // Runs every time this screen appears when automatic selection is enabled.
        .task(id: randomSpinEnabled) {
            guard randomSpinEnabled else {
                highlighted = nil
                manualSelectionPending = false
                return
            }
            await spin()
        }
        .onDisappear {
            manualSelectionTask?.cancel()
            manualSelectionTask = nil
            manualSelectionPending = false
        }
    }

    private func chooseManually(_ game: MiniGame) {
        guard !randomSpinEnabled, !manualSelectionPending else { return }
        manualSelectionPending = true
        highlighted = game
        lastGameID = game.rawValue
        manualSelectionTask?.cancel()
        manualSelectionTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            onChosen(game)
        }
    }

    private func spin() async {
        highlighted = nil
        let pick = MiniGame.randomPick(avoiding: MiniGame(rawValue: lastGameID))

        do {
            if !reduceMotion {
                let games = MiniGame.allCases
                // Two full rounds, then stop on the picked game.
                let hops = games.count * 2 + (games.firstIndex(of: pick) ?? 0)
                for step in 0...hops {
                    highlighted = games[step % games.count]
                    // Each hop waits a little longer, so it slows down before stopping.
                    try await Task.sleep(for: .milliseconds(140 + step * 45))
                }
            }

            highlighted = pick
            lastGameID = pick.rawValue

            // Let the child see which game was picked, then open it.
            try await Task.sleep(for: .seconds(1.5))
            onChosen(pick)
        } catch {
            // The child left this screen (for example with the back button); stop here.
        }
    }
}

#Preview("Game map", traits: .landscapeLeft) {
    RandomizerView(onChosen: { _ in }, onSettings: {})
}
