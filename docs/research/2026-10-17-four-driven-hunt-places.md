# Four driven-hunt places, planted from code (Task 193)

Karen, 2026-10-15 ~17:30: *"then we need make at least 4 hunting places ... so you goal fix terrain
make 4 hunting places where each time person will be in new place when is hunter then loop it
again"*, and *"be sure you do it properly not fake it or broken"*. Her four, and the Director's one
reference frame each, are in `reviews/task-193/BRIEF.md` section 2.

This note covers the **new** system only: what dresses a place -- the scatter of trees, the graded
edge, the strip down the middle and the ground under it. The layout RECORD (where the line is, how
many stands, how far apart) is task 179's and is designed in `docs/design/drive-layouts.md`; this
note adds a fourth row to it and changes its choice rule from a bag to a rotation, both on Karen's
own sentence.

---

## 1. What the system must do

1. Make each of Karen's four places read, from a hunter's eye at ground level, as the kind of place
   her reference frame shows -- a gravel forest road, a field edge, a cut line, a narrow forest
   track -- using the trees this world already holds.
2. Put every tree ON the ground: the trunk/root junction at or below the LOWEST terrain anywhere
   under the trunk's own footprint (the 196/199 rule, `src/shared/TreeGround`).
3. Keep the shooting lanes clear: no tree in the strip a hunter shoots over, no stand inside a
   trunk.
4. Be reproducible from a commit. The same seed and the same layout must plant the same forest, so
   a frame Karen judges can be rebuilt and a defect can be bisected.
5. Cost nothing a player notices -- no stutter at the start of a drive.
6. Be provable without a world: a spec must be able to assert where every tree goes, and that no
   tree is in a lane, with no Studio running.

### Numeric targets

| Target | Value | Where it comes from |
|---|---|---|
| Trunk junction above ground, worst case over all planted trees | **<= 0.20 studs** | `TreeGround.TOLERANCE_STUDS`, the number task 196 measured the lobby's 38 trees against |
| Tree inside a shooting lane | **0** | rule 3, the dispatch's *"no trees in the shooting lanes"* |
| Trunk within the stand circle | **0** | the dispatch's *"no stands inside trunks"* |
| Cut line (place 3) strip width | **64 studs = 18 m** | source C: 10-15 m preferred for a `Schussschneise`; the dispatch asks 15-25 m; 18 m is in both |
| Forest road (place 4) track width | **18 studs = 5 m** | source B: a `Rueckegasse` is 3-4 m, "at least four metres" recommended |
| Field (place 2) width, tree line to hunters | **350 studs = 98 m** | Karen's 80-150 m. It was 140 m until a frame showed the ground rising in front of the guns -- section 5 |
| Every stand can see the drive | **worst terrain intrusion 0.0 studs**, all 5/5/6 stands | section 5, the correction that moved three of the four lines |
| Graded edge: herb band at the strip's lip | **4-10 studs**, not 14-36 | section 5. The sources' 5-10 m `Krautsaum` is measured from the FIELD, not from inside a 24 m shooting lane |
| Visible-band belt depth either side of a strip | **>= 230 studs = 64 m** at full density, then a coarse band to **640 studs** | the frames' 40-60 m sight line; 640 is `beaterNorthStuds()` 580 + a run-out, so the beaters muster in trees |
| A belt is at least as opaque as the wood Karen already has | **>= 22% of eye-height rays stopped by a trunk within 300 studs** | MEASURED off `OurForest` itself: 8-14 of 36, mean sight 242-272 studs |
| Build cost, all four places | **< 2.5 s** | measured: 200 models clone and seat in 0.09 s (`BRIEF.md` M9) |
| Metres per stud | 0.28 | the project's constant |

## 2. Sources

### A. Robert Bridson, *Fast Poisson Disk Sampling in Arbitrary Dimensions* (SIGGRAPH 2007 sketch)

https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf
Reference implementations: SciPy `scipy.stats.qmc.PoissonDisk`
(https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.qmc.PoissonDisk.html, BSD-3,
actively maintained), and https://github.com/KamilKrol5/bridson-algorithm.

