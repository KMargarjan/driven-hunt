# Task 328h - the other seven cells: THREE of row 1 baked, FIVE blocked and escalated

Task: 328h
Round: 2
Base: `main` `62fd830e`
Code commit: `88f032537fb61625f95efa2758c372587693112d`

```
[harness] PASS: 34/34 checks @ 88f032537fb61625f95efa2758c372587693112d (clean tree) scope=all
```
`test2` N/A: no `TWO_PLAYER_PATHS` path is touched (Grid, Relief, TerrainBake, grid*.spec, terrainbake.py).

**The dispatch asked for seven cells. Three are baked (B1, C1, D1) and five are not**, for a measured
reason I could not design my way past without a design ruling: `ESCALATE.md`, 2026-11-04.

## Round 1's two findings, both correct, both fixed in `93958b06` / `88f03253`

**1. A hole in a bench band was never checked, so a bench over the void would have been shaped with
its bench silently missing.** Right, and the chain is exactly as the finding states: `decodeSlice`
carries the payload's holes, `readOne` answers nil at one, `blurredAt` answers nil the moment its
reader does, and `applyOps` then takes `smoothed or b` and `if n > 0` -- the column loses its bench
with no error and no report. **A band with any hole is now REFUSED, naming the count**, exactly as
the tile's own slice is. It is not hypothetical for the cells this unblocks: B2's band is `v0 = 0.00`,
the cell's north edge, which is where this world's terrain runs out.

**2. The x clip ignored the bend.** Right, and the arithmetic is the finding's. The anchor is read at
the tile column's GRID x but at the BAND's z, and `shapeTile` reads through `Grid.toWorld`, so the
world x of the anchor sample is displaced from the column's own by `bendX(zAnchor) - bendX(zTile)` --
up to `2 * nsStuds` = **120 studs** at 45/60, against the 204 the tile pad alone gave. `benchBands`
now carries **`xPad = 2 * Grid.maxBendStuds()`** and BOTH sides clip to the same rectangle
(`bench_slices_for` in the tool, `bandMinX`/`bandMaxX` in `bakeTileAt`). **Both findings are entered
by a case**: `grid_relief.spec` 328h-1 (b) hands a band cut only to the tile pad and expects the
refusal, and (d) hands a band with one hole and expects "no single height".

**Notes fixed in the same pass** (the quick ones; the rest are queued in `TASKS.md`): the union's
527 is now re-derived from `tile_count` rather than compared with itself; the union key is sorted, so
`--cells C1,B1,D1` meets the same pin; a new selftest case drives `tile_pass` with a REAL band and
asserts the third payload arrives non-empty and carries the band's own `minZ` (until it, no non-empty
band had ever travelled tool -> Luau in any run); `padFor`'s and `grid_relief` 328d-8's headers no
longer describe the retired refusal; `benchBands` asserts `op.v0`; 328h-2's band is built from a
height function 500 studs higher, so its "the point's own column comes from the FIRST slice" line
bites (the note now reads **355.998 st**, not 6.076); and `grid.spec`'s pad comment no longer implies
C1's fifteen pads were re-measured here.

## Claims, and how to verify each

1. **THE BACKUP, before any terrain write.** `<backups-dir>/FT-before-328h.rbxl`, **29,308,532
   bytes**, header `<roblox!`, sha256 `c714e613e95d81570ec3d4d0800c8295890681be1c4e64d7c28ef77120b55daa`,
   taken **09:31 UTC**; the first terrain write was the bake at 10:00 UTC.

2. **THE BAKE.** `<runs-dir>/328h-bake.txt`: `[bake] OK: 527/527 tiles @ 5a113240 cells=B1,C1,D1
   epoch=5e09ea024be987ee worstTileMs=376 (clean tree)` -- **6 m 03 s**. Ten tiles were measured
   first (`measure --tiles 10`, worst 243 ms). Read from 328k's virgin base
   `terrain-base-010b6400abdd.bin`, sha `010b6400abdd3e12...`, re-checked by the tool. Karen's **15**
   overrides DECLARED with `--keep-flags`, never cleared (rule K). **Row 1 is baked in ONE run on
   purpose**: a cell baked alone writes the VIRGIN base over the ~60-stud strip of its neighbour its
   grown region covers, which would have erased part of C1's finished ground.

