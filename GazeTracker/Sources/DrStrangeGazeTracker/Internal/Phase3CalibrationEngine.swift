import Foundation
import simd

struct Phase3CalibrationEngine {
    static let algorithmVersion = "phase3-selected-right-ray-v1"

    enum MappingKind: String, Equatable, Sendable {
        case fiveTermQuadratic
        case rayPlaneWithAffineResidual
    }

    enum CollectionEvent {
        case none
        case targetAccepted
        case retryTarget
        case calibrated(MappingKind)
        case failed
    }

    struct Output {
        let event: CollectionEvent
        let point: NormalizedGazePoint?
        let quality: GazeQuality
    }

    private var layout: CalibrationLayout?
    private var expectedIndex = 0
    private var visits: [TargetVisit] = []
    private var collector = StableWindowCollector()
    private var model: MappingModel?
    private var calibrationStartedAtNanoseconds: UInt64?
    private(set) var calibrationDurationSeconds: Double?
    private(set) var calibrationTargetRetryCount = 0

    var isCalibrated: Bool { model != nil }
    var mappingKind: MappingKind? { model?.kind }
    var calibrationLayout: CalibrationLayout? { layout }

    func predictRaw(_ ray: RaySample) -> SIMD2<Double>? { model?.predict(ray) }

    mutating func begin(layout: CalibrationLayout, startedAtNanoseconds: UInt64) {
        self.layout = layout
        expectedIndex = 0
        visits.removeAll(keepingCapacity: true)
        collector.reset()
        model = nil
        calibrationStartedAtNanoseconds = startedAtNanoseconds
        calibrationDurationSeconds = nil
        calibrationTargetRetryCount = 0
    }

    mutating func beginTarget(_ target: NormalizedGazePoint) throws {
        guard let targets = layout?.targets, expectedIndex < targets.count else {
            throw CalibrationContractError.invalidState
        }
        guard targets[expectedIndex] == target else {
            throw CalibrationContractError.unexpectedTarget
        }
        collector.begin(target: target)
    }

    mutating func cancel() {
        layout = nil
        expectedIndex = 0
        visits.removeAll()
        collector.reset()
        model = nil
    }

    mutating func invalidate() {
        cancel()
    }

    mutating func ingest(
        timestampNanoseconds: UInt64,
        ray: SelectedEyeRayObservation?,
        setupState: SetupState,
        eyeAvailability: EyeAvailability
    ) -> Output {
        let rawPoint = ray.flatMap { model?.predict(RaySample($0)) }
        let publicPoint = rawPoint.flatMap { NormalizedGazePoint(x: $0.x, y: $0.y) }
        let liveUsable = publicPoint != nil && setupState == .ready && eyeAvailability == .rightOnly
        let liveQuality = liveUsable
            ? GazeQuality(confidence: 0.85, level: .usable)
            : .unavailable

        guard collector.isActive else {
            return Output(event: .none, point: liveUsable ? publicPoint : nil, quality: liveQuality)
        }

        let result = collector.ingest(
            timestampNanoseconds: timestampNanoseconds,
            ray: ray.map(RaySample.init),
            setupReady: setupState == .ready,
            selectedEyeAvailable: eyeAvailability == .rightOnly
        )
        switch result {
        case .collecting:
            return Output(event: .none, point: nil, quality: .unavailable)
        case .retry:
            calibrationTargetRetryCount += 1
            collector.reset()
            return Output(event: .retryTarget, point: nil, quality: .unavailable)
        case .accepted(let visit, _):
            visits.append(visit)
            expectedIndex += 1
            collector.reset()
            guard let targets = layout?.targets else {
                return Output(event: .failed, point: nil, quality: .unavailable)
            }
            guard expectedIndex == targets.count else {
                return Output(event: .targetAccepted, point: nil, quality: .unavailable)
            }
            guard let selected = MappingModel.select(visits: visits) else {
                visits.removeAll()
                return Output(event: .failed, point: nil, quality: .unavailable)
            }
            model = selected
            if let start = calibrationStartedAtNanoseconds, timestampNanoseconds >= start {
                calibrationDurationSeconds = Double(timestampNanoseconds - start) / 1_000_000_000
            }
            visits.removeAll()
            return Output(event: .calibrated(selected.kind), point: nil, quality: .unavailable)
        }
    }
}

