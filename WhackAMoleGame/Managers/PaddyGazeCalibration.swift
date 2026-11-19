import DrStrangeGazeTracker
import Foundation

struct GazeCoordinate: Equatable, Sendable {
    let x: Double
    let y: Double
}

struct GazeCalibrationSample: Equatable, Sendable {
    let raw: GazeCoordinate
    let target: NormalizedGazePoint
}

enum GazeCalibrationError: Error, Equatable {
    case insufficientSamples
    case singularSystem
}

struct AffineGazeCalibration: Equatable, Sendable {
    private let xCoefficients: [Double]
    private let yCoefficients: [Double]

    static func fit(
        samples: [GazeCalibrationSample],
        ridge: Double = 1e-8
    ) throws -> AffineGazeCalibration {
        guard samples.count >= 3 else { throw GazeCalibrationError.insufficientSamples }

        var normal = Array(repeating: Array(repeating: 0.0, count: 3), count: 3)
        var targetX = Array(repeating: 0.0, count: 3)
        var targetY = Array(repeating: 0.0, count: 3)

        for sample in samples {
            let row = [1.0, sample.raw.x, sample.raw.y]
            for column in 0..<3 {
                targetX[column] += row[column] * sample.target.x
                targetY[column] += row[column] * sample.target.y
                for otherColumn in 0..<3 {
                    normal[column][otherColumn] += row[column] * row[otherColumn]
                }
            }
        }
        normal[1][1] += ridge
        normal[2][2] += ridge

        guard let xCoefficients = solve(normal, targetX),
              let yCoefficients = solve(normal, targetY)
        else { throw GazeCalibrationError.singularSystem }

        return AffineGazeCalibration(
            xCoefficients: xCoefficients,
            yCoefficients: yCoefficients
        )
    }

    func predict(_ raw: GazeCoordinate) -> GazeCoordinate {
        let row = [1.0, raw.x, raw.y]
        return GazeCoordinate(
            x: zip(xCoefficients, row).map(*).reduce(0, +),
            y: zip(yCoefficients, row).map(*).reduce(0, +)
        )
    }

    private static func solve(_ matrix: [[Double]], _ vector: [Double]) -> [Double]? {
        var augmented = zip(matrix, vector).map { row, value in row + [value] }
        let count = vector.count

        for pivotColumn in 0..<count {
            guard let pivotRow = (pivotColumn..<count).max(by: {
                abs(augmented[$0][pivotColumn]) < abs(augmented[$1][pivotColumn])
            }), abs(augmented[pivotRow][pivotColumn]) > 1e-12 else { return nil }

            if pivotRow != pivotColumn {
                augmented.swapAt(pivotRow, pivotColumn)
            }

            let pivot = augmented[pivotColumn][pivotColumn]
            for column in pivotColumn...count {
                augmented[pivotColumn][column] /= pivot
            }

            for row in 0..<count where row != pivotColumn {
                let scale = augmented[row][pivotColumn]
                for column in pivotColumn...count {
                    augmented[row][column] -= scale * augmented[pivotColumn][column]
                }
            }
        }

        return augmented.map { $0[count] }
    }
}

enum PersonalizedGazeMappingKind: String, Equatable, Sendable {
    case affine
    case quadratic
}

/// Selects a regularized personalized mapping using leave-one-target-out error.
/// The quadratic candidate can correct smooth landscape/device bias, but is
/// accepted only when it materially outperforms the simpler affine mapping.
struct PersonalizedGazeCalibration: Equatable, Sendable {
    let kind: PersonalizedGazeMappingKind

    private let center: GazeCoordinate
    private let scale: GazeCoordinate
    private let xCoefficients: [Double]
    private let yCoefficients: [Double]

