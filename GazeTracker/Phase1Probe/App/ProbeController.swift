import ARKit
import Foundation
import QuartzCore
import SwiftUI
import UIKit

final class ProbeController: NSObject, ObservableObject, ARSessionDelegate {
    static let algorithmVersion = "phase1-arkit-selected-eye-9point-v8"

    @Published var selectedCondition: ProbeCondition = .around40cm {
        didSet {
            guard selectedCondition != oldValue else { return }
            let previousForcedSource = oldValue.forcedGazeSource
            if let forcedSource = selectedCondition.forcedGazeSource {
                if selectedGazeSource != forcedSource {
                    selectedGazeSource = forcedSource
                } else if previousForcedSource != forcedSource {
                    invalidateCalibration()
                }
            } else if previousForcedSource != nil {
                invalidateCalibration()
            }
        }
    }
    @Published var selectedGazeSource: ProbeGazeSource = .anatomicalRightEye {
        didSet {
            guard selectedGazeSource != oldValue else { return }
            invalidateCalibration()
        }
    }
    @Published private(set) var arFaceTrackingSupported = ARFaceTrackingConfiguration.isSupported
    @Published private(set) var trackingState: ProbeTrackingState = .paused
    @Published private(set) var setupState: ProbeSetupState = .unknown
    @Published private(set) var calibrationState: ProbeCalibrationState = .notCalibrated
    @Published private(set) var eyeAvailability: ProbeEyeAvailability = .none
    @Published private(set) var activeTarget: CGPoint?
    @Published private(set) var activity = "Idle"
    @Published private(set) var aggregateStatus = "No selected-eye ARKit aggregate results recorded"

    var isBusy: Bool { runMode != .idle }
    var canCalibrate: Bool { !isBusy && trackingState != .unsupported && trackingState != .permissionDenied }
    var canValidate: Bool { !isBusy && model != nil && calibrationState == .calibrated }
    var canRunSetupCheck: Bool { !isBusy && trackingState != .unsupported && trackingState != .permissionDenied }

    private enum RunMode { case idle, calibration, validation, setupCheck }

    private let session = ARSession()
    private var runMode: RunMode = .idle
    private var model: RegressionModel?
    private var lastFaceWasTracked = false
    private var lastKnownReady = false
    private var blinkWasActive = false
    private var pendingBlinkRecoveryAt: TimeInterval?
    private var pendingFaceRecoveryAt: TimeInterval?

    private let calibrationTargets = [
        CGPoint(x: 0.05, y: 0.05), CGPoint(x: 0.50, y: 0.05), CGPoint(x: 0.95, y: 0.05),
        CGPoint(x: 0.05, y: 0.50), CGPoint(x: 0.50, y: 0.50), CGPoint(x: 0.95, y: 0.50),
        CGPoint(x: 0.05, y: 0.95), CGPoint(x: 0.50, y: 0.95), CGPoint(x: 0.95, y: 0.95)
    ]
    private let heldOutTargets = [
        CGPoint(x: 0.10, y: 0.10), CGPoint(x: 0.90, y: 0.10),
        CGPoint(x: 0.10, y: 0.90), CGPoint(x: 0.90, y: 0.90),
        CGPoint(x: 0.50, y: 0.08), CGPoint(x: 0.92, y: 0.50),
        CGPoint(x: 0.50, y: 0.92), CGPoint(x: 0.08, y: 0.50),
        CGPoint(x: 0.45, y: 0.45), CGPoint(x: 0.55, y: 0.55)
    ]

    private var runTargets: [CGPoint] = []
    private var targetIndex = 0
    private var phaseStart: TimeInterval?
    private var calibrationStartedAt = 0.0
    private var calibrationFeatures: [[Double]] = []
    private var calibrationTargetValues: [CGPoint] = []
    private var targetCalibrationSampleStart = 0

