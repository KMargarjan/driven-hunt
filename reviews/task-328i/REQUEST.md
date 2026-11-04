# Task 328i -- the forest behind the line: the baked cells beyond C1, at C1's accepted density

Task: 328i
Round: 2
Base: 2d28e98a
Code commit: 325c8435baf617f294c5cc38c00d2b43b15d55af

`[harness] PASS: 34/34 checks @ 325c8435baf617f294c5cc38c00d2b43b15d55af (clean tree) scope=all`

`[harness2]` N/A: no `TWO_PLAYER_PATHS` path is touched. The whole diff is
`src/shared/Places/init.luau`, `src/shared/Grid/init.luau`, `src/server/Places/init.luau`,
`src/server/ForestTestBoot.server.luau`, `tests/server/grid.spec.luau`.

**Every live reading below was taken at `32842034` or later.** `git diff 32842034..325c8435 --
src/shared/Places/init.luau` changes **no line that is not a comment**, so every planted number,
census reading and frame still describes the code commit; the round-2 fix moved the boot PATH, not
the plan. Claim 11 is new and was measured at the code commit's own `src/`. Backup first: `<backups-dir>/FT-before-328i.rbxl`, 28,944,479 B, `<roblox!`,
sha `e75e801742ff601a`, 19:46 UTC, taken before anything.

## PLAN (Core Quality Protocol step 0, committed at `8bf71e73` before any `src/` edit)

