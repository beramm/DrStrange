import CoreGraphics
import Foundation

/// One square of the map grid. Column 0 is the left edge, row 0 the top.
struct GridCell: Hashable {
    var column: Int
    var row: Int
}

/// Which piece of path art a cell shows.
enum PathTile: Equatable {
    enum Side: Equatable { case left, right }
    enum End: Equatable { case top, bottom }

    case horizontal
    case vertical
    /// Quarter turn joining the cell's left or right edge to its top or bottom edge.
    case curve(side: Side, end: End)
}

struct PathCell: Equatable {
    let cell: GridCell
    let tile: PathTile
}

/// Sizes shared by the generator, the engine and the views. Everything on the map is measured
/// in map units; the view scales the whole map to the screen.
enum FoxPathMetrics {
    static let columns = 12
    static let rows = 9
    /// Same proportions as the provided tiles (16:15).
    static let cellSize = CGSize(width: 128, height: 120)
    static let mapSize = CGSize(width: cellSize.width * CGFloat(columns), height: cellSize.height * CGFloat(rows))
    /// Half the width of the beige path band, measured across the path.
    static let pathHalfWidth: CGFloat = 39
    /// Rows the path may use. The top rows stay free so the fox's head never leaves the map.
    static let pathRows = 2...6
    /// Map units for one pixel of the source art (tiles are 576 px wide).
    static let unitsPerArtPixel = cellSize.width / 576
    /// The fox starts this far inside the first tile.
    static let routeInset: CGFloat = 70
    /// The fox stops this far before the right edge, in front of the middle of the finish stall.
    static let routeEndInset: CGFloat = 150
    /// Tiles at the right end of the path that are always straight, so the finish stall fits
    /// above them without standing on a bend.
    static let finalStraightColumns = 3

    static func rect(of cell: GridCell) -> CGRect {
        CGRect(
            x: CGFloat(cell.column) * cellSize.width,
            y: CGFloat(cell.row) * cellSize.height,
            width: cellSize.width,
            height: cellSize.height
        )
    }
}

/// The fox's three looks. The provided art has a side view walking right, a front view and a
/// back view; the path only ever runs right, up or down.
enum FoxFacing: Equatable {
    case side
    case front
    case back

    /// Drawn size in map units.
    var size: CGSize {
        switch self {
        case .side: CGSize(width: 119, height: 219)
        case .front, .back: CGSize(width: 134, height: 218)
        }
    }

    /// Where the feet touch the ground, as a fraction of the image.
    var feetAnchor: CGPoint {
        switch self {
        case .side: CGPoint(x: 0.49, y: 0.965)
        case .front, .back: CGPoint(x: 0.45, y: 0.975)
        }
    }

    /// Frame for a walking direction: sideways unless the path is mostly vertical.
    static func walking(along tangent: CGVector) -> FoxFacing {
        if abs(tangent.dx) >= abs(tangent.dy) { return .side }
        return tangent.dy < 0 ? .back : .front
    }
}

/// The body area the fox can cover while standing with its feet at `feet`, whichever way it
/// faces. Used to keep scenery from hiding the fox.
func foxBodyRect(feet: CGPoint) -> CGRect {
    CGRect(x: feet.x - 70, y: feet.y - 215, width: 140, height: 222)
}

/// Things drawn on the map besides the path.
enum MapSpriteKind: String, CaseIterable {
    case carrotHouseFront, carrotHouseBack
    case mushroomHouseFront, mushroomHouseBack
    case onionHouseFront, onionHouseBack
    case lamp
    case finishStall
    case steppingStone
    case grassTuft1, grassTuft2
    case soilSpeck

    /// Asset in the `FoxPath` namespace.
    var assetName: String {
        switch self {
        case .carrotHouseFront: "FoxPath/HouseCarrotFront"
        case .carrotHouseBack: "FoxPath/HouseCarrotBack"
        case .mushroomHouseFront: "FoxPath/HouseMushroomFront"
        case .mushroomHouseBack: "FoxPath/HouseMushroomBack"
        case .onionHouseFront: "FoxPath/HouseOnionFront"
        case .onionHouseBack: "FoxPath/HouseOnionBack"
        case .lamp: "FoxPath/Lamp"
        case .finishStall: "FoxPath/FinishStall"
        case .steppingStone: "FoxPath/SteppingStone"
        case .grassTuft1: "FoxPath/GrassTuft1"
        case .grassTuft2: "FoxPath/GrassTuft2"
        case .soilSpeck: "FoxPath/SoilSpeck"
        }
    }

