import Foundation

/// Character looks. Each has an optional pair of asset-catalog images
/// (`Targets/<name>Body` and `Targets/<name>Feature`); until those exist a vector placeholder is drawn.
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

    /// Silhouette layer. In dichoptic mode it is shown to one eye only.
    var bodyAssetName: String { "Targets/\(name)Body" }
    /// Face / star layer. In dichoptic mode it is shown to the other eye.
    var featureAssetName: String { "Targets/\(name)Feature" }
}

enum TargetRole: String, Codable {
    /// Awake character with a star: tap it.
    case target
    /// Sleepy character without a star: leave it. Tapping is recorded but never penalised.
    case decoy
}

/// Which eye sees which part of a character. Both parts are needed: the silhouette shows *where*
/// something is, the features show *whether* it is a target or a decoy.
struct StimulusAssignment: Codable, Equatable {
    var bodyEye: Eye
    var featureEye: Eye

    init(featureEye: Eye) {
        self.featureEye = featureEye
        self.bodyEye = featureEye.other
    }
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
    let stimulus: StimulusAssignment
    let spawnedAt: TimeInterval
    let visibleDuration: TimeInterval
    var phase: TargetPhase = .up

    var expiresAt: TimeInterval { spawnedAt + visibleDuration }
}
