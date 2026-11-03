# Task 328m -- review request

Task: 328m
Round: 2
Base: 056f085c (main)
Code commit: 7ff5c4d3309da61e9046862cc30c651f9de5b4aa

`[harness] PASS: 34/34 checks @ 7ff5c4d3309da61e9046862cc30c651f9de5b4aa (clean tree) scope=all`
(`driven-hunt-runs/328m-harness4.txt`.) `test2` is **N/A**: nothing in `TWO_PLAYER_PATHS` is touched.

## What changed

Karen played C1 in her Forest Test on 2026-11-03 (`PLAYTEST.md`, verbatim).

1. **"those gates shouldnt be"** -- the 32 corner stakes of task 327a. `Places.STAKE`,
   `Places.gridStakes`, `Places.stakeGrid`, the `gridStakes` / `gridMissing` report fields and their
   `[ForestTestBoot] grid:` print are archived (rule 7) in
   `backups/2026-11-03_task-328m_Places-stakeGrid-and-grid-case-22.md`. `Places.GRID_FOLDER` stays --
   the cell's wood is dressed into it and `ForestTest.GROUND_IGNORE` names it.
2. **"has to be a bit more realistic more trees but rest is good"** -- a zone gains an optional
   `under` row (C1 only): a second, finer layer over the same rectangle, on its own stream, at the
   `shrub` band's scale, sharing the canopy's neighbour grid and `minGapStuds` so it clumps into
   the gaps. Per zone: `spruceThicket` / `mixedWood` / `birchStand` tighten 24/32/30 -> 21/28/27 AND
   take `under`; **`oakPark` takes neither**; the clearing takes nothing; the two `scrub` zones keep
   their spacing but DO take `jitter` 1.0, like every zone, so their sites move.

**Round 1's finding is fixed.** `oakPark` had an `under` row at 42 studs -- tighter than its own
44-stud canopy -- against its own header's reasoning. The row is dropped, and the header is rewritten
**per zone**, which is the shape the claim needed: round 1 said the two scrub zones were "untouched"
and they are not, because `jitter` 1.0 moves every one of their sites.

## Claims

1. **No stake is built any more, and `GridPlaces` still is.** `grep -rn "stakeGrid|Places.STAKE"
   src/ tests/` finds only the archive pointer and case 22's two `nil` assertions. Case 22 asserts
   the folder exists with the preview on, holds **0** children at build, and that `report.gridStakes`
   / `gridMissing` are **nil**. **LIVE**, the branch's own `Places.build` in her Play session at this
   commit: `stakes 32 -> 0`, `report{gridStakes=nil gridMissing=nil}`, `ForestMarkers` 16 children
   and `HighSeats` 3 untouched (`328m-rebuild2-AFTER.txt`).
2. **Nothing else tall and yellow/orange stands at C1's junctions or road ends.** `328m-BEFORE2-J1.png`
   vs `328m-AFTER2-J1.png`, the same camera (the `NS3`/`EW2` junction, eye 5.6 studs, gaze pinned
   level on BOTH sides so the pair is one camera). Both looked at: BEFORE, four glowing yellow
   pillars stand across the road at ~400 studs, two either side of the carriageway, taller than the
   spruce wall behind them. AFTER, they are gone; the same spruce wall, the same rutted road, the
   same far stand frame on the skyline, and no other tall coloured object anywhere in the frame.
   Descendant scan: `stakesInWorkspace=0` (`328m-census2-AFTER.txt`).
