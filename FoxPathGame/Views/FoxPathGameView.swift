import SwiftUI

/// What moves the pointer during a game.
enum FoxPathInput {
    /// Calibrated gaze from the shared tracker session.
    case gaze(GazeInputController)
    /// A finger on the screen: practice mode, and the fallback where gaze tracking is unavailable.
    case touch

    var usesGaze: Bool {
        if case .gaze = self { return true }
        return false
    }
}
/// Full-screen gameplay. Shows the result screen in place when the game ends: the finish screen
/// when time is up or the game was stopped early, the Game Over screen when the last carrot is gone.
struct FoxPathGameView: View {
    /// Seconds without a gaze sample before the pointer counts as lost.
    private static let gazeTimeout: TimeInterval = 0.5

    let configuration: FoxPathConfiguration
    let input: FoxPathInput
    /// The player's character, always the one followed. Nil draws it at random (standalone app).
    let player: PathCharacter?
    let onClose: () -> Void
    /// Finish screen "Next": goes on to another game. Nil hides the button (standalone app).
    let onNextGame: (() -> Void)?
    /// Finish and pause screen "Home": back to the start of the app. Nil falls back to `onClose`.
    let onHome: (() -> Void)?

    @State private var viewModel: FoxPathGameViewModel
    @State private var isPausedForMissingPatch = false
    @State private var zoomAtPinchStart: CGFloat?
    @Environment(\.scenePhase) private var scenePhase

    init(
        configuration: FoxPathConfiguration,
        input: FoxPathInput,
        player: PathCharacter? = nil,
        onNextGame: (() -> Void)? = nil,
        onHome: (() -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.configuration = configuration
        self.input = input
        self.player = player
        self.onNextGame = onNextGame
        self.onHome = onHome
        self.onClose = onClose
        _viewModel = State(initialValue: Self.makeViewModel(configuration: configuration, input: input, player: player))
    }

    private static func makeViewModel(configuration: FoxPathConfiguration, input: FoxPathInput, player: PathCharacter?) -> FoxPathGameViewModel {
        FoxPathGameViewModel(configuration: configuration, player: player, pointerTimeout: input.usesGaze ? gazeTimeout : nil)
    }

    var body: some View {
        ZStack {
            if let result = viewModel.result, result.endReason == .noLivesLeft {
                // All three carrots are gone: the session already ended the game.
                FoxPathGameOverView(onRestart: restart, onHome: goHome)
                    .transition(.opacity)
            } else if viewModel.result != nil {
                FoxPathResultView(
                    onRestart: restart,
                    onNext: onNextGame,
                    onHome: goHome
                )
                .transition(.opacity)
            } else {
                gameplay
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.result == nil)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .onChange(of: scenePhase) { _, newPhase in
            // Leaving the app pauses the game and the camera too, so no gaze is tracked in the
            // background. The game stays paused until the child taps Resume.
            if newPhase == .active {
                if case let .gaze(controller) = input { controller.resumeForActiveScene() }
            } else {
                viewModel.pause()
                if case let .gaze(controller) = input { controller.pauseForInactiveScene() }
            }
        }
        .onChange(of: gazeController?.patchWearState, initial: true) { _, state in
            respondToPatchState(state)
        }
        // Calibration lost: pause, show "Time to check again", calibrate, then carry on.
        .recalibratesWhenNeeded(
            controller: gazeController,
            isActive: viewModel.result == nil,
            pause: viewModel.pause,
            resume: viewModel.resume
        )
    }

    private var gameplay: some View {
        ZStack {
            playfield

            if viewModel.phase == .paused {
                if isPausedForMissingPatch, gazeController != nil {
                    PatchReminderScreen()
                        .transition(.opacity)
                } else {
                    GamePausePopup(onResume: viewModel.resume, onRestart: restart, onHome: goHome)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isPausedForMissingPatch)
    }

    /// The map, the guidance, the pointer and the top bar.
    @ViewBuilder
    private var playfield: some View {
        ZStack {
            FoxPathMapView(viewModel: viewModel)
                .gesture(input.usesGaze ? nil : fingerGesture)
                .simultaneousGesture(pinchGesture)

            FoxFocusOverlay(viewModel: viewModel, usesGaze: input.usesGaze)

            if !input.usesGaze, configuration.showsGazeMarker, let point = viewModel.pointer {
                FoxPointerMarker(point: point)
            }

            if case let .gaze(controller) = input {
                GazePointerFeed(
                    controller: controller,
                    viewModel: viewModel,
                    showsCursor: configuration.showsGazeMarker
                )
            }

            FoxPathHUDView(viewModel: viewModel)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    /// Practice mode: the finger stands in for the eyes.
    private var fingerGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { viewModel.pointerMoved(to: $0.location) }
            .onEnded { _ in viewModel.pointerLost() }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = zoomAtPinchStart ?? viewModel.camera.targetZoom
                zoomAtPinchStart = start
                viewModel.setZoom(start * value.magnification)
            }
            .onEnded { _ in zoomAtPinchStart = nil }
    }

    /// Leaves the game for the start of the app (or the Fox Path home in the standalone app).
    private func goHome() {
        viewModel.stop()
        (onHome ?? onClose)()
    }

    /// Every new game draws new maps and new roles.
    private func restart() {
        viewModel.stop()
        viewModel = Self.makeViewModel(configuration: configuration, input: input, player: player)
        viewModel.start()
        isPausedForMissingPatch = false
        respondToPatchState(gazeController?.patchWearState)
    }

    private var gazeController: GazeInputController? {
        guard case let .gaze(controller) = input else { return nil }
        return controller
    }

    private func respondToPatchState(_ state: PatchWearState?) {
        guard let gazeController else { return }
        if !gazeController.oneEyeEnforcerEnabled {
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
            // The patch is back on: hide the reminder and carry on without a tap.
            guard isPausedForMissingPatch else { return }
            isPausedForMissingPatch = false
            viewModel.resume()
        default:
            break
        }
    }
}

/// Passes filtered gaze to the game and draws the shared cursor. Its short
/// smoothing and trail history stays in memory and is never saved.
private struct GazePointerFeed: View {
    let controller: GazeInputController
    let viewModel: FoxPathGameViewModel
    let showsCursor: Bool

    @State private var smoother = GazePointSmoother()
    @State private var smoothedNormalizedPoint: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if showsCursor {
                    PaddyGazeCursorVisual(
                        pointNormalized: smoothedNormalizedPoint,
                        isTracking: controller.hasUsableGaze,
                        mayHoldBriefLoss: controller.sample.trackingState == .lost &&
                            controller.isCalibrated &&
                            controller.isPatchVerified &&
                            !controller.isSceneTooDark
                    )
                }

                if !controller.isCalibrated {
                    Text("Eye control needs recalibration")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.75), in: Capsule())
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 96)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: controller.sample.timestamp) { _, _ in
                consumeSample(in: proxy.frame(in: .global))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The shared tracker reports a full-screen normalized point. The same
    /// filtered point drives both the game and the visible bubble.
    private func consumeSample(in frame: CGRect) {
        let raw = controller.sample.pointNormalized.map { CGPoint(x: $0.x, y: $0.y) }
        smoothedNormalizedPoint = smoother.consume(
            point: raw,
            timestampNanoseconds: controller.sample.timestamp.uptimeNanoseconds,
            isUsable: controller.hasUsableGaze
        )
        guard let gaze = smoothedNormalizedPoint else {
            viewModel.pointerLost()
            return
        }
        viewModel.pointerMoved(
            to: PaddyGazeScreenGeometry.point(gaze, in: frame),
            alreadySmoothed: true
        )
    }
}
