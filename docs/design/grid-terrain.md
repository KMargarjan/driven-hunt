# Design: grid-terrain — the ground of the eight cells, and the forest standing on it

Task 328 · Architect · 2026-11-02 · written to `reviews/task-328/BRIEF.md`, which **overrides anything
older** in `docs/`, `TASKS.md` or an earlier design (`docs/ARCHITECT_PROMPT.md`). Read with
`reviews/task-328/SWARM_DESIGN.md` (sections 1–4 and B1–B11 are decided and are not re-opened here)
and `docs/research/2026-11-02-terrain-v2.md` (rule 1).

Karen, 2026-11-02 ~08:05 UTC: *"Terrain what I explained previuosly how it has to be … (we kee same
trees we have do not make same as on image colours ect) I need perfect terrai … not broken trees
hanging or to inside"*.

This document rules on what the brief left to the Architect: the owners, the interfaces, the seam the
tool crosses, the geometry the brief found broken, and how each claim is tested. It settles the three
numbers the research note refuted, the four open points of SWARM_DESIGN §7, and **five more defects
found by reading the code** (§14), two of which would have deleted the forest or reddened CI.

---

## 0. Supersession — what this displaces in `docs/design/grid-map.md`

Two documents describing one piece of ground is the second-writer failure rule 3 exists to stop. Every
row below is a displacement; everything in `grid-map.md` not named here is untouched and still binding.

| `grid-map.md` | Was | Becomes |
|---|---|---|
| **§1.2 item 2** — *"Must not write terrain HEIGHT"* | absolute | **Narrowed, not lifted: no code in `src/` ever writes terrain height**, and `grid_relief.spec` asserts the string `WriteVoxels` appears nowhere under `src/server/`, `src/client/` or `src/shared/`. The height is written **once, at Edit time, from `src/serverstorage/TerrainBake/`** driven by `tools/terrainbake.py` — a tool, in Karen's Forest Test, after a backup. §2, §5 |
| **§3.1 owners**, row *"The roads' terrain MATERIAL … `Ground.paintRoads`"* | run-time writer, every boot, in Play | **the Edit-time tile pass writes shape and material together** (conflict 12). `Ground.paintRoads` is archived under `backups/` with a note (rule 7) in 328e, **with `grid.spec`'s case 19 archived in the same commit** — see §16 |
| **§4.4** — *"the relief is Karen's existing bought terrain … No terrain height is written anywhere"*; **open decision D-5** | measured only | **D-5 is CLOSED: sculpt.** Relief = the measured base + one baked landform a cell. The four `relief` fields and `lineMeanY` **keep their shape and their meaning** and are re-filled by the post-bake survey (§5.5). The escape hatch §4.4 designed for is the one being used |
| **§4.5** — the tree recipes | `zones`, `skirtStuds` | `CELL_PLANS` **v2** (§8.1): `rides`, `cuts`, `frontage`, per-zone `jitter` / `reliefBias` / `floor`, `field`, `fernBand`, `scaleFloor` 0.35. `standTypes` is **derived, not written** (§8.5) |
| **§8.1–8.3** — per-drive `Slice` planting, its budget, the road paint at boot | the only path | **Edit-time prebuild into `Workspace.GridForest` + a border wood**, with v2 budgets (§12). `Slice` and `Places.dressCell` are **kept whole as the measured fallback** (rule 7), behind the 328g gate |
| **§8.4** — the ground rule | by reference to `drive-places.md` | unchanged in substance: `TreeGround` + `Places` stay the one owner of the contact arithmetic (§9.1). What is new is the **template audit, the quarantine and `TEMPLATE_DIMS`** |
| **§11.3 step 2** — *"`Places.build` destroys BOTH folders at boot, always"* | correct, and **fatal to a prebuild in `GridPlaces`** | unchanged **for `GridPlaces` and `DrivePlaces`**. The prebuilt forest lives in a **third folder, `Workspace.GridForest`, which no code in `src/` ever destroys** (§10.1). This is defect **F-1**, §14 |
| **§15 K-6** (roads bare earth or grass rides) | open | **closed: bare earth.** `Places.SURFACES` already carries the measurement — 31 of 65 samples on Karen's road are already `Enum.Material.Ground` — and the grid road's cross-section (§7.1) is built on it |
| **§13.4 / D-1** (the frame fault) | open | **still open, and still not this design's to close.** The route that works in the Forest Test is `Camera.TestLook`'s `DHTestLook` attribute plus `shot.ps1` (`ESCALATE.md`, task 306h item 1: *"`ftplay.py capture` IGNORES the camera and the look point during Play"*). §13.4 |

---

## 1. What it must do, and what it must not do

### 1.1 Must do

| Must | Why |
|---|---|
| Give each of the eight cells **one landform** on top of the measured base, sculpted **once** at Edit time in the Forest Test, after a full backup | SWARM_DESIGN §2.1, conflict 1. Karen: *"I need perfect terrai"* |
| Put **no tree hanging, leaning, lying, sunk or inside anything**, and prove it with an instrument that is **not** the thing that planted it | Karen's sentence is the acceptance test: *"not broken trees hanging or to inside"*. The lesson is task 199's and 326's |
| Keep **our trees**: the 7 groups of `Places.SPECIES`. No new pack, no recolour, no upload, no asset id | Karen: *"we kee same trees we have do not make same as on image colours ect"* |
| Write **shape and material together**, in one tile pass | conflict 12. `Terrain:WriteVoxels` is the only call that can; `ReplaceMaterial` cannot move a voxel |
| Make a road and a ride something a hunter can **see down and shoot along, with no crown over it** | SWARM_DESIGN §1.4. §7.2 and §8.3 are the arithmetic, and the brief's §6.2 is why the old arithmetic failed |
| Be **re-runnable and idempotent**: an interrupted 70-minute bake can be resumed and a re-baked tile is a no-op | B2's base snapshot. A bake of ~1,053 tiles **will** be interrupted |
| Be **reversible**, by the one rollback Workspace has: the backup `.rbxl` | note §4 item 6. There is no terrain undo an API can reach |
| Stay inside a **stated, measured and printed** budget | D8, Karen: *"to not be laggy or look odd"* |
| Do **nothing at all** outside PlaceId **130094961655666**, loudly, before every mutating call | B1. The harness runs in DEV |

### 1.2 Must not

Each line is a boundary, not a style note.

1. **No code in `src/` may write terrain height or terrain material.** Both are the Edit-time tool's.
   `src/server/Places/Ground.luau`'s run-time `paintRoads` is archived (rule 7); `Ground.paint` (the
   four line places' strips) is **untouched** until 327d retires those places.
2. **Must not fork the contact arithmetic.** `ReplicatedStorage.TreeGround` and
   `ServerScriptService.Places` (`clawFor`, `trunkBox`, `groundsUnder`, `stepAllowance`) keep every
   constant they measured. SWARM_DESIGN §3.5 is read as *what the census must check*, never as new
   arithmetic (§9.1).
3. **Must not put Luau arithmetic in a Python string.** The bake's world half is a module on disk
   (`src/serverstorage/TerrainBake/`), linted by `selene src`, formatted by StyLua and reviewable as a
   diff. `tools/terrainbake.py` holds **no arithmetic** (§3, §6).
4. **Must not be a second planter.** `Places.plantOne` is the only thing that makes a planted tree in
   either path. The Edit-time prebuild **drives the same function** (§10.2).
5. **Must not let the planter certify its own work.** The census is a separate module that casts its
   own rays. It shares `TreeGround`'s **thresholds** and shares no **measurement** (§9.4).
6. **Must not destroy the prebuilt forest at boot.** `Workspace.GridForest` is outside every folder
   `Places.build` destroys and outside every Rojo-owned container (§10.1).
7. **Must not run without a usable `--backup`**, in the wrong place, in Play, or on a dirty tree (B7,
   B1, §6.2).
8. **Must not move `Grid.CONFIG`'s geometry to suit a voxel.** The voxel grid is satisfied by snapping
   the **band**, never the road centre (§7.1, defect F-2).
9. **Must not cite an unmeasured budget as evidence.** A budget line reads `MEASURED <value>` or
   `UNMEASURED`, and never a target restated as a result (§12.2).
10. **Must not delete.** Saved trees are moved by setting `Parent` only (B3); the losing branches are
    archived with a note.
11. **Must not claim a frame nobody looked at** (§13.4).

---

## 2. Owners — one writer each, named (rule 3)

This extends `grid-map.md` §3.1 rather than restating it. Every row the brief §5.1 asks for is here.

| State | Owner (the only writer) | Location on disk |
|---|---|---|
| **Terrain HEIGHT inside the footprint** | **`tools/terrainbake.py`**, driving **`ServerStorage.TerrainBake`**. Edit only, FT only, after `--backup`. **At run time: nobody** | `tools/terrainbake.py`, `src/serverstorage/TerrainBake/init.luau` (NEW) |
| **Terrain MATERIAL inside the footprint** | **the same writer, in the same `WriteVoxels` call.** `Places.Ground.paintRoads` is archived | as above |
| **Terrain height and material OUTSIDE the footprint** | **nobody.** It is Karen's bought ground; the bake blends back to the base over `BLEND_STUDS` 200 and writes no voxel past that | — |
| **The landform recipes and the shaping arithmetic** | **nobody at run time**: frozen data + pure functions | **`src/shared/Grid/Relief.luau`** (NEW) — `Relief.LANDFORMS`, `Relief.BAKE_VERSION`, `Relief.heightAt`, … (§4) |
| **The measured `relief` rows and `lineMeanY`** | **a commit**, from the post-bake survey's printed numbers (the Builder). No run-time writer | `src/shared/Grid/init.luau` — `Grid.CELLS[*].relief` |
| **`Grid.CELLS[*].towers` / `towersRelaxed`** | **a commit**, from 327b's own instrument re-run after the bake. No run-time writer | `src/shared/Grid/init.luau` |
| **THE TREES — the prebuild** | **`ServerScriptService.Places`**, unchanged owner, driven at Edit time by `terrainbake.py plant`. It parents into **`Workspace.GridForest`** | `src/server/Places/init.luau` — `Places.plantOne`, `Places.dressCell` |
| **THE TREES — the runtime fallback** | **`ServerScriptService.Places`**, unchanged owner, driven by `ForestTestBoot`. It parents into **`Workspace.GridPlaces`** | same module, `src/server/Places/Slice.luau` |
| **Which of the two runs** | **`src/server/ForestTestBoot.server.luau`** — one boundary read of two attributes, boot lines only, owns nothing (§10.3) | — |
| **The forest PLAN (pure): zones, rides, cuts, cones, corridors, the mask, the border wood** | **nobody at run time**: frozen data + pure functions | `src/shared/Places/init.luau` — `Places.CELL_PLANS` v2, `Places.mask`, `Places.plantCell`, `Places.borderPlan` |
| **The ground-contact ARITHMETIC** | **`ReplicatedStorage.TreeGround`** (pure) plus **`ServerScriptService.Places`** (the world-measuring half). Two modules, **one rule**, both unchanged | `src/shared/TreeGround/init.luau`, `src/server/Places/init.luau` |
| **`TEMPLATE_DIMS` and the quarantine list** | **a commit**, from `tools/forest_ground.py dims`' printed table (NEW subcommand). No run-time writer | `src/shared/Places/init.luau` — `Places.TEMPLATE_DIMS`, `Places.QUARANTINE` |
| **THE CENSUS** | **`ServerStorage.GridCensus`** (NEW) — the only thing that certifies, and it plants nothing | `src/serverstorage/GridCensus/init.luau` |
| **The EPOCH attributes** (`TerrainEpoch` on `Workspace.Terrain`, `PlantEpoch` on `Workspace.GridForest`) | **`tools/terrainbake.py`**, through `TerrainBake.stamp`. Nothing in `src/` writes either; `ForestTestBoot` and `GridCensus` only read | `src/serverstorage/TerrainBake/init.luau` |
| **The SAVED-TREE ARCHIVE** (`Workspace.Archive_SavedTrees_2026-11`) | **`tools/terrainbake.py archive`**, by setting `Parent` only, never `Destroy` (B3) | `src/serverstorage/TerrainBake/init.luau` — `TerrainBake.archive` |

**Rows for `GAME_DESIGN.md`'s *System owners* table** (rule 3), to be pasted by the Builder:

