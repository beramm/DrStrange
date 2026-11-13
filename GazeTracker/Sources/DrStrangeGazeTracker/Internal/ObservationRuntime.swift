import Foundation

@_spi(Platform)
public struct SelectedEyeRayObservation: Sendable {
    public let originX: Double
    public let originY: Double
    public let originZ: Double
    public let directionX: Double
    public let directionY: Double
    public let directionZ: Double
    public let baselineDirectionX: Double
    public let baselineDirectionY: Double
    public let headDirectionX: Double
    public let headDirectionY: Double
    public let headDirectionZ: Double
    public let faceDistanceMeters: Double
    public let selectedEyeBlink: Double
    public let publicationLatencyMilliseconds: Double

    public init(
        originX: Double,
        originY: Double,
        originZ: Double,
        directionX: Double,
        directionY: Double,
        directionZ: Double,
        baselineDirectionX: Double? = nil,
        baselineDirectionY: Double? = nil,
        headDirectionX: Double? = nil,
        headDirectionY: Double? = nil,
        headDirectionZ: Double? = nil,
        faceDistanceMeters: Double,
        selectedEyeBlink: Double,
        publicationLatencyMilliseconds: Double
    ) {
        self.originX = originX
        self.originY = originY
        self.originZ = originZ
        self.directionX = directionX
        self.directionY = directionY
        self.directionZ = directionZ
        self.baselineDirectionX = baselineDirectionX ?? directionX
        self.baselineDirectionY = baselineDirectionY ?? directionY
        self.headDirectionX = headDirectionX ?? directionX
        self.headDirectionY = headDirectionY ?? directionY
        self.headDirectionZ = headDirectionZ ?? directionZ
        self.faceDistanceMeters = faceDistanceMeters
        self.selectedEyeBlink = selectedEyeBlink
        self.publicationLatencyMilliseconds = publicationLatencyMilliseconds
    }
}

@_spi(Platform)
public struct InternalObservationState {
    public let sourceTimestampNanoseconds: UInt64
    public let trackingState: TrackingState
    public let setupState: SetupState
    public let eyeAvailability: EyeAvailability
    public let selectedEyeRay: SelectedEyeRayObservation?

    public init(
        sourceTimestampNanoseconds: UInt64,
        trackingState: TrackingState,
        setupState: SetupState,
        eyeAvailability: EyeAvailability,
        selectedEyeRay: SelectedEyeRayObservation? = nil
    ) {
        self.sourceTimestampNanoseconds = sourceTimestampNanoseconds
        self.trackingState = trackingState
        self.setupState = setupState
        self.eyeAvailability = eyeAvailability
        self.selectedEyeRay = selectedEyeRay
    }
}

@_spi(Platform)
public protocol ObservationRuntimeDelegate: AnyObject {
    func observationRuntime(_ runtime: ObservationRuntime, didProduce state: InternalObservationState)
    func observationRuntimeDidFail(_ runtime: ObservationRuntime)
}

@_spi(Platform)
public protocol ObservationRuntime: AnyObject {
    var delegate: ObservationRuntimeDelegate? { get set }
    func checkSupport() -> GazeSupport
    func start(reset: Bool) async throws
    func pause()
    func stop()
}
