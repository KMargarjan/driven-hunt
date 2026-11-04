# Task 328s -- C1's forest, re-planted denser on the bent ground

Task: 328s
Round: 1
Base: 904f876c
Code commit: 871f7655a0c44989ee47e6b983f70655d1f84444

`[harness] PASS: 34/34 checks @ 871f7655a0c44989ee47e6b983f70655d1f84444 (clean tree) scope=all`

`[harness2]` N/A: no path in `TWO_PLAYER_PATHS` is touched. The diff against `main` is
`src/shared/Places/init.luau` and `tests/server/grid.spec.luau`.

**The code commit is NOT the merge commit.** The merge of `main` (328t #327) is `8164e299`, and the
full gate at it read `FAIL: 32/34 @ 8164e299` -- `grid.spec:800` and `:929` pinned C1's plan at
**1,803 / 1,789** and got **2,458 / 2,448**. Those are MY task's numbers moving two pins written in
328r, and they had never been seen red because the gate could not finish before 328t. `871f7655`
fixes the two pins and nothing else.

**MEASURED NOW:** no new world measurement was taken this session, and none is needed -- the C1
numbers below were measured in Karen's own Forest Test at `aba97b6f`, and `8164e299`..`871f7655`
adds only test and tool code. Karen's Forest Test (130094961655666, :34873) was not touched.

## PLAN (Core Quality Protocol step 0, committed at `3ce58106` before any `src/` edit)

**(a) REAL LIFE.** A managed 40-80 year mixed stand carries 1,000-2,500 stems a hectare at 2-3 m
between them. One stud is ~0.28 m at this world's tree heights (`Places.SPECIES`), so 2-3 m is
**7-11 studs**, and such a wood has TWO storeys.

**(b) MEASURED NOW** (DEV Play server at `14581cc7`, `<runs-dir>/328s-yield.luau`): C1 planned
**1,789** of 3,416 capacity. An **Edit** probe answers from the stale `require` cache, so every
reading in this task is from a Play DataModel.

**(c) TARGET.** C1's PLANNED count **>= 2,300** and **<= `CELL_PART_CAP` 2,640**, `cellCapacity` <=
`CELL_PLAN_CAP` 7,260.

**(d) LEVER**, by `grep`, all in `src/shared/Places/init.luau`: `scatter`'s
`not tooClose(grid, jx, jz, gap)` fed by `plan.minGapStuds`; the per-zone `spacingStuds` and
`under.spacingStuds` rows of `CELL_PLANS.mixedRolling`; its `spacingStuds` / `deepSpacingStuds`.

**(e) HOW MEASURED AFTER.** The same probe, plus `Places.TALLY`, which this task adds.

## WHICH RULE BINDS (`Places.TALLY`, `<runs-dir>/328s-tally.luau`)

At the base: `offered 3412 | outside 360 | noRows 121 | mask 481 | gap 418 | crown 243 | planted 1789`
(mask: corridor 152, ride 140, ditch 75, clearing 53, verge 36, field 15, cone 10; **road 0**).
The gap rule is the largest single refuser; the mask is seven rules added together.

## ITERATION (step 2) -- three cycles, same probe each time

| cycle | change | planned | capacity | gap refusals | distance to 2,300 |
|---|---|---|---|---|---|
| 0 | the base | 1,789 | 3,416 | 418 | -511 |
| 1 | zones 21/28/27 -> 17/23/22, under 42 -> 32, skirt 28/60 -> 24/52, gap 12 -> 11 | 2,355 | 4,746 | 775 | **+55** |
| 2 | zones -> 15/21/20, under -> 28 | 2,559 | 5,442 | 1,155 | +259, but only **81** under the part cap |
| 3 | **shipped**: zones -> 16/22/21, under -> 30 | **2,448** | 5,097 | 947 | **+148, 192 under the cap** |

Cycle 2 is the refutation that sets the shipped number: 696 more offered sites bought **204** more
trees and **380** more gap refusals. The count plateaus because the gap rule binds, so cycle 3 sits
at its knee with margin under the part ceiling.

## Claims, and how to verify each

1. **C1's plan is 2,448, up 36.8 % from 1,789.** `<runs-dir>/328s-tally.luau` in a Play server;
   `grid.spec:920` pins it, and `:921` pins the straight world's 2,458.
2. **Every cell is still inside all three caps.** `328s-cells.luau`: C1 2,448/5,097 (part slack 192,
   plan slack 2,163); the other seven unchanged, worst part slack 884 (B1). `grid.spec` case 14.
3. **`oakPark`, the clearing and the two scrub zones are untouched** -- Karen's *"but rest is good"*.
   `git diff 904f876c -- src/shared/Places/init.luau`.
4. **Planted in KAREN'S place at `aba97b6f`: 2,410 of 2,448, refused 38 = 1.55 %** (<= 8 %).
   `328s-census2.luau`. Before, same instrument, her restored build: 1,752 of 1,789 = 2.07 %.
5. **The part budget holds, measured and not assumed: 7,279 parts for 2,410 models = 3.02 a model**
   against `PARTS_PER_MODEL` 3.03 and `PART_BUDGET_CELL` 8,000.
6. **The census is 0 on every counter that can be 0**: floating, sunk, tilted, broken, inRoad,
   inStand, noGround, onCliff, crownOverRoad, crownUnmeasured. `foliageInGround` 77 (before 73).
7. **`sunk` was an INSTRUMENT fault and the arithmetic proves it.** 328r's `sunk 113` and this
   task's first readings (before 90, after 133) came from a probe passing
   `Plan.clawOf and Plan.clawOf(name) or 0`, and `ReplicatedStorage.Places` **has no `clawOf`**, so
   it answered 0 for every tree; the seater uses `ServerScriptService.Places.clawFor`. Every sunk
   tree was one of the two largest `Places.CLAW_FRACTION` rows, and the reported excess matched
   `height x claw` to two decimals (Var11 83.0 x 0.0425 = 3.53, reported 3.53; Var13 87.2 x 0.0239 =
   2.08, reported 2.08). Handed the real `clawFor`, `sunk` is **0** on both builds.
   `328s-sunk.luau`, then `328s-census2.luau`.
8. **`inLane` CANNOT be 0 and the census says so in its own comment** (`GridCensus/init.luau`, the
   `inLane` block): it asks the four LINE places' rule, *"never 0 for a grid cell"*. 121 before,
   176 after -- the same 6.9 % / 7.3 % of the trees. Reported, not claimed fixed.
9. **A hunter's stand is ON the road.** All 15 C1 stands read `Places.roadDistance` **0.00**
   (328r measured 45 studs off before the merge). `328s-stands.luau`.
10. **An animal crossed a BENT road segment** -- 328r's NOT PROVEN item 9. `328s-sampler.luau`
    measures the crossing in GRID space, so the bend is undone: **27 crossings** in 120 s, e.g. a cub
    from world (-3833,-5025) to (-3857,-5102) in **6.6 s**, where C1's main road centre is at world
    z **-5062.65**, i.e. **44.35 studs** off the straight line (`328s-bend.luau`). Same window:
    80 animals, **0 stuck > 3 s** (worst 1.8 s), **2 of 80** no-progress >= 6 s (worst 13.8 s).

## Frames (rule 5) -- hunter eye height, in Play, in Karen's place, opened and described

`328s-F{1,2,3}-{before,after}.png`, six distinct shas, all from one held point ~(-3916, 110, -5063)
on C1's main road. **F1** east along the bow: before, trunks thin enough to see sky and horizon
between them; after, a closed treeline both sides and young growth on the verge. **F2** west:
before, a thin avenue over open grass; after, visibly more stems and a lined verge. **F3** north off
the road into the wood: before, widely spaced trunks over a lawn with a clearing visible through;
after, a layered screen of spruce that closes that view.

## What could NOT be verified

* **328r's exact F1/F2/F3 camera points.** `Match.CONFIG.STAND_RADIUS_STUDS` (12) holds a player at
  the stand his drive deals him; this session dealt a different one (`NOT HELD, best 434.75 st`).
  All six frames share ONE camera instead, so the pair is exact though the viewpoint is not 328r's.
* **Why `sunk`'s two templates need a claw at all** -- the fix here is to the INSTRUMENT, not the
  world; whether the seater should use that claw is not this task's question.

ANSWERED: L-136 no flake fired -- the two FAILs at `8164e299` were my own stale pins, named and
fixed at `871f7655`, and the re-run is 34/34 with 0 failed and 0 errors.
ANSWERED: L-127 every claim above is MET as written; the two NOT PROVEN items are in their own
section and are not phrased as options.
ANSWERED: L-162 the harness line names `871f7655`, which IS the code commit (the last commit
touching `src/`, `tests/` or `tools/`).
ANSWERED: L-014 Karen's Forest Test (130094961655666, :34873) was never contacted this session; the
harness line says `report comes from the DEV place (136410205938347)`.
ANSWERED: L-174 no extra round was needed; round 1 is this request.
ANSWERED: L-149 row **328v** now exists in `TASKS.md` -- 328t opened it on `main` and the merge
carries it in, so the `deer_hitbox.spec:659/:682` flake is no longer homeless.
ANSWERED: L-173 the two FAILs were diagnosed from `studio_mcp.py console` without a second suite
run, and only one re-run of `scope=all` was spent (two gated runs in total, never concurrent).
