# Driven Hunt terrain and forest v2: final design for cells A1 to D2

**Status:** final, after the Builder's code read of branch `task-327c-wood`. It feeds 328a (the research note, the BRIEF and the Architect design run). Section 2.3 records the merge-time conflicts and section 2.4 records the changes the Builder forced.

**Units and coordinates**
- 1 stud (st) = 0.28 m.
- In cell coordinates, **u** runs from 0 (west) to 1 (east) over 1070 st (300 m). **v** runs from 0 (the main road, where the hunters stand) to 1 (the muster road) over 1430 st (400 m).
- Main stands 1 to 7 sit at x = 85, 235, 385, 535, 685, 835 and 985 st (u ≈ .08, .22, .36, .50, .64, .78, .92).
- Flank stands sit at z = 340, 560, 780 and 1000 st (v ≈ .24, .39, .55, .70): stands 8 to 11 on the west side, 12 to 15 on the east.
- The slug reaches 330 st (92 m). The rifle reaches 800 st (224 m).

**Target place:** Karen's **Forest Test (FT), PlaceId 130094961655666**. Never DEV. See section 3.10.

---

## 1. The idea in 5 lines

1. Your measured terrain stays as the base. Each cell gets **its own landform** on top of it, sculpted once in your Forest Test after a full backup. The eight landforms are a long slope, a hilltop, a ridge, a field in a dip, a valley, a plateau with an edge, a saddle, and broken ground.
2. Each cell gets **its own forest, made only from our 7 tree species** and laid out as in your photos:
   - open oak along a road
   - spruce walls
   - birch poles
   - young larch in rows
   - a field with a hedge
   - a green ride with wheel ruts
3. Each of the 15 stands has a **type** taken from a photo. Neighbouring stands never share a type, and every cell has at least 5 types.
4. Roads are level across their width. Each has earth and wheel ruts, a ditch and a grass verge. **No trunk stands within 34 st (9.5 m) of a road centre**, and no crown hangs over a road or a stand.
5. One rule checks every tree, and an independent counter counts them. A cell is shown to you only after it prints **floating 0, sunk 0, leaning 0, broken 0, on road 0, in stand 0**, plus frames from the hunter's eye.

---

## 2. The cells

### 2.1 Summary table

**Stand types:**

| Letter | Stand type | Photo |
|---|---|---|
| R | road in open wood | 123045 |
| S | spruce wall | 123412 |
| X | a ride crosses in front of the stand | 123108 |
| V | looking straight down a north-south ride | 123412, 123108 |
| L | flank ride, 300 st (84 m) into the cell | |
| F | field edge, or a field behind the stand | 123059 |
| P | open field in front | |
| C | clearing edge | 123205, 123229 |
| O | open wood, seen through the trunks | 123340, 123229 |
| T | tower over young growth or open ground | |

| Cell | Landform | Front (first 300 st / 84 m) | Main 1-7 | West 8-11 | East 12-15 | Signature photo | Models (≈) |
|---|---|---|---|---|---|---|---|
| **A1** | The Long Face: a 7 % slope, a gully, a bench | spruce thicket W, open oak E, a 1430-st ride at stand 4 | S X S V R O F | T F O C | R L O O | 123412 | 1,550 |
| **B1** | Hilltop clearing: a dome +22 st (6.2 m), a fold at 315 st | birch poles W, old oak E | O X O V R T R | O L O L | T R L O | 123340 | 1,600 |
| **C1** | A ridge at 429 st with 2 saddles | open oak, young larch rows E | R O X R V T F | T L O S | R T L T | 123045 | 1,850 |
| **D1** | A field in a shallow dish, with a hedge corner | meadow 798×515 st (223×144 m), 4 lone oaks, a copse | R F P C P T P | R T O T | F C L F | 123059 | 1,250 |
| **A2** | A valley deepening toward the muster road | young larch rows, a green ride on the valley floor | F T X V R F T | F L O C | R L O C | 123108 | 1,900 |
| **B2** | A plateau, then a 7.8 m edge at 340 st, with 2 ramps | open aspen and oak | F T R O R V F | O C L O | O C S L | (short, sudden shots) | 1,450 |
| **C2** | A saddle funnel between two knolls | spruce walls at both ends, light oak in the middle | S X R V O X S | S L O S | R L T O | 123412, mirrored | 1,700 |
| **D2** | A broken hillside, smoothed, with a hanging meadow | open birch on the crests, spruce in the hollows | F V R X O R F | O O L O | T O O F | 123229 | 1,200 |

The Builder's own zone arithmetic for C1 gives about 2,220 sites before exclusions and about 1,890 after. That agrees with the table.

### 2.2 Detail per cell

**Notation**
- Sculpt ops use the shapes in section 3.0.
- A zone is written as `(u0,v0,u1,v1) type spacing`.
- Species are ours only, the 7 groups in `Places.SPECIES`:

| Group | Templates |
|---|---|
| conifer | 7 |
| young/larch | 4 |
| birch | 8 |
| oak | 3 |
| fieldOak | 4 |
| aspen | 4 |
| fern | 5 |