    private var fixationPoints: [CGPoint] = []
    private var fixationDistances: [Double] = []
    private var fixationLeftDirections: [SIMD3<Double>] = []
    private var fixationRightDirections: [SIMD3<Double>] = []
    private var fixationLookAtPoints: [SIMD2<Double>] = []
    private var fixationAggregates: [FixationAggregate] = []
    private var runEligibleFrames = 0
    private var runValidFrames = 0
    private var runSampleTimes: [TimeInterval] = []
    private var runLatencies: [Double] = []
    private var runBlinkRecoveries: [Double] = []
    private var runFaceRecoveries: [Double] = []
    private var runEyeAvailabilityCounts: [ProbeEyeAvailability: Int] = [:]

    private var setupStartedAt: TimeInterval?
    private var setupCounts: [ProbeSetupState: Int] = [:]

    private var calibrationAttempts: [CalibrationAttemptResult] = []
    private var conditionResults: [ConditionResult] = []
    private var setupChecks: [SetupCheckResult] = []
    private var nominalAccuracyMedian: Double?

    override init() {
        super.init()
        session.delegate = self
        session.delegateQueue = .main
        if !arFaceTrackingSupported {
            trackingState = .unsupported
            activity = "AR face tracking unsupported"
        }
    }

    func startTracking() {
        guard arFaceTrackingSupported else {
            trackingState = .unsupported
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            trackingState = .permissionDenied
            activity = "Camera permission denied"
            return
        default: break
        }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        trackingState = .limited
        activity = "Selected-eye ARKit session running"
    }

    func pauseTracking() {
        session.pause()
        trackingState = .paused
        activity = "ARKit session paused"
    }

    func resumeTracking() { startTracking() }

    func startCalibration() {
        guard canCalibrate else { return }
        model = nil
        calibrationState = .collecting
        runMode = .calibration
        runTargets = calibrationTargets
        targetIndex = 0
        phaseStart = nil
        calibrationStartedAt = CACurrentMediaTime()
        calibrationFeatures.removeAll(keepingCapacity: true)
        calibrationTargetValues.removeAll(keepingCapacity: true)
        targetCalibrationSampleStart = 0
        activeTarget = runTargets[0]
        activity = "ARKit calibration 1 / \(runTargets.count)"
    }

    func startValidation() {
        guard canValidate else { return }
        runMode = .validation
        runTargets = (heldOutTargets + heldOutTargets).shuffled()
        targetIndex = 0
        phaseStart = nil
        resetFixationBuffers()
        fixationAggregates.removeAll(keepingCapacity: true)
        runEligibleFrames = 0
        runValidFrames = 0
        runSampleTimes.removeAll(keepingCapacity: true)
        runLatencies.removeAll(keepingCapacity: true)
        runBlinkRecoveries.removeAll(keepingCapacity: true)
        runFaceRecoveries.removeAll(keepingCapacity: true)
        runEyeAvailabilityCounts.removeAll(keepingCapacity: true)
        activeTarget = runTargets[0]
        activity = "ARKit held-out validation 1 / \(runTargets.count)"
    }

    func startSetupCheck() {
        guard canRunSetupCheck else { return }
        runMode = .setupCheck
        setupStartedAt = nil
        setupCounts = [:]
        activeTarget = nil
        activity = "10-second ARKit setup-state check"
    }

    func invalidateCalibration() {
        model = nil
        calibrationState = .invalid
        activity = "ARKit calibration invalidated"
    }

    func cancelRun() {
        runMode = .idle
        activeTarget = nil
        phaseStart = nil
        setupStartedAt = nil
        calibrationFeatures.removeAll()
        calibrationTargetValues.removeAll()
        resetFixationBuffers()
        activity = "Run cancelled; volatile samples discarded"
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked else {
            handleMissingFace(at: frame.timestamp)
            return
        }
        guard let observation = makeObservation(face: face, frameTimestamp: frame.timestamp) else {
            handleMissingFace(at: frame.timestamp)
            return
        }
        process(observation)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        trackingState = .lost
        activity = "ARKit session failed"
    }

