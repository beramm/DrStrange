import Foundation

/// A gaze location in the current drawable viewport.
///
/// Both axes are in the closed range `0...1`. The origin is the drawable
/// viewport's top-left corner; x increases rightward and y increases downward.
public struct NormalizedGazePoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init?(x: Double, y: Double) {
        guard x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) else {
            return nil
        }
        self.x = x
        self.y = y
    }

    public init?(viewportPoint: ViewportPoint, in viewport: GazeViewport) {
        self.init(
            x: viewportPoint.x / viewport.width,
            y: viewportPoint.y / viewport.height
        )
    }

    public func viewportPoint(in viewport: GazeViewport) -> ViewportPoint {
        ViewportPoint(x: x * viewport.width, y: y * viewport.height)
    }
}

public struct ViewportPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct GazeViewport: Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init?(width: Double, height: Double) {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            return nil
        }
        self.width = width
        self.height = height
    }
}

/// Monotonic time from the device uptime clock, unrelated to wall-clock time.
/// Values are meaningful only for ordering and elapsed-time calculations from
/// the same boot session.
public struct MonotonicTimestamp: Equatable, Hashable, Comparable, Sendable {
    public let uptimeNanoseconds: UInt64

    public init(uptimeNanoseconds: UInt64) {
        self.uptimeNanoseconds = uptimeNanoseconds
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.uptimeNanoseconds < rhs.uptimeNanoseconds
    }

    public func durationSince(_ earlier: Self) -> TimeInterval? {
        guard self >= earlier else { return nil }
        return TimeInterval(uptimeNanoseconds - earlier.uptimeNanoseconds) / 1_000_000_000
    }
}

public struct GazeQuality: Equatable, Sendable {
    public enum Level: String, Equatable, Sendable {
        case unavailable
        case limited
        case usable
    }

    public let confidence: Double
    public let level: Level

    public init(confidence: Double, level: Level) {
        let finiteConfidence = confidence.isFinite ? confidence : 0
        self.confidence = min(max(finiteConfidence, 0), 1)
        self.level = level
    }

    public static let unavailable = GazeQuality(confidence: 0, level: .unavailable)
}

public enum TrackingState: String, Equatable, Sendable {
    case tracking
    case limited
    case lost
    case paused
    case unsupported
    case permissionDenied
}

public enum SetupState: String, Equatable, Sendable {
    case tooClose
    case ready
    case tooFar
    case unknown
}

public enum CalibrationState: String, Equatable, Sendable {
    case notCalibrated
    case readyForTarget
    case collecting
    case targetAccepted
    case retryTarget
    case calibrated
    case invalid
    case failed
}

/// Calibration presentations supported by the controlled Phase 3 experiment.
/// The target order is deliberate and is not a claim that more targets improve
/// accuracy.
public enum CalibrationLayout: String, CaseIterable, Equatable, Sendable {
    case ninePosition
    case perimeterToCentre13

    public var targets: [NormalizedGazePoint] {
        switch self {
        case .ninePosition:
            return Self.points([
                (0.05, 0.05), (0.50, 0.05), (0.95, 0.05),
                (0.05, 0.50), (0.50, 0.50), (0.95, 0.50),
                (0.05, 0.95), (0.50, 0.95), (0.95, 0.95)
            ])
        case .perimeterToCentre13:
            return Self.points([
                (0.08, 0.08), (0.29, 0.08), (0.50, 0.08), (0.71, 0.08), (0.92, 0.08),
                (0.92, 0.50),
                (0.92, 0.92), (0.71, 0.92), (0.50, 0.92), (0.29, 0.92), (0.08, 0.92),
                (0.08, 0.50),
                (0.50, 0.50)
            ])
        }
    }

    private static func points(_ values: [(Double, Double)]) -> [NormalizedGazePoint] {
        values.compactMap { NormalizedGazePoint(x: $0.0, y: $0.1) }
    }
}

public enum EyeAvailability: String, Equatable, Sendable {
    case both
    case leftOnly
    case rightOnly
    case none
}

/// The complete live tracker output. This type intentionally has exactly the
/// seven approved categories and contains no framework or face-geometry types.
public struct GazeSample: Equatable, Sendable {
    public let pointNormalized: NormalizedGazePoint?
    public let timestamp: MonotonicTimestamp
    public let quality: GazeQuality
    public let trackingState: TrackingState
    public let setupState: SetupState
    public let calibrationState: CalibrationState
    public let eyeAvailability: EyeAvailability

    public init(
        pointNormalized: NormalizedGazePoint?,
        timestamp: MonotonicTimestamp,
        quality: GazeQuality,
        trackingState: TrackingState,
        setupState: SetupState,
        calibrationState: CalibrationState,
        eyeAvailability: EyeAvailability
    ) {
        self.pointNormalized = pointNormalized
        self.timestamp = timestamp
        self.quality = quality
        self.trackingState = trackingState
        self.setupState = setupState
        self.calibrationState = calibrationState
        self.eyeAvailability = eyeAvailability
    }
}