**Does well.** It is the canonical answer to *"scatter things so none is closer than r to another,
and there are no clumps and no grid lines"* -- which is exactly a forest. The background grid with
cell size `r/sqrt(n)` makes the neighbour test O(1), so the whole scatter is O(n) rather than
O(n^2); the paper's own recommendation of k=30 candidate attempts per active point is the only
tuning it needs.

**Does badly, for us.** The active-list loop is unbounded in wall-clock terms (it keeps trying until
every point is exhausted) and its output is an unordered set -- you cannot ask it for "the tree at
cell (i, j)" and get the same answer twice without storing the whole result. We want a plan that is
a pure function of `(layout, seed)` and can be regenerated identically in a spec, and we want a
hard, known cap on how many trees we plant. So we take the PRINCIPLE (a minimum distance, enforced
through a grid) and not the algorithm.

### B. LWF-Merkblatt Nr. 38 / Wald-Prinz, on `Rueckegassen` (skid trails)

https://www.waldwissen.net/de/technik-und-planung/forsttechnik-und-holzernte/walderschliessung/merkblatt-feinerschliessung
https://www.wald-prinz.de/ruckegassen-anlegen-feinerschliessung-sichert-bodenschonende-holzernte/3436
(Bayerische Landesanstalt fuer Wald und Forstwirtschaft; a public forestry advisory sheet, current.)

**Does well.** It gives the dimension karen-ref-1 is a photograph of: a skid trail is **3-4 m wide**,
"at least four metres" recommended, with **20-60 m between trails**. That is the width of place 4's
track (18 studs = 5 m, the generous end, because a boar has to be shootable crossing it) and it is
also why the track has no made-up surface in the frame: a skid trail is bare soil and leaf litter,
not gravel.

**Does badly.** It is about machinery, not hunting -- it says nothing about sight lines, and nothing
about what a stand on one needs.

### C. `Schneise` / `Schussschneise`: WILD UND HUND forum practice, and the term itself

https://forum.wildundhund.de/threads/schussschneisen-wie-umsetzen.115534/
https://www.kulturpixel.de/waldschneisen/ , https://www.duden.de/rechtschreibung/Schneise

**Does well.** The definition is the brief for place 3: *an artificially created straight strip,
cleared of trees and shrubs, that divides a forest*. And the practitioners give the number: a
30 m-wide lane is too wide and spoils the stand, **10-15 m is preferred**, because game crosses a
narrow lane quickly and then is gone -- which is precisely the shot Karen's ref-5 shows.

**Does badly.** Forum practice, not a measured study; the widths are opinions from people who cut
them, and the thread disagrees with itself between 6 m and 15 m. We take the band, not a point.

### D. The graded forest edge: Gehlken, *Der "ideale Waldrand"* (Uni Goettingen, 2014) and the DVL
practice booklet

https://www.uni-goettingen.de/de/document/download/9ef453bebe0d4d3d4b5fd07c1e814771.pdf/Gehlken%202014%20Waldrand.pdf
https://www.dvl.org/fileadmin/user_upload/Publikationen/Praxishefte_Biotoppflege/DVL-Publikation-Praxisheft_Hinweise_zur_Biotop-_und_Landschaftspflege-Waldrand.pdf
(Academic and NGO practice literature; both current and freely published.)

**Does well.** It is the recipe for why a forest edge does not look like a wall: three interwoven
layers -- **`Krautsaum` 5-10 m** (herbs and grass), **`Strauchmantel` 5-10 m** (shrubs), then the
**`Baummantel`** of light-demanding trees, 10-30 m in all for an outer edge. That is exactly
karen-ref-6 (a bramble wall beside the stand, under an oak) and karen-ref-5 (a band of young pines
in front of taller forest), and it tells us a belt must be built in three depth bands rather than at
one density.

**Does badly.** It is written for biodiversity, so its species lists are nothing like our 61 models,
and it has nothing to say about sight lines or about how dense is too dense to shoot through.

### E. Inside this repo, which rule 2 asks for first

