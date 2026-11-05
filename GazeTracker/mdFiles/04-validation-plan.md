# Validation Plan

Status: custom tracker validation plan; Phase 3 calibration and mapping is next

## Purpose

Validation determines whether the tracker is fit for the game on the agreed hardware and setup. A visually convincing moving cursor is not sufficient evidence.

## Metrics

| Metric | Definition and required reporting | Provisional engineering target |
| --- | --- | --- |
| Accuracy / radial gaze error | For each stable held-out fixation, radial distance from the known target to the median estimated point. Report normalized units, logical screen points, and degrees of visual angle using measured viewing distance and display geometry; stratify center, edges, and corners. | Median at or below 2.0° and 90th percentile at or below 4.0° across supported conditions; no screen region may have median error above 3.0°. |
| Precision | Within each stable fixation, radial RMS distance of valid samples from that fixation's median estimate. Report the same units and regional/condition breakdowns as accuracy. | Median fixation RMS at or below 1.0° and 90th percentile at or below 2.0°. |
| Availability | Valid `tracking` time divided by eligible time when permission is granted, setup is `ready`, calibration is valid, the app is foregrounded, and the participant remains in the supported viewing area. Brief blinks and face-detection dropouts remain in the denominator. Report per-run and aggregate values. | At least 95% aggregate and no supported-condition run below 90%. |
| Update rate | Valid public gaze samples per second during eligible `tracking` intervals; report median, 10th percentile, and sustained minimum over 10-second windows. | At least 30 valid samples/second sustained; target 60 Hz when the observation source supports it. |
| Sample publication latency | Elapsed monotonic time from the source observation timestamp to delivery of the corresponding public tracker sample; excludes UI rendering and dwell processing. | 90th percentile at or below 50 ms and no sample above 100 ms in supported steady-state conditions. |
| Calibration duration | From UI calibration start request to `calibrated`, including collection and, where needed, one retry; report successful attempts separately from failures. | Median at or below 30 seconds and 90th percentile at or below 60 seconds. |
| Calibration success | Eligible ready-state sessions that reach `calibrated`; report first-attempt and within-two-attempt rates. | At least 80% on the first attempt and 90% within two attempts. |
| Drift | Change in held-out radial accuracy from immediate post-calibration baseline while reusing one in-memory calibration through a representative app launch. | Measure in Phase 1; provisional reuse passes only while accuracy continues to meet the accuracy target and no invalidation trigger occurs. |
| Recovery | Time from a blink ending or a previously lost face becoming observable to the next valid public sample; report the event types separately. | Blink recovery at or below 250 ms at the 90th percentile; face-loss recovery at or below 1 second at the 90th percentile after the face is observable. |

Report median, 90th percentile, worst case, failure count, sample/run count, and supported-condition breakdown where meaningful. For rate also report the 10th percentile. Averages alone can hide unusable edge behavior. These are provisional gameplay engineering targets, not clinical-performance claims; Phase 1 may recommend a documented requirement change rather than silently weakening a threshold.

## Capability-spike protocol

1. Lock the target iPad, OS version, orientation, mounting mode, and nominal viewing distance.
2. Present calibration points across the usable game viewport.
3. Fit the mapping only from calibration samples.
4. Present separate validation targets, including corners and edges.
5. Repeat each validation target in randomized order to reduce anticipation bias.
6. Compute per-sample calculations in memory; persist only aggregate, non-identifying metric summaries. Never persist camera frames, gaze samples, gaze paths, or face geometry.
7. Repeat after a short break to measure calibration repeatability.

Calibration and validation targets must be separate, or the result measures memorization/fit rather than generalization.

## Test matrix

Begin with a small internal adult cohort to debug the protocol. Do not generalize those results to children or people with amblyopia.

Test the agreed combinations of:

- center, edge, and corner targets;
- nominal distance plus nearer/farther distances;
- the fixed nominal mount plus permitted remount/position variability, followed by calibration-invalidation checks;
- stationary stand and normal allowed head movement;
- supported landscape orientation plus an orientation-change invalidation check;
- bright, typical, and dim-but-supported lighting;
- no eyewear and representative glasses/contact lenses;
- blinks, brief face loss, and return to frame;
- one eye occluded if patching is part of the intended session;
- the expected patch side and the alternate side if it can vary;
- cold start, recalibration, app background/foreground, and camera interruption;
- longer sessions to detect thermal throttling and drift.

Because intended players are aged 5–7, internal adult testing may debug the engineering protocol but cannot establish usability or performance for the target population. Testing with children requires the approved supervision, consent, privacy, and research/clinical process.

