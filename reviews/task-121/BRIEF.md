# Task 121 brief: the forest, block 1 (Director, carrying Karen's decisions)

Written 2026-10-04 by the Director for the Architect's design run
(`tools/architect.sh design map-generator --task 121`). This brief overrides anything older in `docs/`,
`TASKS.md` or `docs/design/map-generator.md` (v3) where they disagree. The result is **map-generator v4**:
a revision of v3, not a new system.

## Karen's words (verbatim, 2026-10-04)

> "I want to have places like from real life hunt in germany poland lithuania ect / where hunters stand in forest where is forest road where animals has to cross road to another forest realistic / with mountains a bit ect / different trees different situations different road different views"

> "1 big forest with several drive oportunities? so we can make different ares where drive starts and scope it ? as example rectangle and we say 4 blocks drive 1 first block drive 2 second block ect and different ares there more trees less trees yang trees ect"

> "we can do ofc a mic not only same all in one block it has to be real and mix"

> "do all without me until first forrest" (she delegated every decision to the Director until block 1 is built)

## Decisions already taken (do not reopen)

1. **One big forest, divided into DRIVE BLOCKS** (rectangles) by **forest roads**. A drive = one block: the drivers push through that block; the shooters stand on the roads around it; the boars cross a road into the neighbouring block. Design the layout for **4 blocks** (2×2 or 4 in a row — decide), **build block 1 now** (this task), the other three later with the full tree pack.
2. **Every block is a realistic MIX**: a dominant character per block plus other species scattered, patches of young trees, small gaps/clearings, deadwood (fallen trunks), brush and ferns, wetter spots in low ground; natural transitions between blocks; only the roads are straight. **Block 1's character: old oak (and beech where we have it) with a young-tree patch and a gap.**
3. **Real numbers** (Director's research, 2026-10-04, sources in the research note the Builder writes): a drive block ≥ 70–100 ha in reality — scale it to what the game needs, but keep the proportions; stands ~300 m apart in reality on the escape routes between covers; driven-hunt stand floor 1.8–2 m; shots ≤ 60–80 m, downward; forest roads 3.5–4.5 m (main 5–5.5 m) with a cleared corridor 4.5–7 m. Gentle hills ("mountains a bit"): low-mountain feel, never steep enough to block the boar agent or a walking driver.
4. **Tree assets**: Karen bought BuiltByBit's "Realistic Oak Tree Pack" (Standard EULA: commercial use, hosting and modification allowed; no redistribution/resale — the meshes are never published to the Creator Store). It arrives as an `.rbxm` (`<assets-dir>/forest/oak-test/oak.rbxm`, ~70 KB) whose MeshParts **reference meshes the seller uploaded** (5 asset ids) with SurfaceAppearance and ~3 LOD sets (seller: ~6k/5k/3k triangles). `.rbxm` is banned in the repo: the design must say how the generator gets these trees (e.g. the Director inserts the rbxm into a Studio-owned template location outside Rojo's containers, or the asset ids are recorded in the assets registry and the generator builds MeshParts from ids). The Director tests the oak in Studio first (scripts inside? do the seller's meshes load in Karen's place? triangles, LODs, performance with 100+ trees) and adds the facts to the brief before the Builder starts. The full 9-species pack (~$54) may follow for blocks 2–4; the design must make adding species pure data.
5. **Ground and roads**: CC0 textures (Poly Haven / ambientCG: forest floor, leaf litter, gravel road, grass ride, mud) as terrain MaterialVariants. **Upload OK from Karen** (2026-10-04, "my ok") covers these, our own stand model and the oak meshes if needed.
6. **Stands**: no Drückjagdbock model exists anywhere (research): we build our own simple timber stand (floor ~2 m, ladder, rail, ~1–3k triangles) — rule 2's written reason is that none exists. The posts on the roads around the active block become these stands.
7. **The map switch** stays a commit (CLAUDE.md "THE MAP SWITCH IS THE EXCEPTION"). The arena stays the default until Karen sees the forest.
8. **Performance budget** is part of the design: hundreds of trees, LOD use, streaming, and a measured frame-time target with the boar sounder and two players.

## What the design must contain

1. The forest layout: the 4 blocks, the roads (widths, a main road and rides), the hills, where the shooters' stands go for each block's drive, where the drivers start, where the boars spawn and where they exit (across a road into the next block).
2. The mix model: how a block's species, age classes, density, gaps, deadwood, brush and wet spots are described as DATA per block, and generated reproducibly (seeded).
3. How tree assets enter the generator (decision 4) and how a new species is added.
4. Terrain materials and the CC0 texture pipeline.
5. The stand model (our own) and where it is placed.
6. What changes in the map contract (`ReplicatedStorage.Map`) and for the drive/boar systems (drive area = the active block; the corridor; exit).
7. Numeric targets (sizes, densities, budget), how it is tested (specs + screenshots), and the build order for **block 1 only**.
8. Open decisions: only taste calls; the Director decides the rest.

## Out of scope

Blocks 2–4 content (layout only), the animal count per drive (Karen: after the map), rounds/score/penalties, purchases.
