# Gaze Tracker Development Plan

Status: Phase 3 controlled experiment implemented; exact-device gate measurements pending
Last updated: 2026-11-03
Execution tracker: [tasks.md](tasks.md)

## Goal

Build and validate DrStrange's own reliable on-device iPad gaze tracker. It estimates gaze within the viewport and exposes a native Swift tracker contract. Apple's system Eye Tracking is reference material for calibration and interaction design only; it is not an input, dependency, or alternative production architecture.

This plan does not treat the gaze estimate as a clinical or diagnostic measurement unless a later product, clinical, privacy, and regulatory decision explicitly changes that scope.

Hard scope boundary: this plan covers gaze-tracker technology only. It does not authorize implementation or modification of mole visuals, hit radius, dwell logic, cursor UI, scoring, animations, instructions, or any source under `Slicing/`.

## Confirmed tracker baseline and external game context

- Native Swift/iPadOS on a mounted 13-inch iPad Air (M2) in landscape.
- iPadOS 17 minimum deployment target; physical testing on the installed OS.
- Gaze-controlled whack-a-mole for children aged 5–7 with one eye patched.
- A visible gaze cursor and one active mole at a time.
- A hit after 1 second of valid gaze dwell within the mole hit area.
- A circular mole hit area whose radius equals the visible radius plus a validation-derived gaze-error margin.
- Gameplay-only use of gaze; no assessment purpose.
- Desired calibration frequency: once per app launch, subject to drift/invalidation evidence.
- Unsupervised use with live setup guidance; nominal distance 45 cm and provisional valid band 40–60 cm.
- Variable patch side, glasses, and reasonable lighting variation must be supported.
- No persistence of camera frames or gaze samples.

The Phase 0 provisional engineering targets are: median radial accuracy at or below 2.0° and 90th percentile at or below 4.0°; median fixation precision at or below 1.0° RMS and 90th percentile at or below 2.0° RMS; at least 30 valid samples per second while tracking (60 Hz target when supported); sample-publication latency at or below 50 ms at the 90th percentile and 100 ms maximum in supported steady-state conditions; at least 95% tracking availability overall with no supported-condition run below 90%; recovery within 250 ms at the 90th percentile after a blink and within 1 second after the face becomes observable following face loss; calibration within 30 seconds median and 60 seconds at the 90th percentile including one retry; and at least 80% first-attempt and 90% within-two-attempt calibration success. Definitions and reporting rules are in `04-validation-plan.md`.

The cursor, mole, circular hit area, one-second dwell, and hit event are listed only because they define what the UI team needs from the tracker. They are not gaze-team deliverables.

## Working method

- Work proceeds in numbered phases and in order.
- One work session may operate on only one phase.
- A phase may span multiple sessions when necessary.
- If a phase finishes during a session, stop the session after updating `tasks.md`; do not begin the next phase in the same session.
- At the beginning of every session, read `plan.md`, `tasks.md`, and the documents relevant to the active phase.
- Update `tasks.md` as material work is completed and again immediately before stopping.
- A checkbox is completed only when its evidence or acceptance condition exists.
- Do not advance to the next phase until the current phase gate passes.
- Implementation remains confined to `GazeTracker/` unless cross-team integration is explicitly authorized.

## Phase 0 — Requirements and constraints lock

Status: complete on 2026-11-02. Phase 1 is next and was not started in the completing session.

Purpose: remove the decisions that could cause the tracker to be built for the wrong hardware, runtime, user, or data purpose.

Outputs:

- confirmed iPad model(s) and minimum iPadOS version;
- confirmed native Swift, Unity, or other application stack;
- confirmed ownership of `Slicing/`;
- required live tracker output, limited to: normalized gaze point, monotonic timestamp, confidence/quality, tracking state, setup/distance state, calibration state, and eye availability;
- expected orientation, mounting mode, viewing distance, and environment;
- decision on one-eye/patch support and intended age group;
- initial numeric performance targets;
- data retention, privacy, consent, research, and clinical-use classification.

