import Foundation

enum EngineEvent: Equatable {
    case spawned(ActiveTarget)
    case hit(ActiveTarget, responseTime: TimeInterval)
    case missed(ActiveTarget)
    case decoyTapped(ActiveTarget)
    /// The fox leaves its window towards the tapped character.
    case attackStarted(ActiveTarget)
    /// The hammer connects; the character starts its hit reaction.
    case attackImpact(ActiveTarget)
    /// The fox is back in its window.
    case attackFinished
    case finished
}

/// Game rules with no UI or real-time dependency. Time only moves through `advance(by:)`,
/// which keeps pauses out of every measurement and makes the engine easy to test.
struct WhackAMoleEngine {
    let configuration: GameConfiguration
    private(set) var clock: TimeInterval = 0
    private(set) var targets: [ActiveTarget] = []
    private(set) var session: GameSessionRecord
    private(set) var spawnManager: SpawnManager
    private var nextSpawnAt: TimeInterval
    private var nextTargetID = 0
    /// Attacks in progress. Existing characters remain selectable while another helper animation
    /// is running, but no new character spawns until every attack has finished.
    private(set) var attacks: [FoxAttack] = []
    /// Compatibility accessor for callers interested only in the oldest active attack.
    var attack: FoxAttack? { attacks.first }
    private var lastAttackEndedAt: TimeInterval?
    /// The helper for this whole game: waits in the corner and swings at every tap. The player's
    /// own character when one is given (chosen in onboarding); otherwise picked at random when
    /// the game starts, every helper equally likely.
    let helper: HelperCharacter
    private var holes: [OpenHole] = []
    private var nextHoleID = 0

    /// A hole on the board and where it is in its life: opening, waiting for its mole, closing.
    private struct OpenHole {
        let id: Int
        let request: SpawnRequest
        let openedAt: TimeInterval
        var moleArrived = false
        var closingAt: TimeInterval?
    }

    /// The holes currently on the board, for drawing.
    var holeVisuals: [HoleVisual] {
        let rules = configuration.spawnRules
        return holes.map { hole in
            let opening = min(max((clock - hole.openedAt) / max(rules.holeOpenDuration, 0.001), 0), 1)
            let closing = hole.closingAt.map { min(max((clock - $0) / max(rules.holeCloseDuration, 0.001), 0), 1) } ?? 0
            return HoleVisual(
                id: hole.id,
                holeIndex: hole.request.holeIndex,
                position: hole.request.position,
                artIndex: hole.request.artIndex,
                openness: opening * (1 - closing)
            )
        }
    }

    var settings: DifficultySettings { spawnManager.settings }
    private(set) var isFinished = false
    var remainingTime: TimeInterval { max(GameConfiguration.sessionDuration - clock, 0) }
    var progress: Double { min(clock / GameConfiguration.sessionDuration, 1) }

    /// Phase and progress of the oldest current attack, if any.
    var attackState: (phase: FoxAttackPhase, progress: Double)? {
        attack?.state(at: clock, timing: configuration.foxAttack)
    }

    /// Phase and progress of every current attack.
    var attackStates: [(attack: FoxAttack, phase: FoxAttackPhase, progress: Double)] {
        attacks.compactMap { attack in
            attack.state(at: clock, timing: configuration.foxAttack).map {
                (attack, $0.phase, $0.progress)
            }
        }
    }

    /// How each mole should be drawn at the current moment. Driven by game time, so pausing
    /// freezes the animation.
    func moleVisual(for target: ActiveTarget) -> MoleVisual {
        let rules = configuration.spawnRules
        func clamped(_ value: Double) -> Double { min(max(value, 0), 1) }
        func rise(at time: TimeInterval) -> Double {
            clamped((time - target.spawnedAt) / max(rules.moleRiseDuration, 0.001))
        }
        /// Sinks from `height` back into the hole, starting `delay` after `start`.
        func sink(from start: TimeInterval, height: Double, delay: TimeInterval = 0) -> Double {
            height * (1 - clamped((clock - start - delay) / max(rules.exitAnimationDuration, 0.001)))
        }
        switch target.phase {
        case .up, .targeted:
            return MoleVisual(rise: rise(at: clock))
        case let .leaving(at):
            return MoleVisual(rise: sink(from: at, height: rise(at: at)))
        case let .hit(at):
            guard target.role == .target else { return MoleVisual(rise: sink(from: at, height: rise(at: at))) }
            // The sad mole stays up while it reacts to the hammer, then goes back down.
            let reaction = configuration.foxAttack.hitReaction
            let duration = reaction + rules.exitAnimationDuration
            return MoleVisual(
                rise: sink(from: at, height: 1, delay: reaction),
                hitProgress: clamped((clock - at) / max(duration, 0.001))
            )
        }
    }

