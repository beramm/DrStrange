import SwiftUI

/// Full-screen gameplay. Shows the result screen in place when the session ends,
/// whether time ran out or it was stopped early.
struct WhackAMoleGameView: View {
    private static let foxSize: CGFloat = 130

    let configuration: GameConfiguration
    let gazeController: GazeInputController?
    let onClose: () -> Void

    @State private var viewModel: WhackAMoleGameViewModel
    @State private var isConfirmingStop = false
    @State private var isPausedForMissingPatch = false
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
    }

    private var gameplay: some View {
        ZStack {
            playfield
                .overlayPreferenceValue(FoxAnchorKey.self) { anchors in
                    ZStack {
                        AttackAnimationView(pose: viewModel.foxPose, anchors: anchors)
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
        .confirmationDialog("Stop the game?", isPresented: $isConfirmingStop, titleVisibility: .visible) {
            Button("Stop and see my stars") { viewModel.finishEarly(reason: .stopped) }
            Button("Keep playing", role: .cancel) { resumeAfterStopDialog() }
        }
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
                GameHUDView(viewModel: viewModel, onExit: requestStop)
                // Side margins keep the fox's corner clear of the moles on every iPad size.
                GameBoardView(viewModel: viewModel, screenSize: screenSize)
                    .padding(.horizontal, Self.foxSize + 24)
                    .padding(.bottom, 24)
            }

            FoxHomeAnchor()
                .frame(width: Self.foxSize, height: Self.foxSize)
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
        case .paused where !isConfirmingStop:
            if isPausedForMissingPatch, let gazeController {
                MissingPatchPauseOverlay(
                    isPatchVerified: gazeController.isPatchVerified,
                    onResume: resumeAfterPatchCheck,
                    onRest: { viewModel.finishEarly(reason: .restBreak) }
                )
            } else {
                PauseOverlay(
                    onResume: viewModel.resume,
                    onRest: { viewModel.finishEarly(reason: .restBreak) }
                )
            }
        default:
            if let level = viewModel.levelBanner {
                LevelBanner(level: level)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 96)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func requestStop() {
        viewModel.pause()
        isConfirmingStop = true
    }

    private func restart() {
        viewModel.stop()
        viewModel = WhackAMoleGameViewModel(configuration: configuration)
        viewModel.start()
        respondToPatchState(gazeController?.patchWearState)
    }

    private func respondToPatchState(_ state: PatchWearState?) {
        if gazeController?.oneEyeEnforcerEnabled == false {
            if isPausedForMissingPatch {
                isPausedForMissingPatch = false
                viewModel.resume()
            }
            return
        }
        guard state == .missing, viewModel.phase != .finished else { return }
        isPausedForMissingPatch = true
        viewModel.pause()
    }

    private func resumeAfterPatchCheck() {
        guard gazeController?.isPatchVerified == true else { return }
        isPausedForMissingPatch = false
        viewModel.resume()
    }

    private func resumeAfterStopDialog() {
        if isPausedForMissingPatch {
            guard gazeController?.isPatchVerified == true else { return }
            isPausedForMissingPatch = false
        }
        viewModel.resume()
    }
}

private struct MissingPatchPauseOverlay: View {
    let isPatchVerified: Bool
    let onResume: () -> Void
    let onRest: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.32).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 68))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text("Patch check paused the game")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                Text(isPatchVerified
                     ? "The one-eye check passed again. You can keep playing."
                     : "Grown-ups: put the prescribed patch back on, then keep the child's face centred while the camera checks it.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
                HStack(spacing: 20) {
                    Button(action: onRest) {
                        Label("Rest my eyes", systemImage: "moon.zzz.fill")
                            .frame(minWidth: 200, minHeight: 56)
                    }
                    .buttonStyle(.bordered)
                    Button(action: onResume) {
                        Label(isPatchVerified ? "Play" : "Checking…", systemImage: "play.fill")
                            .frame(minWidth: 180, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(WhackAMolePalette.accent)
                    .disabled(!isPatchVerified)
                }
                .font(.title2.weight(.bold))
                Text("The camera only checks whether one eye stays visible; it cannot confirm that the correct prescribed eye is patched.")
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

private struct LevelBanner: View {
    let level: DifficultyLevel

    var body: some View {
        Label("Level \(level.rawValue)", systemImage: "sparkles")
            .font(.system(.title, design: .rounded).weight(.heavy))
            .foregroundStyle(WhackAMolePalette.ink)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(Capsule().fill(.white.opacity(0.85)))
    }
}
