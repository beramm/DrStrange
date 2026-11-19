import SwiftUI

enum GazeTargetGeometry {
    /// Expands every proximity boundary by 20% without changing the tier proportions.
    static let radiusScale: CGFloat = 1.2
}

enum GazeCursorGeometry {
    static let diameter: CGFloat = 250
    static let radius: CGFloat = diameter / 2

    static func contains(target: CGPoint, around cursor: CGPoint) -> Bool {
        hypot(target.x - cursor.x, target.y - cursor.y) <= radius
    }
}

/// Smooths the custom-tracker point for interaction and converts a continuous half-second dwell
/// near an active character into a proximity-scored game action.
struct GazeInteractionView: View {
    let controller: GazeInputController
    let viewModel: WhackAMoleGameViewModel
    let anchors: [FoxAnchorID: Anchor<CGRect>]

    @State private var selector = GazeDwellSelector()
    @State private var smoother = GazePointSmoother()
    @State private var smoothedNormalizedPoint: CGPoint?
    @State private var visibleNormalizedPoint: CGPoint?
    @State private var cursorHideTask: Task<Void, Never>?
    @State private var dwellProgress: Double = 0
    @State private var proximityTier: GazeProximityTier?
    @State private var trailSamples: [GazeTrailSample] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let point = cursorPoint(for: visibleNormalizedPoint, in: proxy.size)

            ZStack {
                if !reduceMotion, controller.hasUsableGaze {
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                        GazeTrailCanvas(samples: trailSamples, now: timeline.date)
                    }
                }

                if let point, mayDisplayCursor {
                    ZStack {
                        GazeCursorBubble()

                        if dwellProgress > 0 {
                            Circle()
                                .trim(from: 0, to: dwellProgress)
                                .stroke(tierColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 62, height: 62)
                        }
                    }
                    .position(point)
                }
            }
            .onChange(of: controller.sample.timestamp) { _, _ in
                consumeSample(in: proxy)
            }
            .onChange(of: viewModel.phase) { _, phase in
                if phase != .playing { resetDwell() }
            }
            .onDisappear { cursorHideTask?.cancel() }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func cursorPoint(for normalizedPoint: CGPoint?, in size: CGSize) -> CGPoint? {
        guard let normalizedPoint else { return nil }
        return CGPoint(
            x: min(max(normalizedPoint.x, 0), 1) * size.width,
            y: min(max(normalizedPoint.y, 0), 1) * size.height
        )
    }

    private func consumeSample(in proxy: GeometryProxy) {
        let rawPoint = controller.sample.pointNormalized.map { CGPoint(x: $0.x, y: $0.y) }
        smoothedNormalizedPoint = smoother.consume(
            point: rawPoint,
            timestampNanoseconds: controller.sample.timestamp.uptimeNanoseconds,
            isUsable: controller.hasUsableGaze
        )
        updateVisibleCursor()
        recordTrailSample(smoothedNormalizedPoint)
        let point = cursorPoint(for: smoothedNormalizedPoint, in: proxy.size)
        let candidate = point.flatMap { point in
            viewModel.targets.compactMap { target -> GazeFocusCandidate? in
                guard target.phase.isUp,
                      let anchor = anchors[.hole(target.holeIndex)] else { return nil }

                let holeRect = proxy[anchor]
                let artIndex = viewModel.holes.first {
                    $0.holeIndex == target.holeIndex
                }?.artIndex ?? 0
                let localCharacterRect = MoleHoleView.characterRect(
                    artIndex: artIndex,
                    in: holeRect.size
                )
                let characterCenter = CGPoint(
                    x: holeRect.minX + localCharacterRect.midX,
                    y: holeRect.minY + localCharacterRect.midY
                )
                let distance = hypot(point.x - characterCenter.x, point.y - characterCenter.y)
                guard GazeCursorGeometry.contains(target: characterCenter, around: point) else {
                    return nil
                }
                // Keep the existing character-relative distance for scoring tiers.
                let baseOuterRadius = max(
                    localCharacterRect.width / 2,
                    min(holeRect.width, holeRect.height) / 2
                )
                let outerRadius = baseOuterRadius * GazeTargetGeometry.radiusScale
                let normalizedDistance = distance / max(outerRadius, 1)
                return GazeFocusCandidate(
                    targetID: target.id,
                    holeIndex: target.holeIndex,
                    normalizedDistance: normalizedDistance
                )
            }
            .min { $0.normalizedDistance < $1.normalizedDistance }
        }

        let update = selector.consume(
            candidate: candidate,
            timestampNanoseconds: controller.sample.timestamp.uptimeNanoseconds,
            isUsable: controller.hasUsableGaze && viewModel.phase == .playing
        )
        dwellProgress = update.progress
        proximityTier = update.tier
        if let activation = update.activation {
            viewModel.activateGazeTarget(activation)
        }
    }

    private var tierColor: Color {
        switch proximityTier {
        case .inner: WhackAMolePalette.star
        case .middle: .orange
        case .outer, nil: WhackAMolePalette.accent
        }
    }

    private var mayDisplayCursor: Bool {
        controller.hasUsableGaze || (
            controller.sample.trackingState == .lost &&
            controller.isCalibrated &&
            controller.isPatchVerified &&
            !controller.isSceneTooDark
        )
    }

    private func updateVisibleCursor() {
        if let smoothedNormalizedPoint {
            cursorHideTask?.cancel()
            cursorHideTask = nil
            visibleNormalizedPoint = smoothedNormalizedPoint
        } else if mayDisplayCursor, visibleNormalizedPoint != nil {
            guard cursorHideTask == nil else { return }
            cursorHideTask = Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(GazeCursorVisuals.briefTrackingGapHold))
                } catch { return }
                guard !Task.isCancelled else { return }
                visibleNormalizedPoint = nil
                cursorHideTask = nil
            }
        } else {
            cursorHideTask?.cancel()
            cursorHideTask = nil
            visibleNormalizedPoint = nil
        }
    }

    private func recordTrailSample(_ point: CGPoint?) {
        guard let point, controller.hasUsableGaze else {
            trailSamples.removeAll()
            return
        }
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

    private func resetDwell() {
        selector.reset()
        smoother.reset()
        smoothedNormalizedPoint = nil
        cursorHideTask?.cancel()
        cursorHideTask = nil
        visibleNormalizedPoint = nil
        trailSamples.removeAll()
        dwellProgress = 0
        proximityTier = nil
    }
}
