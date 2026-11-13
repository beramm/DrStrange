# Gaze Tracker Tasks

Status: Phase 3 host running on exact iPad — controlled physical measurements pending
Last updated: 2026-11-03
Current phase: Phase 3 — implementation verified; exact-device measurements pending
Next permitted work: Phase 3 only — run the nine-versus-13 calibration and three-validation protocol now displayed on `iPad14,10`

## Task rules

- This file is the source of truth for execution progress.
- Update it during work when a task materially changes state and before every session stops.
- Use `[x]` only when the task's evidence or acceptance condition exists.
- Add a short note under a blocked task describing the blocker and required owner.
- Work on one phase only per session.
- A phase may continue across several sessions.
- When a phase gate passes, record the evidence and stop the session. The next phase begins in a new session.
- Do not silently delete tasks. Mark obsolete tasks as struck through and explain the decision in the session log.

## Planning setup

- [x] Create the discovery, technical-options, module-boundary, validation, risk, and repository-structure documents.
- [x] Create a phase-gated `plan.md`.
- [x] Create this live `tasks.md` ledger.
- [x] Record the one-phase-per-session stop rule.

Evidence: planning documents are present under `GazeTracker/mdFiles/`.

## Phase 0 — Requirements and constraints lock

- [x] Confirm the primary game mechanic: the player uses gaze to hit moles in a whack-a-mole game.
- [x] Confirm exact target iPad model: 13-inch iPad Air (M2).
- [x] Set minimum deployment target to iPadOS 17; test on the target device's installed OS.
- [x] Confirm native Swift/iPadOS application stack.
- [x] Confirm `Slicing/` belongs to the UI/game team.
- [x] Confirm intended age group: children aged 5–7.
- [x] Confirm unsupervised use.
- [x] Confirm one-eye tracking is required because one eye will be patched.
- [x] Confirm patch side can vary between users.
- [x] Record external UI/game constraint: the UI team uses 1 second of gaze dwell; gaze team does not implement it.
- [x] Define maximum tracker sample-publication latency, excluding UI rendering and dwell: 90th percentile at or below 50 ms and no steady-state sample above 100 ms under supported conditions.
- [x] Record external UI/game constraint: circular hit geometry is centered on the mole; gaze team only reports error metrics.
- [x] Remove visible mole radius, hit-radius margin, and spawn positions from gaze-tracker deliverables; these belong to `Slicing/`.
- [x] Record external UI/game constraint: one mole remains until hit; gaze team does not implement spawning.
- [x] Lock the live public tracker output to normalized gaze point, monotonic timestamp, confidence/quality, tracking state, setup/distance state, calibration state, and eye availability; game owns dwell and hit events.
- [x] Confirm landscape orientation and mounted use.
- [x] Set provisional distance guidance: 45 cm nominal, 40–60 cm valid band, with closer/farther prompts.
- [x] ~~Validate mount variability and safe/comfortable distance adjustment.~~ Reclassified as physical-iPad evidence and moved to Phase 1; it does not block the Phase 0 requirements lock.
- [x] Confirm glasses and reasonable room-lighting variation require support.
- [x] Define initial accuracy, precision, availability, update-rate, latency, recovery, calibration-duration, and calibration-success targets in `04-validation-plan.md`.
- [x] Decide gaze purpose: gameplay only, not assessment/clinical measurement.
- [x] Define retention: do not persist camera frames or gaze samples; no participant identifier is required for gameplay.
- [x] Draft the camera permission explanation and lock face-data privacy requirements: on-device, active-session processing only; no persistence or transmission of camera frames or gaze samples; no exposure of face geometry; aggregate non-identifying metrics only.
- [x] Confirm calibration at app/game launch is acceptable.
- [x] ~~Investigate and validate whether one calibration can be reused for the full app launch.~~ Reclassified as physical-iPad evidence and moved to Phase 1; Phase 0 retains once-per-launch reuse as a provisional requirement.
- [x] Reconcile currently confirmed answers into all planning documents.
- [x] Lock the provisional module boundary for Phase 0, including the public-output allowlist and `Slicing/` ownership. Cross-team integration review remains a later handoff task and is not an architecture blocker.
- [x] Pass the Phase 0 gate and record evidence below.

Phase 0 evidence: target hardware/runtime/user/setup and gameplay-only data purpose are locked; `04-validation-plan.md` contains numeric provisional targets and reporting definitions; `03-module-boundary.md` contains the exact live-output allowlist; `01-discovery-and-requirements.md` contains the camera-permission draft and mandatory privacy controls; `05-risks-and-decisions.md` records the accepted decisions. Physical-device validation items are assigned to Phase 1. No source code was created and `Slicing/` was not modified.

## Phase 1 — Physical-device capability spike

- [x] Confirm access to the exact target iPad.
- [x] Create the smallest runtime-appropriate physical-device probe.
- [x] Check and record ARKit face-tracking support at runtime.
- [x] Inspect availability and stability of both eye transforms and `lookAtPoint`.
- [x] Measure observation update behavior and dropout rate at nominal setup.
- [ ] Exercise blinks, modest head movement, glasses, and the required one-eye condition. Blink and modest-head-movement evidence is complete; representative glasses and real-patch evidence are accepted non-blocking backlog items and remain unmeasured.
- [ ] Test the required patch side and alternate side if it may vary. **Accepted non-blocking backlog:** selected-eye exploratory hand-occlusion runs exist for both sides, but no real opaque-patch evidence exists. Resume both-side repeats when obtained; do not relabel the exploratory runs as real-patch passes or claim production patch support from them.
- [x] Compare derived observations with known center, edge, and corner targets.
- [x] Report radial gaze-error distributions for the UI team to use when selecting its hit radius.
- [x] Measure and report accuracy, fixation precision, valid-sample update rate, sample-publication latency, tracking availability, recovery, calibration duration, and calibration success for the recorded exact-device conditions. Original accuracy/precision failures remain diagnostics; p90 latency was inconsistent and remains an explicit Phase 2 engineering risk rather than a relabeled pass.
- [ ] Measure drift when one calibration is reused through a representative app session. **Accepted non-blocking backlog:** no representative-duration, pause, or interruption drift sequence was completed; do not claim once-per-launch stability.
- [x] Identify calibration invalidation triggers and record whether once-per-launch reuse passes. Face loss/repositioning and every remount/orientation/material camera-position change are accepted invalidation triggers. Once-per-launch reuse, pause, and interruption behavior did not pass because they remain accepted non-blocking backlog and are not validated.
- [ ] Validate face-distance estimation and closer/farther guidance around 40 cm and 60 cm. **Accepted non-blocking backlog:** no 10-second setup-state matrix was recorded; do not claim the 40–60 cm ready band or closer/farther behavior as validated.
- [x] ~~Validate calibration survival across mount/remount variability.~~ Superseded by the accepted conservative rule: every remount, orientation change, or material camera-position change invalidates calibration and requires recalibration. No survival claim or test is needed. Comfort/adjustment-range evidence remains in the separate distance/setup backlog.
- [ ] Verify variable patch side, representative glasses, and supported lighting conditions. **Accepted non-blocking backlog:** representative glasses, both real opaque-patch sides, and bright/dim supported-lighting variants may remain incomplete when Phase 1 closes. Typical lighting has passed. Missing evidence remains a limitation and cannot be described as supported-condition validation.
- [x] Compute measurements in memory and persist only aggregate, non-identifying results; never persist camera frames or gaze samples.
- [x] Write the ARKit pass/fail recommendation and fallback decision.
- [x] Pass the revised Phase 1 capability gate and record evidence below. Phase 2 is next and must begin in a new session.

Phase 1 evidence: physical `iPad Air 13-inch (M2)` (`iPad14,10`) connected on 2026-11-03. Installed iPadOS is 27.0.1 (build 24A446), Developer Mode is enabled, and Xcode identifies the device as physical. No iPhone or simulator result is accepted as gate evidence.

The disposable native probe exists at `GazeTracker/Phase1Probe/`, compiles as a signed arm64 iOS application, and is installed and launched on the exact target iPad. The on-device runtime UI reported `AR face support: yes`, proving `ARFaceTrackingConfiguration.isSupported == true` on this device/OS combination. Camera permission was granted and the recorded aggregate-only physical tests were completed as documented below.

After camera permission was granted, the live target-device session reached `tracking` with setup `ready` and eye availability `both`. The probe only reaches that state after finite left/right eye transforms and `lookAtPoint` features are present. This confirms initial availability at the current ready-band position, but stability and supported-condition availability remain unmeasured until validation runs complete.

Resolved deployment blocker: the Apple Developer agreement/device-registration issue was corrected on 2026-11-03. Xcode created a compatible development profile, the signed build succeeded, and the probe installed and launched on the target iPad. Camera permission was granted. No iPhone or simulator evidence was substituted.

### Phase 1 provisional-target status

The table below preserves the original Phase 0 point-accuracy evaluation and rejected fused/head-compensated routes. It is historical evidence, not the current selected-eye decision rule. Under the accepted 2026-11-03 interaction-fit change control, accuracy and precision remain diagnostics while directional agreement plus an accepted held-out radius are the relevant spatial gate.

| Provisional target | Result | Evidence |
| --- | --- | --- |
| `ARFaceTrackingConfiguration.isSupported` | **Pass** | Signed probe launched on physical `iPad14,10` with iPadOS 27.0.1 and reported `AR face support: yes`. |
| Eye transforms and `lookAtPoint` availability/stability | Nominal availability confirmed; supported matrix pending | Both eye transforms and `lookAtPoint` were finite throughout accepted fixations. V2 left/right angular RMS median: 0.267°/0.260°, p90: 0.617°/0.620°. `lookAtPoint` RMS median 4.292 mm, p90 9.528 mm. The stable V2 observations are materially better than v1 and indicate that residual accuracy error is mapping bias rather than fixation jitter alone. |
| Accuracy: median ≤2.0°, p90 ≤4.0°, no region median >3.0° | **Fail — ARKit route rejected** | V1 runs: 7.813°/6.893° median. Constrained v2 improved to 5.796° median / 7.632° p90. Head-compensated v3 regressed to 10.004° median / 13.707° p90 / 14.568° worst. V3 center/edge/corner medians were 10.604°/10.953°/7.830°. No tested ARKit mapping approached the target. |
| Precision: median RMS ≤1.0°, p90 RMS ≤2.0° | **Fail overall** | V2 passed at 0.683° median / 1.454° p90, but v3 failed at 2.232° median / 5.680° p90 / 6.072° worst. |
| Availability: aggregate ≥95%, no supported run <90% | **Pass — nominal ARKit runs** | V1: 99.495%/99.747%; v2: 99.591%; v3: 97.909%. The full condition matrix was stopped after baseline accuracy failure. |
| Update rate: sustained ≥30 valid samples/s | **Pass — nominal ARKit runs** | V3 median 60 Hz, p10 51.7 Hz, sustained minimum 57.1 Hz. |
| Publication latency: p90 ≤50 ms, maximum ≤100 ms | **Pass in v2/v3; inconsistent across runs** | V3 median 46.589 ms, p90 47.170 ms, worst 55.487 ms. V2 also passed; both v1 runs failed p90. |
| Calibration duration: median ≤30 s, p90 ≤60 s | **Pass — nominal attempts** | V1: 16.091 s/16.086 s; v2: 16.062 s; 13-point v3: 23.211 s. |
| Calibration success: ≥80% first attempt, ≥90% within two | Preliminary 4/4 nominal success | Every nominal calibration succeeded, but robustness-condition rates were not collected after the accuracy early stop. |
| Drift / once-per-launch reuse | Blocked / not measured | No baseline or reuse run. |
| Blink recovery p90 ≤250 ms | Preliminary pass; explicit blink condition not measured | Four natural blink recoveries across two runs were recorded at 0 ms to the first valid frame. The dedicated blink run remains required. |
| Face-loss recovery p90 ≤1 s | Blocked / not measured | No face-loss run. |
| 40–60 cm setup band and mount/comfort variability | Blocked / not measured | No physical setup-state checks were run. |
| Both patch sides, glasses, head movement, and supported lighting | Blocked / not measured | Required condition matrix was not run. |

ARKit feasibility recommendation: **fail / no-go for production architecture**. On the exact target iPad, ARKit supplies supported, high-rate face/eye observations with acceptable calibration duration, availability, and sometimes latency/precision, but three progressively constrained mappings all fail nominal held-out accuracy by a large margin. V3 head compensation did not rescue the result and instead regressed to 10.004° median / 13.707° p90.

This recommendation applies to the original strict point-target requirement and the rejected v1–v3 routes. It is superseded for the current revised interaction-fit experiment by the selected-eye v5 change control; it is not deleted or relabeled as a historical pass.

### Revised selected-eye interaction-fit status

| Revised requirement | Current result | Status |
| --- | --- | --- |
| Directional agreement ≥80% for recorded selected-eye conditions | 100% in accepted selected-right baseline, head-movement, and typical-lighting runs; face-loss/repositioning fell to 77.778% and is an invalidation trigger | **Pass for the supported calibrated state** |
| Calibration-specific p90 radius accepted by product/UI | Selected-right valid-state results ranged from 3.885 cm to 7.795 cm; the 12.794 cm post-face-loss result is excluded because face loss/repositioning invalidates calibration | **Accepted: per-calibration held-out p90 radius ≤8.0 cm; otherwise recalibrate** |
| Availability ≥95% | 98.909% selected right; 99.545% selected left | **Exploratory pass** |
| Sustained rate ≥30 Hz | 58.6 Hz selected right; 59.7 Hz selected left | **Exploratory pass** |
| Latency p90 ≤50 ms / max ≤100 ms | Selected-right runs included passes at 45.947 ms, 45.090 ms, and 39.138 ms p90, plus misses at 55.600 ms and 56.374 ms; every measured maximum remained below 100 ms | **Inconsistent; accepted as an explicit Phase 2 engineering risk, not a universal pass** |
| Calibration duration/success | Both first attempts succeeded in 16.063 s | **Exploratory pass** |
| Real opaque patch on both sides | Hand/covering method not confirmed as real patch | **Accepted non-blocking backlog; not a pass** |
| Controlled blink recovery | 6 events; p90 0 ms to the first valid reopened frame | **Pass with frame-resolution caveat** |
| Immediate calibration reuse | Selected left: 5.267 cm then 7.726 cm (+46.7%). Selected right: 7.795 cm then 7.056 cm (-9.5%). Every run retained 100% directional agreement. | **Selected right is more repeatable within this pair; absolute/radius acceptance still pending** |
| Modest head movement | Selected right: 100% direction, 99.591% availability, 59.1 Hz sustained rate, 45.090 ms p90 latency, 6.511 cm p90 radius | **Operational metrics pass; radius acceptance pending** |
| Brief face loss / retained calibration | Three deliberate losses resumed public output on the first re-detected frame, but the run measured 77.778% direction, 88.261% availability, 52.432 ms p90 latency, and a 12.794 cm radius | **Calibration reuse fail; face loss/reposition is an invalidation trigger** |
| Representative glasses | Not completed; deferred at operator request | **Accepted non-blocking backlog; not a pass** |
| Typical lighting | Selected right: 100% direction/availability, 60 Hz sustained, 39.138 ms p90 latency, 3.885 cm p90 radius; historical precision diagnostic also passed at 0.390° median / 1.275° p90 | **Pass; bright/dim still required** |
| Bright/dim supported lighting | Not completed; deferred at operator request after typical lighting passed | **Accepted non-blocking backlog; not a pass** |
| 40–60 cm setup-distance states | No controlled setup-state recordings completed | **Accepted non-blocking backlog; not a pass** |
| Remount/orientation/camera-position change | Calibration survival intentionally unsupported | **Accepted invalidation trigger; always recalibrate** |
| Longer-session drift/reuse, pause, and interruption | Not completed for selected-eye candidate | **Accepted non-blocking backlog; once-per-launch stability not proven** |
| Patch-presence verification | Not measured; selected eye is declared | **Accepted non-blocking backlog; no patch-detection claim** |

