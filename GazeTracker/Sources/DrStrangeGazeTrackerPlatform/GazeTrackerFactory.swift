@_spi(Platform) import DrStrangeGazeTracker

#if canImport(ARKit) && canImport(UIKit) && os(iOS)
import ARKit
import UIKit
#endif

public enum GazeTrackerFactory {
    /// Creates the iPadOS platform tracker without exposing the observation
    /// framework or any of its types through the contract module.
    public static func makeTracker() -> GazeTracker {
        GazeTracker(runtime: PlatformObservationRuntime())
    }

    #if canImport(ARKit) && canImport(UIKit) && os(iOS)
    /// Volatile framing aid with optional preprocessing sidecars. A single
    /// tracker-owned ARSession supplies both observations and preview frames,
    /// so there is no competing renderer or second camera capture path.
    /// Nothing displayed or processed here is persisted, logged, or transmitted.
    @_spi(Engineering)
    public static func makeTrackerWithVolatilePreview(
        faceIsolationEnabled: Bool = true,
        blazeGazeEnabled: Bool = true
    ) -> (
        tracker: GazeTracker,
        preview: UIView,
        cameraInput: GazeCameraInputConfiguration,
        ambientLight: GazeAmbientLightConfiguration,
        faceIsolationPreview: UIView,
        faceIsolation: GazeFaceIsolationConfiguration,
        blazeGazePreview: UIView,
        blazeGaze: GazeBlazeGazeConfiguration
    ) {
        let cameraFramePreview = VolatileCameraFramePreview(frame: .zero)
        let cameraInput = GazeCameraInputConfiguration()
        let ambientLight = GazeAmbientLightConfiguration()
        let faceIsolation = GazeFaceIsolationConfiguration()
        let faceIsolationPreview = VolatileFaceIsolationPreview(frame: .zero)
        let blazeGaze = GazeBlazeGazeConfiguration()
        let blazeGazePreview = VolatileBlazeGazePreview(frame: .zero)
        let runtime = PlatformObservationRuntime(
            previewHostView: cameraFramePreview,
            cameraFramePreview: cameraFramePreview,
            cameraInput: cameraInput,
            ambientLight: ambientLight,
            faceIsolation: faceIsolationEnabled ? faceIsolation : nil,
            faceIsolationPreview: faceIsolationEnabled ? faceIsolationPreview : nil,
            blazeGaze: blazeGazeEnabled ? blazeGaze : nil,
            blazeGazePreview: blazeGazeEnabled ? blazeGazePreview : nil
        )
        return (
            GazeTracker(runtime: runtime),
            cameraFramePreview,
            cameraInput,
            ambientLight,
            faceIsolationPreview,
            faceIsolation,
            blazeGazePreview,
            blazeGaze
        )
    }
    #endif
}