    static func fit(samples: [GazeCalibrationSample]) throws -> PersonalizedGazeCalibration {
        guard samples.count >= 6 else { throw GazeCalibrationError.insufficientSamples }
        let affineError = leaveOneOutP90(samples: samples, kind: .affine)
        let quadraticError = leaveOneOutP90(samples: samples, kind: .quadratic)
        let selected: PersonalizedGazeMappingKind = quadraticError < affineError * 0.90
            ? .quadratic
            : .affine
        guard let result = fitModel(samples: samples, kind: selected) else {
            throw GazeCalibrationError.singularSystem
        }
        return result
    }

    func predict(_ raw: GazeCoordinate) -> GazeCoordinate {
        let normalized = GazeCoordinate(
            x: (raw.x - center.x) / scale.x,
            y: (raw.y - center.y) / scale.y
        )
        let row = Self.features(for: normalized, kind: kind)
        return GazeCoordinate(
            x: zip(xCoefficients, row).map(*).reduce(0, +),
            y: zip(yCoefficients, row).map(*).reduce(0, +)
        )
    }

    private static func fitModel(
        samples: [GazeCalibrationSample],
        kind: PersonalizedGazeMappingKind
    ) -> PersonalizedGazeCalibration? {
        let width = kind == .affine ? 3 : 6
        guard samples.count >= width else { return nil }
        let center = GazeCoordinate(
            x: samples.map(\.raw.x).reduce(0, +) / Double(samples.count),
            y: samples.map(\.raw.y).reduce(0, +) / Double(samples.count)
        )
        let scale = GazeCoordinate(
            x: max(rootMeanSquare(samples.map { $0.raw.x - center.x }), 1e-6),
            y: max(rootMeanSquare(samples.map { $0.raw.y - center.y }), 1e-6)
        )
        let rows = samples.map { sample in
            features(
                for: GazeCoordinate(
                    x: (sample.raw.x - center.x) / scale.x,
                    y: (sample.raw.y - center.y) / scale.y
                ),
                kind: kind
            )
        }
        var weights = Array(repeating: 1.0, count: samples.count)
        var solution: (x: [Double], y: [Double])?
        for _ in 0..<4 {
            guard let candidate = weightedFit(
                rows: rows,
                samples: samples,
                weights: weights,
                ridge: kind == .affine ? 0.001 : 0.03
            ) else { return nil }
            solution = candidate
            let residuals = zip(rows, samples).map { row, sample in
                hypot(
                    dot(candidate.x, row) - sample.target.x,
                    dot(candidate.y, row) - sample.target.y
                )
            }
            let robustScale = max(percentile(residuals.sorted(), fraction: 0.5), 1e-5)
            let threshold = 1.5 * robustScale
            weights = residuals.map { $0 <= threshold ? 1 : threshold / $0 }
        }
        guard let solution else { return nil }
        return PersonalizedGazeCalibration(
            kind: kind,
            center: center,
            scale: scale,
            xCoefficients: solution.x,
            yCoefficients: solution.y
        )
    }

    private static func leaveOneOutP90(
        samples: [GazeCalibrationSample],
        kind: PersonalizedGazeMappingKind
    ) -> Double {
        guard samples.count >= 7 else { return .infinity }
        var errors: [Double] = []
        for index in samples.indices {
            var training = samples
            let heldOut = training.remove(at: index)
            guard let model = fitModel(samples: training, kind: kind) else { return .infinity }
            let prediction = model.predict(heldOut.raw)
            errors.append(hypot(prediction.x - heldOut.target.x, prediction.y - heldOut.target.y))
        }
        return percentile(errors.sorted(), fraction: 0.9)
    }

    private static func features(
        for point: GazeCoordinate,
        kind: PersonalizedGazeMappingKind
    ) -> [Double] {
        switch kind {
        case .affine:
            return [1, point.x, point.y]
        case .quadratic:
            return [1, point.x, point.y, point.x * point.x, point.y * point.y, point.x * point.y]
        }
    }

