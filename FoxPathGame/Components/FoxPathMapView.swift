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
                    thief: viewModel.thiefPose,
                    thiefVisibility: viewModel.thiefVisibility
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

/// Houses, lamps, gardens, the finish stall and the characters, drawn back to front by where they touch the ground so a character walks in front of things behind it.
private struct FoxPathStandingView: View {
    let sprites: [MapSprite]
    let fox: FoxWalkPose
    let thief: FoxWalkPose?
    let thiefVisibility: Double

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
            if let thief {
                Group {
                    GroundMarker(feet: thief.feet, width: thief.frame.width, color: FoxPathPalette.danger)
                        .zIndex(Double(thief.feet.y) - 0.5)
                    FoxSpriteView(pose: thief)
                        .zIndex(Double(thief.feet.y))
                }
                .opacity(thiefVisibility)
            }
        }
    }
}

/// Soft oval on the ground under a character: white under the friend the child follows, red
/// under the thief, so the two roles are easy to tell apart whoever plays them.
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
