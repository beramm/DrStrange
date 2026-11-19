# Follow the Fox (smooth pursuit game)

A calm, child-friendly iPad game. A friend (the fox, the bunny or the raccoon) walks along a
winding path through a small village, and the child keeps their eyes on it all the way to the
veggie stall. The thief is a mole: it only comes when the child stops following. The friend stops
where it is, and the mole pops up out of a hole under the vegetable basket on the friend's back,
takes a carrot and goes back down. Each carrot taken costs a heart. A game lasts 2 minutes and the
child has 3 hearts.

The game uses the app's on-device gaze tracker (`GazeInputController`, calibrated with
`GazeCalibrationView`). A finger can be used instead for practice or on devices without tracking.

> This is a research and development prototype. It does not treat or cure amblyopia, does not
> replace patching, glasses or any treatment prescribed by an eye-care professional, and does not
> replace clinical follow-up. The carrots on the finish screen are gameplay results, not
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
  six times during the 2 minutes (two of them long enough for the mole to take a carrot, the others short enough
  for the mole to be sent away), so the warning, the refocus and the mole can be checked and
  recorded on a simulator. It is a recording aid only, not gaze tracking.

## Gameplay

1. **Home screen.** **Calibrate & Play** runs the gaze calibration and then starts the game with
   eye control. **Practice with a finger** starts it with touch. There are no levels.
2. **Who to follow.** Each path draws one friend at random from the fox, the bunny and the raccoon;
   only that friend is on the map. None of them is ever the thief: that is always the mole. A card
   shows "Follow Bunny!" and "Mole wants the veggies!". A white oval on the ground marks the friend
   to follow.
3. **Start.** The friend stands at the left end of the path and starts walking when the child has looked at it (or held a finger on it) for a moment. The
   2-minute clock starts with the first look of the game.
4. **Follow.** The friend walks right, and up or down around the bends, while the gaze stays within
   the follow radius around it. It faces sideways when walking right, shows its front going down
   and its back going up.
5. **Off track.** When the gaze leaves the friend for longer than the grace time:
   - the friend stops exactly where it is and keeps facing the way it was walking (it does not
     turn round), standing with its feet together
   - the edges of the screen dim to a soft red and a clear spotlight stays on the friend
   - a dashed ring breathes around the friend, a "!" bubble bobs above it, and a hint tells the
     child to look at it again
   - the ring fills while the child looks at the friend, and it walks on when the ring is full
6. **Next path.** When the friend reaches the veggie stall, a new random path appears, the friend
   to follow is drawn again, and the walk goes on until the time is up.
7. **End.** The game ends when the 2 minutes are up or when the last heart is gone.

The warning never flashes: it fades in and moves slowly. With **Reduce Motion** switched on, the
ring, the bubble and the vignette stay still.

If the tracker loses the face (the child looked away from the iPad, or the camera is covered), the
friend simply waits. This does not count as going off track. If tracking stays poor, the game
offers to recalibrate.

### The thief: the mole

The mole comes **only because the child stopped following**. There is no timer that sends one,
and missing gaze readings never bring one. Exactly:

1. The gaze leaves the friend for longer than the look-away grace (0.55 s): the walk goes off
   track, the friend stops where it is (facing the way it was going) and the attention state
   becomes `notFollowing`.
2. If the child is still not following 0.5 s later (`triggerDelay`), one mole comes, provided
   that no mole is around, the last mole left at least 4 s ago (`cooldown`), at least 3 s of the
   game are left and the friend is not about to reach the stall. Following again, or a missing
   reading, starts the 0.5 s over.
3. Only one mole is ever on the map, so a long stretch of not following brings one mole, not one
   per frame.

| State | What happens |
|---|---|
| `openingHole` | A hole (`Holes/Hole1`, the supplied mole hole) opens on the ground right under the basket on the friend's back (0.35 s). |
| `emerging` | The mole comes up out of the hole (0.6 s). Its feet stay in the hole. |
| `reaching` | It stays upright and stretches up to the basket (0.9 s). At the end it has a carrot: the heart is lost now, once. |
| `sinking` | It goes back down the same hole, holding the carrot over its head (0.6 s). |
| `closingHole` | The hole closes (0.35 s) and nothing is left on the map. |

