import DrStrangeGazeTracker
import Foundation
import ImageIO
import Observation
import SwiftUI
import UIKit

/// Owns Paddy's volatile on-device camera, Vision, Core ML and calibration flow.
/// Camera frames and eye crops are never retained, written, or uploaded.
@MainActor
@Observable
final class GazeInputController {
    private(set) var sample: GazeSample
    private(set) var activeCalibrationTarget: NormalizedGazePoint?
    private(set) var status = "Starting the front camera…"
    private(set) var cameraStatus = "paddy-gazeTrack loading…"
    private(set) var cameraStarted = false
    private(set) var isPreparingCalibration = false
    private(set) var isResumingCalibration = false
    private(set) var calibrationCountdown = 0
    private(set) var patchWearState: PatchWearState = .checking
    private(set) var oneEyeEnforcerEnabled = true
    private(set) var isSceneTooDark = false
    private(set) var isFrameCaptureReady = false
    private(set) var unclampedCalibratedPoint: CGPoint?
    private(set) var completedCalibrationCount = 0

    var cameraPreview: UIView { runtime.previewView }

    @ObservationIgnored private let runtime = PaddyGazeRuntime()
    @ObservationIgnored private var calibration: PersonalizedGazeCalibration?
    @ObservationIgnored private var calibrationState: CalibrationState = .notCalibrated
    @ObservationIgnored private var calibrationTask: Task<Void, Never>?
    @ObservationIgnored private var wasPausedByScene = false
    @ObservationIgnored private var patchWearMonitor = PatchWearMonitor()
    @ObservationIgnored private var stableSetupState: SetupState = .unknown
    @ObservationIgnored private var pendingSetupState: SetupState?
    @ObservationIgnored private var pendingSetupFrameCount = 0
    @ObservationIgnored private var lastImageOrientation: CGImagePropertyOrientation?
    @ObservationIgnored private var lastAnalysisUptime: TimeInterval?
    @ObservationIgnored private var isCollectingSamples = false
    @ObservationIgnored private var rawSamples: [GazeCoordinate] = []
    @ObservationIgnored private var stableWindowStartedAt: TimeInterval?
    @ObservationIgnored private var lastValidSampleAt: TimeInterval?
    @ObservationIgnored private var captureFrameCount = 0
    @ObservationIgnored private var captureRejections: [String: Int] = [:]
    @ObservationIgnored private var isPreviewEnabled = false

    private let minimumSamplesPerTarget = PaddyCalibrationCapture.minimumSamples
    private let maximumCaptureWindow: TimeInterval = 2.0
    private let droppedPredictionGrace: TimeInterval = 0.25

    init() {
        sample = GazeSample(
            pointNormalized: nil,
            timestamp: MonotonicTimestamp(uptimeNanoseconds: 0),
            quality: .unavailable,
            trackingState: .paused,
            setupState: .unknown,
            calibrationState: .notCalibrated,
            eyeAvailability: .none
        )
        runtime.onAnalysis = { [weak self] analysis in
            Task { @MainActor in self?.consume(analysis) }
        }
        runtime.onFailure = { [weak self] error in
            Task { @MainActor in self?.handleRuntimeFailure(error) }
        }
    }

    var isReadyToCalibrate: Bool {
        cameraStarted &&
            sample.setupState == .ready &&
            isPatchVerified &&
            !isSceneTooDark &&
            isFrameCaptureReady &&
            cameraStatus.contains("active")
    }

    var calibrationNeedsGuidance: Bool {
        activeCalibrationTarget != nil && !isReadyForPreparationCountdown
    }

    var isCountdownPositionReady: Bool {
        (isPreparingCalibration || isResumingCalibration) && isReadyForPreparationCountdown
    }

    var isCalibrated: Bool {
        calibration != nil && sample.calibrationState == .calibrated
    }

    var isPatchVerified: Bool {
        !oneEyeEnforcerEnabled || patchWearState == .verified
    }

    var hasUsableGaze: Bool {
        isCalibrated &&
            sample.trackingState == .tracking &&
            isPatchVerified &&
            sample.quality.level == .usable &&
            sample.pointNormalized != nil
    }

