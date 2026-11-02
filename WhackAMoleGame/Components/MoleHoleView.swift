import SwiftUI

/// One hole. The character rises out of it, squashes when hit and sinks back when it leaves.
/// The whole cell is the touch target so small hands do not need to be precise.
struct MoleHoleView: View {
    let holeIndex: Int
    let target: ActiveTarget?
    let targetScale: Double
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A character that is leaving is already sinking, so it is no longer drawn here.
    private var shownTarget: ActiveTarget? {
        guard let target else { return nil }
        if case .leaving = target.phase { return nil }
        return target
    }

    private var hitTarget: ActiveTarget? {
        guard let target, case .hit = target.phase, target.role == .target else { return nil }
        return target
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let holeWidth = width * 0.72
            let holeHeight = Self.holeHeight(forWidth: width)
            let characterSize = Self.characterRect(in: proxy.size, targetScale: targetScale).height

            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(WhackAMolePalette.holeShadow)
                    .frame(width: holeWidth, height: holeHeight)

                // Characters are clipped at the hole's centre line so they appear to come out of it.
                ZStack(alignment: .bottom) {
                    if let shownTarget {
                        CharacterView(target: shownTarget)
                            .frame(width: characterSize, height: characterSize)
                            .id(shownTarget.id)
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                    }
                }
                .frame(width: width, height: characterSize)
                .clipped()
                .padding(.bottom, holeHeight / 2)
                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: shownTarget?.id)

                HoleRimShape()
                    .fill(WhackAMolePalette.rim)
                    .frame(width: holeWidth * 1.04, height: holeHeight * 0.58)

                if let hitTarget {
                    HitFeedbackView()
                        .id(hitTarget.id)
                        .frame(width: characterSize, height: characterSize)
                        .padding(.bottom, holeHeight)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: width, height: height, alignment: .bottom)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
        .anchorPreference(key: FoxAnchorKey.self, value: .bounds) { [.hole(holeIndex): $0] }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onTap)
    }

    static func holeHeight(forWidth width: CGFloat) -> CGFloat {
        width * 0.72 * 0.3
    }

    /// Where a fully risen character sits inside a hole cell of `size`. Shared with the fox's
    /// attack so the hammer lands on the character.
    static func characterRect(in size: CGSize, targetScale: Double) -> CGRect {
        let side = min(size.width * 0.62, size.height * 0.78) * targetScale
        let bottom = size.height - holeHeight(forWidth: size.width) / 2
        return CGRect(x: (size.width - side) / 2, y: bottom - side, width: side, height: side)
    }

    private var accessibilityLabel: String {
        guard let shownTarget, shownTarget.phase.isUp else { return "Empty hole" }
        return shownTarget.role == .target ? "Character with a star" : "Sleepy character"
    }
}

/// Front lip of the hole: a crescent along the lower edge, drawn over the character's base.
/// `rect` spans the lower half of the hole ellipse.
struct HoleRimShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.minY)
        let steps = 32
        func point(_ step: Int, radiusX: CGFloat, radiusY: CGFloat) -> CGPoint {
            let angle = Double.pi * Double(step) / Double(steps)
            return CGPoint(x: center.x + radiusX * cos(angle), y: center.y + radiusY * sin(angle))
        }
        var path = Path()
        // Outer edge from right to left along the bottom, then the inner edge back.
        path.move(to: point(0, radiusX: rect.width / 2, radiusY: rect.height))
        for step in 1...steps { path.addLine(to: point(step, radiusX: rect.width / 2, radiusY: rect.height)) }
        for step in stride(from: steps, through: 0, by: -1) {
            path.addLine(to: point(step, radiusX: rect.width / 2 * 0.92, radiusY: rect.height * 0.4))
        }
        path.closeSubpath()
        return path
    }
}
