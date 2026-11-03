# Design: grid-roads — the eight roads bend in plan, and the grid keeps its coordinates

Task 328o · Architect · 2026-11-03 · written to `reviews/task-328o/BRIEF.md`, which **overrides anything
older** in `docs/`, `TASKS.md` or an earlier design (`docs/ARCHITECT_PROMPT.md`). Read with
`docs/design/grid-map.md` (the world, the cells, the stands, the safety inequality) and
`docs/design/grid-terrain.md` (the ground, the road cross-section, the forest, the census). Decisions
1–6 of the brief are not re-opened.

Karen, 2026-11-03 ~11:20 UTC, C1 playtest 2, verbatim: *"more trees, and road could be also not just
straight make line in real life"*. The brief §1 carries it; it is not restated below.

What this document rules on is everything the brief left to the Architect: the centreline's owner and
its interface, every consumer of a constant `roadZ`/`standX`, the numbers, the census and spec changes,
the revised capacity bound, and the task split with its order against 328h, 328i and 328g.

---

## 0. Supersession — what this displaces, row by row

Two documents describing one piece of geometry is the second-writer failure rule 3 exists to stop.
Everything in `grid-map.md` and `grid-terrain.md` not named here is untouched and still binding.

| Where | Was | Becomes |
|---|---|---|
| `grid-map.md` §2 — *"A CELL'S ROADS ARE STRAIGHT IN PLAN"*, and `Grid.layoutFor`'s `amplitudeStuds = 0` | straight | **bent, by one sine per axis whose zeros fall exactly on the junctions** (§2). A cell layout's `amplitudeStuds` becomes the east–west family's amplitude, and `ForestTest.roadZ` delegates to `Grid` for a cell exactly as `standPosition` already does |
| `grid-map.md` §4.2 / §6.1 — the stands sit at a constant `roadZ` (main) or a constant `standX` (flank) | constants | **each stand sits on its own road's world curve**, by construction: `Grid.standGridOf` is today's arithmetic in **grid** coordinates and `Grid.standPosition` is that point through `Grid.toWorld` (§4, §6.2) |
| `grid-map.md` §7 — `flankFirstStuds` = 340, derived from `sqrt(330² − 106²)` | a plane solve | **366, re-derived in WORLD coordinates**: the shear can take up to 39.9 studs off the 106-stud `dx` term, which left the 330-stud invariant with 3.1 studs of margin instead of 26.1. §5.4 is the fixed point; `grid.spec` case 5 is the proof. **This is defect F-1 and it is the one the bend would have shipped silently** |
| `grid-map.md` §8.3 / `grid.spec` case 14 — *"models per drive ≈ 2,400; hard bound < 3,600"* at *"≈ 7 descendants per model"* | a literal, carrying a refuted ratio | **two derived bounds** from the **measured 3.03 parts a model**: a plan cap of 7,260 and a draw cap of 2,640 models a cell. §8. C1's room for "more trees" goes from 184 models to 953 |
| `grid-terrain.md` §7.1 — the cross-section is measured from `road.at`, a constant | a constant | **a function of the station**: `centre = Grid.roadCentreAt(road, along)`. The band realiser, the materials, the junction rule, the grade clamp and the cut/fill cap are **unchanged**; three lines of `TerrainBake.roadAt` move (§7) |
| `grid-terrain.md` §7.1 correction F-2 — the band snaps, never the centre | correct and kept | **kept and extended: the band snaps in WORLD coordinates at each station**, so the ditch and the rut stay whole voxel columns everywhere and the cost is a 4-stud lateral stair every 31.5 studs along a bend, which is one voxel and is measured, not hidden (§5.5, §7.2) |
| `grid-terrain.md` §4 — `Relief.luau` | pure, world coordinates | **unchanged, not one line**, and it becomes curve-correct for free, because in grid coordinates the roads are straight. The bake composes the maps (§7.3). `Relief.BAKE_VERSION` does **not** bump and `relief_golden.luau` does **not** move; `Relief.epochInput`'s key list gains the bend's three rows, so the **epoch changes and the stale-forest refusal fires** (§7.4) |
| `grid-terrain.md` §13.4 / `grid-map.md` D-1 — the frame fault | open | **still open, still not this design's to close.** The `DHTestLook` + `shot.ps1` route is what §11.4 mandates |

---

## 1. What it must do, and what it must not do

### 1.1 Must do

| Must | Why |
|---|---|
| Make **every road in the world bend in plan**, so no road is a ruler line | Karen: *"road could be also not just straight make line in real life"* |
| Keep **every junction exactly where it is**, so the eight cells stay closed and a hunter on a corner still stands at a crossing | brief decision 2 |
| Keep the **2×4 topology, the cell ids, the drive direction, the main line, the muster line and the flanks per cell** | brief decision 1 |
| Keep **one owner for the centreline**, a pure function in `src/shared/Grid` | brief, and rule 3 |
| Keep the drive's **arithmetic identities**: the beaters' walk is exactly `cellDepthStuds`, the main and muster roads are exactly `cellDepthStuds + roadClearStuds` apart along every column, and `grid-map.md` §4.3's 275 s does not move | §4.3 is the number the cell size came from. A road that bends the walk is a drive whose length is an accident |
| Keep the **330-stud cross-side separation** (`grid-map.md` §7, D10) true in **world** coordinates | it is the whole of the safety proof |
| **Borrow the sine that is already in this repo**, and say which of its numbers survive | rule 2; brief decision 3 |
| Be **inert until a commit turns it on**: amplitude 0 reproduces today's world value for value | the map-switch exception (task 79) and `ForestTest.Layout`'s own *"0 IS A STRAIGHT LINE"* rule |
| Re-bake **C1 only**, from the **base snapshot**, and leave the accepted landform, paint rules and forest v2 rules alone | brief decision 4 |
| Un-block **"more trees"** by replacing a bound that carries a refuted ratio | brief, and Karen's first clause |

### 1.2 Must not

1. **Must not move a junction.** Not by a stud. The offset is **exactly zero** at every junction, by construction (`sin(πk) = 0`), asserted to 1e-12 — not by a solver, not by a tolerance.
2. **Must not create a second centreline.** `Grid` owns it; `Places`, `TerrainBake`, `GridCensus`, `ForestTest`, `MapUi` and `tools/terrainbake.py` **read** it. Two of those have their own `roadDistance` today (§12 F-4); both are re-pointed, neither is re-derived.
3. **Must not make `Relief.luau` curve-aware.** It is pure, it has a golden fixture, and in grid coordinates it is already right. The bake composes the maps instead (§7.3).
4. **Must not change the road's cross-section, its materials, its grade clamp, its cut/fill cap or the junction rule.** Only the centre of the section moves.
5. **Must not change a safety number.** `SAFETY_LOCK_STUDS`, `SAFETY_MISS_STUDS`, `SAFETY_RANGE_STUDS`, `SAFETY_ARC_HALF_DEG`, `Weapon.SafetyArc`, `Match.Penalty` and `Weapon.Rules` are read-only here. §6.5 proves D10 again with the bend in it, by moving the **derived** set-back and nothing else.
6. **Must not write terrain from `src/`.** `grid-terrain.md` §1.2 item 1 holds whole: the re-bake is the Edit-time tool's, in the Forest Test, after a backup.
7. **Must not be two coordinate spaces with one vocabulary.** A function that takes world coordinates keeps its name; its grid-coordinate kernel is named `*Grid`, and a spec asserts the two agree through the maps (§11.1). A mixed-up space is exactly the class of bug `docs/PROJECT_CONTEXT.md` is about.
8. **Must not quantise a ditch by accident.** The voxel band snaps in world coordinates at every station, or the ruts merge — which has already been measured once (`Places.SURFACES.track.ruts`: *"the whole 18-stud track came back Mud"*).
9. **Must not be a feature flag.** It is a world switch by commit (§9.3), for task 79's measured reason.
10. **Must not delete.** The straight-world numbers stay reachable (`bend.ewStuds = 0`), and the archived text goes under `backups/` with a note (rule 7).
11. **Must not claim a frame nobody looked at** (§11.4).

---

## 2. The pattern adopted, and why

**THE GRID KEEPS ITS COORDINATES. THE WORLD IS SHEARED.**

One sine per axis, shared by every road on that axis:

```
bendZ(x) = ewStuds · sin( π · harmonic · (x − (originX + roadClearStuds/2)) / (cellWidthStuds + roadClearStuds) )
bendX(z) = nsStuds · sin( π · harmonic · (z − (originZ + roadClearStuds/2)) / (cellDepthStuds + roadClearStuds) )
```

and two maps built from them:

```
Grid.toGrid (x, z) = ( x − bendX(z),  z − bendZ(x) )     -- THE DEFINITION
Grid.toWorld(u, v) = the (x, z) with toGrid(x, z) = (u, v)  -- its numeric inverse, 5 fixed-point steps
```

Five consequences, and every one of them is why this shape was chosen over the alternatives:

1. **The half-wavelength IS the junction pitch**, so the offset is exactly 0 at every junction and
   **every road passes through all of its crossings by construction**. Brief decision 2 needs no
   solver, no tolerance and no pin.
2. **At any road's own line, the other axis's offset is zero** (an east–west road sits at a zero of
   `bendX`, and vice versa). So each road is the **graph** of one sine over its own axis —
   `(along, road.at + bendZ(along))` — with no coupling at all. That is what makes the stands, the
   long profiles, the junction pins and the map's polyline one `math.sin` each rather than a solve.
3. **One sine per axis means the roads of an axis are exact world translates of one another**, so the
   cell's depth is exactly `cellDepthStuds` along **every** column and `grid-map.md` §4.3's 275-second
   beater walk does not move by one second. A per-road sign or a per-road amplitude breaks that: two
   E–W roads 2·A apart in phase make the walk vary by up to 90 studs, which is **17 s** at 5.2 studs/s,
   and `ForestTest.beaterStart`'s `roadZ(x) + beaterNorthStuds` would stop landing on the muster road.
   **The cost is named: the world is sheared, not randomised** — seen from above, all three E–W roads
   bow the same way at the same x. From the ground, where Karen stands, that is not a visible fact.
   Open decision K-B if she wants per-road variety; the price is in seconds and is written above.