**Section types**

| Code | What it is | Spacing (st / m) | Trees/ha |
|---|---|---|---|
| T | spruce thicket | 22 / 6.2 | 264 |
| H | spruce high forest | 34 / 9.5 | 111 |
| W | open oak wood | 36-38 / 10-10.6 | 89-99 |
| M | mixed wood | 30-32 / 8.4-9.0 | 124-142 |
| B | birch stand | 24 / 6.7 | 222 |
| Bo | open birch | 36-40 / 10-11.2 | 80-99 |
| A | aspen | 26-30 / 7.3-8.4 | 142-189 |
| Y | larch in rows | 18 / 5.0 | 394 |
| P | park | lone fieldOaks, placed | n/a |
| S | scrub or hedge | 16-24 / 4.5-6.7 | n/a |
| C | clearing | none | 0 |

**A1: The Long Face**
- **Sculpt:**
  - baseKeep .6.
  - A trough through (.42,.12), (.34,.50) and (.30,1.0): depth 14 st (3.9 m), half-width 45 st (12.6 m).
  - A bench at v .55-.74: weight .8, grade 2 %.
- **Zones:**
  - (0,0,.5,.30) T 22
  - (0,.30,.5,1) H 34, minus the clearing (0,.55,.28,.78)
  - (.5,0,1,.55) W 36, with fern patches
  - (.5,.55,1,.80) M 30
  - (.5,.80,1,1) S 24, larch and birch regrowth
- **Rides and cuts:**
  - A V ride at stand 4 (x 535), the full 1430 st (400 m), with spruce on the west side and broadleaf on the east.
  - An X cut at stand 2.
  - An L ride at E13 (z 560), 300 st long.
- **Floor:** needle on the west side, leaf litter on the east side, and Mud in the gully floor.
- **Hunter sees:** a dark wall on the low ground. From stand 4 the ride runs 400 m to orange beaters at its far end. The gully brings animals to stands 2 and 3.
- **Beater walk:** downhill, 1430 st in 275 s.

**B1: Hilltop clearing**
- **Sculpt:**
  - baseKeep .6.
  - A dome at (.62,.73): r 280 st (78 m), +22 st (6.2 m).
  - An E-W trough at v .22 (315 st / 88 m): depth 8 st (2.2 m), half-width 50 st. This is dead ground inside slug range.
- **Zones:**
  - (0,0,.55,.45) B 24, with dense fern patches
  - (.55,0,1,.45) W 36
  - (0,.45,.35,.85) Bo 36
  - (.35,.45,1,.55) M 30
  - a clearing on the dome at (.35,.55,.85,.85)
  - (.85,.55,1,.85) B 24
  - (0,.85,1,1) S 24
- **Rides and cuts:**
  - A V ride at stand 4, 786 st long, ending in the clearing.
  - An X cut at stand 2.
  - L rides at W9 (z 560), W11 (z 1000) and E14 (z 780, 160 st, into the clearing).
  - A window of young larch in front of stand 6 (a T stand).
- **Floor:** birch floor. The clearing is meadow.
- **Hunter sees:** white poles and bracken. Animals vanish into the fold at 88 m and reappear.

**C1: The ridge across the drive** (the preview cell)
- **Sculpt:**
  - baseKeep .8.
  - A ridge along v .30: +24 st (6.7 m), half-width 150 st (42 m).
  - Two saddles at u .28 and .72: −12 st, r 70 st.
- **Zones:**
  - (0,0,.62,.40) W 38, clean trunks, sightlines over 100 st (28 m)
  - (.62,0,1,.40) Y 18, in rows
  - (0,.40,.62,.70) M 32
  - (.62,.40,1,.70) B 24
  - (0,.70,.35,1) T 22
  - (.35,.70,1,1) A 30
- **Rides and cuts:**
  - A V ride at stand 5 (x 685), 700 st long.
  - An X cut at stand 3.
  - L rides at W9 (z 560) and E14 (z 780).
  - Stand 7 is an F stand. Its field window lies in C2's muster-edge clearing.
- **Hunter sees:** the 123045 view. Animals crest the ridge at 120 m and come down a 7° face into range.
- **Towers:** W8, E13 and E15 are kept and re-measured after the bake.

**D1: Field in a dish**
- **Sculpt:**
  - baseKeep .6.
  - A bowl at (.50,.30): rx 260 st, rz 200 st, depth **10 st (2.8 m)**, flat floor over the inner .45 of the radius.
  - **No rim.**
- **Zones:**
  - a field (.25,.03,1,.40) with 4 solitary fieldOaks
  - a copse of 8 fieldOaks at (.42,.12,.50,.20)
  - a hedge, S 16 in 3 rows, at (.22,0,.25,.40) and (.25,.40,1,.45)
  - (0,0,.22,.40) W 36
  - (0,.45,.5,1) M 32
  - (.5,.45,1,.75) W 38
  - (.5,.75,1,1) T 22
