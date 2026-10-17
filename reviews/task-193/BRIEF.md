# Task 193 BRIEF -- four real driven-hunt places, a new one each drive

The Builder, carrying the Director. Input to `tools/architect.ps1 design drive-places --task 193`.
**This file overrides anything older in `docs/`, `TASKS.md` or an earlier design** (CLAUDE.md,
"Files the roles talk through").

It supersedes `docs/design/drive-layouts.md` section 1.2 item 3 ("must not ship a fourth layout")
and its section 3 table. The reason that item gave was a measurement -- *there is no clearing in
this wood* -- and it is still true. What changed is the answer: the new places are **not** cut out
of the existing wood, they are **planted on the clean open ground this world already has**, which
the measurements in section 3 below locate to the stud.

---

## 1. KAREN'S WORDS, verbatim

2026-10-15 ~17:30:

> *"then we need make at least 4 hunting places / 1. has to be road like we did previuosly / 2. next
> one has to be forest ending then field and then again forest / 3. next one has to be just cut tree
> line and forest on both sides / 4. has to be again forest road and forests on side / it has to be
> like real life hunting situations in driven hunt / use same trees mix them make like in real life
> and what is acceptable for us / so you goal fix terrain make 4 hunting places where each time
> person will be in new place when is hunter then loop it again"*

2026-10-15:

> *"be sure you do it properly not fake it or broken"*

2026-10-16, handing over seven frames from a hunting video:

> *"I also will add here now few screenshoots what I am thinking is should be standing position for
> hunter so hunter view / choose 4 we do 4"*

The frames live OUTSIDE the repo (`<runs-dir>/193-refs/karen-ref-1..7.png`). They are someone
else's video: **look reference only** -- never copied into the repo, never uploaded, no texture
traced from them.

## 2. DECISIONS ALREADY TAKEN. The design does not re-open these.

**D1. FOUR places, and these four.** The Director's pick of one hunter's view per place, as Karen
asked ("choose 4 we do 4"):

| # | Place | Reference | What the hunter sees |
|---|---|---|---|
| 1 | **road** | karen-ref-7 | a pale gravel forest road curving away, mossy verges 2-3 m, open bare oak/hornbeam high forest both sides, brown leaf-litter and bracken floor, the sight line running along the road and into the open wood |
| 2 | **field edge** | karen-ref-6 | standing in a dense hedge/forest edge, bushes right beside the stand, facing a wide field (tall, dry, waist-high) with a dark forest line across it; a boar crosses the field |
| 3 | **cut line** | karen-ref-5 | a straight grassy ride with two wheel ruts, tall dry grass at its edges, a band of young pines one side and taller mixed forest behind, forest both sides; the animal crosses from cover to cover and the next hunter stands far down the ride |
| 4 | **forest road** | karen-ref-1 | a narrow dirt double track under brown leaves, forest CLOSE both sides: spruce and pine mixed with bare birch, dead standing trunks, young firs right at the track, low brambles |

The forest itself (karen-ref-2, -3, -4): the floor is **brown** (leaf litter, dry bracken, dead
branches), not green lawn; trunks mixed (birch in groups, oak/beech, spruce/pine stands); open
understorey in high forest so you see 40-60 m between trunks; dense young growth at the edges.

