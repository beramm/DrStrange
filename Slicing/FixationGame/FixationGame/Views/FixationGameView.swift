//
//  FixationGameView.swift
//  Veggie Keeper (fixation game) prototype: guard the vegetable stall.
//  Styled like the Whack-a-Mole game (meadow background, top bar, pause and end screens).
//
//  For now a finger on the screen stands in for the eye tracker:
//  holding = watching the stall, lifting = looking away, so a thief comes.
//

import SwiftUI

struct FixationGameView: View {
    private enum Phase: Equatable {
        case waiting                          // before the first hold
        case playing
        case paused
        case finished(stoppedEarly: Bool)
    }

    /// What `.task(id:)` watches: the game logic runs again whenever one of these changes.
    private struct GameState: Equatable {
        let isWatching: Bool
        let phase: Phase
    }

    private let totalVeggies = 3
    /// How long the stall must be guarded to finish.
    private let guardSeconds: Double = 30
    /// How long the thief needs to take one veggie.
    private let thiefSeconds: Double = 2

    /// True while the child is guarding the stall.
    /// TODO: replace the finger with the real gaze check from the gaze tracker.
    @GestureState private var isWatching = false

    @State private var phase = Phase.waiting
    @State private var veggiesLeft = 3
    @State private var guardedSeconds: Double = 0
    @State private var thiefIsHere = false
    @Environment(\.scenePhase) private var scenePhase

    private var secondsLeft: Int {
        Int((guardSeconds - guardedSeconds).rounded(.up))
    }

    var body: some View {
        ZStack {
            if case let .finished(stoppedEarly) = phase {
                GameResultView(
                    veggiesSaved: veggiesLeft,
                    totalVeggies: totalVeggies,
                    stoppedEarly: stoppedEarly,
                    onPlayAgain: restart
                )
                .transition(.opacity)
            } else {
                gameplay
            }
        }
        .animation(.easeInOut(duration: 0.3), value: phase)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        // Runs again each time the finger goes down or up, or the phase changes.
        .task(id: GameState(isWatching: isWatching, phase: phase)) {
            await updateGame()
        }
        // Pause when the app goes to the background.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && phase == .playing { phase = .paused }
        }
    }

    // MARK: - Gameplay screen

    private var gameplay: some View {
        ZStack {
            GameBackground()

            // Invisible layer that fills the screen and feels the finger.
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isWatching) { _, state, _ in state = true }
                )

            VStack(spacing: 0) {
                topBar
                Spacer()
                VeggieStallView(veggiesLeft: veggiesLeft, thiefIsHere: thiefIsHere)
                    .allowsHitTesting(false)
                Spacer()
            }

            prompt
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 96)
                .allowsHitTesting(false)

            if phase == .paused {
                PauseOverlay(
                    onResume: { phase = .playing },
                    onRest: { phase = .finished(stoppedEarly: true) }
                )
            }
        }
    }

    /// Exit, veggies left, time bar and pause, like Whack-a-Mole's top bar.
    private var topBar: some View {
        HStack(spacing: 20) {
            HUDButton(systemImage: "xmark", label: "Stop the game") {
                phase = .finished(stoppedEarly: true)
            }

            VeggiesLeftView(left: veggiesLeft, total: totalVeggies)

            GuardProgressView(progress: guardedSeconds / guardSeconds, secondsLeft: secondsLeft)
                .frame(maxWidth: .infinity)

            HUDButton(systemImage: "pause.fill", label: "Pause") {
                phase = .paused
            }
            .disabled(phase != .playing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    /// Reminder to hold the screen: before the game starts, and whenever the finger is lifted.
    @ViewBuilder
    private var prompt: some View {
        if phase == .waiting || (phase == .playing && !isWatching) {
            Label(phase == .waiting ? "Hold the screen to guard the stall" : "Keep holding!",
                  systemImage: "hand.point.up.left.fill")
                .font(.system(.title, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Capsule().fill(.white.opacity(0.85)))
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Game logic

    /// Finger down: the guard time fills up until the stall is safe.
    /// Finger up: the thief comes and takes a veggie every few seconds.
    /// Sleeping throws when the finger or the phase changes, which stops this run.
    private func updateGame() async {
        thiefIsHere = false

        if isWatching && phase == .waiting {
            phase = .playing      // this changes the task id, so the game logic runs again
            return
        }
        guard phase == .playing else { return }

        do {
            if isWatching {
                while guardedSeconds < guardSeconds {
                    try await Task.sleep(for: .milliseconds(100))
                    guardedSeconds = min(guardedSeconds + 0.1, guardSeconds)
                }
                phase = .finished(stoppedEarly: false)
            } else {
                while veggiesLeft > 0 {
                    thiefIsHere = true
                    try await Task.sleep(for: .seconds(thiefSeconds))
                    veggiesLeft -= 1
                }
                thiefIsHere = false
                phase = .finished(stoppedEarly: false)
            }
        } catch {
            // The finger changed or the game was paused; this run stops here.
        }
    }

    private func restart() {
        veggiesLeft = totalVeggies
        guardedSeconds = 0
        thiefIsHere = false
        phase = .waiting
    }
}

#Preview("Fixation game", traits: .landscapeLeft) {
    FixationGameView()
}