```
| **The ground of the eight cells** (terrain HEIGHT and MATERIAL inside the grid footprint, one landform a cell) | `tools/terrainbake.py` driving `ServerStorage.TerrainBake`, at **Edit time in the Forest Test only**, after a `--backup`. **Nothing in `src/` writes terrain height or material**, and `grid_relief.spec` asserts the call appears nowhere there. The shaping is pure and testable with no terrain in the world (`ReplicatedStorage.Grid.Relief`); the data (`Relief.LANDFORMS`) is separable from the arithmetic | `src/shared/Grid/Relief.luau`, `src/serverstorage/TerrainBake/`, `tools/terrainbake.py` | [design](docs/design/grid-terrain.md), [note](docs/research/2026-11-02-terrain-v2.md) |
| **The prebuilt forest** (`Workspace.GridForest`, saved with the place) | `ServerScriptService.Places` is still the ONE writer of a planted tree -- `Places.plantOne` in both paths -- and the prebuild is that owner's own `dressCell` driven from Edit instead of from the boot. `Workspace.GridForest` is destroyed by nothing in `src/`; `Places.build` keeps destroying `DrivePlaces` and `GridPlaces` exactly as it does. `ForestTestBoot` is the one arbiter of which path runs, from `TerrainEpoch` and `PlantEpoch` | `src/server/Places/`, `src/server/ForestTestBoot.server.luau` | [design](docs/design/grid-terrain.md) |
| **Whether every tree is really on the ground** (the census) | `ServerStorage.GridCensus`, which casts its OWN fresh rays at each part's real bottom face and plants nothing. It shares `TreeGround`'s THRESHOLDS and shares no MEASUREMENT -- task 199's lesson, that the thing which places a tree may not be the thing that certifies it | `src/serverstorage/GridCensus/` | [design](docs/design/grid-terrain.md) |
```

---

## 3. The seam the tool crosses — and `forest_ground.py`'s reason for injecting is stale

The brief §5.3 asks how the Luau the tool sends and the modules in `src/` stay one copy of the
arithmetic, and offers `tools/forest_ground.py`'s source injection as *"the precedent to follow or to
better"*. **Better it, and the reason is a fact in the repository.**

`tools/forest_ground.py`'s docstring says the injection *"exists because Karen's Forest Test place is
a DIFFERENT place: `default.project.json` serves only the DEV place, so
`require(ReplicatedStorage.TreeGround)` would be yesterday's copy, or absent."* That is no longer
true: `default.project.json` reads

```
"servePlaceIds": [136410205938347, 130094961655666],
```

so Rojo serves the Forest Test, and task 327c's live proof is the evidence that it works — it read
`ServerScriptService.Places.Slice` in that place at the code commit
(`reviews/task-327c/REQUEST.md`, claim 10).

**Ruling: the bake REQUIRES, and the sameness is MEASURED rather than promised.**

1. The world half lives on disk at `src/serverstorage/TerrainBake/init.luau` and is Rojo-synced into
   the Forest Test. It is linted (`selene src`), formatted (`stylua --check src`) and reviewable as a
   diff. **No Luau arithmetic in a Python string.** This is `tools/mapgen.py` ↔
   `ServerStorage.MapGen` exactly, and that tool's own header states the rule: *"Everything about
   talking to Studio … is IMPORTED from tools/studio_mcp.py rather than copied."*
2. Before **every mutating call**, the tool runs `check_synced`, which is `mapgen.py`'s own function
   (`tools/mapgen.py`, `check_synced`): `synced_nodes()` filtered to
   `ServerStorage.TerrainBake`, `ReplicatedStorage.Grid` and `ReplicatedStorage.Places`, then
   `compare_synced(studio, wanted)` — byte for byte, line endings normalised. A difference is a
   refusal, not a warning. Both functions are **imported from `tools/studio_mcp.py`**, never copied.
3. Studio's `require` cache can hold an older module after a Rojo sync — measured, and
   `mapgen.py`'s `STALE` query is the evidence (*"this Edit session has an OLDER
   ReplicatedStorage.Map in its require cache … Reopen the place when you want the session itself
   current (a Rojo sync cannot)"*). So **the bake loads every module through a parentless clone**:
   `require(ReplicatedStorage.Grid.Relief:Clone())`, the same idiom `STALE` uses
   (`require(script:Clone())`) and the same idiom the harness uses for a Rojo JSON module
   (CLAUDE.md, *"the harness requires a parentless clone in Studio"*). A clone resolves
   `ReplicatedStorage:WaitForChild(...)` because those paths are absolute, not sibling lookups.
4. **`Relief.luau` requires nothing**, so a clone of it is complete on its own. `Grid` requires only
   `Shotgun` (`src/shared/Grid/init.luau`), by an absolute path, so its clone is complete too.

**What this buys, said plainly:** `forest_ground.py`'s injection is text surgery
(`module_source()` strips `--!` lines and rewrites `export type`), and it cannot be linted in the
form that is sent. The require route sends nothing, so there is nothing to drift. `forest_ground.py`
itself is **not** rewritten by this task — it works, and rule 7 applies — but its stale rationale is
recorded here, and the task that next touches it should take this route (a queued note, §16).

---

## 4. `Relief.luau` — pure, and its data separable from its arithmetic (brief §5.2)

`src/shared/Grid/Relief.luau`. **Requires nothing.** No Instance, no Terrain, no service, no
`Workspace`, no `Random`. Every landform is assertable in a spec with no terrain in the world, which
is the brief's condition and `TreeGround`'s own discipline.

```luau
-- ---- DATA, separable: one row per cell id, the eight recipes of SWARM_DESIGN section 2.2.
Relief.LANDFORMS : frozen   -- [cellId] = Landform

export type Landform = {
    baseKeep: number,                 -- b in h = b*base + (1-b)*blur(base)
    ops: { Op },                      -- in order; the slope limiter and the road fade are not ops
    noTrees: { { v0: number, v1: number } }?,   -- cell-relative v bands with no trunk (the scarp)
}
export type Op =
      { kind: "dome"|"knoll"|"bowl", u: number, v: number, rStuds: number, dyStuds: number,
        flatFraction: number? }       -- bowl only: a flat floor inside this fraction of r
    | { kind: "ridge"|"trough", via: { { u: number, v: number, dyStuds: number } },
        halfWidthStuds: number }
    | { kind: "bench", v0: number, v1: number, weight: number, gradePercent: number }
    | { kind: "scarp", v: number, dropStuds: number, runStuds: number }
    | { kind: "ramp", u: number, widthStuds: number, gradePercent: number }

-- ---- THE ARITHMETIC. Pure. `bounds` is `Grid.boundsOf(id)`'s four numbers, handed in, so this
-- module never requires `Grid` and the two can be composed by a spec, by the bake or by the planner.
Relief.BAKE_VERSION : number          -- see section 5.4
Relief.BLEND_STUDS = 200              -- how far outside the footprint the result returns to the base
Relief.ROAD_FADE = { zeroStuds = 51, fullStuds = 120 }
Relief.BLUR = { sigmaStuds = 24, cutoffStuds = 72 }
Relief.LIMIT_DEG = { tree = 20, open = 32 }
Relief.VOXEL = 4                      -- one fact with `Ground.RESOLUTION` and `MapGen.Config.VOXEL`

Relief.uvOf(bounds: Bounds, x: number, z: number): (number, number)
Relief.blurKernel(): { number }                      -- separable, normalised, 1-D
Relief.weightOf(op: Op, bounds: Bounds, x: number, z: number): number      -- 0..1 falloff
Relief.deltaAt(form: Landform, bounds: Bounds, x: number, z: number): number
Relief.roadFadeAt(roads: { Grid.Road }, x: number, z: number): number      -- 0 near a centreline
Relief.heightAt(form, bounds, roads, baseAt: (number, number) -> number?, x, z): number?
Relief.limitPass(column: { number }, pitchStuds: number, ceilingDeg: number): { number }
Relief.columnsFor(centreStuds: number, nearStuds: number, farStuds: number): (number, number)
Relief.materialAt(form, bounds, plan, slopeDeg: number, depthStuds: number, x, z): string
Relief.tiles(footprint: Bounds, tileStuds: number): { { minX, minZ: number } }
Relief.epochInput(forms, config): string             -- the canonical JSON section 5.4 hashes
```

Three things about this shape are rules rather than details:

1. **`baseAt` is a function handed in.** The bake passes a reader over the **base snapshot**
   (B2), never live terrain; a spec passes a fake hillside. This is `Places.groundsUnder`'s own
   discipline (`groundAt` is a parameter) and `Lobby.Field`'s (*"a spec hands in a fake with a
   recording `FillBlock`, so no spec in the DEV place can write DEV's terrain, ever"*).
2. **`Relief.columnsFor` is the one place a nominal stud distance becomes a whole voxel column**, and
   it is `Ground.bandBounds`' arithmetic generalised to both axes — borrowed, not re-derived. §7.1 is
   why it exists.
3. **`Relief` never requires `Grid` and `Grid` never requires `Relief`.** The caller composes them.
   `src/shared/Places` already requires `Grid` one way (task 327c), and that stays the only edge.

---

## 5. The bake — the tile pass, the order of operations, the epoch

### 5.1 `ServerStorage.TerrainBake` — the world half

`src/serverstorage/TerrainBake/init.luau`. It requires `ReplicatedStorage` modules only and takes
every writer it needs as an **injected seam**, so it never requires `ServerScriptService.Places`:

```luau
TerrainBake.PLACE_ID = 130094961655666        -- asserted by the tool before EVERY mutating call (B1)
TerrainBake.TILE_STUDS = 128
TerrainBake.MAX_VOXELS = 24_576               -- MEASURED (see below); one fact with MapGen.Config
TerrainBake.BAND_PAD = { belowStuds = 16, aboveStuds = 32 }

TerrainBake.snapshot(region: Bounds): (Snapshot, string?)   -- step 1.5, B2. REFUSES Water/overhang
TerrainBake.tilePlan(region: Bounds): { Tile }              -- pure, delegates to Relief.tiles
TerrainBake.bakeTile(tile: Tile, slice: Snapshot, forms, roads, plan): TileReport
TerrainBake.survey(cellId: string): ReliefRow               -- read-only, step 4
TerrainBake.stamp(epoch: string): ()                        -- the ONE writer of TerrainEpoch
TerrainBake.archive(folderName: string, seams): ArchiveReport -- B3, Parent only, never Destroy
TerrainBake.census(seams): { CensusLine }                   -- delegates to ServerStorage.GridCensus
```

**The voxel ceiling is ours and is version-bound.** `MapGen.Config.VOXEL` records it: *"MEASURED,
2026-09-26 … `Terrain:WriteVoxels` accepts a 128 × 128 × 96-stud region at resolution 4
(32 × 24 × 32 = 24,576 voxels), and REFUSES resolution 8 and resolution 2 with 'Resolution has to be
4'."* The design's tile sits **exactly on** that ceiling, not under it. So:

- `bakeTile` computes its Y band from the snapshot slice (`min − 16` to `max + 32`) and **splits into
  stacked calls** whenever the band exceeds 96 studs. It never assumes one call is enough.
- `TerrainBake.MAX_VOXELS` is asserted against the computed region before every call, and a region
  over it is a refusal with the tile named — not a Studio error with no location.
- **328d's first ten tiles re-confirm the ceiling** rather than inheriting it. Studio is not pinned
  (CLAUDE.md, Toolchain).

**Tile alignment is a one-line discipline and it already holds.** `Region3:ExpandToGrid(4)` rounds
**outward** and the call throws on a misaligned region since 2025-04-30 (note §2, the DevForum bug
closed as intentional). `Grid.CONFIG.originX` is **−6700** and `originZ` **−6600**; both are multiples
of 4, and 128 is a multiple of 4, so every tile anchored at the origin minus a multiple of 128 is
aligned and `ExpandToGrid` has nothing to do. `grid_relief.spec` asserts that for every tile
`Relief.tiles` emits, so the discipline is a case and not a comment.

### 5.2 The region the bake covers

`footprint()` expanded by `Relief.BLEND_STUDS` 200 **plus** the border wood's 230 (B6's *"footprint
plus 430 st"*), then expanded outward to the 128-st tile grid. The exact tile count is
**`Relief.tiles`' own output, printed by the tool**, not a number in this document: SWARM_DESIGN's
1,053 is an estimate and 36 × 24 = 864 covers the bare 4490 × 2986 footprint. The design asserts the
**rule**, and the run prints the **count**.

### 5.3 Order of operations

