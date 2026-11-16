import CoreGraphics
import Foundation

/// Builds a random map from a seed: a path that winds from the left edge to the right edge,
/// then houses, lamps, rocks, gardens, stepping stones and grass details around it.
///
/// The same seed and settings always give the same map. Scenery is placed so that nothing
/// stands on the path and nothing is ever drawn over the fox.
enum FoxPathGenerator {
    /// Fewer houses or lamps than this and the generator tries again with a derived seed.
    private static let wantedHouses = 3
    private static let wantedLamps = 3
    private static let maximumAttempts = 8

    static func makeMap(seed: UInt64, settings: FoxPathSettings) -> FoxPathMap {
        var best: FoxPathMap?
        func score(_ map: FoxPathMap) -> Int {
            min(map.houses.count, wantedHouses) * 10 + min(map.lamps.count, wantedLamps)
        }
        for attempt in 0..<maximumAttempts {
            var generator = SeededGenerator(seed: seed &+ UInt64(attempt) &* 0xD6E8_FEB8_6659_FD93)
            let map = makeMap(seed: seed, settings: settings, using: &generator)
            if map.houses.count >= wantedHouses, map.lamps.count >= wantedLamps { return map }
            if score(map) > best.map(score) ?? -1 { best = map }
        }
        return best!
    }

    private static func makeMap(
        seed: UInt64,
        settings: FoxPathSettings,
        using generator: inout SeededGenerator
    ) -> FoxPathMap {
        let pathCells = makePath(settings: settings, using: &generator)
        let route = makeRoute(for: pathCells)
        var scenery = SceneryBuilder(route: route, generator: generator)
        scenery.placeFinishStall()
        scenery.placeHouses()
        scenery.placeLamps()
        scenery.placePathRocks()
        scenery.fillOpenGrass()
        let grassPatches = scenery.makeGrassPatches(avoiding: Set(pathCells.map(\.cell)))
        scenery.scatterGrassDetails()
        generator = scenery.generator
        return FoxPathMap(
            seed: seed,
            pathCells: pathCells,
            route: route,
            grassPatches: grassPatches,
            groundSprites: scenery.ground,
            standingSprites: scenery.standing
        )
    }

    // MARK: - Path

    /// A staircase from column 0 to the last column that only ever goes right, up or down,
    /// like the provided reference maps. The first tile and the last few tiles are always straight.
    static func makePath(settings: FoxPathSettings, using generator: inout SeededGenerator) -> [PathCell] {
        let columns = FoxPathMetrics.columns
        let rows = FoxPathMetrics.pathRows
        var row = Int.random(in: rows, using: &generator)
        var straightLeft = Int.random(in: settings.straightRunRange, using: &generator)
        var cells: [PathCell] = []

        for column in 0..<columns {
            // The last columns stay straight so the path leaves through the right edge and the
            // finish stall has room above it.
            if straightLeft > 0 || column >= columns - FoxPathMetrics.finalStraightColumns {
                cells.append(PathCell(cell: GridCell(column: column, row: row), tile: .horizontal))
                straightLeft -= 1
                continue
            }

            let preferred = rows.filter { settings.turnHeightRange.contains(abs($0 - row)) }
            let candidates = preferred.isEmpty ? rows.filter { $0 != row } : preferred
            let target = candidates.randomElement(using: &generator) ?? row
            let goesDown = target > row
            let step = goesDown ? 1 : -1

            cells.append(PathCell(
                cell: GridCell(column: column, row: row),
                tile: .curve(side: .left, end: goesDown ? .bottom : .top)
            ))
            for between in stride(from: row + step, to: target, by: step) {
                cells.append(PathCell(cell: GridCell(column: column, row: between), tile: .vertical))
            }
            cells.append(PathCell(
                cell: GridCell(column: column, row: target),
                tile: .curve(side: .right, end: goesDown ? .top : .bottom)
            ))
            row = target
            straightLeft = Int.random(in: settings.straightRunRange, using: &generator)
        }
        return cells
    }

    // MARK: - Route

