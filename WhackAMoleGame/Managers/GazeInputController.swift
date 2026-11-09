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
    private(set) var patchWearState: PatchWearState = .checking
    private(set) var oneEyeEnforcerEnabled = true

    let cameraPreview: UIView

    @ObservationIgnored private let tracker: GazeTracker
    @ObservationIgnored private let cameraInput: GazeCameraInputConfiguration
    @ObservationIgnored private var calibrationTargets: [NormalizedGazePoint] = []
    @ObservationIgnored private var targetIndex = 0
    @ObservationIgnored private var transitionPending = false
    @ObservationIgnored private var calibrationTask: Task<Void, Never>?
    @ObservationIgnored private var wasPausedByScene = false
    @ObservationIgnored private var patchWearMonitor = PatchWearMonitor()

    init() {
        let host = GazeTrackerFactory.makeTrackerWithVolatilePreview()
        tracker = host.tracker
        cameraPreview = host.preview
        cameraInput = host.cameraInput
        cameraInput.mode = .zoomedOnePointFive
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
            selectedRightEyeIsAvailable &&
            isPatchVerified
    }

    var isCalibrated: Bool { sample.calibrationState == .calibrated }

    var isPatchVerified: Bool { !oneEyeEnforcerEnabled || patchWearState == .verified }

    var hasUsableGaze: Bool {
        isCalibrated &&
            sample.trackingState == .tracking &&
            sample.setupState == .ready &&
            selectedRightEyeIsAvailable &&
            sample.quality.level == .usable &&
            sample.pointNormalized != nil
    }

    private var selectedRightEyeIsAvailable: Bool {
        sample.eyeAvailability == .rightOnly ||
            (!oneEyeEnforcerEnabled && sample.eyeAvailability == .both)
    }

    func setOneEyeEnforcerEnabled(_ enabled: Bool) {
        guard oneEyeEnforcerEnabled != enabled else { return }
        oneEyeEnforcerEnabled = enabled
        tracker.setOneEyeEnforcementEnabled(enabled)
        patchWearMonitor.reset()
        patchWearState = enabled ? .checking : .verified
        processCalibrationState()
    }

    func startCamera() {
        guard !cameraStarted else { return }
        cameraInput.mode = .zoomedOnePointFive
        Task {
            do {
                try await tracker.start()
                cameraStarted = true
                updateCameraStatus()
                status = oneEyeEnforcerEnabled
                    ? "Centre your face 40–60 cm away and keep the right eye visible"
                    : "Testing mode — centre your face with the right eye visible"
            } catch {
                updateCameraStatus()
                status = "Camera start failed: \(error)"
            }
        }
    }

    func startCalibration() {
        guard isReadyToCalibrate, !transitionPending else { return }
        calibrationTask?.cancel()
        transitionPending = true
        isPreparingCalibration = true
        activeCalibrationTarget = nil
        status = "Hold still — calibration begins in 3 seconds"

        do {
            try tracker.beginCalibration(layout: Self.calibrationLayout)
        } catch {
            transitionPending = false
            isPreparingCalibration = false
            status = "Calibration blocked: \(error)"
            return
        }

        calibrationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled else { return }
            calibrationTargets = Self.calibrationLayout.targets
            targetIndex = 0
            transitionPending = false
            isPreparingCalibration = false
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
        activeCalibrationTarget = nil
        patchWearMonitor.reset()
        patchWearState = oneEyeEnforcerEnabled ? .checking : .verified
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
                transitionPending = false
            } catch {
                transitionPending = false
                status = "Target rejected: \(error)"
            }
        }
    }

    private func processCalibrationState() {
        if cameraStarted, activeCalibrationTarget == nil, !isPreparingCalibration, !isCalibrated {
            status = switch (sample.setupState, sample.eyeAvailability, oneEyeEnforcerEnabled) {
            case (.tooClose, _, _): "Move farther from the front camera"
            case (.tooFar, _, _): "Move closer to the front camera"
            case (.ready, .both, false), (.ready, .rightOnly, false): "Testing mode — start calibration"
            case (.ready, .both, true): "Put on the prescribed eye patch and keep your face still"
            case (.ready, .rightOnly, true) where patchWearState == .verified: "One-eye check passed — start calibration"
            case (.ready, .rightOnly, true): "Checking the patch — keep still"
            case (.ready, .leftOnly, _): "Keep the right eye uncovered and visible"
            case (.ready, .none, _): "Keep the right eye open and visible"
            default: "Centre your face 40–60 cm from the landscape camera"
            }
        }

        guard !transitionPending else { return }
        switch sample.calibrationState {
        case .targetAccepted:
            targetIndex += 1
            presentCalibrationTarget()
        case .retryTarget:
            status = "That target was unstable — hold still and retry"
            presentCalibrationTarget()
        case .calibrated:
            calibrationTask?.cancel()
            activeCalibrationTarget = nil
            status = "Calibration complete — ready to play"
        case .invalid:
            activeCalibrationTarget = nil
            status = "Calibration was lost — return and recalibrate"
        case .failed:
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
        sample = value
        guard oneEyeEnforcerEnabled else {
            patchWearState = .verified
            processCalibrationState()
            return
        }
        let observation: PatchEyeObservation
        if value.setupState != .ready {
            observation = .unavailable
        } else {
            observation = switch value.eyeAvailability {
            case .both: .bothEyes
            case .rightOnly: .expectedEyeOnly
            case .leftOnly: .otherEyeOnly
            case .none: .unavailable
            }
        }
        patchWearState = patchWearMonitor.consume(
            observation,
            timestampNanoseconds: value.timestamp.uptimeNanoseconds
        )
        processCalibrationState()
    }
}
