# Task 337b -- the world trim: `tools/terrainbake.py trim`

Task: 337b
Round: 2
Base: 77217b77 (`main`)
Code commit: 98dbdaa95772c0e015bb30c3278ae70ab7d4cc71

`[harness] PASS: 34/34 checks @ 98dbdaa95772c0e015bb30c3278ae70ab7d4cc71 (clean tree) scope=all`

`test2`: **N/A** -- no `TWO_PLAYER_PATHS` path. The three files changed are `tools/terrainbake.py`,
`src/serverstorage/TerrainBake/init.luau` and `tests/server/grid_relief.spec.luau`; the first two map
to scope `map` in `BLAST_RADIUS` and none is in `TWO_PLAYER_PATHS`.

## What changed

The TOOL only. **No terrain has been removed, and none will be until this review passes** (dispatch
item 1). Design `docs/design/cell-loading.md` section 10.

## The two round-1 findings

1. **The irreversible half is now proved in Studio, against terrain the case writes itself.**
   `tests/server/grid_relief.spec.luau` 337b-1 and 337b-2 fill a 128-stud block of Grass at
   x,z 8000 -- outside every keep box, every cell, and the region the terrain-writer case reads --
   and then: `trimHits` reads **16 nodes / 0 hits** over Air and **16 hits** over ground;
   `trimBlock` returns `hitsBefore 16 -> hitsAfter 0` and the lattice reads 0 after it; and a
   MISALIGNED block is refused with `filled == 0` **and the ground still there**. *Verify:* the two
   `it` blocks at the end of the `the bake (task 328d)` describe, and the harness note
   `[server] 337b trimBlock x[8000,8128] z[8000,8128]: 16 node(s), 16 hit -> 0`. Delete `trimHits`,
   delete the `FillRegion`, or widen the alignment threshold and a COUNT goes red, not a sentence.
   The tool's `selftest` now only asserts that the two cases exist.
2. **K1 is checked against `TerrainBake.regionFor(Grid.cellIds())` IN STUDIO**, the function design
   10.4 names. `trim_live_region` asks it; `trim_region_problem` refuses when it could not be read
   at all, when any side differs by a voxel, and when the answer is not numbers. `command_trim` asks
   it **before the first block** and refuses; `command_trim_plan` asks it too and prints `ASSERTED`
   or `NOT ASKED`. Read back live in her place: `x[-7190,-1720] z[-7090,-3124]`. *Verify:*
   `selftest`'s *"K1 is checked against TerrainBake.regionFor IN STUDIO"* case, which enters all
   three arms.

A round-1 note is fixed in the same round because it was one line: the `--block-studs` refusal now
sits BEFORE the `trim plan` return, so `trim plan --block-studs 7` refuses instead of printing a
traceback. **Every other note is queued, not fixed** (CLAUDE.md step 5), including the two the
verdict corrected me on: `MapGen/Ground.luau` has two `WriteVoxels`, so *"every WriteVoxels in this
repo"* was wrong -- the owner-boundary substance (the new terrain write is inside `TerrainBake`)
holds; and the 11.3 % / ~10.5 % pair have different denominators.

## Claims

3. **A terrain write is not rayable on the tick that makes it, so both lattice reads yield first.**
   MEASURED in DEV 2026-11-09 through `terrainbake`'s own `call`: a `FillBlock` at (8064, 0, 8064)
   rayed `nil` on its writing tick and `18.0` after **two** frames; an Air fill the same.
   `TerrainBake.TRIM_SETTLE_FRAMES` is 3 and `trimBlock` waits it before the before-read and before
   the after-read. Without it the run's own numbers are stale readings -- which is how round 2's
   first gate run read `16 hit -> 0` wrongly as `0`.
4. **`trim` is a second DRIVER of one writer.** The Air fill is `TerrainBake.trimBlock`, in the
   module that owns the bake's terrain writes; `tools/terrainbake.py` does the complement arithmetic
   and calls it. The only new terrain-write call in `src/` is that one `FillRegion`.
5. **K1 is computed, never typed (L-093).** `trim_keeps` returns `region_for(CELL_IDS, facts)`.
   *Verify:* `selftest`'s first trim case moves the bend by +40 in a COPY of the facts and asserts
   all four sides of K1 move with it; a typed rectangle cannot.
6. **The keep list is checked against what it exists to hold, and the check is not a tautology.**
   `trim_keep_problem` refuses unless every point of `trim_points()` is inside a keep box -- the
   spawn, `Lobby.ANCHORS["forest-test"]`, `Range.ANCHORS["forest-test"]` and `OurForest`'s two
   measured corners -- the two anchors READ OFF their own Luau files by `trim_anchors`. *Verify:*
   `selftest` fires the refusal once for each anchor moved to (9000, -9000).
7. **Refusal 10, the rotation, is code.** `trim_rotation_problem` refuses unless
   `src/shared/ForestTest/init.luau` still reads `ForestTest.LAYOUT_ORDER = Grid.PLANTED_CELLS` and
   every name in it is a grid cell -- `ride` (4900, -4540) and `track` (4700, -3900) stand outside
   K2. *Verify:* `selftest` refuses a hand-written list, an empty one, and one holding `ride`.
