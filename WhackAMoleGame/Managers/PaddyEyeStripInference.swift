import CoreImage
import CoreML
import CoreVideo
import Foundation
import Vision

struct EyeStripPrediction: Equatable, Sendable {
    let xScreenCentered: Double
    let yScreenCentered: Double
    let inferenceDurationMS: Double
}

struct EyeStripCropGeometry: Equatable, Sendable {
    let normalizedRectVision: CGRect
    let metadata: [Float]
}

enum EyeStripInputGeometry {
    static let outputWidth = 55
    static let outputHeight = 25
    static let horizontalScale = 1.25
    static let heightToWidth = 0.45

    static func cropGeometry(
        leftEyePointsFaceNormBottomLeft: [CGPoint],
        rightEyePointsFaceNormBottomLeft: [CGPoint],
        faceRectVisionNorm face: CGRect,
        imageWidth: Int,
        imageHeight: Int
    ) -> EyeStripCropGeometry? {
        guard imageWidth > 0, imageHeight > 0,
              let leftCorners = horizontalExtrema(leftEyePointsFaceNormBottomLeft),
              let rightCorners = horizontalExtrema(rightEyePointsFaceNormBottomLeft)
        else { return nil }
        let points = (leftCorners + rightCorners).map { point in
            CGPoint(
                x: face.minX + point.x * face.width,
                y: face.minY + point.y * face.height
            )
        }
        guard let minimumX = points.map(\.x).min(),
              let maximumX = points.map(\.x).max()
        else { return nil }
        let centerX = (minimumX + maximumX) / 2
        let centerY = points.map(\.y).reduce(0, +) / CGFloat(points.count)
        let cropWidth = max(
            8 / CGFloat(imageWidth),
            (maximumX - minimumX) * horizontalScale
        )
        let cropHeight = max(
            6 / CGFloat(imageHeight),
            cropWidth * CGFloat(imageWidth) / CGFloat(imageHeight) * heightToWidth
        )
        let desired = CGRect(
            x: centerX - cropWidth / 2,
            y: centerY - cropHeight / 2,
            width: cropWidth,
            height: cropHeight
        )
        let clipped = desired.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard clipped.width > 0, clipped.height > 0 else { return nil }
        return EyeStripCropGeometry(
            normalizedRectVision: clipped,
            metadata: [
                Float(centerX * 2 - 1),
                Float((1 - centerY) * 2 - 1),
                Float(cropWidth),
                Float(cropHeight),
            ]
        )
    }

    private static func horizontalExtrema(_ points: [CGPoint]) -> [CGPoint]? {
        guard let left = points.min(by: { $0.x < $1.x }),
              let right = points.max(by: { $0.x < $1.x })
        else { return nil }
        return [left, right]
    }
}