- **Floor:** a Grass headland 12 st (3.4 m) wide, then E-W stripes at an 8-st pitch. Each stripe is one 4-st row of Ground and one 4-st row of mixed Ground 70 / Grass 30. Mud only where the dish is at least 6 st deep.
- **Hunter sees:** stand 2 at the hedge corner, as in 123059. Stands 3-7 shoot across 140 m of open ground.

**A2: Valley and green ride**
- **Sculpt:**
  - baseKeep .6.
  - A trough along u .50: depth 0 at v .20, rising to 26 st (7.3 m) at v 1. Half-width 180 st, walls 8°.
- **Zones:**
  - (0,0,.6,.25) Y 18 in rows (jitter .25), scale .35-.50
  - (.6,0,1,.25) M 32
  - (0,.25,.6,.75) M 30, with relief bias
  - (.6,.25,1,.75) T 24
  - (0,.75,1,1) H 34
  - two clearings, (0,.65,.25,.82) and (.77,.65,1,1)
- **Rides and cuts:**
  - A V ride on the valley floor at stand 4, 1430 st long.
  - A full-width E-W ride at z 670, 110 st from both rows of flank stands.
  - An X cut at stand 3.
  - L rides at W9 (z 560) and E12 (z 340).
- **Hunter sees:** over young larch to the mature wood. A stag crosses the green ride.
- **Towers:** stands 2 and 7 are kept.

**B2: Plateau and the edge**
- **Sculpt:**
  - baseKeep .6.
  - A bench from v 0 to .22 at 2 %.
  - A scarp centred at v .24: a drop of 28 st (7.8 m) over 64 st (24°), with no trees.
  - Two ramps at u .20 and .78: 60 st wide, 15 %.
- **Zones:**
  - (0,0,1,.22) A/W 34
  - (0,.22,1,.30) the bare edge
  - (0,.30,.65,1) A 30, with relief bias
  - (.65,.30,1,1) T 22
  - clearings (0,.34,.22,.52) and (.78,.34,1,.52)
- **Rides:**
  - A V ride at stand 6 (x 835), running up through the u .78 ramp.
  - L rides at W10 (z 780) and E15 (z 1000).
- **Floor:** leaf litter. Scree (Ground 70 / Rock 30) where the slope is 30-40°.
- **Beater walk:** beaters at x 160 and 760 use the ramps. The bot's climb of the 24° face is **measured** in 328h, never assumed.

**C2: Saddle funnel**
- **Sculpt:**
  - baseKeep .7.
  - Two knolls at (.18,.40) and (.82,.40): r 200 st (56 m), +26 st (7.3 m) each.
- **Zones:**
  - (0,0,.30,.45) and (.70,0,1,.45) T 22
  - (.30,0,.70,.45) W 36
  - H 34 on the knolls, (0,.45,.25,.70) and (.75,.45,1,.70)
  - a saddle meadow (.25,.45,.75,.68)
  - (0,.70,.5,1) M 30
  - a muster-edge clearing (.55,.85,.75,1), the field for C1's stand 7
  - (.5,.70,1,1) B 26
- **Rides:**
  - A V ride at stand 4, 643 st long.
  - X cuts at stands 2 and 6.
  - L rides at W9 and E12.
- **Hunter sees:** a light gap between two dark walls.

**D2: Broken hillside**
- **Sculpt:**
  - baseKeep .5.
  - A bench (the hanging meadow) at v .50-.74: weight .7, grade 4 %.
  - The slope limiter (section 3.0).
- **Zones:**
  - (0,0,1,.30) Bo 34, with relief bias
  - (0,.30,.40,.74) B 24
  - (.40,.30,.75,.50) Bo 40
  - a meadow (.40,.50,.75,.74)
  - (.75,.30,1,.74) A 26
  - (0,.74,1,1) W 36
- **Rides:**
  - A V ride at stand 2, 800 st long.
  - An X cut at stand 4.
  - An L ride at W10, 428 st long, ending in the meadow.
  - No east ride.
- **Hunter sees:** the roughest round. From a ground stand the view is 40-80 st (11-22 m). From the E12 tower it is 250 st (70 m).

### 2.3 Conflicts settled at merge time

| # | Conflict | Decision |
|---|---|---|
| 1 | Sculpt the terrain, or never write it | **Sculpt**, in one Edit-time bake on the measured base, after a backup. Design §4.4 names D-5 as the way out |
| 2 | D1: a wet hollow, or a field | A field in a 10-st dish with no rim |
| 3 | Ride layouts | At most 1 V ride and at most 2 X cuts per cell. L rides at least 110 st apart. Full-width rides at least 80 st from any flank stand |
| 4 | Where A2's ride goes | On the valley floor, at stand 4 |
| 5 | B2's landform | Plateau and edge. The forest adapts to it |
| 6 | C2's middle | The saddle meadow, with H on the knolls |
| 7 | Where D2's meadow goes | On the bench |
| 8 | Road edge | Section 3.1 (as revised by B8) |
| 9 | Scaled shrub belt | Scale floor 0.35. Belt is larch and birch only |
| 10 | Seat limits | One limit for the planter and the census (section 3.5) |
| 11 | Stand clearance | 20 st around a post, 24 st around a tower, plus the front cone (section 3.3) |
| 12 | Runtime paint, or a bake | One Edit-time tile pass writes shape and material together. Runtime `paintRoads` is archived |
| 13 | Plant per drive, or prebuild | Prebuild at Edit time and save, behind the 328g performance gate. The fallback is per-drive planting, `MAX_PER_STEP` 6 |
| 14 | Border | A border wood 230 st (64 m) deep, with field windows 320×300 st behind every F stand |
| 15 | Flank shooting sectors | Out of scope. Geometry only asserts the lane rule (section 3.3) |

