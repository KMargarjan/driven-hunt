# Curved grid roads: the eight roads bend in plan (task 328o)

Rule 1's note for `docs/design/grid-roads.md`. Written by the Builder, 2026-11-03, **after** the
Architect's design run and before any code, which is the order task 328o was dispatched in: the design
is the input, and this note is the check on it.

Karen, 2026-11-03 ~11:20 UTC, C1 playtest 2, verbatim: *"more trees, and road could be also not just
straight make line in real life"*.

Two things are done here that the Architect could not do, and both were asked for by name in the
dispatch:

1. **Every source in `grid-roads.md` section 10 was FETCHED.** The Architect has Read, Grep and Glob and
   no network, and its section 16 item 1 says every licence and maintenance status was written from
   knowledge. Section 2 below is what the network actually returned, and **all five sources carry a
   correction.**
2. **Every number in `grid-roads.md` sections 5 and 8 was RE-DERIVED from `Grid.CONFIG`**, not copied.
   Section 4 is the arithmetic with its inputs. **Two numbers do not reproduce**, and they are findings
   against the design rather than silent fixes.

---

## 1. What the system must do

| Must | Why |
|---|---|
| Every road in the world bends in plan; no road is a ruler line | Karen's sentence above |
| Every junction stays exactly where it is, so the eight cells stay closed and a hunter on a corner still stands at a crossing | `reviews/task-328o/BRIEF.md` decision 2 |
| The 2x4 topology, the cell ids, the drive direction and the main / muster / flank lines per cell are untouched | BRIEF decision 1 |
| One owner for the centreline: a pure function in `src/shared/Grid` | rule 3, BRIEF |
| The drive's arithmetic identities hold: the beaters' walk is exactly `cellDepthStuds`, and `grid-map.md` 4.3's 275 s does not move | 1430 / 5.2 = 275 s is where the cell size came from |
| The 330-stud cross-side stand separation (`Shotgun.CONFIG.RANGE_STUDS.Slug`) stays true in **world** coordinates | it is the whole safety proof |
| Borrow the sine already in this repo before inventing one | rule 2, BRIEF decision 3 |
| Inert until a commit switches it on: amplitude 0 reproduces today's world value for value | task 79's measured map-switch rule |
| Un-block "more trees" -- the blocker is a capacity bound, not the road | Karen's first clause |

**Must not:** move a junction by a stud; create a second centreline; make `Relief.luau` curve-aware;
change the road cross-section, its materials, its grade clamp or its cut/fill cap; change any safety
number; ship as a feature flag (it is a world switch by commit, task 79).

---

## 2. The five sources, FETCHED

Every URL below was fetched on **2026-11-03** from this session. Where a fetch failed, the failure is
printed, not papered over.

### A. ASAM **OpenDRIVE** -- the road-network description standard

<https://www.asam.net/standards/detail/opendrive/> ·
<https://publications.pages.asam.net/standards/ASAM_OpenDRIVE/ASAM_OpenDRIVE_Specification/v1.9.0/specification/index.html>

**Fetched: both pages, 200.** **Maintenance: actively maintained** -- the detail page says the standard
is "in maintenance mode" with change requests "constantly" collected, and the current release is
**v1.9.0, specification dated 2026-05-08** (the detail page gives the release as 2026-05-19).
**Licence:** ASAM's own, not Creative Commons: *"The licensor grants everyone a basic, non-exclusive and
unlimited license to use the standard ASAM OpenDRIVE"*, with unrestricted distribution, and the download
is *"free of charge"*. Nothing is reproduced here; the decomposition is what is taken.

**DELTA vs the design (section 10 A):** it says *"1.8 released ... in 2024"* (**stale by a major
release**) and *"the recent HTML releases carry a Creative Commons attribution/no-derivatives licence"*
(**wrong** -- it is an ASAM grant, and it is *more* permissive than CC BY-ND, so nothing we do becomes
newly unsafe). Also `poly3` **is listed as deprecated** in 1.9.0, so the design's list of geometry
records should read `line`, `arc`, `spiral`, `paramPoly3`.

