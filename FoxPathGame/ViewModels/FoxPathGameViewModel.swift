import Foundation
import Observation
import QuartzCore

/// Drives one game in real time: reads the pointer, moves the followed character and the thief,
/// runs the 2-minute clock and the camera, and exposes only what the views need. Pointer
/// positions live in memory for the current frame only; nothing about where the player looked
/// is stored.
@MainActor
@Observable
final class FoxPathGameViewModel {
    enum Phase: Equatable {
        case playing
        case paused
        case finished
    }

    /// Upper bound on one frame step, so a hitch cannot make a character jump.
    private static let maxFrameStep = 0.1
    /// Seconds the character stands at the stall before the next path appears.
    private static let walkPause = 1.4
    /// Seconds the last moment stays on screen before the result shows.
    private static let endPause = 1.2
    /// Time constant that takes the jitter out of pointer readings without adding visible lag.
    private static let pointerSmoothing = 0.08

    let configuration: FoxPathConfiguration
    let settings: FoxPathSettings
    /// Seconds without a new reading before the pointer counts as lost. `nil` for a finger,
    /// which sends nothing while it rests.
    let pointerTimeout: TimeInterval?

    private(set) var phase: Phase = .playing
    private(set) var map: FoxPathMap
    private(set) var roles: CharacterRoles
    /// The character the child follows.
    private(set) var foxPose: FoxWalkPose
    /// The thief, while one is on the map.
    private(set) var thiefPose: FoxWalkPose?
    private(set) var thiefState: ThiefState = .inactive
    /// 0...1 while the thief fades in or out.
    private(set) var thiefVisibility: Double = 0
    private(set) var trackingState: FoxTrackingState = .waiting
    private(set) var attention: PlayerAttentionState = .following
    private(set) var refocusProgress: Double = 0
    private(set) var needsPointer = false
    private(set) var lives: Int
    private(set) var remainingSeconds: Int
    /// Which path this is (1 for the first); the views use it to restart the intro for each one.
    private(set) var walkNumber = 1
    private(set) var camera: FoxPathCamera
    /// Smoothed pointer position on screen, for the optional marker.
    private(set) var pointer: CGPoint?
    /// Set when the game is over, to show the result screen.
    private(set) var result: FoxPathResult?

    /// Size of the full-screen game view, reported by the view.
    var viewportSize: CGSize = .zero

    @ObservationIgnored private var session: FoxPathSession
    @ObservationIgnored private var engine: FoxPathEngine
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private let linkTarget = DisplayLinkTarget()
    @ObservationIgnored private var lastTick: CFTimeInterval?
    @ObservationIgnored private var lastPointerTime: CFTimeInterval?
    @ObservationIgnored private var pointerIsDown = false
    @ObservationIgnored private var tangent = CGVector(dx: 1, dy: 0)
    @ObservationIgnored private var nextWalkCountdown: TimeInterval?
    @ObservationIgnored private var endCountdown: TimeInterval?
    @ObservationIgnored private var thiefDistance: CGFloat = 0
    @ObservationIgnored private let feedback: FoxPathFeedback

    #if DEBUG
    /// QA hook for simulator recordings: `-FoxPathSimulatedGaze YES` moves a pretend pointer
    /// that follows the character and looks away a few times, some of them long enough for a
    /// thief to reach the character. It is a recording aid, not gaze tracking.
    @ObservationIgnored private let usesScriptedPointer = UserDefaults.standard.bool(forKey: "FoxPathSimulatedGaze")
    @ObservationIgnored private var scriptClock: TimeInterval = 0
    #endif

