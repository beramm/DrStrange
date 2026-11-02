import SwiftUI

/// Soft burst of stars plus a "+10" that floats up. One short, slow animation; no flashing.
struct HitFeedbackView: View {
    let renderer: any EyeChannelRenderer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    private let starCount = 6

    var body: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) * 0.5
            let starInk = renderer.ink(for: .both, standardColor: WhackAMolePalette.star, contrast: 0.6)
            let textInk = renderer.ink(for: .both, standardColor: WhackAMolePalette.ink, contrast: 0.8)
            ZStack {
                if !reduceMotion {
                    ForEach(0..<starCount, id: \.self) { index in
                        let angle = Double(index) / Double(starCount) * 2 * .pi - .pi / 2
                        StarShape()
                            .fill(starInk)
                            .frame(width: radius * 0.22, height: radius * 0.22)
                            .offset(
                                x: expanded ? cos(angle) * radius * 0.9 : 0,
                                y: expanded ? sin(angle) * radius * 0.9 : 0
                            )
                    }
                }
                Text("+\(WhackAMoleGameViewModel.pointsPerHit)")
                    .font(.system(size: radius * 0.32, weight: .heavy, design: .rounded))
                    .foregroundStyle(textInk)
                    .offset(y: expanded && !reduceMotion ? -radius * 0.9 : -radius * 0.5)
            }
            .opacity(expanded ? 0 : 1)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { expanded = true }
        }
        .accessibilityHidden(true)
    }
}

/// The fox mascot from the provided frame sequence. It swings its hammer once per hit.
struct FoxHammerView: View {
    let swingCount: Int
    let isDichoptic: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frame = 1
    @State private var swingTask: Task<Void, Never>?

    static let frameCount = 21
    private static let frameDuration: Duration = .milliseconds(30)

    var body: some View {
        Image(Self.assetName(frame))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            // Full-colour art is seen by both eyes through anaglyph filters, unevenly. Neutral grey
            // keeps the mascot from favouring either eye.
            .grayscale(isDichoptic ? 1 : 0)
            .opacity(isDichoptic ? 0.55 : 1)
            .onChange(of: swingCount) { _, _ in swing() }
            .onDisappear { swingTask?.cancel() }
            .accessibilityLabel("Fox with a hammer")
    }

    static func assetName(_ frame: Int) -> String {
        String(format: "FoxHammer/Frame%02d", frame)
    }

    private func swing() {
        guard !reduceMotion else { return }
        swingTask?.cancel()
        swingTask = Task { @MainActor in
            for index in 1...Self.frameCount {
                guard !Task.isCancelled else { return }
                frame = index
                try? await Task.sleep(for: Self.frameDuration)
            }
            frame = 1
        }
    }
}
