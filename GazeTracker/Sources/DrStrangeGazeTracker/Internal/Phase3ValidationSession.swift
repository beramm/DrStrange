import Foundation
import simd

struct Phase3ValidationSession {
    private struct Fixation {
        let target: NormalizedGazePoint
        let predictedMedian: SIMD2<Double>
        let radiusCentimeters: Double
        let radiusLogicalPoints: Double
        let radiusNormalized: Double
        let radiusDegrees: Double
        let precisionDegreesRMS: Double

        var region: String {
            let horizontalEdge = target.x <= 0.20 || target.x >= 0.80
            let verticalEdge = target.y <= 0.20 || target.y >= 0.80
            if horizontalEdge && verticalEdge { return "corner" }
            if horizontalEdge || verticalEdge { return "edge" }
            return "center"
        }
    }

    private(set) var state: Phase3ValidationState = .idle
    private(set) var summaries: [Phase3ValidationSummary] = []
    private var condition: Phase3ValidationCondition?
    private var targets: [NormalizedGazePoint] = []
    private var targetIndex = 0
    private var collector = StableWindowCollector()
    private var fixations: [Fixation] = []
    private var viewport: GazeViewport?
    private var layout: CalibrationLayout?
    private var mappingKind = ""
    private var eligibleFrames = 0
    private var validFrames = 0
    private var validTimestamps: [UInt64] = []
    private var latencies: [Double] = []
    private var retryCount = 0
    private var calibrationDurationSeconds: Double?
    private var calibrationTargetRetryCount = 0

    mutating func begin(
        condition: Phase3ValidationCondition,
        targets: [NormalizedGazePoint],
        viewport: GazeViewport,
        layout: CalibrationLayout,
        mappingKind: String,
        calibrationDurationSeconds: Double?,
        calibrationTargetRetryCount: Int
    ) throws {
        guard Self.isUntouchedPermutation(targets) else {
            throw CalibrationContractError.unexpectedTarget
        }
        switch condition {
        case .consecutiveOne:
            summaries.removeAll()
        case .consecutiveTwo:
            guard summaries.last?.condition == .consecutiveOne else {
                throw CalibrationContractError.invalidState
            }
        case .modestHeadMovement:
            guard summaries.suffix(2).map(\.condition) == [.consecutiveOne, .consecutiveTwo] else {
                throw CalibrationContractError.invalidState
            }
        }
        self.condition = condition
        self.targets = targets
        self.viewport = viewport
        self.layout = layout
        self.mappingKind = mappingKind
        self.calibrationDurationSeconds = calibrationDurationSeconds
        self.calibrationTargetRetryCount = calibrationTargetRetryCount
        targetIndex = 0
        fixations.removeAll(keepingCapacity: true)
        collector.reset()
        eligibleFrames = 0
        validFrames = 0
        validTimestamps.removeAll(keepingCapacity: true)
        latencies.removeAll(keepingCapacity: true)
        retryCount = 0
        state = .readyForTarget
    }

    mutating func beginTarget(_ target: NormalizedGazePoint) throws {
        guard state == .readyForTarget || state == .targetAccepted || state == .retryTarget,
              targetIndex < targets.count,
              targets[targetIndex] == target else {
            throw CalibrationContractError.unexpectedTarget
        }
        collector.begin(target: target)
        state = .collecting
    }

    mutating func ingest(
        timestampNanoseconds: UInt64,
        ray: SelectedEyeRayObservation?,
        setupState: SetupState,
        eyeAvailability: EyeAvailability,
        predict: (RaySample) -> SIMD2<Double>?
    ) {
        guard condition != nil, state != .idle, state != .completed, state != .failed else { return }
        if setupState == .ready {
            eligibleFrames += 1
            if let ray {
                let sample = RaySample(ray)
                if eyeAvailability == .rightOnly, predict(sample) != nil {
                    validFrames += 1
                    validTimestamps.append(timestampNanoseconds)
                    latencies.append(sample.publicationLatencyMilliseconds)
                }
            }
        }
        guard state == .collecting else { return }
        let result = collector.ingest(
            timestampNanoseconds: timestampNanoseconds,
            ray: ray.map(RaySample.init),
            setupReady: setupState == .ready,
            selectedEyeAvailable: eyeAvailability == .rightOnly
        )
        switch result {
        case .collecting:
            break
        case .retry:
            retryCount += 1
            collector.reset()
            state = .retryTarget
        case .accepted(let visit, let rays):
            guard let fixation = makeFixation(visit: visit, rays: rays, predict: predict) else {
                retryCount += 1
                collector.reset()
                state = .retryTarget
                return
            }
            fixations.append(fixation)
            targetIndex += 1
            collector.reset()
            if targetIndex < targets.count {
                state = .targetAccepted
            } else {
                finish()
            }
        }
    }

    mutating func cancel() {
        condition = nil
        targets.removeAll()
        fixations.removeAll()
        collector.reset()
        state = .idle
    }

