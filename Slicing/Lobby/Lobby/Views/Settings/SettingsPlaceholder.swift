//
//  SettingsPlaceholder.swift
//  Temporary settings screen. Replace when you build it.
//

import SwiftUI

struct SettingsPlaceholder: View {
    var body: some View {
        // TODO: put this behind a parental gate (e.g. "hold for 3 seconds").
        Form {
            Section("Language") { Text("Bahasa Indonesia / English") }
            Section("Text size") { Text("Normal / Large") }
            Section("Voice") { Text("On / Off") }
        }
        .navigationTitle("Settings")
    }
}