3. **FIVE CELLS CANNOT BE BAKED, AND IT IS MEASURED.** `bakeTileAt` refuses a tile with a hole
   anywhere in its slice **plus the 204-stud read pad**. Over the 328k base: `B1` **0** refused of
   238, `D1` **0** of 238, `C1` **0** of 255, the shipped `B1,C1,D1` run **0 of 527**; `A1` 34,
   `A2` 46, `B2` 14, `C2` 15, `D2` 23 -- the seven together **103 of 1,120**, all eight **327 of
   1,408**. Every one is a REAL hole, not the file ending (`refused-for-file-edge-only 0`), and it is
   the PLACE: probed live (`<runs-dir>/328h-void.luau`, `placeId=130094961655666`)
   `(-7100,-6500)=NO GROUND`, `(-7200,-5000)=NO GROUND`, `(-7050,-4000)=NO GROUND`,
   `(-5000,-7100)=NO GROUND`, against `(-6700,-6600)=109.59 Grass` and `(-2210,-3614)=110.76
   Limestone`. The refusal is RIGHT as the code stands: `shapeTile` pins an unanswerable column at
   `snapshot.minY` and `limitGrid` drags the real ground beside it down. The fix is a design change
   to what an ABSENT column means to the limiter, and that is not mine to take.

4. **A SECOND BLOCKER WAS FIXED: a `bench` cell can be baked at all.** `bakeTileAt` refused **every**
   cell whose landform has a bench -- A1, B2, D2 -- because the anchor walk reads the base over the
   band's first `Relief.BENCH_ANCHOR_STUDS` at the same x. Since 328k the base is a sha-checked FILE,
   so `benchBands` names that rectangle and the tool cuts it from the same `.bin`; `readerFor` falls
   through to it. **No arithmetic moved; `BAKE_VERSION` stays 1.** `terrainbake.py selftest` gains
   **eleven** cases over two rounds.

5. **THE JUNCTIONS HOLD.** All **8** crossings: pin **0.0000 st** every one, worst voxel step
   **1.1257 st** inside its own explained 1.2556, **none `OVER`**. (The seven-cell dry run printed two
   `OVER` -- `EW1 x NS2` 2.4728/2.4419 and `EW3 x NS1` 0.7158/0.6846 -- both on roads of the five that
   did not bake. Named, not hidden.) `NS2` is RELAXED and its breach is printed: cut-or-fill 25.3 st
   still over the 20-st cap at a 20 % grade.

6. **THE DITCH, AT THE REALISED COLUMN CENTRES** (`<runs-dir>/328h-line.json`, probe
   `328h-line.luau`, in her place): 15 stations, five a cell. Deepest cut **1.76-2.43 studs** at
   d +-24..26 against design 11.4's 2 +- 1.0; **all 15 centreline samples read material `Ground`**.

7. **THE RE-SURVEY** (`survey --cells B1,C1,D1`, 3,888 samples a cell; `lineSpread` off 54 samples
   along the realised line): B1 **66.05 / 189.54 / 123.50 / 22.82 / 81.29**, D1 **101.83 / 166.26 /
   64.43 / 36.27 / 135.85**, and **C1 reproduces 328r exactly** (89.14 / 150.26 / 61.12 / 20.49 /
   106.03). All in `Grid.CELLS`, pinned by a new `grid.spec` case that also pins C1 UNCHANGED and
   B2's and C2's rows as still PRE-bake. `character` keeps 327c's word: it is a label nothing reads
   to decide anything.

8. **THE PADS AND THE TOWERS, IN A PLAY SESSION** (design 6.1 -- an Edit run reads
   `DrivePlaces=ABSENT`; mine reads `DrivePlaces=3 GridPlaces=1 ForestMarkers=16 HighSeats=3`).
   **All 30 of B1's and D1's pads read `spread 0.00`, `relief 0.01-0.12`** against the 1.8 threshold,
   so `towersRelaxed` stays absent. Towers: B1 `{12}` -> **`{8, 10, 12, 14}`**, D1 `{9, 11}` ->
   **`{9}`** (D1's 11 fell out, gain +95 -> **+40**). No MAIN stand of either clears +60.

9. **C1 IS NOT BYTE-IDENTICAL, AND THE SIZE IS MEASURED.** Over C1's own interior
   (`Grid.boundsOf`, 95,944 columns, `328h-c1-before.bin` vs `-after.bin`): **120 moved, worst
   0.1562 st**, all on its two easternmost column lines (x -3368, -3364) over z -4572..-4184, where
   D1's new ground now feeds C1's limiter. **95,824 columns byte-identical.** The dispatch asked for
   byte-identical; it is not, and this is the measurement, not a dismissal.

10. **C1's PLAN MOVED 2448 -> 2429 AND THE WHOLE 19 IS THE SKIRT.** Two harness runs at the same code
    commit, one with `src/shared/Grid/init.luau` reverted to `main`, print `C1 2448(t1861 f104 s483)`
    and `C1 2429(t1861 f104 s464)`: **identical trees and ferns**. A cell's plan carries a skirt into
    its neighbours, masked against THEIR stands, and a tower stand carries a wider exclusion -- B1
    gained three towers. `grid.spec` pins 2429 and NOTES both counts before either is asserted.
    Neither counting run is itself clean-tree evidence; the gate line above is.

11. **HER ATTRIBUTES: exactly 2 of 30 changed**, both this task's own stamps (`TerrainShape_B1`,
    `TerrainShape_D1`). `TerrainEpoch` and `TerrainShape_C1` unchanged; her 15 flags and three `DH*`
    attributes byte-identical (`328h-attrs-BEFORE.json` / `-AFTER.json`).

