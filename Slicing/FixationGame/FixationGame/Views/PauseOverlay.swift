//
//  PauseOverlay.swift
//  Pause screen, same as Whack-a-Mole's: resume, or stop and rest when the
//  child's eyes are tired or uncomfortable.
//

import SwiftUI

struct PauseOverlay: View {
    let onResume: () -> Void
    let onRest: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accent)
                    .accessibilityHidden(true)
                Text("Paused")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ink)
                HStack(spacing: 20) {
                    Button(action: onRest) {
                        Label("Rest my eyes", systemImage: "moon.zzz.fill")
                            .frame(minWidth: 200, minHeight: 56)
                    }
                    .buttonStyle(.bordered)
                    Button(action: onResume) {
                        Label("Play", systemImage: "play.fill")
                            .frame(minWidth: 180, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accent)
                }
                .font(.title2.weight(.bold))
            }
            .padding(48)
            .background(RoundedRectangle(cornerRadius: 36).fill(Color.cream))
        }
    }
}