struct RaySample: Equatable {
    let origin: SIMD3<Double>
    let direction: SIMD3<Double>
    let baselineDirection: SIMD2<Double>
    let headDirection: SIMD3<Double>
    let distanceMeters: Double
    let blink: Double
    let publicationLatencyMilliseconds: Double

    init(_ value: SelectedEyeRayObservation) {
        origin = SIMD3(value.originX, value.originY, value.originZ)
        let rawDirection = SIMD3(value.directionX, value.directionY, value.directionZ)
        direction = simd_length(rawDirection) > 1e-9 ? simd_normalize(rawDirection) : rawDirection
        baselineDirection = SIMD2(value.baselineDirectionX, value.baselineDirectionY)
        let rawHeadDirection = SIMD3(value.headDirectionX, value.headDirectionY, value.headDirectionZ)
        headDirection = simd_length(rawHeadDirection) > 1e-9 ? simd_normalize(rawHeadDirection) : rawHeadDirection
        distanceMeters = value.faceDistanceMeters
        blink = value.selectedEyeBlink
        publicationLatencyMilliseconds = value.publicationLatencyMilliseconds
    }

    var isFinite: Bool {
        origin.allFinite && direction.allFinite && baselineDirection.allFinite && headDirection.allFinite &&
            distanceMeters.isFinite &&
            publicationLatencyMilliseconds.isFinite && simd_length(direction) > 0.99
    }
}

struct TargetVisit {
    let target: NormalizedGazePoint
    let ray: RaySample
    let acceptedFrameCount: Int
    let angularDispersionDegrees: Double
    let maximumAngularVelocityDegreesPerSecond: Double
    let originRangeMeters: Double
    let headPoseRangeDegrees: Double
}

struct StableWindowCollector {
    enum Result {
        case collecting
        case retry
        case accepted(TargetVisit, [RaySample])
    }

    private(set) var isActive = false
    private var target: NormalizedGazePoint?
    private var startedAt: UInt64?
    private var lastBlinkAt: UInt64?
    private var recent: [(UInt64, RaySample)] = []
    private var accepted: [(UInt64, RaySample)] = []
    private var maximumVelocity = 0.0

    private let blinkThreshold = 0.70
    private let postBlinkNanoseconds: UInt64 = 250_000_000
    private let maximumTargetNanoseconds: UInt64 = 3_500_000_000
    private let recentCapacity = 48
    private let fixationEstablishmentNanoseconds: UInt64 = 500_000_000
    private let acceptedMinimumDurationNanoseconds: UInt64 = 1_000_000_000
    private let acceptedFrameFloor = 24
    private let maximumDispersionDegrees = 1.5
    private let maximumVelocityDegreesPerSecond = 20.0
    private let maximumOriginRangeMeters = 0.015
    private let maximumHeadPoseRangeDegrees = 3.0

    mutating func begin(target: NormalizedGazePoint) {
        reset()
        self.target = target
        isActive = true
    }

    mutating func reset() {
        isActive = false
        target = nil
        startedAt = nil
        lastBlinkAt = nil
        recent.removeAll(keepingCapacity: true)
        accepted.removeAll(keepingCapacity: true)
        maximumVelocity = 0
    }

