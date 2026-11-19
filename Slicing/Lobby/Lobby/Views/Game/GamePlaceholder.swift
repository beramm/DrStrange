//
//  GamePlaceholder.swift
//  Routes each lobby selection to its playable mini-game, with the character the
//  player chose on character select: the same character in every game.
//  Every game opens the shared gaze calibration flow as soon as it is chosen.
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
    /// Finish and pause screen "Home": back to the start screen.
    var onHome: () -> Void = {}
    /// Finish screen "Next": on to another game, picked by ContentView.
    var onNextGame: () -> Void = {}

    /// The character chosen on character select.
    @AppStorage(GameCharacter.storageKey) private var characterID = GameCharacter.fox.id
    @AppStorage(AppSettings.wearsEyePatchKey)
    private var wearsEyePatch = AppSettings.wearsEyePatch(
        fallback: ConfigurationStore.standard.load().oneEyeEnforcerEnabled
    )
    @State private var configuration = ConfigurationStore.standard.load()
    @State private var gazeController = GazeInputController()
    @State private var presentedScreen: PresentedScreen?
    @State private var hasStarted = false

    var body: some View {
        gameLauncher
            .toolbar(.hidden, for: .navigationBar)
            .task {
                guard !hasStarted else { return }
                hasStarted = true
                // Apply the caregiver's saved gaze-testing setting before calibration.
                gazeController.setOneEyeEnforcerEnabled(wearsEyePatch)
                presentedScreen = .calibration
            }
            .onChange(of: wearsEyePatch) { _, enabled in
                gazeController.setOneEyeEnforcerEnabled(enabled)
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
                    selectedGame
                }
            }
            .onChange(of: presentedScreen) { _, screen in
                guard screen == .game else { return }
                switch game {
                case .whackAMole: BackgroundMusicPlayer.shared.play(.whackAMole)
                case .veggieKeeper: BackgroundMusicPlayer.shared.play(.veggieKeeper)
                case .veggieDash: break
                }
            }
    }

    @ViewBuilder
    private var selectedGame: some View {
        switch game {
        case .veggieDash:
            FoxPathGameView(
                configuration: FoxPathConfigurationStore.standard.load(),
                input: .gaze(gazeController),
                player: PathCharacter(rawValue: characterID) ?? .fox,
                onClose: closeGameFlow
            )
        case .whackAMole:
            WhackAMoleGameView(
                configuration: configuration,
                gazeController: gazeController,
                // The player's character swings the hammer.
                helper: HelperCharacter(rawValue: characterID) ?? .fox,
                onClose: closeGameFlow
            )
        case .veggieKeeper:
            FixationGameView(
                gaze: gazeController,
                character: FixationCharacter(rawValue: characterID) ?? .fox,
                onExit: closeGameFlow,
                onHome: { leaveGame(through: onHome) },
                onNextGame: { leaveGame(through: onNextGame) }
            )
        }
    }

    private var gameLauncher: some View {
        ZStack(alignment: .topLeading) {
            Color.sky
                .ignoresSafeArea()

            Text(game.title)
                .textCase(.uppercase)
                .font(.daysOne(64))
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            RoundIconButton(systemImage: "arrowtriangle.backward.fill", label: "Back", size: 62) {
                closeGameFlow()
            }
            .padding(.leading, 37)
            .padding(.top, 20)
        }
    }

    private func closeGameFlow() {
        leaveGame(through: onExit)
    }

    private func leaveGame(through destination: () -> Void) {
        gazeController.stop()
        presentedScreen = nil
        destination()
    }
}
#else
struct SelectedGameView: View {
    let game: MiniGame
    /// Leaves the game. ContentView decides where to go (the start screen or the Game Map).
    let onExit: () -> Void
    /// Finish and pause screen "Home": back to the start screen.
    var onHome: () -> Void = {}
    /// Finish screen "Next": on to another game, picked by ContentView.
    var onNextGame: () -> Void = {}


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
