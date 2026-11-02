# Task 328f -- C1's FOREST v2: the mask, the frontage, the 54-stud rides, the crown set-back

Task: 328f
Round: 1
Base: main `121eb5ce`
Code commit: `fee478b9893600a054c3df6761556b2d7c8375e6`

`[harness] PASS: 34/34 checks @ fee478b9893600a054c3df6761556b2d7c8375e6 (clean tree) scope=all`

`test2` is **N/A**: nothing here is on `TWO_PLAYER_PATHS` (`src/shared/Places/`, `src/server/Places/`,
`tests/server/grid.spec.luau`, `tests/server/grid_ground.spec.luau`, `GAME_DESIGN.md`).
**No terrain is written by this task** -- the forest is planted at boot behind `GRID_PREVIEW`.

**The live proof is in Karen's Forest Test at this commit, by INJECTION** (`driven-hunt-runs/328f-plant.py`:
the branch's `src/shared/Places/init.luau` is sent into her PLAY server as `INJECTED_Places`, and the
PLANTER is her place's own unchanged `Places.plantOne`). No port switch, nothing checked out in
`driven-hunt-karen`, nothing saved or published.

## Claims

1. **`Places.mask` is in `src/shared/Places/`, not `Grid`** (design 8.2, the require cycle), and it is
   pure -- no Instance, no raycast, no terrain. `Places.REASON` holds the design's fifteen names and
   `Places.REASON_ORDER` is the order as a TABLE, outermost fact first. Two of the fifteen are named
   as reasons a pure mask can never return -- `CLIFF` (terrain; `plantOne`'s own refusal) and `GAP`
   (the min-gap rule, `scatter`'s neighbour grid) -- in `Places.REASON_NOT_MASKED`.
   *Verify:* `grid_ground.spec`, "the mask refuses for the right reason, in the stated order" -- the
   second case walks a 41 x 41 lattice of C1 and asserts neither reason ever comes back.
2. **The road cross-section tiles [0, 34] in three named bands** and **no trunk of any cell stands
   inside it**. *Verify:* `grid_ground.spec`, "no trunk stands in a road or a ride" -- `roadGap` is
   the spec's OWN loop over `Grid.roads()`, not the mask, over `plantCell` of all eight cells; the
   second case then asks the mask the same question point for point over a 61 x 61 lattice.
   Measured in her place: `nearestTrunkToRoad=37.50 st`, and the 0-34 band holds **nothing**
   (`driven-hunt-runs/328f-frontage.txt`).
3. **The ride is 54 studs trunk-free** (design 7.3) and a ride runs from its stand along that stand's
   facing; an X cut runs across the sight line at the cone's far edge. C1 carries the four rides
   SWARM_DESIGN 2.2 names -- V at stand 5 (700 st), X at stand 3, L at W9 and E14 -- and
   `Grid.standPosition` puts W9 and E14 at z 560 and 780, the two depths that table names.
   *Verify:* the same two cases, through `rideGap`; and frame `328f-AFTER-G3.png`.
4. **THE CROWN TERM, AND ITS ONE DELIBERATE DEVIATION FROM DESIGN 7.2.** The design writes
   `halfCrown * scale + 10`, taking 10 from the painted carriageway. **That cannot reach the census's
   own zero**: `GridCensus.crownOverRoad` counts a tree inside `roadClearStuds / 2` (21) PLUS its
   crown reach, so a set-back of `crown + 10` still counts. MEASURED in her place at `121eb5ce`
   before this task: **crownOverRoad 88** of 1,999 trees, worst overhang **22.77 studs**, in every
   group (conifer 29, birch 24, aspen 16, oak 7, young 3, fieldOak 2). So the base is the census's
   own 21 plus `Places.CROWN_DRIFT_STUDS` **10**, which is also measured -- `plantOne` places the
   model's PIVOT and moves it in Y only, and over C1's 1,999 trees the pivot-to-trunk-centre drift is
   mean 0.746, **worst 9.273** (`SM_AspenTree_Var04`), `driven-hunt-runs/328f-offset.luau`. It is
   strictly stronger than design 7.2 and costs about 5 studs on the widest crown.
   *Verify:* `grid_ground.spec`, "the crown rule is linear, by parameter" (the widest crown is read
   out of `TEMPLATE_DIMS`, never typed); and **crownOverRoad 88 -> 0** below.
5. **The frontage rule draws FROM the four groups**, not from the four a zone happens to carry.
   Measured, cycle 2: the intersection left C1's roadside thicket able to draw only `young`, which
   the front cone then refuses in front of every stand, and the frame came back as BARE GRASS. Design
   7.2 says *"only those four groups are drawn"* and A1's thicket *"becomes birch and larch"*, so a
   missing group joins at weight 1 and the zone's own weights are kept where they overlap. An empty
   mix (a clearing) stays empty. *Verify:* `grid_ground.spec`, "the frontage rule"; and the measured
   histogram in her place -- the **34-60 stud band holds birch 55, young 30, aspen 21, fieldOak 15
   and NO conifer and NO oak at all**, with conifer back at 60-100.
6. **`fernBand` is measured from the ROAD CENTRELINE** (defect F-5), so no bracken stands in the
   ditch or on the verge; ferns are drawn in W/M/B/Bo zones only and capped at 400 a cell.
   *Verify:* `grid_ground.spec`, "the ferns".
7. **`standTypeFor` is DERIVED and no recipe carries a letter** (design 8.5); cones, corridors, the
   field, the clearings, the relief bias, N-S rows and the 0.35 scale floor are all in, all as data.
   `Places.borderPlan` (8.4) is built and is deliberately NOT planted -- the whole-world prebuild into
   `Workspace.GridForest` is 328i's. *Verify:* "stand types are derived, never written"; and the
   measured letters, every cell, below.
8. **LIVE IN HER PLACE, same instrument, same session, BEFORE -> AFTER:**
   `[census] C1 ... trees=1999 ... foliageInGround=255 ... inRoad=0 ... crownOverRoad=88 refused=not-handed-in`
   `[census] C1 ... trees=1369 ... foliageInGround=177 ... inRoad=0 ... crownOverRoad=0  refused=74+0/1443=5.1%`
   floating **0**, sunk **0**, tilted **0**, broken **0**, noGround **0**, onCliff **0** on both sides.
   `crownOverRoad 88 -> 0`, `inRoad 0`, `refused 5.1 %` (gate: <= 8 %), plan 1,443 / planted 1,369,
   **plant time 1.0 s**, plan 72 ms. 15 posts, 3 towers, and the boot's own line
   `[ForestTestBoot] grid preview cell C1: 15 of 15 post(s) (7 line), 3 tower(s) at {8,13,15}, line=true, complete=true`.
   Open space **30.59 %** of C1 (and clearing-or-field alone 14.31 %) on the convention 328a-notes (c)
   asks for: a 10-stud lattice over 15,552 points **strictly inside the cell**, counting every point
   the mask refuses with no template -- so each road strip counts only the part inside the cell.
   Letters: `A1=SSSSSSSTOOOSOOO B1=RRRRSSSOOOOTSOC C1=SXXXVRRTLOOOTLT D1=FPPPPPFFTFTFFFC
   A2=RRRRRRTOOOCOOOC B2=RTRRRRROCOOOCSS C2=SSRRRSSSSOOSSTO D2=RRRRRRROOCCTOOO`.
   **Attribute diff byte-identical** (`328f-attrs-BEFORE.json` vs `328f-attrs-AFTER.json`, L-101): her
   15 flags untouched.
9. **SIX EYE-HEIGHT FRAME PAIRS, looked at** (`driven-hunt-runs/328f-{BEFORE,AFTER}-G[1-6].png`, each
   camera point printed beside it, all twelve shas distinct). G1 stand 4 on the main line: an oak and
   a spruce at ~15 st closed the view; now the nearest trunks are ~40 st back and you see 150 st
   through. G2 tower 13's deck at 17.5: open birch-and-oak park, nothing in the deck's face. G3 the V
   ride at stand 5: a clean 54-stud grass ride running 700 st to the ridge, no crown over it. G4 the
   photo-match against `terrain-refs/Driven Hunt/Screenshot 2026-10-16 123045.png` (layout only, not
   colours): a spruce crown hung over the carriageway, now the road is an open lane with sky above it
   and the stand stakes visible down it. **G6 is Q6's frame** (the roadside between stands 2 and 3): a
   solid wall of dark spruce 18 st from the eye, now larch and birch poles at ~37 st with the spruce
   set back behind them. G5 is the same frontage taken down stand 2's OWN cone, which is why its near
   ground is bare -- that is the cone, not the frontage.
10. **`grid_ground.spec` gains design 13.2's cases 4-9**; the road and ride floors are measured by the
    spec's own loops and then asked of the mask. `grid.spec`'s skirt case learned the frontage rule
    (a skirt planting inside the band is drawn from `frontage.groups`), and its `dressCell` case now
    compares against `plantCell(id, hillside)` -- the plan `dressCell` actually makes, since the
    relief bias is a pure function of a height.

## NOT MET, with the count and the cause

- **`foliageInGround` 255 -> 177, NOT 0.** It is a TEMPLATE fact and no forest plan can move it.
  Measured per name (`driven-hunt-runs/328f-foliage.luau`): five templates offend on **every single
  instance** -- `LarchTree_Var02` 63/63, `Field_OakTree_Var07_LOD_0` 48/48, `_Var04` 44/44, `_Var06`
  39/39, `_Var05` 30/30 -- because their foliage geometry sits **below** the trunk box
  (-0.12 to -1.83 studs at the planted scale), and the seat then sinks the trunk by up to
  `TreeGround.SINK_STUDS` 0.6 against the census's own `FOLIAGE_SINK_STUDS` 0.5. The rate is
  unchanged by this task (12.8 % -> 12.9 %), which is the proof it is per-tree and not placement.
  Fixing it means changing the CONTACT ARITHMETIC or quarantining five templates, and design 1.2
  item 2 forbids this task from forking either. For the Architect.
- **The far cone's density rule is not implemented.** SWARM_DESIGN 3.3 asks for "at most 1 trunk per
  900 sq st" between 40 and 140 st; the mask enforces the trunk-free 40 st and the no-young-growth
  band, which are per-point facts. A density cap is not.
- **The painted ride (24 st of Grass with ruts) is not painted.** It is terrain, and this task writes
  none.
- **Design 8.5's "no two adjacent stands share a letter" holds for no cell**, C1 included (C1 has 7
  distinct letters over 15 and 5 adjacent pairs). The design's own answer is that a failing cell has
  its RECIPE changed, and only C1's recipe is in this task's scope. The spec asserts >= 5 distinct for
  a cell whose recipe carries `rides` (C1: 7) and >= 3 for every cell (weakest A1: 3), and the
  measured rows are in claim 8 for the task that brings each recipe to v2.
- **`StreamingMinRadius` 64 -> 384 is still for Karen** (unchanged, listed).

`deer_hitbox.spec:682`, which the dispatch names as intermittent, fired once at this same commit and
passed on the two runs after it; the pasted harness line is from a run where it passed.
