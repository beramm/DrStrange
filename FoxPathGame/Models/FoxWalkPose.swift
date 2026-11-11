import CoreGraphics
import Foundation

/// Where the fox stands on the map and which picture it shows.
struct FoxWalkPose: Equatable {
    /// Ground point under the fox's feet, in map units.
    var feet: CGPoint
    var facing: FoxFacing
    var assetName: String

    /// Where the picture is drawn so the feet land on `feet`.
    var frame: CGRect {
        let size = facing.size
        let anchor = facing.feetAnchor
        return CGRect(
            x: feet.x - size.width * anchor.x,
            y: feet.y - size.height * anchor.y,
            width: size.width,
            height: size.height
        )
    }

    /// Middle of the fox's body: what the player is asked to look at.
    var bodyCenter: CGPoint {
        CGPoint(x: feet.x, y: feet.y - facing.size.height * 0.5)
    }
}

/// Picks walk-cycle pictures from the distance walked, so the legs keep time with the ground
/// at any speed and freeze exactly when the fox stops.
enum FoxWalkAnimation {
    /// Map units for one full side-view cycle.
    static let sideCycleLength: CGFloat = 104
    /// Map units for one full front or back cycle (4 pictures).
    static let frontCycleLength: CGFloat = 64
    /// The picture used whenever the fox stands and waits.
    static let standingAsset = "FoxPath/Front1"

    /// The provided side view is a 39-picture cycle in which several pictures repeat. Only the
    /// unique ones are in the asset catalog; this is the order they play in.
    static let sideSequence: [Int] = Array(1...11) + [8, 7, 14, 5, 4, 3, 2, 1]
        + Array(20...29) + Array((21...29).reversed()) + [39]

    static func assetName(facing: FoxFacing, distance: CGFloat) -> String {
        switch facing {
        case .side:
            let index = step(distance, cycleLength: sideCycleLength, count: sideSequence.count)
            return String(format: "FoxPath/Side%02d", sideSequence[index])
        case .front:
            return "FoxPath/Front\(step(distance, cycleLength: frontCycleLength, count: 4) + 1)"
        case .back:
            return "FoxPath/Back\(step(distance, cycleLength: frontCycleLength, count: 4) + 1)"
        }
    }

    private static func step(_ distance: CGFloat, cycleLength: CGFloat, count: Int) -> Int {
        let position = max(distance, 0).truncatingRemainder(dividingBy: cycleLength) / cycleLength
        return min(Int(position * CGFloat(count)), count - 1)
    }
}
