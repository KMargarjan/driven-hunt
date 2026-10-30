# Task 306l -- the backstop as an earth hill, and the far lane out of its toe

Task: 306l
Round: 2
Base: dfade85b
Code commit: a634ca12f96f2c6f56575262509103c7325f5821

[harness] PASS: 34/34 checks @ a634ca12f96f2c6f56575262509103c7325f5821 (clean tree) scope=all

`[harness2]`: N/A. Nothing in `TWO_PLAYER_PATHS` is touched -- `src/shared/Range/`,
`src/server/Range/Build.luau`, `tests/server/range.spec.luau` and one research note. No match, no
drive, no tie, no teams. (The last commit that changed `src/` or `tests/` is `2cb5de9b`; `a634ca12`
adds only `reviews/task-306l/RESULT.md`, so the line covers the code.)

## PLAN (core quality protocol step 0), measured and met

- **(a) REAL LIFE.** A live-fire impact berm is 4-6 m with a **bare, scoured impact face** and a
  grassed crest and back (NRA Range Source Book ch. 3; US Army TC 25-8 app. B), and a real heap of
  earth has neither a level crest nor a straight toe.
- **(b) MEASURED NOW** (`<runs-dir>/306l-profile.luau`, `306l-marker.luau`, her place, on `main`):
  **`AT LANE 179: ground 7.28 over shelf`**; the crest is **20.61 / 21.02 / 20.61** at d 188/192/196
  -- one level line; the asphalt road starts at d 204. A 5.5 x 3 x 2 box (the released boar's own
  measured trunk) at `Range.laneCentre(... 179)` reads **BURIED 7.28 of 3.00, VISIBLE 0.00 (0%)**.
- **(c) TARGET.** `bermToeClearance` >= 5 studs; the crest >= 4 distinct heights, >= 3 stud spread,
  and **never under the deck's own firing eye 17.5 where the firing fan reaches**; T6 180/180.
- **(d) LEVER.** `src/shared/Range/init.luau` `LAYOUT.BERM.behindStuds` / `slopeRun` /
  `crestDropStuds` / `shoulderDropStuds` / `shoulderStuds`, read by `Range.bermColumns`,
  `Range.bermCrestFaceZ`, `Range.bermToeZ`; `Build.bermBoxes` is the only writer of the heap's boxes.
- **(e) HOW MEASURED AFTER.** The same probes, the same camera points, in her place.

## Round 1's two blocking findings

1. **The crest had only an UPPER bound, and the shipped dials dipped under the deck's firing eye.**
   `range.spec` "fills an uneven earth hill" now asserts a LOWER bound: `local deckEye =
   HighSeats.DIMS.DECK_RISE_STUDS + HighSeats.AIM_RISE_STUDS`, `local fan =
   RangeData.sightHalfWidthAt(LAYOUT, math.abs(face - anchor.Z))`, and for **every column whose span
   meets `[anchor.X - fan, anchor.X + spotSpan + fan]`**, `expect(column.top >= deckEye)`, plus
   `expect(inFan >= #columns - 4)` so the fan cannot be narrowed to nothing and
   `expect(deckEye >= 17.5)` so the eye cannot be lowered to meet the hill. The dials moved to make
   it hold: `crestDropStuds` 4 -> 3, `shoulderDropStuds` 9 -> 5, `shoulderStuds` 24 -> 16.
   *Verify:* the 17 in-fan columns now run **18.00 .. 20.50**; set `crestDropStuds` back to 4 and
   column 11 lands on 17.25 and the case fails; set `shoulderStuds` back to 24 and column 2 lands on
   16.75 and it fails. Measured live at this commit (`306l-t6.luau`, nine raycasts across the row):
   **18.51 / 20.52 / 24.38 / 24.38 / 24.59 / 18.88 / 18.13** inside the corridor, 9.31 and 13.45 on
   the east shoulder outside the firing fan.
