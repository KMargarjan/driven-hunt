# Task 328f -- C1's FOREST v2: the mask, the frontage, the 54-stud rides, the crown set-back

Task: 328f
Round: 2
Base: main `121eb5ce`
Code commit: `47f982c4db0d7de8f451c10766c5db2d89d00c3d`

`[harness] PASS: 34/34 checks @ 47f982c4db0d7de8f451c10766c5db2d89d00c3d (clean tree) scope=all`

`test2` is **N/A**: nothing here is on `TWO_PLAYER_PATHS`. **No terrain is written** -- the forest is
planted at boot behind `GRID_PREVIEW`. The live proof is in Karen's Forest Test **at this commit**,
by injection (`driven-hunt-runs/328f-plant.py` sends this branch's `src/shared/Places/init.luau` into
her PLAY server; the PLANTER is her place's own unchanged `Places.plantOne`). No port switch, nothing
checked out in `driven-hunt-karen`, nothing saved or published.

## Round 1's four findings, all four correct, all four fixed

1. **THE FERN FLOOR WAS PLANTING FULL-SIZE TREES.** Correct, and it was the worst thing in the task:
   `fernFloor` carries one row, `fern`, in no `frontage.groups`, so the rewrite dropped it and put the
   four TREE groups back -- a tree at the herb band's own 0.8-1.7 scale on the FLOOR's neighbour grid,
   where `minGapStuds` could not see it. `scatter` now gates the rewrite on the drawn band and
   `frontageRows` passes a ground-cover mix through untouched. **Verify:** "the fern floor is ferns"
   -- every herb-band item of every cell is `isHerbName` AND in a `FERN_MIXES` zone, plus the rule
   itself on `fernFloor` and `frontageGroupFor`. The relief bias also moved BEFORE the frontage, so a
   biased conifer at the roadside is re-drawn rather than refused (the density cost round 1's note
   named). Live: the 34-60 band now reads **fern 39**, which it could not before.
2. **`report.wanted` was a value compared with itself.** Correct. The case now also asserts the plan
   WITH a reader differs from the plan without one, so it fails if `dressCell` stops handing the
   reader through; and `grid_ground.spec` gains "the relief bias is a function of the ground, and it
   bites" -- two synthetic hillsides, two group histograms, `conifer` higher on the cold one and
   `birch` on the warm one, and the no-reader plan lower than both.
3. **The ride claims were unproven and `rideGap` was not independent.** Correct. "the rides are where
   the recipe says" asserts one segment per row, each endpoint against `Grid.standPosition` +
   `Places.standFacing` x `lengthStuds`, the X cut's midpoint at `CUT_CROSS_STUDS` and its
   perpendicularity, W9 and E14 at z 560 and 780, the two facings -- plus a COUNTED bite, so an empty
   `rides` row cannot pass.
4. **Six arms were deletable with the suite green.** Correct. One case per arm with its just-outside
   twin: the cone (near; the young-growth far band, same point and two templates; past it), a
   corridor on its own jittered centreline and 15 studs off, D1's field against its headland (and no
   planting inside it), a clearing. **`STAND` and `TOWER` are proven SUBSUMED** -- every stand sits on
   a road centreline (asserted, all 8 x 15) and the road's 34-stud band is wider than both clearances,
   so design 7.4's clearance is MET by a stronger rule; no planting of any cell is inside either.
   **`NO_TREES` is asserted as a declared reason with no recipe behind it** (the scarp is B2's, 328h's)
   rather than faked.

## What else round 2 found and fixed, measured

5. **`TEMPLATE_DIMS.scale` DISAGREES WITH THE LIVE TEMPLATE FOR 27 OF THE 35.** Round 2's first
   replant came back `crownOverRoad=1`: one `SM_AspenTree_Var04`, 3.17 studs over a road, planner
   reach 18.76 against the census's 30.58. The planner knows `item.scale` (relative to the template)
   and `GridCensus` divides `model:GetScale()` by `dims.scale`, so the two agree only while that row
   IS the template's own `GetScale()`. Measured in her place (`driven-hunt-runs/328f-dims.luau`,
   2026-11-03, 35 of 35 found): **27 disagree**, `live / row` from **0.589**
   (`Forest_OakTree_Var02_LOD_0`) to **1.371** (`SilverBirch_Var01_LOD_0`); that aspen is live 0.8081
   against the row's 0.6135. Re-measuring the table is **328b's and the Architect's** -- until then
   `Places.CROWN_SCALE_SLACK` 1.40 carries the worst ratio so the census's reach is always the one
   covered, and the spec asserts the slack is at least 1.371. **With it, `crownOverRoad` is 0.**
6. **`flags.spec` went red mid-task on `DRIVE_BOTS`' `expires = 2026-11-02`** when the UTC clock
   rolled over -- the tripwire doing its job, nothing 328f changed. Moved 21 days to `2026-11-23`
   with the reason the rule asks for: the flag is still ON as an override in her place and she has
   not judged the bots.
