import SwiftUI

/// The whole map, scaled and moved by the camera. Everything inside is laid out in map units.
struct FoxPathMapView: View {
    let viewModel: FoxPathGameViewModel

    var body: some View {
        GeometryReader { proxy in
            let viewport = proxy.size
            let camera = viewModel.camera
            let origin = camera.mapOrigin(in: viewport)
            let mapSize = viewModel.map.size

            ZStack(alignment: .topLeading) {
                FoxPathGroundView(map: viewModel.map)
                    .equatable()
                FoxPathStandingView(
                    sprites: viewModel.map.standingSprites,
                    fox: viewModel.foxPose,
                    mole: viewModel.mole
                )
            }
            .frame(width: mapSize.width, height: mapSize.height, alignment: .topLeading)
            .scaleEffect(camera.scale(in: viewport), anchor: .topLeading)
            .offset(x: origin.x, y: origin.y)
            .frame(width: viewport.width, height: viewport.height, alignment: .topLeading)
            .onAppear { viewModel.viewportSize = viewport }
            .onChange(of: viewport) { _, newValue in viewModel.viewportSize = newValue }
        }
        .background(FoxPathPalette.grass)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Path, grass patches and flat details. It never changes during a game, so it is compared by
/// map seed and left alone while the fox and the camera move.
private struct FoxPathGroundView: View, Equatable {
    let map: FoxPathMap

    static func == (lhs: FoxPathGroundView, rhs: FoxPathGroundView) -> Bool {
        lhs.map.seed == rhs.map.seed && lhs.map.pathCells == rhs.map.pathCells
    }

    /// Tiles overlap by this much so no grass line shows between them when the map is scaled.
    private static let overlap: CGFloat = 0.5
    /// Extra straight tiles past each edge, for screens wider than the map.
    private static let edgeTiles = 2

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(map.grassPatches.enumerated()), id: \.offset) { _, patch in
                tile(patch.assetName, in: FoxPathMetrics.rect(of: patch.cell))
                    .scaleEffect(x: patch.isMirrored ? -1 : 1, y: 1)
                    .position(center(of: patch.cell))
            }
            ForEach(Array(edgeCells.enumerated()), id: \.offset) { _, cell in
                tile("FoxPath/PathHorizontal", in: FoxPathMetrics.rect(of: cell))
                    .position(center(of: cell))
            }
            ForEach(Array(map.pathCells.enumerated()), id: \.offset) { _, pathCell in
                pathTile(pathCell)
                    .position(center(of: pathCell.cell))
            }
            ForEach(map.groundSprites) { sprite in
                MapSpriteView(sprite: sprite)
            }
        }
        .frame(width: map.size.width, height: map.size.height, alignment: .topLeading)
    }

    /// Cells just outside the map where the path carries on to the screen edge.
    private var edgeCells: [GridCell] {
        guard let first = map.pathCells.first?.cell, let last = map.pathCells.last?.cell else { return [] }
        return (1...Self.edgeTiles).flatMap { step in
            [
                GridCell(column: first.column - step, row: first.row),
                GridCell(column: last.column + step, row: last.row),
            ]
        }
    }

    private func center(of cell: GridCell) -> CGPoint {
        let rect = FoxPathMetrics.rect(of: cell)
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    private func tile(_ name: String, in rect: CGRect) -> some View {
        Image(name)
            .resizable()
            .frame(width: rect.width + Self.overlap * 2, height: rect.height + Self.overlap * 2)
    }

    @ViewBuilder
    private func pathTile(_ pathCell: PathCell) -> some View {
        let rect = FoxPathMetrics.rect(of: pathCell.cell)
        switch pathCell.tile {
        case .horizontal:
            tile("FoxPath/PathHorizontal", in: rect)
        case .vertical:
            tile("FoxPath/PathVertical", in: rect)
        case let .curve(side, end):
            // The curve art joins the left edge to the top edge; mirror it for the other three.
            tile("FoxPath/PathCurve", in: rect)
                .scaleEffect(x: side == .right ? -1 : 1, y: end == .bottom ? -1 : 1)
        }
    }
}

