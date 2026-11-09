import SwiftUI

/// One hole, open only while its mole is around. The hole opens, the mole climbs out (frame by
/// frame), reacts when hit and goes back down, then the hole closes.
/// The whole cell is the touch target so small hands do not need to be precise.
struct MoleHoleView: View {
    let hole: HoleVisual
    let target: ActiveTarget?
    let visual: MoleVisual?
    let onTap: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let art = HoleArt.all[hole.artIndex % HoleArt.all.count]
            let image = art.imageRect(fittingMouth: Self.mouthRect(in: proxy.size))
            let moleFrame = Self.moleImageRect(artIndex: hole.artIndex, in: proxy.size)

            ZStack(alignment: .topLeading) {
                Image(art.assetName)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: image.width, height: image.height)
                    .scaleEffect(0.55 + 0.45 * Self.springy(hole.openness))
                    .opacity(min(hole.openness * 1.6, 1))
                    .position(x: image.midX, y: image.midY)

                // Each frame already ends at the hole's front edge, so the mole only needs placing.
                if let target, let visual {
                    CharacterView(target: target, visual: visual)
                        .frame(width: moleFrame.width, height: moleFrame.height)
                        .position(x: moleFrame.midX, y: moleFrame.midY)
                        .id(target.id)
                }

                if let visual, let progress = visual.hitProgress {
                    let mole = Self.characterRect(artIndex: hole.artIndex, in: proxy.size)
                    HitFeedbackView(progress: progress)
                        .frame(width: mole.width, height: mole.height)
                        .position(x: mole.midX, y: mole.midY)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
        .anchorPreference(key: FoxAnchorKey.self, value: .bounds) { [.hole(hole.holeIndex): $0] }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onTap)
    }

    /// Height of the hole's dark opening for a cell of `width` (the provided hole art's openings are
    /// about 0.4 as tall as they are wide).
    static func holeHeight(forWidth width: CGFloat) -> CGFloat {
        width * 0.72 * 0.4
    }

    /// The line where a risen mole meets the hole: the middle of the dark opening.
    static func holeLine(in size: CGSize) -> CGFloat {
        size.height - holeHeight(forWidth: size.width) / 2
    }

    /// The dark opening the mole comes out of, centred on the hole line.
    static func mouthRect(in size: CGSize) -> CGRect {
        let mouthWidth = size.width * 0.72
        let mouthHeight = holeHeight(forWidth: size.width)
        return CGRect(x: (size.width - mouthWidth) / 2, y: holeLine(in: size) - mouthHeight / 2, width: mouthWidth, height: mouthHeight)
    }

    /// Slight overshoot as the hole opens, like earth pushing up.
    private static func springy(_ t: Double) -> Double {
        let c1 = 1.4, c3 = c1 + 1
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
    }

    /// Maps a rect given relative to the hole's front edge (in opening widths) into the cell.
    private static func rectFromLip(_ rect: CGRect, artIndex: Int, in size: CGSize) -> CGRect {
        let art = HoleArt.all[artIndex % HoleArt.all.count]
        let opening = art.openingRect(in: art.imageRect(fittingMouth: mouthRect(in: size)))
        let unit = opening.width
        return CGRect(
            x: opening.midX + rect.minX * unit,
            y: opening.maxY + rect.minY * unit,
            width: rect.width * unit,
            height: rect.height * unit
        )
    }

    /// Frame for the mole images in a hole cell of `size`.
    static func moleImageRect(artIndex: Int, in size: CGSize) -> CGRect {
        rectFromLip(MoleArt.imageRect, artIndex: artIndex, in: size)
    }

    /// The fully risen mole inside a hole cell of `size`. Shared with the fox's attack so the
    /// hammer lands on the mole.
    static func characterRect(artIndex: Int, in size: CGSize) -> CGRect {
        rectFromLip(MoleArt.fullMoleRect, artIndex: artIndex, in: size)
    }

    private var accessibilityLabel: String {
        guard let target, target.phase.isUp else { return "Empty hole" }
        return target.role == .target ? "Mole" : "Sleeping mole"
    }
}

/// Where the mole frames sit relative to the hole they were painted in, measured from the art and
/// given in opening widths from the middle of the opening's front edge.
enum MoleArt {
    private static let openingWidth: CGFloat = 290
    private static let lip = CGPoint(x: 333, y: 598)

    private static func relative(_ rect: CGRect) -> CGRect {
        CGRect(x: (rect.minX - lip.x) / openingWidth, y: (rect.minY - lip.y) / openingWidth, width: rect.width / openingWidth, height: rect.height / openingWidth)
    }

    /// The cropped frame images.
    static let imageRect = relative(CGRect(x: 209, y: 278, width: 265, height: 330))
    /// The mole when fully out of the hole (last frame).
    static let fullMoleRect = relative(CGRect(x: 212, y: 281, width: 259, height: 324))
}

/// The provided hole artwork (`Holes/Hole1…3`), with where the dark opening sits in each image,
/// measured from the art.
struct HoleArt: Equatable {
    let assetName: String
    /// Image height / width.
    let aspect: CGFloat
    /// The dark opening, as fractions of the image.
    let opening: CGRect

    static let all = [
        HoleArt(assetName: "Holes/Hole1", aspect: 167.0 / 400.0, opening: CGRect(x: 0.122, y: 0.228, width: 0.601, height: 0.574)),
        HoleArt(assetName: "Holes/Hole2", aspect: 291.0 / 443.0, opening: CGRect(x: 0.122, y: 0.326, width: 0.686, height: 0.430)),
        HoleArt(assetName: "Holes/Hole3", aspect: 204.0 / 425.0, opening: CGRect(x: 0.167, y: 0.191, width: 0.624, height: 0.515)),
    ]

    /// The dark opening in screen space, for the art drawn at `image`.
    func openingRect(in image: CGRect) -> CGRect {
        CGRect(
            x: image.minX + opening.minX * image.width,
            y: image.minY + opening.minY * image.height,
            width: opening.width * image.width,
            height: opening.height * image.height
        )
    }

    /// Image frame that puts the art's opening over `mouth` (matching its width and centre).
    func imageRect(fittingMouth mouth: CGRect) -> CGRect {
        let width = mouth.width / opening.width
        let height = width * aspect
        return CGRect(
            x: mouth.midX - opening.midX * width,
            y: mouth.midY - opening.midY * height,
            width: width,
            height: height
        )
    }
}