### 2.4 Changes forced by the Builder's code read

| # | Builder blocker | Decision |
|---|---|---|
| B1 | Which place, and the tooling guard | **The bake, plant, census and frames target FT, PlaceId 130094961655666.** `tools/terrainbake.py` takes `--place-id 130094961655666` and checks `game.PlaceId` **before every mutating call**, not once per run. It refuses DEV. The DEV harness cannot evidence FT work, so each REQUEST pastes the FT probe lines next to the DEV harness line, as 327c did. |
| B2 | Bake idempotency | **New step 1.5: BASE SNAPSHOT.** Before any write, the driver reads the column heights of all 1,053 tiles and saves them outside the repo as `<runs-dir>/terrain-base-<sha>.bin` with its sha. A tile that holds Water or an overhang is refused. Each tile call receives its padded base slice: 64×64 columns, about 30 KB. `heightAt` never reads live terrain, so re-running a tile is idempotent. |
| B3 | An archive in ServerStorage is deleted by Rojo on Connect | Saved trees are archived into the place backup `.rbxl` plus **`Workspace.Archive_SavedTrees_2026-11`**, a container Rojo does not own. Trees are moved by setting Parent only, never destroyed. Before any move, the tool asserts that every species still resolves in `Places.templates()`. A `Session` or `OurForest` model that is the only copy of a template stays where it is and is re-seated. |
| B4 | StreamingMinRadius cannot be set from Luau (measured in Task 43, `Map.STREAMING`) | It is a NEEDS KAREN click from the start (section 6). 328g prints whatever value is live. |
| B5 | 328b's "refused ≤ 8 %" cannot be reached on unsculpted ground | In 328b, `refused` is **printed and reported, not gated**. The ≤ 8 % cap gates from 328f, once C1 is baked. Every other count is 0 in 328b. |
| B6 | Neither the ground nor the saved trees can be flagged | This is the **map-switch exception** (Task 79). The change switches by commit plus a place save. Rollback is restoring the backup `.rbxl`. Before 328d, the 327a part survey is re-run over the footprint plus 430 st (200 st of blend plus 230 st of border wood), and the count is pasted. **Q1 must be answered before 328d. The default is not assumed.** |
| B7 | Backup and save are clicks no tool can make | One NEEDS KAREN entry (section 6). `terrainbake.py` refuses to run without `--backup <file.rbxl>`, outside the repo and modified within the last 6 h, as `mapgen.py` does. |
| B8 | A 2-st ditch over d 21-27 is smaller than a voxel | The ditch becomes **2 whole voxel columns**. With the road centre snapped to 4k+2, column centres sit at d = 4k and their edges at 4k ± 2, so the ditch columns are centred on d 24 and 28 and cover **d 22-30**. The flat-bottomed ditch is 8 st (2.2 m) wide and 2 st (0.56 m) deep. The verge is d 30-34, so **the trunk minimum becomes 34 st (9.5 m)**, up from 33. The census measures ditch depth at the column centres d 24 and 28 only. |
| B9 | The fern cap contradicts the fern rule | **400 per cell is a hard cap.** There is one candidate patch per 100-st square (≈ 150 per cell at half coverage). Patches are drawn in seeded order until 400 ferns are planted (100 patches of 4). A refused fern is dropped and is not counted in the tree refusal rate. |
| B10 | The template audit is under-defined for our meshes | See section 3.5, step 1. **Trunk axis = the longest extent of the trunk box, which must be Y.** **Detached = foliage box minY > trunk box maxY + 1 st, or no XZ overlap between foliage and trunk.** **Reference extents** are measured once per template at scale 1 and stored as data in `Places.TEMPLATE_DIMS`, together with the crown half-width. |
| B11 | Blast-radius scope | The design said "map scope". That is wrong: TreeGround → `lobby`, Places → `places`, Grid → `map`, ForestTestBoot → `match` (a scope only, not in `TWO_PLAYER_PATHS`). Any spec reached means the full run. The one-player gate applies to every task. |

---

## 3. World-wide rules

### 3.0 Shaping (pure `Grid/Relief.luau`)

**Base.** `h = b·base + (1−b)·blur(base)`, where b is the cell's baseKeep. The blur is a **Gaussian with σ = 24 st (6.7 m), cut off at 72 st**, run separably over the snapshot. In D2 this removes the 4-st voxel steps.

