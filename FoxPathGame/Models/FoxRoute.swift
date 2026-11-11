import CoreGraphics
import Foundation

/// The centre line of the path as a polyline, with distances measured along it.
struct FoxRoute: Equatable {
    let points: [CGPoint]
    /// Distance from the first point to each point. Same count as `points`.
    let cumulativeLengths: [CGFloat]

    init(points: [CGPoint]) {
        precondition(points.count >= 2, "A route needs at least two points")
        self.points = points
        var lengths: [CGFloat] = [0]
        lengths.reserveCapacity(points.count)
        for index in 1..<points.count {
            let previous = points[index - 1]
            let point = points[index]
            lengths.append(lengths[index - 1] + hypot(point.x - previous.x, point.y - previous.y))
        }
        cumulativeLengths = lengths
    }

    var length: CGFloat { cumulativeLengths[cumulativeLengths.count - 1] }

    /// Position and unit direction of travel at `distance` along the route (clamped to its ends).
    func sample(at distance: CGFloat) -> (point: CGPoint, tangent: CGVector) {
        let clamped = min(max(distance, 0), length)
        // First segment whose end is at or beyond the distance.
        var low = 1
        var high = points.count - 1
        while low < high {
            let middle = (low + high) / 2
            if cumulativeLengths[middle] < clamped { low = middle + 1 } else { high = middle }
        }
        let start = points[low - 1]
        let end = points[low]
        let segmentLength = cumulativeLengths[low] - cumulativeLengths[low - 1]
        guard segmentLength > 0 else { return (start, CGVector(dx: 1, dy: 0)) }
        let fraction = (clamped - cumulativeLengths[low - 1]) / segmentLength
        let point = CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
        let tangent = CGVector(dx: (end.x - start.x) / segmentLength, dy: (end.y - start.y) / segmentLength)
        return (point, tangent)
    }

    /// Points spaced roughly `spacing` apart along the whole route.
    func samples(spacing: CGFloat) -> [CGPoint] {
        let count = max(2, Int((length / spacing).rounded(.up)) + 1)
        return (0..<count).map { sample(at: length * CGFloat($0) / CGFloat(count - 1)).point }
    }

    /// Shortest distance from `point` to the route.
    func distance(to point: CGPoint) -> CGFloat {
        var best = CGFloat.greatestFiniteMagnitude
        for index in 1..<points.count {
            let a = points[index - 1]
            let b = points[index]
            let dx = b.x - a.x
            let dy = b.y - a.y
            let lengthSquared = dx * dx + dy * dy
            let t = lengthSquared > 0 ? min(max(((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared, 0), 1) : 0
            best = min(best, hypot(point.x - (a.x + dx * t), point.y - (a.y + dy * t)))
        }
        return best
    }
}