4. **In grid coordinates every piece of arithmetic in this repository is already correct.** Road
   distance, the cell rectangles, the zones, the rides, the corridors, the fern bands, the skirts, the
   capacity count, the landform's `u`/`v`, the road fade, the slope limiter: all of it reads a straight
   grid, and a straight grid is what it is handed. **Only four functions cross the seam** (§6.3), and
   `Relief.luau` is not touched at all.
5. **Tangent continuity everywhere.** A per-span amplitude (one bend per cell, signed from the seed)
   was the obvious alternative and it is **rejected**: positions would match at a junction and tangents
   would not, which is a kink in the carriageway — source D's exact point. One sine has no joints.

**Borrowed, said plainly (rule 2):** the sine itself is `ForestTest.LAYOUTS.road`'s, whole — the
formula `z = centre.Z + amplitude · sin((x − centre.X)/divisor)`, the discipline that *"**0 IS A
STRAIGHT LINE**: one shape, not two, so a straight layout needs no second code path anywhere"*,
`exitZOf`'s `− amplitudeStuds`, and `MapUi.geometryFromForestTest`'s rule that the map **asks**
`roadZ` and never re-types the sine (*"a map that re-typed the sine would be a second curve that
disagrees with the first"*). Also borrowed: `Relief.columnsFor` / `Ground.bandBounds` for the voxel
snap, `Grid.seedFor` for anything seeded, `Places.forgetCells` for the cache door, and task 79's
world-switch-by-commit with its rollback recipe.

### 2.1 Is the shipped sine enough? The formula yes, its two numbers no

Brief decision 3 asks this straight, so it is answered straight. `ForestTest.LAYOUTS.road` carries
`amplitudeStuds = 30` over `ForestTest.SHAPE.wavelengthDivisor = 70`, i.e. a 440-stud wavelength.
**The formula is adopted unchanged and both numbers are refused**, for three reasons that are
arithmetic, not taste:

1. **Its zeros are wherever `centre.X` happens to be.** On the grid that would put a road's crossing up
   to 30 studs away from its junction, and `TerrainBake.junctionPins` — which pins the N–S profile's
   height to the E–W profile's at the crossing — would be pinning a point that is not on either road.
   Brief decision 2 fails at the first junction.
2. **A 440-stud wavelength is 2.54 full waves inside one 1112-stud span.** Minimum plan radius
   `λ²/(4π²A)` = `70²/30` = **163 studs = 46 m**, and the view down the carriageway closes at
   `(λ/2π)·sqrt(2·34/A)` ≈ **95 studs** — before the next stand, which is 150 away. The main line
   would be seven hunters who cannot see any part of the drive line but their own feet.
3. **A 23.2° tangent swing** (`atan(30/70)`) against a 45° safety cone and a 30° sight cone, and
   against a `roadAt` whose voxel bands would stair every 9.4 studs. The old road gets away with it
   because it is *one* line in open wood with nine stands and no ditch; `ForestTest.Markers` even
   records the licence it took — *"the curve's tangent swings only +-23 degrees, so one plane is the
   right answer here"*.

So: **same sine, new wavelength (pinned to the junction pitch, §5.1) and new amplitude (sized by the
sight line, §5.3).** The real-world reason the old numbers do not transfer is that they describe a
440-stud serpentine ride, and a forest road at 1 stud = 0.28 m bends on a scale of hundreds of metres
(source B).

---

## 3. Owners — one writer each, named (rule 3)

This extends `grid-map.md` §3.1 and `grid-terrain.md` §2 rather than restating them.

| State | Owner (the only writer) | Location on disk |
|---|---|---|
| **The road centreline in plan** — the bend's data and its arithmetic, the two maps, the derived facts | **nobody at run time**: frozen data + pure functions | **`src/shared/Grid/init.luau`** — `Grid.CONFIG.bend`, `Grid.bendZ`, `Grid.bendX`, `Grid.bendSlopeZ`, `Grid.bendSlopeX`, `Grid.toGrid`, `Grid.toWorld`, `Grid.roadCentreAt`, `Grid.roadPolyline`, `Grid.bendFacts`, `Grid.maxBendStuds` |
| **The bend's shipped numbers** | **a commit** — the map-switch pattern (task 79), never a `Flags` row (§9.3) | `src/shared/Grid/init.luau` — `Grid.CONFIG.bend` |
| **Where a hunter stands** | **`Grid.standPosition`** — unchanged owner; `Grid.standGridOf` is the grid-coordinate definition it maps | `src/shared/Grid/init.luau` |
| **The flank set-back** | **`Grid.flankFirstStuds`** — unchanged owner, **derived and never a literal**, now solved in world coordinates (§5.4) | `src/shared/Grid/init.luau` |
| **Terrain HEIGHT and MATERIAL inside the footprint** | **`tools/terrainbake.py`** driving **`ServerStorage.TerrainBake`**, Edit only, FT only, after `--backup` — **unchanged owner**. It READS `Grid.roadCentreAt` and owns no centreline | `tools/terrainbake.py`, `src/serverstorage/TerrainBake/init.luau` |
| **The landform and the shaping arithmetic** | **`ReplicatedStorage.Grid.Relief`** — **unchanged owner and unchanged code** (§7.3) | `src/shared/Grid/Relief.luau` |
| **The forest plan** (zones, rides, cuts, cones, corridors, the mask, the fern bands, the skirts, the border wood) | **`src/shared/Places`** — unchanged owner. **Everything inside it is grid-coordinate and bend-free**; four functions cross the seam (§6.3) | `src/shared/Places/init.luau` |
| **The part and model budget** | **`src/shared/Places`** — frozen constants, derived from one measured ratio (§8) | `src/shared/Places/init.luau` — `Places.PARTS_PER_MODEL`, `PART_BUDGET_*`, `CELL_PLAN_CAP`, `CELL_PART_CAP` |
| **Whether every tree is really on the ground, and off the road** | **`ServerStorage.GridCensus`** — unchanged owner, its own fresh rays | `src/serverstorage/GridCensus/init.luau` |
| **The measured `relief` rows, `lineMeanY` and `towers`** | **a commit**, from the post-bake survey — unchanged owner. All three are **stale the moment the road moves** and are re-filled by C1's re-survey (§9.2) | `src/shared/Grid/init.luau` |
| **The drive's line plane and its posts** | **`ServerScriptService.ForestTest.Markers`** — unchanged owner, unchanged `+Z` normal (§6.5) | `src/server/ForestTest/Markers.luau` |
| **Every pixel of the map** | **`Hud.MapUi`** — unchanged owner; it asks `Grid.roadPolyline` and never re-types a sine | `src/client/Hud/MapUi.luau` |

Row for `GAME_DESIGN.md`'s *System owners* table (rule 3), for the Builder to paste:

```
| **The road centreline in plan** (the bend: one sine per axis, pinned to zero at every junction, and the two maps between grid and world coordinates) | **nobody at run time** (frozen data + pure functions). The numbers ship by COMMIT, never by flag (task 79's map-switch exception). `Places`, `TerrainBake`, `GridCensus`, `ForestTest` and `MapUi` all READ it; none of them holds a second centreline | `src/shared/Grid/init.luau` (`Grid.CONFIG.bend`, `toGrid`, `toWorld`, `roadCentreAt`, `roadPolyline`) | [design](docs/design/grid-roads.md) |
```

---

## 4. The interface — `ReplicatedStorage.Grid`, still pure, still requiring only `Shotgun`

```luau
-- ---- DATA, one table, and 0 IS TODAY'S WORLD (section 9.3).
Grid.CONFIG.bend = table.freeze({
    ewStuds = 45,      -- the east-west family's amplitude (the main and muster lines)
    nsStuds = 60,      -- the north-south family's (the flanks)
    harmonic = 1,      -- bends per junction span. AN INTEGER, OR THE JUNCTIONS STOP BEING ZEROS
})

-- ---- THE TWO SINES. `bend` is a trailing optional, the idiom this repo already uses for `layout`,
-- `spook`, `beater` and `rest`: the arithmetic is pure in a table handed in, so a spec can ask any
-- amplitude anything with no world running, and BOTH STATES ARE REACHABLE BY PARAMETER.
Grid.bendZ(x: number, bend: Bend?): number          -- the E-W family's z offset at a world x
Grid.bendX(z: number, bend: Bend?): number          -- the N-S family's x offset at a world z
Grid.bendSlopeZ(x: number, bend: Bend?): number     -- d(bendZ)/dx, for the tangent and the normal
Grid.bendSlopeX(z: number, bend: Bend?): number
Grid.maxBendStuds(bend: Bend?): number              -- max(ewStuds, nsStuds); every world box grows by it

-- ---- THE TWO MAPS. `toGrid` IS THE DEFINITION; `toWorld` is its numeric inverse, five fixed-point
-- steps, residual <= 1e-7 studs (section 5.6). One direction only would be a second definition.
Grid.toGrid (x: number, z: number, bend: Bend?): (number, number)
Grid.toWorld(u: number, v: number, bend: Bend?): (number, number)

-- ---- THE ROADS. The rows of `Grid.roads()` / `roadsOf()` are UNCHANGED and are now explicitly in
-- GRID coordinates: `axis`, `at`, `from`, `to`. The world curve is asked for, never re-derived.
Grid.roadCentreAt(road: Road, along: number, bend: Bend?): number   -- road.at + the other family's bend
Grid.roadTangentDeg(road: Road, along: number, bend: Bend?): number
Grid.roadPolyline(road: Road, samples: number, bend: Bend?): { Vector2 }  -- world points, one sampler

-- ---- THE STANDS. `standGridOf` is TODAY'S ARITHMETIC, unchanged, in grid coordinates;
-- `standPosition` keeps its signature and is that point through `toWorld`, so every stand lies
-- exactly on its own road's world curve (asserted, grid.spec case 4).
Grid.standGridOf(id: string, standIndex: number): (number, number)
Grid.standPosition(id: string, standIndex: number): Vector3     -- unchanged signature

-- ---- WORLD BOXES, for everything that needs an axis-aligned world bound: the bake's region, the
-- boar field, the map's bounds, the border wood, `nearestCellTo`.
Grid.worldBoundsOf(id: string): Bounds       -- boundsOf grown by (nsStuds in x, ewStuds in z)
Grid.worldFootprint(): Bounds                -- footprint, same growth

-- ---- THE DERIVED FACTS, AS A FUNCTION AND NOT AS A COMMENT, so the spec and the console line read
-- the same numbers and nothing is transcribed (section 5).
Grid.bendFacts(axis: "x" | "z", bend: Bend?): {
    pitchStuds: number, amplitudeStuds: number, harmonic: number,
    swingDeg: number,      -- atan(A*pi*m/P)
    radiusStuds: number,   -- P^2 / (A*pi^2*m^2)
    sightStuds: number,    -- (P/(pi*m)) * sqrt(2 * ROAD_TRUNK_FLOOR / A)
    stairStuds: number,    -- Relief.VOXEL / tan(swing)
}
```

`Grid` still requires **only `Shotgun`**. It does not require `Relief`, `Places` or `ForestTest`, and
nothing requires it in the other direction. The one existing edge (`src/shared/Places` requires `Grid`)
is unchanged.

---

## 5. The numbers, every one of them derived

### 5.1 The wavelength is not a choice

| | east–west roads | north–south roads |
|---|---|---|
| junctions are at | the five N–S road centres | the three E–W road centres |
| junction pitch `P` | `cellWidthStuds + roadClearStuds` = **1112** | `cellDepthStuds + roadClearStuds` = **1472** |
| first junction | `originX + roadClearStuds/2` = −6679 | `originZ + roadClearStuds/2` = −6579 |
| half-wavelength | **1112 / harmonic** | **1472 / harmonic** |
| offset at every junction | `A·sin(πk)` = **0, exactly** | **0, exactly** |

`harmonic` must be a positive **integer**: at `m = 1.5` the zeros fall at 741-stud spacing and three of
the five junctions stop being zeros. `grid.spec` asserts `harmonic % 1 == 0`.

### 5.2 The amplitudes are a pair, chosen by one rule

**The rule: equal maximum tangent swing on both axes**, because every bound in this design — the
safety cone, the line plane's `+Z` normal, the perpendicular-versus-axis measure, the voxel stair —
is written in that angle, and one angle for the whole world is one number to check instead of two.

```
tan(swing) = A·π·harmonic / P
ewStuds = 45  ->  45π/1112 = 0.12713  ->  7.244 deg
nsStuds = 60  ->  60π/1472 = 0.12805  ->  7.295 deg      (equal to 0.05 deg)
```

### 5.3 What 45 and 60 buy, and the constraint that does NOT bind

| | E–W | N–S |
|---|---|---|
| lateral wander, peak to trough | ±45 studs (12.6 m) | ±60 studs (16.8 m) |
| **minimum plan radius** `P²/(Aπ²m²)` | **2,784 studs = 780 m** | **3,659 studs = 1,024 m** |
| published minimum for this class of road (source B) | 15–30 m | 15–30 m |
| so ours is | **26 to 52× looser than the real limit** | same |
| **view down the carriageway** `(P/πm)·sqrt(2·34/A)` | **435 studs** | **499 studs** |
| in stand gaps (150 main / 220 flank) | **2.9** | **2.3** |

**Curvature is not the binding constraint and the design says so plainly.** A real forest road's tight
bends come from gullies, rock and property lines at a 1:1 scale; our cell is 300 × 400 m of invented
ground whose landform is already flattened within 51 studs of every centreline
(`Relief.ROAD_FADE`). So the amplitude is sized by the **sight line**: from a main stand the trunk-free
corridor (34 studs each side, `Places.ROAD_TRUNK_FLOOR_STUDS`) closes the view at 435 studs, which is
**two to three stands' worth** — his neighbours are visible, the far end of the line is not. That is
the same thing `LAYOUTS.road`'s own header asked of the old sine (*"a shooter cannot see his
neighbour down the whole length"*), re-sized for a line that is now a shooting line and not a ride.

The sight figure is a **tangent-line approximation** (deviation `≈ ½κd²`), not a ray cast through the
planted wood. §11.4 measures it with a frame; §16 item 3 says it is not a measurement.

### 5.4 `flankFirstStuds`: 340 → 366, and this is the defect the bend would have shipped

`grid-map.md` §7's invariant is *"every pair of stands on DIFFERENT sides of a cell is at least
`Shotgun.CONFIG.RANGE_STUDS.Slug` (330) apart"*, and `Grid.flankFirstStuds` solves it:
`dx = 556 − 450 = 106`, `dz = sqrt(330² − 106²) = 312.5`, `+ flankMarginStuds 27` → 340.

**In world coordinates the shear eats that margin.** The tight pair is the main line's end stand
against the near flank stand. They differ by 340 studs in `v`, and `bendX` changes by up to
`0.12805 × 340 = 43.5` studs over that — straight off the `dx` term:

```
dx = 106 − 43.5 = 62.5  ->  needed dz = sqrt(330² − 62.5²) = 324.0
and the pair also loses up to 0.12713 × 106 = 13.5 studs of dz to bendZ
->  realised separation  sqrt(62.5² + (340 − 13.5)²) = 333.1 studs, 3.1 of margin, not 26.1
```

**The fix is the formula, not the literal.** Solve it where it is written, in world terms, by one
fixed-point iteration (it converges in two steps and the code does three):

```
f(n+1) = ceil( sqrt(range² − (dx0 − |bendX'|max · f(n))²) + |bendZ'|max · dx0 ) + flankMarginStuds
340 -> 365 -> 366 -> 366
```

**`Grid.flankFirstStuds()` = 366**, and the realised worst pair is **357.4 studs — 27.4 of margin**,
which is the margin the design asked for. `grid.spec` case 5 computes all 105 pairs of all 8 cells in
**world** coordinates with its own loop and reports the worst, so a CONFIG change that eats it is read
as a number and not as a pass.

**What moves with it, named:** `Sides.flanks.firstStuds`; `grid_ground.spec`'s two transcribed depths
(`standPosition("C1", 9).Z − main.at` 560 → **586**, `(…, 14)` 780 → **806**); and
`Places.CELL_PLANS`' comment that names those two depths. The flank's four stands now span
`366 + 3×220 = 1026` of 1430 studs, so the far one is 404 studs short of the muster road — unchanged
in kind.

### 5.5 Two measures of "distance to the road", one centreline

| Measure | Who asks | Why | Difference |
|---|---|---|---|
| **perpendicular** `|v − road.at| · cos(atan(bendSlope))` | `Places.roadDistance`, the mask, the census, the crown rule | a crown hangs over a road **perpendicular** to it. The trunk-free corridor must be 34 studs wide measured across the carriageway, not across the z axis | — |
| **axis-aligned** `|across − Grid.roadCentreAt(road, along)|` | `TerrainBake.roadAt`, `bandFor`, `Relief.columnsFor` | the voxel lattice is world-axis-aligned. A band that is perpendicular is not whole columns, and a ditch that is not whole columns is the merge already measured once | **≤ 0.82 %** (`1/cos 7.295°`) |

Both read **the same** `Grid.roadCentreAt`. The design states the bound, `grid_ground.spec` asserts it,
and the two residuals are: the realised carriageway is 0.16 studs narrower perpendicular than nominal,
and the tangent measure is up to **0.21 studs** optimistic against the true curve distance at 34 studs
(`½κd²`). The independent polyline check in the spec carries a 0.3-stud allowance for exactly that.

### 5.6 The rest of the arithmetic

| Quantity | Value | Derivation |
|---|---|---|
| shear Jacobian `1 − bendZ'·bendX'` | 1 ± **0.0163** | so a cell's area, and therefore `cellCapacity`, moves by ≤ 1.63 % |
| `toWorld` contraction per step | **0.0163** | the same product. From a 60-stud initial error: 4 steps → 4e-6, **5 steps → 7e-8 studs** |
| main-stand spacing along the road | 150 → **≤ 151.2 studs** (`150/cos θ`) | the nominal grid spacing is unchanged |
| main-stand spacing in world x | 150 **± 2.4 studs** | the second-order coupling, ≤ 1.63 % |
| **cell depth along any column** | **exactly 1430 studs** | the E–W roads are exact translates (§2 item 3) |
| voxel band stair | **4 studs lateral every 31.5 studs along** (E–W), 31.2 (N–S) | `Relief.VOXEL / tan θ`. One voxel; printed by the census, looked at by Karen (K-C) |
| blur anisotropy from the shear | **≤ 1.6 %** | the bake blurs the base on the world lattice and hands it in as `smoothedAt`; a 7.3° shear of an isotropic σ-24 Gaussian is a 1.6 % axis stretch |

---

## 6. Every consumer, and what happens to it

The brief asks for this list in full. Nothing below is optional reading: a consumer that is not in the
table is a consumer that was not checked.

### 6.1 Changed, because it crosses the seam

| Consumer (file · symbol) | Today | Becomes |
|---|---|---|
| `src/shared/Grid` · `standPosition` | main at `mainZ`, flank at `roads.west.at` | `toWorld(standGridOf(...))`. **On the road's world curve, exactly** |
| `src/shared/Grid` · `flankFirstStuds` | 340 | **366**, the world-coordinate fixed point (§5.4) |
| `src/shared/Grid` · `layoutFor` | `amplitudeStuds = 0`, `fieldNorthStuds = 1472`, `halfSpanStuds = 535` | **`amplitudeStuds = bend.ewStuds` (45)**, `fieldNorthStuds = cellDepth + roadClear + ewStuds` = **1517**, `halfSpanStuds = cellWidth/2 + nsStuds` = **595**. The memoisation and `centre` (a GRID point) are unchanged |
| `src/shared/ForestTest` · `roadZ` | `centre.Z`, or the 70-divisor sine | **delegates to `Grid` when `layout.sides ~= nil`**, exactly as `standX` and `standPosition` already do. **The cell branch comes FIRST**, before the `amplitudeStuds == 0` branch, or a cell would be evaluated with the line places' wavelength |
| `src/shared/ForestTest` · `exitZOf`, `boundsOf`, `fieldFor`, `beaterStart`, `roadPointAt`, `wavePoint`, `restPoint`, `laneLookPoint`, `releaseLine`, `stockWood` | read `roadZ` / `amplitudeStuds` | **unchanged, correct for free.** `exitZOf` already subtracts `amplitudeStuds`; `beaterStart`'s `roadZ(x) + beaterNorthStuds` lands on the muster road because the two are exact translates (§2 item 3) |
| `src/shared/Places` · `roadDistance` | `|z − road.at|` | **world in; `toGrid` once; the kernel is today's body; × `cos θ`** (§5.5). The kernel is `Places.roadDistanceGrid` |
| `src/shared/Places` · `clearOfEveryRoad` | world, straight | **world in; `toGrid` once**; the body is unchanged. The census's one road question goes through here |
| `src/shared/Places` · `mask` | world in, straight arithmetic | **world in; `toGrid` once; delegates to `Places.maskGrid`**, which is today's body verbatim. The planner calls `maskGrid` directly and pays no inverse |
| `src/shared/Places` · `plantCell`, `scatter` | generates and emits world | **generates in grid coordinates; maps each site with `toWorld` before `heightAt` and before the `Planting` row**. One call site |
| `src/shared/Places` · `rideSegments` | from `Grid.standPosition` (world) | from **`Grid.standGridOf`** — a ride is straight in grid coordinates and a gentle curve in the world |
| `src/shared/Places` · `cellFacts`, `standFacing`, `corridorXAt` | world | **grid coordinates, code unchanged.** The cache key stays `cellId`: these hold grid facts, which the bend does not move |
| `src/shared/Places` · `nearestCellTo`, `borderPlan` | world | `toGrid` at entry / `toWorld` at exit; `borderPlan` reads **`Grid.worldFootprint`** |
| `src/serverstorage/TerrainBake` · `roadAt` | `centre = road.at` | **`centre = Grid.roadCentreAt(road, along)`** — three lines. `bandFor`, the materials, the junction-square rule, the crown fall, the shoulder, the ditch, the verge and the bank are **unchanged**, and the band still snaps to whole **world** columns at each station (§5.5) |
| `src/serverstorage/TerrainBake` · `longProfile`, `profileSamples` | samples `(along, road.at)` | samples `(along, Grid.roadCentreAt(road, along))`. The grade clamp, the ≤ 2 %/50 st rule, the cut/fill cap and the breach report are unchanged |
| `src/serverstorage/TerrainBake` · `roadDistance` | its own straight copy | re-pointed at `Grid.roadCentreAt`. **Second copy, named: §12 F-4** |
| `src/serverstorage/TerrainBake` · `regionFor`, `unionOf`, `blendAt`, `cellAt` | `roads.west.at ± ROAD_HALF_STUDS`, straight boxes | grown by **`Grid.maxBendStuds()`**; `cellAt` converts with `toGrid` |
| `src/serverstorage/TerrainBake` · `shapeTile`, `limitGrid` | passes world points to `Relief` | **passes GRID points to `Relief` and a base reader composed with `toWorld`** (§7.3). `Relief` itself is untouched |
| `tools/terrainbake.py` · `luau_facts`, `cell_of`, `roads_of`, `region_for`, `EXPECTED_TILES` | an independent Python twin of the straight grid (Director decision 6) | **reads the three `bend` rows with `number_from` and grows `region_for` by the amplitude.** `EXPECTED_TILES` is re-derived and re-committed (the region grows by 45/60 studs, which can add a tile row). The captured `epochInput` fixture is **re-captured** (§7.4) |
| `src/shared/Grid/Relief.luau` · `epochInput` | hashes seven `Grid.CONFIG` keys | hashes **ten**: `+ bendEwStuds, bendNsStuds, bendHarmonic`. One line. **This is what forces the re-bake and catches a stale forest** (§7.4) |
| `tests/server/grid.spec.luau` · cases 3, 4, 5, 6, 11, 14, 15 and `amplitudeStuds == 0` | assert a straight world | §11.1 |
| `tests/server/grid_ground.spec.luau` · cases 5, 6, 8 and the two transcribed flank depths | straight | §11.2 |
| `tests/server/grid_relief.spec.luau` · cases 5, 10, 11 | straight roads at `road.at` | §11.3 |

### 6.2 Unchanged, and the reason each is unchanged

| Consumer | Why it needs nothing |
|---|---|
| `Grid.roads`, `roadsOf`, `boundsOf`, `footprint`, `cellOf`, `sideOf`, `standWalk`, `standCount`, `mainStandCount`, `seedFor`, `towerStands` | they are **grid**-coordinate facts, and the grid did not move |
| `Grid.separationStuds` | it reads `standPosition`, which is now world. The number it answers changes (356 → 357); the function does not |
| `src/shared/Grid/Relief.luau`, all of it | in grid coordinates the roads are straight, so `roadFadeAt`, `deltaAt`, `weightOf`, `limitPass`, `materialAt`, `columnsFor`, `isExempt`, `tiles` are already right (§7.3). `BAKE_VERSION` does not bump and `relief_golden.luau` does not move |
| `Places.cellGround`, `zoneRect`, `zoneAt`, `fieldRect`, `fernBands`, `skirtBands`, `neighboursOf`, `cellCapacity`, `laneHalfWidth`, `frontage*`, `standTypeFor`, `crownReachStuds`, `roadTrunkMin`, `rideTrunkMin` | grid-coordinate arithmetic, bend-free. `CELL_EDGE_STUDS`' 3-stud inset still keeps a jittered site out of a road's clear width, because that width is a grid band |
| `src/shared/TreeGround`, `Places.plantOne`, `clawFor`, `trunkBox`, `groundsUnder`, `stepAllowanceStuds` | world-only, and the contact rule is not geometry |
| `ForestTest.Markers.build`, `ring`, `groundFor`, `lineGroundFor`; `ForestTest.Seats` | they read `standPosition` and `roadZ` and measure the real ground under them |
| `ForestTest.standSpan`, `hunterStandX`, `nearestStand`, `withinStand`, `standArea`, `boundaryPoint` | they read `standX`/`standPosition`; the main span is still the main line's |
| `Match.lineReferenceFor`, `crossedLine`, `beaterGoalFor`, `gatherSpotFor`, `Markers.Set.linePosts`, `Fill.standsFree` | **this is the mechanism built for a curved road in the first place** — `lineReferenceFor`'s own header: *"the stands stand ON the road, so the nearest one sideways is where the line really is for this beater"*. §6.5 |
| `Weapon.SafetyArc`, `Match.Penalty`, `Match.lineUnsafeFor`, `Weapon.Rules` | person-relative or `+Z`-relative. §6.5 |
| `Bots.Lane` | goal-directed. The goal is `beaterGoalFor`, which is post-relative |
| `MapUi.geometryFromForestTest` | it already samples `data.roadZ(x, layout)` into a polyline and already adds `layout.amplitudeStuds` to its bounds. `GEOMETRY_MARGIN_STUDS` 60 still covers 45; `ROAD_SAMPLES` 33 over 1,190 studs is a 36-stud chord on a 2,224-stud wavelength |
| `Hud.Objective.targetFor` | it reads the geometry's polyline |
| `GridCensus.measure`, `brokenReason`, the floating/sunk/tilted/foliage rules | contact arithmetic, not geometry. Its one road question is `clearOfEveryRoad` (§6.1) |

### 6.3 The seam, in one sentence

**Four functions convert, and everything else is one coordinate space:** `Places.roadDistance`,
`Places.clearOfEveryRoad`, `Places.mask` and `Places.nearestCellTo` take world coordinates and call
`Grid.toGrid` once; `Places.plantCell` and `Grid.standPosition` produce world coordinates by calling
`Grid.toWorld`; the bake converts per sampled point. **Inside `Places` nothing is bend-aware**, which
is why `cellFacts` keeps its cache key and `Relief` keeps its code.

### 6.4 The one place the stand slots' FACING changes meaning, and it is safe

`Places.standFacing` returns `(0, ±1)` or `(±1, 0)` and is now explicitly a **grid**-coordinate unit
vector. Mapped into the world, the front cone (`Places.CONE.halfDegrees` 30) is therefore
perpendicular to the **local road**, not to the drive axis — and the drive axis is at most **7.3°**
off it, so **22.7° of the cone still lies up-drive**. That is the honest statement of what the cone
clears after the bend, and it is a spec case, not a comment (§11.2). No code changes.

### 6.5 Safety, the line plane and the drive's endings — D10 again, with the bend in it

| Rule | Evidence | After the bend |
|---|---|---|
| `Match.lineUnsafeFor` (6), `Match.Penalty.judge` (12 / 330), `Weapon.Rules.beaterInLine` | person-relative | **unchanged** |
| `Weapon.SafetyArc.isForbidden`, 45° about `line.normal` | `Markers.build` sets `normal = Vector3.zAxis`; `Match.Markers.read`'s *"the part's −Z faces the drivers"* | **unchanged.** A hunter square to his own road is ≤ 7.3° off `+Z` (against the old road's accepted **±23°**), and a hunter looking **along** the road is 82.7°–97.3° off it, far outside the cone |
| `Match.lineReferenceFor` / `crossedLine` / `beaterGoalFor` | nearest post **laterally**, `+Z` normal | **unchanged, and this is the case it was written for.** A beater now crosses at his own post's z, which is `main.at + bendZ(x)` — the bulge, not the baseline. New spec case (§11.1) |
| the 330-stud cross-side invariant | `Grid.separationStuds`, `grid.spec` case 5 | **holds, at 357.4 studs**, because the **derived** set-back moved (§5.4). No safety number moved |
| the beaters' walk, `END_ON_BEATERS_CROSS`, `BEATERS_THROUGH_GRACE_SECONDS` | `grid-map.md` §4.3 | **unchanged: exactly 1430 studs along every column** (§2 item 3), so 275 s ± 0 |

---

## 7. The bake, and why `Relief.luau` is not touched

### 7.1 What is re-baked, and from what

**C1 only, from the base snapshot.** `TerrainBake.snapshot` wrote
`<runs-dir>/terrain-base-<sha>.bin` in 328k and `heightAt` **never reads live terrain**, so re-baking
C1's region writes absolute heights over the old bake rather than layering on it: the straight road's
cut and fill are **erased**, not stacked. That property is the whole reason B2's base snapshot exists,
and it is what makes this a re-run and not a repair.

The region grows by `Grid.maxBendStuds()` (60) on each side before the 128-stud tile rounding, so every
tile the old straight road touched is re-written.

### 7.2 What changes inside a tile

Three lines of `TerrainBake.roadAt` (the centre becomes a function of the station) and the two profile
samplers. **Nothing else**: the long profile's 20-stud sampling, the 15 pinned junctions, the 8 %/10 %
grade clamp, the ≤ 2 %-per-50-studs change, the 12-stud cut-or-fill cap and its printed breach, the
junction square rule (*"the E–W profile wins"*), the carriageway, the ruts at d ±6…±10, the ditch's two
columns, the verge, the 1:2 bank and every material are untouched.

**The one measured consequence is the stair** (§5.6): the band is snapped to whole world voxel columns
at each station, so the rut's and the ditch's edges step by one voxel (4 studs) every 31.5 studs along
a bend. That is the lattice's own resolution and the alternative is the merge
`Places.SURFACES.track.ruts` already measured. The census prints the realised column centres and the
achieved ditch depth, as it already does; **K-C is Karen looking at it**, and the named fallback is
`grid-terrain.md` §15 item 2's: the ditch goes to one whole 4-stud column.

### 7.3 `Relief` is composed, not changed

For each world voxel column the bake computes `(gx, gz) = Grid.toGrid(x, z)` and calls

```
Relief.heightAt(form, Grid.boundsOf(id), Grid.roads(), baseAtGrid, gx, gz, blend, smoothedAt)
   where  baseAtGrid(a, b) = baseAtWorld(Grid.toWorld(a, b))
```

In grid coordinates the roads are straight at `road.at`, so **`roadFadeAt` becomes curve-correct with
no edit**, the landform's `u`/`v` follow the cell, `isExempt` finds the scarp where the recipe put it,
and the base is still read at the real world point. Two named approximations: the blur is run on the
world lattice and handed in (≤ 1.6 % anisotropy, §5.6), and the slope limiter stays a world-lattice
pass because slope is a world property.

**So `Relief.BAKE_VERSION` stays 1 and `relief_golden.luau` does not move** — no arithmetic moved. The
golden fixture is the obligation that enforces that claim: if the Builder edits `Relief`'s maths, the
samples stop matching and the spec's own message demands the bump.

### 7.4 The epoch is what forces the re-bake and catches a stale forest

`Relief.epochInput`'s key list gains `bendEwStuds`, `bendNsStuds`, `bendHarmonic`. Therefore:

* the moment the bend's numbers are committed, `TerrainEpoch` changes;
* `Workspace.GridForest`'s `PlantEpoch` no longer matches, so `ForestTest.prebuildVerdict`'s **third
  branch** fires: *"print REFUSED with both epochs and dress NOTHING"* — the designed protection
  against a forest standing on ground that moved under it;
* `GridCensus` fails on the mismatch rather than certifying the old wood;
* `tools/terrainbake.py`'s captured `epochInput` fixture (its cross-check of the two canonical-JSON
  encoders) must be **re-captured in the same commit**, or `selftest` reddens CI. Named, so nobody
  discovers it in a review round.

