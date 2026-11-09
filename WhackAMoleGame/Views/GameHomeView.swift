import SwiftUI

/// Entry screen for the game: a big level picker for the child and a panel for the adult
/// with the patching session record and game options.
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
        .onAppear {
            gazeController.setOneEyeEnforcerEnabled(configuration.oneEyeEnforcerEnabled)
        }
        .onChange(of: configuration.oneEyeEnforcerEnabled) { _, enabled in
            gazeController.setOneEyeEnforcerEnabled(enabled)
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

            HStack(spacing: 20) {
                ForEach(DifficultyLevel.allCases) { level in
                    LevelCard(level: level, isSelected: configuration.startingLevel == level) {
                        configuration.startingLevel = level
                    }
                }
            }

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
                LabeledContent("Session length", value: "\(Int(configuration.sessionDuration / 60)) min")
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

            Section("Game") {
                Toggle("Adjust level from performance", isOn: $configuration.adaptiveDifficulty.isEnabled)
                Toggle("Sound", isOn: $configuration.soundEnabled)
                Toggle("Haptics", isOn: $configuration.hapticsEnabled)
            }

            Section {
                Toggle("One-eye enforcer", isOn: $configuration.oneEyeEnforcerEnabled)
            } header: {
                Text("Gaze testing")
            } footer: {
                Text("Testing only. Turn this off to calibrate and play with both eyes visible. Patch-loss pauses will also be disabled.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(WhackAMolePalette.cream.opacity(0.6))
    }
}

private struct LevelCard: View {
    let level: DifficultyLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(0..<level.rawValue, id: \.self) { _ in
                        Image(systemName: "star.fill")
                    }
                }
                .font(.title)
                .foregroundStyle(WhackAMolePalette.star)
                Text(level.title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(WhackAMolePalette.ink)
            }
            .frame(width: 170, height: 130)
            .background(RoundedRectangle(cornerRadius: 24).fill(WhackAMolePalette.cream))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(isSelected ? WhackAMolePalette.accent : .clear, lineWidth: 5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(level.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
