# Follow the Fox (smooth pursuit game)

A calm, child-friendly iPad game. A fox walks along a winding path through a small village, and the
child keeps their eyes on it all the way to the veggie stall. If the child looks away for too long, the fox
stops and waits, a gentle warning shows where to look, and the walk goes on once the child has
found the fox again.

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
- `-FoxPathSimulatedGaze YES`: moves a pretend pointer that follows the fox and looks away three
  times, so the warning and the refocus can be checked and recorded on a simulator.

## Gameplay

1. **Home screen.** The child picks a level. **Calibrate & Play** runs the gaze calibration and
   then starts the game with eye control. **Practice with a finger** starts it with touch.
2. **Start.** The fox stands at the left end of the path. It starts walking when the child has
   looked at it (or held a finger on it) for a moment.
3. **Follow.** The fox walks right, and up or down around the bends, while the gaze stays within
   the follow radius around it. It faces sideways when walking right, shows its front going down
   and its back going up.
4. **Off track.** When the gaze leaves the fox for longer than the grace time:
   - the fox stops and waits where it is
   - the edges of the screen dim to a soft red and a clear spotlight stays on the fox
   - a dashed ring breathes around the fox, a "!" bubble bobs above it, and a hint tells the child
     to look at the fox again
   - the ring fills while the child looks at the fox, and the fox walks on when it is full
5. **Finish.** The fox reaches the veggie stall at the right end of the path, stops in front of its
   counter, and the result screen shows.

The warning never flashes: it fades in and moves slowly. With **Reduce Motion** switched on, the
ring, the bubble and the vignette stay still.

If the tracker loses the face (the child looked away from the iPad, or the camera is covered), the
fox simply waits. This does not count as going off track. If tracking stays poor, the game offers
to recalibrate.

### Zoom

- The **magnifier buttons** in the top bar zoom in and out in steps, and a **pinch** zooms freely,
  from the whole map (1×) to 2.5×.
- Zoomed in, the camera follows the fox, looks a little ahead of it and stops at the map edges.
- The follow radius grows with the fox when the map is zoomed in.

### Comfort and stopping

- **Pause** freezes the game clock. Leaving the app pauses automatically.
- The pause screen has **Rest my eyes**, which ends the game straight away and shows the result.
  It is meant for sore or tired eyes, a headache, or an uncomfortable patch.
- **✕** asks "Stop the game?" first.

## Folder structure

```
FoxPathGame/
├── App/            FoxPathGameApp (@main, standalone only), FoxPathEntryView
├── Views/          FoxPathHomeView, FoxPathGameView, FoxPathResultView
├── Components/     FoxPathMapView (tiles, scenery, fox), FoxFocusOverlay (warning, ring, hints),
│                   FoxPathHUDView (progress, zoom, pause)
├── ViewModels/     FoxPathGameViewModel
├── Models/         FoxPathConfiguration, FoxPathMap (grid, tiles, sprites), FoxRoute,
│                   FoxWalkPose (walk animation frames)
├── Managers/       FoxPathGenerator (random map), FoxPathEngine (rules), FoxPathCamera (zoom and
│                   follow), FoxPathFeedback (sounds and haptics)
├── Utilities/      FoxPathPalette (colours)
└── Resources/      Assets.xcassets (FoxPath/Fox, Houses, Tiles, Decorations, app icon, accent)
```

- **Rules:** `FoxPathEngine`, `FoxPathGenerator` and `FoxPathCamera` are plain Swift with no UI or
  timers. Time only moves through `advance(by:reading:)` and `update(delta:…)`, so the rules are
  unit-tested and pauses are exact.
- **Timing:** the view model runs a ~60 Hz loop. Each frame it works out whether the gaze (or the
  finger) is on the fox, away from it or unavailable, and feeds that to the engine.
- **Shared code:** the gaze tracker, the calibration screen, `DifficultyLevel`,
  `ParameterProvenance`, the seeded random generator and a few small views come from
  `WhackAMoleGame/`.
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

Every game draws a new map from a fresh seed (`FoxPathGenerator.makeMap(seed:settings:)`):

- **Path.** It runs from the left edge to the right edge of a 12 × 9 grid and only goes right, up
  or down, never back. The length of each straight stretch and the height of each turn are drawn
  from the level's ranges, and the path stays in the middle rows so houses fit above and below it.
  The last three tiles are always straight so the finish stall fits above them.
- **Houses.** Carrot, mushroom and onion houses are shuffled and placed along the path. A house
  above the path shows its front with the door, and stepping stones lead from the door towards the
  path. A house below the path shows its back and may be partly cut by the bottom edge.
- **Finish stall.** The veggie stall stands just above the end of the path, near the right edge,
  and the fox stops in front of the middle of its counter.
