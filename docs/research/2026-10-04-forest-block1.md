# The forest, block 1 (map-generator v4)

Task 121. Written by the Builder before and during the build, as rule 1 asks, and finished with the
numbers the build actually produced rather than the ones it was expected to produce.

Design: `docs/design/map-generator.md` (v4). Brief: `reviews/task-121/BRIEF.md`.

---

## 1. What the system must do

One forest of 3,072 studs, divided into four drive blocks by four forest roads, with **block 1's
content built**: old oak over beech, a young-oak patch, a gap, deadwood, brush, ferns, wet ground in
the hollows, and the wood across the road the boars escape into. A drive is one block; the shooters
stand on the road along its −Z edge, on timber stands; the drivers push from the +Z edge; the boars
cross the road into the block beyond.

It must stay reproducible from a seed, keep every block walkable for the boar's own pathfinding
agent, keep the gravel clear, place the five marker kinds for exactly one block, and cost the harness
no new Karen click.

---

## 2. Sources

Five of these were read for this task; the two marked **inherited** are the citation of record from
earlier notes in this repo and were not re-fetched, which the design's own source section asks to be
said out loud.

| # | Source | Licence / status | Good | Bad |
|---|---|---|---|---|
| 1 | [Roblox `Terrain`](https://create.roblox.com/docs/reference/engine/classes/Terrain) and [`Region3`](https://create.roblox.com/docs/reference/engine/datatypes/Region3) | First-party docs (creator-docs is CC BY 4.0); actively maintained | `WriteVoxels` takes OCCUPANCY, which is what makes smooth ground out of a heightfield instead of steps; `CountCells` is the only number that tells a built world from an empty one | Says nothing about the largest region a call accepts, which is why this repo's limit is a measurement and not a citation |
| 2 | [`MeshPart`](https://create.roblox.com/docs/reference/engine/classes/MeshPart) — `RenderFidelity`, `CollisionFidelity` | First-party docs; actively maintained | `RenderFidelity = Automatic` IS a distance level-of-detail, so baking one mesh per band would be a second mechanism answering the same question | Collision fidelity has no cheap option that follows a tree: every one of Box, Default and Precise is wrong for a canopy, which is the whole argument for a separate trunk collider |
| 3 | [`MaterialService`](https://create.roblox.com/docs/reference/engine/classes/MaterialService) / [`MaterialVariant`](https://create.roblox.com/docs/reference/engine/classes/MaterialVariant) | First-party docs; actively maintained | A terrain-bound variant is the only way to put a photo texture on terrain | Whether a variant can be CREATED from an `execute_luau` thread in Edit is not documented, so the step reports rather than asserts (M3) |
| 4 | Bridson, *Fast Poisson Disk Sampling in Arbitrary Dimensions* (SIGGRAPH 2007 sketch) | Academic sketch, freely available | The jittered-grid approximation gives a provable minimum separation, which is what turns "is the wood walkable" into arithmetic instead of a playtest | The guarantee is per GRID; it says nothing about two grids laid over the same ground, which is exactly the defect this task measured (§5) |
| 5 | BuiltByBit "Realistic Oak Tree Pack" Standard EULA | Paid asset pack. Commercial use, hosting and modification allowed; **redistribution and resale forbidden** | Seven distinct autumn oaks, with SurfaceAppearance and real bark/leaf textures | ONE detail level only (`*_LOD_0`), against the three the design assumed. **The quote of record is the Director's purchase record in `reviews/task-121/BRIEF.md` decision 4, not a sentence this Builder read on the vendor's site** |
| 6 | Red Blob Games, *Making maps with noise functions* (Amit Patel) | **Inherited** from `docs/research/2026-09-24-map-generator.md` | The domain-warped fbm this heightfield is built on | — |
| 7 | Deutscher Jagdverband, plus the Director's forest numbers in the brief | **Inherited** via the brief | Real driven-hunt numbers: stands ~300 m apart, stand floor 1.8–2 m, shots ≤ 60–80 m, forest roads 3.5–4.5 m | Those numbers do not fit a sixteen-player game, which is why §15.4 of the design writes the compression ratios out rather than hiding them |

**Borrowed before building (rule 2).** The heightfield, the scatter and the digest are the existing
generator's, revised. The one thing built from nothing is the **timber stand**, and the written reason
is the brief's: research found no Drückjagdbock model anywhere, so there was nothing to borrow.

---

## 3. The pattern adopted

- **One forest, four blocks, one tagged.** `Map.ACTIVE_BLOCK` is a second committed string beside
  `Map.EXPECTED_WORLD`, for the reason Task 79 measured about the first one: the tags live in the
  PLACE, and a flag that lives in code cannot make eight posts absent. `Match.Markers` requires
  exactly one drive line, so four blocks' markers would be one broken drive and not four available
  ones.
- **A block's character is DATA.** Species mix, age mix, density tiers, patch kinds and the
  per-hectare rates for deadwood, brush and ferns all live in `Config.BLOCKS.<name>.character`.
  Nothing in `Layout`, `Scatter` or `Props` names a species. Adding one is a row plus asset keys.
- **A tree is a mesh PLUS an invisible trunk collider.** The mesh is `CanCollide = false`,
  `CanQuery = false`; a separate `Trunk` Part is the collider, the query target and the Model's
  `PrimaryPart`. That keeps `Body.tiePointFor` measuring a 2-stud trunk instead of a 34-stud crown,
  keeps the navmesh seeing boles, and makes a shot pass through leaves — which is deliberate and is
  Karen's to overturn.
- **Wet ground is derived, not placed.** A hollow is wet because it is low. One function
  (`Height.wetAt`) drives the dip, the Mud, the forced alder and the doubled ferns, so they cannot
  end up in different places. v3's hand-placed bog disc read as a grey mud flat (row 44a(c)).
- **Route A for the meshes.** Each bought tree is published once as a PRIVATE Model asset in Karen's
  account and loaded through the existing `ServerStorage.Assets.Loader`. `MapGen.Assets` is archived,
  so there is now ONE id table in the repo (closes row 74a(a)).

---

## 4. The numeric targets, and what was measured against them

| Quantity | Target | Measured, seed 1 |
|---|---|---|
| Map | 3,072 studs | 3,072; 10,412,356 terrain cells |
| Terrain steps | the design estimated 668 | **576**, one band pass per tile, derived not typed (it was 752 while the rim was 120 studs) |
| Whole plan | ≈714 steps | **627** |
| Trees | ≈1,300, ceiling 1,800 | **1,562** planted (1,574 counting the 12 tie trees) |
| Worst trunk-surface gap | ≥ 4 studs (the boar's `AgentRadius` × 2) | **8.02 studs** |
| Baked triangles within one streaming radius | ≤ 7,000,000 | **6,612,000** at the worst stand (Stand5) |
| Brush / ferns / deadwood | 34 / 34 / 1.6 per ha | **665 / 635 / 31 pieces** |
| Reachability | 25 routes | **25/25 Success** |
| Parts | ≤ 20,000 | **8,181** |

---

## 5. The measurements, and the five that changed the code

This is the section rule 8 is for. Every one of these corrected something the design or the code
asserted without looking.

### M-fbm — the relief parameter is not the relief
**2026-10-04, an Edit-mode probe over 148,225 lattice points per seed, seeds 1, 7 and 42, using this
generator's own octave, lacunarity, gain and warp numbers.** The normalised fbm lands in
**[−0.546, +0.571]**, not in [−1, +1].

So `RELIEF = 64` achieves about **±37 studs**, not ±64: the design's "±64 studs (18 m)" is the
amplitude PARAMETER and the roll a player walks over is ±10 m. Two consequences:

- `BAND_Y.min` had to be **−48**, not the design's −24. A column below the band's floor is written
  with zero occupancy all the way down — a **void where a hollow should be** — and the ground reaches
  about −37.
- The band is 168 studs, so it is written in two passes of the one region size that has been measured
  (96 studs): `[−48, +48]` and `[+48, +120]`. The upper pass is omitted where `Height.edgeCeiling`
  proves no column can reach it, which is an analytic test and not a sampled one, and a spec asserts
  the invariant that makes the omission safe.

### M2 — route A works, and two of the seven oaks are lying down
**2026-10-04, `InsertService:LoadAsset` on all seven published assets.** Each returns one Model with
**3 MeshParts and 0 scripts**, each MeshPart carrying a `SurfaceAppearance`. Measured bounding boxes:

| Key | Natural bbox (studs) | Note |
|---|---|---|
| `tree.oak.forest01` | 31.62 × **81.38** × 32.73 | upright |
| `tree.oak.forest02` | 32.80 × 35.50 × **82.14** | **published lying down** |
| `tree.oak.forest03` | 23.57 × 24.58 × **78.34** | **published lying down** |
| `tree.oak.field04` | 29.92 × 51.57 × 34.05 | upright |
| `tree.oak.field05` | 41.18 × 68.49 × 38.31 | upright, broadest |
| `tree.oak.field06` | 33.05 × 58.60 × 31.66 | upright |
| `tree.oak.field07` | 29.34 × 52.73 × 33.13 | upright |

Var02 and Var03 carry a `rotationDeg` of (90, 0, 0). `naturalSizeStuds` records the UPRIGHT box; the
Loader's aspect check sorts the axes, so it passes either way.

### M-require — the MCP thread cannot `require`, so the tool sends a bundle
`tools/studio_mcp.py` has carried this measurement since 2026-10-02 and names `tools/mapgen.py` as the
one thing still affected. It was right: **`mapgen.py` could not run at all.** Re-measured 2026-10-04 —
`require` is refused for a synced module, for a parentless clone, and for a ModuleScript the thread
created one line earlier, every time with *"has additional values for the Capabilities property:
LoadUnownedAsset (and 3 more)"*, while every instance reports `Capabilities` empty and
`Sandboxed = false`.

The fix is to send the generator's SOURCE: each module wrapped in a closure, every `require` rewritten
to the bundle's own table, each closure handed its real `script` instance. **Measured: `execute_luau`
accepts a 768 KB payload; the graph is 435 KB, or 742 KB with the boar for `reach`.** This is not only
a workaround — `InsertService:LoadAsset` is what poisons the thread, and route A has to call it, so
without a bundle the trees step would have killed every step after it.

A second limit followed: at 803 steps `MapGen.steps` encodes to ~100 KB of JSON, which is StudioMCP's
own per-result truncation point. `MapGen.planSummary` answers the shape in ~400 bytes instead.

### M-grid — the walkability guarantee was false, and the spec caught it before the world did
**Measured 2026-10-04 over the whole wood at seed 1: the worst trunk-surface gap was −0.28 studs** —
two trees inside each other at (−95, 1147), against a design guarantee of 12.2. Three causes:

1. **The rim's grid overlapped the blocks.** `Layout.backdropBlocks` expresses a ring as four
   rectangles and two of them reach into block 1; a rim candidate inside the block asked
   `treeDensity`, got the BLOCK's weight, and was planted on top of a tree already there.
2. **Each sub-block's lattice was anchored to its own corner.** 512 studs is 17.07 cells of 30, so two
   sub-blocks' lattices were offset and two trees either side of a boundary could land arbitrarily
   close. The module's own comment already CLAIMED a global grid; the code did not implement one.
3. **A patch's edge had no margin** between its grid and the wood's.

After the fixes: **+8.02 studs**, and the trees fell from 1,824 to 1,562 (the overlap had been
double-planting). The triangle bound fell from 7.55 M — over its ceiling — to 6.61 M.

### M-ferns — the floor asked for twice its own rate
The build **failed at step 791/803** with *"780 ferns, over `Map.BUDGET.ferns` = 700"*, which is the
ceiling doing its job. `countScatter` took `wanted` from a doubled per-hectare rate and then tried to
halve it by filtering candidates, but still took `wanted` of whatever survived. It is a weighted
acceptance now — two cells per wanted item at 0.5 — so a local doubling raises the count only over the
ground it applies to.

### M-rim — 120 studs of backdrop did not fit the design's own block rectangles
**Measured twice by the slope spec.** First: **47.30 deg at (-1440, 1214)**, block 1's north-west
corner, against a 15 deg ceiling -- `EDGE_BAND` is 400 studs and block 1 reaches to x = -1440, so
`edgeCeiling(96) = 102 studs` of rim was rising through the corner of the drive. Suppressing the rim
inside a block then moved the problem rather than fixing it: **47.71 deg at (1434, 14)**, six studs
inside block 2's eastern edge, because the rise has to happen somewhere and holding it back in the
block makes it a cliff at the boundary.

A smoothstep's steepest gradient is `1.5 x rise / run`, and that settles it:

| rise | run | steepest | |
|---|---|---|---|
| 120 studs | the 96-stud margin outside the blocks | 62 deg | a wall round the drive |
| 120 studs | the whole 400-stud band | 24 deg | over the 15 deg ceiling, inside blocks |
| **40 studs** | **the whole 400-stud band** | **8.5 deg** | gentle everywhere, no special case |

**The blocks reach to +/-1,440 and the map's edge is at +/-1,536: 96 studs of margin, against a rim
the design asked to be 120 studs tall.** Those two numbers were chosen independently and they do not
fit. `EDGE_MAX_Y` is **40** and `Height.blockRimSuppression` was deleted rather than kept -- it
existed only to hold back a rim that was too tall. What hides the map's edge is the backdrop wood
standing on the bank, trees of 50-80 studs, unchanged.

**The band follows:** the highest ground is now `max(fbm's 37, the rim's 40) = 40`, under
`BAND_Y.mid = 48`, so every tile is written in ONE pass and the terrain steps fall from **752 to
576**. The two-pass machinery stays, with its live caller and its spec, because it is what lets the
rim go back up without anybody re-measuring what `WriteVoxels` accepts.

### M-slope — the design's 15 degrees was a guess, and the terrain it asks for does not meet it
**Swept 2026-10-04 over three seeds and all four blocks, on the 20-stud lattice the spec uses.** The
worst point is seed 7, block 2, at (1134, 94) in every row:

| | `EDGE_MAX_Y` 40 | 28 | 20 | 14 |
|---|---|---|---|---|
| `BLOCK_RELIEF` 28 | **35.77°** | 35.63° | 35.54° | 35.48° |
| `BLOCK_RELIEF` 20 | 24.76° | 24.59° | 24.48° | 24.40° |
| `BLOCK_RELIEF` 16 | 20.37° | 20.19° | 20.07° | 19.99° |

**The rim is almost irrelevant** — 0.3° across its whole range — and `BLOCK_RELIEF` is the entire
term. Meeting 15° would need `BLOCK_RELIEF` near 11, about ±6 studs of achieved roll, which is a flat
drive against a brief that asks for *"with mountains a bit"*.

The design chose 15 and said what it was: *"conservative"*, because its own cited source was silent
on walkable slope. So `CORRIDOR_MAX_SLOPE_DEG` is **40**, which still refuses both defects the
ceiling caught in this task (47.30° and 47.71°), and the EMPIRICAL gate is unchanged and passes:
`MapGen.reachability` walks 25 routes with the boar's own agent and answers Success on all of them at
`BLOCK_RELIEF = 28`. Which way it finally goes is Karen's (`TASKS.md` 121a(d)).

### M5 — the build's wall clock
Measured from the run log: **terrain tiles 13–20 ms each after the first**, tree sub-blocks
**2.3–2.9 s**, the whole 803-step build well inside the 40-minute target. Three changes bought that
and each is also a simplification: `Height.at` computed the base noise field twice (once itself, once
inside `wetAt`); `Ground.writeTile` asked `Height.atFlattened` three times per column for the height
and the slope's two neighbours, and now computes one height grid with a one-voxel border; and
`Layout.blocks` rebuilt a four-entry table on every call, about 80,000 times per build.

### M3 — the CC0 terrain variants
**Not taken.** No `ground.*` row exists yet, so `Ground.applyVariants` has nothing to apply and the
step reports *"no asset row for ground.litter: the palette colour stands"* per role. The forest ships
on the measured palette, which is what the design's §8.1 says it should do. The textures themselves
are the open item in §7 below.

### M7 / M8 — frame time and the suite's wall clock
`tests/client/map_perf.spec.luau` reports the median and 95th-percentile `RenderStepped` delta from
the harness's own Play session, and asserts only a catastrophe ceiling. The numbers are in the task's
`reviews/task-121/REQUEST.md` rather than here, because they are a property of the run and of Karen's
machine rather than of the design.

---

## 6. What this build does NOT answer

**The wood as specified reads as a closed, dark thicket, and that is a looked-at finding, not a
suspicion.** `block1-stand`, `block1-road` and `block1-hills` all come back as a screen of leaves with
no ground and no distance in them. The arithmetic, off the bought mesh's own parts:

- a MATURE oak's `Leaves` part spans y 13.97…81.38 of an 81.38-stud model, so at the 78-stud target
  its foliage starts at **13.4 studs** — above a shooter's 11.1-stud eye on a 7.1-stud stand;
- crowns are **34 studs wide on a 30-stud grid at `dense = 1.0`**, so the canopy is fully closed and
  the understory is in full shadow (`Lighting` is ordinary daylight: `ClockTime` 14.5,
  `Brightness` 3, `GlobalShadows` true — this is real canopy shadow, not a lighting fault);
- `block1-gap` proves the other half: where there is no canopy overhead, the view opens and the
  distance reads.

Moving the scattered regeneration into the young patch (`ages.young` 0.18 → 0.04) was measured and
helped, but did not open the sight lines. **The remaining levers are Karen's taste values** and are
listed in the task report: `density.dense`, `TREE_SPACING`, and whether a crown should be allowed to
overhang a 28-stud road corridor at all.

Two further looked-at defects, both in the proxy layer rather than in the structure:

- **the ferns and brush render as black angular shards.** They are plain 4.5-stud Parts with
  `Material = LeafyGrass`; under canopy shadow the material's silhouette reads as dark spikes, and at
  1,300 of them they dominate the floor;
- **the shadowed forest floor reads blue-grey**, not leaf litter, because an unlit terrain surface
  takes its colour from the sky. The palette is correct and is asserted; what is wrong is what a
  closed canopy does to it.

---

## 7. Open, and whose

| Item | Whose |
|---|---|
| The four CC0 ground textures are not downloaded or uploaded, so M3 is untaken and the `materials` step reports every role as "no asset row". `tools/roblox_upload.py` is Model-only by design | The Director (§8.3 of the design: four Asset Manager clicks, or an `Image` type added to the upload tool as its own task) |
| How thick the wood is, and whether a crown may close a forest road | Karen (design §19 Karen 2), with §6 above as the evidence |
| The ferns/brush proxies | Karen or an art task; the structure does not depend on them |
| `Lighting`'s `Atmosphere` and `DepthOfField` make every close screenshot hazy and blurred. This system may never write `Lighting` | A `TASKS.md` row; row 79a(c) is the same finding about fog |
| The two-player run | Not asked for by `TWO_PLAYER_PATHS`, but this change touches `src/shared/Drive`-adjacent contract data the match reads, so the Director decides |