The explicitly deferred real-patch, representative-glasses, bright/dim-lighting, distance/setup-state, and representative-session drift/reuse evidence does not block the revised Phase 1 capability gate, but it remains unmeasured and cannot support production-condition claims. Remount survival is intentionally unsupported and is handled by mandatory invalidation.

### Final Phase 1 gate decision

**Pass / conditional go for Phase 2 foundation.** Use ARKit with the selected anatomical right-eye transform and the nine-position quadratic calibration. Each calibration must use distinct held-out validation to derive its UI-owned p90 radius; accept only a finite radius at or below **8.0 cm**, otherwise fail calibration and retry. Original accuracy/precision limits remain reported diagnostics.

Invalidate calibration after face loss with repositioning, remount, orientation change, material camera-position or viewing-position change, active-eye/patch-side change, or another known setup change. Once-per-launch reuse, pause, and interruption stability are not claimed. Intermittent p90 publication-latency misses up to 56.374 ms remain a Phase 2 engineering risk; the 100 ms maximum bound passed every selected-right run.

Privacy passes for the probe: camera frames, face geometry, calibration samples/parameters, and gaze samples/paths remained volatile; only aggregate, non-identifying results were persisted. The live output remains limited to normalized gaze point, monotonic timestamp, confidence/quality, tracking state, setup/distance state, calibration state, and eye availability.

This is a capability/architecture decision, not production validation or therapeutic evidence. Phase 1 is complete. Phase 2 is the next permitted phase and must begin in a new session.

Historical fallback decision: a disposable Vision-based pupil/eye-landmark spike was run and rejected under the original strict targets. The later selected-eye ARKit interaction-fit change control and final gate decision above supersede that escalation for Phase 2 foundation work.

Future-option note: retain ARKit for possible reconsideration rather than treating this result as a permanent platform ban. Based on the measured spike, its heuristic score is **55/100 overall** and approximately **35/100 for production readiness under the current game requirements**. Strong support, calibration, availability, rate, and sometimes latency/precision are outweighed by failed accuracy. ARKit may be reconsidered only after a materially better mapping approach, a relevant platform/device improvement, an evidence-based requirement change, or a more error-tolerant use case—and must then rerun the complete exact-device Phase 1 gate before selection.

Early-stop rationale: patch-side, glasses, lighting, distance-band, mount, movement, drift, interruption, and reuse matrices were not executed for the rejected ARKit mapping because the required nominal accuracy gate already failed repeatedly. Running harsher conditions cannot turn that candidate into a pass and would collect additional biometric observations without a valid engineering purpose. Those matrices remain required for any fallback candidate that first passes nominal accuracy.

### Historical Vision fallback nominal result

The disposable Vision fallback `phase1-vision-pupil-quadratic-v1` was built, signed, installed, and run on the same physical 13-inch iPad Air (M2), `iPad14,10`, with iPadOS 27.0.1 in landscape. Runtime front-camera face, eye, and pupil landmarks were available with both eyes detected. One measured nominal 45 cm calibration completed on its first attempt in 23.403 seconds, followed by 20 randomized held-out fixations.

| Provisional target | Vision result | Decision |
| --- | --- | --- |
| Runtime framework/camera/eye-landmark availability | Vision landmarks detected; `tracking`, setup `ready`, eyes `both` | **Pass** |
| Accuracy: median ≤2.0°, p90 ≤4.0°, no region median >3.0° | 2.672° median / 5.012° p90 / 6.802° worst; center/edge/corner medians 4.579°/2.137°/1.756° | **Fail** |
| Precision: median RMS ≤1.0°, p90 RMS ≤2.0° | 1.750° median / 7.988° p90 / 9.554° worst | **Fail** |
| Availability: aggregate ≥95%, no run <90% | 100% | **Pass — nominal run** |
| Update rate: sustained ≥30 valid samples/s | 30 Hz median / 30 Hz p10 / 30 Hz sustained minimum | **Pass at the minimum bound** |
| Publication latency: p90 ≤50 ms, maximum ≤100 ms | 58.187 ms median / 61.130 ms p90 / 66.174 ms worst | **Fail p90; maximum passes** |
| Calibration duration: median ≤30 s, p90 ≤60 s | 23.403 s | **Pass — one attempt** |
| Calibration success: ≥80% first attempt, ≥90% within two | 1/1 first-attempt success | **Preliminary pass; insufficient run count** |
| Recovery, drift/reuse, distance/mount, patch sides, glasses, lighting, head movement | Not measured after nominal early stop | **Blocked for rejected candidate** |

Vision recommendation: **fail / no-go under the original strict production requirements**. Vision materially improved nominal accuracy over the original ARKit mapping, but it still failed both global accuracy bounds, the center regional bound, precision, and p90 latency. This is historical candidate evidence and does not override the final selected-eye ARKit gate decision above.

Historical escalation resolved: product explicitly revised the interaction-fit requirement, accepted calibration-specific radius behavior, and selected the ARKit route under the final Phase 1 gate decision above.

## Phase 2 — Module foundation and public contract

- [x] Create the confirmed stack's tracker source/test structure under `GazeTracker/`.
- [x] Define public models limited to the Phase 0 output allowlist and lifecycle operations.
- [x] Implement lifecycle operations.
- [x] Implement monotonic timestamps and the agreed coordinate convention.
- [x] Keep ARKit/camera types internal to the module.
- [x] Create a physical-device demo/test host.
- [x] Add state-transition and coordinate-conversion tests.
- [x] Document the language-level API or bridge boundary.
- [x] Pass the Phase 2 gate and record evidence below.

Phase 2 evidence: the gate passes. The Swift Package contains a framework-neutral `DrStrangeGazeTracker` contract target and a separate `DrStrangeGazeTrackerPlatform` adapter containing ARKit. The standard arm64 iOS contract `.swiftinterface` imports Foundation only and contains no ARKit, AVFoundation, camera-frame, face-anchor, eye-transform, or face-geometry type. The adapter's sole public declaration is `GazeTrackerFactory.makeTracker() -> GazeTracker`; ARKit types remain absent from public signatures.

`swift test` on Xcode 27.2 / Swift 6.4.2 passes 13 focused tests with zero failures. Coverage includes lifecycle transitions, calibration lifecycle, all accepted invalidation reasons, top-left normalized-coordinate conversion, invalid coordinate rejection, strictly increasing uptime timestamps under repeated/regressing clocks, ARKit-type isolation, the exact seven-category `GazeSample` allowlist, and absence of adaptive-radius/game fields.

The minimal `GazeTrackerDemo` host resolves the local package and builds successfully as an unsigned generic arm64 iOS 17 application. A distribution-interface build also succeeds; the only emitted warning is Xcode's benign App Intents metadata skip because the host has no App Intents dependency. Source scans find no persistence, networking, analytics, logging, caching, gaze history, adaptive-radius implementation, or game logic in the Phase 2 module/host. `Slicing/` remains untouched.

Exact-device evidence: Xcode produced a signed build for physical 13-inch iPad Air (M2) `iPad14,10`, UDID `00008112-000550C10A6BA01E`, iPadOS 27.0.1 build `24A446`, using the existing development team/profile. After the iPad was made available, CoreDevice installed `com.chandra.DrStrange.GazeTrackerDemo` successfully and launched it. The device process list confirmed the installed app running from its private application container as PID `8708`. A volatile `/tmp` screenshot confirmed the host running in landscape and publishing the exact seven-category typed sample with `pointNormalized = unavailable`, a nonzero monotonic uptime timestamp, quality `unavailable / 0.0`, tracking `paused`, setup `unknown`, calibration `notCalibrated`, and eye availability `none`. No camera session or permission was started merely by launching the host, and no fabricated point appeared. Together with the automated transition tests and signed device-SDK build, this satisfies the Phase 2 run/publication gate. Phase 2 is complete. Custom Phase 3 is next and must begin in a new session.

## Phase 3 — Calibration and screen mapping

Status: accuracy gate failed after corrected build 8; product explicitly approved provisional game integration on 2026-11-05 without relabeling the gate as passed. Phase 4 robustness work remains unstarted.

- [x] Implement the UI/tracker calibration handshake.
- [x] Implement fixation-gated stable-window collection, invalid-sample rejection, and robust target-visit aggregation.
- [x] Preserve the selected-right five-term quadratic as the comparison baseline.
- [x] Implement the geometric selected-eye ray/screen-plane mapping with a small residual correction.
- [x] Compare only bounded mapping candidates under the same calibration observations and untouched final validation.
- [x] Separate fitting targets from validation targets.
- [x] Version calibration data and define invalidation conditions.
- [ ] Measure center, edge, and corner accuracy/precision.
- [x] Report original Phase 0 accuracy/precision diagnostics and enforce the Phase 3 repeatable p90 radius ≤4.0 cm gate; treat 2–3 cm as the stretch objective and 8.0 cm as historical Phase 1 evidence only.
- [ ] Run two consecutive same-calibration held-out validations and modest-head-movement evidence for the selected candidate under the corrected elapsed-time collector.
- [ ] Pass the Phase 3 gate and record evidence below.

Phase 3 implementation evidence: algorithm `phase3-selected-right-ray-v1` composes the anatomical right-eye transform into camera coordinates and keeps the observation volatile. Calibration is gated on a ready 40–60 cm/face-position setup and right-eye availability. Each target uses angular-velocity, angular-dispersion, and eye-origin-range fixation checks; rejects non-finite samples, selected-eye blinks, 250 ms post-blink samples, setup failures, and excessive movement; requires 500 ms of continuously stable fixation followed by a separate one-second stable collection window with a 24-frame floor; and returns `retryTarget` after 3.5 seconds rather than accepting weak data. The host adds a 500 ms visual acquisition interval before collection, making the nominal target visit approximately two seconds. The accepted visit is reduced to one component-wise median origin/direction observation before fitting.

The controlled candidates are the existing selected-right five-term quadratic and a camera-space 3D eye-ray/display-plane intersection with a bounded affine residual. Candidate selection uses leave-one-calibration-target-out error from the same target-visit aggregates; untouched final validation targets do not select the model. Both the existing nine-position layout and the smooth perimeter-to-centre 13-target layout are available, with no assumption that 13 is superior. The gaze-owned host performs a three-second hold-still stage, animated target feedback, target-confirmed advancement/retry, and the required randomized validation order: consecutive validation one, consecutive validation two from the same calibration, then modest head movement.

Validation summaries are engineering-only and volatile. They report raw median/p90/worst radial error in centimetres, logical points, normalized units, and degrees, plus raw fixation precision, directional agreement, availability, update rate, latency, and retry count. The gate evaluator requires all ten untouched targets and p90 ≤4.0 cm independently in all three validations. It contains no smoothing, snapping, restricted spawning, hit-radius adjustment, game logic, persistence, logging, analytics, networking, or sample-level output. Face loss followed by more than 3 cm of eye-origin repositioning invalidates calibration; every public invalidation reason remains supported.

Automated/build evidence: `swift test` on Xcode 27.2 / Swift 6.4.2 passes **20 tests with zero failures**, including setup gating, target ordering, both layouts, timed stable-window acceptance, explicit rejection before the 500 ms fixation plus one-second collection budget, blink/post-blink rejection, unready-target retry, ordered untouched validation, the strict three-run 4.0 cm gate, face-loss/reposition invalidation, the exact seven-field live contract, and prior lifecycle/coordinate/timestamp coverage. Signed Release build 8 succeeds, installs, and launches on the exact iPad; the only warning is the existing benign App Intents metadata skip.

Physical gate result: **FAIL under the corrected timing protocol**. On the exact required `iPad Air 13-inch (M2)` (`iPad14,10`, UDID `00008112-000550C10A6BA01E`), build 8 reached `setup ready` with anatomical `rightOnly` observations and real ARKit camera input at exactly 1.5×. A corrected perimeter-to-centre 13-target calibration and untouched validation produced raw median **2.14 cm**, p90 **6.26 cm**, and worst **6.34 cm**. The p90 exceeds the unchanged 4.0 cm gate. The tracker then published calibration `invalid`, so consecutive validation two and modest-head-movement validation could not legally continue from the same calibration. A preceding corrected-timing calibration produced one diagnostic validation at median 3.27 cm / p90 7.40 cm / worst 8.36 cm, but the operator accidentally started a new calibration rather than the next validation, so that result is not part of the final same-calibration sequence. Build 7's faster measurements remain rejected as gate evidence. No smoothing or interaction assistance was used or credited, and Phase 4 was not started.

Product exception: on 2026-11-05 the product owner explicitly chose to continue with a functional prototype and improve raw accuracy later. This is a **provisional integration acceptance only**, not a Phase 3 accuracy pass. The raw p90 remains **6.26 cm**, the ≤4.0 cm requirement remains unmet, and calibration invalidation/repeatability remains a known risk. The exception authorizes game integration but does not weaken the threshold or permit dwell, active-hole matching, touch fallback, smoothing, snapping, or hit-region size to be reported as tracker-accuracy improvement.

## Phase 4 — Tracking quality and robustness

- [ ] Implement blink, occlusion, and invalid-observation handling.
- [ ] Implement smoothing and measure its latency cost.
- [ ] Implement confidence and typed tracking states.
- [ ] Implement bounded dropout behavior without fabricated coordinates.
- [ ] Handle camera interruption and app background/foreground transitions.
- [ ] Detect setup/orientation changes that invalidate calibration.
- [ ] Implement drift monitoring and recalibration requests.
- [ ] Add automated failure-state and recovery tests.
- [ ] Pass the Phase 4 gate and record evidence below.

Phase 4 evidence: not started.

## Phase 5 — Tracker API handoff and boundary verification

- [ ] Freeze the public Swift API and module integration with the UI/game team.
- [x] Integrate the volatile custom gaze stream into the Whack-a-Mole prototype behind the explicit provisional-acceptance exception.
- [ ] Prove tracker lifecycle in the gaze-owned demo host.
- [ ] Prove calibration target, progress, retry, and cancellation events in the gaze-owned demo host.
- [ ] Verify viewport, orientation, and coordinate contract without editing `Slicing/`.
- [ ] Prove low-confidence, interruption, permission, unsupported, and lost tracker states.
- [ ] Verify callback threading and sample/update-rate behavior in tracker contract tests.
- [ ] Run physical-device tracker API tests.
- [ ] Write UI/game integration instructions.
- [ ] Verify no gaze-team implementation exists under `Slicing/` and no game logic exists under `GazeTracker/`.
- [ ] Pass the Phase 5 gate and record evidence below.