    /// Centre line of the path: straight through straight tiles and a quarter ellipse around the
    /// inner corner of each turn, which is how the curve tile is drawn.
    static func makeRoute(for cells: [PathCell]) -> FoxRoute {
        var points: [CGPoint] = []
        func append(_ point: CGPoint) {
            if let last = points.last, hypot(last.x - point.x, last.y - point.y) < 0.01 { return }
            points.append(point)
        }

        for (index, pathCell) in cells.enumerated() {
            let rect = FoxPathMetrics.rect(of: pathCell.cell)
            switch pathCell.tile {
            case .horizontal:
                // The fox stops in front of the stall, which can be a tile or two before the edge.
                let stopX = FoxPathMetrics.mapSize.width - FoxPathMetrics.routeEndInset
                let startX = rect.minX + (index == 0 ? FoxPathMetrics.routeInset : 0)
                append(CGPoint(x: min(startX, stopX), y: rect.midY))
                append(CGPoint(x: min(rect.maxX, stopX), y: rect.midY))
            case .vertical:
                let goesDown = index > 0 && cells[index - 1].cell.row < pathCell.cell.row
                append(CGPoint(x: rect.midX, y: goesDown ? rect.minY : rect.maxY))
                append(CGPoint(x: rect.midX, y: goesDown ? rect.maxY : rect.minY))
            case let .curve(side, end):
                let sidePoint = CGPoint(x: side == .left ? rect.minX : rect.maxX, y: rect.midY)
                let endPoint = CGPoint(x: rect.midX, y: end == .top ? rect.minY : rect.maxY)
                let corner = CGPoint(x: sidePoint.x, y: endPoint.y)
                // The path always travels right, so a turn is entered through its left side or
                // left through its right side.
                let (from, to) = side == .left ? (sidePoint, endPoint) : (endPoint, sidePoint)
                let steps = 12
                for step in 0...steps {
                    let angle = CGFloat.pi / 2 * CGFloat(step) / CGFloat(steps)
                    append(CGPoint(
                        x: corner.x + (from.x - corner.x) * cos(angle) + (to.x - corner.x) * sin(angle),
                        y: corner.y + (from.y - corner.y) * cos(angle) + (to.y - corner.y) * sin(angle)
                    ))
                }
            }
        }
        return FoxRoute(points: points)
    }

    /// The route continued past both map edges, where the path art carries on. Scenery is
    /// checked against this line so nothing lands on the first or last stretch of path either.
    static func pathLine(for route: FoxRoute) -> FoxRoute {
        let first = route.points[0]
        let last = route.points[route.points.count - 1]
        let overshoot = FoxPathMetrics.cellSize.width * 2
        return FoxRoute(
            points: [CGPoint(x: -overshoot, y: first.y)] + route.points
                + [CGPoint(x: FoxPathMetrics.mapSize.width + overshoot, y: last.y)]
        )
    }

    /// `true` when a standing sprite neither stands on the path nor hides the fox anywhere
    /// along it. `pathPoints` are closely spaced points on the path's centre line.
    static func isClear(_ sprite: MapSprite, of pathPoints: [CGPoint]) -> Bool {
        let margin = FoxPathMetrics.pathHalfWidth + 6
        let blocked = sprite.footprint.insetBy(dx: -margin, dy: -margin)
        let body = sprite.frame.insetBy(dx: 4, dy: 4)
        for point in pathPoints {
            if blocked.contains(point) { return false }
            // Standing lower than the fox here means being drawn in front of it.
            if sprite.baseline > point.y, body.intersects(foxBodyRect(feet: point)) { return false }
        }
        return true
    }
}

// MARK: - Scenery

private struct SceneryBuilder {
    private enum HouseStyle: CaseIterable {
        case carrot, mushroom, onion

        /// Houses above the path show their door; houses below it are seen from behind.
        func kind(showingFront: Bool) -> MapSpriteKind {
            switch self {
            case .carrot: showingFront ? .carrotHouseFront : .carrotHouseBack
            case .mushroom: showingFront ? .mushroomHouseFront : .mushroomHouseBack
            case .onion: showingFront ? .onionHouseFront : .onionHouseBack
            }
        }
    }

