import SwiftUI

/// 3 x 3 grid of hole positions. Only the holes active at the current level are drawn and only
/// rows that contain them take space, so beginners see a calm board with a few large holes.
struct GameBoardView: View {
    let viewModel: WhackAMoleGameViewModel

    private let columns = SpawnManager.gridColumns

    private var rows: [Int] {
        Array(Set(viewModel.settings.activeHoleIndices.map { $0 / columns })).sorted()
    }

    var body: some View {
        GeometryReader { proxy in
            // Never taller than half the board, so a single row of holes stays in proportion.
            let cellHeight = proxy.size.height / CGFloat(max(rows.count, 2))
            let cellWidth = min(proxy.size.width / CGFloat(columns), cellHeight * 1.5)
            let gridWidth = cellWidth * CGFloat(columns)

            ZStack {
                if viewModel.settings.showsBackgroundDecorations {
                    BoardDecorationsView()
                }
                VStack(spacing: 0) {
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<columns, id: \.self) { column in
                                cell(index: row * columns + column)
                                    .frame(width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                }
                .frame(width: gridWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeInOut(duration: 0.5), value: viewModel.settings.activeHoleIndices)
        }
    }

    @ViewBuilder
    private func cell(index: Int) -> some View {
        if viewModel.activeHoles.contains(index) {
            MoleHoleView(
                holeIndex: index,
                target: viewModel.target(inHole: index),
                targetScale: viewModel.settings.targetScale,
                onTap: { viewModel.tapHole(index) }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
        } else {
            Color.clear
        }
    }
}

/// Static, low-contrast scenery for the advanced level. Kept in the margins and never animated,
/// so it adds a little visual complexity without hiding or competing with characters.
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
