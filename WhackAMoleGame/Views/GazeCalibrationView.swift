import DrStrangeGazeTracker
import SwiftUI
import UIKit

/// Pre-game calibration using whichever prescribed eye remains uncovered.
struct GazeCalibrationView: View {
    static let calibrationBackground = Color.white
    let controller: GazeInputController
    let isRecalibration: Bool
    let onCalibrated: () -> Void
    let onCancel: () -> Void

    @State private var didComplete = false
    @Environment(\.scenePhase) private var scenePhase

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
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Self.calibrationBackground.ignoresSafeArea()

                if let target = controller.activeCalibrationTarget {
                    CalibrationFixationTarget()
                        .position(
                            x: target.x * geometry.size.width,
                            y: target.y * geometry.size.height
                        )
                        .animation(
                            .easeInOut(duration: PaddyCalibrationCapture.targetTransitionSeconds),
                            value: target
                        )
                } else if controller.isPreparingCalibration {
                    calibrationInstructions
                } else {
                    setupPanel
                }

                VStack {
                    if controller.activeCalibrationTarget?.y ?? 1 <= 0.10 {
                        Spacer()
                        calibrationControls
                    } else {
                        calibrationControls
                        Spacer()
                    }
                }
                .padding(24)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .statusBarHidden()
        .onAppear { controller.startCamera() }
        .onChange(of: controller.completedCalibrationCount) { _, _ in
            guard controller.isCalibrated, !didComplete else { return }
            didComplete = true
            onCalibrated()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { controller.resumeForActiveScene() }
            else { controller.pauseForInactiveScene() }
        }
    }

    private var calibrationControls: some View {
        HStack {
            if controller.activeCalibrationTarget != nil {
                Text(controller.status)
                    .font(.caption.monospaced())
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 12)
            Button("Cancel") {
                controller.stop()
                onCancel()
            }
            .buttonStyle(.bordered)
            .tint(.black)
        }
    }

    private var calibrationInstructions: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "scope")
                .font(.system(size: 88, weight: .bold))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Get ready for the first dot")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
            Text("Focus on the centre of each dot with your eye. Keep your head and the iPad still.")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 680)
            Text("\(controller.calibrationCountdown)")
                .font(.system(size: 88, weight: .heavy, design: .rounded))
                .foregroundStyle(.orange)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: controller.calibrationCountdown)
                .accessibilityLabel("First dot in \(controller.calibrationCountdown) seconds")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .foregroundStyle(.black)
        .accessibilityElement(children: .contain)
    }

    private var setupPanel: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            Text("Get ready to play")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
            Text("Face the iPad from about 45–60 cm away. Follow the yellow dots with your uncovered eye.")
                .font(.title2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 650)

            ZStack {
                VolatileGazeCameraPreview(view: controller.cameraPreview)
                FacePositionGuide(isReady: controller.isReadyToCalibrate)
            }
            .frame(width: 320, height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.black.opacity(0.18), lineWidth: 2)
            }
            .accessibilityLabel("Live camera preview with centered face guide")

            guidanceBanner.frame(maxWidth: 620)

            HStack(spacing: 12) {
                ReadinessBadge(
                    title: "Face",
                    isReady: controller.sample.setupState == .ready
                )
                if controller.oneEyeEnforcerEnabled {
                    ReadinessBadge(
                        title: "Eye patch",
                        isReady: controller.isPatchVerified
                    )
                }
                ReadinessBadge(
                    title: "Light",
                    isReady: !controller.isSceneTooDark
                )
            }

            Text(controller.cameraStatus)
                .font(.caption.monospaced())
                .foregroundStyle(controller.cameraStatus.contains("active") ? .green : .secondary)
                .accessibilityLabel("Active gaze model: \(controller.cameraStatus)")

            Button(controller.isPreparingCalibration ? "Get ready…" : "Let's start!") {
                controller.startCalibration(preparationSeconds: isRecalibration ? 3 : 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(controller.isReadyToCalibrate ? .green : .gray)
            .disabled(!controller.isReadyToCalibrate || controller.isPreparingCalibration)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .foregroundStyle(.black)
    }

    private var guidance: CalibrationGuidance {
        if controller.sample.calibrationState == .failed ||
            controller.sample.calibrationState == .invalid {
            return .init(
                id: "calibration-failed",
                title: "Calibration didn't finish",
                message: controller.status,
                systemImage: "exclamationmark.triangle.fill",
                tone: .warning
            )
        }
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
            message: "Tap the green Let's start button.",
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
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(guidance.tone.color.opacity(0.28), lineWidth: 1)
        }
        .id(guidance.id)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .animation(.smooth(duration: 0.3), value: guidance.id)
        .accessibilityElement(children: .combine)
    }
}

private struct SetupStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(.blue, in: Circle())
            Text(text)
                .font(.headline)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ReadinessBadge: View {
    let title: String
    let isReady: Bool

    var body: some View {
        Label(
            title,
            systemImage: isReady ? "checkmark.circle.fill" : "circle.dashed"
        )
        .font(.headline)
        .foregroundStyle(isReady ? .green : .orange)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white, in: Capsule())
        .accessibilityLabel("\(title): \(isReady ? "ready" : "not ready")")
    }
}

private struct FacePositionGuide: View {
    let isReady: Bool

    private var color: Color {
        isReady ? .mint : .yellow.opacity(0.85)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: isReady ? 4 : 2, dash: [9, 7])
                )
                .frame(width: 240, height: 240)
            Circle()
                .fill(isReady ? .mint : .yellow)
                .frame(width: 10, height: 10)
                .shadow(color: .black.opacity(0.45), radius: 3)
        }
        .animation(.easeInOut(duration: 0.2), value: isReady)
        .allowsHitTesting(false)
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
    var body: some View {
        ZStack {
            Circle()
                .stroke(.black, lineWidth: 3)
                .frame(width: 46, height: 46)
            Circle()
                .fill(.yellow)
                .frame(width: 30, height: 30)
        }
        .accessibilityHidden(true)
    }
}
