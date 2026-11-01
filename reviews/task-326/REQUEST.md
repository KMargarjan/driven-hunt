# Task 326 -- no tree stands in the air

Task: 326
Round: 1
Base: cf2e6955b84665e18f2c4337ffb96fc41c3cf906 (main)
Code commit: 889ea95ca3f2fadc27a85bdde821249ecf62a8f6

Karen, 2026-11-01: *"also fix broken trees all terai some trees is high in air"*.

```
[harness] PASS: 34/34 checks @ 889ea95ca3f2fadc27a85bdde821249ecf62a8f6 (clean tree) scope=all
```

`test2` N/A: nothing in `TWO_PLAYER_PATHS` is touched (`src/server/Places/`,
`src/shared/TreeGround/`, `src/server/ForestTestBoot.server.luau`, two server specs).

## The instrument

`<runs-dir>/326census.py`: every model in Workspace, measured against the terrain under its
TRUNK's own footprint -- a 5x5 grid over the flare box, corners included, never the pivot
(L-086/L-024). It INJECTS `src/shared/TreeGround/init.luau` the way `tools/forest_ground.py` does,
so the census and the game share one piece of arithmetic. It reports `trunkGapHigh`: the trunk base
above the HIGHEST ground under the footprint -- daylight, the thing an eye sees -- as well as
`TreeGround`'s own lowest-ground number. Saved: `326-census-play-main.json` (before),
`326-census-play-after.json` (after), `326-census-edit-main.json`, `326report.py`.

## BEFORE and AFTER, her Forest Test (place 130094961655666), in Play

| | main `cf2e6955` | code commit `889ea95c` |
|---|---|---|
| `DrivePlaces` trees above the ground by >0.3 | **646** of 3028, worst **1812.81** | **0** of 3253, worst -0.20 |
| `Session` (both folders) | **4** (29.0 / 34.4 / 53.5 / 65.2 studs up) | **0** |
| `OurForest` / `LobbyAssets` | 0 / 0 | 0 / 0 |
| models spanning >300 studs | **329** (worst 2260) | **0** |
| boot line | `3028 planted, 863 on a step` | `3253 planted, 638 on a step, 0 left in the air, 413 re-seated` + `wood re-seated after the lobby: 2` |

The 10 models still over 0.3 are all in `Workspace.Lobby` and none is foliage: four rack guns, a
boar head and the shopkeeper stand on the lodge FLOOR and the four trucks on their wheels. Proven
rather than asserted -- `<runs-dir>/326-under.out` fires an unfiltered ray under each: the
shopkeeper's first hit is `Workspace.Lobby.Lodge.RoofNorth` at y 170.1 with terrain at 150.0. A
terrain-only census cannot see a floor, so these are the census's limit, not a defect.

## Claims

1. **The giants are `Model:ScaleTo` being absolute while `item.scale` is relative.** Measured in
   her place (`326-scale.luau`): 52 of the 61 templates stand at a `Scale` that is not 1 --
   `SilverBirch_Var13_LOD_0` at 0.0413, the larches at 1.4-2.1 -- so `ScaleTo(0.95)` grew that
   birch 23x. One broken clone dumped part by part (`326-broken.out`): the template's `Trunk.011`
   is 4.8 x 84.5 x 5.2, the clone's 124.8 x 2048.0 x 136.9. `plantOne` now calls
   `made:ScaleTo(made:GetScale() * item.scale)`.
2. **The floaters are `plantOne` and `decide` using two different cliff thresholds.** The pre-check
   used `Places.stepAllowance`, `decide` re-checked with `CLIFF_STUDS` (4); in between, `move` was
   false and the clone stayed where `PivotTo` put it, one tree-height up. 536 of the 646 were that
   case. `decide` takes `cliffStuds`; `plantOne` passes the number it already checked with.
