import Foundation

@_spi(Engineering)
public enum GazeCameraInputMode: String, CaseIterable, Equatable, Sendable {
    case fullSensor
    case zoomedOnePointFive

    public var requestedZoomFactor: Double {
        switch self {
        case .fullSensor: 1.0
        case .zoomedOnePointFive: 1.5
        }
    }
}

@_spi(Engineering)
public struct GazeCameraInputStatus: Equatable, Sendable {
    public let captureDeviceAvailable: Bool
    public let requestedZoomFactor: Double
    public let appliedZoomFactor: Double?
    public let minimumZoomFactor: Double?
    public let maximumZoomFactor: Double?

    init(
        captureDeviceAvailable: Bool,
        requestedZoomFactor: Double,
        appliedZoomFactor: Double?,
        minimumZoomFactor: Double?,
        maximumZoomFactor: Double?
    ) {
        self.captureDeviceAvailable = captureDeviceAvailable
        self.requestedZoomFactor = requestedZoomFactor
        self.appliedZoomFactor = appliedZoomFactor
        self.minimumZoomFactor = minimumZoomFactor
        self.maximumZoomFactor = maximumZoomFactor
    }
}

/// Engineering-only, volatile capture configuration for the controlled
/// full-sensor-versus-1.5x experiment. It stores no camera or gaze data.
@_spi(Engineering)
public final class GazeCameraInputConfiguration: @unchecked Sendable {
    private let lock = NSLock()
    private var selectedMode: GazeCameraInputMode = .fullSensor
    private var latestStatus = GazeCameraInputStatus(
        captureDeviceAvailable: false,
        requestedZoomFactor: 1.0,
        appliedZoomFactor: nil,
        minimumZoomFactor: nil,
        maximumZoomFactor: nil
    )

    public var mode: GazeCameraInputMode {
        get {
            lock.lock()
            defer { lock.unlock() }
            return selectedMode
        }
        set {
            lock.lock()
            selectedMode = newValue
            latestStatus = GazeCameraInputStatus(
                captureDeviceAvailable: latestStatus.captureDeviceAvailable,
                requestedZoomFactor: newValue.requestedZoomFactor,
                appliedZoomFactor: nil,
                minimumZoomFactor: latestStatus.minimumZoomFactor,
                maximumZoomFactor: latestStatus.maximumZoomFactor
            )
            lock.unlock()
        }
    }

    public func status() -> GazeCameraInputStatus {
        lock.lock()
        defer { lock.unlock() }
        return latestStatus
    }

    func requestedZoomFactor() -> Double {
        lock.lock()
        defer { lock.unlock() }
        return selectedMode.requestedZoomFactor
    }

    func record(_ status: GazeCameraInputStatus) {
        lock.lock()
        latestStatus = status
        lock.unlock()
    }
}

@_spi(Engineering)
public enum GazeAmbientLightState: Equatable, Sendable {
    case unknown
    case adequate
    case tooDark
}

/// Volatile, coarse lighting guidance derived from ARKit's light estimate.
/// Hysteresis prevents the UI from flickering when the room is near the limit.
@_spi(Engineering)
public final class GazeAmbientLightConfiguration: @unchecked Sendable {
    static let darkThreshold = 250.0
    static let recoveryThreshold = 400.0

    private let lock = NSLock()
    private var latestState: GazeAmbientLightState = .unknown

    public func state() -> GazeAmbientLightState {
        lock.lock()
        defer { lock.unlock() }
        return latestState
    }

    func record(ambientIntensity: Double?) {
        lock.lock()
        defer { lock.unlock() }
        guard let ambientIntensity, ambientIntensity.isFinite, ambientIntensity >= 0 else {
            latestState = .unknown
            return
        }

        switch latestState {
        case .unknown:
            latestState = ambientIntensity < Self.darkThreshold ? .tooDark : .adequate
        case .adequate:
            if ambientIntensity < Self.darkThreshold { latestState = .tooDark }
        case .tooDark:
            if ambientIntensity >= Self.recoveryThreshold { latestState = .adequate }
        }
    }

    func reset() {
        lock.lock()
        latestState = .unknown
        lock.unlock()
    }
}
