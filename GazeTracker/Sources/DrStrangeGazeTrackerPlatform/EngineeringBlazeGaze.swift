#if canImport(CoreML) && canImport(MediaPipeTasksVision) && canImport(UIKit) && os(iOS)
import CoreImage
import CoreML
import CoreVideo
import Foundation
import ImageIO
import MediaPipeTasksVision
import UIKit

@_spi(Engineering)
public enum GazeBlazeGazeState: String, Equatable, Sendable {
    case inactive
    case initializing
    case awaitingFace
    case predicting
    case missingAssets
    case failed
}

@_spi(Engineering)
public struct GazeBlazeGazeStatus: Equatable, Sendable {
    public let state: GazeBlazeGazeState
    public let attemptedFrameCount: Int
    public let predictedFrameCount: Int
    public let latestRawPoint: CGPoint?
    public let latestCorrectedPoint: CGPoint?
    public let latestLatencyMilliseconds: Double?
    public let p90LatencyMilliseconds: Double?
    public let calibrationPointCount: Int
    public let isCalibrated: Bool
    public let detail: String
}

@_spi(Engineering)
public struct GazeBlazeGazeValidationSummary: Equatable, Sendable {
    public let condition: String
    public let fixationCount: Int
    public let medianRadiusCentimeters: Double?
    public let p90RadiusCentimeters: Double?
    public let worstRadiusCentimeters: Double?
}

/// Engineering-only control surface for the BlazeGaze shadow candidate. It
/// stores points and aggregate timings only; camera frames and eye strips stay
/// inside the volatile processing path.
@_spi(Engineering)
public final class GazeBlazeGazeConfiguration: @unchecked Sendable {
    let faceLandmarkerModelURL: URL?
    let gazeModelURL: URL?
    private let lock = NSLock()
    private var state: GazeBlazeGazeState = .inactive
    private var attempts = 0
    private var predictions = 0
    private var latestRawPoint: CGPoint?
    private var latestCorrectedPoint: CGPoint?
    private var latestLatency: Double?
    private var recentLatencies: [Double] = []
    private var calibrationPairs: [BlazeGazeCalibrationPair] = []
    private var activeCalibrationTarget: CGPoint?
    private var activeTargetObservations: [CGPoint] = []
    private var correction = BlazeGazeRBFCorrection()
    private var validationCondition: String?
    private var activeValidationTarget: CGPoint?
    private var activeValidationObservations: [CGPoint] = []
    private var validationErrorsCentimeters: [Double] = []
    private var validationSummaries: [GazeBlazeGazeValidationSummary] = []
    private var detail = "Start the camera to load BlazeGaze"

    init(bundle: Bundle = .main) {
        faceLandmarkerModelURL = bundle.url(forResource: "face_landmarker", withExtension: "task")
        gazeModelURL = bundle.url(forResource: "blazegaze", withExtension: "mlmodelc")
    }

    public func status() -> GazeBlazeGazeStatus {
        lock.lock()
        defer { lock.unlock() }
        return GazeBlazeGazeStatus(
            state: state,
            attemptedFrameCount: attempts,
            predictedFrameCount: predictions,
            latestRawPoint: latestRawPoint,
            latestCorrectedPoint: latestCorrectedPoint,
            latestLatencyMilliseconds: latestLatency,
            p90LatencyMilliseconds: Self.percentile(recentLatencies, fraction: 0.90),
            calibrationPointCount: calibrationPairs.count,
            isCalibrated: correction.isFitted,
            detail: detail
        )
    }

    public func beginCalibrationTarget(x: Double, y: Double) {
        lock.lock()
        activeCalibrationTarget = CGPoint(x: x, y: y)
        activeTargetObservations.removeAll()
        lock.unlock()
    }

    public func finishCalibrationTarget() {
        lock.lock()
        defer { lock.unlock() }
        guard let target = activeCalibrationTarget else { return }
        defer {
            activeCalibrationTarget = nil
            activeTargetObservations.removeAll()
        }
        guard let observed = Self.robustMean(activeTargetObservations) else {
            detail = "Model calibration target had too few predictions"
            return
        }
        calibrationPairs.append(BlazeGazeCalibrationPair(observed: observed, target: target))
        _ = correction.fit(calibrationPairs)
        detail = correction.isFitted
            ? "BlazeGaze RBF fitted with \(calibrationPairs.count) targets"
            : "Collected \(calibrationPairs.count) BlazeGaze calibration targets"
    }

