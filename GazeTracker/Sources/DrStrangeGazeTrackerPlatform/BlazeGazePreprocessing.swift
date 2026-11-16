#if canImport(Accelerate) && canImport(CoreVideo)
import Accelerate
import CoreGraphics
import CoreVideo
import Foundation

// The preprocessing and RBF equations in this file are adapted from MacGaze
// (MIT, Copyright 2026 Will Wade and contributors), pinned at
// 3884a8c5a9f6284aff4726db8f282f62661e9dd3. They reproduce WebEyeTrack's
// BlazeGaze input contract rather than feeding the model an approximate crop.

enum BlazeGazeEyePatchExtractor {
    static let patchWidth = 512
    static let patchHeight = 128
    private static let faceCropSize = 512

    static func extract(
        pixelBuffer: CVPixelBuffer,
        landmarks: [[Double]]
    ) -> CVPixelBuffer? {
        guard landmarks.count >= 468 else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let center = pixelPoint(landmarks[4], width, height)
        let padding = (x: CGFloat(0.4), y: CGFloat(0.2))
        let source = [
            expand(pixelPoint(landmarks[103], width, height), from: center, by: padding),
            expand(pixelPoint(landmarks[150], width, height), from: center, by: padding),
            expand(pixelPoint(landmarks[379], width, height), from: center, by: padding),
            expand(pixelPoint(landmarks[332], width, height), from: center, by: padding)
        ]
        let destination = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: faceCropSize),
            CGPoint(x: faceCropSize, y: faceCropSize),
            CGPoint(x: faceCropSize, y: 0)
        ]
        guard
            let inverse = homography(source: destination, destination: source),
            let forward = homography(source: source, destination: destination),
            let warped = perspectiveWarp(
                pixelBuffer: pixelBuffer,
                inverseHomography: inverse,
                outputSize: faceCropSize
            )
        else { return nil }

        let topPoint = apply(forward, to: pixelPoint(landmarks[151], width, height))
        let bottomPoint = apply(forward, to: pixelPoint(landmarks[195], width, height))
        let top = max(0, min(Int(topPoint.y), faceCropSize - 1))
        let bottom = max(top + 1, min(Int(bottomPoint.y), faceCropSize))
        guard let band = cropRows(warped, top: top, bottom: bottom) else { return nil }
        return resize(band, sourceHeight: bottom - top)
    }

    private static func pixelPoint(_ landmark: [Double], _ width: Int, _ height: Int) -> CGPoint {
        CGPoint(x: landmark[0] * Double(width), y: landmark[1] * Double(height))
    }

    private static func expand(
        _ point: CGPoint,
        from center: CGPoint,
        by padding: (x: CGFloat, y: CGFloat)
    ) -> CGPoint {
        CGPoint(
            x: point.x + padding.x * (point.x - center.x),
            y: point.y + padding.y * (point.y - center.y)
        )
    }

    static func homography(source: [CGPoint], destination: [CGPoint]) -> [Double]? {
        guard source.count == 4, destination.count == 4 else { return nil }
        var matrix = [[Double]](repeating: [Double](repeating: 0, count: 8), count: 8)
        var values = [Double](repeating: 0, count: 8)
        for index in 0..<4 {
            let x = Double(source[index].x)
            let y = Double(source[index].y)
            let targetX = Double(destination[index].x)
            let targetY = Double(destination[index].y)
            matrix[index * 2] = [x, y, 1, 0, 0, 0, -targetX * x, -targetX * y]
            matrix[index * 2 + 1] = [0, 0, 0, x, y, 1, -targetY * x, -targetY * y]
            values[index * 2] = targetX
            values[index * 2 + 1] = targetY
        }
        for column in 0..<8 {
            var pivot = column
            for row in (column + 1)..<8 where abs(matrix[row][column]) > abs(matrix[pivot][column]) {
                pivot = row
            }
            if pivot != column {
                matrix.swapAt(column, pivot)
                values.swapAt(column, pivot)
            }
            guard abs(matrix[column][column]) > 1e-10 else { return nil }
            for row in (column + 1)..<8 {
                let factor = matrix[row][column] / matrix[column][column]
                for item in column..<8 { matrix[row][item] -= factor * matrix[column][item] }
                values[row] -= factor * values[column]
            }
        }
        var result = [Double](repeating: 0, count: 8)
        for row in (0..<8).reversed() {
            var sum = values[row]
            for column in (row + 1)..<8 { sum -= matrix[row][column] * result[column] }
            result[row] = sum / matrix[row][row]
        }
        return result + [1]
    }

    private static func apply(_ matrix: [Double], to point: CGPoint) -> CGPoint {
        let x = Double(point.x)
        let y = Double(point.y)
        let divisor = matrix[6] * x + matrix[7] * y + matrix[8]
        guard abs(divisor) > 1e-10 else { return .zero }
        return CGPoint(
            x: (matrix[0] * x + matrix[1] * y + matrix[2]) / divisor,
            y: (matrix[3] * x + matrix[4] * y + matrix[5]) / divisor
        )
    }

    private static func perspectiveWarp(
        pixelBuffer: CVPixelBuffer,
        inverseHomography matrix: [Double],
        outputSize: Int
    ) -> CVPixelBuffer? {
        let sourceWidth = CVPixelBufferGetWidth(pixelBuffer)
        let sourceHeight = CVPixelBufferGetHeight(pixelBuffer)
        guard let output = makePixelBuffer(width: outputSize, height: outputSize) else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(output, [])
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            CVPixelBufferUnlockBaseAddress(output, [])
        }
        guard
            let sourceBase = CVPixelBufferGetBaseAddress(pixelBuffer),
            let outputBase = CVPixelBufferGetBaseAddress(output)
        else { return nil }
        let sourceRowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let outputRowBytes = CVPixelBufferGetBytesPerRow(output)
        let source = sourceBase.assumingMemoryBound(to: UInt8.self)
        let destination = outputBase.assumingMemoryBound(to: UInt8.self)
        for outputY in 0..<outputSize {
            for outputX in 0..<outputSize {
                let x = Double(outputX)
                let y = Double(outputY)
                let divisor = matrix[6] * x + matrix[7] * y + matrix[8]
                guard abs(divisor) > 1e-10 else { continue }
                let sourceX = (matrix[0] * x + matrix[1] * y + matrix[2]) / divisor
                let sourceY = (matrix[3] * x + matrix[4] * y + matrix[5]) / divisor
                let x0 = max(0, min(sourceWidth - 1, Int(sourceX)))
                let y0 = max(0, min(sourceHeight - 1, Int(sourceY)))
                let x1 = min(sourceWidth - 1, x0 + 1)
                let y1 = min(sourceHeight - 1, y0 + 1)
                let xFraction = max(0, min(1, sourceX - Double(x0)))
                let yFraction = max(0, min(1, sourceY - Double(y0)))
                for channel in 0..<4 {
                    let p00 = Double(source[y0 * sourceRowBytes + x0 * 4 + channel])
                    let p01 = Double(source[y0 * sourceRowBytes + x1 * 4 + channel])
                    let p10 = Double(source[y1 * sourceRowBytes + x0 * 4 + channel])
                    let p11 = Double(source[y1 * sourceRowBytes + x1 * 4 + channel])
                    let value = p00 * (1 - xFraction) * (1 - yFraction)
                        + p01 * xFraction * (1 - yFraction)
                        + p10 * (1 - xFraction) * yFraction
                        + p11 * xFraction * yFraction
                    destination[outputY * outputRowBytes + outputX * 4 + channel] = UInt8(
                        max(0, min(255, value))
                    )
                }
            }
        }
        return output
    }

    private static func cropRows(_ source: CVPixelBuffer, top: Int, bottom: Int) -> CVPixelBuffer? {
        let height = bottom - top
        guard height > 0, let output = makePixelBuffer(width: faceCropSize, height: height) else {
            return nil
        }
        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(output, [])
        defer {
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
            CVPixelBufferUnlockBaseAddress(output, [])
        }
        guard
            let sourceBase = CVPixelBufferGetBaseAddress(source),
            let outputBase = CVPixelBufferGetBaseAddress(output)
        else { return nil }
        let sourceRowBytes = CVPixelBufferGetBytesPerRow(source)
        let outputRowBytes = CVPixelBufferGetBytesPerRow(output)
        for row in 0..<height {
            memcpy(
                outputBase.advanced(by: row * outputRowBytes),
                sourceBase.advanced(by: (top + row) * sourceRowBytes),
                min(sourceRowBytes, outputRowBytes)
            )
        }
        return output
    }

    private static func resize(_ source: CVPixelBuffer, sourceHeight: Int) -> CVPixelBuffer? {
        guard let output = makePixelBuffer(width: patchWidth, height: patchHeight) else { return nil }
        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(output, [])
        defer {
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
            CVPixelBufferUnlockBaseAddress(output, [])
        }
        guard
            let sourceBase = CVPixelBufferGetBaseAddress(source),
            let outputBase = CVPixelBufferGetBaseAddress(output)
        else { return nil }
        var sourceBuffer = vImage_Buffer(
            data: sourceBase,
            height: vImagePixelCount(sourceHeight),
            width: vImagePixelCount(faceCropSize),
            rowBytes: CVPixelBufferGetBytesPerRow(source)
        )
        var outputBuffer = vImage_Buffer(
            data: outputBase,
            height: vImagePixelCount(patchHeight),
            width: vImagePixelCount(patchWidth),
            rowBytes: CVPixelBufferGetBytesPerRow(output)
        )
        let error = vImageScale_ARGB8888(
            &sourceBuffer,
            &outputBuffer,
            nil,
            vImage_Flags(kvImageHighQualityResampling)
        )
        return error == kvImageNoError ? output : nil
    }

    private static func makePixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var output: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &output
        )
        return output
    }
}

