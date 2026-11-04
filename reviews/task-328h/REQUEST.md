# Task 328h - the other seven cells: THREE of row 1 baked, FIVE blocked and escalated

Task: 328h
Round: 1
Base: `main` `62fd830e`
Code commit: `6ae3c4857a1d77dd66bed026c0a04b93b7607883`

```
[harness] PASS: 34/34 checks @ 6ae3c4857a1d77dd66bed026c0a04b93b7607883 (clean tree) scope=all
```
`test2` N/A: no `TWO_PLAYER_PATHS` path is touched (Grid, Relief, TerrainBake, grid*.spec, terrainbake.py).

**The dispatch asked for seven cells. Three are baked (B1, C1, D1) and five are not, for a measured
reason I could not design my way past without a design ruling.** `ESCALATE.md`, 2026-11-04, carries
it. What follows is what shipped and how to check each claim.

## Claims, and how to verify each

1. **THE BACKUP, before any terrain write.** `<backups-dir>/FT-before-328h.rbxl`, **29,308,532
   bytes**, header `<roblox!`, sha256 `c714e613e95d81570ec3d4d0800c8295890681be1c4e64d7c28ef77120b55daa`,
   taken **09:31 UTC**. The first terrain write was the bake at 10:00 UTC.

2. **THE BAKE.** `<runs-dir>/328h-bake.txt`:
   `[bake] OK: 527/527 tiles @ 5a11324064b954e4a5c779479cc7f43fc3ccc04d cells=B1,C1,D1
   epoch=5e09ea024be987ee worstTileMs=376 (clean tree)` -- **6 m 03 s** wall. Ten tiles were measured
   first (`measure --tiles 10`, worst 243 ms); the estimate from them was ~4 min against a real
   6 min. Read from 328k's virgin base `terrain-base-010b6400abdd.bin`, sha `010b6400abdd3e12...`,
   which the tool re-checked. Karen's **15** flag overrides were DECLARED with `--keep-flags`, never
   cleared (rule K).
   **ROW 1 IS BAKED IN ONE RUN ON PURPOSE:** a cell baked alone writes the VIRGIN base over the
   ~60-stud strip of its neighbour that its grown region covers, which would have erased part of
   C1's finished ground. `EXPECTED_TILES` now pins `"B1,C1,D1": 527`.

3. **FIVE CELLS CANNOT BE BAKED, AND IT IS MEASURED.** `bakeTileAt` refuses a tile with a hole
   anywhere in its slice **plus the 204-stud read pad** (the blur reads 72 studs out, the limiter
   128). Over the 328k base: `B1` 0 refused of 238, `D1` 0 of 238, `C1` 0 of 255, **the shipped
   `B1,C1,D1` run 0 of 527**; `A1` 34, `A2` 46, `B2` 14, `C2` 15, `D2` 23; the seven together
   **103 of 1,120**, all eight **327 of 1,408**. Every one is a REAL hole, not the file ending
   (the same count with out-of-file columns separated reads `refused-for-file-edge-only 0`), and
   it is the PLACE, not the snapshot: probed live at the code commit (`<runs-dir>/328h-void.luau`,
   `placeId=130094961655666`) `(-7100,-6500)=NO GROUND`, `(-7200,-5000)=NO GROUND`,
   `(-7050,-4000)=NO GROUND`, `(-5000,-7100)=NO GROUND`, against `(-6700,-6600)=109.59 Grass` and
   `(-2210,-3614)=110.76 Limestone`. **Her Forest Test has no terrain under the grid's north and
   west border pad.** The refusal is RIGHT as the code stands -- `shapeTile` pins an unanswerable
   column at `snapshot.minY` and `limitGrid` then drags the real ground beside it down -- so the fix
   is a design change to what an ABSENT column means to the limiter, and that is not mine to take.

4. **A SECOND, UNRELATED BLOCKER WAS FIXED: a `bench` cell can now be baked at all.** `bakeTileAt`
   refused **every** cell whose landform has a `bench` -- A1, B2, D2 -- because `applyOps` anchors a
   bench plane on the base over the band's first `Relief.BENCH_ANCHOR_STUDS` at the same x, which for
   a tile deep in the band is a cell away in z. Since 328k the base is a sha-checked FILE, so
   `TerrainBake.benchBands` names that rectangle and the tool cuts it from the same `.bin` as a
   second slice; `readerFor` falls through to it. **No arithmetic moved and `BAKE_VERSION` stays 1.**
   `grid_relief.spec` 328h-1 proves the refusal still fires without a band and with a band that does
   not reach the tile, and that a covering band gets the tile past it; 328h-2 proves the
   fall-through BITES -- D2's bench moves one point **6.076 studs** (16.600 -> 22.676), noted by the
   spec itself. `terrainbake.py selftest` gains six cases, including that the old blanket refusal
   text is gone.

