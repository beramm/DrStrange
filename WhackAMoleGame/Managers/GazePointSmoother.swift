import Foundation

/// Interaction-only gaze smoothing. Raw tracker output and validation metrics remain unchanged.
struct GazePointSmoother {
    static let defaultStableTimeConstant = 0.11
    static let defaultMovingTimeConstant = 0.025
    static let defaultFullSpeedDistance = 0.12
    static let defaultResetGapNanoseconds: UInt64 = 250_000_000

    private let stableTimeConstant: Double
    private let movingTimeConstant: Double
    private let fullSpeedDistance: Double
    private let resetGapNanoseconds: UInt64

    private var filteredPoint: CGPoint?
    private var lastTimestampNanoseconds: UInt64?

    init(
        stableTimeConstant: Double = Self.defaultStableTimeConstant,
        movingTimeConstant: Double = Self.defaultMovingTimeConstant,
        fullSpeedDistance: Double = Self.defaultFullSpeedDistance,
        resetGapNanoseconds: UInt64 = Self.defaultResetGapNanoseconds
    ) {
        self.stableTimeConstant = stableTimeConstant
        self.movingTimeConstant = movingTimeConstant
        self.fullSpeedDistance = fullSpeedDistance
        self.resetGapNanoseconds = resetGapNanoseconds
    }

    mutating func consume(
        point rawPoint: CGPoint?,
        timestampNanoseconds: UInt64,
        isUsable: Bool
    ) -> CGPoint? {
        guard isUsable,
              let rawPoint,
              rawPoint.x.isFinite,
              rawPoint.y.isFinite else {
            reset()
            return nil
        }

        guard let previous = filteredPoint,
              let previousTimestamp = lastTimestampNanoseconds,
              timestampNanoseconds > previousTimestamp else {
            return begin(at: rawPoint, timestampNanoseconds: timestampNanoseconds)
        }

        let elapsedNanoseconds = timestampNanoseconds - previousTimestamp
        guard elapsedNanoseconds <= resetGapNanoseconds else {
            return begin(at: rawPoint, timestampNanoseconds: timestampNanoseconds)
        }

        let elapsedSeconds = Double(elapsedNanoseconds) / 1_000_000_000
        let distance = hypot(rawPoint.x - previous.x, rawPoint.y - previous.y)
        let movement = min(max(Double(distance) / max(fullSpeedDistance, .leastNonzeroMagnitude), 0), 1)
        let easedMovement = movement * movement * (3 - 2 * movement)
        let timeConstant = stableTimeConstant
            + (movingTimeConstant - stableTimeConstant) * easedMovement
        let alpha = 1 - exp(-elapsedSeconds / max(timeConstant, .leastNonzeroMagnitude))
        let next = CGPoint(
            x: previous.x + (rawPoint.x - previous.x) * alpha,
            y: previous.y + (rawPoint.y - previous.y) * alpha
        )

        filteredPoint = next
        lastTimestampNanoseconds = timestampNanoseconds
        return next
    }

    mutating func reset() {
        filteredPoint = nil
        lastTimestampNanoseconds = nil
    }

    private mutating func begin(at point: CGPoint, timestampNanoseconds: UInt64) -> CGPoint {
        filteredPoint = point
        lastTimestampNanoseconds = timestampNanoseconds
        return point
    }
}
