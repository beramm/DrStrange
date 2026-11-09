import Foundation

/// Converts ARKit's mirrored blink coefficients into anatomical eye availability.
///
/// On the mounted landscape front camera, ARKit's `eyeBlinkLeft` coefficient follows the
/// player's anatomical right eye and `eyeBlinkRight` follows the anatomical left eye.
@_spi(Platform)
public enum EyeAvailabilityClassifier {
    public static func classify(
        eyeBlinkLeft: Double,
        eyeBlinkRight: Double,
        openThreshold: Double = 0.70
    ) -> EyeAvailability {
        let anatomicalRightOpen = eyeBlinkLeft.isFinite && eyeBlinkLeft < openThreshold
        let anatomicalLeftOpen = eyeBlinkRight.isFinite && eyeBlinkRight < openThreshold

        return switch (anatomicalLeftOpen, anatomicalRightOpen) {
        case (true, true): .both
        case (true, false): .leftOnly
        case (false, true): .rightOnly
        case (false, false): .none
        }
    }
}