    let route: FoxRoute
    let pathLine: FoxRoute
    let pathPoints: [CGPoint]
    var generator: SeededGenerator
    private(set) var standing: [MapSprite] = []
    private(set) var ground: [MapSprite] = []
    private var nextID = 0

    private let mapSize = FoxPathMetrics.mapSize
    private let pathHalfWidth = FoxPathMetrics.pathHalfWidth

    init(route: FoxRoute, generator: SeededGenerator) {
        self.route = route
        self.generator = generator
        pathLine = FoxPathGenerator.pathLine(for: route)
        pathPoints = pathLine.samples(spacing: 6)
    }

    private mutating func makeSprite(_ kind: MapSpriteKind, frame: CGRect, isMirrored: Bool = false) -> MapSprite {
        nextID += 1
        return MapSprite(id: nextID, kind: kind, frame: frame, isMirrored: isMirrored)
    }

    private func overlapsStanding(_ rect: CGRect) -> Bool {
        standing.contains { $0.frame.intersects(rect) }
    }

    // MARK: Finish stall

    /// The veggie stall stands just behind the end of the route, so the fox stops in front of
    /// its counter.
    mutating func placeFinishStall() {
        let end = route.points[route.points.count - 1]
        let size = MapSpriteKind.finishStall.size
        let frame = CGRect(
            x: min(end.x - size.width / 2, mapSize.width - size.width),
            y: end.y - pathHalfWidth - 8 - size.height,
            width: size.width,
            height: size.height
        )
        standing.append(makeSprite(.finishStall, frame: frame))
    }

    // MARK: Houses

    /// Houses spread out along the map: each one first tries its own share of the width, so
    /// they do not bunch up on one side.
    mutating func placeHouses() {
        let wanted = Int.random(in: 3...4, using: &generator)
        var styles = ShuffleBag(HouseStyle.allCases)
        var above = Bool.random(using: &generator)

        for index in 0..<wanted {
            let style = styles.next(using: &generator)
            let band = (CGFloat(index) / CGFloat(wanted))...(CGFloat(index + 1) / CGFloat(wanted))
            // Try the preferred side first, then the other one, then anywhere along the map.
            let placed = placeHouse(style, above: above, band: band)
                || placeHouse(style, above: !above, band: band)
                || placeHouse(style, above: above, band: 0...1)
            if placed { above.toggle() }
        }
    }

    private mutating func placeHouse(_ style: HouseStyle, above: Bool, band: ClosedRange<CGFloat>) -> Bool {
        let kind = style.kind(showingFront: above)
        let size = kind.size
        let lowest = max(size.width * 0.42, mapSize.width * band.lowerBound)
        let highest = min(mapSize.width - size.width * 0.42, mapSize.width * band.upperBound)
        guard lowest < highest else { return false }

        for _ in 0..<40 {
            let centerX = CGFloat.random(in: lowest...highest, using: &generator)
            let minX = centerX - size.width / 2
            let gap = CGFloat.random(in: above ? 14...88 : 8...56, using: &generator)

            // The stretch of path in line with the house's base decides how close it can stand.
            let baseStart = minX + size.width * kind.baseSpan.lowerBound - 12
            let baseEnd = minX + size.width * kind.baseSpan.upperBound + 12
            let inLine = pathPoints.filter { $0.x >= baseStart && $0.x <= baseEnd }.map(\.y)
            guard let highest = inLine.min(), let lowest = inLine.max() else { continue }

            let frame: CGRect
            if above {
                let baseline = highest - pathHalfWidth - gap
                frame = CGRect(x: minX, y: baseline - size.height, width: size.width, height: size.height)
                // The top may poke out of the map a little, as in the reference art.
                guard frame.minY >= -size.height * 0.12 else { continue }
            } else {
                frame = CGRect(x: minX, y: lowest + pathHalfWidth + gap, width: size.width, height: size.height)
                guard frame.maxY <= mapSize.height + size.height * 0.35 else { continue }
            }

            let house = makeSprite(kind, frame: frame)
            guard FoxPathGenerator.isClear(house, of: pathPoints),
                  !overlapsStanding(frame.insetBy(dx: -8, dy: -8)) else { continue }
            standing.append(house)
            addSteppingStones(from: house)
            addDoorstep(for: house)
            addRocks(around: house)
            return true
        }
        return false
    }