    mutating func ingest(
        timestampNanoseconds: UInt64,
        ray: RaySample?,
        setupReady: Bool,
        selectedEyeAvailable: Bool
    ) -> Result {
        guard isActive, let target else { return .collecting }
        if startedAt == nil { startedAt = timestampNanoseconds }
        if let start = startedAt, timestampNanoseconds &- start >= maximumTargetNanoseconds {
            return .retry
        }

        guard let ray, ray.isFinite else {
            clearStability()
            return .collecting
        }
        if ray.blink >= blinkThreshold {
            lastBlinkAt = timestampNanoseconds
            clearStability()
            return .collecting
        }
        if let blink = lastBlinkAt, timestampNanoseconds &- blink < postBlinkNanoseconds {
            clearStability()
            return .collecting
        }
        guard setupReady, selectedEyeAvailable else {
            clearStability()
            return .collecting
        }

        if let previous = recent.last, timestampNanoseconds > previous.0 {
            let seconds = Double(timestampNanoseconds - previous.0) / 1_000_000_000
            let angle = Self.angleDegrees(previous.1.direction, ray.direction)
            maximumVelocity = max(maximumVelocity, angle / seconds)
        }
        recent.append((timestampNanoseconds, ray))
        if recent.count > recentCapacity { recent.removeFirst(recent.count - recentCapacity) }

        guard let recentStart = recent.first?.0,
              timestampNanoseconds &- recentStart >= fixationEstablishmentNanoseconds else {
            return .collecting
        }
        let dispersion = Self.dispersionDegrees(recent.map { $0.1.direction })
        let originRange = Self.originRange(recent.map { $0.1.origin })
        let headPoseRange = Self.dispersionDegrees(recent.map { $0.1.headDirection })
        guard dispersion <= maximumDispersionDegrees,
              maximumVelocity <= maximumVelocityDegreesPerSecond,
              originRange <= maximumOriginRangeMeters,
              headPoseRange <= maximumHeadPoseRangeDegrees else {
            clearStability()
            return .collecting
        }

        accepted.append((timestampNanoseconds, ray))
        guard let acceptedStart = accepted.first?.0,
              accepted.count >= acceptedFrameFloor,
              timestampNanoseconds &- acceptedStart >= acceptedMinimumDurationNanoseconds else {
            return .collecting
        }
        let rays = accepted.map { $0.1 }
        let aggregate = RaySample.robustAggregate(rays)
        return .accepted(TargetVisit(
            target: target,
            ray: aggregate,
            acceptedFrameCount: accepted.count,
            angularDispersionDegrees: Self.dispersionDegrees(rays.map(\.direction)),
            maximumAngularVelocityDegreesPerSecond: maximumVelocity,
            originRangeMeters: Self.originRange(rays.map(\.origin)),
            headPoseRangeDegrees: Self.dispersionDegrees(rays.map(\.headDirection))
        ), rays)
    }

    private mutating func clearStability() {
        recent.removeAll(keepingCapacity: true)
        accepted.removeAll(keepingCapacity: true)
        maximumVelocity = 0
    }

    static func angleDegrees(_ lhs: SIMD3<Double>, _ rhs: SIMD3<Double>) -> Double {
        acos(min(max(simd_dot(lhs, rhs), -1), 1)) * 180 / .pi
    }

    static func dispersionDegrees(_ directions: [SIMD3<Double>]) -> Double {
        guard !directions.isEmpty else { return .infinity }
        let sum = directions.reduce(SIMD3<Double>(repeating: 0), +)
        guard simd_length(sum) > 1e-9 else { return .infinity }
        let centre = simd_normalize(sum)
        return directions.map { angleDegrees(centre, $0) }.max() ?? .infinity
    }

    static func originRange(_ origins: [SIMD3<Double>]) -> Double {
        guard let first = origins.first else { return .infinity }
        return origins.dropFirst().map { simd_distance(first, $0) }.max() ?? 0
    }
}

private extension RaySample {
    static func robustAggregate(_ values: [RaySample]) -> RaySample {
        func median(_ values: [Double]) -> Double {
            let sorted = values.sorted()
            let middle = sorted.count / 2
            return sorted.count.isMultiple(of: 2)
                ? (sorted[middle - 1] + sorted[middle]) / 2
                : sorted[middle]
        }
        let origin = SIMD3(
            median(values.map { $0.origin.x }),
            median(values.map { $0.origin.y }),
            median(values.map { $0.origin.z })
        )
        let rawDirection = SIMD3(
            median(values.map { $0.direction.x }),
            median(values.map { $0.direction.y }),
            median(values.map { $0.direction.z })
        )
        return RaySample(
            origin: origin,
            direction: simd_normalize(rawDirection),
            baselineDirection: SIMD2(
                median(values.map { $0.baselineDirection.x }),
                median(values.map { $0.baselineDirection.y })
            ),
            headDirection: simd_normalize(SIMD3(
                median(values.map { $0.headDirection.x }),
                median(values.map { $0.headDirection.y }),
                median(values.map { $0.headDirection.z })
            )),
            distanceMeters: median(values.map(\.distanceMeters)),
            blink: median(values.map(\.blink)),
            publicationLatencyMilliseconds: median(values.map(\.publicationLatencyMilliseconds))
        )
    }

