@_spi(Platform) import DrStrangeGazeTracker
import Foundation

#if canImport(ARKit) && canImport(AVFoundation) && os(iOS)
import ARKit
import AVFoundation
import ImageIO
import UIKit
import simd

final class PlatformObservationRuntime: NSObject, ObservationRuntime, ARSessionDelegate {
    weak var delegate: ObservationRuntimeDelegate?
    private weak var previewHostView: UIView?
    private let cameraFramePreviewProcessor: CameraFramePreviewProcessor?
    private let cameraInput: GazeCameraInputConfiguration?
    private let ambientLight: GazeAmbientLightConfiguration?
    private let faceIsolationProcessor: FaceIsolationProcessor?
    private let blazeGazeProcessor: BlazeGazeShadowProcessor?

    private let sessionLock = NSLock()
    private var session: ARSession?
    private let delegateQueue = DispatchQueue(
        label: "com.drstrange.gaze.arkit-observations",
        qos: .userInteractive
    )

    init(
        previewHostView: UIView? = nil,
        cameraFramePreview: VolatileCameraFramePreview? = nil,
        cameraInput: GazeCameraInputConfiguration? = nil,
        ambientLight: GazeAmbientLightConfiguration? = nil,
        faceIsolation: GazeFaceIsolationConfiguration? = nil,
        faceIsolationPreview: VolatileFaceIsolationPreview? = nil,
        blazeGaze: GazeBlazeGazeConfiguration? = nil,
        blazeGazePreview: VolatileBlazeGazePreview? = nil
    ) {
        self.previewHostView = previewHostView
        if let cameraFramePreview {
            cameraFramePreviewProcessor = CameraFramePreviewProcessor(preview: cameraFramePreview)
        } else {
            cameraFramePreviewProcessor = nil
        }
        self.cameraInput = cameraInput
        self.ambientLight = ambientLight
        if let faceIsolation, let faceIsolationPreview {
            faceIsolationProcessor = FaceIsolationProcessor(
                configuration: faceIsolation,
                preview: faceIsolationPreview
            )
        } else {
            faceIsolationProcessor = nil
        }
        if let blazeGaze, let blazeGazePreview {
            blazeGazeProcessor = BlazeGazeShadowProcessor(
                configuration: blazeGaze,
                preview: blazeGazePreview
            )
        } else {
            blazeGazeProcessor = nil
        }
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
        let preview = previewHostView
        let faceImageOrientation = await MainActor.run {
            let activeSceneOrientation = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }?
                .interfaceOrientation
            return Self.faceImageOrientation(
                for: preview?.window?.windowScene?.interfaceOrientation
                    ?? activeSceneOrientation
                    ?? .landscapeRight
            )
        }
        faceIsolationProcessor?.start(orientation: faceImageOrientation)
        cameraFramePreviewProcessor?.start(orientation: faceImageOrientation)
        let options: ARSession.RunOptions = reset ? [.resetTracking, .removeExistingAnchors] : []
        let session = makeSession()
        session.run(configuration, options: options)
        // MediaPipe creates a GPU/GL context while its graph is initialized.
        // Let ARKit acquire and warm the TrueDepth session first so the shadow
        // candidate can never race the control path for camera startup.
        delegateQueue.asyncAfter(deadline: .now() + 0.75) { [weak self, weak session] in
            guard let self, let session, self.isCurrentSession(session) else { return }
            self.blazeGazeProcessor?.start(orientation: faceImageOrientation)
        }
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
        // The runtime exclusively owns this session. Keeping ARSCNView out of
        // the path prevents a renderer from replacing the delegate and starving
        // the direct preview of frame callbacks on physical devices.
        let created = ARSession()
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
        ambientLight?.reset()
        faceIsolationProcessor?.stop()
        cameraFramePreviewProcessor?.stop()
        blazeGazeProcessor?.stop()
        released?.pause()
        released?.delegate = nil
    }

    private func isCurrentSession(_ candidate: ARSession) -> Bool {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        return session === candidate
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
        // Leave ARKit's primary TrueDepth device completely untouched for the
        // default path. Re-locking the capture device only to assign 1.0 can
        // leave some iPadOS/device combinations delivering video-range black
        // frames even though the ARSession continues at 60 Hz.
        if abs(requested - 1.0) <= 0.01 {
            cameraInput?.record(GazeCameraInputStatus(
                captureDeviceAvailable: true,
                requestedZoomFactor: requested,
                appliedZoomFactor: 1.0,
                minimumZoomFactor: minimum,
                maximumZoomFactor: maximum
            ))
            return
        }
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
        guard let cameraInput else { return }
        let status = cameraInput.status()
        guard let applied = status.appliedZoomFactor, abs(applied - 1.0) > 0.01 else { return }
        guard let device = ARFaceTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera else { return }
        let minimum = Double(device.minAvailableVideoZoomFactor)
        let maximum = Double(device.maxAvailableVideoZoomFactor)
        guard minimum <= 1.0, maximum >= 1.0 else { return }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = 1.0
            device.unlockForConfiguration()
            cameraInput.record(GazeCameraInputStatus(
                captureDeviceAvailable: true,
                requestedZoomFactor: status.requestedZoomFactor,
                appliedZoomFactor: 1.0,
                minimumZoomFactor: minimum,
                maximumZoomFactor: maximum
            ))
        } catch {
            // Session shutdown must continue even if the camera rejects reset.
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        ambientLight?.record(
            ambientIntensity: frame.lightEstimate.map { Double($0.ambientIntensity) }
        )
        cameraFramePreviewProcessor?.process(
            pixelBuffer: frame.capturedImage,
            timestamp: frame.timestamp
        )
        faceIsolationProcessor?.process(
            pixelBuffer: frame.capturedImage,
            timestamp: frame.timestamp
        )
        blazeGazeProcessor?.process(
            pixelBuffer: frame.capturedImage,
            timestamp: frame.timestamp
        )
        guard let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked else {
            publish(frameTimestamp: frame.timestamp, tracking: .lost, setup: .unknown, eyes: .none)
            return
        }

        // Select the single visible anatomical eye. When both eyes are allowed,
        // keep the right eye as the deterministic default. Only the resulting
        // volatile ray crosses the platform SPI; ARKit objects and biometric
        // geometry never cross the public tracker boundary.
        let anatomicalRightBlink = Double(face.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0)
        let anatomicalLeftBlink = Double(face.blendShapes[.eyeBlinkRight]?.floatValue ?? 0)
        let eyeAvailability = EyeAvailabilityClassifier.classify(
            eyeBlinkLeft: anatomicalRightBlink,
            eyeBlinkRight: anatomicalLeftBlink
        )
        let selectedEyeTransform: simd_float4x4
        let selectedEyeBlink: Double
        if eyeAvailability == .leftOnly {
            selectedEyeTransform = face.leftEyeTransform
            selectedEyeBlink = anatomicalLeftBlink
        } else {
            selectedEyeTransform = face.rightEyeTransform
            selectedEyeBlink = anatomicalRightBlink
        }

        let cameraFromWorld = simd_inverse(frame.camera.transform)
        let eyeInCamera = cameraFromWorld * face.transform * selectedEyeTransform
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
            -Double(selectedEyeTransform.columns.2.x),
            -Double(selectedEyeTransform.columns.2.y)
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
        let selectedEyeOpen = eyeAvailability != .none
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
            tracking: finite && selectedEyeOpen && setup == .ready ? .limited : (finite ? .limited : .lost),
            setup: setup,
            eyes: finite ? eyeAvailability : .none,
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

    private static func faceImageOrientation(
        for interfaceOrientation: UIInterfaceOrientation
    ) -> CGImagePropertyOrientation {
        let displayOrientation: FaceIsolationDisplayOrientation = switch interfaceOrientation {
        case .landscapeLeft: .landscapeLeft
        case .landscapeRight: .landscapeRight
        case .portrait: .portrait
        case .portraitUpsideDown: .portraitUpsideDown
        default: .landscapeRight
        }
        return displayOrientation.imagePropertyOrientation
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