    /// A short trail of stones from a front door down to the path.
    private mutating func addSteppingStones(from house: MapSprite) {
        guard let door = house.kind.doorCenter else { return }
        let doorX = house.frame.minX + house.frame.width * door
        // Every stretch of path a stone could touch counts, so a trail next to a corner stops
        // on the grass instead of running over the bend.
        let stoneSize = MapSpriteKind.steppingStone.size
        let reach = pathHalfWidth + stoneSize.width * 0.75
        let pathBelow = pathPoints.filter { abs($0.x - doorX) < reach && $0.y > house.baseline }.map(\.y).min()
        guard let pathBelow else { return }

        let start = house.baseline + 4
        let end = pathBelow - pathHalfWidth - stoneSize.height * 0.7
        let length = end - start
        guard length > 22 else { return }

        let count = min(5, max(1, Int(length / 28)))
        let drift = CGFloat.random(in: -16...16, using: &generator)
        for index in 0..<count {
            let fraction = (CGFloat(index) + 0.5) / CGFloat(count)
            let scale = CGFloat.random(in: 0.9...1.25, using: &generator)
            let size = MapSpriteKind.steppingStone.size
            let center = CGPoint(
                x: doorX + drift * (fraction - 0.5) * 2 + CGFloat.random(in: -5...5, using: &generator),
                y: start + length * fraction
            )
            let frame = CGRect(
                x: center.x - size.width * scale / 2,
                y: center.y - size.height * scale / 2,
                width: size.width * scale,
                height: size.height * scale
            )
            ground.append(makeSprite(.steppingStone, frame: frame, isMirrored: Bool.random(using: &generator)))
        }
    }

    /// Two stepping stones either side of the trail, just below a front door, like a little
    /// front yard.
    private mutating func addDoorstep(for house: MapSprite) {
        guard let door = house.kind.doorCenter else { return }
        let doorX = house.frame.minX + house.frame.width * door
        let size = MapSpriteKind.steppingStone.size
        for side: CGFloat in [-1, 1] {
            let scale = CGFloat.random(in: 0.75...0.95, using: &generator)
            let center = CGPoint(
                x: doorX + side * CGFloat.random(in: 62...82, using: &generator),
                y: house.baseline + CGFloat.random(in: 2...16, using: &generator)
            )
            let frame = CGRect(
                x: center.x - size.width * scale / 2,
                y: center.y - size.height * scale / 2,
                width: size.width * scale,
                height: size.height * scale
            )
            guard pathLine.distance(to: center) > pathHalfWidth + frame.width / 2 + 6,
                  !ground.contains(where: { $0.frame.insetBy(dx: -4, dy: -4).intersects(frame) }),
                  !standing.contains(where: { $0.footprint.intersects(frame) }) else { continue }
            ground.append(makeSprite(.steppingStone, frame: frame, isMirrored: Bool.random(using: &generator)))
        }
    }

    /// A few grey rocks on the grass in front of a house.
    private mutating func addRocks(around house: MapSprite) {
        let stone = MapSpriteKind.pathRock.size
        let span = house.kind.baseSpan
        let isFront = house.kind.doorCenter != nil
        let wanted = Int.random(in: 3...5, using: &generator)
        var placed = 0
        for _ in 0..<(wanted * 8) where placed < wanted {
            let scale = CGFloat.random(in: 0.8...1.3, using: &generator)
            let size = CGSize(width: stone.width * scale, height: stone.height * scale)
            let center = CGPoint(
                x: house.frame.minX + house.frame.width * CGFloat.random(in: (span.lowerBound - 0.2)...(span.upperBound + 0.2), using: &generator),
                y: house.baseline + (isFront
                    ? CGFloat.random(in: 6...52, using: &generator)
                    : CGFloat.random(in: -24...24, using: &generator))
            )
            let frame = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
            guard frame.minX >= 4, frame.maxX <= mapSize.width - 4, frame.maxY <= mapSize.height - 4,
                  pathLine.distance(to: center) > pathHalfWidth + size.width / 2 + 6,
                  !ground.contains(where: { $0.frame.insetBy(dx: -4, dy: -4).intersects(frame) }),
                  !standing.contains(where: { $0.footprint.intersects(frame) }) else { continue }
            ground.append(makeSprite(.pathRock, frame: frame, isMirrored: Bool.random(using: &generator)))
            placed += 1
        }
    }