Where the hole opens depends on which way the friend faces (`FoxWalkPose.bagHolePoint`): in the
side view the basket is behind the body, so the hole is just behind the feet and the mole comes up
in front of the tail, under the basket; in the back view (walking up the map) the basket faces the
player, so the hole is in front of the legs; in the front view (walking down) the basket is hidden
behind the body, so the hole is beside the friend where the mole can still be seen. The hole stays
where it opened, and is always kept on the map.

- **Looking back before the carrot is taken** (the walk refocuses): the mole goes straight back
  down the same hole empty-handed and no heart is lost; the friend walks on from where it
  stopped. A hole that is still opening just closes again.
- **Looking back after the carrot is taken**: the heart stays lost; the mole finishes going down.
- **Tracking unavailable**: the mole holds still where it is, nothing is taken and no heart is
  lost until tracking is usable again. A missing reading never counts as looking away.
- **Reaching the stall** sends a mole that has not taken a carrot back down.

Each mole can take at most one carrot and cost at most one heart. Another mole can come once the
cooldown is over and the child stops following again.

### Decoy moles

While the child follows, harmless decoy moles pop up at random on the grass to tempt the eyes
away (`DecoyMoleSpawner`). A decoy's hole opens, it comes up, stays up for 1.2 s, goes back down
and the hole closes; it never takes anything, never costs a heart and does not react to where
the child looks. Looking at it is what costs: the friend stops, and the real thief comes from under
the basket.

- Only while the child follows the walking friend and no thief is around, and only one at a time.
- The first one pops up 4–7 s into a walk, then one every 4–8 s after the last has gone (random).
- It pops up 240–520 map units from the friend, on open grass: off the path, clear of houses,
  lamps and other things that stand, below the top bar and on the map. If there is no room
  nearby, it tries again half a second later.
- A new walk clears it. Its random times and spots come from the game seed, so a fixed seed
  replays them.

### Hearts and time

- The top bar shows only the lives, the time bar and the pause button.
- The game starts with **3 hearts**, shown in the top bar as three carrots. Each carrot the mole takes costs one,
  and that carrot turns grey; hearts never go below zero. With no hearts left the game ends (**Game over**).
