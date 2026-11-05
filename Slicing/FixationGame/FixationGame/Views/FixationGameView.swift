//
//  FixationGameView.swift
//  Fixation game prototype: guard the vegetable stall.
//  A finger on the screen stands in for the eye tracker for now.
//

import SwiftUI

struct FixationGameView: View {
    private enum Phase { case waiting, playing, won, lost }

    private let startingLives = 3
    private let guardSeconds = 30
    private let thiefSeconds = 2.0
    private let vegetables = ["🥕", "🥦", "🍅"]

    /// True while the child is guarding the stall.
    /// TODO: replace the finger with the real gaze check from ARKit.
    @GestureState private var isWatching = false

    @State private var phase = Phase.waiting
    @State private var lives = 3
    @State private var secondsLeft = 30
    @State private var thiefIsHere = false

    var body: some View {
        ZStack {
            GameBackground()

            // Invisible layer that fills the screen and feels the finger.
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isWatching) { _, state, _ in state = true }
                )

            VStack(spacing: 32) {
                statusBar
                stall
                hint
            }
            .padding(48)
            .allowsHitTesting(false)

            if phase == .won || phase == .lost {
                endScreen
            }
        }
        // Runs again each time the finger goes down or lifts up.
        .task(id: isWatching) {
            try? await updateGame()
        }
    }

    private var statusBar: some View {
        HStack {
            HStack(spacing: 12) {
                ForEach(0..<startingLives, id: \.self) { index in
                    Image(systemName: index < lives ? "heart.fill" : "heart")
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            Label("\(secondsLeft)", systemImage: "clock.fill")
                .foregroundStyle(Color.ink)
                .monospacedDigit()
        }
        .font(.system(size: 44, weight: .bold, design: .rounded))
    }

    private var stall: some View {
        HStack(spacing: 24) {
            ForEach(0..<lives, id: \.self) { index in
                Text(vegetables[index])
                    .font(.system(size: 90))
            }
        }
        .frame(width: 420, height: 180)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.cardFill))
        // An overlay, so the stall stays still when the thief shows up.
        .overlay(alignment: .leading) {
            if thiefIsHere {
                Text("🦝")
                    .font(.system(size: 120))
                    .offset(x: -180)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var hint: some View {
        Image(systemName: isWatching ? "hand.point.up.left.fill" : "hand.point.up.left")
            .font(.system(size: 60))
            .foregroundStyle(Color.ink)
    }

    private var endScreen: some View {
        VStack(spacing: 32) {
            Text(phase == .won ? "🎉" : "🦝")
                .font(.system(size: 120))

            Button(action: restart) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 120)
                    .background(RoundedRectangle(cornerRadius: 32).fill(Color.playGreen))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.skyBottom)
    }

    /// Finger down: count down to a win. Finger up: send the thief.
    /// Sleeping throws an error when the finger changes, which stops this run.
    private func updateGame() async throws {
        thiefIsHere = false

        if isWatching && phase == .waiting {
            phase = .playing
        }
        guard phase == .playing else { return }

        if isWatching {
            while secondsLeft > 0 {
                try await Task.sleep(for: .seconds(1))
                secondsLeft -= 1
            }
            phase = .won
        } else {
            while lives > 0 {
                thiefIsHere = true
                try await Task.sleep(for: .seconds(thiefSeconds))
                lives -= 1
            }
            thiefIsHere = false
            phase = .lost
        }
    }

    private func restart() {
        lives = startingLives
        secondsLeft = guardSeconds
        thiefIsHere = false
        phase = .waiting
    }
}

#Preview("Fixation game", traits: .landscapeLeft) {
    FixationGameView()
}
