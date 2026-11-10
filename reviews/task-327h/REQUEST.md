# Task 327h — each section its own animal pattern

Task: 327h
Round: 1
Base: 516b9698 (main, PR #353)
Code commit: b80635aa5270cd35f38621f9850d6ffa96b954b7

`[harness] PASS: 34/34 checks @ b80635aa5270cd35f38621f9850d6ffa96b954b7 (clean tree) scope=all`

`test2` N/A: `tools/agents.py`'s `TWO_PLAYER_PATHS` names none of the changed files — no
`src/server/Match/`, no `src/shared/Drive/`, no `MatchBoot`, no `tests/client/Role.luau`, none of
the named specs. The change is `Grid`, `ForestTest` (shared + server), `Places`, the boar runtime,
`ForestTestBoot` and `forest_line.spec`.

## PLAN (core quality protocol, step 0)

- **(a) REAL LIFE.** A driven shoot is not the same twice: cover, wind and the beat decide how many
  break, where, and how deep they sit. Karen, 2026-11-09: *"each sections ahs different animal
  patters to be intrestin"*.
- **(b) MEASURED NOW.** Merged main, one 400 s drive in C1 in her Forest Test
  (`327h-BEFORE-C1b-track.txt`): 121 crossings, 58/13/50 west/centre/east of the stand, |offset|
  mean 53.4 studs, peak 60 live / 1,050 parts. Every cell plays that one pattern.
- **(c) TARGET.** Seven planted cells, seven different (density, routeBias) pairs; measurably
  different release counts and crossing distributions per cell; budget 9.2 not made worse.
- **(d) LEVER.** `Grid.CELLS[*].animals` (new) → `ForestTest.cellSchedule` (new, pure) →
  `ForestTest.waveAt` / `stagRow` / `releaseLine`, which are the two call sites that read a density
  (`grep "SCHEDULE.density" src/` before this task: `src/server/ForestTest/init.luau:438` and
  `:3554`, both now `ForestTest.cellSchedule()`).
- **(e) HOW MEASURED AFTER.** The same probe, same place, same 400 s window:
  `327h-arm.luau` + `327h-crosses.luau`, plus `327h-step.luau` for the new step counters.

## What changed

- **`Grid.CELLS[*].animals`** on all seven planted cells (A1 is not planted): `density`,
  `startDepth` (four fractions of the cell's own depth), `routeBias`, `restZones`. One comment per
  row says how that section plays. `Grid.animalsOf(id)` reads it.
- **`ForestTest.cellSchedule(animals, cellDepthStuds, schedule)`** — pure, memoised on the row's
  identity, derives that cell's schedule from the one `SCHEDULE`. `depthQuarter`, `startDepthStuds`
  and `crossBias` are its three pure parts; `SCHEDULE.bandFraction`, `crossCapStuds` and
  `ROUTE_BIAS` are its vocabulary. `slotAt`, `stagRow`, `releaseDepth`, `routeFloor`, `wavePoint`,
  `computeRoute` and `releaseLine` are **unchanged** and are handed the cell's numbers.
- **`restSpot` takes a third pass** — the cell's recipe zones first (`Places.zoneIndexAt`, new),
  then the zones alone, then any legal spot. With no list there are two passes, exactly as before.
- **`stepMsAvg` / `stepMsMax` / `steps` and `partCount`** on the boar runtime (design 9.2's named
  hole), published on the runtime's folder every `Boar.STEP_PUBLISH_EVERY` (120) steps and printed
  per drive as `[boarstep]`.

## Claims, and how to verify each

1. **A cell with no row plays exactly as today, by identity.** `ForestTest.cellSchedule(nil, …)`
   returns the `SCHEDULE` table itself; `Grid.animalsOf` answers nil for A1 and for every road
   layout name. `forest_line.spec` case *"gives two cells different release counts"* asserts
   `to.equal(Data.SCHEDULE)` for A1 and for an unknown id.
2. **Seven rows, seven different patterns.** `forest_line.spec` case *"has one row per planted
   cell…"* walks `Grid.PLANTED_CELLS` and refuses a repeated (density, routeBias), asserts the
   split is 2 quiet / 3 normal / 2 busy, and asserts every word of `SCHEDULE.ROUTE_BIAS` is used.
3. **Two cells release different numbers.** Same spec: D1 `quiet` = `DENSITIES.quiet` (9) and A2
   `busy` = `DENSITIES.busy` (15), against the base table's 13. Delete the `animals` rows or make
   `cellSchedule` return the base table and both sides become 13 (L-093).
4. **Two cells cross in different places.** Same spec, case *"gives two cells different crossing
   distributions"*: D1 `centre` has 0 crossings in either flank third, A2 `east` has 0 west, B1
   `west` has 0 east, C1 `split` has **0 in the middle** — a shape no one-sided word can make — and
   the base table has all three thirds non-empty.
5. **No bias can send an animal out of the cell.** Every generated `crossOffset` is inside
   `crossCapStuds` 95, the cap task 267 measured, because no `ROUTE_BIAS` band exceeds |1.0|. The
   depth-curve case asserts it over all seven cells and every row. A row that never crosses
   (`BREAK-BACK`, `HOLD`) keeps `crossOffset = nil`.
6. **The depth curve never writes a depth its own route cannot walk.** Same case: every clamped row
   is `>= routeFloor(row, schedule)`, and the `HOLD` row keeps its own 360 (task 253's measured
   defect was a sow lying up 25 studs in front of the hunter).
7. **The band is derived, not chosen.** `bandFraction` x `cellDepthStuds` = 357.5, which is this
   script's own deepest row (360) to within 5 studs — asserted, so the band cannot drift from the
   table.
8. **`restZones` is a reading of the recipe.** Every listed zone is `band == "wood"`, has
   `spacingStuds > 0` (not the clearing) and overlaps `REST.nearRoadStuds..farRoadStuds` as
   fractions of the cell's depth. Asserted over all seven cells against `Places.cellPlanFor`.
9. **The boar runtime now reports what its step costs, and a probe can read it.** The spec steps a
   real runtime exactly to `STEP_PUBLISH_EVERY` and asserts the folder's `StepCount` / `StepMsAvg` /
   `StepMsMax` are the same three numbers `stats()` answers. Live: `327h-step.luau` read
   `steps=16920 stepMsAvg=9.88 stepMsMax=88.43 alive=57` in her Forest Test.
10. **Measured in her Forest Test at the code commit**, one 400 s drive per cell, same probe as the
    before: crossings W/C/E of the stand — BEFORE C1 58/13/50 (|mean| 53.4) → AFTER C1 `split`
    65/**0**/53 (|mean| 72.3), D1 `quiet+centre` **0/146/2** (|mean| 15.4), A2 `busy+east`
    6/20/**100**. Crossings inside the scripted part (t <= 220 s): quiet 49 < normal 63-69 < busy 74.

## What I could not verify

- **Design 9.2's `<= 24` live and `<= 4.0 / 8.0 ms` step budget are NOT met — and were not met
  before this task either** (60 live on merged main with no row anywhere). `ESCALATE.md`,
  2026-11-10, carries the arithmetic and the decision asked for. Making a cell quieter does not fix
  it: the drive outlives its fifteen-slot script and the repeat window refills to `MAX_BOARS`.
- **Nobody has watched a drive and said the three cells FEEL different.** Karen is away. The
  frames (`327h-F1/F2/F3.png`) and the counts are what exists; the feel claim is NOT PROVEN.
- `stepMsMax` is a session high-water mark and is never reset, so the peak includes cold frames.
- The `restZones` third pass is proved by its pure rule and by the recipe reading, not by a live
  count of which zone each stocked group landed in — beater mode was not played in this session.
