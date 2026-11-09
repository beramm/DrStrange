@_spi(Platform) import DrStrangeGazeTracker

#if canImport(ARKit) && canImport(UIKit) && os(iOS)
import ARKit
import SceneKit
import UIKit
#endif

public enum GazeTrackerFactory {
    /// Creates the iPadOS platform tracker without exposing the observation
    /// framework or any of its types through the contract module.
    public static func makeTracker() -> GazeTracker {
        GazeTracker(runtime: PlatformObservationRuntime())
    }

    #if canImport(ARKit) && canImport(UIKit) && os(iOS)
    /// Demo-only framing aid. The renderer shares the tracker's ARSession, so it
    /// does not open a second camera capture path or expose camera frames.
    /// Nothing displayed by this view is persisted, logged, or transmitted.
    @_spi(Engineering)
    public static func makeTrackerWithVolatilePreview() -> (
        tracker: GazeTracker,
        preview: UIView,
        cameraInput: GazeCameraInputConfiguration
    ) {
        let preview = ARSCNView(frame: .zero)
        preview.scene = SCNScene()
        preview.preferredFramesPerSecond = 30
        preview.isPlaying = true
        preview.automaticallyUpdatesLighting = false
        preview.backgroundColor = .black
        let cameraInput = GazeCameraInputConfiguration()
        let runtime = PlatformObservationRuntime(
            previewView: preview,
            cameraInput: cameraInput
        )
        return (GazeTracker(runtime: runtime), preview, cameraInput)
    }
    #endif
}
