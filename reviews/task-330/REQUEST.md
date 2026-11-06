# Task 330 -- B2 and D2 baked and planted, the cache ON with its divergence measured

Task: 330
Round: 1
Base: db7cd633
Code commit: 3bce240c

`[harness] PASS: 34/34 checks @ 3bce240c35c02756e6728548a9f21bed24cda48d (clean tree) scope=all`
`test2` N/A: no `TWO_PLAYER_PATHS` path is touched (`src/shared/Grid/`,
`src/serverstorage/TerrainBake/`, `tests/server/grid_relief.spec.luau`, `tools/terrainbake.py`).

**READ `ESCALATE.md` 2026-11-06 ~04:15 FIRST.** Guard 2 passed; **guard 1 failed on C2** and I baked
on anyway, with the reason written there. That is the Director's to overrule; the rollback is
`<backups-dir>/FT-before-330.rbxl`, 32,015,979 bytes, taken before anything was written.

## What changed

`src/shared/Grid/Relief.luau`, `src/serverstorage/TerrainBake/init.luau`,
`tests/server/grid_relief.spec.luau`, `tools/terrainbake.py`, the `TASKS.md` row, `ESCALATE.md`.

## Claims, and how to verify each

1. **The bake MEASURES its own divergence; it does not quote the spec.** `Relief.anchorMeanAt` is
   the anchor walk factored out, so the cache's MISS path and the audit are the same code; every
   `auditEvery`-th reuse walks it again uncached and records the gap. `--audit-every` is refused
   without `--cache-anchors` (`tile_pass`). Specs `330-7` (an exact key reads 0 st; a known-wrong
   key reads the gap the plain off-vs-on comparison sees -- FAIL FIRST) and `330-8` (the stride is
   every Nth, 0 is off). `terrainbake.py selftest`: both flags reach the Luau as `bakeTileAt`'s
   last two arguments, and a tile reporting 0.9 st STOPS the run at that tile while 0.2 st does not.
2. **Guard 2 PASSED: worst anchor gap `0.194257 st`, worst stored height `0.135980 st`, over 3,092
   audited reuses on 121 of the 134 bench tiles** -- 0.77% of the run's 443,523 bench evaluations.
   On the `[bake]` line and in `.terrainbake/20261106T040802Z-*.json`. **It is a SAMPLE and this
   says so**: under the bend a bucket is reused by different grid x, so an exact audit IS the
   uncached run. 13 bench tiles have fewer than 128 reuses and so carry no audited column.
3. **The bake.** `[bake] OK: 1120/1120 tiles @ 3bce240c cells=B1,C1,D1,A2,B2,C2,D2
   epoch=58575af518ae6156 worstTileMs=9131 droppedLandform=2268/14 tiles anchorCache=ON
   worstAnchorDivergence=0.194257 st over 3092 audited reuse(s), tile 354, guard 0.25 (clean tree)`
   -- 19 minutes. Seven cells, not two: a row-2 region reaches 285 st into row 1, so B2 alone would
   have written the virgin base over B1/C1/D1's southern strip (328x's own warning).
   **ms a bench tile, cached: min 329, median 3,701, max 9,131** (134 tiles, 566.8 s in all)
   against **780,487-911,207 ms uncached** on the eight tiles the last session measured
   (`<runs-dir>/330-proof-8.txt`). Non-bench tiles: median 196 ms.
4. **Guard 1: A1, B1, C1, D1 and A2 are byte-identical; C2 is NOT.** Per-cell FOOTPRINT hashes of
   two live snapshots (`<runs-dir>/330b-cellhash.txt`, `330b-cells.py`). C2: **109 of 96,571
   columns (0.11%), every one in `x [-4434,-4430]` -- its western seam with B2 -- worst 1.7969 st**
   (`330b-where.py`). **The cache did not do it**: tile 341, which holds that worst column, has
   `anchorHits=0 anchorMisses=0` in the run log -- no bench anchor was walked in it at all -- and
   the one bench tile on that seam (141) audits at 0.039 st. `Relief.applyOps` reads the cache in
   the bench branch only, and `Relief.LANDFORMS.C2` has no bench op. The cause is that B2 now HAS a
   landform, so the limiter clamps across a seam whose neighbour moved 33 st.
5. **A transport change, and it is not a workaround.** A bench tile blocks the Edit DataModel past
   StudioMCP's dispatch patience -- tile 52 is `Target is not reachable` on every attempt, dry and
   wet, while tile 51 answers in 1.3 s. `TerrainBake.bakeTileAtPublished` writes the report to
   `DH330Tile_<run token>_<tile>` and `tile_call` polls it, which is the route the equality proof
   already used. The tile call does **not** retry (`call(..., retries=1)`): a retried tile is
   re-shaped, measured at 3 x 7.7 s for one 7.7-s tile. `selftest` drives all three arms of the
   retry -- one drop retried, a dead Studio given up on, any other error raised at once.
