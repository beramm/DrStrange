import SwiftUI

/// One hole, open only while its mole is around. The hole opens, the mole slides up out of it,
/// turns sad when hit and slides back down, then the hole closes.
/// Gameplay activation is gaze-only; the cell deliberately ignores direct touch input.
struct MoleHoleView: View {
    let hole: HoleVisual
    let target: ActiveTarget?
    let visual: MoleVisual?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let art = HoleArt.all[hole.artIndex % HoleArt.all.count]
            let image = art.imageRect(fittingMouth: Self.mouthRect(in: proxy.size))
            let opening = art.openingRect(in: image)

            ZStack(alignment: .topLeading) {
                Image(art.assetName)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: image.width, height: image.height)
                    .scaleEffect(0.55 + 0.45 * Self.springy(hole.openness))
                    .opacity(min(hole.openness * 1.6, 1))
                    .position(x: image.midX, y: image.midY)

                // The mole slides up from inside the hole; anything below the hole's front edge is
                // hidden, so it looks like it climbs out. With Reduce Motion it fades instead.
                if let target, let visual {
                    let moleFrame = Self.moleImageRect(
                        artIndex: hole.artIndex,
                        isHit: visual.isHit,
                        rise: reduceMotion ? 1 : Self.smooth(visual.rise),
                        in: proxy.size
                    )
                    CharacterView(target: target, visual: visual)
                        .frame(width: moleFrame.width, height: moleFrame.height)
                        .position(x: moleFrame.midX, y: moleFrame.midY)
                        .opacity(reduceMotion ? visual.rise : 1)
                        .mask(HoleMouthMask(opening: opening))
                        .id(target.id)
                }

            }
            .frame(width: width, height: height)
        }
        .anchorPreference(key: FoxAnchorKey.self, value: .bounds) { [.hole(hole.holeIndex): $0] }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
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

    /// Gentle start and finish for the slide in and out of the hole.
    static func smooth(_ t: Double) -> Double {
        let t = min(max(t, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Frame for the mole picture in a hole cell of `size`, `rise` of the way out of the hole
    /// (0 = helmet just below the front edge, 1 = fully out).
    static func moleImageRect(artIndex: Int, isHit: Bool, rise: Double, in size: CGSize) -> CGRect {
        let full = rectFromLip(MoleArt.picture(isHit: isHit).imageRect, artIndex: artIndex, in: size)
        let drop = rectFromLip(MoleArt.fullMoleRect, artIndex: artIndex, in: size).height
        return full.offsetBy(dx: 0, dy: drop * CGFloat(1 - rise))
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

/// Shows only what is above the hole's front edge: everything above the middle of the dark
/// opening, plus the opening itself, so the cut follows the opening's curved front rim.
private struct HoleMouthMask: Shape {
    let opening: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path(CGRect(x: rect.minX - rect.width, y: rect.minY - rect.height * 2, width: rect.width * 3, height: opening.midY - rect.minY + rect.height * 2))
        path.addEllipse(in: opening)
        return path
    }
}

/// The two provided mole pictures and where the mole stands in its hole, given in hole-opening
/// widths from the middle of the opening's front edge. Both pictures are lined up on the helmet, so
/// swapping to the sad mole keeps it in place.
enum MoleArt {
    struct Picture: Equatable {
        let assetName: String
        /// Image size in pixels.
        let pixelSize: CGSize
        /// The yellow helmet in the image, in pixels, measured from the art.
        let helmet: CGRect

        /// Where the whole image goes when the mole is fully out.
        var imageRect: CGRect {
            let unit = helmet.width / MoleArt.helmetWidth
            return CGRect(
                x: -helmet.midX / unit,
                y: -MoleArt.standingHeight - helmet.minY / unit,
                width: pixelSize.width / unit,
                height: pixelSize.height / unit
            )
        }
    }

    /// Helmet width in opening widths: the same size the moles had before.
    static let helmetWidth: CGFloat = 0.66
    /// From the top of the helmet down to the hole's front edge when fully out, in opening widths:
    /// the head and the top of the striped shirt show; the legs stay in the hole.
    static let standingHeight: CGFloat = 1.09

    static let appear = Picture(
        assetName: "Mole/Appear",
        pixelSize: CGSize(width: 1119, height: 1434),
        helmet: CGRect(x: 293, y: 124, width: 476, height: 238)
    )
    static let disappear = Picture(
        assetName: "Mole/Disappear",
        pixelSize: CGSize(width: 674, height: 643),
        helmet: CGRect(x: 223, y: 51, width: 197, height: 101)
    )

    static func picture(isHit: Bool) -> Picture { isHit ? disappear : appear }

    /// The mole's body (helmet to the hole's front edge) when fully out, from the appear picture's
    /// outline (pixels 202...874 across).
    static let fullMoleRect: CGRect = {
        let unit = appear.helmet.width / helmetWidth
        return CGRect(
            x: (202 - appear.helmet.midX) / unit,
            y: -standingHeight,
            width: (874 - 202) / unit,
            height: standingHeight
        )
    }()
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
