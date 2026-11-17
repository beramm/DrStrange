import SwiftUI

/// Entry screen for Follow the Fox: the player's character (or all three friends in the standalone
/// app) and a big Play button for the child, and a panel with game options for the adult.
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
    /// The player's character from onboarding: always the one followed; the thief is one of the
    /// other two. Nil in the standalone app, where all three swap roles at random.
    let player: PathCharacter?

    init(player: PathCharacter? = nil, onExit: (() -> Void)? = nil) {
        self.player = player
        self.onExit = onExit
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            childPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            settingsPanel
                .frame(width: 440)
        }
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
        .onChange(of: configuration) { _, newValue in
            FoxPathConfigurationStore.standard.save(newValue)
        }
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
                FoxPathGameView(configuration: configuration, input: .gaze(gazeController), player: player) {
                    gazeController.stop()
                    presentedScreen = nil
                }
            case .touchGame:
                FoxPathGameView(configuration: configuration, input: .touch, player: player) {
                    presentedScreen = nil
                }
            }
        }
    }

    // MARK: - Child panel

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

    // MARK: - Adult panel

    private var settingsPanel: some View {
        Form {
            Section {
                Toggle("Sound", isOn: $configuration.soundEnabled)
                Toggle("Haptics", isOn: $configuration.hapticsEnabled)
                Toggle("Show where the eyes point", isOn: $configuration.showsGazeMarker)
            } header: {
                Text("Game")
            } footer: {
                Text(player == nil
                     ? "Every path is new, and the fox, the bunny and the raccoon swap roles at random. Pinch the map or use the magnifier buttons to zoom."
                     : "Every path is new. The child follows their own character; the thief is one of the other two. Pinch the map or use the magnifier buttons to zoom.")
            }

            Section {
                LabeledContent("Game length", value: "\(Int(FoxPathConfiguration.sessionDuration / 60)) min")
                LabeledContent("Hearts", value: "\(FoxPathConfiguration.initialLives)")
                LabeledContent("Walking speed", value: speedText)
                LabeledContent("Look-away allowance", value: String(format: "%.2f s", settings.lookAwayGrace))
                LabeledContent("Time to refocus", value: String(format: "%.2f s", settings.refocusDwell))
            } header: {
                Text("How the game works (for grown-ups)")
            } footer: {
                ClinicalNote("Follow the Fox is a game. It does not diagnose, measure or treat vision, and these are game settings that still need clinical review. The 2 minutes are one game, not a recommended play time. Patching and play time follow your child's eye doctor.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(WhackAMolePalette.cream.opacity(0.6))
    }

    private var settings: FoxPathSettings { configuration.settings }

    private var speedText: String {
        String(format: "%.1f tiles/s", settings.foxSpeed / Double(FoxPathMetrics.cellSize.width))
    }
}
