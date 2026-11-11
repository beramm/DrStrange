// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DrStrangeGazeTracker",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "DrStrangeGazeTracker",
            targets: ["DrStrangeGazeTracker", "DrStrangeGazeTrackerPlatform"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/google-ai-edge/mediapipe.git",
            revision: "39c0c70001d8b0b6c2208fde01eed3606ef4ca1b"
        )
    ],
    targets: [
        .target(name: "DrStrangeGazeTracker"),
        .target(
            name: "DrStrangeGazeTrackerPlatform",
            dependencies: [
                "DrStrangeGazeTracker",
                .product(
                    name: "MediaPipeTasksVision",
                    package: "mediapipe",
                    condition: .when(platforms: [.iOS])
                )
            ]
        ),
        .testTarget(
            name: "DrStrangeGazeTrackerTests",
            dependencies: ["DrStrangeGazeTracker", "DrStrangeGazeTrackerPlatform"]
        )
    ]
)