final class EyeStripInferenceEngine {
    private let model: MLModel
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    init(modelURL: URL) throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        model = try MLModel(contentsOf: modelURL, configuration: configuration)
    }

    static func loadBundled() -> (engine: EyeStripInferenceEngine?, status: String) {
        guard let url = Bundle.main.url(
            forResource: "paddy-gazeTrackV2",
            withExtension: "mlmodelc"
        ) else {
            return (nil, "paddy-gazeTrackV2 not bundled")
        }
        do {
            return (try EyeStripInferenceEngine(modelURL: url), "paddy-gazeTrackV2 ready")
        } catch {
            return (nil, "paddy-gazeTrackV2 failed to load")
        }
    }

    /// The ARKit camera buffer is oriented into the active landscape interface
    /// before both Vision and this cropper see it. Passing that same CIImage
    /// here keeps Vision landmarks and crop pixels in one coordinate system.
    func predict(
        orientedImage image: CIImage,
        face observation: VNFaceObservation
    ) throws -> EyeStripPrediction? {
        let extent = image.extent.integral
        guard let landmarks = observation.landmarks,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye,
              let geometry = EyeStripInputGeometry.cropGeometry(
                leftEyePointsFaceNormBottomLeft: leftEye.normalizedPoints,
                rightEyePointsFaceNormBottomLeft: rightEye.normalizedPoints,
                faceRectVisionNorm: observation.boundingBox,
                imageWidth: Int(extent.width),
                imageHeight: Int(extent.height)
              ),
              let crop = resizedCrop(
                image,
                normalizedRect: geometry.normalizedRectVision
              )
        else { return nil }
        let eyeStrip = try makeEyeStripTensor(crop)
        let cropGeometry = try MLMultiArray(shape: [1, 4], dataType: .float32)
        for (index, value) in geometry.metadata.enumerated() {
            cropGeometry[index] = NSNumber(value: value)
        }
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "eye_strip": MLFeatureValue(multiArray: eyeStrip),
            "crop_geometry": MLFeatureValue(multiArray: cropGeometry),
        ])
        let started = ProcessInfo.processInfo.systemUptime
        let result = try model.prediction(from: provider)
        let duration = (ProcessInfo.processInfo.systemUptime - started) * 1_000
        guard let values = result.featureValue(for: "gaze_screen_centered")?.multiArrayValue,
              values.count == 2
        else { return nil }
        return EyeStripPrediction(
            xScreenCentered: values[0].doubleValue,
            yScreenCentered: values[1].doubleValue,
            inferenceDurationMS: duration
        )
    }

    private func resizedCrop(
        _ image: CIImage,
        normalizedRect: CGRect
    ) -> CVPixelBuffer? {
        let extent = image.extent
        let cropRect = CGRect(
            x: extent.minX + normalizedRect.minX * extent.width,
            y: extent.minY + normalizedRect.minY * extent.height,
            width: normalizedRect.width * extent.width,
            height: normalizedRect.height * extent.height
        )
        guard cropRect.width >= 1, cropRect.height >= 1 else { return nil }
        let cropped = image.clampedToExtent().cropped(to: cropRect)
        let translated = cropped.transformed(
            by: CGAffineTransform(translationX: -cropRect.minX, y: -cropRect.minY)
        )
        let resized = translated.transformed(
            by: CGAffineTransform(
                scaleX: CGFloat(EyeStripInputGeometry.outputWidth) / cropRect.width,
                y: CGFloat(EyeStripInputGeometry.outputHeight) / cropRect.height
            )
        )
        var output: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
            kCVPixelBufferCGImageCompatibilityKey: true as CFBoolean,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true as CFBoolean,
        ] as CFDictionary
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            EyeStripInputGeometry.outputWidth,
            EyeStripInputGeometry.outputHeight,
            kCVPixelFormatType_32BGRA,
            attributes,
            &output
        )
        guard status == kCVReturnSuccess, let output else { return nil }
        context.render(
            resized,
            to: output,
            bounds: CGRect(
                x: 0,
                y: 0,
                width: EyeStripInputGeometry.outputWidth,
                height: EyeStripInputGeometry.outputHeight
            ),
            colorSpace: colorSpace
        )
        return output
    }

    private func makeEyeStripTensor(_ pixelBuffer: CVPixelBuffer) throws -> MLMultiArray {
        let width = EyeStripInputGeometry.outputWidth
        let height = EyeStripInputGeometry.outputHeight
        let tensor = try MLMultiArray(
            shape: [1, 3, NSNumber(value: height), NSNumber(value: width)],
            dataType: .float32
        )
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return tensor }
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let planeSize = width * height
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let blue = powf(Float(bytes[offset]) / 255, 1 / 2.2)
                let green = powf(Float(bytes[offset + 1]) / 255, 1 / 2.2)
                let red = powf(Float(bytes[offset + 2]) / 255, 1 / 2.2)
                let index = y * width + x
                tensor[index] = NSNumber(value: ((red + green + blue) / 3) * 2 - 1)
                tensor[planeSize + index] = NSNumber(value: Float(x) / Float(width) * 2 - 1)
                tensor[2 * planeSize + index] = NSNumber(value: Float(y) / Float(height) * 2 - 1)
            }
        }
        return tensor
    }
}
