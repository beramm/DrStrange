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

1. The game starts on an empty painted meadow, with no holes showing. A hole opens at a random spot and a
   mole climbs out of it, frame by frame.
2. The child finds it and taps it. The whole hole area counts, so taps do not need to be precise.
3. The fox's yellow card opens beside that mole: it grows from its centre as a rounded square with
   a slight spring, and a square ring ripples out. Meanwhile the fox fades out of its corner.
4. The fox rises up from the bottom of the card and swings. Its hammer slides out from behind the
   card and lands on the mole's helmet. The mole screws up its face, plays its 24-frame hit
   animation sinking back down the hole, and "+10" floats up. There is no flashing and the motion
   is short.
5. The hammer slides back behind
   the card, the fox sinks down out of its bottom, the empty card shrinks away and the fox is back
   in its corner.
6. The hole closes. After a short pause another hole opens somewhere else.

The characters are moles in a yellow miner's helmet and a red-and-white striped shirt. They come
out of dirt holes drawn by the artist (three variations, used evenly).
A mole climbs out of the dark opening and stands in it up to its shirt; the hole's front edge hides
the rest. The fox's hammer lands on the helmet. Moles that are not tapped go back down the same way.

Missed moles only sink back: there is no sound, penalty or score loss for a miss. At the advanced
level some moles are **asleep**: drawn in grey with a "z z" bubble. The child should leave these
alone; tapping one is recorded but never penalised, and the fox does not attack it.

### The fox attack

The fox stands in for the player's hammer. When idle it waits in a fixed spot in the bottom-left
corner, in the side margin beside the board, with no frame showing. It only moves after a valid
tap, and it never takes a touch.

The "frame" is the fox's own yellow card from the artwork (rounded, with an orange border).
`FoxWindowView` draws it on its own, using colours and proportions measured from the frames, so
when the fox image fades in on top the two cards line up exactly.

The sequence always runs in this order:

| State (`GameInteractionState`) | What happens | Duration |
|---|---|---|
| `idle` | No character on the board; the fox waits in its corner. | – |
| `targetAppearing` | A mole is climbing out of its hole (24 frames). | 0.55 s |
| `targetActive` | A character is up and can be tapped; the fox waits with its hammer raised. | per level |
| `frameAppearing` | After a valid tap, the yellow card opens beside the character: the whole card, border included, grows from its centre as a rounded square with a slight spring, and a square ring ripples out. The corner fox fades away. | 0.34 s |
| `foxEmerging` | The fox rises up from the bottom of the card, clipped to the inside of the card, with its hammer hidden. | 0.36 s |
| `foxAttacking` | The fox leans in and swings (frames 1→21, speeding up) while the hammer slides out from behind the card. It ends at impact. | 0.36 s |
| `targetHit` | The hammer is on the helmet (frame 21). The mole's hit animation starts and "+10" floats up. | 0.45 s |
| `foxRetracting` | The mole's climb plays backwards (0.45 s, carrying on into the next step). The hammer slides back behind the card, then the fox sinks down out of the card's bottom. | 0.36 s |
| `frameDisappearing` | The empty card shrinks back to its centre; the fox fades back in at its corner. | 0.28 s |
| `nextTarget` | A short pause before the next character may appear. | 0.3 s |

The view model also exposes the fox's own state as `FoxAnimationState`: `idle`,
`frameAppearing`, `foxEmerging`, `attacking`, `targetHit`, `foxRetracting` and
`frameDisappearing`.

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
  out the fox's position, size, opacity and animation frame, and the card's reveal and scale,
  from the attack progress on every frame.
- So pausing freezes the fox exactly, and the impact frame always lines up with the character's
  reaction.
- The fox stands to the right of its target and swings left. For characters in the right-hand
  column it is mirrored and stands on the left.
- The card is drawn behind the fox. While the fox lunges and swings, only the fox's own card
  (part of the image) is shown, so the two never sit out of line.
- While the fox rises or sinks, only the inside of its own card is drawn (no border, no hammer),
  clipped to the inside of the drawn card, so nothing slides across the card's edge.
- The hammer sticks out of the card in the artwork. It is kept hidden until the swing starts, then
  the part of the image beside the card slides out from behind the card's edge. It slides back the
  same way afterwards, so it never pops in outside the frame.
- Mole frames also come from the game clock (`WhackAMoleEngine.moleVisual(for:)`), so pausing
  freezes them too.
- One phase starts only when the previous one has finished, because every phase comes from the
  same attack clock. There are no separate timers or delays to drift apart.
- With Reduce Motion on, the fox stays in its corner and swings there, no card opens, and moles
  fade in and out instead of climbing.

## Folder structure

