import UIKit
import XCTest
@testable import DrStrange

final class FoxPathGeneratorTests: XCTestCase {
    private let seeds: [UInt64] = Array(1...40)

    private func settings(_ level: DifficultyLevel) -> FoxPathSettings {
        FoxPathSettings.defaults(for: level)
    }

    func testSameSeedGivesSameMap() {
        for level in DifficultyLevel.allCases {
            let first = FoxPathGenerator.makeMap(seed: 2024, settings: settings(level))
            let second = FoxPathGenerator.makeMap(seed: 2024, settings: settings(level))
            XCTAssertEqual(first, second)
        }
    }

    func testDifferentSeedsGiveDifferentMaps() {
        let maps = seeds.map { FoxPathGenerator.makeMap(seed: $0, settings: settings(.beginner)) }
        let paths = Set(maps.map { $0.pathCells.map { "\($0.cell.column),\($0.cell.row)" }.joined(separator: " ") })
        XCTAssertGreaterThan(paths.count, seeds.count / 2, "paths should rarely repeat")
        for (index, map) in maps.enumerated().dropFirst() {
            XCTAssertNotEqual(map.standingSprites, maps[index - 1].standingSprites)
        }
    }

    func testPathRunsLeftToRightWithoutGoingBack() {
        for level in DifficultyLevel.allCases {
            for seed in seeds {
                let cells = FoxPathGenerator.makeMap(seed: seed, settings: settings(level)).pathCells
                XCTAssertEqual(cells.first?.cell.column, 0)
                XCTAssertEqual(cells.last?.cell.column, FoxPathMetrics.columns - 1)
                XCTAssertEqual(cells.first?.tile, .horizontal)
                XCTAssertEqual(cells.last?.tile, .horizontal)
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
    }

    func testRouteStaysOnThePathTiles() {
        for seed in seeds {
            let map = FoxPathGenerator.makeMap(seed: seed, settings: settings(.advanced))
            let route = map.route
            XCTAssertEqual(route.points.first?.x ?? 0, FoxPathMetrics.routeInset, accuracy: 0.01)
            XCTAssertEqual(route.points.last?.x ?? 0, map.size.width - FoxPathMetrics.routeInset, accuracy: 0.01)
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
        for level in DifficultyLevel.allCases {
            for seed in seeds {
                let map = FoxPathGenerator.makeMap(seed: seed, settings: settings(level))
                let pathPoints = FoxPathGenerator.pathLine(for: map.route).samples(spacing: 6)
                for sprite in map.standingSprites where sprite.kind != .finishFlag {
                    XCTAssertTrue(
                        FoxPathGenerator.isClear(sprite, of: pathPoints),
                        "seed \(seed) \(level): \(sprite.kind) at \(sprite.frame)"
                    )
                }
            }
        }
    }

    func testEveryMapHasHousesAndLamps() {
        for level in DifficultyLevel.allCases {
            for seed in seeds {
                let map = FoxPathGenerator.makeMap(seed: seed, settings: settings(level))
                XCTAssertGreaterThanOrEqual(map.houses.count, 2, "seed \(seed) \(level)")
                XCTAssertGreaterThanOrEqual(map.standingSprites.filter { $0.kind == .lamp }.count, 2, "seed \(seed) \(level)")
                XCTAssertEqual(map.standingSprites.filter { $0.kind == .finishFlag }.count, 1)
            }
        }
    }

    func testHousesDoNotOverlapEachOther() {
        for seed in seeds {
            let houses = FoxPathGenerator.makeMap(seed: seed, settings: settings(.intermediate)).houses
            for (index, house) in houses.enumerated() {
                for other in houses.dropFirst(index + 1) {
                    XCTAssertFalse(house.frame.intersects(other.frame), "seed \(seed)")
                }
            }
        }
    }

    func testEveryPictureIsInTheAssetCatalog() {
        var names = MapSpriteKind.allCases.compactMap(\.assetName)
        names += ["FoxPath/PathHorizontal", "FoxPath/PathVertical", "FoxPath/PathCurve", "FoxPath/GrassPatch1", "FoxPath/GrassPatch2"]
        names += stride(from: CGFloat(0), to: FoxWalkAnimation.sideCycleLength, by: 1).map {
            FoxWalkAnimation.assetName(facing: .side, distance: $0)
        }
        for facing in [FoxFacing.front, .back] {
            names += stride(from: CGFloat(0), to: FoxWalkAnimation.frontCycleLength, by: 1).map {
                FoxWalkAnimation.assetName(facing: facing, distance: $0)
            }
        }
        for name in Set(names) {
            XCTAssertNotNil(UIImage(named: name), "missing \(name)")
        }
    }

    func testWalkCycleFollowsTheDistanceWalked() {
        let cycle = FoxWalkAnimation.sideCycleLength
        XCTAssertEqual(
            FoxWalkAnimation.assetName(facing: .side, distance: 10),
            FoxWalkAnimation.assetName(facing: .side, distance: 10 + cycle * 3)
        )
        let shown = Set(stride(from: CGFloat(0), to: cycle, by: 0.5).map { FoxWalkAnimation.assetName(facing: .side, distance: $0) })
        XCTAssertEqual(shown.count, Set(FoxWalkAnimation.sideSequence).count, "one cycle shows every side picture")
        XCTAssertEqual(FoxFacing.walking(along: CGVector(dx: 1, dy: 0)), .side)
        XCTAssertEqual(FoxFacing.walking(along: CGVector(dx: 0, dy: 1)), .front)
        XCTAssertEqual(FoxFacing.walking(along: CGVector(dx: 0, dy: -1)), .back)
    }
}