    var interactionState: GameInteractionState {
        if let state = attackState {
            switch state.phase {
            case .frameAppearing: return .frameAppearing
            case .foxEmerging: return .foxEmerging
            case .attacking: return .foxAttacking
            case .hitting: return .targetHit
            case .foxRetracting: return .foxRetracting
            case .frameDisappearing: return .frameDisappearing
            }
        }
        let upTargets = targets.filter { $0.phase.isUp }
        if upTargets.contains(where: { clock - $0.spawnedAt < configuration.spawnRules.moleRiseDuration }) { return .targetAppearing }
        if !upTargets.isEmpty { return .targetActive }
        if let lastAttackEndedAt, clock - lastAttackEndedAt < configuration.foxAttack.nextTargetDelay { return .nextTarget }
        return .idle
    }

    init(configuration: GameConfiguration, helper: HelperCharacter? = nil, startedAt: Date = Date()) {
        self.configuration = configuration
        let seed = configuration.randomSeed ?? UInt64.random(in: .min ... .max)
        var recordedConfiguration = configuration
        recordedConfiguration.randomSeed = seed
        self.session = GameSessionRecord(configuration: recordedConfiguration, startedAt: startedAt)
        self.spawnManager = SpawnManager(settings: configuration.board, rules: configuration.spawnRules, seed: seed)
        self.nextSpawnAt = configuration.spawnRules.leadInDelay
        // Its own generator, so the pick never changes where or when moles appear.
        var helperGenerator = SeededGenerator(seed: seed ^ 0x5EED_4E1F_E12C_0FF5)
        self.helper = helper ?? HelperCharacter.random(using: &helperGenerator)
    }

    @discardableResult
    mutating func advance(by delta: TimeInterval, now: Date = Date()) -> [EngineEvent] {
        guard !isFinished, delta > 0 else { return [] }
        clock += delta
        session.activePlayDuration = clock
        var events: [EngineEvent] = []

        advanceAttacks(by: delta, into: &events)
        expireTargets(into: &events)
        removeFinishedAnimations()
        advanceHoles(into: &events)

        if clock >= GameConfiguration.sessionDuration {
            finish(reason: .timeUp, now: now)
            events.append(.finished)
            return events
        }

        if attacks.isEmpty, clock >= nextSpawnAt {
            if openHole() {
                nextSpawnAt = clock + spawnManager.nextInterval()
            } else {
                nextSpawnAt = clock + configuration.spawnRules.busyRetryDelay
            }
        }
        return events
    }

    /// Tap on the empty board, away from any hole. Counted but never penalised.
    mutating func tapBoard() {
        guard !isFinished, attack == nil else { return }
        session.offTargetTaps += 1
    }

    /// Tap on a hole.
    ///
    /// - An awake character starts the fox's attack on that character. The hit, its response
    ///   time and its points are recorded at the tap; the character reacts and the points are
    ///   shown when the hammer lands.
    /// - A sleeping mole (decoy) reacts by itself; the fox does not attack it.
    /// - Taps on empty holes are counted but never penalised.
    /// - A character can be selected while another attack is running. Repeated input on the same
    ///   character is still ignored because its phase changes immediately to `targeted`.
    @discardableResult
    mutating func tapHole(
        _ holeIndex: Int,
        awardedPoints: Int = GameSessionRecord.defaultPointsPerHit
    ) -> [EngineEvent] {
        guard !isFinished else { return [] }
        guard let index = targets.firstIndex(where: { $0.holeIndex == holeIndex && $0.phase.isUp }) else {
            // Preserve the old behavior of ignoring empty-board input during an animation.
            if attacks.isEmpty { session.offTargetTaps += 1 }
            return []
        }
        let target = targets[index]

        switch target.role {
        case .target:
            targets[index].phase = .targeted
            targets[index].pointsAwarded = awardedPoints
            let artIndex = holes.first { $0.request.holeIndex == target.holeIndex }?.request.artIndex ?? 0
            attacks.append(FoxAttack(targetID: target.id, holeIndex: target.holeIndex, artIndex: artIndex, startedAt: clock, helper: helper))
            let responseTime = clock - target.spawnedAt
            record(target, outcome: .hit(responseTime: responseTime), pointsAwarded: awardedPoints)
            return [.hit(targets[index], responseTime: responseTime), .attackStarted(targets[index])]
        case .decoy:
            targets[index].phase = .hit(at: clock)
            record(target, outcome: .decoyTapped)
            return [.decoyTapped(targets[index])]
        }
    }

    /// Ends the session early (exit or rest break). Characters still up are not counted.
    mutating func end(reason: SessionEndReason = .stopped, now: Date = Date()) {
        guard !isFinished else { return }
        finish(reason: reason, now: now)
    }

    // MARK: - Private

