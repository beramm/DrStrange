import Dispatch
@_spi(Engineering) import DrStrangeGazeTracker
@_spi(Engineering) import DrStrangeGazeTrackerPlatform
import Observation
import SwiftUI
import UIKit

/// Owns one volatile custom-tracker session across calibration and gameplay.
/// No frame, calibration observation, gaze sample, or gaze path is persisted.
@MainActor
@Observable
final class GazeInputController {
    private static let calibrationLayout = CalibrationLayout.ninePosition

    private(set) var sample: GazeSample
    private(set) var activeCalibrationTarget: NormalizedGazePoint?
    private(set) var status = "Starting the front camera…"
    private(set) var cameraStatus = "ARKit input pending"
    private(set) var cameraStarted = false
    private(set) var isPreparingCalibration = false
    private(set) var calibrationCountdown = 0
    private(set) var patchWearState: PatchWearState = .checking
    private(set) var oneEyeEnforcerEnabled = true
    private(set) var isSceneTooDark = false

    let cameraPreview: UIView

    @ObservationIgnored private let tracker: GazeTracker
    @ObservationIgnored private let cameraInput: GazeCameraInputConfiguration
    @ObservationIgnored private let ambientLight: GazeAmbientLightConfiguration
    @ObservationIgnored private var calibrationTargets: [NormalizedGazePoint] = []
    @ObservationIgnored private var targetIndex = 0
    @ObservationIgnored private var transitionPending = false
    @ObservationIgnored private var calibrationTask: Task<Void, Never>?
    @ObservationIgnored private var wasPausedByScene = false
    @ObservationIgnored private var patchWearMonitor = PatchWearMonitor()
    @ObservationIgnored private var calibrationSampleGate = CalibrationSampleGate()