3. **`oakPark` is untouched, and that is measured, not asserted.** `328m-yield-v4.txt`: `oakPark
   sp=44 cap=120 got=76 | under sp=nil cap=0 got=0`, against round 1's `sp=44 ... got=76 | under
   sp=42 cap=132 got=62`. Its canopy count is the SAME 76 either way -- the understorey ran after
   the zone loop on the shared grid and displaced nothing.
4. **The understorey is data and it plants.** `Zone.under`, `Places.CELL_STREAM.under`,
   `Places.UNDER_JITTER`, and the loop in `Places.plantCell` after the zone loop. C1's `shrub` band
   goes **317 -> 457** planted (`328m-census2-BEFORE.txt` / `-AFTER.txt`). Case 12a asserts
   `saplings > 381` -- the two scrub zones alone hold 381 sites -- so it reddens the moment that loop
   is deleted (L-093); with the loop it reads 452.
5. **It is counted in design 8.3's bound.** `cellCapacity` adds the `under` grid: C1
   **2,598 -> 3,416**, 184 under the 3,600 the case asserts (round 1 left 52). Case 12a asserts
   `cellCapacity("C1") == zones + under + ferns + skirt` from its own arithmetic.
6. **The gap rule has no seam.** Case 12a re-buckets C1's whole non-herb list and asserts the closest
   pair is **>= 12**; measured 12.06 (`328m-yield-v4.txt`). Its own grid or its own gap reddens it.
7. **MEASURED IN HER PLACE AT THIS CODE COMMIT, one boot, same probe both sides** (`328m-plant.py`,
   `--raw` = the place's own modules = main). **Every counter the census emits**:
   `trees` 1433 -> 1687 · `parts` 4338 -> 5104 · `floating` 0 -> 0 · `sunk` 0 -> 0 ·
   `foliageInGround` **62 -> 65** · `tilted` 0 -> 0 · `broken` 0 -> 0 · `noGround` 0 -> 0 ·
   `inRoad` 0 -> 0 · `inStand` 0 -> 0 · `inLane(other-world)` **81 -> 98** · `onCliff` 0 -> 0 ·
   `crownOverRoad` 0 -> 0 · `crownUnmeasured` 0 -> 0 · `refusedCliff` 118 -> 122 ·
   `refusedSkipped` 0 -> 0 · `refusedWanted` 1551 -> 1809 · `refusedPct` **7.61 % -> 6.74 %** ·
   `worstHigh` 0.0000153 -> 0.0000153 · `worstSink` 0.600 -> 0.600 · `laneHalf` 21 -> 21.
   Plant: `planMs` 43 -> 46, `plantSeconds` 1.1 -> 1.4, `capacity` 2598 -> 3416.
   **The two that rose**, named rather than left out: `foliageInGround` +3 is 328l's known residue
   (the three `Field_OakTree` variants) and FELL as a fraction, 4.33 % -> 3.85 %; `inLane` is
   labelled in `GridCensus` itself as *"NOT a cell defect"* -- the legacy line places' stripe across
   the whole world, retired at 327d -- and it scales with the count.
8. **`refused` went DOWN, and that was the one real risk here (L-041).** 7.61 % -> 6.74 % against the
   8 % gate: 118 -> 122 cliff refusals against a want of 1551 -> 1809, because the added sites are in
   the cell's gentler interior. **The gate's threshold and `SCOPE_SPECS` are untouched**; had it gone
   over, the fix would have been more plant sites, never the gate.
9. **The seven other cells are byte-identical.** `328m-cap-BEFORE.txt` vs `328m-cap-AFTER.txt`:
   A1, B1, D1, A2, B2, C2, D2 report the same `cap` and the same `plan` count on both sides. Case 12a
   asserts C1 is the only cell carrying an `under` row.
10. **The new density, at eye height, looked at.** `328m-{BEFORE2,AFTER2}-{S1,W1}.png`, same cameras.
    **S1** (stand 5, looking north up the V ride): BEFORE, scattered trunks on an unbroken lawn and
    the far hillside visible between every pair; AFTER, the flanks close into a wall of conifer with
    small spire-shaped larches among them, the hillside is now screened except straight up the ride,
    and the 54-stud ride itself is still open from the post to the skyline. **W1** (inside the birch
    stand, looking west): BEFORE, ~14 bare trunks with the ground visible all the way out; AFTER,
    more trunks plus three or four conical young larches standing BETWEEN them at mid-ground -- a
    second storey where there was none. The floor is still grass in both: the fern layer is
    unchanged (50 planted, design 8.2's Krautsaum, cap 400).
11. **Posts, towers and the boot are clean.** Her boot line: `grid preview cell C1: 15 of 15 post(s)
    (7 line), 3 tower(s) at {8,13,15}, line=true, complete=true`; `places: 3 dressed, 3727 planted
    (9105 parts), ... 9.92s`; and **0** lines matching `Stack Begin|attempt to|invalid argument` in
    the whole console, before and after (`328m-console2-BEFORE.txt`, `328m-console2-AFTER.txt`).
12. **No terrain write, and her place is untouched.** The probes raycast `Workspace.Terrain` and
    never write it; `ServerStorage`'s 19 attributes are byte-identical before and after (same md5,
    `328m-attrs2-BEFORE.clean` / `-AFTER.clean`), the Edit place holds no `GridPlaces` and no stake
    afterwards, nothing was checked out in `driven-hunt-karen`, and her place was never saved,
    published or committed.

## What I could not verify

- **Whether the new density reads as "realistic" to Karen.** That is hers (`## Needs Karen`).
- **The pre-328f count of ~2,019 is not reached and cannot be** from this ground: 1,687 is +17.7 %,
  and four allocations of the same budget all land at ~1,823-1,886 planned
  (`328m-yield-v{1,2,3,4}.txt`). What refuses the rest is `Places.mask` -- the rides, cones,
  corridors and frontage Karen accepted -- and `minGapStuds` 12, not the grid. Going further needs a
  design number to move: the < 3,600 model bound, whose derivation assumes 7 parts per model against
  a measured 3.03 (5,104 parts for 1,687 models), or the 12-stud gap, which these 20-80-stud crowns
  already interpenetrate. **Neither was touched here**; both are for the Director and the Architect.
- Round 1's remaining notes outside the files this change touches (`Flags.GRID_PREVIEW.why`,
  `ForestTest.GROUND_IGNORE`'s header, `tools/studio_mcp.py`'s two scope comments, and the two
  design-doc appends) are queued in `TASKS.md`, not fixed here.