Unchanged from SWARM_DESIGN §3.9, with the folder correction of §10.1 and the Q1 gate:

1. **Q1 answered** (§17), **Team Create checked**, the 327a part survey re-run over the footprint
   + 430 st and pasted (B6), **BACKUP**: Karen's click, noted in `backups/README.md`.
2. **BASE SNAPSHOT** (B2) → `<runs-dir>/terrain-base-<sha>.bin` + its sha, outside the repo. A tile
   holding Water or an overhang is **refused**, never guessed (note §4 item 5). `heightAt` never
   reads live terrain, which is what makes a re-run a no-op.
3. **SCULPT and PAINT**, one tile pass, shape and material in the same `WriteVoxels` call.
4. **RE-SURVEY**: `Grid.CELLS[*].relief`, `lineMeanY`, the road long profiles, the pads, the towers.
   Printed, then written into `Grid` **by a commit**.
5. **MASKS** (`Places.mask`, pure).
6. **PLANT** into `Workspace.GridForest`, nearest the hunter line first (`Slice.order`).
7. **CENSUS** (`ServerStorage.GridCensus`).
8. **FRAMES** (§13.4).
9. **SAVE**: Karen's click.

### 5.4 The epoch — settled (brief §3.1)

**Ruling: no code commit in the epoch. The Builder's version is rejected and the reason is the
brief's own: a commit-based epoch fails the census after every paperwork commit, which makes the
census a liar on every review round.**

```
TerrainEpoch = first 16 hex of sha256(baseSnapshotSha ‖ Relief.epochInput(LANDFORMS, CONFIG) ‖ tostring(BAKE_VERSION))
```

- `Relief.epochInput` is **canonical JSON**: keys sorted, numbers formatted `%.6g`, no whitespace. It
  covers `Relief.LANDFORMS` and the geometry fields of `Grid.CONFIG` (`originX`, `originZ`,
  `cellWidthStuds`, `cellDepthStuds`, `roadClearStuds`, `rows`, `columns`). It is canonical because
  the value makes two trips through two encoders — the same reason the harness compares a Rojo JSON
  module's **value** to a relative 1e-9 and not its text (CLAUDE.md, *File types*).
- **`BAKE_VERSION` bumps when the bake's ARITHMETIC moves** — a falloff shape, the blur σ, the slope
  limiter, the road fade, the Y-band rule, `columnsFor`. **It does not bump for a data change**,
  because `epochInput` already covers that.
- **Who is obliged, enforced rather than remembered.** `tests/server/grid_relief.spec.luau` reads
  `tests/server/relief_golden.luau` — a committed fixture holding `bakeVersion` and ~48 golden
  heights (6 per cell, at named (u, v) over a synthetic base). If the arithmetic moves, the samples
  stop matching and the failure message is *"the bake's maths moved: re-measure
  `relief_golden.luau` and bump `Relief.BAKE_VERSION` in the same commit."* The spec also asserts
  `Relief.BAKE_VERSION == golden.bakeVersion`, so the samples cannot be refreshed without touching
  the version. Pure, no Studio, and it fails the harness, which blocks the merge gate.
  A `Source`-digest check was considered and rejected: `Script.Source` needs plugin security and a
  spec cannot read it.
- `PlantEpoch`, a string attribute on `Workspace.GridForest`, carries the `TerrainEpoch` the plant ran
  against. **The census and the boot both fail when the two differ** (§10.3).

### 5.5 What the post-bake survey writes

`TerrainBake.survey` is **read-only** and prints 327a's own four fields plus `lineMeanY`, per cell,
on the same 20-stud lattice. A commit writes them into `Grid.CELLS[*].relief`. The `character`
classifier stays 327a's rule, so a baked ridge classifies as `ridge` by the same rule that classified
the base as `slope` — and `grid.spec`'s existing assertions do not move, which is exactly the escape
hatch `grid-map.md` §4.4 designed.

---

## 6. `tools/terrainbake.py` — interface and the refusal shape (brief §5.5)

### 6.1 Commands

```
python tools/terrainbake.py plan                                    # read-only: the tiles and the cost estimate
python tools/terrainbake.py snapshot --out <runs-dir>/terrain-base-<sha>.bin
python tools/terrainbake.py bake   --cells C1 --backup <f>.rbxl [--tiles 10]   # sculpt + paint
python tools/terrainbake.py survey                                  # read-only: the relief rows
python tools/terrainbake.py plant  --cells C1 --backup <f>.rbxl     # Edit-time prebuild
python tools/terrainbake.py archive --backup <f>.rbxl               # B3, Parent only
python tools/terrainbake.py census                                  # read-only
python tools/terrainbake.py dims                                    # read-only: TEMPLATE_DIMS + the audit
python tools/terrainbake.py selftest                                # no Studio, no network; CI
```

### 6.2 What it refuses, before it touches anything