8. **The removal set is the exact complement and no block can reach a keep box.** `subtract_box`,
   `trim_complement`, `grid_inward` (INWARD only), and `trimBlock`'s own `ExpandToGrid` refusal.
   *Verify:* `selftest`'s complement case (areas sum to world less keep union; no rectangle meets a
   keep box; no two meet each other) and its block case (on the lattice, inside a rectangle, clear
   of both keeps).
9. **The run prints what it removed (L-182).** Each block line prints `nodes`,
   `hitsBefore -> hitsAfter` and its own milliseconds; the closing line totals them and states
   `0 part(s) moved to Workspace.Archive337` with design 10.3's reason; the rows go to
   `.terrainbake/<ts>-trim.json`, which is also where `trim plan` takes its MEASURED minutes from.
10. **`trim` takes the whole existing ladder.** `MUTATING = PLANT_MUTATING + ("trim",)`: Edit mode,
    the place id re-asked before **every block**, a clean tree, a fresh `--backup .rbxl` outside the
    repo, the flag rule; `--blocks` required, `--cells` refused. `trim plan` returns before the
    clean-tree check and writes nothing.
11. **`trim plan` ran read-only in Karen's Forest Test at this commit** (Edit, place
    130094961655666): K1 `x[-7190,-1720] z[-7090,-3124]` **ASSERTED against Studio's own
    `regionFor`**, K2 `x[2200,3900] z[-3500,-1250]`, world `x[-7500,7500] z[-7500,7500] y[-512,616]`,
    **7 rectangles, 233 blocks, 88.7 % of the world box removed, 11.3 % kept**, census `841/1681`
    nodes with **738 outside the keep boxes**, `ForestRoadSpawn (3000, -2109) is inside K2`,
    `OurForest parts x[2229..3833] z[-2896..-1297]`. The minutes line reads *"NOT MEASURED YET"*,
    which is design 10.4 step 3.
12. **The world box is MEASURED and the one unmeasurable number is bounded, not assumed.**
    `trim_world` takes the census's occupied box grown by one lattice step -- not
    `Terrain.MaxExtents`, which reads `[-32000..32000]` on every axis in her place and would make
    4,073 blocks of mostly nothing. The Y floor cannot be read by a downward ray, so it is DECLARED
    (-512) and the after-census is its check.

## What I could not verify

- **No terrain has been trimmed.** Dispatch items 2-4 (backup, run, before/after census, frames,
  `smoke.sh`) come after this review by the dispatch's own order.
- **The per-block cost is unmeasured**, so `trim plan` prints no minutes.
- **Terrain beyond the census lattice (+-10,000 studs) is not in the removal set**, and the Y
  CEILING is inferred from the same lattice as the floor (round-1 note).
- **One incidental change to the DEV place, reported rather than hidden:** the 2026-11-09 settle
  measurement filled and then cleared a 128 x 32 x 128 block at (576, 0, 576) in DEV's Edit session,
  and the Air fill removed ~4,096 pre-existing terrain cells there as well as its own. Nothing was
  saved or published; terrain is not Rojo-managed and no harness check reads it. The later probes
  used x,z 8064, where there is no terrain.

ANSWERED: L-136 the named flakes fired repeatedly and are named with their runs, at this commit:
run 6 `deer_hitbox.spec:682`, `weapon_shot.spec:1490`, `weapon_shot.spec:1890`,
`semiauto_client.spec:93`; run 7 `weapon_shot.spec:1490` and `weapon_client.spec:1769`; run 8
`PASS: 34/34`. All but `weapon_client.spec:1769` are in the dispatch's list (that file is listed at
:1211/:1263, not :1769). Earlier, at the round-1 commit, `map_ui.spec:1071` failed three runs in a
row at 11.05/11.10/11.62 Hz against `near 20 (within 8)`: NOT random and NOT a code defect -- free
memory was 2.3 GB of 14.2 with a stray `RobloxPlayerBeta` (1,153 s CPU, no window, started 01:12),
Chrome and three `RobloxCrashHandler`s alive. Closing those took it to 2.7 GB and the next run read
PASS. Eight `test` runs in all; no control run at the merge-base was taken, and I do not claim one.
ANSWERED: L-127 every claim names its instrument; everything else is under *"What I could not
verify"*.
ANSWERED: L-162 the harness line, `trim plan`'s live run and `selftest` are all at `98dbdaa9` on a
clean tree.
ANSWERED: L-014 nothing was checked out in `driven-hunt-karen`; `trim plan` only READ her place,
in Edit, through StudioMCP.
ANSWERED: L-101 no attribute of her place has been written; the attribute diff belongs with the run.
ANSWERED: L-093 claims 1, 5, 6 and 7 each name the producer and what deleting it reddens; the Luau
half is a Studio spec now, because a grep survived the deletion.
ANSWERED: L-182 claim 9 -- the run prints the block count and the before/after lattice itself.
ANSWERED: L-174 the cap is the Director's; this is round 2 and I stop here either way.
