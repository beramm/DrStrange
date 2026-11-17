import SwiftUI

/// Full-screen reminder shown while a game is paused because the camera sees both eyes (the patch
/// came off). Three foxes putting their patch on show the child what to do, in a small meadow so
/// the screen does not feel empty. The game hides this screen and carries on by itself once the
/// one-eye check passes again; "Rest my eyes" stays available as a way to stop.
struct PatchReminderScreen: View {
    let onRest: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    /// The layout was drawn on a 1366 × 1024 point screen (iPad Pro 12.9" in landscape).
    private static let design = CGSize(width: 1366, height: 1024)

    static let sky = Color(red: 231 / 255, green: 245 / 255, blue: 252 / 255)
    private static let backHill = Color(red: 150 / 255, green: 205 / 255, blue: 92 / 255)
    private static let frontHill = Color(red: 112 / 255, green: 182 / 255, blue: 46 / 255)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                Self.sky
                sky(in: size)
                meadow(in: size)
                foxes(in: size)
                caption(in: size)
            }
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .topTrailing) { restButton.padding(28) }
        }
        .ignoresSafeArea()
        .onAppear { isAnimating = !reduceMotion }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Foxes

    /// Three foxes in a row, the middle one centred, sized like the design (270 pt circles).
    private func foxes(in size: CGSize) -> some View {
        let circle = min(size.width * 0.198, size.height * 0.27)
        // The yellow circle fills 96.3% of the artwork's width; the ears stick out above it.
        let artWidth = circle / 0.963
        let spacing = circle * 1.14
        return ForEach(0..<3, id: \.self) { index in
            Image("PatchReminder/FoxPatch")
                .resizable()
                .scaledToFit()
                .frame(width: artWidth)
                .offset(y: isAnimating ? -circle * 0.03 : circle * 0.03)
                .animation(
                    isAnimating
                        ? .easeInOut(duration: 1.3).repeatForever().delay(Double(index) * 0.35)
                        : .default,
                    value: isAnimating
                )
                .position(x: size.width / 2 + CGFloat(index - 1) * spacing, y: size.height * 0.48)
        }
        .accessibilityHidden(true)
    }

    private func caption(in size: CGSize) -> some View {
        Text("Patch back on, and the game goes on!")
            .font(.system(.title2, design: .rounded).weight(.heavy))
            .foregroundStyle(WhackAMolePalette.ink)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(.white.opacity(0.85), in: Capsule())
            .position(x: size.width / 2, y: size.height * 0.68)
            .accessibilityLabel("Game paused. Put the eye patch back on and the game will keep going.")
    }

    private var restButton: some View {
        Button(action: onRest) {
            Label("Rest my eyes", systemImage: "moon.zzz.fill")
                .font(.headline)
                .padding(.horizontal, 18)
                .frame(minHeight: 48)
        }
        .buttonStyle(.bordered)
        .tint(WhackAMolePalette.ink)
        .background(.white.opacity(0.7), in: Capsule())
    }

    // MARK: - Sky

    private func sky(in size: CGSize) -> some View {
        let scale = min(size.width / Self.design.width, size.height / Self.design.height)
        return ZStack(alignment: .topLeading) {
            sun(radius: 52 * scale)
                .position(point(x: 1060, y: 120, in: size))
            ForEach(Array(Self.clouds.enumerated()), id: \.offset) { index, cloud in
                CloudShape()
                    .fill(.white)
                    .frame(width: cloud.width * scale, height: cloud.width * 0.48 * scale)
                    .shadow(color: .white.opacity(0.8), radius: 6)
                    .offset(x: isAnimating ? cloud.drift * scale : -cloud.drift * scale)
                    .animation(
                        isAnimating
                            ? .easeInOut(duration: 7 + Double(index)).repeatForever()
                            : .default,
                        value: isAnimating
                    )
                    .position(point(x: cloud.x, y: cloud.y, in: size))
            }
        }
        .accessibilityHidden(true)
    }

    private func sun(radius: CGFloat) -> some View {
        Circle()
            .fill(Color(red: 1, green: 0.84, blue: 0.4))
            .frame(width: radius * 2, height: radius * 2)
            .background(
                Circle()
                    .fill(Color(red: 1, green: 0.9, blue: 0.6).opacity(0.55))
                    .frame(width: radius * 3, height: radius * 3)
            )
    }

    private struct Cloud {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let drift: CGFloat
    }

    private static let clouds = [
        Cloud(x: 170, y: 130, width: 230, drift: 24),
        Cloud(x: 480, y: 70, width: 150, drift: 16),
        Cloud(x: 800, y: 150, width: 190, drift: 20),
        Cloud(x: 1230, y: 230, width: 170, drift: 18),
    ]

    // MARK: - Meadow

    /// Rolling hills along the bottom with houses, lamps and garden bits from the Fox Path village.
    private func meadow(in size: CGSize) -> some View {
        let scale = min(size.width / Self.design.width, size.height / Self.design.height)
        return ZStack(alignment: .topLeading) {
            HillShape(left: 0.79, middle: 0.70, right: 0.77)
                .fill(Self.backHill)
            ForEach(Array(Self.backProps.enumerated()), id: \.offset) { _, prop in
                propView(prop, scale: scale, in: size)
            }
            ForEach(Array(Self.flowers.enumerated()), id: \.offset) { index, spot in
                FlowerView(petal: Self.flowerColors[index % Self.flowerColors.count])
                    .frame(width: 22 * scale, height: 22 * scale)
                    .position(point(x: spot.x, y: spot.y, in: size))
            }
            HillShape(left: 0.86, middle: 0.82, right: 0.87)
                .fill(Self.frontHill)
            ForEach(Array(Self.frontProps.enumerated()), id: \.offset) { _, prop in
                propView(prop, scale: scale, in: size)
            }
        }
        .accessibilityHidden(true)
    }

    private struct Prop {
        let kind: MapSpriteKind
        /// Middle of the bottom edge, in design points.
        let x: CGFloat
        let y: CGFloat
        /// Design points per map unit.
        var scale: CGFloat = 0.75
        var isMirrored = false
    }

    /// On the back hill, kept left and right of the foxes.
    private static let backProps = [
        Prop(kind: .mushroomHouseFront, x: 105, y: 815),
        Prop(kind: .onionHouseFront, x: 1268, y: 808, isMirrored: true),
        Prop(kind: .lamp, x: 268, y: 832, scale: 0.95),
        Prop(kind: .lamp, x: 1110, y: 828, scale: 0.95),
        Prop(kind: .grassTuft1, x: 360, y: 795, scale: 2.2),
        Prop(kind: .grassTuft2, x: 620, y: 762, scale: 2.2),
        Prop(kind: .grassTuft1, x: 945, y: 776, scale: 2.2),
        Prop(kind: .grassTuft2, x: 205, y: 830, scale: 2.2),
        Prop(kind: .pathRock, x: 770, y: 780, scale: 1.3),
    ]

    /// On the front hill, nearer the child.
    private static let frontProps = [
        Prop(kind: .treeStump, x: 400, y: 945, scale: 1.6),
        Prop(kind: .treeStump, x: 1020, y: 980, scale: 1.35, isMirrored: true),
        Prop(kind: .steppingStone, x: 560, y: 990, scale: 1.2),
        Prop(kind: .steppingStone, x: 690, y: 1005, scale: 1.2, isMirrored: true),
        Prop(kind: .steppingStone, x: 820, y: 990, scale: 1.2),
        Prop(kind: .pathRock, x: 225, y: 970, scale: 1.7),
        Prop(kind: .pathRock, x: 1190, y: 930, scale: 1.5, isMirrored: true),
        Prop(kind: .soilSpeck, x: 120, y: 1000, scale: 1.6),
        Prop(kind: .soilSpeck, x: 1285, y: 1005, scale: 1.6, isMirrored: true),
        Prop(kind: .grassTuft1, x: 60, y: 915, scale: 3),
        Prop(kind: .grassTuft2, x: 310, y: 1005, scale: 3),
        Prop(kind: .grassTuft1, x: 485, y: 915, scale: 2.8),
        Prop(kind: .grassTuft2, x: 625, y: 940, scale: 2.6),
        Prop(kind: .grassTuft1, x: 900, y: 935, scale: 2.8),
        Prop(kind: .grassTuft2, x: 1100, y: 925, scale: 3),
        Prop(kind: .grassTuft1, x: 1320, y: 945, scale: 3),
        Prop(kind: .grassTuft2, x: 940, y: 1015, scale: 2.8),
        Prop(kind: .grassTuft1, x: 160, y: 1015, scale: 2.6),
    ]

    private static let flowers: [CGPoint] = [
        CGPoint(x: 330, y: 815), CGPoint(x: 440, y: 770), CGPoint(x: 545, y: 790),
        CGPoint(x: 700, y: 752), CGPoint(x: 850, y: 790), CGPoint(x: 1010, y: 768),
        CGPoint(x: 1180, y: 800), CGPoint(x: 200, y: 870), CGPoint(x: 1300, y: 880),
    ]

    private static let flowerColors: [Color] = [
        .white,
        Color(red: 1, green: 0.78, blue: 0.85),
        Color(red: 1, green: 0.86, blue: 0.4),
    ]

    private func propView(_ prop: Prop, scale: CGFloat, in size: CGSize) -> some View {
        let drawn = CGSize(
            width: prop.kind.size.width * prop.scale * scale,
            height: prop.kind.size.height * prop.scale * scale
        )
        let base = point(x: prop.x, y: prop.y, in: size)
        return Image(prop.kind.assetName)
            .resizable()
            .scaleEffect(x: prop.isMirrored ? -1 : 1, y: 1)
            .frame(width: drawn.width, height: drawn.height)
            .position(x: base.x, y: base.y - drawn.height / 2)
    }

    /// Spreads design points across the real screen: horizontally by width, vertically by height.
    private func point(x: CGFloat, y: CGFloat, in size: CGSize) -> CGPoint {
        CGPoint(x: x / Self.design.width * size.width, y: y / Self.design.height * size.height)
    }
}

