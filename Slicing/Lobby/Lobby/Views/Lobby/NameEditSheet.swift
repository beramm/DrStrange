//
//  NameEditSheet.swift
//  Pop-up where the child types a new name for the character.
//

import SwiftUI

struct NameEditSheet: View {
    @Binding var name: String

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    /// The typed name without spaces at the start or end.
    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 32) {
            Text("What's my name?")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.ink)

            TextField("Name", text: $draft)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isFocused)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 24).fill(Color.namePlate.opacity(0.4)))
                .onChange(of: draft) { _, newValue in
                    // Keep the name short enough to fit the name plate.
                    if newValue.count > Buddy.maxNameLength {
                        draft = String(newValue.prefix(Buddy.maxNameLength))
                    }
                }
                .onSubmit(save)

            HStack(spacing: 20) {
                KidButton(title: "Cancel", systemImage: "xmark", kind: .secondary) {
                    dismiss()
                }
                KidButton(title: "Save", systemImage: "checkmark", kind: .primary) {
                    save()
                }
                .disabled(trimmedDraft.isEmpty)
                .opacity(trimmedDraft.isEmpty ? 0.4 : 1)
            }
        }
        .padding(48)
        .onAppear {
            draft = name
            isFocused = true
        }
    }

    private func save() {
        guard !trimmedDraft.isEmpty else { return }
        name = trimmedDraft
        dismiss()
    }
}

#Preview {
    NameEditSheet(name: .constant("Kiko"))
}
