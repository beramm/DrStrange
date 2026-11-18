import CoreGraphics
import Foundation

/// The three friends of the game. Any of them can be the one the child follows; none of them is
/// ever the thief (that is the mole).
enum PathCharacter: String, CaseIterable, Codable, Identifiable {
    case fox
    case bunny
    case raccoon

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fox: "Fox"
        case .bunny: "Bunny"
        case .raccoon: "Raccoon"
        }
    }

    /// Asset catalog prefix. The fox kept its original names; the others have their own folder.
    private var assetPrefix: String {
        switch self {
        case .fox: "FoxPath/"
        case .bunny: "FoxPath/Bunny/"
        case .raccoon: "FoxPath/Raccoon/"
        }
    }

    /// Picture used whenever the character stands still, facing the player.
    var standingAsset: String { "\(assetPrefix)Front1" }

    /// Drawn size in map units. All three were drawn on the same canvas, so they keep the
    /// artist's relative sizes (219 map units for the fox's 1,496-pixel side view).
    func size(facing: FoxFacing) -> CGSize {
        switch (self, facing) {
        case (.fox, .side): CGSize(width: 119, height: 219)
        case (.fox, _): CGSize(width: 134, height: 218)
        case (.bunny, .side): CGSize(width: 131, height: 220)
        case (.bunny, .front): CGSize(width: 133, height: 229)
        case (.bunny, .back): CGSize(width: 120, height: 229)
        case (.raccoon, .side): CGSize(width: 126, height: 204)
        case (.raccoon, .front): CGSize(width: 146, height: 205)
        case (.raccoon, .back): CGSize(width: 146, height: 208)
        }
    }

    /// Where the feet touch the ground, as a fraction of the picture.
    func feetAnchor(facing: FoxFacing) -> CGPoint {
        switch (self, facing) {
        case (.fox, .side): CGPoint(x: 0.49, y: 0.965)
        case (.fox, _): CGPoint(x: 0.45, y: 0.975)
        case (.bunny, .side): CGPoint(x: 0.5, y: 0.98)
        case (.bunny, .front): CGPoint(x: 0.45, y: 0.98)
        case (.bunny, .back): CGPoint(x: 0.4, y: 0.98)
        case (.raccoon, .side): CGPoint(x: 0.52, y: 0.98)
        case (.raccoon, .front): CGPoint(x: 0.45, y: 0.98)
        case (.raccoon, .back): CGPoint(x: 0.44, y: 0.98)
        }
    }

    /// Order of the side-view pictures in one walk cycle. Each provided walk plays forward and
    /// back, so many pictures repeat; only the unique ones are in the asset catalog, named by
    /// their original frame number.
    var sideSequence: [Int] {
        switch self {
        case .fox:
            Array(1...11) + [8, 7, 14, 5, 4, 3, 2, 1] + Array(20...29) + Array((21...29).reversed()) + [39]
        case .bunny:
            Array(1...13) + Array((1...12).reversed()) + Array(26...35) + [34, 33, 31, 32, 30, 29, 28, 27, 26]
        case .raccoon:
            Array(1...12) + Array((1...11).reversed()) + Array(24...33) + Array((24...32).reversed())
        }
    }

    func sideAsset(frame: Int) -> String { String(format: "%@Side%02d", assetPrefix, frame) }
    func frontAsset(frame: Int) -> String { "\(assetPrefix)Front\(frame)" }
    func backAsset(frame: Int) -> String { "\(assetPrefix)Back\(frame)" }
}

/// Who the child follows on one walk. Any of the three friends can be the one to follow; the
/// thief is always the mole, never one of the friends.
struct CharacterRoles: Equatable {
    let primary: PathCharacter

    /// The character to follow, drawn from all three.
    static func random(using generator: inout SeededGenerator) -> CharacterRoles {
        CharacterRoles(primary: PathCharacter.allCases.randomElement(using: &generator) ?? .fox)
    }
}
