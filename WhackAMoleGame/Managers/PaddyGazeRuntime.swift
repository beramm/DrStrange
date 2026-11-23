import ARKit
import AVFoundation
import CoreImage
import DrStrangeGazeTracker
import Foundation
import ImageIO
import UIKit
import Vision

struct PaddyCapturedFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let hostUptime: TimeInterval
    let imageOrientation: CGImagePropertyOrientation
    let eyeAvailability: EyeAvailability
    let ambientIntensity: Double?
}

struct PaddyFrameAnalysis: @unchecked Sendable {
    let hostUptime: TimeInterval
    let imageOrientation: CGImagePropertyOrientation
    let prediction: EyeStripPrediction?
    let setupCandidate: SetupState
    let eyeAvailability: EyeAvailability
    let isSceneTooDark: Bool
    let captureRejectionReason: String?
    let modelStatus: String
    let previewImage: CGImage?
}

/// Accepts frames as fast as ARKit publishes them, but retains only the newest
/// pending frame while Vision/Core ML are busy.
actor PaddyLatestFrameProcessor<Frame: Sendable> {
    typealias Processor = @Sendable (Frame) async -> Void

    private var latest: Frame?
    private var isProcessing = false
    private let processor: Processor

    init(processor: @escaping Processor) {
        self.processor = processor
    }

    func submit(_ frame: Frame) {
        latest = frame
        guard !isProcessing else { return }
        isProcessing = true
        Task { await drain() }
    }

    private func drain() async {
        while let frame = latest {
            latest = nil
            await processor(frame)
        }
        isProcessing = false
    }
}

