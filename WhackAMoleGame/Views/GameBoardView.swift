import SwiftUI

/// The board starts as an empty field. A hole opens at a random spot when a mole is about to
/// appear, and closes again after the mole has gone, so the child cannot tell where the next one
/// will be.
struct GameBoardView: View {
    let viewModel: WhackAMoleGameViewModel
    /// The whole screen, used to find where the painted grass is.
    let screenSize: CGSize

    /// `targetScale` of the largest moles; the cell share below is measured at this size.
    private static let largestTargetScale = 0.95
    /// Width of a hole's area as a share of the board at the largest mole size, and its shape.
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
        let width = min(board.width * cellWidthShare, board.height * 0.41) * CGFloat(targetScale / largestTargetScale)
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

/// The painted meadow behind the game: sky at the top, grass in the middle, a fence along the bottom,
/// with two clouds drifting slowly across the sky.
struct GameBackgroundView: View {
    let screenSize: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let imageSize = CGSize(width: 2752, height: 2064)
    /// The part of the painting where holes may open, as fractions of its height: below the
    /// horizon and above the fence, measured from the art.
    private static let grassTop: CGFloat = 0.37
    private static let grassBottom: CGFloat = 0.8

    var body: some View {
        ZStack {
            Image("Meadow")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: screenSize.width, height: screenSize.height)

            // The clouds only move with real time, never with the game clock: pausing the game
            // leaves them drifting, and they never affect play. With Reduce Motion they stay put.
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                ZStack(alignment: .topLeading) {
                    ForEach(DriftingCloud.all, id: \.assetName) { cloud in
                        let frame = cloud.frame(at: time, screen: screenSize)
                        Image(cloud.assetName)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                    }
                }
                .frame(width: screenSize.width, height: screenSize.height)
            }
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// How much the painting is scaled to fill a screen of `screen` size.
    static func scale(screen: CGSize) -> CGFloat {
        max(screen.width / imageSize.width, screen.height / imageSize.height)
    }

    /// Where the grass is on a screen of `screen` size, with the painting filling the screen and
    /// centred (the same way `body` draws it).
    static func grassBand(screen: CGSize) -> ClosedRange<CGFloat> {
        let height = imageSize.height * scale(screen: screen)
        let top = (screen.height - height) / 2
        return (top + grassTop * height)...(top + grassBottom * height)
    }
}

/// One of the provided clouds (`MeadowCloud1…2`), drifting slowly from left to right across the sky
/// and coming back in on the left once it has left the screen.
struct DriftingCloud: Equatable {
    let assetName: String
    /// Size in the painting's pixels, so the cloud scales with the meadow.
    let size: CGSize
    /// Top of the cloud in the painting's pixels; both clouds stay in the sky.
    let top: CGFloat
    /// Where the cloud starts, as a share of its whole trip (off-screen left to off-screen right).
    let phase: Double
    /// Speed in the painting's pixels per second. Slow: a trip across takes one to one and a half minutes.
    let speed: Double

    static let all = [
        DriftingCloud(assetName: "MeadowCloud1", size: CGSize(width: 758, height: 283), top: 330, phase: 0.18, speed: 52),
        DriftingCloud(assetName: "MeadowCloud2", size: CGSize(width: 827, height: 330), top: 110, phase: 0.72, speed: 36),
    ]

    /// The cloud's frame on a screen of `screen` size at `time` seconds.
    func frame(at time: TimeInterval, screen: CGSize) -> CGRect {
        let scale = GameBackgroundView.scale(screen: screen)
        let width = size.width * scale
        let height = size.height * scale
        let paintingTop = (screen.height - GameBackgroundView.imageSize.height * scale) / 2
        // One trip runs from just off the left edge to just off the right edge.
        let trip = Double(screen.width + width)
        let travelled = (phase * trip + time * speed * Double(scale)).truncatingRemainder(dividingBy: trip)
        return CGRect(x: CGFloat(travelled) - width, y: paintingTop + top * scale, width: width, height: height)
    }
}
