# Task 337c — forest behind every road of the hunted cell

Task: 337c
Round: 2
Base: efe88ab2 (main, task 340's world trim)
Code commit: 65cbd4ba183df23129edfe3978ee1979f0335214

`[harness] PASS: 34/34 checks @ 65cbd4ba183df23129edfe3978ee1979f0335214 (clean tree) scope=all`
`[harness2]` N/A: no `TWO_PLAYER_PATHS` path is touched (`src/shared/Places/`, `tests/server/`).

The last commit to touch `src/` or `tests/` is `82c19024`; `65cbd4ba` adds only
`reviews/task-337c/RESULT.md` on top of it, so the line above covers every code file.

FAIL lines appear in earlier runs of this branch and the word flake is used below, so two harness
lines at two different commits: the control at the merge base is
`[harness] FAIL: 32/34 checks @ efe88ab2885ff66402a3ebac4fbc6d8b2552c8b7 (clean tree) scope=all`,
failing the same `map_ui.spec:1071` and worse — 9.72 Hz against this branch's 10.91-11.57.

Karen, 2026-11-09: *"so behind the road always has to be forest to have impression that animals
running in forest not in empty field"*. Design: `docs/design/cell-loading.md` 8.1. Every number is
in `reviews/task-337c/MEASUREMENTS.md`; each claim names where to read it.

## Round 1's finding, and what round 2 did about it

**Finding 1 — case 16 collapsed both outer edges of a corner cell into one `"OUTER"` bucket, so
A1, D1, A2 and D2 had only 3 of their 4 sides asserted. FIXED** in `82c19024`. An outer row is now
keyed by the footprint edge it is beyond (`OUTER:W/E/N/S`), **exactly one** must match
(`expect(#beyond).to.equal(1)`), and the per-side loop builds the same key from the side's `axis`
and `sign` through one `sideKey` helper, which the species loop also uses. Verify: case 16's
`sideKey`, the `beyond` block, and `expect((hitEach[sideKey(side)] or 0) > 0)`; with the fix, each
of A1/D1/A2/D2's two outer sides must carry rows of its own. The empty-band kill the finding
describes now reddens on that side's own key.

Three comments the change had made false are corrected in the same commit (round 1 notes): the cap
header's `7,260 / 2,640` -> `7,180 / 3,404`; `plantCell`'s *"differ only on an outer edge and into
A1"* -> only into A1, because an outer edge has no neighbour; and `neighboursOf`'s claim to be the
skirt's walker. Case 18c's `516` -> `514`, and `MEASUREMENTS.md` §1's ratio wording and §2's reach
arithmetic. Everything else the Reviewer noted is queued in `TASKS.md`, not fixed here.

## What changed, overall

`src/shared/Places/init.luau` — `Places.skirtSides` (new), `Places.skirtZoneAt` (new),
`Places.skirtBands` (an outer-edge arm), `plantCell`'s skirt loop, `cellCapacity`'s skirt term, and
the three budget constants. `tests/server/grid.spec.luau` and `tests/server/grid_ground.spec.luau`
follow. Two `grid.spec` cases that asserted task 328i's opposite rule are archived under
`backups/` (rule 7).

## Claims

1. **Every cell skirts all four of its roads, the grid's outer edges included.** `skirtSides`
   answers four entries per cell, `id` nil at an outer edge; `plantCell` walks it with no
   `hasOwnWood` skip. Verify: case 16's note — `C1 666 over 4 sides (1 outer, reach 253/230)`,
   four sides for all eight cells — and MEASUREMENTS §2's before/after (C1 **0 -> 666**).

2. **It dies if the fix dies, and the kill was RUN** (L-093). Put `plantCell`'s
   `if Places.hasOwnWood(side.id) then continue end` back and C1's skirt goes **666 -> 150**, every
   survivor an outer-edge row. `c1Skirt > 0` would still pass, so case 18c counts `intoPlanted`
   (514 today) which goes to **0**, and case 16's per-side `expect((hitEach[sideKey(side)] or 0) >
   0)` reddens for B1, D1 and C2. Verify: the comment above case 18c carries both readings, taken
   through `<runs-dir>/337c-l093.luau`.

3. **Whose wood each side is** (Director decision): across a road into a cell with a wood of its
   own, THAT cell's species; at an outer edge, and into A1 which has none, the standing cell's.
   `Places.skirtZoneAt` is the one reader. Verify: case 16's share assertion — each side's dominant
   group holds >= 10 % of the species cell's own wood. A share and not an equality because C2's own
   wood is 1,252 conifer to 1,218 birch; a swapped rule still reddens, C1's birch being ~1 % of
   B1's wood.

4. **No trunk on a road, a stand pad or a beater line, and the skirt's roadside edge matches the
   cell's own.** Every skirt row answers `nil` to `Places.maskGrid(groundCell, x, z, model, scale)`
   — the cell whose GROUND it stands on. Verify: case 16's note, one pair on one line —
   **nearest road centre, skirt 35.90 studs / own wood 34.32 studs, verge ends 34.0**.

5. **Nothing leaks inward.** Not one skirt row lands in its own cell's ground, over all eight
   cells. Verify: case 18c, `expect(stray).to.equal(0)`.

6. **The budget, re-derived and raised, with the before/after in its own ledger** (L-165):
   `PARTS_PER_MODEL` 3.03 -> **3.76**; `PART_BUDGET_CELL` 8,000 -> **12,800** (`CELL_PART_CAP`
   2,640 -> 3,404); `PART_BUDGET_DRIVE` 22,000 -> **27,000** (`CELL_PLAN_CAP` 7,260 -> 7,180).
   Verify: MEASUREMENTS §1 and case 14's note — worst plan D2 3,256, tightest slack **155 plan /
   148 part** (it was 16 part). **The drawn-parts row is the one that mattered: C1 drew 9,318 parts
   against the OLD 8,000 budget — already breached — and draws 11,645 against 12,800 now**, still
   4,200 under 328g's measured 17,000-part client frame.

7. **Karen's sentence as a number, in her place, before and after, one instrument.** Open ground
   behind the standing cell's four roads, 20-stud lattice, 25-stud reach, band computed from `Grid`
   and never from `Places`: **C1 100.0 % open -> 37.6 %**, D2 100.0 % -> 49.0 %, B2 100.0 % ->
   38.0 %. Verify: MEASUREMENTS §4 and `<runs-dir>/337c-open.luau`.

8. **And on screen.** `337c-F1-before.png` / `337c-F1-after.png`, C1 stand 8, eye height, identical
   camera: before, an empty green field across the road to the horizon; after, a dense spruce wood
   on both sides of the same road, carriageway still clear. `337c-G-before/after.png` top-down
   shows the band appear on all four sides. **`337c-F2` from a D2 stand is NOT OBTAINABLE** and
   MEASUREMENTS §7 gives the measured reason (a Play client streams only around its own character).

9. **The guard held, and the one target that did not.** Frame-time p95 at a C1 stand
   **19.22 -> 20.03 ms** against the dispatch's ceiling of 28.53 x 1.10 = **31.38 ms** — MET;
   client memory **4,384.1 -> 5,353.3 MB**, reported. **NOT MET: the swap.** `Cells.reconcile`
   254 -> **661 ms** to C1 and 271 -> **573 ms** to B2, past `cell-loading.md` T7's 500 ms. T7
   names its own `Slice`-bitten fallback; a separate task. Verify: MEASUREMENTS §5 and §6.

10. **Her place is planted at the code commit's planner and boots clean.** `[bake] plant OK:
    7 cell(s) @ d84337a6… 20599 models / 67926 parts` (`d84337a6` is this branch's first commit;
    `82c19024` and `65cbd4ba` change only specs and paperwork, and the per-cell plan counts are
    byte-identical across all three — the harness note prints the same `s588/s645/s666/…` row at
    `183a38fe` and at `65cbd4ba`). Boot: `prebuilt forest: STANDS … 20599 model(s) in 7 cell
    folder(s) … dress=false`; `smoke.sh` **PASS** (gun in hand at +16 s and 80 s, stacks=0,
    errorLines=0, waves=10); **attribute diff EMPTY**; backup `FT-before-337c.rbxl` 11,545,437
    bytes taken before any write. Verify: MEASUREMENTS §8.

## What could not be verified

- **The D2/B2 eye-height frames** (claim 8) — NOT OBTAINABLE, reason measured, §7. **Rule 5 is met
  for C1 only**: items 7 and 8 are `NOT PROVEN` for the other six cells, where the skirt is a
  lattice number and not a look, and Karen has accepted neither the 230-stud depth nor any frame.
- **A1-facing sides cannot distinguish the species rule** (claim 3): A1's own recipe is
  `spruceSlope` and so is its neighbours' dominant group, so that pair would pass either way. The
  rule is distinguished on C1's three sides and on every outer edge.
- **In EDIT mode all seven cell folders stand at once**, so 328i's measured trunk interpenetration
  across a road returns there until the boot's `Cells.reconcile` stores six. Nobody re-measured it
  this round (round 1 note, for the Director).
- **`docs/design/cell-loading.md` is now stale in three places** (§8's contract table, §8.1's
  "not this task", §14's "+464 sites"). Not the Builder's file; queued for the Architect.
- **The 1,614 floating `Session`/`LobbyAssets` parts left by task 340's trim are untouched.** This
  dispatch's NOT YOURS defers them to the next task; `340-result.json` says 337c owns them.
  Flagged for the Director, not acted on.
- **A new flake, named because it is not in the dispatch's list**: `weapon_equip.spec:713` failed
  two consecutive round-2 runs and the merge-base control, then passed with nothing changed. It
  re-raises a `pcall`'d inner assertion in the weapon-equip sweep; nothing in this change reaches
  the weapon.
