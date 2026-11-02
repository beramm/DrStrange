# Whack-a-Mole (occlusion therapy game)

A calm, child-friendly Whack-a-Mole game for iPad, designed to be played **while the child wears
the eye patch prescribed by their ophthalmologist** over the stronger eye. Playing gives the
amblyopic eye an engaging task during patching time.

> This is a research and development prototype. It does not treat or cure amblyopia, does not
> replace patching, glasses or any treatment prescribed by an eye-care professional, and does not
> replace clinical follow-up. Game scores are gameplay results, not measurements of vision or of
> treatment progress. Which eye to patch, for how long, and how often are decided by the child's
> ophthalmologist or orthoptist, never by the app.

## Run it in Xcode

1. Open `DrStrange.xcodeproj` in Xcode (27 or later).
2. In the scheme menu at the top of the window, choose **WhackAMoleGame**.
3. Choose an iPad simulator, for example **iPad Pro 11-inch (M5)**.
4. Press **Cmd + R**.

The game starts on its own home screen. It does not use the DrStrange app's navigation or any
sign-in. The **DrStrange** scheme still builds the main app, which opens the same game from its
home screen.

Command line:

```bash
xcodebuild -scheme WhackAMoleGame -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build
xcodebuild -scheme DrStrange -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' test
```

Debug builds accept the launch argument `-WhackAMoleAutostart` (Product ▸ Scheme ▸ Edit Scheme ▸
Run ▸ Arguments), which skips the home screen and starts a game with the saved settings. This is
useful for checking layouts on different iPad sizes.

## How patching fits into the game

- Before playing, a parent or caregiver puts the patch on the eye the child's eye doctor told them
  to cover. The game itself is the same whichever eye is patched.
- **Patching session** (optional, from the home screen) records, for the caregiver's notes:
  - **Patched eye**: left, right or not recorded
  - **Playing eye**: left, right or not recorded. If the same eye is entered for both, the app
    shows a warning.
  - **Session length**: the play time the eye doctor advised, entered by the caregiver (1–60 min).
    The default of 2 minutes only makes the game playable out of the box; it is not a
    recommendation.
  - Start and end time are recorded automatically.
- The app never works out which eye is amblyopic, never suggests patch wear time, and does not use
  the camera, so it cannot and does not claim that the patch is worn or on the correct eye.
- The patching screen includes short guidance for parents and caregivers: patch first, supervise,
  stop if there is discomfort, keep check-ups, and scores are not an eye test.

### Comfort and stopping

- **Pause** (top right) freezes the game clock. Leaving the app pauses automatically.
- The pause screen has **Rest my eyes**, which ends the session straight away and shows the
  summary. It is meant for sore or tired eyes, a headache, or an uncomfortable patch.
- **✕** (top left) asks "Stop the game?" and then also shows the summary.
- Each saved session records why it ended: `timeUp`, `stopped` or `restBreak`.

## Gameplay

1. A character rises out of a hole.
2. The child finds it and taps it. The whole hole area counts, so taps do not need to be precise.
3. The character squashes, a few stars drift out, "+10" floats up and the fox mascot swings its
   hammer. There is no flashing and the motion is short.
4. The character sinks back, and the next one appears somewhere else.

Missed characters only sink back: there is no sound, penalty or score loss for a miss. At the
advanced level some characters are **sleepy** (closed eyes, no star). The child should leave
these alone; tapping one is recorded but never penalised.

## Folder structure

```
WhackAMoleGame/
├── App/            WhackAMoleGameApp (@main, standalone only), GameEntryView
├── Views/          GameHomeView, PatchingSetupView, WhackAMoleGameView, GameBoardView,
│                   GameHUDView, GameResultView
├── Components/     CharacterView, MoleHoleView, ScoreView, FeedbackView (hit effect, fox)
├── ViewModels/     WhackAMoleGameViewModel
├── Models/         GameConfiguration, PatchingConfiguration, GameCharacter, GameSession
├── Managers/       WhackAMoleEngine, SpawnManager, DifficultyProgression, Randomness,
│                   GameSessionManager (session and settings storage), FeedbackPlayer
├── Utilities/      GameConstants (colours)
└── Resources/      Assets.xcassets (Characters/FoxHammer, app icon and accent colour)
```