    func sessionWasInterrupted(_ session: ARSession) {
        trackingState = .paused
        activity = "ARKit session interrupted"
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        activity = "ARKit interruption ended; calibration retained for reuse test"
        resumeTracking()
    }

    private func makeObservation(face: ARFaceAnchor, frameTimestamp: TimeInterval) -> InternalObservation? {
        let faceTransform = face.transform
        let left = face.leftEyeTransform
        let right = face.rightEyeTransform
        let look = face.lookAtPoint
        let faceTranslation = SIMD3<Double>(
            Double(faceTransform.columns.3.x),
            Double(faceTransform.columns.3.y),
            Double(faceTransform.columns.3.z)
        )
        let leftDirection = SIMD3<Double>(
            -Double(left.columns.2.x), -Double(left.columns.2.y), -Double(left.columns.2.z)
        )
        let rightDirection = SIMD3<Double>(
            -Double(right.columns.2.x), -Double(right.columns.2.y), -Double(right.columns.2.z)
        )
        let lookPoint = SIMD2<Double>(Double(look.x), Double(look.y))
        let featurePoint: SIMD2<Double>
        switch selectedGazeSource {
        case .fusedLookAtPoint:
            featurePoint = lookPoint
        case .anatomicalLeftEye:
            featurePoint = SIMD2<Double>(leftDirection.x, leftDirection.y)
        case .anatomicalRightEye:
            featurePoint = SIMD2<Double>(rightDirection.x, rightDirection.y)
        }
        // Preserve the best measured bounded quadratic, changing only its input
        // to the declared uncovered eye during a patch condition.
        let features = [
            featurePoint.x,
            featurePoint.y,
            featurePoint.x * featurePoint.x,
            featurePoint.y * featurePoint.y,
            featurePoint.x * featurePoint.y
        ]
        guard features.allSatisfy(\.isFinite),
              simd_length(leftDirection) > 0,
              simd_length(rightDirection) > 0 else { return nil }
        return InternalObservation(
            timestamp: frameTimestamp,
            publicationLatencyMilliseconds: max(0, (CACurrentMediaTime() - frameTimestamp) * 1_000),
            features: features,
            leftEyeDirection: leftDirection,
            rightEyeDirection: rightDirection,
            lookAtPoint: lookPoint,
            distanceMeters: simd_length(faceTranslation),
            blinkLeft: Double(face.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0),
            blinkRight: Double(face.blendShapes[.eyeBlinkRight]?.floatValue ?? 0)
        )
    }

    private func process(_ observation: InternalObservation) {
        if !lastFaceWasTracked { pendingFaceRecoveryAt = observation.timestamp }
        lastFaceWasTracked = true
        setupState = setupState(for: observation.distanceMeters)
        lastKnownReady = setupState == .ready

        let blinkActive = activeEyeBlinking(
            leftBlink: observation.blinkLeft,
            rightBlink: observation.blinkRight
        )
        if blinkWasActive && !blinkActive { pendingBlinkRecoveryAt = observation.timestamp }
        blinkWasActive = blinkActive
        eyeAvailability = eyeAvailability(leftBlink: observation.blinkLeft, rightBlink: observation.blinkRight)
        trackingState = eyeAvailability == .none ? .limited : .tracking

        let sample = makePublicSample(observation)
        if sample.pointNormalized != nil, sample.trackingState == .tracking {
            if let start = pendingBlinkRecoveryAt {
                runBlinkRecoveries.append(max(0, (observation.timestamp - start) * 1_000))
                pendingBlinkRecoveryAt = nil
            }
            if let start = pendingFaceRecoveryAt {
                runFaceRecoveries.append(max(0, (observation.timestamp - start) * 1_000))
                pendingFaceRecoveryAt = nil
            }
        }

        switch runMode {
        case .calibration: processCalibration(observation)
        case .validation: processValidation(observation, sample: sample)
        case .setupCheck: processSetupCheck(state: setupState, timestamp: observation.timestamp)
        case .idle: break
        }
    }