**Does well, confirmed on the page:** section 9 *Geometries* is a plan-view reference line built from
straight lines, spirals, arcs and parametric cubics; section 11.5 *Lane offset* is exactly "shift the
whole cross-section sideways from the reference line as a function of s"; section 12 *Junctions* is a
first-class chapter (common, direct and virtual junctions, connecting roads, boundaries). So the
design's three content claims all hold.
**Does badly:** a description format for simulators, not a generator -- it says nothing about how much a
forest road should bend or how often; its spiral needs a numeric integral per sample where our pinned
sine is one `math.sin`; and its `t` axis is strictly perpendicular to the reference line, which stops
being invertible inside the curvature radius.
**Adopted:** the reference-line + lateral-offset decomposition, the cross-section as a function of the
offset alone, and junctions as pinned facts. **Not adopted:** clothoids, and the perpendicular `t` frame.

### B. Keller & Sherar, **"Low-Volume Roads Engineering: Best Management Practices Field Guide"** (USDA Forest Service / USAID / Virginia Tech CMI, **July 2003**)

**The official URL in the design,
<https://www.fs.usda.gov/t-d/pubs/pdf/LowVolumeRoads/LVR_BMP_Field_Guide.pdf>, returned HTTP 403
Forbidden to this fetcher.** The document was read instead from a complete re-host --
<https://www.cedengineering.com/userfiles/C08-013%20-%20Low-Volume%20Roads%20Engineering%20-%20US.pdf>
(PDH course C08-013, which wraps the guide's own pages unaltered: the same title page, the same
"LOW-VOLUME ROADS BMPS: i..." page footers, the same Table 4.1) -- fetched 200, 4.7 MB, extracted with
`pdftotext -layout`. So the text below is the guide's own, but **"still distributed by the Forest
Service's T&D programme" could not be confirmed from here**: the Forest Service's copy is 403 to a tool.

**Licence / status, as the document itself states it:** produced for **USAID** in co-operation with
**USDA Forest Service, International Programs** and the **Conservation Management Institute, Virginia
Polytechnic Institute and State University**, July 2003. It carries **no copyright notice** -- only a
USDA / USAID disclaimer (*"The U.S. Department of Agriculture (USDA) or U.S. Agency for International
Development (USAID) assumes no responsibility for the interpretation or use of this information"*).
**Maintenance: 2003, not revised.** **DELTA vs the design (section 10 B):** it asserts *"a work of the
United States federal government -- public domain"*. The absence of a copyright notice and the federal
authorship point that way, but a university institute is a named co-producer and the document makes no
public-domain statement, so **"no copyright notice; US federal plus university co-production"** is what
is provable and is what this note claims. It changes nothing we do: only facts are used, and nothing is
reproduced.

**THE "15-30 m" FIGURE IS WRONG. This is the check the dispatch asked for first.** Table 4.1,
*TYPICAL LOW-VOLUME ROAD DESIGN STANDARDS*, gives two columns and no range:

| Design Element | Rural Access Road | Collector Road |
|---|---|---|
| Design Speed | 25-35 kph | 45-60 kph |
| Road Width | 3.5-4.5 m | 4-5.5 m |
| Road Grade | 15% max. | 12% max. |
| **Curve Radius** | **15 m min.** | **25 m min.** |
| Crown/Shape | outslope/inslope (5%) | in/outslope or crown (5%) |

and the recommended practice is a single number: *"Locate roads with a minimum curve radius of 15
meters."* **There is no 30 anywhere in the document** -- `grep -i "radius\|radii"` over the extracted
text returns four lines: these two and two about *hydraulic* radius. Our road is the **Rural Access**
column by its own running surface, because 3.5-4.5 m is `grid-terrain.md` 7.1's carriageway (20 studs =
5.6 m with the verge; the painted running surface is 18 studs = 5.0 m). So **the published floor for our
class of road is 15 m, and 25 m is the floor for a wider collector road.** What that changes in the
design's section 5.3 is in section 4 below: only the ratio row, and it moves in our favour.