- **Rules:** the engine, spawn manager and difficulty progression are plain Swift with no UI or
  timers. Time only moves through `WhackAMoleEngine.advance(by:)`, so the rules are fully
  unit-tested and pauses are exact.
- **Timing:** the view model runs a ~60 Hz loop and feeds real elapsed time to the engine.
- **UI:** SwiftUI only; SpriteKit was not needed.

### Xcode targets

The project uses folder-synchronised groups (Xcode 16+), so files added to `WhackAMoleGame/` are
picked up automatically.

| Target | Sources | Entry point | Bundle id |
|---|---|---|---|
| `WhackAMoleGame` (app) | `WhackAMoleGame/` | `WhackAMoleGameApp` | `com.drstrange.whackamole` |
| `DrStrange` (app) | `DrStrange/` + `WhackAMoleGame/` except `App/WhackAMoleGameApp.swift` | `DrStrangeApp` | `com.drstrange.app` |
| `DrStrangeTests` | `DrStrangeTests/` (hosted by DrStrange) | – | – |

The exclusion is a build-file exception on the `WhackAMoleGame` folder, set in **File inspector ▸
Target Membership**. `README.md` is excluded from both apps. Each app has a shared scheme with the
same name.

## Randomization

Everything random goes through `SeededGenerator` (SplitMix64). Each saved session stores its seed,
so a session can be replayed exactly. Set `GameConfiguration.randomSeed` to fix it for QA.

| What | Rule | Why |
|---|---|---|
| Hole | Free, active hole not used in the last `noRepeatWindow` (2) spawns, at least `minimumGridDistance` (1 cell) and at most `maximumGridDistance` (2.3 cells) from the previous one. Rules relax one at a time until at least two holes qualify. Among those, weight `1 / (1 + times used)`. | Characters never reappear in the same spot straight away and are spread across the board. No corner-to-corner jumps, which keeps eye movements comfortable. Avoids predictable cycles: with 3 holes, a strict rule would allow only one hole and produce an A-B-C loop. |
| Interval | Uniform in the level's `spawnIntervalRange`. | Varied but never rushed. |
| Visible time | `visibleDuration × (1 ± jitter)`. | Enough time to find and tap. |
| At once | At most `maxSimultaneousTargets` (1 at beginner, 2 later). | Limits visual load. |
| Look | Shuffle bag over the level's looks: each appears equally often. | Consistent looks within a level, and no look dominates. |
| Decoy | Advanced only, 25 %, never more than two in a row. | Adds identification without long waits. |

This randomization is a gameplay design. It is not a clinically validated protocol.

## Difficulty

| | Beginner | Intermediate | Advanced |
|---|---|---|---|
| Active holes | 3 (one row) | 6 (two rows) | 9 |
| Character size (share of cell) | 0.95 | 0.80 | 0.68 |
| Spawn interval (s) | 2.6–3.6 | 1.9–2.9 | 1.5–2.5 |
| Visible for (s) | 3.2 ±10 % | 2.6 ±10 % | 2.2 ±15 % |
| Max up at once | 1 | 2 | 2 |
| Character looks | 1 | 3 | 4 |
| Sleepy decoys | none | none | 25 % |
| Background | plain | plain | few static, low-contrast decorations in the margins |

Only rows with active holes take space, so beginner characters are also the largest on screen.

**Adjust level from performance** (on by default, can be switched off): after 10 real targets
(decoys excluded), accuracy ≥ 85 % moves up one level and ≤ 50 % moves down one level. Time spent
playing never changes the level. All values in this section are gameplay placeholders for review.
A higher level is a harder game, not a better or stronger treatment.

