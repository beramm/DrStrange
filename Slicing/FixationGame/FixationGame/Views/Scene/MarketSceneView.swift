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

    private func stage(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Image("StallBG")
                .resizable()
                .frame(width: w, height: h)

            DriftingCloudsView(stageWidth: w, stageHeight: h)

            // The fox stands behind the stall: drawn first, so the stall covers its legs.
            KeeperFoxView(isAwake: foxIsAwake)
                .frame(height: h * 0.34)
                .position(x: w * 0.52, y: h * 0.68)

            Image(stallImageName)
                .resizable()
                .scaledToFit()
                .frame(width: w * 0.565)
                .position(x: w * 0.520, y: h * 0.559)

            // Where the stall is drawn (without the empty space around it).
            // The game checks the gaze point against this area.
            Color.clear
                .frame(width: w * 0.541, height: h * 0.601)
                .position(x: w * 0.5185, y: h * 0.552)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onStallFrameChange($0) }

            ThiefView(isHere: thiefIsHere, stageWidth: w, stageHeight: h)

            MoleView(canAppear: molesCanAppear, stageWidth: w, stageHeight: h)
        }
        .frame(width: w, height: h)
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
