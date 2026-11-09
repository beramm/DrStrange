import Foundation
import Observation
import QuartzCore

/// Drives `WhackAMoleEngine` in real time and exposes only what the views need.
@MainActor
@Observable
final class WhackAMoleGameViewModel {
    enum Phase: Equatable {
        case countdown(Int)
        case playing
        case paused
        case finished
    }

    static let pointsPerHit = 10
    private static let countdownSeconds = 3.0
    /// Upper bound on one frame step, so a hitch (or the app returning from background) cannot
    /// skip a whole character.
    private static let maxFrameStep = 0.1

    let configuration: GameConfiguration

    private(set) var phase: Phase = .countdown(3)
    private(set) var targets: [ActiveTarget] = []
    private(set) var score = 0
    private(set) var level: DifficultyLevel
    private(set) var settings: DifficultySettings
    private(set) var remainingSeconds: Int
    private(set) var progress: Double = 0
    /// The fox's attack in progress; `nil` while it waits in its window.
    /// Updated every frame during an attack, from game time, so pausing freezes the fox exactly.
    private(set) var foxPose: FoxPose?
    private(set) var interactionState: GameInteractionState = .idle
    /// The holes on the board right now. There are none until a mole is about to appear.
    private(set) var holes: [HoleVisual] = []
    /// How each visible mole should be drawn, by hole. Updated from game time.
    private(set) var moleVisuals: [Int: MoleVisual] = [:]

    var foxAnimationState: FoxAnimationState { FoxAnimationState(foxPose) }
    /// Set briefly after an adaptive level change.
    private(set) var levelBanner: DifficultyLevel?
    private(set) var finishedSession: GameSessionRecord?

    var soundEnabled: Bool {
        didSet { feedback.soundEnabled = soundEnabled }
    }

    @ObservationIgnored private var engine: WhackAMoleEngine
    @ObservationIgnored private var loopTask: Task<Void, Never>?
    @ObservationIgnored private var lastTick: CFTimeInterval?
    @ObservationIgnored private var countdownRemaining = WhackAMoleGameViewModel.countdownSeconds
    @ObservationIgnored private var phaseBeforePause: Phase = .playing
    @ObservationIgnored private var bannerTask: Task<Void, Never>?
    @ObservationIgnored private let feedback: FeedbackPlayer
    @ObservationIgnored private let sessionStore: SessionStore

    #if DEBUG
    /// QA hooks for checking animations on the simulator:
    /// `-WhackAMoleAutoplay YES` taps each awake character 0.6 s after it appears, and
    /// `-WhackAMoleTimeScale 0.25` runs game time at a quarter speed.
    @ObservationIgnored private let autoplay = UserDefaults.standard.bool(forKey: "WhackAMoleAutoplay")
    @ObservationIgnored private let timeScale: Double = {
        let value = UserDefaults.standard.double(forKey: "WhackAMoleTimeScale")
        return value > 0 ? value : 1
    }()
    #endif

    init(configuration: GameConfiguration, sessionStore: SessionStore = .standard) {
        self.configuration = configuration
        self.engine = WhackAMoleEngine(configuration: configuration)
        self.level = configuration.startingLevel
        self.settings = configuration.settings(for: configuration.startingLevel)
        self.remainingSeconds = Int(configuration.sessionDuration.rounded(.up))
        self.soundEnabled = configuration.soundEnabled
        self.feedback = FeedbackPlayer(soundEnabled: configuration.soundEnabled, hapticsEnabled: configuration.hapticsEnabled)
        self.sessionStore = sessionStore
    }

    func target(inHole hole: Int) -> ActiveTarget? {
        targets.first { $0.holeIndex == hole }
    }

    // MARK: - Lifecycle

    func start() {
        guard loopTask == nil, phase != .finished else { return }
        lastTick = CACurrentMediaTime()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.phase != .finished else { return }
                self.tick()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        bannerTask?.cancel()
    }

    func pause() {
        guard phase != .paused, phase != .finished else { return }
        phaseBeforePause = phase
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        lastTick = CACurrentMediaTime()
        phase = phaseBeforePause
    }

