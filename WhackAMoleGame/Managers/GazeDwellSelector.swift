import Foundation

/// Converts a continuous gaze-over-hole signal into one deliberate activation.
/// This is interaction assistance, not tracker smoothing or an accuracy metric.
struct GazeDwellSelector {
    static let defaultDwellNanoseconds: UInt64 = 600_000_000

    private let dwellNanoseconds: UInt64
    private var focusedHole: Int?
    private var focusStartedAt: UInt64?
    private var latchedHole: Int?

    init(dwellNanoseconds: UInt64 = Self.defaultDwellNanoseconds) {
        self.dwellNanoseconds = dwellNanoseconds
    }

    mutating func consume(
        candidateHole: Int?,
        timestampNanoseconds: UInt64,
        isUsable: Bool
    ) -> Int? {
        guard isUsable, let candidateHole else {
            clearFocus()
            latchedHole = nil
            return nil
        }

        if latchedHole == candidateHole { return nil }
        if latchedHole != nil { latchedHole = nil }

        guard focusedHole == candidateHole, let focusStartedAt else {
            focusedHole = candidateHole
            self.focusStartedAt = timestampNanoseconds
            return nil
        }

        guard timestampNanoseconds >= focusStartedAt,
              timestampNanoseconds - focusStartedAt >= dwellNanoseconds else {
            return nil
        }

        latchedHole = candidateHole
        clearFocus()
        return candidateHole
    }

    mutating func reset() {
        clearFocus()
        latchedHole = nil
    }

    private mutating func clearFocus() {
        focusedHole = nil
        focusStartedAt = nil
    }
}