    func setOneEyeEnforcerEnabled(_ enabled: Bool) {
        guard oneEyeEnforcerEnabled != enabled else { return }
        oneEyeEnforcerEnabled = enabled
        patchWearMonitor.reset()
        patchWearState = enabled ? .checking : .verified
    }

    func startCamera() {
        setPreviewEnabled(true)
        guard !cameraStarted else { return }
        Task {
            do {
                try await runtime.start(reset: true)
                cameraStarted = true
                status = oneEyeEnforcerEnabled
                    ? "Centre your face 45–60 cm away and keep the uncovered eye visible"
                    : "Centre your face 45–60 cm away and keep both eyes visible"
            } catch {
                status = "Camera start failed: \(error)"
                cameraStatus = "paddy-gazeTrack camera unavailable"
            }
        }
    }

    static func countdownValues(preparationSeconds: Int) -> [Int] {
        Array(stride(from: max(preparationSeconds, 1) - 1, through: 0, by: -1))
    }

    func startCalibration(preparationSeconds: Int = 4) {
        guard isReadyToCalibrate, calibrationTask == nil else { return }
        let preparationSeconds = max(preparationSeconds, 1)
        let countdownValues = Self.countdownValues(preparationSeconds: preparationSeconds)
        calibration = nil
        calibrationState = .readyForTarget
        unclampedCalibratedPoint = nil
        isPreparingCalibration = true
        calibrationCountdown = countdownValues[0]
        activeCalibrationTarget = nil
        status = "Hold still — calibration begins in \(preparationSeconds) seconds"
        publishWithoutPrediction(trackingState: .limited)

        calibrationTask = Task { [weak self] in
            guard let self else { return }
            preparation: while !Task.isCancelled {
                while !isReadyForPreparationCountdown {
                    calibrationCountdown = countdownValues[0]
                    status = "Countdown reset — return your face to the oval"
                    do { try await Task.sleep(for: .milliseconds(100)) }
                    catch { return }
                }
                for remaining in countdownValues {
                    calibrationCountdown = remaining
                    status = "Stay still — calibration begins after the countdown"
                    let secondEndsAt = ProcessInfo.processInfo.systemUptime + 1
                    while ProcessInfo.processInfo.systemUptime < secondEndsAt {
                        guard !Task.isCancelled else { return }
                        guard isReadyForPreparationCountdown else {
                            calibrationCountdown = countdownValues[0]
                            status = "Countdown reset — return your face to the oval"
                            continue preparation
                        }
                        do { try await Task.sleep(for: .milliseconds(100)) }
                        catch { return }
                    }
                }
                break
            }
            guard !Task.isCancelled, isReadyForPreparationCountdown else { return }
            isPreparingCalibration = false
            calibrationCountdown = 0
            await runCalibration()
        }
    }

    func stop() {
        calibrationTask?.cancel()
        calibrationTask = nil
        setPreviewEnabled(false)
        runtime.stop()
        cameraStarted = false
        isPreparingCalibration = false
        isResumingCalibration = false
        calibrationCountdown = 0
        activeCalibrationTarget = nil
        calibration = nil
        calibrationState = .notCalibrated
        unclampedCalibratedPoint = nil
        clearCaptureStability()
        patchWearMonitor.reset()
        patchWearState = oneEyeEnforcerEnabled ? .checking : .verified
        stableSetupState = .unknown
        pendingSetupState = nil
        pendingSetupFrameCount = 0
        lastImageOrientation = nil
        lastAnalysisUptime = nil
        isSceneTooDark = false
        isFrameCaptureReady = false
        status = "Stopped; volatile gaze and calibration data discarded"
        cameraStatus = "paddy-gazeTrack stopped"
        publishWithoutPrediction(trackingState: .paused)
    }

    func pauseForInactiveScene() {
        guard cameraStarted, sample.trackingState != .paused else { return }
        runtime.pause()
        wasPausedByScene = true
        publishWithoutPrediction(trackingState: .paused)
    }

    func resumeForActiveScene() {
        guard wasPausedByScene else { return }
        wasPausedByScene = false
        Task {
            do { try await runtime.start(reset: false) }
            catch { status = "Resume failed: \(error)" }
        }
    }

