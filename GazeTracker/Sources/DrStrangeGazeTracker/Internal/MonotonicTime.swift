import Foundation

protocol UptimeClock: AnyObject {
    func nowNanoseconds() -> UInt64
}

final class SystemUptimeClock: UptimeClock {
    func nowNanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }
}

final class MonotonicSequencer {
    private var last: UInt64

    init(initial: UInt64 = 0) {
        last = initial
    }

    func next(candidate: UInt64) -> MonotonicTimestamp {
        let value = candidate > last ? candidate : last &+ 1
        last = value
        return MonotonicTimestamp(uptimeNanoseconds: value)
    }
}