Phase 5 evidence: not started.

Provisional integration evidence: remote branch `origin/feature/amblyopia-whack-a-mole` at `e054137` was fast-forwarded into `dev/gazeTracker` without touching `Slicing/`. The root Xcode project now resolves the local `GazeTracker` package for both app targets. The game performs the corrected 13-target custom calibration before play, keeps the same tracker/session alive, renders the raw unsmoothed point, and converts a continuous 600 ms gaze dwell inside an active hole's actual layout bounds into the existing `tapHole` action. Invalid or unavailable samples reset dwell, and a held gaze cannot repeatedly activate the same hole. This dwell and active-hole filtering are explicitly interaction assistance, not accuracy improvement. No Apple system Eye Tracking input, dependency, fallback, or activation path was added.

The integration persists no frame, biometric geometry, calibration observation, gaze sample, or gaze path. Existing game-session persistence remains game data only. All **47** game tests pass on an iPad simulator, including three new dwell-selector tests; all **20** tracker tests pass. Debug builds of both the combined `DrStrange` app and standalone `WhackAMoleGame` app succeed. A signed Release build installs and launches on the exact iPad as bundle `com.chandra.DrStrange.WhackAMoleGaze`. Live setup evidence shows `Custom ARKit camera input 1.5×`, setup `ready`, anatomical eye `rightOnly`, the volatile camera preview, and an enabled `Start calibration` control. The operator then completed calibration and entered gameplay; a live screenshot showed the raw gaze cursor beside the active mole and score 10. This is accepted as a functional prototype smoke result. Because touch remains enabled and a screenshot cannot independently distinguish dwell from touch, it is not treated as isolated gaze-activation proof or tracker-accuracy evidence.

## Phase 6 — Validation against acceptance criteria

- [ ] Freeze the validation hardware/setup matrix.
- [ ] Execute accuracy, precision, availability, rate, latency, calibration, drift, and recovery tests.
- [ ] Execute required lighting, eyewear, distance, orientation, and head-movement cases.
- [ ] Execute long-session thermal and drift tests.
- [ ] Test representative users only under the approved process.
- [ ] Report distributions and failures, not averages alone.
- [ ] Separate engineering conclusions from clinical conclusions.
- [ ] Record pass/fail and required corrective decision for every metric.
- [ ] Pass the Phase 6 gate and record evidence below.

Phase 6 evidence: not started.

## Phase 7 — Hardening and handoff

- [ ] Finalize public API and usage documentation.
- [ ] Document supported devices, setups, limitations, and failure modes.
- [ ] Document privacy behavior and retained-data schema.
- [ ] Document automated and physical-device test procedures.
- [ ] Document troubleshooting and recalibration guidance.
- [ ] Remove disposable spike code and unapproved diagnostics.
- [ ] Complete handoff review with UI/game and product owners.
- [ ] Pass the Phase 7 gate and record evidence below.

Phase 7 evidence: not started.

## Session log

### 2026-11-05 — Provisional Whack-a-Mole gaze integration installed

- Decision: product explicitly approved proceeding with a functional prototype despite the failed Phase 3 raw gate. This is recorded as a provisional integration exception, not a pass; raw median remains 2.14 cm, p90 6.26 cm, worst 6.34 cm, and the ≤4.0 cm requirement stays open.
- Branch integration: fetched and fast-forwarded `origin/feature/amblyopia-whack-a-mole` (`e054137`) into `dev/gazeTracker`. The game branch did not overlap the existing untracked `GazeTracker/` work, and `Slicing/` was not edited.
- Implementation: linked the local tracker package into both root app targets; added automatic 1.5× custom-ARKit camera startup, visible setup state and volatile preview, corrected perimeter-to-centre 13-target calibration, raw gaze cursor, and a 600 ms dwell that calls the game's existing hole-tap seam.
- Accuracy boundary: only usable, calibrated, ready, anatomical-right-eye samples can accumulate dwell. Dwell resets on invalid samples and active-hole matching uses the hole's real SwiftUI layout bounds. These are interaction aids and are not credited to the tracker p90.
- Privacy: no camera frame, biometric geometry, calibration observation, gaze sample, or gaze path is persisted, logged, transmitted, or added to game session records.
- Automated proof: all 20 tracker tests and all 47 game tests pass; both app targets build for the simulator and signed Release builds for the exact iPad.
- Exact-device state: installed and launched `com.chandra.DrStrange.WhackAMoleGaze` on `iPad14,10` / iPadOS 27.0.1. One live screenshot showed the calibration screen at setup `ready`, eye `rightOnly`, real input `1.5×`, and the enabled Start calibration button. After the operator completed calibration, a second screenshot showed active gameplay, the raw cursor beside the live mole, and score 10.
- Stop reason: the requested smallest functional game integration is built, tested, installed, and live, so stop without broadening into Phase 4. The physical screen result is a prototype smoke check only; touch remains enabled, raw p90 remains 6.26 cm, and the 4.0 cm accuracy gate remains failed.

### 2026-11-05 — Real ARKit-input zoom experiment installed; accuracy still unmeasured

- Scope: added only a bounded engineering comparison between full-sensor input (1.0×) and real capture-device zoom (1.5×). This uses ARKit's configurable primary-camera `AVCaptureDevice` before starting the same face-tracking session; it is not a display-only crop and is not Apple system Eye Tracking.
- Control: the input mode is locked while capture is active, changing it requires Stop → select → Start, and each mode requires its own calibration. The runtime rejects a requested zoom when the exact factor is unavailable or clamped, resets the device to 1.0× on session release, and retains no frame, biometric geometry, calibration observation, gaze sample, or path.
- Exact-device proof: signed Release build 6 installed and launched on the required `iPad14,10`. With `Real camera zoom (1.5×)` selected, the live host reported `ARKit input applied 1.5×` and showed the corresponding camera crop. The observed setup was `tooFar` with anatomical `rightOnly` availability; therefore this proves input capability only and does not count as an accuracy result.
- Stopped-state correction: build 7 clears published setup/eye state to `unknown`/`none` and covers the preview when capture is stopped, so the renderer's last volatile texture is neither visible nor presented as current tracking. The signed Release build installed and launched on the exact iPad. A live screenshot confirmed a black preview, `tracking paused`, `setup unknown`, `eye none`, and `ARKit input pending` before Start.
- Verification: `swift test` passes all 19 tests with zero failures after the lifecycle-state correction; the signed Release device build succeeds. No smoothing, snapping, restricted spawning, larger hit radius, or interaction assistance was introduced or credited.
- Physical protocol: build 7 reached `setup ready` with `rightOnly` and `ARKit input applied 1.5×`. The operator completed one perimeter-to-centre 13-target calibration, consecutive validations 1 and 2 without recalibration, and the modest-head-movement validation with a small lateral shift while keeping the face directed toward the display.
- Raw result: consecutive one median **4.53 cm** / p90 **9.19 cm** / worst **9.84 cm**; consecutive two median **6.70 cm** / p90 **9.40 cm** / worst **10.49 cm**; modest head movement median **4.37 cm** / p90 **8.81 cm** / worst **15.26 cm**. Every pass is a **FAIL** against p90 ≤4.0 cm.
- Evidence correction: the operator reported that calibration and validation advanced too quickly. Inspection confirmed a target had only a 350 ms presentation lead, eight frames to establish stability, and 24 accepted frames; at approximately 60 Hz it could advance in about 0.8–0.9 seconds. Because collection was not separated in elapsed time from fixation establishment, the build 7 run is rejected as controlled gate evidence rather than relabeled as a mapping pass or failure.
- Build 8 timing patch: each target now has a 500 ms visual-acquisition interval, 500 ms of continuous stable fixation, and a separate one-second stable collection window with a 24-frame minimum. Instability clears both stages. Nominal target time is approximately two seconds; the 13-target calibration remains near the 30-second calibration objective. A regression test proves acceptance cannot occur before the complete elapsed-time budget.
- Build 8 physical timing proof: the 13-target sequence visibly remained active through the expected multi-second target visits instead of completing calibration plus validation in the earlier fast interval. The first corrected calibration's validation reported median **3.27 cm** / p90 **7.40 cm** / worst **8.36 cm**, but the operator then pressed calibration instead of next validation; that abandoned the required same-calibration sequence and is retained only as diagnostic evidence.
- Corrected controlled result: the replacement 13-target calibration's first untouched validation reported median **2.14 cm** / p90 **6.26 cm** / worst **6.34 cm**. Immediately afterward the public state was calibration `invalid` while tracking/setup returned to `limited`/`ready`; the UI does not expose whether the automatic invalidation came from face-loss/reposition or a runtime failure. The invalid state prohibits the required consecutive passes from the same calibration.
- Final verification and exact stop reason: all **20** automated tests pass; signed Release build 8 succeeds, installs, and runs on the exact iPad. Corrected raw p90 is **6.26 cm**, above the fixed 4.0 cm gate, and the calibration invalidated before validation two. Stop Phase 3 without weakening the threshold, crediting assistance, running extra conditions to obscure the failed result, or starting Phase 4.

### 2026-11-03 — Phase 3 controlled experiment implemented; physical gate blocked

- Phase worked: custom Phase 3 calibration and screen mapping only. No Apple system Eye Tracking input, dependency, fallback, or activation path was added; no `Slicing/` file or game behavior was changed.
- Implementation: added selected anatomical right-eye camera-space rays, setup/face-position gating, finite/blink/post-blink/head-stability rejection, fixation detection, robust target-level reduction, retry behavior, the historical five-term quadratic baseline, and geometric ray/display-plane mapping with bounded affine residual correction.
- Controlled protocol: the gaze-owned host compares nine-position and perimeter-to-centre 13-target presentations, keeps final validation targets untouched and randomized, and enforces two consecutive same-calibration validations followed by modest head movement. Raw aggregate accuracy is reported separately from interaction assistance; none is implemented.
- Privacy: new production/host code contains no persistence, networking, analytics, logging, cache, camera-frame retention, calibration-observation retention, gaze history, or gaze-path output. Engineering summaries live only in memory.
- Verification: 19 automated tests pass; generic, Debug, and Release exact-device builds succeed. The Release host installs and launches on the exact `iPad14,10`; a live screenshot confirms the Phase 3 UI is running.
- Runtime retry: the first `Start camera` attempt competed with the diagnostic Phase 1 probe, and a second press correctly hit `invalidLifecycleTransition`; the old probe was terminated, the Phase 3 host was restarted, and the host now disables Start after one successful invocation to prevent duplicate lifecycle requests. The revised Release build passes all 19 tests, installs, and launches.
- Live face check: after a successful camera start, Phase 3 remained `setup unknown` / `eye none`. The preserved Phase 1 probe independently reported `tracking lost` / `setup unknown` / `eyes none` under the same live position, proving this was not a Phase 3 calibration-gate regression. The host now displays tracking state and explicit face/distance guidance; calibration remains correctly disabled until ARKit sees the selected right eye in a ready 40–60 cm setup.
- Camera-release failure: the operator established a repeatable chronology—after reboot the system Camera app works; starting the gaze host yields lost face tracking; afterward the Camera app is black. Inspection found that the platform runtime retained its `ARSession` object and only called `pause()` on pause/stop. The runtime now detaches the delegate, clears its strong session reference, and recreates a fresh session only on start/resume. All 19 tests and a signed Release build pass.
- Deployment retry: after the iPad reboot restored the system camera, the Mac-side CoreDevice services were restarted and the exact iPad returned as paired, wired, connected, booted, and Developer Mode enabled. A live device screenshot identified the launch blocker as iPadOS online verification of the Apple Development identity, not USB pairing or the app signature. After the iPad network path was restored, build 3 installed and launched successfully. The briefly launched Phase 1 diagnostic probe was terminated and no longer owns the camera.
- Framing aid: build 4 adds a demo-only `ARSCNView` using the same `ARSession` as the tracker. It creates no second capture path, exposes no frame through the tracker API, and persists/logs/transmits nothing. Pause/stop replaces the preview's strong session reference with an idle session so the camera-owning session can be released. Digital zoom was intentionally not added: it would enlarge only the displayed image and would not improve ARKit's full-sensor gaze input. All 19 tests pass, the signed Release build succeeds, installs, and launches on the exact iPad. The live image still requires the operator to press `Start camera`; the installed host is open and waiting.
- Preview comparison: build 5 corrects the preview container to landscape 4:3 and adds explicit `Default preview` versus `Zoomed preview (1.5×)` presentation choices. The 1.5× option is a clipped visual comparison only; it does not crop or modify the ARKit observation stream and cannot count as an accuracy improvement. The default live preview reached `setup ready` with anatomical `rightOnly` availability on the exact iPad. All 19 tests and the signed Release build pass.
- Camera-release regression: while the gaze host camera session was active, switching to the system Camera app produced a working live front-camera image rather than the previously observed black screen. This confirms the preview/session detachment fix releases camera ownership on app deactivation in this observed run. Returning by a fresh remote launch correctly starts the gaze host paused with no camera capture until `Start camera` is pressed again.
- Stop reason: press `Start camera` once, confirm the framing preview and setup state, then execute the camera-release regression (leave the app and verify the system Camera works) before running the displayed gaze trials. The 4.0 cm gate has not yet been measured, passed, failed, or weakened. Remain in Phase 3; do not start Phase 4.

### 2026-11-03 — Apple-inspired custom Phase 3 brief approved

- Product rejected 8.0 cm as the Phase 3 success threshold; it remains historical Phase 1 foundation evidence only.
- New raw-tracker gate: p90 radius ≤4.0 cm in both consecutive same-calibration held-out validations and the modest-head-movement validation; stretch objective 2–3 cm.
- Recorded the Apple-inspired custom approach: setup gate, hold-still/fixation detection, stable-window collection, blink/outlier rejection, target retry, robust target aggregates, smooth perimeter-to-centre target presentation, geometric 3D eye-ray/screen-plane mapping, and untouched validation.
- Kept raw tracker accuracy separate from semantic target assistance, snapping, hysteresis, dwell, smoothing, restricted spawning, or larger hit areas.
- Added `08-apple-inspired-custom-phase3.md` with the implementation brief and copy-ready next-session prompt. No source code or `Slicing/` file changed.

### 2026-11-03 — System activation route rejected; custom Phase 3 restored

- Product direction is explicit: DrStrange must build and use its own gaze tracker.
- Apple system Eye Tracking remains reference material for face guidance, hold-still setup, countdown, calibration-target motion/feedback, recalibration, and interaction-quality goals only.
- Removed the proposed system-activation phase, validation protocol, boundary, risks, and task checklist before any implementation began.
- Restored custom Phase 3 as the next permitted work: selected-right observations, fixation-gated robust calibration, quadratic baseline, geometric eye-ray/screen-plane mapping, and untouched held-out validation.
- No source code or `Slicing/` file changed.

### 2026-11-03 — Apple system activation route hypothesis — superseded

