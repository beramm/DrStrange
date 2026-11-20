import CoreGraphics
import Foundation

/// Decides which part of the map is on screen.
///
/// At zoom 1 the whole map fits the screen and the camera does not move. Zoomed in, the camera
/// lets the fox walk across the screen and then moves ahead of it, so the fox keeps moving on
/// screen instead of being pinned to the centre.
struct FoxPathCamera: Equatable {
    static let zoomRange: ClosedRange<CGFloat> = 1...2.5
    static let zoomStep: CGFloat = 1.25
    /// The fox may stray this far from the centre (fraction of the screen) before the camera moves.
    private static let deadZone = CGSize(width: 0.32, height: 0.26)
    /// Where the camera settles ahead of the fox (fraction of the screen).
    private static let lead = CGSize(width: 0.3, height: 0.24)
    /// Beyond this the fox is about to leave the screen and the camera hurries.
    private static let safeZone = CGSize(width: 0.42, height: 0.36)

    let mapSize: CGSize
    /// Centre of the screen in map units.
    private(set) var center: CGPoint
    private(set) var zoom: CGFloat = 1
    /// Zoom the camera is easing towards.
    private(set) var targetZoom: CGFloat = 1
    private var isCatchingUp = false

    init(mapSize: CGSize) {
        self.mapSize = mapSize
        center = CGPoint(x: mapSize.width / 2, y: mapSize.height / 2)
    }

    var canZoomIn: Bool { targetZoom < Self.zoomRange.upperBound - 0.001 }
    var canZoomOut: Bool { targetZoom > Self.zoomRange.lowerBound + 0.001 }

    mutating func setTargetZoom(_ value: CGFloat) {
        targetZoom = min(max(value, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
    }

    mutating func zoomIn() { setTargetZoom(targetZoom * Self.zoomStep) }
    mutating func zoomOut() { setTargetZoom(targetZoom / Self.zoomStep) }

    /// Screen points per map unit.
    func scale(in viewport: CGSize) -> CGFloat {
        guard viewport.width > 0, viewport.height > 0 else { return 1 }
        return min(viewport.width / mapSize.width, viewport.height / mapSize.height) * zoom
    }

    func screenPoint(for mapPoint: CGPoint, in viewport: CGSize) -> CGPoint {
        let scale = scale(in: viewport)
        return CGPoint(
            x: viewport.width / 2 + (mapPoint.x - center.x) * scale,
            y: viewport.height / 2 + (mapPoint.y - center.y) * scale
        )
    }

    /// Top-left corner of the map on screen.
    func mapOrigin(in viewport: CGSize) -> CGPoint {
        screenPoint(for: .zero, in: viewport)
    }

    /// Moves the camera for one frame. `focus` is the middle of the fox, `tangent` the way it walks.
    mutating func update(
        delta: TimeInterval,
        focus: CGPoint,
        tangent: CGVector,
        foxSpeed: CGFloat,
        viewport: CGSize
    ) {
        guard viewport.width > 0, viewport.height > 0 else { return }
        let ease = CGFloat(1 - exp(-delta * 9))
        zoom += (targetZoom - zoom) * ease
        if abs(targetZoom - zoom) < 0.0005 { zoom = targetZoom }

        let scale = scale(in: viewport)
        // Half the screen in map units.
        let half = CGSize(width: viewport.width / scale / 2, height: viewport.height / scale / 2)
        let offset = CGVector(dx: focus.x - center.x, dy: focus.y - center.y)

        func isOutside(_ zone: CGSize) -> Bool {
            abs(offset.dx) > zone.width * half.width * 2 || abs(offset.dy) > zone.height * half.height * 2
        }

        if isOutside(Self.deadZone) { isCatchingUp = true }
        if isCatchingUp {
            let target = clamped(
                CGPoint(
                    x: focus.x + tangent.dx * Self.lead.width * half.width * 2,
                    y: focus.y + tangent.dy * Self.lead.height * half.height * 2
                ),
                half: half
            )
            let dx = target.x - center.x
            let dy = target.y - center.y
            let remaining = hypot(dx, dy)
            // Twice the fox's pace keeps its speed across the screen about the same while the
            // camera moves; faster only when the fox is about to leave the screen.
            var speed = foxSpeed * 2
            if isOutside(Self.safeZone) { speed = max(speed, remaining * 4) }
            let step = speed * CGFloat(delta)
            if remaining <= max(step, 0.01) {
                center = target
                isCatchingUp = false
            } else {
                center.x += dx / remaining * step
                center.y += dy / remaining * step
            }
        }
        center = clamped(center, half: half)
    }

    /// Keeps the screen inside the map, or centres the map on an axis the screen fully covers.
    private func clamped(_ point: CGPoint, half: CGSize) -> CGPoint {
        func clamp(_ value: CGFloat, half: CGFloat, length: CGFloat) -> CGFloat {
            half * 2 >= length ? length / 2 : min(max(value, half), length - half)
        }
        return CGPoint(
            x: clamp(point.x, half: half.width, length: mapSize.width),
            y: clamp(point.y, half: half.height, length: mapSize.height)
        )
    }
}