    // MARK: Rocks by the path

    /// Grey rocks just beside the path, spread along the whole walk, on alternating sides.
    mutating func placePathRocks() {
        let wanted = Int.random(in: 7...10, using: &generator)
        let size = MapSpriteKind.pathRock.size
        var side: CGFloat = Bool.random(using: &generator) ? 1 : -1
        for index in 0..<wanted {
            for _ in 0..<12 {
                let along = (CGFloat(index) + CGFloat.random(in: 0.15...0.85, using: &generator)) / CGFloat(wanted)
                let (point, tangent) = route.sample(at: route.length * along)
                let scale = CGFloat.random(in: 0.75...1.25, using: &generator)
                // Sideways from a vertical stretch the rock's width counts, from a horizontal one its height.
                let reach = (abs(tangent.dx) >= abs(tangent.dy) ? size.height : size.width) * scale / 2
                let offset = (pathHalfWidth + reach + CGFloat.random(in: 6...20, using: &generator)) * side
                let center = CGPoint(x: point.x - tangent.dy * offset, y: point.y + tangent.dx * offset)
                let frame = CGRect(
                    x: center.x - size.width * scale / 2,
                    y: center.y - size.height * scale / 2,
                    width: size.width * scale,
                    height: size.height * scale
                )
                guard frame.minX >= 4, frame.maxX <= mapSize.width - 4, frame.minY >= 4, frame.maxY <= mapSize.height - 4,
                      [CGPoint(x: frame.minX, y: frame.minY), CGPoint(x: frame.maxX, y: frame.minY),
                       CGPoint(x: frame.minX, y: frame.maxY), CGPoint(x: frame.maxX, y: frame.maxY), center]
                        .allSatisfy({ pathLine.distance(to: $0) > pathHalfWidth + 3 }),
                      !ground.contains(where: { $0.frame.insetBy(dx: -6, dy: -6).intersects(frame) }),
                      !standing.contains(where: { $0.footprint.intersects(frame.insetBy(dx: -6, dy: -6)) }) else { continue }
                ground.append(makeSprite(.pathRock, frame: frame, isMirrored: Bool.random(using: &generator)))
                side = -side
                break
            }
        }
    }

    // MARK: Lamps

    /// Street lamps on the grass beside the path, one per stretch of the route so they spread
    /// along the whole walk.
    mutating func placeLamps() {
        let wanted = Int.random(in: 4...6, using: &generator)
        let size = MapSpriteKind.lamp.size

        for index in 0..<wanted {
            for _ in 0..<24 {
                let along = (CGFloat(index) + CGFloat.random(in: 0.1...0.9, using: &generator)) / CGFloat(wanted)
                let (point, tangent) = route.sample(at: route.length * along)
                let side: CGFloat = Bool.random(using: &generator) ? 1 : -1
                let offset = (pathHalfWidth + CGFloat.random(in: 10...30, using: &generator)) * side
                // Step sideways from the centre line onto the grass.
                let base = CGPoint(x: point.x - tangent.dy * offset, y: point.y + tangent.dx * offset)
                let frame = CGRect(x: base.x - size.width / 2, y: base.y - size.height, width: size.width, height: size.height)
                let lamp = makeSprite(.lamp, frame: frame)

                let isOnMap = frame.minX >= 8 && frame.maxX <= mapSize.width - 8 && frame.minY >= 0
                let isApart = !standing.contains { other in
                    other.kind == .lamp && abs(other.frame.midX - frame.midX) < 150 && abs(other.baseline - lamp.baseline) < 150
                }
                guard isOnMap, isApart,
                      FoxPathGenerator.isClear(lamp, of: pathPoints),
                      !overlapsStanding(frame.insetBy(dx: -34, dy: 0)) else { continue }
                standing.append(lamp)
                break
            }
        }
    }

