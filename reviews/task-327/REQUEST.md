# REQUEST -- Task 327a: the grid, surveyed and walkable

Task: 327
Round: 1
Base: ad0eb35e (main at `Merge pull request #309`)
Code commit: dd4e16501c6e4952925294cb8d76b2883ac8c34f

Harness, full one-player run on a clean tree at the code commit:

```
[harness] PASS: 34/34 checks @ dd4e16501c6e4952925294cb8d76b2883ac8c34f (clean tree) scope=all
```

`test2` is **N/A**: nothing here is in `TWO_PLAYER_PATHS` (`src/shared/Grid/`, `src/server/Places/`,
`src/shared/Flags/`, `src/shared/ForestTest/`, `src/server/ForestTestBoot.server.luau`,
`tests/server/grid.spec.luau`, `tools/studio_mcp.py`, docs). Design D-6 says the same.

**An earlier run of the same commit read `FAIL: 32/34` with `2666 passed, 1 failed, 1 errors` on the
server side, and the failing spec's name is not recoverable** -- the harness prints `failed [server]`
lines before the client notes and the head of that captured output was lost. Nothing changed between
the two runs. The second is the one quoted above; the first is reported rather than hidden.

## What changed

`src/shared/Grid/init.luau` (NEW) -- one world, eight drive cells. `Ground.paintRoads` and corner
stakes behind `GRID_PREVIEW` (born OFF). Research note first. Built to `docs/design/grid-map.md`
section 17's 327a; `ForestTest.LAYOUTS` is untouched.

## Claims

1. **The eight cells are the design's arithmetic.** `Grid.CONFIG` / `Grid.CELLS` / `boundsOf` /
   `roads` / `roadsOf` / `footprint` in `src/shared/Grid/init.luau`; `grid.spec` cases 1 and 3.
   Verify: the footprint is `4 x 1070 + 5 x 42` by `2 x 1430 + 3 x 42`; no two cells overlap; three
   east-west and five north-south roads, all inside it. Harness note:
   `footprint 4490 x 2986 at (-6700, -6600), 8 roads`.
2. **The relief rows are MEASURED, not written.** `Grid.CELLS[*].relief`. The survey probes are
   `327-survey3.luau` .. `327-survey7.luau` in the runs dir, run through `ftplay.py edit` against
   Karen's Forest Test in Edit. 100-stud lattice over x,z in [-7200, 7200] (21,025 rays), every
   `BasePart` bucketed in, all 10,656 windows of this size ranked: **twelve** hold 100 % terrain,
   zero non-terrain parts and a 300-stud margin. The chosen origin re-reads at 20 studs:
   **33,750/33,750 terrain hits, 0 parts inside**, per-cell spread 61.7-173.0, line spread
   14.1-70.2. Verify: `grid.spec` case 1 asserts `spread == maxY - minY`, `lineSpread <= spread`,
   `lineMeanY` inside `[minY, maxY]` and a character from the classified set, for all eight.
3. **No stand is within a slug's range of a stand on another side.** `Grid.standPosition` /
   `sideOf` / `separationStuds`; `grid.spec` case 5. Verify: the case recomputes all 8 x 72
   cross-side pairs with its own loop (not by calling `separationStuds`) and reports the worst.
   Harness note: `worst cross-side pair 356.1 studs (A1 1-8), range 330, margin 26.1`.
4. **The flank set-back is solved, not typed.** `Grid.flankFirstStuds`; case 6 recomputes it from
   `cellWidth`, `roadClear`, `mainCount`, `mainSpacing` and `RANGE_STUDS.Slug`. Note:
   `flank set-back 340 studs (needed 312.5), deepest flank stand 1000 of 1430`.
   **Deviation from the design, stated:** section 7 writes the margin as `27.5` and the sum as
   `340`; `ceil(312.5) + 27.5` is 340.5, so `flankMarginStuds` is **27** -- the number that makes
   the sum the 340 the design states.
5. **The beaters walk a cell inside the drive clock.** Case 9 asserts the two relations, never the
   numbers. Note: `beaters 275s over 1430 studs at 5.2 (clock 300s - 15s grace); slot 15 at 192s,
   83s of margin`.
6. **The walk is centre-out then flanks.** `Grid.standWalk` GENERATES it; case 11 asserts the
   literal `{4,3,5,2,6,1,7,8,12,9,13,10,14,11,15}`, that it is a permutation of 1..15, and that
   neither flank is filled before the other is touched.
