# Follow the Fox (smooth pursuit game)

A calm, child-friendly iPad game. A friend (the fox, the bunny or the raccoon) walks along a
winding path through a small village, and the child keeps their eyes on it all the way to the
veggie stall. Another friend plays the thief and sneaks towards the vegetables whenever the child
stops following. A game lasts 2 minutes and the child has 3 hearts.

The game uses the app's on-device gaze tracker (`GazeInputController`, calibrated with
`GazeCalibrationView`). A finger can be used instead for practice or on devices without tracking.

> This is a research and development prototype. It does not treat or cure amblyopia, does not
> replace patching, glasses or any treatment prescribed by an eye-care professional, and does not
> replace clinical follow-up. The numbers on the result screen are gameplay results, not
> measurements of vision, of eye movements or of treatment progress. Which eye to patch, for how
> long, and how often are decided by the child's ophthalmologist or orthoptist, never by the app.

## Run it in Xcode

1. Open `DrStrange.xcodeproj` in Xcode (27 or later).
2. In the scheme menu at the top of the window, choose **FoxPathGame**.
3. Choose an iPad. Gaze tracking needs the front camera, so use a real iPad for **Calibrate &
   Play**. On a simulator, use **Practice with a finger**.
4. Press **Cmd + R**.

The game starts on its own home screen. The **DrStrange** scheme still builds the main app, which
opens the same game from its home screen ("Follow the Fox").

Command line:

```bash
xcodebuild -scheme FoxPathGame -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build
xcodebuild -scheme DrStrange -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' test
```

Debug builds accept these launch arguments (Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Arguments):

- `-FoxPathAutostart`: skips the home screen and starts a game with the saved settings and finger
  input. Useful for checking layouts on different iPad sizes.
- `-FoxPathSimulatedGaze YES`: moves a pretend pointer that follows the character and looks away
  five times during the 2 minutes, three of them for 8 seconds, so the warning, the refocus and the
  thief can be checked and recorded on a simulator.

## Gameplay

1. **Home screen.** **Calibrate & Play** runs the gaze calibration and then starts the game with
   eye control. **Practice with a finger** starts it with touch. There are no levels.
2. **Roles.** Each path draws a primary character at random from the fox, the bunny and the
   raccoon, and a thief from the other two. A card shows "Follow Bunny!" and "Raccoon wants the
   veggies!". A white oval on the ground marks the friend to follow and a red one marks the thief.
3. **Start.** The friend stands at the left end of the path and starts walking when the child has
   looked at it (or held a finger on it) for a moment. The 2-minute clock starts with the first
   look of the game.
4. **Follow.** The friend walks right, and up or down around the bends, while the gaze stays within
   the follow radius around it. It faces sideways when walking right, shows its front going down
   and its back going up.
5. **Off track.** When the gaze leaves the friend for longer than the grace time:
   - the friend stops and waits where it is
   - the edges of the screen dim to a soft red and a clear spotlight stays on the friend
   - a dashed ring breathes around the friend, a "!" bubble bobs above it, and a hint tells the
     child to look at it again
   - the ring fills while the child looks at the friend, and it walks on when the ring is full
6. **Next path.** When the friend reaches the veggie stall, a new random path appears, the roles
   are drawn again, and the walk goes on until the time is up.
7. **End.** The game ends when the 2 minutes are up or when the last heart is gone.

The warning never flashes: it fades in and moves slowly. With **Reduce Motion** switched on, the
ring, the bubble and the vignette stay still.

If the tracker loses the face (the child looked away from the iPad, or the camera is covered), the
friend simply waits. This does not count as going off track. If tracking stays poor, the game
offers to recalibrate.

### The thief

Only one thief is ever on the map. It comes at a random time, 8–14 s after a path starts and then
10–18 s after the previous thief has left, and never when fewer than 12 s are left in the game or
when the friend is about to reach the stall.