- **Lamps, grass tufts, soil specks and grass patches** are scattered around the path.
- **Clearance.** Nothing stands on the path, and nothing that is drawn in front of the fox may
  cover it anywhere along the route.

The same seed and level always give the same map. `FoxPathConfiguration.randomSeed` fixes the seed
for research or QA; it is `nil` in normal play.

## Difficulty

Levels are gameplay settings only. They do not stand for a therapeutic intensity.

| | Beginner | Intermediate | Advanced |
|---|---|---|---|
| Fox speed (map units per second; one tile is 128 wide) | 48 | 68 | 90 |
| Follow radius (screen points at 1× zoom) | 230 | 190 | 160 |
| Look-away grace (s) | 0.7 | 0.55 | 0.4 |
| Refocus dwell (s) | 0.35 | 0.4 | 0.45 |
| Straight stretch between turns (tiles) | 2–3 | 2–3 | 1–2 |
| Turn height (rows) | 1–2 | 1–3 | 2–4 |

There is no automatic level change in this game.

## Result screen

The result screen shows, for this one game only:

- stars: 3 when the fox had to wait at most once, 2 for up to four waits, otherwise 1
- the time the walk took
- how many times the fox had to wait
- the level

These are gameplay numbers. **Nothing from a game is saved**: no results, no gaze samples, no gaze
paths and no camera frames. Only the settings (level, sound, haptics, gaze marker) are remembered
on the device.

## Clinical limitations

- The game has not been clinically validated. It makes no claim to treat amblyopia or to improve
  vision, eye movements or attention.
- The app never works out which eye is amblyopic, never suggests how long or how often to play,
  and does not check whether a patch is worn.
- Gaze tracking is a front-camera estimate with limited accuracy. "On the fox" means "within the
  follow radius according to the tracker", so a wait can be caused by the tracker as well as by the
  child. The wait count must not be read as a measure of smooth pursuit.
- Speeds, radii and timings were chosen for playability and need review by an ophthalmologist or
  orthoptist before any clinical use.
- An adult should supervise play and stop the game if the child has discomfort, sore or tired
  eyes, or a headache.

## Parameters

Every tunable value is in `FoxPathConfiguration.swift` (`FoxPathSettings.defaults(for:)`) and is
marked `ParameterProvenance.gameDesign`: a gameplay placeholder that is configurable and subject to
clinical review. Map geometry (grid size, tile size, path width) is in `FoxPathMetrics`, and the
zoom range in `FoxPathCamera`.

## Assets

All pictures come from the three Google Drive folders supplied for this game and are stored in
`Resources/Assets.xcassets/FoxPath/`. They were cropped to their content and scaled down with
transparency kept.

- **The Fox** (`Fox/`): `Side01…39` (walking right; a subset of the supplied frames makes up the
  walk cycle), `Front1…4` (walking down, towards the viewer) and `Back1…4` (walking up). The walk
  cycle advances with the distance walked, so the feet do not slide and a paused fox stands still.
- **The House** (`Houses/`): front and back views of the carrot, mushroom and onion houses.
- **The Path** (`Tiles/`, `Decorations/`): horizontal, vertical and curved path tiles (the curve is
  rotated and mirrored for all four corners), grass patches, the lamp, stepping stones, grass tufts
  and soil specks.
- **Finish stall** (`Decorations/FinishStall`): the "Veggies" market stall, supplied as a separate
  file (`FINISH.png`).
- **Drawn in code:** the warning overlay, the focus ring and the HUD.
- **Missing:** dedicated sound effects (built-in system sounds stand in), optional background
  music, and an app icon.

## Testing

- `DrStrangeTests` adds 22 unit tests for this game:
  - `FoxPathGeneratorTests`: seed reproducibility and variety, the path only goes right, up or
    down and never crosses itself, the route stays on the path tiles, scenery never stands on the
    path or covers the fox, houses do not overlap, every map has houses, lamps and one finish
    stall, the stall stands on the map behind the end of the route, every
    picture exists in the asset catalog, and the walk cycle follows the distance walked
  - `FoxPathEngineTests`: nothing counts before the first look at the fox, the start dwell, walking
    speed, a short look away is forgiven, a long one stops the fox once, a glance does not refocus,
    lost tracking holds the fox without counting, the finish fires once, and the star thresholds
  - `FoxPathCameraTests`: the whole map is centred at 1×, zoom limits, and at every zoom the view
    stays inside the map with the fox on screen along the whole route
- Manual checks on the iPad Pro 13-inch simulator with finger input and with the simulated pointer:
  a new map on every launch, the walk with side and front poses, the off-track warning and refocus,
  zoom in and out, pause, and the result screen.
- **Not yet checked:** eye control on a real iPad (the simulator has no camera), and pinch zoom on
  a real device.