**(a) REAL LIFE.** A managed 40-80 year mixed stand carries 1,000-2,500 stems a hectare at 2-3 m
between them (328s's cited figure). One stud is ~0.28 m at these tree heights, so 2-3 m is 7-11
studs; C1 ships `minGapStuds` **11** (~3.1 m) and Karen accepted it: *"rest seems ok"*.

**(b) MEASURED NOW** (`<runs-dir>/328i-base.txt`, Play server, main's code, her place):
`GridPlaces` held **C1 and nothing else** -- 2,393 models / 8,128 parts -- because `Places.build`
called `dressCell(Grid.PREVIEW_CELL, ...)` **once**. Seven cells had never had a tree in them in any
session. Planned: C1 2,450, C2 1,689, A2 1,431, B1 1,754, D1 1,204.

**(c) TARGET.** Each planted cell's OWN-rectangle tree count within **+-10 %** of C1's accepted
**1,861**, every cell still under `CELL_PART_CAP` 2,640 and `CELL_PLAN_CAP` 7,260. The skirt is
excluded because a skirt stands in the NEIGHBOUR's ground -- see claim 3.

**(d) LEVER** (grep): `Places.CELL_PLANS.{spruceRolling,larchRolling,birchSlope,oakRolling}`, and
`Places.build`'s single `Places.dressCell(Grid.PREVIEW_CELL, ...)` -- which round 2 splits in two
(claim 9), because that call site is `ForestTestBoot`'s composition root.

**(e) MEASURED AFTER** by the same probes, with this branch injected into the same Play session.

## ITERATION (step 2) -- four cycles, same probe

| cycle | change | C2 | A2 | B1 | D1 | verdict |
|---|---|---|---|---|---|---|
| 1 | C1's fields + canopy x0.667 (C1's own 24->16) | 3,329 | 2,803 | 3,114 | 2,024 | **three past `CELL_PART_CAP` 2,640** -- one borrowed ratio is refuted |
| 2 | the ratio solved per cell | 3,035 | 2,552 | 2,844 | 2,147 | two still over, D1 short |
| 3 | sweep: **C2 and B1 reach it on the FIELDS ALONE** | 2,469 | 2,444 | 2,409 | 2,385 | all in band; then claim 3 moved the target |
| 4 | **shipped**, measured as OWN wood | **1,926** | **2,016** | **1,805** | **1,843** | **103 / 108 / 97 / 99 % of C1's 1,861** |

Files: `328i-yield-c{1,2,3}.txt`, `328i-sweep1.txt`, `328i-split.txt`, `328i-split2.txt`.

## Claims, and how to verify each

1. **The cause was one call, and a list fixes it.** `Places.build` dressed `Grid.PREVIEW_CELL`
   alone; it now dresses `Grid.PLANTED_CELLS` (`C1,C2,A2,B1,D1` -- the five whose ground 328x baked;
   A1 was never baked, B2 and D2 were held with `--hold-landform`), through a new
   `Places.dressCells`. `dressCell` fells every other cell's wood on its way in, so it gains a
   `keep` set; the cell being dressed is destroyed whether it is in the set or not. *Verify:*
   `grid.spec` "the cells that get a wood" -- three cases, one of which stands three cells up at
   once over a fake hillside and **cannot pass under the one-cell contract**.
2. **Every planted cell is at C1's own accepted density.** Own-rectangle trees, skirt and ferns
   excluded: C1 **1,861** (the standard), C2 1,926, A2 2,016, B1 1,805, D1 1,843 -- 97 to 108 %.
   *Verify:* `328i-split2.txt`; `grid.spec` "plants every one of them at C1's own accepted density".
   **AND C1 ITSELF DOES NOT MOVE A SINGLE TREE**, which is the other half of the same fact: both
   plans computed in ONE probe in her place with one ground reader -- main's `Places` from the
   place, this branch's injected -- give C1 own **1,986 against 1,986, and 0 of 1,986 rows differ**
   on model, x, z, scale, yaw and band. Only its skirt goes, 464 to 0 (`328i-c1same.txt`).
3. **A cell draws no skirt into a PLANTED neighbour, and that removes a measured defect rather than
   tidying up.** With all five standing and the skirt still drawn, trunk pivots, ferns excluded:
   **652 cross-cell pairs inside 11 studs, 199 inside 6, 59 inside 3, worst 0.54 studs** --
   interpenetrating trunks -- against **102 / 0 / 0 WITHIN a cell, same instrument, same run**. With
   the rule: **20 / 9 / 1, worst 1.25 studs**. *Verify:* `328i-overlap-after.txt` against
   `328i-overlap-final.txt`; `grid.spec` "draws no skirt into a planted neighbour, and still skirts
   a bare one", which asserts both halves so neither extreme can pass.
4. **Planted in HER place, through the branch's own `dressCell`.** C1 1,941 of 1,986 (refused
   2.27 %), C2 2,241 of 2,367 (5.32 %), A2 2,311 of 2,334 (0.99 %), B1 2,167 of 2,252 (3.77 %),
   D1 2,169 of 2,223 (2.43 %) -- **every one under 8 %**. Parts a cell 6,563 / 7,490 / 7,562 /
   7,274 / 7,108, **all under `PART_BUDGET_CELL` 8,000**. A second dress of C2 returned the same
   2,241 of 2,367 and the same 7,490 parts, which is the plan's purity measured rather than assumed.
   *Verify:* `328i-dress2-*.txt`, `328i-dress3-C2.txt`.
5. **`GridCensus` is 0 world-wide on every counter that can be 0**, over all five cells: floating,
   sunk, tilted, broken, noGround, inRoad, inStand, onCliff, crownOverRoad, crownUnmeasured. Worst
   daylight under a trunk **1.9e-05 studs**, worst sink **0.600** -- the seating rule's own
   `min(0.6, 0.1h)` cap, so these are live readings and not a metric stuck at zero. `inLane`
   144/0/0/195/239, which the module's own comment says can never be 0 for a grid cell.
   *Verify:* `328i-census-final.txt`.
6. **The performance guard passes, measured in her place at a C1 stand in Play.** Client frame time,
   C1-only against all five: mean **37.90 to 39.75 ms (+4.9 %)**, median 33.36 to 35.79, p95 69.30
   to 63.51; parts the client held 3,743 to 5,815 (+55 %). Under the dispatch's **15 %**.
   World-wide **35,997 grid parts + 9,111 places = 45,108**, under `grid-terrain.md` 12.2's
   ~63,000. The five dresses cost **172 s** of sliced planting in round 1 and **71.8 s** in round
   2's warm session, average step 4.6 ms, **0 starts over budget** -- and claim 9 is why that
   number is no longer the boot's. *Verify:* `328i-fps-before.txt`, `328i-fps-after.txt`,
   `328i-census-final.txt`, `328i-dress2-*.txt`, `328i-deferred.txt`.
