import SwiftUI

enum PaddyGazeScreenGeometry {
    static func point(_ normalized: CGPoint, in frame: CGRect) -> CGPoint {
        CGPoint(
            x: frame.minX + min(max(normalized.x, 0), 1) * frame.width,
            y: frame.minY + min(max(normalized.y, 0), 1) * frame.height
        )
    }
}

enum GazeCursorVisuals {
    static let bubbleDiameter = GazeCursorGeometry.diameter
    static let bubbleRadius = GazeCursorGeometry.radius
    static let centerOpacity = 0.75
    static let middleOpacity = 0.56
    static let outerOpacity = 0.26
    static let middleLocation = 0.46
    static let outerLocation = 0.76
    static let trailLifetime: TimeInterval = 0.30
    static let trailBlur: CGFloat = 21
    static let trailMinimumMovement: CGFloat = 0.004
    static let trailMaximumSamples = 9
    static let trailBaseWidth: CGFloat = 53
    static let trailLifeWidth: CGFloat = 95
    static let trailOpacity = 0.25
    static let trailFadePower = 1.35
    static let briefTrackingGapHold: TimeInterval = 0.20
    static let color = Color(
        red: 252.0 / 255.0,
        green: 204.0 / 255.0,
        blue: 105.0 / 255.0
    ) // #FCCC69
}

struct GazeTrailSample {
    let point: CGPoint
    let timestamp: Date
}

struct GazeTrailCanvas: View {
    let samples: [GazeTrailSample]
    let now: Date

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let active = samples.filter {
                now.timeIntervalSince($0.timestamp) < GazeCursorVisuals.trailLifetime
            }
            guard active.count > 1 else { return }
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: GazeCursorVisuals.trailBlur))
                for index in 1..<active.count {
                    let older = active[index - 1]
                    let newer = active[index]
                    let remainingLife = max(
                        0,
                        1 - now.timeIntervalSince(older.timestamp) / GazeCursorVisuals.trailLifetime
                    )
                    let width = GazeCursorVisuals.trailBaseWidth +
                        GazeCursorVisuals.trailLifeWidth * CGFloat(remainingLife)
                    let opacity = GazeCursorVisuals.trailOpacity *
                        pow(remainingLife, GazeCursorVisuals.trailFadePower)
                    var path = Path()
                    path.move(to: CGPoint(x: older.point.x * size.width, y: older.point.y * size.height))
                    path.addLine(to: CGPoint(x: newer.point.x * size.width, y: newer.point.y * size.height))
                    layer.stroke(
                        path,
                        with: .color(GazeCursorVisuals.color.opacity(opacity)),
                        style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
    }
}

struct GazeCursorBubble: View {
    var body: some View {
        Circle()
            .fill(RadialGradient(
                stops: [
                    .init(color: GazeCursorVisuals.color.opacity(GazeCursorVisuals.centerOpacity), location: 0),
                    .init(color: GazeCursorVisuals.color.opacity(GazeCursorVisuals.middleOpacity), location: GazeCursorVisuals.middleLocation),
                    .init(color: GazeCursorVisuals.color.opacity(GazeCursorVisuals.outerOpacity), location: GazeCursorVisuals.outerLocation),
                    .init(color: GazeCursorVisuals.color.opacity(0), location: 1)
                ],
                center: .center,
                startRadius: 0,
                endRadius: GazeCursorVisuals.bubbleRadius
            ))
            .frame(width: GazeCursorVisuals.bubbleDiameter, height: GazeCursorVisuals.bubbleDiameter)
    }
}

/// Shared visual cursor for the other Paddy mini games. The game supplies the
/// already-smoothed point that it uses for interaction.
struct PaddyGazeCursorVisual: View {
    let pointNormalized: CGPoint?
    let isTracking: Bool
    let mayHoldBriefLoss: Bool

    @State private var visiblePoint: CGPoint?
    @State private var trailSamples: [GazeTrailSample] = []
    @State private var cursorHideTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if !reduceMotion, isTracking {
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                        GazeTrailCanvas(samples: trailSamples, now: timeline.date)
                    }
                }

                if let visiblePoint, isTracking || mayHoldBriefLoss {
                    GazeCursorBubble()
                        .position(
                            x: visiblePoint.x * proxy.size.width,
                            y: visiblePoint.y * proxy.size.height
                        )
                }
            }
            .onChange(of: pointNormalized) { _, _ in updateCursor() }
            .onChange(of: isTracking) { _, _ in updateCursor() }
            .onChange(of: mayHoldBriefLoss) { _, _ in updateCursor() }
            .onAppear { updateCursor() }
            .onDisappear { cursorHideTask?.cancel() }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func updateCursor() {
        if isTracking, let pointNormalized {
            cursorHideTask?.cancel()
            cursorHideTask = nil
            visiblePoint = pointNormalized
            recordTrail(pointNormalized)
        } else {
            trailSamples.removeAll()
            guard mayHoldBriefLoss, visiblePoint != nil else {
                cursorHideTask?.cancel()
                cursorHideTask = nil
                visiblePoint = nil
                return
            }
            guard cursorHideTask == nil else { return }
            cursorHideTask = Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(GazeCursorVisuals.briefTrackingGapHold))
                } catch { return }
                guard !Task.isCancelled else { return }
                visiblePoint = nil
                cursorHideTask = nil
            }
        }
    }

    private func recordTrail(_ point: CGPoint) {
        let now = Date()
        trailSamples.removeAll {
            now.timeIntervalSince($0.timestamp) >= GazeCursorVisuals.trailLifetime
        }
        if let previous = trailSamples.last,
           hypot(point.x - previous.point.x, point.y - previous.point.y) < GazeCursorVisuals.trailMinimumMovement {
            return
        }
        trailSamples.append(GazeTrailSample(point: point, timestamp: now))
        if trailSamples.count > GazeCursorVisuals.trailMaximumSamples {
            trailSamples.removeFirst(trailSamples.count - GazeCursorVisuals.trailMaximumSamples)
        }
    }
}