7. **The server runner went over its 300 s twice.** `Places.zoneRect` allocated a fresh table on
   every call and the mask asks `zoneAt` for every candidate, so it is memoised per (cell, zone) --
   both inputs frozen, and `forgetCells` drops it. `grid_ground.spec` works out each cell's plan once
   (`planOf`), except inside the quarantine fixture, which must ask while its stub is up.
   Measured after (`328f-cost.luau`, in her place): `plantCell` x 8 = **0.18 s** for 11,830 sites, an
   81 x 81 mask lattice = **0.02 s**. The two later timeouts were the Studio session, not the cases
   (the Play client went unreachable in the same runs); the clean PASS above is from a settled one.
8. **`Places.frontageAllows` took a TEMPLATE and was being asked with a GROUP**, so it answered false
   for every group and the "keep the zone's character" short-circuit never fired. `frontageAllowsGroup`
   is the group door; the template one goes through `groupOf`. Caught by the spec, asserted both ways.
   Also: `DITCH_STUDS` (read by nothing, and 22 where the mask uses 21) is gone with a note saying why
   the bands start at 21; `towerTopStuds` is a comment; the mask calls `fieldRect` and `corridorXAt`
   instead of inlining them; A2's larch plantation carries `rows = "NS"`, so that path has data and a
   case behind it.

## The live proof, BEFORE -> AFTER, same session, same instrument

```
[census] C1 ... trees=1999 ... foliageInGround=255 ... inRoad=0 ... crownOverRoad=88 refused=not-handed-in
[census] C1 ... trees=1364 ... foliageInGround=158 ... inRoad=0 ... crownOverRoad=0  refused=88+0/1452=6.1%
```
floating **0**, sunk **0**, tilted **0**, broken **0**, noGround **0**, onCliff **0** on both sides.
`crownOverRoad 88 -> 0`; `inRoad` 0; `refused 6.1 %` against the gate's 8 %; plan 1,452, planted 1,364,
**plant time 0.9 s**, plan 47 ms; 15 posts and 3 towers, and the boot's own
`[ForestTestBoot] grid preview cell C1: 15 of 15 post(s) (7 line), 3 tower(s) at {8,13,15}, line=true, complete=true`.
`nearestTrunkToRoad` **38.54 st**. Frontage band 34-60: **birch 37, young 29, fieldOak 7, aspen 1,
fern 39, and no conifer and no oak**; conifer returns at 60-100. Open space **30.59 %** of C1
(clearing-or-field alone 14.31 %) on 328a-notes (c)'s convention: a 10-stud lattice over 15,552 points
**strictly inside the cell**, counting every point the mask refuses with no template, so each road
strip counts only the part inside the cell. Letters: `A1=SSSSSSSTOOOSOOO B1=RRRRSSSOOOOTSOC
C1=SXXXVRRTLOOOTLT D1=FPPPPPFFTFTFFFC A2=RRRRRRTOOOCOOOC B2=RTRRRRROCOOOCSS C2=SSRRRSSSSOOSSTO
D2=RRRRRRROOCCTOOO`. **Attribute diff byte-identical**; her 15 flags untouched (L-101).

**Six eye-height frame pairs at this commit, all twelve shas distinct, each opened and described.**
G1 stand 4 on the main line: an oak and a spruce at ~15 st closed the view, now the nearest trunks are
~40 st back and you see through to the far wood. G2 tower 13's deck at 17.5: open birch-and-oak park
over the hill shoulder, nothing in the deck's face. G3 the V ride at stand 5: a clean 54-stud grass
ride running to the ridge, no crown over it. G4 the photo-match against `terrain-refs/Driven Hunt/
Screenshot 2026-10-16 123045.png` (layout, not colours): the carriageway runs clean to the horizon with
sky above it, the stakes visible at ~650 st and boar crossing it. **G6 is Q6's frame**: a wall of
mature spruce 18 st from the eye with crowns over the verge, now larch and birch poles at ~37 st with
the spruce behind. G5 is the same frontage down stand 2's OWN cone, which is why its near ground is
bare -- that is the cone, not the frontage.

## NOT MET, with the count and the cause

- **`foliageInGround` 255 -> 158, not 0.** A TEMPLATE fact no forest plan can move: five templates
  offend on EVERY instance (`LarchTree_Var02` 63/63, `Field_OakTree_Var07_LOD_0` 48/48, `_Var04` 44/44,
  `_Var06` 39/39, `_Var05` 30/30) because their foliage sits 0.12-1.83 studs BELOW the trunk box, and
  the seat then sinks the trunk by up to `SINK_STUDS` 0.6 against the census's `FOLIAGE_SINK_STUDS` 0.5.
  The rate is unchanged (12.8 % -> 11.6 %), which is the proof it is per-tree. Fixing it means changing
  the contact arithmetic or quarantining five templates, and design 1.2 item 2 forbids both here.
- **The far cone's "1 trunk per 900 sq st" is not implemented** (a density cap is not a per-point fact).
- **The painted 24-stud ride is not painted** -- terrain, and this task writes none.
- **The border wood is built and not planted** -- `Workspace.GridForest` is 328i's.
- **Design 8.5's no-two-adjacent-letters rule holds for no cell**, C1 included (7 distinct over 15, 5
  adjacent pairs). The design's answer is that a failing cell has its RECIPE changed and only C1's is
  in scope; the spec asserts >= 5 distinct for a cell carrying `rides` and >= 3 for every cell.
- **`StreamingMinRadius` 64 -> 384 is still Karen's**, unchanged and still listed.
