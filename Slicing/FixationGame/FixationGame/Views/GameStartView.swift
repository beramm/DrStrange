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
    /// Who keeps the stall; the other two characters are the thieves.
    /// Fox for now. Later this will be the character chosen in onboarding.
    private let character = GameCharacter.fox

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
                    .foregroundStyle(Color.ink)

                Button {
                    screen = .calibration
                } label: {
                    Label("Calibrate & Play", systemImage: "eye.fill")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .frame(minWidth: 320, minHeight: 84)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accent)
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
                .tint(Color.ink)
            }
            .padding(48)
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
                FixationGameView(gaze: gaze, character: character) {
                    // Turn the camera off when leaving the game.
                    gaze.stop()
                    screen = nil
                }
            case .fingerGame:
                FixationGameView(gaze: nil, character: character) { screen = nil }
            }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    GameStartView()
}
