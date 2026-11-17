import SwiftUI

/// Full-screen gameplay. Shows the result screen in place when the session ends,
/// whether time ran out or it was stopped early.
struct WhackAMoleGameView: View {
    private static let idleHelperSize: CGFloat = 250

    let configuration: GameConfiguration
    let gazeController: GazeInputController?
    let onClose: () -> Void

    @State private var viewModel: WhackAMoleGameViewModel
    @State private var isPausedForMissingPatch = false
    @State private var isPausedForRecalibration = false
    @State private var isPresentingRecalibration = false
    @Environment(\.scenePhase) private var scenePhase

    init(
        configuration: GameConfiguration,
        gazeController: GazeInputController? = nil,
        onClose: @escaping () -> Void
    ) {
        self.configuration = configuration
        self.gazeController = gazeController
        self.onClose = onClose
        _viewModel = State(initialValue: WhackAMoleGameViewModel(configuration: configuration))
    }

    var body: some View {
        ZStack {
            if let session = viewModel.finishedSession {
                GameResultView(
                    session: session,
                    score: viewModel.score,
                    previousHighScore: viewModel.highScore,
                    isNewHighScore: viewModel.isNewHighScore,
                    onPlayAgain: restart,
                    onDone: onClose
                )
                .transition(.opacity)
            } else {
                gameplay
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.finishedSession == nil)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                gazeController?.resumeForActiveScene()
            } else {
                viewModel.pause()
                gazeController?.pauseForInactiveScene()
            }
        }
        .onChange(of: gazeController?.patchWearState, initial: true) { _, state in
            respondToPatchState(state)
        }
        .onChange(of: gazeController?.isCalibrated, initial: true) { _, isCalibrated in
            respondToCalibrationState(isCalibrated)
        }
        .fullScreenCover(isPresented: $isPresentingRecalibration) {
            if let gazeController {
                GazeCalibrationView(
                    controller: gazeController,
                    isRecalibration: true,
                    onCalibrated: finishRecalibration,
                    onCancel: { isPresentingRecalibration = false }
                )
            }
        }
    }

    private var gameplay: some View {
        ZStack {
            playfield
                .overlayPreferenceValue(FoxAnchorKey.self) { anchors in
                    ZStack {
                        if viewModel.foxPoses.isEmpty {
                            AttackAnimationView(pose: nil, anchors: anchors, helper: viewModel.helper)
                        } else {
                            ForEach(viewModel.foxPoses, id: \.holeIndex) { pose in
                                AttackAnimationView(pose: pose, anchors: anchors, helper: viewModel.helper)
                            }
                        }
                        HitFeedbackOverlay(viewModel: viewModel, anchors: anchors)
                        if let gazeController {
                            GazeInteractionView(
                                controller: gazeController,
                                viewModel: viewModel,
                                anchors: anchors
                            )
                        }
                    }
                }

            overlay
        }
        .animation(.easeInOut(duration: 0.3), value: isPausedForMissingPatch)
    }

    /// Board plus the fox's corner spot. The holes and the corner report their positions so the
    /// fox and its frame can be placed beside the tapped character.
    private var playfield: some View {
        GeometryReader { screen in
            let insets = screen.safeAreaInsets
            let fullScreen = CGSize(
                width: screen.size.width + insets.leading + insets.trailing,
                height: screen.size.height + insets.top + insets.bottom
            )
            ZStack {
                GameBackgroundView(screenSize: fullScreen)
                    .position(x: fullScreen.width / 2 - insets.leading, y: fullScreen.height / 2 - insets.top)

                playfieldContent(screenSize: fullScreen)
            }
        }
    }

    private func playfieldContent(screenSize: CGSize) -> some View {
        ZStack {
            VStack(spacing: 0) {
                GameHUDView(viewModel: viewModel)
                // Side margins keep the fox's corner clear of the moles on every iPad size.
                GameBoardView(viewModel: viewModel, screenSize: screenSize)
                    .padding(.horizontal, Self.idleHelperSize + 24)
                    .padding(.bottom, 24)
            }

            FoxHomeAnchor()
                .frame(width: Self.idleHelperSize, height: Self.idleHelperSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(16)
        }
    }

    @ViewBuilder
    private var overlay: some View {
        switch viewModel.phase {
        case let .countdown(number):
            Text("\(number)")
                .font(.system(size: 160, weight: .heavy, design: .rounded))
                .foregroundStyle(WhackAMolePalette.accent)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: number)
                .accessibilityLabel("Starting in \(number)")
        case .paused:
            if isPausedForRecalibration {
                RecalibrationPauseOverlay(
                    onRecalibrate: { isPresentingRecalibration = true },
                    onRest: { viewModel.finishEarly(reason: .restBreak) }
                )
            } else if isPausedForMissingPatch, gazeController != nil {
                PatchReminderScreen()
                    .transition(.opacity)
            } else {
                PauseOverlay(
                    onResume: viewModel.resume,
                    onRest: { viewModel.finishEarly(reason: .restBreak) }
                )
            }
        default:
            EmptyView()
        }
    }

    private func restart() {
        viewModel.stop()
        viewModel = WhackAMoleGameViewModel(configuration: configuration)
        viewModel.start()
        respondToPatchState(gazeController?.patchWearState)
        respondToCalibrationState(gazeController?.isCalibrated)
    }

    private func respondToCalibrationState(_ isCalibrated: Bool?) {
        guard gazeController != nil,
              isCalibrated == false,
              viewModel.phase != .finished else { return }
        isPausedForRecalibration = true
        viewModel.pause()
    }

    private func finishRecalibration() {
        isPresentingRecalibration = false
        isPausedForRecalibration = false
        if gazeController?.isPatchVerified == true {
            isPausedForMissingPatch = false
        }
        viewModel.resume()
    }

    private func respondToPatchState(_ state: PatchWearState?) {
        if gazeController?.oneEyeEnforcerEnabled == false {
            if isPausedForMissingPatch {
                isPausedForMissingPatch = false
                viewModel.resume()
            }
            return
        }
        switch state {
        case .missing:
            guard viewModel.phase != .finished else { return }
            isPausedForMissingPatch = true
            viewModel.pause()
        case .verified:
            // The patch is back on: hide the reminder and carry on without a tap, unless the
            // game is also waiting on recalibration.
            guard isPausedForMissingPatch else { return }
            isPausedForMissingPatch = false
            if !isPausedForRecalibration { viewModel.resume() }
        default:
            break
        }
    }
}

