//
//  RandomizerView.swift
//  Picks which mini-game the child plays. A highlight hops across the three
//  game cards, slows down and stops on the chosen game; then Go appears.
//

import SwiftUI

struct RandomizerView: View {
    /// Called with the chosen game when the child taps Go.
    let onGo: (MiniGame) -> Void

    /// The last game picked, saved so the same game isn't picked twice in a row.
    @AppStorage(MiniGame.lastGameStorageKey) private var lastGameID = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The card the highlight is on right now.
    @State private var highlighted: MiniGame?
    /// The final pick. Stays nil while the highlight is still hopping.
    @State private var chosen: MiniGame?

    var body: some View {
        VStack(spacing: 56) {
            Spacer()
            HStack(spacing: 28) {
                ForEach(MiniGame.allCases, id: \.self) { game in
                    MiniGameCard(game: game, isHighlighted: game == highlighted)
                }
            }
            KidButton(title: "Go", systemImage: "play.fill", kind: .primary) {
                if let chosen { onGo(chosen) }
            }
            .frame(maxWidth: 380)
            // Hidden (but still taking up space, so nothing jumps) until a game is chosen.
            .opacity(chosen == nil ? 0 : 1)
            .disabled(chosen == nil)
            Spacer()
        }
        .padding(.horizontal, 48)
        .padding(.top, 32)
        // Keep tappable things away from the bottom edge (wrists rest there).
        .padding(.bottom, 72)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LobbyBackground())
        // A small tap feeling each time the highlight hops.
        .sensoryFeedback(.selection, trigger: highlighted)
        // Runs every time this screen appears, so coming back picks a new game.
        .task { await spin() }
    }

    private func spin() async {
        chosen = nil
        let pick = MiniGame.randomPick(avoiding: MiniGame(rawValue: lastGameID))

        if !reduceMotion {
            let games = MiniGame.allCases
            // Two full rounds, then stop on the picked game.
            let hops = games.count * 2 + (games.firstIndex(of: pick) ?? 0)
            for step in 0...hops {
                highlighted = games[step % games.count]
                // Each hop waits a little longer, so it slows down before stopping.
                do {
                    try await Task.sleep(for: .milliseconds(80 + step * 25))
                } catch {
                    return  // The child left this screen; stop here.
                }
            }
        }

        highlighted = pick
        chosen = pick
        lastGameID = pick.rawValue
    }
}

#Preview("Randomizer", traits: .landscapeLeft) {
    RandomizerView(onGo: { _ in })
}
