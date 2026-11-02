# Task 328e -- C1's stand pads, then paint v2

Task: 328e
Round: 1
Base: `64394f87` (main, with 328d + 328j #316 merged; C1 already baked in Karen's Forest Test)
Code commit: `9946c7da26eff06fd3652ed7c62cf0b934ea89ba`

```
[harness] PASS: 34/34 checks @ 9946c7da26eff06fd3652ed7c62cf0b934ea89ba (clean tree) scope=all
```

`test2` is **N/A**: no path under `TWO_PLAYER_PATHS` is touched (terrain, the bake, `Places.Ground`,
`grid.spec`, `grid_relief.spec`, `terrainbake.py`). 2749 server + 676 client assertions, 0 failures,
0 errors, no flake fired.

## What changed

1. **The stand pads** (design 7.4). `TerrainBake.STAND_PAD` + `standPadsFor` + `standPadAt`, applied
   in `shapeTile` after the road and exempt from the limiter inside the core.
2. **The paint.** `ROAD.midStuds` 6 (design 7.1's table row), and `Relief.LANDFORMS.C1.floor.default`
   from the placeholder `Ground` to `LeafyGrass`.
3. **The archive** (design 16, rule 7). `Ground.paintRoads` with its helpers and constants, its call
   site, the boot's paint clause, and `grid.spec` case 19 -- in the same commit.
4. **`TerrainBake.reshapeWanted`**: the landform goes into the ground ONCE. Not in the dispatch; it
   is there because the measurement below said a bake would otherwise build C1 a second ridge.
5. **`parse_json` reads a bare scalar** -- the first bake wrote all 208 tiles and then died on
   `stampShape`'s reply of `1`.

## Claims, and how to verify each

1. **The pads are level and they are in her ground.** Worst relief over 327b's own 12-stud ring,
   fifteen stands of C1: **2.398 -> 0.091 studs**, 0 of 15 over `JUMP_RELIEF_STUDS` 1.8 (was 1, stand
   10). `HighSeats` footprint spread **0.000 on all fifteen** (was 0.026-0.687). Verify:
   `<runs-dir>/328e-ground-BEFORE.json` vs `-AFTER.json`, key `standsWorst` and the `stands` rows;
   and the boot's own line went `[seats] C1: ... worst spread 0.23` -> `0.00`.
2. **The pad's height is the road's crown, NOT `Grid.standPosition`'s Y, and that is arithmetic and
   not preference.** `standPadsFor`'s header carries it: `lineMeanY` is ONE number for fifteen
   stands (106.98) and C1's west flank road rises 35.4 studs between stands 8 and 11 (ground 93.41
   and 128.82, measured). Levelling both to it is a 21.84-stud pit beside a 13.57-stud mound, and a
   21.84-stud wall at `LIMIT_DEG.tree` 20 needs 60 studs of ring -- a 134-stud crater at every stand,
   220 studs apart. **So the dispatch's float/bury numbers are NOT closed by a pad and are reported
   as such**; they are `standPosition`'s per-cell constant, and 328h's re-survey owns it. Verify:
   the two `groundY` columns above, and `Grid.standPosition`'s `local y = cell.relief.lineMeanY`.
3. **Nothing in the world actually stands at that Y.** `ForestTest.Markers.build` places each post at
   `Markers.groundFor(stand.X, stand.Z, ...)` and `HighSeats.plan` reads `grounds`, never `stand.Y`.
   Verify: read both functions; `Grid.standPosition().Y` is a fallback.
4. **Every arm of the pad is entered by a case** (L-093): `grid_relief.spec` 328e-2 drives the level
   core (96 points, worst 0.0000 off), the blend (monotone, weight strictly in (0,1), both joins
   continuous), out of reach (nil, weight 0) and **no road under the stand** (`standPadsFor` with no
   profiles reports all fifteen as missed rather than inventing a height). 328e-3 writes a pad into a
   tile on a 10 % slope and **fails first** with `standPadsFor` stubbed out.
5. **The cross-section is design 7.1's, measured on the ground.** EW3 at x=-4164, after:
   `LeafyGrass | Grass[-34..-27] | Mud[-26..-24] | Grass[-23..-11] | Mud[-10..-7] | Ground[-6..+4] |
   Mud[+5..+9] | Grass[+10..+21] | Mud[+22..+24] | Grass[+25..+37] | LeafyGrass`, ditch **1.98 studs**
   below the crown (design asks 2). Before, the same line read `Ground[+10..+13] Grass[+14..+21]` --
   the 4-stud `mid` strip that `d < 10` left where the table asks for `outer`. Verify:
   `<runs-dir>/328e-xsec-BEFORE.json` vs `-AFTER.json`; case 328e-4 asserts it and fails first.
6. **The ruts were ALREADY at +-8 and still are.** `(rut.nearStuds + rut.farStuds)/2 == 8` was 328d's,
   not this task's, and the realised Mud column contains |d| 8 on all four roads. Said so rather than
   claimed as new work. Verify: case 328e-4's last block; the `AFTER` runs above.
7. **The floor: `Ground` 100 % -> `LeafyGrass` 100 %** over 5,504 lattice samples of C1 -- the "bare
   brown from every stand". **Slope rock is N/A for C1 and that is measured, not skipped**: C1's
   landform carries no scree rule, and `LIMIT_DEG.tree` caps the cell at 20 degrees while the
   design's only scree band (B2's) starts at 30, so such a rule could never fire. Verify: the
   `materials.zones.cellFloor` share in the two ground JSONs; case 328e-5.
