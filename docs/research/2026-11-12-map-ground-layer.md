# The M map that reads like ground: a stylised ground layer drawn from the planting data (task 347)

Karen, 2026-11-10 ~10:30 UTC, verbatim: *"map is odd and hard to understand what and where it has to
be clean and nice as I showed you exmple / please improve map visuals and selection postion to be
clear with icons and actial map terrain as I send example"*. Earlier, 2026-11-08 ~16:00 UTC:
*"clicking M it has to be nice map visuals with selection icons tower ect / it shows where is lake
struckture trees ecat / ofc all has to be light load when needed and fast"*.

Style reference: `<runs-dir>/refs/karen-mapstyle-ref-2026-11-08.png` -- a painterly top-down:
forest texture, open ground, lakes, curving dirt roads, small clear icons. **STYLE ONLY.** Nothing
of that game's art, icons or layout is copied; every shape here is drawn by us out of `Frame`,
`UIStroke`, `UIGradient` and `UICorner`.

## 1. What the system must do

1. On M, the eight drive cells read as GROUND at a glance: wood where the wood is, open where it is
   open, the roads as curving lines on their real bends.
2. The icons on top are small and clear: YOU, your stand, free stands, taken stands, towers, the
   lodge, the other players.
3. One legend.
4. Picking a stand by click works exactly as it does today.
5. Light and fast: opening M costs **< 50 ms** on the client, the open map is **< 1,500 UI
   instances**, and the ground layer is **built once per cell set and cached** -- never per frame.
6. OFF (flag `MAP_LOOK` off) is today's map, value for value.

## 2. What the game already knows, measured out of the tree

The ground layer must be **derived from data the game already has** -- that is the dispatch's
decision, and it is also the only option that cannot be wrong about where the wood is, because it
reads the same table the planter planted from.

| Fact | Where it lives | Shape |
|---|---|---|
| which cells exist, and their world bounds | `Grid.CELL_ORDER`, `Grid.worldBoundsOf` | 8 rects, 1070 x 1430 studs |
| which cells have a wood at all | `Grid.PLANTED_CELLS` | 7 of 8 (A1 has none) |
| **where the wood is INSIDE a cell** | `Places.CELL_PLANS[recipe].zones` | 4-7 rects per cell in NORMALISED cell coords (`at = {x0,z0,x1,z1}`), each with `spacingStuds`, a `mix` name and a `band` ("wood"/"shrub") |
| which wood | the `mix` name (`spruceAll`, `birchWood`, `oakPark`, `clearing`, `scrub`...) | a string |
| how dense | `spacingStuds` -- the lattice pitch the planter used | 0 = plants NOTHING (a clearing); 24-60 studs otherwise |
| the roads, bent | `Grid.roads`, `Grid.roadPolyline(road, samples, bend)` | 8 polylines, already drawn today |
| the stands, their sides and the towers | `Grid.standPosition`, `Grid.sideOf`, `Grid.towerStands` | 15 per cell, already drawn today |
| the lodge | `Lobby.ANCHORS["forest-test"]` | ONE point, (2850, -2950) |

**Counted: 48 zones over the eight plans** (`spruceSlope` 6, `spruceRidge` 7, `mixedRolling` 7,
`oakRolling` 6, `aspenRolling` 5, `larchSlope` 4, `spruceBirchRolling` 7, `oakAspenRolling` 6).
That is the whole ground layer's input, and it is 48 rectangles -- not 10,000 tree positions.

**TWO MEASUREMENTS THAT CHANGE THE DESIGN:**

