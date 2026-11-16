import Foundation

#if canImport(ARKit) && canImport(CoreImage) && canImport(UIKit) && os(iOS)
import ARKit
import CoreImage
import UIKit

/// Volatile preview rendered directly from `ARFrame.capturedImage`.
/// It keeps the camera display on the same tracker-owned session without
/// introducing a second renderer or capture path.
final class VolatileCameraFramePreview: UIView {
    private let imageView = UIImageView()
    private let telemetryLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        telemetryLabel.translatesAutoresizingMaskIntoConstraints = false
        telemetryLabel.textColor = .white
        telemetryLabel.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        telemetryLabel.backgroundColor = UIColor.black.withAlphaComponent(0.68)
        telemetryLabel.layer.cornerRadius = 8
        telemetryLabel.layer.masksToBounds = true
        telemetryLabel.textAlignment = .center

        addSubview(imageView)
        addSubview(telemetryLabel)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            telemetryLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            telemetryLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            telemetryLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            telemetryLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
        show(message: "Starting camera…")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func display(_ image: CGImage) {
        imageView.image = UIImage(cgImage: image)
        telemetryLabel.isHidden = true
    }

    func show(message: String) {
        imageView.image = nil
        telemetryLabel.isHidden = false
        telemetryLabel.text = "  \(message)  "
    }
}

final class CameraFramePreviewProcessor {
    private static let minimumFrameInterval: TimeInterval = 1.0 / 30.0

    private let queue = DispatchQueue(
        label: "com.drstrange.gaze.camera-frame-preview",
        qos: .userInitiated
    )
    private let context = CIContext(options: [.cacheIntermediates: false])
    private weak var preview: VolatileCameraFramePreview?
    private let stateLock = NSLock()
    private var active = false
    private var processing = false
    private var generation = 0
    private var lastScheduledTimestamp: TimeInterval = -.infinity
    private var orientation: CGImagePropertyOrientation = .up

    init(preview: VolatileCameraFramePreview) {
        self.preview = preview
    }

    func start(orientation: CGImagePropertyOrientation) {
        stateLock.lock()
        generation += 1
        active = true
        processing = false
        lastScheduledTimestamp = -.infinity
        self.orientation = orientation
        stateLock.unlock()
        DispatchQueue.main.async { [weak preview] in
            preview?.show(message: "Starting camera…")
        }
    }

    func stop() {
        stateLock.lock()
        generation += 1
        active = false
        processing = false
        stateLock.unlock()
        DispatchQueue.main.async { [weak preview] in
            preview?.show(message: "Camera stopped")
        }
    }

    func process(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        let currentGeneration: Int
        let currentOrientation: CGImagePropertyOrientation
        stateLock.lock()
        guard
            active,
            !processing,
            timestamp - lastScheduledTimestamp >= Self.minimumFrameInterval
        else {
            stateLock.unlock()
            return
        }
        processing = true
        lastScheduledTimestamp = timestamp
        currentGeneration = generation
        currentOrientation = orientation
        stateLock.unlock()

        queue.async { [weak self] in
            guard let self else { return }
            let oriented = CIImage(cvPixelBuffer: pixelBuffer).oriented(currentOrientation)
            let extent = oriented.extent.integral
            let maximumEdge = max(extent.width, extent.height)
            let scale = maximumEdge > 720 ? 720 / maximumEdge : 1
            let scaled = oriented
                .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let outputRect = CGRect(
                x: 0,
                y: 0,
                width: extent.width * scale,
                height: extent.height * scale
            ).integral
            let image = self.context.createCGImage(scaled, from: outputRect)
            self.complete(image: image, generation: currentGeneration)
        }
    }

    private func complete(image: CGImage?, generation completedGeneration: Int) {
        stateLock.lock()
        let canPublish = active && generation == completedGeneration
        if generation == completedGeneration { processing = false }
        stateLock.unlock()
        guard canPublish else { return }
        DispatchQueue.main.async { [weak preview] in
            guard let image else {
                preview?.show(message: "Camera preview unavailable")
                return
            }
            preview?.display(image)
        }
    }
}
#endif