/// Houses, lamps, gardens, the finish stall, the character and the mole, drawn back to front by
/// where they touch the ground so a character walks in front of things behind it.
private struct FoxPathStandingView: View {
    let sprites: [MapSprite]
    let fox: FoxWalkPose
    let mole: MoleThiefVisual?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(sprites) { sprite in
                MapSpriteView(sprite: sprite)
                    .zIndex(Double(sprite.baseline))
            }
            GroundMarker(feet: fox.feet, width: fox.frame.width, color: .white)
                .zIndex(Double(fox.feet.y) - 0.5)
            FoxSpriteView(pose: fox)
                .zIndex(Double(fox.feet.y))
            if let mole {
                // The hole lies flat on the ground, under everything that stands.
                ThiefHoleView(mole: mole)
                    .zIndex(-1)
                ThiefMoleView(mole: mole)
                    .zIndex(Double(mole.hole.y) + 0.25)
            }
        }
    }
}

/// Soft white oval on the ground under the friend the child follows.
private struct GroundMarker: View {
    let feet: CGPoint
    let width: CGFloat
    let color: Color

    var body: some View {
        Ellipse()
            .fill(color.opacity(0.45))
            .overlay(Ellipse().strokeBorder(color.opacity(0.8), lineWidth: 3))
            .frame(width: width * 0.85, height: width * 0.28)
            .position(feet)
    }
}

/// The hole the mole comes out of (`Holes/Hole1`, the supplied mole hole), opening and closing.
private struct ThiefHoleView: View {
    let mole: MoleThiefVisual

    /// Drawn size in map units (the picture is 400 × 166 pixels).
    private static let size = CGSize(width: 96, height: 40)

    var body: some View {
        Image("Holes/Hole1")
            .resizable()
            .frame(width: Self.size.width, height: Self.size.height)
            .scaleEffect(0.4 + 0.6 * mole.holeOpenness)
            .opacity(mole.holeOpenness)
            .position(mole.hole)
    }
}

/// The mole coming up out of its hole: everything below the middle of the hole is hidden, so it
/// rises out of the ground and sinks back into it. While it reaches up it leans towards the
/// basket; once it has the carrot it holds it over its head (`FoxPath/Mole/Carrot`).
private struct ThiefMoleView: View {
    let mole: MoleThiefVisual

    var body: some View {
        let size = mole.holdsCarrot ? MoleThiefVisual.carrotSize : MoleThiefVisual.standingSize
        let window = CGSize(width: size.width * 1.6, height: size.height * 1.25)
        let shown = CGFloat(mole.rise) * MoleThiefVisual.highestRise * size.height
        let stretch = CGFloat(sin(mole.reach * .pi))
        Image(mole.holdsCarrot ? "FoxPath/Mole/Carrot" : "FoxPath/Mole/Standing")
            .resizable()
            .frame(width: size.width, height: size.height)
            .rotationEffect(.degrees(Double(mole.towardBasket * 9 * stretch)), anchor: .bottom)
            .offset(y: size.height - shown - 6 * stretch)
            .frame(width: window.width, height: window.height, alignment: .bottom)
            .clipped()
            .position(x: mole.hole.x, y: mole.hole.y - window.height / 2)
    }
}

private struct MapSpriteView: View {
    let sprite: MapSprite

    var body: some View {
        Image(sprite.kind.assetName)
            .resizable()
            .scaleEffect(x: sprite.isMirrored ? -1 : 1, y: 1)
            .frame(width: sprite.frame.width, height: sprite.frame.height)
            .position(x: sprite.frame.midX, y: sprite.frame.midY)
    }
}

struct FoxSpriteView: View {
    let pose: FoxWalkPose

    var body: some View {
        let frame = pose.frame
        Image(pose.assetName)
            .resizable()
            .scaleEffect(x: pose.isMirrored ? -1 : 1, y: 1)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }
}