enum BlazeGazeMetricFaceOrigin {
    private static let realWorldIPDCentimeters = 6.3
    private static let verticalFieldOfViewDegrees = 60.0
    private static let leftEye = [362, 263]
    private static let rightEye = [33, 133]

    static func compute(
        landmarks: [[Double]],
        width: Int,
        height: Int,
        rotation: [[Double]]?
    ) -> [Float] {
        let width = Double(width)
        let height = Double(height)
        let left = mean(landmarks, indices: leftEye, width: width, height: height)
        let right = mean(landmarks, indices: rightEye, width: width, height: height)
        let imageIPD = hypot(left.x - right.x, left.y - right.y)
        guard imageIPD > 1 else { return [0, 0, 60] }
        let focalLength = height / (2 * tan(verticalFieldOfViewDegrees * .pi / 360))
        let theta: Double
        if let rotation, rotation.count == 3 {
            theta = atan2(rotation[0][2], rotation[2][2])
        } else {
            theta = 0
        }
        let depth = focalLength * realWorldIPDCentimeters * cos(theta) / imageIPD
        let centimetersPerPixel = depth / focalLength
        return [
            Float(((left.x + right.x) / 2 - width / 2) * centimetersPerPixel),
            Float((height / 2 - (left.y + right.y) / 2) * centimetersPerPixel),
            Float(depth)
        ]
    }

