import Foundation

/// Interaction-only One Euro smoothing. Calibration always consumes the raw
/// `paddy-gazeTrack` output before this filter is applied.
struct GazePointSmoother {
    static let minimumCutoff = 0.6
    static let speedCoefficient = 0.02
    static let derivativeCutoff = 1.0
    static let deadZone = 0.012
    static let resetGapNanoseconds: UInt64 = 500_000_000

    private var filter = OneEuroGazeFilter()
    private var lastUsableTimestampNanoseconds: UInt64?

    mutating func consume(
        point rawPoint: CGPoint?,
        timestampNanoseconds: UInt64,
        isUsable: Bool
    ) -> CGPoint? {
        guard isUsable,
              let rawPoint,
              rawPoint.x.isFinite,
              rawPoint.y.isFinite else {
            if let lastUsableTimestampNanoseconds,
               timestampNanoseconds > lastUsableTimestampNanoseconds,
               timestampNanoseconds - lastUsableTimestampNanoseconds > Self.resetGapNanoseconds {
                reset()
            }
            return nil
        }
        if let lastUsableTimestampNanoseconds {
            guard timestampNanoseconds > lastUsableTimestampNanoseconds else { return nil }
            if timestampNanoseconds - lastUsableTimestampNanoseconds > Self.resetGapNanoseconds {
                reset()
            }
        }
        lastUsableTimestampNanoseconds = timestampNanoseconds
        let filtered = filter.filter(
            GazeCoordinate(x: rawPoint.x, y: rawPoint.y),
            timestamp: TimeInterval(timestampNanoseconds) / 1_000_000_000
        )
        return CGPoint(x: filtered.x, y: filtered.y)
    }

    mutating func reset() {
        filter.reset()
        lastUsableTimestampNanoseconds = nil
    }
}