## What I could NOT verify, said plainly

* **KAREN'S SENTENCE IS NOT ANSWERED.** C1's main line is `EW2` at z -5107 and the hunters face +Z,
  so **"behind the line" is cell `C2`** -- one of the five. F1-before and F1-after are deliberately
  the same view, and that is the evidence.
* **NO BENCH GROUND EXISTS ANYWHERE.** No bench cell baked, so the band path has never written a
  voxel. What is proved is the RULE (two refusals entered by cases, one end-to-end selftest that a
  real band reaches the tile call, and a 355.998-stud height change through the reader), not the
  ground.
* **B2's THREE RAMPS HAVE NEVER BEEN WRITTEN TO GROUND and the B2 BOT CLIMB STAYS UNMEASURED**
  (`grid-terrain.md` 12.2, 15 item 4).
* **THE BENCH PATH IS EXPENSIVE AND NOBODY HAS PAID IT.** The anchor walk is six `blurredAt` calls
  (1,369 base reads each) for every point in the band -- shaping ONE real D2 tile is ~1.5e8 reads and
  overran the harness's 300 s cap twice before I moved the case to a single point. The three bench
  cells' real bake cost is unmeasured and could be far above this run's 376 ms a tile.
* **THE PER-CELL ANIMAL COUNT IN A NEW CELL IS NOT OBTAINABLE HERE.** `328h-sampler.luau` (328n's,
  with a per-cell split added) over 100 s: 73 animals, **0 stuck > 3 s**, crossings 20 attempted / 17
  completed, and **`CELL B1 n=0` / `CELL D1 n=0`** -- no animal spent its drive in either; 17 were in
  C1 and 56 outside the three. The FT's drive runs in C1 only. The `noProgress >= 6 s` figure is
  phase-dependent and is NOT a bake discriminator: three runs in one session read **1 of 37**,
  **20 of 58**, **40 of 73** as the drive filled, and the worst point (-4101,-5374) is on the road.
* **THE FLAKES.** At this code commit, runs 10-13 failed on the disclosed family and run 14 passed:
  10 `boar_behaviour.spec:1553`; 11 `boar_body.spec:743`, `deer_hitbox.spec:682`,
  `weapon_shot.spec:1890`, `semiauto_client.spec:93`; 12 `weapon_shot.spec:1890`,
  `gun_client.spec:833`; 13 `boar_wound.spec:365`, `match_score.spec:331`, `weapon_shot.spec:1890`,
  `semiauto_client.spec:93` x2; **14 = 34/34**. A control at the merge base with `Grid` reverted is
  `328h-control.txt` (`boar_behaviour.spec:1553`, `boar_shot.spec:2582`). Two earlier runs died on
  `Boar.Brain:838` while the server waited for a client that never bound -- a stray DEV Play
  datamodel left by my own probe, cleared with `studio_mcp.py stop`.

## Frames (rule 5) -- six, in Play, in her place, at hunter eye height, opened and described

`<runs-dir>/328h-F{1,2,3}-{before,after}.png`, cropped to the viewport, all six shas distinct. The
camera is the character's own eye, ~3.5 studs above the local ground in every one; the ground under
F2 ROSE 6.25 studs in the bake (114.38 -> 120.63), so the after camera is 6.2 studs higher -- the
same eye height over different ground, said rather than hidden. The body is a Driver, not a Hunter:
`ForestTest.boundary` clamps a hunter to 12 studs of his dealt stand (328r's finding) and F2 and F3
are 1,300 and 1,600 studs away.

* **F1, from C1 main stand 4 looking SOUTH, behind the line.** Before: a gravel carriageway with its
  yellow line in the foreground, then open grass with thin scattered birch and spruce and a low hill
  on the horizon. After: **the same view** -- same trees, same ground. That is C2, and C2 did not
  bake. This is the picture Karen asked about and it has not changed.
* **F2, on B1's west flank road (NS2) at z -4400, looking south along it.** Before: an unbroken grass
  hillside with **no road at all**. After: a cut carriageway with two pale rutted wheelings running
  away to the horizon, grass verges either side, the ground falling away south.
* **F3, on D1's east flank road (NS5) at z -4400, looking south along it.** Before: plain grass
  slope. After: the same cut track with its ruts and verges. **This is a SUBSTITUTE for the B2 ramp
  frame the dispatch asked for**, because B2 did not bake; said here rather than swapped in quietly.
