import DrStrangeGazeTracker
import SwiftUI
import UIKit

/// Pre-game calibration using whichever prescribed eye remains uncovered.
struct GazeCalibrationView: View {
    let controller: GazeInputController
    let onCalibrated: () -> Void
    let onCancel: () -> Void

    @State private var didComplete = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.ignoresSafeArea()

                if let target = controller.activeCalibrationTarget {
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
                } else if controller.isPreparingCalibration {
                    calibrationInstructions
                } else {
                    setupPanel
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
            ProgressView()
                .controlSize(.large)
                .tint(.orange)
            Text("The first dot will appear in a moment.")
                .font(.headline)
                .foregroundStyle(.secondary)
            Button("Cancel") {
                controller.stop()
                onCancel()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .foregroundStyle(.black)
        .accessibilityElement(children: .contain)
    }

    private var setupPanel: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 36)
            Text("Get ready to play")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
            HStack(spacing: 30) {
                SetupStep(number: 1, text: "Face in oval")
                SetupStep(number: 2, text: "Follow arrow")
                SetupStep(number: 3, text: "Hold still")
            }

            ZStack {
                VolatileGazeCameraPreview(view: controller.cameraPreview)
                if !controller.cameraStarted { Color.black }
                FacePositionGuide(
                    state: controller.sample.setupState,
                    isReady: controller.isReadyToCalibrate,
                    isCheckingPatch: controller.oneEyeEnforcerEnabled &&
                        controller.patchWearState == .checking
                )
            }
            .frame(width: 520, height: 390)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(alignment: .bottom) {
                guidanceBanner
                    .padding(16)
            }

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

            Button(controller.isPreparingCalibration ? "Get ready…" : "Let's start!") {
                controller.startCalibration()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(controller.isReadyToCalibrate ? .green : .gray)
            .disabled(!controller.isReadyToCalibrate || controller.isPreparingCalibration)

            Button("Cancel") {
                controller.stop()
                onCancel()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .foregroundStyle(.black)
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
        .background(.thinMaterial, in: Capsule())
        .accessibilityLabel("\(title): \(isReady ? "ready" : "not ready")")
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