    private func handleMissingFace(at timestamp: TimeInterval) {
        lastFaceWasTracked = false
        trackingState = .lost
        eyeAvailability = .none
        setupState = .unknown
        if runMode == .validation, lastKnownReady {
            runEligibleFrames += 1
            runEyeAvailabilityCounts[.none, default: 0] += 1
        }
        if runMode == .setupCheck { processSetupCheck(state: .unknown, timestamp: timestamp) }
    }

    private func makePublicSample(_ observation: InternalObservation) -> ProbeSample {
        let point = model?.predict(observation.features)
        let isUsable = point != nil && setupState == .ready && eyeAvailability != .none
        let distancePenalty = min(abs(observation.distanceMeters - 0.50) / 0.10, 1.0) * 0.25
        let eyePenalty = eyeAvailability == .both ? 0.0 : 0.20
        return ProbeSample(
            pointNormalized: isUsable ? point : nil,
            timestamp: observation.timestamp,
            confidence: max(0, 1 - distancePenalty - eyePenalty),
            trackingState: isUsable ? .tracking : trackingState,
            setupState: setupState,
            calibrationState: calibrationState,
            eyeAvailability: eyeAvailability
        )
    }

    private func processCalibration(_ observation: InternalObservation) {
        guard targetIndex < runTargets.count else { return }
        if phaseStart == nil { phaseStart = observation.timestamp }
        guard let start = phaseStart else { return }
        let elapsed = observation.timestamp - start
        if elapsed >= 0.55, elapsed < 1.75, setupState == .ready, eyeAvailability != .none {
            calibrationFeatures.append(observation.features)
            calibrationTargetValues.append(runTargets[targetIndex])
        }
        guard elapsed >= 1.75 else { return }
        let acceptedCount = calibrationFeatures.count - targetCalibrationSampleStart
        guard acceptedCount >= 30 else {
            finishCalibration(success: false)
            return
        }
        targetIndex += 1
        targetCalibrationSampleStart = calibrationFeatures.count
        phaseStart = nil
        if targetIndex < runTargets.count {
            calibrationState = .targetAccepted
            activeTarget = runTargets[targetIndex]
            calibrationState = .collecting
            activity = "ARKit calibration \(targetIndex + 1) / \(runTargets.count)"
        } else {
            model = RegressionModel.fit(features: calibrationFeatures, targets: calibrationTargetValues)
            finishCalibration(success: model != nil)
        }
    }

    private func finishCalibration(success: Bool) {
        let duration = CACurrentMediaTime() - calibrationStartedAt
        let attempt = calibrationAttempts.filter { $0.condition == selectedCondition }.count + 1
        calibrationAttempts.append(CalibrationAttemptResult(
            condition: selectedCondition,
            gazeSource: selectedGazeSource,
            attemptNumber: attempt,
            success: success,
            durationSeconds: duration
        ))
        calibrationFeatures.removeAll()
        calibrationTargetValues.removeAll()
        activeTarget = nil
        runMode = .idle
        calibrationState = success ? .calibrated : .failed
        activity = success ? "Selected-eye ARKit calibration completed" : "ARKit calibration failed"
        persistAggregateResults()
    }