The provisional setup target is 45 cm with an acceptable band of 40–60 cm. Phase 1 must verify whether this band gives stable observations on the mounted 13-inch iPad Air (M2). Test just inside and outside both limits and verify that the tracker publishes the correct setup state and does not accept calibration samples outside `ready`.

Test both patch sides across participants when possible. A patch-side change invalidates calibration. Include representative glasses and supported bright/typical/dim lighting conditions; determine and document any environment that must be rejected rather than silently producing low-quality gaze.

Report radial gaze-error distributions in logical screen points and normalized coordinates. The UI team may use those results to choose its circular hit radius, but mole sizing, hit testing, dwell correctness, and gameplay tuning are not part of tracker validation.

## Calibration reuse experiment

The desired experience is one calibration when the app/game is opened, reused through the play session. Validate this explicitly:

1. calibrate once after launch;
2. validate immediately on held-out targets;
3. play representative rounds without recalibrating;
4. revalidate after elapsed time, ordinary head movement, a game pause, and an AR session interruption;
5. compare drift with the agreed threshold;
6. determine which condition requires recalibration.

Do not reuse calibration across a different child, a changed patch side, a remounted/reoriented iPad, or a materially changed viewing position without separate evidence.

## Permitted validation record

Per-sample values may exist only in volatile memory during a test. After each test condition, reduce them to aggregate results that cannot reconstruct a gaze path. The permitted persisted record is limited to:

- device model, OS version, orientation, and viewport dimensions;
- non-identifying test-condition labels such as distance band, patch side, eyewear category, and lighting category;
- aggregate accuracy and precision percentiles by target region/condition;
- aggregate update-rate, latency, availability, recovery, drift, and calibration-duration percentiles;
- calibration attempt/success counts and failure-state counts;
- the tracker/calibration algorithm version needed to reproduce the engineering build.

Do not persist target-by-target gaze coordinates, timestamps tied to gaze, participant identifiers, device identifiers, camera frames, face/eye geometry, calibration parameters, or gaze samples. Analytics and crash-reporting payloads must be inspected to verify that none of these values leak indirectly. A future request to retain sample-level data requires a separate scope decision; it is not authorized by this plan.

## Gate from spike to production work

Proceed only if:

- the exact device supports the selected framework and sustained session;
- measured metrics meet the agreed thresholds for the required target sizes;
- failures are exposed through states the UI can handle;
- calibration works for the intended user/setup, including eye occlusion if required;
- privacy and data handling are approved;
- the UI team accepts the module contract.

Phase 1 may execute the spike against the Phase 0 provisional contract without treating final UI integration review or child-cohort evidence as a prerequisite. Representative-child testing remains subject to the approved caregiver consent and research/clinical process.

If the spike fails, preserve only its permitted aggregate measurements and use them to choose between reduced product requirements, a Vision/custom approach, or external hardware.

## ARKit reconsideration under revised interaction-fit requirement

On 2026-11-03, product chose to reconsider ARKit because the game presents one target at a time and may use a UI-owned radius derived from each calibration's held-out error. This does not retroactively make the original point-accuracy target pass. Accuracy and precision remain mandatory reported diagnostics, but ARKit selection may instead be based on an explicitly accepted interaction-fit envelope.

Before Phase 2, the revised Phase 1 candidate must:

- use held-out validation—not calibration-fit residuals—to report the p90 radial radius in degrees, physical distance, logical points, and normalized units;
- prove that both patch sides leave the uncovered anatomical eye available and that target transitions produce consistent directional gaze movement;
- compare separately calibrated 40 cm and 45 cm setups and select only a comfortable, stable supported distance;
- continue meeting availability, update-rate, publication-latency, calibration-duration/success, recovery, privacy, and failure-state requirements;
- keep adaptive radius, target separation, dwell, and hit logic owned by the UI/game team;
- obtain product/UI acceptance of the measured radius and target-separation implications before the revised gate can pass.

The adaptive radius may not be derived from sample-level persisted data, may not silently expand after calibration, and may not be presented as evidence of therapeutic efficacy. If patch-side directional response fails or the UI/product team rejects the measured radius, ARKit remains a no-go.

### Accepted interaction-fit change control — 2026-11-03

The product owner explicitly accepted that the original ≤2° median accuracy and ≤2° p90 precision limits are not hard blockers for this gameplay route. The interaction needs reliable directional eye movement while one target is active, and the UI may consume a radius derived from that calibration's held-out p90 radial error. The original accuracy and precision targets remain reported diagnostics and historical pass/fail results; they are not retroactively marked as passed.

For this revised route, Phase 1 selection is based on:

- at least 80% held-out directional agreement in every supported required condition;
- a finite calibration-specific held-out p90 radius reported in degrees, logical points, normalized units, and physical distance, with explicit product/UI acceptance before use;
- continued compliance with the existing availability, update-rate, latency, calibration, recovery, setup-state, privacy, failure-state, and invalidation requirements;
- separate calibration and validation for each patch side using only the declared uncovered eye;
- real opaque-patch evidence on the exact target iPad; a hand-occlusion exploratory run is insufficient for the gate.

Product accepts the current exploratory selected-eye envelopes—4.726 cm p90 for the selected anatomical right eye and 2.695 cm p90 for the selected anatomical left eye—as interaction-feasible for continued Phase 1 testing. A materially different real-patch or representative-user radius requires renewed acceptance. Precision remains mandatory evidence because severe jitter can still harm interaction quality, but failing the original point-precision threshold alone no longer rejects the revised candidate when directional agreement and the accepted interaction envelope remain fit.

Subsequent immediate-reuse evidence reopened the selected-left radius acceptance: one calibration produced 5.267 cm and then 7.726 cm p90 radius in consecutive no-deliberate-blink validations, despite 100% directional agreement. Therefore the earlier 2.695 cm result may not be used as a stable universal radius. Before gate passage, consecutive held-out validations must demonstrate that the accepted radius continues to cover the current calibration, or product/UI must explicitly accept a larger conservative envelope or a directional-only interaction that does not depend on stable absolute point placement.

A controlled 15-position calibration experiment did not resolve the issue: consecutive validations from the same calibration produced 7.317 cm and 10.213 cm p90 radii while directional agreement, availability, rate, and latency all passed. Additional calibration positions are therefore rejected as the next tuning lever for this quadratic mapping. The revised gate must treat stable direction and stable absolute point placement as separate capabilities.

### Accepted non-blocking evidence deferral — 2026-11-03

The product owner explicitly moved the real opaque-patch repeats for both sides, representative-glasses validation, bright/dim supported-lighting variants, the 40–60 cm distance/setup-state matrix, and representative-session calibration drift/reuse (including pause/interruption cases) to a **non-blocking backlog**. This decision supersedes the earlier requirement that those evidence groups complete before Phase 2. It does not convert missing measurements into passes and does not authorize claims that those conditions are supported.

Phase 1 may pass and Phase 2 may begin after all remaining non-deferred gate work is reconciled: the revised directional/performance evidence, calibration-specific radius acceptance, privacy verification, and an explicit ARKit recommendation. Typical lighting and exploratory selected-eye evidence remain the only current evidence for the deferred condition groups. The production route must preserve the ability to complete the backlog later, and the deferred conditions must be resolved before claiming production support for patched use, glasses, broad lighting variation, the provisional 40–60 cm setup band and closer/farther guidance, or once-per-launch calibration stability through a representative session.

Remount behavior is no longer a calibration-survival claim requiring a test: any iPad remount, orientation change, or material camera-position change is an unconditional calibration invalidation trigger. The tracker must return to an uncalibrated/recalibration-required state; it may not reuse the prior mapping.

### Final Phase 1 acceptance — 2026-11-03

Product accepted the selected anatomical right-eye ARKit route for Phase 2 foundation work. Each calibration must run distinct held-out validation and produce a finite p90 radial radius of **8.0 cm or less**. The UI may use that calibration-specific radius; a larger result fails calibration and requires retry. The observed valid-state selected-right range was 3.885–7.795 cm. The 12.794 cm post-face-loss result is excluded because face loss with repositioning invalidates calibration.

Change control after the Apple-informed review: this 8.0 cm value remains only the historical gate that allowed Phase 2 foundation work. It is not acceptable for Phase 3 completion. Phase 3 now requires p90 radial error of **4.0 cm or less** in each of two consecutive same-calibration held-out validations and in the modest-head-movement validation; the stretch objective is 2–3 cm.

Directional agreement passed at 100% in the accepted selected-right baseline, modest-head-movement, and typical-lighting runs. Availability, update rate, calibration duration/success, blink behavior, and the 100 ms maximum latency bound passed in those recorded conditions. The 50 ms p90 latency target was inconsistent: several runs passed, while two same-calibration validations measured 55.600 ms and 56.374 ms. This remains explicit Phase 2 engineering risk and is not relabeled as a universal pass.

The probe privacy boundary passed: volatile-only camera/face/calibration/gaze processing, aggregate-only non-identifying persistence, and the seven-category live-output allowlist. Under the accepted non-blocking evidence deferrals above, the revised Phase 1 capability gate passes. This is not production validation or therapeutic evidence.