---

## 8. The capacity bound — what blocked "more trees", and what replaces it

### 8.1 The bound that blocks is the wrong bound

`tests/server/grid.spec.luau` case 14 asserts `cellCapacity(id) < 3600` and `#plantCell(id) < 3600`.
C1's capacity is **3,416** (`reviews/task-328m/RESULT.md`, re-derived by the Reviewer:
`1,875 + 516 + 1,025`), so there are **184** of slack — a **2.6 %** spacing reduction. Karen asked for
more trees; the spec says no.

**And the number carries a ratio that measurement refuted.** `grid-map.md` §8.3 derives it from
*"**parts per drive** < 22,000 — ≈ 7 descendants per model"*. The measured figure in Karen's place is
**3.03** (5,104 parts for 1,687 models, task 328m claim 7, re-derived by the Reviewer). The two
published bounds never even agreed with each other: 3,600 models × 7 parts = 25,200, which is 3,200
parts **past** the same section's own ceiling.

### 8.2 Two derived bounds, both with teeth

```luau
-- src/shared/Places/init.luau
-- MEASURED, in Karen's Forest Test at 328m's code commit: 5,104 parts for 1,687 planted models in C1
-- (reviews/task-328m/RESULT.md). It SUPERSEDES design 8.3's "~7 descendants per model", which was
-- derived from the four line places and which made the model bound and the part ceiling disagree by
-- 3,200 parts. It is C1's MIX: a recipe that plants more of a 7-part template moves it, which is why
-- the census prints `parts/trees` every run and this number is re-read, not trusted forever.
Places.PARTS_PER_MODEL = 3.03

Places.PART_BUDGET_DRIVE = 22_000   -- design 8.3's per-drive part ceiling, unchanged
Places.PART_BUDGET_CELL  = 8_000    -- grid-terrain 12.2's per-cell row. DERIVED, NOT MEASURED:
                                    -- 328g's client frame is what can raise or lower it

Places.CELL_PLAN_CAP = math.floor(Places.PART_BUDGET_DRIVE / Places.PARTS_PER_MODEL)  -- 7,260
Places.CELL_PART_CAP = math.floor(Places.PART_BUDGET_CELL  / Places.PARTS_PER_MODEL)  -- 2,640
```

