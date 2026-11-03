# Task 328m -- review request

Task: 328m
Round: 1
Base: 056f085c (main)
Code commit: 9f537820e3db6f71c70aecf7f69730c8eeb63f42

`[harness] PASS: 34/34 checks @ 9f537820e3db6f71c70aecf7f69730c8eeb63f42 (clean tree) scope=all`
(`driven-hunt-runs/328m-harness3.txt`.) `test2` is **N/A**: nothing in `TWO_PLAYER_PATHS` is touched
-- the change is `src/shared/Places`, `src/server/Places`, `src/server/ForestTestBoot.server.luau`
and `tests/server/grid.spec.luau`.

The run before it (`328m-harness2.txt`) failed 32/34 on `deer_hitbox.spec:659`, named in the dispatch
as a known intermittent and in no file this task touches; the re-run above is clean and is the
evidence. No FAIL line is claimed as evidence here.

## What changed

Karen played C1 in her Forest Test on 2026-11-03 (`PLAYTEST.md`, verbatim).

1. **"those gates shouldnt be"** -- the 32 corner stakes of task 327a. `Places.STAKE`,
   `Places.gridStakes`, `Places.stakeGrid`, the `gridStakes` / `gridMissing` report fields and their
   `[ForestTestBoot] grid:` print are archived (rule 7) in
   `backups/2026-11-03_task-328m_Places-stakeGrid-and-grid-case-22.md`. `Places.GRID_FOLDER` stays --
   the cell's wood is dressed into it and `ForestTest.GROUND_IGNORE` names it.
2. **"has to be a bit more realistic more trees but rest is good"** -- a zone gains an optional
   `under` row (`Places.CELL_PLANS`, C1 only): a second, finer layer over the same rectangle, on its
   own stream, at the `shrub` band's scale, sharing the canopy's neighbour grid and `minGapStuds`.
   C1's three closed canopy zones tighten 24/32/30 -> 21/28/27 and every zone takes `jitter` 1.0.
   `oakPark`, the clearing and the two scrub zones are untouched -- they are "the rest".

## Claims

1. **No stake is built any more, and `GridPlaces` still is.** `Places.STAKE` / `gridStakes` /
   `stakeGrid` are gone from `src/server/Places/init.luau`; `grep -rn "stakeGrid\|Places.STAKE" src/
   tests/` finds only the archive pointer. `grid.spec` case 22 asserts the folder exists with the
   preview on, holds **0** children at build, and that `report.gridStakes` / `report.gridMissing`
   are **nil** -- so a later report cannot quietly reintroduce the count. **LIVE**, the branch's own
   `Places.build` in Karen's Play session: `stakes 32 -> 0`, `report{gridStakes=nil gridMissing=nil}`,
   `ForestMarkers` 16 children and `HighSeats` 3 untouched (`328m-rebuild-AFTER.txt`).
2. **Nothing else tall and yellow/orange stands at C1's junctions or road ends.** Frame
   `328m-AFTER-J1.png`, the same camera as `328m-BEFORE-J1.png` (the junction of `NS3` and `EW2`,
   eye 5.6 studs, level gaze): four glowing pillars before, none after, and no other such object in
   the frame. `Workspace` descendant scan after the build: `stakesInWorkspace=0`
   (`328m-census-AFTER.txt`).
3. **The understorey is data and it plants.** `Zone.under`, `Places.CELL_STREAM.under`,
   `Places.UNDER_JITTER`, and the loop in `Places.plantCell` after the zone loop. C1's `shrub` band
   goes **317 -> 525** planted (`328m-census-BEFORE.txt` / `-AFTER.txt`, `bands[...]`). `grid.spec`
   case 12a asserts `saplings > 381` -- the two scrub zones alone hold 381 sites -- so the case
   reddens the moment that loop is deleted (L-093).
4. **It is counted in design 8.3's bound.** `Places.cellCapacity` adds the `under` grid. C1
   **2,598 -> 3,548**, and case 14's `capacity < 3600` still passes. Case 12a asserts
   `cellCapacity("C1") == zones + under + ferns + skirt` from its own arithmetic, so dropping the
   clause reddens it.