**Falloffs:**
- **Dome, knoll and bowl:** radial smoothstep, `w = 1 − smoothstep(0, 1, d/r)`. The bowl adds a flat floor where d/r < .45.
- **Ridge and trough:** a cos² cross-profile over the half-width, following the polyline. Along the trough, depth is interpolated linearly between control points.
- **Saddle:** a negative dome, applied after the ridge.
- **Bench (weight w, grade g):** `h ← (1−w)·h + w·P`. P is a plane that rises along +v at grade g, anchored at the mean `h` over the bench's first 20 st. The bench's v-edges blend by smoothstep over 40 st.
- **Scarp:** a smoothstep drop between v_c ± 32 st, so 64 st at an average 24°. `noTrees` covers the scarp ± 8 st.
- **Ramp:** a 60-st strip where the scarp's drop is replaced by a linear 15 % grade, with its sides blended over 16 st.

**Slope limiter:** 8 relaxation passes that clamp the gradient over a 16-st (4-column) window. The ceiling is **20° in tree zones, 32° on open ground**. The scarp and ramps are exempt.

**Road fade:** every op is 0 within 51 st (14.3 m) of a road centre and reaches full strength at 120 st (33.6 m), by smoothstep.

**Outside the footprint:** the result blends back to the base over 200 st (56 m).

### 3.1 Roads (3 E-W, 5 N-S)

**Long profile**
1. Sample `h` along the centreline every 20 st.
2. Pin the 15 junctions.
3. Clamp the grade to **8 % on E-W roads and 10 % on N-S roads**, with at most 2 % change per 50 st.
4. **Cut or fill ≤ 12 st (3.4 m).** A breach relaxes the grade on that road and is printed, never hidden. D2's line is the one to watch.

**Cross-section.** The road centre snaps to 4k+2 (a shift of at most 2 st). d is the distance from the centre.

| d (st) | m | Shape | E-W material | N-S material |
|---|---|---|---|---|
| 0 | 0 | level | Ground | Grass |
| ±4 (ruts) | 1.1 | level | Mud | Mud |
| ±8 | 2.2 | level | Ground | Ground 70 / Grass 30 |
| ±12 to ±20 | 3.4-5.6 | level, crossfall ≤ 0.5 st over 44 st | Grass, then Grass/LeafyGrass | same |
| 22-30 (ditch) | 6.2-8.4 | 2 columns, 2 st deep | Mud | Mud |
| 30-34 (verge) | 8.4-9.5 | no tree, no fern | Grass | Grass |
| 34 to natural ground | ≥ 9.5 | bank ≤ 1:2, at least 12 st wide | the zone floor | the zone floor |

- Junctions: the E-W profile wins inside the junction square.
- The painted carriageway is 20 st (5.6 m) wide, ±10 st.

**Trunk minimum:** `max(34 + r, 22 + ½·crown·scale + 2)`, where crown is the template's half-width from `TEMPLATE_DIMS` (B10). The shrub belt runs from d 34 to 50, on spruce and mixed frontage only.

### 3.2 Rides
- Painted 24 st (6.7 m) wide: Grass in the centre, ruts of Mud/Grass, Grass edges.
- **Trunk-free width: 36 st (10 m).**
- Each rut is displaced sideways by up to ±1 st, using noise with a wavelength of 24 st.
- Every L ride or X cut ends in at least 60 st (17 m) of thicket or rising ground.

### 3.3 Stands
- **Pad:** radius 12 st (3.4 m), level with the road profile to ±0.25 st, Ground material. Towers get 12×12 st.
- **Trunk-free:** 20 st (5.6 m) around a post, 24 st (6.7 m) around a tower centre.
- **Front cone, ±30°:**
  - 0-40 st: no trunk.
  - 40-140 st: at most 1 trunk per 900 sq st, and no young growth or scrub.
  - On T stands, young growth is allowed in the cone if its top is ≤ 13.5 st (3.8 m), which is under the 17.5-st (4.9 m) deck eye.
- No foliage within 4 st of a tower's deck eye, over the forward 180°.
- **Lane rule:** no ride or cut **centreline** comes within 12 st (3.4 m) of another stand within 800 st (224 m).
- Stand type is keyed by (cell, index). A shared flank point has two faces, one per cell.

### 3.4 Beater corridors
- 6 per cell, at x = 160, 310, 460, 610, 760 and 910 st.
- Each is 10 st (2.8 m) wide and trunk-free. Its centreline is jittered by up to ±20 st, using noise with a wavelength of 240 st (67 m).
- No thicket backstop sits on a corridor.
- Walk time: 1430 st at 5.2 st/s = 275 s.

### 3.5 Ground contact (`TreeGround`, one function shared by the planter and the census)

