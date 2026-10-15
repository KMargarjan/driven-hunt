# Task 192 -- nobody dies on respawn or at a new round, and the terrain is whole

Task: 192
Round: 3
Base: 5cc4472 (main, after #173)
Code commit: 168fe3d52b6130b9d2255a87deca87270144c2cc

Harness, clean tree, FULL suite (this branch touches `src/server/Match/`, which maps to the `match`
scope, and `src/server/ForestTestBoot.server.luau`, which maps to nothing and therefore to `all`):

    [harness] PASS: 33/33 checks @ 94a31d614f919a0c66e0e5b01f00f5e97e0d3983 (clean tree) scope=all
    [harness] PASS: 33/33 checks @ bca1b0b5db65c8b26684996685400122d0d3dc06 (clean tree) scope=all
    [harness] PASS: 33/33 checks @ 168fe3d52b6130b9d2255a87deca87270144c2cc (clean tree) scope=all
    [harness2] PASS: 35/35 checks @ 168fe3d52b6130b9d2255a87deca87270144c2cc (clean tree)

THE CODE COMMIT IS THE SECOND ONE, and it is a commit that also carries paperwork -- which the git
workflow allows and which is the honest fix for my own slip: `docs/research/` is NOT in the merge
gate's paperwork list, and I had committed the note after the last code commit. Re-running the
harness at that head costs one run and leaves the history straight, where naming the earlier commit
would have left the evidence not covering the tree. Between `bca1b0b` and the branch head, only
`reviews/` and `TASKS.md` change.

Round 2's finding is fixed and it was right. Four of its five notes are fixed; the fifth is answered
by a rename. **The threshold and one spec case differ from the dispatch's own numbers, for a
measured reason -- see "Where this differs from the dispatch" at the end.**

## Finding 1 -- it read a neighbouring voxel, and the proof is the span itself

`Region3.new(at - 2, at + 2):ExpandToGrid(4)` is four studs wide only when the coordinate is exactly
2 (mod 4); at every other offset it expands to EIGHT -- two voxels per axis -- and
`materials[1][1][1]` is the region's MINIMUM corner. Measured live at (3555, -3000):

    span = 8, 8, 8   minimum = (3552, 192, -3004)

A root at z -3000 was therefore asked about a cell **four studs away in z**. The function was
answering about a neighbour, and the only thing standing between that and a 4 Hz teleport was
`RESCUE_MOVED_STUDS` (1) against a ~0.5-stud gap -- a coincidence of two numbers, exactly as the
review said.

**It reads the containing cell now, by construction**: `min = floor(at / 4) * 4`, `max = min + 4`,
always a 1x1x1 grid. **"Buried" is that cell solid AND the cell four studs above it solid** -- a
body in the ground with ground over its head.

**The threshold is measured, and round 2's own occupancy table was taken from the wrong cells.**
Reading the CONTAINING cell down four columns of the live place, by offset from the surface:

| offset | (3555,-3000) | (3405,-3000) | (2850,-2934) | (3030,-2097) |
|---|---|---|---|---|
| -12 | 1.00 | 1.00 | 1.00 | 1.00 |
| -8 | 0.98 | 1.00 | 1.00 | 0.89 |
| -4 | 0.93 | 1.00 | 0.56 | 0.50 |
| 0 | 0.39 | 0.46 | 0.00 | 0.00 |
| +4 | 0.00 | 0.00 | 0.00 | 0.00 |

A half puts the surface cell on the fence (0.46 and 0.50 are two of those readings), so
`TERRAIN_SOLID_OCCUPANCY` is **0.75** -- in the gap between "within one cell of the surface"
(<= 0.56) and "two or more cells down" (>= 0.89).

## Claims

1. **`Body.insideTerrain` reads the cell the point is in, and a second cell above it.** No
   `ExpandToGrid`, no corner index, no neighbour.
   *Verify:* `cellOf` / `cellIsSolid` / `Body.insideTerrain` in `src/server/Match/Body.luau`.

2. **A standing character cannot read "buried", by arithmetic as well as by measurement.** A root
   is ~3 studs above its feet, so for its cell to be half solid the surface would have to be 2 studs
   above that cell's floor -- which puts the root 5 studs above the floor of a 4-stud cell.
   *Verify:* the proof is written at `Body.insideTerrain`; the measurement is claim 3.

3. **Specced against HAND-PLACED TERRAIN in DEV, at four residues mod 4.** Four columns whose x, z
   and measured surface land on four different residues (surfaces 502.00, 503.02, 504.02, 505.00 --
   residues 2, 3, 0, 1). Standing at +3.0 / +3.2 / +3.6 / +4.0 above the surface: **`Air` 0.00,
   buried = false at all sixteen points.** Buried at -10 / -17.5 / -24: **`Grass` 1.00, buried =
   true at all twelve.** A third case proves the cell above the surface and the cell well below it
   are told apart, which the old span could not do.
   *Verify:* `tests/server/match_place.spec.luau`, describe "Body.insideTerrain"; the two
   `TestKit.note` lines in the harness report print every reading.

4. **The spec cannot damage the place, and that is checked rather than asserted.** The blocks are at
   x 5000+, y 500; the region is REQUIRED to be empty before anything is written (a boolean every
   case asserts, not an `expect` inside `beforeAll` -- which is what broke the first run of this
   spec: the throw took the fill with it); the fill is cleared in `afterAll`; and a Play session's
   terrain write never reaches the saved place, which is what the harness compares.
   *Verify:* `beforeAll` / `afterAll` / `wasEmpty` in that describe; `git log` for the second
   round-3 commit, which says the same thing.

5. **Live: four 60-second stands on real terrain, and one forced burial.** The lodge yard
   (2845, -2934), and three points inside the player's own stand circle at (3030, -1517) x%4=2
   z%4=3, (3035, -1514) x%4=3 z%4=2 and (3024, -1522) x%4=0 z%4=2 -- the first on flat shelf, the
   other three on the forest's own slope. **Exactly one `[place] RESCUED` line in the whole session,
   and it is the forced burial**:

       [place] RESCUED Alhamdulilah824: root (3024, 212.6, -1522) was inside solid terrain,
       put back at (3024, 236.1, -1522)

   236.1 is where he had been standing a moment earlier -- so this is also the first live proof of
   the `lastGood` branch, which round 2 could not exercise.
   *Verify:* `<runs-dir>/t192c-console.txt`; the marker lines quoted in TASKS.md.

6. **Note 1: the scene asks the reader from the layout point's own Y.** It was two arguments, so
   the animals and the torches were still placed with the cast from the sky -- a carcass under one
   of this place's canopies would have hung at canopy height.
   *Verify:* `onGround` in `src/server/Match/Scene.luau`.

7. **Note 2: `fromY` is in all three published types** (`groundReader`, `Body.setGroundReader`,
   `Scene.build`'s `groundAt`), so a world that injects a two-argument reader is a type error rather
   than a silent return of finding 1.
   *Verify:* the three annotations.

8. **Note 4: the net asks once and never yields.** `Body.onGround` takes `attempts`, and the
   rescue passes 1 -- it runs inside `Match:step`, where a `task.wait` would delay the drive's own
   tick. A placement still retries, because it can afford to wait for a region to stream.
   *Verify:* `groundWithRetries` / `Body.onGround` / the `floorStep` call site.

9. **Note 5: the two mis-titled cases are merged into one that names what it proves.** They passed
   `never` as `buriedTest` with an anchored root, so they never reached the ground reader; the title
   now says what they do test (the net's three questions are independent of the reader) and points
   at the two describes that hold the real guards.
   *Verify:* the case "asks no depth at all: a reader that answers 14 studs too high moves nobody".

10. **Note 3 is answered by a correction, not a change.** Claim 1 of round 2 ("Nothing above a point
    can be its ground any more") overstated it: stage B is still the cast from 600 and it runs on
    the buried case. The headline is dropped and claim 1 of this round says what the code does.
    *Verify:* this document's claim 1.

## What I could not verify

* **`test2`.** `src/server/Match/` is in `TWO_PLAYER_PATHS`, so the MERGE needs a two-player line
  and that needs a human F7. The review does not: the pasted line is `scope=all`.
* **THE PER-SAMPLE LOG OF THE FOUR STANDS IS LOST, and that is my mistake.** I stopped Play before
  dumping the 0.5 s sampler, and it lived in the session's `shared` table. What survives is the
  console (exactly one `RESCUED` line, the forced burial), the marker lines with each spot's
  coordinates and residues, `deaths = 0`, and an earlier analysed window from the same session
  showing 119 consecutive samples at the lodge yard with **zero** position change. The claim
  "nothing moved him" therefore rests on the absence of a rescue rather than on 480 logged
  positions. Round 2's three-cycle log (`t192b-after.log`, 2208 samples, none under the ground) is
  unaffected and still stands.
* **The shallow burial case.** See below.

## Where this differs from the dispatch, and why

The dispatch asked for `occupancy >= 0.5` and for a spec case "root embedded 3+ studs deep ->
buried". The measured profile makes those two incompatible with each other: at 3 studs deep the root
is in the cell the surface crosses, which reads **0.39-0.56** across the four columns -- so 0.5
decides that case by coin-flip, and anything low enough to catch it reliably also hands the surface
cell to a character standing on top of it, which is round 1's finding returning. The two-cell rule
answers FALSE at 3 studs deep for the same reason: there is open air over that body's head.

I implemented the dispatch's RULE (containing cell, plus the cell above) and changed its NUMBER
(0.75, measured), and the spec asserts burial at 10 / 17.5 / 24 studs instead of 3. The shallow case
is left to the placement rule that prevents it and to the engine, which ejects a body with air above
it rather than trapping it; the three real failures this net exists for were 4, 17.5 and 47.8 studs,
and the 4-stud one was a placement, now snapped. **If the Director wants 3 studs caught as well,
that is a different mechanism (the feet rather than the root, or a ray up from the body) and a
fourth round -- it is not a threshold tweak.**
