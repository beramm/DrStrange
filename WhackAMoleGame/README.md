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

Debug builds accept these launch arguments (Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Arguments):

- `-WhackAMoleAutostart`: skips the home screen and starts a game with the saved settings. Useful
  for checking layouts on different iPad sizes.
- `-WhackAMoleAutoplay YES`: taps each awake character 0.6 s after it appears.
- `-WhackAMoleTimeScale 0.2`: runs game time at 20 % speed, to look at the fox animation closely.

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
- The app never works out which eye is amblyopic or suggests patch wear time. Its on-device camera
  heuristic requires the selected right eye to remain visible while the other eye is obscured; it
  cannot confirm the patch material, fit, or prescription.
- The patching screen includes short guidance for parents and caregivers: patch first, supervise,
  stop if there is discomfort, keep check-ups, and scores are not an eye test.

### Comfort and stopping

- **Pause** (top right) freezes the game clock. Leaving the app pauses automatically.
- If both eyes remain visible for 1 second, the game pauses. Play stays disabled until only the
  selected right eye has been consistently visible again for 1.5 seconds.
- The pause screen has **Rest my eyes**, which ends the session straight away and shows the
  summary. It is meant for sore or tired eyes, a headache, or an uncomfortable patch.
- **✕** (top left) asks "Stop the game?" and then also shows the summary.
- Each saved session records why it ended: `timeUp`, `stopped` or `restBreak`.

## Gameplay

1. A character rises out of a hole.
2. The child finds it and taps it. The whole hole area counts, so taps do not need to be precise.
3. The fox leaves its window in the bottom-left corner and flies to that character, swinging its
   hammer.
4. The hammer lands on the character's head. The character squashes, a few stars drift out and
   "+10" floats up. There is no flashing and the motion is short.
5. The character sinks into its hole while the fox flies back into its window.
6. After a short pause the next character appears somewhere else.

Missed characters only sink back: there is no sound, penalty or score loss for a miss. At the
advanced level some characters are **sleepy** (closed eyes, no star). The child should leave
these alone; tapping one is recorded but never penalised, and the fox does not attack it.

### The fox attack

The fox stands in for the player's hammer. It lives in a small wooden window beside the board, in
the side margin, so it never covers a hole or takes a touch. It only leaves after a valid tap.

| State (`GameInteractionState`) | What happens | Duration |
|---|---|---|
| `idle` | No character on the board; the fox is home. | – |
| `targetAppearing` | A character is rising out of its hole. | 0.38 s |
| `targetActive` | A character is up and can be tapped; the fox waits with its hammer raised. | per level |
| `foxEmerging` | After a valid tap, the fox rises out of its window (frame 1, hammer raised). | 0.28 s |
| `foxAttacking` | The fox flies to the tapped character while swinging (frames 1→21, speeding up). It ends at impact. | 0.42 s |
| `targetHit` | The hammer is on the character's head (frame 21); the character squashes, with stars and "+10". | 0.38 s |
| `foxReturning` | The character sinks; the fox flies home, lifting the hammer (frames 21→1). | 0.34 s |
| `nextTarget` | The fox is home; a short pause before the next character may appear. | 0.4 s |

The durations are `FoxAttackTiming` in `GameConfiguration` (gameplay placeholders).

Rules, enforced in `WhackAMoleEngine` and covered by unit tests:

- Only an awake character that is up can start an attack, and the fox attacks the character that
  was tapped.
- Taps on empty holes never start an attack.
- While an attack runs, every tap is ignored. Rapid or repeated taps cannot start a second attack,
  and attacks never overlap.
- No new character appears during an attack. Characters already up are not penalised: their hide
  timer is paused while the fox is busy.
- The hit and response time are recorded at the tap; points and the hit sound arrive at impact.
  The tapped character cannot hide or disappear before the hammer lands.
- Stopping the game during an attack cancels it. Play again starts with the fox at home.

How the animation is driven:

- The engine's game clock drives the animation, not SwiftUI timers. `AttackAnimationView` works
  out the fox's position, size and frame from the attack progress on every frame.
- So pausing freezes the fox exactly, and the impact frame always lines up with the character's
  reaction.
- The fox stands to the right of its target and swings left. For characters in the right-hand
  column it is mirrored and stands on the left.
- With Reduce Motion on, the fox stays in its window and swings there.

## Folder structure

```
WhackAMoleGame/
├── App/            WhackAMoleGameApp (@main, standalone only), GameEntryView
├── Views/          GameHomeView, PatchingSetupView, WhackAMoleGameView, GameBoardView,
│                   GameHUDView, GameResultView
├── Components/     CharacterView (target), MoleHoleView, ScoreView, FeedbackView (stars),
│                   FoxCharacterView, FoxWindowView, AttackAnimationView
├── ViewModels/     WhackAMoleGameViewModel
├── Models/         GameConfiguration, PatchingConfiguration, GameCharacter, GameSession,
│                   FoxAttack (timing, phases, interaction state)
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

- The camera can only infer sustained one-eye versus two-eye visibility from ARKit blink signals.
  It cannot confirm patch material, fit, or the prescription, so a caregiver should supervise.
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
  `Resources/Assets.xcassets/Characters/FoxHammer/Frame01…21`.
  - Frame 1 (hammer raised) is the waiting and emerging pose, frames 1→21 are the attack swing,
    and frame 21 is the impact.
  - The frames include the fox's yellow card background, so the fox flies out as a card. A cut-out
    fox without the card would look more natural, if the artist can supply one.
  - The fox also appears on the home and result screens.
- **Missing:**
  - **Pop-up character art.** The Drive folder has no pop-up characters, so vector placeholders are
    drawn. To use real art, add image sets named `Character<Name>` (awake, with a star) and
    `Character<Name>Sleepy` (decoy) for `Sunny`, `Berry`, `Leafy` and `Sky`. `CharacterView` uses
    them automatically.
  - Board art, gentle sound effects (built-in system sounds stand in), optional background music,
    and an app icon.

## Testing

- `DrStrangeTests`: 50 unit tests covering:
  - spawn rules: no repeats, spacing, no corner jumps, balance, no fixed cycles, seed reproducibility
  - timing, decoys, hits, misses, double taps, the limit on characters up at once
  - session end, stop and rest-break reasons, adaptive levels, JSON round trip
  - patching record validation, and that gameplay is identical whichever eye is patched
  - the fox attack:
    - starts only on a valid tap, aims at the tapped character, and runs its phases in order
    - the character waits for the impact
    - rapid taps start one attack, nothing spawns during an attack, and spawning resumes after
    - other characters don't hide meanwhile, and decoys don't trigger it
    - stopping cancels it
    - frame mapping
    - the hammer lands on the tapped character, normal and mirrored
    - the fox stays home when idle or with Reduce Motion
    - settings saved by older versions still load
  - one-eye patch-state verification, blink tolerance, removal debounce and re-verification
- Manual checks on the iPad Pro 11-inch simulator:
  - patching setup, including the same-eye warning
  - play and hit animation
  - pause, Rest my eyes, ✕ then stop
  - result screen and Play again
  - DrStrange app navigation into the game
- The fox attack, checked in slow motion with autoplay at 20 % speed:
  - the sequence: the fox emerges and flies to the character, the hammer lands on its head at the
    same moment as the squash and "+10", the character sinks, the fox returns, and the next
    character appears after the pause
  - pausing mid-attack freezes the fox, and resuming finishes it
- Advanced level (9 holes, decoys) checked on iPad Pro 11-inch and iPad mini.
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
