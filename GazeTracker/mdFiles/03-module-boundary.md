# Gaze Module Boundary

Status: custom tracker contract locked through Phase 2; custom Phase 3 is next

## Repository boundary

- Tracker implementation, calibration logic, tracker-specific tests, and tracker documentation belong under `GazeTracker/`.
- `Slicing/` is outside the gaze team's implementation scope unless both teams explicitly agree on an integration change.
- `Slicing/` is confirmed as the UI/game team's area.
- Cross-team integration should depend on a small public contract, not direct access to ARKit sessions, camera frames, or tracker internals.
- The gaze team does not implement or modify cursor visuals, mole geometry, hit testing, dwell timing, hit events, scoring, animation, instructions, or files under `Slicing/`.

## Ownership

### Gaze-tracking team owns

- camera permission requirement, camera usage-description draft, and tracker lifecycle;
- device capability detection;
- eye/head observation processing;
- calibration target sequence and sample acceptance logic;
- calibration model, filtering, confidence, and tracking-state logic;
- conversion to the agreed screen coordinate convention;
- tracker diagnostics and validation tooling;
- documentation of privacy-sensitive inputs and outputs.

### UI/game team owns

- final approved presentation of the permission explanation and all production visuals;
- rendering the agreed calibration target sequence and reporting each target's normalized position to the tracker;
- user instructions, cancel/retry controls, and accessibility presentation;
- consuming gaze samples and deciding how the game responds;
- dwell/selection visuals and game-specific event logic;
- session screens and participant-facing error messages.

No camera frames or gaze samples are persisted, transmitted, logged, cached, or sent to analytics/crash reporting. The gaze module exposes only live in-memory samples and state for gameplay. Calibration parameters remain in memory for the current app launch and are discarded on shutdown or termination.

## Whack-a-mole interaction boundary

The gaze module estimates where the player is looking and whether that estimate is usable. The UI/game layer owns mole geometry, hit testing, intentional dwell timing, score rules, animation, and audio/visual hit feedback.

The expected path is:

1. tracker publishes a timestamped gaze sample and state;
2. game converts the normalized point into its active viewport;
3. game tests the point against the currently hittable mole area;
4. game continuously accumulates the agreed 1-second dwell while the valid gaze point remains within the mole's hit area;
5. game emits one idempotent hit event for that mole.

This should be a game-level event, not a synthetic UIKit/Unity touch. Keeping gaze estimation separate from mole activation lets the UI team tune dwell time and target tolerance without changing camera/tracking code.

The game renders the gaze cursor from valid gaze samples. During `limited` or `lost` tracking, the cursor must visibly change state or be hidden; it must not silently remain on the last valid mole and complete a dwell.

After a hit, the game resets dwell state before presenting the next mole. Only one mole is active, so hit testing never needs to choose between simultaneous targets.

The one-second dwell is continuous: leaving the mole hit area or receiving a non-valid tracking state resets progress immediately. A small visual hit-area margin may absorb measured tracker jitter, but time spent outside the final hit area is never accumulated.

The game models each mole using a center, a visible artwork radius, and a circular hit radius. For a valid gaze point `g` and mole center `m`, the gaze is on-target when `distance(g, m) <= hitRadius`. The hit radius should be at least the visible radius and may include an evidence-based error margin. The game owns these values; the tracker remains unaware of mole geometry.

Because only one mole is active, a larger hit radius cannot select the wrong simultaneous mole. It can still feel inaccurate if overly generous, so the final value must balance missed and false/undeserved hits.

The tracker publishes a setup/distance state equivalent to `tooClose`, `ready`, or `tooFar`. The UI team renders child-friendly closer/farther guidance. Calibration and dwell are disabled unless setup is `ready`.

## Platform-neutral public output allowlist

The live public tracker output is limited to the following fields:

| Field | Meaning |
| --- | --- |
| `timestamp` | Monotonic capture/observation time, not wall-clock time |
| `pointNormalized` | `(x, y)` in `[0, 1]`, origin at top-left of the current drawable area |
| `confidence` | Normalized quality score with a documented interpretation |
| `trackingState` | `tracking`, `limited`, `lost`, `paused`, `unsupported`, or `permissionDenied` |
| `setupState` | `tooClose`, `ready`, `tooFar`, or `unknown` |
| `calibrationState` | `notCalibrated`, `readyForTarget`, `collecting`, `targetAccepted`, `retryTarget`, `calibrated`, `invalid`, or `failed` |
| `eyeAvailability` | `both`, `leftOnly`, `rightOnly`, or `none` |

No additional live fields may be added without change control. In particular, raw camera images, biometric face geometry, eye/head transforms, derived distance values, screen-space duplicates, sequence identifiers, diagnostics, calibration parameters, gaze history, dwell state, target geometry, and game events are excluded. A missing/invalid gaze point is represented by state rather than a fabricated coordinate.

## Lifecycle surface

The UI/game layer needs operations equivalent to:

- check device support;
- request/start camera-backed tracking;
- start calibration;
- accept/cancel calibration;
- pause/resume tracking;
- stop and release camera resources;
- subscribe/unsubscribe to samples and state changes;
- invalidate calibration after orientation/setup changes.

The tracker exposes this surface through Swift protocols and value types in the `DrStrangeGazeTracker` package, with ARKit isolated in `DrStrangeGazeTrackerPlatform`. ARKit types must remain internal to the tracker module.

## Calibration handshake

1. UI requests calibration using the agreed ordered target sequence.
2. UI renders each target and reports its normalized position after it is visibly settled.
3. Tracker collects a stable window and updates `calibrationState` to `targetAccepted` or `retryTarget`; the UI owns the sequence index and advances only after acceptance.
4. Tracker fits and validates the mapping internally.
5. Tracker reports `calibrated` or a typed failed/invalid state; engineering metrics remain internal diagnostics and are not added to the gameplay output.

The UI should never advance only on a fixed timer; the tracker must confirm that enough valid samples were captured.

## State and failure behavior

- Never emit a made-up center point when tracking is unavailable.
- A short dropout may use a clearly flagged, bounded prediction window; after that, publish `lost`.
- Orientation, camera geometry, or material viewing-distance changes may invalidate calibration.
- Backgrounding, camera interruption, and permission changes must produce state events.
- Callbacks consumed by UI must be delivered on the agreed thread/queue.
- The UI may render at display rate, but it must not assume every rendered frame has a new gaze sample.

## Contract decisions still required

- final production-application integration location for the already selected Swift Package boundary;
- exact drawable viewport used by `pointNormalized` at integration time;
- callback threading and back-pressure behavior at integration time;

The Phase 0 performance contract is already set: at least 30 valid samples per second while tracking (60 Hz target when supported), with publication latency at or below 50 ms at the 90th percentile and no supported steady-state sample above 100 ms.

## External UI/game decisions

The following are recorded for context but are owned by the `Slicing/` team and are not gaze-tracker tasks:

- cursor appearance;
- visible mole size and position;
- circular hit radius and margin;
- one-second dwell implementation and reset animation;
- hit event, scoring, sound, animation, and mole spawning;
- wording and presentation of closer/farther, calibration, and tracking-loss guidance.

The gaze team supplies accuracy, precision, latency, confidence, and state measurements that the UI team may use when making these decisions.