- Documentation/change-control hypothesis only; no system-activation or Phase 3 implementation was started.
- Recording evidence: analyzed the user-supplied 88.43-second iPhone portrait recording. It visibly contains face-distance guidance, hold-still setup, a five-second countdown, an automatic 13-target perimeter-first calibration at roughly 2.5 seconds per target, completion feedback, semantic focus outlines, item snapping, and dwell activation.
- Evidence limit: the recording and firsthand accuracy report are effective-interaction evidence, not raw gaze measurements and not proof for the exact landscape iPad, a real patch, or child users.
- Superseded idea: briefly considered replacing continuous custom coordinates with system accessibility activation. Product rejected this before implementation; it is not the project architecture.
- Files changed: planning/documentation files under `GazeTracker/mdFiles/` only. No source code or `Slicing/` file changed.
- Resolution: custom Phase 3 remains the next permitted implementation and Apple behavior is reference material only.

### 2026-11-03 — Radius-reduction findings recorded

- Documentation-only follow-up; Phase 3 implementation was not started.
- Root-cause direction: recorded that the current p90 radius is dominated by systematic mapping/calibration variation, so ordinary smoothing or a larger hit region cannot be counted as measured-radius improvement.
- Highest-priority experiment: documented full 3D selected-eye ray construction, screen-plane intersection, and a small residual calibration as a distinct alternative to the rejected polynomial head-compensation attempt.
- Calibration improvements: documented fixation-gated collection, robust target-visit aggregation, balanced/repeated nine-position visits, center-drift checks, and retry behavior.
- Model comparison: documented affine, bilinear, current quadratic, geometric ray-plane, and piecewise-bilinear candidates with untouched final held-out validation.
- Experiment rule: require two consecutive same-calibration validations plus modest-head-movement evidence; reject isolated best runs and regressions in latency, availability, or repeatability.
- Boundaries: retained the accepted finite p90 radius <=8.0 cm gate; recorded 4-5 cm only as an engineering objective. Online bias correction remains an unauthorized later option requiring change control.
- Files changed: `GazeTracker/mdFiles/07-apple-gaze-tracking-lessons.md` and this execution ledger. No source code or `Slicing/` file changed.
- Stop reason: the requested findings are documented; Phase 3 remains the next permitted implementation in a separate session.

### 2026-11-03 — Apple gaze-tracking lessons recorded

- Documentation-only follow-up; Phase 3 implementation was not started.
- Research synthesis: recorded the public distinction between iPadOS camera/ML-based accessibility Eye Tracking, the ARKit developer surface, and Apple Vision Pro's dedicated infrared hardware.
- Project guidance: retained the accepted selected-right ARKit route, calibration-specific held-out p90 radius gate, tracker/UI ownership boundary, setup invalidation rules, and privacy boundary.
- Proposed interaction lessons: documented Snap-to-Item-style assistance, independent cursor/hit-test filtering, and dwell hysteresis as UI/product proposals requiring change control rather than accepted implementation changes.
- Current gaps: recorded that the Phase 2 foundation still publishes no gaze point or usable quality, reports unknown setup, and needs Phase 3 calibration, mapping, held-out validation, quality gating, filtering, and invalidation behavior.
- Files changed: `GazeTracker/mdFiles/07-apple-gaze-tracking-lessons.md`, the planning index, and this execution ledger. No source code or `Slicing/` file changed.
- Stop reason: the requested documentation is complete; the next permitted implementation remains Phase 3 in a separate session.

### 2026-11-03 — Phase 2 exact-device retry passed the gate

- Phase worked: Phase 2 device verification only. Phase 3 was not started.
- Device: exact physical 13-inch iPad Air (M2), `iPad14,10`, UDID `00008112-000550C10A6BA01E`, iPadOS 27.0.1 build `24A446`, landscape.
- Installation/run: the existing signed arm64 iOS host installed successfully, launched through CoreDevice, and remained present in the target-device process list as PID `8708`.
- On-device contract evidence: a screenshot captured to volatile `/tmp` showed `Gaze Contract Host` and exactly the seven approved live categories. Initial output was point unavailable, nonzero monotonic timestamp, quality unavailable/0.0, tracking paused, setup unknown, calibration not calibrated, and no available eye. This correctly avoids a fabricated point before tracking/mapping.
- Privacy behavior: launch alone did not start camera capture or request permission. No screenshot or device artifact was added to the repository; source still contains no persistence, logging, networking, cache, analytics, or gaze-history path.
- Supporting evidence retained: 13/13 focused Swift tests pass; generic and signed exact-device builds pass; the generated contract interface contains no ARKit/AVFoundation import or framework type; `Slicing/` remains untouched.
- Gate result: **Phase 2 passed.** Phase 3 is the next permitted phase and must start in a new session. Work stops here under the one-phase-per-session rule.

### 2026-11-03 — Phase 2 implementation verified; device-run gate blocked

- Phase worked: Phase 2 only. Phase 3 was not started.
- Structure: created the `DrStrangeGazeTracker` Swift contract target, separate `DrStrangeGazeTrackerPlatform` ARKit adapter, focused tests, documentation, and the minimal `GazeTrackerDemo` iPad host. `Phase1Probe/` remains independent disposable evidence.
- Public boundary: `GazeSample` contains exactly the seven approved categories. The generated contract `.swiftinterface` has no ARKit/AVFoundation import or framework type. The calibration-specific radius remains absent and any future result handoff is documented as separate from live output and hit logic.
- Privacy/latency: no persistence, transmission, logging, analytics, cache, gaze-history, or frame/geometry exposure path exists. ARKit uses a dedicated user-interactive queue with direct publication and no main-thread hop, timer, smoothing buffer, or history queue. The known 56.374 ms p90 risk is documented.
- Automated evidence: 13/13 Swift tests passed; generic arm64 iOS host build passed; library-evolution interface build passed; signed exact-device build passed.
- Exact blocker: the paired `iPad14,10` repeatedly disconnected during CoreDevice installation, so the app was not installed or launched. A subsequent device-details query explicitly reported that a connection could not be established.
- Gate result: **blocked, not passed.** Resume Phase 2 with a stable USB/local-network device connection, install and launch the signed host, verify support and lifecycle/state publication on the exact iPad, record the evidence here, then stop at the Phase 2 gate. Phase 3 remains unauthorized.

### 2026-11-03 — Phase 2 module-boundary work started

- Phase worked: Phase 2 only. Phase 1 evidence is accepted as final and Phase 3 is not authorized in this session.
- Instructions: the request-supplied `AGENTS.md` references `@RTK.md`, but neither file exists in the checkout. All planning documents and all Phase 1 probe source/project files were read before implementation.
- Packaging decision: use a Swift Package library with framework-neutral public value types and an internal ARKit runtime, plus a separate minimal gaze-owned iPad demo host. This keeps the disposable `Phase1Probe/` intact and prevents probe mapping/diagnostic architecture from becoming the production boundary.
- Contract decision: the live `GazeSample` will contain exactly seven stored categories; calibration-result handoff and any future radius remain separate from live output. Phase 2 implements lifecycle/state contracts only, not Phase 3 calibration or mapping behavior.
- Device availability: Xcode 27.2 and Swift 6.4.2 are installed. The previously used exact target iPad is currently listed offline, so exact-device build/run evidence will be attempted only if it becomes available; this does not authorize simulator evidence as a substitute.

### 2026-11-03 — Phase 1 gate passed; selected-right ARKit chosen

- Phase worked: Phase 1 only. Phase 2 was **not** started.
- Exact evidence device: physical 13-inch iPad Air (M2), `iPad14,10`, iPadOS 27.0.1, mounted landscape. No iPhone or simulator evidence was used.
- Final route: ARKit selected anatomical right-eye transform with nine-position quadratic calibration and distinct held-out validation.
- Product acceptance: use the current calibration's held-out p90 radius only when it is finite and ≤8.0 cm. A larger radius fails calibration and requires retry; no universal fixed radius is claimed.
- Supported-state evidence: recorded selected-right runs achieved 100% directional agreement, 98.909–100% availability, 58.6–60 Hz sustained rates, approximately 16.05 s first-attempt calibration, and valid-state p90 radii from 3.885 cm to 7.795 cm. Modest head movement and typical lighting passed the revised operational criteria.
- Known performance risk: selected-right p90 latency passed in several runs (39.138–48.426 ms) but missed in two same-calibration validations (55.600 and 56.374 ms). Every maximum remained below 100 ms. This variance is recorded as a Phase 2 engineering risk, not relabeled as a universal pass.
- Invalidation: face loss with repositioning, remount, orientation change, material camera/viewing-position change, active-eye/patch-side change, and known setup changes require recalibration. The 12.794 cm post-face-loss result is excluded from the accepted calibrated state.
- Privacy: camera frames, gaze samples/paths, face geometry, calibration samples/parameters, identifiers, and gaze-linked timestamps were never persisted, transmitted, logged, cached, uploaded, or exposed. Only aggregate non-identifying results persisted; live output remains the seven approved categories.
- Accepted non-blocking backlog: both real opaque-patch sides, representative glasses, bright/dim lighting, 40–60 cm setup-state matrix, representative-session drift/reuse, pause/interruption behavior, and patch-presence verification. These are not passes and cannot support production claims.
- Gate result: **Phase 1 passed for Phase 2 foundation work under the explicit limits above.** Phase 2 is next and must begin in a new session. Work stops here under the one-phase-per-session rule.

### 2026-11-03 — Representative-session drift/reuse made non-blocking backlog

- Phase worked: Phase 1 requirement change control only; Phase 2 was not started.
- Product decision: defer representative-duration drift, pause, and AR-session-interruption reuse tests as accepted non-blocking backlog items.
- Evidence semantics: once-per-launch calibration stability is unproven and is **not a pass**. Existing immediate selected-right reuse and head-movement evidence remains valid, while face loss/repositioning is a demonstrated invalidation trigger.
- Conservative invalidation rules: always recalibrate after face loss with repositioning, remount, orientation change, material camera-position change, patch-side/active-eye change, or another known setup change. Pause/interruption handling remains unresolved backlog.
- Gate effect: missing representative-session drift/reuse evidence no longer prevents Phase 1 completion or Phase 2 start.
- Remaining blocking Phase 1 work is documentation/decision work: reconcile the selected-right directional, availability, rate, latency, calibration, recovery, and radius evidence; obtain final calibration-specific radius acceptance; reconfirm privacy; and record the final ARKit recommendation and Phase 1 gate result.

### 2026-11-03 — Remount made an unconditional invalidation trigger

- Phase worked: Phase 1 requirement change control only; Phase 2 was not started.
- Product decision: do not attempt to preserve or prove calibration across an iPad remount. Any remount, orientation change, or material camera-position change invalidates calibration and requires a new calibration.
- Gate effect: the prior remount test/backlog is removed as unnecessary because calibration survival is explicitly unsupported. This is a conservative behavior rule, not evidence that remount reuse works.
- Implementation requirement for later phases: detect or receive the setup change, discard the in-memory mapping, publish the existing uncalibrated/recalibration-required calibration state, and emit no calibrated gaze point until recalibration completes. The live public-output allowlist remains unchanged.
- Next physical evidence: representative-session reuse/drift with no remount, orientation change, material distance change, or face-loss invalidation event.

### 2026-11-03 — Remount variability made non-blocking backlog

- Phase worked: Phase 1 requirement change control only; Phase 2 was not started.
- Product decision: defer the physical `Remounted` calibration-reuse validation as an accepted non-blocking backlog item.
- Evidence semantics: remount survival remains unmeasured and is **not a pass**. Until tested, production behavior must conservatively invalidate calibration after an iPad remount, orientation change, or material camera-position change.
- Gate effect: missing remount evidence no longer prevents Phase 1 completion or Phase 2 start.
- Remaining blocking Phase 1 work: representative-session calibration reuse/drift/invalidation, final calibration-specific radius acceptance, reconciliation of operational pass/fail evidence, privacy confirmation, and the final selected-eye ARKit recommendation.
- Next physical evidence: reuse the current selected-right calibration through a representative session, then validate `Drift after representative use`. Phase 2 remains blocked until the remaining non-deferred gate work passes and is recorded.

### 2026-11-03 — Distance/setup-state matrix made non-blocking backlog

- Phase worked: Phase 1 requirement change control only; Phase 2 was not started.
- Product decision: defer the controlled below-40/around-40/around-60/above-60 cm setup-state recordings as an accepted non-blocking backlog item.
- Evidence semantics: no setup-state result is inferred. The provisional 40–60 cm ready band, distance estimation, and closer/farther behavior remain unvalidated and may not be claimed as supported.
- Gate effect: the missing distance/setup matrix no longer prevents Phase 1 completion or Phase 2 start. It remains a documented product risk and future validation item.
- Remaining blocking Phase 1 work: mount/remount variability, representative-session calibration reuse/drift/invalidation, final calibration-specific radius acceptance, reconciliation of operational pass/fail evidence, privacy confirmation, and the final selected-eye ARKit recommendation.
- Next physical evidence: perform the `Remounted` condition on the exact target iPad. Phase 2 remains blocked until the remaining non-deferred gate work passes and is recorded.

### 2026-11-03 — Backlog items made non-blocking for Phase 1

- Phase worked: Phase 1 requirement change control only; Phase 2 was not started.
- Product decision: real opaque-patch repeats for both sides, representative-glasses validation, and bright/dim supported-lighting variants are accepted as non-blocking backlog items.
- Evidence semantics: these conditions remain unmeasured and are **not passes**. Do not claim that the current candidate detects a patch or is validated with a real patch, representative glasses, or broad lighting variation.
- Gate effect: missing evidence for those three groups no longer prevents Phase 1 completion or Phase 2 start. Their associated risks remain open and must be resolved before claiming production support for those conditions.
- Remaining blocking Phase 1 work at that decision point included distance/setup states, mount/remount and comfortable-distance behavior, representative-session calibration reuse/drift/invalidation, final calibration-specific radius acceptance, reconciliation of operational pass/fail results, privacy confirmation, and the final selected-eye ARKit recommendation. The later entry above subsequently moved distance/setup states to the non-blocking backlog.
- Next physical evidence: record the four distance/setup conditions using the exact mounted target iPad. Phase 2 remains blocked until the remaining non-deferred gate work passes and is recorded.

### 2026-11-03 — Bright/dim lighting variants deferred

- Phase worked: Phase 1 planning/ledger update only; Phase 2 remains blocked.
- Backlog decision: defer—not silently pass—the `Bright lighting` and `Dim supported lighting` validations at the operator's request. The completed `Typical lighting` pass remains valid evidence.
- Gate effect: Phase 0 requires support for reasonable room-lighting variation. Phase 1 cannot be marked complete while bright/dim evidence is absent unless that requirement is explicitly revised through change control.
- Calibration state: the selected-right typical-lighting calibration may remain in volatile memory, but no lighting result is inferred from it without a completed validation run.
- Next available evidence: distance/setup-state checks around and outside the provisional 40–60 cm ready band, followed by remount and representative-session drift work.
- Existing backlog: representative glasses, both sides with a real opaque patch, and now bright/dim lighting remain incomplete. Phase 2 was not started.

