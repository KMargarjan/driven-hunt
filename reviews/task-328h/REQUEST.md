# Task 328h - ROW 1 BAKED (B1, C1, D1). Round 3 reviews the two round-2 fixes and nothing else

Task: 328h
Round: 3
Base: `main` `62fd830e`
Code commit: `8e05ce48143aadad41596096813cb28c567c454c`

```
[harness] PASS: 34/34 checks @ 8e05ce48143aadad41596096813cb28c567c454c (clean tree) scope=all
```
`test2` N/A: no `TWO_PLAYER_PATHS` path is touched (Grid, Relief, TerrainBake, grid*.spec, terrainbake.py).
The last code commit is `6260e7dc`; only `reviews/task-328h/RESULT.md`, `ESCALATE.md` and this task's
`TASKS.md` row follow it (`git diff --name-only 8e05ce48..HEAD` = `ESCALATE.md`, `TASKS.md`).

## THE SCOPE OF THIS ROUND, and what it does NOT claim

The Director's `ESCALATE.md` entry of 2026-11-04 ~13:25 UTC authorised round 3 **within MAX_ROUNDS 3**
(no `DIRECTOR_MAX_ROUNDS`; the cap lifted was the dispatch's own two-round one) and decided the
five-cell blocker as **candidate 1, a NEW task `328x`**. So:

* **328h ships ROW 1 ONLY: B1, C1, D1.**
* **`A1`, `A2`, `B2`, `C2`, `D2` are NOT MET** and are moved to **328x**, not resolved here.
* **KAREN'S SENTENCE STAYS OPEN.** *"More trees behind the line"* (2026-11-04 ~09:20 UTC) names cell
  **`C2`** -- C1's main line is `EW2` at z -5107 and the hunters face +Z. `C2` did not bake, so
  `328h-F1-before.png` and `328h-F1-after.png` are deliberately the SAME frame. **Row 1 being done is
  not an answer to her; her named defect is open in 328x and nobody has seen it fixed.**

**MEASURED NOW: nothing new.** No terrain was written, no probe was run and **Karen's Forest Test was
not touched** in this round. Every number below was measured in her place at this code commit by the
earlier session; claims 3-10 are restated, not re-measured, and that is said here rather than
presented as fresh readings.

## Round 2's two findings, both correct, both fixed in `6260e7dc`

1. **The bench band's x window was clamped to the band's own rectangle, so the coverage test could
   not fail where it mattered.** `TerrainBake.benchBands` cut the band to `bounds +/- 136` and
   `bakeTileAt` then clamped its required window to that same rectangle, so `covered` was true by
   construction exactly where the band ran out. `TerrainBake.cellAt` answers *the nearest cell* and
   `Relief.blendAt` is non-zero `BLEND_STUDS` 200 past `Grid.worldBoundsOf`, so the bench walk runs
   for grid x hundreds of studs outside `Grid.boundsOf`, where `readOne` answers nil, `blurredAt`
   answers nil, and `applyOps` anchors the plane on the RAW base (or past `bounds.maxX + 76` drops
   the bench outright). **The window is now the TILE's, unclamped** (`bandMinX`/`bandMaxX` in
   `bakeTileAt`, `bench_slices_for` in `tools/terrainbake.py`), **every band of a run is cut for
   every tile with no relevance skip** -- a skip keyed on the band's own rectangle is the same
   unfalsifiable clamp in another place -- and `base_slice` refuses a rectangle that leaves the file.
   *Verify:* `grid_relief.spec` 328h-1 now picks its tile with `tile.minX + side > bounds.maxX`, the
   cell's EASTERN EXTREMITY, which round 1's `bounds.minX + 200 ... bounds.maxX - 200` pick excluded;
   case (b) still expects `"covering its anchor"` for a band 4,000 studs away; `terrainbake.py
   selftest` asserts **both** bands are cut (`len(_cut) == 2`, where the old case asserted the far one
   was dropped) and that each is cut over the tile's window. Restoring either clamp fails those.

2. **328h-2's precedence line could not fail.** `expect(withBand(x, z)).to.equal(plain(x, z))`
   compared at z -5557 while the band covers -5983..-5687, so both readers answered nil whatever the
   order. It now builds an **overlapping** slice at the compared point from the 500-stud-higher
   `bandHeight`, asserts the first slice wins (`both(x, z) == plain(x, z)`) **and** that the answer is
   NOT the band's. *Verify:* swap `readerFor`'s order, or try `extras` first, and the second
   assertion dies; the old line survived both.

## The row-1 claims (restated from the code commit's own measurements)

3. **BACKUP BEFORE ANY TERRAIN WRITE.** `<backups-dir>/FT-before-328h.rbxl`, 29,308,532 bytes, header
   `<roblox!`, sha256 `c714e613e95d81570ec3d4d0800c8295890681be1c4e64d7c28ef77120b55daa`, 09:31 UTC;
   the bake ran at 10:00 UTC.