3. **Nothing `plantOne` leaves behind stands in the air, by construction.** It re-measures the
   SETTLED model (`Places.isSeated` -> `Places.junctionGap`, read off the model, not off the lift
   just applied) and destroys anything still up, counted as `air`. The boot line reads `0`.
4. **Karen's own standing wood gets the same rule at run time**, since saved place content cannot
   be moved by a commit. `Places.reseat` only ever lowers (`decide` answers `seated` for a buried
   tree), and `Places.reseatAll` reads `Places.STANDING_WOOD` (`OurForest`, `Session`, `Foliage`)
   and NOT `TEMPLATE_SOURCES`, so it can never see the lodge, the trucks or the wall heads in
   `LobbyAssets`. `rootsNamed` takes every match, because Workspace has two folders called
   `Session`. `places.spec` asserts the list against the lobby's own `CLEARING.FOLDERS`.
5. **The second sweep is on the lobby's BUILD edge, and that was measured twice.** `Lobby.start`
   does not build (the build is lazy -- `reportLobby`'s own header). A sweep placed right after
   `start` moved 1 and left two ferns 106 studs west of the lodge at 3.48 and 2.42 studs
   (`326-census-play-326.json`); a sweep run by hand on that same live server moved exactly those
   two, to -0.18 and -0.31 (`326-third.luau`). Moved to `reportLobby`, the boot now prints
   `wood re-seated after the lobby: 2` and the census reads 0.
6. **FAIL FIRST, run.** `src/` checked out at main `cf2e6955` with these specs, one harness run:
   `places.spec:821` (planted trunk size), `:875` (junction above the ground after planting on a
   5-stud step -- the defect itself, measured with helpers that already existed), `:888`
   (`STANDING_WOOD` nil), `:953` (`reseat` nil), `tree_ground.spec:215` (`decide(...,7)` answered
   "cliff", wanted "ok"): `[harness] FAIL: 32/34 ... 5 failed, 5 errors @ a69a1b63 (DIRTY TREE
   (3 paths))`. Verify: `git checkout cf2e6955 -- src/` and re-run. The `reseatAll` case
   (`places.spec`, "sweeps BOTH folders called Session") was written after that control run and its
   bite is argued by reading: `Planter.reseatAll` does not exist at `cf2e6955`.
7. **One settler, not a second ground-fit** (L-024). `reseat`, `plantOne` and `junctionGap` all go
   through `TreeGround.decide` / `junctionY`; no new raycast rule was written.
8. **The counts are printed, not assumed** -- `air` and `reseated` on `ForestTestBoot`'s own line.

## What I could NOT verify

* **No frame; rule 5 is NOT met.** `screen_capture` against that Studio returned the same cached
  image for six different cameras AND for a confirmed character move (`326-before-A-eye.png` ...
  `326-before-S1.png`, `326-test-cam.png`, all the lodge porch). `326frame.py` (park the client
  camera) and `326shot.py` (stand the player at the measured spot) both report success in Luau and
  both yield that frame. Nothing here is claimed from a picture. `ESCALATE.md` has the entry.
* **The live proof used `:34873`, not `:34874`.** The Forest Test's Rojo panel is not open in that
  window (`326-screen6.png`), and `rojo-port.sh` / `reconnect34874.sh` click fixed coordinates, so
  they would have clicked blind into Karen's viewport. Instead `driven-hunt-karen` was checked out
  at the code commit, which is what `:34873` already serves, and **restored to `main` (cf2e6955)
  afterwards** -- verified, with `rojo :34873` still on its original session id. Her place itself
  was never saved, published or committed.
* **"None sunk more than 1.5 studs" is not met and was not attempted.** 721 of the 5,659 standing
  models in her place were ALREADY sunk more than 1.5 by that measure before this task (529 in
  `Workspace.Session`, most at exactly -2.50): that is how the bought map was authored.
  `TreeGround` only ever sinks -- raising saved content is a different question. The sweep's own
  sinking is `TreeGround.sinkFor`, 0.6.
