import SwiftUI

/// Optional patching session record, filled in by a parent or caregiver.
///
/// Documentation only: the game plays the same whichever eye is patched. The app does not decide
/// which eye is amblyopic, does not check the patch, and does not recommend wear or play time.
struct PatchingSetupView: View {
    @Binding var configuration: GameConfiguration

    @Environment(\.dismiss) private var dismiss

    private var sessionMinutes: Binding<Int> {
        Binding(
            get: { Int(configuration.sessionDuration / 60) },
            set: { configuration.sessionDuration = TimeInterval($0 * 60) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Patched eye", selection: $configuration.patching.patchedEye) {
                        Text("Not recorded").tag(Eye?.none)
                        ForEach(Eye.allCases) { eye in Text(eye.title).tag(Eye?.some(eye)) }
                    }
                    Picker("Playing eye", selection: $configuration.patching.playingEye) {
                        Text("Not recorded").tag(Eye?.none)
                        ForEach(Eye.allCases) { eye in Text(eye.title).tag(Eye?.some(eye)) }
                    }
                    if !configuration.patching.isConsistent {
                        Label("The same eye is set as patched and playing. Please check.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Eye patch")
                } footer: {
                    Text("Enter the eyes as your child's eye doctor prescribed. This is saved with each session for your records; the game itself is the same for either eye.")
                }

                Section {
                    Stepper(value: sessionMinutes, in: GameConfiguration.sessionMinutesRange) {
                        LabeledContent("Session length", value: "\(sessionMinutes.wrappedValue) min")
                    }
                } header: {
                    Text("Prescribed session duration")
                } footer: {
                    Text("Enter the play time advised by your child's eye doctor. The app does not recommend how long to patch or play. Start and end times are recorded automatically.")
                }

                Section("For parents and caregivers") {
                    GuidanceRow(systemImage: "eye.slash", text: "Put the patch on the eye your child's eye doctor told you to cover before pressing Play.")
                    GuidanceRow(systemImage: "person.2", text: "Stay nearby while your child plays and check the patch stays in place. The app cannot check this.")
                    GuidanceRow(systemImage: "moon.zzz", text: "Stop if your child has sore or tired eyes, a headache, or skin irritation from the patch. Pause the game and choose Rest my eyes.")
                    GuidanceRow(systemImage: "stethoscope", text: "Game time is not a replacement for prescribed patching hours or check-ups. Ask the eye doctor if you are unsure.")
                    GuidanceRow(systemImage: "chart.bar", text: "Scores show how the game went. They are not an eye test.")
                }
            }
            .navigationTitle("Patching session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct GuidanceRow: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(WhackAMolePalette.accent)
        }
    }
}