5. **THE JUNCTIONS HOLD.** All **8** crossings of this run: pin **0.0000 st** every one, worst voxel
   step **1.1257 st** inside its own explained 1.2556, and **none is `OVER`**. (The seven-cell dry
   run printed two `OVER` crossings -- `EW1 x NS2` 2.4728 against 2.4419 and `EW3 x NS1` 0.7158
   against 0.6846 -- both on roads of the five cells that did not bake. Named, not hidden.)
   `NS2` is RELAXED and the breach is printed: cut-or-fill 25.3 st still over the 20-st cap at a
   20 % grade.

6. **THE DITCH, AT THE REALISED COLUMN CENTRES** (`<runs-dir>/328h-line.json`, probe
   `328h-line.luau`, run in her place): 15 stations, five a cell. Deepest cut **1.76-2.43 studs** at
   d +-24..26 against design 11.4's 2 +- 1.0; **every one of the 15 centreline samples reads
   material `Ground`**.

7. **THE RE-SURVEY** (`terrainbake.py survey --cells B1,C1,D1`, 3,888 samples a cell; `lineSpread`
   off 54 samples along the realised line):
   B1 **66.05 / 189.54 / 123.50 / 22.82 / 81.29**, D1 **101.83 / 166.26 / 64.43 / 36.27 / 135.85**,
   and **C1 reproduces 328r exactly** -- 89.14 / 150.26 / 61.12 / 20.49 / 106.03. All written into
   `Grid.CELLS`. `character` is kept at 327c's own word for both: it is a LABEL that nothing reads to
   decide anything, and `grid.spec` accepts five words of which the survey classifier emits three.

8. **THE PADS AND THE TOWERS, MEASURED IN A PLAY SESSION** (design 6.1 -- an Edit run reads
   `DrivePlaces=ABSENT`; mine reads `DrivePlaces=3 GridPlaces=1 ForestMarkers=16 HighSeats=3`).
   `<runs-dir>/328h-towers.luau`, 327b's instrument with B1's and D1's stand positions read out of
   `Grid.standPosition`. **All 30 pads read `spread 0.00` and `relief 0.01-0.12`** against the 1.8
   threshold, so `towersRelaxed` stays absent for both. Towers by 327b's rule (rank by gain, never
   two adjacent, `gain >= 60`): B1 `{12}` -> **`{8, 10, 12, 14}`**, D1 `{9, 11}` -> **`{9}`** --
   D1's 11 fell out, its gain +95 -> **+40**. No MAIN stand of either cell clears +60.

9. **C1 IS NOT BYTE-IDENTICAL, AND THE SIZE IS MEASURED.** `snapshot --cells C1` before
   (`328h-c1-before.bin`, sha `4d17647d8921500f...`) and after (`328h-c1-after.bin`, sha
   `f4f2ac9c4ee3604a...`) -- the shas differ, and most of that is the parts of C1's GROWN region that
   lie in B1 and D1. Over **C1's own interior** (`Grid.boundsOf`, 95,944 columns): **120 moved,
   worst 0.1562 st**, and all 120 sit on its two easternmost column lines, x -3368 and -3364, over
   z -4572..-4184 -- where D1's new ground now feeds C1's limiter. **95,824 columns byte-identical.**
   The dispatch asked for byte-identical; it is not, and this is the measurement, not a dismissal.

10. **C1's PLAN MOVED 2448 -> 2429 AND THE WHOLE 19 IS THE SKIRT.** Two harness runs at the same
    code commit, one with `src/shared/Grid/init.luau` reverted to `main`, print the per-cell note
    `C1 2448(t1861 f104 s483)` and `C1 2429(t1861 f104 s464)`: **identical trees and ferns.** A
    cell plan carries a skirt into its neighbours, the skirt is masked against THEIR stands, and a
    tower stand carries a wider exclusion -- B1 gained three towers. `grid.spec` pins 2429 and notes
    both counts BEFORE either is asserted. C1's own trees are untouched at 1,861.

