# Whack-a-Mole (amblyopia game prototype)

A child-friendly Whack-a-Mole game for iPad, built so it can present a **dichoptic** version
of the task (different information to each eye) through red/cyan glasses.

> This is a research and development prototype. It does not treat or cure amblyopia, does not
> replace patching, glasses or any treatment prescribed by an eye-care professional, and its
> scores are game performance, not clinical measurements. Any therapeutic use, including every
> parameter marked "requires clinical validation" below, must be reviewed by an ophthalmologist
> or orthoptist.

## 1. Game flow

```
HomeView ─▶ WhackAMoleSetupView ─▶ WhackAMoleGameView ─▶ GameResultView
             (level + adult settings)  countdown 3-2-1        summary
                                       playing ⇄ paused        play again / done
                                       exit (confirm) ─▶ partial session saved
```

- Characters rise out of holes, stay up for a set time, then sink back.
- Tapping an awake character (open eyes and a star) scores 10 points: the character squashes,
  a few stars drift out, "+10" floats up and the fox mascot swings its hammer.
- A miss is recorded but has **no** sound, penalty or score loss.
- At the advanced level some characters are "sleepy" decoys (closed eyes, no star). Tapping one
  is recorded but never penalised.
- Tapping an empty hole is counted (`offTargetTaps`) and otherwise ignored.
- The whole hole cell is the touch target.
- Pause freezes the game clock; leaving the app pauses automatically. Response times and session
  length only count active play.

## 2. Architecture

The game follows MVVM with the rules kept apart from the UI:

| Layer | Files | Notes |
|---|---|---|
| Models | `Models/GameConfiguration.swift`, `TherapyConfiguration.swift`, `Target.swift`, `GameSession.swift` | Codable, data-driven. Each tunable value carries a `ParameterProvenance` in its doc comment. |
| Logic | `Logic/SpawnManager.swift`, `DifficultyProgression.swift`, `WhackAMoleEngine.swift`, `Randomness.swift` | Pure Swift, no UIKit or timers. Time only moves through `advance(by:)`, so it is fully unit-tested and pauses are exact. |
| Rendering | `Rendering/EyeChannelRenderer.swift` | Maps "this element is for the left eye at contrast c" to a colour. One implementation per display method. |
| View model | `ViewModels/WhackAMoleGameViewModel.swift` | `@Observable`; runs a ~60 Hz loop, feeds real elapsed time to the engine, triggers sound/haptics, saves the session. |
| Views | `Views/*` | SwiftUI only. SpriteKit was not needed: at most nine holes and two characters at once. |
| Services | `Services/FeedbackPlayer.swift`, `WhackAMoleStores.swift` | Sound/haptics; JSON session files and the saved configuration. |

There was no existing code in the repository, so the project, folder layout and conventions are
new. `HomeView` is a placeholder game list; the Lobby feature can link to `WhackAMoleSetupView`
instead.

## 3. Randomization

Everything random goes through `SeededGenerator` (SplitMix64). Each session stores its seed in
`GameSessionRecord.configuration.randomSeed`, so any session can be replayed exactly. Setting
`GameConfiguration.randomSeed` fixes the seed for research or QA.

| What | Rule | Why |
|---|---|---|
| Hole | Free, active hole that was not used in the last `noRepeatWindow` (2) spawns and is at least `minimumGridDistance` (1 cell) from the previous one. Constraints are relaxed one at a time until **at least two** holes qualify. Among the candidates, a hole is picked with weight `1 / (1 + times used)`. | No immediate repeats and spacing between consecutive targets. Coverage evens out across the board without becoming a fixed rotation. The "at least two" rule exists because with 3 holes and a window of 2, only one hole was ever allowed, which made spawns a predictable A-B-C cycle (a unit test caught this). |
| Interval | Uniform draw from the level's `spawnIntervalRange`. | Unpredictable but bounded. |
| Visible time | `visibleDuration × (1 ± jitter)`. | Avoids rhythm-based tapping while keeping difficulty controlled. |
| Simultaneous | Never more than `maxSimultaneousTargets` up at once (1 or 2). If all holes are busy, retry after 0.25 s. | Avoids overloading the child. |
| Look | Shuffle bag over the level's character variants: each look appears once per round, never twice across a refill. | No look is over- or under-represented, so none can act as a hidden cue. |
| Decoy | Probability `decoyProbability` (advanced only, 25 %), never more than two in a row. | Adds identification without long runs of nothing to tap. |
| Eye assignment | Shuffle bag of 10: `round(share × 10)` spawns send the features to the amblyopic eye, the rest to the fellow eye. With no amblyopic eye set, 5 left / 5 right. | Exact balance over every block of 10, so neither eye's stimulus is systematically easier. |