| State | What happens |
|---|---|
| `appearing` | The thief walks into view from below the map or from its right edge (1.5 s). |
| `approaching` | It moves towards the stall only while the child is **not following** (the friend has stopped after the grace time): 6 s of not following take it all the way. While the child follows, it backs off at half that speed. When tracking is unavailable, it waits. After 14 s it gives up and leaves. |
| `stealing` | At the stall it rummages in the vegetables for 1.2 s. A theft that has started always finishes. |
| `retreating` | It runs back off the map (2 s). |

A finished theft costs exactly one heart. When the friend reaches the stall, a thief that has not
started stealing runs off. The thief always walks along a straight line from out of sight to the
front of the stall, chosen so it does not walk through a house or a lamp; it never jumps.

### Hearts and time

- The game starts with **3 hearts**, shown in the top bar. Each theft takes one; hearts never go
  below zero. With no hearts left the game ends (**Game over**).
- The top bar counts down from **02:00** (MM:SS). At 00:00 the game ends (**Time's up!**). The
  2 minutes are one game, not a recommended play or patching time, and cannot be changed.
- When the game ends, everything stops: the walk, the thief, the clock and any thief that was due.

### Zoom

- The **magnifier buttons** in the top bar zoom in and out in steps, and a **pinch** zooms freely,
  from the whole map (1×) to 2.5×.
- Zoomed in, the camera follows the fox, looks a little ahead of it and stops at the map edges.
- The follow radius grows with the fox when the map is zoomed in.

### Comfort and stopping

- **Pause** freezes the game clock, the walk and the thief. Leaving the app pauses the game and the gaze camera
  automatically; the camera starts again on return and the game waits for **Resume**.
- The pause screen has **Rest my eyes**, which ends the game straight away and shows the result.
  It is meant for sore or tired eyes, a headache, or an uncomfortable patch.
- **✕** asks "Stop the game?" first.

## Folder structure

```
FoxPathGame/
├── App/            FoxPathGameApp (@main, standalone only), FoxPathEntryView
├── Views/          FoxPathHomeView, FoxPathGameView, FoxPathResultView
├── Components/     FoxPathMapView (tiles, scenery, characters), FoxFocusOverlay (warning, ring,
│                   hints, role card), FoxPathHUDView (timer, hearts, zoom, pause)
├── ViewModels/     FoxPathGameViewModel
├── Models/         FoxPathConfiguration, FoxPathMap (grid, tiles, sprites), FoxRoute,
│                   FoxWalkPose (walk animation frames), PathCharacter (the three friends, roles)
├── Managers/       FoxPathGenerator (random map), FoxPathEngine (one walk), FoxPathSession (clock,
│                   hearts, roles, thief timing), FoxPathThief (thief rules and way in),
│                   FoxPathCamera (zoom and follow), FoxPathFeedback (sounds and haptics)
├── Utilities/      FoxPathPalette (colours)
└── Resources/      Assets.xcassets (FoxPath/Fox, Bunny, Raccoon, Houses, Tiles, Decorations, app
                    icon, accent)
```

- **Rules:** `FoxPathEngine`, `FoxPathSession`, `FoxPathThief`, `FoxPathGenerator` and
  `FoxPathCamera` are plain Swift with no UI or timers. Time only moves through `advance(by:…)` and
  `update(delta:…)`, so the rules are unit-tested and pauses are exact.
- **Timing:** the view model runs a ~60 Hz display-link loop. Each frame it works out whether the
  gaze (or the finger) is on the friend, away from it or unavailable, feeds that to the walk, then
  turns the walk's state into a `PlayerAttentionState` (`following`, `notFollowing`,
  `trackingUnavailable`) for the session and the thief. The thief never reads the pointer itself.
- **Shared code:** the gaze tracker, the calibration screen, `ParameterProvenance`, the seeded
  random generator and a few small views come from `WhackAMoleGame/`.
- **UI:** SwiftUI only.

### Xcode targets

