import SwiftUI

/// The board starts as an empty meadow. A hole opens at a random spot when a mole is about to
/// appear, and closes again after the mole has gone, so the child cannot tell where the next one
/// will be.
struct GameBoardView: View {
    let viewModel: WhackAMoleGameViewModel

    /// Width of a hole's area as a share of the board at the largest level size, and its shape.
    private static let cellWidthShare: CGFloat = 0.25
    private static let cellAspect: CGFloat = 0.85

    var body: some View {
        GeometryReader { proxy in
            let cell = Self.cellSize(board: proxy.size, targetScale: viewModel.settings.targetScale)
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.tapBoard() }

                if viewModel.settings.showsBackgroundDecorations {
                    BoardDecorationsView()
                }

                ForEach(viewModel.holes) { hole in
                    MoleHoleView(
                        hole: hole,
                        target: viewModel.target(inHole: hole.holeIndex),
                        visual: viewModel.moleVisuals[hole.holeIndex],
                        onTap: { viewModel.tapHole(hole.holeIndex) }
                    )
                    .frame(width: cell.width, height: cell.height)
                    .position(Self.center(of: hole.position, board: proxy.size, cell: cell))
                }
            }
        }
    }

    static func cellSize(board: CGSize, targetScale: Double) -> CGSize {
        let beginnerScale = DifficultySettings.defaults(for: .beginner).targetScale
        let width = min(board.width * cellWidthShare, board.height * 0.41) * CGFloat(targetScale / beginnerScale)
        return CGSize(width: width, height: width * cellAspect)
    }

    /// Space kept above the highest holes for the fox's card, which appears above the mole.
    private static func foxRoom(cell: CGSize) -> CGFloat { cell.width * 0.42 }

    /// Screen position for a board point, keeping the hole, the mole and the fox on the board.
    static func center(of point: BoardPoint, board: CGSize, cell: CGSize) -> CGPoint {
        let top = foxRoom(cell: cell)
        return CGPoint(
            x: cell.width / 2 + CGFloat(point.x) * (board.width - cell.width),
            y: top + cell.height / 2 + CGFloat(point.y) * (board.height - cell.height - top)
        )
    }
}

/// Static, low-contrast scenery for the advanced level. Never animated, so it adds a little visual
/// complexity without competing with the moles.
struct BoardDecorationsView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                ForEach(Self.spots.indices, id: \.self) { index in
                    let spot = Self.spots[index]
                    Group {
                        if index.isMultiple(of: 2) {
                            StarShape(points: 6).fill(WhackAMolePalette.cream.opacity(0.7))
                        } else {
                            Ellipse().fill(WhackAMolePalette.meadowDeep.opacity(0.6))
                        }
                    }
                    .frame(width: spot.size, height: spot.size * (index.isMultiple(of: 2) ? 1 : 0.5))
                    .position(x: size.width * spot.x, y: size.height * spot.y)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Fixed positions in the margins between holes (unit coordinates).
    private static let spots: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (0.04, 0.12, 34), (0.96, 0.18, 40), (0.03, 0.55, 46), (0.97, 0.62, 30),
        (0.06, 0.92, 38), (0.94, 0.94, 44), (0.33, 0.02, 26), (0.67, 0.03, 30),
    ]
}
