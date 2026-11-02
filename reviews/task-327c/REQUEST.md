# Task 327c: THE CELL'S WOOD

Task: 327c
Round: 1
Base: main (71f9c515, which has 327a #310 and 327b #311 merged)
Code commit: 8585266ba4e31f34b7d86093265e66cd0dec301e
Branch: task-327c-wood

Built to `docs/design/grid-map.md` section 17's 327c row: `Places.CELL_PLANS`' eight recipes with
their zones, `Places.plantCell`, `src/server/Places/Slice.luau`, destroy-then-plant, nearest-the-line
first, `GROUND_IGNORE` gaining `GridPlaces` (already there from 327a -- **confirmed, not
duplicated**), the census, and `grid.spec` cases 12-18 and 20. Behind `GRID_PREVIEW` (OFF).

Gate, first try at the code commit, no flake:
`[harness] PASS: 34/34 checks @ 8585266ba4e31f34b7d86093265e66cd0dec301e (clean tree) scope=all`
`test2` is **N/A**: no path in `TWO_PLAYER_PATHS` is touched (`src/shared/Places/`,
`src/server/Places/`, `src/shared/Grid/`, `src/server/ForestTestBoot.server.luau`,
`tests/server/grid.spec.luau`). CI green on the code commit: run 41368961924, `Build and lint` success.

## Claims

1. **Eight recipes, one per cell, each a tiling of zones that never overlap and name species this
   world has.** `Places.CELL_MIXES` / `Places.CELL_PLANS` (`src/shared/Places/init.luau`),
   `Grid.CELLS[i].recipe` (`src/shared/Grid/init.luau`). Verify: `grid.spec` case 12 -- every zone in
   `[0,1]^2`, non-empty, pairwise disjoint, tiling to 1e-9; every mix a key of `Places.CELL_MIXES`
   and every group in it a key of `Places.SPECIES`; a clearing is an EMPTY mix **and** spacing 0,
   both ways. Measured: `A1=spruceSlope(6 zones, 11% clear) B1=birchSlope(7, 15%) C1=mixedRolling(7,
   15%) D1=oakRolling(6, 11%) A2=larchRolling(5, 17%) B2=aspenSlope(4, 18%) C2=spruceRolling(7, 12%)
   D2=birchRolling(6, 12%)`.
2. **A cell's wood is a pure function of its id -- the same list twice, and the same list whatever
   order the cells were built in.** Every stream is `Grid.seedFor(id, stream)`; no counter.
   Verify: `grid.spec` case 13 (item for item; A1 before B1 and A1 after B1; two cells differ; an
   unknown id gets 0 plantings).
3. **Every cell is under its own declared bound and every bound is under 3,600 models.**
   `Places.cellCapacity`, and `Places.capacity` dispatches to it on `plan.zones`. Verify: `grid.spec`
   case 14. Measured, per cell `total(trees ferns skirt)/capacity`: `A1 2232(1598 250 384)/2624
   B1 2181(1449 247 485)/2635 C1 2165(1426 245 494)/2602 D1 1771(1223 249 299)/2130 A2 1975(1404 264
   307)/2374 B2 2268(1545 255 468)/2720 C2 2224(1506 261 457)/2649 D2 1707(1160 261 286)/2050` --
   worst B2 2268 of 2720. Design 8.3's target for a cell's own wood is ~1,500; measured 1160-1598.
4. **No tree stands in any road's clear width, and none is inside a stand's clearance.** Verify:
   `grid.spec` case 15, asked TWICE -- the spec's own loop over `Grid.roads()` (independent of
   `Places.inLane`, `drive-places.md` 10.4 item 3's lesson) and then through `Places.inLane` and
   `Places.clearOfEveryRoad`. Measured over all 16,523 plantings: nearest road centre **24.01** studs
   against a clear half of 21.0; nearest of any of the 120 stands **24.27** studs, against the
   dispatch's 8, `ForestTest.PICK.standRadiusStuds` 12 and `HighSeats.footprintRadiusStuds` 5.1.
   `Places.laneHalfWidth(cellPlan) * 2 == Grid.CONFIG.roadClearStuds` is asserted as one fact.
5. **The skirt reaches into every neighbour from the shared road, stops at `skirtStuds`, and is the
   NEIGHBOUR'S own wood.** `Places.neighboursOf`, `Places.skirtBands`, `Places.zoneAt`. Verify:
   `grid.spec` case 16 -- each skirt planting outside the active cell, inside exactly one neighbour,
   between `roadClear/2 + CELL_EDGE_STUDS` and that plus `skirtStuds` of the shared road's centre,
   every neighbour dressed, and its model drawn from the zone it stands in over there. Measured
   reach 251-254 of a 254 bound.
6. **The slice spends a budget, finishes, and destroys before it plants.** `src/server/Places/Slice.luau`.
   Verify: `grid.spec` case 17 -- 2,400 plant + 600 destroy items with a clock the WORK advances,
   begun plant-first on purpose: 3,000 of 3,000 done, the first 600 work calls all destroys and no
   destroy after a plant, `overBudgetStarts == 0`, 5 items a step at 1 ms a model (the clock bites)
   and 10 at 0.1 ms (`MAX_PER_STEP` bites). A step never BEGINS an item past the budget and so can
   overrun by at most the item in hand -- that is `Slice.step`'s stated contract, and the case asserts
   `BUDGET_MS + one item`.
7. **The wood is planted nearest the hunter line first.** `Slice.order`, pure, monotone in
   `|z - Forest.roadZ(x, layout)|`, a permutation, and a total order (the tie-break is the original
   index, because `table.sort` is not stable). Verify: `grid.spec` case 18. Measured on C1: first
   planting 24.5 studs off the line, last 1447.7.
8. **Every planted tree stands ON the ground and a refused one is destroyed.** Lesson L-086:
   design 13.1's cases 12-18 and 20 carry NO ground-contact assertion, so one was added. Verify:
   `grid.spec` "a dressed cell" -- `Places.dressCell` driving the REAL `plantOne` and `TreeGround`
   over C1's real plan on a hillside falling 1 in 10, every surviving model re-measured off the MODEL
   with `Places.junctionGap` (lowest terrain under the TRUNK's own 25-sample footprint, never the
   pivot): 2165 planted, 0 refused, worst junction **-0.600** studs, folder count == planted, and
   `planted + cliff + skipped + missing == wanted`. A second dress destroys the first's wood before
   planting its own, the corner stakes are untouched, and an unknown id dresses nothing.
9. **`GROUND_IGNORE` and the folder name are one fact.** Verify: `grid.spec` case 20 --
   `table.find(Forest.GROUND_IGNORE, Planter.GRID_FOLDER) ~= nil`, both folders carried, and the two
   names differ. **327a already added `"GridPlaces"`; this task confirmed it and added nothing.**
10. **LIVE IN KAREN'S FOREST TEST at the code commit** (`driven-hunt-294` on rojo :34874;
    `GRID_PREVIEW` set as an attribute and removed after -- her other 14 flags read identical before
    and after; switched back to :34873 and verified two ways). Boot's own line:
    `grid wood C1: 2019 of 2165 planted (6494 parts), 146 on a step, 0 skipped, 0 missing,
    0 destroyed, capacity 2602, 308 slice step(s) avg 4.85 ms worst 7.69 ms over budget 0, 5.44s`.
    Census (`driven-hunt-runs/327c-census.luau`, the planter's own `trunkBox`/`groundsUnder`):
    **FLOATING (lowest trunk geometry > 1 stud above the HIGHEST terrain under its footprint) = 0**,
    worstHigh **-0.19**, worstLow **-0.18**, noGround 0, **inRoad 0**, **inside a stand's 8 studs 0**,
    35 distinct models over 18 zone/band/mix buckets. Zero console errors in the whole session.

## Deviations from the design, named

- **Design 8.3's skirt row says "worst case (4 neighbours)". A 2 x 4 grid has no cell with four**
  (no third row): a corner cell has 2 and B1/C1/B2/C2 have 3. The worst measured skirt is C1's 565
  planned (494 after the gap rule) against the design's 650, so the bound is not breached; the
  arithmetic behind it is. Re-derived rather than built to (lesson L-167).
- **A cell plan does not carry `bands` / `beltStuds` / `northBeltStuds` / `plotHalfWidthStuds`.**
  Design 4.5 says "the same record shape", but those four are depth bands measured out from ONE
  road and have no meaning over a rectangle bounded by four; `zones` is what replaces them, and the
  surveyed plot IS the cell (327a: 33,750/33,750 terrain hits, 0 parts inside). Every other field
  is carried under the same name. Written at `Places.CELL_PLANS`.
- **`plantCell` does not apply `Places.clearOfEveryLane`**, it applies `Places.clearOfEveryRoad`.
  A layout's line is a `roadZ(x)` defined for every x, so `ride`'s line at z -4540 would cut a
  42-stud bare stripe across the whole grid footprint 5,000 studs west of where that place is. The
  two worlds are separate (design 11.3) and 327d retires the first. Written at that function.
- **`src/shared/Places` now requires `Grid`.** One direction only; `Grid` requires neither.
- **One extra commit after the first code commit touched `src/`** (`ForestTestBoot.server.luau`):
  the boot's grid line printed the roads and the stakes but not the wood, so the first live dress put
  2,019 models in with nothing on the boot's face saying so (design 11: "printed, not assumed").
  `8585266b` is the code commit and the harness line names it; nothing changed after it.

## What could NOT be verified

- **Karen has not looked at it.** Three frames were taken in her place at the code commit, from the
  player's eye, and described: `327c-f1-stand.png` (stand 4's eye, the road at her feet, 21 studs of
  clear lane, then C1's spruce thicket wall to the left and the lighter mixed wood to the right),
  `327c-f2-tower.png` (the stand-13 tower deck at y 130.1, ferns at the road edge, the oak park's
  44-stud spacing with white birch trunks below the eye, dark spruce behind), `327c-f3-skirt.png`
  (the same stand looking SOUTH across the road into C2's skirt: a close broadleaf wall where
  unskirted ground would be bare grass). Whether it FEELS different per cell is rule 5 and hers.
- **Only C1 was dressed live.** The preview dresses `Grid.PREVIEW_CELL`; the other seven recipes are
  proved by arithmetic and by the spec, not by a frame.
- **Design 8.3's "whole cell planted < 4.0 s" is NOT met: measured 5.44 s** for 2,165 items in 308
  slice steps. The design derived 0.45 ms a model (M9); the measured cost in her place is ~0.69 ms,
  so the 4.5 ms budget allows ~6.6 items a step and not 10, and 308 frames at 60 Hz is 5.1 s on its
  own. Head-room is unaffected (design 8.3 allows 40 s; a destroy plus a plant is ~11 s), but the row
  is wrong and the number is reported rather than rounded. `stepMsAvg` 4.85 and worst 7.69 ms are the
  documented one-item overrun, with `overBudgetStarts` 0.
- **A row-2 cell's hunter looks south out of the world.** Its main line is the south border road and
  design 8.2 only skirts cells that HAVE a neighbour. Not this task's scope; flagged for 327d.

ANSWERED: L-136 the gate ran three times; the only failures were my own new slice case (a float knife
edge, twice, fixed in the tree) -- no spec was called a flake, and the one `[input]` transport failure
in run 2 did not recur in run 3 at the same commit.
ANSWERED: L-127 every claim above is MET or sits under "What could NOT be verified" by name.
ANSWERED: L-162 every live proof -- boot line, census, heartbeat A/B, all three frames -- was taken at
8585266b, after re-syncing `driven-hunt-294` to it and restarting Play.
ANSWERED: L-014 `driven-hunt-karen` was never checked out; it is still at 71f9c515, clean. The proof
worktree was `driven-hunt-294`.
ANSWERED: L-139 the switch back to :34873 is verified two ways -- the panel frame
(`327c-back-b-rojo.png`, "DrivenHunt localhost:34873", Disconnect, 14 seconds ago) and a probe in the
place reading `ServerScriptService.Places.Slice=false`, i.e. 327c's module is gone.
