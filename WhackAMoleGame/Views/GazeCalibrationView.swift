import DrStrangeGazeTracker
import SwiftUI
import UIKit

/// Pre-game calibration using whichever prescribed eye remains uncovered. Shared by every game.
///
/// Three steps, from the design:
/// 1. "Stare at the dots": what to do (sit still, follow the dots with your eye). NEXT.
/// 2. "Keep your head in the circle": the camera, with the face oval. When the face is in place
///    and still, calibration starts by itself.
/// 3. The dots (unchanged).
/// Recalibration during a game skips step 1.
///
/// Positions come from the 1366 × 1024 design frame and are scaled to the screen.
struct GazeCalibrationView: View {
    let controller: GazeInputController
    let isRecalibration: Bool
    let onCalibrated: () -> Void
    let onCancel: () -> Void

    @State private var didComplete = false
    /// False on step 1 ("Stare at the dots"), true once NEXT is tapped.
    @State private var showsCamera: Bool
    @Environment(\.scenePhase) private var scenePhase

    /// Size of the design frame.
    private static let design = CGSize(width: 1366, height: 1024)
    private static let background = Color(red: 0.984, green: 0.890, blue: 0.682)
    private static let titleBrown = Color(red: 0.600, green: 0.357, blue: 0.220)
    /// Seconds the face must stay ready before the dots start by themselves.
    private static let readyHoldSeconds = 1.0

    init(
        controller: GazeInputController,
        isRecalibration: Bool = false,
        onCalibrated: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.controller = controller
        self.isRecalibration = isRecalibration
        self.onCalibrated = onCalibrated
        self.onCancel = onCancel
        _showsCamera = State(initialValue: isRecalibration)
    }

