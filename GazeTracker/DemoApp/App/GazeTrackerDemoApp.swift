@_spi(Engineering) import DrStrangeGazeTracker
@_spi(Engineering) import DrStrangeGazeTrackerPlatform
import SwiftUI
import UIKit

@main
struct GazeTrackerDemoApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = DemoModel()

    var body: some Scene {
        WindowGroup {
            Phase3ExperimentView(model: model)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active: model.resumeIfPaused()
                    case .inactive, .background: model.pauseIfRunning()
                    @unknown default: model.pauseIfRunning()
                    }
                }
        }
    }
}

@MainActor
final class DemoModel: ObservableObject {
    @Published private(set) var sample: GazeSample
    @Published private(set) var activeTarget: NormalizedGazePoint?
    @Published private(set) var status = "Start the camera and reach setup ready"
    @Published private(set) var summaries: [Phase3ValidationSummary] = []
    @Published private(set) var completedLayoutSummaries: [String: [Phase3ValidationSummary]] = [:]
    @Published private(set) var cameraStarted = false
    @Published private(set) var cameraInputStatus = "ARKit input pending"
    @Published var selectedLayout: CalibrationLayout = .ninePosition
    @Published var selectedCameraInput: GazeCameraInputMode = .fullSensor

    let cameraPreview: UIView
    private let tracker: GazeTracker
    private let cameraInput: GazeCameraInputConfiguration
    private var calibrationTargets: [NormalizedGazePoint] = []
    private var validationTargets: [NormalizedGazePoint] = []
    private var targetIndex = 0
    private var transitionPending = false
    private var wasPausedByScene = false

    init() {
        let engineeringHost = GazeTrackerFactory.makeTrackerWithVolatilePreview()
        tracker = engineeringHost.tracker
        cameraPreview = engineeringHost.preview
        cameraInput = engineeringHost.cameraInput
        sample = GazeSample(
            pointNormalized: nil,
            timestamp: MonotonicTimestamp(uptimeNanoseconds: 0),
            quality: .unavailable,
            trackingState: .paused,
            setupState: .unknown,
            calibrationState: .notCalibrated,
            eyeAvailability: .none
        )
        tracker.setSampleHandler { [weak self] value in
            Task { @MainActor in
                self?.sample = value
                self?.processExperimentState()
            }
        }
    }

    func startCamera() {
        guard !cameraStarted else { return }
        cameraInput.mode = selectedCameraInput
        Task {
            do {
                try await tracker.start()
                cameraStarted = true
                cameraInputStatus = captureStatusText(cameraInput.status())
                status = "Camera started; hold the selected right eye open at 40–60 cm"
            } catch {
                cameraInputStatus = captureStatusText(cameraInput.status())
                status = "Camera start failed: \(error)"
            }
        }
    }

    func startCalibration() {
        guard !transitionPending else { return }
        transitionPending = true
        activeTarget = nil
        validationTargets = []
        summaries = []
        status = "Hold still — calibration begins in 3 seconds"
        do {
            try tracker.beginCalibration(layout: selectedLayout)
        } catch {
            transitionPending = false
            status = "Calibration blocked: \(error)"
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            calibrationTargets = selectedLayout.targets
            targetIndex = 0
            transitionPending = false
            presentCalibrationTarget()
        }
    }

    func startNextValidation(in size: CGSize) {
        guard sample.calibrationState == .calibrated, !transitionPending else { return }
        let condition: Phase3ValidationCondition
        switch summaries.count {
        case 0: condition = .consecutiveOne
        case 1: condition = .consecutiveTwo
        case 2: condition = .modestHeadMovement
        default:
            status = tracker.phase3GatePassed()
                ? "Phase 3 gate passed; stop without starting Phase 4"
                : "Phase 3 gate failed; stop without weakening 4.0 cm"
            return
        }
        guard let viewport = GazeViewport(width: size.width, height: size.height) else { return }
        validationTargets = Phase3ValidationPlan.targets.shuffled()
        do {
            try tracker.beginPhase3Validation(
                condition: condition,
                randomizedTargets: validationTargets,
                viewport: viewport
            )
            targetIndex = 0
            status = condition == .modestHeadMovement
                ? "Validation 3/3: make only modest permitted head movements"
                : "Validation \(summaries.count + 1)/3: keep the current calibration"
            presentValidationTarget()
        } catch {
            status = "Validation blocked: \(error)"
        }
    }

