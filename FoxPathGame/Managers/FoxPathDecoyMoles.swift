import CoreGraphics
import Foundation

/// Timings for the decoy moles: harmless moles that pop up at random spots on the grass while the
/// child follows, to tempt the eyes away. They never take anything and never cost a heart.
struct DecoyMoleSettings: Equatable {
    /// Seconds of following before the first decoy of a walk can pop up, at random in this range.
    var firstDelay: ClosedRange<Double> = 4...7
    /// Seconds between one decoy going back down and the next popping up, at random in this range.
    var interval: ClosedRange<Double> = 4...8
    /// How far from the followed character's feet a decoy pops up (map units), so it is near
    /// enough to be seen but never mistaken for the thief under the basket.
    var distance: ClosedRange<CGFloat> = 240...520
    var holeOpenDuration: Double = 0.3
    var emergeDuration: Double = 0.45
    /// Seconds the decoy stays up, looking around.
    var peekDuration: Double = 1.2
    var sinkDuration: Double = 0.45
    var holeCloseDuration: Double = 0.3
}

/// One decoy mole: its hole opens, it comes up, stays up for a moment, goes back down and the hole
/// closes. It does not react to the child's attention.
struct DecoyMole: Equatable {
    enum Phase: Equatable {
        case openingHole, emerging, peeking, sinking, closingHole, gone
    }

    let hole: CGPoint
    let settings: DecoyMoleSettings
    private(set) var phase: Phase = .openingHole
    private(set) var phaseTime: TimeInterval = 0

    init(hole: CGPoint, settings: DecoyMoleSettings) {
        self.hole = hole
        self.settings = settings
    }

    /// 0 inside the hole, 1 all the way up.
    var rise: Double {
        switch phase {
        case .openingHole, .closingHole, .gone: 0
        case .emerging: fraction(of: settings.emergeDuration)
        case .peeking: 1
        case .sinking: 1 - fraction(of: settings.sinkDuration)
        }
    }

    /// 0...1: how open the hole is.
    var holeOpenness: Double {
        switch phase {
        case .openingHole: fraction(of: settings.holeOpenDuration)
        case .emerging, .peeking, .sinking: 1
        case .closingHole: 1 - fraction(of: settings.holeCloseDuration)
        case .gone: 0
        }
    }

    private func fraction(of duration: TimeInterval) -> Double {
        min(phaseTime / max(duration, 0.01), 1)
    }

    mutating func advance(by delta: TimeInterval) {
        guard delta > 0, phase != .gone else { return }
        phaseTime += delta
        let (duration, next): (Double, Phase) = switch phase {
        case .openingHole: (settings.holeOpenDuration, .emerging)
        case .emerging: (settings.emergeDuration, .peeking)
        case .peeking: (settings.peekDuration, .sinking)
        case .sinking: (settings.sinkDuration, .closingHole)
        case .closingHole: (settings.holeCloseDuration, .gone)
        case .gone: (0, .gone)
        }
        if phaseTime >= duration {
            phase = next
            phaseTime = 0
        }
    }
}

/// Sends the decoy moles: one at a time, at random times and random spots on the grass near the
/// followed character, only while the child is following. Driven by the game clock and a seeded
/// generator, so it can be tested and a fixed seed replays it.
struct DecoyMoleSpawner {
    let settings: DecoyMoleSettings
    private(set) var decoy: DecoyMole?
    /// Seconds of following left before the next decoy may pop up.
    private(set) var countdown: TimeInterval
    private var generator: SeededGenerator

    init(seed: UInt64, settings: DecoyMoleSettings = DecoyMoleSettings()) {
        self.settings = settings
        generator = SeededGenerator(seed: seed)
        countdown = 0
        countdown = Double.random(in: settings.firstDelay, using: &generator)
    }

    /// A new walk on a new map: any decoy goes, and the first one waits again.
    mutating func reset() {
        decoy = nil
        countdown = Double.random(in: settings.firstDelay, using: &generator)
    }

    /// - Parameters:
    ///   - canSpawn: `true` while the child follows the walking character and no thief is around.
    ///   - feet: the followed character's feet, in map units.
    ///   - map: the current map, to keep decoys on open grass.
    mutating func advance(by delta: TimeInterval, canSpawn: Bool, feet: CGPoint, map: FoxPathMap) {
        guard delta > 0 else { return }
        if var current = decoy {
            current.advance(by: delta)
            decoy = current.phase == .gone ? nil : current
            return
        }
        guard canSpawn else { return }
        countdown -= delta
        guard countdown <= 0 else { return }
        if let spot = Self.spot(near: feet, on: map, settings: settings, using: &generator) {
            decoy = DecoyMole(hole: spot, settings: settings)
            countdown = Double.random(in: settings.interval, using: &generator)
        } else {
            // No room nearby right now: try again a little later.
            countdown = 0.5
        }
    }

    /// A random spot on open grass near `feet`: off the path, clear of houses and other things that
    /// stand, and on the map. `nil` when no spot was found.
    static func spot(
        near feet: CGPoint,
        on map: FoxPathMap,
        settings: DecoyMoleSettings,
        using generator: inout SeededGenerator
    ) -> CGPoint? {
        let line = FoxPathGenerator.pathLine(for: map.route)
        let moleWidth = MoleThiefVisual.standingSize.width
        for _ in 0..<40 {
            let angle = Double.random(in: 0..<(2 * .pi), using: &generator)
            let distance = CGFloat.random(in: settings.distance, using: &generator)
            let point = CGPoint(x: feet.x + distance * CGFloat(cos(angle)), y: feet.y + distance * CGFloat(sin(angle)))
            // The whole mole (about 95 units tall when up) stays on the map, below the top bar.
            guard point.x >= 60, point.x <= map.size.width - 60,
                  point.y >= 200, point.y <= map.size.height - 24 else { continue }
            guard line.distance(to: point) > FoxPathMetrics.pathHalfWidth + 45 else { continue }
            let body = CGRect(x: point.x - moleWidth * 0.8, y: point.y - 100, width: moleWidth * 1.6, height: 120)
            guard !map.standingSprites.contains(where: { $0.frame.intersects(body) }) else { continue }
            return point
        }
        return nil
    }
}