1. **Template audit.** It runs once per template at build time. A template that fails is quarantined, listed, and never planted. It fails if any of these holds:
   - the trunk box's longest extent is not Y, or the trunk box's vertical axis is more than 5° off true (this catches 327c-f3's lying birch)
   - a foliage box is detached: its minY is more than 1 st above the trunk box's maxY, or it has no XZ overlap with the trunk
   - its part count differs from the template's
   - its extents are outside ±15 % of the `TEMPLATE_DIMS` reference × scale
2. **Footprint.** The XZ box of the trunk parts, measured after `ScaleTo`, with a half-width of at least 2 st. It is sampled at 29 points.
3. **Accept** only if the spread is ≤ 3.0 st (0.84 m) **and** the plane-fit slope over a 16-st disc is ≤ 32°.
4. **Re-seat.** Try 6 points on a ring of radius `max(4, 0.35 × spacing)` st, then refuse. Lone placed trees (spacing 0) use a radius of 8 st. Refusals are counted: from 328f the cap is ≤ 8 % per cell, and in 328b they are reported only.
5. **Seat.** Yaw only. Trunk bottom = low − sink, where sink = clamp(0.03h, 0.5, 2.0) st.
6. **Post-check** with fresh rays. A clone that fails is destroyed and counted.
7. **Streaming.** `ModelStreamingMode = Atomic` on every tree.

### 3.6 Exclusions

One pure function, `Grid.mask(x, z, r) → reason?`, answers for every site. It generalises `Places.clearOfEveryRoad` and `Places.inLane`. The reasons are:
- road, verge, ditch
- ride
- stand, tower, front cone
- beater corridor
- noTrees (the scarp)
- cliff (slope ≥ 40°)
- field, clearing
- gap: closer than r1 + r2 + 4 st to another tree

### 3.7 Relief bias, rows and ferns
- **Relief bias:** `hn = (y − minY) / spread`. Where hn < .30, a broadleaf zone draws spruce instead. Where hn > .70, it draws birch or open oak.
- **Plantations:** jitter .25, in N-S rows.
- **Ferns:** in patches only, inside W, M, B and Bo zones. There are none on verges and none under thicket. **The cap is 400 per cell** (B9).
- **Scale floor:** 0.35.

### 3.8 Materials
- **Built-in only:** Grass, LeafyGrass, Ground, Mud and Rock. No MaterialVariant and no colour changes.
- **Floor tables:** needle, mixedLitter, birchFloor, leafLitter, parkGrass, plantation, scrub, meadow, field.
- **Zone edges:** a blend band 32 st wide. The edge is displaced by up to ±12 st, using noise with a wavelength of 96 st (27 m).
- **Overrides:**

| Rule | Test | Material |
|---|---|---|
| cliff | slope ≥ 40° | Rock |
| scree | 30-40° | Ground 70 / Rock 30 |
| wet hollow | ≥ 6 st deep | Mud |
| damp rim | 3-6 st deep | Mud 40 / LeafyGrass 60 |

- **Caps:** Rock ≤ 6 % and Mud ≤ 8 % per cell. **The denominator is the cell's interior surface columns, excluding everything within 34 st of a road centre.** The ditches and ruts on the road bands are not counted.
- **Grass blades:** only on verges, rides, meadows and fields.

### 3.9 Order of operations and epoch
1. **BACKUP:** Karen's click (section 6), with a note in `backups/README.md`.
2. **BASE SNAPSHOT** (B2).
3. **SCULPT and PAINT** in one tile pass:
   - Each tile is 128×128 st, at resolution 4.
   - The Y band is the tile's surface min − 16 st to its max + 32 st.
   - One `ReadVoxels`/`WriteVoxels` call covers at most 96 st of height. MapGen measured that 128×128×96 is accepted (24,576 voxels).
   - A tile whose band is taller than 96 st is split into stacked calls.
4. **RE-SURVEY:** `Grid.CELLS[*].relief`, `lineMeanY`, the road heights and the towers.
5. **MASKS.**
6. **PLANT,** nearest the hunter line first.
7. **CENSUS.**
8. **FRAMES.**
9. **SAVE:** Karen's click.

**TerrainEpoch**
- It is the first 16 hex characters of `sha256(base-snapshot sha ‖ Relief data JSON ‖ BAKE_VERSION)`.
- `BAKE_VERSION` is an integer constant in `Relief.luau`, bumped whenever the bake's maths changes.
- The epoch is stored as the string attribute `TerrainEpoch` on `Workspace.Terrain`. Every planted folder carries `PlantEpoch`.
- The census fails when the two differ.

### 3.10 Place guard
- `terrainbake.py` checks the PlaceId on every mutating call (B1).
- The probe is read from a file, never from inline Luau quoting.
- An explicit `studio_id` is verified by `game.PlaceId`, because StudioMCP can fall back to DEV.

---

## 4. Budgets, census and frames

### 4.1 Budgets

| Item | Budget |
|---|---|
| Models per cell | ≤ 2,400 |
| Parts per cell | ≤ 8,000 (3.2 parts a model, measured in 327c) |
| Whole world | ≈ 19,800 models / ~63,000 parts, plus 21,022 base parts. This is about 12,500 trees, ~1,900 belt, ≤ 3,200 ferns and ~2,150 border trees |
| Border wood | 230 st deep. Spacing **40 st (11.2 m)**, which gives ≈ 2,150 trees over 3.44 M sq st. The mix copies the nearest cell's front zone. Planted after the bake, on the blended ground |
| Client within 1024 st | ≈ 5,000 models / ≤ 17,000 parts |
| Server heartbeat | ≤ the baseline with the wood off + 1.0 ms (A/B test at t + 120 s) |
| Client frame | ≤ 16.7 ms at C1-8 and D2-12 (Device Simulator OFF) |
| Bake | Measure 10 tiles first. **Stop if a tile takes more than 8 s or Studio memory goes over 6 GB.** Memory is sampled every 50 tiles to catch ChangeHistory/undo growth. At the 4 s estimate, 1,053 tiles take about 70 min, unmeasured |
| Team Create | Checked in 328d, step 0. In a Team Create place, the save behaviour is reported before anything is baked |
| Place file | Estimated at +25-40 MB, unmeasured. **Gate: file ≤ 150 MB, Studio save ≤ 90 s**, measured in 328g |
| Plant at Edit time | ~20,000 × 0.69 ms ≈ 14 s |
| Boot | Manifest check (plan hash + epoch) ≤ 0.2 s. A mismatch prints REFUSED and nothing is silently rebuilt |
| Fallback | Per-drive planting, `MAX_PER_STEP` 6: ~6.7 s a cell, worst step ≤ 8 ms |
| Streaming | `StreamingMinRadius` 64 → **384 st (107 m)**. This is Karen's click |

### 4.2 Census

The census is an independent measurer: it casts fresh rays at each part's real bottom face. It prints one line per cell, plus a `border` line and a `savedInBounds` line:

```
[census] C1 epoch=<h> trees=N parts=P floating=0 sunk=0 foliageInGround=0 tilted=0 broken=0 inRoad=0 inVerge=0 inDitch=0 inRide=0 inStand=0 inTower=0 inLane=0 inBeaterPath=0 onCliff=0 refused=k/N rock%<=6 mud%<=8 worstHigh<=0.25 worstSink<=2.25
```

| Count | Definition |
|---|---|
| floating | trunk bottom − low > 0.25 st (7 cm) |
| sunk | low − trunk bottom > sink + 0.25 |
| foliageInGround | a foliage part's minY < ground − 0.5 |
| tilted | up·Y < cos 2° |
| broken | the template audit fails after planting |

**Other checks:**
- Roads: crossfall ≤ 0.5 st every 20 st, the grade within its limit, cut and fill ≤ 12 st or reported.
- Ditches: depth 2 ± 0.5 st at d 24 and 28.
- The 120 pads: relief ≤ 1.8 st.
- The landforms: crest and floor within ±3 st (0.84 m) of the recipe.

### 4.3 Frames
- **Each planting task:** 3 frames per cell it touches: the signature stand, the line-centre stand looking down the road, and a 45° aerial.
- **Final sign-off:** 48 frames (6 per cell), plus 7 frames matched to the reference photos.
- **Camera:** eye at **5.6 st (1.57 m) above the pad**, FOV 70. The tower deck eye is 17.5 st.
- **Duplicates:** a frame whose sha256 matches an earlier frame counts as no frame. If D-1 (the cached image) is not fixed first, the frames are declared Karen-eye-only.
- **FT freshness:** an FT frame after a sync needs a Play stop/start.

---

## 5. Changes to the design and to 327a/b/c, and the task split

### 5.1 `docs/design/grid-map.md` (Architect, through a BRIEF)
- **§4.4:** D-5 is closed. Relief = measured base + baked landforms.
- **§4.5:** the recipe gains:
  - `landform`
  - `rides`
  - `cuts`
  - per-zone jitter, relief bias and floor
  - `field`
  - `standTypes`
  - crown clearance
  - scale floor 0.35
- **§6:** stand pads and types. **§7:** the lane rule.
- **§8.1-8.3:** prebuild, border wood and budgets. **§8.4:** the contact rule.
- **K-6:** closed.
- **§13:** `grid_ground.spec`.
- **New §17:** this document.

### 5.2 327a, 327b and 327c

| Task | Change |
|---|---|
| 327a | The survey instrument is kept. `Ground.paintRoads` is archived once the Edit-time paint lands |
| 327b | `standPosition.y` comes from the road profile. Towers are re-measured, and `towersRelaxed` is expected to flip to false |
| 327c | **Merge as is, behind `GRID_PREVIEW` OFF.** `plantOne`, `Slice` and the census are the engine. `CELL_PLANS` becomes v2 and `stepAllowance` is retired. Notes (a), (b), (d) and (g) fold into 328b/328f. Note (e) is closed by the border wood |

### 5.3 Task split

**Gates for every task**
- Every task gets the one-player gate only: `test --scope auto` for a review round and the full `test` for the PR.
- No path is in `TWO_PLAYER_PATHS`.
- Each FT task also pastes its FT probe lines (B1).

| Task | What | What Karen sees | Days | Gate |
|---|---|---|---|---|
| **328a** | Research note, INDEX, BRIEF (decisions B1-B11 and every number in sections 3-4), Architect design run | nothing | 0.5 | docs-only, 1 round |
| **328b** | `TreeGround` contact rule, template audit with `TEMPLATE_DIMS` and quarantine, census v2, Atomic streaming, `grid_ground.spec` with fake-terrain fixtures | C1 as it is today with no leaning, lying or hanging tree. The quarantine list. 3 frames | 1.5 | test + FT census: every count 0, `refused` reported only |
| **328c** | Pure `Relief.luau` (section 3.0), 8 landform rows, spec, off-Studio hillshade PNGs | 8 top-down relief pictures | 1 | test |
| **328d** | 0. Q1 answered, Team Create checked, survey of the footprint + 430 st pasted, backup click. 1. `terrainbake.py` with the per-call guard, the base snapshot and 10 measured tiles. 2. Bake **C1 and its 4 roads** | C1's ridge from stand 4. Level roads with ditches. 3 frames | 1.5 | test + FT road/pad/ditch/landform census + bake cost per tile |
| **328e** | Paint pass v2 in the same tiles, C1 first. Archive `paintRoads` | C1 with ruts, verges and litter floors. 3 frames | 1.5 | test + material census |
| **328f** | Forest v2 plan (pure): `Grid.mask`, rides, cones, corridors, relief bias, rows, ferns, field, border wood. C1 v2 data, replanted live | **The 123045 view in C1.** 3 frames + the photo-matched frame | 2 | test + C1 census 0, **refused ≤ 8 %** |
| **328g** | Edit-time prebuild for C1 and its 4 neighbours, manifest and epoch at boot, **performance gate** (heartbeat, client frame, parts in radius, file size, save time, live StreamingMinRadius) | no change in look, no trees growing in | 1 | test + every perf line within budget. On a failure, the fallback is used and reported |
| **328h** | Bake and paint the other 7 cells, re-survey, measure the B2 bot climb | all 8 landforms in aerial frames | 1 + bake time | test + 8 landform census lines |
| **328i** | CELL_PLANS v2 for the other 7 cells, stand types, border wood, saved-tree archive (B3), whole-world plant | every cell from its signature stand | 2 | test + 10 census lines at 0 + 48 + 7 frames |

**Total:** about 12.5 days plus bake time.
- 328b and 328c run in parallel after 328a.
- 328d does not start until Q1 is answered.
- Every task stops at its own picture for Karen.

---

## 6. Questions for Karen (each has a default)

1. **May we permanently reshape the ground in your Forest Test?** A full copy is saved first, so it can be put back. *Default: yes, but 328d waits for your answer.*
2. **Build the whole forest once and save it**, with every tree checked before you play and no pop-in? The alternative is planting per round, with about 7 s of trees growing in. *Default: build once.*
3. **D1's field is a green meadow with tractor stripes and a hedge** (we have no crop model). Is that acceptable? *Default: yes.*
4. **Flank hunters:** keep today's rule, no shots into the drive within ±45°? *Default: keep it, no change in this split.*
5. **Row 1 low, looking uphill; row 2 high, looking down.** Keep it? *Default: keep.*

**NEEDS KAREN clicks, in order (FT open in Edit):**
1. Before 328d: File › Save to File › `<runs-dir>/ft-backup-2026-11-xx.rbxl`.
2. Workspace › StreamingMinRadius: 64 → **384**, then save.
3. After each bake or plant reports: File › Save to Roblox (or Publish).

The Director's `click.ps1` may do these clicks if Karen delegates them.

---

## 7. Builder sign-off

**The Builder's understanding (quoted from its answer):**
> "The measured terrain stays as the base. Each of the 8 cells gets one landform, sculpted once at Edit time in Karen's Forest Test (FT, PlaceId 130094961655666), not DEV. The same tile pass writes shape and material together (ReadVoxels/WriteVoxels, 128-st tiles). Then the whole forest is planted once at Edit time and saved into her place, with one ground-contact rule and one independent census that must read 0 in every count. Runtime Ground.paintRoads (270 ReplaceMaterial calls at boot) is retired and archived. The per-drive Slice planting becomes the fallback, used only if the 328g performance gate fails. 327c merges as it is, behind GRID_PREVIEW OFF. … What I would build first: the research note, the BRIEF and the Architect design run (328a, docs only). Then 328b … because the 'broken/lying trees' in 327c-f1 and 327c-f3 come from templates and seating, not from relief. 328c, pure Relief.luau, can run beside them."

**Accepted from the Builder, unchanged:** B1, B2, B3, B4, B5, B6, B7, B9 (the 400 hard cap), B10 and B11.

**Still open, for the Builder to accept or the Architect to settle in 328a:**
1. **The epoch's inputs.** The Builder put the code commit into the hash. This design uses a `BAKE_VERSION` constant instead, because a commit-based epoch would fail the census after every paperwork commit. The Builder has not confirmed.
2. **The ditch.** The Builder offered two options. This design picks the 2-column ditch at d 22-30, which **moves the trunk minimum from 33 to 34 st** (the verge ends at 34). The Architect confirms it in 328a.
3. **The unmeasured budgets** stay targets until 328d and 328g measure them: 8 s a tile, 6 GB of memory, a 150 MB file and a 90 s save. Neither side has numbers yet.
4. **B2's bot climb of the 24° scarp** is unmeasured. If the bot cannot climb it, a third ramp at u .50 is the default fix (the Architect decides).