5. **The gap rule has no seam.** The understorey shares the canopy's grid AND `minGapStuds`, which
   is both what makes it clump into the gaps and what stops a sapling inside a trunk. Case 12a
   re-buckets C1's whole non-herb list and asserts the closest pair is **>= 12**; measured 12.06
   (`328m-yield-v1.txt`). Giving the layer its own grid or its own gap reddens it.
6. **MEASURED IN HER PLACE AT THE CODE COMMIT, same probe both sides** (`328m-plant.py`, `--raw` =
   the place's own modules = main, no flag = the branch's). **Every counter the census emits**:
   `trees` 1433 -> 1755 · `parts` 4338 -> 5319 · `floating` 0 -> 0 · `sunk` 0 -> 0 ·
   `foliageInGround` **62 -> 65** · `tilted` 0 -> 0 · `broken` 0 -> 0 · `noGround` 0 -> 0 ·
   `inRoad` 0 -> 0 · `inStand` 0 -> 0 · `inLane(other-world)` **81 -> 111** · `onCliff` 0 -> 0 ·
   `crownOverRoad` 0 -> 0 · `crownUnmeasured` 0 -> 0 · `refusedCliff` 118 -> 123 ·
   `refusedSkipped` 0 -> 0 · `refusedWanted` 1551 -> 1878 · `refusedPct` **7.61 % -> 6.55 %** ·
   `worstHigh` 0.0000153 -> 0.0000153 · `worstSink` 0.600 -> 0.600 · `laneHalf` 21 -> 21.
   Plant: `planMs` 41 -> 52, `plantSeconds` 1.0 -> 1.3, `capacity` 2598 -> 3548.
   **Two counters rose** and neither is a defect: `foliageInGround` +3 is 328l's known residue (the
   three `Field_OakTree` variants) and FELL as a fraction, 4.33 % -> 3.70 %; `inLane` is labelled in
   `GridCensus` itself as *"NOT a cell defect"* -- the four legacy line places' stripe across the
   whole world, retired at 327d -- and it scales with the count.
7. **`refused` went DOWN, not up, and that was the risk in this task (L-041).** 7.61 % -> 6.55 %
   against the 8 % gate: 118 -> 123 cliff refusals against a want of 1551 -> 1878, because the sites
   added are in the cell's gentler interior. **The gate's threshold and `SCOPE_SPECS` are
   untouched**; had it gone over, the fix would have been more plant sites, never the gate.
8. **The seven other cells are byte-identical.** `328m-cap-BEFORE.txt` / `328m-cap-AFTER.txt`: A1,
   B1, D1, A2, B2, C2, D2 all report the same `cap` and the same `plan` count on both sides. Only
   C1 moves. Case 12a asserts C1 is the only cell carrying an `under` row.
9. **Posts, towers and the boot are clean.** Her boot line: `grid preview cell C1: 15 of 15 post(s)
   (7 line), 3 tower(s) at {8,13,15}, line=true, complete=true`, and `0` lines matching
   `Stack Begin|attempt to|invalid argument` in the whole console, before and after
   (`328m-console-BEFORE.txt`, `328m-console-AFTER.txt`).
10. **No terrain write, and her place is untouched.** The probes raycast `Workspace.Terrain` and
    never write it; `ServerStorage`'s 19 attributes are byte-identical before and after (same md5,
    `328m-attrs-BEFORE.clean` / `-AFTER.clean`), nothing was checked out in `driven-hunt-karen`, and
    her place was never saved, published or committed.

## What I could not verify

- **Whether the new density reads as "realistic" to Karen.** That is hers (`## Needs Karen`). The
  frames are `328m-{BEFORE,AFTER}-{J1,S1,W1}.png`, all six looked at and described in the report.
- **The pre-328f count of ~2,019 is not reached and cannot be** from this ground: 1,755 is +22.5 %,
  and three allocations of the same budget all land at ~1,885 planned. What refuses the rest is
  `Places.mask` (the rides, cones, corridors and frontage Karen accepted) and `minGapStuds` 12, not
  the grid. Raising it further needs a design number to move -- the < 3,600 model bound, whose
  derivation assumes 7 parts per model against a measured 3.03, or the 12-stud gap. **Neither was
  touched here**; both are queued for the Director.
- `S1`'s AFTER frame has a sounder of boars crossing the ride (the drive was running); the BEFORE
  frame does not. Nothing else differs between the two but the wood.
