# Task 328r - C1's ground, re-baked at the bend

Task: 328r
Round: 2
Base: `main` `33ae3d15`
Code commit: `d989ebc0f7ed51415d5a45f00c2d2e175d79cac4`

```
[harness] PASS: 34/34 checks @ d989ebc0f7ed51415d5a45f00c2d2e175d79cac4 (clean tree) scope=all
```
`test2` N/A: no `TWO_PLAYER_PATHS` path is touched (Grid, Places, TerrainBake, grid*.spec, terrainbake.py).

`Grid.CONFIG.bend` is **45 / 60 / 1**, by commit, and C1's ground in Karen's Forest Test is baked to
it. Six commits; the bake ran at `11f354cf` and everything after it changes only `Grid.CELLS.C1`,
spec pins, spec coordinate spaces and three headers -- see claim 10.

## Round 1's two findings, both correct, both fixed in `d989ebc0`

**1. The junction-step allowance was widened in every world by an inverted test.** Right, and worse
than the finding says: `Grid.bendFacts` answers `stairStuds = math.huge` at amplitude 0, which this
suite asserts itself, so `row.stairStuds > 0` was true everywhere and the 0.32-stud term applied to
the straight world the comment exempted -- and its arithmetic was a LONGITUDINAL grade over one
voxel wearing the name of a lateral stair. The term is gone. The gate is now `row.explainedStuds`,
which is the rule `junctionSteps`' own docstring states, plus a second line asserting
`explainedStuds == ewSpanStuds + crownFallStuds` so the two cannot drift. **It is now exactly
tight**, which is the point: the note reads `worst step 0.2000 st ... explained 0.2000` at all four
of C1's crossings, so a single stud of regression reddens it.

**2. Two "and not just outside it" controls still asked `Plan.mask` (WORLD) with a GRID point.**
Right. At `z` -4386 `Grid.bendX` is -59.97, against a corridor half-width of 5 and an `off` of 15:
both controls answered "not in the band" for a point that was never in it, and would have held with
`off` set to 0. Both ask `maskGrid` now.

**And the same class in the same pass, which the Reviewer asked for:** the counted ride bite and the
CLIFF/GAP lattice walk `Grid.boundsOf` (a grid rectangle); the clearing case asks a `zoneRect`
centre; the front-cone case built its point from a WORLD `standPosition` plus a GRID `standFacing`
unit vector, up to 4.6 studs of lateral drift at 45/60. All five ask `maskGrid` at a grid point now.

**Three headers corrected, no behaviour:** `reshapeWanted` still promised the retired refusal -- and
now says plainly that **nothing checks the `--base` file was captured off virgin ground**
(`check_base` proves the sha, not the provenance, so a snapshot taken after a bake would pass it and
the landform would go in twice); `standPadsFor` still quoted `lineMeanY` 106.98; `roadDistance`'s
new sentence called a grid axis gap a world one.

**Queued, not fixed (said so rather than left to be found):** `shapeTile` carries `bend` into
`toGrid`/`toWorld`/`roadAt`/`standPadsFor`/`standPadAt` but not into `cellAt`/`unionOf`/`blendAt`,
which read `Grid.CONFIG.bend` themselves -- harmless today because each case bakes one cell deep
inside its own union, and threading it would move `unionOf` under three cases I would then have to
re-pin in a round that must not fail. `Places.fernBands`' 34-stud inset against the perpendicular
34 goes to 328s with the replant.

## What changed

1. `Grid.CONFIG.bend` 0/0 -> 45/60 (design 5.2, 9.2), and the seam takes a trailing optional `bend`
   everywhere 328q note (a) listed, plus `plantCell`, `scatter`, `shapeTile`, `bakeTile`,
   `standPadsFor`, `junctionSteps`. `nil` is `Grid.CONFIG.bend`, so no production caller moves.
2. 328q notes (a) (b) (c) (d) (i) (j) (k) fixed -- the ones marked "before 328r".
3. Refusal 7b retired (claim 2), archived under `backups/` per rule 7.
4. `EXPECTED_TILES` re-derived at 45/60; C1 208 -> 255, the world 1333 -> 1408.
5. C1 re-baked from the 328k base snapshot; `relief` and `towers` re-measured off the result.

## Claims, and how to verify each

1. **THE BAKE.** `<runs-dir>/328r-bake.txt`:
   `[bake] OK: 255/255 tiles @ 11f354cf... cells=C1 epoch=5e09ea024be987ee worstTileMs=163 (clean tree)`
   -- 35.4 s of tile time, mean 139 ms, 4,288,512 voxels, worst tile **163 ms** against design 11.4's
   8 s. Read from the virgin base `terrain-base-010b6400abdd.bin`, sha `010b6400abdd3e12...`, which
   328k's row names and which the tool re-checked. Backup `<backups-dir>/FT-before-328r.rbxl`,
   29,331,551 bytes, `<roblox!` header, taken 19:00 UTC before any terrain write. Karen's 13 extra
   flag overrides were **declared** with `--keep-flags`, never cleared (rule K); the run prints
   `keep 13 declared override(s), left as found`.