    func stop() {
        tracker.stop()
        cameraStarted = false
        activeTarget = nil
        cameraInputStatus = "ARKit input stopped; camera restored to 1.0×"
        status = "Stopped; all volatile calibration and gaze data discarded"
    }

    func pauseIfRunning() {
        guard sample.trackingState != .paused else { return }
        do {
            try tracker.pause()
            wasPausedByScene = true
        } catch {
            status = "Pause rejected: \(error)"
        }
    }

    func resumeIfPaused() {
        guard wasPausedByScene else { return }
        wasPausedByScene = false
        Task {
            do { try await tracker.resume() }
            catch { status = "Resume failed: \(error)" }
        }
    }

    private func presentCalibrationTarget() {
        guard targetIndex < calibrationTargets.count else { return }
        transitionPending = true
        activeTarget = calibrationTargets[targetIndex]
        status = "Calibration target \(targetIndex + 1)/\(calibrationTargets.count) — fixate until accepted"
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            do {
                try tracker.beginCalibrationTarget(at: calibrationTargets[targetIndex])
                transitionPending = false
            } catch {
                transitionPending = false
                status = "Calibration target rejected: \(error)"
            }
        }
    }

    private func presentValidationTarget() {
        guard targetIndex < validationTargets.count else { return }
        transitionPending = true
        activeTarget = validationTargets[targetIndex]
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            do {
                try tracker.beginPhase3ValidationTarget(at: validationTargets[targetIndex])
                transitionPending = false
            } catch {
                transitionPending = false
                status = "Validation target rejected: \(error)"
            }
        }
    }

    private func processExperimentState() {
        guard !transitionPending else { return }
        if cameraStarted, sample.calibrationState == .notCalibrated, activeTarget == nil {
            status = switch (sample.setupState, sample.eyeAvailability) {
            case (.tooClose, _): "Move farther from the front camera"
            case (.tooFar, _): "Move closer to the front camera"
            case (.ready, .rightOnly): "Setup ready — choose a layout and calibrate"
            case (.ready, _): "Keep the selected right eye open and visible"
            default: "Face not detected — centre your face 40–60 cm from the uncovered landscape camera"
            }
        }
        switch sample.calibrationState {
        case .targetAccepted:
            targetIndex += 1
            presentCalibrationTarget()
            return
        case .retryTarget:
            status = "Calibration target unstable — retrying the same target"
            presentCalibrationTarget()
            return
        case .calibrated where activeTarget != nil && validationTargets.isEmpty:
            activeTarget = nil
            status = "Calibration fitted; run two consecutive validations, then head movement"
        case .failed:
            activeTarget = nil
            status = "Calibration failed; retry without changing the acceptance threshold"
        default: break
        }

        switch tracker.phase3ValidationState() {
        case .targetAccepted:
            targetIndex += 1
            presentValidationTarget()
        case .retryTarget:
            status = "Validation target unstable — retrying the same target"
            presentValidationTarget()
        case .completed:
            activeTarget = nil
            validationTargets = []
            summaries = tracker.phase3ValidationSummaries()
            if summaries.count == 3 {
                completedLayoutSummaries["\(selectedLayout.rawValue)|\(selectedCameraInput.rawValue)"] = summaries
                status = tracker.phase3GatePassed()
                    ? "PASS: all three raw p90 radii are ≤4.0 cm"
                    : "FAIL: at least one raw p90 radius exceeds 4.0 cm"
            } else {
                status = "Validation complete; start the next pass without recalibrating"
            }
        case .failed:
            activeTarget = nil
            status = "Validation failed; raw Phase 3 gate not met"
        default: break
        }
    }

    private func captureStatusText(_ value: GazeCameraInputStatus) -> String {
        let requested = String(format: "%.1f×", value.requestedZoomFactor)
        guard let applied = value.appliedZoomFactor else {
            if let minimum = value.minimumZoomFactor, let maximum = value.maximumZoomFactor {
                return "ARKit input \(requested) unavailable (range \(String(format: "%.1f", minimum))–\(String(format: "%.1f", maximum))×)"
            }
            return "ARKit input \(requested) unavailable on this capture device"
        }
        return "ARKit input applied \(String(format: "%.1f×", applied))"
    }
}

