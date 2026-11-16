//
//  MarketSceneView.swift
//  The Veggie Keeper picture: sky and grass, drifting clouds, the fox behind
//  the stall, the thief and the moles.
//
//  The artwork is drawn for a 4:3 screen (the 13-inch iPad). Everything sits on a
//  4:3 "stage" that fills the screen, and each piece is placed with fractions of
//  the stage size, so the layers line up on every iPad.
//

import SwiftUI

struct MarketSceneView: View {
    let veggiesLeft: Int
    let foxIsAwake: Bool
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

    /// How far the stall (with its shadow and the fox) sits above its place in
    /// the original FULL PIC, as a fraction of the stage height.
    private let stallRaise: CGFloat = 0.05

    private func stage(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Image("StallBG")
                .resizable()
                .frame(width: w, height: h)

            DriftingCloudsView(stageWidth: w, stageHeight: h)

            // The stall's shadow on the grass. Moves together with the stall.
            Image("StallShadow")
                .resizable()
                .scaledToFit()
                .frame(width: w * 0.5476)
                .position(x: w * 0.5049, y: h * (0.8476 - stallRaise))

            // The fox stands behind the stall: drawn first, so the stall covers its legs.
            KeeperFoxView(isAwake: foxIsAwake)
                .frame(height: h * 0.28)
                .position(x: w * 0.52, y: h * (0.665 - stallRaise))

            Image(stallImageName)
                .resizable()
                .scaledToFit()
                .frame(width: w * 0.565)
                .position(x: w * 0.520, y: h * (0.559 - stallRaise))

            // Where the stall is drawn (without the empty space around it).
            // The game checks the gaze point against this area.
            Color.clear
                .frame(width: w * 0.541, height: h * 0.601)
                .position(x: w * 0.5185, y: h * (0.552 - stallRaise))
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onStallFrameChange($0) }

            ThiefView(isHere: thiefIsHere, crate: thiefCrate, stageWidth: w, stageHeight: h)

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
    MarketSceneView(veggiesLeft: 3, foxIsAwake: true, thiefIsHere: false, molesCanAppear: true) { _ in }
}
