import SwiftUI

/// The helper's hammer swing: the fox from the provided 21-frame swing (`FoxHammer/Frame01…21`)
/// or any other `HelperCharacter`, whose frames share the same card placement.
/// Frame 1 holds the hammer raised; the last frame is the moment of impact, low on the left.
struct FoxCharacterView: View {
    /// 1...helper.frameCount.
    let frame: Int
    /// Whose artwork is drawn. Everything else is the same for every helper.
    var helper = HelperCharacter.fox
    /// Flipped so the hammer swings to the right instead of the left.
    var mirrored = false
    /// How much of the image is shown. The hammer sticks out of the card, so it is hidden while the
    /// fox rises and slides out from behind the card as the swing starts.
    var visibility = Visibility.all

    enum Visibility: Equatable {
        case all
        /// Only what is inside the card's border: used while the fox rises up through its card.
        case cardInterior
        /// The card, with the hammer this far (0...1) out from behind the card's edge.
        case cardAndHammer(Double)
    }

    /// The fox's frame count and impact point; see `HelperCharacter` for every helper's own.
    static let frameCount = HelperCharacter.fox.frameCount
    static let impactPoint = HelperCharacter.fox.impactPoint
    /// The card in the image (unmirrored), measured from the fox's frames; every helper's frames
    /// are aligned to it. The hammer sticks out to its left.
    static let cardRect = CGRect(x: 0.284, y: 0.013, width: 0.707, height: 0.712)
    static let cardCenter = CGPoint(x: cardRect.midX, y: cardRect.midY)

    private var image: some View {
        Image(Self.assetName(frame, helper: helper))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
    }

    var body: some View {
        Group {
            if case let .cardAndHammer(reveal) = visibility, reveal < 1 {
                // The card stays put; the part of the image beside it (the hammer) slides out from
                // behind the card's edge, so it is only ever cut off by the card itself.
                GeometryReader { proxy in
                    let card = Self.cardFrame(in: proxy.size, mirrored: mirrored)
                    let travel = mirrored ? proxy.size.width - card.maxX : card.minX
                    let slide = travel * (1 - CGFloat(max(reveal, 0))) * (mirrored ? -1 : 1)
                    ZStack {
                        image.mask(VisibleArea(area: .card, mirrored: mirrored))
                        image
                            .mask(VisibleArea(area: .besideCard, mirrored: mirrored))
                            .offset(x: slide)
                            .mask(VisibleArea(area: .besideCard, mirrored: mirrored))
                    }
                }
            } else if visibility == .cardInterior {
                image.mask(VisibleArea(area: .cardInterior, mirrored: mirrored))
            } else {
                image
            }
        }
        .accessibilityHidden(true)
    }

    /// The card in an image of `size`.
    static func cardFrame(in size: CGSize, mirrored: Bool) -> CGRect {
        let x = mirrored ? 1 - cardRect.maxX : cardRect.minX
        return CGRect(x: x * size.width, y: cardRect.minY * size.height, width: cardRect.width * size.width, height: cardRect.height * size.height)
    }

    private struct VisibleArea: Shape {
        enum Area { case card, cardInterior, besideCard }

        let area: Area
        let mirrored: Bool

        func path(in rect: CGRect) -> Path {
            let card = FoxCharacterView.cardFrame(in: rect.size, mirrored: mirrored)
            switch area {
            case .card:
                return Path(card)
            case .cardInterior:
                let inset = card.width * 0.03
                return Path(card.insetBy(dx: inset, dy: inset))
            case .besideCard:
                return Path(mirrored
                    ? CGRect(x: card.maxX, y: 0, width: rect.width - card.maxX, height: rect.height)
                    : CGRect(x: 0, y: 0, width: card.minX, height: rect.height))
            }
        }
    }

    static func assetName(_ frame: Int, helper: HelperCharacter = .fox) -> String {
        String(format: "%@/Frame%02d", helper.assetFolder, min(max(frame, 1), helper.frameCount))
    }

    /// Animation frame for a point in the attack: hammer raised until the attack, a swing that
    /// speeds up into the impact, held on impact, and lifted back while the fox retracts.
    /// The same curve for every helper, spread over that helper's own frames.
    static func frame(for pose: FoxPose?) -> Int {
        guard let pose else { return 1 }
        let frameCount = pose.helper.frameCount
        let swing = Double(frameCount - 1)
        switch pose.phase {
        case .frameAppearing, .foxEmerging, .frameDisappearing: return 1
        case .attacking: return 1 + Int((swing * pose.progress * pose.progress).rounded())
        case .hitting: return frameCount
        // Hammer is fully raised again by the time the fox is back on its card (halfway).
        case .foxRetracting: return frameCount - Int((swing * min(pose.progress / 0.5, 1)).rounded())
        }
    }
}
