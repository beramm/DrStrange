import Foundation
import simd

/// Production tracker boundary with a volatile Phase 3 calibration mapping.
///
/// The class retains no camera frame, face geometry, calibration sample, gaze
/// sample history, or gaze path. The latest value exists only in volatile memory.
public final class GazeTracker: GazeTracking, @unchecked Sendable {
    private let lock = NSLock()
    private let runtime: ObservationRuntime
    private let clock: UptimeClock
    private let sequencer: MonotonicSequencer
    private let runtimeBridge = RuntimeBridge()

    private var machine = TrackerStateMachine()
    private var handler: GazeSampleHandler?
    private var sample: GazeSample
    private var calibrationEngine = Phase3CalibrationEngine()
    private var validationSession = Phase3ValidationSession()
    private var lastEyeOrigin: SIMD3<Double>?
    private var faceWasLost = false
    private var oneEyeEnforcementEnabled = true

    @_spi(Platform)
    public convenience init(runtime: ObservationRuntime) {
        self.init(runtime: runtime, clock: SystemUptimeClock())
    }

    init(runtime: ObservationRuntime, clock: UptimeClock) {
        self.runtime = runtime
        self.clock = clock
        let initialNanoseconds = clock.nowNanoseconds()
        sequencer = MonotonicSequencer(initial: initialNanoseconds)
        let timestamp = MonotonicTimestamp(uptimeNanoseconds: initialNanoseconds)
        sample = GazeSample(
            pointNormalized: nil,
            timestamp: timestamp,
            quality: .unavailable,
            trackingState: .paused,
            setupState: .unknown,
            calibrationState: .notCalibrated,
            eyeAvailability: .none
        )
        runtimeBridge.owner = self
        runtime.delegate = runtimeBridge
    }

    deinit {
        runtime.stop()
    }

    public func checkSupport() -> GazeSupport {
        runtime.checkSupport()
    }

    public func setSampleHandler(_ handler: GazeSampleHandler?) {
        let current: GazeSample
        lock.lock()
        self.handler = handler
        current = sample
        lock.unlock()
        handler?(current)
    }

    public func start() async throws {
        let support = runtime.checkSupport()
        do {
            try transitionToStarted(supported: support.isSupported)
        } catch {
            publishState()
            throw error
        }
        do {
            try await runtime.start(reset: true)
            publishState()
        } catch {
            applyStartError(error)
            throw error
        }
    }

    public func pause() throws {
        lock.lock()
        do {
            try machine.pause()
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }
        runtime.pause()
        publishState(setupState: .unknown, eyeAvailability: EyeAvailability.none)
    }

    public func resume() async throws {
        let support = runtime.checkSupport()
        do {
            try transitionToResumed(supported: support.isSupported)
        } catch {
            publishState()
            throw error
        }
        do {
            try await runtime.start(reset: false)
            publishState()
        } catch {
            applyStartError(error)
            throw error
        }
    }

    public func stop() {
        runtime.stop()
        lock.lock()
        machine.stop()
        calibrationEngine.cancel()
        validationSession = Phase3ValidationSession()
        lastEyeOrigin = nil
        faceWasLost = false
        lock.unlock()
        publishState(setupState: .unknown, eyeAvailability: EyeAvailability.none)
    }

    public func beginCalibration() throws {
        try beginCalibration(layout: .ninePosition)
    }

    public func beginCalibration(layout: CalibrationLayout) throws {
        lock.lock()
        do {
            try machine.beginCalibration()
            guard sample.setupState == .ready,
                  sample.eyeAvailability.isSelectedRightEyeAvailable(
                    oneEyeEnforcementEnabled: oneEyeEnforcementEnabled
                  ) else {
                machine.cancelCalibration()
                throw CalibrationContractError.setupNotReady
            }
            calibrationEngine.begin(layout: layout, startedAtNanoseconds: clock.nowNanoseconds())
            validationSession = Phase3ValidationSession()
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }
        publishState()
    }

    public func beginCalibrationTarget(at point: NormalizedGazePoint) throws {
        lock.lock()
        do {
            try calibrationEngine.beginTarget(point)
            try machine.beginCalibrationTarget()
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }
        publishState()
    }

    public func cancelCalibration() {
        lock.lock()
        machine.cancelCalibration()
        calibrationEngine.cancel()
        validationSession = Phase3ValidationSession()
        lock.unlock()
        publishState()
    }

    public func invalidateCalibration(reason: CalibrationInvalidationReason) {
        _ = reason
        lock.lock()
        machine.invalidateCalibration()
        calibrationEngine.invalidate()
        validationSession = Phase3ValidationSession()
        lock.unlock()
        publishState()
    }

    private func mutateMachine(_ mutation: (inout TrackerStateMachine) throws -> Void) rethrows {
        lock.lock()
        do {
            try mutation(&machine)
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }
        publishState()
    }

    @_spi(Engineering)
    public func setOneEyeEnforcementEnabled(_ enabled: Bool) {
        lock.lock()
        oneEyeEnforcementEnabled = enabled
        lock.unlock()
    }

    @_spi(Engineering)
    public func beginPhase3Validation(
        condition: Phase3ValidationCondition,
        randomizedTargets: [NormalizedGazePoint],
        viewport: GazeViewport
    ) throws {
        lock.lock()
        do {
            guard machine.calibrationState == .calibrated,
                  let layout = calibrationEngine.calibrationLayout,
                  let mapping = calibrationEngine.mappingKind else {
                throw CalibrationContractError.invalidState
            }
            try validationSession.begin(
                condition: condition,
                targets: randomizedTargets,
                viewport: viewport,
                layout: layout,
                mappingKind: mapping.rawValue,
                calibrationDurationSeconds: calibrationEngine.calibrationDurationSeconds,
                calibrationTargetRetryCount: calibrationEngine.calibrationTargetRetryCount
            )
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }
    }