Gate: every architecture-blocking question in `01-discovery-and-requirements.md` has an owner and answer. Open non-blocking questions are explicitly recorded.

Gate result: passed. Hardware-dependent distance validation, mount variability, calibration reuse, drift, and supported-condition limits are Phase 1 evidence tasks and do not block the Phase 0 requirements lock. Evidence is recorded in `tasks.md`.

## Phase 1 — Physical-device capability spike

Purpose: prove that the exact target iPad can provide sufficiently useful eye/head observations before production architecture is built.

Approach:

- build the smallest disposable physical-device probe for the confirmed stack;
- check `ARFaceTrackingConfiguration.isSupported` at runtime;
- inspect availability, update behavior, and stability of eye transforms and `lookAtPoint`;
- test nominal viewing distance, orientation, blinks, modest head movement, glasses, and required one-eye condition;
- test whether one calibration remains valid throughout a representative app session;
- validate distance estimation and closer/farther gating around the provisional 40–60 cm band;
- compute derived diagnostics in memory and persist only aggregate, non-identifying metric summaries; never persist camera frames or gaze samples;
- compare observations against known screen targets without presenting the spike as a final tracker.

Gate: record a pass/fail recommendation with measurements from the target device. If ARKit fails, explicitly choose whether to test Vision, reduce requirements, or evaluate external hardware.

Change-control note (2026-11-03): after the original ARKit and Vision point-accuracy gates failed, product chose to reconsider the best ARKit configuration for a less point-exact interaction: reliable eye-driven movement with a UI-owned adaptive radius derived from held-out error. This revised route remains Phase 1 work. It must compare 40/45 cm, validate both patch sides and directional response, preserve all privacy/performance/state requirements, and obtain product/UI acceptance of the measured radius before Phase 2. It does not convert eye movement into a clinical or therapeutic-effect measurement.

Accepted interaction-fit clarification (2026-11-03): product explicitly accepts that the original ≤2° median accuracy and ≤2° p90 precision thresholds are diagnostics rather than hard rejection criteria for the revised one-target directional interaction. The selected-eye candidate must still achieve at least 80% held-out directional agreement, report and obtain acceptance for its calibration-specific held-out p90 radius, pass the unchanged performance/availability/recovery/setup/privacy requirements, and repeat both sides with a real opaque patch. Current exploratory radii of 4.726 cm for the selected right eye and 2.695 cm for the selected left eye are accepted for continued Phase 1 evaluation, not as final child-population or therapeutic evidence.

Accepted evidence-deferral clarification (2026-11-03): product explicitly classifies real opaque-patch repeats on both sides, representative glasses, bright/dim lighting variants, the 40–60 cm distance/setup-state matrix, and representative-session calibration drift/reuse (including pause/interruption cases) as non-blocking backlog items. Their absence remains documented risk and is not a pass or a support claim, but it no longer prevents the Phase 1 gate or Phase 2 start. Directional/performance evidence reconciliation, radius acceptance, privacy, and the exact-device recommendation remain blocking Phase 1 work. Remount survival is not a supported behavior: remounting, orientation change, or material camera-position change unconditionally invalidates calibration and therefore requires no calibration-survival test.

Gate result: **passed on 2026-11-03 under the revised interaction-fit contract.** Use selected-right ARKit with distinct held-out validation and accept only a calibration-specific p90 radius ≤8.0 cm; otherwise recalibrate. Known p90 latency variance remains a Phase 2 risk, while all measured maxima stayed below 100 ms. Privacy and the live-output boundary passed. Phase 2 is next and must begin in a new session; no Phase 2 work was started in the completing session.

## Phase 2 — Module foundation and public contract

Purpose: create the production module boundary only after the runtime and feasibility route are known.

Outputs:

- runtime-appropriate structure under `GazeTracker/`;
- public models limited to the Phase 0 output allowlist and lifecycle operations;
- lifecycle operations for support check, start, pause, resume, stop, and calibration;
- monotonic timestamps and documented coordinate convention;
- demo/test host on physical hardware;
- initial unit tests for state transitions and coordinate conversion.