    /// - Parameter player: the player's character, always the one followed. Nil draws it at random.
    init(configuration: FoxPathConfiguration, player: PathCharacter? = nil, pointerTimeout: TimeInterval? = nil) {
        let seed = configuration.randomSeed ?? UInt64.random(in: .min ... .max)
        var session = FoxPathSession(seed: seed, player: player, thiefSettings: configuration.thief)
        let settings = configuration.settings
        let walk = Self.makeWalk(session: &session, settings: settings)
        self.configuration = configuration
        self.settings = settings
        self.pointerTimeout = pointerTimeout
        self.session = session
        map = walk.map
        engine = walk.engine
        roles = session.roles
        foxPose = .standing(session.roles.primary, at: walk.map.route.sample(at: 0).point)
        lives = session.lives
        remainingSeconds = Int(session.duration.rounded(.up))
        camera = FoxPathCamera(mapSize: walk.map.size)
        feedback = FoxPathFeedback(soundEnabled: configuration.soundEnabled, hapticsEnabled: configuration.hapticsEnabled)
    }

    /// A new random map and its walk; the session draws the roles for it.
    private static func makeWalk(session: inout FoxPathSession, settings: FoxPathSettings) -> (map: FoxPathMap, engine: FoxPathEngine) {
        let seed = session.nextMapSeed()
        let map = FoxPathGenerator.makeMap(seed: seed, settings: settings)
        session.prepareWalk()
        return (map, FoxPathEngine(settings: settings, routeLength: Double(map.route.length)))
    }

    // MARK: - Geometry

    /// Screen points per map unit.
    var scale: CGFloat { camera.scale(in: viewportSize) }

    /// Middle of the followed character on screen.
    var foxScreenPoint: CGPoint { camera.screenPoint(for: foxPose.bodyCenter, in: viewportSize) }

    /// Height of the followed character on screen.
    var foxScreenHeight: CGFloat { foxPose.height * scale }

    /// How close to the middle of the character the pointer must be. Never smaller than the
    /// character itself.
    var followRadius: CGFloat {
        max(CGFloat(settings.followRadius), foxScreenHeight * 0.6)
    }

    // MARK: - Lifecycle

