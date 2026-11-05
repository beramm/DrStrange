@_spi(Platform) import DrStrangeGazeTracker
import Foundation

#if canImport(ARKit) && canImport(AVFoundation) && os(iOS)
import ARKit
import AVFoundation
import simd

final class PlatformObservationRuntime: NSObject, ObservationRuntime, ARSessionDelegate {
    weak var delegate: ObservationRuntimeDelegate?
    private weak var previewView: ARSCNView?
    private let cameraInput: GazeCameraInputConfiguration?

    private let sessionLock = NSLock()
    private var session: ARSession?
    private let delegateQueue = DispatchQueue(
        label: "com.drstrange.gaze.arkit-observations",
        qos: .userInteractive
    )

    init(
        previewView: ARSCNView? = nil,
        cameraInput: GazeCameraInputConfiguration? = nil
    ) {
        self.previewView = previewView
        self.cameraInput = cameraInput
        super.init()
    }

    func checkSupport() -> GazeSupport {
        GazeSupport(
            isSupported: ARFaceTrackingConfiguration.isSupported,
            cameraAuthorization: Self.authorizationState
        )
    }

    func start(reset: Bool) async throws {
        guard ARFaceTrackingConfiguration.isSupported else { throw GazeTrackerError.unsupported }
        let authorized: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorized = true
        case .notDetermined:
            authorized = await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            authorized = false
        @unknown default:
            authorized = false
        }
        guard authorized else { throw GazeTrackerError.permissionDenied }

        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        try configureCaptureZoom()
        let options: ARSession.RunOptions = reset ? [.resetTracking, .removeExistingAnchors] : []
        let session = makeSession()
        session.run(configuration, options: options)
    }

    func pause() {
        releaseSession()
    }

    func stop() {
        releaseSession()
    }

    private func makeSession() -> ARSession {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        if let session { return session }
        // When the engineering preview is present, use the renderer's own
        // session. ARSCNView wires its camera background when it owns the
        // session from the beginning; assigning a separately-created running
        // session later can leave the preview black even while frames arrive.
        let created = previewSession() ?? ARSession()
        created.delegate = self
        created.delegateQueue = delegateQueue
        session = created
        return created
    }

    private func releaseSession() {
        let released: ARSession?
        sessionLock.lock()
        released = session
        session = nil
        sessionLock.unlock()

        resetCaptureZoom()
        released?.pause()
        released?.delegate = nil
        if let released { detachPreview(from: released) }
    }

    private func configureCaptureZoom() throws {
        let requested = cameraInput?.requestedZoomFactor() ?? 1.0
        guard let device = ARFaceTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera else {
            cameraInput?.record(GazeCameraInputStatus(
                captureDeviceAvailable: false,
                requestedZoomFactor: requested,
                appliedZoomFactor: requested == 1.0 ? 1.0 : nil,
                minimumZoomFactor: nil,
                maximumZoomFactor: nil
            ))
            if requested != 1.0 { throw GazeTrackerError.runtimeFailure }
            return
        }

        let minimum = Double(device.minAvailableVideoZoomFactor)
        let maximum = Double(device.maxAvailableVideoZoomFactor)
        guard requested >= minimum, requested <= maximum else {
            cameraInput?.record(GazeCameraInputStatus(
                captureDeviceAvailable: true,
                requestedZoomFactor: requested,
                appliedZoomFactor: nil,
                minimumZoomFactor: minimum,
                maximumZoomFactor: maximum
            ))
            throw GazeTrackerError.runtimeFailure
        }

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = CGFloat(requested)
            let applied = Double(device.videoZoomFactor)
            device.unlockForConfiguration()
            cameraInput?.record(GazeCameraInputStatus(
                captureDeviceAvailable: true,
                requestedZoomFactor: requested,
                appliedZoomFactor: applied,
                minimumZoomFactor: minimum,
                maximumZoomFactor: maximum
            ))
            guard abs(applied - requested) <= 0.01 else {
                throw GazeTrackerError.runtimeFailure
            }
        } catch {
            cameraInput?.record(GazeCameraInputStatus(
                captureDeviceAvailable: true,
                requestedZoomFactor: requested,
                appliedZoomFactor: nil,
                minimumZoomFactor: minimum,
                maximumZoomFactor: maximum
            ))
            throw GazeTrackerError.runtimeFailure
        }
    }

    private func resetCaptureZoom() {
        guard let device = ARFaceTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera else { return }
        let minimum = Double(device.minAvailableVideoZoomFactor)
        let maximum = Double(device.maxAvailableVideoZoomFactor)
        guard minimum <= 1.0, maximum >= 1.0 else { return }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = 1.0
            device.unlockForConfiguration()
        } catch {
            // Session shutdown must continue even if the camera rejects reset.
        }
    }

    private func previewSession() -> ARSession? {
        guard let previewView else { return nil }
        if Thread.isMainThread { return previewView.session }
        return DispatchQueue.main.sync { [weak previewView] in previewView?.session }
    }

    private func detachPreview(from session: ARSession) {
        let previewView = previewView
        DispatchQueue.main.async { [weak previewView, weak session] in
            guard let previewView, let session, previewView.session === session else { return }
            // ARSCNView retains its session. Replacing it with an idle session
            // ensures pause/stop releases the camera-owning session completely.
            previewView.session = ARSession()
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked else {
            publish(frameTimestamp: frame.timestamp, tracking: .lost, setup: .unknown, eyes: .none)
            return
        }

        // Compose the accepted anatomical right-eye transform into camera space.
        // Only the resulting volatile ray crosses the platform SPI; ARKit objects
        // and biometric geometry never cross the public tracker boundary.
        let cameraFromWorld = simd_inverse(frame.camera.transform)
        let eyeInCamera = cameraFromWorld * face.transform * face.rightEyeTransform
        let faceInCamera = cameraFromWorld * face.transform
        let origin = SIMD3<Double>(
            Double(eyeInCamera.columns.3.x),
            Double(eyeInCamera.columns.3.y),
            Double(eyeInCamera.columns.3.z)
        )
        let rawDirection = SIMD3<Double>(
            -Double(eyeInCamera.columns.2.x),
            -Double(eyeInCamera.columns.2.y),
            -Double(eyeInCamera.columns.2.z)
        )
        let baselineDirection = SIMD2<Double>(
            -Double(face.rightEyeTransform.columns.2.x),
            -Double(face.rightEyeTransform.columns.2.y)
        )
        let faceTranslation = SIMD3<Double>(
            Double(faceInCamera.columns.3.x),
            Double(faceInCamera.columns.3.y),
            Double(faceInCamera.columns.3.z)
        )
        let headDirection = SIMD3<Double>(
            -Double(faceInCamera.columns.2.x),
            -Double(faceInCamera.columns.2.y),
            -Double(faceInCamera.columns.2.z)
        )
        let distance = simd_length(faceTranslation)
        let selectedEyeBlink = Double(face.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0)
        let finite = (0..<4).allSatisfy { column in
            let value = eyeInCamera[column]
            return value.x.isFinite && value.y.isFinite && value.z.isFinite && value.w.isFinite
        } && rawDirection.x.isFinite && rawDirection.y.isFinite && rawDirection.z.isFinite &&
            simd_length(rawDirection) > 1e-9 && distance.isFinite
        let facePositionReady = abs(faceTranslation.x) <= 0.18 &&
            faceTranslation.y >= -0.25 && faceTranslation.y <= 0.12
        let setup: SetupState = if !distance.isFinite || !facePositionReady {
            .unknown
        } else if distance < 0.40 {
            .tooClose
        } else if distance > 0.60 {
            .tooFar
        } else {
            .ready
        }
        let eyeOpen = selectedEyeBlink < 0.70
        let ray = finite ? SelectedEyeRayObservation(
            originX: origin.x,
            originY: origin.y,
            originZ: origin.z,
            directionX: rawDirection.x,
            directionY: rawDirection.y,
            directionZ: rawDirection.z,
            baselineDirectionX: baselineDirection.x,
            baselineDirectionY: baselineDirection.y,
            headDirectionX: headDirection.x,
            headDirectionY: headDirection.y,
            headDirectionZ: headDirection.z,
            faceDistanceMeters: distance,
            selectedEyeBlink: selectedEyeBlink,
            publicationLatencyMilliseconds: max(
                0,
                (ProcessInfo.processInfo.systemUptime - frame.timestamp) * 1_000
            )
        ) : nil
        publish(
            frameTimestamp: frame.timestamp,
            tracking: finite && eyeOpen && setup == .ready ? .limited : (finite ? .limited : .lost),
            setup: setup,
            eyes: finite && eyeOpen ? .rightOnly : .none,
            ray: ray
        )
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        delegate?.observationRuntimeDidFail(self)
    }

    func sessionWasInterrupted(_ session: ARSession) {
        publishNow(tracking: .paused, eyes: .none)
    }

    private func publish(
        frameTimestamp: TimeInterval,
        tracking: TrackingState,
        setup: SetupState,
        eyes: EyeAvailability,
        ray: SelectedEyeRayObservation? = nil
    ) {
        let nanoseconds = UInt64(max(frameTimestamp, 0) * 1_000_000_000)
        delegate?.observationRuntime(
            self,
            didProduce: InternalObservationState(
                sourceTimestampNanoseconds: nanoseconds,
                trackingState: tracking,
                setupState: setup,
                eyeAvailability: eyes,
                selectedEyeRay: ray
            )
        )
    }

    private func publishNow(tracking: TrackingState, eyes: EyeAvailability) {
        delegate?.observationRuntime(
            self,
            didProduce: InternalObservationState(
                sourceTimestampNanoseconds: DispatchTime.now().uptimeNanoseconds,
                trackingState: tracking,
                setupState: .unknown,
                eyeAvailability: eyes,
                selectedEyeRay: nil
            )
        )
    }

    private static var authorizationState: CameraAuthorizationState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .denied
        }
    }
}
#else
final class PlatformObservationRuntime: ObservationRuntime {
    weak var delegate: ObservationRuntimeDelegate?

    func checkSupport() -> GazeSupport {
        GazeSupport(isSupported: false, cameraAuthorization: .restricted)
    }

    func start(reset: Bool) async throws {
        throw GazeTrackerError.unsupported
    }

    func pause() {}
    func stop() {}
}
#endif