**D2. ROTATION, not a bag.** Each drive the hunters go to the NEXT place in order
1 -> 2 -> 3 -> 4 -> 1 (Karen: *"each time person will be in new place when is hunter then loop it
again"*). This REPLACES task 179's shuffled bag, which is the one decision in `drive-layouts.md`
this task reverses, and it is Karen's own sentence that reverses it. `DHForestLayout` still forces
one, and a forced drive still must not advance the rotation.

**D3. Place 1 keeps today's geometry**, to the stud: centre (3030, 138, -2097), amplitude 30, 9
stands 150 apart, half-span 800 (`drive-layouts.md` 3.1). Polish of its DRESSING is allowed; its
numbers are not touched.

**D4. Every tree is planted with `src/shared/TreeGround`** -- the trunk/root junction at or just
below the LOWEST ground anywhere under the trunk's own footprint, never a pivot, never the claw
tips. That is the 196/199 rule, lesson L-086 (which has already recurred twice on this code) and
standing rule E. No second copy of the arithmetic.

**D5. The beater ground behind each place is task 194's.** This task leaves room for it and states
where; it does not build it.

**D6. THE DRESSING IS BUILT FROM CODE, IN `src/`, AT RUN TIME -- not hand-built in Studio.**
Three reasons, all already paid for in this project:
  * `docs/PROJECT_CONTEXT.md`, on what killed the previous game: *"Everything lived in the cloud
    place file: no diffs, no history, no rollback."* Four hand-built places would be exactly that.
  * Task 199 is the bill for the Studio-built alternative: `Workspace.OurForest` is Studio content,
    *"nothing under `src/` creates it, no Rojo path owns it, and it is saved with the place, so no
    commit can move it"* -- which is why a 704-line tool had to be written to put its trees back on
    the ground after Karen's *"look at the trees wtf"*.
  * The precedent inside this repo is `Lobby.Build`, which plants the lodge's tree ring at run time
    through `TreeGround` and is reviewable as a diff.

**D7. The templates are the Studio content already in the place, cloned and never touched.**
`Workspace.OurForest` (61 distinct models, section 3) and `Workspace.Session` (831 bush and tree
models: `Bush`, `Bush1`, `Bush3`, `Bush4`, `Tree3`, `Tree8`, `Tree10`, `Mesh Tree`, `Mesh TreeV`).
Clone only: nothing in either folder is moved, re-parented, scaled or destroyed (rule 7). Karen's
*"use same trees mix them"* is this sentence.

**D8. A PURE PLANNER plus a THIN PLANTER.** The planner answers *what stands where* -- position,
species, scale, yaw -- from a layout and a seed, with no Instance, no service and no raycast, so a
spec can assert every placement with no world at all. The planter is the only thing that touches
`Workspace`: it clones, measures the ground and hands the measurements to `TreeGround`. This is
task 199's own split, and `docs/research/2026-10-17-forest-trees-on-the-ground.md` names why: when
the arithmetic and the measuring were one lump *"neither could be checked alone"*.

**D9. `CanQuery = false` on every cloned part whose `CanCollide` is false** (lesson L-060). Task
149 lost 4 of 5 shots in leaves. Trunks stay queryable and collidable -- you must not shoot through
a trunk -- and the rule is written against the template's own `CanCollide`, which in this wood is
already the trunk/leaf-card distinction.

**D10. Ground is chosen by measurement, never by preference** (section 3).

## 3. THE MEASUREMENTS, read today in Karen's Forest Test (130094961655666) in Edit

All read-only, through StudioMCP. Terrain height is a `Terrain`-only downward ray (the
`ForestTest.terrainYAt` rule); "trunk" is `GetPartBoundsInRadius` with `RespectCanCollide = true`
(the `ForestTest.roomToStand` rule), which in this wood excludes the non-colliding fern and
leaf cards.

**M1. What is in the world.** `Ambience`, `Session(771)`, `Foliage(0)`, `Session(60)`,
`OurForest(4819)`, `LobbyAssets(5)`, `Terrain`, `ForestRoadSpawn`, `Camera`.

**M2. `OurForest`: 4,819 models, x 2230..3830, z -2896..-1297, 61 distinct models** -- 7 field oak
+ 3 forest oak (229 + 210), 7 larch (149), 6 old spruce + 2 spruce (170), 9 aspen (1,076), 13+7
silver birch (434), 10 fern models (2,603). So the wood is ~2,200 trees and ~2,600 ferns. **The
ferns are our bracken**: `SM_Forest_Fern_Var01..05` and `SM_Lady_Fern_Var01..05`.

**M3. Sizes** (`GetExtentsSize`, studs): aspen 32x85, old spruce 22x81, silver birch 21x58, forest
oak 22x57, larch 14x26, lady fern 6x3. At the project's 0.28 m/stud an aspen is 24 m and a larch
7 m, so **young growth is a scaled model, not a species** (`Model:ScaleTo`).

**M4. The wood is one block with open ground on all four sides.** Terrain answered a ray at EVERY
sample of x 1400..4600 by 400 and z -2900..-5000 by 300 (72 points, 0 misses), heights 127..285,
materials Grass / LeafyGrass / Limestone / Asphalt / Mud. There is no edge of the world to fall off
within the ground this task uses.

**M5. The south tree line, per column** (first trunk within 25 studs walking north from z -3300):
east `3100..3800` all **-2900 +/-25** (3850 is -2725, 3900 none); west `2250..2750`
**-2825..-3050**. So the wood's southern face is a straight edge across the whole east half, which
is what place 2 needs behind the field.

**M6. The field ground is empty.** x 3100..3860, z -2900..-3400 holds **6** non-terrain parts (one
`OurForest` field oak, five `Session` bushes/trees).

**M7. A NEW TRACK CANNOT BE CUT THROUGH THE EXISTING WOOD.** The best candidate line inside it is
7 stands 150 apart at z -2500, centre x 3000: **7/7 trunk-free at the stands**. But along that same
line, **18 of 36 samples (x 2480..3520 by 30) have a trunk within 14 studs**, worst 3. A 28-stud
track there clips trees; making it clear means deleting Studio-built trees, which rule 7 forbids
and which is Karen's call. **This is the measurement that sends places 3 and 4 to clean ground.**

**M8. The clean plots.** 42 candidate plots scored (820 x 900 studs: the hunters' line, 620 studs
of drive ground north and 280 south), counting non-terrain parts in the box and the relief along
the 700-stud stand line:

| plot centre | non-terrain parts | line relief | plot relief |
|---|---|---|---|
| **x 1500, z -4100** | **0** | **29** | **63** |
| x 4800, z -4100 | 0 | 37 | 58 |
| x 4800, z -4300 | 0 | 35 | 60 |
| x 1500, z -4300 | 4 | 18 | 61 |
| x 4500, z -4300 | 0 | 49 | 69 |

The two taken are the flattest plots with **zero** parts in them: **x 1500, z -4100** and
**x 4800, z -4100**. Every plot in this world rolls 58-98 studs over 820 x 900 -- there is no flat
ground anywhere -- so a rolling ride and a rolling road are what the terrain gives, and the design
must say how a stand stays on it.

**M9. The build budget is not a constraint.** Cloning a tree model out of `OurForest`, raycasting
the terrain under it and `PivotTo`-ing it: **200 models in 0.09 s** (1,404 descendants), destroyed
cleanly afterwards. So ~2,000 planted models cost about a second, and the design may plant real
forest rather than a thin screen of it.

## 4. THE FOUR LAYOUTS, as the Builder proposes them

Everything here is a proposal the design may move, EXCEPT what section 2 fixed. The shared
constants (`SHAPE.wavelengthDivisor` 70, `halfWidthStuds` 20, `EXIT_SOUTH_STUDS` 250,
`beaterNorthStuds()` 580) are task 179's and are not touched.

| | 1 road | 2 field | 3 cutline | 4 forestroad |
|---|---|---|---|---|
| `centre` | (3030, 138, -2097) | (3480, ?, -3400) | (1500, ?, -4100) | (4800, ?, -4100) |
| `amplitudeStuds` | 30 | 0 | 0 | 0 |
| stands x spacing | 9 x 150 | 6 x 150 | 5 x 130 | 6 x 130 |
| stand span | 2430..3630 | 3105..3855 | 1240..1760 | 4475..5125 |
| `halfSpanStuds` | 800 | 435 | 320 | 385 |
| beaters start z | -1517 | **-2820, inside the wood** | -3520, inside the planted north belt | -3520, inside the planted north belt |
| `exitZOf` | -2377 | -3650 | -4350 | -4350 |
| planted | nothing (today's wood) | the hunters' own edge only | both belts | both belts |

`centre.Y` is a FALLBACK ground only (`drive-layouts.md` 3.4) and is set to the mean of the layout's
own MEASURED stand terrain -- a number this task must read before it ships, not guess.

**Place 2, the field.** The hunters stand at z -3400 facing north. The field is the open ground
between them and the wood's southern face at z -2900: **504 studs = 141 m**, inside Karen's
80-150 m. The far forest is the existing wood, measured straight across the whole stand span (M5),
and the beaters start INSIDE it at z -2820 and push south out of the trees into the open -- which
is the real "Feldrand" stand, and is exactly Karen's *"forest ending then field and then again
forest"* read from the hunter's end. Planted: the hunters' own dense hedge/edge belt immediately
behind and beside the line, so the stand is IN cover looking out (ref-6), not standing in a bare
paddock. **Honest gap to state:** we have no crop or cereal model, so a *golden waist-high crop* is
not reachable; the closest our assets get is terrain material plus grass decoration, and the
nearest real improvement would be one cheap wheat/stubble mesh.

**Places 3 and 4** are planted whole on the two clean plots of M8, each with a clear strip down the
middle and a forest belt either side. The strip is what Karen described: **cutline a ride 80 studs
(22 m) wide** (her *"just cut tree line"*, inside the 15-25 m the dispatch names);
**forestroad a narrow double track ~18 studs (5 m) with the belts starting 22 studs off the centre
line**, so the forest is CLOSE (ref-1). The north belt reaches z -3520 so a beater starts inside
the trees and is never seen walking in from open ground; the south belt gives the animal the cover
it crosses INTO (Karen, place 3: *"cut tree line and forest on both sides"*).

## 5. WHAT THE DESIGN MUST CONTAIN

1. **The owner, the name and the Workspace home of the dressing system**, and its ONE seam with
   `ForestTest` (rule 3). The Builder's proposal: the plan is its own shared module, not a field of
   the `Layout` record, so `src/shared/ForestTest` stays what task 157 made it -- the one
   world-GEOMETRY seam -- and the dressing is a second system that READS a layout.
2. **Who builds, when, and who may destroy.** Boot once for all four places (M9 says it costs ~1 s)
   or per drive with a tear-down? Name the choice and the reason. If it is per drive, say what
   guarantees the previous place's trees are gone before the next drive's hunter is spawned, because
   a failed tear-down is a forest standing in place 2's field.
3. **The planner/planter interface** (D8): what the planner returns, in what units, and what the
   planter is allowed to decide (nothing, is the proposal).
4. **The rotation** (D2): whether `Data.nextLayout`'s signature changes or a second function is
   added, and what happens to the bag's documented sources. State the invariant a spec can assert:
   four drives in a row visit 1, 2, 3, 4 and the fifth is 1 again, and a forced drive does not
   advance it.
5. **How a stand stays on rolling ground** (M8: 29-37 studs of relief along a 700-stud line, and no
   flatter ground exists). Does the dressing re-measure per stand, like `Markers.groundFor`?
6. **No tree in a shooting lane, no stand inside a trunk** -- as a rule the planner enforces and a
   spec asserts, with the numbers. The lane is the ground a hunter shoots over; the dispatch's words
   are "no trees in the shooting lanes, no stands inside trunks".
7. **What a spec can prove with no world**, and what only a live place can answer. Name both lists.
8. **The DEV path.** `ForestTestBoot` already returns early unless `Map.EXPECTED_WORLD ==
   "forest-test"`, and neither `OurForest` nor `Session` exists in DEV. Say what the planter does
   with no templates (the proposal: nothing, loudly, once).
9. **The per-place species mix, as data**: conifer stands, birch groups, oak/beech, young growth at
   the edges, fern/bracken floor, bushes at the field edge, dead standing trunks on the forest road.
   The mix is numbers in a table, not code.
10. **Deltas** to `docs/design/drive-layouts.md` (sections 1.2 item 3, 3, and the choice rule),
    `docs/design/forest-drive.md` and `docs/design/map-ui.md`.
11. **The blast radius rows** this task must add: any new `src/` directory needs a `BLAST_RADIUS`
    row in `tools/studio_mcp.py` or `--scope auto` silently resolves to the whole suite (lesson
    L-079, which is what happened in task 190's `HandAssets`), and any new spec file needs a
    `SCOPE_SPECS` membership or CI's selftest goes red (standing rule G, task 198).

## 6. ALSO ASKED OF THIS RUN: two designs that are behind the code

The Learning Agent, 2026-10-17: *no Architect run for 3 days, `docs/design/` is behind the code*,
and this task builds on both files. Bring them up to date with what shipped:
  * `docs/design/lobby.md` -- task 191's `world.gatherSpot` (the gathering moved onto clean ground
    beside the cabin) and task 196's tree settler (now `src/shared/TreeGround`, shared with
    `tools/forest_ground.py`);
  * `docs/design/drive.md` -- task 197's pad rig (the truck-pad menu, the "leaving" message and the
    truck that starts).

## 7. OUT OF SCOPE

The boar's behaviour, the weapon, the horn, the shop, the lobby's build, the drive's length, the
stand radius, the spook reaches, the wave rhythm, the beater ground of task 194, a drive on another
axis, terrain carving, and any change to `src/server/Match/`, `src/client/Match/` or
`src/shared/Drive/` -- those three are `TWO_PLAYER_PATHS` and this task is gated on the scoped
one-player run (Karen, 2026-10-15), so a change there stops the task instead.
