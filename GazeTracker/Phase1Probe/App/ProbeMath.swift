import CoreGraphics
import Foundation
import simd

struct RegressionModel {
    private let means: [Double]
    private let scales: [Double]
    private let coefficientsX: [Double]
    private let coefficientsY: [Double]

    static func fit(features: [[Double]], targets: [CGPoint]) -> RegressionModel? {
        guard features.count == targets.count,
              features.count >= 30,
              let width = features.first?.count,
              width > 0,
              features.allSatisfy({ $0.count == width }) else { return nil }

        var means = Array(repeating: 0.0, count: width)
        for row in features {
            for index in 0..<width { means[index] += row[index] }
        }
        means = means.map { $0 / Double(features.count) }

        var scales = Array(repeating: 0.0, count: width)
        for row in features {
            for index in 0..<width {
                let delta = row[index] - means[index]
                scales[index] += delta * delta
            }
        }
        scales = scales.map { max(sqrt($0 / Double(features.count)), 1e-6) }

        let normalized = features.map { row in
            [1.0] + zip(zip(row, means), scales).map { pair, scale in
                (pair.0 - pair.1) / scale
            }
        }
        let dimension = width + 1
        var normal = Array(repeating: Array(repeating: 0.0, count: dimension), count: dimension)
        var rhsX = Array(repeating: 0.0, count: dimension)
        var rhsY = Array(repeating: 0.0, count: dimension)

        for (row, target) in zip(normalized, targets) {
            for i in 0..<dimension {
                rhsX[i] += row[i] * Double(target.x)
                rhsY[i] += row[i] * Double(target.y)
                for j in 0..<dimension { normal[i][j] += row[i] * row[j] }
            }
        }
        for index in 1..<dimension { normal[index][index] += 0.01 }

        guard let x = solve(normal, rhsX), let y = solve(normal, rhsY) else { return nil }
        return RegressionModel(means: means, scales: scales, coefficientsX: x, coefficientsY: y)
    }

    func predict(_ features: [Double]) -> CGPoint? {
        guard features.count == means.count else { return nil }
        let row = [1.0] + zip(zip(features, means), scales).map { pair, scale in
            (pair.0 - pair.1) / scale
        }
        let x = zip(row, coefficientsX).reduce(0.0) { $0 + $1.0 * $1.1 }
        let y = zip(row, coefficientsY).reduce(0.0) { $0 + $1.0 * $1.1 }
        guard x.isFinite, y.isFinite else { return nil }
        return CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }

    private static func solve(_ matrix: [[Double]], _ vector: [Double]) -> [Double]? {
        var augmented = zip(matrix, vector).map { $0 + [$1] }
        let count = vector.count
        for pivot in 0..<count {
            guard let best = (pivot..<count).max(by: {
                abs(augmented[$0][pivot]) < abs(augmented[$1][pivot])
            }), abs(augmented[best][pivot]) > 1e-10 else { return nil }
            if best != pivot { augmented.swapAt(best, pivot) }
            let divisor = augmented[pivot][pivot]
            for column in pivot...count { augmented[pivot][column] /= divisor }
            for row in 0..<count where row != pivot {
                let factor = augmented[row][pivot]
                for column in pivot...count { augmented[row][column] -= factor * augmented[pivot][column] }
            }
        }
        return augmented.map { $0[count] }
    }
}

enum ProbeMath {
    static func fixationAggregate(
        target: CGPoint,
        points: [CGPoint],
        distances: [Double],
        leftDirections: [SIMD3<Double>],
        rightDirections: [SIMD3<Double>],
        lookAtPoints: [SIMD2<Double>],
        viewport: CGSize
    ) -> FixationAggregate? {
        guard points.count >= 15 else { return nil }
        let xs = points.map { Double($0.x) }.sorted()
        let ys = points.map { Double($0.y) }.sorted()
        guard let medianX = xs.percentile(0.5), let medianY = ys.percentile(0.5) else { return nil }
        let predictedMedian = CGPoint(x: medianX, y: medianY)

        let deltaX = medianX - Double(target.x)
        let deltaY = medianY - Double(target.y)
        let accuracyPoints = hypot(deltaX * viewport.width, deltaY * viewport.height)
        let precisionPoints = sqrt(points.reduce(0.0) { partial, point in
            let dx = (Double(point.x) - medianX) * viewport.width
            let dy = (Double(point.y) - medianY) * viewport.height
            return partial + dx * dx + dy * dy
        } / Double(points.count))

        let diagonalInches = 12.9
        let diagonalPoints = hypot(viewport.width, viewport.height)
        let widthInches = diagonalInches * viewport.width / diagonalPoints
        let heightInches = diagonalInches * viewport.height / diagonalPoints
        let distanceMeters = distances.sorted().percentile(0.5) ?? 0.45
        let accuracyMeters = hypot(deltaX * widthInches, deltaY * heightInches) * 0.0254
        let precisionMeters = sqrt(points.reduce(0.0) { partial, point in
            let dx = (Double(point.x) - medianX) * widthInches * 0.0254
            let dy = (Double(point.y) - medianY) * heightInches * 0.0254
            return partial + dx * dx + dy * dy
        } / Double(points.count))

        return FixationAggregate(
            region: region(for: target),
            targetNormalized: target,
            predictedMedianNormalized: predictedMedian,
            distanceMeters: distanceMeters,
            accuracyDegrees: atan2(accuracyMeters, distanceMeters) * 180 / .pi,
            precisionDegreesRMS: atan2(precisionMeters, distanceMeters) * 180 / .pi,
            accuracyLogicalPoints: accuracyPoints,
            precisionLogicalPointsRMS: precisionPoints,
            leftEyeAngularStabilityDegreesRMS: angularRMS(leftDirections),
            rightEyeAngularStabilityDegreesRMS: angularRMS(rightDirections),
            lookAtPointStabilityMillimetersRMS: pointRMSMillimeters(lookAtPoints)
        )
    }

