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

## Learning flags the dispatch checked

ANSWERED: L-136 — the gate ran clean twice and NO spec from the dispatch's flake list fired. Both
runs: `34/34 checks ... scope=all`, 2,878 server + 684 client assertions, 0 failed. `boar_behaviour`
and `boar_shot`, the two named as in my area, did not fire, so there is no control run to paste.
ANSWERED: L-127 — every item is MET / NOT MET / NOT PROVEN in the report's handover block, and the
two that are NOT PROVEN (the feel claim, the `restZones` live landing) say so in "What I could not
verify" above rather than being left to be read as done.
ANSWERED: L-162 — every live number here was read at the code commit `b80635aa`: the Forest Test was
served from `driven-hunt-rev` detached at that commit, Rojo showed `DrivenHunt localhost:34873`
connected (`327h-connect3.png`), and the build was confirmed live by `327h-table.txt` printing
`cellSchedule` output that does not exist at the base.
ANSWERED: L-014 — `driven-hunt-karen` was never checked out; it stayed at `516b9698` throughout
(`git -C driven-hunt-karen log` before and after). The proof build was served from `driven-hunt-rev`
on :34873 and :34873 now serves `driven-hunt-karen` again, reconnected
(`327h-reconnect2.png` shows `Disconnect`), place in **Edit**.
ANSWERED: L-101 — her attributes were dumped before (`327h-attrs-BEFORE.txt`) and after
(`327h-attrs-AFTER.txt`) with the same probe: the diff is **EMPTY**, `DHFlag_STAND_PICK = true`
included. The one attribute this task wrote, `DHForestLayout`, was cleared back to nil.
ANSWERED: L-093 — the six new cases die if the fix is deleted: three of them compare TWO cells'
derived schedules, so removing the `animals` rows (or making `cellSchedule` return the base table)
makes both sides of every comparison the same number. The seventh asserts the published step
counters against `stats()`, which is nil before the publish line exists.
ANSWERED: L-150 / L-176 — the frame instrument DID fail on its first try, exactly as warned: the
probe pivoted the player to the stand, the lobby pulled him back to the lodge, and the frame was
unstreamed haze over a "step on a truck pad" HUD with `0 ANIMALS`. It is not reported as a crossing
frame. The pivot was removed, the game put him at stand 4 itself (`dist=0`, `team=Shooters`,
`gun=true`), and the three frames were re-taken with one common due-north look. Each is opened and
described in the report, with `within220` beside it as the number.
ANSWERED: ROUTE (339's queued in-band speed finding) — `computeRoute`, `computeRouteVia`,
`repathVia`, `clearRoute` and `wavePoint` are **byte-identical** in this diff
(`git diff 516b9698..b80635aa -- src` touches none of them). What moves is the two numbers they are
handed, and both stay inside the caps already measured: `crossCapStuds` 95 and `routeFloor`. The
finding is neither worsened nor fixed here and stays queued.