    var body: some View {
        GeometryReader { geometry in
            let sx = geometry.size.width / Self.design.width
            let sy = geometry.size.height / Self.design.height
            let s = min(sx, sy)

            ZStack {
                if let target = controller.activeCalibrationTarget {
                    // Step 3: the dots.
                    Color.white.ignoresSafeArea()
                    CalibrationFixationTarget()
                        .position(
                            x: target.x * geometry.size.width,
                            y: target.y * geometry.size.height
                        )
                    if controller.calibrationNeedsGuidance {
                        VStack {
                            if target.y > 0.5 {
                                guidanceBanner
                                    .frame(maxWidth: 620)
                                Spacer()
                            } else {
                                Spacer()
                                guidanceBanner
                                    .frame(maxWidth: 620)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                    }
                } else {
                    Self.background.ignoresSafeArea()
                    if showsCamera {
                        cameraStep(sx: sx, sy: sy, s: s)
                    } else {
                        instructionsStep(sx: sx, sy: sy, s: s)
                    }
                    closeButton(s: s)
                        .position(x: 70 * sx, y: 70 * sy)
                }
            }
        }
        .preferredColorScheme(.light)
        .statusBarHidden()
        .onAppear { controller.startCamera() }
        .onChange(of: controller.isCalibrated) { _, calibrated in
            guard calibrated, !didComplete else { return }
            didComplete = true
            onCalibrated()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { controller.resumeForActiveScene() }
            else { controller.pauseForInactiveScene() }
        }
        // Step 2: once the face is in place and still for a moment, start the dots by themselves.
        .task(id: ReadyState(showsCamera: showsCamera, isReady: controller.isReadyToCalibrate)) {
            guard showsCamera, controller.isReadyToCalibrate, !controller.isPreparingCalibration,
                  controller.activeCalibrationTarget == nil else { return }
            try? await Task.sleep(for: .seconds(Self.readyHoldSeconds))
            guard !Task.isCancelled, controller.isReadyToCalibrate,
                  !controller.isPreparingCalibration else { return }
            controller.startCalibration(preparationSeconds: isRecalibration ? 3 : 6)
        }
    }

    private struct ReadyState: Equatable {
        let showsCamera: Bool
        let isReady: Bool
    }

    // MARK: - Step 1: Stare at the dots

    private func instructionsStep(sx: CGFloat, sy: CGFloat, s: CGFloat) -> some View {
        ZStack {
            card(sx: sx, sy: sy)

            Text("Stare at the dots")
                .textCase(.uppercase)
                .font(.custom("DoodleChalkDemoRegular", size: 92 * s))
                .tracking(92 * s * 0.025)
                .foregroundStyle(Self.titleBrown)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 880 * sx)
                .position(x: 683 * sx, y: 300 * sy)
                .accessibilityAddTraits(.isHeader)

            Text("Sit still and don't move your head")
                .font(.custom("DaysOne-Regular", size: 38 * s))
                .foregroundStyle(.black)
                .position(x: 683 * sx, y: 455 * sy)

            Text("Follow the dots with only your eye")
                .font(.custom("DaysOne-Regular", size: 38 * s))
                .foregroundStyle(.black)
                .position(x: 683 * sx, y: 567 * sy)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showsCamera = true }
            } label: {
                Image("ButtonBoard")
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        Text("Next")
                            .textCase(.uppercase)
                            .font(.custom("DoodleChalkDemoRegular", size: 62 * s))
                            .tracking(62 * s * 0.025)
                            .foregroundStyle(Color(red: 0.98, green: 0.93, blue: 0.88))
                            // The board's thick bottom edge: lift the word a little.
                            .offset(y: -6 * s)
                    }
                    .frame(width: 280 * s)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next")
            .position(x: 676 * sx, y: 735 * sy)

            houses(carrot: CGRect(x: 130, y: 622, width: 155, height: 268),
                   onion: CGRect(x: 1030, y: 688, width: 180, height: 202),
                   sx: sx, sy: sy)
        }
    }

    // MARK: - Step 2: Keep your head in the circle

    private func cameraStep(sx: CGFloat, sy: CGFloat, s: CGFloat) -> some View {
        ZStack {
            Text("Keep Your Head in The Circle")
                .font(.custom("DoodleChalkDemoRegular", size: 76 * s))
                .tracking(76 * s * 0.025)
                .foregroundStyle(Self.titleBrown)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 1060 * sx)
                .position(x: 683 * sx, y: 100 * sy)
                .accessibilityAddTraits(.isHeader)

            card(sx: sx, sy: sy)

            // The camera, inside the card.
            ZStack {
                VolatileGazeCameraPreview(view: controller.cameraPreview)
                if !controller.cameraStarted { Color.black }
                FacePositionGuide(
                    state: controller.sample.setupState,
                    isReady: controller.isReadyToCalibrate,
                    isCheckingPatch: controller.oneEyeEnforcerEnabled &&
                        controller.patchWearState == .checking
                )
                .scaleEffect(1.25 * s)
                if controller.isPreparingCalibration {
                    countdown(s: s)
                }
            }
            .frame(width: 844 * sx, height: 583 * sy)
            .clipped()
            .overlay(alignment: .bottom) {
                if !controller.isPreparingCalibration {
                    guidanceBanner
                        .frame(maxWidth: 620 * s)
                        .padding(16 * s)
                }
            }
            .position(x: 683 * sx, y: 511.5 * sy)

            houses(carrot: CGRect(x: 128, y: 607, width: 154, height: 268),
                   onion: CGRect(x: 1048, y: 670, width: 180, height: 202),
                   sx: sx, sy: sy)
        }
    }

    /// "First dot in 3, 2, 1" over the camera, once the face is ready.
    private func countdown(s: CGFloat) -> some View {
        VStack(spacing: 8 * s) {
            Text("Get ready for the first dot")
                .font(.custom("DaysOne-Regular", size: 34 * s))
            Text("\(controller.calibrationCountdown)")
                .font(.custom("DaysOne-Regular", size: 110 * s))
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: controller.calibrationCountdown)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.5), radius: 6)
        .padding(28 * s)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 28 * s))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("First dot in \(controller.calibrationCountdown) seconds")
    }

    // MARK: - Shared pieces

    /// The cream card with the brown border, same place on both steps.
    private func card(sx: CGFloat, sy: CGFloat) -> some View {
        Image("SettingsCard")
            .resizable()
            .frame(width: 962 * sx, height: 698 * sy)
            .position(x: 684 * sx, y: 511 * sy)
            .accessibilityHidden(true)
    }

    /// The carrot house bottom left and the onion house bottom right.
    private func houses(carrot: CGRect, onion: CGRect, sx: CGFloat, sy: CGFloat) -> some View {
        ZStack {
            Image("FoxPath/HouseCarrotFront")
                .resizable()
                .frame(width: carrot.width * sx, height: carrot.height * sy)
                .position(x: carrot.midX * sx, y: carrot.midY * sy)
            Image("FoxPath/HouseOnionFront")
                .resizable()
                .frame(width: onion.width * sx, height: onion.height * sy)
                .position(x: onion.midX * sx, y: onion.midY * sy)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Leaves calibration (and the game) before the dots start.
    private func closeButton(s: CGFloat) -> some View {
        Button {
            controller.stop()
            onCancel()
        } label: {
            Image("FinishScreen/ButtonClose")
                .resizable()
                .scaledToFit()
                .frame(width: 80 * s, height: 80 * s)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private var guidance: CalibrationGuidance {
        if !controller.cameraStarted {
            return .init(
                id: "camera",
                title: "Starting the camera",
                message: "Please wait a moment.",
                systemImage: "camera.fill",
                tone: .info
            )
        }
        if controller.isSceneTooDark {
            return .init(
                id: "dark",
                title: "Turn on a light",
                message: "Ask a grown-up to make the room brighter.",
                systemImage: "lightbulb.fill",
                tone: .warning
            )
        }
        switch controller.sample.setupState {
        case .tooClose:
            return .init(
                id: "close",
                title: "Move back a little",
                message: "Move the iPad away from your face.",
                systemImage: "arrow.backward.circle.fill",
                tone: .warning
            )
        case .tooFar:
            return .init(
                id: "far",
                title: "Come a little closer",
                message: "Bring the iPad toward your face.",
                systemImage: "arrow.forward.circle.fill",
                tone: .warning
            )
        case .misaligned:
            return .init(
                id: "angle",
                title: "Point your nose at the iPad",
                message: "Look straight at the screen.",
                systemImage: "ipad.landscape",
                tone: .warning
            )
        case .lookUp:
            return .init(
                id: "look-up",
                title: "Look up a little",
                message: "Move your nose toward the arrow.",
                systemImage: "arrow.up.circle.fill",
                tone: .warning
            )
        case .lookDown:
            return .init(
                id: "look-down",
                title: "Look down a little",
                message: "Move your nose toward the arrow.",
                systemImage: "arrow.down.circle.fill",
                tone: .warning
            )
        case .turnLeft:
            return .init(
                id: "turn-left",
                title: "Turn left a little",
                message: "Move your nose toward the arrow.",
                systemImage: "arrow.left.circle.fill",
                tone: .warning
            )
        case .turnRight:
            return .init(
                id: "turn-right",
                title: "Turn right a little",
                message: "Move your nose toward the arrow.",
                systemImage: "arrow.right.circle.fill",
                tone: .warning
            )
        case .movingTooMuch:
            return .init(
                id: "movement",
                title: "Too much movement",
                message: "Keep your head and the iPad still.",
                systemImage: "exclamationmark.triangle.fill",
                tone: .warning
            )
        case .stabilizing:
            return .init(
                id: "stable",
                title: "Hold still…",
                message: "Keep your head and the iPad still.",
                systemImage: "viewfinder",
                tone: .info
            )
        case .unknown:
            return .init(
                id: "face",
                title: "Face in the oval",
                message: "Move the iPad until your whole face is inside.",
                systemImage: "face.smiling",
                tone: .info
            )
        case .ready:
            break
        }

        if controller.oneEyeEnforcerEnabled {
            if controller.patchWearState == .missing || controller.sample.eyeAvailability == .both {
                return .init(
                    id: "patch",
                    title: "Put on your eye patch",
                    message: "Keep your other eye open.",
                    systemImage: "eye.slash.fill",
                    tone: .warning
                )
            }
            if controller.sample.eyeAvailability == .none {
                return .init(
                    id: "eye",
                    title: "Open your eye",
                    message: "Look at the iPad.",
                    systemImage: "eye.fill",
                    tone: .warning
                )
            }
            if controller.patchWearState == .checking {
                return .init(
                    id: "checking",
                    title: "Hold still…",
                    message: "Checking your eye patch.",
                    systemImage: "hourglass",
                    tone: .info
                )
            }
        }

        return .init(
            id: "ready",
            title: "Ready!",
            message: "Keep still, the dots start soon.",
            systemImage: "checkmark.circle.fill",
            tone: .success
        )
    }

    private var guidanceBanner: some View {
        let guidance = guidance
        return HStack(spacing: 12) {
            Image(systemName: guidance.systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(guidance.tone.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(guidance.title)
                    .font(.headline)
                Text(guidance.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .foregroundStyle(.primary)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(guidance.tone.color.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.15), radius: 12, y: 5)
        .id(guidance.id)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .animation(.smooth(duration: 0.3), value: guidance.id)
        .accessibilityElement(children: .combine)
    }
}

private struct FacePositionGuide: View {
    let state: SetupState
    let isReady: Bool
    let isCheckingPatch: Bool

    private var color: Color {
        if isReady { return .green }
        if state == .stabilizing || isCheckingPatch { return .blue }
        return .orange
    }

    private var label: String {
        if isReady { return "Ready!" }
        if state == .movingTooMuch { return "Too much movement" }
        if state == .stabilizing || isCheckingPatch { return "Hold still…" }
        return "Your face"
    }

    private var directionIcon: String? {
        switch state {
        case .lookUp: "arrow.up"
        case .lookDown: "arrow.down"
        case .turnLeft: "arrow.left"
        case .turnRight: "arrow.right"
        default: nil
        }
    }

    private var directionOffset: CGSize {
        switch state {
        case .turnLeft: CGSize(width: -175, height: 0)
        case .turnRight: CGSize(width: 175, height: 0)
        default: CGSize(width: 175, height: 0)
        }
    }

    var body: some View {
        ZStack {
            Ellipse()
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [12, 9])
                )
                .frame(width: 220, height: 290)
                .overlay(alignment: .top) {
                    Text(label)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(color.opacity(0.92), in: Capsule())
                        .offset(y: -18)
                }

            if let directionIcon {
                Image(systemName: directionIcon)
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(.orange.opacity(0.95), in: Circle())
                    .overlay { Circle().stroke(.white, lineWidth: 4) }
                    .offset(directionOffset)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
        .animation(.smooth(duration: 0.25), value: state)
        .accessibilityHidden(true)
    }
}

private struct CalibrationGuidance {
    let id: String
    let title: String
    let message: String
    let systemImage: String
    let tone: Tone

    enum Tone {
        case info
        case warning
        case success

        var color: Color {
            switch self {
            case .info: .blue
            case .warning: .orange
            case .success: .green
            }
        }
    }
}

private struct VolatileGazeCameraPreview: UIViewRepresentable {
    let view: UIView

    func makeUIView(context: Context) -> UIView { view }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

private struct CalibrationFixationTarget: View {
    @State private var contracted = false

    var body: some View {
        ZStack {
            Circle().stroke(.black, lineWidth: 5).frame(width: 72, height: 72)
            Circle().fill(.orange).frame(width: 30, height: 30)
                .scaleEffect(contracted ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: contracted)
        }
        .onAppear { contracted = true }
        .accessibilityHidden(true)
    }
}
