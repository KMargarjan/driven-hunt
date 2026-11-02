# Task 328e -- C1's stand pads, then paint v2

Task: 328e
Round: 2
Base: `64394f87` (main, with 328d + 328j #316 merged; C1 already baked in Karen's Forest Test)
Code commit: `c7d97625f7e5e84e6fc561e0654f0c4106f30f38`

```
[harness] PASS: 34/34 checks @ c7d97625f7e5e84e6fc561e0654f0c4106f30f38 (clean tree) scope=all
```

`test2` is **N/A**: no path under `TWO_PLAYER_PATHS` is touched (terrain, the bake, `Places.Ground`,
`grid.spec`, `grid_relief.spec`, `terrainbake.py`, `studio_mcp.py` comments). 2749 server + 676
client assertions, 0 failures, 0 errors; no flake fired in any of the four full runs.

## Round 1's two findings, both correct

**Finding 1 -- a never-baked cell read `reshape=false`.** It is fixed and the fix is the Reviewer's:
`TerrainEpoch` is ONE attribute on the Terrain while a bake covers only its own `--cells`, so it
cannot answer a per-cell question. The epoch arm is gone; only `TerrainShape_<id>` is evidence about
a cell. `reshapeWanted` returns the reason as a WORD, and `terrainbake.py` gains **refusal 7b**: a
wet run on a cell whose stamp names a DIFFERENT landform is refused outright, because a bake ADDS
the new ops to the old. Case 328e-6 now stamps C1, leaves A1 unstamped, sets the global epoch and
asserts the two answer **differently** -- the round-1 case asserted the arm that froze the defect --
then walks all eight cells on a bare marker and requires every one to read `virgin`.

**Finding 2 -- the frames.** All twelve are described below, by name, with their camera height.

## What changed

1. **The stand pads** (design 7.4): `TerrainBake.STAND_PAD` + `standPadsFor` + `standPadAt`, applied
   in `shapeTile` after the road, exempt from the limiter inside the core.
2. **The paint**: `ROAD.midStuds` 6 (design 7.1's table row), and `Relief.LANDFORMS.C1.floor.default`
   from the placeholder `Ground` to `LeafyGrass`.
3. **The archive** (design 16, rule 7): `Ground.paintRoads` and `grid.spec` case 19, same commit.
4. **`TerrainBake.reshapeWanted`**: the landform goes into the ground once, asked per cell.
5. **`parse_json` reads a bare scalar**, and its fallback prefers a container.

## Claims, and how to verify each

1. **The pads are level, in her ground, at the code commit.** Worst relief over 327b's own 12-stud
   ring, fifteen stands of C1: **2.398 -> 0.0897 studs**, **0 of 15** over `JUMP_RELIEF_STUDS` 1.8
   (was 1, stand 10 at 2.398). `HighSeats` footprint spread **0.000 on all fifteen** (was
   0.026-0.687), and the boot's own line went `[seats] C1: ... worst spread 0.23` -> **`0.00`**.
   Verify: `<runs-dir>/328e-ground-BEFORE.json` vs `-AFTER2.json`, key `standsWorst` and the `stands`
   rows; the two boot lines in `328e-bake*.txt`'s session consoles.
2. **The pad's height is the road's crown, NOT `Grid.standPosition`'s Y, and that is arithmetic.**
   `lineMeanY` is ONE number for fifteen stands (106.98) and C1's west flank road rises 35.4 studs
   between stands 8 and 11 (ground 93.41 and 128.82, measured). Levelling both to it is a
   21.84-stud pit beside a 13.57-stud mound; a 21.84-stud wall at `LIMIT_DEG.tree` 20 needs 60 studs
   of ring, so a 134-stud crater at stands 220 studs apart. **The dispatch's float/bury numbers are
   therefore NOT closed by a pad, and are reported, not claimed.** Verify: `standPadsFor`'s header;
   `Grid.standPosition`'s `local y = cell.relief.lineMeanY`.
3. **Nothing in the world stands at that Y.** `Markers.build` places each post at
   `Markers.groundFor(stand.X, stand.Z, ...)`; `HighSeats.plan` reads `grounds` and never `stand.Y`.
   Verify: read both functions.
4. **Every arm of the pad is entered by a case** (L-093): 328e-2 drives the level core (96 points,
   worst 0.0000 off the pad height), the blend (monotone, weight strictly in (0,1), both joins
   continuous), out of reach (nil, weight 0), and **no road under the stand** (all fifteen reported
   missed rather than given an invented height). 328e-3 writes a pad into a tile on a 10 % slope and
   **fails first** with `standPadsFor` stubbed out.
5. **The cross-section is design 7.1's, measured on the ground.** EW3 at x=-4164, after:
   `LeafyGrass | Grass[-34..-27] | Mud[-26..-24] | Grass[-23..-11] | Mud[-10..-7] | Ground[-6..+4] |
   Mud[+5..+9] | Grass[+10..+21] | Mud[+22..+24] | Grass[+25..+37] | LeafyGrass`, the ditch **1.98
   studs** below the crown (design asks 2). Before, the same line read `Ground[+10..+13]
   Grass[+14..+21]`. Verify: `<runs-dir>/328e-xsec-BEFORE.json` vs `-AFTER.json`; case 328e-4.
6. **The ruts were ALREADY at +-8 and still are -- 328d's work, not mine.** 8 is the nominal band's
   midpoint; the REALISED column is d 3..7 on this parity and does not contain 8, while the MEASURED
   Mud on the ground does (|d| 5..9 on EW2). Case 328e-4 asserts both halves separately so neither
   can be read as the other.
7. **The floor: `Ground` 100 % -> `LeafyGrass` 100 %** over 5,504 lattice samples of C1 -- the "bare
   brown from every stand". **Slope rock is N/A for C1, measured not skipped**: C1's landform carries
   no scree rule, and `LIMIT_DEG.tree` caps the cell at 20 degrees while the design's only scree band
   (B2's) starts at 30, so such a rule could not fire. Verify: `materials.zones.cellFloor`; 328e-5.
8. **A second ridge was measured and refused BEFORE the write.** 90 points of C1: mean **+3.67
   studs**, 27 rising, **0 falling**, worst **+24.04** on the ridge line -- `C1.ops[1].dyStuds` is 24.
   The live runs printed `reshape=false`/`stamped`, and over THREE full bakes `survey`'s meanY moved
   115.655 -> **116.43** (+0.78 in all), against +3.67 **per bake** for the old path. Verify:
   `<runs-dir>/328e-drift-BEFORE.json`, `328e-bake3.txt`, `ESCALATE.md` 2026-11-02 ~20:35; 328e-6.
9. **The archive is complete and the lane paint is untouched.** `paintRoads`, `roadChunks`,
   `roadYBand`, `roadBand`, the three constants, the call site, `report.gridPaints`, the boot clause
   and `grid.spec` case 19 -- one commit, with
   `backups/2026-11-02_task-328e_Ground-paintRoads-and-grid-case-19.md` carrying the code and the
   rollback. `Ground.band`, `bandBounds`, `SOURCE_MATERIALS`, `Y_PAD_STUDS` stay. Verify: 328e-5;
   `grep -rn paintRoads src tests`.
10. **Live in her place, at the code commit.** `[bake] OK: 208/208 tiles @ c7d97625 cells=C1
    epoch=6e4b9087ce9f24ba worstTileMs=110 (clean tree)`. GridCensus C1: **floating 0, sunk 0,
    tilted 0, broken 0, noGround 0, inRoad 0, inStand 0, onCliff 0** over 1,999 trees. Boot:
    `15 of 15 post(s), 3 tower(s) at {8,13,15}, complete=true`. Attribute diff before/after: **two
    changes, both this task's own stamps**; Karen's 15 flag overrides byte-identical.

## The frames -- what each one shows (rule 5, rule F; all at a hunter's eye height)

Six camera points, held by `<runs-dir>/328e-cam.luau` against the game's own camera owner, in a PLAY
session so the wood and the stands are there. `BEFORE` is the ground as 328j left it; `FINAL` is
this code commit. I opened all twelve.

- **F1, stand 5 on the main line, eye 5 studs (`328e-BEFORE-F1.png` / `328e-FINAL-F1.png`).**
  BEFORE: a grey-brown gravelly road fills the bottom third, a bright green grass band behind it,
  and then **a wide bare-brown plain running back to the treeline** with birch and spruce standing
  on it. FINAL: the brown plain is **gone** -- the floor under the trees is green leaf litter all
  the way to the treeline, and the near field is green rather than gravel.
- **F2, stand 10 on the west flank, eye 5, looking east (`-BEFORE-F2` / `-FINAL-F2`).** BEFORE: a
  dark **brown bank** rises across the middle of the frame under the birches, with a green grass
  strip in front of it. FINAL: the same bank is **green**, with the tree shadows readable on it.
- **F3, stand 11 -- the worst buried stand -- eye 5, looking east (`-BEFORE-F3` / `-FINAL-F3`).**
  BEFORE: tall green grass in the foreground, then **flat bare brown** under the wood and out to a
  distant rock ridge. FINAL: green litter under the wood and green rolling ground to the same ridge.
- **F4, from tower stand 13's deck, eye 17.5 (`-BEFORE-F4` / `-FINAL-F4`).** BEFORE: looking down on
  **a brown field** with trees dotted over it. FINAL: the same view, green, with the ground's rolls
  now legible as light and shade instead of flat brown.
- **F5, NS3 at a truck driver's eye, 7 studs, looking north (`-BEFORE-F5` / `-FINAL-F5`).** Both
  show the road running away between spruce with green verges **and a high seat standing in the
  middle of the carriageway** (stand 8 is on the road centreline -- `Grid.standPosition`'s geometry,
  not this task's, and Karen should be told). BEFORE the hillsides beyond the verge are brown;
  FINAL they are green, and the tower's four legs stand on a visibly level landing.
- **F6, stand 5 looking EAST along the main road itself, eye 5 (`-BEFORE-F6` / `-FINAL-F6`).** Both
  show a brown carriageway between green verges with the two orange corner stakes at the far end.
  The road strip is brown in BOTH because `Ground.paintRoads` **still runs in her copy** (see below);
  what changed is the wood either side, brown before and green after.

## What I could not verify, and what is wrong but not mine to fix tonight

- **`towersRelaxed` "flipping to false" proves nothing here.** `Grid.CELLS` C1 carries no
  `towersRelaxed` field, so it has read `false` since 327b, before this task. The pads make the claim
  true for the right reason (every tower's ring now rolls <= 0.09 studs), but the flip is not
  evidence of anything I did. A re-survey that WRITES `towers`/`towersRelaxed` is 328h's.
- **THE ROAD HALF OF THE BAKE IS STILL NOT IDEMPOTENT, and I measured it on my own three runs.**
  `profilesFor` reads the long profile off LIVE ground, which after a bake already contains the road,
  so the cut-or-fill clamp lets the crown creep. `survey`'s `lineMeanY` went 108.88 -> 112.83 (two
  bakes) -> **114.81** (a third), about **+2 studs a bake**, and the stands moved up to **3.42 studs**
  between the last two. Bounded per run, but it accumulates: **C1's main line is ~6 studs higher than
  when I started, and three of those are mine.** Same root cause as the landform one: nothing stores
  the original base. Queued in `TASKS.md` 328e (b) and in `ESCALATE.md`; **C1 should not be re-baked
  again until the base snapshot of design 5.3 step 2 exists.**
- **A half-voxel registration offset in `bakeTile`, pre-existing (328d's).** Over 828 road samples on
  four roads the ground disagrees with `roadAt`'s own answer at **186 (22.5 %)**, and **183 of those
  186 are explained by an outward shift of <= 3 studs**; the ditch realises as one column where
  `roadAt` answers two. `shapeTile` samples column centres at `tile.minX + (i-0.5)*v` while
  `Region3:ExpandToGrid(4)` puts the written voxel's centre elsewhere. Queued, `TASKS.md` 328e (a).
- **`Ground.paintRoads` still runs in Karen's copy**, which syncs `main`: measured in her Play
  session it erases both Mud ruts and widens the `Ground` strip from |d| 6 to |d| 14
  (`Ground[-14..+8]` where the bake wrote `Mud[-10..-7] Ground[-6..+4] Mud[+5..+8]`). The floor and
  the pads survive it. Needs the merge plus a `driven-hunt-karen` refresh -- `ESCALATE.md`.
- **`StreamingMinRadius` 64 -> 384 is still NEEDS KAREN.** Not readable from `execute_luau` ("not a
  valid member of Workspace"), let alone settable.
