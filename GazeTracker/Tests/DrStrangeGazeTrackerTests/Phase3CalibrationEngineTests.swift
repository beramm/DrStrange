import XCTest
@_spi(Platform) @_spi(Engineering) @testable import DrStrangeGazeTracker
import simd

final class Phase3CalibrationEngineTests: XCTestCase {
    func testLayoutsKeepNineAndSmoothThirteenCandidatesDistinct() {
        XCTAssertEqual(CalibrationLayout.ninePosition.targets.count, 9)
        XCTAssertEqual(CalibrationLayout.perimeterToCentre13.targets.count, 13)
        XCTAssertEqual(
            CalibrationLayout.perimeterToCentre13.targets.last,
            NormalizedGazePoint(x: 0.5, y: 0.5)
        )
    }

    func testStableWindowAcceptsOneRobustVisit() throws {
        var collector = StableWindowCollector()
        let target = try XCTUnwrap(NormalizedGazePoint(x: 0.5, y: 0.5))
        collector.begin(target: target)

        var accepted: TargetVisit?
        for index in 0..<100 {
            let result = collector.ingest(
                timestampNanoseconds: UInt64(index) * 16_666_667,
                ray: makeRay(directionX: Double(index % 3 - 1) * 0.0002),
                setupReady: true,
                selectedEyeAvailable: true
            )
            if case .accepted(let visit, _) = result {
                accepted = visit
                break
            }
        }

        XCTAssertEqual(accepted?.target, target)
        XCTAssertGreaterThanOrEqual(accepted?.acceptedFrameCount ?? 0, 60)
        XCTAssertLessThan(accepted?.angularDispersionDegrees ?? .infinity, 1.5)
    }

    func testStableWindowCannotAcceptBeforeFixationAndTimedCollectionComplete() throws {
        var collector = StableWindowCollector()
        collector.begin(target: try XCTUnwrap(NormalizedGazePoint(x: 0.5, y: 0.5)))

        for index in 0..<90 {
            let result = collector.ingest(
                timestampNanoseconds: UInt64(index) * 16_666_667,
                ray: makeRay(),
                setupReady: true,
                selectedEyeAvailable: true
            )
            if case .accepted = result {
                XCTFail("Target accepted before 500 ms fixation establishment plus 1 s stable collection")
            }
        }

        let result = collector.ingest(
            timestampNanoseconds: 90 * 16_666_667,
            ray: makeRay(),
            setupReady: true,
            selectedEyeAvailable: true
        )
        guard case .accepted = result else { return XCTFail("Expected timed stable window acceptance") }
    }

    func testBlinkAndPostBlinkSamplesAreRejected() throws {
        var collector = StableWindowCollector()
        collector.begin(target: try XCTUnwrap(NormalizedGazePoint(x: 0.5, y: 0.5)))

        for index in 0..<20 {
            let blink = index == 10 ? 0.9 : 0.0
            let result = collector.ingest(
                timestampNanoseconds: UInt64(index) * 16_666_667,
                ray: makeRay(blink: blink),
                setupReady: true,
                selectedEyeAvailable: blink < 0.7
            )
            if case .accepted = result { XCTFail("Blink-contaminated window must not be accepted") }
        }

        var acceptedAfterRecovery = false
        for index in 20..<150 {
            let result = collector.ingest(
                timestampNanoseconds: UInt64(index) * 16_666_667,
                ray: makeRay(),
                setupReady: true,
                selectedEyeAvailable: true
            )
            if case .accepted = result {
                acceptedAfterRecovery = true
                break
            }
        }
        XCTAssertTrue(acceptedAfterRecovery)
    }

    func testUnreadyTargetTimesOutToRetry() throws {
        var collector = StableWindowCollector()
        collector.begin(target: try XCTUnwrap(NormalizedGazePoint(x: 0.5, y: 0.5)))

        _ = collector.ingest(
            timestampNanoseconds: 1,
            ray: makeRay(),
            setupReady: false,
            selectedEyeAvailable: true
        )
        let result = collector.ingest(
            timestampNanoseconds: 3_500_000_002,
            ray: makeRay(),
            setupReady: false,
            selectedEyeAvailable: true
        )
        guard case .retry = result else { return XCTFail("Expected target retry") }
    }

    func testThreeOrderedUntouchedValidationsEnforceFourCentimeterGate() throws {
        var session = Phase3ValidationSession()
        let viewport = try XCTUnwrap(GazeViewport(width: 1_366, height: 1_024))
        var timestamp: UInt64 = 1

        for condition in Phase3ValidationCondition.allCases {
            let targets = Array(Phase3ValidationPlan.targets.reversed())
            try session.begin(
                condition: condition,
                targets: targets,
                viewport: viewport,
                layout: .ninePosition,
                mappingKind: "synthetic",
                calibrationDurationSeconds: 20,
                calibrationTargetRetryCount: 0
            )
            for target in targets {
                try session.beginTarget(target)
                for _ in 0..<100 {
                    timestamp += 16_666_667
                    let ray = SelectedEyeRayObservation(
                        originX: target.x,
                        originY: target.y,
                        originZ: -0.4,
                        directionX: 0,
                        directionY: 0,
                        directionZ: 1,
                        faceDistanceMeters: 0.4,
                        selectedEyeBlink: 0,
                        publicationLatencyMilliseconds: 20
                    )
                    session.ingest(
                        timestampNanoseconds: timestamp,
                        ray: ray,
                        setupState: .ready,
                        eyeAvailability: .rightOnly,
                        predict: { SIMD2($0.origin.x, $0.origin.y) }
                    )
                    if session.state != .collecting { break }
                }
            }
            XCTAssertEqual(session.state, .completed)
        }

        XCTAssertEqual(session.summaries.map(\.condition), Phase3ValidationCondition.allCases)
        XCTAssertTrue(session.summaries.allSatisfy(\.passesFourCentimeterGate))
        XCTAssertTrue(session.summaries.allSatisfy { $0.rawRadiusCentimeters.p90 == 0 })
    }

    private func makeRay(directionX: Double = 0, blink: Double = 0) -> RaySample {
        RaySample(SelectedEyeRayObservation(
            originX: 0,
            originY: -0.10,
            originZ: -0.40,
            directionX: directionX,
            directionY: -0.10,
            directionZ: 1,
            faceDistanceMeters: 0.40,
            selectedEyeBlink: blink,
            publicationLatencyMilliseconds: 20
        ))
    }
}