    private static func weightedFit(
        rows: [[Double]],
        samples: [GazeCalibrationSample],
        weights: [Double],
        ridge: Double
    ) -> (x: [Double], y: [Double])? {
        guard let width = rows.first?.count else { return nil }
        var normal = Array(repeating: Array(repeating: 0.0, count: width), count: width)
        var targetX = Array(repeating: 0.0, count: width)
        var targetY = Array(repeating: 0.0, count: width)
        for index in rows.indices {
            let row = rows[index]
            let weight = weights[index]
            for column in 0..<width {
                targetX[column] += weight * row[column] * samples[index].target.x
                targetY[column] += weight * row[column] * samples[index].target.y
                for other in 0..<width {
                    normal[column][other] += weight * row[column] * row[other]
                }
            }
        }
        for index in 1..<width { normal[index][index] += ridge }
        guard let x = solve(normal, targetX), let y = solve(normal, targetY) else { return nil }
        return (x, y)
    }

    private static func solve(_ matrix: [[Double]], _ vector: [Double]) -> [Double]? {
        var augmented = zip(matrix, vector).map { row, value in row + [value] }
        for pivotColumn in vector.indices {
            guard let pivotRow = (pivotColumn..<vector.count).max(by: {
                abs(augmented[$0][pivotColumn]) < abs(augmented[$1][pivotColumn])
            }), abs(augmented[pivotRow][pivotColumn]) > 1e-12 else { return nil }
            augmented.swapAt(pivotColumn, pivotRow)
            let pivot = augmented[pivotColumn][pivotColumn]
            for column in pivotColumn...vector.count { augmented[pivotColumn][column] /= pivot }
            for row in vector.indices where row != pivotColumn {
                let factor = augmented[row][pivotColumn]
                for column in pivotColumn...vector.count {
                    augmented[row][column] -= factor * augmented[pivotColumn][column]
                }
            }
        }
        return augmented.map { $0[vector.count] }
    }

    private static func dot(_ coefficients: [Double], _ values: [Double]) -> Double {
        zip(coefficients, values).map(*).reduce(0, +)
    }

    private static func rootMeanSquare(_ values: [Double]) -> Double {
        sqrt(values.map { $0 * $0 }.reduce(0, +) / Double(values.count))
    }

    private static func percentile(_ sorted: [Double], fraction: Double) -> Double {
        guard sorted.count > 1 else { return sorted.first ?? .infinity }
        let position = fraction * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        let weight = position - Double(lower)
        return sorted[lower] * (1 - weight) + sorted[upper] * weight
    }
}

/// Adaptive low-pass filtering for the visible cursor. Slow fixation jitter is
/// smoothed strongly while fast intentional motion remains responsive.
struct OneEuroGazeFilter: Sendable {
    private var x = ScalarOneEuroFilter()
    private var y = ScalarOneEuroFilter()
    private var lastTimestamp: TimeInterval?
    private var lastOutput: GazeCoordinate?
    private let deadZone = 0.012

    mutating func filter(_ point: GazeCoordinate, timestamp: TimeInterval) -> GazeCoordinate {
        if let lastTimestamp, timestamp - lastTimestamp > 0.5 { reset() }
        self.lastTimestamp = timestamp
        let smoothed = GazeCoordinate(
            x: x.filter(point.x, timestamp: timestamp),
            y: y.filter(point.y, timestamp: timestamp)
        )
        guard let lastOutput else {
            self.lastOutput = smoothed
            return smoothed
        }
        let deltaX = smoothed.x - lastOutput.x
        let deltaY = smoothed.y - lastOutput.y
        let distance = hypot(deltaX, deltaY)
        guard distance > deadZone else { return lastOutput }
        let movementFraction = (distance - deadZone) / distance
        let stabilized = GazeCoordinate(
            x: lastOutput.x + deltaX * movementFraction,
            y: lastOutput.y + deltaY * movementFraction
        )
        self.lastOutput = stabilized
        return stabilized
    }

    mutating func reset() {
        x.reset()
        y.reset()
        lastTimestamp = nil
        lastOutput = nil
    }
}

