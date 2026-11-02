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
    /// Tapped; the fox is on its way. The character stays still and cannot expire.
    case targeted
    /// Struck (by the fox), or a sleepy decoy that was tapped. Reacts, then sinks.
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
    /// When the character hides if not tapped. Pushed back while the fox is attacking another
    /// character, so the child is never penalised for watching the animation.
    var expiresAt: TimeInterval

    init(id: Int, holeIndex: Int, variant: CharacterVariant, role: TargetRole, spawnedAt: TimeInterval, visibleDuration: TimeInterval) {
        self.id = id
        self.holeIndex = holeIndex
        self.variant = variant
        self.role = role
        self.spawnedAt = spawnedAt
        self.visibleDuration = visibleDuration
        self.expiresAt = spawnedAt + visibleDuration
    }
}