    public func resetCalibration() {
        lock.lock()
        calibrationPairs.removeAll()
        activeCalibrationTarget = nil
        activeTargetObservations.removeAll()
        correction.reset()
        validationCondition = nil
        activeValidationTarget = nil
        activeValidationObservations.removeAll()
        validationErrorsCentimeters.removeAll()
        validationSummaries.removeAll()
        latestCorrectedPoint = latestRawPoint
        lock.unlock()
    }

    public func beginValidationPass(condition: String) {
        lock.lock()
        validationCondition = condition
        activeValidationTarget = nil
        activeValidationObservations.removeAll()
        validationErrorsCentimeters.removeAll()
        lock.unlock()
    }

    public func beginValidationTarget(x: Double, y: Double) {
        lock.lock()
        guard validationCondition != nil else {
            lock.unlock()
            return
        }
        activeValidationTarget = CGPoint(x: x, y: y)
        activeValidationObservations.removeAll()
        lock.unlock()
    }

    public func finishValidationTarget() {
        lock.lock()
        defer { lock.unlock() }
        guard
            let target = activeValidationTarget,
            let observed = Self.robustMean(activeValidationObservations)
        else {
            activeValidationTarget = nil
            activeValidationObservations.removeAll()
            return
        }
        let widthMeters = 0.26216
        let heightMeters = 0.19662
        let radiusMeters = hypot(
            (observed.x - target.x) * widthMeters,
            (observed.y - target.y) * heightMeters
        )
        validationErrorsCentimeters.append(radiusMeters * 100)
        activeValidationTarget = nil
        activeValidationObservations.removeAll()
    }

    @discardableResult
    public func finishValidationPass() -> GazeBlazeGazeValidationSummary? {
        lock.lock()
        defer { lock.unlock() }
        guard let condition = validationCondition else { return nil }
        let sorted = validationErrorsCentimeters.sorted()
        let summary = GazeBlazeGazeValidationSummary(
            condition: condition,
            fixationCount: sorted.count,
            medianRadiusCentimeters: Self.percentile(sorted, fraction: 0.5),
            p90RadiusCentimeters: Self.percentile(sorted, fraction: 0.9),
            worstRadiusCentimeters: sorted.last
        )
        validationSummaries.append(summary)
        validationCondition = nil
        activeValidationTarget = nil
        activeValidationObservations.removeAll()
        validationErrorsCentimeters.removeAll()
        return summary
    }

    public func completedValidationSummaries() -> [GazeBlazeGazeValidationSummary] {
        lock.lock()
        defer { lock.unlock() }
        return validationSummaries
    }

    func recordInitializing() {
        lock.lock()
        state = .initializing
        attempts = 0
        predictions = 0
        latestRawPoint = nil
        latestCorrectedPoint = nil
        latestLatency = nil
        recentLatencies.removeAll()
        detail = "Loading MediaPipe and BlazeGaze"
        lock.unlock()
    }

    func recordReady() {
        lock.lock()
        state = .awaitingFace
        detail = "Exact 478-point preprocessing ready"
        lock.unlock()
    }

    func recordMissingAssets() {
        lock.lock()
        state = .missingAssets
        detail = "face_landmarker.task or blazegaze.mlmodelc is missing"
        lock.unlock()
    }

    func recordFailure(_ message: String) {
        lock.lock()
        state = .failed
        detail = message
        lock.unlock()
    }

    func recordNoFace(latencyMilliseconds: Double) {
        lock.lock()
        attempts += 1
        state = .awaitingFace
        recordLatencyLocked(latencyMilliseconds)
        detail = "MediaPipe is looking for one face"
        lock.unlock()
    }

    func recordPrediction(_ point: CGPoint, latencyMilliseconds: Double) -> CGPoint {
        lock.lock()
        attempts += 1
        predictions += 1
        state = .predicting
        latestRawPoint = point
        if activeCalibrationTarget != nil { activeTargetObservations.append(point) }
        let corrected = correction.correct(point)
        if activeValidationTarget != nil { activeValidationObservations.append(corrected) }
        latestCorrectedPoint = corrected
        recordLatencyLocked(latencyMilliseconds)
        detail = correction.isFitted ? "RBF-corrected BlazeGaze shadow" : "Raw BlazeGaze shadow"
        lock.unlock()
        return corrected
    }