    init() {
        // Paddy links only the native full-sensor ARKit tracker product. The
        // experimental model sidecars live in the separate engineering product.
        let host = GazeTrackerFactory.makeTrackerWithVolatilePreview(
            faceIsolationEnabled: false
        )
        tracker = host.tracker
        cameraPreview = host.preview
        cameraInput = host.cameraInput
        ambientLight = host.ambientLight
        cameraInput.mode = .fullSensor
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
                self?.consume(value)
            }
        }
    }

    var isReadyToCalibrate: Bool {
        cameraStarted &&
            sample.setupState == .ready &&
            visibleEyeIsAvailable &&
            isPatchVerified &&
            !isSceneTooDark
    }

    var calibrationNeedsGuidance: Bool {
        activeCalibrationTarget != nil && !isReadyToCalibrate
    }

    var isCalibrated: Bool { sample.calibrationState == .calibrated }

    var isPatchVerified: Bool { !oneEyeEnforcerEnabled || patchWearState == .verified }

    var hasUsableGaze: Bool {
        isCalibrated &&
            sample.trackingState == .tracking &&
            sample.setupState == .ready &&
            visibleEyeIsAvailable &&
            sample.quality.level == .usable &&
            sample.pointNormalized != nil
    }

    private var visibleEyeIsAvailable: Bool {
        sample.eyeAvailability == .leftOnly ||
            sample.eyeAvailability == .rightOnly ||
            (!oneEyeEnforcerEnabled && sample.eyeAvailability == .both)
    }

    func setOneEyeEnforcerEnabled(_ enabled: Bool) {
        guard oneEyeEnforcerEnabled != enabled else { return }
        oneEyeEnforcerEnabled = enabled
        tracker.setOneEyeEnforcementEnabled(enabled)
        patchWearMonitor.reset()
        patchWearState = enabled ? .checking : .verified
        processCalibrationState(isCurrentTargetResult: false)
    }

    func startCamera() {
        guard !cameraStarted else { return }
        cameraInput.mode = .fullSensor
        Task {
            do {
                try await tracker.start()
                cameraStarted = true
                updateCameraStatus()
                status = oneEyeEnforcerEnabled
                    ? "Centre your face 40–60 cm away and keep the uncovered eye visible"
                    : "Testing mode — centre your face and keep your eyes visible"
            } catch {
                updateCameraStatus()
                status = "Camera start failed: \(error)"
            }
        }
    }

    func startCalibration(preparationSeconds: Int = 6) {
        guard isReadyToCalibrate, !transitionPending else { return }
        let preparationSeconds = max(preparationSeconds, 1)
        calibrationTask?.cancel()
        transitionPending = true
        isPreparingCalibration = true
        calibrationCountdown = preparationSeconds
        activeCalibrationTarget = nil
        status = "Hold still — calibration begins in \(preparationSeconds) seconds"

        do {
            try tracker.beginCalibration(layout: Self.calibrationLayout)
        } catch {
            transitionPending = false
            isPreparingCalibration = false
            calibrationCountdown = 0
            status = "Calibration blocked: \(error)"
            return
        }

        calibrationTask = Task { [weak self] in
            for remaining in stride(from: preparationSeconds, through: 1, by: -1) {
                guard let self, !Task.isCancelled else { return }
                calibrationCountdown = remaining
                try? await Task.sleep(for: .seconds(1))
            }
            guard let self, !Task.isCancelled else { return }
            calibrationTargets = Self.calibrationLayout.targets
            targetIndex = 0
            transitionPending = false
            isPreparingCalibration = false
            calibrationCountdown = 0
            presentCalibrationTarget()
        }
    }

    func stop() {
        calibrationTask?.cancel()
        calibrationTask = nil
        tracker.stop()
        cameraStarted = false
        transitionPending = false
        isPreparingCalibration = false
        calibrationCountdown = 0
        activeCalibrationTarget = nil
        patchWearMonitor.reset()
        patchWearState = oneEyeEnforcerEnabled ? .checking : .verified
        isSceneTooDark = false
        status = "Stopped; volatile gaze and calibration data discarded"
        cameraStatus = "ARKit input stopped; camera restored to 1.0×"
    }

    func pauseForInactiveScene() {
        guard cameraStarted, sample.trackingState != .paused else { return }
        do {
            try tracker.pause()
            wasPausedByScene = true
        } catch {
            status = "Pause rejected: \(error)"
        }
    }

    func resumeForActiveScene() {
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
        let target = calibrationTargets[targetIndex]
        activeCalibrationTarget = target
        status = "Target \(targetIndex + 1) of \(calibrationTargets.count) — look at the centre"

        calibrationTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            do {
                try tracker.beginCalibrationTarget(at: target)
                calibrationSampleGate.markTargetStarted(
                    at: DispatchTime.now().uptimeNanoseconds
                )
                transitionPending = false
            } catch {
                transitionPending = false
                status = "Target rejected: \(error)"
            }
        }
    }

    private func processCalibrationState(isCurrentTargetResult: Bool) {
        if sample.calibrationState == .invalid {
            calibrationTask?.cancel()
            calibrationTask = nil
            transitionPending = false
            isPreparingCalibration = false
            calibrationCountdown = 0
            activeCalibrationTarget = nil
            calibrationTargets.removeAll(keepingCapacity: true)
            targetIndex = 0
            status = sample.setupState == .movingTooMuch
                ? "Too much movement — hold still, then restart calibration"
                : "Calibration was lost — return and recalibrate"
            return
        }

        if cameraStarted, activeCalibrationTarget == nil, !isPreparingCalibration, !isCalibrated {
            status = switch (sample.setupState, sample.eyeAvailability, oneEyeEnforcerEnabled) {
            case (.tooClose, _, _): "Move farther from the front camera"
            case (.tooFar, _, _): "Move closer to the front camera"
            case (.misaligned, _, _): "Point your nose at the iPad"
            case (.lookUp, _, _): "Look up a little"
            case (.lookDown, _, _): "Look down a little"
            case (.turnLeft, _, _): "Turn left a little"
            case (.turnRight, _, _): "Turn right a little"
            case (.movingTooMuch, _, _): "Too much movement — hold still"
            case (.stabilizing, _, _): "Hold still"
            case (.ready, .both, false): "Testing mode — start calibration"
            case (.ready, .both, true): "Put on the prescribed eye patch and keep your face still"
            case (.ready, .leftOnly, true), (.ready, .rightOnly, true):
                patchWearState == .verified
                    ? "One-eye check passed — start calibration"
                    : "Checking the patch — keep still"
            case (.ready, .leftOnly, false), (.ready, .rightOnly, false): "Testing mode — start calibration"
            case (.ready, .none, _): "Keep the uncovered eye open and visible"
            default: "Centre your face 40–60 cm from the landscape camera"
            }
        }

        guard !transitionPending else { return }
        switch sample.calibrationState {
        case .targetAccepted:
            guard isCurrentTargetResult else { return }
            targetIndex += 1
            presentCalibrationTarget()
        case .retryTarget:
            guard isCurrentTargetResult else { return }
            status = "That target was unstable — hold still and retry"
            presentCalibrationTarget()
        case .calibrated:
            guard isCurrentTargetResult else { return }
            calibrationTask?.cancel()
            activeCalibrationTarget = nil
            status = "Calibration complete — ready to play"
        case .invalid:
            break
        case .failed:
            guard isCurrentTargetResult else { return }
            activeCalibrationTarget = nil
            status = "Calibration failed — try again"
        default:
            break
        }
    }

    private func updateCameraStatus() {
        let value = cameraInput.status()
        if let applied = value.appliedZoomFactor {
            cameraStatus = String(format: "Custom ARKit camera input %.1f×", applied)
        } else {
            cameraStatus = "Custom ARKit camera input unavailable"
        }
    }

    private func consume(_ value: GazeSample) {
        let isTargetResult = switch value.calibrationState {
        case .targetAccepted, .retryTarget, .calibrated, .failed: true
        default: false
        }
        let decision = calibrationSampleGate.evaluate(
            timestampNanoseconds: value.timestamp.uptimeNanoseconds,
            isTargetResult: isTargetResult
        )
        guard decision.shouldConsume else { return }

        sample = value
        isSceneTooDark = ambientLight.state() == .tooDark
        guard oneEyeEnforcerEnabled else {
            patchWearState = .verified
            processCalibrationState(isCurrentTargetResult: decision.isCurrentTargetResult)
            return
        }
        let observation: PatchEyeObservation
        if value.setupState != .ready {
            observation = .unavailable
        } else {
            observation = switch value.eyeAvailability {
            case .both: .bothEyes
            case .leftOnly, .rightOnly: .singleEye
            case .none: .unavailable
            }
        }
        patchWearState = patchWearMonitor.consume(
            observation,
            timestampNanoseconds: value.timestamp.uptimeNanoseconds
        )
        processCalibrationState(isCurrentTargetResult: decision.isCurrentTargetResult)
    }
}
