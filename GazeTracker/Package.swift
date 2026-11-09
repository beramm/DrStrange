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
    targets: [
        .target(name: "DrStrangeGazeTracker"),
        .target(
            name: "DrStrangeGazeTrackerPlatform",
            dependencies: ["DrStrangeGazeTracker"]
        ),
        .testTarget(
            name: "DrStrangeGazeTrackerTests",
            dependencies: ["DrStrangeGazeTracker"]
        )
    ]
)
