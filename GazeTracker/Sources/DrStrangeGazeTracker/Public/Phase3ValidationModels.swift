import Foundation

@_spi(Engineering)
public enum Phase3ValidationCondition: String, CaseIterable, Equatable, Sendable {
    case consecutiveOne
    case consecutiveTwo
    case modestHeadMovement
}

@_spi(Engineering)
public enum Phase3ValidationState: String, Equatable, Sendable {
    case idle
    case readyForTarget
    case collecting
    case targetAccepted
    case retryTarget
    case completed
    case failed
}

@_spi(Engineering)
public struct Phase3MetricSummary: Equatable, Sendable {
    public let count: Int
    public let median: Double?
    public let p90: Double?
    public let worst: Double?

    public init(values: [Double]) {
        let sorted = values.filter(\.isFinite).sorted()
        count = sorted.count
        median = sorted.phase3Percentile(0.5)
        p90 = sorted.phase3Percentile(0.9)
        worst = sorted.last
    }
}

@_spi(Engineering)
public struct Phase3ValidationSummary: Equatable, Sendable {
    public let algorithmVersion: String
    public let calibrationLayout: CalibrationLayout
    public let mappingKind: String
    public let condition: Phase3ValidationCondition
    public let fixationCount: Int
    public let rawRadiusCentimeters: Phase3MetricSummary
    public let rawRadiusLogicalPoints: Phase3MetricSummary
    public let rawRadiusNormalized: Phase3MetricSummary
    public let rawRadiusDegrees: Phase3MetricSummary
    public let rawPrecisionDegreesRMS: Phase3MetricSummary
    public let regionalRawRadiusCentimeters: [String: Phase3MetricSummary]
    public let directionalAgreementPercent: Double?
    public let availabilityPercent: Double
    public let updateRateMedianHz: Double?
    public let updateRateP10Hz: Double?
    public let updateRateSustainedMinimumHz: Double?
    public let publicationLatencyMilliseconds: Phase3MetricSummary
    public let calibrationDurationSeconds: Double?
    public let calibrationTargetRetryCount: Int
    public let targetRetryCount: Int

    public var passesFourCentimeterGate: Bool {
        fixationCount == Phase3ValidationPlan.targets.count &&
            (rawRadiusCentimeters.p90 ?? .infinity) <= 4.0
    }
}

@_spi(Engineering)
public enum Phase3ValidationPlan {
    /// Untouched targets are distinct from both calibration layouts. The host
    /// randomizes this array independently for each validation pass.
    public static let targets: [NormalizedGazePoint] = [
        NormalizedGazePoint(x: 0.13, y: 0.16)!, NormalizedGazePoint(x: 0.87, y: 0.16)!,
        NormalizedGazePoint(x: 0.13, y: 0.84)!, NormalizedGazePoint(x: 0.87, y: 0.84)!,
        NormalizedGazePoint(x: 0.50, y: 0.18)!, NormalizedGazePoint(x: 0.84, y: 0.50)!,
        NormalizedGazePoint(x: 0.50, y: 0.82)!, NormalizedGazePoint(x: 0.16, y: 0.50)!,
        NormalizedGazePoint(x: 0.38, y: 0.42)!, NormalizedGazePoint(x: 0.62, y: 0.58)!
    ]
}

extension Array where Element == Double {
    fileprivate func phase3Percentile(_ fraction: Double) -> Double? {
        guard !isEmpty else { return nil }
        let position = Swift.min(Swift.max(fraction, 0), 1) * Double(count - 1)
        let lower = Int(floor(position))
        let upper = Int(ceil(position))
        guard lower != upper else { return self[lower] }
        let weight = position - Double(lower)
        return self[lower] * (1 - weight) + self[upper] * weight
    }
}