    init(
        origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        baselineDirection: SIMD2<Double>,
        headDirection: SIMD3<Double>,
        distanceMeters: Double,
        blink: Double,
        publicationLatencyMilliseconds: Double
    ) {
        self.origin = origin
        self.direction = direction
        self.baselineDirection = baselineDirection
        self.headDirection = headDirection
        self.distanceMeters = distanceMeters
        self.blink = blink
        self.publicationLatencyMilliseconds = publicationLatencyMilliseconds
    }
}

private struct MappingModel {
    let kind: Phase3CalibrationEngine.MappingKind
    let transform: (RaySample) -> SIMD2<Double>?

    func predict(_ ray: RaySample) -> SIMD2<Double>? { transform(ray) }

    static func select(visits: [TargetVisit]) -> MappingModel? {
        let candidates = [quadratic(visits: visits), geometric(visits: visits)].compactMap { $0 }
        return candidates.min { looError(kind: $0.kind, visits: visits) < looError(kind: $1.kind, visits: visits) }
    }

    private static func looError(kind: Phase3CalibrationEngine.MappingKind, visits: [TargetVisit]) -> Double {
        guard visits.count >= 7 else { return .infinity }
        var errors: [Double] = []
        for index in visits.indices {
            var training = visits
            let heldOut = training.remove(at: index)
            let fitted = kind == .fiveTermQuadratic
                ? quadratic(visits: training)
                : geometric(visits: training)
            guard let point = fitted?.predict(heldOut.ray) else { return .infinity }
            errors.append(hypot(point.x - heldOut.target.x, point.y - heldOut.target.y))
        }
        return errors.sorted().percentile(0.9) ?? .infinity
    }

    private static func quadratic(visits: [TargetVisit]) -> MappingModel? {
        let features = visits.map { visit in
            let x = visit.ray.baselineDirection.x
            let y = visit.ray.baselineDirection.y
            return [1, x, y, x * x, y * y, x * y]
        }
        let targets = visits.map { SIMD2($0.target.x, $0.target.y) }
        guard let fit = RobustLinearFit.fit(features: features, targets: targets, ridge: 0.01) else { return nil }
        return MappingModel(kind: .fiveTermQuadratic) { ray in
            let x = ray.baselineDirection.x
            let y = ray.baselineDirection.y
            return fit.predict([1, x, y, x * x, y * y, x * y])
        }
    }

    private static func geometric(visits: [TargetVisit]) -> MappingModel? {
        let nominal = visits.compactMap { RayPlaneGeometry.intersectionNormalized($0.ray) }
        guard nominal.count == visits.count else { return nil }
        let features = nominal.map { [1, $0.x - 0.5, $0.y - 0.5] }
        let residuals = zip(nominal, visits).map { point, visit in
            SIMD2(visit.target.x - point.x, visit.target.y - point.y)
        }
        guard let fit = RobustLinearFit.fit(features: features, targets: residuals, ridge: 0.03),
              fit.coefficients.allSatisfy({ abs($0.x) <= 0.35 && abs($0.y) <= 0.35 }),
              abs(fit.coefficients[0].x) <= 0.15,
              abs(fit.coefficients[0].y) <= 0.15 else { return nil }
        return MappingModel(kind: .rayPlaneWithAffineResidual) { ray in
            guard let point = RayPlaneGeometry.intersectionNormalized(ray) else { return nil }
            let residual = fit.predict([1, point.x - 0.5, point.y - 0.5])
            return point + residual
        }
    }
}

private enum RayPlaneGeometry {
    // 12.9-inch 4:3 display. The landscape camera is modelled at the midpoint
    // of the upper edge; calibration may fit only a bounded affine residual.
    static let widthMeters = 0.26216
    static let heightMeters = 0.19662

