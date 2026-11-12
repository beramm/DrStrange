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

/// Full-screen gameplay. Shows the result screen in place when the walk ends, whether the fox
/// reached the stall or the game was stopped early.
struct FoxPathGameView: View {
    /// Seconds without a gaze sample before the pointer counts as lost.
    private static let gazeTimeout: TimeInterval = 0.5

    let configuration: FoxPathConfiguration
    let input: FoxPathInput
    let onClose: () -> Void

    @State private var viewModel: FoxPathGameViewModel
    @State private var isConfirmingStop = false
    @State private var zoomAtPinchStart: CGFloat?
    @Environment(\.scenePhase) private var scenePhase

    init(configuration: FoxPathConfiguration, input: FoxPathInput, onClose: @escaping () -> Void) {
        self.configuration = configuration
        self.input = input
        self.onClose = onClose
        _viewModel = State(initialValue: Self.makeViewModel(configuration: configuration, input: input))
    }

    private static func makeViewModel(configuration: FoxPathConfiguration, input: FoxPathInput) -> FoxPathGameViewModel {
        FoxPathGameViewModel(configuration: configuration, pointerTimeout: input.usesGaze ? gazeTimeout : nil)
    }

    var body: some View {
        ZStack {
            if let result = viewModel.result {
                FoxPathResultView(
                    result: result,
                    level: configuration.level,
                    onPlayAgain: restart,
                    onDone: onClose
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
    }

    private var gameplay: some View {
        ZStack {
            FoxPathMapView(viewModel: viewModel)
                .gesture(input.usesGaze ? nil : fingerGesture)
                .simultaneousGesture(pinchGesture)

            FoxFocusOverlay(viewModel: viewModel, usesGaze: input.usesGaze)

            if configuration.showsGazeMarker, let point = viewModel.pointer {
                FoxPointerMarker(point: point)
            }

            if case let .gaze(controller) = input {
                GazePointerFeed(controller: controller, viewModel: viewModel)
            }

            FoxPathHUDView(viewModel: viewModel, onExit: requestStop)
                .frame(maxHeight: .infinity, alignment: .top)

            if viewModel.phase == .paused, !isConfirmingStop {
                PauseOverlay(onResume: viewModel.resume, onRest: viewModel.finishEarly)
            }
        }
        .confirmationDialog("Stop the game?", isPresented: $isConfirmingStop, titleVisibility: .visible) {
            Button("Stop and see my stars") { viewModel.finishEarly() }
            Button("Keep playing", role: .cancel) { viewModel.resume() }
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

    private func requestStop() {
        viewModel.pause()
        isConfirmingStop = true
    }

    /// Every new game draws a new map.
    private func restart() {
        viewModel.stop()
        viewModel = Self.makeViewModel(configuration: configuration, input: input)
        viewModel.start()
    }
}

/// Passes each gaze sample to the game as a screen point. Samples are used for the current
/// frame only and are never stored.
private struct GazePointerFeed: View {
    let controller: GazeInputController
    let viewModel: FoxPathGameViewModel

    var body: some View {
        GeometryReader { proxy in
            ZStack {
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
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The tracker reports gaze as a fraction of the safe-area rectangle it was calibrated on.
    private func consumeSample(in frame: CGRect) {
        guard controller.hasUsableGaze, let gaze = controller.sample.pointNormalized else {
            viewModel.pointerLost()
            return
        }
        viewModel.pointerMoved(to: CGPoint(
            x: frame.minX + gaze.x * frame.width,
            y: frame.minY + gaze.y * frame.height
        ))
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
                    .foregroundStyle(FoxPathPalette.accent)
                    .accessibilityHidden(true)
                Text("Paused")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(FoxPathPalette.ink)
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
                    .tint(FoxPathPalette.accent)
                }
                .font(.title2.weight(.bold))
                Text("Grown-ups: if your child has sore or tired eyes, a headache, or the patch feels uncomfortable, choose Rest my eyes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
            .padding(48)
            .background(RoundedRectangle(cornerRadius: 36).fill(FoxPathPalette.cream))
        }
    }
}