    static func movementSummary(
        fixations: [FixationAggregate],
        viewport: CGSize
    ) -> (agreementPercent: Double?, gains: [Double]) {
        guard fixations.count >= 2 else { return (nil, []) }
        var agreements = 0
        var eligible = 0
        var gains: [Double] = []
        for pair in zip(fixations, fixations.dropFirst()) {
            let targetDelta = SIMD2<Double>(
                Double(pair.1.targetNormalized.x - pair.0.targetNormalized.x) * viewport.width,
                Double(pair.1.targetNormalized.y - pair.0.targetNormalized.y) * viewport.height
            )
            let predictedDelta = SIMD2<Double>(
                Double(pair.1.predictedMedianNormalized.x - pair.0.predictedMedianNormalized.x) * viewport.width,
                Double(pair.1.predictedMedianNormalized.y - pair.0.predictedMedianNormalized.y) * viewport.height
            )
            let targetLength = simd_length(targetDelta)
            let predictedLength = simd_length(predictedDelta)
            guard targetLength > 1, predictedLength > 1 else { continue }
            eligible += 1
            let cosine = simd_dot(targetDelta, predictedDelta) / (targetLength * predictedLength)
            if cosine >= 0.5 { agreements += 1 }
            gains.append(predictedLength / targetLength)
        }
        let percent = eligible == 0 ? nil : Double(agreements) / Double(eligible) * 100
        return (percent, gains)
    }

    static func rateSummaries(sampleTimes: [TimeInterval]) -> (median: Double?, p10: Double?, sustainedMinimum: Double?) {
        guard let first = sampleTimes.first, let last = sampleTimes.last, last > first else { return (nil, nil, nil) }
        let startSecond = floor(first)
        let endSecond = floor(last)
        let buckets = stride(from: startSecond, through: endSecond, by: 1).map { second in
            Double(sampleTimes.filter { $0 >= second && $0 < second + 1 }.count)
        }.sorted()
        var tenSecondRates: [Double] = []
        var windowStart = first
        while windowStart + 10 <= last {
            let count = sampleTimes.filter { $0 >= windowStart && $0 < windowStart + 10 }.count
            tenSecondRates.append(Double(count) / 10)
            windowStart += 1
        }
        return (buckets.percentile(0.5), buckets.percentile(0.1), tenSecondRates.min())
    }

    private static func region(for target: CGPoint) -> String {
        let nearHorizontalEdge = target.x < 0.15 || target.x > 0.85
        let nearVerticalEdge = target.y < 0.15 || target.y > 0.85
        if nearHorizontalEdge && nearVerticalEdge { return "corner" }
        if nearHorizontalEdge || nearVerticalEdge { return "edge" }
        return "center"
    }

    private static func angularRMS(_ vectors: [SIMD3<Double>]) -> Double {
        guard !vectors.isEmpty else { return .nan }
        let sum = vectors.reduce(SIMD3<Double>(repeating: 0), +)
        guard simd_length(sum) > 1e-9 else { return .nan }
        let mean = simd_normalize(sum)
        let squares = vectors.map { vector -> Double in
            let normalized = simd_normalize(vector)
            let radians = acos(min(max(simd_dot(normalized, mean), -1), 1))
            let degrees = radians * 180 / .pi
            return degrees * degrees
        }
        return sqrt(squares.reduce(0, +) / Double(squares.count))
    }

    private static func pointRMSMillimeters(_ points: [SIMD2<Double>]) -> Double {
        guard !points.isEmpty else { return .nan }
        let mean = points.reduce(SIMD2<Double>(repeating: 0), +) / Double(points.count)
        let squareMeters = points.reduce(0.0) { partial, point in
            let delta = point - mean
            return partial + simd_dot(delta, delta)
        } / Double(points.count)
        return sqrt(squareMeters) * 1_000
    }
}