4. **THE BAKE.** `<runs-dir>/328h-bake.txt`: `[bake] OK: 527/527 tiles @ 5a113240 cells=B1,C1,D1
   epoch=5e09ea024be987ee worstTileMs=376 (clean tree)`, 6 m 03 s, from 328k's virgin base
   `terrain-base-010b6400abdd.bin`. Karen's **15** overrides DECLARED with `--keep-flags`, never
   cleared (rule K). Row 1 was baked in ONE run on purpose: a cell baked alone writes the virgin base
   over its neighbour's finished strip.

5. **THE JUNCTIONS.** All **8**: pin **0.0000 st** each, worst voxel step **1.1257 st** inside its own
   explained 1.2556, **none `OVER`**. `NS2` is RELAXED and its breach is printed (cut-or-fill 25.3 st
   still over the 20-st cap at a 20 % grade).

6. **THE DITCH, at the realised column centres** (`<runs-dir>/328h-line.json`, probe
   `328h-line.luau`, her place): 15 stations, deepest cut **1.76-2.43 st** at d +/-24..26 against
   design 11.4's 2 +/- 1.0; all 15 centreline samples read material `Ground`.

7. **THE RE-SURVEY AND THE TOWERS.** `survey --cells B1,C1,D1`, 3,888 samples a cell: B1
   66.05/189.54/123.50/22.82/81.29, D1 101.83/166.26/64.43/36.27/135.85, **C1 reproduces 328r exactly**
   (89.14/150.26/61.12/20.49/106.03), all pinned in `Grid.CELLS` by a `grid.spec` case that also pins
   C1 unchanged and B2/C2 as still pre-bake. In a PLAY session (design 6.1): all **30** B1/D1 pads
   `spread 0.00`, `relief 0.01-0.12` against the 1.8 threshold, so `towersRelaxed` stays absent;
   towers B1 `{12}` -> `{8,10,12,14}`, D1 `{9,11}` -> `{9}` (11's gain +95 -> +40).

8. **C1 IS NOT BYTE-IDENTICAL, AND THE SIZE IS MEASURED.** Over `Grid.boundsOf("C1")`, 95,944 columns:
   **120 moved, worst 0.1562 st**, all on x -3368 and -3364 over z -4572..-4184, where D1's new ground
   feeds C1's limiter. 95,824 byte-identical. The dispatch asked for byte-identical; it is not.

9. **C1's PLAN MOVED 2448 -> 2429 AND THE WHOLE 19 IS THE SKIRT.** Two harness runs at the same code
   commit, one with `src/shared/Grid/init.luau` reverted to `main`: `C1 2448(t1861 f104 s483)` vs
   `C1 2429(t1861 f104 s464)` -- identical trees and ferns. `grid.spec` pins 2429 and notes both.
   Neither counting run is itself clean-tree evidence; the gate line above is.

10. **HER ATTRIBUTES: exactly 2 of 30 changed**, both this task's own stamps (`TerrainShape_B1`,
    `TerrainShape_D1`); `TerrainEpoch` and `TerrainShape_C1` unchanged, her 15 flags and three `DH*`
    attributes byte-identical (`328h-attrs-BEFORE.json` / `-AFTER.json`).

## What I could NOT verify, said plainly

* **Karen's `C2` defect is open** (above). Rule 5 is met for B1/D1 ground only: `328h-F2/F3`
  before/after at hunter eye height on NS2 and NS5, opened and described, with the 6.25-stud ground
  rise under F2 owned. F1 is the same frame twice, on purpose.
* **NO BENCH GROUND EXISTS ANYWHERE.** No bench cell baked, so the path both round-2 findings concern
  has never written a voxel. What is proved is the RULE (two refusals entered by cases, one
  end-to-end selftest that a real band reaches the tile call, a 355.998-stud height change through
  the reader) -- not the ground.
* **B2's three ramps have never been written to ground; the B2 bot climb stays UNMEASURED**
  (`grid-terrain.md` 12.2, 15 item 4). Both go to 328x / 328i.
* **THE BENCH PATH'S COST IS UNMEASURED.** Six `blurredAt` calls (1,369 base reads each) per band
  point: ~1.5e8 reads for ONE real D2 tile, and it overran the harness's 300 s cap twice. 328x's first
  measurement is ten tiles.
* **THE PER-CELL ANIMAL COUNT IN A NEW CELL IS NOT OBTAINABLE HERE.** `328h-sampler.luau` over 100 s:
  73 animals, 0 stuck > 3 s, `CELL B1 n=0` / `CELL D1 n=0`; the FT's drive runs in C1 only.
* **THE GREEN RUN WAS NOT THE FIRST.** At this code commit run 14 of 14 read 34/34; runs 10-13 failed
  on the disclosed intermittent family (`boar_behaviour`, `boar_body`, `deer_hitbox`, `weapon_shot`,
  `semiauto_client`, `gun_client`, `boar_wound`, `match_score`). A control at the merge base
  `62fd830e` with `Grid` reverted failed two of the same family (`<runs-dir>/328h-control.txt`:
  `boar_behaviour.spec`, `boar_shot.spec`). Two commits, two runs, both named; neither is called clean.
