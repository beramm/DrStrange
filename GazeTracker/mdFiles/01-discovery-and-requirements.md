# Discovery and Requirements

Status: Phase 0 requirements locked; custom Phase 3 is next
Owner: gaze-tracking team
Reviewers: product/clinical owner and UI/game team

## Problem statement

DrStrange needs an iPad component that estimates where the current user is looking on the app screen. The UI/game team will consume the estimate but will build the visible experience separately.

DrStrange is a therapeutic game for amblyopia, but the gaze estimate is an assistive gameplay signal, not a clinical measurement or diagnostic result.

## Confirmed game context

- The game mechanic is whack-a-mole.
- The player aims at a visible mole using gaze while a visible gaze cursor provides feedback.
- Continuously dwelling on the mole for 1 second should produce a game-level hit.
- Only one mole is active at a time. It remains visible until the gaze dwell successfully hits it; the next mole does not appear earlier.
- Each mole has a circular hit area centered on it. The invisible hit radius may be larger than the visible artwork radius to tolerate measured gaze error.
- The exact visible radius and additional hit-radius margin are not decided yet.
- The intended players are children aged 5–7.
- One eye will be patched during play, so the chosen approach must be validated under one-eye occlusion.
- Gaze is used for gameplay only, not as assessment or clinical measurement data.
- A calibration step when the app/game is opened is acceptable.
- Play is unsupervised rather than requiring an adult/operator.
- The patched eye can differ between users, so calibration is bound to the current user setup and patch side.
- Leaving the mole hit area resets the 1-second dwell immediately.
- Glasses and reasonable variations in room lighting must be supported and tested.
- Camera frames and gaze samples are never persisted or transmitted.

The integration model sends gaze coordinates/state from our custom tracker to game logic and lets the game produce a hit when its activation rule passes. The tracker must not fabricate or inject an operating-system touch event.

## Confirmed hardware and setup

| Item | Requirement |
| --- | --- |
| Application stack | Native Swift/iPadOS |
| Target device | 13-inch iPad Air (M2) |
| Minimum deployment target | iPadOS 17; test on the actual installed OS |
| Orientation | Landscape |
| Physical setup | Mounted iPad |
| Viewing distance | Nominal 45 cm; provisional valid band 40–60 cm, subject to device validation |
| Front camera | Landscape-positioned camera; exact ARKit eye-pose quality must be tested on device |
| Player | Age 5–7 with one eye patched |
| Session type | Unsupervised use; setup and recovery instructions must be child-friendly |
| Calibration | Once when the game/app is opened is acceptable; reuse conditions require investigation |
| Data retention | No camera frames or gaze samples persisted or transmitted |

## Current repository facts

- `GazeTracker/` is the bounded area for this team's work and contains the Swift Package, platform adapter, focused tests, gaze-owned demo host, disposable Phase 1 probe, and planning documents.
- `Slicing/` is confirmed as the UI/game team's area and is outside gaze-team implementation scope.
- The production-oriented custom tracker boundary uses a framework-neutral `DrStrangeGazeTracker` Swift target and a separate `DrStrangeGazeTrackerPlatform` ARKit adapter.
- The Phase 2 demo host builds, installs, and runs on the exact target iPad; production integration with the UI/game application remains a later handoff.

## Proposed outcome

The gaze module's live public output is limited to:

- normalized gaze point;
- monotonic timestamp;
- confidence/quality;
- tracking state;
- setup/distance state;
- calibration state;
- eye availability.

Lifecycle controls and the calibration workflow are operations on the module, not additional live sample fields. Raw or derived face geometry, camera frames, framework objects, screen-space duplicates, sequence identifiers, gameplay events, and diagnostics are not public tracker output.

The seven-category continuous tracker output remains required. Apple system Eye Tracking is not the production architecture because it does not expose these values to the app. Its observed behavior is used only as reference material for improving our own calibration and interaction design.

## Out of scope for the first milestone

- visual design and final game UI;
- medical diagnosis or treatment-effect claims;
- cloud processing or uploading camera frames;
- multi-person tracking;
- support for iPad models other than the confirmed target device;
- selection/dwell interaction behavior owned by the UI team;
- cursor UI, mole artwork/placement/hit radius, hit events, scoring, animation, audio, and all `Slicing/` implementation;
- a custom machine-learning model unless the platform approach fails the capability spike.
- Apple system Eye Tracking as the game's gaze input or activation architecture;
- private APIs, synthetic touch injection, or attempts to read system accessibility gaze/focus state.

## Phase 0 decisions and ownership

The remaining architecture questions have the following provisional answers and owners:

