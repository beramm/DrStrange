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

    private var setupPanel: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 36)
            Text("Set up eye control")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
            Text(controller.oneEyeEnforcerEnabled
                 ? "Put on the prescribed patch, then use the preview to centre your face. Keep the uncovered eye open and look directly at each target."
                 : "Use the preview to centre your face, keep your eyes visible, and look directly at each target.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 680)

            ZStack {
                VolatileGazeCameraPreview(view: controller.cameraPreview)
                if !controller.cameraStarted { Color.black }
            }
            .frame(width: 520, height: 390)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(alignment: .bottom) {
                guidanceBanner
                    .padding(16)
            }

            Button(controller.isPreparingCalibration ? "Get ready…" : "Start calibration") {
                controller.startCalibration()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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
                title: "The room is too dark",
                message: "Turn on a light so the camera can see your eye clearly.",
                systemImage: "lightbulb.fill",
                tone: .warning
            )
        }
        switch controller.sample.setupState {
        case .tooClose:
            return .init(
                id: "close",
                title: "Move a little farther away",
                message: "Keep your face about an arm's length from the screen.",
                systemImage: "arrow.backward.circle.fill",
                tone: .warning
            )
        case .tooFar:
            return .init(
                id: "far",
                title: "Move a little closer",
                message: "Bring your face closer to the screen.",
                systemImage: "arrow.forward.circle.fill",
                tone: .warning
            )
        case .unknown:
            return .init(
                id: "face",
                title: "Centre your face",
                message: "Look toward the screen and keep your face inside the preview.",
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
                    title: "Eye patch not detected",
                    message: "Put on the prescribed patch and keep the other eye uncovered.",
                    systemImage: "eye.slash.fill",
                    tone: .warning
                )
            }
            if controller.sample.eyeAvailability == .none {
                return .init(
                    id: "eye",
                    title: "Keep the uncovered eye open",
                    message: "Face the screen and make sure the camera can see the uncovered eye.",
                    systemImage: "eye.fill",
                    tone: .warning
                )
            }
            if controller.patchWearState == .checking {
                return .init(
                    id: "checking",
                    title: "Checking the eye patch",
                    message: "Hold still for a moment.",
                    systemImage: "hourglass",
                    tone: .info
                )
            }
        }

        return .init(
            id: "ready",
            title: "Ready to calibrate",
            message: "Keep your head still, then select Start calibration.",
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
