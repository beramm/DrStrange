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
    case levelChanged(from: DifficultyLevel, to: DifficultyLevel)
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
    private var progression: DifficultyProgression
    private var nextSpawnAt: TimeInterval
    private var nextTargetID = 0
    /// The attack in progress. While set, no new character spawns and further taps are ignored.
    private(set) var attack: FoxAttack?
    private var lastAttackEndedAt: TimeInterval?

    var level: DifficultyLevel { progression.level }
    var settings: DifficultySettings { spawnManager.settings }
    private(set) var isFinished = false
    var remainingTime: TimeInterval { max(configuration.sessionDuration - clock, 0) }
    var progress: Double { min(clock / max(configuration.sessionDuration, 1), 1) }

    /// Phase and progress of the current attack, if any.
    var attackState: (phase: FoxAttackPhase, progress: Double)? {
        attack?.state(at: clock, timing: configuration.foxAttack)
    }

    /// Seconds a newly spawned character spends rising out of its hole (matches the UI spring).
    static let appearDuration: TimeInterval = 0.38

    var interactionState: GameInteractionState {
        if let state = attackState {
            switch state.phase {
            case .emerging: return .foxEmerging
            case .attacking: return .foxAttacking
            case .hitting: return .targetHit
            case .returning: return .foxReturning
            }
        }
        let upTargets = targets.filter { $0.phase.isUp }
        if upTargets.contains(where: { clock - $0.spawnedAt < Self.appearDuration }) { return .targetAppearing }
        if !upTargets.isEmpty { return .targetActive }
        if let lastAttackEndedAt, clock - lastAttackEndedAt < configuration.foxAttack.nextTargetDelay { return .nextTarget }
        return .idle
    }

    init(configuration: GameConfiguration, startedAt: Date = Date()) {
        self.configuration = configuration
        let seed = configuration.randomSeed ?? UInt64.random(in: .min ... .max)
        var recordedConfiguration = configuration
        recordedConfiguration.randomSeed = seed
        self.session = GameSessionRecord(configuration: recordedConfiguration, startedAt: startedAt)
        self.spawnManager = SpawnManager(
            settings: configuration.settings(for: configuration.startingLevel),
            rules: configuration.spawnRules,
            seed: seed
        )
        self.progression = DifficultyProgression(rules: configuration.adaptiveDifficulty, startingLevel: configuration.startingLevel)
        self.nextSpawnAt = configuration.spawnRules.leadInDelay
    }

    @discardableResult
    mutating func advance(by delta: TimeInterval, now: Date = Date()) -> [EngineEvent] {
        guard !isFinished, delta > 0 else { return [] }
        clock += delta
        session.activePlayDuration = clock
        var events: [EngineEvent] = []

        advanceAttack(by: delta, into: &events)
        expireTargets(into: &events)
        removeFinishedAnimations()

        if clock >= configuration.sessionDuration {
            finish(reason: .timeUp, now: now)
            events.append(.finished)
            return events
        }

        if attack == nil, clock >= nextSpawnAt {
            if let target = spawn() {
                events.append(.spawned(target))
                nextSpawnAt = clock + spawnManager.nextInterval()
            } else {
                nextSpawnAt = clock + configuration.spawnRules.busyRetryDelay
            }
        }
        return events
    }

    /// Tap on a hole.
    ///
    /// - An awake character starts the fox's attack on that character. The hit (and response
    ///   time) is recorded at the tap; the character reacts when the hammer lands.
    /// - A sleepy decoy reacts by itself; the fox does not attack it.
    /// - Taps on empty holes are counted but never penalised.
    /// - While an attack is running, every tap is ignored, so rapid or repeated taps can never
    ///   start a second attack.
    @discardableResult
    mutating func tapHole(_ holeIndex: Int) -> [EngineEvent] {
        guard !isFinished, attack == nil else { return [] }
        guard let index = targets.firstIndex(where: { $0.holeIndex == holeIndex && $0.phase.isUp }) else {
            session.offTargetTaps += 1
            return []
        }
        let target = targets[index]

        switch target.role {
        case .target:
            targets[index].phase = .targeted
            attack = FoxAttack(targetID: target.id, holeIndex: target.holeIndex, startedAt: clock)
            let responseTime = clock - target.spawnedAt
            record(target, outcome: .hit(responseTime: responseTime))
            var events: [EngineEvent] = [.hit(target, responseTime: responseTime), .attackStarted(targets[index])]
            if let change = recordProgression(hit: true) { events.append(change) }
            return events
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

    private mutating func advanceAttack(by delta: TimeInterval, into events: inout [EngineEvent]) {
        guard let attack else { return }
        let timing = configuration.foxAttack

        // Characters the child is not attacking wait while the animation plays.
        for index in targets.indices where targets[index].phase.isUp {
            targets[index].expiresAt += delta
        }

        let impactAt = attack.startedAt + timing.impactOffset
        if clock >= impactAt, let index = targets.firstIndex(where: { $0.id == attack.targetID && $0.phase == .targeted }) {
            targets[index].phase = .hit(at: impactAt)
            events.append(.attackImpact(targets[index]))
        }

        if clock >= attack.startedAt + timing.total {
            self.attack = nil
            lastAttackEndedAt = clock
            nextSpawnAt = max(nextSpawnAt, clock + timing.nextTargetDelay)
            events.append(.attackFinished)
        }
    }

    private mutating func spawn() -> ActiveTarget? {
        let busy = Set(targets.map(\.holeIndex))
        let upCount = targets.filter { $0.phase.isUp }.count
        guard upCount < settings.maxSimultaneousTargets,
              let request = spawnManager.makeSpawn(occupiedHoles: busy) else { return nil }

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
            level: level,
            spawnedAt: clock
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
                if let change = recordProgression(hit: false) { events.append(change) }
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
                // A struck character sinks when its reaction ends, as the fox heads home.
                clock - at >= (target.role == .target ? hitReaction : linger)
            case let .leaving(at):
                clock - at >= linger
            }
        }
    }

    private mutating func record(_ target: ActiveTarget, outcome: TrialOutcome) {
        guard let index = session.trials.lastIndex(where: { $0.id == target.id }) else { return }
        session.trials[index].outcome = outcome
    }

    private mutating func recordProgression(hit: Bool) -> EngineEvent? {
        let previous = progression.level
        guard let newLevel = progression.record(hit: hit) else { return nil }
        spawnManager.update(settings: configuration.settings(for: newLevel))
        session.levelChanges.append(LevelChange(at: clock, from: previous, to: newLevel))
        session.finalLevel = newLevel
        return .levelChanged(from: previous, to: newLevel)
    }

    private mutating func finish(reason: SessionEndReason, now: Date) {
        targets.removeAll()
        attack = nil
        session.completed = reason == .timeUp
        session.endReason = reason
        session.endedAt = now
        session.finalLevel = level
        isFinished = true
    }
}