    private mutating func advanceAttacks(by delta: TimeInterval, into events: inout [EngineEvent]) {
        guard !attacks.isEmpty else { return }
        let timing = configuration.foxAttack

        // Characters the child is not attacking wait while the animation plays.
        for index in targets.indices where targets[index].phase.isUp {
            targets[index].expiresAt += delta
        }

        for attack in attacks {
            let impactAt = attack.startedAt + timing.impactOffset
            if clock >= impactAt, let index = targets.firstIndex(where: { $0.id == attack.targetID && $0.phase == .targeted }) {
                targets[index].phase = .hit(at: impactAt)
                events.append(.attackImpact(targets[index]))
            }
        }

        let finishedCount = attacks.count { clock >= $0.startedAt + timing.total }
        if finishedCount > 0 {
            attacks.removeAll { clock >= $0.startedAt + timing.total }
            lastAttackEndedAt = clock
            nextSpawnAt = max(nextSpawnAt, clock + timing.nextTargetDelay)
            events.append(contentsOf: repeatElement(.attackFinished, count: finishedCount))
        }
    }

    /// Opens a new hole at a random spot, if the board allows another mole. Its mole follows once
    /// the hole is open.
    private mutating func openHole() -> Bool {
        let molesOnTheWay = holes.filter { !$0.moleArrived }.count
        let upCount = targets.filter { $0.phase.isUp }.count + molesOnTheWay
        guard upCount < settings.maxSimultaneousTargets else { return false }
        let busy = Set(holes.map(\.request.holeIndex))
        guard let request = spawnManager.makeSpawn(occupiedHoles: busy, openPositions: holes.map(\.request.position)) else { return false }
        nextHoleID += 1
        holes.append(OpenHole(id: nextHoleID, request: request, openedAt: clock))
        return true
    }

    /// Brings moles out of holes that have finished opening, and closes holes whose mole has gone.
    private mutating func advanceHoles(into events: inout [EngineEvent]) {
        let rules = configuration.spawnRules
        for index in holes.indices {
            let zone = holes[index].request.holeIndex
            if !holes[index].moleArrived {
                // New moles wait while the fox is attacking.
                if attacks.isEmpty, clock >= holes[index].openedAt + rules.holeOpenDuration {
                    holes[index].moleArrived = true
                    events.append(.spawned(addTarget(from: holes[index].request)))
                }
            } else if holes[index].closingAt == nil, !targets.contains(where: { $0.holeIndex == zone }) {
                holes[index].closingAt = clock
            }
        }
        holes.removeAll { hole in
            hole.closingAt.map { clock - $0 >= rules.holeCloseDuration } ?? false
        }
    }

    private mutating func addTarget(from request: SpawnRequest) -> ActiveTarget {
        nextTargetID += 1
        let target = ActiveTarget(
            id: nextTargetID,
            holeIndex: request.holeIndex,
            variant: request.variant,
            role: request.role,
            spawnedAt: clock,
            visibleDuration: request.visibleDuration
        )
        targets.append(target)
        session.trials.append(TrialRecord(
            id: target.id,
            holeIndex: target.holeIndex,
            variant: target.variant,
            role: target.role,
            spawnedAt: clock,
            position: request.position
        ))
        return target
    }

    private mutating func expireTargets(into events: inout [EngineEvent]) {
        for index in targets.indices where targets[index].phase.isUp && clock >= targets[index].expiresAt {
            targets[index].phase = .leaving(at: clock)
            let target = targets[index]
            switch target.role {
            case .target:
                record(target, outcome: .missed)
                events.append(.missed(target))
            case .decoy:
                record(target, outcome: .decoyIgnored)
            }
        }
    }

    private mutating func removeFinishedAnimations() {
        let linger = configuration.spawnRules.exitAnimationDuration
        let hitReaction = configuration.foxAttack.hitReaction
        targets.removeAll { target in
            switch target.phase {
            case .up, .targeted:
                false
            case let .hit(at):
                // A struck mole plays its hit animation, which ends with it back down the hole.
                clock - at >= (target.role == .target ? hitReaction + linger : linger)
            case let .leaving(at):
                clock - at >= linger
            }
        }
    }

    private mutating func record(
        _ target: ActiveTarget,
        outcome: TrialOutcome,
        pointsAwarded: Int? = nil
    ) {
        guard let index = session.trials.lastIndex(where: { $0.id == target.id }) else { return }
        session.trials[index].outcome = outcome
        session.trials[index].pointsAwarded = pointsAwarded
    }

    private mutating func finish(reason: SessionEndReason, now: Date) {
        targets.removeAll()
        holes.removeAll()
        attacks.removeAll()
        session.completed = reason == .timeUp
        session.endReason = reason
        session.endedAt = now
        isFinished = true
    }
}