### 2026-11-03 — Selected-right typical-lighting result

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Device/setup: exact target 13-inch iPad Air (M2), `iPad14,10`, iPadOS 27.0.1, mounted landscape, approximately 40 cm, both eyes uncovered, no glasses, source `anatomicalRightEye`, build 12 / `phase1-arkit-selected-eye-9point-v8`.
- Privacy: inspected only the protected schema-4 aggregate. No camera frames, face geometry, calibration samples/parameters, gaze samples/paths, identifiers, or gaze-linked timestamps were retrieved or persisted.
- Calibration reset: the degraded post-face-loss calibration was replaced. A fresh selected-right calibration under `typicalLighting` succeeded on the first attempt in 16.055 s — **pass**.
- Held-out result: 20/20 fixations; directional agreement 100% with movement-gain median 1.000 / p90 1.115 — **pass**. Availability was 100% — **pass**. Update rate was 60 Hz median, p10, and sustained minimum — **pass**.
- Publication latency: 38.847 ms median / 39.138 ms p90 / 39.582 ms worst — **pass**.
- Spatial diagnostics: accuracy was 3.977° median / 5.249° p90 / 5.478° worst; p90 radius was 203.113 logical points or 3.885 cm. Precision also passed the historical diagnostic at 0.390° median / 1.275° p90 / 1.532° worst.
- Decision: typical room lighting passes all revised operational criteria and produced the strongest recent selected-right radius. This single calibration does not settle universal-radius acceptance. Retain it for controlled bright-then-dim lighting reuse tests; do not recalibrate between those lighting conditions unless tracking becomes unavailable or the physical setup changes.

### 2026-11-03 — Representative-glasses test deferred

- Phase worked: Phase 1 planning/ledger update only; Phase 2 remains blocked.
- Backlog decision: defer—not waive—the selected-right representative-glasses condition at the operator's request. Resume it when representative glasses/test conditions are available.
- Calibration safety: the calibration degraded by the preceding face-loss/reposition run and must be explicitly invalidated before any subsequent condition. It must not be reused for lighting or other robustness evidence.
- Next available evidence: recalibrate `Selected anatomical right eye` at approximately 40 cm under typical lighting, validate `Typical lighting`, then test the supported bright and dim lighting conditions using the protocol's required calibration/reuse controls.
- Unchanged blockers: both real opaque-patch sides and representative glasses remain required before the Phase 1 gate can pass. Phase 2 was not started.

### 2026-11-03 — Selected-right brief-face-loss result

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Device/setup: exact target 13-inch iPad Air (M2), `iPad14,10`, iPadOS 27.0.1, mounted landscape, approximately 40 cm, both eyes uncovered, source `anatomicalRightEye`, build 12 / `phase1-arkit-selected-eye-9point-v8`. The preceding calibration was intentionally retained.
- Privacy: inspected only the protected schema-4 aggregate. No camera frames, face geometry, calibration samples/parameters, gaze samples/paths, identifiers, or gaze-linked timestamps were retrieved or persisted.
- Event evidence: all three deliberate face-loss events were detected. On each event, the first frame on which ARKit re-detected a face also produced a valid public sample, recorded as 0 ms at frame resolution. This does **not** measure the physical return-to-ARKit-detection interval, so the recovery claim is limited to re-detection-to-publication behavior.
- Held-out result: 19 valid fixation aggregates; directional agreement 77.778% — **fail** against ≥80%. Availability was 88.261% with 11.739% `none` — **fail** against ≥95%. Update rate remained a **pass** at 60 Hz median / 49.9 Hz sustained minimum.
- Publication latency: 52.105 ms median / 52.432 ms p90 / 58.750 ms worst — p90 **fail**, maximum **pass**.
- Spatial diagnostics: accuracy was 8.534° median / 15.669° p90 / 24.817° worst; p90 radius was 664.432 logical points or 12.794 cm. Precision was 1.137° median / 3.053° p90. The retained calibration degraded materially after face loss/reposition.
- Invalidation decision: brief face loss accompanied by user repositioning is a calibration invalidation trigger for this candidate. Do not continue subsequent robustness tests with this calibration; explicitly invalidate and recalibrate under the next physical condition.
- Interpretation boundary: this run proves prompt valid-sample publication once ARKit reports the face again, but it does not prove ≤1 s physical reacquisition latency. A separate externally marked protocol would be required for that exact duration.

### 2026-11-03 — Selected-right modest-head-movement result

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Device/setup: exact target 13-inch iPad Air (M2), `iPad14,10`, iPadOS 27.0.1, mounted landscape, approximately 40 cm, both eyes uncovered, source `anatomicalRightEye`, build 12 / `phase1-arkit-selected-eye-9point-v8`.
- Privacy: inspected only the protected schema-4 aggregate. No camera frames, face geometry, calibration samples/parameters, gaze samples/paths, identifiers, or gaze-linked timestamps were retrieved or persisted.
- Calibration: the new build's first `around40cm` attempt succeeded in 16.062 s — **pass**. The calibration was retained while changing the engineering condition to `headMovement`.
- Held-out result: 20 fixations; 100% directional agreement and movement-gain median 0.851 / p90 1.214 — **pass**. Availability was 99.591% — **pass**. Update rate was 60 Hz median / 58.8 Hz p10 / 59.1 Hz sustained minimum — **pass**.
- Publication latency: 44.735 ms median / 45.090 ms p90 / 47.650 ms worst — **pass** against the 50 ms p90 and 100 ms maximum limits.
- Spatial diagnostics: accuracy was 5.071° median / 8.607° p90 / 9.652° worst; p90 radius was 335.437 logical points or 6.511 cm. Precision median passed the historical diagnostic at 0.872°, while p90 failed it at 3.320°. Accuracy/precision remain diagnostics under the revised interaction-fit rule.
- Recovery observation: two natural blink events returned a valid sample on the first reopened frame; no deliberate face-loss event occurred, so face recovery remains unmeasured.
- Decision: modest head movement passes the current directional, availability, rate, and latency criteria for selected-right ARKit. The 6.511 cm radius is encouraging but remains subject to product/UI acceptance and does not establish a universal envelope. Continue the non-patch robustness matrix; do not begin Phase 2.

### 2026-11-03 — Build 12 selected-right default installed

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Configuration alignment: changed the default non-patch active source from `anatomicalLeftEye` to `anatomicalRightEye`, matching the latest immediate same-calibration comparison. Patch conditions continue to force the anatomically uncovered eye and are unchanged.
- Build/install: incremented the disposable probe to build 12; the arm64 device build completed successfully, passed strict code-sign verification, installed over the existing probe, and launched on the exact 13-inch iPad Air (M2).
- Expected reset: installation/relaunch cleared the volatile in-memory calibration. No aggregate evidence was deleted, and no camera frame, face geometry, calibration sample, or gaze sample was persisted or transferred.
- Planned next evidence was a selected-right `Modest head movement` held-out run without recalibration; that run is now completed and recorded in the session entry above.

### 2026-11-03 — Selected-right-eye immediate same-calibration comparison

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Device/setup: exact target 13-inch iPad Air (M2), `iPad14,10`, iPadOS 27.0.1, mounted landscape, approximately 40 cm, both eyes uncovered, source `anatomicalRightEye`, algorithm `phase1-arkit-selected-eye-9point-v8`.
- Privacy: inspected only schema-4 aggregate output from the protected app container. No camera frames, face geometry, calibration samples/parameters, gaze samples/paths, identifiers, or gaze-linked timestamps were retrieved or persisted.
- Calibration: one 9-position calibration succeeded on the first attempt in 16.064 s — **pass** against the ≤30 s duration target.
- First held-out validation: 100% directional agreement; 99.500% availability; 60 Hz median / 58.9 Hz sustained-minimum update rate — **pass**. Accuracy was 6.222° median / 9.075° p90; precision was 1.048° median / 3.771° p90; the calibration-specific p90 radius was 402.328 points or 7.795 cm. Publication latency was 55.311 ms median / 55.600 ms p90 / 56.545 ms worst — p90 **fail**, maximum **pass**.
- Immediate same-calibration validation: 100% directional agreement; 99.773% availability; 60 Hz median / 59.5 Hz sustained-minimum update rate — **pass**. Accuracy was 5.126° median / 8.194° p90; precision was 0.446° median / 0.641° p90; p90 radius was 366.859 points or 7.056 cm. Publication latency was 56.101 ms median / 56.374 ms p90 / 57.085 ms worst — p90 **fail**, maximum **pass**.
- Repeatability: radius changed from 7.795 cm to 7.056 cm, a 9.5% decrease. This is materially more consistent than the selected-left pair's 46.7% increase and the rejected 15-position pair's 39.6% increase. Movement gain was also similar across runs: median 0.876 then 0.843; p90 1.122 then 1.142.
- Interpretation: selected anatomical right is the strongest current source for immediate within-calibration directional/reuse consistency, but this single pair does not establish a universal absolute-gaze envelope. Both radii are materially larger than the earlier 4.726 cm selected-right exploratory result, and product/UI acceptance of a roughly 7.8 cm conservative calibration-specific radius remains pending.
- Decision: retain selected-right ARKit as the preferred source for the next non-patch robustness checks. Do not claim Phase 1 pass, stable point accuracy, or accepted radius. The real opaque-patch repeats remain backlogged and required; glasses, lighting, head movement, face recovery, distance/setup, remount, and longer-session drift remain incomplete.

### 2026-11-03 — Fifteen-position selected-left calibration result

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Device/setup: exact target iPad Air 13-inch (M2), iPadOS 27.0.1, landscape, approximately 40 cm, both eyes uncovered, source `anatomicalLeftEye`, algorithm `phase1-arkit-selected-eye-15point-v7`.
- Privacy: inspected only the permitted schema-4 aggregate file `phase1-arkit-selected-eye-15point-aggregate-results.json`; no raw/reconstructable camera, face, calibration, or gaze data was retrieved or persisted.
- Calibration: 15/15 positions completed successfully on the first attempt in 26.766 s — **pass** against the ≤30 s median duration target.
- First held-out validation: 100% directional agreement, 100% availability, 60 Hz sustained rate, 40.931 ms p90 / 49.906 ms max latency — all **pass**. Accuracy was 5.064° median / 9.449° p90; p90 radius was 380.506 points or 7.317 cm. Precision passed the original diagnostic at 0.614° median / 1.234° p90.
- Immediate same-calibration validation: 100% directional agreement, 100% availability, 60 Hz sustained rate, 42.357 ms p90 / 50.985 ms max latency — all **pass**. Accuracy was 6.164° median / 12.809° p90; p90 radius was 530.214 points or 10.213 cm. Precision was 0.441° median / 2.737° p90.
- Repeatability: the same 15-position calibration's radius increased from 7.317 cm to 10.213 cm, a 39.6% increase. Absolute point placement remained unstable even though direction, availability, rate, and latency were consistently strong.
- Comparison with 9 positions: adding six calibration locations increased duration from approximately 16 s to 26.766 s and did not recover the earlier best 2.695–4.726 cm exploratory envelope or solve consecutive-validation drift.
- Decision: **reject 15 positions as an improvement for the current quadratic selected-eye mapping**. Calibration-point count is not the root cause of absolute repeatability failure. Stop adding calibration points; preserve this evidence and return to the smaller 9-position selected-eye harness for subsequent directional robustness testing.
- Product implication: ARKit remains strong for directional movement but has not demonstrated a stable absolute radius. Any design requiring repeatable point hit testing needs either a conservatively larger accepted envelope, a different mapping/hardware route, or a directional-only interaction decision owned outside the tracker.
- Restoration: source returned to the 9-position selected-eye matrix as `phase1-arkit-selected-eye-9point-v8`, build 11, with a new aggregate filename that preserves both earlier 9-position and rejected 15-position result files. Build 11 compiled, passed strict code-sign verification, installed, and launched on the exact iPad; older probe processes were stopped and process inventory confirmed only build 11 remains running.

### 2026-11-03 — Fifteen-position selected-eye calibration experiment

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Authorized change: test whether additional spatial constraints improve selected-eye calibration/reuse repeatability. No production architecture, smoothing, implicit recalibration, ML, or game/UI behavior was added.
- Algorithm/build: `phase1-arkit-selected-eye-15point-v7`, build 10.
- Calibration protocol: expanded only the unique calibration positions from 9 to 15 using a 5×3 landscape grid at x = 5%, 27.5%, 50%, 72.5%, 95% and y = 5%, 50%, 95%. Rows use a serpentine order to avoid unnecessary full-width target jumps.
- Controlled constants: five-term quadratic, selected anatomical eye source, 1.75 s target timing, distinct randomized 20-fixation held-out validation, aggregate calculations, setup bounds, public output, and all privacy controls are unchanged.
- Expected duration: approximately 26.25 s for 15 targets, within the ≤30 s median calibration target if runtime overhead remains small.
- Evidence isolation: build 10 writes `phase1-arkit-selected-eye-15point-aggregate-results.json`; the prior 9-position aggregate file remains untouched in the app container.
- Acceptance experiment: at approximately 40 cm with `Selected anatomical left eye`, calibrate once, validate twice without recalibrating, and compare directional agreement, p90 radius, availability, rate, latency, and same-calibration repeatability against build 9.
- Verification: build 10 compiled for arm64, passed strict code-sign verification, installed over the selected-eye probe, and launched on the exact 13-inch iPad Air (M2). Process inventory confirmed only this probe is running. Physical calibration and consecutive-validation measurements remain pending.

### 2026-11-03 — Apple built-in Eye Tracking calibration comparison

- Phase worked: Phase 1 research/change consideration only; Phase 2 remains blocked. No Apple accessibility data or camera output was accessed, and the probe was not changed in this step.
- Official Apple behavior: built-in Eye Tracking asks the user to follow a dot that appears at different screen locations, requires calibration whenever Eye Tracking is enabled, can automatically request recalibration after face/iPad position changes, and exposes smoothing plus Snap to Item. Apple does not document a fixed calibration-point count or expose this system calibration as a developer gaze API.
- Independent count evidence: current AbleNet accessibility setup guidance describes Apple's flow as a 15-point calibration; another observed iOS implementation reports 13 positions. These are not Apple API guarantees and may vary by device/OS.
- Probe clarification: selected-eye v6 currently uses **9 unique calibration positions** in a 3×3 grid. The fitted quadratic has five input terms plus an intercept—six coefficients per output axis—which may be the source of the apparent “6-point” confusion.
- Engineering implication: nine positions already overdetermine the six-coefficient fit, but a 15-position landscape grid would provide more spatial constraints and may reduce calibration variance. Using the current 1.75 s per target would take approximately 26.25 s, still inside the ≤30 s median calibration target.
- Important comparison limit: Apple's system also uses undisclosed on-device modeling, smoothing, automatic recalibration, and optional item snapping; its behavior cannot be attributed to point count alone or reproduced by copying a dot count.
- Recommended next experiment: before abandoning selected-eye absolute mapping, compare a 15-position landscape calibration against the same distinct held-out targets and two consecutive validations. Preserve the accepted privacy boundary and treat the current 9-position evidence as historical rather than overwriting it.

