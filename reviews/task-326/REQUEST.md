# Task 326 -- no tree stands in the air

Task: 326
Round: 2
Base: cf2e6955b84665e18f2c4337ffb96fc41c3cf906 (main)
Code commit: 5ebe4b4cef72ae78cdd3b9861e446d460d4d578a

Karen, 2026-11-01: *"also fix broken trees all terai some trees is high in air"*.

```
[harness] PASS: 34/34 checks @ 5ebe4b4cef72ae78cdd3b9861e446d460d4d578a (clean tree) scope=all
```

`test2` N/A: nothing in `TWO_PLAYER_PATHS` is touched. Three files change against main:
`src/shared/TreeGround/init.luau`, `src/server/Places/init.luau` and two server specs.
`src/server/ForestTestBoot.server.luau` is back to main byte for byte.

## The three round-1 findings

1. **Removed, not argued.** `docs/design/drive-places.md` §1.2 item 2 forbids `Places` moving
   anything in `OurForest` / `Session` / `LobbyAssets`, and the Builder may not amend a design. So
   `Places.reseat`, `Places.reseatAll`, `Places.STANDING_WOOD`, `Places.rootsNamed`, the boot's
   after-lobby hook and all four of their spec cases are gone. `Places.foliageRoots` is back to its
   round-0 body. `ESCALATE.md`'s top entry carries the decision and three ways to take it, and names
   what is left unfixed with numbers.
2. **Gone with finding 1.** The sweep that moved ~409 unmeasured models no longer exists.
3. **The dead arm is deleted.** The Reviewer's own arithmetic is right: after the `allowance` fix,
   `decide` at that point can only answer `seated` or `ok`, so `air` could never be anything but 0
   and proved nothing. `plantOne`'s `"air"` arm, `Places.isSeated` and the `air` counter are
   removed, and no claim rests on them. `Places.junctionGap` stays as the SPEC's measuring helper
   (re-measure off the model, not off the lift), and its header now says nothing in `src/` reads it.

## What is left: the planter, and only the planter

`src/shared/TreeGround/init.luau` -- `decide` takes an optional `cliffStuds`.
`src/server/Places/init.luau` -- the scale is relative to the size the template stands at; one
allowance, asked once and handed to the verdict; `junctionGap`.

## The instrument, and BEFORE / AFTER in her place (130094961655666), in Play

`<runs-dir>/326census.py`: every model in Workspace against the terrain under its TRUNK's footprint
-- a 5x5 grid over the flare box, corners included, never the pivot (L-086/L-024). It INJECTS
`src/shared/TreeGround/init.luau` the way `tools/forest_ground.py` does, so the census and the game
share one piece of arithmetic. `trunkGapHigh` is the trunk base above the HIGHEST ground under the
footprint -- daylight, what an eye sees. `326-census-play-main.json` / `326-census-play-r2.json`.

| | main `cf2e6955` | code commit `5ebe4b4c` |
|---|---|---|
| `DrivePlaces` above the ground by >0.3 | **646** of 3028, worst **1812.81** | **0** of 3253, worst -0.20 |
| models spanning >300 studs | **329**, worst 2260 | **0** |
| `Session` (saved content, NOT fixed) | 4: 29.0 / 34.4 / 53.5 / 65.2 | 4, unchanged |
| `OurForest` (saved content, NOT fixed) | 2 ferns by the lodge: 3.48 / 2.42 | 2, unchanged |
| boot line | `3028 planted, 863 on a step, 2.71s` | `3253 planted, 638 on a step, 1.20s` |

The 10 other models over 0.3 are `Workspace.Lobby` and none is foliage: four rack guns, a boar head
and the shopkeeper stand on the lodge FLOOR, the four trucks on their wheels. Proven, not asserted
-- `<runs-dir>/326-under.out` fires an unfiltered ray under each: the shopkeeper's first hit is
`Workspace.Lobby.Lodge.RoofNorth` at y 170.1 with terrain at 150.0. A terrain-only census cannot
see a floor; that is the census's limit, not a defect.

## Claims

1. **The giants are `Model:ScaleTo` being absolute while `item.scale` is relative** ("1 is the
   template's own size"). Measured in her place (`326-scale.luau`): 52 of the 61 templates stand at
   a `Scale` that is not 1 -- `SilverBirch_Var13_LOD_0` at 0.0413, the larches at 1.4-2.1 -- so
   `ScaleTo(0.95)` grew that birch 23x. One clone dumped part by part (`326-broken.out`): the
   template's `Trunk.011` is 4.8 x 84.5 x 5.2, the clone's 124.8 x 2048.0 x 136.9. Now
   `made:ScaleTo(made:GetScale() * item.scale)`.
2. **The floaters are `plantOne` and `decide` using two different cliff thresholds.** The pre-check
   used `Places.stepAllowance`, `decide` re-checked with `CLIFF_STUDS` (4); in between, `move` was
   false and the clone stayed where `PivotTo` put it -- one tree-height up. 536 of the 646 carried
   reason `cliff` in the before census. `decide` now takes `cliffStuds` and `plantOne` passes the
   number it already checked with, so the pre-check and the verdict cannot disagree.
3. **`decide`'s new parameter narrows as well as widens**, so it is a threshold and not a way to
   switch the guard off -- `tree_ground.spec`, "the caller's own cliff allowance".
4. **FAIL FIRST, run.** `src/` checked out at main `cf2e6955` with these specs, one harness run at
   `a69a1b63`: `[harness] FAIL: 32/34 ... 2654 passed, 5 failed, 5 errors @ a69a1b63 (DIRTY TREE (3
   paths))`. The three dirty paths were `src/server/ForestTestBoot.server.luau`,
   `src/server/Places/init.luau`, `src/shared/TreeGround/init.luau`. Of the five, the two that
   survive into this round are **`places.spec` "plants a template at the size it stands"** (the
   planted trunk measured 4.75x what it should) and **`tree_ground.spec` "the caller's own cliff
   allowance"** (`decide(...,7)` answered "cliff", wanted "ok"); the third, **`places.spec` "leaves
   nothing in the air on a step its own allowance accepted"**, failed on its own geometric line --
   the junction 40 studs above the ground, measured with `trunkBox` / `groundsUnder` / `clawFor`,
   all of which exist at `cf2e6955`. The other two cases are deleted in this round. Verify:
   `git checkout cf2e6955 -- src/` and re-run.
5. **One settler, not a second ground-fit** (L-024). `plantOne` and `junctionGap` both go through
   `TreeGround.decide` / `junctionY`; no new raycast rule was written.

## What I could NOT verify

* **No frame; rule 5 is NOT met.** `screen_capture` against that Studio returned the same cached
  image for six different cameras AND for a confirmed character move (`326-before-*.png`,
  `326-test-cam.png`). `326frame.py` (park the client camera) and `326shot.py` (stand the player
  there) both report success in Luau and both yield that frame. Nothing here is claimed from a
  picture; every figure is a census reading. `ESCALATE.md` has the entry and the clicks.
* **Six models of Karen's saved content still hang** (4 in `Session`, 2 ferns in `OurForest`), and
  that is the escalated decision, not an oversight. Her place was never saved, published or
  committed.
* **The live proof used `:34873`, not `:34874`**, because the Forest Test's Rojo panel is not open
  (`326-screen6.png`) and the port scripts click fixed coordinates. `driven-hunt-karen` -- the copy
  `:34873` already serves -- was checked out at the code commit, Played and measured, then
  **restored to `main` (cf2e6955)**: verified, with `rojo :34873` still on its original session id.