    private func processValidation(_ observation: InternalObservation, sample: ProbeSample) {
        if setupState == .ready {
            runEligibleFrames += 1
            runEyeAvailabilityCounts[eyeAvailability, default: 0] += 1
        }
        guard targetIndex < runTargets.count else { return }
        if phaseStart == nil { phaseStart = observation.timestamp }
        guard let start = phaseStart else { return }
        let elapsed = observation.timestamp - start
        if let point = sample.pointNormalized, sample.trackingState == .tracking, setupState == .ready {
            runValidFrames += 1
            runSampleTimes.append(observation.timestamp)
            runLatencies.append(observation.publicationLatencyMilliseconds)
            if elapsed >= 0.60, elapsed < 1.80 {
                fixationPoints.append(point)
                fixationDistances.append(observation.distanceMeters)
                fixationLeftDirections.append(observation.leftEyeDirection)
                fixationRightDirections.append(observation.rightEyeDirection)
                fixationLookAtPoints.append(observation.lookAtPoint)
            }
        }
        guard elapsed >= 1.80 else { return }
        if let aggregate = ProbeMath.fixationAggregate(
            target: runTargets[targetIndex],
            points: fixationPoints,
            distances: fixationDistances,
            leftDirections: fixationLeftDirections,
            rightDirections: fixationRightDirections,
            lookAtPoints: fixationLookAtPoints,
            viewport: UIScreen.main.bounds.size
        ) {
            fixationAggregates.append(aggregate)
        }
        resetFixationBuffers()
        targetIndex += 1
        phaseStart = nil
        if targetIndex < runTargets.count {
            activeTarget = runTargets[targetIndex]
            activity = "ARKit held-out validation \(targetIndex + 1) / \(runTargets.count)"
        } else {
            finishValidation()
        }
    }

    private func finishValidation() {
        let result = makeConditionResult()
        conditionResults.append(result)
        if selectedCondition == .nominal45cm { nominalAccuracyMedian = result.accuracyDegrees.median }
        activeTarget = nil
        runMode = .idle
        activity = "Selected-eye ARKit held-out validation completed"
        aggregateStatus = "Recorded \(conditionResults.count) ARKit validation run(s), \(setupChecks.count) setup check(s)"
        resetFixationBuffers()
        persistAggregateResults()
    }

