//
//  RandomizerView.swift
//  The "Game Map": picks which mini-game the child plays.
//  A highlight hops across the three game cards. The highlighted card pops up
//  to full size while the others shrink back. It slows down, stops on the
//  chosen game, and after a short pause opens that game by itself.
//  While it picks by itself, the screen is locked: no back button.
//
//  With "Random game" off in Setting, the cards are buttons and the child picks,
//  and a back button is shown. There is no settings button on this screen.
//  With "Lock games" on (testing), only Whack a Mole can be picked or played.
//
//  Every position below is taken from the 1194 × 834 Figma frame and then
//  scaled to the real screen (same approach as LobbyView).
//

import SwiftUI

struct RandomizerView: View {
    /// Called with the chosen game once the highlight has stopped.
    let onChosen: (MiniGame) -> Void

    /// The last game picked, saved so the same game isn't picked twice in a row.
    @AppStorage(MiniGame.lastGameStorageKey) private var lastGameID = ""
    /// When disabled, the cards become direct choices and no spin runs.
    @AppStorage(MiniGame.randomSpinEnabledStorageKey) private var randomSpinEnabled = true
    /// Testing setting: locked games can't be picked or played.
    @AppStorage(AppSettings.gamesLockedKey) private var gamesLocked = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    /// The card that is popped up right now (nil before the spin starts).
    @State private var highlighted: MiniGame?
    /// The picked game: its card flips over to show the full card.
    @State private var revealed: MiniGame?
    @State private var manualSelectionPending = false
    @State private var manualSelectionTask: Task<Void, Never>?

    /// Size of the Figma frame the design was made in.
    private let design = CGSize(width: 1194, height: 834)
    /// Card centres in the design, left to right (same order as `MiniGame.allCases`).
    private let cardCentersX: [CGFloat] = [207, 596, 976]
    private let cardCenterY: CGFloat = 428
    /// Size of the cards that aren't popped up, compared with the popped-up one.
    private let smallCardScale: CGFloat = 0.765
    /// The highlight sequence and its sound effect finish together at this time.
    private let spinDurationMilliseconds: Int64 = 3_000

    var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width / design.width
            let sy = geo.size.height / design.height
            let s = min(sx, sy)

            ZStack {
                LobbyScenery()

                // Top bar: back and title. When the game is picked at random,
                // the screen is locked, so there is no back button.
                if !randomSpinEnabled {
                    RoundIconButton(systemImage: "arrowtriangle.backward.fill", label: "Back", size: 62 * s) {
                        dismiss()
                    }
                    .position(x: 68 * sx, y: 83 * sy)
                }

                Text(randomSpinEnabled ? "Game map" : "Choose a game")
                    .textCase(.uppercase)
                    .doodleText(size: 80 * s)
                    .foregroundStyle(Color.titleBrown)
                    .position(x: 598 * sx, y: 80 * sy)
                    .accessibilityAddTraits(.isHeader)

                // The three game cards. The highlighted one is full size and in front.
                ForEach(Array(MiniGame.allCases.enumerated()), id: \.element) { index, game in
                    let isPopped = game == highlighted
                    let isLocked = game.isLocked(whenGamesLocked: gamesLocked)
                    Group {
                        if randomSpinEnabled {
                            MiniGameCard(game: game, isLocked: isLocked, isRevealed: game == revealed, scale: s)
                        } else {
                            Button {
                                chooseManually(game)
                            } label: {
                                MiniGameCard(game: game, isLocked: isLocked, isRevealed: game == revealed, scale: s)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .disabled(manualSelectionPending)
                            // A locked game can't be opened: chooseManually ignores the tap.
                            // (Not .disabled here, which would also fade the lock.)
                            .accessibilityHint(isLocked ? "" : "Play \(game.title)")
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
                revealed = nil
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
        guard !randomSpinEnabled, !manualSelectionPending,
              !game.isLocked(whenGamesLocked: gamesLocked) else { return }
        manualSelectionPending = true
        highlighted = game
        revealed = game
        lastGameID = game.rawValue
        manualSelectionTask?.cancel()
        manualSelectionTask = Task {
            // Time for the card to flip over and for the child to see it.
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            onChosen(game)
        }
    }

    private func spin() async {
        highlighted = nil
        revealed = nil
        // Only open (unlocked) games can be picked.
        let pick = MiniGame.randomPick(avoiding: MiniGame(rawValue: lastGameID), gamesLocked: gamesLocked)
        var randomizerSoundIsPlaying = false

        do {
            if !reduceMotion {
                let games = MiniGame.allCases
                // Two full rounds, then stop on the picked game.
                let hops = games.count * 2 + (games.firstIndex(of: pick) ?? 0)
                let delays = (0..<hops).map { 140 + $0 * 45 }
                let totalDelay = delays.reduce(0, +)
                let clock = ContinuousClock()
                let start = clock.now

                SoundEffectPlayer.shared.play(.randomizer)
                randomizerSoundIsPlaying = true

                highlighted = games[0]
                var elapsedDelay = 0
                for step in 1...hops {
                    // Preserve the slowdown curve, normalized to exactly three seconds.
                    elapsedDelay += delays[step - 1]
                    let targetMilliseconds = Int64(
                        (Double(elapsedDelay) / Double(totalDelay) * Double(spinDurationMilliseconds)).rounded()
                    )
                    try await clock.sleep(
                        until: start.advanced(by: .milliseconds(targetMilliseconds))
                    )
                    highlighted = games[step % games.count]
                }

                SoundEffectPlayer.shared.stop(.randomizer)
                randomizerSoundIsPlaying = false
            }

            highlighted = pick
            lastGameID = pick.rawValue

            // The picked card flips over to show the full card.
            try await Task.sleep(for: .milliseconds(250))
            revealed = pick

            // Let the child see which game was picked, then open it.
            try await Task.sleep(for: .seconds(2.2))
            onChosen(pick)
        } catch {
            // The child left this screen (for example with the back button); stop here.
            if randomizerSoundIsPlaying {
                SoundEffectPlayer.shared.stop(.randomizer)
            }
        }
    }
}

#Preview("Game map", traits: .landscapeLeft) {
    RandomizerView(onChosen: { _ in })
}
