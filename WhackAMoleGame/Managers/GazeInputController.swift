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
    private(set) var sample: GazeSample
    private(set) var activeCalibrationTarget: NormalizedGazePoint?
    private(set) var status = "Starting the front camera…"
    private(set) var cameraStatus = "ARKit input pending"
    private(set) var cameraStarted = false
    private(set) var isPreparingCalibration = false

    let cameraPreview: UIView

    @ObservationIgnored private let tracker: GazeTracker
    @ObservationIgnored private let cameraInput: GazeCameraInputConfiguration
    @ObservationIgnored private var calibrationTargets: [NormalizedGazePoint] = []
    @ObservationIgnored private var targetIndex = 0
    @ObservationIgnored private var transitionPending = false
    @ObservationIgnored private var calibrationTask: Task<Void, Never>?
    @ObservationIgnored private var wasPausedByScene = false

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
                self?.sample = value
                self?.processCalibrationState()
            }
        }
    }

    var isReadyToCalibrate: Bool {
        cameraStarted && sample.setupState == .ready && sample.eyeAvailability == .rightOnly
    }

    var isCalibrated: Bool { sample.calibrationState == .calibrated }

    var hasUsableGaze: Bool {
        isCalibrated &&
            sample.trackingState == .tracking &&
            sample.setupState == .ready &&
            sample.eyeAvailability == .rightOnly &&
            sample.quality.level == .usable &&
            sample.pointNormalized != nil
    }

    func startCamera() {
        guard !cameraStarted else { return }
        cameraInput.mode = .zoomedOnePointFive
        Task {
            do {
                try await tracker.start()
                cameraStarted = true
                updateCameraStatus()
                status = "Centre your face 40–60 cm away and keep the right eye visible"
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
            try tracker.beginCalibration(layout: .perimeterToCentre13)
        } catch {
            transitionPending = false
            isPreparingCalibration = false
            status = "Calibration blocked: \(error)"
            return
        }

        calibrationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled else { return }
            calibrationTargets = CalibrationLayout.perimeterToCentre13.targets
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
            status = switch (sample.setupState, sample.eyeAvailability) {
            case (.tooClose, _): "Move farther from the front camera"
            case (.tooFar, _): "Move closer to the front camera"
            case (.ready, .rightOnly): "Ready — start calibration"
            case (.ready, _): "Keep the selected right eye open and visible"
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
}