    private func makeConditionResult() -> ConditionResult {
        let accuracyDegrees = MetricSummary(fixationAggregates.map(\.accuracyDegrees))
        let precisionDegrees = MetricSummary(fixationAggregates.map(\.precisionDegreesRMS))
        let accuracyPoints = MetricSummary(fixationAggregates.map(\.accuracyLogicalPoints))
        let precisionPoints = MetricSummary(fixationAggregates.map(\.precisionLogicalPointsRMS))
        var regions: [String: RegionalResult] = [:]
        for region in ["center", "edge", "corner"] {
            let values = fixationAggregates.filter { $0.region == region }
            regions[region] = RegionalResult(
                fixationCount: values.count,
                accuracyDegrees: MetricSummary(values.map(\.accuracyDegrees)),
                precisionDegreesRMS: MetricSummary(values.map(\.precisionDegreesRMS)),
                accuracyLogicalPoints: MetricSummary(values.map(\.accuracyLogicalPoints)),
                precisionLogicalPointsRMS: MetricSummary(values.map(\.precisionLogicalPointsRMS))
            )
        }
        let availability = runEligibleFrames == 0 ? 0 : Double(runValidFrames) / Double(runEligibleFrames) * 100
        let rates = ProbeMath.rateSummaries(sampleTimes: runSampleTimes)
        let latency = MetricSummary(runLatencies)
        let blinkRecovery = MetricSummary(runBlinkRecoveries)
        let faceRecovery = MetricSummary(runFaceRecoveries)
        let movement = ProbeMath.movementSummary(fixations: fixationAggregates, viewport: UIScreen.main.bounds.size)
        let movementGain = MetricSummary(movement.gains)
        let drift = nominalAccuracyMedian.flatMap { baseline in accuracyDegrees.median.map { $0 - baseline } }
        let medianDistance = fixationAggregates.map(\.distanceMeters).sorted().percentile(0.5)
        let radiusCentimeters = accuracyDegrees.p90.flatMap { degrees in
            medianDistance.map { tan(degrees * .pi / 180) * $0 * 100 }
        }

        let regionsPass = regions.values.allSatisfy { ($0.accuracyDegrees.median ?? .infinity) <= 3.0 }
        let accuracyPass = (accuracyDegrees.median ?? .infinity) <= 2.0 &&
            (accuracyDegrees.p90 ?? .infinity) <= 4.0 && regionsPass
        let precisionPass = (precisionDegrees.median ?? .infinity) <= 1.0 &&
            (precisionDegrees.p90 ?? .infinity) <= 2.0
        let latencyPass = (latency.p90 ?? .infinity) <= 50 && (latency.worst ?? .infinity) <= 100
        let ratePass = (rates.sustainedMinimum ?? 0) >= 30
        let directionalPass = (movement.agreementPercent ?? 0) >= 80
        let eyeTotal = max(runEyeAvailabilityCounts.values.reduce(0, +), 1)
        func eyePercent(_ state: ProbeEyeAvailability) -> Double {
            Double(runEyeAvailabilityCounts[state, default: 0]) / Double(eyeTotal) * 100
        }
        let patchEyePass: String
        switch selectedCondition {
        case .patchLeft: patchEyePass = eyePercent(.rightOnly) >= 90 ? "pass" : "fail"
        case .patchRight: patchEyePass = eyePercent(.leftOnly) >= 90 ? "pass" : "fail"
        default: patchEyePass = "notApplicable"
        }

        var passFail: [String: String] = [
            "legacyAccuracyDiagnostic": accuracyPass ? "pass" : "fail",
            "precision": precisionPass ? "pass" : "fail",
            "availability": availability >= 95 ? "pass" : "fail",
            "updateRate": ratePass ? "pass" : "fail",
            "publicationLatency": latencyPass ? "pass" : "fail",
            "directionalMovement": directionalPass ? "pass" : "fail",
            "adaptiveRadiusProductAcceptance": accuracyPoints.p90 == nil ? "notMeasured" : "pending",
            "patchEyeAvailability": patchEyePass,
            "blinkRecovery": blinkRecovery.count == 0 ? "notMeasured" : ((blinkRecovery.p90 ?? .infinity) <= 250 ? "pass" : "fail"),
            "faceRecovery": faceRecovery.count == 0 ? "notMeasured" : ((faceRecovery.p90 ?? .infinity) <= 1_000 ? "pass" : "fail")
        ]
        passFail["patchPresenceVerification"] = switch selectedCondition {
        case .patchLeft, .patchRight: "notMeasured"
        default: "notApplicable"
        }
        if selectedCondition.rawValue.hasPrefix("drift") { passFail["calibrationReuse"] = accuracyPass ? "pass" : "fail" }

        return ConditionResult(
            condition: selectedCondition,
            gazeSource: selectedGazeSource,
            fixationCount: fixationAggregates.count,
            accuracyDegrees: accuracyDegrees,
            precisionDegreesRMS: precisionDegrees,
            accuracyLogicalPoints: accuracyPoints,
            precisionLogicalPointsRMS: precisionPoints,
            regions: regions,
            recommendedRadiusDegreesP90: accuracyDegrees.p90,
            recommendedRadiusLogicalPointsP90: accuracyPoints.p90,
            recommendedRadiusCentimetersP90: radiusCentimeters,
            movementDirectionalAgreementPercent: movement.agreementPercent,
            movementGain: movementGain,
            eyeAvailabilityBothPercent: eyePercent(.both),
            eyeAvailabilityLeftOnlyPercent: eyePercent(.leftOnly),
            eyeAvailabilityRightOnlyPercent: eyePercent(.rightOnly),
            eyeAvailabilityNonePercent: eyePercent(.none),
            availabilityPercent: availability,
            updateRateMedianHz: rates.median,
            updateRateP10Hz: rates.p10,
            updateRateSustainedMinimumHz: rates.sustainedMinimum,
            publicationLatencyMilliseconds: latency,
            blinkRecoveryMilliseconds: blinkRecovery,
            faceRecoveryMilliseconds: faceRecovery,
            leftEyeAngularStabilityDegreesRMS: MetricSummary(fixationAggregates.map(\.leftEyeAngularStabilityDegreesRMS)),
            rightEyeAngularStabilityDegreesRMS: MetricSummary(fixationAggregates.map(\.rightEyeAngularStabilityDegreesRMS)),
            lookAtPointStabilityMillimetersRMS: MetricSummary(fixationAggregates.map(\.lookAtPointStabilityMillimetersRMS)),
            driftFromNominalMedianDegrees: drift,
            passFail: passFail
        )
    }

