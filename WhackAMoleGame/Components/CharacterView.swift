import SwiftUI
import UIKit

/// One pop-up character: awake with a star (tap it) or sleepy (leave it).
///
/// Uses `Character<Name>` / `Character<Name>Sleepy` from the asset catalog when present.
/// Until that artwork exists, a vector placeholder is drawn instead.
struct CharacterView: View {
    let target: ActiveTarget

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isHit: Bool {
        if case .hit = target.phase { true } else { false }
    }

    var body: some View {
        artwork
            .scaleEffect(x: isHit ? 1.12 : 1, y: isHit ? 0.82 : 1, anchor: .bottom)
            .rotationEffect(.degrees(isHit && !reduceMotion ? -4 : 0), anchor: .bottom)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: isHit)
    }

    @ViewBuilder
    private var artwork: some View {
        let assetName = target.variant.assetName(for: target.role)
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                PlaceholderCritterBody().fill(WhackAMolePalette.body(target.variant))
                PlaceholderCritterFeatures(
                    isAwake: target.role == .target,
                    isHit: isHit,
                    ink: WhackAMolePalette.ink,
                    starInk: WhackAMolePalette.star
                )
            }
        }
    }
}

// MARK: - Placeholder artwork (replace with real target assets)

/// Placeholder silhouette: round head with ears and a body. Unit square coordinates.
struct PlaceholderCritterBody: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.addEllipse(in: CGRect(x: rect.minX + w * 0.18, y: rect.minY + h * 0.06, width: w * 0.22, height: w * 0.22))
        path.addEllipse(in: CGRect(x: rect.minX + w * 0.60, y: rect.minY + h * 0.06, width: w * 0.22, height: w * 0.22))
        path.addEllipse(in: CGRect(x: rect.minX + w * 0.15, y: rect.minY + h * 0.12, width: w * 0.70, height: h * 0.58))
        path.addRoundedRect(
            in: CGRect(x: rect.minX + w * 0.2, y: rect.minY + h * 0.5, width: w * 0.6, height: h * 0.5),
            cornerSize: CGSize(width: w * 0.2, height: w * 0.2)
        )
        return path
    }
}

/// Placeholder features: open eyes, smile and a belly star when awake; closed eyes when sleepy.
struct PlaceholderCritterFeatures: View {
    let isAwake: Bool
    let isHit: Bool
    let ink: Color
    let starInk: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack {
                if isAwake && !isHit {
                    Circle().fill(ink).frame(width: w * 0.1).position(x: w * 0.38, y: h * 0.38)
                    Circle().fill(ink).frame(width: w * 0.1).position(x: w * 0.62, y: h * 0.38)
                } else {
                    // Closed or squeezed eyes.
                    Capsule().fill(ink).frame(width: w * 0.12, height: w * 0.035).position(x: w * 0.38, y: h * 0.39)
                    Capsule().fill(ink).frame(width: w * 0.12, height: w * 0.035).position(x: w * 0.62, y: h * 0.39)
                }
                SmileShape()
                    .stroke(ink, style: StrokeStyle(lineWidth: w * 0.03, lineCap: .round))
                    .frame(width: w * 0.18, height: h * 0.06)
                    .position(x: w * 0.5, y: h * 0.5)
                if isAwake {
                    StarShape().fill(starInk).frame(width: w * 0.26, height: w * 0.26).position(x: w * 0.5, y: h * 0.76)
                }
            }
        }
    }
}

struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2))
        return path
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
