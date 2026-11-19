//
//  VolumeSlider.swift
//  A volume slider for the Settings pop-up, drawn like the choice pills:
//  a rounded track with a dark brown outline that fills yellow up to the
//  round knob. A quiet speaker on the left, a loud one on the right.
//
//  Drag the knob, or tap anywhere on the track to jump there.
//

import SwiftUI

struct VolumeSlider: View {
    /// From 0 (silent) to 1 (full).
    @Binding var value: Double
    let width: CGFloat
    let height: CGFloat
    /// Called when the finger lets go, for example to play a sample sound.
    var onRelease: () -> Void = {}

    var body: some View {
        HStack(spacing: height * 0.2) {
            speaker("speaker.fill")
            track
            speaker("speaker.wave.3.fill")
        }
        .frame(width: width, height: height)
        // VoiceOver: swipe up or down to change the volume.
        .accessibilityElement()
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 0.1, 1)
            case .decrement: value = max(value - 0.1, 0)
            @unknown default: break
            }
        }
    }

    private func speaker(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: height * 0.4, weight: .bold))
            .foregroundStyle(Color.pillOutline)
            .accessibilityHidden(true)
    }

    private var track: some View {
        GeometryReader { geo in
            let knob = height
            let line = height * 0.065
            // How far the knob's centre can move.
            let travel = geo.size.width - knob

            ZStack(alignment: .leading) {
                // The track, filled yellow up to the knob.
                Capsule()
                    .fill(Color.pillYellow)
                    .frame(width: knob / 2 + travel * value + knob / 2)
                Capsule()
                    .strokeBorder(Color.pillOutline, lineWidth: line)

                // The knob.
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().strokeBorder(Color.pillOutline, lineWidth: line))
                    .frame(width: knob, height: knob)
                    .offset(x: travel * value)
            }
            .frame(height: knob)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let position = (drag.location.x - knob / 2) / travel
                        value = min(max(position, 0), 1)
                    }
                    .onEnded { _ in onRelease() }
            )
        }
        .frame(height: height)
    }
}

#Preview {
    @Previewable @State var volume = 0.6
    VolumeSlider(value: $volume, width: 320, height: 56)
        .padding()
        .background(Color.sky)
}
