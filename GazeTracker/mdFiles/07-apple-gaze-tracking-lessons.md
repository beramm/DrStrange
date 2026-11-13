# Lessons from Apple's Gaze-Tracking Systems

Status: design guidance for Phase 3 and UI/game integration; not a new acceptance decision
Last updated: 2026-11-03

## Purpose

This note records what the DrStrange gaze tracker can learn from Apple's publicly documented gaze-tracking systems. It separates confirmed platform behavior, reasonable design inferences, project-specific implications, and proposals that still require product/UI change control.

The central lesson is that gaze interaction is a layered system rather than a raw coordinate estimator:

`camera/eye observation -> calibration -> setup and quality gating -> gaze mapping -> filtering -> interaction assistance -> dwell`

Apple does not publish the model architecture, training data, screen-mapping function, or filtering implementation used by iPadOS Eye Tracking. DrStrange therefore cannot reproduce or invoke Apple's private tracker directly. It can adopt the same product-level principles using public ARKit observations and the project's own exact-device evidence.

## What Apple publicly confirms

### iPhone and iPad Eye Tracking

Apple documents that its accessibility Eye Tracking feature:

- uses the built-in front-facing camera without additional eye-tracking hardware;
- performs setup and control processing on device;
- calibrates by asking the user to follow targets around the screen;
- recommends a stable device, adequate lighting, and a viewing distance of approximately 18 inches / 46 cm;
- offers pointer smoothing, Snap to Item, dwell activation, dwell movement tolerance, Auto-Hide, and face-position guidance;
- can request recalibration when the user's face or device position changes.

The accessibility feature is an end-user operating-system control. No suitable public API has been identified that gives a third-party iPad application its continuous gaze coordinates.

### Public developer surface

For third-party iPad applications, ARKit is the closest first-party observation source. `ARFaceAnchor` exposes:

- face pose through `transform`;
- separate `leftEyeTransform` and `rightEyeTransform` matrices;
- a fused `lookAtPoint` estimate;
- blink-related blend-shape coefficients.

These are face/eye observations, not calibrated screen coordinates. An application must still fit and validate a screen mapping, reject unusable observations, manage setup changes, and publish an explicit tracking state.

### Apple Vision Pro is not the comparable implementation

Apple Vision Pro uses dedicated LEDs and infrared cameras to project invisible patterns onto each eye. visionOS keeps continuous gaze private and normally exposes system-mediated hover, focus, and selection behavior instead of raw eye input. Its accuracy and sensing hardware should not be used as evidence for what the iPad Air front camera can achieve.

## What this means for DrStrange

### 1. Keep the accepted selected-eye ARKit route

The public platform route and the project's physical-device evidence support continuing with ARKit. Phase 1 accepted the anatomical right-eye transform for Phase 2 foundation work. Apple accessibility behavior does not replace that evidence and does not establish one-eye-patch support.

Patch side remains part of the calibration setup. The tracker must not assume that Apple's binocular accessibility feature or ARKit's fused `lookAtPoint` behaves correctly when one eye is covered.

### 2. Treat calibration as calibration plus validation

Reaching a fitted mathematical model is not sufficient. Each launch-time calibration should:

1. collect stable samples for the declared uncovered eye at the agreed calibration targets;
2. fit the selected-right-eye mapping in volatile memory;
3. run distinct held-out targets that were not used to fit the mapping;
4. compute the calibration-specific held-out p90 radial error;
5. accept the Phase 3 candidate only when the radius is finite and no greater than 4.0 cm in both consecutive same-calibration validations and the modest-head-movement validation;
6. request a retry or report calibration failure when validation misses that limit.

The earlier 8.0 cm threshold remains historical Phase 1 foundation evidence only. It does not pass Phase 3. This also mirrors Apple's principle that a user-specific setup must be completed before gaze control becomes active.

### 3. Productize uncertainty instead of hiding it

The exact-device results show stronger directional agreement than absolute point accuracy. The tracker and game should therefore distinguish:

- whether gaze moved consistently in the intended direction;
- whether the current absolute point mapping passed held-out validation;
- whether the current sample is usable;
- how large the accepted calibration-specific error envelope is.

The tracker continues publishing only the approved seven live categories. The calibration-specific radius remains an internal calibration result or a separately approved integration handoff; it must not be silently added to every `GazeSample`.

### 4. Use target assistance at the UI/game layer

Apple's Snap to Item demonstrates that semantic target knowledge can make gaze interaction more reliable than a free-moving pointer alone. DrStrange has an unusually favorable interaction model: only one mole is active at a time.

The UI/game team can use the accepted calibration evidence to consider:

- an invisible circular hit region larger than the visible mole artwork;
- a target-attraction or visual snap effect after gaze enters a stable on-target region;
- target placement and separation compatible with the accepted error envelope;
- a visual indication that the mole has acquired gaze before dwell completes.

