import SwiftUI

@main
struct Phase1ProbeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller = ProbeController()

    var body: some Scene {
        WindowGroup {
            ProbeView(controller: controller)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        if controller.trackingState == .paused { controller.resumeTracking() }
                    case .inactive, .background:
                        controller.pauseTracking()
                    @unknown default:
                        controller.pauseTracking()
                    }
                }
        }
    }
}

private struct ProbeView: View {
    @ObservedObject var controller: ProbeController

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.08).ignoresSafeArea()

                if let target = controller.activeTarget {
                    TargetMarker()
                        .position(
                            x: target.x * geometry.size.width,
                            y: target.y * geometry.size.height
                        )
                }

                VStack(spacing: 14) {
                    statusPanel
                    Spacer()
                    if controller.isBusy {
                        Button("Cancel engineering run") { controller.cancelRun() }
                            .buttonStyle(.bordered)
                    } else {
                        controls
                    }
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var statusPanel: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DrStrange Phase 1 Selected-Eye ARKit Probe")
                    .font(.headline)
                Text(controller.activity)
                    .font(.subheadline.monospaced())
                Text(controller.aggregateStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("tracking: \(controller.trackingState.rawValue)")
                Text("setup: \(controller.setupState.rawValue)")
                Text("calibration: \(controller.calibrationState.rawValue)")
                Text("eyes: \(controller.eyeAvailability.rawValue)")
                Text("AR face support: \(controller.arFaceTrackingSupported ? "yes" : "no")")
            }
            .font(.caption.monospaced())
        }
        .padding(14)
        .background(.black.opacity(0.60), in: RoundedRectangle(cornerRadius: 12))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("Engineering condition", selection: $controller.selectedCondition) {
                ForEach(ProbeCondition.allCases) { condition in
                    Text(condition.label).tag(condition)
                }
            }
            .pickerStyle(.menu)

            Picker("Active gaze source", selection: $controller.selectedGazeSource) {
                ForEach(ProbeGazeSource.allCases) { source in
                    Text(source.label).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .disabled(controller.selectedCondition.forcedGazeSource != nil)

            HStack(spacing: 12) {
                Button("Start camera") { controller.startTracking() }
                    .buttonStyle(.borderedProminent)
                Button("Calibrate") { controller.startCalibration() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!controller.canCalibrate)
                Button("Validate held-out targets") { controller.startValidation() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!controller.canValidate)
                Button("Record 10s setup state") { controller.startSetupCheck() }
                    .buttonStyle(.bordered)
                    .disabled(!controller.canRunSetupCheck)
                Button("Invalidate calibration") { controller.invalidateCalibration() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct TargetMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(.white, lineWidth: 6)
                .frame(width: 70, height: 70)
            Circle()
                .fill(.orange)
                .frame(width: 20, height: 20)
            Rectangle()
                .fill(.white)
                .frame(width: 2, height: 90)
            Rectangle()
                .fill(.white)
                .frame(width: 90, height: 2)
        }
        .accessibilityHidden(true)
    }
}