| Topic | Phase 0 answer | Owner / next evidence |
| --- | --- | --- |
| Patch side | Calibration is bound to the current patch side; how it is selected is a UI/product detail and does not change the tracker architecture | Product/UI before calibration-flow integration |
| Child-facing instructions | UI/game owns wording and presentation; tracker publishes typed setup, tracking, and calibration state only | UI/product before distribution |
| Mount and distance | Mounted landscape setup, 45 cm nominal and provisional 40–60 cm ready band | Engineering validates on the physical iPad in Phase 1 |
| Performance | Use the numeric provisional targets in `04-validation-plan.md` | Engineering measures in Phase 1 and later validation |
| Head movement | Support ordinary seated movement while the user remains in the validated setup band; invalidate calibration on material geometry change | Engineering defines measured limits in Phase 1 |
| Privacy approval | The requirements and permission draft below are locked; product/privacy owner approves final distribution copy | Product/privacy before external distribution |
| Future research/clinical/analytics use | Out of scope and cannot weaken the no-persistence rule without a separately approved scope and privacy review | Product/privacy/clinical owner before any scope change |

## Camera permission explanation

Proposed iPad camera usage description:

> DrStrange uses the front camera while gaze control is active to estimate where you are looking so you can play with your eyes. Camera images and gaze points are processed only on this iPad and are never saved or uploaded.

The pre-permission UI may use child-friendly wording, but it must preserve the same facts and must not imply clinical measurement or identity recognition.

## Face-data privacy requirements

- Process camera frames, face/eye observations, calibration inputs, and gaze samples on device and in memory only while tracking or calibration is active.
- Never persist, cache, upload, transmit, export, log, or add camera frames or gaze samples to analytics, diagnostics, crash reports, screenshots, or backups.
- Keep framework face geometry, eye transforms, and head-pose details internal; do not expose them through the public tracker API.
- Keep calibration parameters in memory for the current app launch only and erase them on tracker shutdown or app termination. They are not reused across launches.
- Persist only aggregate, non-identifying engineering summaries produced after in-memory analysis, such as percentile error, rate, latency, availability, duration, success counts, and failure counts. Aggregates must not permit reconstruction of a gaze path.
- Do not attach participant, child, caregiver, account, advertising, or device identifiers to tracker processing or aggregate engineering summaries.
- Ensure third-party analytics and crash-reporting SDKs cannot receive camera, face, calibration, or gaze values.
- Stop camera capture and release resources when tracking stops, the app backgrounds, or permission is revoked; publish the appropriate tracking state without a fabricated point.
- Require product/privacy approval of final permission and privacy copy before external distribution. Testing with children additionally requires the approved caregiver consent and research/clinical process, even though gaze is gameplay-only.

## Phase 1 physical-device evidence

These items require the physical target iPad and are explicitly non-blocking for the Phase 0 requirements gate:

- validate the provisional 40–60 cm band and safe/comfortable distance adjustment;
- validate mount variability and ordinary head movement limits;
- measure accuracy, precision, latency, rate, availability, recovery, and calibration outcomes;
- test calibration reuse across a representative app launch, drift, and invalidation triggers;
- test both patch sides, glasses, lighting, blinks, face loss, and interruption behavior.

## Working assumptions to validate

- One face is present and approximately centered in front of the iPad.
- Tracking and calibration run entirely on device.
- Camera frames and gaze samples are not persisted or transmitted.
- The UI team can render the agreed calibration target sequence and report target positions to the gaze module.
- The first milestone targets one known iPad model in one orientation.
- A failed or low-confidence estimate is represented as unavailable, not as the last known point indefinitely.
- Gaze-tracker source and tests will remain inside `GazeTracker/`; cross-folder changes require explicit integration agreement.
- Calibration is held in memory for the current app launch only and is never reused across launches.
- Calibration is invalidated when the user/patch side changes or when device orientation, mount, viewing distance, or camera-to-face geometry changes materially.
- Before and during calibration, the tracker checks face distance. The UI asks the user to move closer or farther when outside the validated band.
- Dwell pauses and resets whenever tracking is invalid or the gaze point exits the mole hit area.
- Mole centers are placed far enough from viewport edges that the complete circular hit area remains usable.

## Phase 0 gate result

Phase 0 passes because every architecture-blocking requirement has a provisional answer and owner, acceptance thresholds are numeric, the live output allowlist is locked, and privacy requirements are documented. Physical-device proof is Phase 1 by design. Production implementation remains unauthorized until the Phase 1 capability spike passes and the later phase gates permit it.

Change control on 2026-11-03 confirms that Apple system Eye Tracking is reference material only. DrStrange continues with its own tracker and continuous coordinate/state contract; Phase 3 must improve calibration and mapping without depending on the operating-system tracker.