8. **A bake over baked ground would have built C1 a second ridge, and it was measured BEFORE the
   write.** 90 points: mean **+3.67 studs**, 27 rising, **0 falling**, worst **+24.04** on the ridge
   line -- `C1.ops[1].dyStuds` is 24. `reshapeWanted` puts the landform in once; the live run printed
   `[reshape] C1 reshape=false`, and over TWO full bakes tonight `survey` moved meanY 115.655 ->
   116.14 (**+0.49**). Verify: `<runs-dir>/328e-drift-BEFORE.json`, `328e-bake2.txt`, `ESCALATE.md`
   2026-11-02 ~20:35 UTC; case 328e-6 enters all four arms with a FAIL FIRST.
9. **The archive is complete and the lane paint is untouched.** `paintRoads`, `roadChunks`,
   `roadYBand`, `roadBand`, `ROAD_CALL_BUDGET`, `ROAD_CHUNK_STUDS`, `ROAD_CALLS_PER_STEP`, the call
   site, `report.gridPaints`, the boot clause and `grid.spec` case 19 -- all in one commit, with
   `backups/2026-11-02_task-328e_Ground-paintRoads-and-grid-case-19.md` carrying the code and the
   rollback. `Ground.band`, `bandBounds`, `SOURCE_MATERIALS`, `Y_PAD_STUDS` stay. Verify: case 328e-5;
   `grep -rn paintRoads src tests`.
10. **Live, in her place, at the code commit.** `[bake] OK: 208/208 tiles @ 9946c7da cells=C1
    epoch=2bd42cc2fec396da worstTileMs=108 (clean tree)` -- 18.1 s of tile time, mean 87 ms,
    3,560,448 voxels. GridCensus C1: **floating 0, sunk 0, tilted 0, broken 0, noGround 0, inRoad 0,
    inStand 0, onCliff 0** over 2,021 trees. Boot: `15 of 15 post(s), 3 tower(s) at {8,13,15},
    complete=true`. Attribute diff before/after: **two changes, both this task's own stamps**
    (`TerrainEpoch`, `TerrainShape_C1`); Karen's 15 flag overrides byte-identical. Six eye-height
    frames before and after, looked at and described in the report.

## What I could not verify

- **`towersRelaxed` "flipping to false" proves nothing here.** `Grid.CELLS` C1 carries no
  `towersRelaxed` field, so it has read `false` since 327b -- before this task. The pads make the
  claim true for the right reason (every tower's ring now rolls <= 0.091 studs), but the flip itself
  is not evidence of anything I did. A re-survey that WRITES `towers`/`towersRelaxed` is 328h's.
- **A half-voxel registration offset in `bakeTile`, pre-existing.** Over 828 road samples the ground
  disagrees with `roadAt`'s own answer at 186 (22.5 %), and 183 of those are explained by an outward
  shift of <= 3 studs; the ditch realises as one column where `roadAt` answers two. Queued in
  `TASKS.md` 328e (a), not fixed: it moves every band in the world and deserves its own measurement.
- **`Ground.paintRoads` still runs in Karen's copy**, which syncs `main`: measured in her Play
  session it erases both ruts and widens the `Ground` strip from |d| 6 to |d| 14. The floor and the
  pads survive it. It needs the merge plus a `driven-hunt-karen` refresh -- `ESCALATE.md`.
- **`StreamingMinRadius` 64 -> 384 is still NEEDS KAREN.** It is not readable from `execute_luau`
  ("not a valid member of Workspace"), let alone settable.