This randomization is a gameplay design. It is not a clinical protocol.

## 4. Difficulty

| | Beginner | Intermediate | Advanced |
|---|---|---|---|
| Active holes | 3 (one row) | 6 (two rows) | 9 |
| Character size (fraction of cell) | 0.95 | 0.80 | 0.68 |
| Spawn interval (s) | 2.6–3.6 | 1.9–2.9 | 1.5–2.5 |
| Visible for (s) | 3.2 ±10 % | 2.6 ±10 % | 2.2 ±15 % |
| Max up at once | 1 | 2 | 2 |
| Character looks | 1 | 3 | 4 |
| Decoys | none | none | 25 % |
| Background decorations | none | none | static, low contrast |

Only rows that contain active holes take up space, so beginner characters are also drawn larger
on screen.

**Performance-based progression** (`AdaptiveDifficultyRules`, switchable in settings): after a full
window of 10 real targets (decoys excluded), accuracy ≥ 85 % moves up one level and ≤ 50 % moves down
one level, and then the window resets. Elapsed time alone never changes the level. A level change
shows a small "Level n" badge. All values are gameplay placeholders. A higher level means a harder
game, **not** a higher therapeutic dose.

## 5. Dichoptic / binocular design

### Background: monocular, occlusion, dichoptic and binocular approaches

- **Monocular therapy / occlusion (patching, atropine penalisation):** the fellow eye is blocked or
  blurred so the amblyopic eye has to work. This is the established standard together with
  refractive correction. It trains one eye at a time and does not directly address binocular
  suppression.
- **Binocular visual training (general):** both eyes are open. Older approaches (for example
  binocular games on an ordinary screen) do not control what each eye sees, so the stronger eye
  can do the whole task.
- **Dichoptic therapy:** each eye receives *different*, complementary images (via filters, polarisation,
  shutters or a head-mounted display). Task-critical information is split between the eyes and the
  fellow eye's image is usually reduced in contrast, so both eyes are needed and suppression of
  the amblyopic eye is counteracted.
- **Evidence status (to be checked by the clinical team):** randomised trials of early iPad anaglyph
  games (for example the PEDIG falling-blocks studies) found less improvement than patching, with
  low adherence as a likely factor. More recent dichoptic treatments that use engaging content
  and headsets or eye-tracked glasses have reported benefits in some trials and have regulatory
  clearance in some markets. Results depend strongly on display method, dose, adherence and
  patient group.

### What this game does

Each character is drawn as two layers:

- **Body (silhouette):** shows *where* a character is. Sent to one eye.
- **Features (eyes, smile, star):** show *whether* it is an awake target or a sleepy decoy. Sent to
  the **other** eye.

Wearing red/cyan glasses, the child needs the body eye to notice and locate a character and the
feature eye to tell targets from decoys (advanced level). The shared board (holes and rim) is
drawn in neutral grey for both eyes at low contrast, which gives the eyes a common frame to fuse on.

How each eye gets its own image (`AnaglyphRenderer`):
- A red filter passes red light. Red ink on a light background looks like the background to that eye
  (invisible) and dark to the eye behind the cyan filter. Cyan ink works the other way round.
- An element for eye E is therefore drawn in the ink that E's filter blocks.
- Layers are combined with `.multiply`, so where a left-eye part overlaps a right-eye part, each
  eye still sees its own part.
- Contrast per eye scales how far the ink departs from the background.
- `GlassesCheckView` shows one shape per eye so an adult can confirm the separation (and see
  crosstalk) with the actual glasses and iPad.

Balance safeguards:
- Feature/body eye assignment is exactly balanced per block of 10 unless a clinician sets
  another share.
- With no amblyopic eye set, both eyes get identical contrast (1.0).
- The fox mascot (full-colour art, which would reach the two eyes unevenly) is shown in greyscale
  in dichoptic mode.
- Session data records per-trial eye assignment, so `GameSessionRecord.accuracy(featureEye:)` can
  check balance afterwards. It is not an acuity measure.

**Standard mode** (no glasses) draws the same characters in full colour. Both eyes see
everything, so it is **not** dichoptic. It is for getting to know the game and for development.

### Extending to a validated dichoptic display

To add a display method, implement `EyeChannelRenderer` and add a `ViewingMode` case. Game
logic, spawn rules and session data stay unchanged. Methods that could be added this way:

- a stereo head-mounted display with a separate image per eye
- a polarised or shutter-glasses display
- an eye-tracked approach

A true per-eye display would replace the colour-ink approach with two separate render passes; the
body/feature split per eye already provides the content for each pass.