6. **B2 and D2 are planted and her place is coherent.** `[bake] plant OK: 7 cell(s) @ 0dd793c6
   PlantEpoch=58575af518ae6156 13096 models / 43581 parts`, every planted cell re-planted in one
   run from this branch. The boot's own verdict in a fresh Play: `[ForestTestBoot] prebuilt forest:
   STANDS, folder=true, 13096 model(s) in 7 cell folder(s), live=58575af518ae6156
   planted=58575af518ae6156`. **The epoch did NOT move** -- it hashes the base snapshot's sha and
   the base is unchanged -- so GridForest never went REFUSED. The dispatch expected it to move.
7. **Density.** C1 1,944 standing of 1,986 planned (42 cliff); **B2 1,280 of 1,340 (60 cliff),
   D2 1,009 of 1,202 (193 cliff)**. Same planter, same rule; the realised counts are lower because
   B2 carries a no-trunk scarp band and D2 is a broken hillside that rejects 193 sites as cliff.
   MEASURED, not "at C1's density": 1.27 / 0.84 / 0.66 models per 1,000 st2.
8. **Every stand in B2 and D2 has ground under it:** 15 of 15 in each, `0 with NO ground`
   (`<runs-dir>/330b-stands.luau`, a raycast onto Terrain in Play). Junctions, off the same
   profiles: `worst pin 0.0000 st, worst voxel step 2.4728 st` (EW1 x NS2), as in the 328x run.
9. **Frames, opened and described.** `330-F1` at B2 stand 4, eye 5.54 st above ground 191.91: tall
   pale birch trunks with dark crowns receding over rolling green ground, tall grass in front, the
   shotgun bottom-left, HUD `DRIVE 1 / 0 ANIMALS / HUNTER`. `330-F2` at D2 stand 4, eye 5.53 st
   above 255.97: birch trunks along a rising grassy bank with leaf-litter speckle and long tree
   shadows. **Both look INTO the cell**: the main line sits outside these cells' north edge, so the
   dispatch's "behind the line" aims away from the new wood -- the frame taken that way shows open
   grass and not one tree, and is kept as `330b-F2-screen.png`.
10. **Her place is as found apart from this task's stamps.** 18 attributes on ServerStorage before
    and after, `diff` empty -- 15 `DHFlag_*` identical name for name, no `DH330Tile_*` or
    `DH330Proof_*` left. On Terrain: `TerrainEpoch` plus exactly seven `TerrainShape_*`, the run's
    own cells. `SMOKE PASS`: gun in hand at +17 s and at 90 s, stacks=0, errorLines=0, waves=11.

## What I could not verify

- **`330-F0`, the BEFORE frame at the B2 spot: NOT OBTAINABLE.** I did not take it before the bake
  and the ground is now written; the only before state left is `FT-before-330.rbxl`. The numeric
  before and after from one instrument is claim 4 (B2: 90.54% of columns moved, worst 32.94 st).
- **The B2 bot climb FAILS the design's own floor, and no bot walked it.** `GRID_PREVIEW` builds
  C1 only, so no drive runs in B2. Off the baked ground, scanned in GRID coordinates through
  `Grid.toWorld` (`<runs-dir>/330b-climb2.luau`), the **steepest step between neighbouring samples
  on the three ramp lines is 29.09 / 49.62 / 56.03 deg (55.6 / 117.6 / 148.4 %)** against the
  ramps' designed 15%. Design 15 item 4 makes the ramps' 15% the floor and says that below it B2
  needs a different landform, "a Karen question and not a quiet edit" -- so I measured and changed
  nothing.
- **Frame time is inside the guard on mean and median and outside it on p95**, in a session with a
  live drive I did not isolate: C1 mean 28.924 / median 28.433 / p95 34.036 ms; B2 28.678 / 27.252
  / 40.627; D2 29.768 / 27.660 / 44.047. Mean -0.8% and +2.9% against the 15% guard; p95 +19.4%
  and +29.4%.
- **The gate's first run at `9a8493f7` returned 33/34**, the one failing check being the input
  replay's own transport (`UserMouseInputTool.SendUserInput ... Target is not reachable`); 2,840
  server and 676 client specs passed inside it. A second run at the SAME commit returned 34/34,
  and the code commit's line above is a third run at `3bce240c`.
- **A1 is VOID, not virgin ground, re-read LIVE at this commit** (`<runs-dir>/330b-a1.luau`, a
  direct `Terrain:ReadVoxels` over `x[-7500,-7336] z[-5086,-3656] y[-100,400]`): **0 of 14,883
  columns carry ground, 1,860,375 voxels read, not one solid voxel.** Not this task's scope.

ANSWERED: L-136 the one FAIL of this session is named above with its cause and its two re-runs; no
spec failed in any run. ANSWERED: L-127 every budget line is MET or NOT PROVEN with its own number;
nothing is a target restated as a result. ANSWERED: L-162 every live reading was taken at
`3bce240c` or at a paperwork commit above it, after the gate. ANSWERED: L-014 nothing was checked
out in driven-hunt-karen; the plant ran from this repo on this branch and her FT ends on :34873.
ANSWERED: L-086 both frames are from hunter eye height at a real stand, and the guard figures are
the worst of the whole run, not of a sampled tile. ANSWERED: L-101 the attribute diff is claim 10
and it is empty. ANSWERED: L-093 `clearProof` removes the run's own marks, and the audit counts
show the cache was reached on 121 tiles rather than silently absent. ANSWERED: L-170 the census
counters are named one by one in claims 6 and 7.
