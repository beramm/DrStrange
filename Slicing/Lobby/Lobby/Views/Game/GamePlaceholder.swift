//
//  GamePlaceholder.swift
//  Launches the selected mini-game through calibration.
//  Whack a Mole is connected to the shared calibration and gameplay flow;
//  games that have not been built yet remain on their announcement screen.
//

import SwiftUI

#if canImport(DrStrangeGazeTracker)
struct SelectedGameView: View {
    private enum PresentedScreen: String, Identifiable {
        case calibration
        case game

        var id: String { rawValue }
    }

    let game: MiniGame
    /// Leaves the game. ContentView decides where to go (the start screen or the Game Map).
    let onExit: () -> Void

    @State private var configuration = ConfigurationStore.standard.load()
    @State private var gazeController = GazeInputController()
    @State private var presentedScreen: PresentedScreen?
    @State private var hasStarted = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.sky
                .ignoresSafeArea()

            Text(game.title)
                .textCase(.uppercase)
                .font(.daysOne(64))
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            RoundIconButton(systemImage: "arrowtriangle.backward.fill", label: "Back", size: 62) {
                onExit()
            }
            .padding(.leading, 37)
            .padding(.top, 20)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard game == .whackAMole, !hasStarted else { return }
            hasStarted = true
            // Apply the caregiver's saved gaze-testing setting before calibration.
            gazeController.setOneEyeEnforcerEnabled(configuration.oneEyeEnforcerEnabled)
            presentedScreen = .calibration
        }
        .fullScreenCover(item: $presentedScreen) { screen in
            switch screen {
            case .calibration:
                GazeCalibrationView(
                    controller: gazeController,
                    onCalibrated: { presentedScreen = .game },
                    onCancel: { closeGameFlow() }
                )
            case .game:
                WhackAMoleGameView(
                    configuration: configuration,
                    gazeController: gazeController,
                    onClose: { closeGameFlow() }
                )
            }
        }
    }

    private func closeGameFlow() {
        gazeController.stop()
        presentedScreen = nil
        onExit()
    }
}
#else
struct SelectedGameView: View {
    let game: MiniGame
    /// Leaves the game. ContentView decides where to go (the start screen or the Game Map).
    let onExit: () -> Void


    var body: some View {
        gameAnnouncement
    }

    private var gameAnnouncement: some View {
        ZStack(alignment: .topLeading) {
            Color.sky
                .ignoresSafeArea()

            Text(game.title)
                .textCase(.uppercase)
                .font(.daysOne(64))
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            RoundIconButton(systemImage: "arrowtriangle.backward.fill", label: "Back", size: 62) {
                onExit()
            }
            .padding(.leading, 37)
            .padding(.top, 20)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
#endif

#Preview(traits: .landscapeLeft) {
    SelectedGameView(game: .whackAMole, onExit: {})
}