7. **Three frames, in Play, at hunter eye height, opened and described.**
   `328i-F1-{before,after}.png` -- the same C1 stand looking -Z into C2, same session, player
   UNENROLLED (L-095): before, bare trunks and an open plain running to a green ridge; after, a
   closed wood. **Sky in the horizon band 27.03 % to 9.79 %, mean RGB 95,120,99 to 65,86,59**; 5x
   zooms `328i-F1-zoom-{before,after}.png`. `328i-F2-after.png` -- standing on EW2 at (-4100,
   107.3, -5069) looking west: a clear dirt corridor with a wall of wood both sides, which is
   `inRoad 0` and `crownOverRoad 0` on screen. `328i-F3-after.png` -- inside C2's densest 100-stud
   window (-4171, -5975, eye 176.3): mature trunks all round, young spruce understorey, leaf litter,
   sky only in gaps.
8. **The new wood does not trap an animal, measured BOTH ways in one drive.** 328h called this NOT
   OBTAINABLE ("the drive runs in C1 only"); that is **refuted here** -- 8,881 of 23,955 position
   samples (37 %) were in C2. Same sampler, same session, same drive, C2 planted against C2
   stripped: stuck **2.07 % against 0.80 %** of commanded samples, **0 animals stuck >= 3 s either
   way**, worst single run **1.80 s against 2.20 s**, and both worst cases are in C1 -- the cell
   this task does not change. *Verify:* `328i-sampler-after.txt`, `328i-sampler-before.txt`. The
   stripped reading was taken SECOND; said here rather than implied.
9. **ROUND 2, THE BLOCKING FINDING: the four cells are off the boot's critical path, and that is
   measured live.** `Places.build` is `ForestTestBoot`'s composition root -- `Bots.start` (593),
   `Economy.start` (656), `Lobby.start` (793), `Shop.start` (1007), `Match.start` (1053) and
   `HitLog.start` (1779) all come after it -- so `build` now dresses **`PLANTED_CELLS[1]` only**
   and hands the rest back in `report.gridPending`; the boot dresses those on a `task.spawn`
   **below `HitLog.start` and `ForestTest.start`**, passing `Grid.PLANTED_CELLS` as the KEEP list.
   `dressCells` gains that separable keep list, and the template audit is lifted into
   `Places.templateLookup` so the deferred dress runs the SAME audit, not a copy.
   *Verify, live in her place at this `src/`* (`328i-deferred.txt`): a fresh boot's own line is
   `grid wood C1: 2393 of 2450 planted (8128 parts) ... 20.19s` and `places: ... 22.66s` -- **one
   cell on the boot path, exactly as before this task**; then `Places.dressPending` with
   `pending = C2,A2,B1,D1` planted **2,241 / 2,311 / 2,167 / 2,169**, the same counts as claim 4,
   in **71.8 s**, and **C1 went 2,393 -> 2,393: it survived**, which is the keep list working on
   the real world. *Verify by spec:* `grid.spec` "plants one cell on the boot path and hands the
   rest back as gridPending" (and the keep-list half of the `dressCells` case, which shows the
   same call **felling** the others when the list is omitted).
   **Honest limit:** that boot line is her place's own boot, which runs `main` (L-014). What this
   branch changes on that path is `dressCell(PREVIEW_CELL)` -> `dressCells({PLANTED_CELLS[1]})` --
   the same single cell, pinned by the spec above, not re-measured by her boot.
10. **Nothing was left behind.** The Edit place's probe output is **byte-identical before and
   after** (`328i-where.txt` against `328i-where-after.txt`, by `cmp`): same attributes, same
   Workspace children, Karen's 15 `DHFlag_*` untouched (rule K). `GridPlaces` and `GridForest` are
   both absent in Edit -- the plant lives only in a Play DataModel. The FT ends in **Edit on
   localhost:34873** (`328i-rojo-crop.png`). `smoke.sh` **PASS** in both rounds (`328i-smoke.txt`,
   `328i-smoke2.txt`): gun in hand at 15 s and at 80 s, **0 stacks, 0 error lines**, 12 waves.