/// A gentle hill filling the bottom of its frame. The edges and the middle give the height of
/// the hilltop as fractions of the frame height.
private struct HillShape: Shape {
    let left: CGFloat
    let middle: CGFloat
    let right: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let leftPoint = CGPoint(x: rect.minX, y: rect.minY + rect.height * left)
        let rightPoint = CGPoint(x: rect.maxX, y: rect.minY + rect.height * right)
        // A quadratic curve peaks halfway to its control point, so aim the control point twice
        // as far above the edges as the wanted hilltop.
        let edges = (left + right) / 2
        let control = CGPoint(x: rect.midX, y: rect.minY + rect.height * (2 * middle - edges))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: leftPoint)
        path.addQuadCurve(to: rightPoint, control: control)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A puffy cartoon cloud: a few circles on a flat base.
private struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let puffs: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
            (0.22, 0.66, 0.2), (0.42, 0.45, 0.28), (0.64, 0.5, 0.24), (0.8, 0.68, 0.18),
        ]
        for puff in puffs {
            let radius = puff.r * w * 0.75
            path.addEllipse(in: CGRect(
                x: rect.minX + puff.x * w - radius,
                y: rect.minY + puff.y * h - radius * 0.8,
                width: radius * 2,
                height: radius * 1.6
            ))
        }
        path.addRoundedRect(
            in: CGRect(x: rect.minX + w * 0.08, y: rect.minY + h * 0.6, width: w * 0.84, height: h * 0.36),
            cornerSize: CGSize(width: h * 0.18, height: h * 0.18)
        )
        return path
    }
}

/// A five-petal meadow flower.
private struct FlowerView: View {
    let petal: Color

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(petal)
                        .frame(width: side * 0.45, height: side * 0.45)
                        .offset(y: -side * 0.27)
                        .rotationEffect(.degrees(Double(index) * 72))
                }
                Circle()
                    .fill(Color(red: 1, green: 0.72, blue: 0.2))
                    .frame(width: side * 0.34, height: side * 0.34)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

#Preview {
    PatchReminderScreen(onRest: {})
}