    private func runCalibration() async {
        var samples: [GazeCalibrationSample] = []
        for (index, target) in PaddyCalibrationCapture.targets.enumerated() {
            guard !Task.isCancelled else { return }
            let label = "Calibrating \(index + 1)/\(PaddyCalibrationCapture.targets.count)"
            guard let raw = await captureRawPoint(
                at: target,
                label: label,
                movesFromPreviousTarget: index > 0
            ) else { return }
            samples.append(GazeCalibrationSample(raw: raw, target: target))
        }
        guard !Task.isCancelled else { return }
        finishCalibration(samples)
    }

    private func captureRawPoint(
        at target: NormalizedGazePoint,
        label: String,
        movesFromPreviousTarget: Bool
    ) async -> GazeCoordinate? {
        var attempt = 1
        while !Task.isCancelled {
            let isMoving = movesFromPreviousTarget && attempt == 1
            let isFirstTarget = activeCalibrationTarget == nil
            activeCalibrationTarget = target
            if isFirstTarget {
                setPreviewEnabled(false)
            }
            calibrationState = .collecting
            isCollectingSamples = false
            rawSamples = []
            stableWindowStartedAt = nil
            lastValidSampleAt = nil
            captureFrameCount = 0
            captureRejections = [:]
            status = isMoving ? "\(label) — follow the dot" : "\(label) — hold steady"
            publishWithoutPrediction(trackingState: .limited)

            var completedStableWindow = false
            do {
                if isMoving {
                    try await Task.sleep(for: .seconds(PaddyCalibrationCapture.targetTransitionSeconds))
                    status = "\(label) — hold steady"
                }
                try await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return nil }
                guard await restoreCalibrationPositionIfNeeded(label: label) else { return nil }
                isCollectingSamples = true
                var started = ProcessInfo.processInfo.systemUptime
                var maximumEnd = started + maximumCaptureWindow
                repeat {
                    try await Task.sleep(for: .milliseconds(100))
                    guard !Task.isCancelled else { return nil }
                    if !isReadyForPreparationCountdown {
                        isCollectingSamples = false
                        clearCaptureStability()
                        guard await restoreCalibrationPositionIfNeeded(label: label) else { return nil }
                        isCollectingSamples = true
                        started = ProcessInfo.processInfo.systemUptime
                        maximumEnd = started + maximumCaptureWindow
                        continue
                    }
                    let now = ProcessInfo.processInfo.systemUptime
                    let stableDuration = stableWindowStartedAt.map { now - $0 } ?? 0
                    status = "\(label) · attempt \(attempt) · \(rawSamples.count)/\(minimumSamplesPerTarget) stable samples"
                    if PaddyCalibrationCapture.hasCompleteWindow(
                        elapsed: now - started,
                        stableDuration: stableDuration,
                        sampleCount: rawSamples.count
                    ) {
                        completedStableWindow = true
                        break
                    }
                    if now >= maximumEnd { break }
                } while true
            } catch {
                return nil
            }

            isCollectingSamples = false
            if completedStableWindow,
               let accepted = PaddyCalibrationCapture.reduce(rawSamples) {
                calibrationState = .targetAccepted
                return accepted
            }
            calibrationState = .retryTarget
            let reason = dominantCaptureRejection() ?? "predictions were not stable"
            status = "\(label) failed because \(reason). Retrying…"
            publishWithoutPrediction(trackingState: .limited)
            do { try await Task.sleep(for: .milliseconds(900)) }
            catch { return nil }
            attempt += 1
        }
        return nil
    }

    func finishCalibration(_ samples: [GazeCalibrationSample]) {
        defer {
            activeCalibrationTarget = nil
            isResumingCalibration = false
            calibrationCountdown = 0
            isCollectingSamples = false
            rawSamples = []
            stableWindowStartedAt = nil
            lastValidSampleAt = nil
            calibrationTask = nil
        }
        guard samples.count == PaddyCalibrationCapture.targets.count else {
            calibrationState = .failed
            status = "Calibration was incomplete. No partial calibration was saved."
            setPreviewEnabled(true)
            publishWithoutPrediction(trackingState: .limited)
            return
        }
        do {
            calibration = try PaddyCalibrationCapture.fitComplete(samples)
            calibrationState = .calibrated
            status = "Calibration complete — paddy-gazeTrack is ready to play"
            publishWithoutPrediction(trackingState: .limited)
            completedCalibrationCount += 1
        } catch {
            calibration = nil
            calibrationState = .failed
            status = "Calibration could not fit a stable mapping. Try again."
            setPreviewEnabled(true)
            publishWithoutPrediction(trackingState: .limited)
        }
    }

    func consume(_ analysis: PaddyFrameAnalysis) {
        guard analysis.hostUptime.isFinite, analysis.hostUptime >= 0 else { return }
        if let lastAnalysisUptime, analysis.hostUptime <= lastAnalysisUptime { return }
        lastAnalysisUptime = analysis.hostUptime
        if let lastImageOrientation, lastImageOrientation != analysis.imageOrientation {
            invalidateCalibrationForOrientationChange()
        }
        lastImageOrientation = analysis.imageOrientation
        cameraStatus = analysis.modelStatus
        isSceneTooDark = analysis.isSceneTooDark
        isFrameCaptureReady = analysis.captureRejectionReason == nil
        updateStableSetupState(with: analysis.setupCandidate)
        updatePatchState(with: analysis)
        let needsSetupPreview = !isCalibrated &&
            (activeCalibrationTarget == nil || calibrationNeedsGuidance)
        setPreviewEnabled(needsSetupPreview)
        if cameraStarted, isPreviewEnabled, let previewImage = analysis.previewImage {
            runtime.previewView.display(previewImage)
        }
        if isCollectingSamples { recordCalibrationFrame(analysis) }

        let timestampNanoseconds = UInt64(max(analysis.hostUptime, 0) * 1_000_000_000)
        guard let prediction = analysis.prediction,
              prediction.xScreenCentered.isFinite,
              prediction.yScreenCentered.isFinite,
              let calibration,
              isPatchVerified,
              !analysis.isSceneTooDark,
              calibrationState == .calibrated else {
            unclampedCalibratedPoint = nil
            sample = GazeSample(
                pointNormalized: nil,
                timestamp: MonotonicTimestamp(uptimeNanoseconds: timestampNanoseconds),
                quality: .unavailable,
                trackingState: analysis.prediction == nil ? .lost : .limited,
                setupState: stableSetupState,
                calibrationState: calibrationState,
                eyeAvailability: analysis.eyeAvailability
            )
            updateIdleStatus()
            return
        }

        let raw = GazeCoordinate(
            x: prediction.xScreenCentered,
            y: prediction.yScreenCentered
        )
        let calibrated = calibration.predict(raw)
        unclampedCalibratedPoint = CGPoint(x: calibrated.x, y: calibrated.y)
        let renderingPoint = NormalizedGazePoint(
            x: min(max(calibrated.x, 0), 1),
            y: min(max(calibrated.y, 0), 1)
        )
        sample = GazeSample(
            pointNormalized: renderingPoint,
            timestamp: MonotonicTimestamp(uptimeNanoseconds: timestampNanoseconds),
            quality: GazeQuality(confidence: 1, level: .usable),
            trackingState: .tracking,
            setupState: stableSetupState,
            calibrationState: calibrationState,
            eyeAvailability: analysis.eyeAvailability
        )
    }

    private func updateStableSetupState(with candidate: SetupState) {
        guard candidate != stableSetupState else {
            pendingSetupState = nil
            pendingSetupFrameCount = 0
            return
        }
        if pendingSetupState == candidate {
            pendingSetupFrameCount += 1
        } else {
            pendingSetupState = candidate
            pendingSetupFrameCount = 1
        }
        guard pendingSetupFrameCount >= 3 else { return }
        stableSetupState = candidate
        pendingSetupState = nil
        pendingSetupFrameCount = 0
    }

    private func invalidateCalibrationForOrientationChange() {
        calibrationTask?.cancel()
        calibrationTask = nil
        calibration = nil
        calibrationState = .invalid
        activeCalibrationTarget = nil
        isPreparingCalibration = false
        isResumingCalibration = false
        calibrationCountdown = 0
        isCollectingSamples = false
        clearCaptureStability()
        unclampedCalibratedPoint = nil
        stableSetupState = .unknown
        pendingSetupState = nil
        pendingSetupFrameCount = 0
        setPreviewEnabled(true)
        status = "The iPad orientation changed — recalibrate before playing"
    }

    private func setPreviewEnabled(_ enabled: Bool) {
        guard isPreviewEnabled != enabled else { return }
        isPreviewEnabled = enabled
        runtime.setPreviewEnabled(enabled)
        if !enabled { runtime.previewView.clear() }
    }

    private var isReadyForPreparationCountdown: Bool {
        cameraStarted &&
            sample.setupState == .ready &&
            isPatchVerified &&
            !isSceneTooDark &&
            cameraStatus.contains("active")
    }

    private func restoreCalibrationPositionIfNeeded(
        label: String,
        preparationSeconds: Int = 4
    ) async -> Bool {
        guard !isReadyForPreparationCountdown else { return true }

        let countdownValues = Self.countdownValues(preparationSeconds: preparationSeconds)
        isCollectingSamples = false
        clearCaptureStability()
        isResumingCalibration = true
        calibrationCountdown = countdownValues[0]
        setPreviewEnabled(true)
        var didRestorePosition = false

        defer {
            isResumingCalibration = false
            calibrationCountdown = 0
            if didRestorePosition { setPreviewEnabled(false) }
        }

        recovery: while !Task.isCancelled {
            while !isReadyForPreparationCountdown {
                setPreviewEnabled(true)
                calibrationCountdown = countdownValues[0]
                status = "\(label) paused — return your face to the oval"
                do { try await Task.sleep(for: .milliseconds(100)) }
                catch { return false }
            }

            setPreviewEnabled(false)
            for remaining in countdownValues {
                calibrationCountdown = remaining
                status = "\(label) — stay still while the countdown finishes"
                let secondEndsAt = ProcessInfo.processInfo.systemUptime + 1
                while ProcessInfo.processInfo.systemUptime < secondEndsAt {
                    guard !Task.isCancelled else { return false }
                    guard isReadyForPreparationCountdown else {
                        setPreviewEnabled(true)
                        calibrationCountdown = countdownValues[0]
                        status = "\(label) paused — return your face to the oval"
                        continue recovery
                    }
                    do { try await Task.sleep(for: .milliseconds(100)) }
                    catch { return false }
                }
            }
            break
        }

        guard !Task.isCancelled, isReadyForPreparationCountdown else { return false }
        didRestorePosition = true
        status = "\(label) — continue looking at the dot"
        return true
    }

    private func updatePatchState(with analysis: PaddyFrameAnalysis) {
        guard oneEyeEnforcerEnabled else {
            patchWearState = .verified
            return
        }
        let observation: PatchEyeObservation
        if stableSetupState != .ready {
            observation = .unavailable
        } else {
            observation = switch analysis.eyeAvailability {
            case .both: .bothEyes
            case .leftOnly, .rightOnly: .singleEye
            case .none: .unavailable
            }
        }
        patchWearState = patchWearMonitor.consume(
            observation,
            timestampNanoseconds: UInt64(max(analysis.hostUptime, 0) * 1_000_000_000)
        )
    }

    private func recordCalibrationFrame(_ analysis: PaddyFrameAnalysis) {
        captureFrameCount += 1
        if let reason = analysis.captureRejectionReason,
           analysis.prediction != nil || reason != "the model lost one or both eye regions" {
            recordCaptureRejection(reason)
            clearCaptureStability()
            return
        }
        guard let prediction = analysis.prediction else {
            recordCaptureRejection(analysis.captureRejectionReason ?? "the model lost the eye regions")
            handleDroppedPrediction(at: analysis.hostUptime)
            return
        }
        guard analysis.setupCandidate == .ready else {
            recordCaptureRejection(analysis.captureRejectionReason ?? "face alignment was lost")
            clearCaptureStability()
            return
        }
        guard !analysis.isSceneTooDark else {
            recordCaptureRejection("lighting was too dim")
            clearCaptureStability()
            return
        }
        guard isPatchVerified else {
            recordCaptureRejection("the eye patch check was not ready")
            clearCaptureStability()
            return
        }
        guard prediction.xScreenCentered.isFinite, prediction.yScreenCentered.isFinite else {
            recordCaptureRejection("the model produced an invalid prediction")
            clearCaptureStability()
            return
        }

        if stableWindowStartedAt == nil { stableWindowStartedAt = analysis.hostUptime }
        lastValidSampleAt = analysis.hostUptime
        rawSamples.append(
            GazeCoordinate(
                x: prediction.xScreenCentered,
                y: prediction.yScreenCentered
            )
        )
        if rawSamples.count >= 4, capturedSampleSpreadP90(rawSamples) > 1.5 {
            recordCaptureRejection("the gaze predictions did not form a stable fixation")
            clearCaptureStability()
        }
    }

    private func capturedSampleSpreadP90(_ samples: [GazeCoordinate]) -> Double {
        let center = GazeCoordinate(
            x: median(samples.map(\.x).sorted()),
            y: median(samples.map(\.y).sorted())
        )
        return percentile(
            samples.map { hypot($0.x - center.x, $0.y - center.y) }.sorted(),
            fraction: 0.9
        )
    }

    private func handleDroppedPrediction(at timestamp: TimeInterval) {
        guard let lastValidSampleAt,
              timestamp - lastValidSampleAt <= droppedPredictionGrace else {
            clearCaptureStability()
            return
        }
    }

    private func clearCaptureStability() {
        rawSamples.removeAll(keepingCapacity: true)
        stableWindowStartedAt = nil
        lastValidSampleAt = nil
    }

    private func recordCaptureRejection(_ reason: String) {
        captureRejections[reason, default: 0] += 1
    }

    private func dominantCaptureRejection() -> String? {
        captureRejections.max { $0.value < $1.value }?.key
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return .nan }
        let middle = values.count / 2
        return values.count.isMultiple(of: 2)
            ? (values[middle - 1] + values[middle]) / 2
            : values[middle]
    }

    private func percentile(_ sorted: [Double], fraction: Double) -> Double {
        guard sorted.count > 1 else { return sorted.first ?? .infinity }
        let position = fraction * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        let weight = position - Double(lower)
        return sorted[lower] * (1 - weight) + sorted[upper] * weight
    }

    private func updateIdleStatus() {
        guard cameraStarted, activeCalibrationTarget == nil, !isPreparingCalibration, !isCalibrated,
              calibrationState != .failed, calibrationState != .invalid else {
            return
        }
        status = switch stableSetupState {
        case .tooClose: "Move farther from the front camera"
        case .tooFar: "Move closer to the front camera"
        case .misaligned: "Centre your face and point your nose at the iPad"
        case .lookUp: "Look up a little"
        case .lookDown: "Look down a little"
        case .turnLeft: "Turn left a little"
        case .turnRight: "Turn right a little"
        case .movingTooMuch: "Too much movement — hold still"
        case .stabilizing: "Hold still while paddy-gazeTrack finds both eye regions"
        case .ready where !isPatchVerified: "Keep still while the eye patch is checked"
        case .ready: "Ready to calibrate with paddy-gazeTrack"
        case .unknown: "Centre your face 45–60 cm from the landscape camera"
        }
    }

    private func publishWithoutPrediction(trackingState: TrackingState) {
        sample = GazeSample(
            pointNormalized: nil,
            timestamp: MonotonicTimestamp(
                uptimeNanoseconds: UInt64(ProcessInfo.processInfo.systemUptime * 1_000_000_000)
            ),
            quality: .unavailable,
            trackingState: trackingState,
            setupState: stableSetupState,
            calibrationState: calibrationState,
            eyeAvailability: sample.eyeAvailability
        )
    }

    private func handleRuntimeFailure(_ error: Error) {
        unclampedCalibratedPoint = nil
        status = "Camera tracking failed: \(error)"
        cameraStatus = "paddy-gazeTrack camera failed"
        publishWithoutPrediction(trackingState: .lost)
    }
}