## 6. Limitations

Technical:
- An ordinary iPad screen cannot show different images to the two eyes. Separation exists only
  while the child wears correctly oriented red/cyan glasses.
- **Crosstalk:** how well the colours separate depends on the screen's colour primaries (wide-gamut
  P3 panels differ from sRGB) and on the filters. Ghosting is expected and must be measured for
  each iPad and glasses pair. `GlassesCheckView` is a visual check, not a measurement.
- Red and cyan filters pass different amounts of light, so the eyes receive unequal brightness
  even at equal "contrast" settings. Contrast values here are nominal ink contrasts, not
  calibrated photometric contrast.
- There is no check that the glasses are worn, worn the right way round, or that the child is
  not peeking over them. There is no eye tracking or fixation monitoring.
- In children with strabismus, fusion of the shared board is not guaranteed.
- The HUD and menus are binocular (seen by both eyes).
- Response time is measured from when a character starts to appear (game clock, pauses excluded)
  with about 16 ms frame granularity. It is a gameplay timing, not a clinical reaction time.
- Sound uses built-in system sounds as placeholders. Most iPads have no haptic engine.

Clinical:
- The app never infers or decides which eye is amblyopic.
- No contrast ratio, contrast schedule, session length or frequency is prescribed. Defaults are
  neutral placeholders.
- Game metrics (accuracy, response time, level) are not diagnostic and are not evidence of
  improvement.

## 7. Parameters and their status

| Parameter | Default | Status |
|---|---|---|
| `TherapyConfiguration.amblyopicEye` | not set | Must be entered by or for the clinician |
| `amblyopicEyeContrast` | 1.0 | **Requires clinical validation** |
| `fellowEyeContrast` | 1.0 | **Requires clinical validation** (published dichoptic designs reduce it; the starting value and any schedule are clinical decisions) |
| `criticalFeatureAmblyopicShare` | 0.5 | **Requires clinical validation** |
| `GameConfiguration.sessionDuration` | 120 s (options 1/2/3/5 min) | **Requires clinical validation** (session length and frequency) |
| `glasses.redFilterEye` | left | Match the physical glasses |
| `sharedBoardContrast` | 0.35 | Game design; review with the clinical team |
| `anaglyphBackgroundLevel` | 0.94 | Game design; affects crosstalk, so measure it |
| Difficulty tables, spawn rules, adaptive thresholds | see above | Game design placeholders |

## 8. Session data

`GameSessionRecord` (JSON in `Application Support/Sessions/WhackAMole/<id>.json`) contains:

- configuration snapshot with seed
- start and end time, whether the session was completed, active play time
- every trial: hole, look, role, eye assignment, level, spawn time, outcome
- off-target taps and level changes

Derived values:

- **targets spawned:** real targets that finished
- **hits** and **misses**
- **accuracy** = hits / (hits + misses)
- **average response time**
- **decoys shown** and **decoys tapped**

The format is meant to be read later by a progress dashboard.

## 9. Assets

- **Provided (Google Drive `FRAME PALU`):** 21 frames (2048×2048 RGBA) of the fox mascot swinging
  a hammer. They were cropped to the shared bounding box, scaled to 640 px and stored in
  `Assets.xcassets/FoxHammer/Frame01…21`. The fox plays the swing on each hit and appears on the
  home, setup and result screens.
- **Missing:**
  - **Target characters:** vector placeholders (`PlaceholderCritterBody` / `PlaceholderCritterFeatures`)
    are drawn until art arrives. For dichoptic use, each character needs **two transparent PNG
    layers**: a solid silhouette and the features (eyes, mouth, star; plus a sleepy variant).
    Name them `Targets/<Name>Body` and `Targets/<Name>Feature` (`Sunny`, `Berry`, `Leafy`, `Sky`),
    in a `Targets` folder with "Provides Namespace" on. `CharacterView` picks them up
    automatically. In dichoptic mode each layer is tinted as a single ink, so detail inside a layer
    is lost.
  - Hole and board art, a background, sound effects, an app icon.

## 10. Testing

- `DrStrangeTests` contains 32 unit tests covering:
  - seed reproducibility, active-hole limits, spacing and no-repeat rules
  - balanced coverage, no fixed rotation, look and eye balance, decoy runs, timing ranges
  - hits, misses, double taps, the simultaneous limit, session end and early exit
  - adaptive level up and down, JSON round trip, anaglyph ink routing and contrast
- Debug builds accept the launch argument `-WhackAMoleAutostart`, which opens the game directly with
  the saved settings (QA on other screen sizes).

```bash
xcodebuild -scheme DrStrange -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' test
```
