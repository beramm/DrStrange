# Apple-Inspired Custom Tracker Phase 3

Status: approved implementation brief for the next session
Last updated: 2026-11-03

## Objective

Improve DrStrange's own gaze tracker by applying the useful calibration and interaction lessons visible in Apple's Eye Tracking flow. Apple system Eye Tracking is not an input, dependency, fallback, or activation mechanism for the product.

The previous 8.0 cm threshold is retained only as historical Phase 1 evidence. It is too large for the intended experience and is not the Phase 3 success criterion.

Phase 3 succeeds only when the custom tracker demonstrates a repeatable held-out p90 radial error of **4.0 cm or less** on the exact target iPad. The stretch objective is **2–3 cm**. The result must be repeated; one unusually good run is insufficient.

## What the Apple recording actually teaches us

The supplied recording visibly shows:

- face-position guidance before calibration;
- a hold-still stage and countdown;
- an automatic 13-target perimeter-first sequence ending at the centre;
- targets that contract or pulse during fixation;
- completion feedback;
- semantic focus, snapping, and dwell after calibration.

The recording does not reveal Apple's private model, raw gaze coordinates, fixation detector, calibration fitting, filtering, or true raw error. Its precise-feeling selection is probably the combined result of gaze estimation and system-level interaction assistance. We must therefore separate raw-tracker improvement from accurate-feeling target selection.

## Raw-tracker improvements to implement

### 1. Setup gate before calibration

- Require the face to be within the supported distance and position range.
- Require the selected anatomical right eye to be available.
- Do not start calibration while setup is unstable.
- Invalidate calibration after remounting, orientation change, face loss with repositioning, or material camera/screen geometry change.

### 2. Fixation-gated collection

- Show a hold-still stage before the target sequence.
- Do not collect immediately when a target appears.
- Detect when selected-eye angular velocity and short-window dispersion have settled.
- Reject blinks, a short post-blink interval, excessive head movement, non-finite observations, and setup-state failures.
- Collect a bounded stable window after fixation is established.
- Retry the target when the stable window is insufficient instead of accepting bad data.

### 3. Apple-inspired target presentation

- Implement a smooth perimeter-to-centre presentation candidate with contracting or pulsing fixation feedback.
- Adapt the layout to the target iPad's landscape viewport.
- Compare the existing nine-position coverage with an Apple-inspired 13-target candidate under the same collector and mapping protocol.
- Do not assume that 13 targets are better merely because Apple displays 13. The earlier 15-position experiment proved that adding positions alone does not solve the mapping problem.

### 4. Robust target-level observations

- Reduce each accepted target visit to one volatile robust observation.
- Use medians or another bounded robust estimator for eye origin and direction.
- Track dispersion, angular velocity, head-pose range, and accepted-frame count for quality decisions.
- Give each target visit controlled weight instead of treating hundreds of correlated frames as independent measurements.
- Revisit the centre near the beginning, middle, and end when testing drift detection. Reject calibration when centre drift exceeds the validated bound.

### 5. Better screen mapping

Keep the selected-right five-term quadratic as the baseline. Compare it with:

1. a geometric 3D selected-eye ray/screen-plane intersection;
2. the geometric mapping plus a small user-specific affine residual correction;
3. bounded local mappings such as piecewise bilinear interpolation only when justified by tuning evidence.

The geometric candidate must use the selected eye's 3D origin and direction in one consistent device coordinate system. This is different from the rejected experiment that appended head-pose values to a polynomial.

### 6. Honest held-out validation

- Never evaluate final performance on calibration targets.
- Use untouched, randomized centre, edge, and corner validation targets.
- Calibrate once and run two consecutive validations without recalibrating.
- Repeat the selected candidate with modest permitted head movement.
- Report median, p90, and worst radial error in centimetres, logical points, normalized units, and degrees.
- Also report precision, directional agreement, availability, calibration duration, sample rate, latency, retry count, and between-validation change.

## Phase 3 success criteria

The candidate passes only when:

- each of two consecutive same-calibration held-out validations has p90 radial error **≤4.0 cm**;
- the modest-head-movement validation also remains **≤4.0 cm**;
- results are finite and cover centre, edges, and corners;
- directional agreement and existing operational requirements continue to pass;
- calibration completes within the existing duration and success limits;
- the improvement is produced by calibration/mapping, not by smoothing, target snapping, restricted target placement, or a larger hit radius;
- privacy remains unchanged: raw frames, biometric geometry, calibration observations, and gaze paths remain volatile and are not persisted or transmitted.

The stretch objective is repeatable p90 error in the **2–3 cm** range. If the candidate cannot reach 4.0 cm repeatably, Phase 3 fails; do not relabel the old 8.0 cm result as acceptable.

## Interaction assistance is a separate result

After raw mapping is measured, the game may separately evaluate its own semantic target resolver, attraction, hysteresis, and dwell behavior. These can reproduce some of Apple's precise-feeling selection, especially when only one mole is active, but they must be reported as interaction assistance—not as reduced tracker radius.

No Phase 3 tracker experiment may edit `Slicing/`. The gaze team should provide the UI/game team with evidence and a proposal for any later integration experiment.

## Stop rules

- Do not use Apple system Eye Tracking as product input.
- Do not repeat arbitrary polynomial head-pose features.
- Do not count ordinary temporal smoothing as correction of systematic offset.
- Do not add more calibration points without testing a specific hypothesis.
- Do not select a model from its best single run.
- Do not weaken the 4.0 cm gate when a candidate fails.
- Do not begin Phase 4 in the same session that completes Phase 3.

## Copy-ready prompt for the next session

```text
Continue the DrStrange project in /Users/chandra/Projects/DrStrange.

Read AGENTS.md/RTK.md if present, then read:
- GazeTracker/mdFiles/plan.md
- GazeTracker/mdFiles/tasks.md
- GazeTracker/mdFiles/08-apple-inspired-custom-phase3.md
- GazeTracker/mdFiles/07-apple-gaze-tracking-lessons.md
- GazeTracker/mdFiles/03-module-boundary.md
- GazeTracker/mdFiles/04-validation-plan.md

Work only on custom Phase 3: calibration and screen mapping for our own gaze tracker. Do not use Apple system Eye Tracking as an input, dependency, fallback, or activation path. Apple's recording is reference material only.

First inspect the existing GazeTracker package, Phase1Probe evidence, tests, and current git state. Preserve unrelated user changes and do not edit Slicing/.

Implement the smallest controlled Phase 3 experiment that:
1. uses the selected anatomical right-eye ARKit observation source;
2. adds setup gating, fixation detection, stable-window collection, blink/post-blink rejection, invalid-sample rejection, and target retry;
3. reduces each calibration-target visit to a robust volatile observation rather than fitting every correlated frame;
4. preserves the current five-term quadratic as the baseline;
5. implements a 3D selected-eye ray/screen-plane mapping with only a small residual correction;
6. supports a controlled comparison of the existing nine-position layout and an Apple-inspired smooth perimeter-to-centre 13-target presentation without assuming that more points are better;
7. uses untouched randomized held-out targets and runs two consecutive validations from one calibration plus a modest-head-movement validation;
8. reports raw median/p90/worst radius and operational metrics separately from any smoothing or interaction assistance;
9. persists only permitted non-identifying aggregate results—never frames, biometric geometry, calibration observations, gaze samples, or gaze paths.

The Phase 3 raw-tracker gate is repeatable p90 radial error <=4.0 cm in both consecutive validations and the modest-head-movement validation. The stretch objective is 2–3 cm. The previous 8.0 cm threshold is historical only and must not be used as the Phase 3 pass condition. Do not count smoothing, snapping, restricted spawning, or a larger hit radius as accuracy improvement.

Run relevant automated tests and, when the exact iPad is available, the controlled physical-device protocol. Update tasks.md with implementation, measurements, failures, and the exact stop reason. If the 4.0 cm gate passes, record the evidence and stop without starting Phase 4. If it fails, record the failure honestly and stop without weakening the threshold.
```