    func start() {
        guard displayLink == nil, result == nil else { return }
        lastTick = nil
        linkTarget.onFrame = { [weak self] in self?.tick() }
        let link = CADisplayLink(target: linkTarget, selector: #selector(DisplayLinkTarget.step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    func pause() {
        guard phase == .playing else { return }
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        lastTick = nil
        phase = .playing
    }

    /// Ends the game early (exit button, or a rest break when the child has discomfort, a
    /// headache or tired eyes) and shows the summary.
    func finishEarly() {
        guard result == nil else { return }
        session.stop()
        finish()
    }

    // MARK: - Zoom

    func zoomIn() { camera.zoomIn() }
    func zoomOut() { camera.zoomOut() }
    func setZoom(_ zoom: CGFloat) { camera.setTargetZoom(zoom) }

    // MARK: - Pointer

    /// A new gaze or finger position, in the coordinates of the full-screen game view.
    func pointerMoved(to point: CGPoint, alreadySmoothed: Bool = false) {
        let now = CACurrentMediaTime()
        if !alreadySmoothed, let previous = pointer, pointerIsDown, let last = lastPointerTime {
            let blend = 1 - exp(-(now - last) / Self.pointerSmoothing)
            pointer = CGPoint(
                x: previous.x + (point.x - previous.x) * blend,
                y: previous.y + (point.y - previous.y) * blend
            )
        } else {
            pointer = point
        }
        pointerIsDown = true
        lastPointerTime = now
    }

    /// The finger left the screen, or the tracker has no usable gaze right now.
    func pointerLost() {
        pointerIsDown = false
        pointer = nil
    }

    private func currentReading(at now: CFTimeInterval) -> FoxPointerReading {
        if let pointerTimeout, let lastPointerTime, now - lastPointerTime > pointerTimeout {
            pointerLost()
        }
        guard pointerIsDown, let pointer else {
            // A lifted finger is a clear "not following"; a lost gaze reading is nobody's fault.
            return pointerTimeout == nil ? .away : .unavailable
        }
        let fox = foxScreenPoint
        return hypot(pointer.x - fox.x, pointer.y - fox.y) <= followRadius ? .onFox : .away
    }

    /// What the thief reacts to. Only the walk's own off-track state, which already waited for
    /// the look-away grace, counts as not following; a missing reading never does.
    private func attention(for reading: FoxPointerReading) -> PlayerAttentionState {
        if reading == .unavailable { return .trackingUnavailable }
        return engine.state == .offTrack ? .notFollowing : .following
    }

    // MARK: - Loop

    private func tick() {
        let now = CACurrentMediaTime()
        let delta = min(now - (lastTick ?? now), Self.maxFrameStep)
        lastTick = now
        guard phase == .playing, delta > 0, viewportSize != .zero else { return }

        if var countdown = endCountdown {
            // The game is over: everything holds still until the result shows.
            countdown -= delta
            endCountdown = countdown
            if countdown <= 0 { finish() }
        } else {
            #if DEBUG
            if usesScriptedPointer { moveScriptedPointer(by: delta) }
            #endif
            let reading = currentReading(at: now)
            if var countdown = nextWalkCountdown {
                countdown -= delta
                nextWalkCountdown = countdown
                applySession(session.advance(by: delta, attention: .following, walk: nil))
                // A thief still running off finishes before the next path appears.
                if countdown <= 0, session.thief == nil, endCountdown == nil { startNextWalk() }
            } else {
                applyWalk(engine.advance(by: delta, reading: reading))
                let current = attention(for: reading)
                if current != attention { attention = current }
                let walk = engine.state == .finished ? nil : WalkProgress(
                    distanceLeft: engine.distanceLeft,
                    feet: map.route.sample(at: CGFloat(engine.distance)).point
                )
                applySession(session.advance(by: delta, attention: current, walk: walk))
            }
            syncFromEngine()
            syncThief()
        }

        var nextCamera = camera
        nextCamera.update(
            delta: delta,
            focus: foxPose.bodyCenter,
            tangent: tangent,
            foxSpeed: CGFloat(settings.foxSpeed),
            viewport: viewportSize
        )
        if nextCamera != camera { camera = nextCamera }
    }

    private func applyWalk(_ events: [FoxPathEvent]) {
        for event in events {
            switch event {
            case .started:
                session.walkStarted()
            case .wentOffTrack:
                session.recordOffTrack()
                feedback.wentOffTrack()
            case .refocused:
                feedback.refocused()
            case .finished:
                session.walkFinished()
                feedback.finished()
                nextWalkCountdown = Self.walkPause
            }
        }
    }

    private func applySession(_ events: [FoxPathSessionEvent]) {
        for event in events {
            switch event {
            case .thiefAppeared:
                feedback.thiefAppeared()
            case .thiefLeft:
                break
            case let .lifeLost(remaining):
                lives = remaining
                feedback.lifeLost()
            case .timeUp, .gameOver:
                feedback.gameEnded()
                endCountdown = Self.endPause
            }
        }
        let seconds = Int(session.remainingTime.rounded(.up))
        if seconds != remainingSeconds { remainingSeconds = seconds }
    }

    /// A new random path; the roles may change, so the walk starts with an introduction.
    private func startNextWalk() {
        nextWalkCountdown = nil
        let walk = Self.makeWalk(session: &session, settings: settings)
        map = walk.map
        engine = walk.engine
        roles = session.roles
        foxPose = .standing(roles.primary, at: walk.map.route.sample(at: 0).point)
        tangent = CGVector(dx: 1, dy: 0)
        walkNumber += 1
    }

    private func syncFromEngine() {
        let sample = map.route.sample(at: CGFloat(engine.distance))
        tangent = sample.tangent

        var pose = foxPose
        pose.character = roles.primary
        pose.feet = sample.point
        switch engine.state {
        case .following:
            // While it holds still for a lost reading the character keeps its last walking picture.
            pose.facing = FoxFacing.walking(along: sample.tangent)
            pose.assetName = FoxWalkAnimation.assetName(for: roles.primary, facing: pose.facing, distance: CGFloat(engine.distance))
        case .waiting, .offTrack, .finished:
            pose.facing = .front
            pose.assetName = roles.primary.standingAsset
        }
        if pose != foxPose { foxPose = pose }

        if engine.state != trackingState { trackingState = engine.state }
        let dwell = (engine.refocusProgress * 50).rounded() / 50
        if dwell != refocusProgress { refocusProgress = dwell }
        if engine.needsPointer != needsPointer { needsPointer = engine.needsPointer }
    }

    private func syncThief() {
        guard let thief = session.thief else {
            if thiefPose != nil { thiefPose = nil }
            if thiefState != .inactive { thiefState = .inactive }
            if thiefVisibility != 0 { thiefVisibility = 0 }
            thiefDistance = 0
            return
        }
        let position = thief.position(around: foxPose.feet)
        var pose = thiefPose ?? FoxWalkPose.standing(thief.character, at: position)
        let step = CGVector(dx: position.x - pose.feet.x, dy: position.y - pose.feet.y)
        let moved = hypot(step.dx, step.dy)
        pose.character = thief.character
        if moved > 0.01 {
            thiefDistance += moved
            pose.facing = FoxFacing.walking(along: step)
            pose.isMirrored = pose.facing == .side && step.dx < 0
            pose.assetName = FoxWalkAnimation.assetName(for: thief.character, facing: pose.facing, distance: thiefDistance)
        } else if pose.facing == .side {
            // Standing still side on: feet together.
            pose.assetName = thief.character.sideAsset(frame: thief.character.sideSequence[0])
        } else {
            pose.facing = .front
            pose.isMirrored = false
            pose.assetName = thief.character.standingAsset
        }
        pose.feet = position
        if pose != thiefPose { thiefPose = pose }
        if thief.state != thiefState { thiefState = thief.state }
        let visibility = (thief.visibility * 20).rounded() / 20
        if visibility != thiefVisibility { thiefVisibility = visibility }
    }

    private func finish() {
        endCountdown = nil
        nextWalkCountdown = nil
        phase = .finished
        result = session.result
        pointerLost()
        stop()
    }

    #if DEBUG
    /// Windows of script time (seconds) in which the pretend pointer wanders off. The long ones
    /// let a thief reach the character; the short ones bring a thief that is then chased off.
    private static let scriptedLookAways: [ClosedRange<TimeInterval>] = [
        6...13, 30...31.6, 40...42.3, 58...65, 85...86.5, 100...102.3,
    ]

    private func moveScriptedPointer(by delta: TimeInterval) {
        scriptClock += delta
        let fox = foxScreenPoint
        let isAway = Self.scriptedLookAways.contains { $0.contains(scriptClock) }
        let target = isAway
            ? CGPoint(x: viewportSize.width * (fox.x < viewportSize.width / 2 ? 0.78 : 0.24), y: viewportSize.height * 0.22)
            : CGPoint(x: fox.x + CGFloat(sin(scriptClock * 2.1)) * 22, y: fox.y + CGFloat(cos(scriptClock * 1.7)) * 16)
        let from = pointer ?? CGPoint(x: viewportSize.width * 0.5, y: viewportSize.height * 0.3)
        let blend = CGFloat(1 - exp(-delta / 0.16))
        pointer = CGPoint(x: from.x + (target.x - from.x) * blend, y: from.y + (target.y - from.y) * blend)
        pointerIsDown = true
        lastPointerTime = CACurrentMediaTime()
    }
    #endif
}

/// `CADisplayLink` needs an Objective-C target; this forwards each frame to the view model
/// without the link keeping the view model alive.
@MainActor
private final class DisplayLinkTarget: NSObject {
    var onFrame: (() -> Void)?

    @objc func step(_ link: CADisplayLink) {
        onFrame?()
    }
}