These are game-layer behaviors. The tracker must remain unaware of mole geometry and must not fabricate UIKit touches or game hits.

The currently accepted rule is still that leaving the final hit area immediately resets the one-second dwell. Any proposal to use separate entry/exit radii, boundary hysteresis, or a dwell movement tolerance changes that behavior and requires explicit product/UI change control before implementation.

### 5. Separate visual smoothing from selection behavior

A pleasant cursor and responsive hit testing do not necessarily require the same filtering:

- cursor rendering may use stronger smoothing or animation to reduce distracting jitter;
- gaze used for hit testing should minimize added latency;
- fast gaze movement should remain responsive;
- stable fixation may tolerate stronger smoothing;
- any filter must reset or stop producing usable output when tracking becomes invalid.

The tracker owns signal filtering. The UI team owns cursor presentation and hit testing. Filter tuning must be evaluated against both precision and publication latency; a smoother cursor is not a pass if it delays or distorts interaction.

### 6. Implement setup guidance and automatic invalidation

Apple's face guidance and recalibration behavior reinforce the project's existing setup-state design. Production tracking should derive a usable setup state and let the UI show child-friendly guidance.

Calibration and dwell must be disabled outside `ready`. Calibration must be invalidated after:

- a device remount;
- an orientation or material camera-position change;
- a patch-side or active-eye change;
- a material viewing-position change;
- face loss followed by repositioning;
- an explicit user or application request;
- measured drift or validation failure once that detection exists.

A brief blink or short dropout should make the current point unavailable immediately. It does not have to invalidate the whole calibration unless the setup subsequently changes.

Apple's approximately 46 cm recommendation is a useful reference, not a replacement for project evidence. The project's current exact-device result favors approximately 40 cm. Physical evidence on the mounted target iPad takes precedence.

### 7. Strengthen eye-availability semantics

The Phase 2 platform adapter currently reports `rightOnly` when the selected right-eye transform contains finite values. A finite transform alone does not prove that the eye is open, visible, uncovered, stable, or suitable for screen mapping.

Production availability and quality should also consider, at minimum:

- face tracking state;
- selected-eye blink coefficient;
- selected-eye transform validity and short-window stability;
- setup distance/state;
- whether the current calibration is valid;
- recovery after lost tracking.

ARKit blink coefficients are not proof of external patch presence. Patch presence/side must remain a declared and independently verified setup unless a separately authorized and validated on-device occlusion detector is introduced.

### 8. Preserve the current privacy boundary

Apple's on-device, privacy-preserving design supports the project's existing rules:

- camera frames, face geometry, eye transforms, calibration samples, gaze samples, and gaze paths remain in volatile memory;
- no sample-level analytics, logging, cache, upload, crash payload, or backup is permitted;
- only permitted non-identifying aggregate validation results may be persisted;
- framework objects and biometric geometry never cross the public module boundary.

No privacy-boundary change is recommended.

## Observed Apple Eye Tracking recording

A user-supplied 88.43-second screen recording from 2026-11-03 provides empirical interaction evidence. It shows an iPhone in portrait, not the target iPad Air in landscape, so its layout, timing, and performance are observations rather than platform guarantees.

The successful flow visibly includes:

1. a live face-position preview with “Move away from the camera” guidance;
2. a “Hold still” state before calibration;
3. a five-second countdown;
4. an automatic 13-target sequence lasting roughly 2.5 seconds per target;
5. five targets across the top, middle-right, five across the bottom, middle-left, and center, forming a smooth perimeter-first path;
6. colored targets that begin large and contract/pulse during the fixation interval;
7. a completion checkmark and return to the operating system;
8. semantic focus outlines, item snapping, and dwell activation after calibration.

The tester reports that the system points at exactly the control they intend to click. That firsthand effective-interaction result is meaningful even though the recording cannot separate raw gaze accuracy from smoothing, semantic focus, Snap to Item, and dwell tolerance.

### Project implication

The recording sets a strong interaction-quality benchmark, but DrStrange will not use Apple system Eye Tracking as its tracker or activation architecture. We are building our own tracker and retain the existing continuous coordinate/state contract. Apple's observable flow is useful only as reference material for our setup, calibration, feedback, and recovery design.

The recording reinforces these custom-tracker design lessons:

- perform setup/distance guidance before calibration;
- use a short hold-still state and clear countdown;
- present calibration targets in a smooth path rather than forcing repeated full-screen saccades;
- let fixation quality control sample acceptance even if the visual target has a bounded maximum duration;
- use animated target feedback appropriate for young users;
- treat target count as only one factor—Apple's effectiveness also depends on private modeling and system-level interaction assistance.

The observed 13 targets do not reverse the project's controlled evidence that 15 unique positions failed to improve the current quadratic mapping. Copying Apple's count is not the next radius-reduction lever.