    @_spi(Engineering)
    public func beginPhase3ValidationTarget(at point: NormalizedGazePoint) throws {
        lock.lock()
        defer { lock.unlock() }
        try validationSession.beginTarget(point)
    }

    @_spi(Engineering)
    public func phase3ValidationState() -> Phase3ValidationState {
        lock.lock()
        defer { lock.unlock() }
        return validationSession.state
    }

    @_spi(Engineering)
    public func phase3ValidationSummaries() -> [Phase3ValidationSummary] {
        lock.lock()
        defer { lock.unlock() }
        return validationSession.summaries
    }

    @_spi(Engineering)
    public func phase3GatePassed() -> Bool {
        let expected: [Phase3ValidationCondition] = [
            .consecutiveOne, .consecutiveTwo, .modestHeadMovement
        ]
        lock.lock()
        defer { lock.unlock() }
        let summaries = validationSession.summaries
        return summaries.map(\.condition) == expected &&
            summaries.allSatisfy(\.passesFourCentimeterGate)
    }

    private func transitionToStarted(supported: Bool) throws {
        lock.lock()
        defer { lock.unlock() }
        try machine.start(supported: supported)
    }

    private func transitionToResumed(supported: Bool) throws {
        lock.lock()
        defer { lock.unlock() }
        try machine.resume(supported: supported)
    }

    private func applyStartError(_ error: Error) {
        lock.lock()
        if error as? GazeTrackerError == .permissionDenied {
            machine.setTrackingState(.permissionDenied)
        } else if error as? GazeTrackerError == .unsupported {
            machine.setTrackingState(.unsupported)
        } else {
            machine.setTrackingState(.lost)
        }
        lock.unlock()
        publishState()
    }

    private func publishState(
        sourceTimestamp: UInt64? = nil,
        setupState: SetupState? = nil,
        eyeAvailability: EyeAvailability? = nil,
        point: NormalizedGazePoint? = nil,
        quality: GazeQuality = .unavailable
    ) {
        let output: GazeSample
        let callback: GazeSampleHandler?
        lock.lock()
        let timestamp = sequencer.next(candidate: sourceTimestamp ?? clock.nowNanoseconds())
        output = GazeSample(
            pointNormalized: point,
            timestamp: timestamp,
            quality: quality,
            trackingState: machine.trackingState,
            setupState: setupState ?? sample.setupState,
            calibrationState: machine.calibrationState,
            eyeAvailability: eyeAvailability ?? sample.eyeAvailability
        )
        sample = output
        callback = handler
        lock.unlock()

        // Delivery happens directly from the producing queue. The module adds no
        // main-thread hop, timer, smoothing buffer, or sample-history queue.
        callback?(output)
    }

    fileprivate func handleObservation(_ state: InternalObservationState) {
        let engineOutput: Phase3CalibrationEngine.Output
        let tracking: TrackingState
        lock.lock()
        if state.trackingState == .lost {
            faceWasLost = true
        } else if let ray = state.selectedEyeRay {
            let origin = SIMD3(ray.originX, ray.originY, ray.originZ)
            if faceWasLost, let previous = lastEyeOrigin, simd_distance(previous, origin) > 0.03 {
                calibrationEngine.invalidate()
                validationSession = Phase3ValidationSession()
                machine.invalidateCalibration()
            }
            faceWasLost = false
            lastEyeOrigin = origin
        }
        engineOutput = calibrationEngine.ingest(
            timestampNanoseconds: state.sourceTimestampNanoseconds,
            ray: state.selectedEyeRay,
            setupState: state.setupState,
            eyeAvailability: state.eyeAvailability,
            oneEyeEnforcementEnabled: oneEyeEnforcementEnabled
        )
        let currentEngine = calibrationEngine
        validationSession.ingest(
            timestampNanoseconds: state.sourceTimestampNanoseconds,
            ray: state.selectedEyeRay,
            setupState: state.setupState,
            eyeAvailability: state.eyeAvailability,
            oneEyeEnforcementEnabled: oneEyeEnforcementEnabled,
            predict: currentEngine.predictRaw
        )
        switch engineOutput.event {
        case .none: break
        case .targetAccepted: machine.setCalibrationState(.targetAccepted)
        case .retryTarget: machine.setCalibrationState(.retryTarget)
        case .calibrated: machine.setCalibrationState(.calibrated)
        case .failed: machine.setCalibrationState(.failed)
        }
        tracking = engineOutput.point == nil ? state.trackingState : .tracking
        machine.setTrackingState(tracking)
        lock.unlock()
        publishState(
            sourceTimestamp: state.sourceTimestampNanoseconds,
            setupState: state.setupState,
            eyeAvailability: state.eyeAvailability,
            point: engineOutput.point,
            quality: engineOutput.quality
        )
    }

    fileprivate func handleRuntimeFailure() {
        lock.lock()
        machine.setTrackingState(.lost)
        calibrationEngine.invalidate()
        validationSession = Phase3ValidationSession()
        machine.invalidateCalibration()
        lock.unlock()
        publishState(setupState: .unknown, eyeAvailability: EyeAvailability.none)
    }
}

private final class RuntimeBridge: ObservationRuntimeDelegate {
    weak var owner: GazeTracker?

    func observationRuntime(_ runtime: ObservationRuntime, didProduce state: InternalObservationState) {
        owner?.handleObservation(state)
    }

    func observationRuntimeDidFail(_ runtime: ObservationRuntime) {
        owner?.handleRuntimeFailure()
    }
}
