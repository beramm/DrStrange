import UIKit
import XCTest
@testable import DrStrange

final class FoxPathGeneratorTests: XCTestCase {
    private let seeds: [UInt64] = Array(1...80)
    private let settings = FoxPathSettings.standard

    func testSameSeedGivesSameMap() {
        let first = FoxPathGenerator.makeMap(seed: 2024, settings: settings)
        let second = FoxPathGenerator.makeMap(seed: 2024, settings: settings)
        XCTAssertEqual(first, second)
    }

    func testDifferentSeedsGiveDifferentMaps() {
        let maps = seeds.map { FoxPathGenerator.makeMap(seed: $0, settings: settings) }
        let paths = Set(maps.map { $0.pathCells.map { "\($0.cell.column),\($0.cell.row)" }.joined(separator: " ") })
        XCTAssertGreaterThan(paths.count, seeds.count / 2, "paths should rarely repeat")
        for (index, map) in maps.enumerated().dropFirst() {
            XCTAssertNotEqual(map.standingSprites, maps[index - 1].standingSprites)
        }
    }

    func testPathRunsLeftToRightWithoutGoingBack() {
        for seed in seeds {
            let cells = FoxPathGenerator.makeMap(seed: seed, settings: settings).pathCells
            XCTAssertEqual(cells.first?.cell.column, 0)
            XCTAssertEqual(cells.last?.cell.column, FoxPathMetrics.columns - 1)
            XCTAssertEqual(cells.first?.tile, .horizontal)
            for cell in cells.suffix(FoxPathMetrics.finalStraightColumns) {
                XCTAssertEqual(cell.tile, .horizontal, "seed \(seed): the last tiles are straight")
            }
            XCTAssertEqual(Set(cells.map(\.cell)).count, cells.count, "the path never crosses itself")

            for cell in cells {
                XCTAssertTrue(FoxPathMetrics.pathRows.contains(cell.cell.row), "seed \(seed): row \(cell.cell.row)")
            }
            for (previous, next) in zip(cells, cells.dropFirst()) {
                let columnStep = next.cell.column - previous.cell.column
                let rowStep = next.cell.row - previous.cell.row
                let goesRight = columnStep == 1 && rowStep == 0
                let goesUpOrDown = columnStep == 0 && abs(rowStep) == 1
                XCTAssertTrue(goesRight || goesUpOrDown, "seed \(seed): \(previous.cell) to \(next.cell)")
            }
        }
    }

    func testRouteStaysOnThePathTiles() {
        for seed in seeds {
            let map = FoxPathGenerator.makeMap(seed: seed, settings: settings)
            let route = map.route
            XCTAssertEqual(route.points.first?.x ?? 0, FoxPathMetrics.routeInset, accuracy: 0.01)
            XCTAssertEqual(route.points.last?.x ?? 0, map.size.width - FoxPathMetrics.routeEndInset, accuracy: 0.01)
            for (previous, next) in zip(route.points, route.points.dropFirst()) {
                XCTAssertGreaterThanOrEqual(next.x, previous.x - 0.001, "the fox never walks left")
            }

            let cells = Set(map.pathCells.map(\.cell))
            for point in route.samples(spacing: 10) {
                // Points on a shared tile edge may belong to either neighbour.
                let nearby = [-0.5, 0.5].flatMap { dx in
                    [-0.5, 0.5].map { dy in
                        GridCell(
                            column: Int(((point.x + dx) / FoxPathMetrics.cellSize.width).rounded(.down)),
                            row: Int(((point.y + dy) / FoxPathMetrics.cellSize.height).rounded(.down))
                        )
                    }
                }
                XCTAssertTrue(nearby.contains(where: cells.contains), "seed \(seed): \(point) is off the path")
            }
        }
    }

    func testSceneryNeverStandsOnThePathOrHidesTheFox() {
        for seed in seeds {
            let map = FoxPathGenerator.makeMap(seed: seed, settings: settings)
            let pathPoints = FoxPathGenerator.pathLine(for: map.route).samples(spacing: 6)
            for sprite in map.standingSprites {
                XCTAssertTrue(
                    FoxPathGenerator.isClear(sprite, of: pathPoints),
                    "seed \(seed): \(sprite.kind) at \(sprite.frame)"
                )
            }
        }
    }

    func testEveryMapHasHousesAndLamps() {
        for seed in seeds {
            let map = FoxPathGenerator.makeMap(seed: seed, settings: settings)
            XCTAssertGreaterThanOrEqual(map.houses.count, 2, "seed \(seed)")
            XCTAssertGreaterThanOrEqual(map.standingSprites.filter { $0.kind == .lamp }.count, 2, "seed \(seed)")
            XCTAssertEqual(map.standingSprites.filter { $0.kind == .finishStall }.count, 1)
        }
    }

