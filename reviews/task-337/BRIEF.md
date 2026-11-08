# BRIEF for `tools/architect.sh design cell-loading --task 337`

The Builder, carrying the Director. Read this FIRST; it overrides anything older in `docs/`,
`TASKS.md` or an earlier design (`docs/ARCHITECT_PROMPT.md`).

Note: `docs/research/2026-11-08-one-cell-at-a-time.md` (sources, the pattern, targets T1-T6).

## 1. Karen's two decisions (verbatim, 2026-11-08) -- DECIDED, NOT OPEN

1. *"so we will need to optimize, we only load one per game thats it"*
2. *"so rest part of map we can remove we can only focus on those what we have from A1 ect /
   outsource also best practicisess"*

The design does not re-open either. "One per game" means one CELL of `Grid.CELL_ORDER` in
`Workspace` at a time. "Remove the rest" means the land outside `Grid.footprint()` plus the 300-stud
margin, less an explicit keep set.

## 2. What must be designed

### A. Cell loading (the new system)
- A planted cell's wood is **stored** (server-side, not drawn, not replicated) and only the round's
  **active cell** stands in `Workspace`.
- Changing the active cell **swaps them on the server**. The swap time is measured and printed.
- **Planting a cell never destroys another cell's stored wood.** This is a live defect: task 335's
  `Places.dressCell` takes a `keep` set and fells every cell folder not in it
  (`src/server/Places/init.luau`, `dressCell` / `dressCells` / `dressPending`).
- The boot must still read **STANDS** (`ForestTest.prebuildVerdict`) without re-planting.
- The guarantee is a **reconciliation** run at boot and at every swap -- what is in `Workspace`
  against what should be -- not logic that only fires inside `plant`/`swap` (lesson L-029).
- **`Places.isPlanted` reads the static `Grid.PLANTED_CELLS`** (`src/shared/Places/init.luau`).
  Once cells move in and out, *has a wood* and *is standing now* are two different facts and the
  skirt rule, `cellCapacity` and `standTypeFor` all read the one name. Say which fact each caller
  wants, name them separately, and make the live one read the world (lesson L-093).

### B. World trim
- Decide **where it lives**: a `tools/` Edit-time command (the `tools/terrainbake.py` precedent --
  it already writes this world's terrain from Edit and is a second DRIVER of one writer, not a
  second writer), or a `src/` boot step. Terrain outside the grid cannot be re-created by a boot
  step, which is an argument, not a conclusion.
- **Archive-first (rule 7)**: parts are MOVED to an archive container with a note, never destroyed.
  Terrain cannot be moved; its removal is covered by the place backup and by nothing else, so the
  backup is a precondition of the terrain half **and of that half alone**.
- The keep set and the removal set are both named **by region and by instance count**.

## 3. The measured ground truth (Forest Test, 2026-11-08, before any change)

Instruments: `<runs-dir>/337-census.luau`, `337-regions.luau`, `337-terrain.luau`,
`337-frametime.luau`, `337-streaming.luau`, `smoke.sh`.

### Workspace, in a Play session: 75,008 instances / 31,437 parts

