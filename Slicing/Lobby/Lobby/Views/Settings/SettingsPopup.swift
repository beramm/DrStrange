//
//  SettingsPopup.swift
//  The Settings pop-up, from the final design: a faded brown layer over the
//  screen, with the Settings card on top.
//
//  Changes are only kept when the player taps SAVE. The X closes the card and
//  forgets the changes.
//
//  Positions are fractions (0–1) of the card picture's width and height,
//  so the card looks the same at every size.
//

import SwiftUI

struct SettingsPopup: View {
    let onClose: () -> Void

    @AppStorage(AppSettings.languageKey) private var savedLanguage = AppLanguage.english
    @AppStorage(AppSettings.backgroundVolumeKey) private var savedBackgroundVolume = 1.0
    @AppStorage(AppSettings.soundEffectsVolumeKey) private var savedSoundEffectsVolume = 1.0
    @AppStorage(AppSettings.wearsEyePatchKey) private var savedWearsEyePatch = true

    // The choices on the card, before they are saved.
    @State private var language = AppLanguage.english
    @State private var backgroundVolume = 1.0
    @State private var soundEffectsVolume = 1.0
    @State private var wearsEyePatch = true

    /// Width ÷ height of the card picture.
    private let cardAspect: CGFloat = 1933 / 1405

    var body: some View {
        GeometryReader { geo in
            // As big as fits: at most 70% of the screen width and 90% of its height.
            let width = min(geo.size.width * 0.7, geo.size.height * 0.9 * cardAspect)
            let height = width / cardAspect

            ZStack {
                // Faded brown layer. It catches taps, so the screen behind can't be used.
                Color.popupShade
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {}
                    .accessibilityHidden(true)

                card(width: width, height: height)
                    .frame(width: width, height: height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .onAppear(perform: loadSaved)
    }

    private func card(width w: CGFloat, height h: CGFloat) -> some View {
        let pillHeight = h * 0.075

        return ZStack(alignment: .topLeading) {
            Image("SettingsCard")
                .resizable()
                .accessibilityHidden(true)

            Text("Settings")
                .textCase(.uppercase)
                .doodleText(size: h * 0.115)
                .foregroundStyle(Color.pillOutline)
                .position(x: w * 0.5, y: h * 0.105)
                .accessibilityAddTraits(.isHeader)

            Button(action: cancel) {
                Image("ButtonClose")
                    .resizable()
                    .scaledToFit()
                    .frame(width: w * 0.085)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Close")
            .position(x: w * 0.9, y: h * 0.11)

            row("Language", y: 0.25, width: w, height: h) {
                ChoicePill(title: "English", isChosen: language == .english, width: w * 0.19, height: pillHeight) {
                    language = .english
                }
                ChoicePill(title: "Bahasa", isChosen: language == .bahasa, width: w * 0.19, height: pillHeight) {
                    language = .bahasa
                }
            }

            row("Background sound", y: 0.39, width: w, height: h) {
                VolumeSlider(value: $backgroundVolume, width: w * 0.34, height: pillHeight)
                    // Hear the music change while sliding.
                    .onChange(of: backgroundVolume) { _, volume in
                        BackgroundMusicPlayer.shared.setVolume(volume)
                    }
            }

            row("Sound effect", y: 0.53, width: w, height: h) {
                VolumeSlider(value: $soundEffectsVolume, width: w * 0.34, height: pillHeight) {
                    // A sample sound at the new volume when the finger lets go.
                    SoundEffectPlayer.shared.play(.button)
                }
                .onChange(of: soundEffectsVolume) { _, volume in
                    SoundEffectPlayer.shared.setVolume(volume)
                }
            }

            // Testing option: NO lets someone play with both eyes open.
            row("Wearing eye patch", y: 0.67, width: w, height: h) {
                ChoicePill(title: "Yes", isChosen: wearsEyePatch, width: w * 0.115, height: pillHeight) {
                    wearsEyePatch = true
                }
                ChoicePill(title: "No", isChosen: !wearsEyePatch, width: w * 0.115, height: pillHeight) {
                    wearsEyePatch = false
                }
            }

            Button(action: save) {
                Image("ButtonBoard")
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        Text("Save")
                            .textCase(.uppercase)
                            .doodleText(size: h * 0.068)
                            .foregroundStyle(Color.signText)
                            // The board's thick bottom edge: lift the word a little.
                            .offset(y: -h * 0.008)
                    }
                    .frame(width: w * 0.25)
            }
            .buttonStyle(PressableButtonStyle())
            .position(x: w * 0.5, y: h * 0.84)
        }
    }

    /// One setting: its name on the left, its choices on the right.
    private func row<Choices: View>(
        _ title: LocalizedStringKey,
        y: CGFloat,
        width w: CGFloat,
        height h: CGFloat,
        @ViewBuilder choices: () -> Choices
    ) -> some View {
        HStack(spacing: w * 0.015) {
            Text(title)
                .textCase(.uppercase)
                .font(.daysOne(h * 0.042))
                .foregroundStyle(Color.pillOutline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: w * 0.02)
            choices()
        }
        .accessibilityElement(children: .contain)
        .frame(width: w * 0.86)
        .position(x: w * 0.5, y: h * y)
    }

    /// Shows the saved settings on the card.
    private func loadSaved() {
        language = savedLanguage
        backgroundVolume = savedBackgroundVolume
        soundEffectsVolume = savedSoundEffectsVolume
        wearsEyePatch = savedWearsEyePatch
        #if canImport(DrStrangeGazeTracker)
        // Keep the old Whack-a-Mole preference only until a global choice is saved.
        wearsEyePatch = AppSettings.wearsEyePatch(
            fallback: ConfigurationStore.standard.load().oneEyeEnforcerEnabled
        )
        #endif
    }

    /// Keeps the choices on the card, then closes it.
    /// X: forgets the changes, and puts the volumes back to the saved ones.
    private func cancel() {
        BackgroundMusicPlayer.shared.setVolume(savedBackgroundVolume)
        SoundEffectPlayer.shared.setVolume(savedSoundEffectsVolume)
        onClose()
    }

    private func save() {
        savedLanguage = language
        savedBackgroundVolume = backgroundVolume
        savedSoundEffectsVolume = soundEffectsVolume
        savedWearsEyePatch = wearsEyePatch
        #if canImport(DrStrangeGazeTracker)
        // Whack-a-Mole's patch check ("one-eye enforcer") follows the eye patch choice.
        var configuration = ConfigurationStore.standard.load()
        configuration.oneEyeEnforcerEnabled = wearsEyePatch
        ConfigurationStore.standard.save(configuration)
        #endif
        onClose()
    }
}

#Preview(traits: .landscapeLeft) {
    ZStack {
        LobbyScenery()
        SettingsPopup(onClose: {})
    }
}
