//
//  FixationGameView.swift
//  Veggie Keeper (fixation game): guard the vegetable stall.
//  The picture comes from MarketSceneView; the top bar, pause and end screens
//  are styled like the Whack-a-Mole game.
//
//  "Watching the stall" comes from one of two inputs:
//  - Eye control: the gaze tracker's point is on the stall (after calibration).
//  - Finger (testing only, e.g. in the simulator): a finger is held on the screen.
//  Looking away (or lifting the finger) lets a thief come and take a veggie.
//

import DrStrangeGazeTracker
import SwiftUI

struct FixationGameView: View {
    /// The gaze tracker, already calibrated. nil = finger mode.
    let gaze: GazeInputController?
    /// The character who keeps the stall. The other two come to steal.
    let character: FixationCharacter
    /// Back to the start screen.
    let onExit: () -> Void

    private enum Phase: Equatable {
        case waiting                          // before the child first watches the stall
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
    /// Extra space around the stall that still counts as "looking at it".
    /// Kept small, so looking at a mole (beside the stall) counts as looking away.
    private let gazeMargin: CGFloat = 10
    /// Show where the tracker thinks the eye is looking (helpful while testing).
    private let showsGazeDot = true

    /// Finger mode: true while a finger is on the screen.
    @GestureState private var fingerIsDown = false
    /// Eye-control mode: true while the gaze point is on the stall.
    @State private var gazeIsOnStall = false
    /// Steadies the gaze point; the dot and the stall check both use its point.
    @State private var smoother = GazeSmoother()
    /// The stall's position on screen, used to check the gaze point.
    @State private var stallFrame: CGRect = .zero
    /// The full screen size, used to turn the 0–1 gaze point into screen points.
    @State private var screenSize: CGSize = .zero

    @State private var phase = Phase.waiting
    @State private var veggiesLeft = 3
    @State private var guardedSeconds: Double = 0
    @State private var thiefIsHere = false
    @Environment(\.scenePhase) private var scenePhase

    private var usesGaze: Bool { gaze != nil }

    /// True while the child is guarding the stall.
    private var isWatching: Bool {
        usesGaze ? gazeIsOnStall : fingerIsDown
    }

    /// The keeper sleeps while nobody watches the stall (also before the game starts).
    /// On the pause screen they stay awake.
    private var keeperIsAwake: Bool {
        (phase == .waiting || phase == .playing) ? isWatching : true
    }

    private var secondsLeft: Int {
        Int((guardSeconds - guardedSeconds).rounded(.up))
    }

