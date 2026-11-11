import CoreGraphics
import Foundation
import ImageIO

@_spi(Engineering)
public enum GazeFaceIsolationState: String, Equatable, Sendable {
    case inactive
    case disabled
    case awaitingFace
    case faceIsolated
    case faceNotFound
    case failed
}

@_spi(Engineering)
public struct GazeFaceIsolationStatus: Equatable, Sendable {
    public let state: GazeFaceIsolationState
    public let attemptedFrameCount: Int
    public let detectedFrameCount: Int
    public let detectionRate: Double?
    public let latestProcessingLatencyMilliseconds: Double?
    public let p90ProcessingLatencyMilliseconds: Double?
    public let sourceCropEdgePixels: Int?
    public let sourcePixelFractionRetained: Double?
    public let outputEdgePixels: Int
}

/// Engineering-only control and aggregate telemetry for the volatile face-crop
/// assessment. Camera frames and crops never enter this value or the public gaze
/// sample contract.
@_spi(Engineering)
public final class GazeFaceIsolationConfiguration: @unchecked Sendable {
    private let lock = NSLock()
    private var enabled = true
    private var enabledChangeHandler: ((Bool) -> Void)?
    private var state: GazeFaceIsolationState = .inactive
    private var attemptedFrameCount = 0
    private var detectedFrameCount = 0
    private var latestLatency: Double?
    private var recentLatencies: [Double] = []
    private var sourceCropEdgePixels: Int?
    private var sourcePixelFractionRetained: Double?

    public var isEnabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return enabled
        }
        set {
            let handler: ((Bool) -> Void)?
            lock.lock()
            guard enabled != newValue else {
                lock.unlock()
                return
            }
            enabled = newValue
            state = newValue ? .awaitingFace : .disabled
            handler = enabledChangeHandler
            lock.unlock()
            handler?(newValue)
        }
    }

    public func status() -> GazeFaceIsolationStatus {
        lock.lock()
        defer { lock.unlock() }
        let detectionRate = attemptedFrameCount > 0
            ? Double(detectedFrameCount) / Double(attemptedFrameCount)
            : nil
        return GazeFaceIsolationStatus(
            state: state,
            attemptedFrameCount: attemptedFrameCount,
            detectedFrameCount: detectedFrameCount,
            detectionRate: detectionRate,
            latestProcessingLatencyMilliseconds: latestLatency,
            p90ProcessingLatencyMilliseconds: Self.percentile(recentLatencies, fraction: 0.90),
            sourceCropEdgePixels: sourceCropEdgePixels,
            sourcePixelFractionRetained: sourcePixelFractionRetained,
            outputEdgePixels: FaceIsolationCropGeometry.outputEdgePixels
        )
    }

    func setEnabledChangeHandler(_ handler: @escaping (Bool) -> Void) {
        lock.lock()
        enabledChangeHandler = handler
        lock.unlock()
    }

    func recordStarted() {
        lock.lock()
        state = enabled ? .awaitingFace : .disabled
        attemptedFrameCount = 0
        detectedFrameCount = 0
        latestLatency = nil
        recentLatencies = []
        sourceCropEdgePixels = nil
        sourcePixelFractionRetained = nil
        lock.unlock()
    }

    func recordInactive() {
        lock.lock()
        state = .inactive
        lock.unlock()
    }

    func recordAttempt(
        detected: Bool,
        latencyMilliseconds: Double,
        cropEdgePixels: Int? = nil,
        sourcePixelFractionRetained: Double? = nil,
        failed: Bool = false
    ) {
        lock.lock()
        attemptedFrameCount += 1
        if detected { detectedFrameCount += 1 }
        latestLatency = latencyMilliseconds
        recentLatencies.append(latencyMilliseconds)
        if recentLatencies.count > 240 {
            recentLatencies.removeFirst(recentLatencies.count - 240)
        }
        if let cropEdgePixels { self.sourceCropEdgePixels = cropEdgePixels }
        if let sourcePixelFractionRetained {
            self.sourcePixelFractionRetained = sourcePixelFractionRetained
        }
        state = failed ? .failed : (detected ? .faceIsolated : .faceNotFound)
        lock.unlock()
    }

    private static func percentile(_ values: [Double], fraction: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, Int(ceil(Double(sorted.count) * fraction)) - 1)
        return sorted[max(0, index)]
    }
}