* `src/shared/TreeGround` (task 199) -- where a tree meets the ground, as arithmetic. **Taken whole.**
  No second copy of it exists and none is written here.
* `src/server/Lobby/Build.luau` -- the precedent for planting a tree ring from code at run time:
  clone a template out of Studio content, measure the ground under the footprint, hand the
  measurements to `TreeGround`, settle. **Its shape is taken; its code is not reused**, because it
  plants 38 trees in a ring around a building and this plants ~2,000 in belts, and because `Build`
  is documented as *the one writer of every part in `Workspace.Lobby`* -- reaching into it from a
  second system is the owner collision rule 3 exists to stop.
* `src/server/Lobby/Field.luau` -- the precedent for writing terrain inside one session: pure
  block-geometry functions, `terrain` passed in as an argument so no spec in the DEV place can ever
  write DEV's terrain. **Taken whole, as a pattern.**
* `src/shared/ForestTest` (tasks 157, 179) -- the one world-geometry seam; a pure function reads a
  layout handed in. The dressing READS a layout and adds no field to it.

## 3. The pattern adopted, and why

**A PURE PLAN, THEN A THIN PLANT.** The planner answers *what stands where* -- position, species,
scale, yaw -- as a pure function of `(layout, seed)`, with no Instance, no service and no raycast.
The planter is the only thing that touches `Workspace`: it clones the template, measures the terrain
under the trunk's footprint, and hands the measurements to `TreeGround`. This is task 199's own
split and `docs/research/2026-10-17-forest-trees-on-the-ground.md` says why it matters: when the
arithmetic and the measuring were one lump, *"neither could be checked alone"*, and part 3d's
version was wrong for rounds at a time.

**A JITTERED GRID, NOT AN ACTIVE LIST** (source A). Each belt is divided into cells of
`spacingStuds` and one tree is offered per cell, displaced inside its cell by a seeded jitter. A
candidate is dropped if it is closer than `minGapStuds` to a tree already placed in the same or an
adjacent cell -- Bridson's grid neighbour test, with his cell invariant (at most one sample per
cell) holding by construction instead of by checking. What this buys over Bridson's own loop is the
property we actually need: the plan is a pure function of `(layout, seed)`, the tree count is bounded
by the cell count before anything runs, and cell (i, j) is the same tree every time, so a spec can
assert one. What it costs is a slightly more regular scatter than true blue noise; at a jitter of
0.8 of the cell the grid is not visible in a frame, which is the only test that matters here.

**THREE DEPTH BANDS PER EDGE, NOT ONE DENSITY** (source D). Measured from the open side inward:
a herb/fern band (ferns and low bushes, no trees), a shrub band (bushes and trees scaled to
young growth), then the high forest. That one rule produces ref-5's young pines in front of taller
forest, ref-6's bramble wall, and ref-1's young firs at the track, from the same table with
different numbers.

**THE STRIP IS A SUBTRACTION, NOT A SHAPE.** Nothing is planted within `halfStripStuds` of the line
plus the lane clearance, and that is the ONE rule that keeps the shooting lanes clear -- rather than
a hand-placed row of trees that a later tweak could walk into the lane. A spec asserts it over every
tree of every place.

