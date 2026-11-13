import SwiftUI

/// Entry screen for the game: the high score and a big Play button for the child, and a panel
/// for the adult with the patching session record and game options.
struct GameHomeView: View {
    private enum PresentedScreen: String, Identifiable {
        case calibration
        case game

        var id: String { rawValue }
    }

    @State private var configuration = ConfigurationStore.standard.load()
    @State private var gazeController = GazeInputController()
    @State private var presentedScreen: PresentedScreen?
    @State private var showsPatchingSetup = false
    @State private var highScore = HighScoreStore.standard.best

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            childPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            settingsPanel
                .frame(width: 440)
        }
        .background(WhackAMolePalette.meadow.ignoresSafeArea())
        .navigationTitle("Whack-a-Mole")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: configuration) { _, newValue in
            ConfigurationStore.standard.save(newValue)
        }
        .fullScreenCover(item: $presentedScreen) { screen in
            switch screen {
            case .calibration:
                GazeCalibrationView(
                    controller: gazeController,
                    onCalibrated: { presentedScreen = .game },
                    onCancel: { presentedScreen = nil }
                )
            case .game:
                WhackAMoleGameView(configuration: configuration, gazeController: gazeController) {
                    gazeController.stop()
                    highScore = HighScoreStore.standard.best
                    presentedScreen = nil
                }
            }
        }
        .sheet(isPresented: $showsPatchingSetup) {
            PatchingSetupView(configuration: $configuration)
        }
    }

    // MARK: - Child panel

    private var childPanel: some View {
        VStack(spacing: 32) {
            Image(FoxCharacterView.assetName(1))
                .resizable()
                .scaledToFit()
                .frame(height: 200)
                .accessibilityHidden(true)

            HighScoreBadge(score: highScore)

            Button {
                presentedScreen = .calibration
            } label: {
                Label("Calibrate & Play", systemImage: "eye.fill")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .frame(minWidth: 280, minHeight: 84)
            }
            .buttonStyle(.borderedProminent)
            .tint(WhackAMolePalette.accent)
            .clipShape(Capsule())
        }
        .padding(32)
    }

    // MARK: - Adult panel

    private var settingsPanel: some View {
        Form {
            Section {
                LabeledContent("Patched eye", value: configuration.patching.patchedEye?.title ?? "Not recorded")
                LabeledContent("Playing eye", value: configuration.patching.playingEye?.title ?? "Not recorded")
                if !configuration.patching.isConsistent {
                    Label("The same eye is set as patched and playing.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Button("Set up patching session") { showsPatchingSetup = true }
            } header: {
                Text("Patching session (for grown-ups)")
            } footer: {
                ClinicalNote("Which eye to patch and for how long follow your child's eye doctor. The app only records what you enter.")
            }

            Section {
                LabeledContent("Game length", value: "\(Int(GameConfiguration.sessionDuration / 60)) min")
                Toggle("Sound", isOn: $configuration.soundEnabled)
                Toggle("Haptics", isOn: $configuration.hapticsEnabled)
            } header: {
                Text("Game")
            } footer: {
                Text("Every game lasts 2 minutes of play. This is the length of one round, not a recommended patching or play time.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(WhackAMolePalette.cream.opacity(0.6))
    }
}

/// The best score on this device, or a friendly prompt before the first game.
private struct HighScoreBadge: View {
    let score: Int

    var body: some View {
        VStack(spacing: 6) {
            Text("High score")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.secondary)
            Label {
                Text(score > 0 ? "\(score)" : "–")
                    .monospacedDigit()
            } icon: {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(WhackAMolePalette.star)
            }
            .font(.system(size: 48, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(WhackAMolePalette.ink)
        .frame(minWidth: 280, minHeight: 130)
        .padding(.horizontal, 24)
        .background(RoundedRectangle(cornerRadius: 24).fill(WhackAMolePalette.cream))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(score > 0 ? "High score \(score)" : "No high score yet")
    }
}

struct ClinicalNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label(text, systemImage: "stethoscope")
    }
}