## What could not be verified, and what is NOT MET

* **`Workspace.GridForest` is NOT built** (`grid-terrain.md` 16's 328i row, defect F-1). That row
  wants an **Edit-time prebuild saved with the place**; this dispatch forbids clicking Save or
  Publish, and `grid-roads.md` section 13 item 5 assigns the prebuild and its performance gate to
  **328g**. So the wood is planted at boot into `GridPlaces`, as `Places.build` has always done.
  `ESCALATE.md` carries it for the Director: it is a scope question, not a wrong number.
* **The boot's own `task.spawn` is not proven live.** Her Forest Test syncs from
  `driven-hunt-karen` (L-014), so its boot ran main. Claim 11 drives the branch's own
  `Places.dressPending` over the real world with the real keep list, which is everything that call
  does; what is unproven is the `task.spawn` wrapper in `ForestTestBoot` itself.
* **1 cross-cell pair remains inside 3 studs** (1.25 studs, C2/D1 at -3222,-5346) and 9 inside 6.
  Every one is two cells' skirts meeting inside a cell that is **bare** (A1/B2/D2), which no drive
  uses. Measured, not fixed; queued in the TASKS row.
* **`foliageInGround` D1 176** against C1's 45 -- carried, not raised: it read 214 before the skirt
  rule, and that counter has never been a 0 one (328s shipped C1 at 77).
* **Karen has not seen it.** The frames are mine.

## Learning flags

ANSWERED: L-136 two of the dispatch's named flakes fired, each once, and each cleared on an
immediate re-run at the SAME commit: `boar_behaviour.spec:1553` in gate run 1, and
`deer_hitbox.spec:682` in gate run 5 (`325c8435` FAIL 32/34) against gate run 6 (`325c8435` PASS
34/34). Nothing else was ever called a flake -- the other three failures in run 1 and the one in
run 2 were MINE, and were named and fixed in `79f42097` and `032ee3c0`.
ANSWERED: L-127 every dispatch item is MET or NOT MET by name in the report's handover block, and
the NOT MET items are listed above rather than left out.
ANSWERED: L-162 every live reading was taken at `32842034`, whose `src/` is identical to the code
commit's -- `git diff --name-only 32842034..032ee3c0` is one spec file.
ANSWERED: L-014 nothing was ever checked out in `driven-hunt-karen`; the branch's code reached her
Play session by injection (328m's route) and her FT ends on `localhost:34873` in Edit.
ANSWERED: L-167 every design number was re-derived: `CELL_PART_CAP` 2,640 and `CELL_PLAN_CAP` 7,260
read live from `Plan`, the 1,861 standard read off C1's own plan in the same probe, and cycle 1
refuted the single borrowed ratio by measurement instead of by argument.
ANSWERED: L-076 three eye-height Play frames at the worst spots were opened and described BEFORE any
"0 floating" is claimed, and claim 5 reports the live worst daylight and worst sink rather than a
bare zero.
ANSWERED: L-101 the Edit place's attributes were captured before and after and are byte-identical;
Karen's 15 flags are listed in `328i-attrs-after.txt`.
ANSWERED: L-093 the producer-deleted test: `grid.spec`'s `dressCells` case fails if `keep` is
removed (only the last cell of the list would be standing), and the skirt case asserts both halves,
so deleting the `isPlanted` guard reddens it as surely as deleting the skirt would.
ANSWERED: L-095 the Learning Agent's own flag -- the player was kept UNENROLLED for F1, F2 and F3
(team=nil), which 328x and 328y could not do; repins were 1 to 5 over 110 s, not 185, and all three
frames are Play frames, not Edit cameras.
ANSWERED: L-169 the planter targets by explicit cell id and `cellWoodFolders` by folder NAME, never
through `cellAt`, so there is no A1 spillover: the census found exactly five folders, and A1, B2 and
D2 have no wood at all.
