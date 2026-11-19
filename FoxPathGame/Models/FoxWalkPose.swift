import CoreGraphics
import Foundation

/// Where a character stands on the map and which picture it shows.
struct FoxWalkPose: Equatable {
    var character: PathCharacter
    /// Ground point under the character's feet, in map units.
    var feet: CGPoint
    var facing: FoxFacing
    var assetName: String
    /// The side view walks right; mirrored, it walks left.
    var isMirrored = false

    /// A character standing still at `feet`, facing the player.
    static func standing(_ character: PathCharacter, at feet: CGPoint) -> FoxWalkPose {
        FoxWalkPose(character: character, feet: feet, facing: .front, assetName: character.standingAsset)
    }

    /// The followed character on its path for a tracking state.
    ///
    /// - Walking: faces the way it walks, with the walk-cycle picture for the distance walked.
    /// - Stopped because the child looked away: stays exactly where it stopped and keeps facing
    ///   the way it was walking (it never turns round), standing with its feet together.
    /// - Waiting for the first look, or at the stall: stands facing the player.
    static func onPath(
        _ character: PathCharacter,
        state: FoxTrackingState,
        feet: CGPoint,
        tangent: CGVector,
        distance: CGFloat
    ) -> FoxWalkPose {
        switch state {
        case .following:
            let facing = FoxFacing.walking(along: tangent)
            return FoxWalkPose(
                character: character,
                feet: feet,
                facing: facing,
                assetName: FoxWalkAnimation.assetName(for: character, facing: facing, distance: distance)
            )
        case .offTrack:
            let facing = FoxFacing.walking(along: tangent)
            return FoxWalkPose(
                character: character,
                feet: feet,
                facing: facing,
                assetName: FoxWalkAnimation.restingAssetName(for: character, facing: facing)
            )
        case .waiting, .finished:
            return .standing(character, at: feet)
        }
    }

    /// Where the picture is drawn so the feet land on `feet`.
    var frame: CGRect {
        let size = character.size(facing: facing)
        var anchor = character.feetAnchor(facing: facing)
        if isMirrored { anchor.x = 1 - anchor.x }
        return CGRect(
            x: feet.x - size.width * anchor.x,
            y: feet.y - size.height * anchor.y,
            width: size.width,
            height: size.height
        )
    }

    /// Middle of the body: what the player is asked to look at.
    var bodyCenter: CGPoint {
        CGPoint(x: feet.x, y: feet.y - character.size(facing: facing).height * 0.5)
    }

    var height: CGFloat { character.size(facing: facing).height }
}

/// Picks walk-cycle pictures from the distance walked, so the legs keep time with the ground
/// at any speed and freeze exactly when the character stops.
enum FoxWalkAnimation {
    /// Map units walked per side-view picture (the fox's 39-picture cycle covers 104 units).
    static let sideStepLength: CGFloat = 104 / 39
    /// Map units for one full front or back cycle (4 pictures).
    static let frontCycleLength: CGFloat = 64
    /// The fox standing, for screens outside the game (the DrStrange home card).
    static let standingAsset = PathCharacter.fox.standingAsset

    /// Map units for one full side-view cycle of `character`.
    static func sideCycleLength(of character: PathCharacter) -> CGFloat {
        sideStepLength * CGFloat(character.sideSequence.count)
    }

    static func assetName(for character: PathCharacter, facing: FoxFacing, distance: CGFloat) -> String {
        switch facing {
        case .side:
            let sequence = character.sideSequence
            let index = step(distance, cycleLength: sideCycleLength(of: character), count: sequence.count)
            return character.sideAsset(frame: sequence[index])
        case .front:
            return character.frontAsset(frame: step(distance, cycleLength: frontCycleLength, count: 4) + 1)
        case .back:
            return character.backAsset(frame: step(distance, cycleLength: frontCycleLength, count: 4) + 1)
        }
    }

    /// The picture for standing still while facing `facing`: feet together.
    static func restingAssetName(for character: PathCharacter, facing: FoxFacing) -> String {
        switch facing {
        case .side: character.sideAsset(frame: character.sideSequence[0])
        case .front: character.frontAsset(frame: 1)
        case .back: character.backAsset(frame: 1)
        }
    }

    private static func step(_ distance: CGFloat, cycleLength: CGFloat, count: Int) -> Int {
        let position = max(distance, 0).truncatingRemainder(dividingBy: cycleLength) / cycleLength
        return min(Int(position * CGFloat(count)), count - 1)
    }
}