Gate: the module builds, runs on the target iPad, publishes typed states/samples, and does not leak ARKit or camera-frame internals into the UI/game contract.

Gate result (2026-11-03): **passed.** The module, 13 focused tests, generated public interface, generic iOS host build, signed exact-device build, installation, launch, and landscape typed-sample publication passed on the physical `iPad14,10`. The standard contract interface contains no ARKit/AVFoundation import or framework type, and the live sample has exactly the seven approved categories. Custom Phase 3 is next and must begin in a new session.

## Phase 3 — Calibration and screen mapping

Purpose: convert the custom tracker's eye/head observations into validated viewport coordinates.

Approach:

- implement the calibration handshake defined in `03-module-boundary.md`;
- collect fixation-gated robust target-visit aggregates and reject invalid samples;
- preserve the selected-right five-term quadratic as the comparison baseline;
- implement a geometric selected-eye ray/screen-plane mapping with a small residual correction;
- keep calibration and validation points separate;
- record calibration version and invalidation conditions;
- measure accuracy and precision across center, edge, and corner targets.

Gate: calibration completes reliably on the target setup; two consecutive same-calibration held-out validations and the modest-head-movement validation each produce a finite p90 radius no greater than 4.0 cm; and directional agreement plus operational requirements continue to pass. The Phase 3 stretch objective is 2–3 cm. The earlier 8.0 cm decision remains historical Phase 1 foundation evidence and is not the Phase 3 pass condition. Original Phase 0 accuracy/precision thresholds remain reported diagnostics and are not silently relabeled as passes.

## Phase 4 — Tracking quality and robustness

Purpose: make failures explicit and improve stability without hiding latency or error.

Outputs:

- blink/occlusion and invalid-sample rejection;
- bounded smoothing with measured latency impact;
- confidence and `tracking`, `limited`, and `lost` behavior;
- interruption, background/foreground, and recovery behavior;
- orientation/setup change detection and calibration invalidation;
- drift monitoring and recalibration request behavior;
- automated tests for failure-state transitions.

Gate: robustness scenarios meet the agreed availability, latency, recovery, and false-output requirements without fabricating gaze points.

## Phase 5 — Tracker API handoff and boundary verification

Purpose: prove and document the tracker contract without implementing the other team's UI or game logic.

Outputs:

- final Swift API and module integration;
- agreed viewport/safe-area coordinate mapping;
- calibration-state handshake contract;
- state/error contract tests in the gaze-owned demo host;
- threading, update-rate, lifecycle, and coordinate-contract tests;
- integration documentation for the UI/game team.

Gate: the gaze-owned demo host and contract tests prove all public states and samples on physical hardware, and the UI team has sufficient documentation to integrate independently.

## Phase 6 — Validation against acceptance criteria

Purpose: determine whether the gaze tracker is fit to supply the agreed game contract.

Approach:

- execute `04-validation-plan.md` on the fixed hardware/setup matrix;
- report median, 90th percentile, worst-case, and failure counts where meaningful;
- test longer-session drift and thermal behavior;
- test representative users only under the approved consent/research process;
- separate engineering results from clinical validity claims.

Gate: every required metric has evidence and a pass/fail result. Failures lead to an explicit product, algorithm, or hardware decision rather than an undocumented workaround.

## Phase 7 — Hardening and handoff

Purpose: leave a supportable module and clear ownership after validation passes.

Outputs:

- finalized public API and usage documentation;
- supported device/setup matrix and known limitations;
- privacy and retained-data documentation;
- automated test and physical-device verification instructions;
- troubleshooting and recalibration guidance;
- removal of disposable spike code and unapproved diagnostics;
- handoff review with UI/game and product owners.

Gate: another developer can integrate, test, and diagnose the tracker from the documentation, and all required validation/privacy artifacts are present.

## Change control

Changes to phase order, product scope, hardware, runtime, public output, or acceptance thresholds must be recorded in `05-risks-and-decisions.md` and reflected in both this plan and `tasks.md`.