2. **REFUSAL 7b WAS WRONG, AND IT IS MEASURED AND NOT ARGUED.** In Karen's place before any write,
   `TerrainBake.reshapeWanted("C1")` answered `wanted=false, kind=stamped`. `shapeTile`'s branch
   `elseif form == nil or (reshape ~= nil and reshape[id] ~= true)` then keeps the base -- and since
   328k the base is the VIRGIN `.bin`, so the bake would have written C1's roads and pads onto ground
   with no landform in it and erased the ridge. `bakeTileAt` now always applies the landform (the
   slice IS the base; design 7.1 "erased, not stacked") and still PRINTS the stamp:
   `reshape C1 changed ... (the base file is virgin: the landform goes in regardless)`.
   `reshape_report` replaces `reshape_blocked`; four selftest cases assert it refuses nothing and
   still names every cell's kind. Archived verbatim in
   `backups/2026-11-03_task-328r_refusal-7b-reshape-blocked.txt`.

3. **THE JUNCTIONS HOLD, AND A DEFECT IN MY OWN NEW CODE WAS CAUGHT BY A SPEC AND FIXED.**
   `junctionSteps` walked the square in the roads' local frame in ONE pass, reading the N-S centre at
   `a.at + dz` when the sample's real z is `a.at + bendZ(x) + dz` -- up to 45 studs out, over which
   `bendX` moves 5.8 studs. Measured before: **worst step 1.8379 st at (+16,+24)**. Solved as a
   three-step fixed point. Measured after, in `grid_relief.spec`'s note: **0.2000 st** at all four of
   C1's crossings, equal to the case's own `explained` allowance. On the REAL base (`328r-bake.txt`):
   pin **0.0000 st** at all four, worst voxel step **1.1257 st** inside its own explained 1.2556.

4. **THE DITCH AND THE CROSS-SECTION, AT THE REALISED COLUMN CENTRES** (`<runs-dir>/328r-line.json`,
   probe `328r-line.luau`): five stations along C1's main line, each read at
   `roadCentreAt(road, x) + d`. Deepest cut **1.76-1.95 studs** at d +-24..26 -- design 11.4 asks
   2 +- 1.0. Every station's centre reads material `Ground`; `-4350.67`, `-4361`, `-3849`, `-4620`
   all read `Ground` on the curve, and a point 13 studs off it reads `Mud` (the ditch).

5. **THE RE-SURVEY** (`terrainbake.py survey --cells C1`, 3,888 samples): minY 89.2 -> **89.14**,
   maxY 150.9 -> **150.26**, spread 61.7 -> **61.12**, lineMeanY 106.98 -> **106.03**,
   lineSpreadStuds 21.0 -> **20.49** (54 samples along the curve, `328r-line.luau`). `character`
   stays `rolling`. All five are written into `Grid.CELLS.C1.relief` in `f0cc0459`.

6. **THE TOWERS AND THE PADS.** 327b's own instrument re-run over C1's fifteen new world points
   (`<runs-dir>/328r-towers.luau`, the 327b script with the positions re-read): **every pad reads
   `spread 0.00` and `relief 0.01-0.10`** against the 1.8 threshold, so all 15 are on their pads and
   `towersRelaxed` stays absent -- which is exactly what design 11.4 said to watch. The boot agrees:
   `[seats] C1: 3 built, 0 refused, worst foot gap -0.30 studs, worst spread 0.81 studs`.
   `towers` 8/13/15 -> **8/10/13** by the rule in `Grid`'s own header: 13 (+234), 10 (+216), 8 (+120);
   11 (+180) and 9 (+89) are adjacent to 10 and 14 (+120) to 13. **15 fell out** -- its gain went
   +95 -> +40, under the 60 floor.

