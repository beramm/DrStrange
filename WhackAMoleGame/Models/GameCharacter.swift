import Foundation

/// Character looks. Each look can have artwork in the asset catalog
/// (`Character<Name>` awake, `Character<Name>Sleepy` for decoys); until that exists a vector
/// placeholder is drawn instead.
enum CharacterVariant: Int, CaseIterable, Codable {
    case sunny
    case berry
    case leafy
    case sky

    var name: String {
        switch self {
        case .sunny: "Sunny"
        case .berry: "Berry"
        case .leafy: "Leafy"
        case .sky: "Sky"
        }
    }

    func assetName(for role: TargetRole) -> String {
        role == .target ? "Character\(name)" : "Character\(name)Sleepy"
    }
}

enum TargetRole: String, Codable {
    /// Awake character with a star: tap it.
    case target
    /// Sleepy character without a star: leave it. Tapping is recorded but never penalised.
    case decoy
}

enum TargetPhase: Equatable {
    case up
    case hit(at: TimeInterval)
    case leaving(at: TimeInterval)

    var isUp: Bool { self == .up }
}

struct ActiveTarget: Identifiable, Equatable {
    let id: Int
    let holeIndex: Int
    let variant: CharacterVariant
    let role: TargetRole
    let spawnedAt: TimeInterval
    let visibleDuration: TimeInterval
    var phase: TargetPhase = .up

    var expiresAt: TimeInterval { spawnedAt + visibleDuration }
}
