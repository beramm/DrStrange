import SwiftUI
import UIKit

/// One mole, drawn from the provided 24-frame rise animation (`Characters/MoleRise/Frame01…24`).
/// The frames play forwards as it climbs out and backwards as it goes down. Sleeping moles (decoys)
/// are drawn in grey with a "z z" bubble.
struct CharacterView: View {
    let target: ActiveTarget
    let visual: MoleVisual

    /// Where the hammer lands, as a fraction of the fully risen mole: the top of its helmet.
    static let strikePoint = CGPoint(x: 0.5, y: 0.1)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func assetName(_ frame: Int) -> String {
        String(format: "MoleRise/Frame%02d", min(max(frame, 1), MoleVisual.frameCount))
    }

    private var isAsleep: Bool { target.role == .decoy }

    /// Squash on impact, then a head wobble that dies away.
    private var reaction: (squash: Double, wobble: Double) {
        guard let progress = visual.hitProgress, !reduceMotion else { return (0, 0) }
        let squash = sin(min(progress / 0.3, 1) * .pi)
        let wobble = sin(progress * .pi * 4) * (1 - progress)
        return (squash, wobble)
    }

    var body: some View {
        GeometryReader { proxy in
            // With Reduce Motion the mole fades in and out instead of climbing.
            Image(Self.assetName(reduceMotion ? MoleVisual.frameCount : visual.frame))
                .resizable()
                .interpolation(.high)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .grayscale(isAsleep ? 1 : 0)
                .opacity(reduceMotion ? Double(visual.frame) / Double(MoleVisual.frameCount) : 1)
                .overlay(alignment: .topTrailing) {
                    if isAsleep && visual.frame >= MoleVisual.frameCount - 2 {
                        SleepBubble()
                            .frame(width: proxy.size.width * 0.38, height: proxy.size.width * 0.26)
                    }
                }
        }
        .scaleEffect(x: 1 + 0.12 * reaction.squash, y: 1 - 0.16 * reaction.squash, anchor: .bottom)
        .rotationEffect(.degrees(9 * reaction.wobble), anchor: .bottom)
        .accessibilityHidden(true)
    }
}

/// "z z" bubble shown next to a sleeping mole.
private struct SleepBubble: View {
    var body: some View {
        GeometryReader { proxy in
            Text("z z")
                .font(.system(size: proxy.size.height * 0.62, weight: .heavy, design: .rounded))
                .foregroundStyle(WhackAMolePalette.ink.opacity(0.75))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .background(Capsule().fill(WhackAMolePalette.cream.opacity(0.9)))
        }
    }
}

struct StarShape: Shape {
    var points = 5

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.45
        var path = Path()
        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = Double(index) * .pi / Double(points) - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}