    func recordInactive() {
        lock.lock()
        state = .inactive
        activeCalibrationTarget = nil
        activeTargetObservations.removeAll()
        validationCondition = nil
        activeValidationTarget = nil
        activeValidationObservations.removeAll()
        validationErrorsCentimeters.removeAll()
        validationSummaries.removeAll()
        latestRawPoint = nil
        latestCorrectedPoint = nil
        detail = "Stopped; volatile model input cleared"
        lock.unlock()
    }

    private func recordLatencyLocked(_ latency: Double) {
        latestLatency = latency
        recentLatencies.append(latency)
        if recentLatencies.count > 240 {
            recentLatencies.removeFirst(recentLatencies.count - 240)
        }
    }

    private static func robustMean(_ points: [CGPoint]) -> CGPoint? {
        guard points.count >= 3 else { return nil }
        let sortedX = points.map(\.x).sorted()
        let sortedY = points.map(\.y).sorted()
        let median = CGPoint(x: sortedX[sortedX.count / 2], y: sortedY[sortedY.count / 2])
        let distances = points.map { hypot($0.x - median.x, $0.y - median.y) }.sorted()
        let medianDistance = distances[distances.count / 2]
        let limit = max(0.015, medianDistance * 3)
        let retained = points.filter { hypot($0.x - median.x, $0.y - median.y) <= limit }
        guard retained.count >= 3 else { return nil }
        return CGPoint(
            x: retained.reduce(0) { $0 + $1.x } / CGFloat(retained.count),
            y: retained.reduce(0) { $0 + $1.y } / CGFloat(retained.count)
        )
    }

    private static func percentile(_ values: [Double], fraction: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, Int(ceil(Double(sorted.count) * fraction)) - 1)
        return sorted[max(0, index)]
    }
}

final class VolatileBlazeGazePreview: UIView {
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
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        show(message: "Start the camera to load the model")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func display(_ image: CGImage) {
        imageView.image = UIImage(cgImage: image)
        messageLabel.text = nil
    }

    func show(message: String) {
        imageView.image = nil
        messageLabel.text = message
    }
}

final class BlazeGazeShadowProcessor {
    private let configuration: GazeBlazeGazeConfiguration
    private weak var preview: VolatileBlazeGazePreview?
    private let queue = DispatchQueue(label: "com.drstrange.gaze.blazegaze", qos: .userInitiated)
    private let stateLock = NSLock()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var active = false
    private var generation = 0
    private var processing = false
    private var ready = false
    private var lastScheduledTimestamp: TimeInterval = -.infinity
    private var orientation: CGImagePropertyOrientation = .up
    private var landmarker: FaceLandmarker?
    private var runner: BlazeGazeCoreMLRunner?

    init(configuration: GazeBlazeGazeConfiguration, preview: VolatileBlazeGazePreview) {
        self.configuration = configuration
        self.preview = preview
    }

    func start(orientation: CGImagePropertyOrientation) {
        stateLock.lock()
        generation += 1
        let currentGeneration = generation
        active = true
        ready = false
        processing = false
        lastScheduledTimestamp = -.infinity
        self.orientation = orientation
        stateLock.unlock()
        configuration.recordInitializing()
        DispatchQueue.main.async { [weak preview] in preview?.show(message: "Loading BlazeGaze…") }
        queue.async { [weak self] in self?.initialize(generation: currentGeneration) }
    }

    func stop() {
        stateLock.lock()
        generation += 1
        active = false
        ready = false
        processing = false
        stateLock.unlock()
        queue.async { [weak self] in
            self?.landmarker = nil
            self?.runner = nil
        }
        configuration.recordInactive()
        DispatchQueue.main.async { [weak preview] in
            preview?.show(message: "Eye strip cleared — nothing is stored")
        }
    }

    func process(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        let currentGeneration: Int
        let currentOrientation: CGImagePropertyOrientation
        stateLock.lock()
        guard active, ready, !processing, timestamp - lastScheduledTimestamp >= 0.10 else {
            stateLock.unlock()
            return
        }
        processing = true
        lastScheduledTimestamp = timestamp
        currentGeneration = generation
        currentOrientation = orientation
        stateLock.unlock()
        queue.async { [weak self] in
            self?.runFrame(
                pixelBuffer: pixelBuffer,
                timestamp: timestamp,
                orientation: currentOrientation,
                generation: currentGeneration
            )
        }
    }