**Also a delta:** the design credits source B with *"the alignment rule that a forest road should follow
the natural contour **and avoid long tangents**"*. The contour half is verbatim present -- *"Locate
roads to follow the natural terrain by conforming to the ground, rolling the grade, and minimizing cuts
and fills"*, with Figure 4.1 *"The affects of road alignment across topography"* and *"Conforming to
topography minimizes earth work"*. **"Avoid long tangents" is not in the document.** The reason a real
forest road is not a ruler line is in this source as *conforming to the ground*, which is the honest
form of Karen's sentence.
**One more:** the design says source B's radii *"come from the turning circle of a log truck"*. Table 4.1
pairs the radius with a **design speed** (25-35 kph), so it is a speed-and-geometry standard; the truck
is in the road-width and switchback rows. The design's point -- that the figure is not about sight lines
for shooting -- survives either reading.

**Does well:** the only source here with real numbers for *this* class of road, plus the contour rule.
**Does badly:** it is a drainage-and-erosion guide; it says nothing about sight lines, which is the only
thing Karen judges.
**Adopted:** the published minimum as a floor we are nowhere near (so the amplitude is sized by the
sight line instead), and the contour-following principle **as a recorded deviation** -- our bend is
arithmetic, not terrain-following (open decision K-B, Director default taken 2026-11-03).

### C. FAO -- **Watershed Management Field Manual**, FAO Conservation Guide **13/5**, Rome, **1998**, ISBN 92-5-102789-X

<https://www.fao.org/4/t0099e/t0099e00.htm> -- **fetched, 200.**