### 2026-11-03 — Selected-left-eye immediate same-calibration repeat

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Protocol: reused the exact selected-left-eye `around40cm` calibration from the preceding run; no recalibration, deliberate blinks, source change, or condition change.
- Held-out result: 20/20 fixation aggregates; directional agreement remained 100%, movement-gain median 0.990 and p90 1.308 — revised directional criterion **pass**.
- Availability: 98.636% — **pass**. Update rate: 60.0 Hz median, 58.1 Hz sustained minimum, 53.0 Hz p10 — **pass**.
- Publication latency: 54.061 ms median, 54.447 ms p90, 61.924 ms maximum — p90 **fail**, maximum within 100 ms.
- Accuracy/radius diagnostic: 6.980° median / 9.446° p90 / 10.691° worst; p90 radius 407.713 logical points or 7.726 cm. Precision was 0.689° median / 3.969° p90.
- Same-calibration comparison: the first validation measured 5.267 cm p90 radius; the immediate repeat measured 7.726 cm, a 46.7% increase without recalibration. Direction remained correct, but absolute point placement was not repeatable.
- Decision: **immediate calibration reuse fails against the previously accepted selected-left envelope**. The original 2.695 cm result is not reproducible enough to serve as a universal radius, and a radius derived from one held-out run is not yet dependable for subsequent absolute hit testing.
- Interpretation boundary: this does not invalidate the 100% directional-movement result. It does invalidate any claim that the current selected-left calibration provides a stable absolute gaze radius through a representative session.
- Next diagnostic: test selected anatomical right eye with both eyes uncovered at approximately 40 cm using one calibration and two consecutive held-out validations. This determines whether repeatability failure is eye/source-specific before a product decision on a larger radius or directional-only interaction.

### 2026-11-03 — Selected-left-eye no-deliberate-blink control repeat

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Device/setup: exact target iPad, landscape, approximately 40 cm, condition `around40cm`, source `anatomicalLeftEye`, both eyes uncovered, no deliberate blink schedule.
- Calibration: first attempt succeeded in 16.055 s — **pass**.
- Held-out result: 20/20 fixation aggregates; directional agreement 100%, movement-gain median 0.906 and p90 1.066 — **pass**.
- Availability: 97.818% — **pass**; six natural/detected blink events again recovered on the first valid reopened frame (0 ms at frame resolution).
- Update rate: 60.0 Hz median, 57.4 Hz sustained minimum, 53.0 Hz p10 — **pass**.
- Publication latency: 51.900 ms median, 52.261 ms p90, 59.488 ms maximum — **fail** against the 50 ms p90 target, while maximum remains within 100 ms.
- Accuracy/radius diagnostic: 3.750° median / 6.382° p90 / 7.677° worst; p90 radius 274.208 logical points or 5.267 cm. Precision was 0.945° median / 4.219° p90.
- Comparison with controlled-blink run: radius improved from 11.317 cm to 5.267 cm and p90 accuracy from 14.933° to 6.382°, indicating the deliberate-blink validation procedure contributed materially to the prior spatial regression.
- Repeatability concern: 5.267 cm remains almost twice the earlier selected-left exploratory radius of 2.695 cm. This could reflect calibration bias, validation behavior, posture/setup variation, or ARKit single-eye variability; one more validation using the **same current calibration** is required to separate calibration-to-calibration variation from immediate validation-repeat variation.
- Next action: do not recalibrate. Repeat `Validate held-out targets` once under the same 40 cm posture/source/condition with no deliberate blinks, then compare the two runs sharing one calibration.

### 2026-11-03 — Selected-left-eye controlled blink recovery

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Device/setup: exact required 13-inch iPad Air (M2), `iPad14,10`, iPadOS 27.0.1, landscape, approximately 40 cm, condition `blinkRecovery`, source `anatomicalLeftEye`, both eyes uncovered.
- Privacy: inspected only schema-4 permitted aggregate output; no raw camera, face, calibration, or gaze data was retrieved or persisted.
- Calibration: first attempt succeeded in 16.061 s — **pass**.
- Controlled events: six blinks were detected (five requested plus one additional/natural event). Recovery median/p90/worst were all 0 ms under the frame-level definition, meaning the first frame classified as reopened also produced a valid public sample — **pass** against p90 ≤250 ms, with frame-resolution caveat.
- Availability: 96.773% with 3.227% selected-eye `none` during the blink run — **pass** against ≥95%.
- Directional agreement: 100%; movement-gain median 0.934 and p90 1.260 — **pass**.
- Update rate: 60.0 Hz median, 56.5 Hz sustained minimum, 47.6 Hz p10 — **pass**.
- Publication latency: 49.201 ms median, 49.544 ms p90, 53.506 ms maximum — **pass** against p90 ≤50 ms and maximum ≤100 ms.
- Precision: 0.895° median passes the historical median diagnostic; 3.513° p90 fails the historical p90 diagnostic.
- Spatial regression: accuracy was 5.886° median / 14.933° p90 / 17.054° worst, with a p90 radius of 589.433 logical points or 11.317 cm. Direction remains correct, but this is materially worse than the accepted exploratory selected-left envelope of 2.695 cm.
- Decision: accept the controlled blink-recovery evidence, but do **not** accept or silently expand the interaction radius from this run. Before another robustness condition, repeat a no-deliberate-blink selected-left 40 cm calibration/validation in build 9 to distinguish calibration/run variance from blink-protocol impact.

### 2026-11-03 — Real-patch repeats backlogged; selected-eye robustness matrix enabled

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Backlog decision: defer—not waive—the real opaque-patch repeat for both sides until the operator obtains a patch. The Phase 1 patch task remains incomplete and explicitly blocked on equipment availability.
- Next authorized work: continue non-patch Phase 1 robustness evidence, beginning with controlled blink recovery on the strongest exploratory source, the selected anatomical left eye.
- Harness change: `phase1-arkit-selected-eye-matrix-v6`, build 9, separates active gaze source from engineering condition. Patch conditions still force the anatomically uncovered eye; non-patch conditions can now exercise selected left, selected right, or fused baseline without silently changing algorithms.
- Calibration safety: changing active eye or entering/leaving/changing a patch condition invalidates calibration. Ordinary non-patch condition changes retain calibration only so the planned reuse/drift experiment can be measured intentionally.
- Scope/privacy: no ML, camera-frame access, game logic, public-output expansion, or `Slicing/` change. Aggregate schema and volatile processing rules remain unchanged.
- Verification: build 9 compiled for arm64, passed strict code-sign verification, installed over the selected-eye probe, and launched on the exact 13-inch iPad Air (M2). The next physical evidence is a `Blink recovery` calibration/validation using `Selected anatomical left eye` at approximately 40 cm.
- Runtime isolation: iPadOS had relaunched three older probe processes after installation; all three were terminated and process inventory confirmed only build 9 remains running before the blink test.

### 2026-11-03 — Product acceptance of revised interaction-fit envelope

- Phase worked: Phase 1 requirement change control only; Phase 2 remains blocked.
- Product decision: the original ≤2° median point-accuracy and ≤2° p90 precision limits are no longer hard rejection criteria for the revised one-target gameplay interaction. Accuracy and precision remain mandatory reported diagnostics and their historical results remain failures under the original Phase 0 targets.
- Accepted rationale: reliable directional eye movement is the required tracker behavior; the UI/game team may consume a calibration-specific radius derived from held-out p90 radial error. This is an interaction decision, not evidence that patching or eye movement produces a therapeutic outcome.
- Revised candidate requirement: directional agreement ≥80% in every required supported condition, an explicitly accepted held-out p90 radius, and unchanged availability/rate/latency/calibration/recovery/setup/privacy/failure-state requirements.
- Current product acceptance: the exploratory exact-device selected-eye radii of 4.726 cm for the selected anatomical right eye and 2.695 cm for the selected anatomical left eye are acceptable for continued Phase 1 testing.
- Remaining limits: hand occlusion does not satisfy the real-patch gate; a materially different radius in real-patch or representative-user testing needs renewed product/UI acceptance. Phase 1 is not complete.

### 2026-11-03 — Selected anatomical left-eye exploratory result and side comparison

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Device/setup: exact required 13-inch iPad Air (M2), `iPad14,10`, iPadOS 27.0.1, mounted landscape, approximately 40 cm, condition `patchRight`, gaze source `anatomicalLeftEye`.
- Evidence classification: **exploratory monocular result** because a real opaque patch was not confirmed. Patch presence remained `notMeasured`; both recorded patch conditions do not constitute final patch-gate completion.
- Privacy: inspected only schema-4 permitted non-identifying aggregates; no raw or reconstructable camera, face, calibration, or gaze data was retrieved or persisted.
- Calibration: first attempt succeeded in 16.063 s — duration **pass**.
- Held-out validation: 20/20 fixations produced aggregates.
- Directional agreement: 100%; movement-gain median 1.016 and p90 1.073 — **pass** and close to unit response.
- Availability: 99.545% — **pass**; configured active-eye distribution was 99.545% `leftOnly` and 0.455% `none`. This is declared-active-eye availability, not patch detection.
- Update rate: 60.0 Hz median, 59.7 Hz sustained minimum, 58.8 Hz p10 — **pass**.
- Publication latency: 48.067 ms median, 48.426 ms p90, 48.704 ms maximum — **pass**.
- Legacy accuracy diagnostic: 2.458° median **fail** against ≤2°; 3.527° p90 **pass** against ≤4°; 3.993° worst. Center/edge/corner medians 1.556°/2.519°/2.950° all **pass** against ≤3°. Combined original accuracy target remains **fail** because its median exceeds 2°.
- Precision: 0.497° median **pass**; 4.067° p90 **fail** against ≤2°; combined original precision target **fail**.
- Adaptive p90 radius: 3.527°, 140.366 logical points, or 2.695 cm.
- Side comparison: selected left eye improved over selected right eye from 3.172° to 2.458° median accuracy, 5.951° to 3.527° p90 accuracy, and 4.726 cm to 2.695 cm p90 radius. Both maintained 100% directional agreement and passed availability, update rate, latency, and calibration duration.
- Fused-baseline comparison: selected left eye reduced the 40 cm fused route's 6.291 cm radius by approximately 57%; selected right eye reduced it by approximately 25%.
- Interpretation: monocular selection is the strongest ARKit configuration tested for the revised directional/radius use case, especially the selected anatomical left eye. The side asymmetry may reflect run variation, hand occlusion, eye dominance, or genuine transform quality and cannot be generalized from one adult exploratory run.
- Required next evidence: repeat both sides with a real opaque patch, then complete controlled blink/face recovery, head movement, glasses, lighting, setup-distance, remount, calibration reuse/drift/invalidation, and product/UI radius acceptance before any Phase 1 pass decision.

### 2026-11-03 — Selected anatomical right-eye exploratory result

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Device/setup: exact required 13-inch iPad Air (M2), `iPad14,10`, iPadOS 27.0.1, mounted landscape, approximately 40 cm, condition `patchLeft`, gaze source recorded as `anatomicalRightEye`.
- Evidence classification: **exploratory monocular result** because a real opaque patch was not confirmed. Patch presence remained explicitly `notMeasured`; the configured active-eye result must not be described as automatic patch detection.
- Privacy: inspected only schema-4 permitted aggregates from `phase1-arkit-selected-eye-aggregate-results.json`; no raw or reconstructable camera, face, calibration, or gaze data was retrieved or persisted.
- Calibration: first attempt succeeded in 16.063 s — duration **pass**.
- Held-out validation: 20/20 fixations produced aggregates.
- Directional agreement: 100%; movement-gain median 1.042 and p90 1.274 — **pass** for the revised directional criterion.
- Availability: 98.909% — **pass**; configured active-eye distribution was 98.909% `rightOnly` and 1.091% `none`. `patchEyeAvailability` passes only as declared-active-eye availability, not as patch-presence verification.
- Update rate: 60.0 Hz median, 58.6 Hz sustained minimum, 55.0 Hz p10 — **pass**.
- Publication latency: 45.609 ms median, 45.947 ms p90, 46.254 ms maximum — **pass**.
- Legacy accuracy diagnostic: 3.172° median, 5.951° p90, 6.618° worst; center/edge/corner medians 4.140°/3.595°/2.928° — **fail** against the original strict target.
- Precision: 0.838° median **pass**, 4.284° p90 **fail**; combined original precision target **fail**.
- Adaptive p90 radius: 5.951°, 245.925 logical points, or 4.726 cm. This improves over the fused 40 cm baseline's 8.681°/327.925 points/6.291 cm, while p90 precision is slightly worse (4.284° vs 4.097°).
- Interpretation: selecting the right-eye transform materially improved tail accuracy/radius while retaining strong directional movement and performance in this exploratory run. It is not sufficient for a gate decision until repeated with a real patch and compared with the selected anatomical left eye.
- Next measurement: `Right eye patched` / `anatomicalLeftEye` at approximately 40 cm; changing the condition must invalidate and repeat calibration.

### 2026-11-03 — Selected-uncovered-eye ARKit probe implementation

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Authorized change: build the smallest disposable ARKit experiment that uses only the user-declared uncovered eye during a patch condition. No ML, production module, or game/UI behavior was authorized.
- Algorithm: `phase1-arkit-selected-eye-quadratic-v5`. Non-patch baselines retain the measured v4 fused `lookAtPoint` quadratic. `Left eye patched` uses only `rightEyeTransform`; `Right eye patched` uses only `leftEyeTransform`, each through the same bounded five-term quadratic.
- Calibration binding: changing the engineering condition immediately invalidates the fitted model. Each patch side must be calibrated independently.
- Availability semantics: in patch conditions, `eyeAvailability` reports whether the declared active anatomical eye is open/usable; it does not claim the external patch is detected. Aggregate output explicitly records `patchPresenceVerification: notMeasured`.
- Privacy/public boundary: unchanged. Camera frames, eye transforms, face geometry, calibration samples, gaze samples/paths, and timestamps remain volatile; only schema-4 non-identifying aggregates may persist. The seven-field live output remains unchanged.
- Isolation: build 8 uses bundle ID `com.chandra.DrStrange.Phase1ARKitSelectedEyeProbe` and aggregate file `phase1-arkit-selected-eye-aggregate-results.json`, preserving the previously installed v4 container and results.
- Verification state: build 8 compiled for arm64, passed strict code-sign verification, installed under the isolated bundle ID, and launched on the exact 13-inch iPad Air (M2). Three older probe processes were terminated before launch to prevent camera contention. Anatomical transform behavior and both patch-side measurements remain pending physical validation.
- Exact-device selected-eye regression: **pass for physical-left-patched mode**. With `Left eye patched` selected, both eyes open reported `rightOnly`; closing only the physical left eye remained `rightOnly`; closing only the selected physical right eye changed availability to `none`. This proves the declared active-eye/blink mapping behaves anatomically on the mounted landscape device. It does not verify external patch presence or yet prove gaze accuracy from the selected transform.

### 2026-11-03 — Selected-uncovered-eye ARKit feasibility

- Phase worked: Phase 1 feasibility only; Phase 2 remains blocked. No implementation or new measurement was started.
- Feasibility: ARKit exposes distinct `leftEyeTransform` and `rightEyeTransform` matrices. The tracker can therefore use a declared patch side to select only the anatomically uncovered eye: physical left eye patched → right-eye transform; physical right eye patched → left-eye transform.
- Current-probe impact: optimized v4 currently fits its gaze mapping from `lookAtPoint`, which Apple defines as an abstraction over both eye transforms. A valid monocular experiment requires a new calibration model fitted only from the selected uncovered eye's direction, with separate calibration after every patch-side change.
- Expected benefit: prevents the gaze mapping from directly consuming the covered eye's estimated transform. It may be sufficient if the product only needs gaze from a user/caregiver-declared active eye.
- Limitation: selecting one transform does **not** detect or verify that a patch is present, and ARKit can continue producing a finite transform for an occluded eye. If patch compliance/removal detection is a requirement, the selected-eye route still needs independent visual verification such as the proposed volatile-memory sidecar classifier.
- Required evidence: implement only as a disposable Phase 1 candidate, then calibrate and validate both physical patch sides on the exact iPad at approximately 40 cm; compare directional agreement, radius, precision, availability, latency, and transform stability against the current fused `lookAtPoint` route before selection.

