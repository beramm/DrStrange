//
//  GazeSmoother.swift
//  Calms the shaky gaze point.
//
//  The tracker sends a new point about 60 times a second, with no smoothing.
//  Even when the eye rests on one spot, the point wobbles a little.
//  - Small moves are blended in slowly, so the point stays steady.
//  - A big jump that lasts (the eye really moved somewhere new) is followed at once,
//    so the point doesn't lag behind.
//

import CoreGraphics

struct GazeSmoother {
    /// 0–1: how much of each new point is mixed in. Lower = steadier but slower.
    var blend: CGFloat = 0.2
    /// A move bigger than this (in screen points) may mean the eye jumped somewhere new.
    var jumpDistance: CGFloat = 150
    /// How many far-away points in a row count as a real jump (not one bad reading).
    var jumpSamples = 3

    /// The smoothed point, or nil before the first point.
    private(set) var point: CGPoint?
    private var farSamplesInARow = 0

    mutating func add(_ newPoint: CGPoint) {
        guard let current = point else {
            point = newPoint
            return
        }

        let distance = hypot(newPoint.x - current.x, newPoint.y - current.y)
        if distance > jumpDistance {
            farSamplesInARow += 1
            if farSamplesInARow >= jumpSamples {
                point = newPoint          // a real jump: follow it straight away
                farSamplesInARow = 0
            }
            return                        // otherwise ignore the odd far-away reading
        }

        farSamplesInARow = 0
        point = CGPoint(
            x: current.x + (newPoint.x - current.x) * blend,
            y: current.y + (newPoint.y - current.y) * blend
        )
    }

    /// Forget the point, e.g. when tracking is lost.
    mutating func reset() {
        point = nil
        farSamplesInARow = 0
    }
}
