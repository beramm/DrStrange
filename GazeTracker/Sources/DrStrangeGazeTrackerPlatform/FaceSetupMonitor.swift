@_spi(Platform) import DrStrangeGazeTracker
import Foundation
import simd

/// Converts volatile face pose into actionable setup guidance. A posture must
/// remain inside the acceptable zone before it becomes ready, so calibration
/// never starts collecting on the first coincidentally valid frame.
struct FaceSetupMonitor {
    private struct Sample {
        let timestamp: TimeInterval
        let translation: SIMD3<Double>
        let direction: SIMD3<Double>
    }

    private var samples: [Sample] = []
    private var isRecoveringFromExcessiveMovement = false

    // Keep the child in a near-camera sweet spot. Forty centimetres is the
    // hard near edge; the narrow ten-centimetre ready band encourages them to
    // stay close enough for strong eye geometry without hovering directly on
    // the "too close" boundary.
    private let minimumDistanceMeters = 0.40
    private let maximumDistanceMeters = 0.50
    // The live setup check is intentionally forgiving for children. The
    // calibration collector applies its stricter stability gate to the actual
    // samples after this preflight passes.
    private let maximumFaceAngleDegrees = 25.0
    private let stabilizationDurationSeconds = 0.35
    private let maximumTranslationRangeMeters = 0.030
    private let maximumDirectionRangeDegrees = 6.0

    mutating func evaluate(
        timestamp: TimeInterval,
        faceTranslation: SIMD3<Double>,
        headDirection: SIMD3<Double>
    ) -> SetupState {
        let baseState = staticState(
            faceTranslation: faceTranslation,
            headDirection: headDirection
        )
        guard baseState == .ready, timestamp.isFinite else {
            reset()
            return baseState
        }

        let direction = Self.directionFacingCamera(
            headDirection: headDirection,
            faceTranslation: faceTranslation
        )
        if let last = samples.last, timestamp < last.timestamp { reset() }
        samples.append(Sample(
            timestamp: timestamp,
            translation: faceTranslation,
            direction: direction
        ))

        // Keep one rolling stabilization window instead of retaining face pose
        // for the lifetime of a game session.
        let cutoff = timestamp - stabilizationDurationSeconds
        while samples.count > 2, samples[1].timestamp <= cutoff {
            samples.removeFirst()
        }

        guard let first = samples.first else { return .stabilizing }
        let translationRange = samples
            .map { simd_distance(first.translation, $0.translation) }
            .max() ?? 0
        let directionRange = Self.directionDispersionDegrees(samples.map(\.direction))
        guard translationRange <= maximumTranslationRangeMeters,
              directionRange <= maximumDirectionRangeDegrees else {
            samples = [samples[samples.count - 1]]
            isRecoveringFromExcessiveMovement = true
            return .movingTooMuch
        }

        guard timestamp - first.timestamp >= stabilizationDurationSeconds else {
            return isRecoveringFromExcessiveMovement ? .movingTooMuch : .stabilizing
        }
        isRecoveringFromExcessiveMovement = false
        return .ready
    }

    mutating func reset() {
        samples.removeAll(keepingCapacity: true)
        isRecoveringFromExcessiveMovement = false
    }

    private func staticState(
        faceTranslation: SIMD3<Double>,
        headDirection: SIMD3<Double>
    ) -> SetupState {
        guard faceTranslation.allFinite,
              headDirection.allFinite,
              simd_length(headDirection) > 1e-9 else {
            return .unknown
        }
        let facePositionReady = abs(faceTranslation.x) <= 0.18 &&
            faceTranslation.y >= -0.25 && faceTranslation.y <= 0.12
        guard facePositionReady else { return .unknown }

        let distance = simd_length(faceTranslation)
        if distance < minimumDistanceMeters { return .tooClose }
        if distance > maximumDistanceMeters { return .tooFar }

        let cameraFacingDirection = simd_normalize(-faceTranslation)
        let direction = Self.directionFacingCamera(
            headDirection: headDirection,
            faceTranslation: faceTranslation
        )
        let angle = Self.angleDegrees(direction, cameraFacingDirection)
        guard angle <= maximumFaceAngleDegrees else {
            let verticalError = direction.y - cameraFacingDirection.y
            let horizontalError = direction.x - cameraFacingDirection.x
            if abs(verticalError) >= abs(horizontalError) {
                // The nose points above/below the camera, so guide it back in
                // the opposite direction.
                return verticalError > 0 ? .lookDown : .lookUp
            }
            return horizontalError > 0 ? .turnLeft : .turnRight
        }
        return .ready
    }

    /// ARKit axis sign can vary with the face-anchor convention. Orient the
    /// axis toward the physical camera, then compare it with the actual
    /// face-to-camera line instead of an imaginary face at the screen centre.
    private static func directionFacingCamera(
        headDirection: SIMD3<Double>,
        faceTranslation: SIMD3<Double>
    ) -> SIMD3<Double> {
        let cameraDirection = simd_normalize(-faceTranslation)
        let normalized = simd_normalize(headDirection)
        return simd_dot(normalized, cameraDirection) < 0 ? -normalized : normalized
    }

    private static func directionDispersionDegrees(_ directions: [SIMD3<Double>]) -> Double {
        guard !directions.isEmpty else { return .infinity }
        let sum = directions.reduce(SIMD3<Double>(repeating: 0), +)
        guard simd_length(sum) > 1e-9 else { return .infinity }
        let centre = simd_normalize(sum)
        return directions.map { angleDegrees($0, centre) }.max() ?? .infinity
    }

    private static func angleDegrees(_ lhs: SIMD3<Double>, _ rhs: SIMD3<Double>) -> Double {
        acos(min(max(simd_dot(lhs, rhs), -1), 1)) * 180 / .pi
    }
}

private extension SIMD3 where Scalar == Double {
    var allFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}
