import Foundation

/// Character looks. All looks currently use the same mole animation; the variant is still chosen
/// and recorded per spawn so per-look artwork can be added later without changing game logic.
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
}

enum TargetRole: String, Codable {
    /// Awake mole: tap it.
    case target
    /// Sleeping mole (grey, with a "z z" bubble): leave it. Tapping is recorded but never penalised.
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

/// A spot on the board as fractions of its width and height (0...1).
struct BoardPoint: Codable, Equatable {
    var x: Double
    var y: Double

    func distance(to other: BoardPoint) -> Double {
        ((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)).squareRoot()
    }
}

/// A hole currently on the board. Holes exist only around a mole: they open, the mole comes and
/// goes, and they close again.
struct HoleVisual: Identifiable, Equatable {
    let id: Int
    /// Zone of the board; at most one hole per zone at a time.
    let holeIndex: Int
    let position: BoardPoint
    /// Which of the hole images to draw.
    let artIndex: Int
    /// 0 = closed, 1 = fully open.
    var openness: Double
}

/// What a mole looks like right now.
struct MoleVisual: Equatable {
    /// 1 (helmet tip) ... `frameCount` (fully out of the hole).
    var frame: Int
    /// 0...1 through the hit animation, from the hammer landing until the mole has sunk out of
    /// sight; `nil` when not hit.
    var hitProgress: Double?

    static let frameCount = 24

    /// Which frame of the hit animation to draw, 1 ... `frameCount`; `nil` when not hit.
    var hitFrame: Int? {
        hitProgress.map { 1 + Int((Double(Self.frameCount - 1) * $0).rounded()) }
    }
}

struct ActiveTarget: Identifiable, Equatable {
    let id: Int
    let holeIndex: Int
    let variant: CharacterVariant
    let role: TargetRole
    let spawnedAt: TimeInterval
    let visibleDuration: TimeInterval
    var phase: TargetPhase = .up
    /// Set when the child hits the character; shown with the points when the hammer lands.
    var rating: HitRating?
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
