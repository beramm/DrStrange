import Foundation

public enum CameraAuthorizationState: String, Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

public struct GazeSupport: Equatable, Sendable {
    public let isSupported: Bool
    public let cameraAuthorization: CameraAuthorizationState

    public init(isSupported: Bool, cameraAuthorization: CameraAuthorizationState) {
        self.isSupported = isSupported
        self.cameraAuthorization = cameraAuthorization
    }
}

public enum GazeTrackerError: Error, Equatable, Sendable {
    case unsupported
    case permissionDenied
    case invalidLifecycleTransition
    case runtimeFailure
}

public enum CalibrationContractError: Error, Equatable, Sendable {
    case trackingNotRunning
    case invalidState
    case setupNotReady
    case unexpectedTarget
}

public enum CalibrationInvalidationReason: String, Equatable, Sendable {
    case faceRepositioned
    case deviceRemounted
    case orientationChanged
    case cameraPositionChanged
    case viewingPositionChanged
    case activeEyeOrPatchSideChanged
    case setupChanged
    case explicitlyRequested
}

public typealias GazeSampleHandler = @Sendable (GazeSample) -> Void

/// Public lifecycle and calibration-control surface.
///
/// Calibration collection, held-out validation, mapping, and any separate
/// calibration-result handoff are Phase 3 responsibilities. Phase 2 exposes
/// their lifecycle states without fabricating a calibrated mapping.
public protocol GazeTracking: AnyObject {
    func checkSupport() -> GazeSupport
    func setSampleHandler(_ handler: GazeSampleHandler?)
    func start() async throws
    func pause() throws
    func resume() async throws
    func stop()

    func beginCalibration() throws
    func beginCalibration(layout: CalibrationLayout) throws
    func beginCalibrationTarget(at point: NormalizedGazePoint) throws
    func cancelCalibration()
    func invalidateCalibration(reason: CalibrationInvalidationReason)
}
