# Task 306l -- the backstop as an earth hill, and the far lane out of its toe

Task: 306l
Round: 1
Base: dfade85b
Code commit: 3259ae6fdc1eb63a1bef04828f265a0e4bd0e9d0

[harness] PASS: 34/34 checks @ 3259ae6fdc1eb63a1bef04828f265a0e4bd0e9d0 (clean tree) scope=all

`[harness2]`: N/A. Nothing in `TWO_PLAYER_PATHS` is touched -- the change is `src/shared/Range/`,
`src/server/Range/Build.luau`, `tests/server/range.spec.luau` and one research note. No match, no
drive, no tie, no teams.

## PLAN (core quality protocol step 0), as it was measured and met

- **(a) REAL LIFE.** A live-fire impact berm is 4-6 m with a **bare, scoured impact face** and a
  grassed crest and back (NRA Range Source Book ch. 3; US Army TC 25-8 app. B). Its face is a 1:1 to
  1:1.5 batter, and a real heap of earth has neither a level crest nor a straight toe.
- **(b) MEASURED NOW** (`<runs-dir>/306l-profile.luau`, her place, on `main`): a terrain raycast down
  lane 2 reads **`AT LANE 179: ground 7.28 over shelf`**, the crest is **20.61 / 21.02 / 20.61** at
  d 188 / 192 / 196 -- one level line -- and the asphalt road starts at **d 204**. A staged
  2 x 3 x 5.5 trunk box (the released boar's own measured size) at `Range.laneCentre(... 179)` reads
  **BURIED 7.28 of 3.00, VISIBLE 0.00 studs (0%)**.
- **(c) TARGET.** `bermToeClearance` >= **5 studs** (half the boar's 5.5 length is 2.75, plus 2.25 --
  more than the half voxel a partial fill can reach with); the crest takes >= 4 distinct heights with
  a >= 3 stud spread; T6 still 180/180.
- **(d) LEVER.** `src/shared/Range/init.luau` `LAYOUT.BERM.behindStuds` / `slopeRun`, read by
  `Range.bermPosition` / `Range.bermCrestFaceZ` / `Range.bermToeZ`, and `Build.bermBoxes`, which is
  the only writer of the heap's boxes (`Build.writeTerrain` fills them).
- **(e) HOW MEASURED AFTER.** The same two probes, the same camera points, in her place.

## What changed

1. **The toe off the far lane.** `behindStuds` 13 -> 17, `slopeRun` 12 -> 8, `slopeSteps` 6 -> 4.
   New: `Range.bermCrestFaceZ`, `Range.bermToeZ`, `Range.bermToeClearance` (= 5).
2. **The heap is a hill.** `Range.bermColumns` cuts the 232-stud span into 19 columns, each with its
   own crest height and batter run (two incommensurate sines, not a seed). `Build.bermBoxes` emits a
   grassed core per column (`SURFACE.HILL`), `slopeSteps` bare-earth bands on its uprange face
   (`SURFACE.BERM`), then `Range.bermScrubPoints`' seven `LeafyGrass` clumps behind the crest's bare
   lip (`SURFACE.SCRUB`). The two side banks are grassed in both arms.
3. Nothing else: stations, distances, prompts, climb, window, heights, the part arm's one box.

Research note: `docs/research/2026-10-28-the-range-in-the-lobby.md` section 9.

## Claims, and how to verify each

1. **The farthest lane is clear of the heap, both ways down the row.**
   `range.spec` "keeps the backstop's toe behind the farthest lane, both ways down the row":
   `RangeData.bermToeClearance(LAYOUT)` = 5, `bermToeZ` is `distanceMax + 5` out for `dir` 1 and -1 at
   two anchors, and NO box of `Build.bermBoxes` has its uprange face past the lane.
   *Dies when the producer is removed:* put `behindStuds` back to 13 (or `slopeRun` back to 12) and
   `expect(clear >= LAYOUT.BERM.toeClearStuds)` fails at -3 (or 1), and the frozen-dials case fails
   at `expect(RangeData.bermToeClearance(LAYOUT)).to.equal(5)`.
2. **Measured in her place, BEFORE and AFTER, same instrument, same camera** (`306l-marker.luau`,
   a 5.5 x 3 x 2 box at `laneCentre(... 179)`): `main` -> *ground 7.28 over the shelf, BURIED 7.28 of
   3.00, VISIBLE 0.00 studs (0%)*; this commit -> *ground 0.00, BURIED 0.00, VISIBLE 3.00 studs
   (100%)*. Frames `306l-BEFORE-marker-zoom.png` (no red box anywhere) and
   `306l-AFTER-marker-zoom.png` (the red box standing on the flat lane), camera
   (2624, 155.7405, -3030.3999) in both.
3. **The ground profile down lane 2** (`306l-profile.luau`, this commit): 0.00 all the way to d 184,
   first earth 13.18 at d 188, crest 20.52 at d 196, and the materials split as designed -- **Ground**
   (bare earth) at 188 and 192, **Grass** at 196 and 200. `AT LANE 107 / 125 / 179: ground 0.00`.
4. **The crest is not one line.** `306l-t6.luau` raycasts the crest at nine x across the row:
   14.96 / 20.27 / 24.27 / 24.27 / 25.02 / 18.63 / 14.51 / 9.31 / 13.45 -- **9.31 .. 25.02 studs**.
   A level box reads one number (it did: 21.02). In the spec, `bermColumns` gives 19 columns, >= 4
   distinct tops with a >= 3 stud spread and >= 4 distinct runs; delete the `wave` term and the
   distinct-top assertion fails at 1.
5. **T6 re-sweep, this commit, her place:** `T6: 180 shots, 180 stopped at or before the heap's far
   face, 0 not`. Six stations x two eye heights (shelf+5 bench, shelf+17.5 deck) x three lanes x five
   window points. The criterion CHANGED and that is stated: 306k tested `hit.Z >= berm.Z - depth`,
   which the moved heap reads as an escape; this one escapes only with no hit at all or a hit past
   the heap's FAR face. Under the old plane-at-the-toe test 114/180 counted, with the worst case a
   hit at z -3213.8 against a nominal toe of -3214 -- a hit ON the batter, 0.2 studs of voxel spread.
6. **Only the impact face is bare earth, and the scrub is never on it.** `range.spec` "fills an
   uneven earth hill": every `BERM` box's downrange face IS the crest face and it reaches no further
   than `slopeRun`; every `HILL` box's uprange face IS the crest face; every `SCRUB` box is at least
   `scrubBackStuds` behind it. The banks' terrain fill is asserted to be `SURFACE.HILL`.
   *Dies when the producer is removed:* give the cores `SURFACE.BERM` and the `HILL` count assertion
   fails at 0.
7. **Nothing floats (rule E / L-086), by construction.** The scrub is TERRAIN, not parts: there is no
   pivot, no mesh and no asset. `range.spec` asserts every box of `bermBoxes` -- cores, bands and
   scrub -- has its bottom AT the shelf to 1e-6, and the terrace case's own heap branch asserts the
   same over the recorded fills. Column heights are quantised to a quarter stud so that identity is
   exact in float32 (it was not, and 19 boxes failed it -- commit 7789eddc).
8. **The input path did not change.** A real `E` (`298key.ps1 e` after one focusing click) at station
   2 opens the menu with all three distances offered: `306l-PROOF-E-crop.png`, looked at -- ANIMAL /
   KIND / PACE / WEAPON / CARTRIDGE / DISTANCE `107 studs (30 m)` `125 studs (35 m)` `179 studs
   (50 m)`, RELEASE THE TARGET, and THE BOARD under it.
9. **The three BEFORE/AFTER look frames, same camera points, all looked at.**
   bench 2: `306l-BEFORE-marker-zoom.png` / `306l-AFTER-marker-zoom.png` and the full
   `306l-BEFORE-bench2-crop.png` / `306l-AFTER-bench2-boar-crop.png`;
   deck 2: `306l-BEFORE-deck2-crop.png` / `306l-AFTER-deck2-crop.png`, camera Y 167.22 on both;
   lodge yard: `306l-BEFORE-yard-crop.png` / `306l-AFTER-yard-crop.png`, camera (2659.84, 159.80,
   -2970.79) on both. BEFORE: a flat grey band with a dead-straight top. AFTER: a green, uneven,
   scrub-topped ridge over a bare earth face.
10. **Lint, build and both selftests:** `selene src`, `selene --config tests/selene.toml tests`,
    `stylua --check src tests`, `rojo build` all exit 0; `python tools/studio_mcp.py selftest` and
    `python tools/agents.py selftest` both PASS.

## What I could NOT verify

- **Whether Karen reads the new shape as "an earth formed mountain".** That is her eye and nobody
  else's. The frames exist and are described; the verdict is hers, and this is flagged for a look
  BEFORE the merge (learning flag L-117).
- **A frame of a GAME-RELEASED boar standing at 179.** The live release path stopped serving requests
  part-way through the session (`NO TARGET DRAWN` from a client `RangeRequest:FireServer`, with a
  drive running in the same place), so claim 2's frames use the staged trunk box instead -- the same
  object, the same point, on both builds. The earlier live releases ARE recorded: on `main` a real
  request for 179 put the boar at **d 171.9, 1.5 studs up the batter**; on this commit the same
  request put it at **d 178.5, 1.49 over the shelf**. Both are readings, neither is a frame of the
  animal.
- **Four studs of the road's near edge.** The terrace grew with the heap: the same profile that read
  asphalt at d 204 on `main` reads **Ground at d 204 and asphalt from d 208** on this commit. The
  terrace's own downrange edge is d 202. The lodge-yard frame shows no visible cut, but this is a
  change to her road's shoulder and it is stated rather than buried.
