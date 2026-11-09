import Foundation

enum PatchWearState: Equatable {
    case checking
    case verified
    case missing
}

enum PatchEyeObservation: Equatable {
    case bothEyes
    case expectedEyeOnly
    case otherEyeOnly
    case unavailable
}

/// Debounces live eye visibility so a blink or one bad camera frame cannot pass or pause play.
struct PatchWearMonitor {
    static let defaultVerificationDuration: UInt64 = 1_500_000_000
    static let defaultRemovalDuration: UInt64 = 1_000_000_000

    private let verificationDuration: UInt64
    private let removalDuration: UInt64
    private var expectedEyeSince: UInt64?
    private var bothEyesSince: UInt64?
    private var lastTimestamp: UInt64?

    private(set) var state: PatchWearState = .checking

    init(
        verificationDuration: UInt64 = Self.defaultVerificationDuration,
        removalDuration: UInt64 = Self.defaultRemovalDuration
    ) {
        self.verificationDuration = verificationDuration
        self.removalDuration = removalDuration
    }

    @discardableResult
    mutating func consume(
        _ observation: PatchEyeObservation,
        timestampNanoseconds timestamp: UInt64
    ) -> PatchWearState {
        if let lastTimestamp, timestamp < lastTimestamp {
            expectedEyeSince = nil
            bothEyesSince = nil
        }
        lastTimestamp = timestamp

        switch observation {
        case .expectedEyeOnly:
            bothEyesSince = nil
            if state == .missing { state = .checking }
            if expectedEyeSince == nil { expectedEyeSince = timestamp }
            if elapsed(since: expectedEyeSince, at: timestamp) >= verificationDuration {
                state = .verified
            }

        case .bothEyes:
            expectedEyeSince = nil
            if bothEyesSince == nil { bothEyesSince = timestamp }
            if elapsed(since: bothEyesSince, at: timestamp) >= removalDuration {
                state = .missing
            }

        case .otherEyeOnly, .unavailable:
            expectedEyeSince = nil
            bothEyesSince = nil
        }

        return state
    }

    mutating func reset() {
        expectedEyeSince = nil
        bothEyesSince = nil
        lastTimestamp = nil
        state = .checking
    }

    private func elapsed(since start: UInt64?, at timestamp: UInt64) -> UInt64 {
        guard let start, timestamp >= start else { return 0 }
        return timestamp - start
    }
}