### 2026-11-03 — On-device patch-detector feasibility decision point

- Phase worked: Phase 1 planning/feasibility only; Phase 2 remains blocked. No ML model, training dataset, camera capture, or new persisted output was created.
- Feasibility: the existing ARKit session exposes each camera frame as a `CVPixelBuffer`; Vision can run a `VNCoreMLRequest` with a custom Core ML image classifier. A low-rate sidecar classifier can therefore coexist with the 60 Hz ARKit gaze route on the target iPad, subject to measured latency/thermal impact.
- Recommended classes: `noPatch`, `leftPatch`, `rightPatch`, and `uncertain`. Require a confidence threshold plus temporal agreement before changing public eye availability; never force a confident label from an uncertain frame.
- Privacy contract: inference must remain entirely on device and in volatile memory. Do not persist, log, cache, transmit, upload, or expose frames, eye crops, face geometry, per-frame predictions, or confidence histories. Persist only non-identifying aggregate confusion-matrix/performance results that cannot reconstruct a gaze or image sequence.
- Public contract: keep ARKit gaze output unchanged. The sidecar may influence only existing confidence/quality, tracking state, and anatomical eye availability; it must not add face geometry, framework objects, patch imagery, or new live diagnostic fields.
- Validation requirement: train and evaluate on representative patch styles/colors, no-patch faces, both sides, glasses, lighting, distance, head pose, skin tones, hair/hand/shadow confounders, and—before production claims—the intended 5–7 age range under approved consent/data governance. Adult-only internal evidence is insufficient for the final user population.
- Decision: technically feasible and preferred over pretending ARKit blink coefficients sense occlusion, but **not yet authorized for implementation**. This is a change to the earlier no-custom-ML fallback decision and requires explicit Phase 1 change control, a lawful representative dataset source, acceptance thresholds, and privacy review before any model is built or integrated.

### 2026-11-03 — ARKit one-eye hand-occlusion pre-check

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Exact-device observation: with the physical left eye covered by the operator's hand, the optimized ARKit probe continued to publish `eyes: both`.
- Interpretation: **failed occlusion detection pre-check**. The current eye-availability heuristic is derived from ARKit `eyeBlinkLeft`/`eyeBlinkRight`; those coefficients can continue describing an estimated open eye when the eye is externally occluded. They are not proof that an anatomical eye is visually observable.
- Evidence limitation: a hand is not accepted as the final opaque-patch condition because it can obscure additional face geometry and move. No patch-side calibration/validation result was recorded from this pre-check.
- Immediate action: do not run or claim the patched-eye gate with the current heuristic. Repeat the observation with a real opaque eye patch. If ARKit still reports `both`, the project must explicitly choose between a separately validated volatile-memory occlusion detector and treating patch side as a declared setup input with appropriate verification; it must not relabel configured intent as sensed availability.

### 2026-11-03 — Optimized ARKit 45 cm baseline and distance comparison

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Device: exact required 13-inch iPad Air (M2), model `iPad14,10`, running iPadOS 27.0.1, mounted in landscape; viewport 1366×1024 logical points.
- Requested test conditions: approximately 45 cm, both eyes open, no glasses, ordinary supported indoor lighting, comfortable steady head position. Condition recorded by the probe: `nominal45cm`.
- Privacy: inspected only schema-3 permitted aggregate results; no raw or reconstructable gaze/camera/face data was retrieved or retained.
- Calibration: first attempt succeeded in 16.065 s — duration **pass** and first-attempt success **pass for this attempt**.
- Held-out validation: 20/20 fixations produced aggregates.
- Legacy accuracy diagnostic: median 3.230°, p90 9.655°, worst 15.511°; center/edge/corner medians 2.657°/2.683°/3.886° — **fail** against the provisional overall median/p90 and per-region requirements.
- Precision: median RMS 2.222°, p90 RMS 6.506° — **fail** against ≤1° median and ≤2° p90.
- Availability: 98.091% — **pass** against ≥95%; eye-state distribution was 98.091% `both`, 1.909% `none`, 0% one-eye states.
- Update rate: 60.0 Hz median, 57.8 Hz sustained minimum, 55.2 Hz p10 — **pass** against ≥30 Hz.
- Publication latency: 50.641 ms median, 50.974 ms p90, 51.309 ms maximum — **fail** against p90 ≤50 ms, while maximum remains within ≤100 ms.
- Revised interaction-fit evidence: directional agreement 100% — **pass** against provisional ≥80%; movement-gain median 1.137 and p90 1.543.
- Adaptive radius: held-out p90 error 9.655°, 423.267 logical points, or 8.136 cm. Product/UI acceptance remains **pending**.
- Distance comparison: 45 cm improved median accuracy (3.230° vs 4.127° at 40 cm), but worsened the more safety-relevant p90 accuracy/radius (9.655°/8.136 cm vs 8.681°/6.291 cm), precision, availability, and latency. **Provisional operating-distance winner: approximately 40 cm**, subject to patch-side and remaining-condition evidence.
- Recovery: controlled blink and face-loss recovery were not measured in this run; incidental frame observations are not accepted as final controlled evidence.
- Next required measurements: run both physical patch sides at the provisional winning 40 cm distance, starting with the physical left eye patched.

### 2026-11-03 — Optimized ARKit 40 cm baseline

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Device: exact required 13-inch iPad Air (M2), model `iPad14,10`, running iPadOS 27.0.1, mounted in landscape; viewport 1366×1024 logical points.
- Requested test conditions: ruler-measured approximately 40 cm, both eyes open, no glasses, ordinary supported indoor lighting, comfortable steady head position. Condition recorded by the probe: `around40cm`.
- Privacy: inspected only schema-3 permitted aggregate results. No camera frame, gaze sample/path, timestamp stream, face geometry, calibration parameter, participant identifier, or device identifier was persisted or retrieved.
- Calibration: first attempt succeeded in 16.066 s — duration **pass** (≤30 s median provisional target), first-attempt success **pass for this attempt**.
- Held-out validation: 20/20 fixations produced aggregates.
- Legacy accuracy diagnostic: median 4.127°, p90 8.681°, worst 10.080°; center/edge/corner medians 3.696°/5.482°/5.229° — **fail** against ≤2° median, ≤4° p90, and ≤3° per-region provisional targets.
- Precision: median RMS 0.722° **pass** against ≤1°; p90 RMS 4.097° **fail** against ≤2°; overall legacy precision target **fail**.
- Availability: 99.091% — **pass** against ≥95%; eye-state distribution was 99.091% `both`, 0.909% `none`, 0% one-eye states.
- Update rate: 60.0 Hz median, 58.6 Hz sustained minimum, 55.2 Hz p10 — **pass** against ≥30 Hz.
- Publication latency: 48.211 ms median, 48.560 ms p90, 48.948 ms maximum — **pass** against p90 ≤50 ms and max ≤100 ms.
- Revised interaction-fit evidence: directional agreement 100% — **pass** against the provisional ≥80% criterion; movement-gain median 0.933 and p90 1.165.
- Adaptive radius: held-out p90 error 8.681°, 327.925 logical points, or 6.291 cm at the measured condition. Product/UI acceptance and target-separation consequences remain **pending**; this measurement alone does not pass the revised gate.
- Recovery: four incidental blink-recovery observations were recorded at 0 ms by the current frame-level definition; a controlled blink/recovery run is still required. Face recovery was not measured.
- Remaining gate evidence: 45 cm comparison, physical-left and physical-right patch runs, controlled recovery, head movement, glasses, lighting, setup/distance states, remount variability, calibration reuse/drift/invalidation, and product/UI acceptance of the measured adaptive radius.

### 2026-11-03 — Phase 1 optimized ARKit anatomical eye-label correction

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Exact-device reproduction: closing the user's physical right eye displayed `rightOnly`; the available anatomical eye was actually the left eye.
- Cause: in the mounted landscape front-camera feed, ARKit blend-shape side labels are mirrored relative to user-anatomical left/right.
- Change: swapped only the public one-eye availability conversion. Both/none behavior, gaze mapping, aggregate measurement, privacy, and the optimized ARKit configuration are unchanged.
- Expected regression proof: right eye closed → `leftOnly`; left eye closed → `rightOnly`; both open → `both`.
- Verification: corrected build 7 compiled and passed strict code-signing verification, then installed and launched under bundle ID `com.chandra.DrStrange.Phase1ARKitOptimizedProbe` on the exact 13-inch iPad Air (M2).
- Exact-device regression result: **pass**. The operator confirmed `both` with both eyes open, `leftOnly` with the physical right eye closed, and `rightOnly` with the physical left eye closed. Anatomical eye availability is now correct for the mounted landscape setup.

### 2026-11-03 — Phase 1 optimized ARKit reconsideration started

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Product decision: reconsider ARKit under a revised gameplay requirement. Exact point-gaze accuracy is diagnostic rather than the sole selection gate; the intended interaction may use a UI-owned radius derived from held-out calibration error while the tracker proves reliable eye-driven movement.
- Clinical boundary: this remains gameplay technology used during prescribed patching. Eye movement is not treated as proof of therapeutic efficacy, diagnosis, or clinical outcome.
- Selected configuration: restore the best measured ARKit v2 route—`lookAtPoint` five-term quadratic, nine calibration targets spanning 5%/50%/95%, and distinct randomized held-out targets. Do not restore v3 head compensation because it regressed accuracy and precision.
- Required Phase 1 evidence before Phase 2: compare measured 40 cm and 45 cm runs; report the held-out radius distribution; validate anatomical eye availability and directional response with both patch sides; retain the existing availability, rate, latency, calibration, recovery, privacy, and setup-state requirements.
- Scope: no cursor, target geometry, dwell, scoring, prompts, or `Slicing/` changes. The gaze team reports aggregate radius/error evidence only.
- Implementation: restored ARKit as `phase1-arkit-lookat-quadratic-adaptive-radius-v4`, build 6, with the v2 five-term mapping, aggregate p90 radius, directional agreement/gain, and anatomical eye-availability percentages. The seven-field live public output is unchanged.
- Build/deployment: signed arm64 build succeeded under bundle ID `com.chandra.DrStrange.Phase1ARKitOptimizedProbe`, installed, and launched on the exact target iPad. Older probe processes were stopped first so only this build can own the camera.
- Current device state: landscape UI reports AR face support `yes`; camera permission was granted and the first optimized 40 cm baseline run was completed. See the aggregate evidence above.

### 2026-11-03 — Phase 1 anatomical eye-label correction

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Reproduction evidence: on the exact physical iPad, closing the user's left eye displayed `leftOnly`; the visible physical eye was actually the right eye.
- Cause: the Vision request uses a mirrored front-camera image orientation, so its landmark-side labels were being exposed directly instead of converted to user-anatomical left/right.
- Change: swapped only the one-eye public availability mapping. `both` and `none`, all gaze calculations, privacy behavior, retained aggregates, and the ARKit/Vision gate decisions are unchanged.
- Required physical confirmation after installation: left eye closed → `rightOnly`; right eye closed → `leftOnly`.
- Verification so far: build 5 compiled and signed successfully, installed, and launched on the exact 13-inch iPad Air (M2). Final regression proof requires the operator to perform both one-eye closures while facing the camera.

### 2026-11-03 — Phase 1 Vision fallback session started

- Phase worked: Phase 1 only; Phase 2 remains blocked.
- Device check: the physical 13-inch iPad Air (M2), model `iPad14,10`, is connected and paired. No iPhone or simulator result will be accepted.
- Scope: replace the rejected ARKit observation source in the disposable probe with front-camera Vision face/eye/pupil landmarks while reusing the aggregate-only calibration and held-out measurement protocol.
- Stop rule: run nominal 45 cm calibration and held-out validation first. If nominal accuracy fails the Phase 0 target, stop the Vision route without collecting the broader biometric condition matrix. If it passes, continue the remaining Phase 1 robustness matrix.
- Privacy and boundary: frames, landmarks, calibration samples, and gaze samples remain volatile; only permitted non-identifying aggregates may be persisted. `Slicing/` and all game/UI logic remain untouched.
- Implementation: revised the disposable probe to `phase1-vision-pupil-quadratic-v1` using front-camera Vision face, eye, and pupil landmarks; retained the seven-field public output and aggregate-only persistence in a separate protected `phase1-vision-aggregate-results.json` file.
- Build/deployment: signed arm64 device build 4 succeeded with bundle ID `com.chandra.DrStrange.Phase1VisionProbe`, installed, and launched on the exact target iPad.
- Runtime evidence: a physical-device screenshot showed landscape operation with `tracking`, setup `ready`, eye availability `both`, and `Vision landmarks: detected`. This passes runtime framework/camera/landmark availability only; nominal calibration and held-out metrics are still required.
- Privacy verification: source inspection found no console logging, analytics, networking, or secondary write path. The device screenshot contained probe state/UI only and no camera preview, face image, gaze sample, or gaze path; it remains outside the repository.
- Nominal aggregate: calibration succeeded first attempt in 23.403 seconds; 20 held-out fixations produced 2.672° median / 5.012° p90 accuracy, 1.750° median / 7.988° p90 precision, 100% availability, 30 Hz sustained rate, and 61.130 ms p90 latency.
- Gate decision: Vision fails nominal accuracy, precision, and p90 latency. Per the recorded stop rule, no robustness matrix was collected. Phase 1 remains failed and Phase 2 remains blocked.
- Next decision: external eye-tracking hardware versus explicit evidence-based requirement revision. Custom ML and silent threshold relaxation are not authorized.
- Stop reason: the Vision candidate reached the pre-recorded nominal failure condition; this Phase 1 session stops without beginning Phase 2.
- Session shutdown: both disposable probe processes were terminated after aggregate extraction so camera capture stopped; generated build artifacts were cleaned. Source and permitted aggregate evidence remain.

### 2026-11-02 — Planning workflow setup

- Phase worked: planning setup only.
- Completed: created `plan.md` and `tasks.md`; encoded phase gates and the one-phase-per-session rule.
- Files changed: `GazeTracker/mdFiles/plan.md`, `GazeTracker/mdFiles/tasks.md`, and the planning index.
- Blockers: Phase 0 stakeholder answers are still required.
- Stop reason: planning setup is complete; Phase 0 work must begin in a new session.

### 2026-11-02 — Phase 0 gameplay-context capture

- Phase worked: Phase 0 only.
- Completed: confirmed gaze-controlled whack-a-mole as the primary mechanic and recorded the expected look-to-hit delay.
- Decision recorded: tracker should publish gaze data; game logic should create a hit event rather than the tracker injecting a synthetic touch.
- Files changed: `01-discovery-and-requirements.md`, `03-module-boundary.md`, `05-risks-and-decisions.md`, and `tasks.md`.
- Blockers: activation rule, timing budget, target geometry, hardware, runtime, user/setup, and data-purpose answers remain open.
- Stop reason: Phase 0 context has been captured; this Phase 0 session stops pending stakeholder answers.