11. **HER ATTRIBUTES: exactly 2 of 30 changed**, both this task's own stamps (`TerrainShape_B1`,
    `TerrainShape_D1`). `TerrainEpoch` and `TerrainShape_C1` unchanged; Karen's 15 flags and her
    three `DH*` test attributes byte-identical (`328h-attrs-BEFORE.json` / `-AFTER.json`).

## What I could NOT verify, said plainly

* **KAREN'S SENTENCE IS NOT ANSWERED.** C1's main line is `EW2` at z -5107 and the hunters face +Z,
  so **"behind the line" is cell `C2`** -- one of the five that could not be baked. `328h-F1-before`
  and `328h-F1-after` are deliberately the same view, and that is the evidence.
* **B2's THREE RAMPS HAVE NEVER BEEN WRITTEN TO GROUND and the B2 BOT CLIMB STAYS UNMEASURED**
  (`grid-terrain.md` 12.2, 15 item 4). The ramps are in `Relief.LANDFORMS`; B2 did not bake.
* **THE PER-CELL ANIMAL COUNT IN A NEW CELL IS NOT OBTAINABLE HERE.** The sampler
  (`328h-sampler.luau`, 328n's with a per-cell split added) over 100 s: 73 animals, **0 stuck > 3 s**,
  crossings 20 attempted / 17 completed, and **`CELL B1 n=0` / `CELL D1 n=0` -- no animal spent its
  drive in either**; 17 were in C1 and 56 outside the three. The FT drive runs in C1 only.
  The `noProgress >= 6 s` figure is phase-dependent and is NOT a bake discriminator: three runs of
  the same instrument in one session read **1 of 37**, **20 of 58** and **40 of 73** as the drive
  filled, and the worst point (-4101,-5374) is on the road, not on the new ground.
* **THE BENCH PATH IS EXPENSIVE AND NOBODY HAS PAID IT.** The anchor walk is six `blurredAt` calls
  (1,369 base reads each) for every point in the band, so shaping ONE real D2 tile is ~1.5e8 reads --
  it overran the harness 300 s cap twice before I moved the spec to a single point. The three
  bench cells' real bake cost is unmeasured and could be far above the 376 ms of this run.
* **THE FLAKES.** Runs 6 and 7 at this code commit failed on the disclosed family and run 8 passed:
  run 6 `weapon_shot.spec:1490/:1890/:2077`, `semiauto_client.spec:93`, `weapon_client.spec:1773`;
  run 7 `boar_sounder.spec:440`, `camera_client.spec:375`, `weapon_client.spec:1211`; run 8
  **34/34**. A control at the merge base is in `328h-control.txt` (`boar_behaviour.spec:1553`,
  `boar_shot.spec:2582`). Two earlier runs died on `Boar.Brain:838` while the server waited for a
  client that never bound -- that was a stray DEV Play datamodel left by my own probe, cleared with
  `studio_mcp.py stop`.

## Frames (rule 5) -- six, in Play, in her place, at hunter eye height, opened and described

`<runs-dir>/328h-F{1,2,3}-{before,after}.png`, cropped to the viewport, all six shas distinct. The
camera is the character's own eye, ~3.5 studs above the local ground in every one; the ground under
F2 ROSE 6.25 studs in the bake (114.38 -> 120.63) so the after camera is 6.2 studs higher, which is
the same eye height over different ground and is said rather than hidden. The body is a Driver, not
a Hunter: `ForestTest.boundary` clamps a hunter to 12 studs of his dealt stand (328r's finding) and
F2 and F3 are 1,300 and 1,600 studs away.

* **F1, from C1 main stand 4 looking SOUTH, behind the line.** Before: a gravel carriageway with its
  yellow line in the foreground, then open grass with thin scattered birch and spruce and a low hill
  on the horizon. After: **the same view** -- same trees, same ground. That is C2, and C2 did not
  bake. This is the picture Karen asked about and it has not changed.
* **F2, on B1's west flank road (NS2) at z -4400, looking south along it.** Before: an unbroken
  grass hillside with **no road at all**. After: a cut carriageway with two pale rutted wheelings
  running away to the horizon, grass verges either side, the ground falling away south.
* **F3, on D1's east flank road (NS5) at z -4400, looking south along it.** Before: plain grass
  slope. After: the same cut track with its ruts and verges. **This is a SUBSTITUTE for the B2 ramp
  frame the dispatch asked for**, because B2 did not bake; said here rather than swapped in quietly.