private struct RecalibrationPauseOverlay: View {
    let onRecalibrate: () -> Void
    let onRest: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.32).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "viewfinder.circle.fill")
                    .font(.system(size: 68))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text("Eye control needs recalibration")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                Text("Your position changed too much. Set up eye control again before continuing.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
                HStack(spacing: 20) {
                    Button(action: onRest) {
                        Label("Rest my eyes", systemImage: "moon.zzz.fill")
                            .frame(minWidth: 200, minHeight: 56)
                    }
                    .buttonStyle(.bordered)
                    Button(action: onRecalibrate) {
                        Label("Calibrate again", systemImage: "eye.fill")
                            .frame(minWidth: 220, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(WhackAMolePalette.accent)
                }
                .font(.title2.weight(.bold))
                Text("Your score and remaining play time will stay paused while you recalibrate.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
            .padding(48)
            .background(RoundedRectangle(cornerRadius: 36).fill(WhackAMolePalette.cream))
        }
    }
}

/// Pause screen. Besides resuming, it offers a clear way to stop and rest when the child's eyes
/// are tired or uncomfortable.
private struct PauseOverlay: View {
    let onResume: () -> Void
    let onRest: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(WhackAMolePalette.accent)
                    .accessibilityHidden(true)
                Text("Paused")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
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
                    .tint(WhackAMolePalette.accent)
                }
                .font(.title2.weight(.bold))
                Text("Grown-ups: if your child has sore or tired eyes, a headache, or the patch feels uncomfortable, choose Rest my eyes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
            .padding(48)
            .background(RoundedRectangle(cornerRadius: 36).fill(WhackAMolePalette.cream))
        }
    }
}
