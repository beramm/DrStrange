import SwiftUI

/// Smooths the custom-tracker point for interaction and converts a continuous one-second dwell
/// near an active character into a proximity-scored game action.
struct GazeInteractionView: View {
    let controller: GazeInputController
    let viewModel: WhackAMoleGameViewModel
    let anchors: [FoxAnchorID: Anchor<CGRect>]

    @State private var selector = GazeDwellSelector()
    @State private var smoother = GazePointSmoother()
    @State private var smoothedNormalizedPoint: CGPoint?
    @State private var dwellProgress: Double = 0
    @State private var proximityTier: GazeProximityTier?

    var body: some View {
        GeometryReader { proxy in
            let point = cursorPoint(for: smoothedNormalizedPoint, in: proxy.size)

            ZStack {
                if let point, controller.hasUsableGaze {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 3)
                            .background(Circle().fill(tierColor.opacity(0.72)))
                            .frame(width: 30, height: 30)

                        if dwellProgress > 0 {
                            Circle()
                                .trim(from: 0, to: dwellProgress)
                                .stroke(tierColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 46, height: 46)
                        }
                    }
                    .position(point)
                    .shadow(radius: 3)
                }

                if !controller.isCalibrated {
                    Text("Eye control needs recalibration")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.75), in: Capsule())
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 18)
                }
            }
            .onChange(of: controller.sample.timestamp) { _, _ in
                consumeSample(in: proxy)
            }
            .onChange(of: viewModel.phase) { _, phase in
                if phase != .playing { resetDwell() }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func cursorPoint(for normalizedPoint: CGPoint?, in size: CGSize) -> CGPoint? {
        guard let normalizedPoint else { return nil }
        return CGPoint(x: normalizedPoint.x * size.width, y: normalizedPoint.y * size.height)
    }

    private func consumeSample(in proxy: GeometryProxy) {
        let rawPoint = controller.sample.pointNormalized.map { CGPoint(x: $0.x, y: $0.y) }
        smoothedNormalizedPoint = smoother.consume(
            point: rawPoint,
            timestampNanoseconds: controller.sample.timestamp.uptimeNanoseconds,
            isUsable: controller.hasUsableGaze
        )
        let point = cursorPoint(for: smoothedNormalizedPoint, in: proxy.size)
        let candidate = point.flatMap { point in
            viewModel.targets.compactMap { target -> GazeFocusCandidate? in
                guard target.phase.isUp,
                      let anchor = anchors[.hole(target.holeIndex)] else { return nil }

                let holeRect = proxy[anchor]
                let artIndex = viewModel.holes.first {
                    $0.holeIndex == target.holeIndex
                }?.artIndex ?? 0
                let localCharacterRect = MoleHoleView.characterRect(
                    artIndex: artIndex,
                    in: holeRect.size
                )
                let characterCenter = CGPoint(
                    x: holeRect.minX + localCharacterRect.midX,
                    y: holeRect.minY + localCharacterRect.midY
                )
                let distance = hypot(point.x - characterCenter.x, point.y - characterCenter.y)
                // Use a circular area at least as large as the visible character, while retaining
                // the forgiving target size of the existing hole-cell interaction.
                let outerRadius = max(
                    localCharacterRect.width / 2,
                    min(holeRect.width, holeRect.height) / 2
                )
                let normalizedDistance = distance / max(outerRadius, 1)
                guard normalizedDistance <= 1 else { return nil }
                return GazeFocusCandidate(
                    targetID: target.id,
                    holeIndex: target.holeIndex,
                    normalizedDistance: normalizedDistance
                )
            }
            .min { $0.normalizedDistance < $1.normalizedDistance }
        }

        let update = selector.consume(
            candidate: candidate,
            timestampNanoseconds: controller.sample.timestamp.uptimeNanoseconds,
            isUsable: controller.hasUsableGaze && viewModel.phase == .playing
        )
        dwellProgress = update.progress
        proximityTier = update.tier
        if let activation = update.activation {
            viewModel.activateGazeTarget(activation)
        }
    }

    private var tierColor: Color {
        switch proximityTier {
        case .inner: WhackAMolePalette.star
        case .middle: .orange
        case .outer, nil: WhackAMolePalette.accent
        }
    }

    private func resetDwell() {
        selector.reset()
        smoother.reset()
        smoothedNormalizedPoint = nil
        dwellProgress = 0
        proximityTier = nil
    }
}
