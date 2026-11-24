//
//  GameStartView.swift
//  First screen of the game. Leads to eye control (calibrate, then play) or,
//  for testing without the front camera (e.g. in the simulator), to finger play.
//  Same flow as the Whack-a-Mole game: calibration → game.
//  The stall keeper is the player's character from onboarding ("Choose your
//  character"). The standalone Veggie Keeper app uses the fox.
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
    /// Pause and finish screen "Home": back to the start of the host app. Nil stays on this screen.
    let onHome: (() -> Void)?
    /// Finish screen "Next": on to another game in the host app. Nil hides the button.
    let onNextGame: (() -> Void)?
    /// Host music hooks. Nil in the standalone Veggie Keeper app.
    let onResultShown: (() -> Void)?
    let onGameplayRestarted: (() -> Void)?
    /// Who keeps the stall (the player's character). The thief is a mole.
    let character: FixationCharacter
    let oneEyeEnforcerEnabled: Bool

    init(
        character: FixationCharacter = .fox,
        oneEyeEnforcerEnabled: Bool = true,
        onExit: (() -> Void)? = nil,
        onGameplayStarted: (() -> Void)? = nil,
        onHome: (() -> Void)? = nil,
        onNextGame: (() -> Void)? = nil,
        onResultShown: (() -> Void)? = nil,
        onGameplayRestarted: (() -> Void)? = nil
    ) {
        self.character = character
        self.oneEyeEnforcerEnabled = oneEyeEnforcerEnabled
        self.onExit = onExit
        self.onGameplayStarted = onGameplayStarted
        self.onHome = onHome
        self.onNextGame = onNextGame
        self.onResultShown = onResultShown
        self.onGameplayRestarted = onGameplayRestarted
    }

    var body: some View {
        ZStack {
            GameBackground()

            VStack(spacing: 32) {
                // The player's own character.
                Image(character.keeperAwakeImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 260)
                    .accessibilityHidden(true)

                Text("Veggie Keeper")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(FixationPalette.ink)

                Button {
                    #if !VEGGIE_KEEPER_STANDALONE
                    gaze.setOneEyeEnforcerEnabled(oneEyeEnforcerEnabled)
                    #endif
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
                FixationGameView(
                    gaze: gaze,
                    character: character,
                    onExit: { closeGame() },
                    onHome: goHome,
                    onNextGame: onNextGame.map { next in { closeGame(then: next) } },
                    onResultShown: onResultShown,
                    onGameplayRestarted: onGameplayRestarted
                )
            case .fingerGame:
                FixationGameView(
                    gaze: nil,
                    character: character,
                    onExit: { closeGame() },
                    onHome: goHome,
                    onNextGame: onNextGame.map { next in { closeGame(then: next) } },
                    onResultShown: onResultShown,
                    onGameplayRestarted: onGameplayRestarted
                )
            }
        }
        .onChange(of: screen) { _, screen in
            guard screen == .gazeGame || screen == .fingerGame else { return }
            onGameplayStarted?()
        }
        #if !VEGGIE_KEEPER_STANDALONE
        .onChange(of: oneEyeEnforcerEnabled, initial: true) { _, enabled in
            gaze.setOneEyeEnforcerEnabled(enabled)
        }
        #endif
    }

    /// Stops the camera, closes the game and hands over to `destination` (by default the usual
    /// exit).
    private func closeGame(then destination: (() -> Void)? = nil) {
        gaze.stop()
        screen = nil
        (destination ?? onExit)?()
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
