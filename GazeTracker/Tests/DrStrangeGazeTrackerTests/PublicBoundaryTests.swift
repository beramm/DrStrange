import Foundation
import XCTest
@testable import DrStrangeGazeTracker

final class PublicBoundaryTests: XCTestCase {
    func testLiveSampleHasExactlyTheSevenApprovedCategories() throws {
        let sample = GazeSample(
            pointNormalized: NormalizedGazePoint(x: 0.25, y: 0.75),
            timestamp: MonotonicTimestamp(uptimeNanoseconds: 123),
            quality: GazeQuality(confidence: 0.8, level: .usable),
            trackingState: .tracking,
            setupState: .ready,
            calibrationState: .calibrated,
            eyeAvailability: .rightOnly
        )

        let labels = Set(Mirror(reflecting: sample).children.compactMap(\.label))
        XCTAssertEqual(labels, [
            "pointNormalized",
            "timestamp",
            "quality",
            "trackingState",
            "setupState",
            "calibrationState",
            "eyeAvailability"
        ])
        XCTAssertEqual(labels.count, 7)
    }

    func testPublicDeclarationsDoNotExposeFrameworkInternals() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let packageRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoot = packageRoot.appendingPathComponent("Sources/DrStrangeGazeTracker")
        let files = try FileManager.default.subpathsOfDirectory(atPath: sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }
        let forbidden = [
            "ARKit", "ARFrame", "ARFaceAnchor", "ARSession", "ARFaceTrackingConfiguration",
            "CVPixelBuffer", "AVCapture", "simd_float4x4", "cameraFrame", "faceGeometry",
            "eyeTransform"
        ]

        for file in files {
            let content = try String(contentsOf: sourceRoot.appendingPathComponent(file), encoding: .utf8)
            for line in content.split(separator: "\n") where line.contains("public ") {
                for token in forbidden {
                    XCTAssertFalse(line.contains(token), "Public declaration leaks \(token): \(line)")
                }
            }
        }
    }

    func testLiveSampleDoesNotContainAdaptiveRadiusOrGameFields() {
        let sample = GazeSample(
            pointNormalized: nil,
            timestamp: MonotonicTimestamp(uptimeNanoseconds: 1),
            quality: .unavailable,
            trackingState: .limited,
            setupState: .unknown,
            calibrationState: .notCalibrated,
            eyeAvailability: .none
        )
        let labels = Mirror(reflecting: sample).children.compactMap(\.label).joined(separator: " ").lowercased()

        for forbidden in ["radius", "hit", "dwell", "cursor", "target", "path", "geometry"] {
            XCTAssertFalse(labels.contains(forbidden))
        }
    }
}
