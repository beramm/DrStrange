# DrStrange

DrStrange is an iPad game prototype designed to support **active patching therapy for amblyopia**. During a patching session prescribed by an eye-care professional, the player covers the prescribed eye and uses the uncovered eye to play Whack-a-Mole.

## How it works

1. A caregiver records which eye is patched and chooses the prescribed session length.
2. The app calibrates its custom on-device gaze tracker for the uncovered right eye.
3. The player looks at an active mole for a short dwell period to trigger the fox's attack.
4. The game records ordinary session results such as score and completed play time.

The current tracker uses ARKit face observations as input to DrStrange's own calibration and screen-mapping pipeline. It does not use Apple system Eye Tracking as an input, dependency, fallback, or activation path.

## Privacy

Camera frames, biometric geometry, calibration observations, gaze samples, and gaze paths are processed only in volatile memory and are not persisted, logged, or transmitted. Saved game information is limited to game settings and session results.

## Project status and safety

This repository is an engineering prototype, not a diagnostic tool or a substitute for professional treatment. Patching side, duration, and frequency must follow the plan provided by the player's ophthalmologist or orthoptist. Stop the session if the player experiences eye pain, headache, unusual fatigue, or discomfort.

The custom gaze tracker is functionally integrated with the game, but its current measured raw p90 error remains above the project's accuracy target. Interaction dwell and target bounds improve playability and are not reported as tracker-accuracy improvements.

## Repository layout

- `DrStrange/` — main iPad application.
- `WhackAMoleGame/` — amblyopia patching game, UI, and game engine.
- `GazeTracker/` — custom gaze-tracking package, calibration experiment, tests, and validation notes.
- `DrStrangeTests/` — game-engine and gaze-interaction tests.