    /// Drawn size in map units at scale 1.
    var size: CGSize {
        switch self {
        case .carrotHouseFront, .carrotHouseBack: CGSize(width: 216, height: 371)
        case .mushroomHouseFront, .mushroomHouseBack: CGSize(width: 322, height: 273)
        case .onionHouseFront, .onionHouseBack: CGSize(width: 259, height: 291)
        case .lamp: CGSize(width: 37, height: 192)
        case .finishStall: CGSize(width: 300, height: 250)
        case .steppingStone: CGSize(width: 85, height: 28)
        case .grassTuft1: CGSize(width: 16.5, height: 22)
        case .grassTuft2: CGSize(width: 16, height: 17.5)
        case .soilSpeck: CGSize(width: 35, height: 16)
        }
    }

    var isHouse: Bool {
        switch self {
        case .carrotHouseFront, .carrotHouseBack, .mushroomHouseFront, .mushroomHouseBack,
             .onionHouseFront, .onionHouseBack: true
        default: false
        }
    }

    /// Part of the sprite's width that touches the ground, as fractions of the width.
    var baseSpan: ClosedRange<CGFloat> {
        switch self {
        case .carrotHouseFront, .carrotHouseBack: 0.15...0.89
        case .mushroomHouseFront, .mushroomHouseBack: 0.23...0.86
        case .onionHouseFront, .onionHouseBack: 0.18...0.81
        case .lamp: 0.2...0.8
        case .finishStall: 0.04...0.95
        default: 0...1
        }
    }

    /// Horizontal centre of the front door, as a fraction of the width. Front houses only.
    var doorCenter: CGFloat? {
        switch self {
        case .carrotHouseFront: 0.5
        case .mushroomHouseFront: 0.55
        case .onionHouseFront: 0.47
        default: nil
        }
    }
}

struct MapSprite: Identifiable, Equatable {
    let id: Int
    let kind: MapSpriteKind
    /// Where the sprite is drawn, in map units.
    let frame: CGRect
    var isMirrored = false

    /// Ground line used for depth: sprites lower on the map are drawn in front.
    var baseline: CGFloat { frame.maxY }

    /// The strip of ground the sprite stands on.
    var footprint: CGRect {
        let span = kind.baseSpan
        let height = min(frame.height * 0.22, 60)
        return CGRect(
            x: frame.minX + frame.width * span.lowerBound,
            y: frame.maxY - height,
            width: frame.width * (span.upperBound - span.lowerBound),
            height: height
        )
    }
}

/// A full grass tile with painted tufts, dropped on an empty cell.
struct GrassPatch: Equatable {
    let cell: GridCell
    /// 1 or 2 (`FoxPath/GrassPatch1`, `FoxPath/GrassPatch2`).
    let variant: Int
    let isMirrored: Bool

    var assetName: String { "FoxPath/GrassPatch\(variant)" }
}

/// One randomly generated map: the path, the line the fox walks and the scenery.
struct FoxPathMap: Equatable {
    let seed: UInt64
    /// Path tiles in walking order, from the left edge to the right edge.
    let pathCells: [PathCell]
    let route: FoxRoute
    let grassPatches: [GrassPatch]
    /// Flat details that lie on the grass: stepping stones, tufts and soil specks.
    let groundSprites: [MapSprite]
    /// Things that stand up and can overlap the fox: houses, lamps and the finish stall.
    let standingSprites: [MapSprite]

    var size: CGSize { FoxPathMetrics.mapSize }
    var houses: [MapSprite] { standingSprites.filter(\.kind.isHouse) }
    var lamps: [MapSprite] { standingSprites.filter { $0.kind == .lamp } }
}
