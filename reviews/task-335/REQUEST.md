# Task 335 -- cell C1 is one birch wood, wall to wall

Task: 335
Round: 1
Base: main 4751ffd6
Code commit: ef357ba1322a076f6b81d5038c210a82636e8ac1

Gate, clean tree, at the code commit:

```
[harness] PASS: 34/34 checks @ ef357ba1322a076f6b81d5038c210a82636e8ac1 (clean tree) scope=all
```

`test2` N/A: no `TWO_PLAYER_PATHS` path is touched (`src/shared/Places/init.luau`,
`tests/server/grid.spec.luau`, `tests/server/grid_ground.spec.luau`).

Karen, 2026-11-08 ~15:35 UTC, on a top-down frame of C1: *"so we start with this that all has to be
forest no free spot excep road so in one terrain maik all birch trees"*.

## What changed

`Places.CELL_PLANS.mixedRolling` (C1 only) v5: three birch-only mixes (`birchWood`, `birchThicket`,
`birchScrub` -- three names and not one because `Places.FERN_MIXES` keys on the mix name), the
understorey `larchYoung` -> `birchScrub`, `reliefBias` dropped from all four wood zones, the clearing
zone 0 -> 24 and the oak park 44 -> 26. Nothing else in the recipe moves. Two specs follow the
recipe and two more carry the task's own claims.

## Claims

1. **Every stem C1 offers is a birch.** `grid_ground.spec` "offers no stem that is not a birch"
   walks `Plan.plantCell("C1", nil)` and fails on any model not in `Places.SPECIES.birch` (ferns
   excepted, they are ground cover). Verify: read the case; revert `mixedRolling`'s `zones` and it
   fails. Measured live in claim 3.
2. **C1's open ground meets the bound.** `grid_ground.spec` "leaves no open ground off the roads,
   the rides, the corridors and the stands": a 20-stud lattice over `Grid.boundsOf("C1")`, a point
   open when no non-herb planting is within 25 studs, `road`/`ditch`/`verge`/`ride`/`corridor`/
   `stand`/`tower`/`cone` points excluded, bound 3 %. Verify: read the case and its `TestKit.note`.
3. **Measured in Karen's Forest Test, same probe both sides** (`<runs-dir>/335-cover.luau`, run on
   the LIVE `Workspace.GridForest.C1`, not on the plan). Before: `C1 trunks=1853 herbs=91
   parts=6566`, `species aspen=126 birch=433 conifer=754 fieldOak=99 oak=58 young=383`, `open
   1188/3888 = 30.56%`. After: `C1 trunks=2387 herbs=89 parts=9318`, `species birch=2387`, `open
   ALL 480/3888 = 12.35% | NON-EXEMPT 80/3220 = 2.48%`. Verify: the lines are quoted in the task
   row; re-run the probe in a Play of her place.
4. **The dispatch's 3 % is unreachable over ALL interior points, and that is arithmetic.** After the
   change the uncovered points are `PLANTABLE=73 clearing=7 corridor=11 ride=233 road=107 verge=49`:
   400 of them are road, verge, ride or corridor, which the mask keeps trunk-free for the stands and
   the beaters -- 10.3 % of the lattice before a single tree is planted. The bound is therefore
   reported both ways and asserted against the non-exempt points. Verify: the `openwhy` line, and
   `Places.maskGrid`'s arms 1-4 and 9-12.
5. **`reliefBias` had to go, and the spec says so.** It rewrites any non-conifer to `conifer` under
   hn .30; C1's `relief.minY` 89.14 + .30 x 61.12 = 107.5 is ABOVE its `lineMeanY` 106.03, so left
   in it would have planted the lower half of a birch-only cell in spruce -- the live BEFORE count,
   conifer 754 of 1,853, is that bias at work. Verify: `scatter`'s bias block in
   `src/shared/Places/init.luau`, and `Grid.CELLS` C1's `relief`.
6. **The bias is still proven, with no shipped caller.** `grid_ground.spec` "the relief bias ... and
   it bites" now hands `plantCell` its own plan -- C1's row with one `mixedWood` zone over the whole
   cell carrying `reliefBias` -- by stubbing `Plan.cellPlanFor` inside a `pcall` and restoring it;
   a second case asserts no shipped recipe declares the key. Verify: both cases.
7. **`grid.spec`'s "a plan with a reader differs from one without" can no longer bite, and is not
   left pretending to.** With no recipe carrying the bias the two counts are equal; the case now
   asserts equality, says why in the comment, and names where the bias is proven instead.
