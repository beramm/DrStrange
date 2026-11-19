//
//  FixationGameView.swift
//  Veggie Keeper (fixation game): guard the vegetable stall.
//  The picture comes from MarketSceneView. The top bar matches Veggie Dash's
//  (painted carrots, time bar, painted pause button); inside the DrStrange app
//  the pause pop-up, the patch reminder and the finish screen are the ones
//  shared by all the games.
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
    /// Pause and finish screen "Home": back to the start of the app. Nil falls back to `onExit`.
    var onHome: (() -> Void)? = nil
    /// Finish screen "Next": on to another game. Nil hides the button.
    var onNextGame: (() -> Void)? = nil

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
    /// Steadies the gaze point; the cursor and stall check use the same point.
    #if VEGGIE_KEEPER_STANDALONE
    @State private var smoother = GazeSmoother()
    #else
    @State private var smoother = GazePointSmoother()
    @State private var smoothedNormalizedPoint: CGPoint?
    #endif
    /// The stall's position on screen, used to check the gaze point.
    @State private var stallFrame: CGRect = .zero
    /// The game scene's position in global coordinates, matching the stall frame.
    @State private var screenFrame: CGRect = .zero

    @State private var phase = Phase.waiting
    @State private var veggiesLeft = 3
    @State private var guardedSeconds: Double = 0
    @State private var thiefIsHere = false
    /// True while the game is paused because the camera sees both eyes (the patch came off).
    @State private var isPausedForMissingPatch = false
    /// Where to go back to once the patch is on again: waiting or playing.
    @State private var phaseBeforePatchPause = Phase.waiting
    /// Where the game was when calibration was lost, to carry on from there afterwards.
    @State private var phaseBeforeRecalibration = Phase.waiting
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
                finishScreen(stoppedEarly: stoppedEarly)
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
        #if !VEGGIE_KEEPER_STANDALONE
        .onChange(of: gaze?.patchWearState, initial: true) { _, state in
            respondToPatchState(state)
        }
        // Calibration lost: pause, show "Time to check again", calibrate, then carry on.
        .recalibratesWhenNeeded(
            controller: gaze,
            isActive: !isFinished,
            pause: pauseForRecalibration,
            resume: { phase = phaseBeforeRecalibration }
        )
        #endif
    }

    private var isFinished: Bool {
        if case .finished = phase { return true }
        return false
    }

    private func pauseForRecalibration() {
        if phase != .paused { phaseBeforeRecalibration = phase }
        phase = .paused
    }

    @ViewBuilder
    private func finishScreen(stoppedEarly: Bool) -> some View {
        #if VEGGIE_KEEPER_STANDALONE
        // The standalone Veggie Keeper project has no shared finish screen or its pictures.
        FixationGameResultView(
            character: character,
            veggiesSaved: veggiesLeft,
            totalVeggies: totalVeggies,
            stoppedEarly: stoppedEarly,
            onPlayAgain: restart,
            onDone: onExit
        )
        #else
        // The shared finish screen, with the veggies still safe shown as carrots.
        GameFinishScreen(onRestart: restart, onNext: onNextGame, onHome: { (onHome ?? onExit)() }) { scale in
            VStack(spacing: 22 * scale) {
                Text("Life Remaining")
                    .font(.custom("DaysOne-Regular", size: 38 * scale))
                    .foregroundStyle(Color(red: 0.24, green: 0.13, blue: 0.06))
                carrots
                    .frame(width: 327 * scale)
            }
        }
        #endif
    }

    /// The painted carrots: one orange carrot per veggie still safe, grey for the ones taken.
    private var carrots: some View {
        Image("VeggieKeeperCarrots\(min(max(veggiesLeft, 0), totalVeggies))")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityLabel("Veggies safe")
            .accessibilityValue("\(veggiesLeft) of \(totalVeggies)")
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
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame = $0 }

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
                #if VEGGIE_KEEPER_STANDALONE
                // The standalone Veggie Keeper project has no shared pop-up or its pictures.
                FixationPauseOverlay(
                    onResume: { phase = .playing },
                    onRest: { phase = .finished(stoppedEarly: true) }
                )
                #else
                if isPausedForMissingPatch {
                    // The patch came off: the shared reminder, until the one-eye check passes.
                    PatchReminderScreen()
                        .transition(.opacity)
                } else {
                    // Inside the DrStrange app: the shared pause pop-up (Home, Restart, Play).
                    GamePausePopup(
                        onResume: { phase = .playing },
                        onRestart: restart,
                        onHome: { (onHome ?? onExit)() }
                    )
                }
                #endif
            }
        }
    }

    /// Height of the pause button; the carrots and the time bar are sized to match it.
    private static let controlSize: CGFloat = 64

    /// Veggies left, time bar and pause, like Veggie Dash's top bar. Stopping early is offered
    /// from the pause screen.
    private var topBar: some View {
        HStack(spacing: 20) {
            carrots
                .frame(height: Self.controlSize)
                .animation(.snappy, value: veggiesLeft)

            GuardProgressView(progress: guardedSeconds / guardSeconds, secondsLeft: secondsLeft)
                .frame(maxWidth: .infinity)

            Button {
                phase = .paused
            } label: {
                Image("VeggieKeeperPauseButton")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: Self.controlSize, height: Self.controlSize)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(phase != .playing)
            .accessibilityLabel("Pause")
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

    /// The shared gaze bubble and a warning when eye control is lost.
    private func gazeOverlay(_ gaze: GazeInputController) -> some View {
        ZStack {
            #if VEGGIE_KEEPER_STANDALONE
            if showsGazeDot, gaze.hasUsableGaze, let point = smoother.point {
                Circle()
                    .strokeBorder(.white, lineWidth: 3)
                    .background(Circle().fill(FixationPalette.accent.opacity(0.65)))
                    .frame(width: 30, height: 30)
                    .position(point)
                    .shadow(radius: 3)
            }
            #else
            if showsGazeDot {
                PaddyGazeCursorVisual(
                    pointNormalized: smoothedNormalizedPoint,
                    isTracking: gaze.hasUsableGaze,
                    mayHoldBriefLoss: gaze.sample.trackingState == .lost &&
                        gaze.isCalibrated &&
                        gaze.isPatchVerified &&
                        !gaze.isSceneTooDark
                )
            }
            #endif

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

    #if VEGGIE_KEEPER_STANDALONE
    private func gazePoint(_ gaze: GazeInputController) -> CGPoint? {
        guard let point = gaze.sample.pointNormalized else { return nil }
        let local = GazeScreenArea.screenPoint(x: point.x, y: point.y, in: screenFrame.size)
        return CGPoint(x: screenFrame.minX + local.x, y: screenFrame.minY + local.y)
    }
    #endif

    /// Is the eye looking at the stall right now? Lost tracking counts as looking away.
    private func updateGazeOnStall() {
        #if VEGGIE_KEEPER_STANDALONE
        guard let gaze, gaze.hasUsableGaze, let rawPoint = gazePoint(gaze) else {
            smoother.reset()
            gazeIsOnStall = false
            return
        }
        smoother.add(rawPoint)
        guard let point = smoother.point else { return }
        gazeIsOnStall = stallFrame.insetBy(dx: -gazeMargin, dy: -gazeMargin).contains(point)
        #else
        let raw = gaze?.sample.pointNormalized.map { CGPoint(x: $0.x, y: $0.y) }
        smoothedNormalizedPoint = smoother.consume(
            point: raw,
            timestampNanoseconds: gaze?.sample.timestamp.uptimeNanoseconds ?? 0,
            isUsable: gaze?.hasUsableGaze == true
        )
        guard let point = smoothedNormalizedPoint else {
            gazeIsOnStall = false
            return
        }
        let screenPoint = PaddyGazeScreenGeometry.point(point, in: screenFrame)
        gazeIsOnStall = stallFrame.insetBy(dx: -gazeMargin, dy: -gazeMargin).contains(screenPoint)
        #endif
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
                    // The mole shows the veggies and goes back down, then comes up at the next basket.
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
        smoother.reset()
        #if !VEGGIE_KEEPER_STANDALONE
        smoothedNormalizedPoint = nil
        #endif
        gazeIsOnStall = false
        veggiesLeft = totalVeggies
        guardedSeconds = 0
        thiefIsHere = false
        isPausedForMissingPatch = false
        phase = .waiting
        #if !VEGGIE_KEEPER_STANDALONE
        respondToPatchState(gaze?.patchWearState)
        #endif
    }

    #if !VEGGIE_KEEPER_STANDALONE
    /// Pauses behind the patch reminder while the camera sees both eyes, and carries on by itself
    /// once the one-eye check passes again.
    private func respondToPatchState(_ state: PatchWearState?) {
        guard let gaze else { return }
        if !gaze.oneEyeEnforcerEnabled {
            if isPausedForMissingPatch {
                isPausedForMissingPatch = false
                phase = phaseBeforePatchPause
            }
            return
        }
        switch state {
        case .missing:
            guard phase == .waiting || phase == .playing else { return }
            phaseBeforePatchPause = phase
            isPausedForMissingPatch = true
            phase = .paused
        case .verified:
            guard isPausedForMissingPatch else { return }
            isPausedForMissingPatch = false
            phase = phaseBeforePatchPause
        default:
            break
        }
    }
    #endif
}

#Preview("Fixation game (finger)", traits: .landscapeLeft) {
    FixationGameView(gaze: nil, character: .fox, onExit: {})
}