**Licence: ALL RIGHTS RESERVED.** The document states: *"All rights reserved. No part of this
publication may be reproduced, stored in a retrieval system, or transmitted in any form or by any means,
electronic, mechanical, photocopying or otherwise, without the prior permission of the copyright
owner."* **DELTA vs the design (section 10 C):** it says *"the document repository permits
non-commercial reproduction with attribution (FAO's newer works are CC BY-NC-SA 3.0 IGO)"* -- **not true
of this document**, which predates that policy. **Nothing is reproduced from it here**, which is what
keeps it usable: facts and principles only. **Second delta: the printed year is 1998, not 1989** (the
series designation "13/5" in the design is right).
**Maintenance:** 1998, still published in the FAO document repository, not revised.

**Does well, confirmed in the fetched table of contents:** section 3 *Road design*, with **3.1
Horizontal and Vertical Alignment**, 3.1.1 Horizontal Alignment Considerations, 3.1.2 Curve Widening and
3.1.3 Vertical Alignment -- forest-road geometric design from first principles, 122 figures and 44
tables. It is the clearest statement of *why* a forest road bends.
**Does badly:** metric and truck-centric, written for watershed protection; its curve-widening
arithmetic assumes a vehicle we do not simulate; nothing about the half of our problem that is a game.
**Adopted:** "the road is laid to the ground" as the named deviation (K-B), and the gradient discipline
that `grid-terrain.md` 7.1 already carries, unchanged by this task.

### D. Red Blob Games -- **"Curved paths"** (Amit Patel)

<https://www.redblobgames.com/articles/curved-paths/> -- **fetched, 200.**

**Licence:** site-wide, *"Accompanying code is open source, under either the MIT License or the Apache v2
License. Both allow use in commercial projects"*; the prose is the author's. The design's wording is
**accurate**. **Maintenance: live and actively maintained** -- the article footer reads *"Created Nov
2012"*, *"Last modified: 22 Jun 2026"*.
**Does well:** the continuity ladder in one page -- *"We can connect line segments together into
piecewise linear curves, which have G0 continuity"*, *"We can connect circular arcs into piecewise
circular curves, which have G1 continuity"*, and with cubic Beziers *"G2 continuity"* -- plus what a
G0-only joint costs in practice: *"you have to abruptly shift your steering wheel when transitioning
from a straight segment to a curved segment"*. **Small delta:** the article argues the point in the
G0/G1/G2 vocabulary and the steering discontinuity; the design's paraphrase (*"a position-only joint
looks like a kink"*) is that content, not a quotation.
**Does badly:** it is about agents following paths on a grid -- no cross-section, no terrain, no voxels.
**Adopted:** tangent continuity as a **hard** condition, which is why one sine per axis beats a per-span
amplitude whose positions would match at a junction and whose tangents would not.

### E. Roblox -- terrain voxels and `Region3:ExpandToGrid`

<https://create.roblox.com/docs/parts/terrain> ·
<https://create.roblox.com/docs/reference/engine/classes/Terrain#WriteVoxels> ·
<https://github.com/Roblox/creator-docs/blob/main/LICENSE> -- **all fetched, 200.**

**Licence: CC BY 4.0**, confirmed at the repository's own LICENSE file (*"reproduce and Share the
Licensed Material"* with attribution, royalty-free, irrevocable). **Maintenance: actively maintained**
(first-party, `Roblox/creator-docs`). The design's section 10 E is **right about the licence.**
**The 4-stud figure is confirmed, but not on the page the design links:**
`create.roblox.com/docs/parts/terrain` states *"Terrain is made up of grids of voxels which are 4x4x4
stud regions in the 3D world with a set material"*. **DELTA:** the `Terrain` class reference the design
cites states neither the resolution nor the alignment, and the `Region3` reference documents
`ExpandToGrid(resolution)` with **no description at all** -- so this note cites `docs/parts/terrain` for
the 4 studs, and **"the lattice is world-axis-aligned" is NOT stated by any Roblox page fetched here.**
It is this repo's own measured fact (`Relief.VOXEL = 4`, `MapGen.Config.VOXEL = 4`, and `Relief.tiles`'
assertion `tileStuds % Relief.VOXEL == 0`), and the design's 5.5 / 5.6 should rest on that rather than
on a documented guarantee.
**Does badly:** it still states no limits at all -- the 24,576-voxel `WriteVoxels` ceiling this repo
builds to is measured, not published (`docs/research/2026-11-02-terrain-v2.md`).

### Borrowed before building (rule 2) -- in-repo, no licence question

The sine is **not invented**: `ForestTest.LAYOUTS.road` already curves
(`z = centre.Z + amplitude * sin((x - centre.X) / divisor)`, `amplitudeStuds = 30`), and with it come
three disciplines this design keeps whole -- *"**0 IS A STRAIGHT LINE**: one shape, not two"*,
`exitZOf`'s `- amplitudeStuds`, and `MapUi.geometryFromForestTest`'s rule that the map **asks** for
`roadZ` and never re-types the sine. Also borrowed: `Relief.columnsFor` / `Ground.bandBounds` for the
voxel snap, `Grid.seedFor` for anything seeded, `Places.forgetCells` for the cache door, and task 79's
world-switch-by-commit with its rollback recipe. **Nothing here is new geometry. What is new is that the
half-wavelength is pinned to the junction pitch.**

---

## 3. The pattern adopted, and why

**The grid keeps its coordinates; the world is sheared.** One sine per axis, shared by every road on
that axis, with the **half-wavelength equal to the junction pitch**:

```
bendZ(x) = ewStuds * sin( pi * harmonic * (x - (originX + roadClearStuds/2)) / (cellWidthStuds + roadClearStuds) )
bendX(z) = nsStuds * sin( pi * harmonic * (z - (originZ + roadClearStuds/2)) / (cellDepthStuds + roadClearStuds) )
Grid.toGrid(x, z)  = ( x - bendX(z), z - bendZ(x) )            -- the definition
Grid.toWorld(u, v) = its numeric inverse, 5 fixed-point steps
```

Why this and not the alternatives:

1. **The junction condition is `sin(pi*k) = 0`** -- exact, at every junction, with no solver and no
   tolerance. That is BRIEF decision 2 satisfied by construction.
2. **At any road's own line the other axis's offset is zero**, so each road is the *graph* of one sine
   over its own axis. The stands, the long profiles and the map polyline are one `math.sin` each.
3. **One sine per axis makes the roads of an axis exact world translates**, so the cell depth is exactly
   1430 studs along every column and the 275-second beater walk does not move. A per-road amplitude or
   sign breaks that by up to 90 studs, which is 17 s at 5.2 studs/s. The named cost: all three east-west
   roads bow the same way (open decision K-C; from the ground it is not a visible fact).
4. **In grid coordinates every piece of arithmetic in this repo is already correct** -- road distance,
   the cell rectangles, the zones, the rides, the fern bands, the skirts, the capacity count, the
   landform's u/v. Only four functions cross the seam, and `Relief.luau` is not touched at all.
5. **Tangent continuity everywhere** (source D). A per-span amplitude -- one bend per cell, signed from
   the seed -- is rejected: positions would match at a junction and tangents would not, which is a kink
   in the carriageway.

**Rejected, with reasons:** clothoids (source A), a numeric integral per sample for a smoothness nobody
at 5.2 studs/s can feel; a perpendicular `t` frame (source A), not invertible inside the curvature
radius where our axis-graph form always is, at the price of the 0.82 % measure difference in section 4;
terrain-following alignment (sources B and C), which re-opens every junction pin and the whole bake, and
the landform is already flattened within 51 studs of each centreline (`Relief.ROAD_FADE.zeroStuds`), so
the road would be following ground it had itself levelled (K-B, default taken).

---

## 4. The numeric targets, RE-DERIVED from `Grid.CONFIG`

