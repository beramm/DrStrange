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
    let renderer: any EyeChannelRenderer

    private(set) var phase: Phase = .countdown(3)
    private(set) var targets: [ActiveTarget] = []
    private(set) var score = 0
    private(set) var level: DifficultyLevel
    private(set) var settings: DifficultySettings
    private(set) var remainingSeconds: Int
    private(set) var progress: Double = 0
    /// Increments on every hit; the fox swings its hammer each time it changes.
    private(set) var hammerSwings = 0
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

    init(configuration: GameConfiguration, sessionStore: SessionStore = .standard) {
        self.configuration = configuration
        self.renderer = EyeChannelRendererFactory.make(for: configuration.therapy)
        self.engine = WhackAMoleEngine(configuration: configuration)
        self.level = configuration.startingLevel
        self.settings = configuration.settings(for: configuration.startingLevel)
        self.remainingSeconds = Int(configuration.sessionDuration.rounded(.up))
        self.soundEnabled = configuration.soundEnabled
        self.feedback = FeedbackPlayer(soundEnabled: configuration.soundEnabled, hapticsEnabled: configuration.hapticsEnabled)
        self.sessionStore = sessionStore
    }

    var activeHoles: Set<Int> { Set(settings.activeHoleIndices) }

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

    /// Ends the session from the exit button. Partial sessions are saved as not completed.
    func exit() {
        guard phase != .finished else { return }
        engine.end()
        if !engine.session.trials.isEmpty { save(engine.session) }
        stop()
    }

    // MARK: - Input

    func tapHole(_ hole: Int) {
        guard phase == .playing else { return }
        // Bring the engine clock up to the moment of the tap for an accurate response time.
        tick()
        apply(engine.tapHole(hole))
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
            apply(engine.advance(by: delta))
        case .paused, .finished:
            break
        }
    }

    private func apply(_ events: [EngineEvent]) {
        for event in events {
            switch event {
            case .spawned, .missed:
                break
            case .hit:
                score += Self.pointsPerHit
                hammerSwings += 1
                feedback.hit()
            case .decoyTapped:
                feedback.decoyTapped()
            case let .levelChanged(_, to):
                settings = engine.settings
                level = to
                feedback.levelChanged()
                showBanner(for: to)
            case .finished:
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
        let seconds = Int(engine.remainingTime.rounded(.up))
        if seconds != remainingSeconds { remainingSeconds = seconds }
        let roundedProgress = (engine.progress * 200).rounded() / 200
        if roundedProgress != progress { progress = roundedProgress }
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