8. **C1 has no clearing left, so the two cases that needed one move.** `grid.spec`'s per-cell rule
   becomes `clear < 0.34` for every cell plus `expect(clear > 0).to.equal(id ~= "C1")` -- which
   fails if C1 gains a clearing back AND if any other cell loses one. `grid_ground.spec`'s "a
   clearing refuses" asks B1.
9. **No other cell's planting moves.** C1's three neighbours (B1, D1, C2) are all in
   `Grid.PLANTED_CELLS`, and `plantCell` draws no skirt into a planted neighbour, so C1 plants
   nothing outside its own rectangle; the skirt other cells draw reads the NEIGHBOUR's mix through
   `Places.zoneAt` and passes no `zone`, so no skirt reads C1's recipe. Verify: `plantCell`'s skirt
   loop, and `grid.spec`'s density case still reading C2/A2/B1/D1 at 1,926/2,016/1,805/1,843.
10. **The density standard became the number 1,861, not C1's live count**, because C1 is now 2,418
    on Karen's instruction and holding four mixed woods to a one-species cell would raise them on
    nobody's say-so. C1's own 2,418 is pinned in the same case. Verify: `grid.spec`'s density case.

## What I could not verify

* **The BEFORE frame time.** The dispatch asked for Play frame-time mean and p95 at a C1 stand
  before and after. The old wood was replaced before anyone read it, and the only copy of it is
  `FT-before-335.rbxl`. What is measured instead, in one run after the plant
  (`<runs-dir>/335-frametime.luau`): C1 stand 8 mean **21.10 ms**, p95 **27.78 ms**, 475 frames,
  against untouched C2 stand 8's **24.05** / **31.60**, 416 frames. So the heavier cell is not the
  slower one; it is not a before/after pair and is not offered as one.
* **The part budget is exceeded and the cap is not.** 2,476 models stand against `CELL_PART_CAP`
  2,640, but at 9,318 parts (3.76 a model, where `Places.PARTS_PER_MODEL` says 3.03 -- it was
  measured on C1's OLD mix) C1 is past `PART_BUDGET_CELL` 8,000, the budget the cap is derived from.
  Pre-existing in kind: five planted cells already exceed `PART_BUDGET_DRIVE`.
* **Karen has not looked at it.** Frames `<runs-dir>/335-F1.png` (top-down, her camera) and
  `335-F2.png` (C1 stand 8, eye 109) are opened and described in the report.
* **The understorey is now birch, so it is no longer `young`** -- and `maskGrid` arm 11 bans only
  `young` growth from a stand's far cone (40-140 studs). Saplings can therefore stand in a hunter's
  shot band where they could not before. Reported, not hidden; it is Karen's feel call.
* No research note: this is a data change inside an existing recipe system, with no new pattern.

ANSWERED: L-136 no spec failed as a flake; the first full run named five failures, all of them this
change's own pins, and they were fixed rather than called known. The second run is 34/34.
ANSWERED: L-127 every dispatch item is MET or NOT PROVEN by name in the report's handover block.
ANSWERED: L-162 every live proof -- the plant, the cover probe, the frames, the frame time -- was
taken in Karen's Forest Test at `ef357ba1`, which `[bake] plant OK: ... @ ef357ba1...` names.
ANSWERED: L-014 nothing was checked out in `driven-hunt-karen`; it still reads `4751ffd6`. The plant
injected the planter's text off `/c/Users/karen/Desktop/driven-hunt` on this branch.
ANSWERED: L-101 the attribute diff of her place before and after the plant is EMPTY
(`<runs-dir>/335-attrs-BEFORE.txt` against `335-attrs-AFTER.txt`): all 15 flag overrides,
`TerrainEpoch` and `PlantEpoch` unchanged.
ANSWERED: L-093 both claims have a case that dies with the recipe (claims 1 and 2).
ANSWERED: L-139 correct, and followed -- `replant-forest.sh` force-checks-out `origin/main`, so it
was NOT used; `tools/terrainbake.py plant` was run from this branch's worktree instead.
ANSWERED: L-095 F2 was taken with `ftplay.py capture` in EDIT at explicit coordinates read off a
probe (`<runs-dir>/335-stands.luau`: C1 stand 8 at -4497,103.6,-4746 facing +x), so no in-Play
camera route was needed.
ANSWERED: L-025 no ray is cast anywhere in the cover measurement; it is trunk pivots against a
lattice, so the downward-ray-from-the-sky defect cannot occur.