    private static func mean(
        _ landmarks: [[Double]],
        indices: [Int],
        width: Double,
        height: Double
    ) -> (x: Double, y: Double) {
        var x = 0.0
        var y = 0.0
        for index in indices {
            x += landmarks[index][0] * width
            y += landmarks[index][1] * height
        }
        return (x / Double(indices.count), y / Double(indices.count))
    }
}

struct BlazeGazeCalibrationPair: Equatable, Sendable {
    let observed: CGPoint
    let target: CGPoint
}

struct BlazeGazeRBFCorrection: Sendable {
    private var inputs: [Double] = []
    private var weights: [Double] = []
    private var sigma = 0.0
    private(set) var isFitted = false

    mutating func reset() {
        inputs.removeAll()
        weights.removeAll()
        sigma = 0
        isFitted = false
    }

    mutating func fit(_ samples: [BlazeGazeCalibrationPair]) -> Bool {
        guard samples.count >= 3 else {
            reset()
            return false
        }
        let count = samples.count
        inputs = samples.flatMap { [Double($0.observed.x), Double($0.observed.y)] }
        sigma = max(1e-6, Self.meanDistance(inputs: inputs, count: count))
        let sigmaSquared = sigma * sigma
        var kernel = [Double](repeating: 0, count: count * count)
        var targets = [Double](repeating: 0, count: count * 2)
        for row in 0..<count {
            targets[row] = Double(samples[row].target.x)
            targets[row + count] = Double(samples[row].target.y)
            for column in 0..<count {
                let dx = inputs[row * 2] - inputs[column * 2]
                let dy = inputs[row * 2 + 1] - inputs[column * 2 + 1]
                kernel[row * count + column] = exp(-(dx * dx + dy * dy) / (2 * sigmaSquared))
            }
            kernel[row * count + row] += 0.01
        }
        var dimension = __CLPK_integer(count)
        var rightHandSides: __CLPK_integer = 2
        var leadingDimension = __CLPK_integer(count)
        var targetLeadingDimension = __CLPK_integer(count)
        var pivots = [__CLPK_integer](repeating: 0, count: count)
        var info: __CLPK_integer = 0
        dgesv_(
            &dimension,
            &rightHandSides,
            &kernel,
            &leadingDimension,
            &pivots,
            &targets,
            &targetLeadingDimension,
            &info
        )
        guard info == 0 else {
            reset()
            return false
        }
        weights = [Double](repeating: 0, count: count * 2)
        for index in 0..<count {
            weights[index * 2] = targets[index]
            weights[index * 2 + 1] = targets[index + count]
        }
        isFitted = true
        return true
    }

    func correct(_ point: CGPoint) -> CGPoint {
        guard isFitted else { return point }
        let count = inputs.count / 2
        let sigmaSquared = sigma * sigma
        var x = 0.0
        var y = 0.0
        for index in 0..<count {
            let dx = Double(point.x) - inputs[index * 2]
            let dy = Double(point.y) - inputs[index * 2 + 1]
            let basis = exp(-(dx * dx + dy * dy) / (2 * sigmaSquared))
            x += weights[index * 2] * basis
            y += weights[index * 2 + 1] * basis
        }
        return CGPoint(x: x, y: y)
    }

    private static func meanDistance(inputs: [Double], count: Int) -> Double {
        var total = 0.0
        var pairs = 0
        for first in 0..<count {
            for second in (first + 1)..<count {
                total += hypot(
                    inputs[first * 2] - inputs[second * 2],
                    inputs[first * 2 + 1] - inputs[second * 2 + 1]
                )
                pairs += 1
            }
        }
        return pairs > 0 ? total / Double(pairs) : 0.1
    }
}
#endif