## Reducing the calibration-specific radius

The current valid-state selected-right p90 radius varies from 3.885 cm to 7.795 cm. The next objective should be a repeatable reduction across consecutive held-out validations, not another isolated best run.

The existing evidence indicates that the radius is driven primarily by systematic screen-mapping error and calibration/reuse variation. Ordinary temporal smoothing may reduce cursor jitter and fixation precision, but it cannot reliably remove a biased fixation median. A larger hit region or Snap-to-Item-style assistance can improve gameplay without reducing the measured gaze radius; those outcomes must be reported separately.

### Highest-priority experiment: geometric gaze-ray mapping

The current selected-eye probe extracts only the selected eye transform's local x/y direction and fits a five-term quadratic. It does not use the eye's 3D origin or geometrically model the relationship between the eye ray, camera, and fixed screen.

The next mapping experiment should:

1. compose the face transform with the selected anatomical eye transform;
2. express the selected eye origin and pupil-facing direction in a consistent camera/device coordinate space;
3. intersect that 3D ray with a model of the mounted display plane;
4. fit only a small user-specific angular offset, scale, or affine residual correction;
5. invalidate the mapping whenever the screen/camera geometry or supported viewing setup changes.

This is materially different from the rejected v3 head-compensation experiment. V3 appended face translation/orientation values to a polynomial. A ray-plane model uses head translation and rotation through the physical geometry instead of asking a regression to infer that geometry from loosely related features.

### Fixation-gated calibration

The probe currently begins collecting on a fixed timer after the target appears and then accepts every usable frame in the collection window. Phase 3 should make target acceptance depend on detected fixation quality:

- reject blinks and a short post-blink recovery interval;
- compute selected-eye angular velocity and short-window dispersion;
- begin collection only after a stable fixation interval;
- collect a bounded stable window rather than every frame until a timer expires;
- reject or retry a target when dispersion, head movement, setup state, or availability is outside its threshold;
- let the tracker report `targetAccepted` or `retryTarget` so the UI does not advance on a timer alone.

The exact stability thresholds must be derived on the target iPad and validated against calibration duration. A longer window is not automatically better; the goal is a cleaner observation.

### Robust target-level aggregation

The current regression treats many correlated frames at one target as separate observations with the same screen label. This can give targets unequal weight and allows unsettled samples to distort the mapping.

For each calibration-target visit, calculate a volatile robust aggregate such as:

- median selected-eye origin and direction;
- angular dispersion and velocity summary;
- head-pose/setup range;
- accepted-frame count and stability weight.

Fit the screen mapping from target-visit aggregates using robust or iteratively reweighted regression. Do not persist the aggregates or raw samples. Repeating the existing nine positions in a balanced or randomized order is more informative than adding more unique positions, because the controlled 15-position experiment already showed that point count alone did not improve repeatability.

Center-target revisits near the beginning, middle, and end of calibration can expose within-calibration posture drift. A material center shift should reject the attempt or support only a separately validated bounded bias correction.

### Compare mapping families under one protocol

Using the same accepted calibration observations, compare:

1. affine mapping;
2. bilinear mapping using `1, x, y, xy`;
3. the existing five-term quadratic;
4. geometric ray-plane mapping with a small affine residual correction;
5. piecewise bilinear interpolation over the 3x3 calibration grid.

Model selection must not consume the final held-out targets. Use leave-one-calibration-target-out scoring or a separate tuning set, then calculate the reported radius from untouched randomized validation targets. A more complex model is acceptable only when it improves consecutive held-out results without harming calibration duration, availability, or latency.

### Bounded drift correction is a later option

Because only one mole is active, a completed high-confidence dwell may eventually provide a weak pseudo-label that the player intended to look at that mole. A future experiment could update only a slowly varying global x/y bias from multiple confirmed hits.

This is implicit recalibration and is not currently authorized. It requires product/engineering change control, strict bounds, rollback behavior, volatile-only state, and separate validation to prevent a self-reinforcing error loop. It must not update from misses, low-quality tracking, or a single hit.

### UI measures versus tracker accuracy

The UI/game team can reduce the effective interaction tolerance by restricting mole placement to empirically stronger regions, avoiding display extremes, showing an acquisition halo, or applying a target-attraction effect. These measures may improve successful dwell interaction, but they do not shrink the tracker-reported p90 radius and must not be presented as tracking-accuracy improvements.

### Controlled experiment and stop rule

The first Phase 3 radius experiment should keep the selected anatomical right eye, exact target iPad, approximate 40 cm setup, nine-position spatial coverage, privacy rules, and untouched held-out protocol constant. It should vary only calibration acceptance/aggregation and mapping family.

For each candidate:

1. calibrate once;
2. run two consecutive randomized held-out validations without recalibration;
3. repeat with modest permitted head movement;
4. report median and p90 radius, fixation precision, directional agreement, availability, calibration duration, publication latency, and between-validation radius change;
5. reject candidates that improve one best run but regress repeatability or operational metrics.

The Phase 3 gate is a repeatable p90 radius no greater than 4.0 cm, with a stretch objective of 2–3 cm. If geometric mapping plus robust fixation-gated calibration cannot meet 4.0 cm across consecutive held-out results and modest head movement, Phase 3 fails; do not fall back to the historical 8.0 cm threshold. Further polynomial tuning is then unlikely to justify its complexity, and the remaining choices are interaction assistance, narrower supported regions/setup, or external eye-tracking hardware.

### Approaches not to repeat as radius fixes

- Do not add calibration positions again without a new failure hypothesis; 15 positions increased duration and failed to improve repeatability.
- Do not rely on ordinary smoothing to correct systematic offset.
- Do not restore arbitrary polynomial head-pose features; the prior head-compensated model regressed.
- Do not select the anatomical left eye from its isolated 2.695 cm result; later same-calibration results reached 5.267-7.726 cm.
- Do not count a larger hit radius, target snapping, or restricted spawning as a reduction in measured gaze radius.

## Current implementation gaps

The Phase 2 production package is intentionally a foundation rather than a complete tracker. At the time of this note:

- `PlatformObservationRuntime` checks whether the anatomical right-eye transform is finite but does not pass mapping features into the production module;
- `setupState` is always `.unknown`;
- `eyeAvailability` does not yet incorporate blink or stability checks;
- `GazeTracker` always publishes `pointNormalized: nil` and unavailable quality;
- calibration target collection, mapping fit, held-out validation, and the 4.0 cm Phase 3 acceptance gate are not implemented;
- filtering, drift monitoring, and automatic setup-change invalidation are not implemented;
- target assistance, cursor behavior, and dwell remain correctly outside the tracker module.

These gaps define Phase 3 work; they are not regressions against the completed Phase 2 foundation scope.

## Recommended implementation order

1. Move the accepted selected-right-eye observation source into private production components, preserving the current quadratic only as the comparison baseline.
2. Implement fixation-gated calibration collection and robust target-visit aggregation.
3. Compare the baseline, geometric ray-plane, and bounded local mapping candidates under one untouched held-out protocol.
4. Enforce repeatable p90 radius of no more than 4.0 cm across both consecutive held-out validations and modest head movement before publishing a Phase 3 pass.
5. Implement selected-eye blink, stability, setup, and recovery gating.
6. Publish normalized points, meaningful quality, and setup state through the existing seven-category contract.
7. Add filtering with accuracy, precision, and latency tests; keep visual cursor smoothing decisions explicit at integration time.
8. Implement the accepted calibration-invalidation triggers and later add drift checks.
9. Hand the UI/game team the validated error evidence needed to choose mole hit radius, cursor treatment, and any proposed target-assistance behavior.
10. Complete the deferred real-patch, glasses, lighting, distance-band, and representative-session evidence before making corresponding production-support claims.

## Non-goals and cautions

- Do not describe this tracker as equivalent to Apple Vision Pro eye tracking.
- Do not claim that ARKit is the implementation behind iPadOS accessibility Eye Tracking; Apple has not documented that internal architecture.
- Do not treat Apple's product behavior as proof that the patched-eye use case works.
- Do not use Apple system Eye Tracking as the product input or activation architecture. It is reference material only.
- Do not increase calibration target count again without evidence of a different failure mechanism; the controlled 15-position experiment did not improve repeatability.
- Do not add custom ML solely to imitate Apple's undisclosed model. Escalate only after the accepted public-framework route and interaction design are insufficient and new scope is explicitly authorized.
- Do not interpret gaze behavior as diagnosis, assessment, or evidence of therapeutic efficacy.

## First-party references

- [Apple announces Eye Tracking for iPad and iPhone](https://www.apple.com/ie/newsroom/2024/05/apple-announces-new-accessibility-features-including-eye-tracking/)
- [Apple Support: Control iPad with the movement of your eyes](https://support.apple.com/guide/ipad/control-ipad-with-the-movement-of-your-eyes-ipad2cd35723/ipados)
- [ARFaceTrackingConfiguration](https://developer.apple.com/documentation/arkit/arfacetrackingconfiguration)
- [ARFaceAnchor](https://developer.apple.com/documentation/arkit/arfaceanchor)
- [ARFaceAnchor.lookAtPoint](https://developer.apple.com/documentation/arkit/arfaceanchor/lookatpoint)
- [ARFaceAnchor.rightEyeTransform](https://developer.apple.com/documentation/arkit/arfaceanchor/righteyetransform)
- [Apple Vision Pro: Eyes, Hands & Privacy](https://www.apple.com/legal/privacy/data/en/eyes-hands/)