    var body: some View {
        ZStack {
            if case let .finished(stoppedEarly) = phase {
                FixationGameResultView(
                    veggiesSaved: veggiesLeft,
                    totalVeggies: totalVeggies,
                    stoppedEarly: stoppedEarly,
                    onPlayAgain: restart,
                    onDone: onExit
                )
                .transition(.opacity)
            } else {
                gameplay
            }
        }
        .animation(.easeInOut(duration: 0.3), value: phase)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        // Runs again each time "watching" changes or the phase changes.
        .task(id: GameState(isWatching: isWatching, phase: phase)) {
            await updateGame()
        }
        // Check every new gaze sample against the stall.
        .onChange(of: gaze?.sample.timestamp) { _, _ in
            updateGazeOnStall()
        }
        // Pause the game (and the camera) when the app goes to the background.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                gaze?.resumeForActiveScene()
            } else {
                gaze?.pauseForInactiveScene()
                if phase == .playing { phase = .paused }
            }
        }
    }

    // MARK: - Gameplay screen

    private var gameplay: some View {
        ZStack {
            MarketSceneView(
                keeper: character,
                veggiesLeft: veggiesLeft,
                keeperIsAwake: keeperIsAwake,
                thiefIsHere: thiefIsHere,
                molesCanAppear: phase == .playing,
                onStallFrameChange: { stallFrame = $0 }
            )
            // The full screen, to place the gaze point.
            .onGeometryChange(for: CGSize.self) { $0.size } action: { screenSize = $0 }

            // Finger mode only: an invisible layer that fills the screen and feels the finger.
            if !usesGaze {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($fingerIsDown) { _, state, _ in state = true }
                    )
            }

            topBar
                .frame(maxHeight: .infinity, alignment: .top)

            prompt
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 96)
                .allowsHitTesting(false)

            if let gaze {
                gazeOverlay(gaze)
            }

            if phase == .paused {
                FixationPauseOverlay(
                    onResume: { phase = .playing },
                    onRest: { phase = .finished(stoppedEarly: true) }
                )
            }
        }
    }

    /// Exit, veggies left, time bar and pause, like Whack-a-Mole's top bar.
    private var topBar: some View {
        HStack(spacing: 20) {
            FixationHUDButton(systemImage: "xmark", label: "Stop the game") {
                phase = .finished(stoppedEarly: true)
            }

            VeggiesLeftView(left: veggiesLeft, total: totalVeggies)

            GuardProgressView(progress: guardedSeconds / guardSeconds, secondsLeft: secondsLeft)
                .frame(maxWidth: .infinity)

            FixationHUDButton(systemImage: "pause.fill", label: "Pause") {
                phase = .paused
            }
            .disabled(phase != .playing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    /// Reminder to watch the stall: before the game starts, and whenever the child looks away.
    @ViewBuilder
    private var prompt: some View {
        if phase == .waiting || (phase == .playing && !isWatching) {
            Label(promptText, systemImage: usesGaze ? "eye.fill" : "hand.point.up.left.fill")
                .font(.system(.title, design: .rounded).weight(.heavy))
                .foregroundStyle(FixationPalette.ink)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Capsule().fill(.white.opacity(0.85)))
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var promptText: LocalizedStringKey {
        switch (usesGaze, phase == .waiting) {
        case (true, true):   "Look at the stall to guard it"
        case (true, false):  "Look at the stall!"
        case (false, true):  "Hold the screen to guard the stall"
        case (false, false): "Keep holding!"
        }
    }

    /// The gaze dot (while testing) and a warning when eye control is lost.
    private func gazeOverlay(_ gaze: GazeInputController) -> some View {
        ZStack {
            if showsGazeDot, gaze.hasUsableGaze, let point = smoother.point {
                Circle()
                    .strokeBorder(.white, lineWidth: 3)
                    .background(Circle().fill(FixationPalette.accent.opacity(0.65)))
                    .frame(width: 30, height: 30)
                    .position(point)
                    .shadow(radius: 3)
            }

            if !gaze.isCalibrated {
                Text("Eye control needs recalibration")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.75), in: Capsule())
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 18)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Gaze

    /// The gaze point in screen points. The tracker gives 0–1 values across the area
    /// the calibration circles covered (see GazeScreenArea): (0, 0) is its top-left
    /// circle and (1, 1) its bottom-right circle.
    private func gazePoint(_ gaze: GazeInputController) -> CGPoint? {
        guard let point = gaze.sample.pointNormalized else { return nil }
        return GazeScreenArea.screenPoint(x: point.x, y: point.y, in: screenSize)
    }

    /// Is the eye looking at the stall right now? Lost tracking counts as looking away.
    private func updateGazeOnStall() {
        guard let gaze, gaze.hasUsableGaze, let rawPoint = gazePoint(gaze) else {
            smoother.reset()
            gazeIsOnStall = false
            return
        }
        smoother.add(rawPoint)
        guard let point = smoother.point else { return }
        gazeIsOnStall = stallFrame.insetBy(dx: -gazeMargin, dy: -gazeMargin).contains(point)
    }

    // MARK: - Game logic

    /// Watching: the guard time fills up until the stall is safe.
    /// Looking away: the thief comes and takes a veggie every few seconds.
    /// Sleeping throws when "watching" or the phase changes, which stops this run.
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
                    // The thief walks back with the veggies, then comes up under the next crate.
                    thiefIsHere = false
                    try await Task.sleep(for: .seconds(1.6))
                }
                phase = .finished(stoppedEarly: false)
            }
        } catch {
            // "Watching" changed or the game was paused; this run stops here.
        }
    }

    private func restart() {
        veggiesLeft = totalVeggies
        guardedSeconds = 0
        thiefIsHere = false
        phase = .waiting
    }
}

#Preview("Fixation game (finger)", traits: .landscapeLeft) {
    FixationGameView(gaze: nil, character: .fox, onExit: {})
}