    /// Stops the session before time is up (exit button, or a rest break when the child has
    /// discomfort, a headache or tired eyes) and shows the summary. The session is saved with
    /// its reason so caregivers can see it later.
    func finishEarly(reason: SessionEndReason) {
        guard phase != .finished else { return }
        engine.end(reason: reason)
        // A hit tapped just before stopping counts even if the hammer had not landed yet.
        score = engine.session.hits * Self.pointsPerHit
        foxPose = nil
        moleVisuals = [:]
        holes = []
        phase = .finished
        finishedSession = engine.session
        save(engine.session)
        stop()
    }

    // MARK: - Input

    func tapHole(_ hole: Int) {
        guard phase == .playing else { return }
        // Bring the engine clock up to the moment of the tap for an accurate response time.
        tick()
        apply(engine.tapHole(hole))
    }

    /// A tap on the empty board.
    func tapBoard() {
        guard phase == .playing else { return }
        engine.tapBoard()
    }

    // MARK: - Loop

    private func tick() {
        let now = CACurrentMediaTime()
        let delta = min(now - (lastTick ?? now), Self.maxFrameStep)
        lastTick = now

        switch phase {
        case .countdown:
            countdownRemaining -= delta
            let shown = Int(countdownRemaining.rounded(.up))
            if shown <= 0 {
                phase = .playing
            } else if phase != .countdown(shown) {
                phase = .countdown(shown)
            }
        case .playing:
            #if DEBUG
            apply(engine.advance(by: delta * timeScale))
            #else
            apply(engine.advance(by: delta))
            #endif
            #if DEBUG
            if autoplay, engine.attack == nil, phase == .playing,
               let target = engine.targets.first(where: { $0.phase.isUp && $0.role == .target && engine.clock - $0.spawnedAt > 0.6 }) {
                apply(engine.tapHole(target.holeIndex))
            }
            #endif
        case .paused, .finished:
            break
        }
    }

    private func apply(_ events: [EngineEvent]) {
        for event in events {
            switch event {
            case .spawned, .missed, .hit, .attackStarted, .attackFinished:
                break
            case .attackImpact:
                // Points and sound arrive when the hammer lands, not at the tap.
                score += Self.pointsPerHit
                feedback.hit()
            case .decoyTapped:
                feedback.decoyTapped()
            case let .levelChanged(_, to):
                settings = engine.settings
                level = to
                feedback.levelChanged()
                showBanner(for: to)
            case .finished:
                score = engine.session.hits * Self.pointsPerHit
                phase = .finished
                finishedSession = engine.session
                save(engine.session)
                feedback.sessionFinished()
                stop()
            }
        }
        syncFromEngine()
    }

    private func syncFromEngine() {
        if targets != engine.targets { targets = engine.targets }
        let visuals = Dictionary(uniqueKeysWithValues: engine.targets.map { ($0.holeIndex, engine.moleVisual(for: $0)) })
        if visuals != moleVisuals { moleVisuals = visuals }
        let holeVisuals = engine.holeVisuals
        if holeVisuals != holes { holes = holeVisuals }
        let seconds = Int(engine.remainingTime.rounded(.up))
        if seconds != remainingSeconds { remainingSeconds = seconds }
        let roundedProgress = (engine.progress * 200).rounded() / 200
        if roundedProgress != progress { progress = roundedProgress }

        let pose = engine.attack.flatMap { attack in
            engine.attackState.map { FoxPose(phase: $0.phase, progress: $0.progress, holeIndex: attack.holeIndex, artIndex: attack.artIndex) }
        }
        if pose != foxPose { foxPose = pose }
        let state = engine.interactionState
        if state != interactionState { interactionState = state }
    }

    private func showBanner(for level: DifficultyLevel) {
        levelBanner = level
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.levelBanner = nil
        }
    }

    private func save(_ record: GameSessionRecord) {
        do {
            try sessionStore.save(record)
        } catch {
            print("WhackAMole: could not save session \(record.id): \(error)")
        }
    }
}
