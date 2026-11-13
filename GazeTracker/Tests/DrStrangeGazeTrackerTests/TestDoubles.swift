import Foundation
@_spi(Platform) @testable import DrStrangeGazeTracker

final class TestClock: UptimeClock {
    var value: UInt64

    init(_ value: UInt64 = 1_000) {
        self.value = value
    }

    func nowNanoseconds() -> UInt64 { value }
}

final class TestRuntime: ObservationRuntime {
    weak var delegate: ObservationRuntimeDelegate?
    var support = GazeSupport(isSupported: true, cameraAuthorization: .authorized)
    private(set) var startResetArguments: [Bool] = []
    private(set) var pauseCount = 0
    private(set) var stopCount = 0

    func checkSupport() -> GazeSupport { support }

    func start(reset: Bool) async throws {
        startResetArguments.append(reset)
    }

    func pause() { pauseCount += 1 }
    func stop() { stopCount += 1 }

    func emit(
        timestamp: UInt64,
        trackingState: TrackingState = .limited,
        setupState: SetupState = .unknown,
        eyeAvailability: EyeAvailability = .rightOnly,
        selectedEyeRay: SelectedEyeRayObservation? = nil
    ) {
        delegate?.observationRuntime(
            self,
            didProduce: InternalObservationState(
                sourceTimestampNanoseconds: timestamp,
                trackingState: trackingState,
                setupState: setupState,
                eyeAvailability: eyeAvailability,
                selectedEyeRay: selectedEyeRay
            )
        )
    }
}

final class SampleRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [GazeSample] = []

    func append(_ sample: GazeSample) {
        lock.lock()
        storage.append(sample)
        lock.unlock()
    }

    var samples: [GazeSample] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var last: GazeSample? { samples.last }
}

func makeTracker(
    runtime: TestRuntime = TestRuntime(),
    clock: TestClock = TestClock()
) -> (GazeTracker, TestRuntime, TestClock, SampleRecorder) {
    let tracker = GazeTracker(runtime: runtime, clock: clock)
    let recorder = SampleRecorder()
    tracker.setSampleHandler { recorder.append($0) }
    return (tracker, runtime, clock, recorder)
}
