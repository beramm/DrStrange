//
//  GazeScreenArea.swift
//  The part of the screen the calibration circles cover. The gaze tracker answers
//  with 0–1 values inside this area, so the calibration and the game must both
//  use it to turn those values into screen points.
//
//  The area stays away from the screen edges. Looking at the far corners
//  (especially the bottom, far from the camera) makes the eyelid droop and the
//  head turn, so the tracker kept retrying the bottom-right circle.
//

import CoreGraphics

nonisolated enum GazeScreenArea {
    /// Space kept free on every side, as a fraction of the screen size.
    static let margin: CGFloat = 0.08

    /// Turns a 0–1 gaze or target point into a point on a screen of this size.
    static func screenPoint(x: Double, y: Double, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * (margin + CGFloat(x) * (1 - 2 * margin)),
            y: size.height * (margin + CGFloat(y) * (1 - 2 * margin))
        )
    }
}
