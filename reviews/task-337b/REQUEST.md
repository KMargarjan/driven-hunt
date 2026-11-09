# Task 337b -- the world trim: `tools/terrainbake.py trim`

Task: 337b
Round: 1
Base: 77217b77 (`main`)
Code commit: 075a19721e8b89064e8d76f2ae65920458f278f0

`[harness] PASS: 34/34 checks @ 075a19721e8b89064e8d76f2ae65920458f278f0 (clean tree) scope=all`

`test2`: **N/A** -- no `TWO_PLAYER_PATHS` path is touched. The two files changed are
`tools/terrainbake.py` and `src/serverstorage/TerrainBake/init.luau`; both map to scope `map` in
`BLAST_RADIUS`, neither is in `TWO_PLAYER_PATHS`.

## What changed

The TOOL only. **No terrain has been removed by this commit, and none will be until this review
passes** (dispatch item 1: *"Gate and review the tool BEFORE any terrain is removed"*). Design
`docs/design/cell-loading.md` section 10.

## Claims

1. **`trim` is a second DRIVER of one writer, not a second writer.** The Air fill is
   `TerrainBake.trimBlock` in `src/serverstorage/TerrainBake/init.luau` -- the module that already
   owns every `WriteVoxels` in this repo; `tools/terrainbake.py` does the complement arithmetic and
   calls it. *Verify:* `grep -n "FillRegion\|WriteVoxels" src/ tools/` -- every terrain write is in
   that one module.
2. **K1 is computed, never typed (L-093).** `trim_keeps` returns `region_for(CELL_IDS, facts)` for
   K1 -- the Python twin of `TerrainBake.regionFor` that `plan` already asserts against Studio's
   own. *Verify:* `selftest`'s first trim case moves the bend by +40 in a COPY of the facts and
   asserts all four sides of K1 move with it; a typed rectangle cannot, so the case dies the day K1
   is typed. Read back: `x[-7190,-1720] z[-7090,-3124]`, which is design 10.2's row.
3. **The keep list is checked against the things it exists to hold, and the check is not a
   tautology.** `trim_keep_problem` refuses unless K1 is `regionFor`'s region AND every point of
   `trim_points()` is inside a keep box: the spawn, `Lobby.ANCHORS["forest-test"]`,
   `Range.ANCHORS["forest-test"]` and `OurForest`'s two measured corners. The two anchors are READ
   OFF their own Luau files by `trim_anchors` (a regex over `src/shared/Lobby/init.luau` and
   `src/shared/Range/init.luau`), not retyped. *Verify:* `selftest` fires the refusal for a K1
   narrowed by 500 studs, and once for each anchor moved to (9000, -9000) -- which is what proves
   the file read is on the live path.
4. **Refusal 10, the rotation, is a line of code and not a sentence.** `trim_rotation_problem`
   refuses unless `src/shared/ForestTest/init.luau` still reads
   `ForestTest.LAYOUT_ORDER = Grid.PLANTED_CELLS` and every name in `Grid.PLANTED_CELLS` is a grid
   cell. `ride` (4900, -4540) and `track` (4700, -3900) stand outside K2. *Verify:* `selftest`
   passes today's list (`C1,C2,A2,B1,D1,B2,D2`) and refuses a hand-written
   `LAYOUT_ORDER = { "ride", "track" }`, an empty list, and a list holding `ride`.
5. **The removal set is the EXACT complement, and nothing in it touches a keep box.**
   `subtract_box` splits a rectangle four ways; `trim_complement` folds the keeps over it.
   *Verify:* `selftest` asserts, on a synthetic world and two synthetic keeps, that the areas sum to
   the world less the keep union, that no rectangle meets a keep box, and that no two rectangles
   meet each other.
6. **No block is ever expanded INTO a keep box.** `grid_inward` rounds a box INWARD to the 4-stud
   voxel lattice and drops a sliver under one voxel; `TerrainBake.trimBlock` calls
   `Region3:ExpandToGrid` and REFUSES the block if that moved it. *Verify:* `selftest` checks
   `grid_inward` both ways, and the refusal string `"not aligned to the"` is in the Luau.
