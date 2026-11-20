//
//  MarketSceneView.swift
//  The Veggie Keeper picture: sky and grass, drifting clouds, the hot air
//  balloon, the keeper behind the stall, the mole thief and the distraction moles.
//
//  The artwork is drawn for a 4:3 screen (the 13-inch iPad). Everything sits on a
//  4:3 "stage" that fills the screen, and each piece is placed with fractions of
//  the stage size, so the layers line up on every iPad.
//

import SwiftUI

struct MarketSceneView: View {
    /// The character who keeps the stall (the player's character).
    let keeper: FixationCharacter
    let veggiesLeft: Int
    let keeperIsAwake: Bool
    let thiefIsHere: Bool
    let molesCanAppear: Bool
    /// Reports where the stall is on screen, used to check the gaze point.
    let onStallFrameChange: (CGRect) -> Void

    var body: some View {
        Color.clear
            .overlay {
                GeometryReader { geo in
                    stage(width: geo.size.width, height: geo.size.height)
                }
                .aspectRatio(4 / 3, contentMode: .fill)
            }
            .clipped()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    /// How big the stall is (1 = its size in the original FULL PIC).
    /// The stall, its shadow and the keeper all shrink together.
    private let stallScale: CGFloat = 0.65
    /// Where the middle of the stall's base stands, as fractions of the stage.
    /// Smaller y = higher up on the screen. The horizon is at about 0.585, so the
    /// stall and its shadow stand on the grass, a little below it.
    private let stallStandsAt = CGPoint(x: 0.52, y: 0.645)
    /// The middle of the stall's base in the original full-size layout.
    private let fullSizeBase = CGPoint(x: 0.52, y: 0.80)

    /// Moves a point of the full-size layout to where it is in the smaller, moved stall.
    private func scaled(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(
            x: stallStandsAt.x + (x - fullSizeBase.x) * stallScale,
            y: stallStandsAt.y + (y - fullSizeBase.y) * stallScale
        )
    }

    private func stage(width w: CGFloat, height h: CGFloat) -> some View {
        let shadow = scaled(x: 0.5049, y: 0.7976)
        // The keeper stands with their feet here (hidden behind the counter).
        let keeperFeet = scaled(x: 0.52, y: 0.755)
        let keeperHeight = keeper.keeperHeight * stallScale
        let stall = scaled(x: 0.520, y: 0.509)
        let gazeArea = scaled(x: 0.5185, y: 0.502)
        // The mole thief comes out of a hole in front of each basket.
        let crateX = [0.39, 0.515, 0.645].map { scaled(x: $0, y: 0).x }
        let thiefHoleY = scaled(x: 0, y: 0.92).y

        return ZStack(alignment: .topLeading) {
            Image("StallBG")
                .resizable()
                .frame(width: w, height: h)

            DriftingCloudsView(stageWidth: w, stageHeight: h)

            // Distraction from above: flies in the sky, behind the stall.
            BalloonView(canAppear: molesCanAppear, stageWidth: w, stageHeight: h)

            // The stall's shadow on the grass. Moves together with the stall.
            Image("StallShadow")
                .resizable()
                .scaledToFit()
                .frame(width: w * 0.5476 * stallScale)
                .position(x: w * shadow.x, y: h * shadow.y)

            // The keeper stands behind the stall: drawn first, so the stall covers their legs.
            KeeperView(character: keeper, isAwake: keeperIsAwake)
                .frame(height: h * keeperHeight)
                .position(x: w * keeperFeet.x, y: h * (keeperFeet.y - keeperHeight / 2))

            Image(stallImageName)
                .resizable()
                .scaledToFit()
                .frame(width: w * 0.565 * stallScale)
                .position(x: w * stall.x, y: h * stall.y)

            // Where the stall is drawn (without the empty space around it).
            // The game checks the gaze point against this area.
            Color.clear
                .frame(width: w * 0.541 * stallScale, height: h * 0.601 * stallScale)
                // Measured before `.position`, which would make it as big as the whole screen.
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onStallFrameChange($0) }
                .position(x: w * gazeArea.x, y: h * gazeArea.y)

            MoleThiefView(
                isHere: thiefIsHere,
                crate: thiefCrate,
                veggiesLeft: veggiesLeft,
                holeX: crateX,
                holeY: thiefHoleY,
                stageWidth: w,
                stageHeight: h
            )

            MoleView(canAppear: molesCanAppear, stageWidth: w, stageHeight: h)
        }
        .frame(width: w, height: h)
    }

    /// The crate the thief goes for next: 0 = left, 1 = middle, 2 = right.
    /// The stall pictures empty the crates in that order.
    private var thiefCrate: Int {
        min(max(3 - veggiesLeft, 0), 2)
    }

    /// One picture for each number of veggie crates left.
    private var stallImageName: String {
        switch veggiesLeft {
        case 3...: "StallFull"
        case 2: "StallStolen1"
        case 1: "StallStolen2"
        default: "StallStolen3"
        }
    }
}

#Preview(traits: .landscapeLeft) {
    MarketSceneView(keeper: .fox, veggiesLeft: 3, keeperIsAwake: true, thiefIsHere: false, molesCanAppear: true) { _ in }
}
