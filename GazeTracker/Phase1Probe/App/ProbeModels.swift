import CoreGraphics
import Foundation
import simd

enum ProbeTrackingState: String, Codable {
    case tracking, limited, lost, paused, unsupported, permissionDenied
}

enum ProbeSetupState: String, Codable {
    case tooClose, ready, tooFar, unknown
}

enum ProbeCalibrationState: String, Codable {
    case notCalibrated, readyForTarget, collecting, targetAccepted
    case retryTarget, calibrated, invalid, failed
}

enum ProbeEyeAvailability: String, Codable {
    case both, leftOnly, rightOnly, none
}

enum ProbeGazeSource: String, CaseIterable, Codable, Identifiable {
    case fusedLookAtPoint
    case anatomicalLeftEye
    case anatomicalRightEye

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fusedLookAtPoint: "Fused look-at baseline"
        case .anatomicalLeftEye: "Selected anatomical left eye"
        case .anatomicalRightEye: "Selected anatomical right eye"
        }
    }
}

/// Complete live-output surface of the disposable probe.
/// ARKit types and face/eye geometry never cross this boundary.
struct ProbeSample {
    let pointNormalized: CGPoint?
    let timestamp: TimeInterval
    let confidence: Double
    let trackingState: ProbeTrackingState
    let setupState: ProbeSetupState
    let calibrationState: ProbeCalibrationState
    let eyeAvailability: ProbeEyeAvailability
}

enum ProbeCondition: String, CaseIterable, Codable, Identifiable {
    case nominal45cm
    case patchLeft
    case patchRight
    case blinkRecovery
    case briefFaceLoss
    case headMovement
    case glasses
    case brightLighting
    case typicalLighting
    case dimSupportedLighting
    case below40cm
    case around40cm
    case around60cm
    case above60cm
    case remounted
    case driftAfterRepresentativeUse
    case driftAfterPause
    case driftAfterInterruption

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nominal45cm: "Nominal 45 cm"
        case .patchLeft: "Left eye patched"
        case .patchRight: "Right eye patched"
        case .blinkRecovery: "Blink recovery"
        case .briefFaceLoss: "Brief face loss"
        case .headMovement: "Modest head movement"
        case .glasses: "Glasses"
        case .brightLighting: "Bright lighting"
        case .typicalLighting: "Typical lighting"
        case .dimSupportedLighting: "Dim supported lighting"
        case .below40cm: "Below 40 cm"
        case .around40cm: "Around 40 cm"
        case .around60cm: "Around 60 cm"
        case .above60cm: "Above 60 cm"
        case .remounted: "Remounted"
        case .driftAfterRepresentativeUse: "Drift after representative use"
        case .driftAfterPause: "Drift after pause"
        case .driftAfterInterruption: "Drift after interruption"
        }
    }

    var expectedSetupState: ProbeSetupState? {
        switch self {
        case .below40cm: .tooClose
        case .around40cm, .nominal45cm, .around60cm: .ready
        case .above60cm: .tooFar
        default: nil
        }
    }

    var forcedGazeSource: ProbeGazeSource? {
        switch self {
        case .patchLeft: .anatomicalRightEye
        case .patchRight: .anatomicalLeftEye
        default: nil
        }
    }
}

struct MetricSummary: Codable {
    let count: Int
    let median: Double?
    let p90: Double?
    let worst: Double?

    init(_ values: [Double]) {
        let finite = values.filter(\.isFinite).sorted()
        count = finite.count
        median = finite.percentile(0.50)
        p90 = finite.percentile(0.90)
        worst = finite.last
    }
}

struct RegionalResult: Codable {
    let fixationCount: Int
    let accuracyDegrees: MetricSummary
    let precisionDegreesRMS: MetricSummary
    let accuracyLogicalPoints: MetricSummary
    let precisionLogicalPointsRMS: MetricSummary
}

