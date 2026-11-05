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
