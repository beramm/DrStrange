# Technical Options

Status: Phase 2 complete; custom Phase 3 calibration and mapping is next

Repository note: Phase 2 created the production-oriented Swift Package, isolated ARKit platform adapter, focused tests, and gaze-owned demo host. Phase 3 will implement the selected custom-coordinate route.

## Confirmed target

- Native Swift/iPadOS application.
- 13-inch iPad Air (M2), mounted in landscape.
- Minimum deployment target: iPadOS 17; physical tests use the device's installed OS.
- Apple documents a landscape 12MP Center Stage front camera and a 16-core Neural Engine for this model.
- The player is aged 5–7 and one eye is patched during play.

Apple documents ARKit face tracking on devices with Apple Neural Engine from iPadOS 14 onward, but applications must still check `ARFaceTrackingConfiguration.isSupported`. Framework support alone does not prove screen-gaze accuracy, and the one-eye-patched condition makes a physical-device spike mandatory.

## Required processing pipeline for the custom coordinate route

Regardless of framework, the tracker needs the same logical stages:

1. capture front-camera observations;
2. determine whether a single face and both/one eye(s) are trackable;
3. estimate eye direction plus relevant head pose;
4. map the observation into normalized screen coordinates using per-user calibration;
5. reject invalid samples and smooth valid samples without excessive lag;
6. publish only the normalized gaze point, monotonic timestamp, confidence/quality, tracking state, setup/distance state, calibration state, and eye availability;
7. monitor drift and request recalibration when quality degrades.

## Option A — ARKit face tracking

Use `ARFaceTrackingConfiguration` and `ARFaceAnchor` observations. Apple exposes left/right eye transforms and a `lookAtPoint` estimate. A calibration model would map eye/head features to screen coordinates.

Strengths:

- first-party, on-device, real-time framework;
- provides 3D face pose and eye orientation rather than pupil pixels alone;
- supports explicit runtime capability checks;
- likely the smallest path to a physical-device feasibility result.

Limitations and unknowns:

- support and eye-pose quality must be tested on the exact iPad, not inferred from processor generation alone;
- ARKit provides face/eye observations, not a ready-made calibrated screen gaze point;
- camera placement, head motion, distance, lighting, glasses, and eye occlusion can introduce bias or dropouts;
- ARKit does not run in the iOS Simulator;
- face tracking requires camera permission and a privacy policy describing use of face data.

Verdict: preferred for the first capability spike, subject to target-device verification.

## Option B — Vision face landmarks plus custom mapping

Use Apple Vision to detect face, eye, and pupil landmarks from front-camera frames, then train or fit a screen mapping from landmark geometry and head pose.

Strengths:

- may work on devices where the chosen ARKit eye-pose route is unavailable or insufficient;
- offers direct 2D pupil landmarks;
- gives more control over the regression and filtering pipeline.

Limitations:

- pupil positions can be inaccurate during blinking;
- 2D landmarks alone do not equal gaze direction;
- likely requires more calibration, head-pose compensation, performance tuning, and validation;
- custom camera/frame processing increases implementation and maintenance cost.

Verdict: fallback experiment, not the default first implementation.

## Option C — iPadOS accessibility Eye Tracking

iPadOS offers a system Eye Tracking feature that calibrates an on-screen pointer and applies smoothing, focus, Snap to Item, and dwell. No suitable public API has been identified that lets a third-party app read its continuous gaze coordinates, confidence, eye availability, or calibration state.

A supplied recording and firsthand report demonstrate high effective control-selection accuracy, but this combines Apple's private gaze model with system-level interaction assistance. Those observations are useful references for our own calibration flow and UI behavior; they do not satisfy the custom tracker contract.

Verdict: do not use system Eye Tracking as DrStrange's gaze input architecture. Continue building the custom tracker. Borrow only observable design principles such as preflight face guidance, hold-still setup, smooth calibration-target ordering, animated fixation feedback, recalibration behavior, and semantic assistance owned by the game UI.

## Option D — external eye-tracking hardware

An external Made for iPad eye tracker may provide stronger accuracy or reliability, but it changes deployment, cost, physical setup, procurement, and integration constraints.

Verdict: consider only if external hardware is allowed and built-in-camera approaches cannot meet the agreed thresholds.

## Provisional recommendation

Run an ARKit capability spike on the exact target iPad before building the production module. The spike should be disposable and answer only these questions:

- Is the required configuration supported?
- Are left/right eye transforms present and stable at the expected distance?
- Can a simple per-user calibration distinguish all required screen regions?
- What are the accuracy, precision, update rate, sample-publication latency, and dropout rate?
- What happens with natural head movement, blinks, glasses, one-eye occlusion, and orientation changes?
- Can one calibration be reused for the entire app launch without unacceptable drift?
- Which changes—user, patch side, head position, viewing distance, mount, interruption, or orientation—must invalidate calibration?
- Can derived face pose/distance reliably gate calibration and provide child-friendly closer/farther guidance within a provisional 40–60 cm band?

The spike evaluates the numeric thresholds in `04-validation-plan.md`. It must process observations and gaze samples in memory and persist only aggregate, non-identifying results; camera frames, gaze samples, face geometry, and gaze paths must never be stored or transmitted.

If ARKit cannot meet the agreed thresholds, compare a Vision-based prototype and, if allowed, external hardware. Do not start a custom ML model until evidence shows simpler approaches are insufficient.

## Current recommendation after Phase 2

Continue with custom Phase 3 using the accepted selected-right ARKit observation source. Preserve the existing quadratic as a baseline, then test fixation-gated robust calibration and a geometric 3D eye-ray/screen-plane mapping. Use the Apple recording only to inform setup/calibration presentation and interaction-quality goals. Do not add a system Eye Tracking activation spike or replace the custom `GazeSample` contract.

## Calibration model candidates for the spike

Start with the least complex model that can be validated:

1. collect synchronized eye/head features while the user fixates known targets;
2. reject blinks and low-quality samples;
3. aggregate a short stable window for each target;
4. fit a regularized linear or low-order polynomial mapping to normalized screen coordinates;
5. validate on targets not used to fit the mapping;
6. add complexity only if residual error shows a repeatable nonlinear pattern.

The calibration target count is not decided. A 5-point flow is faster; 9 or more points can model edge/corner bias better. The validation plan should determine the minimum acceptable flow empirically.

## First-party references

- [ARFaceTrackingConfiguration](https://developer.apple.com/documentation/arkit/arfacetrackingconfiguration)
- [ARFaceAnchor](https://developer.apple.com/documentation/arkit/arfaceanchor)
- [ARFaceAnchor.lookAtPoint](https://developer.apple.com/documentation/arkit/arfaceanchor/lookatpoint)
- [ARFaceAnchor.leftEyeTransform](https://developer.apple.com/documentation/arkit/arfaceanchor/lefteyetransform)
- [Vision rightPupil](https://developer.apple.com/documentation/vision/vnfacelandmarks2d/rightpupil)
- [Verifying device support and user permission](https://developer.apple.com/documentation/arkit/verifying-device-support-and-user-permission)
- [Apple Support: Control iPad with the movement of your eyes](https://support.apple.com/guide/ipad/control-ipad-with-the-movement-of-your-eyes-ipad2cd35723/ipados)
- [Apple Support: 13-inch iPad Air (M2) technical specifications](https://support.apple.com/en-nz/119893)
