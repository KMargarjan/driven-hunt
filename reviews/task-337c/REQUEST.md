# Task 337c — forest behind every road of the hunted cell

Task: 337c
Round: 1
Base: efe88ab2 (main, task 340's world trim)
Code commit: 183a38fee75cba3f65582a1035192c9ed6063589

`[harness] PASS: 34/34 checks @ 183a38fee75cba3f65582a1035192c9ed6063589 (clean tree) scope=all`
`[harness2]` N/A: no `TWO_PLAYER_PATHS` path is touched (`src/shared/Places/`, `tests/server/`).

A FAIL line appears in four earlier runs of this branch and the word flake is used below, so two
harness lines at two different commits: the control at the merge base is
`[harness] FAIL: 32/34 checks @ efe88ab2885ff66402a3ebac4fbc6d8b2552c8b7 (clean tree) scope=all`,
failing the SAME case (`map_ui.spec:1071`) and worse — 9.72 Hz against this branch's 10.91-11.57.

Karen, 2026-11-09: *"so behind the road always has to be forest to have impression that animals
running in forest not in empty field"*. Design: `docs/design/cell-loading.md` 8.1. Every number is
in `reviews/task-337c/MEASUREMENTS.md`; the claims below name where to read each one.

## What changed

`src/shared/Places/init.luau` — `Places.skirtSides` (new), `Places.skirtZoneAt` (new),
`Places.skirtBands` (an outer-edge arm), `Places.plantCell`'s skirt loop, `Places.cellCapacity`'s
skirt term, and the three budget constants. `tests/server/grid.spec.luau` and
`tests/server/grid_ground.spec.luau` follow. Two `grid.spec` cases that asserted task 328i's
opposite rule are archived under `backups/` (rule 7).

## Claims

1. **Every cell skirts all four of its roads now, the grid's outer edge included.**
   `Places.skirtSides` answers four entries for every cell, `id` nil at an outer edge;
   `plantCell`'s loop walks it with no `hasOwnWood` skip. Verify: `grid.spec` case 16's note —
   `C1 666 over 4 sides (1 outer, reach 253/230)`, four sides for all eight cells; and
   MEASUREMENTS §2, which pairs it with the before (C1 **0** -> **666**).

2. **It dies if the fix dies, and the kill was RUN** (L-093). Put `plantCell`'s
   `if Places.hasOwnWood(side.id) then continue end` back and C1's skirt goes **666 -> 150** —
   every surviving row an outer-edge one. `c1Skirt > 0` would still have passed, so case 18c
   counts `intoPlanted` (514 today), which goes to **0**, and case 16's per-side
   `expect((hitEach[wanted] or 0) > 0)` reddens for B1, D1 and C2. Verify: the comment above case
   18c carries both readings, taken through `<runs-dir>/337c-l093.luau`.

3. **Whose wood each side is** (Director decision): across a road into a cell with a wood of its
   own, THAT cell's species; at an outer edge, and into A1 which has none, the standing cell's.
   `Places.skirtZoneAt` is the one reader. Verify: `grid.spec` case 16's share assertion — each
   side's dominant group holds >= 10 % of the species cell's own wood. It is a share and not an
   equality because C2's own wood is 1,252 conifer to 1,218 birch; a swapped rule still reddens,
   C1's birch being ~1 % of B1's wood.

4. **No trunk on a road, a stand pad or a beater line, and the skirt's roadside edge matches the
   cell's own.** Every skirt row answers `nil` to `Places.maskGrid(groundCell, x, z, model, scale)`
   — the cell whose GROUND it stands on. Verify: case 16's note, one pair on one line —
   **nearest road centre, skirt 35.90 studs / own wood 34.32 studs, verge ends 34.0**.

5. **Nothing leaks inward.** Not one skirt row lands in its own cell's ground, over all eight
   cells. Verify: case 18c, `expect(stray).to.equal(0)`.

6. **The budget, re-derived and raised, with the before/after in its own ledger** (L-165):
   `PARTS_PER_MODEL` 3.03 -> **3.76** (C1 live 9,318 parts / 2,476 models); `PART_BUDGET_CELL`
   8,000 -> **12,800** (`CELL_PART_CAP` 2,640 -> 3,404); `PART_BUDGET_DRIVE` 22,000 -> **27,000**
   (`CELL_PLAN_CAP` 7,260 -> 7,180). Verify: MEASUREMENTS §1, and case 14's note — worst plan
   D2 3,256, tightest slack **155 plan / 148 part** (it was 16 part). **The drawn-parts row is the
   one that mattered: C1 drew 9,318 parts against the OLD 8,000 budget — already breached — and
   draws 11,645 against 12,800 now**, still 4,200 under 328g's measured 17,000-part client frame.

7. **Karen's sentence as a number, in her place, before and after, one instrument.** Open ground
   behind the standing cell's four roads, 20-stud lattice, 25-stud reach, band computed from `Grid`
   and never from `Places`: **C1 100.0 % open -> 37.6 %**, D2 100.0 % -> 49.0 %, B2 100.0 % ->
   38.0 %. Verify: MEASUREMENTS §4 and `<runs-dir>/337c-open.luau`.

8. **And on screen.** `337c-F1-before.png` / `337c-F1-after.png`, C1 stand 8, eye height, identical
   camera: before, an empty green field across the road to the horizon; after, a dense spruce wood
   on both sides of the same road, carriageway still clear. `337c-G-before/after.png` top-down
   shows the band appear on all four sides. **`337c-F2` from a D2 stand is NOT OBTAINABLE** and
   MEASUREMENTS §7 gives the measured reason (a Play client streams only around its own character).

9. **The guard held, and the one target that did not.** Frame time p95 at a C1 stand
   **19.22 -> 20.03 ms**, against the dispatch's ceiling of 28.53 x 1.10 = **31.38 ms** — MET;
   client memory **4,384.1 -> 5,353.3 MB**, reported. **NOT MET: the swap.** `Cells.reconcile`
   254 -> **661 ms** to C1 and 271 -> **573 ms** to B2, past `cell-loading.md` T7's 500 ms. T7
   names its own fallback (a `Slice`-bitten move); it is a separate task. Verify: MEASUREMENTS §5
   and §6.

10. **Her place is planted at the code commit and boots clean.** `[bake] plant OK: 7 cell(s) @
    d84337a6… 20599 models / 67926 parts`; boot `prebuilt forest: STANDS … 20599 model(s) in 7 cell
    folder(s) … dress=false`; `smoke.sh` **PASS** (gun in hand at +16 s and 80 s, stacks=0,
    errorLines=0, waves=10); **attribute diff EMPTY**; backup `FT-before-337c.rbxl` 11,545,437
    bytes taken before any write. Verify: MEASUREMENTS §8.

## What could not be verified

- **The D2/B2 eye-height frames** (claim 8) — NOT OBTAINABLE, reason measured, §7.
- **Whether the depth reads right to Karen.** 230 studs is the dispatch's starting point and it is
  what shipped; `337c-F1-after.png` is the evidence that it reads as wood into the haze, and only
  she can accept it.
- **A1-facing sides cannot distinguish the species rule** (claim 3): A1's own recipe is
  `spruceSlope` and so is its neighbours' dominant group, so that pair would pass either way. The
  rule is distinguished on C1's three sides and on every outer edge.
- **Nothing was played as a drive in a cell other than C1**, so the skirt of B1, D1, A2, B2, C2 and
  D2 has been measured (§2, §4) but not looked at from inside.
- **The 1,614 floating `Session`/`LobbyAssets` parts left by task 340's trim are untouched.** The
  dispatch's NOT YOURS defers them to the next task; `340-result.json` says 337c owns them. Flagged
  for the Director, not acted on.
