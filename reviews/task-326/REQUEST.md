# Task 326 -- no tree stands in the air

Task: 326
Round: 1
Base: cf2e6955b84665e18f2c4337ffb96fc41c3cf906 (main)
Code commit: a69a1b63478eee26651eeb5682ed43e06bb9184f

Karen, 2026-11-01: *"also fix broken trees all terai some trees is high in air"*.

```
[harness] PASS: 34/34 checks @ a69a1b63478eee26651eeb5682ed43e06bb9184f (clean tree) scope=all
```

`test2` N/A: no path in `TWO_PLAYER_PATHS` is touched (`src/server/Places/`,
`src/shared/TreeGround/`, `src/server/ForestTestBoot.server.luau`, two server specs).

## What changed

`src/shared/TreeGround/init.luau` -- `decide` takes the caller's own cliff allowance.
`src/server/Places/init.luau` -- the scale is relative; one allowance; nothing is left in the air;
`Places.reseat` puts Karen's own standing wood back on the ground at boot; `STANDING_WOOD`.
`src/server/ForestTestBoot.server.luau` -- the boot line carries the two new counts.
`tests/server/places.spec.luau`, `tests/server/tree_ground.spec.luau` -- five cases.

## MEASURED BEFORE (her Forest Test, place 130094961655666, at main cf2e6955)

Census of EVERY model in Workspace against the terrain under its TRUNK's own footprint -- a 5x5
grid over the flare box, corners included, never the pivot (L-086/L-024). Instrument:
`<runs-dir>/326census.py`, which injects `src/shared/TreeGround/init.luau` the way
`tools/forest_ground.py` does, so the census and the game use one piece of arithmetic.
Saved: `<runs-dir>/326-census-play-main.json`, `326-census-edit-main.json`.

```
IN PLAY   8723 models   DrivePlaces 3028: 646 with the trunk base >0.3 above the ground
                        (536 reason "cliff", 58 "no-ground", 52 "ok"), worst 1812.81 studs
                        882 of the 3028 over 120 studs tall; 125 spanning >300, worst 1394
IN EDIT   5659 models   4 float (all `Workspace.Session`, 29.0 / 34.4 / 53.5 / 65.2 studs up)
                        OurForest 4819: worst 0.03 -- the 65 `forest_ground.py check` lists are
                        cliff-edge footprints whose trunk DOES touch the ground on the high side
[ForestTestBoot] places: 3 dressed, 3028 planted (6932 parts), 0 skipped, 863 on a step,
                 0 missing, 720 paint call(s), 1172 leaf part(s) unblocked, 2.71s
```

## Claims

1. **The giants are `Model:ScaleTo` being absolute while `item.scale` is relative.** Measured in
   her place (`<runs-dir>/326-scale.luau`): 52 of the 61 templates stand at a `Scale` that is not
   1 -- `SilverBirch_Var13_LOD_0` at 0.0413, the larches at 1.4-2.1 -- so `ScaleTo(0.95)` grew that
   birch 23x. Verify: the probe's list, and one broken clone dumped part by part
   (`<runs-dir>/326-broken.out`): template `Trunk.011` is 4.8 x 84.5 x 5.2, the clone 124.8 x 2048
   x 136.9. `plantOne` now calls `made:ScaleTo(made:GetScale() * item.scale)`.
2. **The floaters are `plantOne` and `decide` using two different cliff thresholds.** The
   pre-check used `Places.stepAllowance`, `decide` re-checked with `CLIFF_STUDS` (4); in between,
   `move` was false and the clone stayed where `PivotTo` put it. `decide` now takes `cliffStuds`
   and `plantOne` passes the number it already checked with.
3. **Nothing `plantOne` leaves behind stands in the air, by construction.** It re-measures the
   SETTLED model (`Places.isSeated` -> `Places.junctionGap`, read off the model, not off the lift
   that was applied) and destroys anything still up, counted as `air`.
4. **Karen's own standing wood gets the same rule at run time.** `Places.reseat` lowers a floating
   model and never raises a buried one (`decide` only ever sinks). It reads `Places.STANDING_WOOD`
   (`OurForest`, `Session`, `Foliage`) and NOT `TEMPLATE_SOURCES`, so it can never see the lodge,
   the trucks or the wall heads in `LobbyAssets`. `rootsNamed` takes every match, because Workspace
   has two folders called `Session`.
5. **FAIL FIRST, run.** `src/` checked out at main cf2e6955 with these specs, one harness run:
   `places.spec:821` (planted trunk size), `:875` (junction above the ground after planting on a
   5-stud step), `:888` (`STANDING_WOOD` nil), `:953` (`reseat` nil), `tree_ground.spec:215`
   (`decide(...,7)` answered "cliff", wanted "ok") -- `[harness] FAIL: 32/34 ... 5 failed, 5 errors
   @ a69a1b63 (DIRTY TREE (3 paths))`. Verify: `git checkout cf2e6955 -- src/` and re-run.
6. **The `air` and `reseated` counts are printed, not assumed** -- `ForestTestBoot`'s own line.
7. **One settler, not a second ground-fit** (L-024). `reseat`, `plantOne` and `junctionGap` all go
   through `TreeGround.decide` / `junctionY`; no new raycast rule was written.

## What I could NOT verify

* **THE AFTER CENSUS IN HER PLACE AT THE CODE COMMIT IS NOT DONE.** Pointing her Forest Test at
  `:34874` needs its Rojo panel, and the panel is not open in that window
  (`<runs-dir>/326-screen.png`); `rojo-port.sh` / `reconnect34874.sh` click fixed coordinates and
  would have clicked blind. `ESCALATE.md` has the entry. Her place was left on `:34873`, untouched.
* **No frame.** `screen_capture` against that Studio returned the same cached image for six
  different cameras and for a confirmed character move (`<runs-dir>/326-before-*.png`,
  `326-test-cam.png`, `326-before-S1.png`); `326frame.py` (park the client camera) and
  `326shot.py` (stand the player there) both report success in Luau and both yield that same frame.
  So rule 5 is NOT met and nothing here is claimed from a picture.
