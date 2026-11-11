# DrStrange gaze tracker

`DrStrangeGazeTracker` is the custom Phase 3 Swift tracker for the mounted,
landscape 13-inch iPad Air (M2). It requires iPadOS 17 or later. The
`Phase1Probe/` directory remains disposable evidence and is not a dependency of
the module or demo host.

It implements the Phase 2 contract plus the controlled Phase 3 calibration and
screen-mapping experiment. It does not implement smoothing, interaction
assistance, dwell, hit testing, or other game behavior.

## Layout

```text
GazeTracker/
├── Package.swift
├── Sources/DrStrangeGazeTracker/
│   ├── Public/                 # framework-neutral Swift contract
│   └── Internal/               # framework-neutral state machinery
├── Sources/DrStrangeGazeTrackerPlatform/
│                               # internal ARKit adapter + public factory
├── Tests/DrStrangeGazeTrackerTests/
├── DemoApp/                    # minimal gaze-owned physical-device host
├── Phase1Probe/                # preserved disposable Phase 1 evidence
└── mdFiles/
```

## Integration

Add the local package at `GazeTracker/` and depend on the
`DrStrangeGazeTracker` product:

```swift
import DrStrangeGazeTracker
import DrStrangeGazeTrackerPlatform

let tracker = GazeTrackerFactory.makeTracker()

let support = tracker.checkSupport()
guard support.isSupported else { return }

tracker.setSampleHandler { sample in
    // The callback runs on the producing queue. Hop to the UI's actor/queue
    // only for presentation work.
    consume(sample)
}

try await tracker.start()
try tracker.pause()
try await tracker.resume()
tracker.stop()
```

`stop()` releases the camera-backed runtime and clears the volatile calibration
state. The host must also stop or pause tracking when it backgrounds.

Calibration is setup-gated and advances only after a stable target visit:

```swift
try tracker.beginCalibration(layout: .ninePosition) // or .perimeterToCentre13
for target in CalibrationLayout.ninePosition.targets {
    try tracker.beginCalibrationTarget(at: target) // wait for accepted/retry
}
tracker.cancelCalibration()

tracker.invalidateCalibration(reason: .orientationChanged)
```

The Phase 3 engine uses selected-right-eye fixation-gated robust target visits,
then compares the historical five-term quadratic with a 3D ray/display-plane
mapping plus bounded affine residual. Model selection uses calibration-only
leave-one-target-out error. Final validation uses a separate engineering SPI
and never changes the seven-field live output.

Face loss with repositioning, remounting, orientation changes, material camera
or viewing-position changes, and active-eye or patch-side changes require
invalidation. Validation evidence remains a separate engineering-only summary;
error radii are never added to `GazeSample` and never perform hit testing.

## Live API boundary

`GazeSample` has exactly seven stored categories:

1. `pointNormalized`
2. `timestamp`
3. `quality`
4. `trackingState`
5. `setupState`
6. `calibrationState`
7. `eyeAvailability`

The `DrStrangeGazeTracker` contract module has no ARKit import. The companion
`DrStrangeGazeTrackerPlatform` adapter constructs the runtime; its only public
declaration is a factory returning the framework-neutral `GazeTracker` type.
ARKit sessions, camera frames, face anchors, eye transforms, face geometry,
distance measurements, calibration samples, gaze histories, and game/UI fields
are internal or absent. Until Phase 3 produces an accepted mapping,
`pointNormalized` is `nil`; the module never fabricates a center point.

## Coordinates and time

Normalized coordinates use the current drawable viewport, not the full physical
display unless those are the same area. `(0, 0)` is the viewport's top-left,
`(1, 1)` is its bottom-right, x increases rightward, and y increases downward.
`GazeViewport` converts between normalized and viewport coordinates.

`MonotonicTimestamp` is nanoseconds from device uptime. It is not a date and
must not be compared across device boots. The publisher guarantees strictly
increasing values, including when a source timestamp repeats or regresses.

## Privacy and latency

