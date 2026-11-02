import SwiftUI

/// Full-screen gameplay. Shows the result screen in place when the session ends.
struct WhackAMoleGameView: View {
    private static let foxSize: CGFloat = 130

    let configuration: GameConfiguration
    let onClose: () -> Void

    @State private var viewModel: WhackAMoleGameViewModel
    @State private var isConfirmingExit = false
    @Environment(\.scenePhase) private var scenePhase

    init(configuration: GameConfiguration, onClose: @escaping () -> Void) {
        self.configuration = configuration
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
            if newPhase != .active { viewModel.pause() }
        }
    }

    private var gameplay: some View {
        ZStack {
            viewModel.renderer.background.ignoresSafeArea()

            VStack(spacing: 0) {
                GameHUDView(viewModel: viewModel, onExit: requestExit)
                // Side margins keep the fox clear of the holes on every iPad size.
                GameBoardView(viewModel: viewModel)
                    .padding(.horizontal, Self.foxSize + 24)
                    .padding(.bottom, 24)
            }

            FoxHammerView(swingCount: viewModel.hammerSwings, isDichoptic: viewModel.renderer.isDichoptic)
                .frame(width: Self.foxSize, height: Self.foxSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(16)
                .allowsHitTesting(false)

            overlay
        }
        .confirmationDialog("Leave the game?", isPresented: $isConfirmingExit, titleVisibility: .visible) {
            Button("Leave", role: .destructive) {
                viewModel.exit()
                onClose()
            }
            Button("Keep playing", role: .cancel) { viewModel.resume() }
        }
    }

    @ViewBuilder
    private var overlay: some View {
        switch viewModel.phase {
        case let .countdown(number):
            Text("\(number)")
                .font(.system(size: 160, weight: .heavy, design: .rounded))
                .foregroundStyle(viewModel.renderer.isDichoptic ? Color(white: 0.3) : WhackAMolePalette.accent)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: number)
                .accessibilityLabel("Starting in \(number)")
        case .paused where !isConfirmingExit:
            PauseOverlay(onResume: viewModel.resume, onExit: requestExit)
        default:
            if let level = viewModel.levelBanner {
                LevelBanner(level: level, isDichoptic: viewModel.renderer.isDichoptic)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 96)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func requestExit() {
        viewModel.pause()
        isConfirmingExit = true
    }

    private func restart() {
        viewModel.stop()
        viewModel = WhackAMoleGameViewModel(configuration: configuration)
        viewModel.start()
    }
}

private struct PauseOverlay: View {
    let onResume: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 28) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(WhackAMolePalette.accent)
                    .accessibilityHidden(true)
                Text("Paused")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                HStack(spacing: 20) {
                    Button(action: onExit) {
                        Label("Exit", systemImage: "xmark")
                            .frame(minWidth: 140, minHeight: 56)
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
            }
            .padding(48)
            .background(RoundedRectangle(cornerRadius: 36).fill(WhackAMolePalette.cream))
        }
    }
}

private struct LevelBanner: View {
    let level: DifficultyLevel
    let isDichoptic: Bool

    var body: some View {
        Label("Level \(level.rawValue)", systemImage: "sparkles")
            .font(.system(.title, design: .rounded).weight(.heavy))
            .foregroundStyle(isDichoptic ? Color(white: 0.25) : WhackAMolePalette.ink)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(Capsule().fill(.white.opacity(0.85)))
    }
}