Case 14 then asserts three things and **prints all of them**:

1. `#plantCell(id) <= cellCapacity(id)` — unchanged, and the one with real teeth (delete the plan and
   it reddens);
2. `cellCapacity(id) <= Places.CELL_PLAN_CAP` — the typo guard: a zone at spacing 2 plans 100,000 sites
   and this catches it before anything is cloned;
3. `#plantCell(id) <= Places.CELL_PART_CAP` — **the bound that now binds**, in models, against a part
   ceiling.

### 8.3 What that gives Karen

| | old | new |
|---|---|---|
| C1 capacity / its cap | 3,416 / 3,600 | 3,416 / **7,260** |
| C1 drawn / its cap | — | 1,687 / **2,640** |
| room, in models | **184** | **953** |
| room, as a spacing cut | 2.6 % | **20 %** |
| C1 parts at the cap | — | 8,000 of 8,000; the world at 8 cells is 64,000, which is `grid-terrain.md` §12.2's own ~63,000 |

**The honest limit, said so nobody claims otherwise:** the per-cell part ceiling is **UNMEASURED**
(`grid-terrain.md` §12.2). The real gate is 328g's client frame at ≤ 16.7 ms with ≤ 17,000 parts inside
1,024 studs, and no spec and no request may cite 8,000 as a measurement until that run happens.

