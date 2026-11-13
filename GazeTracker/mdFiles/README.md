# Gaze Tracker Planning Pack

Status: Phase 2 complete; custom Phase 3 calibration and screen mapping is next
Last updated: 2026-11-03
Scope: gaze tracking on iPad for the DrStrange amblyopia therapeutic game

No tracker implementation was created during Phase 0. Later implementation is authorized only within its numbered phase and a separate work session after the preceding gate passes.

Scope is limited to the custom gaze-tracker technology under `GazeTracker/`: camera/ARKit observations, calibration, gaze mapping, filtering, quality/state, diagnostics, tests, and a public Swift API. Apple system Eye Tracking may inform design research but is not the product input architecture. The UI/game team owns `Slicing/`, cursor presentation, mole geometry, hit radius, dwell, scoring, animation, prompts, and game flow.

## Documents

1. [01-discovery-and-requirements.md](01-discovery-and-requirements.md) — goal, scope, assumptions, and questions for stakeholders.
2. [02-technical-options.md](02-technical-options.md) — feasible approaches and a provisional recommendation.
3. [03-module-boundary.md](03-module-boundary.md) — proposed contract between the gaze module and the UI/game team.
4. [04-validation-plan.md](04-validation-plan.md) — how accuracy, stability, latency, and usability will be evaluated.
5. [05-risks-and-decisions.md](05-risks-and-decisions.md) — risk register and decision log.
6. [06-repository-structure.md](06-repository-structure.md) — current folder ownership and future layout options.
7. [07-apple-gaze-tracking-lessons.md](07-apple-gaze-tracking-lessons.md) — Apple-informed design lessons, recording evidence, and custom Phase 3 radius-reduction guidance.
8. [08-apple-inspired-custom-phase3.md](08-apple-inspired-custom-phase3.md) — approved Phase 3 implementation brief, ≤4 cm gate, and copy-ready next-session prompt.
9. [plan.md](plan.md) — phase-gated development roadmap and stop rules.
10. [tasks.md](tasks.md) — live checklist, phase gates, evidence, and session log.

## Current position

Phase 1 is complete under the accepted selected-right ARKit interaction-fit contract. Phase 2 module, tests, documentation, and demo host build/install/run are complete on the exact target iPad. The next permitted work is custom Phase 3 calibration and screen mapping in a new session. The Apple recording is reference evidence for improving our own setup guidance, calibration flow, filtering, and interaction quality; it does not change the selected custom-tracker architecture.

The repository separates `GazeTracker/` and `Slicing/`. The gaze planning pack lives under `GazeTracker/mdFiles/`; the production-oriented Swift Package, tests, and gaze-owned demo host live under `GazeTracker/`. `Phase1Probe/` remains separate disposable evidence. The referenced `RTK.md` instruction file is still not present in this checkout, so no additional repository-specific instructions could be applied.

## Exit criteria for planning

The Phase 0 requirements baseline now records:

- target iPad model(s) and minimum iPadOS version;
- native Swift/iPadOS application stack and repository ownership, with module packaging assigned before Phase 2;
- the exact meaning of “gaze” for the game;
- provisional numeric accuracy, precision, latency, update-rate, availability, recovery, and calibration requirements;
- whether gaze data is gameplay telemetry, research data, or clinical/assessment data;
- privacy, retention, and consent rules;
- the tracker/UI ownership boundary described in the module contract;
- a strict live public-output allowlist and a no-persistence/no-transmission rule for camera frames and gaze samples.

These are provisional engineering acceptance targets, not claims of clinical accuracy. Phase 1 must determine whether they are achievable on the physical target setup before any production module work begins.

Execution progress is tracked only in `tasks.md`. Each work session is limited to one phase and must stop at the phase boundary, even when the next phase appears ready to begin.
