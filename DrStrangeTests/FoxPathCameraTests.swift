import XCTest
@testable import DrStrange

final class FoxPathCameraTests: XCTestCase {
    private let viewport = CGSize(width: 1366, height: 1024)
    private let step = 1.0 / 60

    private func makeMap() -> FoxPathMap {
        FoxPathGenerator.makeMap(seed: 7, settings: .defaults(for: .intermediate))
    }

    /// Walks the fox along the whole route and calls `check` after every frame.
    private func walk(_ camera: inout FoxPathCamera, along route: FoxRoute, speed: CGFloat, check: (FoxPathCamera, CGPoint) -> Void) {
        var distance: CGFloat = 0
        while distance < route.length {
            distance += speed * CGFloat(step)
            let (point, tangent) = route.sample(at: distance)
            let focus = CGPoint(x: point.x, y: point.y - 110)
            camera.update(delta: step, focus: focus, tangent: tangent, foxSpeed: speed, viewport: viewport)
            check(camera, focus)
        }
    }

    func testWholeMapIsCentredWhenZoomedOut() {
        let map = makeMap()
        var camera = FoxPathCamera(mapSize: map.size)
        walk(&camera, along: map.route, speed: 68) { camera, _ in
            XCTAssertEqual(camera.center.x, map.size.width / 2, accuracy: 0.001)
            XCTAssertEqual(camera.center.y, map.size.height / 2, accuracy: 0.001)
        }
        let scale = camera.scale(in: viewport)
        XCTAssertLessThanOrEqual(map.size.width * scale, viewport.width + 0.001)
        XCTAssertLessThanOrEqual(map.size.height * scale, viewport.height + 0.001)
    }

    func testZoomStopsAtItsLimits() {
        var camera = FoxPathCamera(mapSize: makeMap().size)
        XCTAssertFalse(camera.canZoomOut)
        camera.zoomOut()
        XCTAssertEqual(camera.targetZoom, 1)

        for _ in 0..<10 { camera.zoomIn() }
        XCTAssertEqual(camera.targetZoom, FoxPathCamera.zoomRange.upperBound)
        XCTAssertFalse(camera.canZoomIn)
        XCTAssertTrue(camera.canZoomOut)

        camera.setTargetZoom(0.2)
        XCTAssertEqual(camera.targetZoom, FoxPathCamera.zoomRange.lowerBound)
    }

    func testZoomedInCameraKeepsTheFoxOnScreenAndStaysInsideTheMap() {
        let map = makeMap()
        for zoom in [1.25, 1.6, 2.5] as [CGFloat] {
            var camera = FoxPathCamera(mapSize: map.size)
            camera.setTargetZoom(zoom)
            // Let the zoom settle on the fox's starting point before it walks.
            let (start, tangent) = map.route.sample(at: 0)
            for _ in 0..<180 {
                camera.update(delta: step, focus: CGPoint(x: start.x, y: start.y - 110), tangent: tangent, foxSpeed: 90, viewport: viewport)
            }
            XCTAssertEqual(camera.zoom, zoom, accuracy: 0.001)

            walk(&camera, along: map.route, speed: 90) { camera, focus in
                let scale = camera.scale(in: viewport)
                let half = CGSize(width: viewport.width / scale / 2, height: viewport.height / scale / 2)
                XCTAssertGreaterThanOrEqual(camera.center.x - half.width, -0.001)
                XCTAssertLessThanOrEqual(camera.center.x + half.width, map.size.width + 0.001)
                if half.height * 2 < map.size.height {
                    XCTAssertGreaterThanOrEqual(camera.center.y - half.height, -0.001)
                    XCTAssertLessThanOrEqual(camera.center.y + half.height, map.size.height + 0.001)
                }

                let onScreen = camera.screenPoint(for: focus, in: viewport)
                XCTAssertTrue((0...viewport.width).contains(onScreen.x), "zoom \(zoom): fox at x \(onScreen.x)")
                XCTAssertTrue((0...viewport.height).contains(onScreen.y), "zoom \(zoom): fox at y \(onScreen.y)")
            }
        }
    }
}
