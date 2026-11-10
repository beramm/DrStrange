//
//  GuardProgressView.swift
//  Top-bar time bar: fills up while the child guards the stall, with the time left.
//  Same look as Whack-a-Mole's session progress bar.
//

import SwiftUI

struct GuardProgressView: View {
    /// 0 at the start, 1 when the stall has been guarded long enough.
    let progress: Double
    let secondsLeft: Int

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.7))
                    Capsule()
                        .fill(Color.ink.opacity(0.55))
                        .frame(width: max(proxy.size.height, proxy.size.width * progress))
                        .animation(.linear(duration: 0.2), value: progress)
                }
            }
            .frame(height: 18)

            Text(String(format: "%d:%02d", secondsLeft / 60, secondsLeft % 60))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time left")
        .accessibilityValue("\(secondsLeft) seconds")
    }
}