private struct Phase3ExperimentView: View {
    @ObservedObject var model: DemoModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.03, green: 0.04, blue: 0.07).ignoresSafeArea()
                if let target = model.activeTarget {
                    FixationTarget()
                        .position(x: target.x * geometry.size.width, y: target.y * geometry.size.height)
                }
                VStack(spacing: 12) {
                    statusPanel
                    Spacer()
                    if model.activeTarget == nil { controls(size: geometry.size) }
                    summaryPanel
                }
                .padding(22)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var statusPanel: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DrStrange custom Phase 3").font(.headline)
                Text(model.status).font(.subheadline)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("tracking \(model.sample.trackingState.rawValue)")
                Text("setup \(model.sample.setupState.rawValue)")
                Text("eye \(model.sample.eyeAvailability.rawValue)")
                Text("calibration \(model.sample.calibrationState.rawValue)")
                Text(model.cameraInputStatus)
            }
            .font(.caption.monospaced())
        }
        .padding(14)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
    }

    private func controls(size: CGSize) -> some View {
        VStack(spacing: 10) {
            ZStack {
                VolatileCameraPreview(view: model.cameraPreview)
                if !model.cameraStarted {
                    Color.black
                }
            }
                .frame(width: 520, height: 390)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .bottom) {
                    Text(model.cameraInputStatus)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.72), in: Capsule())
                        .padding(10)
                }
            Picker("ARKit camera input", selection: $model.selectedCameraInput) {
                Text("Full sensor (1.0×)").tag(GazeCameraInputMode.fullSensor)
                Text("Real camera zoom (1.5×)").tag(GazeCameraInputMode.zoomedOnePointFive)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 520)
            .disabled(model.cameraStarted)
            Picker("Calibration layout", selection: $model.selectedLayout) {
                Text("Nine positions").tag(CalibrationLayout.ninePosition)
                Text("Perimeter → centre (13)").tag(CalibrationLayout.perimeterToCentre13)
            }
            .pickerStyle(.segmented)
            .disabled(model.sample.calibrationState == .calibrated)
            HStack {
                Button(model.cameraStarted ? "Camera started" : "Start camera") { model.startCamera() }
                    .disabled(model.cameraStarted)
                Button("Calibrate selected layout") { model.startCalibration() }
                    .disabled(model.sample.setupState != .ready || model.sample.eyeAvailability != .rightOnly)
                Button("Run next untouched validation") { model.startNextValidation(in: size) }
                    .disabled(model.sample.calibrationState != .calibrated || model.summaries.count >= 3)
                Button("Stop") { model.stop() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
    }

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Raw mapping evidence — no smoothing or interaction assistance")
                .font(.caption.bold())
            ForEach(Array(model.summaries.enumerated()), id: \.offset) { _, value in
                Text(summaryText(value)).font(.caption.monospaced())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
    }

    private func summaryText(_ value: Phase3ValidationSummary) -> String {
        func number(_ value: Double?) -> String { value.map { String(format: "%.2f", $0) } ?? "—" }
        return "\(value.condition.rawValue): cm med \(number(value.rawRadiusCentimeters.median)) / p90 \(number(value.rawRadiusCentimeters.p90)) / worst \(number(value.rawRadiusCentimeters.worst)); \(value.passesFourCentimeterGate ? "PASS" : "FAIL")"
    }
}

private struct VolatileCameraPreview: UIViewRepresentable {
    let view: UIView

    func makeUIView(context: Context) -> UIView { view }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

private struct FixationTarget: View {
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
