struct CalibrationSampleGate {
    struct Decision: Equatable {
        let shouldConsume: Bool
        let isCurrentTargetResult: Bool
    }

    private var latestTimestampNanoseconds: UInt64?
    private var targetStartedAtNanoseconds: UInt64?
    private var targetResultConsumed = true

    mutating func markTargetStarted(at timestampNanoseconds: UInt64) {
        targetStartedAtNanoseconds = timestampNanoseconds
        targetResultConsumed = false
    }

    mutating func evaluate(
        timestampNanoseconds: UInt64,
        isTargetResult: Bool
    ) -> Decision {
        if let latestTimestampNanoseconds,
           timestampNanoseconds <= latestTimestampNanoseconds {
            return Decision(shouldConsume: false, isCurrentTargetResult: false)
        }

        latestTimestampNanoseconds = timestampNanoseconds
        let isCurrentTargetResult = isTargetResult &&
            !targetResultConsumed &&
            targetStartedAtNanoseconds.map { timestampNanoseconds >= $0 } == true
        if isCurrentTargetResult {
            targetResultConsumed = true
        }
        return Decision(
            shouldConsume: true,
            isCurrentTargetResult: isCurrentTargetResult
        )
    }
}
