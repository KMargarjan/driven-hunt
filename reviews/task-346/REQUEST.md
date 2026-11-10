# Task 346 — deeper forest behind the roads, at the corners and the road ends

Task: 346
Round: 1
Base: 29fd976c (main, PR #359)
Code commit: c4ab2f99d834aae58f2ca2d7dba1d9b0d77fa23e

`[harness] PASS: 34/34 checks @ c4ab2f99d834aae58f2ca2d7dba1d9b0d77fa23e (clean tree) scope=all`

`[harness2]` N/A: no `TWO_PLAYER_PATHS` path is touched (`src/shared/Places/`, `tests/server/`).
No FAIL line is claimed as a flake in this request: the run above is 34/34 with 0 failed, 0 errors.

Karen, 2026-11-10: *"more tree needs behind, it has to be feeling animals run away to another
forest"* and *"also more trees on back side specially on corners or ending"*. Every number is in
`reviews/task-346/MEASUREMENTS.md`; each claim below says where to read it.

## The headline, first

**The dispatch's target — no station above 10 % open past the far road — is REFUTED by the
instrument's own control, and the deepening shipped anyway because the frames show it works.** The
fan reads **61.5 % open from inside C1's own accepted wood**. The metric did not move; frame F3 went
from an empty hillside to a wall of conifers. MEASUREMENTS §1, §2, §3.

## What changed

Two files. `src/shared/Places/init.luau`:

- `Places.SKIRT_DEEPEST_STUDS` = 420 and `Places.SKIRT_WIDEN_STUDS` (derived:
  `Grid.CONFIG.roadClearStuds + SKIRT_DEEPEST_STUDS`).
- `Places.skirtBands` emits a **third band**, `plan.skirtStuds` to `SKIRT_DEEPEST_STUDS`, on all
  four sides; on an **outer edge only** that band also runs `SKIRT_WIDEN_STUDS` past both ends of
  the cell's frontage. That widening is what plants the quadrant diagonally beyond a world corner
  and caps the channel a road leaves where it runs out of the grid.
- `Places.skirtZoneAt` clamps into the species cell's ground on **both** branches; unclamped, the
  widened ground reads nil and plants nothing.
- `PART_BUDGET_CELL` 12,800 → 14,200, `PART_BUDGET_DRIVE` 27,000 → 29,000, both re-derived off the
  measured plans of all eight cells.

`tests/server/grid.spec.luau`: new case **16a**, plus the frozen numbers that move with the
geometry (`BENT_C1`/`STRAIGHT_C1`, the band count, the reach bound, the outer-edge key, the caps).

## Claims

1. **The hole was geometry, not density.** Every band's cross span was the cell's own inset ground,
   so two bands meeting at a corner each stopped at the road between them: the diagonal quadrant
   beyond a corner was planted by neither side, and a road ran out through the skirt as an open
   channel. Verify: `Places.skirtBands`' `lowCross`/`highCross` at `29fd976c`, and the measured
   count — **0 corner-quadrant stems on all 8 cells before, 26–63 after** (MEASUREMENTS §4).
2. **A case that dies if either half is deleted (L-093).** `grid.spec` case 16a
   ("the deep corners and road ends"): set `SKIRT_WIDEN_STUDS` to 0 and every corner quadrant it
   requires empties; drop the third band and `beyondSkirt` goes to 0. Both are counted off the
   PLANTED sites, not off the band rectangles. Verify: run it with either edit.
3. **The widening cannot reach another cell's frontage, ride or interior.** It is confined to the
   deepest band of an outer edge, where it stands 230+ studs beyond the footprint — no road has
   `from`/`to` extent there. The first cut widened every band on every side and
   `grid_ground.spec:647` and `:888` both caught exactly that; the narrowing is commit `c4ab2f99`.
   Verify: the `widen =` term in `skirtBands`, and `grid_ground.spec` green in the harness line.
4. **Every skirt site still stands on ground the task 340 trim kept.** Case 16a asserts
   `outside <= 490` — K1 is the footprint grown by `Relief.BLEND_STUDS + 230 + Grid.maxBendStuds()`
   (`tools/terrainbake.py`'s `region_for`). Measured worst: **470**. Verify: case 16a's note line.
5. **The budgets are re-derived, not raised to fit.** Heaviest cell D2 = 3,650 models = 13,724 parts
   at 3.76, so 14,200 leaves 126 models; D1's `cellCapacity` 7,561 sites = 28,429 parts, so 29,000
   leaves 150. Still **2,800 parts under** the only measured ceiling (328g, 17,000 parts inside
   1,024 studs). Verify: the `PART_BUDGET_*` header, `grid.spec` case 14's recomputation.
6. **Both live sides are the same instrument (L-181).** One Play session each in Karen's place, the
   same `346-run.sh`, the same 27 named stations a cell, and **both replant the cell** through
   `terrainbake.py`'s own prelude — a Play boot would otherwise stand the prebuilt wood. BEFORE is
   `driven-hunt-rev` at `29fd976c`, AFTER is `driven-hunt` at the code commit. Verify:
   MEASUREMENTS §1 header and the `PLANT_REPO=` line of each run.
7. **The 10 % target is refuted, with its own control and the arithmetic.** `ctrl:dense:C1` reads
   61.5 % open from inside the wood Karen accepted; 10 % over 400 studs needs ~3,000 extra models a
   side against a 3,776-model cell ceiling. Verify: MEASUREMENTS §1.
8. **The frames carry the result, and each was opened.** F3: empty hillside → conifers across the
   horizon. F2: the bright gap behind C1's birches closed by a dark band. F1: no visible change, and
   why. Verify: MEASUREMENTS §3 and `<runs-dir>/346-F{1,2,3}-pair.png`.
9. **Budget: one line met, one above, two not proven.** Memory +143.0 MB against +300. p95 at the C1
   stand 20.22 → 25.73 ms, **above the +2 ms budget**, against a measured run-to-run spread of
   1.05–2.77 ms on the same build — one sample a side cannot settle it, and A2 moved the other way.
   Swap worst-frame and drive-start wait were not read by this instrument. Verify: MEASUREMENTS §5.
10. **Nothing was written to Karen's place.** Play only, no Save/Publish/Drafts Commit, no
    `flags.py clear`. The attribute diff is empty but for the session's own two clocks
    (MEASUREMENTS §6); the FT is left on `:34873` from `driven-hunt-karen`, Edit.

## What I could not verify

- The **worst server frame of a cell swap** and the **drive-start wait**: this task's probe reports
  bites and wall ms, not either of those. NOT PROVEN, not claimed.
- Whether C1's **+5.51 ms p95** is this change or session drift. One sample a side; the before run
  was taken twice and spread 1.05 ms at that station. A Director call, recorded as NOT PROVEN.
- **Interior corners and interior road crossings are not deepened.** Closing those means planting
  one cell's species inside a third cell, across that cell's frontage and rides — a real ownership
  question this task refuses to guess at. Queued as 346a in `TASKS.md`.
