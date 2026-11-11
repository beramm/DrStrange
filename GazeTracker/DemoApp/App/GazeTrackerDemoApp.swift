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
    @Published private(set) var blazeGazeSummaries: [GazeBlazeGazeValidationSummary] = []
    @Published private(set) var completedLayoutSummaries: [String: [Phase3ValidationSummary]] = [:]
    @Published private(set) var cameraStarted = false
    @Published private(set) var cameraInputStatus = "ARKit input pending"
    @Published private(set) var faceIsolationStatus = "Face isolation inactive"
    @Published private(set) var blazeGazeStatus = "BlazeGaze inactive"
    @Published private(set) var blazeGazePoint: CGPoint?
    @Published private(set) var performanceComparison = "Collecting no performance samples"
    @Published var selectedLayout: CalibrationLayout = .ninePosition
    @Published var selectedCameraInput: GazeCameraInputMode = .fullSensor
    @Published var faceIsolationEnabled = true {
        didSet {
            faceIsolation.isEnabled = faceIsolationEnabled
            refreshFaceIsolationStatus()
        }
    }
    @Published var oneEyeEnforcementEnabled = true {
        didSet {
            guard oneEyeEnforcementEnabled != oldValue else { return }
            tracker.setOneEyeEnforcementEnabled(oneEyeEnforcementEnabled)
            activeTarget = nil
            if sample.calibrationState != .notCalibrated {
                tracker.invalidateCalibration(reason: .activeEyeOrPatchSideChanged)
            }
            status = oneEyeEnforcementEnabled
                ? "One-eye enforcement ON — only the selected right eye may be visible"
                : "One-eye enforcement OFF — both eyes are allowed for this engineering run"
        }
    }

    let cameraPreview: UIView
    let faceIsolationPreview: UIView
    let blazeGazePreview: UIView
    private let tracker: GazeTracker
    private let cameraInput: GazeCameraInputConfiguration
    private let faceIsolation: GazeFaceIsolationConfiguration
    private let blazeGaze: GazeBlazeGazeConfiguration
    private var calibrationTargets: [NormalizedGazePoint] = []
    private var validationTargets: [NormalizedGazePoint] = []
    private var targetIndex = 0
    private var transitionPending = false
    private var wasPausedByScene = false
    private var isolationOnPerformance = PerformanceAccumulator()
    private var isolationOffPerformance = PerformanceAccumulator()
    private var previousPerformanceMode: Bool?
    private var previousReceiptTimestampNanoseconds: UInt64?

    init() {
        let engineeringHost = GazeTrackerFactory.makeTrackerWithVolatilePreview()
        tracker = engineeringHost.tracker
        cameraPreview = engineeringHost.preview
        cameraInput = engineeringHost.cameraInput
        faceIsolationPreview = engineeringHost.faceIsolationPreview
        faceIsolation = engineeringHost.faceIsolation
        blazeGazePreview = engineeringHost.blazeGazePreview
        blazeGaze = engineeringHost.blazeGaze
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
                self?.recordPerformance(for: value)
                self?.refreshFaceIsolationStatus()
                self?.refreshBlazeGazeStatus()
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
                status = "Camera started; ARKit control and BlazeGaze shadow are running together"
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
        blazeGazeSummaries = []
        blazeGaze.resetCalibration()
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
            blazeGaze.beginValidationPass(condition: condition.rawValue)
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
        refreshFaceIsolationStatus()
        refreshBlazeGazeStatus()
        status = "Stopped; all volatile calibration and gaze data discarded"
    }

    func resetPerformanceComparison() {
        isolationOnPerformance = PerformanceAccumulator()
        isolationOffPerformance = PerformanceAccumulator()
        previousPerformanceMode = nil
        previousReceiptTimestampNanoseconds = nil
        performanceComparison = "Comparison reset; collect samples with isolation on and off"
    }

    var eyeRequirementMet: Bool {
        switch sample.eyeAvailability {
        case .rightOnly:
            true
        case .both:
            !oneEyeEnforcementEnabled
        case .leftOnly, .none:
            false
        }
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
                let target = calibrationTargets[targetIndex]
                blazeGaze.beginCalibrationTarget(x: target.x, y: target.y)
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
                let target = validationTargets[targetIndex]
                blazeGaze.beginValidationTarget(x: target.x, y: target.y)
                try tracker.beginPhase3ValidationTarget(at: target)
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
            case (.ready, .both) where !oneEyeEnforcementEnabled:
                "Setup ready — both eyes allowed by the engineering override"
            case (.ready, .both):
                "One-eye enforcement is on — cover the left eye"
            case (.ready, _): "Keep the selected right eye open and visible"
            default: "Face not detected — centre your face 40–60 cm from the uncovered landscape camera"
            }
        }
        switch sample.calibrationState {
        case .targetAccepted:
            blazeGaze.finishCalibrationTarget()
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
            blazeGaze.finishValidationTarget()
            targetIndex += 1
            presentValidationTarget()
        case .retryTarget:
            status = "Validation target unstable — retrying the same target"
            presentValidationTarget()
        case .completed:
            _ = blazeGaze.finishValidationPass()
            activeTarget = nil
            validationTargets = []
            summaries = tracker.phase3ValidationSummaries()
            blazeGazeSummaries = blazeGaze.completedValidationSummaries()
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

    private func refreshFaceIsolationStatus() {
        let value = faceIsolation.status()
        let detection = value.detectionRate.map { String(format: "%.0f%%", $0 * 100) } ?? "—"
        let latest = value.latestProcessingLatencyMilliseconds.map { String(format: "%.1f ms", $0) } ?? "—"
        let p90 = value.p90ProcessingLatencyMilliseconds.map { String(format: "%.1f ms", $0) } ?? "—"
        let retained = value.sourcePixelFractionRetained.map { String(format: "%.1f%%", $0 * 100) } ?? "—"
        let crop = value.sourceCropEdgePixels.map(String.init) ?? "—"
        faceIsolationStatus = "\(value.state.rawValue) · detect \(detection) · crop \(crop) px → \(value.outputEdgePixels)² · source retained \(retained) · processing latest/p90 \(latest)/\(p90)"
    }

    private func refreshBlazeGazeStatus() {
        let value = blazeGaze.status()
        blazeGazePoint = value.latestCorrectedPoint
        let latest = value.latestLatencyMilliseconds.map { String(format: "%.1f ms", $0) } ?? "—"
        let p90 = value.p90LatencyMilliseconds.map { String(format: "%.1f ms", $0) } ?? "—"
        let raw = value.latestRawPoint.map {
            String(format: "(%.3f, %.3f)", $0.x, $0.y)
        } ?? "—"
        blazeGazeStatus = "\(value.state.rawValue) · predicted \(value.predictedFrameCount)/\(value.attemptedFrameCount) · raw \(raw) · latency latest/p90 \(latest)/\(p90) · RBF \(value.calibrationPointCount) pts \(value.isCalibrated ? "ready" : "collecting") · \(value.detail)"
    }

    private func recordPerformance(for sample: GazeSample) {
        guard cameraStarted else { return }
        let receipt = DispatchTime.now().uptimeNanoseconds
        let source = sample.timestamp.uptimeNanoseconds
        let latency = receipt >= source ? Double(receipt - source) / 1_000_000 : 0
        let mode = faceIsolation.isEnabled
        let interval: Double?
        if previousPerformanceMode == mode, let previousReceiptTimestampNanoseconds {
            interval = Double(receipt - previousReceiptTimestampNanoseconds) / 1_000_000_000
        } else {
            interval = nil
        }
        if mode {
            isolationOnPerformance.record(latencyMilliseconds: latency, intervalSeconds: interval)
        } else {
            isolationOffPerformance.record(latencyMilliseconds: latency, intervalSeconds: interval)
        }
        previousPerformanceMode = mode
        previousReceiptTimestampNanoseconds = receipt
        performanceComparison = "Isolation ON \(isolationOnPerformance.summary)  |  OFF \(isolationOffPerformance.summary)"
    }
}