The project uses folder-synchronised groups (Xcode 16+), so files added to `FoxPathGame/` are
picked up automatically.

| Target | Sources | Entry point | Bundle id |
|---|---|---|---|
| `FoxPathGame` (app) | `FoxPathGame/` + `WhackAMoleGame/` except `App/WhackAMoleGameApp.swift` | `FoxPathGameApp` | `com.drstrange.foxpath` |
| `DrStrange` (app) | `DrStrange/` + `WhackAMoleGame/` + `FoxPathGame/` except the two game `@main` files | `DrStrangeApp` | `com.drstrange.app` |
| `DrStrangeTests` | `DrStrangeTests/` (hosted by DrStrange) | – | – |

The exclusions are build-file exceptions on the game folders, set in **File inspector ▸ Target
Membership**. `README.md` files are excluded from every app.

## Randomization

Every game draws a fresh seed (`FoxPathConfiguration.randomSeed` fixes it for research or QA; it is
`nil` in normal play). From it come every map, every role draw and every thief time, so the same
seed replays the same game for the same play.

- **Roles.** The primary character is drawn from all three friends and the thief from the other two,
  again for every new path.
- **Path.** It runs from the left edge to the right edge of a 12 × 9 grid and only goes right, up
  or down, never back. The length of each straight stretch (2–3 tiles) and the height of each turn
  (1–3 rows) are drawn at random, and the path stays in the middle rows so houses fit above and
  below it. The last three tiles are always straight so the finish stall fits above them.
- **Houses.** Carrot, mushroom and onion houses are shuffled and placed along the path. A house
  above the path shows its front with the door, and stepping stones lead from the door towards the
  path. A house below the path shows its back and may be partly cut by the bottom edge.
- **Finish stall.** The veggie stall stands just above the end of the path, near the right edge,
  and the friend stops in front of the middle of its counter.
- **Lamps, grass tufts, soil specks and grass patches** are scattered around the path.
- **Thief's way in** and its timing, as described above.
- **Clearance.** Nothing stands on the path, and nothing that is drawn in front of the friend may
  cover it anywhere along the route (checked against the largest of the three characters).

## Settings

There are no levels. Every game uses `FoxPathSettings.standard`:

| Setting | Value |
|---|---|
| Walking speed (map units per second; one tile is 128 wide) | 68 |
| Follow radius (screen points at 1× zoom) | 190 |
| Look-away grace (s) | 0.55 |
| Refocus dwell (s) | 0.4 |
| Straight stretch between turns (tiles) | 2–3 |
| Turn height (rows) | 1–3 |
| Game length | 2 min |
| Hearts | 3 |

## Result screen

The result screen shows, for this one game only:

- why it ended: **Time's up!**, **Game over** (no hearts left) or **Time to rest!** (stopped)
- the hearts left
- the time played, the paths finished and how many times the friend had to wait

These are gameplay numbers. **Nothing from a game is saved**: no results, no gaze samples, no gaze
paths and no camera frames. Only the settings (sound, haptics, gaze marker) are remembered on the
device.

## Clinical limitations

- The game has not been clinically validated. It makes no claim to treat amblyopia or to improve
  vision, eye movements or attention.
- The app never works out which eye is amblyopic, never suggests how long or how often to play,
  and does not check whether a patch is worn.
- Gaze tracking is a front-camera estimate with limited accuracy. "On the fox" means "within the
  follow radius according to the tracker", so a wait can be caused by the tracker as well as by the
  child. The wait count, the hearts and the thefts must not be read as a measure of smooth pursuit
  or attention.
- "Not following" means only that the gaze estimate stayed outside the follow radius for longer
  than the grace time. Missing gaze readings are never treated as not following.
- Speeds, radii and timings were chosen for playability and need review by an ophthalmologist or
  orthoptist before any clinical use.
- An adult should supervise play and stop the game if the child has discomfort, sore or tired
  eyes, or a headache.

## Parameters