    // MARK: Gardens

    private enum GardenStyle: CaseIterable {
        /// A row or two of onions coming up through the soil.
        case onionBed
        /// A clump of leafy plants.
        case leafyClump
        /// Baskets and a crate of vegetables, as if just picked.
        case harvest
        /// Leafy plants with a basket beside them.
        case leafyWithBasket
    }

    /// Open grass farther than this from any house, lamp, stall or garden gets a garden.
    private static let openGrassDistance: CGFloat = 165
    private static let maximumGardens = 12

    /// Fills the open grass with small gardens, always in the emptiest spot left, until no
    /// large empty area remains. Nothing lands on the path or in front of the characters.
    mutating func fillOpenGrass() {
        let spacing: CGFloat = 48
        var spots: [CGPoint] = []
        for y in stride(from: CGFloat(110), through: mapSize.height - 20, by: spacing) {
            for x in stride(from: CGFloat(60), through: mapSize.width - 60, by: spacing) {
                let point = CGPoint(x: x, y: y)
                if pathLine.distance(to: point) > pathHalfWidth + 70 { spots.append(point) }
            }
        }
        var styles = ShuffleBag(GardenStyle.allCases)
        var tried: [CGPoint] = []

        for _ in 0..<(Self.maximumGardens * 3) {
            let features = standing.map(\.frame)
            func openness(_ point: CGPoint) -> CGFloat {
                let fromScenery = features.map { distance(from: point, to: $0) }.min() ?? .greatestFiniteMagnitude
                let fromTried = tried.map { hypot($0.x - point.x, $0.y - point.y) }.min() ?? .greatestFiniteMagnitude
                return min(fromScenery, fromTried)
            }
            guard let spot = spots.max(by: { openness($0) < openness($1) }),
                  openness(spot) > Self.openGrassDistance else { return }
            tried.append(spot)
            let style = styles.next(using: &generator)
            _ = placeGarden(style, at: spot)
            if standing.filter(\.kind.isGardenPiece).count >= Self.maximumGardens * 4 { return }
        }
    }