Camera frames, face geometry, calibration inputs, and gaze values stay in
volatile memory. The production module contains no persistence, logging,
analytics, networking, caching, upload, or gaze-history path. Only aggregate,
non-identifying validation results may be persisted by separately reviewed
engineering tooling.

The internal ARKit delegate uses a dedicated user-interactive serial queue and
delivers each state/sample directly from the producing queue. The module adds no
main-thread hop, timer, smoothing buffer, or sample-history queue. Phase 1 saw
intermittent publication-latency p90 values as high as 56.374 ms while every
maximum stayed below 100 ms; this remains an engineering risk for later mapping
and robustness work.

## Engineering face-isolation assessment

The gaze-owned `DemoApp` contains an engineering-only, volatile face-isolation
assessment. It runs Vision face detection at up to 10 Hz on a separate queue,
adds 35% square padding around the largest detected face, and renders a
normalized `224×224` crop beside the full ARKit preview. The crop is a candidate
model input only: it does not drive the ARKit gaze mapper, calibration, or
gameplay.

The app reports face-detection rate, source pixels retained, crop-processing
latency, and separate gaze-stream p90/maximum latency and rate while isolation
is on versus off. To compare on the target iPad:

1. Start the camera at the supported 40–60 cm distance with isolation on.
2. Hold the ordinary test pose for at least 30 seconds, including the intended
   patch and glasses condition when applicable.
3. Turn isolation off for at least 30 seconds without changing the setup.
4. Compare the on/off gaze figures. The existing complete-pipeline gates remain
   at least 30 valid samples/second, p90 latency at or below 50 ms, and maximum
   latency at or below 100 ms.
5. Use **Reset comparison** before changing distance, lighting, patch side, or
   eyewear so conditions are not mixed.

Images, face bounds, and crops remain in volatile memory and are cleared on
stop. Only rolling aggregate timings and counts are shown; the assessment does
not persist, log, cache, or transmit them.

The demo also exposes an engineering-only **Enforce one-eye-only input**
toggle. It defaults to on. Turning it off allows either the selected right eye
alone or both eyes to satisfy calibration and validation availability; it does
not allow left-eye-only or no-eye input. Changing the toggle invalidates any
current calibration so samples collected under different eye rules are never
mixed.

## Engineering BlazeGaze shadow

The demo now also runs a real, engineering-only BlazeGaze candidate beside the
unchanged ARKit control. Google MediaPipe Face Landmarker produces a 478-point
mesh on-device; the pinned MacGaze/WebEyeTrack homography then creates the
actual `512×128` two-eye strip shown in the UI. Core ML consumes that strip,
the MediaPipe head rotation, and a centimetre-scale face origin. The green
cursor is raw BlazeGaze output until at least three accepted calibration
targets are available, then uses a small Gaussian RBF correction fitted only
from the current volatile calibration.

The square `224×224` preview remains a diagnostic and is explicitly not the
model tensor. ARKit remains the control and continues to own calibration state,
held-out validation, and the public seven-field sample. The shadow model does
not drive gameplay. Frames, landmarks, eye strips, predictions, and RBF pairs
are memory-only and cleared on stop.

Model artifacts and their checksums/licenses are recorded in
`DemoApp/App/Models/THIRD_PARTY_NOTICES.md`. The target iPad must still produce
held-out accuracy evidence before this candidate can be adopted.

## Build and test

Run contract tests on the development Mac:

```sh
swift test
```

Build the iPad host without signing:

```sh
xcodebuild \
  -project DemoApp/GazeTrackerDemo.xcodeproj \
  -scheme GazeTrackerDemo \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

For device verification, open `DemoApp/GazeTrackerDemo.xcodeproj`, select the
exact 13-inch iPad Air (M2), and run `GazeTrackerDemo`. Check support, start the
session, exercise pause/resume/stop and calibration state controls, and confirm
that the screen displays only the seven live categories. A simulator cannot
substitute for ARKit device evidence.
