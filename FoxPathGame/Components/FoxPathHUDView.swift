import SwiftUI

/// Top bar: exit, how far the fox has walked, zoom and pause. Icons first, minimal text.
struct FoxPathHUDView: View {
    let viewModel: FoxPathGameViewModel
    let onExit: () -> Void

    private let ink = FoxPathPalette.ink

    var body: some View {
        HStack(spacing: 20) {
            HUDButton(systemImage: "xmark", label: "Exit game", ink: ink, action: onExit)

            PathProgressView(progress: viewModel.progress, ink: ink)
                .frame(maxWidth: .infinity)

            LevelIndicatorView(level: viewModel.configuration.level, ink: ink)
                .padding(.horizontal, 14)
                .frame(height: 60)
                .background(Capsule().fill(.white.opacity(0.75)))

            HUDButton(systemImage: "minus.magnifyingglass", label: "Zoom out", ink: ink) {
                viewModel.zoomOut()
            }
            .disabled(!viewModel.camera.canZoomOut)
            .opacity(viewModel.camera.canZoomOut ? 1 : 0.5)

            HUDButton(systemImage: "plus.magnifyingglass", label: "Zoom in", ink: ink) {
                viewModel.zoomIn()
            }
            .disabled(!viewModel.camera.canZoomIn)
            .opacity(viewModel.camera.canZoomIn ? 1 : 0.5)

            HUDButton(systemImage: "pause.fill", label: "Pause", ink: ink) {
                viewModel.pause()
            }
            .disabled(viewModel.phase != .playing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

/// How much of the path is behind the fox, with the finish stall at the end of the bar.
private struct PathProgressView: View {
    let progress: Double
    let ink: Color

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.75))
                    Capsule()
                        .fill(FoxPathPalette.accent)
                        .frame(width: max(proxy.size.height, proxy.size.width * progress))
                        .animation(.linear(duration: 0.2), value: progress)
                }
            }
            .frame(height: 18)
            Image(systemName: "storefront")
                .font(.title2.weight(.bold))
                .foregroundStyle(ink)
        }
        .padding(.horizontal, 18)
        .frame(height: 60)
        .background(Capsule().fill(.white.opacity(0.55)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Path walked")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }
}
