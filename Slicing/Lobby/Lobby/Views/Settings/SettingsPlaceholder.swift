//
//  SettingsPlaceholder.swift
//  Temporary settings screen. Replace when you build it.
//

import SwiftUI

struct SettingsPlaceholder: View {
    @AppStorage(MiniGame.randomSpinEnabledStorageKey) private var randomSpinEnabled = true

    #if canImport(DrStrangeGazeTracker)
    @State private var configuration = ConfigurationStore.standard.load()
    #endif

    var body: some View {
        // TODO: put this behind a parental gate (e.g. "hold for 3 seconds").
        Form {
            Section("Language") { Text("Bahasa Indonesia / English") }
            Section("Text size") { Text("Normal / Large") }
            Section("Voice") { Text("On / Off") }

            Section {
                Toggle("Random game spin", isOn: $randomSpinEnabled)
            } header: {
                Text("Game selection")
            } footer: {
                Text(randomSpinEnabled
                     ? "The game map spins and chooses a game automatically."
                     : "The game map stays still so you can choose a game directly.")
            }

            #if canImport(DrStrangeGazeTracker)
            Section {
                Toggle("One-eye enforcer", isOn: $configuration.oneEyeEnforcerEnabled)
            } header: {
                Text("Gaze testing")
            } footer: {
                Text("Turn this off to calibrate and play with both eyes visible. Patch-loss pauses will also be disabled.")
            }
            #endif
        }
        .navigationTitle("Settings")
        #if canImport(DrStrangeGazeTracker)
        .onChange(of: configuration) { _, newValue in
            ConfigurationStore.standard.save(newValue)
        }
        #endif
    }
}