Inputs, all read from `src/shared/Grid/init.luau` at `c30a4512`: `originX = -6700`, `originZ = -6600`,
`cellWidthStuds = 1070`, `cellDepthStuds = 1430`, `roadClearStuds = 42`, `mainStandCount = 7`,
`mainSpacingStuds = 150`, `flankStandCount = 4`, `flankSpacingStuds = 220`, `flankMarginStuds = 27`;
`Shotgun.CONFIG.RANGE_STUDS.Slug = 330`; `Places.ROAD_TRUNK_FLOOR_STUDS = 34`; `Relief.VOXEL = 4`;
carriageway 20 studs (`grid-terrain.md` 7.1); **1 stud = 0.28 m** (`Grid.CONFIG`'s own header).
Amplitudes `ewStuds = 45`, `nsStuds = 60`, `harmonic = 1` (K-A, Director default 2026-11-03).

| Quantity | Inputs | Derived here | Design section 5 | Agrees? |
|---|---|---|---|---|
| E-W junction pitch | 1070 + 42 | **1112** | 1112 | yes |
| N-S junction pitch | 1430 + 42 | **1472** | 1472 | yes |
| first E-W junction x | -6700 + 42/2 | **-6679** | -6679 | yes |
| first N-S junction z | -6600 + 42/2 | **-6579** | -6579 | yes |
| offset at a junction | `A*sin(pi*k)` | **0, exactly** | 0 | yes |
| E-W max slope / swing | 45*pi/1112 | 0.12713 -> **7.245 deg** | 0.12713 / 7.244 | slope yes, angle **7.245** |
| N-S max slope / swing | 60*pi/1472 | 0.12805 -> **7.297 deg** | 0.12805 / 7.295 | slope yes, angle **7.297** |
| the two swings differ by | -- | **0.052 deg** | 0.05 | yes |
| E-W min plan radius | `P^2/(A*pi^2*m^2)` = 1112^2/(45*pi^2) | **2784.2 st = 779.6 m** | 2784 / 780 | yes |
| N-S min plan radius | 1472^2/(60*pi^2) | **3659.0 st = 1024.5 m** | 3659 / 1024 | yes |
| source B's floor for our class | Table 4.1, Rural Access | **15 m** (collector: 25 m) | "15-30 m" | **NO -- finding 1** |
| so ours is looser by | 779.6/15, 1024.5/15 | **52x (E-W), 68x (N-S)** | "26 to 52x", N-S "same" | **NO -- finding 1** |
| E-W view down the carriageway | `(P/(pi*m))*sqrt(2*34/A)` | **435.1 st** | 435 | yes |
| N-S view down the carriageway | same, 1472 and 60 | **498.8 st** | 499 | yes |
| in stand gaps | 435.1/150, 498.8/220 | **2.90**, **2.27** | 2.9, 2.3 | yes |
| flank `dx0` | (1070/2 + 42/2) - (7-1)/2*150 = 556 - 450 | **106** | 106 | yes |
| straight `dz` | sqrt(330^2 - 106^2) | **312.512**, ceil + 27 = **340** | 312.5 / 340 | yes |
| straight realised pair | hypot(106, 340) | **356.14**, margin **26.14** | 26.1 | yes |
| bendX over 340 st of v | 0.12805 * 340 | **43.54**, so dx **62.46** | 43.5 / 62.5 | yes |
| needed dz at that dx | sqrt(330^2 - 62.46^2) | **324.04** | 324.0 | yes |
| bendZ over 106 st of x | 0.12713 * 106 | **13.48** | 13.5 | yes |
| **realised pair at 340** | hypot(62.46, 340 - 13.48) | **332.44, margin 2.44** | "333.1 studs, 3.1 of margin" | **NO -- finding 2** |
| `flankFirstStuds` fixed point | 340 -> 365 -> 366 -> 366 | **366** | 366 | yes |
| realised worst pair at 366 | hypot(59.13, 352.52) | **357.45, margin 27.45** | 357.4 / 27.4 | yes |
| `standPosition("C1", 9).Z - main.at` | 366 + 220 | **586** (was 560) | 586 | yes |
| `standPosition("C1", 14).Z - main.at` | 366 + 440 | **806** (was 780) | 806 | yes |
| flank span, and short of the muster road | 366 + 3*220 = 1026; 1430 - 1026 | **1026**, **404** | 1026 / 404 | yes |
| shear Jacobian | 1 - 0.12713*0.12805 | **1 +- 0.0163** | 0.0163 | yes |
| `toWorld` error from 60 st, per step | *0.0163 each | 0.98, 0.016, 2.6e-4, **4.2e-6**, **6.9e-8** | 4e-6 / 7e-8 | yes |
| main-stand spacing along the road | 150 / cos(7.245 deg) | **151.21** | <= 151.2 | yes |
| perpendicular vs axis-aligned measure | 1 / cos(7.297 deg) | **+0.82 %** | <= 0.82 % | yes |
| carriageway narrower perpendicular | 20 * 0.0082 | **0.16 st** | 0.16 | yes |
| tangent approximation error at 34 st | `0.5*34^2/2784.2` | **0.208 st** | 0.21 | yes |
| voxel band stair | 4/0.12713, 4/0.12805 | **31.46**, **31.24** st | 31.5 / 31.2 | yes |
| cell depth along any column | the E-W roads are exact translates | **exactly 1430** | 1430 | yes |

**Capacity (design section 8), re-derived:** `PARTS_PER_MODEL` = 5104 / 1687 = **3.0255 -> 3.03**;
`CELL_PLAN_CAP` = floor(22000 / 3.03) = **7260**; `CELL_PART_CAP` = floor(8000 / 3.03) = **2640**; room =
2640 - 1687 = **953** models, which as a spacing cut is `1 - 1/sqrt(2640/1687)` = **20.1 %** against the
old bound's `1 - 1/sqrt(3600/3416)` = **2.6 %**; C1's capacity 1875 + 516 + 1025 = **3416**, so **184**
of slack under today's `grid.spec` case 14 (`capacity < 3600` **and** `total < 3600`, both at
`tests/server/grid.spec.luau`); 2640 * 3.03 = **7999** parts, about the 8000 cell row, and 8 cells =
**64,000**, about `grid-terrain.md` 12.2's own ~63,000. The refuted ratio's own contradiction reproduces
too: 3600 * 7 = 25,200, which is **3,200 parts past** the same section's 22,000 ceiling.
**All of section 8 reproduces exactly.**