actor PaddyVisionFrameAnalyzer {
    private let previewContext = CIContext(options: [.cacheIntermediates: false])
    private var previewEnabled = false
    private var inferenceEngine: EyeStripInferenceEngine?
    private var modelStatus = "paddy-gazeTrackV2 not loaded"
    private var didAttemptModelLoad = false

    func setPreviewEnabled(_ enabled: Bool) {
        previewEnabled = enabled
    }

    func analyze(_ frame: PaddyCapturedFrame) -> PaddyFrameAnalysis {
        let source = CIImage(cvPixelBuffer: frame.pixelBuffer).oriented(frame.imageOrientation)
        let sourceExtent = source.extent.integral
        let upright = source.transformed(
            by: CGAffineTransform(translationX: -sourceExtent.minX, y: -sourceExtent.minY)
        )
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(ciImage: upright, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return PaddyFrameAnalysis(
                hostUptime: frame.hostUptime,
                imageOrientation: frame.imageOrientation,
                prediction: nil,
                setupCandidate: .unknown,
                eyeAvailability: frame.eyeAvailability,
                isSceneTooDark: false,
                captureRejectionReason: "Vision processing failed",
                modelStatus: modelStatus,
                previewImage: previewEnabled ? makePreview(from: upright) : nil
            )
        }

        loadModelIfNeeded()
        let faces = request.results ?? []
        let face = faces.max {
            $0.boundingBox.width * $0.boundingBox.height <
                $1.boundingBox.width * $1.boundingBox.height
        }
        let luma = averageLuma(frame.pixelBuffer)
        let isTooDark = luma.map { $0 < 0.18 } ?? {
            guard let ambient = frame.ambientIntensity else { return false }
            return ambient < 250
        }()
        let prediction: EyeStripPrediction?
        if let inferenceEngine, let face {
            do {
                prediction = try inferenceEngine.predict(orientedImage: upright, face: face)
                if prediction != nil {
                    modelStatus = "paddy-gazeTrackV2 active · on-device"
                } else {
                    modelStatus = "paddy-gazeTrackV2 waiting for both eye regions"
                }
            } catch {
                prediction = nil
                modelStatus = "paddy-gazeTrackV2 inference failed"
            }
        } else {
            prediction = nil
        }

        let setup = setupState(faces: faces, face: face, prediction: prediction, luma: luma)
        let rejection = captureRejection(
            faces: faces,
            face: face,
            luma: luma,
            prediction: prediction,
            setup: setup
        )
        return PaddyFrameAnalysis(
            hostUptime: frame.hostUptime,
            imageOrientation: frame.imageOrientation,
            prediction: prediction,
            setupCandidate: setup,
            eyeAvailability: frame.eyeAvailability,
            isSceneTooDark: isTooDark,
            captureRejectionReason: rejection,
            modelStatus: modelStatus,
            previewImage: previewEnabled ? makePreview(from: upright) : nil
        )
    }

    private func makePreview(from image: CIImage) -> CGImage? {
        let extent = image.extent.integral
        let longestSide = max(extent.width, extent.height)
        guard longestSide > 0 else { return nil }
        let scale = min(1, 640 / longestSide)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return previewContext.createCGImage(
            scaled,
            from: CGRect(x: 0, y: 0, width: extent.width * scale, height: extent.height * scale)
        )
    }

    private func loadModelIfNeeded() {
        guard !didAttemptModelLoad else { return }
        let loaded = EyeStripInferenceEngine.loadBundled()
        inferenceEngine = loaded.engine
        modelStatus = loaded.status
        didAttemptModelLoad = true
    }

    private func setupState(
        faces: [VNFaceObservation],
        face: VNFaceObservation?,
        prediction: EyeStripPrediction?,
        luma: Double?
    ) -> SetupState {
        guard faces.count == 1, let face else { return .unknown }
        guard face.boundingBox.minX >= 0.01, face.boundingBox.minY >= 0.01,
              face.boundingBox.maxX <= 0.99, face.boundingBox.maxY <= 0.99 else {
            return .misaligned
        }
        if let luma, luma < 0.18 || luma > 0.92 { return .stabilizing }
        let width = face.boundingBox.width
        if width < 0.23 { return .tooFar }
        if width > 0.52 { return .tooClose }

        let centerX = face.boundingBox.midX
        let centerYTopLeft = 1 - face.boundingBox.midY
        guard abs(centerX - 0.5) <= 0.10,
              abs(centerYTopLeft - 0.5) <= 0.10 else {
            return .misaligned
        }
        if let yaw = face.yaw?.doubleValue, abs(yaw) > 0.22 {
            return yaw > 0 ? .turnRight : .turnLeft
        }
        if let pitch = face.pitch?.doubleValue, abs(pitch) > 0.22 {
            return pitch > 0 ? .lookUp : .lookDown
        }
        if let roll = face.roll?.doubleValue, abs(roll) > 0.20 {
            return .misaligned
        }
        guard let prediction,
              prediction.xScreenCentered.isFinite,
              prediction.yScreenCentered.isFinite else {
            return .stabilizing
        }
        return .ready
    }

    private func captureRejection(
        faces: [VNFaceObservation],
        face: VNFaceObservation?,
        luma: Double?,
        prediction: EyeStripPrediction?,
        setup: SetupState
    ) -> String? {
        if faces.isEmpty { return "the face was not detected" }
        if faces.count > 1 { return "multiple faces were visible" }
        guard let face else { return "the face was not detected" }
        if face.boundingBox.minX < 0.01 || face.boundingBox.minY < 0.01 ||
            face.boundingBox.maxX > 0.99 || face.boundingBox.maxY > 0.99 {
            return "the face left the camera frame"
        }
        if let luma, luma < 0.18 { return "lighting was too dim" }
        if let luma, luma > 0.92 { return "lighting was overexposed" }
        switch setup {
        case .tooFar: return "the face was too far away"
        case .tooClose: return "the face was too close"
        case .misaligned, .lookUp, .lookDown, .turnLeft, .turnRight:
            return "the face was not aligned with the screen"
        case .unknown, .movingTooMuch, .stabilizing, .ready:
            break
        }
        guard let prediction,
              prediction.xScreenCentered.isFinite,
              prediction.yScreenCentered.isFinite else {
            return "the model lost one or both eye regions"
        }
        return nil
    }

    private func averageLuma(_ pixelBuffer: CVPixelBuffer) -> Double? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let samplingStride = 16
        var sum: UInt64 = 0
        var count: UInt64 = 0

        if CVPixelBufferIsPlanar(pixelBuffer), CVPixelBufferGetPlaneCount(pixelBuffer) > 0,
           let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) {
            let bytes = base.assumingMemoryBound(to: UInt8.self)
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            let planeWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
            let planeHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
            for y in Swift.stride(from: 0, to: planeHeight, by: samplingStride) {
                for x in Swift.stride(from: 0, to: planeWidth, by: samplingStride) {
                    sum += UInt64(bytes[y * bytesPerRow + x])
                    count += 1
                }
            }
        } else if CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA,
                  let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            let bytes = base.assumingMemoryBound(to: UInt8.self)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            for y in Swift.stride(from: 0, to: height, by: samplingStride) {
                for x in Swift.stride(from: 0, to: width, by: samplingStride) {
                    let offset = y * bytesPerRow + x * 4
                    let blue = UInt64(bytes[offset])
                    let green = UInt64(bytes[offset + 1])
                    let red = UInt64(bytes[offset + 2])
                    sum += (54 * red + 183 * green + 19 * blue) / 256
                    count += 1
                }
            }
        }
        guard count > 0 else { return nil }
        return Double(sum) / Double(count) / 255
    }
}

/// Volatile, setup-only view of the same oriented front-camera frames used by Vision.
final class PaddyCameraPreviewView: UIView {
    private static let setupPreviewZoom: CGFloat = 1.5
    private let imageView = UIImageView()
    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.transform = CGAffineTransform(
            scaleX: Self.setupPreviewZoom,
            y: Self.setupPreviewZoom
        )
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = "Starting camera…"
        messageLabel.textColor = .white
        messageLabel.font = .preferredFont(forTextStyle: .headline)
        messageLabel.textAlignment = .center
        addSubview(imageView)
        addSubview(messageLabel)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func display(_ image: CGImage) {
        imageView.image = UIImage(cgImage: image)
        messageLabel.text = nil
    }

