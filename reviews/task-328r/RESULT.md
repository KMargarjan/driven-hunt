PASS (item 9 NOT PROVEN)

Verified against the repo this round, not taken from the request:
- Round 1 finding 1 is fixed and the gate now bites. `tests/server/grid_relief.spec.luau` 328j-1 asserts
  `row.worstStepStuds <= row.explainedStuds + 1e-6` over `expect(#steps).to.equal(4)` rows; `worstStepStuds`
  comes from the walked `roadAt` grid and `explainedStuds` from `profileY` off the crossing's own profile, so
  the two sides are different computations. On this synthetic base `ewSpan` is 0, the allowance IS 0.2 and the
  measured step is 0.2 +- ~3e-14, so the 1e-6 slack is not float noise (verdict 284 checked).
- Round 1 finding 2 is fixed: the ride control (`Plan.maskGrid(id, x + Plan.RIDE_CLEAR_STUDS, z, ...)`) and
  both corridor controls (`x +- off`) now ask `maskGrid` at the grid point, as do the counted ride bite, the
  CLIFF/GAP walk, the `zoneRect` clearing centre and the front cone (`Grid.standGridOf` + `Plan.standFacing`,
  one space). Set `RIDE_CLEAR_STUDS` or `off` to 0 and each control now fails.
- Claim 10 holds BY READING: `TerrainBake.epochInputFor` builds its input from `Relief.LANDFORMS` and ten
  `Grid.CONFIG` rows and never touches `Grid.CELLS`; `standPadsFor` keeps a pad only where `roadAt` returns
  `weight >= 1`, and every such return (`carriageway`, `ditch`, `shoulder`, `verge`) ignores `naturalY`, so
  `relief.lineMeanY` 106.98 -> 106.03 cannot move a pad; `d989ebc0`'s 19 `TerrainBake` lines are the three
  comment blocks only. `junctionSteps` / `roadDistance` / `survey` are reporting functions with no caller in
  the write path (`tools/terrainbake.py` and the specs), and `9d79b38f` precedes the bake anyway.
- `EXPECTED_TILES` re-derived independently from `Grid.CONFIG` (origin -6700/-6600, 1070/1430/42, roadHalf 46,
  blend 200, bend 60, tile 128): C1 15x17=255, A1/B1/D1/A2/B2/D2 14x17=238, C2 15x17=255, ALL 44x32=1408 --
  every committed number matches, and `luau_facts`' `^\t\tewStuds` regex does read 45 off the new `Grid`.
- `survey`'s 3,888 (54x72 at step 20) and 54 line samples match the claim; its `toWorld(u, road.at)` +
  `roadCentreAt(road, x)` pair is exactly the world point of grid `(u, at)` by `toGrid`'s own definition.

Rule 5, stated so this PASS is not read as rule 5 having been met: item 9 (the animals) is NOT PROVEN for the
road this task moved, and the request says so itself -- the two cited metrics (0 stuck > 3 s, 0 no-progress
>= 6 s) read the same before and after and would pass with the bend deleted, and the one bend-specific metric,
the crossing counter, is dead because its `ROADZ` is the straight `-5107`. Nobody has watched an animal cross a
curved road. Karen has not played the bent world: her build's `Grid.standPosition` is still straight until this
merges, and her forest is the straight plan on the bent ground (sunk 113, inLane 106) until 328s re-plants. What
WAS seen in her place is the ground: the bake (255/255 tiles, worst tile 163 ms), the ditch and cross-section at
the realised column centres, the re-survey, the fifteen pads at spread 0.00, and six described eye-height frames.

## Notes (non-blocking)
- `TerrainBake.junctionSteps` -- the stair comment still carries the inversion round 1 found: *"0 at amplitude
  0, because then there is no stair to climb"* sits directly above `local facts = Grid.bendFacts(a.axis, bend)`,
  and `bendFacts` answers `stairStuds = math.huge` there, not 0. `stairStuds` and `swingDeg` are now emitted on
  every row and no case or note reads either. Fix the sentence and print the two in the note, or drop the fields.
- `tests/server/grid.spec.luau` case 5 -- the FIRST cross-side sweep reads `Grid.standPosition`, which is now
  the shipped BENT world, so it is the same measurement as the `worldStand(id, a, BENT)` sweep below it: the
  comment *"the assertion the straight loop above cannot make"* is stale, the note's first `worst cross-side
  pair` is the bent number (which is what REQUEST.md claim 7 quotes as the straight one), and the straight
  world's separation invariant is no longer covered anywhere. Drive the first sweep with `STRAIGHT`.
- `grid_relief.spec` 328j-1 -- the second new line, `expect(row.explainedStuds).to.be.near(row.ewSpanStuds +
  spec.crownFallStuds, 1e-9)`, is a transcription of the producer's own `explainedStuds = ewSpan +
  spec.crownFallStuds` (verdict 278): it pins the formula but proves nothing about the ground. The gate is
  carried entirely by the line above it; say so rather than letting the pair read as two checks.
- `grid_ground.spec` *"is ONE rule in two spaces"* -- assertions 1 and 2 (`roadDistance` vs `roadDistanceGrid`,
  `mask` vs `maskGrid`) are the wrappers against their own kernels and survive deleting the whole mask; only
  `roadDistanceGrid(u, v)` vs this file's own `roadGap(x, z)` bites. The case is sound because of that third
  line -- it should be the one the comment points at.
- `Places.roadDistanceGrid` now pays `Grid.toWorld` (five fixed-point steps) on every ask a road reaches, and
  `maskGrid` asks it ~3,000 times a cell; 328q note (d) named 328r as where that cost lands and no plant time
  is reported at 45/60 against design 8.3's *"whole cell planted < 4.0 s"*. Measure it in 328s with the replant.
- REQUEST.md top line *"everything after it changes only `Grid.CELLS.C1`, spec pins, spec coordinate spaces and
  three headers"* is right as written, but reads as if `junctionSteps`' fixed point were in that set; it landed
  in `9d79b38f`, before the bake. One clause would stop the next reader re-deriving it as I did.
- `tools/terrainbake.py` `CANONICAL_FIXTURE_INPUT` keeps `bendEwStuds: 0`: correct and needs no re-capture,
  because it is a synthetic landform `Z1` fixture and not a reading of live `Grid.CONFIG` -- worth a word in the
  comment above it, since design F-5 asks for a re-capture when the amplitude moves.

---
REVIEWER verdict on commit `760777ec921b0f144c78376b8bd143a3feda71b9` (round 2) · 2026-11-03 23:10 UTC · session cost $5.12, 38 turns · written by tools/agents.py