### The two findings against the design

**Finding 1 -- section 5.3's published-minimum row is not what source B says, and the ratio row is
wrong.** Source B gives **15 m min.** for a Rural Access Road (3.5-4.5 m running surface, our class) and
**25 m min.** for a Collector Road. There is no "15-30 m" and no 30 m anywhere in it. The design's
*"26 to 52x looser"* is 780/30 to 780/15, so its lower end rests on a figure that is not in the source;
and the N-S column's *"same"* is wrong independently, because the N-S minimum radius is 1,024 m, not
780 m. **Corrected row: E-W 780 m is 52x source B's floor for our class (31x the collector floor); N-S
1,024 m is 68x (41x).** **What it changes in the design: only that row.** The conclusion it supports --
that curvature is not the binding constraint, so the amplitude is sized by the sight line (435 / 499
studs) and not by a radius -- is **strengthened**, because the true margin is larger than claimed.
Nothing downstream reads the ratio: section 5.2's amplitudes come from the equal-swing rule, and the
sight figures from the corridor width. **Not blocking; corrected in the section 14 delta by 328q.**

**Finding 2 -- section 5.4's intermediate "333.1 studs, 3.1 of margin" does not reproduce; it is 332.4
and 2.4.** The design's own parenthesised arithmetic, `sqrt(62.5^2 + (340 - 13.5)^2)`, evaluates to
**332.44**, and at full precision (dx 62.462, dz 326.524) to **332.444** -- margin **2.44**, not 3.1.
**What it changes: nothing that gets built.** It is the "before" figure that motivates the fix; the fix
itself -- the fixed point 340 -> 365 -> 366, `flankFirstStuds() = 366`, and the realised worst pair
**357.45** with **27.45** of margin -- reproduces to the decimal. The defect the design found (the shear
eats the 26.1-stud safety margin down to about 2.4) is **real, and is worse than it wrote**, which is the
direction that matters. **Not blocking; the two numbers are corrected in the section 14 delta by 328q.**

Everything else in sections 5 and 8 reproduces. The two slips in section 5.2's swing angles (7.244 vs
**7.245**, 7.295 vs **7.297**; the slopes they come from are both exact) are rounding, not arithmetic,
and are noted here so that the spec asserting them uses the right value.

---

## 5. The numeric targets, as targets

| Target | Value | Where it is proved |
|---|---|---|
| offset at every junction | **0**, asserted to 1e-12 | `grid.spec`, by construction (`sin(pi*k)`) |
| `harmonic` is a positive integer | `harmonic % 1 == 0` | `grid.spec`; at 1.5 three of the five junctions stop being zeros |
| amplitudes | **45** st E-W, **60** st N-S (K-A) | `Grid.CONFIG.bend`, born at **0** |
| max tangent swing | **7.245 / 7.297 deg**, equal to 0.052 deg | derived above |
| worst cross-side stand pair, in WORLD coordinates | **>= 330**; realised **357.4** (27.4 of margin) | `grid.spec` case 5 computes all 105 pairs of all 8 cells with its own loop and prints the worst |
| `flankFirstStuds` | **366** (was 340) | `Grid.flankFirstStuds`, solved and not written down |
| cell depth along every column | **exactly 1430** st; the 275 s beater walk unmoved | the exact-translate property |
| view down the carriageway | **435 / 499** st, about 2.9 / 2.3 stand gaps | a frame (K-A); the figure is a tangent approximation |
| `toWorld` inverse error | **< 1e-7** st in 5 steps | the 0.0163 contraction |
| perpendicular vs axis-aligned measure | **<= 0.82 %** | `grid_ground.spec` |
| voxel band stair on a bend | **4 st every 31.5 st** (one voxel) | printed by the census; a frame (K-D) |
| capacity caps | plan **7260**, draw **2640**; C1 room **953** models | `grid.spec` case 14, rewritten |
| inert at zero | the whole suite answers today's answers at `bend = {0, 0, 1}` | 328q's gate |