    func clear() {
        imageView.image = nil
        messageLabel.text = "Starting camera…"
    }
}

/// ARKit remains the single camera owner so the existing patch check can keep
/// using blink coefficients. Gaze never uses ARKit eye transforms or lookAtPoint;
/// every gaze estimate is produced from `ARFrame.capturedImage` by Vision/Core ML.
final class PaddyGazeRuntime: NSObject, ARSessionDelegate, @unchecked Sendable {
    var onAnalysis: (@Sendable (PaddyFrameAnalysis) -> Void)?
    var onFailure: (@Sendable (Error) -> Void)?

    let previewView = PaddyCameraPreviewView(frame: .zero)

    private let sessionLock = NSLock()
    private var session: ARSession?
    private let orientationLock = NSLock()
    private var imageOrientation: CGImagePropertyOrientation = .up
    private let analyzer = PaddyVisionFrameAnalyzer()
    private let delegateQueue = DispatchQueue(
        label: "com.drstrange.paddy.gazetrack",
        qos: .userInteractive
    )
    private lazy var frameProcessor = PaddyLatestFrameProcessor<PaddyCapturedFrame> {
        [weak self] frame in
        guard let self else { return }
        let analysis = await self.analyzer.analyze(frame)
        self.onAnalysis?(analysis)
    }
    private var orientationObserver: NSObjectProtocol?

    override init() {
        super.init()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshInterfaceOrientation()
        }
        refreshInterfaceOrientation()
    }

    deinit {
        if let orientationObserver {
            NotificationCenter.default.removeObserver(orientationObserver)
        }
        releaseSession()
    }

    func start(reset: Bool) async throws {
        guard ARFaceTrackingConfiguration.isSupported else {
            throw GazeTrackerError.unsupported
        }
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

        await MainActor.run { refreshInterfaceOrientation() }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        let options: ARSession.RunOptions = reset ? [.resetTracking, .removeExistingAnchors] : []
        let session = makeSession()
        session.run(configuration, options: options)
    }

    func pause() {
        releaseSession()
    }

    func setPreviewEnabled(_ enabled: Bool) {
        Task { await analyzer.setPreviewEnabled(enabled) }
    }

    func stop() {
        releaseSession()
        previewView.clear()
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isCurrentSession(session) else { return }
        let availability = frame.anchors
            .compactMap { $0 as? ARFaceAnchor }
            .first(where: \.isTracked)
            .map(Self.eyeAvailability) ?? .none
        let captured = PaddyCapturedFrame(
            pixelBuffer: frame.capturedImage,
            hostUptime: frame.timestamp,
            imageOrientation: currentImageOrientation(),
            eyeAvailability: availability,
            ambientIntensity: frame.lightEstimate.map { Double($0.ambientIntensity) }
        )
        Task { await frameProcessor.submit(captured) }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        onFailure?(error)
    }

    func sessionWasInterrupted(_ session: ARSession) {
        onFailure?(GazeTrackerError.runtimeFailure)
    }

    private func makeSession() -> ARSession {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        if let session { return session }
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
        released?.pause()
        released?.delegate = nil
    }

    private func isCurrentSession(_ candidate: ARSession) -> Bool {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        return session === candidate
    }

    private func currentImageOrientation() -> CGImagePropertyOrientation {
        orientationLock.lock()
        defer { orientationLock.unlock() }
        return imageOrientation
    }

    private func refreshInterfaceOrientation() {
        let interfaceOrientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .interfaceOrientation ?? .landscapeRight
        // `ARFrame.capturedImage` already follows the front-camera mirrored
        // presentation used by this project. Rotate it into the interface, but
        // do not mirror a second time. Vision and Core ML consume this same image.
        let next: CGImagePropertyOrientation = switch interfaceOrientation {
        case .landscapeLeft: .down
        case .landscapeRight: .up
        case .portrait: .left
        case .portraitUpsideDown: .right
        default: .up
        }
        orientationLock.lock()
        imageOrientation = next
        orientationLock.unlock()
    }

    private static func eyeAvailability(_ face: ARFaceAnchor) -> EyeAvailability {
        // ARKit's front-camera labels are mirrored relative to anatomical eyes.
        let anatomicalRightBlink = Double(face.blendShapes[.eyeBlinkLeft]?.floatValue ?? 1)
        let anatomicalLeftBlink = Double(face.blendShapes[.eyeBlinkRight]?.floatValue ?? 1)
        let rightOpen = anatomicalRightBlink.isFinite && anatomicalRightBlink < 0.70
        let leftOpen = anatomicalLeftBlink.isFinite && anatomicalLeftBlink < 0.70
        return switch (leftOpen, rightOpen) {
        case (true, true): .both
        case (true, false): .leftOnly
        case (false, true): .rightOnly
        case (false, false): .none
        }
    }
}