    private func processSetupCheck(state: ProbeSetupState, timestamp: TimeInterval) {
        if setupStartedAt == nil { setupStartedAt = timestamp }
        setupCounts[state, default: 0] += 1
        guard let start = setupStartedAt, timestamp - start >= 10 else { return }
        let total = max(setupCounts.values.reduce(0, +), 1)
        func percent(_ state: ProbeSetupState) -> Double {
            Double(setupCounts[state, default: 0]) / Double(total) * 100
        }
        let expected = selectedCondition.expectedSetupState
        setupChecks.append(SetupCheckResult(
            condition: selectedCondition,
            durationSeconds: timestamp - start,
            frameCount: total,
            tooClosePercent: percent(.tooClose),
            readyPercent: percent(.ready),
            tooFarPercent: percent(.tooFar),
            unknownPercent: percent(.unknown),
            expectedState: expected,
            expectedStatePass: expected.map { percent($0) >= 90 }
        ))
        runMode = .idle
        setupStartedAt = nil
        activity = "ARKit setup-state check completed"
        aggregateStatus = "Recorded \(conditionResults.count) ARKit validation run(s), \(setupChecks.count) setup check(s)"
        persistAggregateResults()
    }

    private func resetFixationBuffers() {
        fixationPoints.removeAll(keepingCapacity: true)
        fixationDistances.removeAll(keepingCapacity: true)
        fixationLeftDirections.removeAll(keepingCapacity: true)
        fixationRightDirections.removeAll(keepingCapacity: true)
        fixationLookAtPoints.removeAll(keepingCapacity: true)
    }

    private func setupState(for distance: Double) -> ProbeSetupState {
        if distance < 0.40 { return .tooClose }
        if distance > 0.60 { return .tooFar }
        return .ready
    }

    private func eyeAvailability(leftBlink: Double, rightBlink: Double) -> ProbeEyeAvailability {
        let leftOpen = leftBlink < 0.80
        let rightOpen = rightBlink < 0.80
        // In the mounted landscape front-camera feed, ARKit's blend-shape side
        // labels are mirrored relative to the user's anatomical eye labels.
        let observed: ProbeEyeAvailability = switch (leftOpen, rightOpen) {
        case (true, true): .both
        case (true, false): .rightOnly
        case (false, true): .leftOnly
        case (false, false): .none
        }
        // Patch conditions select an anatomical active eye; this does not claim
        // to verify that an external patch is present. Blink labels are mirrored
        // on the exact mounted landscape device, as corrected above.
        switch selectedGazeSource {
        case .anatomicalRightEye:
            return observed == .both || observed == .rightOnly ? .rightOnly : .none
        case .anatomicalLeftEye:
            return observed == .both || observed == .leftOnly ? .leftOnly : .none
        case .fusedLookAtPoint:
            return observed
        }
    }

    private func activeEyeBlinking(leftBlink: Double, rightBlink: Double) -> Bool {
        switch selectedGazeSource {
        case .anatomicalRightEye:
            // Exact-device blend-shape labels are mirrored: leftBlink follows
            // the user's anatomical right eye.
            return leftBlink > 0.70
        case .anatomicalLeftEye:
            return rightBlink > 0.70
        case .fusedLookAtPoint:
            return leftBlink > 0.70 || rightBlink > 0.70
        }
    }

