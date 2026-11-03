//
//  CharacterCard.swift
//  Character image + name plate. Tap the name plate to rename.
//

import SwiftUI

struct CharacterCard: View {
    @Binding var name: String
    let imageName: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBobbing = false
    @State private var isWiggling = false
    @State private var isEditingName = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(Color.cardFill)
                    .shadow(color: .black.opacity(0.12), radius: 14, y: 8)

                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .offset(y: isBobbing ? -8 : 8)
                    .rotationEffect(.degrees(isWiggling ? -8 : 0))
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .contentShape(Rectangle())
            .onTapGesture(perform: wiggle)

            // Name plate: tap to rename
            Button {
                isEditingName = true
            } label: {
                HStack(spacing: 12) {
                    Text(name)
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Image(systemName: "pencil")
                        .font(.system(size: 24, weight: .bold))
                }
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.namePlate))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $isEditingName) {
            NameEditSheet(name: $name)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                isBobbing = true
            }
        }
    }

    /// Small happy reaction when the child taps the character.
    private func wiggle() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) { isWiggling = true }
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { isWiggling = false }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    CharacterCard(name: .constant("Kiko"), imageName: Buddy.imageName)
        .frame(width: 360)
        .padding()
}