7. **THE SAFETY MARGIN.** `grid.spec`'s note: `worst cross-side pair 363.79 studs (A1 7-12),
   range 330, margin 33.79` -- the design's own 363.79 at `flankFirstStuds` **366**, and >= 330.
   Defect F-1 costs two thirds of the margin and is not a breach.

8. **THE SPECS.** 328q's inert gate is kept and re-pointed: it drives `STRAIGHT` by parameter and
   still pins the pre-328q world value for value, including `Grid.CELLS`' own untouched 327b header
   coordinates. A new case pins what this commit shipped -- 45/60, set-back 366, five C1 stands to
   the stud against their straight pair, `layoutFor`'s three fields (535->595, 1472->1517), `roadZ`
   departing 45.00 st from the centre, all 15 junctions exact to 0.0e+00, and the plan counts.
   Every other failure the first clean-tree run found was one of three shapes and **none was the
   bend being wrong**: a GRID fact asked in WORLD coordinates (the production code was already
   right -- the only consumer is `Plan.plantCell`, checked), a LATTICE claim that holds only for a
   whole-stud centreline (driven at amplitude 0 by parameter now), and a float32 `Vector3` tolerance
   asserted at 1e-6 or 1e-9 (measured residual 1.87e-4).

9. **THE ANIMALS ARE NOT RE-STUCK** (328n's sampler, 100 s at 5 Hz, one drive each side).
   Before: 65 animals, **0** stuck > 3 s, **0** no-progress >= 6 s, worst stuck run 2.0 s.
   After: 51 animals, **0** stuck > 3 s, **0** no-progress >= 6 s, worst stuck run 1.8 s.
   The sampler's crossing counter reads 0 after, because its `ROADZ` is the straight `-5107`; that is
   the instrument, not the behaviour, and the two metrics above are position-independent.

10. **THE BAKE RAN AT `11f354cf`, NOT AT THE CODE COMMIT, AND NOTHING SINCE MOVES THE GROUND.**
    `f0cc0459` changes `Grid.CELLS.C1.relief` and `towers`; `79b3c977` changes two spec pins.
    `TerrainBake.epochInputFor` builds its input from `Relief.LANDFORMS` and `Grid.CONFIG` -- it
    never reads `Grid.CELLS` -- so the epoch cannot move, and `Workspace.Terrain.TerrainEpoch` still
    reads the bake's own `5e09ea024be987ee`. **This one is a reading of the code, not a run.**

## What I could NOT verify, said plainly

* **THE CENSUS IS NOT AT 0, AND IT CANNOT BE UNTIL 328s.** Karen's Forest Test syncs from
  `driven-hunt-karen` (merged `main`), whose planner is still straight, so its boot planted
  `grid wood C1: 1782 of 1809` of the STRAIGHT plan onto the BENT ground. Measured
  (`328r-census-after.json`): floating **0**, tilted **0**, broken **0**, noGround **0**, onCliff
  **0**, inRoad **0**, inStand **0**, crownOverRoad **0**; but **sunk 113** (worst 4.40 st),
  **inLane 106**, foliageInGround 79, refused 27 of 1809 = **1.5 %** (<= 8 %). The replant is 328s's
  task and this branch already carries the planner that fixes it (`plantCell("C1")` = 1,789 rows,
  all masked against the bent road).
* **A HUNTER IN HER BUILD IS DEALT A STAND 45 STUDS OFF THE ROAD**, for the same reason: her copy's
  `Grid.standPosition` is the straight one. It resolves when this merges and `karen-build.sh` runs.
* **THE ANIMALS ARE NOT PROVEN ON A BENT ROAD**, and round 1 is right to say so. The two metrics I
  can cite (`0` stuck > 3 s, `0` no-progress >= 6 s) read the same on both sides and so would also
  pass with the bend deleted; the one that is about a curved road -- the crossing counter -- is dead
  because its `ROADZ` is the straight `-5107`. What claim 9 establishes is the NEGATIVE: the re-bake
  did not make anything worse. Nobody has watched an animal cross a curved road.
* The three AFTER frames are from main stands 1 and 7, not from a junction or a flank stand:
  `ForestTest.boundary` clamps a hunter to 12 studs of the stand the drive dealt him, and at 45/60
  the bent road is ~45 studs from the middle stands, so no camera could be held there. Named rather
  than worked around.
* The remaining `grid-roads.md` section 14 deltas (`grid-terrain.md`, `drive-layouts.md`,
  `map-ui.md`) are 328q's leftovers and are **not** pasted here; queued in `TASKS.md`.

## Frames (rule 5) -- all at hunter eye height, in Play, in Karen's place, opened and described

`<runs-dir>/`, cropped to the viewport, all six shas distinct.

* `328r-F1-before.png` / `328r-F1-after.png` -- **the picture Karen's sentence asks for.** Before: a
  dead-straight road running to the horizon from main stand 1. After: from the same stand's new
  world point on the carriageway, the road runs away east and **curves visibly left (north)** before
  straightening, ditch and verge following it round.
* `328r-F2-before.png` / `328r-F2-after.png` -- west toward the junction with the west flank road.
  Before: straight to the horizon. After: the road bends gently south into the junction square.
* `328r-F3-before.png` (flank stand 10, straight road south) / `328r-F3-after.png` (main stand 7,
  west along the bow -- the mirror of F1). **Not the same viewpoint**, for the clamp reason above.
