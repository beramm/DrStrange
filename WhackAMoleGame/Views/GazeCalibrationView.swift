import SwiftUI
import UIKit

/// Pre-game calibration for the custom selected-right-eye tracker.
struct GazeCalibrationView: View {
    let controller: GazeInputController
    let onCalibrated: () -> Void
    let onCancel: () -> Void

    @State private var didComplete = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.03, green: 0.04, blue: 0.07).ignoresSafeArea()

                if let target = controller.activeCalibrationTarget {
                    CalibrationFixationTarget()
                        .position(
                            x: target.x * geometry.size.width,
                            y: target.y * geometry.size.height
                        )
                } else {
                    setupPanel
                }

                statusPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(20)
            }
        }
        .preferredColorScheme(.dark)
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
            Spacer(minLength: 110)
            Text("Set up eye control")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
            Text("Use the preview to centre your face. Keep the right eye open and look directly at each target.")
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
    }

    private var statusPanel: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(controller.status).font(.headline)
                Text(controller.cameraStatus).font(.caption.monospaced())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("tracking \(controller.sample.trackingState.rawValue)")
                Text("setup \(controller.sample.setupState.rawValue)")
                Text("eye \(controller.sample.eyeAvailability.rawValue)")
                Text("calibration \(controller.sample.calibrationState.rawValue)")
            }
            .font(.caption.monospaced())
        }
        .padding(14)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 16))
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
            Circle().stroke(.white, lineWidth: 5).frame(width: 72, height: 72)
            Circle().fill(.orange).frame(width: 30, height: 30)
                .scaleEffect(contracted ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: contracted)
        }
        .onAppear { contracted = true }
        .accessibilityHidden(true)
    }
}