    /// Places the pieces of one garden around `spot`. Returns `true` when at least one landed.
    private mutating func placeGarden(_ style: GardenStyle, at spot: CGPoint) -> Bool {
        var pieces: [(MapSpriteKind, CGPoint)] = []
        switch style {
        case .onionBed:
            let columns = Int.random(in: 3...4, using: &generator)
            let rows = Int.random(in: 1...2, using: &generator)
            for row in 0..<rows {
                for column in 0..<columns {
                    let x = spot.x + (CGFloat(column) - CGFloat(columns - 1) / 2) * 64 + (row == 1 ? 32 : 0)
                    pieces.append((.onionSprout, CGPoint(x: x, y: spot.y + CGFloat(row) * 42)))
                }
            }
        case .leafyClump:
            let count = Int.random(in: 2...3, using: &generator)
            for index in 0..<count {
                let x = spot.x + (CGFloat(index) - CGFloat(count - 1) / 2) * 70
                pieces.append((.leafyPlant, CGPoint(x: x, y: spot.y + (index.isMultiple(of: 2) ? 0 : 20))))
            }
        case .harvest:
            pieces.append((.baskets, CGPoint(x: spot.x - 46, y: spot.y)))
            pieces.append((.veggieCrate, CGPoint(x: spot.x + 60, y: spot.y + 18)))
        case .leafyWithBasket:
            pieces.append((.leafyPlant, CGPoint(x: spot.x - 56, y: spot.y)))
            pieces.append((.leafyPlant, CGPoint(x: spot.x + 10, y: spot.y + 22)))
            pieces.append((.baskets, CGPoint(x: spot.x + 94, y: spot.y + 14)))
        }

        var placedAny = false
        let mirrored = Bool.random(using: &generator)
        for (kind, base) in pieces {
            let scale = CGFloat.random(in: 0.92...1.1, using: &generator)
            let size = CGSize(width: kind.size.width * scale, height: kind.size.height * scale)
            // `base` is where the piece touches the ground.
            let jitter = CGPoint(x: CGFloat.random(in: -6...6, using: &generator), y: CGFloat.random(in: -4...4, using: &generator))
            let frame = CGRect(x: base.x + jitter.x - size.width / 2, y: base.y + jitter.y - size.height, width: size.width, height: size.height)
            guard frame.minX >= 4, frame.maxX <= mapSize.width - 4, frame.minY >= 0, frame.maxY <= mapSize.height - 4 else { continue }
            let piece = makeSprite(kind, frame: frame, isMirrored: kind == .veggieCrate ? false : (mirrored != Bool.random(using: &generator)))
            guard FoxPathGenerator.isClear(piece, of: pathPoints),
                  !standing.contains(where: { $0.frame.insetBy(dx: -4, dy: -4).intersects(frame.insetBy(dx: 6, dy: 6)) }) else { continue }
            standing.append(piece)
            placedAny = true
            if kind == .onionSprout || kind == .leafyPlant {
                // A little dark soil at the foot of each plant.
                let speck = MapSpriteKind.soilSpeck.size
                let soil = CGRect(x: frame.midX - speck.width * 0.7, y: frame.maxY - speck.height * 0.9, width: speck.width * 1.4, height: speck.height * 1.2)
                ground.append(makeSprite(.soilSpeck, frame: soil, isMirrored: Bool.random(using: &generator)))
            }
        }
        return placedAny
    }

    private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
    }

    // MARK: Grass

    /// Painted grass tiles on a few empty cells.
    mutating func makeGrassPatches(avoiding pathCells: Set<GridCell>) -> [GrassPatch] {
        var free: [GridCell] = []
        for row in 0..<FoxPathMetrics.rows {
            for column in 0..<FoxPathMetrics.columns {
                let cell = GridCell(column: column, row: row)
                let rect = FoxPathMetrics.rect(of: cell)
                let isHidden = standing.contains { $0.kind.isHouse && $0.footprint.intersects(rect) }
                if !pathCells.contains(cell), !isHidden { free.append(cell) }
            }
        }
        free.shuffle(using: &generator)
        let wanted = Int.random(in: 10...14, using: &generator)
        return free.prefix(wanted).map { cell in
            GrassPatch(
                cell: cell,
                variant: Int.random(in: 1...2, using: &generator),
                isMirrored: Bool.random(using: &generator)
            )
        }
    }

    /// Loose tufts and soil specks anywhere on the grass.
    mutating func scatterGrassDetails() {
        let wanted = Int.random(in: 44...56, using: &generator)
        let kinds: [MapSpriteKind] = [.grassTuft1, .grassTuft2, .soilSpeck]
        var placed = 0
        var attempts = 0

        while placed < wanted, attempts < wanted * 8 {
            attempts += 1
            let kind = kinds.randomElement(using: &generator) ?? .grassTuft1
            let scale = CGFloat.random(in: 1.1...1.8, using: &generator)
            let size = CGSize(width: kind.size.width * scale, height: kind.size.height * scale)
            let center = CGPoint(
                x: CGFloat.random(in: 20...(mapSize.width - 20), using: &generator),
                y: CGFloat.random(in: 20...(mapSize.height - 20), using: &generator)
            )
            let frame = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)

            guard pathLine.distance(to: center) > pathHalfWidth + size.width / 2 + 10,
                  !standing.contains(where: { $0.frame.insetBy(dx: -6, dy: -6).intersects(frame) }),
                  !ground.contains(where: { $0.frame.insetBy(dx: -10, dy: -10).intersects(frame) }) else { continue }
            ground.append(makeSprite(kind, frame: frame, isMirrored: Bool.random(using: &generator)))
            placed += 1
        }
    }
}