enum FaceIsolationCropGeometry {
    static let paddingScale = 1.35
    static let outputEdgePixels = 224

    static func squareCrop(around face: CGRect, inside extent: CGRect) -> CGRect? {
        guard face.width > 0, face.height > 0, extent.width > 0, extent.height > 0 else {
            return nil
        }
        let maximumEdge = floor(min(extent.width, extent.height))
        let edge = min(ceil(max(face.width, face.height) * paddingScale), maximumEdge)
        guard edge >= 1 else { return nil }
        let proposedX = face.midX - edge / 2
        let proposedY = face.midY - edge / 2
        let x = floor(min(max(proposedX, extent.minX), extent.maxX - edge))
        let y = floor(min(max(proposedY, extent.minY), extent.maxY - edge))
        return CGRect(x: x, y: y, width: edge, height: edge)
    }
}

/// The camera buffer is already presented as a front-camera image by ARKit.
/// Rotate it to the interface orientation without applying a second mirror.
/// This keeps the isolated crop visually consistent with the shared ARSCNView.
enum FaceIsolationDisplayOrientation {
    case landscapeLeft
    case landscapeRight
    case portrait
    case portraitUpsideDown

    var imagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .landscapeLeft: .down
        case .landscapeRight: .up
        case .portrait: .left
        case .portraitUpsideDown: .right
        }
    }
}

#if canImport(ARKit) && canImport(CoreImage) && canImport(UIKit) && canImport(Vision) && os(iOS)
import ARKit
import CoreImage
import UIKit
import Vision

final class VolatileFaceIsolationPreview: UIView {
    private let imageView = UIImageView()
    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.textColor = .secondaryLabel
        messageLabel.font = .preferredFont(forTextStyle: .caption1)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        addSubview(imageView)
        addSubview(messageLabel)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        show(message: "Start the camera to isolate a face")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func display(_ image: CGImage) {
        imageView.image = UIImage(cgImage: image)
        messageLabel.text = nil
    }

    func show(message: String) {
        imageView.image = nil
        messageLabel.text = message
    }
}

final class FaceIsolationProcessor {
    private struct Output {
        let image: CGImage
        let cropEdgePixels: Int
        let sourcePixelFractionRetained: Double
    }

    private let configuration: GazeFaceIsolationConfiguration
    private weak var preview: VolatileFaceIsolationPreview?
    private let queue = DispatchQueue(
        label: "com.drstrange.gaze.face-isolation",
        qos: .userInitiated
    )
    private let stateLock = NSLock()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var active = false
    private var generation = 0
    private var processing = false
    private var lastScheduledTimestamp: TimeInterval = -.infinity
    private var orientation: CGImagePropertyOrientation = .upMirrored

    init(
        configuration: GazeFaceIsolationConfiguration,
        preview: VolatileFaceIsolationPreview
    ) {
        self.configuration = configuration
        self.preview = preview
        configuration.setEnabledChangeHandler { [weak self] enabled in
            self?.enabledChanged(enabled)
        }
    }

    func start(orientation: CGImagePropertyOrientation) {
        stateLock.lock()
        generation += 1
        active = true
        processing = false
        lastScheduledTimestamp = -.infinity
        self.orientation = orientation
        stateLock.unlock()
        configuration.recordStarted()
        let enabled = configuration.isEnabled
        DispatchQueue.main.async { [weak preview] in
            preview?.show(message: enabled ? "Looking for a face…" : "Face isolation is off")
        }
    }

