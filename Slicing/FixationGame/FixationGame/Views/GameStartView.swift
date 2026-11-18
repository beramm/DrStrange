//
//  GameStartView.swift
//  First screen of the game. Leads to eye control (calibrate, then play) or,
//  for testing without the front camera (e.g. in the simulator), to finger play.
//  Same flow as the Whack-a-Mole game: calibration → game.
//  The stall keeper is the fox for now. Later the player's character will come
//  from onboarding ("Choose your character") and be passed in here.
//

import SwiftUI

struct GameStartView: View {
    private enum Screen: String, Identifiable {
        case calibration, gazeGame, fingerGame
        var id: String { rawValue }
    }

    /// One tracker session shared by calibration and the game, like Whack-a-Mole.
    @State private var gaze = GazeInputController()
    @State private var screen: Screen?
    /// Leaves the host app's game flow. Nil in the standalone Veggie Keeper app.
    let onExit: (() -> Void)?
    /// Notifies the host when active gameplay begins. Nil in the standalone app.
    let onGameplayStarted: (() -> Void)?
    /// Pause screen "Home": back to the start of the host app. Nil stays on this screen.
    let onHome: (() -> Void)?
    /// Who keeps the stall; the other two characters are the thieves.
    /// Fox for now. Later this will be the character chosen in onboarding.
    private let character = FixationCharacter.fox

    init(
        onExit: (() -> Void)? = nil,
        onGameplayStarted: (() -> Void)? = nil,
        onHome: (() -> Void)? = nil
    ) {
        self.onExit = onExit
        self.onGameplayStarted = onGameplayStarted
        self.onHome = onHome
    }

    var body: some View {
        ZStack {
            GameBackground()

            VStack(spacing: 32) {
                Image("Fox")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 260)
                    .accessibilityHidden(true)

                Text("Veggie Keeper")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(FixationPalette.ink)

                Button {
                    screen = .calibration
                } label: {
                    Label("Calibrate & Play", systemImage: "eye.fill")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .frame(minWidth: 320, minHeight: 84)
                }
                .buttonStyle(.borderedProminent)
                .tint(FixationPalette.accent)
                .clipShape(Capsule())

                // For testing without the front camera (e.g. in the simulator).
                Button {
                    screen = .fingerGame
                } label: {
                    Label("Play with finger", systemImage: "hand.point.up.left.fill")
                        .font(.title2.weight(.bold))
                        .frame(minWidth: 280, minHeight: 56)
                }
                .buttonStyle(.bordered)
                .tint(FixationPalette.ink)
            }
            .padding(48)

            if let onExit {
                Button(action: onExit) {
                    Label("Back", systemImage: "chevron.backward")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 28, weight: .heavy))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(FixationPalette.accent)
                .clipShape(Circle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(24)
            }
        }
        .fullScreenCover(item: $screen) { current in
            switch current {
            case .calibration:
                GazeCalibrationView(
                    controller: gaze,
                    onCalibrated: { screen = .gazeGame },
                    onCancel: { screen = nil }
                )
            case .gazeGame:
                FixationGameView(gaze: gaze, character: character, onExit: closeGame, onHome: goHome)
            case .fingerGame:
                FixationGameView(gaze: nil, character: character, onExit: closeGame, onHome: goHome)
            }
        }
        .onChange(of: screen) { _, screen in
            guard screen == .gazeGame || screen == .fingerGame else { return }
            onGameplayStarted?()
        }
    }

    private func closeGame() {
        gaze.stop()
        screen = nil
        onExit?()
    }

    /// Closes the game and goes back to the start of the host app (or to this screen when
    /// standalone).
    private func goHome() {
        gaze.stop()
        screen = nil
        onHome?()
    }
}

#Preview(traits: .landscapeLeft) {
    GameStartView()
}