`tools/mapgen.py`'s shape, with one change that B1 forces. Exit codes **0** done · **1** a step
failed · **2** REFUSED — *"deliberately the harness's shape"* (`mapgen.py`'s own docstring).

1. **Studio is not in Edit mode.** Karen may be playing.
2. **`game.PlaceId` is not 130094961655666.** Asked of **every connected Studio**, by place id and
   never by name — lesson L-055, which `forest_ground.py`'s `resolve_studio` records: *"a Studio that
   has just finished a Play session reports no name at all for several seconds, and a silent
   fall-back here would move the DEV place's trees instead of Karen's."* **Checked again
   immediately before every mutating call**, not once per run (B1) — a `bake` is ~70 minutes of
   calls and the operator can open another place inside it.
3. **A dirty tree**, for any mutating command. A world baked from uncommitted code cannot be
   reproduced from a commit — the harness's exit code 3 rule.
4. **Studio's copy differs from disk** for `ServerStorage.TerrainBake`, `ReplicatedStorage.Grid` or
   `ReplicatedStorage.Places` (§3 item 2). Catches *"nobody pressed Connect."*
5. **No usable `--backup`**: it must name an existing, non-empty `.rbxl` **outside** the repository,
   modified within `BACKUP_MAX_AGE_HOURS` **6**. `mapgen.py`'s `check_backup`, imported in
   substance; **`--backup census` is NOT accepted here**, because Karen's place is full of hand-made
   content a census cannot stand in for.
6. **`--cells` missing on `bake`/`plant`.** There is no default: an unnamed cell is an unbounded run.
7. **A flag or pose override is live.** `tools/flags.py clear` / `tools/pose.py clear` first, the
   rule `test` and `test2` already enforce.

### 6.3 The one pasteable report line

```
[bake] OK: 10/10 tiles @ <sha> cells=C1 epoch=<16 hex> worstTileMs=<n> peakMemMB=<n> (clean tree)
[bake] REFUSED: <reason>
```

and, for `plant` and `census`, `GridCensus`' own line (§9.4). Every run appends its per-tile report to
`.terrainbake/<utc>-<cells>.json` (git-ignored), `mapgen.py`'s run-log shape.

### 6.4 Its gate

`tools/terrainbake.py` is **not** in `BLAST_RADIUS` and resolves to no scope, so a change to it alone
is `scope=auto:none`. Its real gate is **`python tools/terrainbake.py selftest` as a CI step**, the
convention `.github/workflows/ci.yml` already applies to `studio_mcp.py`, `pose.py`, `agents.py`,
`aim_bench.py`, `meshy.py`, `boar_prep.py`, `roblox_upload.py` and `privacy_scan.py`. The selftest
covers every refusal above against a scripted Studio, the canonical-JSON encoder against the Luau
one, and the run-log writer. **No path of this task goes in `TWO_PLAYER_PATHS`** (B11).

---

## 7. The roads, the rides, the stands and the corridors

### 7.1 The road cross-section, with two corrections

The long profile is SWARM_DESIGN §3.1's, unchanged: sample every 20 st, pin the 15 junctions, clamp
the grade to 8 % (E–W) / 10 % (N–S) with ≤ 2 % change per 50 st, cut-or-fill ≤ 12 st, and a breach
**relaxes the grade on that road and is printed, never hidden**.

**Correction F-2: the road centre does NOT snap to 4k + 2. The BAND snaps.** `Grid.roads()`' centres
are `originX + 21 + k·1112` and `originZ + 21 + k·1472`; with `originX` −6700 and `originZ` −6600,
**all eight centres sit at ≡ 1 (mod 4)**, so B8's snap is a 1-stud move of every road — which moves
`roadZ`, `standPosition` and `boundsOf`, leaves each cell's clear half at 20 on one side and 22 on
the other, and re-opens `grid.spec`'s footprint case. Snapping the band instead costs nothing and the
arithmetic already exists: `Ground.bandBounds`' header records that the painted width comes out
`ceil(2·half / RESOLUTION) · RESOLUTION` *"whatever the road's own parity is — the defect the Reviewer
measured on the ride's ruts."* `Relief.columnsFor` is that function for both axes; every band below is
**nominal**, and the realised whole-column bounds are printed by the bake and measured by the census
at the realised column centres.

**Correction F-3: the ruts are at d ±8, not ±4.** `Places.SURFACES.track.ruts` carries the
measurement: *"±6 AND NOT ±4: measured after the first paint, a 4-stud offset snapped to the voxel
grid and the two ruts MERGED — the whole 18-stud track came back Mud, with no litter between them.
At ±6 the middle 8 studs stay `Ground`, which is ref-1's leaf litter between two wheel tracks."* The
grid road's carriageway is 20 st (±10), wider than the track's 18, so the rut takes the **outer**
carriageway column and the middle 12 st keeps the carriageway's own material.

| d (st), nominal | m | Shape | E–W material | N–S material |
|---|---|---|---|---|
| 0 to ±6 | 0–1.7 | level | Ground | Grass |
| ±6 to ±10 (**ruts**) | 1.7–2.8 | level, one whole column each side | Mud | Mud |
| ±10 to ±20 | 2.8–5.6 | level, crossfall ≤ 0.5 st over 44 st | Grass, then Grass/LeafyGrass | same |
| 22–30 (**ditch**) | 6.2–8.4 | two whole columns, 2 st deep | Mud | Mud |
| 30–34 (**verge**) | 8.4–9.5 | **no tree, no fern** | Grass | Grass |
| 34 → natural ground | ≥ 9.5 | bank ≤ 1:2, at least 12 st wide | the zone floor | the zone floor |

- **Junctions:** the E–W profile wins inside the junction square.
- **`Grid.CONFIG.roadClearStuds` does not move.** It is 42 and the identity
  `Places.laneHalfWidth(cellPlan) * 2 == Grid.CONFIG.roadClearStuds` is asserted by `grid.spec` case
  15. The 34-stud trunk minimum is a **separate, wider exclusion owned by `Places.mask`**, never a
  change to the road's clear width — see defect F-4, §14. Case 15 still passes: it asserts ≥ 21 and
  the new rule makes every planting ≥ 34, strictly stronger.

### 7.2 The trunk minimum beside a road — the arithmetic that actually satisfies the rule

Brief §6.2's fix (a), with the clearance it should have had:

```
roadTrunkMin(template, scale) = max(34, halfCrown(template) * scale + 10)
rideTrunkMin(template, scale) = max(27, halfCrown(template) * scale + 12)
```

**10 and 12 are the painted half-widths, not the verge.** What Karen looks down is the carriageway
(±10 on a road) and the painted ride (±12); the verge is not a thing anybody sights along. The
research note's 34 and 18 give 73 and 57 studs at `halfCrown` 39 and thin the roadside wood for no
gain Karen can see; these give **49 and 51**, which is the rule met at a cost the frames can judge.

**And the term bites rarely, because the frontage rule carries the work** — brief §6.2 fix (b), which
costs no density and which `CELL_PLANS` already half does (A1's *"spruce on the west side and
broadleaf on the east"*):

```luau
-- Places.CELL_PLANS[*].frontage
frontage = { studs = 60, groups = { "birch", "young", "aspen", "fieldOak" } },
```

Within 60 st of any road or ride centreline, only those four groups are drawn. `conifer` and `oak`
are set back. A broadleaf's half-crown is a few studs, so `halfCrown·scale + 10` falls under 34 and
the floor holds; the linear term is then a **guarantee for the scaled outliers**, not the everyday
rule.

**Who pays, named:** A1's front zone is `spruceThicket` at the main road today
(`zone(0.00, 0.00, 1.00, 0.30, 24, "spruceThicket", "wood")`), so its first 60 studs become birch and
larch. C2's two thickets likewise lose their road frontage. That is a visible change to two cells and
it is a frame for Karen, not a number.

**And it may not be claimed before it is measured.** `halfCrown` comes from `Places.TEMPLATE_DIMS`,
which does not exist (§9.2). Until 328b measures it, `halfCrown` is nil, the linear term is skipped,
the floors (34 / 27) and the frontage rule are the whole rule, and the census prints
`crownOverRoad=UNMEASURED` — **never 0**.

### 7.3 The rides — settled at 54 studs (brief §6.3)

**Ruling: the trunk-free ride is 54 st (15.1 m). The painted ride stays 24 st.** Three reasons, none
of them taste:

1. **15 m is the only published minimum for an open space to count at all** (BASC). At 36 st
   (10.1 m) not one ride in the design qualifies, and C1 scrapes BASC's 10–25 % band **on its roads
   alone** (~11.6 %, note §5). At 54 st C1 reaches ≈ 17 %, mid-band.
2. **It is the cheap half of the crown fix.** At 27 st from the centreline,
   `halfCrown·scale + 12` only exceeds the floor above `halfCrown·scale` 15 — which the frontage rule
   has already excluded.
3. **It costs almost nothing.** A 1430-st V ride widened by 18 st removes ~25,700 sq st, **1.7 % of a
   cell** — about 25 trees at a 32-st spacing.

**What is NOT met, said so nobody claims it:** 54 st is **0.54 ×** a 100-stud tree, against BASC's
1.0 × and Fieldsports' 1.5 ×. Both ratios exist to stop **shading**, which a game does not model, and
a ride wide enough to satisfy them would be a field. The geometric consequence those ratios imply —
no crown over the gap — **is** met, by §7.2 and the frontage rule. That is the deviation and it is
recorded, not hidden.

Otherwise SWARM_DESIGN §3.2 stands: painted Grass with Mud/Grass ruts, the ±1 st rut wander at a
24-st wavelength, and every L ride or X cut ending in ≥ 60 st of thicket or rising ground.

### 7.4 Stands, pads, cones, corridors

SWARM_DESIGN §3.3 and §3.4 in full, and all of it already has an owner: `ForestTest.Markers` owns the
posts, `ForestTest.Seats` the towers, `Grid.standPosition` the geometry, `Places.mask` the exclusions.
Two notes:

- **The pad is level to ±0.25 st and the census measures relief ≤ 1.8 st** on all 120. 1.8 is not a
  new number: it is `HighSeats`' own `JUMP_RELIEF_STUDS`, the threshold 327b's tower measurement used
  and the one `Grid.CELLS[*].towersRelaxed` had to relax for the whole of row 2. After the bake the
  pads are flat by construction, so `towersRelaxed` is **expected to flip to false** — and if it does
  not, that is a finding, not a pass.
- **The lane rule** (no ride or cut centreline within 12 st of another stand within 800 st) is
  asserted by geometry only. Flank shooting sectors stay **out of scope** (conflict 15).

---

## 8. The forest — v2

### 8.1 `CELL_PLANS` v2

Every field of v1 is kept under its own name. New fields, all of them data:

```luau
rides   = { { kind = "V"|"X"|"L", atStandIndex = n, lengthStuds = n } },
frontage = { studs = 60, groups = { "birch", "young", "aspen", "fieldOak" } },
field   = { at = { u0, v0, u1, v1 }, headlandStuds = 12, stripePitchStuds = 8 }?,  -- D1 only
fernBand = { fromStuds = 34, depthStuds = 30 },     -- measured from a road centreline, not from the cell edge
scaleFloor = 0.35,
-- per zone, all optional:
jitter = 0.25?, rows = "NS"?, reliefBias = true?, floor = "needle"|"leafLitter"|...?,
```

`zones`, `spacingStuds`, `deepSpacingStuds`, `minGapStuds`, `skirtFullStuds`, `skirtStuds`,
`shrubScale`, `woodScale` and `seed` are unchanged. `fernBandStuds` is **replaced** by `fernBand`,
because the old field measured 30 st inward from `Places.cellGround` (the cell edge, d 24 from a road
centre) and would put ferns in the ditch and on the verge, which §7.1 forbids — defect **F-5**, §14.

### 8.2 The mask — `Places.mask`, not `Grid.mask`

**Ruling: SWARM_DESIGN §3.6's `Grid.mask` is rejected, and the reason is a require cycle.**
`src/shared/Grid/init.luau` requires only `Shotgun`; `src/shared/Places/init.luau` requires `Grid`
(line 52, added by 327c: *"One direction only; `Grid` requires neither"*). Every input to the mask but
the roads is `CELL_PLANS` data — zones, rides, cuts, the field, the clearings, the frontage, the fern
band. A `Grid.mask` would have to require `Places`, which closes the cycle. So:

```luau
-- src/shared/Places/init.luau -- PURE. It generalises `clearOfEveryRoad` and `inLane`, which stay.
Places.REASON = table.freeze({
    ROAD = "road", VERGE = "verge", DITCH = "ditch", RIDE = "ride",
    STAND = "stand", TOWER = "tower", CONE = "cone", CORRIDOR = "corridor",
    NO_TREES = "noTrees", CLIFF = "cliff", FIELD = "field", CLEARING = "clearing",
    FRONTAGE = "frontage", CROWN = "crown", GAP = "gap",
})
function Places.mask(cellId: string, x: number, z: number, template: string?, scale: number?): string?
```

`nil` means plantable. The order is outermost-fact-first, `Rules.ORDER`'s own rule, and
`grid_ground.spec` asserts the order as a table rather than as prose. `Grid` keeps the roads
(`Grid.roads`, `Grid.CONFIG.roadClearStuds`) and gains nothing.

### 8.3 Relief bias, rows, ferns, scale floor

SWARM_DESIGN §3.7 whole, with one addition: `hn = (y − relief.minY) / relief.spreadStuds` reads the
cell's **post-bake** `relief` row (§5.5), so the bias follows the landform it was measured on. Ferns
in patches only, inside W/M/B/Bo zones, **none on a verge, in a ditch or under thicket**, hard cap
**400 a cell** (B9); a refused fern is dropped and is **not** counted in the tree refusal rate. Scale
floor 0.35.

### 8.4 The border wood

230 st deep, 40-st spacing, the mix copied from the nearest cell's front zone, planted **after** the
bake on the blended ground. It closes 327c's own finding — *"A row-2 cell's hunter looks south out of
the world"* (`reviews/task-327c/REQUEST.md`) — and conflict 14's field windows (320 × 300 st behind
every F stand) stand.

### 8.5 Stand types — DERIVED, never written

**Ruling: SWARM_DESIGN §2.1's letter table is the INTENT and does not go in code.** A hand-written
`standTypes` row and the zones that actually stand there are two writers of one fact, and they will
disagree the first time a recipe moves. So:

```luau
function Places.standTypeFor(cellId: string, standIndex: number): string   -- PURE, one letter
```

computed from the plan: which zone the stand faces, whether a ride or cut centreline lies in its
cone, whether a field or clearing is in front, whether it carries a tower. `grid_ground.spec` asserts
the **rules** — no two adjacent stands share a letter, every cell has ≥ 5 distinct letters over its
15 — and a cell that fails has its **recipe** changed, never its letter. The cost is named: a letter
table you can read at a glance is replaced by a function, and the design's §2.1 table becomes a
target the spec either reaches or reddens.

---

## 9. Ground contact, the template audit, and the census

### 9.1 The contact rule is `TreeGround`'s, and §3.5 does not fork it (brief §6.1)

**Ruling: the Builder's position is upheld in full.** `src/shared/TreeGround/init.luau` and
`src/server/Places/init.luau` keep every constant, because every one was measured on **this** forest
after Karen's *"look at the trees wtf"*:

| Quantity | Shipped, and it stands | SWARM_DESIGN §3.5 proposed | Verdict |
|---|---|---|---|
| contact point | `TreeGround.junctionY(minY, maxY, clawFraction)` — the trunk/root junction | *"Trunk bottom = low − sink"* | §3.5 is **the pre-fix rule Karen photographed**. Rejected |
| sink | `TreeGround.sinkFor(h) = min(0.6, 0.1h)` | `clamp(0.03h, 0.5, 2.0)` → 1.8 st at 60 st | 3× deeper than measured, unsourced. Rejected |
| spread accepted | `Places.stepAllowance(h) = max(TreeGround.CLIFF_STUDS, 0.10h)` | flat 3.0 | tighter than the measured 90th percentile (2.10) **and** than the shipped rule; it inflates the refusal rate §3.5 then caps at 8 %. Rejected |
| samples | **25**, `TreeGround.samples(box, 4)` → 5 × 5 | 29, undefined | Rejected |
| floating | `TreeGround.TOLERANCE_STUDS` **0.2** | census `> 0.25` | 0.2 wins; it is the number task 196's target is written in |

§3.5 is re-read as **the census's checklist**. What is genuinely new is kept whole, because nothing in
the repo does it: the **template audit**, the **quarantine**, and `TEMPLATE_DIMS`.

**327c's census is also superseded, and it needed to be.** `reviews/task-327c/REQUEST.md` claim 10
defines floating as *"lowest trunk geometry > 1 stud above the HIGHEST terrain under its footprint"* —
a 1-stud tolerance against the shipped 0.2, the **lowest** geometry rather than the junction, and the
**highest** ground rather than the lowest. All three are looser than the rule. §9.4 is the definition
that replaces it.

### 9.2 `TEMPLATE_DIMS` — and the hole is bigger than the brief says

The brief §6.1 says `Places.CLAW_FRACTION` *"holds 5 entries, all silver birch, against the 61 models
of `Places.SPECIES`"*. **Two corrections, both counted off the source.**

1. **`Places.SPECIES` names 35 model names, not 61** — conifer 7, young 4, birch 8, oak 3, fieldOak 4,
   aspen 4, fern 5. **61 is the number of models in `Workspace.OurForest`** (that table's own comment:
   *"61 models, 4,819 instances"*), and `tools/forest_claws.json` carries one row per folder model.
   `Places.plantCell`'s `scatter` can only clone a name in `Places.SPECIES`, so **the audit set is 35
   and measuring the other 26 is wasted work.**
2. **Only TWO of the 35 planted templates carry a non-zero claw fraction.** `Places.CLAW_FRACTION`
   holds `SilverBirch_Var07/10/11/12/13`; `Places.SPECIES.birch` holds
   `Var01/02/05/08/11/13` plus `SilverBirchTree_Var02/06`. The intersection is
   **`SilverBirch_Var11_LOD_0` (0.0425)** and **`SilverBirch_Var13_LOD_0` (0.0239)**. The other three
   measured fractions are for templates the planter **never plants**. So today **33 of the 35 planted
   templates seat at `clawFor` = 0**, i.e. by the lowest-point rule Karen rejected — a worse ratio
   than the brief's 56 of 61.

**And B10's `TEMPLATE_DIMS` definition is wrong as written.** It says *"measured once per template at
scale 1"*. `Places.plantOne`'s own comment: *"52 of this world's 61 templates stand at a `Scale` that
is not 1 (the birches at 0.032-0.054, the larches at 1.4-2.1)"*, and it plants with
`made:ScaleTo(made:GetScale() * item.scale)` — `item.scale` is **relative to the template's own
scale**. A reference measured "at scale 1" would fail B10's own ±15 % extents check on everything. So:

```luau
-- src/shared/Places/init.luau -- MEASURED by `tools/forest_ground.py dims` in the Forest Test,
-- one row per name in `Places.SPECIES` (35), each AT THE TEMPLATE'S OWN `GetScale()`, which is
-- recorded, because `plantOne`'s `item.scale` is relative to it.
Places.TEMPLATE_DIMS = table.freeze({
    SilverBirch_Var11_LOD_0 = table.freeze({
        scale = 0.0462,           -- the template's own GetScale() when measured
        heightStuds = 74.1,
        trunkHalfWidthStuds = 1.9,
        crownHalfWidthStuds = 12.4,   -- the union of FOLIAGE-named parts, half-extent, max of X and Z
        parts = 7,
    }),
    ...
})
Places.QUARANTINE = table.freeze({ ... })   -- names the audit failed, with the reason, never planted
```

**`crownHalfWidthStuds` comes free and needs no new definition of "foliage":**
`Places.isFoliageName` already exists and is already asserted to match no trunk name
(*"`places.spec` asserts that no name in `FOLIAGE_WORDS` matches any of those three"*).
`forest_claws.json` already carries `count` and `medianHeight` per model, so the height half of the
reference exists — but it was measured on **instances at their own scales**, so it is a cross-check,
not the reference.

**The claw fractions: do not re-run the method that failed.** The 33 zeros are `"unstable"` or
`"low-plant"` by the tool's own rule — *"the spruces and larches, whose skirt branches sweep to the
ground and whose 'first thing you hit' is a branch underside fourteen studs up"* — and the same
upward-ray pass will produce the same zeros. So 328b measures by a **second, independent method and
accepts only agreement in kind**: the lobby's horizontal rule (*"where the radius falls back to the
trunk's"*), which gave 0.075 for `Var11` against the vertical method's 0.0425 — *"the two agree in
kind and this one is the more conservative"* (`forest_ground.py`'s docstring). A template where the
two methods disagree keeps **0** and is **listed**, not quarantined: 0 is strictly safe arithmetic
(it seats the lowest geometry), and it only *looks* wrong on an arched base. **The census is what
proves it looks right**, because for a 0-fraction template `floating` is exactly
`trunk minY − lowest ground ≤ 0.2`.

### 9.3 The template audit and the quarantine (B10, kept whole)

Run once per template at build time, from `TEMPLATE_DIMS`. A template fails and is quarantined,
listed and never planted if:

- the trunk box's longest extent is not Y, or its vertical axis is more than 5° off true — this is
  what catches 327c-f3's lying birch at the **source**;
- a foliage box is **detached**: its `minY` is more than 1 st above the trunk box's `maxY`, or it has
  no XZ overlap with the trunk;
- its part count differs from `TEMPLATE_DIMS.parts`;
- its extents are outside ±15 % of `TEMPLATE_DIMS` × (`GetScale()` / `TEMPLATE_DIMS.scale`).

### 9.4 The census — `ServerStorage.GridCensus`

**It shares the thresholds and shares no measurement.** It requires `TreeGround` for
`TOLERANCE_STUDS`, `sinkFor` and `junctionY` — three constants and one line of arithmetic — and it
does **not** call `Places.trunkBox` or `Places.groundsUnder`. It finds each part's own real bottom
face and casts its own fresh rays. Task 199's lesson, verbatim: the thing which places a tree may not
be the thing that certifies it.

```
[census] C1 epoch=<h> trees=N parts=P floating=0 sunk=0 foliageInGround=0 tilted=0 broken=0
         inRoad=0 inVerge=0 inDitch=0 inRide=0 inStand=0 inTower=0 inLane=0 inBeaterPath=0
         onCliff=0 crownOverRoad=0 refused=k/N rock%=4.1 mud%=6.2 worstHigh=-0.18 worstSink=0.44
```

| Count | Definition — and it is `TreeGround`'s, not a new one |
|---|---|
| `floating` | `junctionY − lowest ground under the trunk footprint > TreeGround.TOLERANCE_STUDS` (0.2) |
| `sunk` | `lowest ground − junctionY > TreeGround.sinkFor(height) + 0.2` |
| `foliageInGround` | a foliage part's `minY < ground − 0.5` |
| `tilted` | `up · Y < cos 2°` |
| `broken` | the §9.3 audit fails **after** planting |
| `crownOverRoad` | `distance to the nearest road or ride centreline < halfCrown · scale + the painted half-width`. **`UNMEASURED` until `TEMPLATE_DIMS` exists** |
| `refused` | the planter's own `cliff` + `skipped`, as a fraction. **Reported only in 328b** (B5); gated ≤ 8 % from 328f |

Plus: road crossfall ≤ 0.5 st every 20 st and the grade inside its limit; **ditch depth at the
realised column centres** (§7.1), 2 ± 1.0 st (§15 item 2); the 120 pads at relief ≤ 1.8 st; each
landform's crest and floor within ±3 st of its recipe; Rock ≤ 6 % and Mud ≤ 8 % of the cell's
interior surface columns **excluding everything within 34 st of a road centre**; and a `border` line
and a `savedInBounds` line.

---

## 10. Prebuild, the folders, and the one arbiter

### 10.1 Three folders, and only one of them is saved — defect F-1

`grid-map.md` §11.3 step 2 is binding and correct: *"`Places.build` destroys BOTH folders at boot,
always, whichever world is live"*, and `grid.spec` case 21 asserts it. **A prebuilt forest in
`Workspace.GridPlaces` would therefore be deleted at every boot.** That is a hole the next task would
have inherited, and it is closed here.

| Folder | Written by | Lives | Destroyed by |
|---|---|---|---|
| `Workspace.DrivePlaces` | `Places.build` | a Play session | `Places.build`, when the world is not `forest-test` |
| `Workspace.GridPlaces` | `Places.dressCell` via `Slice` (**the fallback**) | a Play session | `Places.build`, and `dressCell` destroys its own previous cell |
| **`Workspace.GridForest`** (NEW) | **`Places.dressCell` driven from Edit** by `terrainbake.py plant` | **saved with the place** | **nothing in `src/`, ever.** Only `terrainbake.py` |
| `Workspace.Archive_SavedTrees_2026-11` | `TerrainBake.archive`, `Parent` only (B3) | saved with the place | nothing |

`ForestTest.GROUND_IGNORE` gains `"GridForest"` — one more name in the list that already carries
`"GridPlaces"` — and `grid_ground.spec` asserts the name exists once
(`table.find(Forest.GROUND_IGNORE, Planter.FOREST_FOLDER) ~= nil`), the idiom `places.spec` already
uses for `Places.FOLDER`.

### 10.2 Two drivers, one writer — the answer to brief §5.1

**They are not two writers, and the proof is structural rather than stated.** `Places.plantOne` is
the only function in the repository that creates a planted tree, and both paths call it through
`Places.dressCell`:

- the **prebuild** passes `gridFolder = Workspace.GridForest`, `breathe = nil` (no yield needed in
  Edit) and `groundAt = ForestTest.terrainYAt`;
- the **fallback** passes `gridFolder = Workspace.GridPlaces`, `breathe = task.wait` and the same
  reader, exactly as `ForestTestBoot` does today.

`Places.dressCell`'s signature already takes the folder, the ground reader, the template lookup, the
yield and the clock as arguments — *"EVERY MOVING PART IS AN ARGUMENT"* (its own header) — so the
prebuild needs **no second implementation and no new function**. `terrainbake.py plant` is a driver,
precisely as `mapgen.py` is a driver for `ServerStorage.MapGen`.

`Places.plantOne` gains one line: `made.ModelStreamingMode = Enum.ModelStreamingMode.Atomic`, so a
tree is never half-streamed (first-party streaming doc: *"all of the initial descendants are present
once the atomic model itself is available"*). **`Persistent` is refused** — the same doc warns it
*"permanently occupies memory"*.

### 10.3 `ForestTestBoot` is the arbiter, and it owns nothing

One boundary read, boot lines only:

```
live   = Workspace.Terrain:GetAttribute("TerrainEpoch")
planted = Workspace.GridForest and Workspace.GridForest:GetAttribute("PlantEpoch")

planted == live  ->  the prebuild stands. Dress NOTHING. Print the epoch and the model count.
GridForest absent ->  the fallback. Dress the active cell through Slice, exactly as today.
planted ~= live  ->  print REFUSED with both epochs and dress NOTHING.
```

The third branch matters: a stale forest on a re-baked landform is trees hanging in the air, which is
the defect this whole task exists to stop, and **nothing is silently rebuilt** (SWARM_DESIGN §4.1,
boot row). Both branches are reachable **by parameter** from a pure spec, because the two epochs are
arguments to `ForestTest.prebuildVerdict(live, planted)` and the boot reads the attributes once.

---

## 11. External sources (rule 1)

**I could not fetch any of these: the Architect has Read, Grep and Glob and no network.** Every
licence and maintenance status is from knowledge or from the research note's own fetch of
2026-11-02, and §18 says so.

### A. Roblox `Terrain` API reference — `ReadVoxels`, `WriteVoxels`, `ReplaceMaterial`, `Region3:ExpandToGrid`
<https://create.roblox.com/docs/reference/engine/classes/Terrain#WriteVoxels> ·
<https://create.roblox.com/docs/reference/engine/datatypes/Region3#ExpandToGrid>
**Licence:** first-party; source repo [`Roblox/creator-docs`](https://github.com/Roblox/creator-docs),
**CC BY 4.0**. **Maintenance:** actively maintained, commits this month.
**Does well:** it is the only API that can write **shape and material in one call**, which is the
whole of conflict 12. The occupancy/material array layout (`[x][y][z]`, 1-based, in the region's
order) is exact, and `ExpandToGrid` is a documented primitive rather than our own rounding.
**Does badly:** **it states no limits at all** — no maximum region, no allowed resolution, no voxel
size in studs, no error conditions. Every limit this design uses had to come from somewhere else.
**Adopted:** the read-modify-write loop, `ExpandToGrid(4)`, and occupancy as the way to express
sub-voxel height — which `src/serverstorage/MapGen/Ground.luau` already does
(`occupancy = clamp((h - bottom) / v, 0, 1)`).

### B. DevForum — *ReadVoxels/WriteVoxels/ReplaceMaterial suddenly error from not being aligned to grid (2025-04-30)*
<https://devforum.roblox.com/t/terrainreadvoxels-writevoxels-replacematerial-suddenly-error-from-not-being-aligned-to-grid-4302025/3633317>
**Licence:** community bug report; **closed as intentional** by Roblox with a technical explanation.
**Maintenance:** closed, not withdrawn.
**Does well:** the hard fact the bake depends on — since 2025-04-30 a misaligned region **throws**
`"Region has to be aligned to the grid"`, where the old silent snapping was *"inconsistent and
imprecise"* depending on coordinate sign. It names `ExpandToGrid(4)` as the sanctioned fix.
**Does badly:** a behaviour change with **no migration note in the reference pages**, so anything
written against pre-2025 examples breaks.
**Adopted:** alignment as a refusal, not a hope — §5.1's tile-origin discipline, asserted by
`grid_relief.spec` for every tile `Relief.tiles` emits.

### C. DevForum — *Maximum region info for Terrain ReadVoxels and WriteVoxels*
<https://devforum.roblox.com/t/maximum-region-info-for-terrain-readvoxels-and-writevoxels/178723>
**Licence:** community thread, 2018-09-13; staff reply 2018-10-02 (*"This is an issue we are aware of
and will be looking into"*). **Maintenance: never resolved, never documented.**
**Does well:** the only published number, and it is **by volume, not by dimension** — 267,632,640 cu
st worked, 268,646,400 threw `"Region is too large"`. Volume-based means a tall thin tile and a flat
wide tile are not interchangeable, which is why §5.1 checks the **computed voxel count** and not the
tile's footprint.
**Does badly:** eight years stale, empirically derived, and the 4,194,304-voxel figure in circulation
is in no document at all.
**Adopted:** the *shape* of the limit. **Not adopted: the number.** Ours is far smaller and is the one
built against — **24,576 voxels a call**, measured 2026-09-26 and recorded in
`src/serverstorage/MapGen/Config.luau` (`Config.VOXEL`) and `MapGen/Ground.luau`'s header.

### D. Roblox — instance-streaming techniques
<https://create.roblox.com/docs/workspace/streaming/techniques>
**Licence:** first-party, **CC BY 4.0**. **Maintenance:** actively maintained.
**Does well:** settles the prebuild's runtime half. `Atomic` guarantees a tree is never
half-streamed; it gives the defaults the design changes (`StreamingMinRadius` 64,
`StreamingTargetRadius` 1024, which is what `src/shared/Map/init.luau`'s `Map.STREAMING` records as
measured in this project) and warns against `Persistent` for scenery.
**Does badly:** its efficiency advice assumes *"the spatial extent of each model under ~64 cubic
studs"*, and our spruces are a measured **56–156 studs tall** (`Places.SPECIES`). **No mature tree we
own satisfies it**, and the doc offers nothing for scenery this size.
**Adopted:** `Atomic` per tree; `Persistent` refused; and the ≤ 16.7 ms client frame is **measured at
C1-8 and D2-12**, never predicted, because the doc's own premise does not hold for us.
`StreamingMinRadius` 64 → 384 **cannot be set from Luau** (measured, task 43, `Map.STREAMING`'s
`scriptable` list holds one property) and stays a **NEEDS KAREN** click.

### E. BASC — *Creating open spaces* and *Managing woodland*
<https://basc.org.uk/gamekeeping/land-management/creating-open-spaces/> ·
<https://basc.org.uk/managing-woodland/>
**Licence:** British Association for Shooting and Conservation, editorial; the facts are used, nothing
is reproduced. **Maintenance:** current trade guidance (the second dated 2024-01-31).
**Does well:** the two numbers a 12.0 ha cell can be tested against — open space **10–25 %** of a
woodland over ten hectares, and *"an open space needs to be at least 15 m wide to qualify"* — plus
the three functions our rides are for, in their words: rides are *"ideal flushing points"*, they
*"allow the demarcation of drives within big woodland blocks"* and they *"provide areas to line out
beaters at the start of a drive"*, which is §7.3's V/X/L rides and §7.4's corridors exactly.
**Does badly:** written for ecological indicators and for **shading**, not for sightlines. It says
nothing about where a gun stands or how far he can see, and its ride ratio (≥ 1.0 × tree height)
would make a 100-stud wood's ride wider than a road.
**Adopted:** the **15 m qualifying width** as the ride's trunk-free minimum (§7.3), and the 10–25 %
band as a per-cell target. **Not adopted:** the 1.0 × ratio, with the reason recorded.

### F. Fieldsports Journal / ShootingUK — *What about woodland?*
<https://fieldsports-journal.com/game-shooting/what-about-woodland/>
**Licence:** trade magazine, 2020-06-28. **Maintenance:** not maintained; a second independent voice
on the same ratio.
**Does well:** states the ride wider — *"the width of the ride being at least 1.5 times greater than
the tree height"* — and the planning principle the eight landforms exist to serve: the layout is
decided *"taking into account the prevailing wind and contours"* **before** planting, which is the
order §5.3 enforces (sculpt, re-survey, mask, plant).
**Does badly:** editorial, with no sources of its own, and its ratio disagrees with BASC's by 50 %
with no measurement behind either.
**Adopted:** contours before planting. **Not adopted:** 1.5 ×.

### G. Red Blob Games — *Making maps with noise functions*, with `amitp/mapgen2`
<https://www.redblobgames.com/maps/terrain-from-noise/> · <https://github.com/amitp/mapgen2>
**Licence:** `mapgen2` **Apache-2.0**; the articles' snippets are published for reuse.
**Maintenance:** the articles actively maintained; `mapgen2` **dormant** (no substantive work since
~2017).
**Does well:** the clearest statement of **a base field plus named shaping functions, composed by
weight** — a radial falloff, a redistribution, a blend — which is `Relief.deltaAt` summing
`Relief.weightOf(op)` exactly. It is also the source `grid-map.md` §12D already credits for
character-then-recipe, and `MapGen.Config`'s `OCTAVES` / `LACUNARITY` / `GAIN` / `WARP` are from the
same family.
**Does badly:** its regions are Voronoi polygons on a Poisson scatter — nothing like a road grid —
and its whole output is a 2-D picture from above. It says nothing about what ground looks like from a
hunter's eye at 5.6 studs, which is the only thing Karen judges (rule 5).
**Adopted:** additive weighted landform ops over a measured base; the smoothstep falloff family.
**Not adopted:** noise as the base (ours is Karen's bought ground) and nothing of its region shape.

### Borrowed from inside this repository, said plainly (rule 2)

`TreeGround` and `Places`' contact arithmetic, **unchanged**; `Places.plantOne` / `dressCell` /
`Slice` as the one planter in both paths; `Ground.bandBounds`' whole-voxel snap, generalised to both
axes as `Relief.columnsFor`; `MapGen.Config.VOXEL`'s measured ceiling and `MapGen.Ground`'s occupancy
loop; `MapGen.steps`' step split (*"~3,000 Models in one step is one step that can time out and tell
you nothing about where it was"*); `mapgen.py`'s refusal shape, `check_synced`, `check_backup` and
run log; `forest_ground.py`'s `resolve_studio` place check and its claw measurement; `Lobby.Field`'s
injected-terrain discipline and its voxel-boundary lesson (`Field.cutBottomY`, `Field.shelfFor`);
`Camera.TestLook`'s held-look attribute for the frames; task 199's independent-census habit.

**Invented here, with the reason rule 2 asks for:** the **template audit and quarantine** (no prior
art in the repo, and the only thing that stops a broken template before it is planted 1,500 times);
the **base snapshot + `BAKE_VERSION` epoch with a golden fixture** (idempotency across an interrupted
70-minute bake, and an obligation that is enforced rather than remembered); and the **crown term for
rides** (§7.2), which is a correction to the swarm design rather than a new system.

---

## 12. Numeric targets

### 12.1 Measured, and therefore usable as evidence today

| # | Target | Instrument | Where the number comes from |
|---|---|---|---|
| 1 | `floating` 0, `sunk` 0, `foliageInGround` 0, `tilted` 0, `broken` 0, every `in*` 0, `onCliff` 0 — per cell | `GridCensus`, fresh rays | the acceptance test, Karen's sentence |
| 2 | floating = junction more than **0.2 st** above the lowest ground under the trunk footprint | `TreeGround.TOLERANCE_STUDS` | measured, task 196. **Supersedes** §3.5's 0.25 and 327c's 1.0 |
| 3 | sink = `min(0.6, 0.1h)` | `TreeGround.sinkFor` | measured. **Supersedes** `clamp(0.03h, 0.5, 2.0)` |
| 4 | spread accepted ≤ `max(4.0, 0.10h)` | `Places.stepAllowance` | measured: a flat 4.0 refused **776 of 2,713** candidates. **Supersedes** the flat 3.0 |
| 5 | ≤ **24,576 voxels** a `WriteVoxels` call, resolution **4**, region `ExpandToGrid(4)`-aligned | the bake's own refusals | `MapGen.Config.VOXEL`, measured 2026-09-26. **Re-confirmed on the first 10 tiles** (Studio is not pinned) |
| 6 | the voxel is **4 st**, and it is the floor on every vertical detail | `Ground.RESOLUTION`, `Relief.VOXEL` | *"the only value `ReplaceMaterial` accepts"* |
| 7 | a rut is **4 st wide at d ±8**, never ±4 | the paint census | `Places.SURFACES.track.ruts` — at ±4 the two ruts **merged** |
| 8 | plant cost **0.69 ms a model** | `Slice.stats()` | measured in Karen's place, 327c. **Supersedes** `drive-places.md` M9's derived 0.45 |
| 9 | ride trunk-free **≥ 54 st (15.1 m)**; open space **10–25 %** a cell | geometry | BASC's 15 m; C1 ≈ 17 % at 54 st against ≈ 11.6 % at 36 |
| 10 | trunk min **34 st** (road) / **27 st** (ride), plus `halfCrown · scale + 10 / + 12` | `Places.mask` | §7.2 |
| 11 | ferns **≤ 400 a cell**, hard cap | the planter's counter | B9 |
| 12 | `refused` **≤ 8 %** a cell | the planter's counter | **reported only in 328b** (B5); gated from 328f. 327c measured 146 of 2,165 = **6.7 %** in C1 on unsculpted ground |

### 12.2 UNMEASURED — and no gate may cite one of these as evidence before its task measures it

**This is a standing rule, not a caveat.** A budget line in a `REQUEST.md` reads `MEASURED <value>` or
`UNMEASURED`, never a target restated as a result (rule 8; lesson L-127).

| Target | Measured by | Status |
|---|---|---|
| ≤ **8 s** a tile; ≤ **6 GB** Studio memory, sampled every 50 tiles | **328d**, ten tiles before anything else | UNMEASURED. No tile has been written |
| ~**70 min** for the tile count `Relief.tiles` emits | **328d**, extrapolated from the ten | UNMEASURED; the count itself is printed, not asserted |
| the ditch's **achieved depth**, 2 ± 1.0 st | **328d**, from the ten tiles, **before 328e paints one** | UNMEASURED. §15 item 2 names the fallback |
| place file **≤ 150 MB**; Studio save **≤ 90 s**; **+25–40 MB** | **328g** | UNMEASURED |
| client frame **≤ 16.7 ms** at C1-8 and D2-12, Device Simulator **off**; ≈ 5,000 models / ≤ 17,000 parts within 1024 st | **328g** | UNMEASURED. Source D's own premise does not hold for our trees |
| server heartbeat ≤ baseline + **1.0 ms** (A/B at t + 120 s) | **328g** | UNMEASURED |
| live `StreamingMinRadius` (64 → **384**) | **328g** prints whatever is live (B4) | a **NEEDS KAREN** click; not settable from Luau |
| ≈ 2,400 models / ≤ 8,000 parts a cell; ≈ 19,800 models / ~63,000 parts world-wide | **328i** | derived from 327c's measured 3.2 parts a model |
| the B2 bot climb of the scarp | **328h** | UNMEASURED. §15 item 4 |
| **crown half-widths for all 35 planted templates** | **328b** | UNMEASURED. Blocks targets 1 and 10, and `crownOverRoad` reads `UNMEASURED` until it lands |

---

## 13. How it is tested (brief §5.4)

Standing rule G: **a spec in no scope turns CI red** (`tools/studio_mcp.py selftest` fails if a spec
file belongs to no scope). Every new file below names its scope.

### 13.1 `tests/server/grid_relief.spec.luau` (NEW) — scope **`map`**

`src/shared/Grid/` → `map` (`BLAST_RADIUS`), so the file joins `SCOPE_SPECS["map"]` beside
`grid.spec.luau`. Pure; it runs in DEV where there is no terrain.

1. **the golden fixture** — `Relief.BAKE_VERSION == golden.bakeVersion`, and all ~48 sample heights to
   1e-6 over a synthetic base (§5.4);
2. **eight landforms, one per cell id**, every op's fields in range, every `u`/`v` in [0,1];
3. **each op's falloff is bounded and continuous** — `weightOf` in [0,1], 0 at the edge of its
   support, and ≤ 0.001 of change per stud at the support boundary (no step a 4-st voxel can show);
4. **the bench, the scarp and the ramps meet their recipe** — crest and floor within ±3 st, and the
   ramp's grade within 1 % of 15;
5. **the road fade** — `roadFadeAt` is 0 within 51 st of any centreline and 1 at 120 st, for all
   eight roads, so no landform can tilt a road;
6. **the slope limiter** — over a synthetic cliff, 8 passes bring every 16-st window under 20° in a
   tree zone and 32° on open ground, and **leaves the scarp and the ramps alone**;
7. **outside the footprint the result is the base**, to 1e-9, past `BLEND_STUDS` 200;
8. **every tile is voxel-aligned** — for every tile `Relief.tiles` emits, both origin coordinates are
   multiples of 4 and the tile is a multiple of 4 wide (§5.1);
9. **no tile exceeds the measured ceiling** — `32 × 32 × (band / 4) ≤ 24_576`, with the band taken
   from a synthetic relief, and a taller band **splits**;
10. **`columnsFor` returns whole voxel columns** for every nominal band in §7.1's table, at a road
    centre ≡ 0, 1, 2 and 3 (mod 4) — the parity case `Ground.bandBounds` exists for;
11. **`epochInput` is canonical** — key order and number format stable under two encodings, and the
    epoch changes when a landform number changes and **does not change** when nothing does;
12. **nothing in `src/` writes terrain** — a source scan over `src/server/`, `src/client/` and
    `src/shared/` finds no `WriteVoxels` and no `FillBlock` (§1.2 item 1). `src/serverstorage/` is
    exempt by name, and the case says why.

### 13.2 `tests/server/grid_ground.spec.luau` (NEW) — scopes **`lobby`**, **`places`**, **`map`**

Triple membership, the idiom `SCOPE_SPECS` already uses: `src/shared/TreeGround/` → `lobby`,
`src/shared/Places/` and `src/server/Places/` → `places`, `src/shared/Grid/` → `map`. Driven through
fake-terrain fixtures, so it runs in DEV with no template and no world.

1. **the contact rule is `TreeGround`'s, by identity** — `Places.stepAllowance`, `TreeGround.sinkFor`
   and `TOLERANCE_STUDS` are read from those modules and compared with the census's own constants, so
   a fork reddens a case rather than shipping;
2. **`TEMPLATE_DIMS` covers exactly the names `Places.SPECIES` plants** — 35 of 35, no extras, and
   every `Places.QUARANTINE` name is in `SPECIES` and is **never** returned by `speciesFrom`;
3. **the audit catches each failure separately** — a lying trunk (axis > 5° off), detached foliage, a
   part-count change and extents outside ±15 %, one synthetic template each, **and the ±15 % check
   uses `GetScale() / TEMPLATE_DIMS.scale`** and not 1 (§9.2);
4. **`Places.mask` refuses for the right reason, in the stated order** — a table over the 15 reasons,
   asserted as `Places.REASON` order and not as prose;
5. **no trunk within 34 st of a road centre or 27 st of a ride centre**, over every cell, asked
   **independently** of the mask and then through it (`drive-places.md` §10.4 item 3's lesson);
6. **the crown rule, by parameter** — with a synthetic `TEMPLATE_DIMS` giving `halfCrown` 39 at scale
   1.2, no trunk is closer than 56.8 st to a road centre or 58.8 to a ride centre; and with
   `TEMPLATE_DIMS` **absent** the floors hold and the census's `crownOverRoad` reads `UNMEASURED`;
7. **the frontage rule** — within 60 st of any centreline, only the four named groups are drawn, over
   all eight cells;
8. **ferns are outside the ditch and the verge** — every fern ≥ 34 st from a road centre (defect F-5),
   and ≤ 400 a cell;
9. **stand types are derived and meet their rules** — no two adjacent equal, ≥ 5 distinct a cell, over
   all eight cells, from `Places.standTypeFor` alone;
10. **the census and the planter disagree about nothing but the instrument** — one synthetic hillside,
    the planter's verdict and the census's, every tree: same count, same names;
11. **the census reads non-zero when it should** — a tree lifted 0.3 st reads `floating` 1, one sunk
    1.2 st reads `sunk` 1, a lying one reads `tilted` 1. A census that can only print 0 is a census
    that proves nothing (lesson L-086);
12. **`GROUND_IGNORE` carries `GridForest`**, once, and the three folder names differ.

### 13.3 `tests/server/grid.spec.luau` (extended) — scopes **`map`**, **`places`**, unchanged

- the `Places.mask` cases above are **in `grid_ground.spec`**, not here, to keep this file's 22 cases
  stable;
- case 19 (`Ground.paintRoads` through an injected terrain, ≤ 300 calls) is **archived together with
  the function** in 328e (§16);
- case 21 (`Places.build` destroys the other world's folder) is **extended**: it also asserts
  `Workspace.GridForest` is **not** destroyed in either world.

### 13.4 Live, in Karen's Forest Test — what a spec cannot answer

Every FT task pastes its probe lines next to the DEV harness line, as 327c did (B1). **The DEV harness
cannot evidence FT work and no line may pretend otherwise.**

| What | Probe | Target |
|---|---|---|
| the bake's cost | `[bake]` line, ten tiles first | worst tile, peak memory, per-tile seconds — **printed, gated at 8 s / 6 GB** |
| the achieved ditch depth | `[census]` ditch rows at the realised column centres | 2 ± 1.0 st, measured **before 328e** |
| the landforms | `[census]` landform rows | crest and floor ±3 st of the recipe, all eight |
| the roads and pads | `[census]` road rows | crossfall ≤ 0.5 st / 20 st; grade in limit; cut-or-fill ≤ 12 st **or reported**; 120 pads at relief ≤ 1.8 |
| every tree on the ground | `[census]` per cell | every count **0**; `refused` reported in 328b, ≤ 8 % from 328f |
| the quarantine | `terrainbake.py dims` | the list, with a reason a line each |
| performance | 328g's own lines | §12.2's rows, each `MEASURED` or `UNMEASURED` |
| the bot climb | 328h | the fraction of beaters that cross the B2 scarp |

**Frames (rule 5) — and the harness fault is reported, not worked around (rule 6).** `ESCALATE.md`,
2026-11-01: `screen_capture` against the Forest Test returns **one cached image for six
camera/look pairs**; and task 306h item 1: *"`ftplay.py capture` IGNORES the camera and the look point
during Play"*. **The route that works** is `Camera.TestLook`'s held `DHTestLook` attribute (level-
triggered, never written by the camera, one writer: the probe) plus `shot.ps1`, and every frame in
`reviews/task-306h/` was taken that way. So:

- every frame in this series is taken through `DHTestLook`, at **eye 5.6 st above the pad** (FOV 70)
  or **17.5 st** on a tower deck, and the camera point is **printed beside the frame**;
- a frame whose sha256 matches an earlier frame **counts as no frame**;
- an FT frame after a sync needs a Play stop/start;
- per planting task: **3 frames a cell** — the signature stand, the line-centre stand down the road,
  a 45° aerial. Final sign-off: **48 + 7** photo-matched;
- **until the cached-image fault is fixed, rule 5 on this work is Karen's eye and nothing else**, and
  no task may claim a frame it could not take (rule 8). This is open decision **D-1**, inherited.

**Harness input (Task 6):** nothing in this series is input-driven, so `input_scenarios.txt` is
untouched. Tasks 6 and 7 are both closed; what the harness still cannot do is touch, gamepad, and
anything after the client report (task 6's own list) — none of which this design needs.

---

## 14. Five defects found by reading the code

Each would have been inherited. Each has a file, a symbol and a fix.

**F-1 — the prebuild would be deleted at every boot.** `grid-map.md` §11.3 step 2 and `grid.spec`
case 21: `Places.build` destroys `GridPlaces` and `DrivePlaces` at boot, always. A forest prebuilt
into `GridPlaces` is gone at the next Play. **Fix:** a third folder, `Workspace.GridForest`, written
only by `terrainbake.py` and destroyed by nothing in `src/` (§10.1). Case 21 is extended to assert it.

**F-2 — snapping the road centre to 4k + 2 moves every road by one stud.** `Grid.roads()` centres are
`originX + 21 + k·1112` and `originZ + 21 + k·1472` with `originX` −6700 and `originZ` −6600, so all
eight sit at ≡ 1 (mod 4). B8's snap leaves each cell's clear half at 20 on one side and 22 on the
other and re-opens `grid.spec`'s footprint case. **Fix:** snap the **band**, with
`Relief.columnsFor` — `Ground.bandBounds`' own arithmetic, which has the measurement behind it
(§7.1).

**F-3 — ruts at d ±4 merge.** `Places.SURFACES.track.ruts`: *"±6 AND NOT ±4: measured after the first
paint, a 4-stud offset snapped to the voxel grid and the two ruts MERGED — the whole 18-stud track
came back Mud."* **Fix:** the rut is the outer carriageway column, d ±6 to ±10, leaving the middle
12 st as the carriageway's own material (§7.1).

**F-4 — a 34-stud trunk minimum would break `Places.laneHalfWidth`'s identity.**
`Places.CELL_PLANS`' header: *"`laneHalfWidth` (9 + `LANE_STUDS` 12) is 21, which is
`Grid.CONFIG.roadClearStuds / 2` exactly"*, and `grid.spec` case 15 asserts it. Raising
`roadClearStuds` to reach 34 would move `Grid.CONFIG`, `ForestTest`'s stand span and the footprint
arithmetic at once. **Fix:** `roadClearStuds` stays 42; the 34-stud minimum is a separate, wider
exclusion owned by `Places.mask` (§7.1, §8.2). Case 15 passes unchanged and strictly more easily.

**F-5 — the fern band plants in the ditch.** `Places.fernBands(cellId, plan)` measures
`plan.fernBandStuds` (30) inward from `Places.cellGround`, whose inset is
`Places.CELL_EDGE_STUDS` (3) — so the band runs from d 24 to d 54 from a road centre, straight through
the ditch (22–30) and the verge (30–34), which §7.1 declares fern-free. **Fix:** `fernBand` is
`{ fromStuds = 34, depthStuds = 30 }`, measured from the **road centreline**, asserted by
`grid_ground.spec` case 8 (§8.1).

**And a sixth, in a document rather than in code:** brief §5.3's premise that *"Rojo serves nothing"*
in the Forest Test is false — `default.project.json`'s `servePlaceIds` holds both places (§3). That
is what makes the require route available and the injection unnecessary.

---

## 15. The four open points of SWARM_DESIGN §7, settled (brief §3)

1. **The epoch.** `BAKE_VERSION`, not the code commit — §5.4. `epochInput` is canonical JSON;
   `BAKE_VERSION` bumps only for an arithmetic change; the obligation is enforced by
   `relief_golden.luau`, which fails the harness if the maths moves without the version.
2. **The ditch and the trunk minimum. CONFIRMED, with one change and one named fallback.** Two whole
   voxel columns (nominal d 22–30), realised by `Relief.columnsFor` at the centre's own parity, 8 st
   wide, **2 st deep as occupancy** — `MapGen.Ground` already writes sub-voxel height that way, so
   depth is expressible. The trunk minimum stays **34 st**, which clears the verge. **But the census
   tolerance is ±1.0 st, not ±0.5**, because a 2-stud feature is half a voxel and
   `Lobby.Field`'s measurement is that a partial voxel comes out *"0.752 studs off its nominal
   shelf"*. **328d measures the achieved depth on its ten tiles before 328e paints a single ditch; if
   the error exceeds 1.0 st the ditch goes to 4 st — one whole voxel — and that fallback is named now
   so nobody invents one later.**
3. **The unmeasured budgets stay targets.** §12.2 is the table, with the task that measures each, and
   §1.2 item 9 and §12.2's heading are the rule: no gate cites one before it is measured.
4. **B2's 24° scarp. It ships at 24°, with THREE ramps from the start, not two.** This is arithmetic,
   not a hedge: the beater corridors are at x = 160, 310, 460, 610, 760, 910 and the ramps at u .20
   and .78 are x ≈ 214 and 835, so the corridors at 460 and 610 cross the scarp with **no ramp within
   ~225 st** — and `Bots.Lane`'s corridor jitter is ±20 st, which cannot reach one. A third ramp at
   **u .50 (x 535)** cuts the worst corridor-to-ramp distance to ~75 st. Three 60-st ramps are 17 %
   of a 1070-st frontage, which the landform can carry. **328h still measures the climb**; if it
   fails, the face comes down, and **the floor is the ramps' own 15 %** — below that it is not a
   scarp and B2 needs a different landform, which is a Karen question and not a quiet edit.

---

## 16. Deltas to the task split, and to the documents this touches

The split of SWARM_DESIGN §5.3 is the Director's and is kept. **What changes inside the tasks, named
plainly as the brief §2 item 7 requires:**

| Task | Change this design makes |
|---|---|
| **328b** | **The audit set is 35 names, not 61** (§9.2), and the claw measurement uses a **second, cross-checked method** with 0-and-listed as the honest outcome. `TEMPLATE_DIMS` records the template's **own `GetScale()`**, not scale 1, and `crownHalfWidthStuds` comes from `Places.isFoliageName`. `GridCensus` is a **new module in `src/serverstorage/`**, not a function in `Places`. `grid_ground.spec` joins **three** scopes. `ModelStreamingMode = Atomic` lands here, in `plantOne` |
| **328c** | `Relief.luau` **requires nothing**; `Relief.columnsFor` is part of it (F-2); `relief_golden.luau` ships with it; `grid_relief.spec` joins **`map`**; the hillshade PNGs are a tool-side render of `Relief.heightAt` and need no Studio |
| **328d** | adds `src/serverstorage/TerrainBake/` (the Luau on disk, linted) and **`terrainbake.py selftest` as a CI step**; the tool **requires** rather than injects, behind `check_synced` and a parentless-clone load (§3); it measures the **ditch depth** on the ten tiles (§15 item 2) |
| **328e** | archives `Ground.paintRoads` **and `grid.spec` case 19 in the same commit** — a case asserting an archived function is a false-PASS path. The ruts move to d ±8 (F-3) |
| **328f** | `Places.mask` lives in `src/shared/Places/`, **not** `Grid` (§8.2, the require cycle). The ride is **54 st** (§7.3); the crown term is linear with the frontage rule carrying it (§7.2); `fernBand` is measured from the road centreline (F-5); `standTypeFor` is derived (§8.5) |
| **328g** | the gate also asserts the **three-branch boot arbiter** (§10.3), including the REFUSED branch, by parameter |
| **328h** | **three** ramps on B2 (§15 item 4); the post-bake re-survey writes `relief`, `lineMeanY` **and** re-measured `towers` / `towersRelaxed` |
| **328i** | the whole-world plant goes into **`Workspace.GridForest`** (F-1); the archive re-parents only (B3) |

**Exact text for the Builder to paste** (the Architect script writes only this file):

**`docs/design/grid-map.md`** — a new **§18, *Superseded by the grid's terrain (task 328)***:
> **§4.4's open decision D-5 is CLOSED: sculpt.** The relief is the measured base plus one baked
> landform a cell, written **once at Edit time** by `tools/terrainbake.py` driving
> `ServerStorage.TerrainBake` in the Forest Test, after a backup. The four `relief` fields and
> `lineMeanY` keep their shape and are re-filled by the post-bake survey — the escape hatch §4.4
> designed is the one being used. **§1.2 item 2 is NARROWED, not lifted: no code in `src/` writes
> terrain height or material**, and `grid_relief.spec` asserts the call appears nowhere there.
> **§3.1's row for `Ground.paintRoads` is superseded**: the Edit-time tile pass writes shape and
> material together, and that function plus `grid.spec` case 19 are archived under `backups/` with a
> note (rule 7) in task 328e. **§4.5 becomes `CELL_PLANS` v2** and **§8.1–8.3 become the Edit-time
> prebuild plus a border wood**, with `Places.dressCell` and `Slice` kept whole as the measured
> fallback behind 328g's performance gate. **§11.3 step 2 is unchanged for `GridPlaces` and
> `DrivePlaces`, and the prebuilt forest lives in a third folder, `Workspace.GridForest`, which
> nothing in `src/` ever destroys** — see `docs/design/grid-terrain.md` §10.1. **K-6 is closed: bare
> earth**, on `Places.SURFACES`' own measurement. **The full design is
> `docs/design/grid-terrain.md`, and where the two disagree that document wins.**

**`docs/design/drive-places.md`** — append to its §19:
> **§1.2 item 3 is NARROWED by `docs/design/grid-terrain.md` §1.2 item 1** (task 328): the grid's
> terrain height is written once, at Edit time, by a tool, in the Forest Test only. **Nothing under
> `src/` writes terrain height or material**, so this document's prohibition holds for every system
> it is about. **§7.2's unverified premise — that a Play session's terrain write is discarded when
> Play stops — stops mattering here**: the bake runs in **Edit** and is saved on purpose, and its
> rollback is the backup `.rbxl`, not a discard.

**`docs/design/map-generator.md`** — append to its grid section:
> **The grid's terrain IS now generated, and `MapGen` is still not what generates it** (task 328).
> The bake is `ServerStorage.TerrainBake` driven by `tools/terrainbake.py`, in the **Forest Test**,
> not DEV, and the only things borrowed from this generator are the **measured voxel ceiling**
> (`Config.VOXEL`: 24,576 a `WriteVoxels` call at resolution 4, and resolution 4 is the only value
> the API takes), the **occupancy loop** in `MapGen.Ground`, the **128-stud tile** and the **step
> split**. §12.2's one-id-table rule is untouched: the bake adds no asset id.

**`tools/forest_ground.py`** — a header note for the task that next touches it (queued, §17 D-3):
> The injection's stated reason is stale: `default.project.json`'s `servePlaceIds` holds the Forest
> Test as well as DEV, so `require(ReplicatedStorage.TreeGround:Clone())` behind
> `compare_synced` is available and is what `tools/terrainbake.py` does
> (`docs/design/grid-terrain.md` §3). This tool is not rewritten here; it works, and rule 7 applies.

---

## 17. Open decisions

### Karen (feel and design)

**Q1 — MAY WE PERMANENTLY RESHAPE THE GROUND IN YOUR FOREST TEST?** A full copy is saved first, so it
can be put back. **UNANSWERED, and 328d does not start until she answers. The default is not
assumed** (B6). **What a NO deletes, in one place, honestly:** the sculpt ends; `grid-map.md` §4.4's
measured relief stands; §4 and §5 of this document — `Relief.luau`, `TerrainBake`,
`terrainbake.py`, the epoch, the base snapshot, the post-bake survey — are **not built**; the ditch,
the verge, the level road profile and the landform census rows go with them. **What survives a NO:**
the whole forest layer — `Places.mask`, the 54-stud rides, the crown and frontage rules, the fern
band, the derived stand types, the border wood, `TEMPLATE_DIMS`, the template audit, the quarantine,
`GridCensus`, the prebuild and `Workspace.GridForest`. That is 328b, 328f, 328g and 328i: **most of
the value, and all of "not broken trees hanging or to inside"**, which is the sentence she actually
wrote. A NO costs the relief, not the forest.

**Q6 (new) — the roadside spruce becomes birch and larch.** The frontage rule (§7.2) replaces the
first 60 studs of A1's and C2's thickets along the roads and rides with broadleaf and larch. It is
what stops a crown hanging over the road, and it changes the two cells she would most notice. **A
frame, not a number** — 328f's.

Q2 (build once), Q3 (D1's meadow with tractor stripes), Q4 (flank sectors, out of scope) and Q5
(row 1 low, row 2 high) proceed on their defaults, and this design is written to them.

### Director (scope)

**D-1 (inherited, still open) — THE FRAME FAULT.** `screen_capture` against the Forest Test returns
one cached image for six cameras (`ESCALATE.md`, 2026-11-01), and `ftplay.py capture` ignores the
camera during Play (task 306h). The `DHTestLook` route works and is what §13.4 mandates. Either the
fault is fixed, or every task here is accepted on Karen's eye and **says so**. This design cannot
close it and will not pretend to.

**D-2 — Team Create.** B6 puts the check at 328d step 0: in a Team Create place the save behaviour is
reported **before anything is baked**. If the place is in Team Create, the Director decides whether a
70-minute bake runs in it at all. Unanswered by anyone.

**D-3 — `tools/forest_ground.py`'s injection.** Its stated reason is stale (§3, §16). Rewriting it to
the require route is a task of its own and is **not** in this split. Queue it or say it stays.

**D-4 — the ride at 54 studs does not meet either published ratio** (0.54 × a 100-stud tree against
BASC's 1.0 × and Fieldsports' 1.5 ×). The design records why (§7.3) and meets the geometric
consequence instead. **Ratify that deviation, or set a wider ride and accept the density cost.**

**D-5 — `terrainbake.py` has no scope and no spec.** Its gate is `selftest` in CI (§6.4). A change to
it alone resolves to `scope=auto:none`, which is correct and worth the Director knowing before a
review round cites it.

**D-6 — the tile count is printed, not asserted.** SWARM_DESIGN's 1,053 is an estimate; 36 × 24 = 864
covers the bare footprint and the border wood pushes it up. §5.2 asserts the rule and prints the
count. If the Director wants a number in a gate, 328d's `plan` is where to take it from.

---

## 18. Not verified (no Studio, no network in an Architect run)

1. **Every external link in §11 was not fetched.** The Architect has Read, Grep and Glob. Licences
   and maintenance statuses are from knowledge and from the research note's own fetch of 2026-11-02
   (which did fetch them, and recorded one page as **checked and failed to yield numbers** — the
   Scottish Wild Deer Best Practice guides, whose woodland-design page now 301s).
2. **No number in this document was measured in Karen's place by me.** Everything measured is quoted
   from the repository with its file and symbol: `MapGen.Config.VOXEL`, `TreeGround`'s constants,
   `Places.stepAllowance`'s 776-of-2,713, `Places.SURFACES.track.ruts`, 327a's survey, 327b's tower
   measurement, 327c's 0.69 ms a model and its 146-of-2,165 refusals, task 43's `Map.STREAMING`.
3. **The 24,576-voxel ceiling is ours and is version-bound** (*"in this Studio version"*). Studio is
   not pinned (CLAUDE.md, Toolchain), so 328d re-confirms it on ten tiles rather than trusting it.
4. **The ditch's achieved depth is arithmetic, not a reading.** §15 item 2 names the measurement and
   the fallback. 2 studs is half a voxel and `Lobby.Field` measured 0.752 studs of error on a partial
   voxel by a different API.
5. **Crown half-widths and claw fractions for 33 of the 35 planted templates are unmeasured.** §7.2's
   arithmetic is over a plausible 0.15–0.25 height ratio. It is a reason to measure before planting,
   not a measurement — and `crownOverRoad` reads `UNMEASURED` until 328b lands.
6. **No bake cost exists.** 8 s a tile, ~70 min, +25–40 MB, a 90 s save and the 6 GB ceiling are
   estimates with no reading behind them (§12.2).
7. **Roblox streaming over a 4,490-stud world with ~19,800 models is unasserted and unassertable** —
   four of `Map.STREAMING`'s five properties cannot be read from Luau. It is a thing to look at
   (328g), not to test.
8. **The B2 bot climb is unmeasured** (§15 item 4), and so is a 1,430-stud bot lane walk through
   planted wood (`grid-map.md` §16 item 7, inherited).
9. **Team Create's save behaviour in that place is unknown** (D-2).
10. **I did not run the harness, open Studio, take a frame or read a terrain voxel.** Task 328a is
    docs-only.

---

## 19. The roads bend (task 328o, pasted by 328q)

*`docs/design/grid-roads.md` section 14's delta for this document, pasted by the task that makes it
true. Born at amplitude 0: nothing in any world moves until 328r's re-bake commit.*

> **§7.1's cross-section is measured from a centreline that is now a FUNCTION of the station:**
> `centre = Grid.roadCentreAt(road, along)`. The long profile's 20-stud sampling, the 15 pinned
> junctions, the 8 %/10 % grade clamp, the ≤ 2 %/50 st rule, the 12-stud cut-or-fill cap, the
> junction-square rule, the carriageway, the ruts at d ±6…±10, the ditch, the verge, the bank and
> every material are **unchanged**; three lines of `TerrainBake.roadAt` move, plus `longProfile` and
> `profileSamples`, which must sample the curve because the base reader and the profile have to agree
> on one lattice. **Correction F-2 is kept and extended: the band snaps to whole WORLD voxel columns
> at each station**, so the ditch and the rut stay whole columns everywhere — asserted over 50
> stations, where a bent centreline visits all four residues mod 4 and a straight one visits one — at
> the cost of a 4-stud lateral stair every **31.46 studs** along an east–west bend (31.24 north–
> south), which is `Grid.bendFacts().stairStuds` and not a typed number. One voxel, printed by the
> census, with §15 item 2's 4-stud ditch as the named fallback. **WHICH WIDTH A ROAD RULE MEANS MUST
> NOW BE SAID**: *"carriageway"* is the **painted** 20-stud strip in §7.1's prose and §7.2, and a
> **half-width** in §7.1's own table row and in `TerrainBake.ROAD.carriagewayStuds = 20`, which makes
> the level formation 40 studs. **§4's `Relief.luau` is not touched, not one line**: the bake hands it
> GRID coordinates and a base reader composed with `Grid.toWorld`, and in grid coordinates the roads
> are straight, so `roadFadeAt` becomes curve-correct for free — asserted by converting 1,056 world
> points within 51 studs of the curved centreline, at amplitude 0 and at 45/60, and finding every one
> inside the grid zero band. **`BAKE_VERSION` stays 1 and `relief_golden.luau` does not move;
> `Relief.epochInput`'s key list gains the three bend rows** (`bendEwStuds`, `bendNsStuds`,
> `bendHarmonic`), so the epoch changes the moment the amplitudes are committed, the stale-forest
> refusal fires and `tools/terrainbake.py`'s captured epoch fixture is re-captured in the same commit.
> **`TerrainBake.regionFor` and `unionOf` grow by `Grid.maxBendStuds()`** (0 today, so
> `EXPECTED_TILES` does not move in 328q and **does** have to be re-derived in 328r), and `cellAt`
> converts with `Grid.toGrid`. `blendAt` and `limitGrid` need **no edit**: the first measures against
> the box `unionOf` already grew, and the second takes a height grid and a pitch and no coordinates.
> **§7.4's pads, §8.2's mask, §8.5's stand types and §9.4's census all keep their arithmetic**, because
> everything inside `src/shared/Places` is grid-coordinate and bend-free; four functions convert at
> the seam (`roadDistance`, `clearOfEveryRoad`, `mask`, `nearestCellTo`), and `plantCell` and
> `standPosition` convert outward. **C1 is re-baked from the 328k base snapshot** — absolute heights
> over the old bake, so the straight road's cut and fill are erased, not layered — and the re-survey
> re-writes `relief`, `lineMeanY`, `towers` and `towersRelaxed` in the same commit. `TerrainBake.survey`
> samples `lineMeanY` **along the curve** for that reason.