**THE GROUND IS PAINTED, NOT BUILT.** The strip's surface is a terrain material write inside the
running session (source: `Lobby.Field`'s pattern), never a slab of parts: the measured relief along
a stand line is 26-45 studs, so a flat slab would float at one end -- which is the exact failure
`docs/PROJECT_CONTEXT.md` was written about, and the one `Lobby.Field`'s header already records.

**ROTATION, NOT A BAG.** Karen: *"each time person will be in new place ... then loop it again"*.
Task 179's shuffled bag (its sources D and E) is replaced by a fixed cycle. The bag's reason --
*"a layout she is never dealt is a layout she cannot judge"* -- is better served by a rotation, which
deals every layout exactly once per cycle in a known order, and the rotation is what Karen asked
for in words.

## 4. What the first build got wrong, and the measurements that corrected it

Three things in sections 1-3 were right in principle and wrong in the world. All three were found by
**looking** -- a hunter's-eye frame -- and then **measured** before anything was changed. They are
recorded here because the design (`docs/design/drive-places.md` section 18) says plainly that the
Architect measured nothing and saw no frame, so this is the only place the live numbers exist.

**4.1 Three of the four lines could not see their own drive.** The gate rule for this task is *"every
stand: the hunter stands ON the ground, can see the drive area"*. The first siting used the flattest
and emptiest ground, which is not the same thing:

| line, as first built | what a ray north from eye height (+5) hit |
|---|---|
| `edge` (3480, −3400) | **terrain at 60 studs** at stand 4 -- no field, no tree line, only crowns over a ridge |
| `ride` (1500, −4100) | 89 studs at stand 1, 241 at stand 3 -- two of five blind |
| `track` (4800, −4100) | **65 and 62 studs** at the two east stands -- 18 m of visible ground |

So every candidate line was scored by walking the terrain from each stand's eye height to the far
side and taking the worst intrusion above the sight ray. For `edge`, 120 candidates gave **18 with
every stand clear**; for `ride` and `track`, a sweep of the whole WEST ground (x 1200…2000,
z −3700…−4500) found **no line at all** where every stand sees 180 studs, and the EAST ground gave
**30**. The three lines moved to `edge` (3400, −3250) 5 × 130, `ride` (4900, −4500) 5 × 130 and
`track` (4700, −3900) 6 × 130 -- **worst intrusion 0.0 studs and a sight line past 400 studs at every
stand of all three.** Flat is not the same as open, and the gate rule asks for open.

**4.2 The belts were transparent, and the bar is the wood Karen already has.** Firing 21 rays over a
120° fan from every stand at eye height, the first build's belts stopped **24 of 105** (ride) and
**25 of 126** (track) within 300 studs, mean sight 276 -- and the frame showed open hillside through
the trees. The honest bar was then measured off `OurForest` itself at five points inside it:
**8-14 of 36 rays stopped, mean sight 242-272**. After bringing the young growth to the strip's lip
(herb band 30 → 6 and 14 → 4) and tightening the close bands' cell (30 → 20 and 28 → 18), the belts
stop **48 of 105** and **40 of 126**, mean 252 and 244 -- i.e. **denser than the wood this world
already holds**, which is the only bar that is not invented.

**4.3 A flat 4-stud step allowance refused a quarter of the forest.** `TreeGround.CLIFF_STUDS` is the
number the RE-SEATING tool uses, where the question is *"would sinking this existing tree bury it?"*.
For planting the question is *"is this a spot at all?"*, and on this rolling ground a flat 4 refused
**776 of 2,713** candidates -- 29% of the wood, as holes. The allowance is now
`max(CLIFF_STUDS, 0.10 × height)`: the junction still goes to the LOWEST ground under the footprint,
so nothing floats either way, and a tenth of a tree's height of buried uphill flare is not something
an eye can see.

**What the live build then measured:** 3 places dressed, **3,012 planted**, 0 skipped, 879 refused on
a step, 0 templates missing, in **2.5 s**; **every planted model's trunk junction below the lowest
terrain under every footprint sample** (worst +(-0.18) studs, i.e. sunk, over all 3,012); boars
crossing the hunters' line per drive **12 / 14 / 7**; 7 bots walking, **0 stuck**; 0 console errors.

## 4.4 The ground under each place, per place -- the Director's look, 2026-10-17

He put three frames next to Karen's references and three things read wrong:

> *"PLACE 3 ... the hunter stands on GREY ASPHALT-LOOKING ground"* · *"PLACE 4 ... grey ground
> again"* · *"PLACE 1 ... shows grass and an oak and NO ROAD"*

**All three were measurable, and all three were true.** Sampling each place's own strip through the
terrain-only ray:

| place | what was under it | why it read wrong |
|---|---|---|
| 1 `road` | along its line, 65 samples: `Ground` **31**, **`Grass` 29**, Asphalt 3, Limestone 1, Mud 1 -- and the grass is at stands **1, 2, 7, 8, 9** | the road Karen built covers only its middle third. A hunter on five of nine stands stands in a field |
| 3 `ride` | 42 samples: Grass 29, **Asphalt 13** | the grey patches are what the frame showed |
| 4 `track` | 42 samples: Grass 19, **Asphalt 23** | more than half the track was grey |

**And the first paint could not have fixed any of it**: `Ground.SOURCE_MATERIALS` was Grass and
LeafyGrass only, on the argument that the world's rock *"is the world's own rock and made ground"*.
That argument skipped exactly the patches he objected to. The list is now every ground material this
world holds, and what is re-surfaced is still only the strip -- 18 to 64 studs wide against this
world's thousands.

**What each place's ground is now** (`Places.SURFACES`, and `places.spec` asserts this table):

| place | reference | strip material | ruts | left alone |
|---|---|---|---|---|
| 1 `road` | karen-ref-7, pale gravel road | **`Ground`**, 22 studs wide | none -- a graded road, not a pair of ruts | its wood and its geometry (BRIEF D3) |
| 2 `edge` | karen-ref-6, field edge | **none** | -- | the whole field. `Ground` there would be a *ploughed* field, a different place from her frame |
| 3 `ride` | karen-ref-5, grassy ride | **`Grass`**, 64 studs | two **`Mud`** strips, 6 studs wide at +-9 | the verges, which keep the world's own grass |
| 4 `track` | karen-ref-1, brown dirt track | **`Ground`**, 18 studs | two **`Mud`** strips, 4 studs wide at +-4 | the belts' floor |

**`Ground` AND NOT A TINT.** `Terrain.MaterialColors` would make the browns browner, and it is
**global** -- it would recolour the lodge's lawn, the existing wood's floor and every other place's
grass with it. We do not own that decision; `Ground` is the brownest thing the engine gives per
region. **So Karen's *"brown floor, not green lawn"* (ref-2/3/4) is answered on the TRACKS and NOT yet
on the forest FLOOR between the trunks**, which is still this world's grass with a fern every 22-26
studs. That remains the largest gap between her frames and what ships, and closing it means painting
~692,000 voxels per place against a strip's ~58,000 -- measured in voxels, not timed, so it is a risk
and not a cost. It is hers to ask for.

**THE RUTS ARE MATERIAL, NOT TRENCHES.** A terrain voxel is 4 studs (1.1 m) and a wheel rut is a hand
deep, so cutting one is not reachable. Two darker strips with something growing between them is what
both frames actually show, and it is what is built.

## 5. What is NOT built, and why

1. **A crop field.** karen-ref-6 is standing maize: dry, golden, waist-high, a boar half hidden in
   it. We have no crop, cereal or stubble model, and nothing in the 61 forest models or the 831
   bush/tree models is one. The closest our assets reach is a terrain material plus grass
   decoration, which is a mown field and not a crop. **This is stated as a gap rather than faked**;
   the fix is one cheap wheat/maize mesh, which is an asset task.
2. **An autumn/winter forest.** Every reference frame is bare-branch late autumn or winter; our 61
   models are in summer leaf. Nothing here recolours or strips them. Stated, not faked.
3. **Wheel ruts as geometry.** karen-ref-5's two ruts and ref-1's double track are ruts in soil. A
   terrain write can change the MATERIAL of a rut strip but not cut 10 cm of depth (terrain
   resolution is 4 studs = 1.1 m), so the ruts are two material strips and not two trenches.
4. **Cutting the existing wood.** Measured impossible without deleting Studio-built trees
   (`BRIEF.md` M7): 18 of 36 samples along the best candidate line inside it have a trunk within
   14 studs. Rule 7, and Karen's call.
5. **A raised stand with a rail**, which three of the frames show. Karen, task 179: *"hunter line
   just a hunter no treestand anything"*, and her 2026-10-10 roadmap keeps "hunter stands/towers" as
   its own later item. The gate rule for this task is that the hunter stands ON the ground.
6. **The beater ground behind each place.** Task 194.