---

## 6. What this note did NOT verify

1. **Nothing was measured in Karen's place.** Task 328o is docs-only: no harness run, no Studio, no
   frame, no voxel, no bake. Every repo number above is read from the file named beside it, and every
   derived number is arithmetic over those.
2. **Source B's official Forest Service URL is 403 to this fetcher**, so the text was read from a
   complete re-host (named in section 2 B). The claim "still distributed by the Forest Service" is
   therefore **not confirmed**; the document's content is.
3. **The 435 / 499-stud sight figures are a tangent-line approximation** (`0.5*k*d^2` against a 34-stud
   corridor), not a ray cast through planted wood. The frame at 328r is the measurement.
4. **"The voxel lattice is world-axis-aligned" is not stated by any Roblox page** fetched here; it is
   this repo's own measured fact (section 2 E).
5. **The per-cell 8,000-part ceiling is UNMEASURED** (`grid-terrain.md` 12.2). 328g's client frame is the
   only thing that can move it, and no gate may cite it as a measurement before then.
6. **`PARTS_PER_MODEL` 3.03 is C1's mix only** (5,104 / 1,687). A recipe planting more of a 7-part
   template moves it; the census prints `parts/trees` every run, so the bound is re-read and not trusted.
7. **The 4-stud ditch stair has never been looked at** (K-D).

---

## 7. Sources

- ASAM OpenDRIVE: <https://www.asam.net/standards/detail/opendrive/> ·
  <https://publications.pages.asam.net/standards/ASAM_OpenDRIVE/ASAM_OpenDRIVE_Specification/v1.9.0/specification/index.html>
  -- ASAM grant, unrestricted distribution; v1.9.0, 2026-05-08; actively maintained.
- Keller, G. and Sherar, J., *Low-Volume Roads Engineering: Best Management Practices Field Guide*, USDA
  Forest Service / USAID / Virginia Tech CMI, July 2003:
  <https://www.fs.usda.gov/t-d/pubs/pdf/LowVolumeRoads/LVR_BMP_Field_Guide.pdf> (**403** here, read from
  <https://www.cedengineering.com/userfiles/C08-013%20-%20Low-Volume%20Roads%20Engineering%20-%20US.pdf>)
  -- no copyright notice, USDA / USAID disclaimer; 2003, not revised.
- FAO, *Watershed Management Field Manual*, FAO Conservation Guide 13/5, Rome 1998, ISBN 92-5-102789-X:
  <https://www.fao.org/4/t0099e/t0099e00.htm> -- **all rights reserved**; 1998, not revised.
- Patel, A., *Curved paths*, Red Blob Games: <https://www.redblobgames.com/articles/curved-paths/> --
  code MIT or Apache-2.0, prose the author's; last modified 22 Jun 2026.
- Roblox, *Terrain* and *Region3*: <https://create.roblox.com/docs/parts/terrain> ·
  <https://create.roblox.com/docs/reference/engine/classes/Terrain#WriteVoxels> ·
  <https://create.roblox.com/docs/reference/engine/datatypes/Region3> -- docs **CC BY 4.0**
  (`Roblox/creator-docs`); actively maintained.
- In-repo, borrowed (rule 2): `ForestTest.LAYOUTS.road`, `ForestTest.exitZOf`,
  `MapUi.geometryFromForestTest`, `Relief.columnsFor`, `Ground.bandBounds`, `Grid.seedFor`,
  `Places.forgetCells`, and task 79's world-switch-by-commit.
