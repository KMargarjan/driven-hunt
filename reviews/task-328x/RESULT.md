PASS (items 8, 9 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: there is no core item in this task
— nothing here is animal behaviour or shooting. What Karen has seen in her place is `328x-F1`
before/after (Play, C1 stand 4's eye height, looking into C2: flat green, then a brown plain rising
to a ridge) and two EDIT cameras declared as such, `328x-F2-edit` (A2#8, the world's edge, item 7)
and `328x-F3-edit` (B2#9, held ground, item 9). **Item 8 is a table of numbers and nothing in it has
been seen** — no pad, junction, ditch station or stand landing is in any frame. **Item 9 is half
seen**: B2 has a frame, D2 has none, and D2 is the cell whose MATERIAL this bake repainted (121/121
`Ground`, note (n)) — a visible change to a cell the hold says it kept, described in words and
measured, never framed. B2's three ramps and the B2 bot climb are not on the ground at all.

Both round-1 findings are answered, and I agree with both answers.

Finding 1 (the silent landform drop) is now a reading. `TerrainBake.shapeTile` returns `dropped`
(`if here == nil then dropped += 1 end`), `TileReport.droppedLandform` carries it, `bakeTile` sets it
on both the normal and the empty-tile return, and `tools/terrainbake.py`'s `tile_pass` prints
`droppedLandform=%d/%d tiles` on the OK line unconditionally. `grid_relief` **328x-7** is a real
case, not a transcription: its two arms are two different runs of `shapeTile` over a `rolling` base
(not a plane), and `base[1]` vs `shaped[1]` compares the clean run's inner column 1 against the holed
run's — not one value through two names. I re-derived its geometry from the code: `padFor()` = 204,
so `strip = pad/v - 2` = 49 slice columns of void ending 12 studs west of the tile's first column,
`holesInTile` 0, and the shaping columns whose 72-stud support holds void are i = 31..48 — 18 a row ×
`wide` 96 = the 1,728 the request states. Delete the drop (make `Relief.heightAt` stop answering nil)
and both `expect(dropped > 0)` and the `math.abs(west - westHoled) > 1e-6` line fail; delete the
counter and `dropped > 0` errors.

Finding 2 (`BAKE_VERSION`) is answered at the constant, with the measurement named, which is the
option round 1 offered. The design has its own precedent for it (§13's 328q correction: *"`BAKE_VERSION`
stays 1 and `relief_golden.luau` does not move"* for arithmetic re-expressed without moving a value),
and both new arms — `limitPass`' `gone(i) or gone(j)` and `bakeTile`'s `if not innerAbsent[at]` band —
are entered only by a column `readerFor` answers nil for, which `bakeTileAt` refused outright before.

Cross-checks I ran against the repo rather than the request: `Grid.footprint()` at a 4-stud pitch is
1123 × 747 = **838,881** columns, exactly claim 4's count; harness line names the `Code commit:`
`a2d647fe` with "(clean tree)" and `paperwork-after-code-commit.txt` reads OK; `test2` N/A is right —
`TWO_PLAYER_PATHS` is `src/server/Match/`, `src/client/Match/`, `src/shared/Drive/` and the match
specs, none of which this diff touches; selene, stylua and `rojo build` are all exit 0.

## Notes (non-blocking)

- `reviews/task-328x/REQUEST.md` claim 5 — **the pasted `[bake]` line cannot have been printed by the
  code under review, and the request's own prose names a different commit for it.** `tile_pass` prints
  `"... worstTileMs=%d droppedLandform=%d/%d tiles (clean tree)"` with no conditional, yet claim 5's
  line reads `... worstTileMs=477 (clean tree)` and carries `@ 1cdc894d` — while the header says *"THE
  BAKE RAN AT `820484a6`"*. `sha` on that line is `check_clean_tree()`'s git HEAD, and `git log` shows
  `2ae2affb` changed `src/serverstorage/TerrainBake/init.luau`, `src/shared/Grid/Relief.luau` and
  `tools/terrainbake.py` after `1cdc894d`. I checked that commit's content: it is the counter and the
  `BAKE_VERSION` paragraph only — nothing in it can move a voxel — so Karen's ground is sound. What is
  wrong is the citation: claim 5 should paste the LAST run's own `[bake]` line, with its sha and its
  `droppedLandform=0/0 tiles`, instead of the first run's. Also `git diff 820484a6..HEAD --name-only`
  is the spec **and** `REQUEST.md`, not the spec "ALONE" (328h note (k)'s class).
- `Relief.heightAt` / `TerrainBake.shapeTile` — **`droppedLandform` counts less than the request
  implies.** When `blurred[at]` is nil, `heightAt` does not give up: `elseif smoothedAt ~= nil then
  smoothedAt else blurredAt(baseAt, x, z)` pays the per-point kernel in GRID space (1,369 base reads)
  and usually succeeds — which is the shear `921c27dc` ran into. So a column whose world-space grid
  blur was lost is shaped from a DIFFERENT blur than its neighbours and costs 1,369 reads, and nothing
  counts those; `droppedLandform` only sees columns where both blurs failed. Worth one sentence at the
  counter, and it is the likely half of `worstTileMs` 477 against 328h's 376.
- claim 11's geometry — the margin is ~10 studs, not the 25 its numbers give. `unionOf` is
  `Grid.worldBoundsOf`, so the union's west edge is A2's `boundsOf.minX` -6658 less `bend.nsStuds` 60
  = **-6718**, and `blendAt` is 0 at or past `BLEND_STUDS` 200, i.e. for x ≤ **-6918** — not -6903. The
  westernmost column that can call `heightAt` with k > 0 therefore reaches -6990 through the blur's 72
  against void at about -7000: **82 studs of gap, 10 of margin**, not 97 against 72. The other three
  sides are 197 / 431 / 416. The conclusion (`droppedLandform` 0) holds and is measured anyway, but the
  west margin is 10 studs and nothing pins it — a bend amplitude or an `originX` change makes it
  non-zero. Same class as 328h note (j).
- `TerrainBake.shapeTile` / `bakeTile` — **a hole that is not a hole: `absent` treats a Water column,
  an overhang and a band-ceiling truncation exactly like an empty one, and writes AIR over it.**
  `columnFault` has four arms and the snapshot carries `holeWhy`, but `enclosedHoles` and
  `occupancy = if gone then 0 else ...` read neither. Before this change `holes > 0` refused the tile;
  now a non-enclosed Water column inside a baked tile is cleared — Karen's bought water deleted, with
  the `--backup` as the only recourse. Not reached in this world (claim 4: 0 holes in all 838,881
  footprint columns, and the base's holes are the world running out), so a note — but gate the AIR
  write, or the non-enclosed acceptance, on `holeWhy` saying EMPTY.
- `TerrainBake.bakeTileAt`, the bench band — narrowing the band refusal to `bandEnclosed > 0` partly
  reopens what 328h added it for: a hole at the band's own edge is now accepted, the anchor walk reads
  nil at that x, and `applyOps` drops the bench for that column with `smoothed or b` — no error, no
  report, and no counter of the `droppedLandform` kind. Unreachable in this run (B2 and D2 are held,
  so `if held[band.cell] then continue` means no band was asked for at all, and A1 is not in the run),
  which is also why *"the bake could not run without"* the clip overstates: with the hold in place
  `bands = [b for b in (bands or []) if b["cell"] not in hold]` empties the list before
  `bench_slices_for` is ever called.
- `TerrainBake.bakeTileAt` — the comment above the changed check still asserts the retired rule, two
  lines above code that does the opposite: *"A TILE WHOSE BASE HAS A HOLE ANYWHERE IN ITS SLICE IS
  REFUSED... **THE PAD COUNTS**, and that is the round-1 finding... so refusing on the tile alone was a
  loosening, not a rule"* — while the refusal it introduces says *"column(s) in its %d-stud pad are
  **not counted**"*. `bench_slices_for`'s docstring has the same problem (*"`base_slice` refuses a
  rectangle that leaves the FILE"*, which is now true in z only).
- `TerrainBake.bakeTileAt` — still nothing drives the clipped-band ACCEPTANCE in Luau: restoring the
  old `extra.minX <= bandMinX + 1e-6 and eMaxX >= bandMaxX - 1e-6` would leave every `grid_relief`
  case green, and only the selftest's `"TerrainBake.voidMargin(extra, band.minZ, band.maxZ, west, east)"
  in bake_text` string match would notice. The Python half IS pinned behaviourally (delete `clip_x`
  and *"a bench band that leaves the base file in x is CLIPPED, not refused"* fails). Round-1 note,
  declared open by the request, 328h note (g)'s class.
- `TerrainBake.bakeTile` — a tile whose every inner column is absent returns `calls = 0, voxels = 0`
  with no message and counts in `1120/1120`; a slice-plumbing fault that made every column absent
  would read as a clean run. No tile in this run is wholly void (`regionFor` subset gives minX -6985
  against ground from about -7000), so it is latent. A count of empty tiles on the `[bake]` line closes
  it.
- `grid_relief.spec` `328x-6` arm (a) — `expect(TerrainBake.cellAt(without, x, z)).never.to.equal("B2")`
  still cannot fail for any `cellAt` that returns a member of the list it was handed; the arm is
  carried entirely by the `blendAt(union, x, z)` near-1 line. Arms (b), (c) and (d) do die with
  `holdLandform`, so the case as a whole is sound. Round-1 note, unfixed.
- `grid_relief.spec` `328x-7` — asserts `dropped > 0` where the geometry pins it at exactly 1,728
  (18 × 96, re-derivable from `padFor`, `BLUR.cutoffStuds` and `LIMIT_MARGIN_STUDS`). The exact number
  is only in a `TestKit.note`; asserting it would catch a reach that changes by one column.
  `328x-5` is never cited by any claim.
- `tools/terrainbake.py` `base_slice` — the comment says the per-column cost was *"looked up as
  `base["holes"]` per column"*; `base_load` makes that a `set`, so the O(n²) was entirely the
  `set(holes)` rebuild inside the `real` comprehension, which is what `hole_set` fixes. The timing
  check (`_took < 1.0` against ~0.2 s measured and 120 s for the old shape) is behavioural and
  falsifiable, which is the right shape for it.
- `reviews/task-328x/REQUEST.md` claims 3, 6, 8 — unchanged from round 1 and still three overstatements
  the measured numbers beside them correct: the five per-cell refusals (34/46/14/15/23) sum to 132, not
  the seven-cell 103; *"Row 1 did not move at all"* is true of the 95,944 INTERIOR columns only, and the
  two snapshot shas differ (`0317b4a77148` vs `8541621a62c9`), which is the seam the ~14:40 ESCALATE
  entry predicted would move; and claim 8's worst voxel step is 0.031 st OVER its own explained value
  at two junctions, stated in passing and not carried into "NOT MET" where 328h reported "none OVER".
  Also claim 12's *"re-baked by THIS code over ground the OLD code wrote"* — it re-baked from the
  virgin `.bin`, not over the old ground; the comparison it rests on is still the right one.
- `docs/design/grid-terrain.md` §5.4 and §5 — the design still says the limiter and the Y-band rule bump
  `BAKE_VERSION` with no exception clause, and its `[bake]` format line carries neither `hold=` nor
  `droppedLandform=`. The exception now lives only in a code comment at `Relief.BAKE_VERSION`. Worth
  carrying into the design when it next moves, with 328q's precedent beside it.
- TASKS.md note (n) — correctly declared, but it is baking D2 at all that repaints it, not the hold;
  the fix is `shapeTile` reading the base snapshot's material for a `reshape = false` cell, not a change
  to the hold.

---
REVIEWER verdict on commit `2816ff295912e07dd90d69fc8cd1495e023c9608` (round 2) · 2026-11-04 17:47 UTC · session cost $5.43, 40 turns · written by tools/agents.py