    private func initialize(generation: Int) {
        guard
            let faceModelURL = configuration.faceLandmarkerModelURL,
            let gazeModelURL = configuration.gazeModelURL
        else {
            configuration.recordMissingAssets()
            complete(generation: generation)
            DispatchQueue.main.async { [weak preview] in preview?.show(message: "Model assets missing") }
            return
        }
        do {
            let options = FaceLandmarkerOptions()
            options.baseOptions.modelAssetPath = faceModelURL.path
            options.runningMode = .video
            options.numFaces = 1
            options.minFaceDetectionConfidence = 0.5
            options.minFacePresenceConfidence = 0.5
            options.minTrackingConfidence = 0.5
            options.outputFaceBlendshapes = false
            options.outputFacialTransformationMatrixes = true
            let landmarker = try FaceLandmarker(options: options)
            let runner = try BlazeGazeCoreMLRunner(modelURL: gazeModelURL)
            stateLock.lock()
            let canStart = active && self.generation == generation
            if canStart {
                self.landmarker = landmarker
                self.runner = runner
                ready = true
            }
            stateLock.unlock()
            guard canStart else { return }
            configuration.recordReady()
            DispatchQueue.main.async { [weak preview] in preview?.show(message: "Looking for a face…") }
        } catch {
            configuration.recordFailure("Model initialization failed: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak preview] in preview?.show(message: "Model initialization failed") }
        }
    }

    private func runFrame(
        pixelBuffer: CVPixelBuffer,
        timestamp: TimeInterval,
        orientation: CGImagePropertyOrientation,
        generation: Int
    ) {
        let startedAt = ProcessInfo.processInfo.systemUptime
        do {
            guard let orientedBuffer = makeOrientedBGRABuffer(from: pixelBuffer, orientation: orientation) else {
                throw BlazeGazeShadowError.imageConversion
            }
            guard let landmarker, let runner else { throw BlazeGazeShadowError.notReady }
            let image = try MPImage(pixelBuffer: orientedBuffer)
            let timestampMilliseconds = Int(timestamp * 1_000)
            let result = try landmarker.detect(
                videoFrame: image,
                timestampInMilliseconds: timestampMilliseconds
            )
            guard let face = result.faceLandmarks.first, face.count >= 468 else {
                configuration.recordNoFace(
                    latencyMilliseconds: (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
                )
                DispatchQueue.main.async { [weak preview] in preview?.show(message: "No face found") }
                complete(generation: generation)
                return
            }
            let landmarks = face.map { [Double($0.x), Double($0.y), Double($0.z)] }
            guard let eyePatch = BlazeGazeEyePatchExtractor.extract(
                pixelBuffer: orientedBuffer,
                landmarks: landmarks
            ) else { throw BlazeGazeShadowError.eyePatch }
            let rotation = Self.rotationMatrix(from: result.facialTransformationMatrixes.first)
            let headVector = Self.headVector(from: rotation)
            let faceOrigin = BlazeGazeMetricFaceOrigin.compute(
                landmarks: landmarks,
                width: CVPixelBufferGetWidth(orientedBuffer),
                height: CVPixelBufferGetHeight(orientedBuffer),
                rotation: rotation
            )
            guard let point = runner.predict(
                eyePatch: eyePatch,
                headVector: headVector,
                faceOrigin: faceOrigin
            ) else { throw BlazeGazeShadowError.prediction }
            let latency = (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
            _ = configuration.recordPrediction(point, latencyMilliseconds: latency)
            if let image = context.createCGImage(CIImage(cvPixelBuffer: eyePatch), from: CGRect(
                x: 0,
                y: 0,
                width: BlazeGazeEyePatchExtractor.patchWidth,
                height: BlazeGazeEyePatchExtractor.patchHeight
            )) {
                DispatchQueue.main.async { [weak preview] in preview?.display(image) }
            }
        } catch {
            configuration.recordFailure("BlazeGaze frame failed: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak preview] in preview?.show(message: "BlazeGaze frame failed") }
        }
        complete(generation: generation)
    }

    private func complete(generation: Int) {
        stateLock.lock()
        if self.generation == generation { processing = false }
        stateLock.unlock()
    }

    private func makeOrientedBGRABuffer(
        from source: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) -> CVPixelBuffer? {
        let image = CIImage(cvPixelBuffer: source).oriented(orientation)
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }
        var output: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(extent.width),
            Int(extent.height),
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &output
        )
        guard let output else { return nil }
        let translated = image.transformed(by: CGAffineTransform(
            translationX: -extent.minX,
            y: -extent.minY
        ))
        context.render(translated, to: output)
        return output
    }

    private static func rotationMatrix(from transform: TransformMatrix?) -> [[Double]]? {
        guard let transform, transform.rows >= 3, transform.columns >= 3 else { return nil }
        return (0..<3).map { row in
            (0..<3).map { column in Double(transform.value(atRow: row, column: column)) }
        }
    }

    private static func headVector(from rotation: [[Double]]?) -> [Float] {
        guard let rotation else { return [0, 0, -1] }
        let pitch = asin(max(-1, min(1, -rotation[2][0])))
        let yaw = atan2(rotation[2][1], rotation[2][2])
        let headPitch = -yaw
        let headYaw = pitch
        return [
            Float(cos(headPitch) * sin(headYaw)),
            Float(sin(headPitch)),
            Float(-cos(headPitch) * cos(headYaw))
        ]
    }
}

private final class BlazeGazeCoreMLRunner {
    private let model: MLModel

    init(modelURL: URL) throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        model = try MLModel(contentsOf: modelURL, configuration: configuration)
    }

    func predict(
        eyePatch: CVPixelBuffer,
        headVector: [Float],
        faceOrigin: [Float]
    ) -> CGPoint? {
        guard
            let image = Self.imageArray(from: eyePatch),
            let head = Self.vectorArray(headVector),
            let origin = Self.vectorArray(faceOrigin),
            let input = try? MLDictionaryFeatureProvider(dictionary: [
                "image": MLFeatureValue(multiArray: image),
                "head_vector": MLFeatureValue(multiArray: head),
                "face_origin_3d": MLFeatureValue(multiArray: origin)
            ]),
            let output = try? model.prediction(from: input),
            let featureName = output.featureNames.first,
            let values = output.featureValue(for: featureName)?.multiArrayValue,
            values.count >= 2
        else { return nil }
        let point = CGPoint(x: values[0].doubleValue, y: values[1].doubleValue)
        return point.x.isFinite && point.y.isFinite ? point : nil
    }

    private static func vectorArray(_ values: [Float]) -> MLMultiArray? {
        guard values.count == 3, let array = try? MLMultiArray(shape: [1, 3], dataType: .float32) else {
            return nil
        }
        let pointer = array.dataPointer.assumingMemoryBound(to: Float.self)
        for index in 0..<3 { pointer[index] = values[index] }
        return array
    }

    private static func imageArray(from buffer: CVPixelBuffer) -> MLMultiArray? {
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        guard
            width == BlazeGazeEyePatchExtractor.patchWidth,
            height == BlazeGazeEyePatchExtractor.patchHeight,
            let array = try? MLMultiArray(
                shape: [1, NSNumber(value: height), NSNumber(value: width), 3],
                dataType: .float32
            )
        else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let source = base.assumingMemoryBound(to: UInt8.self)
        let destination = array.dataPointer.assumingMemoryBound(to: Float.self)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<height {
            for x in 0..<width {
                let sourceIndex = y * rowBytes + x * 4
                let destinationIndex = (y * width + x) * 3
                destination[destinationIndex] = Float(source[sourceIndex + 2]) / 255
                destination[destinationIndex + 1] = Float(source[sourceIndex + 1]) / 255
                destination[destinationIndex + 2] = Float(source[sourceIndex]) / 255
            }
        }
        return array
    }
}

private enum BlazeGazeShadowError: LocalizedError {
    case notReady
    case imageConversion
    case eyePatch
    case prediction

    var errorDescription: String? {
        switch self {
        case .notReady: "pipeline not ready"
        case .imageConversion: "camera image conversion failed"
        case .eyePatch: "eye-strip extraction failed"
        case .prediction: "Core ML prediction failed"
        }
    }
}
#endif