* **There is no water in this world, at all.** `Grid` and `Places` hold no lake, pond or water
  field, and `src/serverstorage/TerrainBake/init.luau` **REFUSES any tile** whose base columns have
  no single height -- its own refusal message names *"Water, an overhang or a pond. That is ground
  this bake would have to INVENT, so the tile is REFUSED, never guessed"*. So the baked ground is
  water-free by construction. Karen's *"where is lake"* has **no data to draw from**: a water layer
  here would be a producer with an empty input, which rule L-093 exists to catch. **Nothing water is
  drawn and it is reported as a gap**, not faked. The lake is a world task (not this one: the
  dispatch's NOT YOURS list holds the world itself).
* **The lodge is 5,270 studs OUTSIDE the grid.** The grid footprint is x -6700..-2420, z
  -6600..-3740; the lobby anchor is (2850, -2950). Drawing it in-bounds would multiply the map's
  span by ~2.2 and shrink every cell to under half its drawn size. So the lodge is **pinned to the
  map's border**, which is the rule this map already has for an out-of-range marker
  (`MapUi.project`'s clamp plus `PINNED_TRANSPARENCY`) -- no new rule, and the honest picture: the
  lodge is that way, a long way off.

## 3. The external sources

| # | Source | Licence / status | Does well | Does badly |
|---|---|---|---|---|
| 1 | [Creating a mini map that includes terrain](https://devforum.roblox.com/t/creating-a-mini-map-that-includes-terrain/1131371) (DevForum, Scripting Support) | forum post, no licence granted -- **pattern only, nothing copied**; thread open since 2021 and still the canonical answer | States the whole option space in one line: *"use frames to represent each voxel, or create an ImageLabel with a pre-generated image file representing the terrain"*. Frames are instances this project can lint, review and count | A frame per voxel is hopeless at our scale: the grid is 4280 x 2860 studs at a 4-stud voxel = **765,000 voxels**. The pre-generated image needs an UPLOAD, which the dispatch forbids this round |
| 2 | [Realtime minimap using EditableImage & Parallel Luau](https://devforum.roblox.com/t/realtime-minimap-using-editableimage-parallel-luau/2776543) (DevForum, Creations Feedback) | showcase thread, no licence -- **idea only**; 2024, `EditableImage` is live API | The genuine "ONE generated texture" answer: raycast a lattice, write pixels into an `AssetService:CreateEditableImage` canvas. Author's own measurement: **~6 ms** on standard hardware | It is a **raycast** sampler, so it reads the ground every time, in parallel Luau, and its cost scales with resolution; it also needs the world to be STREAMED IN around the sample point -- and task 337 loads **one cell at a time**, so seven of eight cells have no instances to ray at. It would draw a map of one cell and a void |
| 3 | [Creating An Efficient* Viewport Minimap](https://devforum.roblox.com/t/creating-an-efficient-viewport-minimap/1179030) (DevForum, Community Tutorials) | tutorial, no licence -- **rejected, not borrowed** | The option Roblox's own docs recommend first | **Refuted by an engine fact already in `MapUi`'s header**: Terrain cannot be parented under a `ViewportFrame` ([feature request open since 2019](https://devforum.roblox.com/t/add-terrain-support-rendering-from-outside-its-parental-structure-for-viewportframe/219346)), and the ground is Terrain in both worlds. It would draw floating meshes over a void -- the blank screen `docs/PROJECT_CONTEXT.md` records being certified twice |
| 4 | [Plum's Minimap V2](https://devforum.roblox.com/t/plums-minimap-v2/4281550) (DevForum, Community Resources) | an importable MODEL, **no licence line in the thread** -- so it cannot be imported or copied (rule: no third-party asset without a licence line). Pattern read, nothing taken | Shows the shipped shape the genre expects: a styled GUI the developer restyles, markers over a ground layer, a legend | An `.rbxm` model is BANNED in this repo (binary, unreviewable in a PR). No licence = no borrow |
| 5 | Minecraft's per-chunk map colour rule (the vanilla filled map: one colour per block column, resolved per chunk and **cached** until the chunk changes) | proprietary -- **pattern only**, and the pattern is already cited in `Grid.CONFIG.seed`'s own comment for per-chunk determinism | The exact division of labour this task needs: a map is a cheap FUNCTION OF THE WORLD'S GENERATION DATA, computed per region, cached, and redrawn only when that region changes | Block-resolution colour is far finer than our 48 zones need, and we have no block grid |

## 4. The pattern adopted, and why

**ZONE RECTANGLES FROM THE PLANTING PLAN, drawn as bend-following column strips, built once per
cell set and cached.** For each of the 48 zones: read its normalised rect, its `spacingStuds` and
its `mix`; map it to a **kind** (`conifer` / `broadleaf` / `mixed` / `scrub` / `open`) and a
**density** in 0..1 from the pitch the planter actually used; project its corners through
`Grid.toWorld` with the world's own `bend`; and draw it as a small number of axis-aligned column
strips so it follows the curve of the ground it describes.

Why this and not sources 1-4:

* It is **the planter's own table**, so the wood on the map is the wood in the world by
  construction -- the same argument `MapUi`'s header already makes for the road and the stands
  (*"the one option that cannot be wrong about where they are"*).
* It needs **no raycast, no streamed-in world and no upload**. Source 2's sampler cannot see seven
  of eight cells (task 337), and sources 1 and 4 need an asset id.
* It is **48 rects of input**, so it is cheap enough to be exact: no sampling error to argue about.
* It is **pure arithmetic over frozen data**, so it is testable in a spec without a world -- which
  is how every other number on this map is proved.

**The bend is why a zone is STRIPS and not one rect.** `Grid.CONFIG.bend` is 45 studs east-west and
60 north-south; at the full map's ~0.25 px/stud over the 4280-stud world that is up to **15 px** of
displacement, and the roads already draw it as polylines. A single axis-aligned rect per zone would
sit up to 15 px off the road it borders. Four columns per zone cut the worst corner error to about a
quarter of that; the realised number is MEASURED in the task's request, not promised here.

**The texture is a gradient plus a sparse stipple on the dealt cell only.** Karen asked for a
painterly forest, and a flat tint is not one. A tiled forest image needs an upload, so: each zone
carries a `UIGradient` (1 instance) for a painterly fall across the band, and the **active cell**
-- the one being hunted, the only one a player is standing in -- carries a sparse deterministic
stipple of small tree marks. Sparse and seeded (`Grid.seedFor`), so it is the same picture every
open and costs nothing to recompute. The other seven cells read by fill and density alone.

**Icons are ours**: a filled square (ground stand), a square with the map's own brass rim (tower /
high seat), a diamond (yours), a ring (taken), a chevron wedge (you, with your facing), a small
house glyph (the lodge). All `Frame` + `UIStroke` + `UICorner`, no icon pack, no asset id, no
licence to carry.

## 5. The numeric targets

| What | Target | Why that number |
|---|---|---|
| M-open cost, client | **< 50 ms** (p50 and max of 5 opens) | the dispatch's budget. One frame at 60 Hz is 16.7 ms, so 50 ms is three frames -- a visible blink at worst, never a stall |
| open-map UI instances | **< 1,500** | the dispatch's budget. The arithmetic below lands at ~700 |
| ground-layer rebuilds | **once per cell set**, 0 per frame | `MapUi.CONFIG.TICK_HZ` is 20 and the tick's job is MARKERS; the ground cannot change inside a drive |
| zone count | 48 | counted out of `Places.CELL_PLANS` |
| columns per zone | 4 | 48 x 4 = 192 frames, and it cuts the bend error to ~4 px |
| stipple marks | active cell only, <= 24 per zone | 7 zones x 24 = 168 worst case |
| frame time p95 with the map open | no worse than OFF, measured | the map is drawn once; the tick is unchanged |

**Instance arithmetic, worst case (C1, fifteen stands, the full map open):** 192 zone strips + 48
gradients + 168 stipple marks + 8 cell boxes with their edge and label (24) + 64 road segments + 15
stands x 6 (90) + 16 markers x 2 (32) + the stand list's 15 rows x 3 (45) + the legend's ~8 rows x 2
(16) + the panel's own chrome (~20) = **~700**, against the 1,500 ceiling.

## 6. What was NOT borrowed, and why nothing was invented

Nothing here is invented: the ground layer is source 5's cached per-region colour rule applied to
source 1's "frames, not an image" option, over the data this repo already generates its forest
from. The one thing that is ours is the **mapping from a planting pitch to a drawn density**, and it
is ours because the pitch is ours -- `spacingStuds` is a number this project chose, so no outside
source can say what it looks like from above.
