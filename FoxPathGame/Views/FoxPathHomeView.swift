import SwiftUI

/// Entry screen for Follow the Fox: the player's character (or all three friends in the standalone
/// app), what the game is about and a big Play button, centred on the meadow. The game uses the
/// saved options (sound, haptics, gaze marker).
struct FoxPathHomeView: View {
    private enum PresentedScreen: String, Identifiable {
        case calibration
        case gazeGame
        case touchGame

        var id: String { rawValue }
    }

    @State private var configuration = FoxPathConfigurationStore.standard.load()
    @State private var gazeController = GazeInputController()
    @State private var presentedScreen: PresentedScreen?
    /// Leaves the host app's game flow. Nil in the standalone Follow the Fox app.
    let onExit: (() -> Void)?
    /// The player's character from onboarding: always the one followed. Nil in the standalone app,
    /// where the one to follow is drawn at random.
    let player: PathCharacter?
    /// Finish and pause screen "Home": back to the start of the host app. Nil stays here.
    let onHome: (() -> Void)?
    /// Finish screen "Next": on to another game in the host app. Nil hides the button.
    let onNextGame: (() -> Void)?

    init(
        player: PathCharacter? = nil,
        onExit: (() -> Void)? = nil,
        onHome: (() -> Void)? = nil,
        onNextGame: (() -> Void)? = nil
    ) {
        self.player = player
        self.onExit = onExit
        self.onHome = onHome
        self.onNextGame = onNextGame
    }

    var body: some View {
        childPanel
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WhackAMolePalette.meadow.ignoresSafeArea())
            .overlay(alignment: .topLeading) {
                if let onExit {
                    Button(action: onExit) {
                        Label("Back", systemImage: "chevron.backward")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 28, weight: .heavy))
                            .frame(width: 56, height: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FoxPathPalette.accent)
                    .clipShape(Circle())
                    .padding(24)
                }
            }
            .navigationTitle("Follow the Fox")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $presentedScreen) { screen in
                switch screen {
                case .calibration:
                    GazeCalibrationView(
                        controller: gazeController,
                        onCalibrated: { presentedScreen = .gazeGame },
                        onCancel: {
                            gazeController.stop()
                            presentedScreen = nil
                        }
                    )
                case .gazeGame:
                    FoxPathGameView(
                        configuration: configuration,
                        input: .gaze(gazeController),
                        player: player,
                        onNextGame: onNextGame.map { next in { closeGame(then: next) } },
                        onHome: onHome.map { home in { closeGame(then: home) } }
                    ) {
                        closeGame()
                    }
                case .touchGame:
                    FoxPathGameView(
                        configuration: configuration,
                        input: .touch,
                        player: player,
                        onNextGame: onNextGame.map { next in { closeGame(then: next) } },
                        onHome: onHome.map { home in { closeGame(then: home) } }
                    ) {
                        closeGame()
                    }
                }
            }
    }

    /// Stops the camera, closes the game and, for Home or Next, hands over to the host app.
    private func closeGame(then destination: (() -> Void)? = nil) {
        gazeController.stop()
        presentedScreen = nil
        destination?()
    }

    // MARK: - Content

    private var childPanel: some View {
        VStack(spacing: 28) {
            HStack(alignment: .bottom, spacing: 18) {
                ForEach(player.map { [$0] } ?? PathCharacter.allCases) { character in
                    Image(character.standingAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 190)
                }
            }
            .accessibilityHidden(true)

            Text("Follow your friend to the veggie stall and keep its veggies safe from the thief!")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(FoxPathPalette.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)

            Label("2 minutes · 3 hearts", systemImage: "heart.fill")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(FoxPathPalette.heart)

            Button {
                presentedScreen = .calibration
            } label: {
                Label("Calibrate & Play", systemImage: "eye.fill")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .frame(minWidth: 280, minHeight: 84)
            }
            .buttonStyle(.borderedProminent)
            .tint(FoxPathPalette.accent)
            .clipShape(Capsule())

            Button {
                presentedScreen = .touchGame
            } label: {
                Label("Practice with a finger", systemImage: "hand.point.up.left.fill")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .frame(minWidth: 240, minHeight: 52)
            }
            .buttonStyle(.bordered)
            .tint(FoxPathPalette.ink)
            .clipShape(Capsule())
        }
        .padding(32)
    }
}