private struct ScalarOneEuroFilter: Sendable {
    private let minimumCutoff = 0.6
    private let beta = 0.02
    private let derivativeCutoff = 1.0
    private var previousRaw: Double?
    private var previousFiltered: Double?
    private var previousDerivative = 0.0
    private var previousTimestamp: TimeInterval?

    mutating func filter(_ value: Double, timestamp: TimeInterval) -> Double {
        guard let previousRaw, let previousFiltered, let previousTimestamp,
              timestamp > previousTimestamp else {
            self.previousRaw = value
            self.previousFiltered = value
            self.previousTimestamp = timestamp
            return value
        }
        let delta = timestamp - previousTimestamp
        let derivative = (value - previousRaw) / delta
        let filteredDerivative = lowPass(
            derivative,
            previous: previousDerivative,
            alpha: Self.alpha(cutoff: derivativeCutoff, delta: delta)
        )
        let cutoff = minimumCutoff + beta * abs(filteredDerivative)
        let filtered = lowPass(
            value,
            previous: previousFiltered,
            alpha: Self.alpha(cutoff: cutoff, delta: delta)
        )
        self.previousRaw = value
        self.previousFiltered = filtered
        self.previousDerivative = filteredDerivative
        self.previousTimestamp = timestamp
        return filtered
    }

    mutating func reset() {
        previousRaw = nil
        previousFiltered = nil
        previousDerivative = 0
        previousTimestamp = nil
    }

    private func lowPass(_ value: Double, previous: Double, alpha: Double) -> Double {
        alpha * value + (1 - alpha) * previous
    }

    private static func alpha(cutoff: Double, delta: TimeInterval) -> Double {
        let timeConstant = 1 / (2 * Double.pi * cutoff)
        return 1 / (1 + timeConstant / delta)
    }
}

struct GazeValidationObservation: Equatable, Sendable {
    let prediction: GazeCoordinate
    let target: NormalizedGazePoint
}

struct GazeValidationMetrics: Equatable, Sendable {
    let expectedTargetCount: Int
    let observedTargetCount: Int
    let meanErrorCM: Double
    let medianErrorCM: Double
    let p90ErrorCM: Double
    let meanNormalizedError: Double

    var trackingCoverage: Double {
        guard expectedTargetCount > 0 else { return 0 }
        return Double(observedTargetCount) / Double(expectedTargetCount)
    }

    static func calculate(
        observations: [GazeValidationObservation],
        expectedTargetCount: Int,
        screenWidthCM: Double,
        screenHeightCM: Double
    ) -> GazeValidationMetrics? {
        guard !observations.isEmpty else { return nil }
        let normalizedErrors = observations.map { observation in
            hypot(
                observation.prediction.x - observation.target.x,
                observation.prediction.y - observation.target.y
            )
        }
        let centimeterErrors = observations.map { observation in
            hypot(
                (observation.prediction.x - observation.target.x) * screenWidthCM,
                (observation.prediction.y - observation.target.y) * screenHeightCM
            )
        }.sorted()

        return GazeValidationMetrics(
            expectedTargetCount: expectedTargetCount,
            observedTargetCount: observations.count,
            meanErrorCM: centimeterErrors.reduce(0, +) / Double(centimeterErrors.count),
            medianErrorCM: percentile(centimeterErrors, fraction: 0.5),
            p90ErrorCM: percentile(centimeterErrors, fraction: 0.9),
            meanNormalizedError: normalizedErrors.reduce(0, +) / Double(normalizedErrors.count)
        )
    }

    private static func percentile(_ sortedValues: [Double], fraction: Double) -> Double {
        guard sortedValues.count > 1 else { return sortedValues[0] }
        let position = fraction * Double(sortedValues.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        let weight = position - Double(lower)
        return sortedValues[lower] * (1 - weight) + sortedValues[upper] * weight
    }
}