---

## 9. The switch, the re-bake and the rollback

### 9.1 Born at zero

`Grid.CONFIG.bend = { ewStuds = 0, nsStuds = 0, harmonic = 1 }` is **today's world, value for value**:
`bendZ` and `bendX` return 0, `toGrid` and `toWorld` are the identity, `standPosition` is
`standGridOf`, `roadCentreAt` is `road.at`, `layoutFor`'s `amplitudeStuds` is 0 and the epoch is
unchanged. So the structural task (§13 step 2) is **provably inert** — every shipped spec answers
exactly what it answers today — and `grid.spec` asserts that identity as a case.

### 9.2 Switched on by the commit that re-bakes

The amplitudes go to 45/60 in the **same commit** that re-bakes C1, re-surveys it and re-plants it,
because a bent road under a straight bake is a ditch 60 studs from the carriageway and stands on a
pad that is not theirs. That commit also re-writes, from the post-bake survey's printed numbers:
`Grid.CELLS.C1.relief` (the four fields), `lineMeanY` (the main line moved), and
`towers` / `towersRelaxed` (327b's instrument re-run — the stands moved, so the measurement is stale).

### 9.3 By commit, never by flag — task 79, verbatim

The world lives in the place. A `Flags` row for the bend would mean a baked, bent ditch and a straight
`Places.mask` in the same session: the flag-off build would plant trees into the real ditch and the
census would read `inRoad` non-zero while every spec passed. That is task 79's measurement exactly —
*"the same commit went from 32/32 checks to 22/27 with eleven specs failing"* — and CLAUDE.md's rule:
**a switch that cannot be switched off is not a feature flag.** No `Flags` row, no `MAX_FLAGS` bump.

### 9.4 The rollback, step by step

1. **A fresh Forest Test backup before anything is baked** — File › Download a Copy, to
   `<runs-dir>/ft-backup-2026-11-xx.rbxl`, noted in `backups/README.md`. **NEEDS KAREN**, step 0 of the
   re-bake task, and the tool refuses without a `--backup` under 6 hours old anyway.
2. To undo: restore that `.rbxl` (the one rollback Workspace has — there is no terrain undo an API can
   reach) **and** commit `bend` back to `{ 0, 0 }`. Both, or the code and the ground disagree.
3. Nothing else rolls back, because nothing else is written: `Workspace.GridForest` is destroyed by
   nothing in `src/`, and the epoch mismatch makes the boot refuse rather than rebuild.

---

## 10. External sources (rule 1)

**I could not fetch any of these: the Architect has Read, Grep and Glob and no network.** Every licence
and maintenance status below is from knowledge, and §16 item 1 says so. The research note for this work
must check each one.

### A. ASAM **OpenDRIVE** — the road-network description standard
<https://www.asam.net/standards/detail/opendrive/> ·
<https://publications.pages.asam.net/standards/ASAM_OpenDRIVE/ASAM_OpenDRIVE_Specification/latest/>
**Licence:** an ASAM standard; the specification is published for free reading and the recent HTML
releases carry a Creative Commons attribution/no-derivatives licence. **No text and no schema is
reproduced here; the decomposition is what is taken.** **Maintenance:** actively maintained — 1.8
released under ASAM's stewardship in 2024, after the hand-over from VIRES.
**Does well:** it is the industry's answer to exactly this problem. A road is a **reference line** in
plan (`geometry` records: `line`, `arc`, `spiral`, `poly3`); everything else about the road — lanes,
widths, ditches, objects, markings — is placed in **`(s, t)` coordinates relative to that line**; and
`lateralProfile`/`laneOffset` expresses *"shift the whole cross-section sideways from the reference
line as a function of `s`"*, which is literally our `bend`. **Junctions are first-class**: roads are
connected at them, so "the junctions still meet" is a stated fact and not an emergent one.
**Does badly:** it is a *description* format for simulators, not a generator — it has nothing to say
about how much a forest road should bend or how often; its `spiral` (clothoid) needs a numeric integral
per sample where our pinned sine is one `math.sin`; and its `t` axis is strictly **perpendicular** to
the reference line, which stops being invertible inside the curvature radius — a trap our axis-graph
form does not have, at the price of the 0.82 % difference §5.5 states.
**Adopted:** the reference-line + lateral-offset decomposition, the rule that the cross-section is a
function of the offset alone, and junctions as pinned facts. **Not adopted:** clothoids, and the
perpendicular `t` frame.

### B. USDA Forest Service / USAID — **"Low-Volume Roads Engineering: Best Management Practices Field Guide"** (Keller & Sherar, 2003)
<https://www.fs.usda.gov/t-d/pubs/pdf/LowVolumeRoads/LVR_BMP_Field_Guide.pdf>
**Licence:** a work of the United States federal government — **public domain**. Facts used, nothing
reproduced. **Maintenance:** 2003, still distributed by the Forest Service's Technology & Development
programme and widely re-hosted; **not revised**.
**Does well:** it is the only source here with real numbers for *this class of road* — a single-lane
forest road with a 3.5–4.5 m running surface, a ditch, a crown or outslope, and **minimum curve radii
of roughly 15–30 m** (tighter at switchbacks); plus the alignment rule that a forest road should follow
the natural contour and avoid long tangents. Our §7.1 cross-section is this shape, and our 780 m
minimum radius is **26 to 52 times looser** than its limit — which is the fact that tells us curvature
is not what sizes the bend.
**Does badly:** it is a drainage-and-erosion guide. Its radii come from the turning circle of a log
truck, which neither our boar nor our hunters have, and it says nothing about sight lines for shooting
— the only thing Karen judges.
**Adopted:** the published minimum as the floor we are nowhere near (so the amplitude is sized by the
sight line instead), and the contour-following principle — recorded as the deviation we take, with its
reason, as open decision K-B.

### C. FAO — **Watershed Management Field Manual: road design and construction in sensitive watersheds** (FAO Conservation Guide 13/5)
<https://www.fao.org/4/t0099e/t0099e00.htm>
**Licence:** © FAO; the document repository permits non-commercial reproduction with attribution
(FAO's newer works are CC BY-NC-SA 3.0 IGO). Nothing is reproduced. **Maintenance:** 1989, still
published in the FAO document repository; **not revised**.
**Does well:** forest-road geometric design from first principles — horizontal alignment, gradient
limits, curve widening, and the explicit principle that a forest road is **laid to the ground** rather
than imposed on it, which is why long straight sections are rare in forest terrain. It is the clearest
statement of *why* Karen's sentence is right.
**Does badly:** metric and truck-centric, written for watershed protection; it has nothing on the half
of our problem that is a game, and its curve-widening arithmetic assumes a vehicle we do not simulate.
**Adopted:** "the road is laid to the ground" as the named deviation (K-B) and the gradient discipline
that `grid-terrain.md` §7.1 already carries, unchanged by this task.

### D. Red Blob Games — **"Curved paths"** (Amit Patel)
<https://www.redblobgames.com/articles/curved-paths/>
**Licence:** the articles' code is published for reuse; the prose is the author's. Nothing reproduced.
**Maintenance:** the site is actively maintained; this article is older and live. It is the same author
`grid-map.md` §12D and `grid-terrain.md` §11G already credit.
**Does well:** the clearest short statement of the two conditions a jointed curve must satisfy —
**position continuity at the joints and tangent continuity through them** — and of what a
position-only joint looks like: a kink. That is the junction condition, and it is the whole reason a
per-span amplitude is rejected in favour of one sine per axis (§2 item 5).
**Does badly:** it is about agents following paths on a grid. No cross-section, no terrain, no voxels,
no road.
**Adopted:** tangent continuity as a hard condition.

### E. Roblox — `Terrain:WriteVoxels` and `Region3:ExpandToGrid`
<https://create.roblox.com/docs/reference/engine/classes/Terrain#WriteVoxels>
**Licence:** first-party, source repo `Roblox/creator-docs`, **CC BY 4.0**. **Maintenance:** actively
maintained. Already cited as `grid-terrain.md` §11A, and carried here for one reason: the voxel lattice
is **world-axis-aligned and 4 studs**, which is why §5.5 keeps the bake's bands axis-aligned and why
the stair in §5.6 is one voxel and not a defect. **Does badly:** it still states no limits at all.

---

## 11. How it is tested

Standing rule G: a spec in no scope turns CI red. Every file below is already in a scope
(`src/shared/Grid/` → `map`, `src/shared/Places/` and `src/server/Places/` → `places`,
`src/shared/TreeGround/` → `lobby`); **no `SCOPE_SPECS` or `BLAST_RADIUS` row changes**, and
`tools/studio_mcp.py selftest` proves it.

### 11.1 `tests/server/grid.spec.luau` — scopes `map`, `places`

Changed:

* **case 3 (the footprint is the arithmetic)** — the grid rectangles and the road rows are unchanged;
  **added**: `worldFootprint` is `footprint` grown by `(nsStuds, ewStuds)`, every road's **world
  polyline** lies inside it, and no two cells' grid rectangles overlap (as today);
* **case 4 (a main index agrees with `ForestTest.standPosition`)** — unchanged to 1e-9, **and** every
  one of the 15 stands lies on its own road's world curve to 1e-6 (the assertion that replaces
  `at.Z == roads.main.at` and `at.X == roads.west.at`);
* **case 5 (no stand within slug range of a stand on another side)** — unchanged assertion, computed by
  the spec's own loop over all 8 cells and all 105 pairs **in world coordinates**, with the worst pair
  **reported** (≥ 330, expected 357.4);
* **case 6 (`flankFirstStuds` is the formula and not a literal)** — recomputed in the case from
  `cellWidth`, `roadClear`, `mainCount`, `mainSpacing`, `RANGE_STUDS.Slug` **and the two bend slopes**,
  including the fixed point, asserted to converge in ≤ 3 steps;
* **case 11 (the walk)** — unchanged; the walk is a grid fact;
* **case 14 (the budget)** — rewritten per §8.2, printing capacity, drawn, drawn × 3.03 and both slacks;
* **case 15 (nothing planted in a road's clear width)** — asserted **independently** of
  `Places.roadDistance`: the spec samples each road's world curve every 2 studs with
  `Grid.roadPolyline`, takes the true perpendicular distance to every planting, and asserts ≥ 21
  (any planting) and ≥ 34 (any trunk), with a 0.3-stud allowance for §5.5's curvature residual — and
  also through the function, which is `drive-places.md` §10.4 item 3's lesson;
* the line `expect(layout.amplitudeStuds).to.equal(0)` becomes
  `expect(layout.amplitudeStuds).to.equal(Grid.CONFIG.bend.ewStuds)`.

New:

1. **the bend is exactly zero at every junction** — for all 8 roads and all 15 crossings,
   `bendZ(ns.at) == 0` and `bendX(ew.at) == 0` to **1e-12**, and the two world curves meet at exactly
   `(ns.at, ew.at)`. **This is brief decision 2 and it is the first case;**
2. **the maps round-trip** — `toGrid(toWorld(p)) == p` and `toWorld(toGrid(q)) == q` to **1e-6** over a
   50-stud lattice across the footprint, at the shipped bend and at twice it;
3. **the harmonic is an integer and the swings are equal** — `harmonic % 1 == 0`, and the two axes'
   `bendFacts().swingDeg` agree to 0.1°, which is the rule §5.2 picked the pair by;
4. **the roads of an axis are exact translates** — over 200 stations,
   `roadCentreAt(EW1, x) − EW1.at == roadCentreAt(EW2, x) − EW2.at`, so the cell's depth is
   `cellDepthStuds` along every column. **This is the case that keeps §4.3's 275 s;**
5. **the facts are derived, not transcribed** — `bendFacts` recomputed in the case from `P`, `A` and
   `m`, and `swingDeg`, `radiusStuds`, `sightStuds` and `stairStuds` **reported**;
6. **a beater crosses at the bulge** — a fake `Set` with 15 posts on the curve, a beater driven down
   the cell-centre column: `lineReferenceFor` answers the **main** post (not a flank one, §6.4 of
   `grid-map.md`), and `crossedLine` flips at `main.at + ewStuds` and not at `main.at`;
7. **bend 0 IS today's world, value for value** — with `{ ewStuds = 0, nsStuds = 0 }`,
   `standPosition`, `roadDistance`, `toGrid`, `layoutFor` and `plantCell` answer exactly what they
   answered before this task. **This is what makes the structural task provably inert;**
8. **the four old places are untouched** — case 2's boundary re-asserted: `road`, `edge`, `ride` and
   `track` have nil `sides`, so `roadZ` never reaches the grid branch and `forest_stand.spec`'s
   number-for-number assertions stand.

### 11.2 `tests/server/grid_ground.spec.luau` — scopes `lobby`, `places`, `map`

* **case 5** — no trunk within **34 studs perpendicular** of a road centreline and 27 of a ride
  centreline, over every cell, asked independently (the sampled polyline) and then through the mask;
* **case 6 (the crown)** — unchanged thresholds, now against the curve; `crownOverRoad` still reads
  `UNMEASURED` with no `TEMPLATE_DIMS` row;
* **case 8 (ferns)** — every fern ≥ 34 studs from a road centreline, measured perpendicular;
* the two transcribed flank depths move with §5.4 (560 → 586, 780 → 806);
* **NEW: one rule, two spaces** — `Places.roadDistance(toWorld(p)) == roadDistanceGrid(p) · cos θ` over
  a lattice to 1e-6, and `Places.mask`'s answer is invariant under `toWorld ∘ toGrid`;
* **NEW: the cone still covers the drive** — for every main and flank stand, the angle between
  `standFacing` mapped into the world and the drive axis is ≤ `bendFacts().swingDeg`, and
  `CONE.halfDegrees − swingDeg ≥ 22°` (§6.4);
* cases 1–4, 7, 9–12 unchanged.

### 11.3 `tests/server/grid_relief.spec.luau` — scope `map`

* **case 1 (the golden fixture)** — unchanged, and that is the point: `BAKE_VERSION` stays 1 because no
  arithmetic in `Relief` moved;
* **case 5 (the road fade)** — asked in **grid** coordinates, with the case saying why, and asserting
  that a **world** point within 51 studs of the curved centreline converts to a grid point inside the
  zero band;
* **case 10 (whole voxel columns)** — **per station**: over 50 stations along a bent road, the realised
  band edges are multiples of 4 in **world** z, at centres ≡ 0, 1, 2 and 3 (mod 4), and the stair pitch
  is **reported** (31.5 studs);
* **case 11 (the epoch)** — `epochInput` carries the three bend rows; the epoch changes when an
  amplitude changes and is stable when nothing does;
* **NEW: the junction pins do not move** — `TerrainBake.junctionPins` answers the same pin at any
  amplitude, because each road's line is a zero of the other family's bend;
* **NEW: the cross-section is the same section, moved** — `roadAt` sampled across a bend at 40 stations
  gives the same band widths, the same materials and the same crown fall as the straight case, within
  the one voxel §5.6 states.

### 11.4 Live, in Karen's Forest Test — what a spec cannot answer

Every FT task pastes its probe lines beside the DEV harness line. **The DEV harness cannot evidence FT
work and no line may pretend otherwise.**

| What | Probe | Target |
|---|---|---|
| the re-bake's cost | `[bake]` line, ten tiles first | worst tile ≤ 8 s, peak memory ≤ 6 GB, per-tile seconds printed |
| the roads | `[census]` road rows | crossfall ≤ 0.5 st / 20 st; grade inside its limit; cut-or-fill ≤ 12 st **or reported**; the junction step at all 15 crossings |
| the ditch and the ruts on a bend | `[census]` at the **realised** column centres | depth 2 ± 1.0 st; the stair reported in studs, both pitch and height |
| the pads | `[census]` pad rows | all 15 of C1 at relief ≤ 1.8 st; `towersRelaxed` **expected to stay false** for C1 — if it flips, that is a finding, not a pass |
| every tree on the ground and off the road | `[census]` per cell | `floating`, `sunk`, `tilted`, `broken`, `inRoad`, `inStand`, `crownOverRoad` all **0**; `refused` ≤ 8 % |
| the bend, as a number in the world | the boot's `grid preview` line plus `Grid.bendFacts` | swing, radius, sight and stair printed, so the console says what shipped |

**Frames (rule 5) — and the harness fault is reported, not worked around (rule 6).** The route that
works is `Camera.TestLook`'s held `DHTestLook` attribute plus `shot.ps1` (`ESCALATE.md` 2026-11-01;
task 306h item 1). Per planting or baking task: **3 frames of C1** — the signature stand, **the
line-centre stand looking down the bending road (this is the frame that shows the bend, and it is the
one Karen's sentence asks for)**, and a 45° aerial. A frame whose sha256 matches an earlier frame
**counts as no frame**. Until the cached-image fault is fixed, rule 5 on this work is **Karen's eye and
nothing else**, and no task may claim a frame it could not take (rule 8). Inherited open decision D-1.

**Harness input (Task 6):** nothing here is input-driven, so `tests/client/input_scenarios.txt` is
untouched.

**Client (`tests/client/map_ui.spec.luau`):** **no change in this task.** `MapUi.geometryFromGrid` does
not exist yet (327f is unbuilt; `src/client/` contains no reference to `Grid`), and the live Forest Test
map draws a line place through `geometryFromForestTest`, which already samples `roadZ`. One queued note
for 327f: the world view's eight road polylines must come from `Grid.roadPolyline`, never from a
re-typed sine — `MapUi`'s own stated rule.

---

## 12. Defects found by reading the code

Each would have been inherited. Each has a file, a symbol and a fix.

**F-1 — the bend eats the safety margin, and nothing would have said so.** `Grid.flankFirstStuds`
solves the 330-stud invariant in plane coordinates; in world coordinates the shear takes up to 39.9
studs off the `dx` term and the tightest pair falls from 356.1 to **333.1 studs — 3.1 of margin**.
`grid.spec` case 5 would still have passed. **Fix:** re-derive the set-back in world terms (§5.4),
340 → **366**, and make case 5 compute the pairs in world coordinates.

**F-2 — the epoch would not have changed, so the census would have certified the old forest.**
`Relief.epochInput` hashes a **fixed list of seven** `Grid.CONFIG` keys and `assert`s each exists, so a
bend added to `CONFIG` is invisible to it: `TerrainEpoch` would be unchanged, `PlantEpoch` would match,
`ForestTest.prebuildVerdict` would take the *"the prebuild stands"* branch, and C1's forest would keep
standing on a landform whose roads had moved 60 studs. **Fix:** the key list gains the three bend rows
(§7.4), and `grid_relief.spec` case 11 asserts the epoch moves with an amplitude.

**F-3 — `Ground.chunkFor` hard-codes the line places' wavelength.**
`src/server/Places/Ground.luau`'s `chunkFor(layout, surface)` reads `layout.amplitudeStuds` and divides
by `Forest.SHAPE.wavelengthDivisor` (70). A cell layout's amplitude becomes 45 with a wavelength of
2,224 — 32× that divisor. Today no cell reaches it (`Places.surfaceFor` has no cell row and
`paintRoads` is archived), and the error direction is conservative (a chunk that is too short is slow,
not wrong). **Fix:** one `assert` refusing a layout with `sides ~= nil`, so the next task that gives a
cell a surface row gets a refusal instead of a silent mis-chunk.

**F-4 — there are two `roadDistance` functions, and the second one is in the bake.**
`Places.roadDistance` and `TerrainBake.roadDistance` are the same arithmetic in two files
(`TerrainBake`'s splits the dry-run diff into road and landform). Both are re-pointed at
`Grid.roadCentreAt` in the same commit; neither is re-derived. **Named here so the next reader knows
there are two and that `Grid` owns the line they both read.**

**F-5 — `tools/terrainbake.py` holds a straight Python twin of the grid.** `cell_of`, `roads_of`,
`footprint` and `region_for` re-implement `Grid.boundsOf`/`roadsOf`/`regionFor` deliberately (Director
decision 6: *"the two must agree"*). With a bend in Luau and not in Python, `plan` would refuse a
correct region or accept a short one, and `EXPECTED_TILES` would be wrong. **Fix:** the three bend rows
join `luau_facts()` through the existing `number_from` regex route, `region_for` grows by the amplitude,
and `EXPECTED_TILES` plus the captured `epochInput` fixture are **re-derived and re-committed in the
same commit**.

**F-6 — pre-existing, not created here, and queued rather than fixed:** the six beater corridors
(`Places.CORRIDOR.atStuds` = 160…910 from the cell's west edge) and the bots' actual lanes
(`ForestTest.beaterLaneOffset`, which deals offsets either side of **the hunter's chosen stand**) are
two different sets of x values and **were never aligned**. The shear does not create the mismatch and
does not worsen it — the corridors bend with the cell, which is what a deer path in a sheared cell
looks like — but a trunk-free corridor that no beater walks down is 10 studs of clearing bought for
nothing. Evidence: `Places.CORRIDOR`, `ForestTest.beaterLaneOffset`, `ForestTest.laneSpacing`. For
`TASKS.md` under "before release".

---

## 13. The task split, and the order against 328h, 328i and 328g

Each step is one task, small, testable, and committed with the research note rule 1 asks for
(`docs/research/2026-11-03-curved-grid-roads.md`, indexed in `docs/research/INDEX.md`, **before any
code**). The ids below are the Director's to assign; I have used 328p…328s so the order can be read.

| # | Task | Days | Gate | Karen sees |
|---|---|---|---|---|
| **328p** | **THE CAPACITY BOUND, DERIVED.** `Places.PARTS_PER_MODEL` 3.03 (measured, cited), `PART_BUDGET_DRIVE`/`_CELL`, `CELL_PLAN_CAP` 7,260, `CELL_PART_CAP` 2,640; `grid.spec` case 14 rewritten to the three assertions and printing both slacks; the archived text for §8.1's refuted ratio under `backups/` with a note. **No world change, no geometry.** It is first because it un-blocks "more trees" on its own | **0.5** | one-player | not yet (a number, not a pixel) |
| **328q** | **THE BEND, PURE AND INERT AT ZERO.** `Grid.CONFIG.bend` at `{0, 0, 1}`; `bendZ`/`bendX`/`bendSlope*`/`toGrid`/`toWorld`/`roadCentreAt`/`roadTangentDeg`/`roadPolyline`/`bendFacts`/`maxBendStuds`/`worldBoundsOf`/`worldFootprint`; `standGridOf` + `standPosition`; `flankFirstStuds` re-derived; `layoutFor`'s three fields; `ForestTest.roadZ`'s cell branch; the four seam functions in `Places` plus `maskGrid`/`roadDistanceGrid`/`plantCell`/`rideSegments`; `TerrainBake`'s `roadAt`/`longProfile`/`profileSamples`/`roadDistance`/`regionFor`/`unionOf`/`blendAt`/`cellAt`/`shapeTile`/`limitGrid`; `Relief.epochInput`'s key list; `Ground.chunkFor`'s refusal (F-3); `tools/terrainbake.py`'s bend rows, `region_for`, `EXPECTED_TILES` and the re-captured epoch fixture (F-5); every spec change in §11.1–11.3 **driven by parameter**. **Provably inert: the whole suite answers what it answers today** | **1.5** | one-player | not yet |
| **328r** | **C1's GROUND, RE-BAKED AT THE BEND.** Step 0: the **backup** (NEEDS KAREN) and the live-override clear. Then `bend` to **45 / 60**, ten tiles measured first, C1's region re-baked from the **328k base snapshot** (shape and material in one pass), the junction steps and the ditch depth measured at the realised column centres, the stand pads re-cut, then the **re-survey** → `relief`, `lineMeanY`, `towers`/`towersRelaxed` written by the same commit. The boot's epoch mismatch is expected and is printed | **1.5** + bake time | one-player + the `[bake]` and `[census]` road/pad lines | **YES: she walks C1's bending roads and stands at a junction. 3 frames, one of them straight down the road** |
| **328s** | **C1's FOREST, RE-PLANTED.** The v2 plan over the new ground, the density raised inside 328p's bound (Karen's *"more trees"*), `GridForest` re-planted at the new epoch, the census at 0, `refused` ≤ 8 % | **1.0** | one-player + the `[census]` line | **YES: C1, denser, with a road that bends. 3 frames** |

**The order, and why:**

1. **328p before 328s**, because "more trees" is blocked by a bound and not by the road.
2. **328q before 328r**, because a bend in the ground with a straight mask is a ditch in the wood and a
   stand off its pad. The inert-at-zero shape is what makes that a safe two-commit split rather than
   one unreviewable task.
3. **328r and 328s before 328h** — brief decision 5, and it is the whole point: no cell is baked
   straight and then baked again. 328h picks the bend up for free, because by then it is `Grid.CONFIG`.
4. **328i after 328h**, unchanged. Its eight recipes are grid-coordinate data and the bend costs it
   nothing.
5. **328g moves to after 328h, and that is a change to the Director's split.** Its subject is the
   Edit-time prebuild and the performance gate **for C1 and its four neighbours**, and four of those
   five are unbaked until 328h. Running it first means baking those four twice and measuring a frame
   that the second bake invalidates. If the Director prefers it early, it must be **scoped to C1
   alone** and say so in its own definition of done.

So: **328p → 328q → 328r → 328s → 328h → 328i → 328g.**

---

## 14. Deltas to the designs this touches — exact text for the Builder to paste

The Architect script writes only this file, so each delta below is pasted into the named document as
part of the task that makes it true.

**`docs/design/grid-map.md`** — a new **§19, *Superseded by the curved roads (task 328o)***:
> **§2's ruling that a cell's roads are straight in plan is OVERRIDDEN by
> `reviews/task-328o/BRIEF.md` and `docs/design/grid-roads.md`.** Every road bends, by one sine per
> axis whose **half-wavelength is the junction pitch**, so the offset is exactly zero at every junction
> and **§4.2's topology, ids, drive direction, main line, muster line and flanks are untouched**.
> `Grid.layoutFor`'s `amplitudeStuds` becomes the east–west amplitude (45) and `ForestTest.roadZ`
> delegates to `Grid` for a cell exactly as `standPosition` already does. **§7's `flankFirstStuds` goes
> 340 → 366**: the invariant is solved in WORLD coordinates, because the shear takes up to 39.9 studs
> off its `dx` term and left the 330-stud separation with 3.1 studs of margin instead of 26.1 — the
> realised worst pair is 357.4. **No safety number moves.** §4.3's 275-second beater walk is unmoved,
> because the roads of an axis are exact translates and the cell's depth is `cellDepthStuds` along every
> column. **§8.3's "hard bound < 3,600 models" and its "≈ 7 descendants per model" are superseded** by
> two bounds derived from the measured **3.03** parts a model: a plan cap of 7,260 and a draw cap of
> 2,640 a cell (`grid-roads.md` §8) — the old pair disagreed with this section's own 22,000-part
> ceiling by 3,200 parts. **§13.1 cases 3, 4, 5, 6, 11, 14 and 15 move** and eight cases are added.
> **The bend ships BY COMMIT, never as a feature flag** (task 79's exception, `grid-roads.md` §9.3).
> **The full design is `docs/design/grid-roads.md`, and where the two disagree that document wins.**

**`docs/design/grid-terrain.md`** — a new **§19, *The roads bend (task 328o)***:
> **§7.1's cross-section is measured from a centreline that is now a FUNCTION of the station:**
> `centre = Grid.roadCentreAt(road, along)`. The long profile's sampling, the 15 pinned junctions, the
> grade clamp, the ≤ 2 %/50 st rule, the 12-stud cut-or-fill cap, the junction-square rule, the
> carriageway, the ruts at d ±6…±10, the ditch, the verge, the bank and every material are
> **unchanged**; three lines of `TerrainBake.roadAt` move. **Correction F-2 is kept and extended: the
> band snaps to whole WORLD voxel columns at each station**, so the ditch and the rut stay whole
> columns everywhere, at the cost of a 4-stud lateral stair every 31.5 studs along a bend — one voxel,
> printed by the census, with §15 item 2's 4-stud ditch as the named fallback. **§4's `Relief.luau` is
> not touched, not one line**: the bake hands it GRID coordinates and a base reader composed with
> `Grid.toWorld`, and in grid coordinates the roads are straight, so `roadFadeAt` becomes
> curve-correct for free. **`BAKE_VERSION` stays 1 and `relief_golden.luau` does not move;
> `Relief.epochInput`'s key list gains the three bend rows**, so the epoch changes, the stale-forest
> refusal fires and `tools/terrainbake.py`'s captured epoch fixture is re-captured in the same commit.
> **§7.4's pads, §8.2's mask, §8.5's stand types and §9.4's census all keep their arithmetic**, because
> everything inside `src/shared/Places` is grid-coordinate and bend-free; four functions convert at the
> seam. **C1 is re-baked from the 328k base snapshot** — absolute heights over the old bake, so the
> straight road's cut and fill are erased, not layered — and the re-survey re-writes `relief`,
> `lineMeanY`, `towers` and `towersRelaxed` in the same commit.

**`docs/design/drive-layouts.md`** — append to §13:
> **A cell's road bends (task 328o).** `ForestTest.LAYOUTS`' cell rows carry
> `amplitudeStuds = Grid.CONFIG.bend.ewStuds`, and `ForestTest.roadZ` resolves a cell through
> `Grid`, not through `SHAPE.wavelengthDivisor`. The four line places keep `road`'s 30-over-70 sine and
> every number `forest_stand.spec` asserts for them.

**`docs/design/map-ui.md`** — append to §21:
> **The grid's roads are curves (task 328o).** `geometryFromGrid`'s eight road polylines come from
> **`Grid.roadPolyline(road, samples)`** and are never re-typed as a sine — this document's own rule,
> stated for `geometryFromForestTest` and binding here. The world view's bounds are
> `Grid.worldFootprint()` plus the margin. Nothing in `src/client/` changes until 327f, which is the
> task that must honour this.

---

## 15. Open decisions

### Karen (feel and design)

**K-A. HOW MUCH BEND.** 45 studs on the main line and 60 on a flank put the far end of her view 435
studs down the road — **about three stands**, so she sees her neighbours and not the whole line. Looser
(25/35) opens it to 580; tighter (90/120, at a 27° swing) closes it at 154 studs, inside one stand gap,
and starts to press on the safety cone. **One row each, and it is a frame rather than a number.**

**K-B. SHOULD THE BEND FOLLOW THE GROUND?** Real forest roads bend because of the terrain (sources B
and C), and ours bend because of arithmetic. The cheap upgrade is **one measured sign per axis per
span**, taken off the base snapshot at the re-bake and written into `Grid` by a commit, exactly as the
`relief` rows are — the bend would then lean toward the low ground. The full version (an alignment
solved against contours) re-opens every junction pin and the whole bake, and the landform is itself
flattened within 51 studs of each centreline, so the road would be following ground it had already
levelled. **Default: seeded-free arithmetic, as designed.**

**K-C. THE WHOLE WORLD'S EAST–WEST ROADS BOW THE SAME WAY** (§2 item 3). From a stand that is invisible;
from the map's world view it reads as a consistent wave. Per-road variety costs up to **17 seconds** of
beater-walk difference between columns and re-opens `grid-map.md` §4.3. **Does she want variety enough
to pay that?**

**K-D. THE DITCH STAIRS BY ONE VOXEL EVERY 31 STUDS ON A BEND** (§5.6, §7.2). It is the lattice's own
resolution and the alternative is the merge already measured. **Look at the frame; the fallback is a
4-stud ditch, one whole column, which `grid-terrain.md` §15 item 2 already names.**

### Director (scope)

**D-A. RATIFY BY-COMMIT, NOT BY-FLAG** (§9.3). The bend is born at 0 and switched on by the commit that
re-bakes. No `Flags` row, no `MAX_FLAGS` bump.

**D-B. 328g MOVES AFTER 328h** (§13 item 5), or is re-scoped to C1 alone and says so.

**D-C. `EXPECTED_TILES` AND THE EPOCH FIXTURE ARE RE-COMMITTED** in 328q (F-5). Both are committed
numbers whose whole purpose is that someone says the new value out loud; the Director should see them
in the diff.

**D-D. THE PYTHON TWIN STAYS A TWIN.** Director decision 6 keeps `tools/terrainbake.py`'s independent
re-implementation of the grid arithmetic. It gains the bend. The alternative — asking Studio for the
numbers — removes the independence that caught the round-2 region defect. **Confirm the twin stays.**

**D-E. F-6 IS QUEUED, NOT FIXED** (the corridors and the bots' lanes were never aligned). It goes under
"before release" in `TASKS.md`, not into this split.

**D-1 (inherited, still open) — THE FRAME FAULT.** `screen_capture` against the Forest Test returns one
cached image for six cameras (`ESCALATE.md`, 2026-11-01) and `ftplay.py capture` ignores the camera
during Play (task 306h). The `DHTestLook` route works and is what §11.4 mandates. Either it is fixed,
or every task here is accepted on Karen's eye and **says so**. This design cannot close it and will not
pretend to.

---

## 16. Not verified (no Studio, no network in an Architect run)

1. **Every external link in §10 was not fetched.** The Architect has Read, Grep and Glob. Licences and
   maintenance statuses are from knowledge and must be checked when the research note is written
   (rule 1). Source B's *"15–30 m"* and source A's licence wording are the two I would check first.
2. **No number in this document was measured in Karen's place by me.** Everything measured is quoted
   with its file or review: `Grid.CONFIG`'s geometry, `Places.CROWN_DRIFT_STUDS`' pivot drift,
   `Places.SURFACES.track.ruts`' merge, `MapGen.Config.VOXEL`'s ceiling, task 328m's **3.03** parts a
   model and C1's **3,416** capacity and **1,687** drawn models, 327c's 0.69 ms a model, 327b's tower
   measurement.
3. **The sight-closure figures (435 / 499 studs) are a tangent-line approximation**, not a ray cast
   through the planted wood: `½κd²` against a 34-stud corridor. The frame in §11.4 is the measurement;
   this is the reason to take it.
4. **The re-bake's cost is not re-measured.** C1 was 208 tiles; the per-tile cost is 328j/328k's figure
   and the bend changes no per-tile work, but §12.2's rule stands — the `[bake]` line reads `MEASURED`
   or the request says `UNMEASURED`.
5. **The 4-stud stair has never been looked at.** It is arithmetic (`VOXEL / tan θ`), and whether it
   reads as a ditch or as a sawtooth is K-D.
6. **`PARTS_PER_MODEL` 3.03 is C1's mix only** (5,104 / 1,687). A recipe that plants more of a 7-part
   template moves it; the census prints `parts/trees` every run and the bound must be re-read, not
   trusted.
7. **The per-cell 8,000-part ceiling is UNMEASURED** (`grid-terrain.md` §12.2). 328g's client frame is
   the only thing that can confirm or move it, and no gate may cite it as evidence before then.
8. **I did not run the harness, open Studio, take a frame, read a terrain voxel or bake a tile.** Task
   328o is docs-only.