7. **The run prints what it removed (lesson L-182).** `TerrainBake.trimHits` reads a 100-stud ray
   lattice inside the block before AND after the fill; each block line prints `nodes`,
   `hitsBefore -> hitsAfter` and its own milliseconds, the closing line totals them and states
   `0 part(s) moved to Workspace.Archive337` with design 10.3's reason. The per-block rows go to a
   `.terrainbake/<ts>-trim.json` run log.
8. **`trim` takes the whole existing ladder, and `trim plan` writes nothing.** `MUTATING` is
   `PLANT_MUTATING + ("trim",)`, so `trim` needs Edit mode, the place id re-asked **before every
   block**, a clean tree, a fresh `--backup .rbxl` outside the repo and the flag rule; `--blocks` is
   required (its refusal 6) and `--cells` is refused. `trim plan` returns before the clean-tree
   check. *Verify:* the `trim` branches in `main`, and `selftest`'s `"trim" in MUTATING` case.
9. **The world box is MEASURED, and the one number the design could not give is bounded rather than
   assumed.** `trim_world` takes the census's own occupied box grown by one lattice step -- NOT
   `Terrain.MaxExtents`, which reads x,y,z `[-32000..32000]` in Karen's place (measured 2026-11-09)
   and would make 4,073 blocks of mostly nothing against 233. The Y floor cannot be read by a
   downward ray, so it is DECLARED (-512) and the after-census is its check: terrain left below the
   band is terrain a ray still hits, so T4 would not read 0.
10. **`trim plan` ran read-only in Karen's Forest Test at this commit** (Edit, place
    130094961655666, nothing written): keep K1 `x[-7190,-1720] z[-7090,-3124]`, keep K2
    `x[2200,3900] z[-3500,-1250]`, world `x[-7500,7500] z[-7500,7500] y[-512,616]`, **7 removal
    rectangles, 233 blocks, 88.7 % of the world box, 11.3 % kept** (design 12 T3's keep share is
    ~10.5 %), census `841/1681` nodes hit with **738 outside the keep boxes**, `ForestRoadSpawn
    (3000, -2109) is inside K2`, `OurForest parts x[2229..3833] z[-2896..-1297]`. The minutes line
    reads *"NOT MEASURED YET"*, which is design 10.4 step 3.

## What I could not verify

- **No terrain has been trimmed.** Items 2-4 of the dispatch (the backup, the run, the before/after
  census, the frames, `smoke.sh`) are AFTER this review by the dispatch's own order. Every number
  above is either offline arithmetic, `selftest`, or the read-only `trim plan`.
- **The per-block cost is unmeasured**, so `trim plan` prints no minutes. An Air `FillRegion` is a
  different engine call from `WriteVoxels` and the design says its cost was not verified.
- **Terrain beyond the census lattice (+-10,000 studs) is not in the removal set.** Stated in
  `trim_world`'s header as a bound, not assumed away.

ANSWERED: L-136 the flake fired and is named -- `map_ui.spec:1071` *"near 20.000000 (within
8.000000) but got 11.05/11.10/11.62"* on three consecutive runs at this same commit, and
`weapon_shot.spec:1490` once. It was NOT a code defect and not random: free memory was 2.3 GB of
14.2, with a stray `RobloxPlayerBeta` (1,153 s CPU, no window, started 01:12), Chrome and three
`RobloxCrashHandler`s alive. Closing those took free memory to 2.7 GB and run 4 read
`PASS: 34/34`. Four runs; the PASS line above is run 4.
ANSWERED: L-127 every claim says MET by its own instrument or sits under *"What I could not
verify"*; nothing after this review's order is claimed.
ANSWERED: L-162 the harness line, `trim plan`'s live run and `selftest` are all at
`075a19721e8b` on a clean tree.
ANSWERED: L-014 nothing was checked out in `driven-hunt-karen`; `trim plan` only READ her place,
through StudioMCP in Edit.
ANSWERED: L-101 no attribute of her place has been written; the diff belongs with the run, after
this review.
ANSWERED: L-093 claims 2, 3 and 4 each name the producer and what deleting it reddens.
ANSWERED: L-182 claim 7 -- the run itself prints the block count and the before/after lattice.
ANSWERED: L-174 the 2-round cap is the Director's; this is round 1.
