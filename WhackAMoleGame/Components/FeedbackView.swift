import SwiftUI

/// Soft burst of stars plus the awarded points that float up. One short animation; no flashing.
struct HitFeedbackView: View {
    let points: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    private let starCount = 6

    var body: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) * 0.5
            ZStack {
                if !reduceMotion {
                    ForEach(0..<starCount, id: \.self) { index in
                        let angle = Double(index) / Double(starCount) * 2 * .pi - .pi / 2
                        StarShape()
                            .fill(WhackAMolePalette.star)
                            .frame(width: radius * 0.22, height: radius * 0.22)
                            .offset(
                                x: expanded ? cos(angle) * radius * 0.9 : 0,
                                y: expanded ? sin(angle) * radius * 0.9 : 0
                            )
                    }
                }
                Text("+\(points)")
                    .font(.system(size: radius * 0.32, weight: .heavy, design: .rounded))
                    .foregroundStyle(WhackAMolePalette.ink)
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
