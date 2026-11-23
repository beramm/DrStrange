import DrStrangeGazeTracker
import Foundation

/// The target order and raw sample reduction used by the live calibration loop.
enum PaddyCalibrationCapture {
    static let targetTransitionSeconds: TimeInterval = 0.35

    static let targets: [NormalizedGazePoint] = [
        (0.08, 0.08), (0.29, 0.08), (0.50, 0.08), (0.71, 0.08), (0.92, 0.08),
        (0.92, 0.50),
        (0.92, 0.92), (0.71, 0.92), (0.50, 0.92), (0.29, 0.92), (0.08, 0.92),
        (0.08, 0.50), (0.50, 0.50)
    ].compactMap { NormalizedGazePoint(x: $0.0, y: $0.1) }

    static let minimumSamples = 6

    static func hasCompleteWindow(
        elapsed: TimeInterval,
        stableDuration: TimeInterval,
        sampleCount: Int
    ) -> Bool {
        elapsed >= 0.70 && stableDuration >= 0.70 && sampleCount >= minimumSamples
    }

    static func reduce(_ samples: [GazeCoordinate]) -> GazeCoordinate? {
        guard samples.count >= minimumSamples,
              samples.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        let initial = GazeCoordinate(
            x: median(samples.map(\.x).sorted()),
            y: median(samples.map(\.y).sorted())
        )
        let distances = samples.map { hypot($0.x - initial.x, $0.y - initial.y) }
        let medianDistance = median(distances.sorted())
        let mad = median(distances.map { abs($0 - medianDistance) }.sorted())
        let cutoff = medianDistance + 3 * max(mad, 0.02)
        let inliers = zip(samples, distances).compactMap { sample, distance in
            distance <= cutoff ? sample : nil
        }
        guard inliers.count >= minimumSamples else { return nil }
        return GazeCoordinate(
            x: median(inliers.map(\.x).sorted()),
            y: median(inliers.map(\.y).sorted())
        )
    }

    static func fitComplete(_ samples: [GazeCalibrationSample]) throws -> PersonalizedGazeCalibration {
        guard samples.count == targets.count,
              zip(samples, targets).allSatisfy({ pair in pair.0.target == pair.1 }) else {
            throw GazeCalibrationError.insufficientSamples
        }
        return try PersonalizedGazeCalibration.fit(samples: samples)
    }

    private static func median(_ sorted: [Double]) -> Double {
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }
}