    static func intersectionNormalized(_ ray: RaySample) -> SIMD2<Double>? {
        guard abs(ray.direction.z) > 1e-6 else { return nil }
        let t = -ray.origin.z / ray.direction.z
        guard t.isFinite, t > 0 else { return nil }
        let hit = ray.origin + ray.direction * t
        let point = SIMD2(0.5 + hit.x / widthMeters, -hit.y / heightMeters)
        return point.allFinite ? point : nil
    }
}

private struct RobustLinearFit {
    let coefficients: [SIMD2<Double>]

    func predict(_ features: [Double]) -> SIMD2<Double> {
        zip(features, coefficients).reduce(SIMD2<Double>(repeating: 0)) { $0 + $1.1 * $1.0 }
    }

    static func fit(features: [[Double]], targets: [SIMD2<Double>], ridge: Double) -> RobustLinearFit? {
        guard features.count == targets.count,
              let width = features.first?.count,
              features.count >= width,
              features.allSatisfy({ $0.count == width }) else { return nil }
        var weights = Array(repeating: 1.0, count: features.count)
        var fit: RobustLinearFit?
        for _ in 0..<4 {
            guard let candidate = weightedFit(features: features, targets: targets, weights: weights, ridge: ridge) else {
                return nil
            }
            fit = candidate
            let residuals = zip(features, targets).map { simd_length(candidate.predict($0) - $1) }
            let scale = max(residuals.sorted().percentile(0.5) ?? 0, 1e-5)
            let threshold = 1.5 * scale
            weights = residuals.map { $0 <= threshold ? 1 : threshold / $0 }
        }
        return fit
    }

    private static func weightedFit(
        features: [[Double]],
        targets: [SIMD2<Double>],
        weights: [Double],
        ridge: Double
    ) -> RobustLinearFit? {
        let width = features[0].count
        var normal = Array(repeating: Array(repeating: 0.0, count: width), count: width)
        var rhsX = Array(repeating: 0.0, count: width)
        var rhsY = Array(repeating: 0.0, count: width)
        for ((row, target), weight) in zip(zip(features, targets), weights) {
            for i in 0..<width {
                rhsX[i] += weight * row[i] * target.x
                rhsY[i] += weight * row[i] * target.y
                for j in 0..<width { normal[i][j] += weight * row[i] * row[j] }
            }
        }
        for index in 1..<width { normal[index][index] += ridge }
        guard let x = solve(normal, rhsX), let y = solve(normal, rhsY) else { return nil }
        return RobustLinearFit(coefficients: zip(x, y).map { SIMD2($0.0, $0.1) })
    }

    private static func solve(_ matrix: [[Double]], _ vector: [Double]) -> [Double]? {
        var augmented = zip(matrix, vector).map { $0 + [$1] }
        for pivot in vector.indices {
            guard let best = (pivot..<vector.count).max(by: {
                abs(augmented[$0][pivot]) < abs(augmented[$1][pivot])
            }), abs(augmented[best][pivot]) > 1e-10 else { return nil }
            if best != pivot { augmented.swapAt(best, pivot) }
            let divisor = augmented[pivot][pivot]
            for column in pivot...vector.count { augmented[pivot][column] /= divisor }
            for row in vector.indices where row != pivot {
                let factor = augmented[row][pivot]
                for column in pivot...vector.count {
                    augmented[row][column] -= factor * augmented[pivot][column]
                }
            }
        }
        return augmented.map { $0[vector.count] }
    }
}

private extension SIMD3 where Scalar == Double {
    var allFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

private extension SIMD2 where Scalar == Double {
    var allFinite: Bool { x.isFinite && y.isFinite }
}

private extension Array where Element == Double {
    func percentile(_ fraction: Double) -> Double? {
        guard !isEmpty else { return nil }
        let position = Swift.min(Swift.max(fraction, 0), 1) * Double(count - 1)
        let lower = Int(floor(position))
        let upper = Int(ceil(position))
        guard lower != upper else { return self[lower] }
        let weight = position - Double(lower)
        return self[lower] * (1 - weight) + self[upper] * weight
    }
}