```
WhackAMoleGame/
├── App/            WhackAMoleGameApp (@main, standalone only), GameEntryView
├── Views/          GameHomeView, PatchingSetupView, WhackAMoleGameView, GameBoardView,
│                   GameHUDView, GameResultView
├── Components/     CharacterView (target), MoleHoleView, ScoreView, FeedbackView (+10),
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

No holes are shown in advance, so the child cannot tell where the next mole will be. Each hole is
placed in two steps: first a zone of a hidden 3 x 3 grid, then a random spot inside that zone.

| What | Rule | Why |
|---|---|---|
| Zone | A free, allowed zone not used in the last `noRepeatWindow` (2) spawns, at least `minimumGridDistance` (1 zone) and at most `maximumGridDistance` (2.3 zones) from the previous one. Rules relax one at a time until at least two zones qualify. Among those, weight `1 / (1 + times used)`. | Spreads moles over the board without a pattern. No corner-to-corner jumps, which keeps eye movements comfortable. |
| Spot | A random point inside the zone, at least `minimumHoleSeparation` (0.42 of the area used) from other open holes and, where possible, from the previous hole. Clearing open holes comes first. Holes open only on the painted grass, below the horizon and above the fence. | Positions are continuous, not a fixed set, and holes do not overlap. |
| Board area | `boardSpread` limits holes to the central 75 % / 90 % / 100 % of the board by level. Room is kept above the highest holes for the fox's card. | Shorter eye movements for beginners; the fox never covers the top bar. |
| Interval | Uniform in the level's `spawnIntervalRange`. | Varied but never rushed. |
| Visible time | `visibleDuration × (1 ± jitter)`, counted from when the mole starts to appear. | Enough time to find and tap. |
| At once | At most `maxSimultaneousTargets` (1 at beginner, 2 later). | Limits visual load. |
| Hole image | Shuffle bag over the three images. | Each is used equally often. |
| Look | Shuffle bag over the level's looks: each appears equally often. | Consistent looks within a level, and no look dominates. |
| Decoy | Advanced only, 25 %, never more than two in a row. | Adds identification without long waits. |

A hole takes 0.28 s to open before its mole starts climbing, and 0.25 s to close after the mole has
gone. Each trial in the session file records the spot where its hole opened (`position`).

This randomization is a gameplay design. It is not a clinically validated protocol.

## Difficulty

| | Beginner | Intermediate | Advanced |
|---|---|---|---|
| Zones where holes can open | 3 (one row) | 6 (two rows) | 9 |
| Board area used | central 75 % | central 90 % | all |
| Hole and mole size | 100 % | 84 % | 72 % |
| Spawn interval (s) | 2.6–3.6 | 1.9–2.9 | 1.5–2.5 |
| Visible for (s) | 3.2 ±10 % | 2.6 ±10 % | 2.2 ±15 % |
| Max up at once | 1 | 2 | 2 |
| Character looks (all the same mole art for now) | 1 | 3 | 4 |
| Sleeping moles (decoys) | none | none | 25 % |

The hole and mole scale together, so the mole always fits its hole as drawn.

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
  `Resources/Assets.xcassets/Characters/FoxHammer/Frame01…21`.
  - Frame 1 (hammer raised) is the waiting and emerging pose, frames 1→21 are the attack swing,
    and frame 21 is the impact.
  - The frames include the fox's yellow card background, so the fox flies out as a card. A cut-out
    fox without the card would look more natural, if the artist can supply one.
  - The fox also appears on the home and result screens.
- **Provided (Google Drive, mole animation folder):** 24 frames (`1`–`24 END`) of the miner mole
  climbing out of a hole, stored in `Resources/Assets.xcassets/Characters/MoleRise/Frame01…24`.
  - The frames were painted with the mole and hole together. The dirt was removed by its colour so
    the moles can sit in the three separate hole images, and each frame still ends along the hole's
    front edge. All 24 frames share one crop.
  - `MoleArt` in `MoleHoleView.swift` records where the frames sit relative to the hole's front edge.
- **Provided (Google Drive, mole hit folder):** 24 frames (`1`–`24`) of the mole being punched and
  sinking into its hole, stored in `Resources/Assets.xcassets/Characters/MoleHit/Frame01…24`. They
  were cut out from the painted dirt the same way as the rise frames, keeping the small "ouch" ticks
  beside the helmet, and play over `hitReaction` + `exitAnimationDuration` (0.9 s).
  - Awake moles are drawn in full colour; sleeping moles (decoys) in grey with a "z z" bubble.
- **Provided (Google Drive, background folder):** `Background whackamole.png`, a 4:3 painted meadow
  with sky, grass and a fence. It is stored as a JPEG in
  `Resources/Assets.xcassets/GameBackgrounds/Meadow`, fills the screen behind the game, and is cropped
  slightly at the top and bottom on wider iPads. `GameBackgroundView` holds where the grass is in the
  painting.
- **Provided (Google Drive, hole folder):** `IMG_0021`–`IMG_0023`, three dirt holes. Each was
  cropped to its visible area and stored in `Resources/Assets.xcassets/Holes/Hole1…3`.
  - The dark opening of each was measured from the art (`HoleArt` in `MoleHoleView.swift`).
  - The image is scaled so its opening matches the hole's tap area.
  - The mole is clipped to the area above the middle of the opening plus the opening itself, so it
    disappears behind the front edge.
  - The hole images are small (400–443 px wide), so they can look slightly soft on the largest
    iPads. Larger exports would fix that.
- **Missing:**
  - **More mole art.** There is a single mole animation, so the per-level "character looks" all
    show the same mole. A sleeping mole (eyes closed) would make decoys clearer than the grey
    version with a bubble.
  - Gentle sound effects (built-in system sounds stand in), optional background music,
    and an app icon.

## Testing

- `DrStrangeTests`: 67 unit tests covering:
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