struct ConditionResult: Codable {
    let condition: ProbeCondition
    let gazeSource: ProbeGazeSource
    let fixationCount: Int
    let accuracyDegrees: MetricSummary
    let precisionDegreesRMS: MetricSummary
    let accuracyLogicalPoints: MetricSummary
    let precisionLogicalPointsRMS: MetricSummary
    let regions: [String: RegionalResult]
    let recommendedRadiusDegreesP90: Double?
    let recommendedRadiusLogicalPointsP90: Double?
    let recommendedRadiusCentimetersP90: Double?
    let movementDirectionalAgreementPercent: Double?
    let movementGain: MetricSummary
    let eyeAvailabilityBothPercent: Double
    let eyeAvailabilityLeftOnlyPercent: Double
    let eyeAvailabilityRightOnlyPercent: Double
    let eyeAvailabilityNonePercent: Double
    let availabilityPercent: Double
    let updateRateMedianHz: Double?
    let updateRateP10Hz: Double?
    let updateRateSustainedMinimumHz: Double?
    let publicationLatencyMilliseconds: MetricSummary
    let blinkRecoveryMilliseconds: MetricSummary
    let faceRecoveryMilliseconds: MetricSummary
    let leftEyeAngularStabilityDegreesRMS: MetricSummary
    let rightEyeAngularStabilityDegreesRMS: MetricSummary
    let lookAtPointStabilityMillimetersRMS: MetricSummary
    let driftFromNominalMedianDegrees: Double?
    let passFail: [String: String]
}

struct SetupCheckResult: Codable {
    let condition: ProbeCondition
    let durationSeconds: Double
    let frameCount: Int
    let tooClosePercent: Double
    let readyPercent: Double
    let tooFarPercent: Double
    let unknownPercent: Double
    let expectedState: ProbeSetupState?
    let expectedStatePass: Bool?
}

struct CalibrationAttemptResult: Codable {
    let condition: ProbeCondition
    let gazeSource: ProbeGazeSource
    let attemptNumber: Int
    let success: Bool
    let durationSeconds: Double
}

struct ProbeAggregateExport: Codable {
    let schemaVersion: Int
    let algorithmVersion: String
    let deviceModel: String
    let installedOS: String
    let orientation: String
    let viewportLogicalPoints: String
    let sourceFramework: String
    let arFaceTrackingSupported: Bool
    let privacyStatement: String
    let calibrationAttempts: [CalibrationAttemptResult]
    let conditionResults: [ConditionResult]
    let setupChecks: [SetupCheckResult]
    let overallPassFail: [String: String]
}

struct InternalObservation {
    let timestamp: TimeInterval
    let publicationLatencyMilliseconds: Double
    let features: [Double]
    let leftEyeDirection: SIMD3<Double>
    let rightEyeDirection: SIMD3<Double>
    let lookAtPoint: SIMD2<Double>
    let distanceMeters: Double
    let blinkLeft: Double
    let blinkRight: Double
}

struct FixationAggregate {
    let region: String
    let targetNormalized: CGPoint
    let predictedMedianNormalized: CGPoint
    let distanceMeters: Double
    let accuracyDegrees: Double
    let precisionDegreesRMS: Double
    let accuracyLogicalPoints: Double
    let precisionLogicalPointsRMS: Double
    let leftEyeAngularStabilityDegreesRMS: Double
    let rightEyeAngularStabilityDegreesRMS: Double
    let lookAtPointStabilityMillimetersRMS: Double
}

extension Array where Element == Double {
    func percentile(_ fraction: Double) -> Double? {
        guard !isEmpty else { return nil }
        let clamped = Swift.min(Swift.max(fraction, 0), 1)
        let position = clamped * Double(count - 1)
        let lower = Int(floor(position))
        let upper = Int(ceil(position))
        guard lower != upper else { return self[lower] }
        let weight = position - Double(lower)
        return self[lower] * (1 - weight) + self[upper] * weight
    }
}
