# Task 306 step B8 -- her place: the six-station range by the lodge, the terrace, the berm

Task: 306h
Round: 2
Base: task-306b7-occupancy (c2cb8437), with origin/main (09d61ff0) merged in
Code commit: 477e67651d1123e593fa3f996cad77f3acfa63ce

```
[harness] PASS: 34/34 checks @ 477e67651d1123e593fa3f996cad77f3acfa63ce (clean tree) scope=all
```

`test2` is **N/A**: no changed path is in `TWO_PLAYER_PATHS` (`src/shared/Range/`,
`src/server/Range/`, `src/server/RangeBoot.server.luau`, `tests/server/range.spec.luau`,
`tests/server/lobby.spec.luau`). The range is the weapon/boar/hud lane.

## Round 1's finding, and what the fix found

**Finding 1 was right and the first two fixes for it were also tautologies. The third was measured
false. The fourth is what shipped.**

Round 1's blocking finding: my replacement for `expect(here > 0)` re-asked `Join.insideHome(at,
areas)` of the same points and asserted the loop's own exit condition. The Reviewer's suggested
shape -- ask the union of the OTHER rectangles -- **is the same question**: every point in `outs`
lies one stud outside rectangle `index` by construction, so rectangle `index` can never be the one
covering it, and `insideHome(at, areas)` and `insideHome(at, others)` are identical for those
points. I then wrote "the others cover its whole area", and **the harness measured it false**
(`lobby.spec:1048`, run at `c7da7586`): the walkway is NOT redundant -- it carries ground the field
and the range footprint do not.

So **claim 4 of round 1 was wrong** and is withdrawn. What shipped is the rule that is both true
and able to fail: **a rectangle must contribute a BOUNDARY of the union, or GROUND of its own.**
`here > 0` is the first; a 5 x 5 grid over the rectangle's own area, with at least one point that
`others` does not cover, is the second.

**FAIL FIRST, run:** commit `0ac23f15` added one far-away rectangle (x 9000..9100, z 9000..9100)
that has no boundary case and no ground anyone else covers -- `[harness] FAIL: 32/34 checks @
0ac23f15a09a05f11b006cc3470c917ee34bfcb0 (clean tree) scope=all`, reddening `lobby.spec:1052`,
inside that grid. Reverted at `c7da7586`.

## What changed

The `forest-test` row moves from (2650, -3216) -- chosen in B6 for ONE station -- to design 2.1's
(2600, -3030) beside the lodge, and gains four data fields: `berm = "terrain"`, `fill = true`,
`shelfFrom` and `keepOut`. `Range.Build` gains the injected `terrain` seam design 8.2 reserved and
writes the terrace, the berm and the two banks as ground. DEV is untouched: its row says
`fill = false, berm = "parts"` and no spec writes a place's terrain.

Evidence is in the runs dir: `evidence/306b8/` (the frames) and the probes `306b8-*.luau`.

## Claims

1. **The site was re-censused in HER place before anything was laid.** Edit, before any build:
   990 samples at 8 studs over design 2.2's footprint, 0 missed, 0 non-terrain ground hits,
   **0 BaseParts**, ground spread **33.0** studs and **23.52** across the firing line. A second
   census ran in Play, **after** the build (round 1's note is taken): 1023 samples, 0 missed,
   120 BaseParts -- Range 102, Lobby 15, DrivePlaces 3, the Lobby/DrivePlaces entries being tree
   CROWNS at x >= 2765; no trunk, no truck pad, and neither the flagpole nor a birch of task 311
   is inside. *Verify:* `306b8-census.luau`, `306b8-proof.luau`.

2. **The terrace is flat where a man stands.** Measured in Play against the surface the engine
   DRAWS, with the range's own parts excluded (they are not ground): the firing-line strip
   x 2592..2728 z -3040..-3016 reads **spread 0.00** (natural: 23.52). The whole terrace, 2375
   samples at 4 studs, heaps excluded: **spread 1.07** (natural: 33.0), 0 sky/near disagreements.
   *Verify:* `306b8-flat.luau`. Every sample casts a second ray from 6 studs above the first hit,
   so no number comes from a ray that fell through a roof or a canopy (L-025).

3. **The level comes from the LODGE, not from the ground under the range.** `shelfFrom` is the
   lobby's anchor, read through the same `ForestTest.groundAt` and floored to the voxel grid:
   shelf **148**, drawn surface **150.00**, the same number the lodge yard reads. The range
   anchor's own ground reads **134.87**, which snaps to **132** -- a 16-stud step across her path.
   (Round 1's note is taken: one measured number, now used in both comments and here.)
   *Verify:* `Build.shelfAt`; `range.spec` "takes its level from the LOBBY and lands on the same
   number a second time" (flooring is a fixed point -- task 311's finding, re-entered here).

4. **T7: nobody is sent home.** `Join.insideHome` is true at all 6 mats, all 6 stands, the berm
   crest, the lodge door and every 8 studs along both walk legs: **0 of the sampled points are not
   home**, 3 home rectangles. `ForestTestBoot.rangeHomeAreas` follows the row and nothing was
   edited there. The walkway rectangle now contributes no boundary case but does carry its own
   ground, which is what `lobby.spec` asserts (above). *Verify:* `306b8-proof.luau`; `lobby.spec`.

5. **T6: no shot leaves the range.** 180 rays -- 6 stations x 2 eye heights (bench shelf+5, deck
   shelf+17.5) x 3 lanes x 5 points across the window -- **180 stopped at or before the berm, 0
   escaped**. These are COMPUTED rays, not a trigger pull: see "What I could not verify".
   *Verify:* `306b8-proof.luau`.

6. **T1, walked with a real held W, not computed.** Lodge door (2850, -2916) to mat 6:
   **169.65 studs in 13.57 s**, ending at (2720.1, 154.1, -3030.0), on the mat. Mat 6 to mat 1:
   **115.24 studs in 10.43 s**. Target: at most 208 studs and 20 s. Nothing blocked either walk,
   so the terrace seam at the lobby's edge is walkable.
   *Verify:* `306b8-walk6.luau` / `306b8-walk1.luau` with `298key.ps1 w`; the held look aims the
   camera first, because movement is camera-relative and a W into an unaimed camera walks north
   (it did -- 14.8 studs, on the first attempt).

7. **A real E at station 1 opens the menu** (`evidence/306b8/f5-menu-view.png`, looked at): ANIMAL
   boar/reddeer, KIND, PACE with all six rows, WEAPON, CARTRIDGE, DISTANCE 107/125/179 studs
   (30/35/50 m), RELEASE THE TARGET, and THE BOARD with its zone columns.

8. **The berm is a battered heap with one level crest, and the banks stand on the flat.** Crest
   **160.02** at every x from 2548 to 2772 -- **10.02 studs proud**, Karen's "not high". Its
   uprange face measures 159.3 / 157.0 / 154.3 / 152.8 / 151.5 / 150.0 over 15 studs: a slope, not
   a wall. Both banks read **8.00 proud**. `FillWedge` was NOT used: its orientation is UNVERIFIED
   (design section 14) and design 8.2 names the stepped stack as the decided fallback -- **four
   2-stud bands** (`10 * k / 5`), which round 1's note corrected in both comments.
   *Verify:* `306b8-flat.luau`; `Build.bermBoxes`; `range.spec` "fills a berm with a battered
   uprange face and ONE level crest".

9. **The terrace never touches the lobby's ground.** `keepOut` is asserted to BE the lobby field's
   west and south edges, computed from `Lobby.CONFIG.FIELD` and not retyped, and the two terrace
   rectangles' overlap with that field is asserted **0**. The cut is also clamped to the range's
   own footprint, so it writes no ground outside the box her return rule calls home.
   *Verify:* `range.spec` "stops the terrace at the lobby field's own edge, read off Lobby and not
   retyped"; `Range.cutRects`.

10. **DEV writes no terrain, the old site is archived, and design 8.3's surface pair was refuted
    by the picture.** The spec hands **the shipped `map:v1` row** (round 1's note: it was the local
    fixture, which exercised only the readers' defaults) a recording fake terrain and asserts
    **0 fills, 0 replaces** -- with the `fillsTerrain(row)` guard dropped, the DEV arm would cut a
    232-stud terrace into the place the harness itself runs in. `backups/task-306b8/` holds the B6
    row and the whole "OVERFLOWS the clearing" case, and **`backups/README.md` now carries their
    row** (round 1's note; claim 10 of round 1 overstated this and it is now true).
    **The deviation:** design 8.3 chose a `Grass` lane against a `LeafyGrass` surround. Measured,
    her hill is ALREADY `Grass`, so there is no contrast; photographed, `Grass` blades fill the
    entire frame from a man's eye on the bench -- no lane, no berm, no range (`f6-berm-view.png`,
    the before). The lane is therefore blade-free `Ground`, which is exactly why
    `Lobby.CONFIG.FIELD.PADS` uses it. After: `f6b-berm-view.png`, `f2b-lane1-view.png`.
    Escalated for the Architect in `ESCALATE.md`.

## The frames, looked at

- `f1b-line-view.png` -- from the lodge's side along the firing line: six treestands receding, the
  benches, posts and mats on a pale strip at their feet, and the terrace edge stepping down out of
  the tall grass on the left.
- `f2b-lane1-view.png` -- station 1, shotgun in hand, bench and post ahead, the clean lane running
  away flat, and the berm a continuous low earth bank across the far end with hills behind. A
  released target is visible out on the lane.
- `f3b-deck4-view.png` -- from the deck at station 4: the whole lane and the berm's lit face.
- `f6b-berm-view.png` -- the berm and the banks from the firing line.
- `f5-menu-view.png` -- the open menu and the board (claim 7).

## What I could not verify

- **No shot was fired, by anyone, at anything** (round 1's note, stated here so nothing reads as
  rule 5 having been met for shooting). Claim 5 is 180 computed rays, not a trigger pull, and this
  step makes no animal-behaviour claim. That is B9's work.
- **The rail board is not visible in the deck frame.** Design 11.5 item 3 asks for the rail board
  below the gun with the berm beyond it; the held-look camera sits above the deck rail.
- **`Flags.ROWS.RANGE.default` is false** (expires 2026-11-17) and `Range.ENABLED` gates the whole
  boot, so as shipped this terrain write reaches nobody until the flag flips. Her Forest Test has
  the override ON, which is why every measurement above exists.
- **The lane is now bare earth** over the terrace's two rectangles -- 232 x 168 (x 2544..2776,
  z -3228..-3060) plus 196 x 60 (x 2544..2740, z -3060..-3000), 228 studs deep in all (round 1's
  note corrected the single figure). Blade-free and clean, which is what Karen asked for, but
  EARTH and not mown grass: a look call only she can make, and it is one value,
  `LAYOUT.SURFACE.LANE`.
- `Range.stats()` could not be read live: `execute_luau` gets a FRESH module instance, so its
  counters read 0. Every number above is an INSTANCE fact -- a ray, a part, a position, a clock.
- **Queued, not fixed** (round 1's notes that are real work): `Range.cutRects`' grid snapping is
  hard-coded for `downrange = -1` and is backwards at `+1` (latent -- no shipped row is
  `fill = true` with `+1`); `Build.cutBoxes`' own floor is dead because `shelfAt` already floored;
  `SURFACE.LINE_BACK_STUDS` 14 reaches the deck's CENTRE so the uprange half of each deck stands
  off the gravel; and design 8 now contradicts the code in four places and needs its own task.