    func testGardensFillTheOpenGrass() {
        for seed in seeds {
            let map = FoxPathGenerator.makeMap(seed: seed, settings: settings)
            let pieces = map.standingSprites.filter(\.kind.isGardenPiece)
            XCTAssertGreaterThanOrEqual(pieces.count, 4, "seed \(seed)")
            XCTAssertGreaterThanOrEqual(Set(pieces.map(\.kind)).count, 2, "seed \(seed): more than one kind")

            // No big empty area is left: every open spot has scenery nearby.
            let line = FoxPathGenerator.pathLine(for: map.route)
            var widest: CGFloat = 0
            for y in stride(from: CGFloat(140), through: map.size.height - 40, by: 64) {
                for x in stride(from: CGFloat(80), through: map.size.width - 80, by: 64) {
                    let point = CGPoint(x: x, y: y)
                    guard line.distance(to: point) > FoxPathMetrics.pathHalfWidth + 70 else { continue }
                    let nearest = map.standingSprites.map { sprite -> CGFloat in
                        let dx = max(sprite.frame.minX - x, 0, x - sprite.frame.maxX)
                        let dy = max(sprite.frame.minY - y, 0, y - sprite.frame.maxY)
                        return hypot(dx, dy)
                    }.min() ?? .greatestFiniteMagnitude
                    widest = max(widest, nearest)
                }
            }
            XCTAssertLessThan(widest, 300, "seed \(seed): open grass \(widest) units from any scenery")
        }
    }

    func testRocksAndStonesStayOffThePath() {
        for seed in seeds {
            let map = FoxPathGenerator.makeMap(seed: seed, settings: settings)
            let line = FoxPathGenerator.pathLine(for: map.route)
            let rocks = map.groundSprites.filter { $0.kind == .pathRock || $0.kind == .steppingStone }
            XCTAssertGreaterThanOrEqual(map.groundSprites.filter { $0.kind == .pathRock }.count, 6, "seed \(seed)")
            for rock in rocks {
                let corners = [
                    CGPoint(x: rock.frame.minX, y: rock.frame.minY), CGPoint(x: rock.frame.maxX, y: rock.frame.minY),
                    CGPoint(x: rock.frame.minX, y: rock.frame.maxY), CGPoint(x: rock.frame.maxX, y: rock.frame.maxY),
                ]
                for corner in corners {
                    XCTAssertGreaterThan(line.distance(to: corner), FoxPathMetrics.pathHalfWidth - 12, "seed \(seed): \(rock.kind) at \(rock.frame)")
                }
            }
        }
    }

    func testFinishStallStandsOnTheMapBehindTheEndOfTheRoute() {
        for seed in seeds {
            let map = FoxPathGenerator.makeMap(seed: seed, settings: settings)
            guard let stall = map.standingSprites.first(where: { $0.kind == .finishStall }),
                  let end = map.route.points.last else {
                return XCTFail("seed \(seed): no stall")
            }
            XCTAssertTrue(CGRect(origin: .zero, size: map.size).contains(stall.frame), "seed \(seed): \(stall.frame)")
            XCTAssertLessThan(stall.baseline, end.y, "the fox stands in front of the stall")
            XCTAssertGreaterThan(end.x, stall.frame.minX + stall.frame.width / 3)
            XCTAssertLessThan(end.x, stall.frame.maxX - stall.frame.width / 3)
        }
    }

    func testHousesDoNotOverlapEachOther() {
        for seed in seeds {
            let houses = FoxPathGenerator.makeMap(seed: seed, settings: settings).houses
            for (index, house) in houses.enumerated() {
                for other in houses.dropFirst(index + 1) {
                    XCTAssertFalse(house.frame.intersects(other.frame), "seed \(seed)")
                }
            }
        }
    }

    func testEveryPictureIsInTheAssetCatalog() {
        var names = MapSpriteKind.allCases.map(\.assetName)
        names += ["FoxPath/PathHorizontal", "FoxPath/PathVertical", "FoxPath/PathCurve", "FoxPath/GrassPatch1", "FoxPath/GrassPatch2"]
        for character in PathCharacter.allCases {
            names.append(character.standingAsset)
            names += stride(from: CGFloat(0), to: FoxWalkAnimation.sideCycleLength(of: character), by: 1).map {
                FoxWalkAnimation.assetName(for: character, facing: .side, distance: $0)
            }
            for facing in [FoxFacing.front, .back] {
                names += stride(from: CGFloat(0), to: FoxWalkAnimation.frontCycleLength, by: 1).map {
                    FoxWalkAnimation.assetName(for: character, facing: facing, distance: $0)
                }
            }
        }
        for name in Set(names) {
            XCTAssertNotNil(UIImage(named: name), "missing \(name)")
        }
    }

    func testWalkCycleFollowsTheDistanceWalked() {
        for character in PathCharacter.allCases {
            let cycle = FoxWalkAnimation.sideCycleLength(of: character)
            XCTAssertEqual(
                FoxWalkAnimation.assetName(for: character, facing: .side, distance: 10),
                FoxWalkAnimation.assetName(for: character, facing: .side, distance: 10 + cycle * 3)
            )
            let shown = Set(stride(from: CGFloat(0), to: cycle, by: 0.5).map {
                FoxWalkAnimation.assetName(for: character, facing: .side, distance: $0)
            })
            XCTAssertEqual(shown.count, Set(character.sideSequence).count, "\(character): one cycle shows every side picture")
        }
        XCTAssertEqual(FoxFacing.walking(along: CGVector(dx: 1, dy: 0)), .side)
        XCTAssertEqual(FoxFacing.walking(along: CGVector(dx: 0, dy: 1)), .front)
        XCTAssertEqual(FoxFacing.walking(along: CGVector(dx: 0, dy: -1)), .back)
    }
}
