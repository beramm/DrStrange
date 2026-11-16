import CoreGraphics
import Foundation

/// Whether the child is following the character, as far as the game can tell.
enum PlayerAttentionState: Equatable {
    case following
    /// The pointer has been off the character for longer than the look-away grace.
    case notFollowing
    /// No usable gaze reading (camera starting, face lost, poor light). Never counted as
    /// not following: the thief holds still.
    case trackingUnavailable
}

enum ThiefState: Equatable {
    case inactive
    /// Coming into view from the edge of the map.
    case appearing
    /// Around the vegetables: creeps closer while the child is not following and backs off
    /// while the child follows.
    case approaching
    /// At the stall, taking vegetables. Once started, a theft always completes.
    case stealing
    /// Running back off the map.
    case retreating
}

enum ThiefEvent: Equatable {
    case reachedVegetables
    /// The theft is complete. Sent exactly once per thief.
    case stole
    /// The thief is off the map again.
    case left
}

/// The thief's way in: a straight line from just outside the map to the front of the stall.
struct ThiefRoute: Equatable {
    let start: CGPoint
    let target: CGPoint

    var length: CGFloat { hypot(target.x - start.x, target.y - start.y) }

    /// 0 at the map edge, 1 at the vegetables.
    func point(at progress: Double) -> CGPoint {
        let t = CGFloat(min(max(progress, 0), 1))
        return CGPoint(x: start.x + (target.x - start.x) * t, y: start.y + (target.y - start.y) * t)
    }

    /// Direction from the edge towards the vegetables.
    var direction: CGVector {
        let length = max(self.length, 0.001)
        return CGVector(dx: (target.x - start.x) / length, dy: (target.y - start.y) / length)
    }

    /// Shortest acceptable way in, so the thief is never at the vegetables in a moment.
    static let minimumLength: CGFloat = 320

    /// A way in from below the map or from its right edge to the right part of the stall's
    /// counter, chosen at random among those that do not cross a house or a lamp.
    static func make(for map: FoxPathMap, using generator: inout SeededGenerator) -> ThiefRoute {
        let size = map.size
        guard let stall = map.standingSprites.first(where: { $0.kind == .finishStall }) else {
            let end = map.route.points[map.route.points.count - 1]
            return ThiefRoute(start: CGPoint(x: end.x, y: size.height + 260), target: end)
        }
        // Right of the counter's middle, where the friend stops, but fully on the map: the stall
        // stands at the right edge.
        let target = CGPoint(x: stall.frame.minX + stall.frame.width * 0.72, y: stall.baseline + 6)
        let obstacles = map.standingSprites
            .filter { $0.kind.isHouse || $0.kind == .lamp }
            .map { $0.footprint.insetBy(dx: -24, dy: -12) }

        var clear: [ThiefRoute] = []
        var all: [ThiefRoute] = []
        for _ in 0..<24 {
            let start: CGPoint
            if Bool.random(using: &generator) {
                // From below, fully out of sight (the tallest character is about 230 units).
                start = CGPoint(x: CGFloat.random(in: (stall.frame.minX - 220)...(size.width - 60), using: &generator), y: size.height + 250)
            } else {
                // From the right edge, below the stall so the thief is never hidden behind it.
                let top = min(stall.baseline + 120, size.height - 40)
                start = CGPoint(x: size.width + 90, y: CGFloat.random(in: top...(size.height - 40), using: &generator))
            }
            let route = ThiefRoute(start: start, target: target)
            guard route.length >= minimumLength else { continue }
            all.append(route)
            let steps = Int(route.length / 10)
            let crosses = (0...steps).contains { step in
                let point = route.point(at: Double(step) / Double(max(steps, 1)))
                return obstacles.contains { $0.contains(point) }
            }
            if !crosses { clear.append(route) }
        }
        if let route = clear.randomElement(using: &generator) { return route }
        if let route = all.max(by: { $0.length < $1.length }) { return route }
        return ThiefRoute(start: CGPoint(x: target.x, y: size.height + 250), target: target)
    }
}

/// One thief visit, driven by the game clock and the child's attention. It has no knowledge of
/// how attention is measured, so the same rules work with gaze, a finger or a test.
struct FoxPathThief: Equatable {
    /// How far along its way the thief walks while coming into view.
    static let lurkProgress = 0.18

    let character: PathCharacter
    let route: ThiefRoute
    let settings: ThiefSettings

    private(set) var state: ThiefState = .appearing
    /// 0 at the map edge, 1 at the vegetables.
    private(set) var progress: Double = 0
    /// Seconds since the thief appeared.
    private(set) var age: TimeInterval = 0
    /// Seconds spent in the current state.
    private(set) var stateTime: TimeInterval = 0
    /// `true` once the theft is complete.
    private(set) var hasStolen = false
    private var retreatFrom: Double = 0

    init(character: PathCharacter, route: ThiefRoute, settings: ThiefSettings) {
        self.character = character
        self.route = route
        self.settings = settings
    }

    var position: CGPoint { route.point(at: progress) }

    mutating func advance(by delta: TimeInterval, attention: PlayerAttentionState) -> [ThiefEvent] {
        guard delta > 0, state != .inactive else { return [] }
        age += delta
        stateTime += delta

        switch state {
        case .inactive:
            return []
        case .appearing:
            progress = Self.lurkProgress * min(stateTime / max(settings.appearDuration, 0.01), 1)
            if stateTime >= settings.appearDuration { enter(.approaching) }
            return []
        case .approaching:
            let speed = 1 / max(settings.approachDuration, 0.01)
            switch attention {
            case .notFollowing:
                progress = min(progress + delta * speed, 1)
            case .following:
                progress = max(progress - delta * speed * settings.backOffRate, Self.lurkProgress)
            case .trackingUnavailable:
                // Missing gaze is nobody's fault: the thief waits.
                break
            }
            if progress >= 1 {
                enter(.stealing)
                return [.reachedVegetables]
            }
            if age >= settings.patience { retreat() }
            return []
        case .stealing:
            guard stateTime >= settings.stealDuration else { return [] }
            hasStolen = true
            retreat()
            return [.stole]
        case .retreating:
            let fraction = min(stateTime / max(settings.retreatDuration, 0.01), 1)
            progress = retreatFrom * (1 - fraction)
            guard fraction >= 1 else { return [] }
            enter(.inactive)
            return [.left]
        }
    }

    /// The character the child follows reached the stall: a thief that has not started
    /// stealing runs off.
    mutating func chaseAway() {
        guard state == .appearing || state == .approaching else { return }
        retreat()
    }

    private mutating func retreat() {
        retreatFrom = progress
        enter(.retreating)
    }

    private mutating func enter(_ newState: ThiefState) {
        state = newState
        stateTime = 0
    }
}
