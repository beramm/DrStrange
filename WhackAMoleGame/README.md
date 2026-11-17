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
  - Start and end time are recorded automatically.
- Every game lasts **2 minutes** of play (pauses excluded). This is the length of one round, a
  gameplay choice. It is not a recommended patching or play time, and it cannot be changed in the
  app.
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

**Calibrate & Play** on the home screen runs the gaze calibration and then plays with eye control:
the child looks at a mole to hit it. The moles do not respond to touch.

1. The game starts on an empty painted meadow, with no holes showing and two clouds drifting slowly
   across the sky. A hole opens at a random spot and a mole slides up out of it.
2. The child finds it and keeps looking at it until the gaze dwell completes.
3. The fox's yellow card opens beside that mole: it grows from its centre as a rounded square with
   a slight spring, and a square ring ripples out. Meanwhile the fox fades out of its corner.
4. The fox rises up from the bottom of the card and swings. Its hammer slides out from behind the
   card and lands on the mole's helmet. The mole turns into the sad mole picture, squashes a little,
   then slides back down the hole, and the points float up in an illustrated bubble
   (Perfect, Good or OK). There is no flashing and the motion is short.
5. The hammer slides back behind
   the card, the fox sinks down out of its bottom, the empty card shrinks away and the fox is back
   in its corner.
6. The hole closes. After a short pause another hole opens somewhere else.

The characters are moles in a yellow miner's helmet and a red-and-white striped shirt. They come
out of dirt holes drawn by the artist (three variations, used evenly).
A mole climbs out of the dark opening and stands in it up to its shirt; the hole's front edge hides
the rest. The fox's hammer lands on the helmet. Moles that are not tapped go back down the same way.

Missed moles only sink back: there is no sound, penalty or score loss for a miss. The game can also
show **sleeping** moles (grey, with a "z z" bubble) that the child should leave alone, but the
standard board has none (`decoyProbability` 0). Tapping one is recorded but never penalised, and
the fox does not attack it.

### Scoring

Each gaze hit scores by how close the child's gaze stayed to the centre of the mole during the
dwell (`GazeProximityTier`, the median distance divided by the outer activation radius):

| Bubble | Gaze distance from the centre | Points |
|---|---|---|
| Perfect | up to 0.35 | 60 |
| Good | up to 0.70 | 30 |
| OK | further out, still inside the activation radius | 20 |

A hit without a gaze tier (for example in sessions saved before proximity scoring) counts 10
points. Misses and sleeping-mole taps cost nothing. The points appear when the hammer lands; a hit
made just before the game ends still counts.

### High score

The home screen shows the best score on this iPad, and the result screen shows "New high score!"
when a game beats it (a tie does not). Only that one number is kept, in `UserDefaults`
(`whackAMole.highScore`). Games that were stopped early count too.

### The fox attack

The fox stands in for the player's hammer. When idle it waits in a fixed spot in the bottom-left
corner, in the side margin beside the board, with no frame showing. It only moves after a valid
tap, and it never takes a touch.

The "frame" is the fox's own yellow card from the artwork (rounded, with an orange border).
`FoxWindowView` draws it on its own, using colours and proportions measured from the frames, so
when the fox image fades in on top the two cards line up exactly.

#### Helper characters

The fox has two stand-ins: the raccoon (blue card) and the bunny (green card). `HelperCharacter`
lists every helper. When a game starts, one helper is picked at random, every helper equally
likely, and it stays for the whole game: in the corner and in every attack. Each game picks on its
own, so the same helper can come several games in a row, and nothing makes them take turns.

- Every helper runs exactly the same attack: the same phases, timing, card reveal, placement and
  frame curve. Only the artwork, the card colours, the number of swing frames and where the hammer
  head sits at impact differ.
- The engine picks the helper with its own generator, seeded from the session seed. The pick never
  changes where or when moles appear.
- The home and result screens still show the fox.

The sequence always runs in this order:

| State (`GameInteractionState`) | What happens | Duration |
|---|---|---|
| `idle` | No character on the board; the fox waits in its corner. | – |
| `targetAppearing` | A mole is sliding up out of its hole. | 0.55 s |
| `targetActive` | A character is up and can be selected; the fox waits with its hammer raised. | 5.2 s ±10 % |
| `frameAppearing` | After a valid tap, the yellow card opens beside the character: the whole card, border included, grows from its centre as a rounded square with a slight spring, and a square ring ripples out. The corner fox fades away. | 0.34 s |
| `foxEmerging` | The fox rises up from the bottom of the card, clipped to the inside of the card, with its hammer hidden. | 0.36 s |
| `foxAttacking` | The fox leans in and swings (frames 1→21, speeding up) while the hammer slides out from behind the card. It ends at impact. | 0.36 s |
| `targetHit` | The hammer is on the helmet (frame 21). The mole's hit animation starts and the points bubble floats up. | 0.45 s |
| `foxRetracting` | The sad mole slides back down its hole (0.45 s, carrying on into the next step). The hammer slides back behind the card, then the fox sinks down out of the card's bottom. | 0.36 s |
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
- How far each mole is out of its hole, and whether it is the sad picture, also come from the game
  clock (`WhackAMoleEngine.moleVisual(for:)`), so pausing freezes them too. The clouds are only
  decoration and keep drifting.
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
├── Components/     CharacterView (target), MoleHoleView, ScoreView, FeedbackView (points bubble),
│                   FoxCharacterView, FoxWindowView, AttackAnimationView
├── ViewModels/     WhackAMoleGameViewModel
├── Models/         GameConfiguration, PatchingConfiguration, GameCharacter, GameSession,
│                   FoxAttack (timing, phases, interaction state), HelperCharacter
├── Managers/       WhackAMoleEngine, SpawnManager, Randomness, GameSessionManager (session,
│                   settings and high score storage), FeedbackPlayer
├── Utilities/      GameConstants (colours)
└── Resources/      Assets.xcassets (Characters/FoxHammer, RaccoonHammer and BunnyHammer, app icon and accent colour)
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
| Board area | `boardSpread` limits holes to the central 90 % of the board. Room is kept above the highest holes for the fox's card. | Keeps eye movements comfortable; the fox never covers the top bar. |
| Interval | Uniform in the board's `spawnIntervalRange`. | Varied but never rushed. |
| Visible time | `visibleDuration × (1 ± jitter)`, counted from when the mole starts to appear. | Enough time to find and tap. |
| At once | At most `maxSimultaneousTargets` (2). | Limits visual load. |
| Hole image | Shuffle bag over the three images. | Each is used equally often. |
| Look | Shuffle bag over the board's looks: each appears equally often. | No look dominates. |
| Decoy | `decoyProbability` (0 on the standard board), never more than two in a row. | Adds identification without long waits, if switched on. |

A hole takes 0.28 s to open before its mole starts climbing, and 0.25 s to close after the mole has
gone. Each trial in the session file records the spot where its hole opened (`position`).

This randomization is a gameplay design. It is not a clinically validated protocol.

## Board

There are no levels: every game uses the same board (`DifficultySettings.standard`).

| Setting | Value |
|---|---|
| Zones where holes can open | 6 (two rows) |
| Board area used | central 90 % |
| Hole and mole size | 84 % of the largest size |
| Spawn interval (s) | 1.9–2.9 |
| Visible for (s) | 5.2 ±10 % (long enough for a gaze dwell) |
| Max up at once | 2 |
| Character looks (all the same mole art for now) | 3 |
| Sleeping moles (decoys) | none |

The hole and mole scale together, so the mole always fits its hole as drawn. The board and the
scoring limits always come from the current defaults, even if older settings were saved on the
device. All values in this section are gameplay placeholders for review.

## Session metrics

The summary screen shows:

- an encouraging message, the score, and the high score (or "New high score!")
- characters, hits, missed, accuracy and average response time
- play time
- a session record: start and end time, why it ended, patched eye and playing eye

Every session is also saved as JSON in `Application Support/Sessions/WhackAMole/<id>.json`
(`GameSessionRecord`). Each file contains:

- the configuration, with the board, the patching record and the random seed
- the end reason
- per-character trials: hole, look, role, appear time, outcome and the points awarded (the score is
  their sum)
- off-target taps

Records saved by older versions, with levels and session length, still load; those fields are
ignored.

The format is meant for a future progress dashboard.

- **Accuracy** = hits / (hits + misses), counting real targets only.
- **Response time** is measured from when the character starts to appear to the tap, in game time
  (pauses excluded), with about 16 ms resolution. It is a gameplay timing, not a clinical reaction
  time.