- The time bar fills up as the game goes on, next to the time left (M:SS, from 2:00). At 0:00 the
  game ends (**Time's up!**). The 2 minutes are one game, not a recommended play or patching time,
  and cannot be changed.
- When the game ends, everything stops: the walk, the mole and the clock.

### Zoom

- A **pinch** zooms freely, from the whole map (1×) to 2.5×. The top bar has no zoom buttons.
- Zoomed in, the camera follows the fox, looks a little ahead of it and stops at the map edges.
- The follow radius grows with the fox when the map is zoomed in.

### Comfort and stopping

- **Pause** freezes the game clock, the walk and the thief. Leaving the app pauses the game and the gaze camera
  automatically; the camera starts again on return and the game waits for **Resume**.
- The pause screen has **Rest my eyes**, which ends the game straight away and shows the result.
  It is meant for sore or tired eyes, a headache, or an uncomfortable patch.
- **✕** asks "Stop the game?" first.
- **Pause** (the painted wooden button, top right) freezes the game clock, the walk and the mole. Leaving the app pauses the game and the gaze camera
  automatically; the camera starts again on return and the game waits on the pause screen.
- The pause screen is the shared "Game paused" pop-up (`GamePausePopup`, also used by Whack-a-Mole
  and Veggie Keeper), shown over the dimmed game. It has three
  round buttons: **Home** (back to the lobby start screen, ending the game; the Follow the Fox
  home in the standalone app), **Restart** (a fresh game with a new map) and **Play** (carry on).
  The close button in the corner also carries on. Home is the way to stop when the child's eyes
  are sore or tired, or the patch is uncomfortable.
- With eye control, if both eyes stay visible for 1 second the game pauses behind the shared
  patch reminder (`WhackAMoleGame/Views/PatchReminderScreen.swift`). When the one-eye check
  passes again the reminder closes and the game carries on without a tap.

## Folder structure

```
FoxPathGame/
├── App/            FoxPathGameApp (@main, standalone only), FoxPathEntryView
├── Views/          FoxPathHomeView, FoxPathGameView, FoxPathResultView
├── Components/     FoxPathMapView (tiles, scenery, characters), FoxFocusOverlay (warning, ring,
│                   hints, role card), FoxPathHUDView (carrots, time bar, pause)
├── ViewModels/     FoxPathGameViewModel
├── Models/         FoxPathConfiguration, FoxPathMap (grid, tiles, sprites), FoxRoute,
│                   FoxWalkPose (walk animation frames, the stopped pose), PathCharacter (the
│                   three friends, who to follow)
├── Managers/       FoxPathGenerator (random map), FoxPathEngine (one walk), FoxPathSession (clock,
│                   hearts, who to follow, when the mole comes), FoxPathThief (the mole's rules
│                   and where its hole opens), FoxPathDecoyMoles (decoy moles on the grass),
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
  `trackingUnavailable`) for the session and the mole. The mole never reads the pointer itself.
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
`nil` in normal play). From it come every map and every draw of the friend to follow, so the same
seed replays the same game for the same play. The mole comes only from the child's attention.

- **Who to follow.** One friend is drawn from all three, again for every new path. The thief is
  always the mole.
- **Path.** It runs from the left edge to the right edge of a 12 × 9 grid and only goes right, up
  or down, never back. The length of each straight stretch (2–3 tiles) and the height of each turn
  (1–3 rows) are drawn at random, and the path stays in the middle rows so houses fit above and
  below it. The last three tiles are always straight so the finish stall fits above them.
- **Houses.** Four or five carrot, mushroom and onion houses are shuffled and spread along the
  map: each one first tries its own share of the width, so they do not bunch up on one side.
  They take turns above and below the path, so both sides have about as many houses (at most one
  more on one side) and neither side looks empty. When a house does not fit on its side, another
  kind of house is tried there before the other side. A house above the path shows its front with
  the door; a house below shows its back, may stand farther down the map and may be partly cut by
  the bottom edge.
- **Stepping stones.** Every front door has at least two stepping stones, and neighbouring doors
  get different layouts: a trail that wiggles from the door down to the path (up to six stones),
  two stones side by side below the door (sometimes with a third below them), or a trail that
  leaves the door at a slant and ends on the grass. Small and large stones are mixed in every
  layout. A house seen from behind sometimes has one or two stones beside it.
- **Finish stall.** The veggie stall stands just above the end of the path, near the right edge,
  and the friend stops in front of the middle of its counter.
- **Lamps** stand beside the path, spread along the whole walk.
- **Signpost.** Every map has exactly one "Veggies Stall / Farm" signpost, on the grass beside a
  level part of the path in the first part of the walk. Above the path it stands just behind the
  fox; below it, it stands far enough down that its top stays on the grass and it never covers
  the fox. It is a little larger than the lamps (205 × 202 map units). A map with no room for it
  is drawn again, like a map with too few houses or lamps.
- **Tree stumps.** Two to four stumps stand at random spots on the grass, some mirrored and in
  slightly different sizes, away from the path and from everything else. They change with every map.
- The signpost and the stumps keep clear of the top strip of the map, where the top bar sits.
- **Rocks by the path.** Seven to ten grey rocks sit just beside the path, spread along the whole
  walk on alternating sides, never on the path itself.
- **Gardens.** The open grass that is left gets small gardens, always in the emptiest spot first:
  a bed of onions coming up through the soil, a clump of leafy plants, leafy plants with a pair
  of baskets, or the baskets beside a few onions. They keep off the path, out from under the top
  bar, off the stepping stones and rocks, and never cover the friend. No veggie crates.
- **Grass tufts, soil specks and grass patches** are scattered over the remaining grass.
- **Clearance.** Nothing stands on the path, and nothing that is drawn in front of the friend may
  cover it anywhere along the route (checked against the largest of the three characters).

## Settings

There are no levels. Every game uses `FoxPathSettings.standard`:

| Setting | Value |
|---|---|
| Walking speed (map units per second; one tile is 128 wide; was 68) | 100 |
| Follow radius (screen points at 1× zoom) | 190 |
| Look-away grace (s) | 0.55 |
| Refocus dwell (s) | 0.4 |
| Straight stretch between turns (tiles) | 2–3 |
| Turn height (rows) | 1–3 |
| Game length | 2 min |
| Hearts | 3 |

Mole timings (`ThiefSettings`): trigger delay 0.5 s, cooldown 4 s, no mole with less than 3 s
left or within 100 map units of the stall, hole opens 0.35 s, comes up 0.6 s, reaches 0.9 s (the
carrot is taken, and the heart lost, at the end), goes down 0.6 s, hole closes 0.35 s.

## Finish screen

When the game ends (time up or no carrots left), `FoxPathResultView` shows the finish screen, laid
out like the Whack-a-Mole one: the cream `SettingsCard` panel on the lobby vines, three stars with
light shining from behind them, the "Great job" ribbon, **Life Remaining** with the carrots left
(`FoxPath/Carrots0…3`, one grey carrot per life lost), and three round buttons. The three stars
stay gold whatever the result.

- **Restart** starts a fresh Veggie Dash game.
- **Next** goes on to Whack a Mole or Veggie Keeper, picked at random with equal chance when the
  button is tapped (`MiniGame.randomNext(after:)`), never Veggie Dash again. Only shown inside the
  DrStrange app.
- **Home** goes back to the lobby start screen (the Follow the Fox home in the standalone app).

The first tap disables the buttons, so repeated taps cannot navigate twice. Veggie Dash has no
score or high score.

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
  child. The wait count, the hearts and the catches must not be read as a measure of smooth pursuit
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
    still. A friend that stops because the child looked away keeps its facing and shows the first
    picture of that view (feet together).
  - The veggies the mole is after are the small basket every character wears on its back in
    the supplied art.
- **The mole** (`Mole/`): standing (`FoxPath/Mole/Standing`) and holding a carrot over its head
  (`FoxPath/Mole/Carrot`), each cropped from its supplied picture. The carrot picture was drawn
  smaller, so it is shown 1.6× larger to keep the body the same size. The hole is `Holes/Hole1`
  from the supplied mole holes, already in the Whack-a-Mole catalog. There are no separate
  emerging, reaching or retracting frames: the mole rises out of and sinks into the hole by
  hiding everything below the middle of the hole, stays upright and stretches up a little while it
  reaches, and switches to the carrot picture once it has the carrot. Decoy moles use the standing
  picture and the same hole.
- **The House** (`Houses/`): front and back views of the carrot, mushroom and onion houses.
- **The Path** (`Tiles/`, `Decorations/`): horizontal, vertical and curved path tiles (the curve is
  rotated and mirrored for all four corners), grass patches, the lamp, grass tufts and soil specks.
- **Street decorations in front of the houses** (`Decorations/SteppingStone`, from
  `Hiasan jalan depan rumah.png`, which replaces the earlier lower-resolution copy of the same
  stone) and **road rocks** (`Decorations/PathRock`, from `BATU JALAN.png`). Both are cropped from
  their canvases and drawn at the tile scale (about 0.22 map units per pixel).
- **Finish stall** (`Decorations/FinishStall`): the "Veggies" market stall, supplied as a separate
  file (`FINISH.png`).
- **Signpost** (`Decorations/Signpost`, from `petunjuk`) and **tree stump** (`Decorations/TreeStump`,
  from `kayu`), each cropped from its 2752 × 2064 canvas.
- **Top bar** (`HUD/`): the three carrots for the lives in four states (`Carrots3` full, then
  `Carrots2`, `Carrots1` and `Carrots0` with one, two and three grey carrots from the right),
  cropped from the four supplied pictures (`full`, `-1`, `-2`, `-3`; the second version, with no
  panel behind the carrots), and the painted wooden pause button. The carrots, the time
  bar and the button share one height (64 points).
- **Garden pieces** (`Decorations/LeafyPlant`, `Decorations/OnionSprout`, `Decorations/Baskets`):
  extra scenery made for this game, cut from the house and veggie stall art. The veggie crate
  from the same art is not used.
- **Drawn in code:** the warning overlay, the focus ring, the role card, the ground oval under the
  friend, and the time bar.
- **Missing:** dedicated sound effects (built-in system sounds stand in), optional background
  music, an app icon, a separate running animation (the walk cycle stands in), and
  dedicated nature props such as trees, bushes or flowers.

## Testing

- `DrStrangeTests` has 67 unit tests for this game:
  - `FoxPathSessionTests` (25): every friend can be the one to follow and it is drawn again for
    each path, the clock starts at the first look and stops at exactly 2 minutes, time up removes
    a mole that is still around, stopping ends everything, no mole while the child keeps following
    (no timer), missing gaze never brings a mole or costs a heart, a mole comes only after a
    stretch of not following, never a second mole at once, the cooldown, no mole near the end of
    the game, of the walk or between walks, the hole opens under the basket and stays there and on
    the map, the mole opens its hole, comes up, takes exactly one carrot (one heart), goes down
    holding it and leaves nothing behind, it rises and sinks without jumps, showing up costs no
    heart, looking back before the theft sends it away empty-handed (also while the hole is still
    opening), looking back after the theft does not give the heart back, missing gaze freezes it
    and costs nothing, three thefts end the game and nothing happens after, reaching the stall
    sends the mole away, old saved settings with a level still load, the trigger delay and
    cooldown are unchanged, and the walk is faster than before
  - `FoxPathDecoyMoleTests` (7): decoys pop up only while the child follows, the first one comes at
    a random time in its range, one at a time at random intervals, a decoy pops up, goes back down
    and leaves nothing, decoys pop up on open grass near the friend (off the path, clear of houses
    and on the map), a new walk clears the decoy, and the same seed replays the same decoys
  - `FoxPathMoleTests` (9): a stopped friend keeps its place and facing (never turns to the
    player) for all three friends, it faces the player only before the walk and at the stall, the
    walk carries on from where it stopped, the hole is behind the friend in the side view, in front
    of the legs in the back view and beside it in the front view, the mole and hole pictures are in
    the catalog, and both mole pictures are the same size
  - `FoxPathGeneratorTests` (15): seed reproducibility and variety, the path only goes right, up or
    down and never crosses itself, the route stays on the path tiles, scenery never stands on the
    path or covers the character, houses do not overlap, every map has houses, lamps and one
    finish stall, houses are balanced above and below the path and spread over both halves, only
    the supplied scenery is used, every front door has stepping stones in sizes and layouts that
    vary, rocks and stones stay off the path, every map has one signpost and two to four tree stumps
    that stay clear of the path, the character and each other and change between maps, the stall stands
    behind the end of the route, every picture exists in the asset catalog, and every walk cycle
    follows the distance walked
  - `FoxPathEngineTests` (8): nothing counts before the first look, the start dwell, walking speed,
    a short look away is forgiven, a long one stops the walk once, a glance does not refocus, lost
    tracking holds the walk without counting, and the finish fires once
  - `FoxPathCameraTests` (3): the whole map is centred at 1×, zoom limits, and at every zoom the
    view stays inside the map with the character on screen along the whole route (at the new
    walking speed)
- **Not yet checked:** eye control on a real iPad (the simulator has no camera), and pinch zoom on
  a real device.
