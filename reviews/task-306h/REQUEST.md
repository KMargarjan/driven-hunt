# Task 306 step B8 -- her place: the six-station range by the lodge, the terrace, the berm

Task: 306h
Round: 1
Base: task-306b7-occupancy (c2cb8437), with origin/main (09d61ff0) merged in
Code commit: 6530b1594f598fc0f067850a9861bf323313056c

```
[harness] PASS: 34/34 checks @ 6530b1594f598fc0f067850a9861bf323313056c (clean tree) scope=all
```

`test2` is **N/A**: no changed path is in `TWO_PLAYER_PATHS` (`src/shared/Range/`,
`src/server/Range/`, `src/server/RangeBoot.server.luau`, `tests/server/range.spec.luau`,
`tests/server/lobby.spec.luau`). The range is the weapon/boar/hud lane.

## What changed

The `forest-test` row moves from (2650, -3216) -- chosen in B6 for ONE station -- to design 2.1's
(2600, -3030) beside the lodge, and gains four data fields: `berm = "terrain"`, `fill = true`,
`shelfFrom` and `keepOut`. `Range.Build` gains the injected `terrain` seam design 8.2 reserved and
writes the terrace, the berm and the two banks as ground. DEV is untouched: its row says
`fill = false, berm = "parts"` and no spec writes a place's terrain.

## Claims

1. **The site was re-censused in HER place before anything was laid**, in Edit and in Play.
   Edit: 990 samples at 8 studs over design 2.2's footprint, 0 missed, 0 non-terrain ground hits,
   **0 BaseParts**, ground spread **33.0** studs and **23.52** across the firing line.
   Play: 1023 samples, 0 missed, 120 BaseParts (Range 102, Lobby 15, DrivePlaces 3 -- all lobby
   tree crowns at x >= 2765, no trunk and no pad inside).
   *Verify:* `evidence/306b8/census.txt`, `profile.txt`, `proof.txt` in the runs dir; probes
   `306b8-census.luau`, `306b8-profile.luau`, `306b8-proof.luau`.

2. **The terrace is flat where a man stands.** Measured in Play against the surface the engine
   DRAWS, with the range's own parts excluded (they are not ground): the firing-line strip
   x 2592..2728 z -3040..-3016 reads **spread 0.00** (natural: 23.52). The whole terrace, 2375
   samples at 4 studs, heaps excluded: **spread 1.07** (natural: 33.0), 0 sky/near disagreements.
   *Verify:* `306b8-flat.luau`; the reader starts a second ray 6 studs above the first hit (L-025).

3. **The level comes from the LODGE, not from the ground under the range.** `shelfFrom` is the
   lobby's anchor, read through the same `ForestTest.groundAt` and floored to the voxel grid, so
   the range terrace and the lodge yard are one terrace: shelf **148**, drawn surface **150.00**,
   the same number the lodge yard reads. The walk door -> gather corner -> mat 6 is level the whole
   way (worst 8-stud step 1.00 once the lodge roof's own ray is excluded).
   *Verify:* `Build.shelfAt`; `range.spec` "takes its level from the LOBBY and lands on the same
   number a second time" (the floor is a fixed point -- task 311's finding).

4. **T7: nobody is sent home.** `Join.insideHome` is true at all 6 mats, all 6 stands, the berm
   crest, the lodge door and every 8 studs along both walk legs: **0 of the sampled points are not
   home**, 3 home rectangles. The range footprint follows the row through
   `ForestTestBoot.rangeHomeAreas`; nothing was edited there.
   *Verify:* `306b8-proof.luau` ("T7: 0 ... NOT home").

5. **T6: no shot leaves the range.** 180 rays -- 6 stations x 2 eye heights (bench shelf+5, deck
   shelf+17.5) x 3 lanes x 5 points across the window -- **180 stopped at or before the berm, 0
   escaped**.
   *Verify:* `306b8-proof.luau` ("T6: 180 shots ... 180 stopped ... 0 not").

6. **T1: the walk is inside budget.** Lodge door -> mat 6: **172.9** studs straight, **186.7**
   round the gathering yard, against the 208-stud / 20-s target at her measured 10.4 studs/s =
   **17.9 s**. The real held-W walk is **NOT DONE** (see "What I could not verify").

7. **The berm is a battered heap with one level crest, and the banks stand on the flat.** Crest
   **160.02** at every x from 2548 to 2772 -- **10.02 studs proud** of the terrace, Karen's "not
   high". Its uprange face measures 159.3 / 157.0 / 154.3 / 152.8 / 151.5 / 150.0 over 15 studs:
   a slope, not a wall. Both banks read **8.00 proud**.
   *Verify:* `306b8-flat.luau`; `Build.bermBoxes`; `range.spec` "fills a berm with a battered
   uprange face and ONE level crest".

8. **The terrace never touches the lobby's ground.** `keepOut` is asserted to BE the lobby field's
   west and south edges, computed from `Lobby.CONFIG.FIELD` and not retyped, and the two terrace
   rectangles' overlap with that field is asserted **0**. The cut is also clamped to the range's
   own footprint, so it writes no ground outside the box her return rule calls home.
   *Verify:* `range.spec` "stops the terrace at the lobby field's own edge, read off Lobby and not
   retyped"; `Range.cutRects`.

9. **DEV writes no terrain, and that case bites.** The spec hands the DEV row a recording fake
   terrain and asserts **0 fills and 0 replaces** -- with the `fillsTerrain(row)` guard dropped,
   the DEV arm would cut a 232-stud terrace into the place the harness itself runs in. DEV's berm
   and both banks are still parts.
   *Verify:* `range.spec` "writes NOTHING without a terrain, and nothing at all on the DEV row
   that has one".

10. **The old site is archived, not deleted (rule 7).** `backups/task-306b8/` holds the B6
    `Range.ANCHORS` block and the whole "OVERFLOWS the clearing" case, each with its note. The
    replacement case asserts the opposite claim with the same instrument.
    *Verify:* `backups/task-306b8/`; `range.spec` "FITS the rectangle the B8 census measured".

## What I could not verify

- **The six screenshots of 11.5 are NOT done.** `ftplay.py capture` ignores the camera during Play
  (it returned the player's own lodge view four times); the `DHTestLook` + `shot.ps1` route works
  and produced **one** frame -- station 1, standing on the mat, looking down lane 1
  (`evidence/306b8/f2-cropC.png`): the man is on the firing line with his bench and post in front of
  him and the lane running away flat and green to the horizon. **The berm is not identifiable in
  that frame** and I did not get a frame from behind the line, from a deck, or of the berm and
  banks. Items 1, 3 and 6 are unproven on screen.
- **The real held-W walk (the click proof) was not run**, so T1 is arithmetic plus a level ground
  profile, not a measured walk.
- **"Mown" is not proven as a contrast.** The lane is `Grass`; the ground immediately outside the
  terrace at (2800, -3120) is **already `Grass`**, not `LeafyGrass`, so the short-beside-long device
  design 8.3 relies on has nothing to read against there. The firing line IS `Limestone`
  (measured at (2660, -3030)).
- `Range.stats()` could not be read live: `execute_luau` gets a FRESH module instance, so its
  counters read 0. Every number above is an INSTANCE fact (a ray, a part, a position).