Every tunable value is in `FoxPathConfiguration.swift` (`FoxPathSettings.standard`,
`ThiefSettings`, the session length and the hearts) and is marked `ParameterProvenance.gameDesign`: a gameplay placeholder that is configurable and subject to
clinical review. Map geometry (grid size, tile size, path width) is in `FoxPathMetrics`, and the
zoom range in `FoxPathCamera`.

## Assets

All pictures come from the Google Drive folders supplied for this game and are stored in
`Resources/Assets.xcassets/FoxPath/`. They were cropped to their content and scaled down with
transparency kept.

- **The characters** (FOX, BUNNY and RACCOON folders; `MAJU` side, `DEPAN` front, `BELAKANG`
  back). Each animation is cropped to one box shared by all its frames and scaled to 640 px high;
  the three keep the artist's relative sizes (the fox is 219 map units tall).
  - **Fox** (`Fox/`, asset names `FoxPath/Side01…`, `FoxPath/Front1…4`, `FoxPath/Back1…4`).
  - **Bunny** (`Bunny/`, `FoxPath/Bunny/…`): 45 supplied side frames, 23 of them unique.
  - **Raccoon** (`Raccoon/`, `FoxPath/Raccoon/…`): 43 supplied side frames, 22 of them unique.
  - Each side walk plays forward and back in the supplied files, so only the unique pictures are
    in the catalog and `PathCharacter.sideSequence` lists the order they play in. The walk cycle
    advances with the distance walked, so the feet do not slide and a waiting character stands
    still. The thief uses the side view mirrored when it walks left, and its back view, looping,
    while it takes vegetables.
- **The House** (`Houses/`): front and back views of the carrot, mushroom and onion houses.
- **The Path** (`Tiles/`, `Decorations/`): horizontal, vertical and curved path tiles (the curve is
  rotated and mirrored for all four corners), grass patches, the lamp, stepping stones, grass tufts
  and soil specks.
- **Finish stall** (`Decorations/FinishStall`): the "Veggies" market stall, supplied as a separate
  file (`FINISH.png`).
- **Drawn in code:** the warning overlay, the focus ring, the role card, the ground ovals under the
  friend and the thief, and the HUD (timer and hearts).
- **Missing:** dedicated sound effects (built-in system sounds stand in), optional background
  music, an app icon, and a separate stealing or running animation (the walk cycle stands in).

## Testing

- `DrStrangeTests` has 37 unit tests for this game:
  - `FoxPathSessionTests` (16): every character can be the primary or the thief but never both,
    the thief is the other character of the walk, roles are drawn again for each path, the clock
    starts at the first look and stops at exactly 2 minutes, stopping ends everything, the first
    thief comes at a random time in range, only one thief at a time, the thief only gets closer
    while the child is not following and backs off while following, it never jumps, missing gaze
    never costs a heart, a theft costs exactly one heart, three thefts end the game and nothing
    happens after, reaching the stall chases the thief away, no thief near the end of the game or
    of the walk, the thief's way in starts out of sight and ends at the stall, and old saved
    settings with a level still load
  - `FoxPathGeneratorTests` (10): seed reproducibility and variety, the path only goes right, up or
    down and never crosses itself, the route stays on the path tiles, scenery never stands on the
    path or covers the character, houses do not overlap, every map has houses, lamps and one
    finish stall, the stall stands behind the end of the route, every picture of all three
    characters exists in the asset catalog, and every walk cycle follows the distance walked
  - `FoxPathEngineTests` (8): nothing counts before the first look, the start dwell, walking speed,
    a short look away is forgiven, a long one stops the walk once, a glance does not refocus, lost
    tracking holds the walk without counting, and the finish fires once
  - `FoxPathCameraTests` (3): the whole map is centred at 1×, zoom limits, and at every zoom the
    view stays inside the map with the character on screen along the whole route
- **Not yet checked:** eye control on a real iPad (the simulator has no camera), and pinch zoom on
  a real device.
