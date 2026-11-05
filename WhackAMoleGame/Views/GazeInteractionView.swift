import SwiftUI

/// Shows the unsmoothed custom-tracker point and converts a 600 ms gaze dwell
/// inside an active hole's real layout bounds into the game's existing tap action.
struct GazeInteractionView: View {
    let controller: GazeInputController
    let viewModel: WhackAMoleGameViewModel
    let anchors: [FoxAnchorID: Anchor<CGRect>]

    @State private var selector = GazeDwellSelector()

    var body: some View {
        GeometryReader { proxy in
            let point = cursorPoint(in: proxy.size)

            ZStack {
                if let point, controller.hasUsableGaze {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .background(Circle().fill(WhackAMolePalette.accent.opacity(0.65)))
                        .frame(width: 30, height: 30)
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
                if phase != .playing { selector.reset() }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func cursorPoint(in size: CGSize) -> CGPoint? {
        guard let gaze = controller.sample.pointNormalized else { return nil }
        return CGPoint(x: gaze.x * size.width, y: gaze.y * size.height)
    }

    private func consumeSample(in proxy: GeometryProxy) {
        let point = cursorPoint(in: proxy.size)
        let candidate = point.flatMap { point in
            viewModel.targets.first { target in
                guard target.phase.isUp,
                      let anchor = anchors[.hole(target.holeIndex)] else { return false }
                return proxy[anchor].contains(point)
            }?.holeIndex
        }

        let activated = selector.consume(
            candidateHole: candidate,
            timestampNanoseconds: controller.sample.timestamp.uptimeNanoseconds,
            isUsable: controller.hasUsableGaze && viewModel.phase == .playing
        )
        if let activated { viewModel.tapHole(activated) }
    }
}
