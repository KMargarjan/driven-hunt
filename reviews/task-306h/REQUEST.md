# Task 306 step B8 -- her place: the six-station range by the lodge, the terrace, the berm

Task: 306h
Round: 1
Base: task-306b7-occupancy (c2cb8437), with origin/main (09d61ff0) merged in
Code commit: aebfffca95d36676fa6cd34c9e6753f51278c58e

```
[harness] PASS: 34/34 checks @ aebfffca95d36676fa6cd34c9e6753f51278c58e (clean tree) scope=all
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

Evidence is in the runs dir: `evidence/306b8/` (the frames) and the probes `306b8-*.luau`.

## Claims

1. **The site was re-censused in HER place before anything was laid**, in Edit and in Play.
   Edit: 990 samples at 8 studs over design 2.2's footprint, 0 missed, 0 non-terrain ground hits,
   **0 BaseParts**, ground spread **33.0** studs and **23.52** across the firing line.
   Play: 1023 samples, 0 missed, 120 BaseParts -- Range 102, Lobby 15, DrivePlaces 3, and the
   Lobby/DrivePlaces entries are tree CROWNS at x >= 2765; no trunk, no truck pad, and neither the
   flagpole nor a birch of task 311 is inside. *Verify:* `306b8-census.luau`, `306b8-proof.luau`.

2. **The terrace is flat where a man stands.** Measured in Play against the surface the engine
   DRAWS, with the range's own parts excluded (they are not ground): the firing-line strip
   x 2592..2728 z -3040..-3016 reads **spread 0.00** (natural: 23.52). The whole terrace, 2375
   samples at 4 studs, heaps excluded: **spread 1.07** (natural: 33.0), 0 sky/near disagreements.
   *Verify:* `306b8-flat.luau`. Every sample casts a second ray from 6 studs above the first hit,
   so no number here comes from a ray that fell through a roof or a canopy (L-025).

3. **The level comes from the LODGE, not from the ground under the range.** `shelfFrom` is the
   lobby's anchor, read through the same `ForestTest.groundAt` and floored to the voxel grid:
   shelf **148**, drawn surface **150.00**, the same number the lodge yard reads. The ground under
   the range anchor is 134.9, which would have cut a 16-stud cliff across her path.
   *Verify:* `Build.shelfAt`; `range.spec` "takes its level from the LOBBY and lands on the same
   number a second time" (flooring is a fixed point -- task 311's finding, re-entered here).

4. **T7: nobody is sent home.** `Join.insideHome` is true at all 6 mats, all 6 stands, the berm
   crest, the lodge door and every 8 studs along both walk legs: **0 of the sampled points are not
   home**, 3 home rectangles. `ForestTestBoot.rangeHomeAreas` follows the row and nothing was
   edited there. One consequence is measured rather than assumed: `Join.walkwayTo`'s corridor is
   now wholly inside the field-plus-footprint union, so `lobby.spec`'s per-rectangle boundary case
   was taught to PROVE containment instead of demanding an edge.
   *Verify:* `306b8-proof.luau`; `lobby.spec`.

5. **T6: no shot leaves the range.** 180 rays -- 6 stations x 2 eye heights (bench shelf+5, deck
   shelf+17.5) x 3 lanes x 5 points across the window -- **180 stopped at or before the berm, 0
   escaped**. *Verify:* `306b8-proof.luau`.

6. **T1, walked with a real held W, not computed.** Lodge door (2850, -2916) to mat 6:
   **169.65 studs in 13.57 s**, ending at (2720.1, 154.1, -3030.0), on the mat. Mat 6 to mat 1:
   **115.24 studs in 10.43 s**. Target: at most 208 studs and 20 s. Nothing blocked either walk,
   so the terrace seam at the lobby's edge is walkable.
   *Verify:* `306b8-walk6.luau` / `306b8-walk1.luau` with `298key.ps1 w`; the held look aims the
   camera first, because movement is camera-relative and a W into an unaimed camera walks north
   (it did, 14.8 studs, on the first attempt).

7. **A real E at station 1 opens the menu** (`evidence/306b8/f5-menu-view.png`, looked at): ANIMAL
   boar/reddeer, KIND, PACE with all six rows, WEAPON, CARTRIDGE, DISTANCE 107/125/179 studs
   (30/35/50 m), RELEASE THE TARGET, and THE BOARD with its zone columns.
   *Verify:* `298key.ps1 e` after one focusing click.

8. **The berm is a battered heap with one level crest, and the banks stand on the flat.** Crest
   **160.02** at every x from 2548 to 2772 -- **10.02 studs proud**, Karen's "not high". Its
   uprange face measures 159.3 / 157.0 / 154.3 / 152.8 / 151.5 / 150.0 over 15 studs: a slope, not
   a wall. Both banks read **8.00 proud**. `FillWedge` was NOT used: its orientation is UNVERIFIED
   (design section 14) and design 8.2 names the stepped stack as the decided fallback.
   *Verify:* `306b8-flat.luau`; `Build.bermBoxes`; `range.spec` "fills a berm with a battered
   uprange face and ONE level crest".

9. **The terrace never touches the lobby's ground.** `keepOut` is asserted to BE the lobby field's
   west and south edges, computed from `Lobby.CONFIG.FIELD` and not retyped, and the two terrace
   rectangles' overlap with that field is asserted **0**. The cut is also clamped to the range's
   own footprint, so it writes no ground outside the box her return rule calls home.
   *Verify:* `range.spec` "stops the terrace at the lobby field's own edge, read off Lobby and not
   retyped"; `Range.cutRects`.

10. **DEV writes no terrain, the old site is archived, and design 8.3's surface pair was refuted
    by the picture.** The spec hands the DEV row a recording fake terrain and asserts **0 fills,
    0 replaces** -- with the `fillsTerrain(row)` guard dropped, the DEV arm would cut a 232-stud
    terrace into the place the harness itself runs in. `backups/task-306b8/` holds the B6 row and
    the whole "OVERFLOWS the clearing" case, each with a note (rule 7). **The deviation:** design
    8.3 chose a `Grass` lane against a `LeafyGrass` surround. Measured, her hill is ALREADY
    `Grass`, so there is no contrast; photographed, `Grass` blades fill the entire frame from a
    man's eye on the bench -- no lane, no berm, no range (`f6-berm-view.png`, the before). The
    lane is therefore blade-free `Ground`, which is exactly why `Lobby.CONFIG.FIELD.PADS` uses it,
    and `AROUND` is now what her hill measures as. After: `f6b-berm-view.png`, `f2b-lane1-view.png`.

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

- **The rail board is not visible in the deck frame.** Design 11.5 item 3 asks for "the rail board
  below the gun and the berm beyond it"; the held-look camera sits above the rail. The berm is
  there, the rail is not shown.
- **Items 4 and the second half of 5 belong to B9**, not to this step.
- **The lane is now bare earth over 232 x 168 studs.** Blade-free and clean, which is what Karen
  asked for, but EARTH and not mown grass. That is a look call only Karen can make, and it is one
  value: `LAYOUT.SURFACE.LANE`.
- `Range.stats()` could not be read live: `execute_luau` gets a FRESH module instance, so its
  counters read 0. Every number above is an INSTANCE fact -- a ray, a part, a position, a clock.
