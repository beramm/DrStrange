import SwiftUI

/// Entry screen for the game: a big level picker for the child and a settings panel for adults.
struct WhackAMoleSetupView: View {
    @State private var configuration = ConfigurationStore.standard.load()
    @State private var isPlaying = false
    @State private var showsGlassesCheck = false

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
        .fullScreenCover(isPresented: $isPlaying) {
            WhackAMoleGameView(configuration: configuration) { isPlaying = false }
        }
        .sheet(isPresented: $showsGlassesCheck) {
            GlassesCheckView(therapy: configuration.therapy)
        }
    }

    // MARK: - Child panel

    private var childPanel: some View {
        VStack(spacing: 32) {
            Image(FoxHammerView.assetName(1))
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
                isPlaying = true
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .frame(minWidth: 280, minHeight: 84)
            }
            .buttonStyle(.borderedProminent)
            .tint(WhackAMolePalette.accent)
            .clipShape(Capsule())
        }
        .padding(32)
    }

    // MARK: - Adult settings

    private var settingsPanel: some View {
        Form {
            Section {
                Picker("Session length", selection: $configuration.sessionDuration) {
                    ForEach(GameConfiguration.sessionDurationOptions, id: \.self) { seconds in
                        Text("\(Int(seconds / 60)) min").tag(seconds)
                    }
                }
                Toggle("Adjust level from performance", isOn: $configuration.adaptiveDifficulty.isEnabled)
                Toggle("Sound", isOn: $configuration.soundEnabled)
                Toggle("Haptics", isOn: $configuration.hapticsEnabled)
            } header: {
                Text("For grown-ups")
            } footer: {
                ClinicalNote("Session length and frequency should follow your eye-care professional's advice.")
            }

            Section {
                Picker("Display", selection: $configuration.therapy.viewingMode) {
                    ForEach(ViewingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                if configuration.therapy.viewingMode == .anaglyph {
                    Picker("Red filter on", selection: $configuration.therapy.glasses.redFilterEye) {
                        ForEach(Eye.allCases) { eye in Text(eye.title).tag(eye) }
                    }
                    Button("Check glasses") { showsGlassesCheck = true }
                }
            } header: {
                Text("Viewing")
            } footer: {
                Text(configuration.therapy.viewingMode == .standard
                     ? "Without glasses both eyes see the same picture. This mode is for getting to know the game; it is not dichoptic."
                     : "Each character's outline goes to one eye and its face and star to the other, so both eyes are needed to play.")
            }

            if configuration.therapy.viewingMode == .anaglyph {
                therapySection
            }
        }
        .scrollContentBackground(.hidden)
        .background(WhackAMolePalette.cream.opacity(0.6))
    }

    private var therapySection: some View {
        Section {
            Picker("Amblyopic eye", selection: $configuration.therapy.amblyopicEye) {
                Text("Not set").tag(Eye?.none)
                ForEach(Eye.allCases) { eye in Text(eye.title).tag(Eye?.some(eye)) }
            }
            if configuration.therapy.amblyopicEye != nil {
                ContrastSlider(title: "Amblyopic eye contrast", value: $configuration.therapy.amblyopicEyeContrast)
                ContrastSlider(title: "Fellow eye contrast", value: $configuration.therapy.fellowEyeContrast)
                ContrastSlider(title: "Faces shown to amblyopic eye", value: $configuration.therapy.criticalFeatureAmblyopicShare)
            }
        } header: {
            Text("Clinical settings")
        } footer: {
            ClinicalNote("Enter these only as directed by an ophthalmologist or orthoptist. The app never decides which eye is amblyopic, and the defaults (100 % contrast, 50 % share) are neutral placeholders, not treatment values.")
        }
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

private struct ContrastSlider: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(value.formatted(.percent.precision(.fractionLength(0))))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: 0.1...1, step: 0.05)
        }
    }
}

private struct ClinicalNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label(text, systemImage: "stethoscope")
    }
}