    private func makeFixation(
        visit: TargetVisit,
        rays: [RaySample],
        predict: (RaySample) -> SIMD2<Double>?
    ) -> Fixation? {
        guard let viewport else { return nil }
        let points = rays.compactMap(predict)
        guard points.count == rays.count, !points.isEmpty else { return nil }
        let median = SIMD2(
            points.map(\.x).sorted().phase3Median,
            points.map(\.y).sorted().phase3Median
        )
        let dx = median.x - visit.target.x
        let dy = median.y - visit.target.y
        let radiusNormalized = hypot(dx, dy)
        let radiusPoints = hypot(dx * viewport.width, dy * viewport.height)
        let widthMeters = 0.26216
        let heightMeters = 0.19662
        let radiusMeters = hypot(dx * widthMeters, dy * heightMeters)
        let distance = max(visit.ray.distanceMeters, 0.01)
        let precisionMeters = sqrt(points.reduce(0.0) { partial, point in
            let px = (point.x - median.x) * widthMeters
            let py = (point.y - median.y) * heightMeters
            return partial + px * px + py * py
        } / Double(points.count))
        return Fixation(
            target: visit.target,
            predictedMedian: median,
            radiusCentimeters: radiusMeters * 100,
            radiusLogicalPoints: radiusPoints,
            radiusNormalized: radiusNormalized,
            radiusDegrees: atan2(radiusMeters, distance) * 180 / .pi,
            precisionDegreesRMS: atan2(precisionMeters, distance) * 180 / .pi
        )
    }

    private mutating func finish() {
        guard let condition, let layout else {
            state = .failed
            return
        }
        let movements = zip(fixations, fixations.dropFirst()).compactMap { first, second -> Bool? in
            let target = SIMD2(second.target.x - first.target.x, second.target.y - first.target.y)
            let predicted = second.predictedMedian - first.predictedMedian
            guard simd_length(target) > 1e-6, simd_length(predicted) > 1e-6 else { return nil }
            let cosine = simd_dot(target, predicted) / (simd_length(target) * simd_length(predicted))
            return cosine >= 0.5
        }
        let agreement = movements.isEmpty
            ? nil
            : Double(movements.filter { $0 }.count) / Double(movements.count) * 100
        let rateValues = zip(validTimestamps, validTimestamps.dropFirst()).compactMap { first, second -> Double? in
            guard second > first else { return nil }
            return 1_000_000_000 / Double(second - first)
        }
        let sortedRates = rateValues.sorted()
        let sustainedRate = Self.sustainedMinimumRate(timestamps: validTimestamps)
        var regions: [String: Phase3MetricSummary] = [:]
        for region in ["center", "edge", "corner"] {
            regions[region] = Phase3MetricSummary(
                values: fixations.filter { $0.region == region }.map(\.radiusCentimeters)
            )
        }
        summaries.append(Phase3ValidationSummary(
            algorithmVersion: Phase3CalibrationEngine.algorithmVersion,
            calibrationLayout: layout,
            mappingKind: mappingKind,
            condition: condition,
            fixationCount: fixations.count,
            rawRadiusCentimeters: Phase3MetricSummary(values: fixations.map(\.radiusCentimeters)),
            rawRadiusLogicalPoints: Phase3MetricSummary(values: fixations.map(\.radiusLogicalPoints)),
            rawRadiusNormalized: Phase3MetricSummary(values: fixations.map(\.radiusNormalized)),
            rawRadiusDegrees: Phase3MetricSummary(values: fixations.map(\.radiusDegrees)),
            rawPrecisionDegreesRMS: Phase3MetricSummary(values: fixations.map(\.precisionDegreesRMS)),
            regionalRawRadiusCentimeters: regions,
            directionalAgreementPercent: agreement,
            availabilityPercent: eligibleFrames == 0 ? 0 : Double(validFrames) / Double(eligibleFrames) * 100,
            updateRateMedianHz: sortedRates.phase3Percentile(0.5),
            updateRateP10Hz: sortedRates.phase3Percentile(0.1),
            updateRateSustainedMinimumHz: sustainedRate,
            publicationLatencyMilliseconds: Phase3MetricSummary(values: latencies),
            calibrationDurationSeconds: calibrationDurationSeconds,
            calibrationTargetRetryCount: calibrationTargetRetryCount,
            targetRetryCount: retryCount
        ))
        self.condition = nil
        fixations.removeAll()
        targets.removeAll()
        state = .completed
    }

    private static func isUntouchedPermutation(_ targets: [NormalizedGazePoint]) -> Bool {
        let expected = Set(Phase3ValidationPlan.targets.map { "\($0.x),\($0.y)" })
        let actual = Set(targets.map { "\($0.x),\($0.y)" })
        return targets.count == Phase3ValidationPlan.targets.count && actual == expected
    }

    private static func sustainedMinimumRate(timestamps: [UInt64]) -> Double? {
        guard let first = timestamps.first, let last = timestamps.last, last > first else { return nil }
        let tenSeconds: UInt64 = 10_000_000_000
        if last - first < tenSeconds {
            return Double(timestamps.count - 1) * 1_000_000_000 / Double(last - first)
        }
        var rates: [Double] = []
        var start = first
        while start + tenSeconds <= last {
            let count = timestamps.filter { $0 >= start && $0 < start + tenSeconds }.count
            rates.append(Double(count) / 10)
            start += 1_000_000_000
        }
        return rates.min()
    }
}

private extension Array where Element == Double {
    var phase3Median: Double {
        let middle = count / 2
        return count.isMultiple(of: 2) ? (self[middle - 1] + self[middle]) / 2 : self[middle]
    }


    func phase3Percentile(_ fraction: Double) -> Double? {
        guard !isEmpty else { return nil }
        let position = Swift.min(Swift.max(fraction, 0), 1) * Double(count - 1)
        let lower = Int(floor(position))
        let upper = Int(ceil(position))
        guard lower != upper else { return self[lower] }
        let weight = position - Double(lower)
        return self[lower] * (1 - weight) + self[upper] * weight
    }
}