private struct PerformanceAccumulator {
    private var latencies: [Double] = []
    private var intervals: [Double] = []

    mutating func record(latencyMilliseconds: Double, intervalSeconds: Double?) {
        latencies.append(latencyMilliseconds)
        if let intervalSeconds, intervalSeconds > 0 { intervals.append(intervalSeconds) }
        if latencies.count > 600 { latencies.removeFirst(latencies.count - 600) }
        if intervals.count > 600 { intervals.removeFirst(intervals.count - 600) }
    }

    var summary: String {
        guard let p90 = percentile(latencies, fraction: 0.90) else { return "n=0" }
        let rate = percentile(intervals, fraction: 0.50).map { 1 / $0 }
        let rateText = rate.map { String(format: "%.1f Hz", $0) } ?? "— Hz"
        let maximum = latencies.max() ?? p90
        return "n=\(latencies.count), gaze p90/max \(String(format: "%.1f/%.1f ms", p90, maximum)), \(rateText)"
    }

    private func percentile(_ values: [Double], fraction: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, Int(ceil(Double(sorted.count) * fraction)) - 1)
        return sorted[max(0, index)]
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
                if let point = model.blazeGazePoint {
                    BlazeGazeCursor()
                        .position(
                            x: min(max(point.x, 0), 1) * geometry.size.width,
                            y: min(max(point.y, 0), 1) * geometry.size.height
                        )
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
                Text("one-eye enforcement \(model.oneEyeEnforcementEnabled ? "on" : "off")")
                Text(model.cameraInputStatus)
            }
            .font(.caption.monospaced())
        }
        .padding(14)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
    }

    private func controls(size: CGSize) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 6) {
                    Text("Full ARKit frame").font(.caption.bold())
                    ZStack {
                        VolatileCameraPreview(view: model.cameraPreview)
                        if !model.cameraStarted { Color.black }
                    }
                    .frame(width: 374, height: 280)
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
                }
                VStack(spacing: 6) {
                    Text("Face isolation diagnostic · 224×224").font(.caption.bold())
                    VolatileCameraPreview(view: model.faceIsolationPreview)
                        .frame(width: 180, height: 180)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    Text("Actual BlazeGaze input · 512×128").font(.caption.bold())
                    VolatileCameraPreview(view: model.blazeGazePreview)
                        .frame(width: 320, height: 80)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            Toggle("Run volatile face-isolation assessment", isOn: $model.faceIsolationEnabled)
                .frame(maxWidth: 668)
            Toggle("Enforce one-eye-only input", isOn: $model.oneEyeEnforcementEnabled)
                .frame(maxWidth: 668)
            Text(model.faceIsolationStatus)
                .font(.caption.monospaced())
                .frame(maxWidth: 900, alignment: .leading)
            Text(model.blazeGazeStatus)
                .font(.caption.monospaced())
                .foregroundStyle(.green)
                .frame(maxWidth: 900, alignment: .leading)
            Text(model.performanceComparison)
                .font(.caption.monospaced())
                .frame(maxWidth: 900, alignment: .leading)
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
                    .disabled(model.sample.setupState != .ready || !model.eyeRequirementMet)
                Button("Run next untouched validation") { model.startNextValidation(in: size) }
                    .disabled(model.sample.calibrationState != .calibrated || model.summaries.count >= 3)
                Button("Stop") { model.stop() }
                Button("Reset comparison") { model.resetPerformanceComparison() }
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
            ForEach(Array(model.summaries.enumerated()), id: \.offset) { index, value in
                Text("ARKit · \(summaryText(value))")
                    .font(.caption.monospaced())
                if model.blazeGazeSummaries.indices.contains(index) {
                    Text(blazeGazeSummaryText(model.blazeGazeSummaries[index]))
                        .font(.caption.monospaced())
                        .foregroundStyle(.green)
                }
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

    private func blazeGazeSummaryText(_ value: GazeBlazeGazeValidationSummary) -> String {
        func number(_ value: Double?) -> String { value.map { String(format: "%.2f", $0) } ?? "—" }
        let passes = value.fixationCount == 10 && (value.p90RadiusCentimeters ?? .infinity) <= 4.0
        return "BlazeGaze · \(value.condition): n \(value.fixationCount)/10 · cm med \(number(value.medianRadiusCentimeters)) / p90 \(number(value.p90RadiusCentimeters)) / worst \(number(value.worstRadiusCentimeters)); \(passes ? "PASS" : "FAIL")"
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

private struct BlazeGazeCursor: View {
    var body: some View {
        ZStack {
            Circle().stroke(.black.opacity(0.8), lineWidth: 6).frame(width: 34, height: 34)
            Circle().stroke(.green, lineWidth: 4).frame(width: 30, height: 30)
            Circle().fill(.green).frame(width: 6, height: 6)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