- **Points** come from gaze proximity during the dwell. They are a gameplay score, not a measure of
  fixation or vision.

These are gameplay metrics only. They are not visual acuity measurements and not evidence of
clinical improvement.

## Clinical limitations

- The camera can only infer sustained one-eye versus two-eye visibility from ARKit blink signals.
  It cannot confirm patch material, fit, or the prescription, so a caregiver should supervise.
- It does not decide or check which eye is amblyopic, and does not recommend patch wear time,
  session length or frequency.
- Game time is not a substitute for prescribed patching hours or for check-ups.
- The 2-minute round, the board, the spawn settings and the scoring limits are gameplay choices
  that have not been validated clinically. Any
  therapeutic use, and every placeholder above, needs review by an ophthalmologist or orthoptist.
- The app has no detection of fatigue or discomfort. Adults should watch for it and use Rest my
  eyes.

## Parameters

| Parameter | Default | Status |
|---|---|---|
| `PatchingConfiguration.patchedEye` / `playingEye` | not recorded | Entered by caregiver from the prescription (documentation only) |
| `GameConfiguration.sessionDuration` | 120 s, fixed | Gameplay design (one round); not a recommended play time |
| `DifficultySettings.standard`, `SpawnRules` | see above | Gameplay design; needs clinical review |
| `GazeProximityTier` (Perfect 60 / Good 30 / OK 20, limits 0.35 and 0.70) | see above | Gameplay design; needs clinical review |

## Assets

- **Provided (Google Drive `FRAME PALU`):** 21 frames of the fox mascot swinging a hammer. They
  were cropped to their shared bounds, scaled to 640 px with transparency kept, and stored in
  `Resources/Assets.xcassets/Characters/FoxHammer/Frame01…21`.
  - Frame 1 (hammer raised) is the waiting and emerging pose, frames 1→21 are the attack swing,
    and frame 21 is the impact.
  - The frames include the fox's yellow card background, so the fox flies out as a card. A cut-out
    fox without the card would look more natural, if the artist can supply one.
  - The fox also appears on the home and result screens.
- **Provided (Google Drive, new character folder):** 24 frames (`1`–`24`, 2048 px) of the raccoon
  swinging a hammer, with a blue card. They are stored in
  `Resources/Assets.xcassets/Characters/RaccoonHammer/Frame01…24`.
  - The frames were scaled and placed on a 637 × 640 canvas so that the raccoon's card sits exactly
    where the fox's card is (`FoxCharacterView.cardRect`). Nothing was redrawn, and transparency
    is kept.
  - Frame 1 (hammer raised) is the waiting pose and frame 24 is the impact. The folder has no
    separate idle, emerging or retracting frames, so the raccoon uses the fox's motion for those,
    the same way the fox does.
