import Foundation
import Observation
import QuartzCore

/// Drives `FoxPathEngine` in real time: reads the pointer, moves the fox and the camera, and
/// exposes only what the views need. Pointer positions live in memory for the current frame
/// only; nothing about where the player looked is stored.
@MainActor
@Observable
final class FoxPathGameViewModel {
    enum Phase: Equatable {
        case playing
        case paused
        case finished
    }

    /// Upper bound on one frame step, so a hitch cannot make the fox jump.
    private static let maxFrameStep = 0.1
    /// Seconds the fox stands at the stall before the result shows.
    private static let finishPause = 1.4
    /// Time constant that takes the jitter out of pointer readings without adding visible lag.
    private static let pointerSmoothing = 0.08

    let configuration: FoxPathConfiguration
    let settings: FoxPathSettings
    let map: FoxPathMap
    /// Seconds without a new reading before the pointer counts as lost. `nil` for a finger,
    /// which sends nothing while it rests.
    let pointerTimeout: TimeInterval?

    private(set) var phase: Phase = .playing
    private(set) var foxPose: FoxWalkPose
    private(set) var trackingState: FoxTrackingState = .waiting
    private(set) var refocusProgress: Double = 0
    private(set) var progress: Double = 0
    private(set) var needsPointer = false
    private(set) var camera: FoxPathCamera
    /// Smoothed pointer position on screen, for the optional marker.
    private(set) var pointer: CGPoint?
    /// Set when the game is over, to show the result screen.
    private(set) var result: FoxPathResult?

    /// Size of the full-screen game view, reported by the view.
    var viewportSize: CGSize = .zero

    @ObservationIgnored private var engine: FoxPathEngine
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private let linkTarget = DisplayLinkTarget()
    @ObservationIgnored private var lastTick: CFTimeInterval?
    @ObservationIgnored private var lastPointerTime: CFTimeInterval?
    @ObservationIgnored private var pointerIsDown = false
    @ObservationIgnored private var tangent = CGVector(dx: 1, dy: 0)
    @ObservationIgnored private var finishCountdown: TimeInterval?
    @ObservationIgnored private let feedback: FoxPathFeedback

    #if DEBUG
    /// QA hook for simulator recordings: `-FoxPathSimulatedGaze YES` moves a pretend pointer
    /// that follows the fox and looks away a few times.
    @ObservationIgnored private let usesScriptedPointer = UserDefaults.standard.bool(forKey: "FoxPathSimulatedGaze")
    @ObservationIgnored private var scriptClock: TimeInterval = 0
    #endif

    init(configuration: FoxPathConfiguration, pointerTimeout: TimeInterval? = nil) {
        let settings = configuration.settings(for: configuration.level)
        let seed = configuration.randomSeed ?? UInt64.random(in: .min ... .max)
        let map = FoxPathGenerator.makeMap(seed: seed, settings: settings)
        self.configuration = configuration
        self.settings = settings
        self.map = map
        self.pointerTimeout = pointerTimeout
        engine = FoxPathEngine(settings: settings, routeLength: Double(map.route.length))
        camera = FoxPathCamera(mapSize: map.size)
        foxPose = FoxWalkPose(
            feet: map.route.sample(at: 0).point,
            facing: .front,
            assetName: FoxWalkAnimation.standingAsset
        )
        feedback = FoxPathFeedback(soundEnabled: configuration.soundEnabled, hapticsEnabled: configuration.hapticsEnabled)
    }

    // MARK: - Geometry

    /// Screen points per map unit.
    var scale: CGFloat { camera.scale(in: viewportSize) }

    /// Middle of the fox on screen.
    var foxScreenPoint: CGPoint { camera.screenPoint(for: foxPose.bodyCenter, in: viewportSize) }

    /// Height of the fox on screen.
    var foxScreenHeight: CGFloat { foxPose.facing.size.height * scale }

    /// How close to the middle of the fox the pointer must be. Never smaller than the fox itself.
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

    /// Ends the walk before the stall (exit button, or a rest break when the child has
    /// discomfort, a headache or tired eyes) and shows the summary.
    func finishEarly() {
        guard result == nil else { return }
        finish()
    }

    // MARK: - Zoom

    func zoomIn() { camera.zoomIn() }
    func zoomOut() { camera.zoomOut() }
    func setZoom(_ zoom: CGFloat) { camera.setTargetZoom(zoom) }

    // MARK: - Pointer

    /// A new gaze or finger position, in the coordinates of the full-screen game view.
    func pointerMoved(to point: CGPoint) {
        let now = CACurrentMediaTime()
        if let previous = pointer, pointerIsDown, let last = lastPointerTime {
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

    // MARK: - Loop

    private func tick() {
        let now = CACurrentMediaTime()
        let delta = min(now - (lastTick ?? now), Self.maxFrameStep)
        lastTick = now
        guard phase == .playing, delta > 0, viewportSize != .zero else { return }

        if var countdown = finishCountdown {
            countdown -= delta
            finishCountdown = countdown
            if countdown <= 0 { finish() }
        } else {
            #if DEBUG
            if usesScriptedPointer { moveScriptedPointer(by: delta) }
            #endif
            apply(engine.advance(by: delta, reading: currentReading(at: now)))
            syncFromEngine()
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

    private func apply(_ events: [FoxPathEvent]) {
        for event in events {
            switch event {
            case .started:
                break
            case .wentOffTrack:
                feedback.wentOffTrack()
            case .refocused:
                feedback.refocused()
            case .finished:
                feedback.finished()
                finishCountdown = Self.finishPause
            }
        }
    }

    private func syncFromEngine() {
        let sample = map.route.sample(at: CGFloat(engine.distance))
        tangent = sample.tangent

        var pose = foxPose
        pose.feet = sample.point
        switch engine.state {
        case .following:
            // While it holds still for a lost reading the fox keeps its last walking picture.
            pose.facing = FoxFacing.walking(along: sample.tangent)
            pose.assetName = FoxWalkAnimation.assetName(facing: pose.facing, distance: CGFloat(engine.distance))
        case .waiting, .offTrack, .finished:
            pose.facing = .front
            pose.assetName = FoxWalkAnimation.standingAsset
        }
        if pose != foxPose { foxPose = pose }

        if engine.state != trackingState { trackingState = engine.state }
        let dwell = (engine.refocusProgress * 50).rounded() / 50
        if dwell != refocusProgress { refocusProgress = dwell }
        let walked = (engine.progress * 200).rounded() / 200
        if walked != progress { progress = walked }
        if engine.needsPointer != needsPointer { needsPointer = engine.needsPointer }
    }

    private func finish() {
        finishCountdown = nil
        phase = .finished
        result = engine.result
        pointerLost()
        stop()
    }

    #if DEBUG
    /// Windows of script time (seconds) in which the pretend pointer wanders off.
    private static let scriptedLookAways: [ClosedRange<TimeInterval>] = [9...11.2, 21...22.6, 33...35.5]

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
