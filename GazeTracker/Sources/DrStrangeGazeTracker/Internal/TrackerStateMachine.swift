import Foundation

struct TrackerStateMachine {
    enum Lifecycle: Equatable {
        case stopped
        case running
        case paused
    }

    private(set) var lifecycle: Lifecycle = .stopped
    private(set) var trackingState: TrackingState = .paused
    private(set) var calibrationState: CalibrationState = .notCalibrated

    mutating func start(supported: Bool) throws {
        guard lifecycle == .stopped else { throw GazeTrackerError.invalidLifecycleTransition }
        guard supported else {
            trackingState = .unsupported
            throw GazeTrackerError.unsupported
        }
        lifecycle = .running
        trackingState = .limited
    }

    mutating func pause() throws {
        guard lifecycle == .running else { throw GazeTrackerError.invalidLifecycleTransition }
        lifecycle = .paused
        trackingState = .paused
    }

    mutating func resume(supported: Bool) throws {
        guard lifecycle == .paused else { throw GazeTrackerError.invalidLifecycleTransition }
        guard supported else {
            trackingState = .unsupported
            throw GazeTrackerError.unsupported
        }
        lifecycle = .running
        trackingState = .limited
    }

    mutating func stop() {
        lifecycle = .stopped
        trackingState = .paused
        calibrationState = .notCalibrated
    }

    mutating func setTrackingState(_ state: TrackingState) {
        guard lifecycle == .running else { return }
        trackingState = state
    }

    mutating func beginCalibration() throws {
        guard lifecycle == .running else { throw CalibrationContractError.trackingNotRunning }
        guard calibrationState == .notCalibrated || calibrationState == .invalid || calibrationState == .failed else {
            throw CalibrationContractError.invalidState
        }
        calibrationState = .readyForTarget
    }

    mutating func beginCalibrationTarget() throws {
        guard lifecycle == .running else { throw CalibrationContractError.trackingNotRunning }
        guard calibrationState == .readyForTarget || calibrationState == .targetAccepted || calibrationState == .retryTarget else {
            throw CalibrationContractError.invalidState
        }
        calibrationState = .collecting
    }

    mutating func setCalibrationState(_ state: CalibrationState) {
        guard lifecycle == .running else { return }
        calibrationState = state
    }

    mutating func cancelCalibration() {
        calibrationState = .notCalibrated
    }

    mutating func invalidateCalibration() {
        calibrationState = .invalid
    }
}