| Child | inst | parts | inside footprint+300 | outside |
|---|---|---|---|---|
| `OurForest` | 24,192 | 9,901 | 0 | 9,901 |
| `GridForest` (C1's prebuilt wood) | 20,518 | 9,318 | 9,318 | 0 |
| `DrivePlaces` (the 4 pre-grid line places) | 21,173 | 9,105 | 0 | 9,105 |
| `Session` (two folders of that name) | 3,559 | 1,538 | 5 | 1,533 |
| `Lobby` (built at boot) | 1,634 | 885 | 0 | 885 |
| `LobbyAssets` (templates) | 452 | 389 | 0 | 389 |
| `Boars` / `HighSeats` / `ForestMarkers` / `Range` / spawn / misc | ~3,500 | ~300 | 272 | ~29 |
| **TOTAL** | **75,008** | **31,437** | **9,596** | **21,841 (69 %)** |

### Where things stand (world AABB of each folder's parts, Edit)

| Thing | x | z |
|---|---|---|
| `Grid.footprint()` | -6700 .. -2210 | -6600 .. -3614 |
| ...+ 300 margin (the keep box) | -7000 .. -1910 | -6900 .. -3314 |
| `GridForest` (C1) | -4475 .. -3387 | -5063 .. -3637 |
| `OurForest` | 2229 .. 3833 | -2896 .. -1297 |
| `Session` (1,420 parts) | -6212 .. 6391 | -6333 .. 6511 |
| `Session` (118 parts) | 831 .. 3664 | 1157 .. 4636 |
| `LobbyAssets` (Trees / Lodge / Truck / heads) | -684 .. 3531 | -2807 .. 1440 |
| `ForestRoadSpawn` (the SpawnLocation) | 3000 | -2109 |
| Lobby field + range, built at boot (`Range.ANCHORS["forest-test"]` 2790,-3090; `shelfFrom` 2850,-2950; `keepOut` 2740,-3060) | ~2400 .. 3700 | ~-3400 .. -2800 |
| `ForestTest.LAYOUTS.road.centre` (a legacy line place) | 3030 | -2097 |
| **Terrain, occupied** | **-7000 .. 7000** | **-7000 .. 7000** |

Terrain lattice (500-stud step over +-10,000): **841 of 1,681 nodes hit**. The keep box is
5,090 x 3,586 = **8.7 %** of the occupied area.

### Other readings
- `Workspace.StreamingEnabled` = **true**, min 384 / target 512. So the far world is **not drawn**
  at a stand; the trim's win is server-side.
- Frame time, camera at C1 stand 8: mean **21.91 ms**, p95 **28.56 ms** (C2 stand 8: 21.04 / 26.02).
- `smoke.sh` PASS: lobby took the player at **+4 s**, gun in hand **+16 s** after the step-on,
  0 stacks, 0 error lines, 12 waves.
- Boot line: `prebuilt forest: STANDS, 2476 model(s) in 1 cell folder(s), dress=false` -- the
  one-cell `GridForest` of task 335. `places: 3 dressed, 3727 planted (9105 parts) ... 1.36s`.

## 4. Facts the design may rely on (measured or read this session, not remembered)

- **Travel from the lobby to a stand is `Match.Body.place` -> `PivotTo`**, not a road drive. The
  truck pads enrol a player; the drive then places him. So **no road corridor between the lobby and
  the grid carries a player**, and the terrain between them is not a travel surface. (If the design
  disagrees, say so and name the code.)
- `Places.TEMPLATE_SOURCES` = `{ "OurForest", "LobbyAssets.Trees", "Session" }` -- **`OurForest` and
  `Session` are the TEMPLATE SOURCES the planter clones from**, found through
  `Places.templates(root)` with `root = Workspace`. Anything that moves them out of `Workspace` must
  keep them findable, or the planter plants nothing.
- `Places.unblockFoliage` sweeps `Places.foliageRoots(root)` over those same folders so leaves stop
  no bullet; the boot reports `1172 leaf part(s) unblocked`.
- `ForestTest.GROUND_IGNORE` = `OurForest, Foliage, Boars, DrivePlaces, GridPlaces, GridForest,
  RangeTargets` -- a ground ray must not stop on our own trunk.
- Three tree folders exist and they are three different things:
  `DrivePlaces` (`Places.FOLDER`, the four line places, rebuilt at every boot),
  `GridPlaces` (`Places.GRID_FOLDER`, destroyed at every boot by design `grid-map.md` 11.3 step 2),
  `GridForest` (`Places.FOREST_FOLDER`, the EDIT-time prebuild that **nothing under `src/` destroys**).
- `Places.PARTS_PER_MODEL` 3.03; `PART_BUDGET_CELL` 8,000; `PART_BUDGET_DRIVE` 22,000.
- `Grid.PLANTED_CELLS` = `{ C1, C2, A2, B1, D1 }`; `Grid.PREVIEW_CELL` = `C1`. Only **C1** is
  actually prebuilt in her place today (task 335).

## 5. What the design must contain

1. The **owner** of "which cell is active" and of the swap, named once (rule 3), and where the
   `docs/design/` table and `GAME_DESIGN.md` owners row change.
2. The **storage container and folder shape**, with the Roblox semantics it relies on **verified or
   cited** -- not written from memory (lesson L-108). Name the page for each claim about
   `ServerStorage`, `Parent = nil`, streaming, or physics/render re-add cost.
3. The **reconciliation**: its inputs, when it runs, and what it does when it finds a cell standing
   that should not be (and the reverse).
4. The **two names** that replace today's single `isPlanted`, and which caller gets which.
5. Whether the swap touches `src/server/Match/` -- it decides the gate (`TWO_PLAYER_PATHS`).
6. The **world trim's** home, its keep set and removal set as regions, and the order of operations
   with the backup.
7. The **proof that dies if the fix is deleted** (L-093): state the case, and state what a reader
   must delete to make it fail.
8. The **numeric targets T1-T6** from the note, adopted or corrected with a reason.

## 6. Open decisions the design must take (the Builder will not)

- D1. Does `DrivePlaces` (the four pre-grid line places, 9,105 parts rebuilt every boot) still get
  built in the `forest-test` world once the grid is the world? If not, what does
  `ForestTest.LAYOUT_ORDER` mean afterwards, and what breaks?
- D2. Do `OurForest` and `Session` move out of `Workspace` (templates kept findable) or stay?
- D3. Is the terrain trim one rectangle or a keep-list of rectangles (grid box + lobby/range box)?
- D4. Does the active cell's wood live in `ServerStorage` as a whole folder, or is it `Parent = nil`?
- D5. Scope: if A and B cannot both be one task (rule 4), say which ships first and what the other's
  task row must say.
