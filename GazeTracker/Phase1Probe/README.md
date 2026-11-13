# Phase 1 selected-eye ARKit probe

This disposable physical-device probe tests whether the declared uncovered eye can drive gaze during the required one-eye-patched conditions. It runs only on the mounted 13-inch iPad Air (M2) in landscape and is not Phase 2 production architecture.

## Selected configuration

- `ARFaceTrackingConfiguration` with light estimation.
- Baseline conditions retain the five-term quadratic from ARKit `lookAtPoint`.
- `Left eye patched` fits the same five-term quadratic only from the anatomical right-eye transform direction.
- `Right eye patched` fits it only from the anatomical left-eye transform direction.
- Patch conditions force the anatomically uncovered eye. Changing active eye or entering/leaving/changing a patch condition invalidates calibration; patch sides never share calibration.
- Non-patch robustness conditions expose an engineering-only active-eye selector so blink, recovery, movement, glasses, lighting, setup, and reuse exercise the selected-eye candidate instead of silently reverting to fused `lookAtPoint`.
- Nine calibration positions in a 3×3 landscape grid spanning 5%/50%/95% of the viewport. A controlled 15-position experiment was rejected after it failed to improve same-calibration repeatability.
- Twenty randomized held-out fixations using ten targets distinct from calibration.
- No v3 head compensation; target-device evidence showed it regressed accuracy and precision.
- Aggregate directional agreement, movement gain, anatomical eye availability, and p90 radius in degrees, logical points, and centimetres.

## Privacy boundary

- Camera frames, ARKit face/eye geometry, calibration samples, gaze samples, gaze paths, and sample timestamps exist only in volatile memory.
- No gaze logging, analytics, networking, cache, upload, or crash-report path exists.
- The only file written by this version is `Library/Application Support/phase1-arkit-selected-eye-9point-v8-aggregate-results.json`. It contains only permitted non-identifying aggregates, uses complete file protection, is excluded from backup, and is overwritten after each completed run. Separate prior aggregate filenames preserve the rejected 15-position and earlier 9-position evidence.
- The live `ProbeSample` surface remains limited to normalized gaze point, monotonic timestamp, confidence, tracking state, setup state, calibration state, and eye availability.

## Required order

1. At the provisional winning distance of approximately 40 cm, select `Left eye patched` and apply a real opaque patch to the physical left eye.
2. Confirm the probe reports the selected active eye as `rightOnly`, calibrate, then validate.
3. Select `Right eye patched`; this invalidates the previous calibration. Move the real opaque patch to the physical right eye.
4. Confirm the probe reports `leftOnly`, recalibrate, then validate.
5. Compare both selected-eye runs with the recorded fused `lookAtPoint` baselines before deciding whether to continue the remaining condition matrix.

The real-patch repeats are backlogged until an opaque patch is available; they remain mandatory and incomplete. Meanwhile, the remaining Phase 1 matrix should use `Selected anatomical right eye`, which produced the strongest immediate same-calibration directional/reuse consistency in the latest comparison. Select the desired non-patch condition, keep that source, recalibrate only when required by a physical setup change, and retain calibration across ordinary robustness conditions when the reuse experiment calls for it. This preference does not establish universal point accuracy or an accepted radius.

In a patch condition, `eyeAvailability` reports whether the declared active eye is open and available to the ARKit mapping. It does not verify patch presence. The aggregate explicitly records patch-presence verification as `notMeasured`; automatic compliance detection remains a separate decision.

Accuracy remains reported and the original accuracy gate remains historically failed. The revised route cannot pass until product/UI accepts the measured p90 radius and its target-separation consequences. No iPhone or simulator result is valid evidence.