- **Provided (Google Drive, bunny folder):** 9 frames (`IMG_0200`–`IMG_0204`, `IMG_0224`,
  `IMG_0206`–`IMG_0208`, 2048 px) of the bunny swinging a hammer, with a green card. They are stored
  in `Resources/Assets.xcassets/Characters/BunnyHammer/Frame01…09`.
  - The folder has no `IMG_0205`. `IMG_0224` sits between `IMG_0204` and `IMG_0206` in the swing
    (measured from the hammer's position), so it is used as frame 6.
  - The frames were scaled and placed the same way as the raccoon's, so the bunny's card sits exactly
    where the fox's card is. Nothing was redrawn, and transparency is kept.
  - Frame 1 (hammer raised) is the waiting pose and frame 9 is the impact. The supplied swing is
    short (the hammer only tips forward a little), so the bunny strikes from higher up than the fox
    and the raccoon; the hammer head still lands on the character.
- **Provided (Google Drive):** two mole pictures, replacing the earlier 24-frame rise and hit
  animations so no frame sequence has to load.
  - `IMG_0024` (1119 × 1434), the happy miner mole, stored as `Characters/Mole/Appear`. It is shown
    while the mole climbs out and waits.
  - `Tikus sedih` (674 × 643), the sad mole, stored as `Characters/Mole/Disappear`. It is shown from
    the moment the hammer lands until the mole has sunk back into its hole.
  - Both are stored unchanged. `MoleArt` in `MoleHoleView.swift` records where the helmet is in each
    picture; both are scaled and placed so the helmet is the same size and in the same spot, so the
    swap to the sad mole does not jump.
  - The picture slides up and down, and the hole hides everything below its front edge: when fully
    out, the head and the top of the striped shirt show and the legs stay in the hole.
  - The sad mole stays up for `hitReaction`, then sinks over `exitAnimationDuration`. With Reduce
    Motion the moles fade in and out instead of sliding, with no squash.
  - Awake moles are drawn in full colour; sleeping moles (decoys) in grey with a "z z" bubble.
- **Provided (Google Drive, `BG LAMA`):** the Whack-a-Mole background, a 4:3 painted meadow
  (2752 × 2064) with sky, grass and a fence and no clouds. It is stored unchanged as a PNG in
  `Resources/Assets.xcassets/GameBackgrounds/Meadow`.
  - It fills the screen behind the game with its aspect ratio kept. On 4:3 iPads nothing is cropped;
    on wider iPads a little is cropped at the top and bottom.
  - `GameBackgroundView` holds where the grass is in the painting (37 %–80 % of its height). The
    horizon and fence of this painting are outside that band, so hole positions are unchanged.
- **Provided (Google Drive, `AWAN 1`, `AWAN 2`):** two clouds, painted on canvases the size of the
  background. Each was cropped to its visible area and stored as
  `GameBackgrounds/MeadowCloud1` and `MeadowCloud2`.
  - `DriftingCloud` in `GameBoardView.swift` scales them with the painting, keeps them in the sky,
    and moves them slowly from left to right (a crossing takes one to one and a half minutes); when
    one leaves the screen on the right it comes back in on the left.
  - They move with real time, not the game clock, and never affect play. With Reduce Motion they
    stay still.
- **Provided (Google Drive, hole folder):** `IMG_0021`–`IMG_0023`, three dirt holes. Each was
  cropped to its visible area and stored in `Resources/Assets.xcassets/Holes/Hole1…3`.
  - The dark opening of each was measured from the art (`HoleArt` in `MoleHoleView.swift`).
  - The image is scaled so its opening matches the hole's tap area.
  - The mole is clipped to the area above the middle of the opening plus the opening itself, so it
    disappears behind the front edge.
  - The hole images are small (400–443 px wide), so they can look slightly soft on the largest
    iPads. Larger exports would fix that.
- **Missing:**
  - **More mole art.** There is a single mole, so the "character looks" all show the same
    mole. A sleeping mole (eyes closed) would make decoys clearer than the grey
    version with a bubble.
  - Gentle sound effects (built-in system sounds stand in), optional background music,
    and an app icon.

## Testing

- `DrStrangeTests`: 93 unit tests covering:
  - spawn rules: no repeats, spacing, no corner jumps, balance, no fixed cycles, seed reproducibility
  - timing, decoys, hits, misses, double taps, the limit on characters up at once
  - the 2-minute session end, stop and rest-break reasons, JSON round trip
  - scoring: awarded points add up, no points for misses, the high score keeps only a better
    score, and saved settings always use the current board
  - patching record validation, and that gameplay is identical whichever eye is patched
  - interaction-layer gaze smoothing, including jitter damping and tracking-loss reset
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
  - the mole pictures: the mole slides up and back down, turns sad only when hit, stays up while it
    reacts, and both pictures line up on the helmet so the hammer lands on it
  - the clouds stay in the sky and drift slowly to the right, wrapping round
  - helper characters:
    - every helper's frames are in the asset catalog
    - each helper is equally likely, and the same helper can come in consecutive games
    - one helper for the whole game, in every attack
    - helper choice never changes the spawns
    - the raccoon and the bunny use the same swing over their own frames, and every helper's hammer
      lands on the character
  - one-eye patch-state verification, blink tolerance, removal debounce and re-verification
- Manual checks on the iPad Pro 11-inch simulator:
  - patching setup, including the same-eye warning
  - play and hit animation
  - pause, Rest my eyes, ✕ then stop
  - result screen and Play again
  - DrStrange app navigation into the game
- The fox attack, checked in slow motion with autoplay at 20 % speed:
  - the sequence: the fox emerges and flies to the character, the hammer lands on its head at the
    same moment as the squash and the points, the character sinks, the fox returns, and the next
    character appears after the pause
  - pausing mid-attack freezes the fox, and resuming finishes it
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