2. **The terrace case's heap count was taken only from the producer.** Added, directly under it:
   `expect(distinct >= #RangeData.bermColumns(anchorOf(b), LAYOUT, -1)).to.equal(true)`.
   *Verify:* make `Build.bermBoxes` return `{}` -- `distinct` is 0, `#bermColumns` is 19, and the
   case fails. Round 1's `expect(want).to.equal(distinct + 1)` passed that deletion vacuously.

Also done, from round 1's notes: `scrubSize.Z` 6 -> 4, so no clump reaches the heap's rear face (its
downrange face is now `face - 6` against a rear face at `face - 8`); the `BERM` comment block's two
pre-306l paragraphs (the 188/196 faces, and *"the toe ... stands at 176, three studs clear of the
farthest target at 179"* -- the very error this task fixes) now say what is true; both
`SURFACE.BERM` paragraphs in `Build.build` say what their line actually writes; note 9.5's M4 count
is corrected to **16.25..20.5, 11 distinct** (the tops are quantised, so they repeat) and M5 is
restated as the lower bound the spec now holds.

## Claims, and how to verify each

1. **The farthest lane is clear of the heap, both ways down the row.** `range.spec` "keeps the
   backstop's toe behind the farthest lane, both ways down the row": `bermToeClearance` = 5,
   `bermToeZ` is `distanceMax + 5` out for `dir` 1 and -1 at two anchors, and no box of
   `Build.bermBoxes` has its uprange face past the lane. *Dies:* put `slopeRun` back to 12 and the
   clearance is 1, under `toeClearStuds` 5 and under the boar's own half length 2.75 plus a margin.
   (Round 1's request said "-3 (or 1)" for reverting one dial; **1** is right for `behindStuds`
   alone, -3 needs both -- the Reviewer's correction, carried.)
2. **BEFORE and AFTER in her place, same instrument, same camera** (`306l-marker.luau`): on `main`
   *ground 7.28 over the shelf, BURIED 7.28 of 3.00, VISIBLE 0.00 studs (0%)*; at THIS commit
   *ground 0.00, BURIED 0.00, VISIBLE 3.00 studs (100%)*. Frames `306l-BEFORE-marker-zoom.png` (a
   dead-straight grey band, no red box anywhere) and `306l-R2-AFTER-marker-zoom.png` (the red box
   standing clear on the flat lane under an uneven green crest), camera
   (2624, 155.7405, -3030.3999) in both. Both looked at.
3. **The ground profile down lane 2, at this commit** (`306l-profile.luau`): 0.00 all the way to
   d 184, first earth 13.18 at d 188, crest 20.52 at d 196, and the materials split as designed --
   **Ground** at 188 and 192 (the impact face), **Grass** at 196 and 200 (the crest and the back).
   `AT LANE 107 / 125 / 179: ground 0.00`.
4. **The crest is not one line.** Live, at this commit: **9.31 .. 24.59 studs** across nine x
   (claim 1 above lists them); a level box reads one number, and did -- 21.02. In the spec,
   `bermColumns` gives 19 columns, >= 4 distinct tops over a >= 3 stud spread and >= 4 distinct runs.
   *Dies:* delete the `wave` term and the shoulder taper alone leaves three distinct tops, under the
   four the case requires. (Round 1's request said "fails at 1"; **3** is right -- the Reviewer's
   correction, carried.)
5. **T6 re-sweep at THIS commit, her place:** `T6: 180 shots, 180 stopped at or before the heap's far
   face, 0 not`. Six stations x two eye heights (shelf+5 bench, shelf+17.5 deck) x three lanes x five
   window points. The criterion CHANGED and that is stated: 306k tested `hit.Z >= berm.Z - depth`,
   which the moved heap reads as an escape; this one escapes only with no hit at all, or a hit past
   the heap's FAR face. Under the old plane-at-the-toe test 114/180 counted, worst case a hit at
   z -3213.8 against a nominal toe of -3214 -- a hit ON the batter, 0.2 studs of voxel spread.
6. **Only the impact face is bare earth, and the scrub is never on it.** `range.spec` "fills an
   uneven earth hill": every `BERM` box's downrange face IS the crest face and it reaches no further
   than `slopeRun`; every `HILL` box's uprange face IS the crest face and its downrange face is
   `face - depth`; every `SCRUB` box is at least `scrubBackStuds` behind the lip and no further back
   than `depth`. The banks' terrain fill is asserted to be `SURFACE.HILL`. *Dies:* give the cores
   `SURFACE.BERM` and the `HILL` count assertion fails at 0.
7. **Nothing floats (rule E / L-086), by construction.** The scrub is TERRAIN, not parts: no pivot,
   no mesh, no asset, and no gap under it. `range.spec` asserts every box of `bermBoxes` -- cores,
   bands and scrub -- has its bottom AT the shelf to 1e-6; the terrace case's heap branch asserts the
   same over the recorded fills AND now that the heap was filled at all (finding 2). Column heights
   are quantised to a quarter stud so the identity is exact in float32 (it was not; 19 boxes failed
   it -- commit 7789eddc).
8. **The input path did not change.** A real `E` (`298key.ps1 e` after one focusing click) at station
   2 opens the menu with all three distances offered: `306l-PROOF-E-crop.png`, looked at -- ANIMAL /
   KIND / PACE / WEAPON / CARTRIDGE / DISTANCE `107 studs (30 m)` `125 studs (35 m)` `179 studs
   (50 m)`, RELEASE THE TARGET, and THE BOARD under it. (Taken at `3259ae6f`; round 2 changed five
   numeric dials and two spec assertions and touched no input path, no prompt, no remote and no
   client file -- `git diff --name-only 3259ae6f..a634ca12` is `src/shared/Range/init.luau`,
   `src/server/Range/Build.luau`, `tests/server/range.spec.luau`, the research note and the
   `reviews/` files.)
9. **The three BEFORE/AFTER look frames, same camera points, all re-taken at THIS commit (L-162)
   and all looked at.** bench 2: `306l-BEFORE-marker-zoom.png` / `306l-R2-AFTER-marker-zoom.png`
   (camera Y 155.7405 both); deck 2: `306l-BEFORE-deck2-crop.png` / `306l-R2-AFTER-deck2-crop.png`
   (camera (2624, 167.217, -3016.399) both); lodge yard: `306l-BEFORE-yard-crop.png` /
   `306l-R2-AFTER-yard-crop.png` (camera (2659.85, 159.80, -2970.77) both). BEFORE: a flat grey band
   with a dead-straight top, against the rounded green hills behind it. AFTER: a green, uneven,
   scrub-topped ridge over a bare earth face, with the red lane marker standing clear in front of it.
10. **Lint, build and both selftests:** `selene src`, `selene --config tests/selene.toml tests`,
    `stylua --check src tests`, `rojo build` all exit 0; `python tools/studio_mcp.py selftest` and
    `python tools/agents.py selftest` both PASS.

## What I could NOT verify

- **Whether Karen reads the new shape as "an earth formed mountain".** Her eye, nobody else's. The
  frames exist and are described; flagged for her look BEFORE the merge (L-117).
- **A frame of a GAME-RELEASED boar standing at 179.** The live release path stopped serving requests
  part-way through the session (`NO TARGET DRAWN` from a client `RangeRequest:FireServer`, with a
  drive running in the same place), so claim 2's frames use the staged trunk box -- the same object
  at the same point on both builds. The live releases that DID run are readings, not frames: on
  `main` a real request for 179 put the boar at **d 171.9, 1.5 studs up the batter**; at `3259ae6f`
  the same request put it at **d 178.5, 1.49 over the shelf**.
- **Four studs of the road's near edge.** The terrace grew with the heap: the profile that read
  asphalt at d 204 on `main` reads **Ground at d 204 and asphalt from d 208** here. The terrace's own
  downrange edge is d 202 and the 4 studs are the voxel containing -3234. The round-1 Reviewer
  checked this in-repo and called it not a defect (inside the B8 census rectangle); it is stated
  anyway, because it is a change to her road's shoulder.