## Session metrics

The summary screen shows:

- an encouraging message
- characters, hits, missed, accuracy and average response time
- play time, level, session length
- a session record: start and end time, why it ended, patched eye and playing eye

Every session is also saved as JSON in `Application Support/Sessions/WhackAMole/<id>.json`
(`GameSessionRecord`). Each file contains:

- the configuration, with the patching record and random seed
- the end reason
- per-character trials: hole, look, role, level, appear time and outcome
- level changes and off-target taps

The format is meant for a future progress dashboard.

- **Accuracy** = hits / (hits + misses), counting real targets only.
- **Response time** is measured from when the character starts to appear to the tap, in game time
  (pauses excluded), with about 16 ms resolution. It is a gameplay timing, not a clinical reaction
  time.

These are gameplay metrics only. They are not visual acuity measurements and not evidence of
clinical improvement.

## Clinical limitations

- The app cannot see whether the patch is worn or which eye it covers. A caregiver should
  supervise.
- It does not decide or check which eye is amblyopic, and does not recommend patch wear time,
  session length or frequency.
- Game time is not a substitute for prescribed patching hours or for check-ups.
- Difficulty and spawn settings are gameplay choices that have not been validated clinically. Any
  therapeutic use, and every placeholder above, needs review by an ophthalmologist or orthoptist.
- The app has no detection of fatigue or discomfort. Adults should watch for it and use Rest my
  eyes.

## Parameters

| Parameter | Default | Status |
|---|---|---|
| `PatchingConfiguration.patchedEye` / `playingEye` | not recorded | Entered by caregiver from the prescription (documentation only) |
| `GameConfiguration.sessionDuration` | 120 s | Entered by caregiver to match the eye doctor's advice |
| Difficulty tables, spawn rules, adaptive thresholds | see above | Gameplay design; needs clinical review |

## Assets

- **Provided (Google Drive `FRAME PALU`):** 21 frames of the fox mascot swinging a hammer. They
  were cropped to their shared bounds, scaled to 640 px with transparency kept, and stored in
  `Resources/Assets.xcassets/Characters/FoxHammer/Frame01…21`. The fox swings once per hit and
  appears on the home and result screens.
- **Missing:**
  - **Pop-up character art.** The Drive folder has no pop-up characters, so vector placeholders are
    drawn. To use real art, add image sets named `Character<Name>` (awake, with a star) and
    `Character<Name>Sleepy` (decoy) for `Sunny`, `Berry`, `Leafy` and `Sky`. `CharacterView` uses
    them automatically.
  - Board art, gentle sound effects (built-in system sounds stand in), optional background music,
    and an app icon.

## Testing

- `DrStrangeTests`: 32 unit tests covering:
  - spawn rules: no repeats, spacing, no corner jumps, balance, no fixed cycles, seed reproducibility
  - timing, decoys, hits, misses, double taps, the limit on characters up at once
  - session end, stop and rest-break reasons, adaptive levels, JSON round trip
  - patching record validation, and that gameplay is identical whichever eye is patched
- Manual checks on the iPad Pro 11-inch simulator:
  - patching setup, including the same-eye warning
  - play and hit animation
  - pause, Rest my eyes, ✕ then stop
  - result screen and Play again
  - DrStrange app navigation into the game
- Layout checked by screenshot on iPad mini and iPad Pro 13-inch.

## Changes from the first (dichoptic) version

The first version was built for red/cyan glasses. This revision removes:

- anaglyph rendering (`EyeChannelRenderer`, `AnaglyphRenderer`)
- the per-eye split of each character (outline to one eye, face to the other) and its balancing
- the glasses check screen
- eye contrast settings and the display-mode setting

It adds the patching session record, rest-break stopping, end reasons, the corner-to-corner
spacing limit, and the standalone `WhackAMoleGame` target. Gameplay, animations, randomization,
difficulty and session tracking are otherwise unchanged.