    func stop() {
        stateLock.lock()
        generation += 1
        active = false
        processing = false
        stateLock.unlock()
        configuration.recordInactive()
        DispatchQueue.main.async { [weak preview] in
            preview?.show(message: "Face crop cleared — nothing is stored")
        }
    }

    func process(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        guard configuration.isEnabled else { return }
        let currentGeneration: Int
        let currentOrientation: CGImagePropertyOrientation
        stateLock.lock()
        guard active, !processing, timestamp - lastScheduledTimestamp >= 0.10 else {
            stateLock.unlock()
            return
        }
        processing = true
        lastScheduledTimestamp = timestamp
        currentGeneration = generation
        currentOrientation = orientation
        stateLock.unlock()

        let scheduledAt = ProcessInfo.processInfo.systemUptime
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let output = try self.makeOutput(
                    from: pixelBuffer,
                    orientation: currentOrientation
                )
                self.complete(
                    output: output,
                    latencyMilliseconds: (ProcessInfo.processInfo.systemUptime - scheduledAt) * 1_000,
                    generation: currentGeneration,
                    failed: false
                )
            } catch {
                self.complete(
                    output: nil,
                    latencyMilliseconds: (ProcessInfo.processInfo.systemUptime - scheduledAt) * 1_000,
                    generation: currentGeneration,
                    failed: !(error is FaceNotFoundError)
                )
            }
        }
    }

    private func makeOutput(
        from pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) throws -> Output {
        let orientedImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(ciImage: orientedImage, orientation: .up)
        try handler.perform([request])
        guard let face = request.results?.max(by: {
            $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
        }) else {
            throw FaceNotFoundError()
        }

        let extent = orientedImage.extent
        let bounds = face.boundingBox
        let faceRect = CGRect(
            x: extent.minX + bounds.minX * extent.width,
            y: extent.minY + bounds.minY * extent.height,
            width: bounds.width * extent.width,
            height: bounds.height * extent.height
        )
        guard let cropRect = FaceIsolationCropGeometry.squareCrop(around: faceRect, inside: extent) else {
            throw FaceNotFoundError()
        }
        let outputEdge = CGFloat(FaceIsolationCropGeometry.outputEdgePixels)
        let scale = outputEdge / cropRect.width
        let normalizedCrop = orientedImage
            .cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -cropRect.minX, y: -cropRect.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let outputRect = CGRect(x: 0, y: 0, width: outputEdge, height: outputEdge)
        guard let image = context.createCGImage(normalizedCrop, from: outputRect) else {
            throw FaceIsolationRenderError()
        }
        return Output(
            image: image,
            cropEdgePixels: Int(cropRect.width.rounded()),
            sourcePixelFractionRetained: cropRect.width * cropRect.height / (extent.width * extent.height)
        )
    }

    private func complete(
        output: Output?,
        latencyMilliseconds: Double,
        generation completedGeneration: Int,
        failed: Bool
    ) {
        stateLock.lock()
        let canPublish = active && generation == completedGeneration && configuration.isEnabled
        if generation == completedGeneration { processing = false }
        stateLock.unlock()
        guard canPublish else { return }

        configuration.recordAttempt(
            detected: output != nil,
            latencyMilliseconds: latencyMilliseconds,
            cropEdgePixels: output?.cropEdgePixels,
            sourcePixelFractionRetained: output?.sourcePixelFractionRetained,
            failed: failed
        )
        DispatchQueue.main.async { [weak preview] in
            if let output {
                preview?.display(output.image)
            } else {
                preview?.show(message: failed ? "Face isolation failed" : "No face found")
            }
        }
    }

    private func enabledChanged(_ enabled: Bool) {
        DispatchQueue.main.async { [weak preview] in
            preview?.show(message: enabled ? "Looking for a face…" : "Face isolation is off")
        }
    }
}

private struct FaceNotFoundError: Error {}
private struct FaceIsolationRenderError: Error {}
#endif