    private func persistAggregateResults() {
        let successfulDurations = calibrationAttempts.filter(\.success).map(\.durationSeconds)
        let duration = MetricSummary(successfulDurations)
        let firstAttempts = Dictionary(grouping: calibrationAttempts, by: \.condition).values.compactMap {
            $0.sorted { $0.attemptNumber < $1.attemptNumber }.first
        }
        let firstAttemptRate = firstAttempts.isEmpty ? nil :
            Double(firstAttempts.filter(\.success).count) / Double(firstAttempts.count) * 100
        let withinTwo = Dictionary(grouping: calibrationAttempts, by: \.condition).values.map {
            $0.filter { $0.attemptNumber <= 2 }.contains(where: \.success)
        }
        let withinTwoRate = withinTwo.isEmpty ? nil : Double(withinTwo.filter { $0 }.count) / Double(withinTwo.count) * 100

        let recorded = Set(conditionResults.map(\.condition))
        let distanceComplete = recorded.contains(.around40cm) && recorded.contains(.nominal45cm)
        let patchComplete = recorded.contains(.patchLeft) && recorded.contains(.patchRight)
        var overall: [String: String] = [
            "arFaceTrackingSupport": arFaceTrackingSupported ? "pass" : "fail",
            "optimizedDistanceComparison": distanceComplete ? "complete" : "incomplete",
            "bothPatchSides": patchComplete ? "complete" : "incomplete",
            "calibrationDuration": duration.count == 0 ? "notMeasured" : (((duration.median ?? .infinity) <= 30 && (duration.p90 ?? .infinity) <= 60) ? "pass" : "fail"),
            "calibrationFirstAttemptSuccess": firstAttemptRate == nil ? "notMeasured" : (firstAttemptRate! >= 80 ? "pass" : "fail"),
            "calibrationWithinTwoAttempts": withinTwoRate == nil ? "notMeasured" : (withinTwoRate! >= 90 ? "pass" : "fail")
        ]
        overall["allRecordedDirectionalMovement"] = conditionResults.isEmpty ? "notMeasured" :
            (conditionResults.allSatisfy { $0.passFail["directionalMovement"] == "pass" } ? "pass" : "fail")
        overall["allRecordedAvailability"] = conditionResults.isEmpty ? "notMeasured" :
            (conditionResults.allSatisfy { $0.passFail["availability"] == "pass" } ? "pass" : "fail")
        overall["allRecordedUpdateRate"] = conditionResults.isEmpty ? "notMeasured" :
            (conditionResults.allSatisfy { $0.passFail["updateRate"] == "pass" } ? "pass" : "fail")
        overall["allRecordedLatency"] = conditionResults.isEmpty ? "notMeasured" :
            (conditionResults.allSatisfy { $0.passFail["publicationLatency"] == "pass" } ? "pass" : "fail")
        overall["adaptiveRadiusProductAcceptance"] = "pending"
        overall["patchPresenceVerification"] = "notMeasured"

        let viewport = UIScreen.main.bounds.size
        let export = ProbeAggregateExport(
            schemaVersion: 4,
            algorithmVersion: Self.algorithmVersion,
            deviceModel: "iPad Air 13-inch (M2) (iPad14,10)",
            installedOS: "iPadOS \(UIDevice.current.systemVersion)",
            orientation: viewport.width > viewport.height ? "landscape" : "portrait",
            viewportLogicalPoints: "\(Int(viewport.width))x\(Int(viewport.height))",
            sourceFramework: "ARKit lookAtPoint baseline; selected anatomical eye transform for patch conditions",
            arFaceTrackingSupported: arFaceTrackingSupported,
            privacyStatement: "Aggregate, non-identifying metrics only; no camera frames, gaze samples, gaze paths, face geometry, calibration parameters, participant IDs, device IDs, or sample timestamps are persisted or transmitted.",
            calibrationAttempts: calibrationAttempts,
            conditionResults: conditionResults,
            setupChecks: setupChecks,
            overallPassFail: overall
        )
        do {
            let manager = FileManager.default
            let directory = try manager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            var directoryValues = URLResourceValues()
            directoryValues.isExcludedFromBackup = true
            var mutableDirectory = directory
            try mutableDirectory.setResourceValues(directoryValues)
            let url = directory.appendingPathComponent("phase1-arkit-selected-eye-9point-v8-aggregate-results.json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(export)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            aggregateStatus = "Selected-eye ARKit aggregate save failed"
        }
    }
}