7. **The roads are painted through an injected terrain and nowhere else, under the call budget.**
   `Ground.paintRoads` / `roadChunks` / `roadYBand` / `roadBand`; case 19. Note:
   `road paint: 270 calls (budget 300), 30 bands x 9 materials, 28400 studs of road, 135 breaths`.
   **Deviation from the design, stated and arithmetic:** section 8.3 derives its 300-call cap as
   `142 chunks x 2 source materials`, but `Ground.band` makes one call **per source material** and
   `SOURCE_MATERIALS` holds ten, so a band costs **nine**. The chunk is therefore derived from the
   budget (`28,400 x 9 / 300 = 852 -> ROAD_CHUNK_STUDS 1000`), and **the grid's roads carry no
   wheel ruts** -- two rut bands per chunk would treble 270 to 810. Verify: the case asserts
   `calls == bands * sources`, `calls <= 300`, every region inside its road's own 21-stud clear
   half-width at `resolution == 4`, **zero** calls with `enabled = false`, and
   `ROAD_CHUNK_STUDS >= roadStuds * sources / budget`.
8. **The preview tags nothing and `ForestTest.LAYOUTS` is untouched.** Case 22. Verify: with the
   preview on (by PARAMETER, not by flag) the folder holds 32 unqueryable, non-colliding, untagged
   `Stake_*` parts, `ForestTest.layoutNames()` is value-for-value unchanged, no cell id resolves to
   a layout, no `ForestMarkers` and no `HighSeats` appear; with it off, nothing at all, and an OFF
   build destroys an ON build's folder. Note:
   `preview on: 32 stakes, 4 layouts before and after; preview off: 0 stakes`.
9. **LIVE, in Karen's Forest Test, at the code commit** (`driven-hunt-294` on rojo :34874; the
   build identity was checked both ways -- `ReplicatedStorage.Grid` present there and **absent**
   after switching back to :34873). Boot line, `GRID_PREVIEW` set ON as an attribute for the proof
   and removed after:
   `[ForestTestBoot] grid: preview=true, 270 road paint call(s), 32 corner stake(s), 0 without
   ground, 6.09s` -- and a server probe read **`material ON the road = Ground ; 60 studs off it =
   Grass`**, `GridPlaces` with 32 children, the first stake `Stake_A1_SW` at (-6658, 84.1, -5086),
   `CanQuery=false CanCollide=false`. Zero console errors. **The 6.09 s is OVER the design's
   `< 4.0 s` road-paint target** (the 270-call budget is met; the time is not), and that is a
   finding against the design's estimate, reported rather than smoothed.
10. **`src/shared/Grid/` resolves to the `map` scope and `grid.spec` is in `map` and `places`**
    (design D-6, plus the dual membership this table already uses because `src/server/Places/`
    draws the grid). Verify: `python tools/studio_mcp.py selftest` and
    `python tools/agents.py selftest` both pass, and `tests/server/grid.spec.luau` appears in both
    tuples in `tools/studio_mcp.py`.

## Frames (rule 5), looked at

* `327-road.png` -- a hunter's eye 5 studs over the ground at cell **A1's south-west corner**,
  looking east along that cell's main line. A brown-grey earth road ~18 studs wide runs dead
  straight to the horizon between green grass; two orange corner stakes stand far down it where the
  next cell begins. The road climbs gently (y 59 -> 65 over 590 studs), which is A1's measured
  `slope`.
* `327-air2.png` -- 260 studs above the central crossroads: the north-south road and the middle
  east-west road crossing over grass, with the cell-corner stakes at the junction.
* `327-air3.png` -- the same from 860 studs: **the roads wash out**. `StreamingTargetRadius`
  defaults to 1024 studs and this place's Atmosphere does the rest, so a true top-down of a
  4,490-stud world is not obtainable from a client camera. That is honest gap 1 of the research
  note, seen.

## Not verified

* **Which spec failed in the first of the two harness runs** (see above).
* **The road paint's 4.0 s target**: measured 6.09 s (claim 9).
* A Play session's terrain write being discarded on stop is still *carried, not verified* --
  `Places.Ground`'s own header says so and this task did not re-test it.
* The grid's relief from a hunter's eye in a DRESSED cell: 327c plants the wood; 327a is bare ground.
