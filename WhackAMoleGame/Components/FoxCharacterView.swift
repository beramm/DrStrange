import SwiftUI

/// The fox from the provided 21-frame hammer swing (`FoxHammer/Frame01…21`).
/// Frame 1 holds the hammer raised; frame 21 is the moment of impact, low on the fox's left.
struct FoxCharacterView: View {
    /// 1...21.
    let frame: Int
    /// Flipped so the hammer swings to the right instead of the left.
    var mirrored = false

    static let frameCount = 21

    /// Where the hammer head is at the impact frame, as a fraction of the (unmirrored) image.
    static let impactPoint = CGPoint(x: 0.11, y: 0.62)
    /// Centre of the fox's card in the image; the hammer sticks out to its left.
    static let cardCenter = CGPoint(x: 0.62, y: 0.36)

    var body: some View {
        Image(Self.assetName(frame))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
            .accessibilityHidden(true)
    }

    static func assetName(_ frame: Int) -> String {
        String(format: "FoxHammer/Frame%02d", min(max(frame, 1), frameCount))
    }

    /// Animation frame for a point in the attack: raised while emerging, a swing that speeds up
    /// into the impact, held on impact, and lifted back on the way home.
    static func frame(for pose: FoxPose?) -> Int {
        guard let pose else { return 1 }
        let swing = Double(frameCount - 1)
        switch pose.phase {
        case .emerging: return 1
        case .attacking: return 1 + Int((swing * pose.progress * pose.progress).rounded())
        case .hitting: return frameCount
        case .returning: return frameCount - Int((swing * pose.progress).rounded())
        }
    }
}
