# Task 346 — deeper forest behind the roads, at the corners and the road ends

Task: 346
Round: 2
Base: 29fd976c (main, PR #359)
Code commit: 7f35ed1d424afd267acc2f893b20c1c5f0e3dd43

`[harness] PASS: 34/34 checks @ 7f35ed1d424afd267acc2f893b20c1c5f0e3dd43 (clean tree) scope=all`

`[harness2]` N/A: no `TWO_PLAYER_PATHS` path is touched (`src/shared/Places/`, `tests/server/`).
No FAIL line is claimed as a flake: the run above is 34/34, 0 failed, 0 errors, first try.
The last commit to touch `src/` or `tests/` is `dd0bc967`; `7f35ed1d` adds only
`reviews/task-346/RESULT.md` on top of it, so the line covers every code file.

Karen, 2026-11-10: *"more tree needs behind, it has to be feeling animals run away to another
forest"* and *"also more trees on back side specially on corners or ending"*. Every number is in
`reviews/task-346/MEASUREMENTS.md`.

## Round 1's finding, and what round 2 did about it

**Finding 1 — case 16a measured depth from the cell's own box, so the band-3 count could not fail.
FIXED** in `dd0bc967`. The Reviewer was right: on an interior side `skirtBands` starts at the
NEIGHBOUR's inset ground, 45 studs outside the box, so band 2's outer rim already read as *past
`skirtStuds`*. Three changes:

- `skirtBands` rows carry **`deepest`**, and case 16a now collects the deepest band's own
  rectangles and counts the planted sites **inside them** — `expect(#deepRects).to.equal(4)` and
  `expect(inDeepest > 0)`. `scatter` refuses a jittered site that leaves its band rect, so lying
  inside one IS the measurement, taken at the kerb each band starts from.
- **`SKIRT_DEEPEST_STUDS >= 420` is pinned as a floor**, which is the Reviewer's own second attack
  (a band that exists but reaches 250 left every count green).
- The terrain bound is **derived**, `Relief.BLEND_STUDS + 230 + Grid.maxBendStuds()`, not typed 490
  (round 1 note).

**The deletion was RUN, not argued** (L-093, `346-deepproof.py` at the code commit, in a Play server
of Karen's place with the planter injected): with band 3 deleted from `skirtBands`,
`deepRects` **4 → 0** and `inDeepest` **C1 371 → 0, A2 451 → 0**. Both new assertions redden.

Four round-1 notes taken in the same commit: the constant's header no longer claims the band is
drawn on the widened flanks only (it runs on all four sides — that is where most of the ~370 extra
sites a cell come from); band 3's `far` is `math.max(plan.skirtStuds, SKIRT_DEEPEST_STUDS)` so a
recipe past 420 cannot invert it; `deepest` is documented and now read; 150 → 151 sites. The rest
are queued as 346a.

**Round 2 moves no tree.** `346-verify.py` at `dd0bc967` returns the plan of `c4ab2f99` to the
digit — C1 3,558 / 13,378 parts, D2 3,650 / 13,724, every corner quadrant the same — so §3's frames
and §2's before/after stand at this code commit (L-162).

## The headline

**The dispatch's target — no station above 10 % open past the far road — is REFUTED by the
instrument's own control, and the deepening shipped anyway because the frames show it works.** The
fan reads **61.5 % open from inside C1's own accepted wood**. The metric did not move
(91.2 → 91.7 %); frame F3 went from an empty hillside to conifers across the horizon.
MEASUREMENTS §1, §2, §3.

## What changed

`src/shared/Places/init.luau`:

- `Places.SKIRT_DEEPEST_STUDS` = 420 and `Places.SKIRT_WIDEN_STUDS` (derived:
  `Grid.CONFIG.roadClearStuds + SKIRT_DEEPEST_STUDS`).
- `Places.skirtBands` emits a **third band**, `plan.skirtStuds` to `SKIRT_DEEPEST_STUDS`, on all
  four sides; on an **outer edge only** that band also runs `SKIRT_WIDEN_STUDS` past both ends of
  the cell's frontage — which plants the quadrant diagonally beyond a world corner and caps the
  channel a road leaves where it runs out of the grid.
- `Places.skirtZoneAt` clamps into the species cell's ground on **both** branches; unclamped, the
  widened ground reads nil and plants nothing.
- `PART_BUDGET_CELL` 12,800 → 14,200, `PART_BUDGET_DRIVE` 27,000 → 29,000, re-derived off the
  measured plans of all eight cells.

`tests/server/grid.spec.luau`: case **16a**, plus the frozen numbers that move with the geometry.

## Claims

1. **The hole was geometry, not density.** Every band's cross span was the cell's own inset ground,
   so two bands meeting at a corner each stopped at the road between them. Verify: `skirtBands`'
   `lowCross`/`highCross` at `29fd976c`, against the measured **0 corner-quadrant stems on all 8
   cells before, 26–63 after** (MEASUREMENTS §4; case 16a's note line).
2. **Case 16a dies if either half is deleted, and the deletion was run.** Band 3 deleted →
   `deepRects` 4 → 0, `inDeepest` 371 → 0 (above). `SKIRT_WIDEN_STUDS` → 0 → every corner quadrant
   the case requires empties. `SKIRT_DEEPEST_STUDS` → 250 → the new floor reddens.
3. **The widening cannot reach another cell's frontage, ride or interior.** Confined to the deepest
   band of an outer edge, 230+ studs beyond the footprint, where no road has `from`/`to` extent.
   The first cut widened every band on every side and `grid_ground.spec:647` and `:888` caught
   exactly that; the narrowing is `c4ab2f99`. Verify: the `widen =` term, and those two cases green.
4. **Every skirt site still stands on ground the task 340 trim kept.** Case 16a asserts
   `outside <= Relief.BLEND_STUDS + 230 + Grid.maxBendStuds()` (490 at today's bend). Measured
   worst **479** (A1). Verify: case 16a's note line.
5. **The budgets are re-derived, not raised to fit.** D2 = 3,650 models = 13,724 parts at 3.76, so
   14,200 leaves 126 models; D1's `cellCapacity` 7,561 = 28,429 parts, so 29,000 leaves 151 sites.
   Verify: the `PART_BUDGET_*` header, `grid.spec` case 14's recomputation. **It is a part bound and
   not a frame claim** (round 1 note): the frame question is claim 9.
6. **Both live sides are the same instrument (L-181).** One Play session each in Karen's place, the
   same `346-run.sh`, the same 27 named stations a cell, and **both replant the cell** through
   `terrainbake.py`'s own prelude — a Play boot would otherwise stand the prebuilt wood. BEFORE is
   `driven-hunt-rev` at `29fd976c`, AFTER `driven-hunt` at `c4ab2f99`, whose plan `dd0bc967`
   reproduces to the digit. Verify: MEASUREMENTS §1 and each run's `PLANT_REPO=` line.
7. **The 10 % target is refuted, by its own control and by arithmetic.** `ctrl:dense:C1` reads
   61.5 % open from inside the wood Karen accepted; 10 % over 400 studs needs ~3,000 extra models a
   side against a 3,776-model cell ceiling. Verify: MEASUREMENTS §1.
8. **The frames carry the result, and each was opened.** F3: empty hillside → conifers across the
   horizon. F2: the bright gap behind C1's birches closed by a dark band. F1: no visible change,
   and why. Verify: MEASUREMENTS §3, `<runs-dir>/346-F{1,2,3}-pair.png`.
9. **Budget: one met, one above it, two not proven.** Memory +143.0 MB against +300. p95 at the C1
   stand 20.22 → 25.73 ms, **above the +2 ms budget**, against a measured same-build spread of
   1.05–2.77 ms; A2 moved the other way (−2.26). Swap worst-frame and drive-start wait were not
   read by this instrument. Verify: MEASUREMENTS §5.
10. **Nothing was written to Karen's place.** Play only; no Save, Publish or Drafts Commit; no
    `flags.py clear`. All 16 `DHFlag_*` rows plus the three grant attributes are byte-identical
    before and after (MEASUREMENTS §6). Her FT ends on `:34873` from `driven-hunt-karen`, Edit.

## What I could not verify

- The **worst server frame of a cell swap** and the **drive-start wait**: this task's probe reports
  bites and wall ms, not either. NOT PROVEN, not claimed.
- Whether C1's **+5.51 ms p95** is this change or session drift. One sample a side; the before run
  was taken twice and spread 1.05 ms at that station. A Director call.
- **Karen has not seen it.** The three frame pairs are the Builder's, described in §3.
- **Interior corners and interior road crossings are not deepened.** Closing them means planting one
  cell's species inside a third cell, across that cell's frontage and rides — an ownership question
  this task refuses to guess at. Queued as 346a(a).
- `docs/design/grid-terrain.md` §8.4 and §5.2 still say the border wood is 230 studs deep. The
  Builder may not edit a design; queued as 346a(d) with the Reviewer's wording.
