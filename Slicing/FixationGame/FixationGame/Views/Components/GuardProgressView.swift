//
//  GuardProgressView.swift
//  Top-bar time bar: fills up while the child guards the stall, with the time left.
//  Same look as Veggie Dash's time bar.
//

import SwiftUI

struct GuardProgressView: View {
    /// 0 at the start, 1 when the stall has been guarded long enough.
    let progress: Double
    let secondsLeft: Int

    var body: some View {
        HStack(spacing: 16) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    // Outlined so the track stays visible over the sky.
                    Capsule()
                        .fill(.white.opacity(0.85))
                        .overlay(Capsule().stroke(FixationPalette.ink.opacity(0.35), lineWidth: 2.5))
                    Capsule()
                        .fill(FixationPalette.ink.opacity(0.55))
                        .frame(width: max(proxy.size.height, proxy.size.width * progress))
                        .animation(.linear(duration: 0.2), value: progress)
                }
            }
            .frame(height: 26)

            Text(String(format: "%d:%02d", secondsLeft / 60, secondsLeft % 60))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(secondsLeft <= 10 ? Color(red: 0.86, green: 0.2, blue: 0.1) : FixationPalette.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time left")
        .accessibilityValue("\(secondsLeft) seconds")
    }
}
