import SwiftUI

/// Entry screen for Follow the Fox: a big level picker for the child and a panel with game
/// options for the adult.
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

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            childPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            settingsPanel
                .frame(width: 440)
        }
        .background(WhackAMolePalette.meadow.ignoresSafeArea())
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
                FoxPathGameView(configuration: configuration, input: .gaze(gazeController)) {
                    gazeController.stop()
                    presentedScreen = nil
                }
            case .touchGame:
                FoxPathGameView(configuration: configuration, input: .touch) {
                    presentedScreen = nil
                }
            }
        }
    }

    // MARK: - Child panel

    private var childPanel: some View {
        VStack(spacing: 28) {
            Image(FoxWalkAnimation.standingAsset)
                .resizable()
                .scaledToFit()
                .frame(height: 210)
                .accessibilityHidden(true)

            Text("Keep your eyes on the fox all the way to the veggie stall")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(FoxPathPalette.ink)
                .multilineTextAlignment(.center)

            HStack(spacing: 20) {
                ForEach(DifficultyLevel.allCases) { level in
                    LevelCard(level: level, isSelected: configuration.level == level) {
                        configuration.level = level
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
                Text("Each game draws a new path with new houses and lamps. Pinch the map or use the magnifier buttons to zoom.")
            }

            Section {
                LabeledContent("Fox speed", value: speedText)
                LabeledContent("Look-away allowance", value: String(format: "%.2f s", settings.lookAwayGrace))
                LabeledContent("Time to refocus", value: String(format: "%.2f s", settings.refocusDwell))
            } header: {
                Text("\(configuration.level.title) level (for grown-ups)")
            } footer: {
                ClinicalNote("Follow the Fox is a game. It does not diagnose, measure or treat vision, and its levels are game settings that still need clinical review. Patching and play time follow your child's eye doctor.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(WhackAMolePalette.cream.opacity(0.6))
    }

    private var settings: FoxPathSettings { configuration.settings(for: configuration.level) }

    private var speedText: String {
        String(format: "%.1f tiles/s", settings.foxSpeed / Double(FoxPathMetrics.cellSize.width))
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
                .foregroundStyle(FoxPathPalette.star)
                Text(level.title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(FoxPathPalette.ink)
            }
            .frame(width: 170, height: 130)
            .background(RoundedRectangle(cornerRadius: 24).fill(FoxPathPalette.cream))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(isSelected ? FoxPathPalette.accent : .clear, lineWidth: 5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(level.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
