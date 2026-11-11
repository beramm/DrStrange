import SwiftUI

/// The board starts as an empty field. A hole opens at a random spot when a mole is about to
/// appear, and closes again after the mole has gone, so the child cannot tell where the next one
/// will be.
struct GameBoardView: View {
    let viewModel: WhackAMoleGameViewModel
    /// The whole screen, used to find where the painted grass is.
    let screenSize: CGSize

    /// Width of a hole's area as a share of the board at the largest level size, and its shape.
    private static let cellWidthShare: CGFloat = 0.25
    private static let cellAspect: CGFloat = 0.85

    var body: some View {
        GeometryReader { proxy in
            let cell = Self.cellSize(board: proxy.size, targetScale: viewModel.settings.targetScale)
            let boardTop = proxy.frame(in: .global).minY
            let grass = GameBackgroundView.grassBand(screen: screenSize)
            let ground = (grass.lowerBound - boardTop)...(grass.upperBound - boardTop)
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    // Board touches are recorded as off-target activity but can never hit a mole.
                    .onTapGesture { viewModel.tapBoard() }

                ForEach(viewModel.holes) { hole in
                    MoleHoleView(
                        hole: hole,
                        target: viewModel.target(inHole: hole.holeIndex),
                        visual: viewModel.moleVisuals[hole.holeIndex]
                    )
                    .frame(width: cell.width, height: cell.height)
                    .position(Self.center(of: hole.position, board: proxy.size, cell: cell, ground: ground))
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

    /// Screen position for a board point, keeping the hole on the grass (`ground`, in board
    /// coordinates) and the hole, mole and fox on the board.
    static func center(of point: BoardPoint, board: CGSize, cell: CGSize, ground: ClosedRange<CGFloat>? = nil) -> CGPoint {
        var lowest = foxRoom(cell: cell) + cell.height / 2
        var highest = board.height - cell.height / 2
        if let ground {
            // The hole's front edge is at the bottom of its cell; its dirt reaches this far around it.
            lowest = max(lowest, ground.lowerBound + cell.width * 0.42 - cell.height / 2)
            highest = min(highest, ground.upperBound - cell.width * 0.12 - cell.height / 2)
        }
        highest = max(highest, lowest)
        return CGPoint(
            x: cell.width / 2 + CGFloat(point.x) * (board.width - cell.width),
            y: lowest + CGFloat(point.y) * (highest - lowest)
        )
    }
}

/// The painted meadow behind the game: sky at the top, grass in the middle, a fence along the bottom.
struct GameBackgroundView: View {
    let screenSize: CGSize

    private static let imageSize = CGSize(width: 2752, height: 2064)
    /// The part of the painting where holes may open, as fractions of its height: below the
    /// horizon and above the fence, measured from the art.
    private static let grassTop: CGFloat = 0.37
    private static let grassBottom: CGFloat = 0.8

    var body: some View {
        Image("Meadow")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: screenSize.width, height: screenSize.height)
            .clipped()
            .accessibilityHidden(true)
    }

    /// Where the grass is on a screen of `screen` size, with the painting filling the screen and
    /// centred (the same way `body` draws it).
    static func grassBand(screen: CGSize) -> ClosedRange<CGFloat> {
        let scale = max(screen.width / imageSize.width, screen.height / imageSize.height)
        let height = imageSize.height * scale
        let top = (screen.height - height) / 2
        return (top + grassTop * height)...(top + grassBottom * height)
    }
}