### 2026-11-02 — Phase 0 target setup and gameplay rules

- Phase worked: Phase 0 only.
- Completed: confirmed native Swift, 13-inch iPad Air (M2), landscape mounted use, visible cursor, 1-second dwell, one persistent mole at a time, ages 5–7, one-eye patching, gameplay-only purpose, and acceptable launch-time calibration.
- Research recorded: Apple documents the target class with a landscape front camera and Neural Engine; ARKit support and eye-pose quality still require an on-device runtime spike.
- Calibration requirement: investigate once-per-app-launch reuse as early as Phase 1 and define invalidation triggers.
- Remaining blockers: iPadOS version, `Slicing/` ownership, supervision model, patch side, viewing distance/environment, mole size/hit area, latency/quality thresholds, and data-retention/privacy rules.
- Files changed: `01-discovery-and-requirements.md`, `02-technical-options.md`, `03-module-boundary.md`, `04-validation-plan.md`, `05-risks-and-decisions.md`, `plan.md`, and `tasks.md`.
- Stop reason: this Phase 0 requirements-update session is complete; Phase 0 remains active pending the open decisions.

### 2026-11-02 — Phase 0 operating constraints

- Phase worked: Phase 0 only.
- Completed: selected iPadOS 17 minimum; confirmed unsupervised use, variable patch side, immediate dwell reset, glasses/lighting support, no camera/gaze persistence, and `Slicing/` UI-team ownership.
- Technical default: 45 cm nominal viewing distance with a provisional 40–60 cm ready band and live closer/farther guidance; calibration and dwell are disabled outside the ready state.
- Evidence basis: Apple recommends a stable iPad position about 18 inches from the face for its camera-based Eye Tracking feature; the custom tracker must validate its own range.
- Remaining blockers: mole size/hit area, additional latency and quality thresholds, mount variability, camera/face-data privacy copy, patch-side UX, and UI-team boundary review.
- Files changed: `01-discovery-and-requirements.md`, `02-technical-options.md`, `03-module-boundary.md`, `04-validation-plan.md`, `05-risks-and-decisions.md`, `plan.md`, and `tasks.md`.
- Stop reason: this Phase 0 constraints session is complete; Phase 0 remains active pending the remaining decisions.

### 2026-11-02 — Phase 0 mole hit geometry

- Phase worked: Phase 0 only.
- Completed: selected a circular hit area centered on each mole and separated visible artwork radius from invisible hit radius.
- Technical rule: `hitRadius = visualRadius + errorMargin`; select `errorMargin` from physical-device validation rather than hardcoding it during planning.
- Dwell rule: valid gaze accumulates time only while its distance to the mole center is within `hitRadius`; target exit or invalid tracking resets dwell immediately.
- Remaining decision: exact visible radius, error margin, and spawn positions after cursor-error and gameplay testing.
- Files changed: `01-discovery-and-requirements.md`, `03-module-boundary.md`, `04-validation-plan.md`, `05-risks-and-decisions.md`, `plan.md`, and `tasks.md`.
- Stop reason: this Phase 0 geometry session is complete; Phase 0 remains active pending the remaining decisions.

### 2026-11-02 — Phase 0 gaze-only scope lock

- Phase worked: Phase 0 only.
- Completed: locked implementation scope to gaze-tracker technology under `GazeTracker/`.
- Gaze deliverables: ARKit/camera observations, calibration, gaze mapping, filtering, confidence, tracking/setup state, timing, diagnostics, tests, demo host, and public Swift API.
- External context only: cursor UI, mole size/position/hit radius, dwell timer, hit event, scoring, spawning, animation, audio, user-facing prompts, and all `Slicing/` implementation.
- Task correction: replaced hit-radius tuning with radial gaze-error reporting; converted Phase 5 into tracker API handoff and contract verification.
- Files changed: `01-discovery-and-requirements.md`, `03-module-boundary.md`, `plan.md`, and `tasks.md`.
- Stop reason: this Phase 0 scope session is complete; Phase 0 remains active pending tracker-specific requirements.

### 2026-11-02 — Phase 0 requirements and constraints gate

- Phase worked: Phase 0 only.
- Completed: locked provisional numeric targets for accuracy, precision, publication latency, update rate, availability, recovery, calibration duration, and calibration success.
- Privacy: drafted the camera-permission explanation and required on-device, ephemeral processing; camera frames and gaze samples may never be persisted, transmitted, logged, or exposed through the public API.
- Public contract: limited live output to normalized gaze point, monotonic timestamp, confidence/quality, tracking state, setup/distance state, calibration state, and eye availability.
- Task correction: moved distance validation, mount variability, calibration reuse, and drift to Phase 1 because they require physical-iPad evidence.
- Gate evidence: architecture-blocking requirements now have provisional answers and owners; remaining uncertainties are explicitly assigned to physical-device validation or later integration work.
- Files changed: all planning documents under `GazeTracker/mdFiles/`; no implementation source and no `Slicing/` changes.
- Verification: the Phase 0 checklist has no unchecked tasks; `GazeTracker/` contains Markdown only; `Slicing/` contains no files; the live-output allowlist contains exactly the seven approved categories.
- Stop reason: Phase 0 gate passed. Phase 1 is the next permitted phase and must begin in a new session.

### 2026-11-03 — Phase 1 target-device probe blocked at deployment

- Phase worked: Phase 1 only.
- Device: physical 13-inch iPad Air (M2), model `iPad14,10`, iPadOS 27.0.1 (build 24A446), paired and connected by wire with Developer Mode enabled.
- Completed: created the disposable native Swift/iPadOS ARKit probe under `GazeTracker/Phase1Probe/`; verified a clean unsigned arm64 iOS device-SDK build.
- Probe scope: runtime support check, volatile eye/look-at observations, in-memory ridge calibration, separate randomized held-out center/edge/corner validation, setup-state checks, aggregate accuracy/precision/rate/latency/availability/recovery/stability/drift output, and aggregate-only protected persistence.
- Privacy: no camera frame, gaze sample/path, face geometry, calibration parameters, participant/device identifiers, or gaze-linked timestamps are persisted, logged, transmitted, cached, or uploaded. The live sample surface contains only the seven allowed categories.
- Blocker: signed target-device build failed because the Apple Developer team has an updated Program License Agreement awaiting acceptance and the installed provisioning profile does not contain the target iPad.
- Measurements: none. Every Phase 0 provisional target remains blocked/not measured; no iPhone or simulator evidence was substituted.
- Recommendation: ARKit feasibility and fallback route remain undecided until the probe runs on this exact iPad.
- Files changed: `GazeTracker/Phase1Probe/` and `GazeTracker/mdFiles/tasks.md`; `Slicing/` was not touched.
- Stop reason: the exact device cannot currently receive the probe. Phase 1 remains blocked and Phase 2 is not permitted.

### 2026-11-03 — Phase 1 deployment blocker cleared

- Phase worked: Phase 1 only.
- Completed: automatic signing registered the exact iPad and generated a compatible development profile; the signed arm64 device build succeeded, installed, and launched.
- Runtime evidence: on the physical 13-inch iPad Air (M2) running iPadOS 27.0.1, the probe reported `AR face support: yes`.
- Current state: the app is open in landscape and awaiting the one-time camera permission decision; no camera observations or gaze samples have yet been collected.
- Measurements: ARKit support passes. All remaining provisional targets remain not measured.
- Phase boundary: Phase 1 remains active; Phase 2 was not started.

### 2026-11-03 — Phase 1 nominal calibration and held-out validation

- Phase worked: Phase 1 only.
- Device/setup: exact physical 13-inch iPad Air (M2), `iPad14,10`, iPadOS 27.0.1, landscape; condition labeled nominal 45 cm and accepted by the probe's 40–60 cm ready-state gate. Exact physical distance was not independently recorded with a ruler, so this is a preliminary nominal run.
- Calibration: first attempt succeeded in 16.091 s.
- Held-out evidence: 18 randomized center/edge/corner fixations; only aggregate metrics were copied from the protected app container.
- Passed provisionally: runtime ARKit support, 99.495% availability, 60 Hz median / 57.3 Hz p10 / 59.3 Hz sustained-minimum update rate, calibration duration, and one first-attempt calibration.
- Failed: radial accuracy (7.813° median, 22.365° p90), precision p90 (3.933°), and publication-latency p90 (51.623 ms). Center, edge, and corner median errors all exceeded the 3.0° regional bound.
- Stability: left/right eye angular RMS medians were 0.277°/0.275°; p90 values were 2.903°/2.841°. `lookAtPoint` RMS median was 4.482 mm and p90 was 45.412 mm.
- Recovery: three natural blink events recovered on the first valid frame; explicit blink and face-loss scenarios remain required.
- Privacy verification: the copied file contained only the permitted aggregate schema; no camera frame, gaze sample/path, face geometry, calibration parameter, participant/device identifier, or gaze-linked timestamp was present. The temporary local copy was not added to the repository.
- Gate status: Phase 1 remains incomplete and does not pass. Required distance, patch-side, eyewear, lighting, movement, remount, face-loss, drift, and reuse runs remain outstanding. Phase 2 was not started.

### 2026-11-03 — Phase 1 measured-distance nominal repeat

- Phase worked: Phase 1 only.
- Setup: operator used a ruler-measured 45 cm position, mounted landscape iPad, and repeated calibration plus held-out validation.
- Calibration: second nominal attempt succeeded in 16.086 s.
- Repeat result: accuracy improved but still failed decisively at 6.893° median, 17.341° p90, and 22.806° worst. Center/edge/corner medians were 3.827°/6.301°/13.212°, all above the 3.0° regional ceiling.
- Precision: 0.824° median passed, but 2.529° p90 failed.
- Passed again: 99.747% availability and 60 Hz median / 60 Hz p10 / 59.5 Hz sustained-minimum rate.
- Latency: failed again at 57.847 ms p90; worst case 64.637 ms remained below the 100 ms maximum.
- Interpretation: repeatability rules out viewing distance as the sole cause. The current regression uses 14 features with only nine unique calibration positions and the held-out grid lies outside the calibration grid at edges/corners; this protocol can create unstable extrapolation and must be corrected before attributing the failure to ARKit itself.
- Gate status: Phase 1 remains incomplete. Phase 2 was not started.

### 2026-11-03 — Phase 1 constrained-mapping probe revision

- Phase worked: Phase 1 only.
- Change: replaced the underconstrained 14-feature mapping with a five-term quadratic using ARKit `lookAtPoint`, which already combines the eye estimate and face pose.
- Protocol correction: expanded the nine-point calibration grid to 5%/50%/95% of the viewport and moved ten distinct held-out center/edge/corner targets inside that grid, eliminating the previous edge extrapolation while preserving separate fit and validation coordinates.
- Version: `phase1-arkit-lookat-quadratic-v2`, build 2.
- Verification: signed device build succeeded, installed over the previous probe, launched on the exact target iPad, and reached `tracking`, setup `ready`, eyes `both`, and `notCalibrated` in landscape.
- Scope/privacy: no production module, game logic, public-output expansion, or `Slicing/` change; aggregate-only persistence remains unchanged.
- Next evidence: repeat nominal 45 cm calibration and held-out validation with v2 before running the condition matrix.

### 2026-11-03 — Phase 1 constrained-mapping v2 nominal result

- Phase worked: Phase 1 only.
- Calibration: v2 first attempt succeeded in 16.062 s; 20 held-out fixations completed.
- Improvement: precision passed at 0.683° median / 1.454° p90, publication latency passed at 45.680 ms median / 46.056 ms p90 / 46.545 ms worst, availability was 99.591%, and the sustained minimum rate was 59.4 Hz.
- Remaining failure: accuracy improved to 5.796° median / 7.632° p90 / 9.118° worst but remained well above the 2.0°/4.0° targets. Center/edge/corner medians were 7.046°/6.106°/4.760°, all above the 3.0° regional ceiling.
- Observation quality: left/right eye angular stability p90 was 0.617°/0.620° and `lookAtPoint` stability p90 was 9.528 mm, indicating stable inputs relative to the residual systematic gaze-map bias.
- Decision: do not spend the required patch/glasses/lighting matrix on v2. Run one final constrained ARKit mapping experiment with bounded head translation/orientation compensation and enough unique calibration positions to constrain it.
- Gate status: Phase 1 remains incomplete and does not pass; Phase 2 was not started.

### 2026-11-03 — Phase 1 head-compensated v3 probe revision

- Phase worked: Phase 1 only.
- Change: retained the five-term `lookAtPoint` quadratic and added only horizontal/vertical face translation and head-orientation terms, for nine features plus intercept.
- Constraint: expanded calibration from nine to thirteen unique viewport positions so the ten fitted coefficients are not underconstrained by target positions; held-out targets remain distinct and inside the calibration grid.
- Version: `phase1-arkit-head-compensated-v3`, build 3.
- Verification: signed build succeeded, installed and launched on the exact target iPad, and reached `tracking`, setup `ready`, eyes `both`, and `notCalibrated` in landscape.
- Decision rule: if the v3 nominal held-out run still misses the Phase 0 accuracy target, stop ARKit model tuning and record the Phase 1 ARKit route as failed with a required fallback experiment.
- Phase boundary: Phase 1 remains active; Phase 2 was not started.

### 2026-11-03 — Phase 1 ARKit candidate failure and fallback decision

- Phase worked: Phase 1 only.
- V3 calibration: first attempt succeeded in 23.211 s; 20 held-out fixations completed at the nominal ready setup.
- V3 result: accuracy failed at 10.004° median / 13.707° p90 / 14.568° worst; center/edge/corner medians were 10.604°/10.953°/7.830°. Precision also failed at 2.232° median / 5.680° p90.
- Passed metrics: 97.909% availability, 60 Hz median / 51.7 Hz p10 / 57.1 Hz sustained-minimum update rate, and 46.589 ms median / 47.170 ms p90 / 55.487 ms worst publication latency.
- ARKit recommendation: fail / no-go. Three mapping variants on the exact physical target failed nominal held-out accuracy; v3 head compensation did not rescue the result.
- Early stop: the robustness matrix was not executed for the rejected candidate because nominal accuracy already failed repeatedly. This avoids collecting unnecessary biometric observations and cannot change the gate outcome.
- Fallback: in a new Phase 1 session, build the smallest Vision pupil/eye-landmark spike on the same iPad with identical privacy controls and acceptance targets. If Vision fails nominal accuracy or patching, escalate to external hardware versus explicit requirement revision; do not silently weaken targets or start custom ML.
- Gate status: Phase 1 did not pass. Phase 2 remains blocked and was not started.
- Stop reason: the ARKit candidate reached its pre-recorded failure condition and the one-phase session stops before fallback implementation.

### 2026-11-03 — ARKit future-option finding preserved

- Documentation-only follow-up; no phase implementation resumed.
- Recorded heuristic assessment: 55/100 overall capability and approximately 35/100 current production readiness.
- Current decision remains unchanged: ARKit does not pass the present Phase 1 gate and Phase 2 remains blocked.
- Future trigger: reconsider only with materially improved mapping/platform evidence, explicitly revised evidence-based requirements, or a more error-tolerant use case, followed by a complete rerun on the exact target iPad.
