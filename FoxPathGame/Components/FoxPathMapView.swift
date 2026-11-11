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
                FoxPathStandingView(sprites: viewModel.map.standingSprites, fox: viewModel.foxPose)
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

/// Houses, lamps, the finish flag and the fox, drawn back to front by where they touch the
/// ground so the fox walks in front of things behind the path.
private struct FoxPathStandingView: View {
    let sprites: [MapSprite]
    let fox: FoxWalkPose

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(sprites) { sprite in
                MapSpriteView(sprite: sprite)
                    .zIndex(Double(sprite.baseline))
            }
            FoxSpriteView(pose: fox)
                .zIndex(Double(fox.feet.y))
        }
    }
}

private struct MapSpriteView: View {
    let sprite: MapSprite

    var body: some View {
        Group {
            if let assetName = sprite.kind.assetName {
                Image(assetName)
                    .resizable()
                    .scaleEffect(x: sprite.isMirrored ? -1 : 1, y: 1)
            } else {
                FinishFlagView()
            }
        }
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
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }
}

/// Checkered flag on a white pole that marks the end of the path. Drawn in code because no
/// flag art was provided.
private struct FinishFlagView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let poleWidth = size.width * 0.12
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(.white)
                    .frame(width: poleWidth, height: size.height)
                    .offset(x: size.width * 0.14)
                Canvas { context, canvasSize in
                    let columns = 4
                    let rows = 3
                    let cell = CGSize(width: canvasSize.width / CGFloat(columns), height: canvasSize.height / CGFloat(rows))
                    context.fill(Path(CGRect(origin: .zero, size: canvasSize)), with: .color(.white))
                    for row in 0..<rows {
                        for column in 0..<columns where (row + column).isMultiple(of: 2) {
                            let rect = CGRect(x: CGFloat(column) * cell.width, y: CGFloat(row) * cell.height, width: cell.width, height: cell.height)
                            context.fill(Path(rect), with: .color(FoxPathPalette.ink))
                        }
                    }
                }
                .frame(width: size.width * 0.72, height: size.height * 0.34)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .offset(x: size.width * 0.14 + poleWidth, y: size.height * 0.04)
                Ellipse()
                    .fill(.black.opacity(0.18))
                    .frame(width: size.width * 0.4, height: size.height * 0.05)
                    .offset(x: 0, y: size.height * 0.975)
            }
        }
    }
}
