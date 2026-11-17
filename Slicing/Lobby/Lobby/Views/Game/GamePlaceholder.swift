//
//  GamePlaceholder.swift
//  Routes each lobby selection to its playable mini-game.
//  Whack a Mole launches through the shared calibration flow; Veggie Dash and
//  Veggie Keeper own their start and calibration screens.
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
        selectedGame
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

    @ViewBuilder
    private var selectedGame: some View {
        switch game {
        case .veggieDash:
            FoxPathHomeView(onExit: onExit)
        case .whackAMole:
            whackAMoleLauncher
        case .veggieKeeper:
            GameStartView(onExit: onExit)
        }
    }

    private var whackAMoleLauncher: some View {
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
