# Task 327h — each section its own animal pattern

Task: 327h
Round: 3
Base: 516b9698 (main, PR #353)
Code commit: b2b12ee8d534c31aa33f71215e0f21f52de2db20

`[harness] PASS: 34/34 checks @ b2b12ee8d534c31aa33f71215e0f21f52de2db20 (clean tree) scope=all`

`test2` N/A: `tools/agents.py`'s `TWO_PLAYER_PATHS` names none of the changed files — no
`src/server/Match/`, no `src/shared/Drive/`, no `MatchBoot`, no `tests/client/Role.luau`, none of
the named specs. The change is `Grid`, `ForestTest` (shared + server), `Places`, the boar runtime,
`ForestTestBoot` and `forest_line.spec`.

## Round 3: what changed, and nothing else

Authorised in `ESCALATE.md` (Director, 2026-11-10 ~01:25 UTC, commit `78c8610e`): option 1, scope
named there. Round 2's two findings were **both right** and both are fixed. Nothing else in `src/`
moved.

1. **THE FOUR-PASS REST ORDER, *(zone AND seen) > zone > seen > any***, in `ForestTest.restPasses`
   and a new `ForestTest.restPassWants` (the one statement of what each pass reads).
   Round 2 shipped three passes, so on the last one `seen` was `true` by construction and task
   172's sightline was gone for any group whose candidates all fall outside the cell's list.
   `restSpot`'s loop is structurally unchanged — it now asks `restPassWants` which of the two world
   facts to read, and asks the cheaper zone test before casting a ray (round 2's note).
   **With no list it is still exactly task 172's two passes.**
2. **THE B1 COORDINATE CASE the Reviewer named.** `restSpot`'s own point: B1's centre x **-5011**,
   a candidate `REST.nearRoadStuds` north of the main road at world z **-5112**. The two spaces
   differ by **45 studs** there: converted it is `spruceRidge` **zone 1**, unconverted it is
   **nil** — outside the cell's inset ground — and `restZoneAllowed` refuses it. Both values are
   asserted, not only their equality.
3. **A case for finding 2**: two candidates, neither in the cell's zones, the one the rings reach
   first screened and the second visible. Four passes take the **second**, on pass 3; three passes
   took the first.

**FAIL FIRST (L-093), one run with BOTH producers deleted** — `Grid.toGrid` removed from
`Places.zoneIndexAt`, and `restPasses`/`restPassWants` reverted to their three-pass arms:

`[harness] FAIL: 30/34 checks @ b2b12ee8d534c31aa33f71215e0f21f52de2db20 (DIRTY TREE (2 paths) - NOT valid evidence) scope=all`
```
failed [server] forest_line.spec:1933 Expected value "4" (number), got "3" (number) instead
failed [server] forest_line.spec:1975 Expected value "2" (number), got "1" (number) instead   <- finding 2's case
failed [server] forest_line.spec:2019 Expected value "1" (number), got "nil" (nil) instead    <- the B1 case
```
The producers were then restored and the tree is clean at `b2b12ee8`; the PASS line above is that
tree. `:1975` is the finding-2 case and `:2019` the B1 one, and both are in the commit reported.

## MEASURED: the ten resting groups, A2 and C1, before and after

Same probe file (`<runs-dir>/327h-rest.luau`), same place, run in her Forest Test from the
`driven-hunt-rev` route — **before at `1d484d4e`** (three passes) and **after at `b2b12ee8`** (four).
It beds all ten `REST.groups` through the live `restSpot`, then recovers the pass from that spot's
own two world facts, so each build is read by its own shipped rule.

| run | cell | passes | placed | seen from the lane | p1 / p2 / p3 / p4 |
|---|---|---|---|---|---|
| BEFORE `1d484d4e` | A2 | 3 | 10/10 | **10** | 2 / 0 / 8 / — |
| AFTER `b2b12ee8` | A2 | 4 | 10/10 | **10** | 2 / 0 / 8 / 0 |
| BEFORE `1d484d4e` | C1 | 3 | 10/10 | **10** | 10 / 0 / 0 / — |
| AFTER `b2b12ee8` | C1 | 4 | 10/10 | **10** | 10 / 0 / 0 / 0 |

**The ten spots are identical in both builds** — `diff` of the two A2 files differs only in the
`passes=` header and the tally line; every group keeps its `dz`, its zone and `seen=true`.

**WHAT THIS DOES AND DOES NOT SHOW, plainly.** The Reviewer's arithmetic is confirmed: **8 of A2's
10 groups** fall past the zone test (they land in zone 1, a `shrub` band, while `restZones = {3}`),
so under three passes they were bedded with **no sightline test at all**. In this sample all eight
happened to be visible anyway — so the regression cost nothing *here*, by luck. The four-pass order
makes it a **rule** rather than luck, at no measured cost: same spots, same count, and pass 4 is
never reached in either cell. A case where luck runs out is the spec case, which goes red on the
three-pass build (`:1975`).

## Round 2: what changed, and nothing else

Round 1's two blocking findings were **both right** and both are fixed. Nothing else in `src/`
moved, except one line of `Flags` the clock broke (below).

1. **WORLD COORDINATES FED INTO A GRID-SPACE TEST.** `Places.zoneIndexAt` is now the WORLD wrapper
   -- `Grid.toGrid` once, `bend` a trailing optional -- over a new `Places.zoneIndexAtGrid` kernel,
   which is `Places.mask` / `clearOfEveryRoad`'s own shape. The header says which space each takes.
   New case *"asks the zone question in the space the zones are written in"*: the world call and
   the grid call agree for the same point, and a **zero-amplitude bend** makes the unconverted call
   right -- so the defect is reachable by parameter, not only by reading.
2. **THE CASE SURVIVED DELETING THE THIRD PASS.** The pass count and the per-candidate rule are now
   `ForestTest.restPasses` / `ForestTest.restPassTakes`, pure and by parameter; `restSpot` supplies
   the two world facts (the zone index, the sightline) and asks nothing itself. New case *"takes a
   bedded group out of the cell's own zones first…"* runs `restSpot`'s own loop over two
   hand-written candidates and asserts **the answer moves**: with no list, two passes return
   candidate 1 on pass 1 (task 172's answer, unchanged); with `{1, 2}`, three passes return
   candidate **2** on pass **2**; with `{7}` -- a zone nobody is in -- the group is still bedded, on
   pass 3. Delete the widening or the filter and the two sides stop differing.

**One line outside the task, named rather than hidden:** `AUTUMN_LIGHT`'s `expires` was
`2026-11-09` and the clock rolled over to 2026-11-10 during this task, so
`tests/server/flags.spec.luau`'s rot tripwire failed the gate (`flags.spec:124`, `2879 passed, 1
failed`). The date is moved to `2026-11-23` with the reason in the row, which is one of the three
answers `docs/design/feature-flags.md` section 11 allows. Commit `1d484d4e`, three lines.

**On the first run of this round the client reported `map_ui.spec:1071` failed** -- one of the
specs the dispatch names as a known flake. It is **not** in the PASS line above: the run was
repeated at the same commit `1d484d4e` and came back `34/34` with `2880 passed, 0 failed` on the
server and the client clean. No FAIL line is offered as evidence here.

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
8. **`restZones` is a reading of the recipe, asked in the right space, and the order bites.**
   Every listed zone is `band == "wood"`, has `spacingStuds > 0` (not the clearing) and overlaps
   `REST.nearRoadStuds..farRoadStuds` — now as fractions of `Places.cellGround`'s **inset** depth
   measured from the road plus the inset, which is the exact map (round 2's note; A2's overlap is
   **31** studs, not ~53). Asserted over all seven cells against `Places.cellPlanFor`. Plus the
   three round-3 cases: the B1 space, the four-pass order, and the finding-2 preference — all
   three red with the producers deleted (the FAIL-FIRST block above).
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
- The rest search is now read live as well as by rule (the A2/C1 table above), but **through
  `restSpot` called from a probe, not through a played beater drive** — nobody has walked a lane
  and seen the bedded animals. Karen is away.
- `restSpot`'s three lines of GLUE (`restZonesOf`, the `for pass` bound, the `restPassTakes` call)
  are still driven by no spec case — round 2's note, and it is NOT fixed: closing it needs a seam
  that takes the pass rule by parameter, which is outside the round the Director authorised. The
  live A2/C1 table is what stands in for it: it is `restSpot`'s own answer, not the rule's.
- **The non-blocking notes I did NOT take**, named rather than dropped silently: that glue seam
  (above), and `AUTUMN_LIGHT`'s re-justified `expires` being 35 days after `born` against section
  12's 21-day ceiling — the Reviewer called that the Architect's file and the Director's call, and
  `docs/design/` is not mine. The other five one-liners are all taken.

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
ANSWERED: L-093 — both producers were DELETED and the gate run, and three cases went red:
`forest_line.spec:1933`, `:1975` (finding 2's case) and `:2019` (the B1 case). The producers were
restored and the clean-tree PASS above is that tree. The pattern cases die the same way: three of
them compare TWO cells' derived schedules, so removing the `animals` rows collapses both sides.
ANSWERED: L-136 — `map_ui.spec:1071` (named in the dispatch's flake list) fired on **2 of the 4**
runs of this round and on 1 of the 2 runs of round 2, at THREE different commits —
`1d484d4e`, `5dcbafc5` and the dirty FAIL-FIRST tree — and passed at `b2b12ee8`, which is the
commit the PASS line above names. No FAIL line is offered as evidence anywhere in this request.
ANSWERED: L-162 — the A2/C1 measurement was read at the two commits it names (`1d484d4e` before,
`b2b12ee8` after), each served to her Forest Test from `driven-hunt-rev` and confirmed connected
(`327h-r3-conn2.png`, `327h-r3-re2.png`).
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
