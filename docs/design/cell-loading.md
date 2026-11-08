# Design: cell-loading — one cell stands, the rest is stored, and the land nobody hunts on goes

Task 337. Architect, 2026-11-08.
Brief: `reviews/task-337/BRIEF.md` (the Builder carrying the Director) — read first, and it overrides
anything older. Note: `docs/research/2026-11-08-one-cell-at-a-time.md` (sources, the pattern,
T1–T6).

Karen, 2026-11-08, both DECIDED and not re-opened here:
1. *"so we will need to optimize, we only load one per game thats it"*
2. *"so rest part of map we can remove we can only focus on those what we have from A1 ect /
   outsource also best practicisess"*

This document designs two things and then **splits them into three tasks** (section 14), because
rule 4 is one task per round and the second half is irreversible where the first is not.

---

## 1. What the system must do, and what it must not do

### Must
1. **Exactly one cell's wood stands in `Workspace`.** A planted cell that is not being hunted exists
   on the server, addressable, but is not replicated, not rendered and not in `Workspace`'s spatial
   queries.
2. **Changing the active cell swaps them on the server**, between drives, and the swap's time is
   **measured and printed** (design 11's rule: *printed, not assumed*).
3. **Planting a cell never destroys another cell's wood.** This is a live defect today:
   `Places.dressCell` (`src/server/Places/init.luau`) takes a `keep` set and fells every cell folder
   not in it — *"nil is the one-cell contract this function was born with: every other cell goes"* —
   and `tools/terrainbake.py`'s `PLANT_SEAM` passes only the cells of that run, so
   `plant --cells C1` felled B1, D1, A2, B2 and C2's wood (`reviews/task-335/RESULT.md`, first note).
4. **The guarantee is a RECONCILIATION, not logic inside `plant`/`swap`** (lesson L-029): the desired
   state is *"only the wanted cell is in `Workspace`"*, checked against the world at boot and at
   every drive boundary, so a disagreement however it arose is corrected and reported.
5. **The boot still reads STANDS** (`ForestTest.prebuildVerdict`, `src/server/ForestTest/init.luau`)
   **without re-planting anything.**
6. **Two facts, two names** (lesson L-093): *has a wood of its own* and *is standing now* stop being
   the same question, and the live one reads the world.

### Must not
7. **Must not create or destroy a single model.** The cell loader writes `Parent` on whole cell
   folders and nothing else. Wood is MADE at Edit time by `tools/terrainbake.py plant` driving
   `Places.dressCell`, and MOVED at run time by this system. Two verbs, two modules, one owner.
8. **Must not judge whether a wood is stale.** `ForestTest.prebuildVerdict` is the one judge
   (`PREBUILD.STANDS / ABSENT / REFUSED`); a second epoch reader would be a second answer.
9. **Must not choose which cell is active.** That is `ServerScriptService.ForestTest`'s, already
   (`promote`, `publishLayout`, `layoutForDrive`). This system READS it through a parameter.
10. **Must not be distance-driven.** The selector is the round's cell, one discrete fact already
    decided. A radius rule laid over it is a second, disagreeing answer (note §3).
11. **Must not run in Edit mode.** See §4.3 — an Edit-time write into `ServerStorage` is deleted by
    the next Rojo **Connect**, and it would take the wood with it.

---

## 2. The owner, named once (rule 3)

| Fact | Owner | File |
|---|---|---|
| **Which cell is active** | `ServerScriptService.ForestTest` — unchanged | `src/server/ForestTest/init.luau` (`promote`, `layoutForDrive`, `publishLayout`, `layoutName`) |
| **Which cell's wood is IN `Workspace`** (the swap) | **`ServerScriptService.Places`**, and inside it the one module that writes a cell folder's `Parent`: **`Places.Cells`** | **`src/server/Places/Cells.luau`** (new) |
| A cell folder's CONTENT (clone, seat, destroy its own) | `ServerScriptService.Places` — `Places.dressCell` | `src/server/Places/init.luau` |
| The planting plan | `ReplicatedStorage.Places` (pure) | `src/shared/Places/init.luau` |

**Why a submodule and not a new owner.** The wood's one writer is already
`ServerScriptService.Places` (`src/server/Places/init.luau` header: *"THE ONE WRITER of
`Workspace.DrivePlaces`, and the only thing in this system that touches an Instance at all"*). The
split inside it is by VERB and is disjoint: `dressCell` makes and destroys models in its own cell's
folder; `Cells` moves whole folders and never touches a model. That is the shape `Places.Ground`
(*the only thing that calls `Terrain`*) and `Places.Slice` already have.

**Require direction, one way only:** `Cells` requires `Places` (for `FOREST_FOLDER`,
`GRID_FOLDER`, `cellWoodFolders`, `stats`) and `Grid`. **`Places/init.luau` never requires
`Cells`.** That is not taste: `tools/terrainbake.py`'s `REWRITES["Planter"]` rewrites every
`require` line in `init.luau` for Edit injection and its `selftest` asserts each rewrite matches
exactly once — a new require there would hang the MCP call on `WaitForChild` with no reason given
(the tool's own docstring, refusal path). With the dependency pointing this way the tool is
untouched and `Cells` is never injected.

### Rows for `GAME_DESIGN.md`'s *System owners* table

Amend row 72 (`WHAT STANDS AROUND A DRIVE LINE`) by appending:

```
**SINCE TASK 337 THE WOOD IS MADE AT EDIT TIME AND MOVED AT RUN TIME, AND THE TWO VERBS ARE TWO
MODULES:** `Places.dressCell` is the only thing that clones or destroys a model, and
`Places.Cells` (`src/server/Places/Cells.luau`) is the only thing that writes a cell folder's
`Parent`. `dressCell` no longer fells any cell but the one it is dressing (the `keep` set is
archived, rule 7).
```

And add one row:

```
| **WHICH CELL'S WOOD IS IN `Workspace`** (one cell stands, every other planted cell is stored in `ServerStorage.GridWood`, and the swap at the drive boundary) -- **BUILT (Task 337)** | `ServerScriptService.Places.Cells` is the ONE writer of a cell folder's `Parent`, in both directions, and it creates and destroys nothing. It is LEVEL-TRIGGERED (`Cells.reconcile`): it compares what stands against the ONE cell `ServerScriptService.ForestTest` says is live (`ForestTest.layoutName`, read at `ForestTestBoot`'s composition root and handed in), corrects the difference and prints only when something moved. It never reads an epoch -- `ForestTest.prebuildVerdict` is the one judge of a stale wood -- and it REFUSES to run at Edit time, because `ServerStorage` is Rojo-owned and a Connect would delete what it stored | `src/server/Places/Cells.luau`, wired in `src/server/ForestTestBoot.server.luau` | [cell loading](docs/design/cell-loading.md), [note](docs/research/2026-11-08-one-cell-at-a-time.md) |
```

---

## 3. The world as it is today (measured, not remembered)

Everything in this section is from the BRIEF's §3/§4 (Forest Test, 2026-11-08) or read off the files
named.

- `Workspace`: **75,008 instances / 31,437 parts**; **21,841 parts (69 %)** outside
  `Grid.footprint()`+300.
- **Only C1 is prebuilt.** Boot line: `prebuilt forest: STANDS, 2476 model(s) in 1 cell folder(s),
  dress=false`. `Grid.PLANTED_CELLS` = `{C1, C2, A2, B1, D1}` but the other four woods were felled
  by task 335's plant.
- `prebuild.dress == false` ⇒ `ForestTestBoot` hands `Places.build` an **empty cell list**, so
  `report.gridWoods` and `report.gridPending` are both empty and **the deferred dress at the bottom
  of the boot is already inert in her place**.
- `Workspace.StreamingEnabled` = true, min 384 / target 512 ⇒ the far world is **not drawn** at a
  stand. The win here is server-side: replication, spatial queries, boot work, place size.
- Three tree folders, three different things: `DrivePlaces` (`Places.FOLDER`, rebuilt every boot),
  `GridPlaces` (`Places.GRID_FOLDER`, destroyed every boot by design), `GridForest`
  (`Places.FOREST_FOLDER`, the Edit prebuild that nothing under `src/` destroys).
- A planted tree is anchored scenery: `Places.quieten` sets `part.Anchored = true` on every part
  (*"A PLANTED TREE IS SCENERY AND NOTHING SIMULATES IT"*), and each model carries
  `ModelStreamingMode = Atomic` (`Places.plantOne`). **So a `Parent` move cannot drop, drift or
  half-stream a tree** — both properties are per-instance and survive a re-parent.

---

## 4. The storage container (decision D4), and the Roblox semantics it rests on

### 4.1 D4, decided: a whole folder in `ServerStorage`, created at RUN TIME

`ServerStorage.GridWood`, one child folder per stored cell, each carrying the attribute
`WoodHome` = `"GridForest"` or `"GridPlaces"` (which `Workspace` folder it came out of).

**Not `Parent = nil`.** Three reasons, none of them about garbage collection (which I did not verify
and the design does not need):
1. A parentless folder is reachable only through a Luau table in one module. The store is then
   invisible in Studio's explorer, and `PROJECT_CONTEXT.md`'s lesson is that *a number is not a
   verification* — a reader must be able to LOOK at what is stored.
2. The existing instruments address instances **by path**: `Places.stats(root, folderName)` is
   `root:FindFirstChild(folderName)` and `tools/terrainbake.py`'s `FOREST_ROWS_SEAM` does
   `Workspace:FindFirstChild(name)`. A folder in `ServerStorage` is measurable by both with no new
   instrument (`Places.stats(ServerStorage, "GridWood")` works verbatim — T2 and T9 are free).
3. `ServerStorage` is the one container Roblox documents as **not replicated**, which is exactly
   *stored, not drawn*.

### 4.2 Every engine claim, with the page that carries it (lesson L-108)

| Claim the design uses | Source |
|---|---|
| **`ServerStorage` is "Not Replicated"**: an instance there is on the server, addressable, reaches no client, is not rendered and is not in `Workspace`'s queries; the documented idiom is to keep the map there and move it into `workspace` to make it live | <https://create.roblox.com/docs/reference/engine/classes/ServerStorage> — CC BY 4.0, first-party, maintained; fetched 2026-11-08, 200 (note §2B) |
| **Stream-out parents an instance to `nil` rather than destroying it**, so state survives and it streams back in — i.e. *detach, do not destroy* is the engine's own shape for exactly this | <https://create.roblox.com/docs/workspace/streaming> — CC BY 4.0; fetched 2026-11-08, 200 (note §2A) |
| **Streaming is a CLIENT optimisation; the server holds the whole world** — which is why this task exists at all, and why the trim's win is server-side | same page (note §2A), plus the live reading: streaming on at target 512 and the server still holds 31,437 parts |
| **`ModelStreamingMode = Atomic`** sends the whole model or none of it — already set per model | <https://create.roblox.com/docs/workspace/streaming#model-streaming-modes>, cited in `Places.plantOne` |
| **A `Parent` write is synchronous** in Roblox (no activation handshake to import from Unity) | note §2D |
| **A move is not free: the parts are re-added to the physics and render world on the way back** — so the swap is MEASURED (T7) and not asserted | note §2B |
| **Rojo deletes instances it does not know about inside a container it owns, at the next Connect** — `$ignoreUnknownInstances` defaults to false on every node with a `$path` | <https://rojo.space/docs/v7/project-format/> (Rojo 7.7.0, MIT, pinned in `rokit.toml`), restated in `CLAUDE.md`, *"Rojo DELETES Studio-created instances in Rojo-owned containers"* |
| **Edit time is `IsStudio() and not IsRunning()`** | <https://create.roblox.com/docs/reference/engine/classes/RunService#IsRunning>, the predicate borrowed verbatim from `src/serverstorage/MapGen/Contract.luau` |

### 4.3 The hazard this container has, and the one line that closes it

`default.project.json` maps **all of `ServerStorage`** to `src/serverstorage` with the default
`$ignoreUnknownInstances: false`. So **a `ServerStorage.GridWood` created in EDIT would be deleted
at the next Connect, and 9,318 parts of Karen's wood with it.** `CLAUDE.md` states the rule and the
mechanism; the Rojo page is its source.

Therefore:

- **`Cells.reconcile` refuses at Edit time.** `Cells.editTime()` is
  `RunService:IsStudio() and not RunService:IsRunning()` — `MapGen.Contract`'s predicate, borrowed by
  name (rule 2) — and the refusal is also reachable **by parameter** (`isEdit`) so both arms are
  provable from a spec. A refused call writes nothing and returns `reason = "edit-time"`.
- **No tool drives it.** `tools/terrainbake.py` must not gain a `Cells` module (and cannot: it never
  requires it, §2).
- Consequence, stated: the store exists only inside a running server, so the Edit place stays
  byte-identical, the harness's sync check and script scan are untouched, and a Play session's store
  is discarded with the session. **Nothing is persisted by this system.** The wood persists because
  it is in `Workspace.GridForest`, saved with the place, exactly as today.

### 4.4 What the place file holds, before and after

Unchanged: **every** prebuilt cell's wood lives in `Workspace.GridForest.<cell>` (Studio content,
no Rojo path owns it, rule 7 protects it). The boot moves all but the active cell into the store on
its first reconcile. So the Edit place is where it was, and only the Play session is thinned — which
is the half Karen's "we only load one per game" is about.

---

## 5. The reconciliation

### 5.1 Inputs

| Input | From | Owner |
|---|---|---|
| `want` — the wanted cell id, or nil | `Cells.wantedCell(ForestTest.layoutName())`, handed in by `ForestTestBoot` | `ServerScriptService.ForestTest` |
| `world` — the root to read (`Workspace` by default, a fake in a spec) | parameter | the caller |
| `store` — the store root (`ServerStorage` by default, a fake in a spec) | parameter | the caller |
| `clock`, `isEdit` | parameters (`os.clock`, `Cells.editTime()` when nil) | the caller |

`groundAt` is **not** an input: nothing here measures ground, because nothing here plants.

`Cells.wantedCell(name)` is PURE: the name if `Grid.cellOf(name) ~= nil`, else `Grid.PREVIEW_CELL`.
**The fallback is what makes this change invisible today**: `chosen.name` starts at
`Data.DEFAULT_LAYOUT` (`road`) and the rotation deals the four line places, so without a fallback
the first boot would store C1 and Karen's forest would vanish from the world she plays. When
`ForestTest.LAYOUT_ORDER` becomes the eight cell ids (the 327d switch) the fallback is unreachable,
and §13's case asserts that rather than assuming it.

### 5.2 When it runs

1. **At boot, once**, in `ForestTestBoot`, **after `Places.build`** (which creates/destroys
   `GridPlaces` and may dress the first cell) and **before `Match.start`**.
2. **At every drive boundary**, inside the existing `markers` closure in `Match.start{...}` —
   *"THE DRIVE BOUNDARY IS WHERE A LAYOUT CHANGES, and this closure is the one place that sees it
   BEFORE anybody is placed"* — immediately after `ForestTest.layoutForDrive(...)` and **before**
   `ForestTest.Seats.ensure` / `ForestTest.Markers.build`. So the wood arrives before
   `Match`'s own `applyPlace` teleports anybody into the cell.

That closure is read **once a second while `Waiting`**, which is the point: the reconcile is
level-triggered exactly as `Seats.ensure` is (*"a folder already stamped with this layout costs a
`FindFirstChild` and casts no ray"*). A no-op reconcile is two `FindFirstChild`s and a list compare
(T8), and it **prints nothing** when nothing moved — `layoutForDrive`'s own rule: *"a print every
drive that said nothing had changed would bury the one that did"*.

**No new clock, no new signal, no `PhaseChanged` handler.** An edge handler would be a second place
that decides when wood exists (L-029).

### 5.3 The plan, and every branch of it

`Cells.plan(standing, stored, want)` is **pure** — two lists of `{cell, home, folder, models}` and a
string in, a plan out — so every branch below is reachable from a spec with no world at all.

| What it finds | What it does | Why |
|---|---|---|
| a standing folder whose cell **is** `want` | keeps it; nothing is written | level-triggered: the common case must cost nothing |
| a standing folder whose cell **is not** `want` | **moves it to the store**, stamping `WoodHome` with the folder it came out of | rule 7: moved, never destroyed |
| `want` in the store, not standing | **moves it back to its own home** (`GridForest`, or `GridPlaces` if that is where it came from), creating the home folder if it is missing | restores exactly where it was |
| `want` neither standing nor stored | `reason = "missing"`, nothing written, ONE line printed | a cell with no wood is a fact to report, not to plant: wood is made at Edit time (§1.7). In DEV this is every boot and it is correct |
| `want` is nil or not a cell id | cannot happen through `wantedCell`, which always answers a cell; defensive: `reason = "no-cell"`, nothing written | a nil must not empty the world |
| **two folders with the same cell id** (one per home — a `GridPlaces` dress over a standing `GridForest` prebuild) | keeps the `GridForest` one standing, stores the `GridPlaces` one, appends an anomaly | Karen's Edit wood is the irreplaceable one; a `GridPlaces` cell is reproducible from the seed and that folder is destroyed every boot by design anyway |
| **a store entry colliding on (cell, home)** | appends an anomaly and leaves the standing one alone | an impossible state means two writers; it must be loud, never silently resolved |
| a child of either home that is not a cell folder | untouched | `Places.cellWoodFolders` already answers *"a child that is not one is not touched"*, and `grid.spec` asserts it |

**Order of writes: STORE FIRST, THEN STAND.** This is `Slice.ORDER`'s *destroy before plant*
borrowed by name (`src/server/Places/Slice.luau`): the peak number of cell parts in `Workspace` is
one cell's and never two.

**The domain is both homes** — `Cells.HOMES = { Places.FOREST_FOLDER, Places.GRID_FOLDER }`, read off
the planter, never literals — because a cell's wood can stand in either today and "is C1 standing"
must have exactly one answer.

### 5.4 The report, and the one line

```
[Places.Cells] want=C1 stood=C1 (2476 models) stored=4 cell(s)/9012 models moved=4 in 318 ms
[Places.Cells] want=C2: MISSING -- no wood standing and none stored (plant it: tools/terrainbake.py plant --cells C2)
[Places.Cells] ANOMALY: C1 stands in both GridForest and GridPlaces; kept GridForest, stored GridPlaces
```

Printed only when `moved > 0`, `reason ~= nil` or `#anomalies > 0`. The boot prints its own line
unconditionally once, so a session always says what it started with — and it is printed **after**
the existing `prebuilt forest:` line, so `Places.stats(workspace, Places.FOREST_FOLDER)` is still
read before anything moves (§6).

---

## 6. The boot, in order, and what comes out of it

```
1  prebuiltForest = workspace:FindFirstChild(Places.FOREST_FOLDER)     -- unchanged
2  prebuild = ForestTest.prebuildVerdict(terrain epoch, plantedEpochOf(prebuiltForest))  -- unchanged
3  prebuiltStats = Places.stats(workspace, Places.FOREST_FOLDER)        -- unchanged, BEFORE any move
4  print "prebuilt forest: STANDS, ... dress=false"                     -- unchanged
5  planted = Places.build(...)  with `if prebuild.dress then nil else {}`-- unchanged
6  print "places: ...", "grid: ...", the per-cell "grid wood" lines      -- unchanged
7  Cells.reconcile(Cells.wantedCell(ForestTest.layoutName()), workspace, ServerStorage)   -- NEW
8  print the cells line                                                 -- NEW
...
   Match.start{ markers = function() ... layoutForDrive(); Cells.reconcile(...); Seats.ensure(); Markers.build() end }  -- ONE new call
```

**`prebuildVerdict` is untouched and still reads STANDS without re-planting (BRIEF A).** The
`PlantEpoch` attribute is on the **`GridForest` folder**, not on its cell children, so moving
children out does not disturb it; steps 1–4 run before step 7 anyway.

### 6.1 The deferred boot dress is retired (rule 7: archived with a note)

The `task.spawn` block at the foot of `ForestTestBoot` (`Places.dressPending(planted.gridPending …,
Grid.PLANTED_CELLS)`) plants four cells into `Workspace` whose only possible next action is to be
stored. It is **71.8 s of planting with no product** (task 328i's own measurement) and it
contradicts §1.1.

- It is **already inert in Karen's place** (`prebuild.dress == false` ⇒ empty cell list ⇒ empty
  `gridPending`), so retiring it changes nothing she can see today. That is why it is safe to do in
  the same task.
- `Places.dressPending` itself is **kept** (it is the Edit/one-off door and has a spec), but it loses
  its `keepIds` parameter with `keep` (§7).
- `Places.build` keeps dressing **one** cell — `PLANTED_CELLS[1]`, which is `PREVIEW_CELL`, which is
  the boot's wanted cell — so a world with no prebuild (ABSENT/REFUSED) still stands exactly one
  wood. `report.gridPending` becomes dead and is removed with the block; the archive note names both.

---

## 7. `dressCell` stops felling other cells (the live defect)

Today:

```luau
for _, folder in ipairs(Places.cellWoodFolders(gridFolder)) do
    if folder.Name == cellId or keep == nil or keep[folder.Name] ~= true then   -- fells everything
```

**Decided: the `keep` parameter goes, and `dressCell` destroys only `cellId`'s own folder.**
`dressCells` and `dressPending` lose `keepIds` with it; `tools/terrainbake.py`'s `PLANT_SEAM` loses
its `local keep = {%s}` line and `command_plant`'s `keep = ",".join(...)`; the selftest case that
asserts the seam's text is re-pointed. Archive note under `backups/task-337/` carries the three
removed parameters and the old line verbatim (rule 7).

Why this and not a bigger keep set: a keep set computed per call is what felled the forest
(note §3), and *"a reconciliation cannot"*. With the parameter gone there is no call shape that can
fell a cell the caller did not name — the smaller contract is the fix, not more logic.

What survives unchanged: the second-dress behaviour (`grid.spec`'s *"A SECOND DRESS DESTROYS THE
FIRST ONE'S WOOD BEFORE PLANTING ITS OWN"* re-dresses the SAME cell and stays green), the
destroy-before-plant order, and the one-folder-per-cell invariant.

**Who may destroy wood after this:** only `dressCell`, only its own cell. `Cells` destroys nothing,
ever. `Places.build` still destroys `GridPlaces` wholesale at every boot (design `grid-map.md` 11.3
step 2) — unchanged, and it is why a `GridPlaces` cell is the one the anomaly branch stores rather
than keeps.

---

## 8. The two names that replace `isPlanted` (BRIEF item 4)

`Places.isPlanted` (`src/shared/Places/init.luau`) answers `table.find(Grid.PLANTED_CELLS, …)`.
It becomes two differently-named facts:

| Name | Where | What it answers | Who asks |
|---|---|---|---|
| **`Places.hasOwnWood(cellId)`** (renamed `isPlanted`, body unchanged) | `src/shared/Places/init.luau` — pure, static, reads `Grid.PLANTED_CELLS` | *A wood exists for this cell somewhere — standing or stored.* | `Places.plantCell`'s skirt loop; `Places.cellCapacity`'s skirt bound; `Places.build`'s cell list; the boot's report; `tools/terrainbake.py`'s cell list |
| **`Cells.isStanding(cellId, world?)`** (new) | `src/server/Places/Cells.luau` — reads the world | *This cell's wood is a child of a home folder in `Workspace` NOW.* | `Cells.plan` / `Cells.reconcile`; the boot's line; the specs |

**Which fact each caller wants, said out loud:**

- **The skirt rule** (`plantCell`: *"NOT INTO A NEIGHBOUR THAT IS PLANTED ITSELF"*) and
  **`cellCapacity`** want `hasOwnWood`, and they must: the plan is *a pure function of (cell, seed)*
  and may not read the world, or a cell's wood stops being reproducible from a commit and
  `grid.spec` can no longer assert it with no Studio at all. **This is a rename with no behaviour
  change.**
- **Nothing in `src/` wants the LIVE fact for geometry**, and that is stated so nobody later wires
  it: the live answer is only used to decide what to MOVE, and to print.
- **`Places.standTypeFor` reads neither** (BRIEF item 4 names it): it derives a stand's letter from
  `cellPlanFor`/`zoneAt`/`Grid.towerStands` and never calls `isPlanted`. It is listed here only to
  record that it was checked.

### 8.1 The skirt's real long-run answer, and why it is NOT this task

Under one cell at a time, a neighbour's wood is **never** standing beside the active cell, so the
skirt — which exists *"to dress a cell whose neighbour is bare ground"* — should always be drawn.
That is the defect Karen can already see (`reviews/task-335/RESULT.md`: C1 draws no skirt into B1,
D1 and C2, whose woods were felled, so *"looking across the road out of C1 she will see bare ground
where 328i's reasoning put wood"*).

**Measured cost of switching it on, which is why it is a separate task:** C1's plan is
`t2418 f104 s0` with a **464-site** skirt withdrawn (`grid.spec`'s bent-count note), i.e. ~2,986
plan sites against `Places.CELL_PART_CAP` **2,640** — `grid.spec` case 14 reddens — and at the
measured 3.76 parts/model (9,318 parts for 2,476 models) that is ~11,200 parts against
`PART_BUDGET_CELL` 8,000, which is already breached at 9,318. So the skirt's return needs a density
decision and a re-derived `PARTS_PER_MODEL`, both of which are Karen's picture and the Director's
budget. **Task row for it in §14.**

---

## 9. The public interface

`src/server/Places/Cells.luau`. **No remotes, no events, no client interface, no flag** (§9.3).

```luau
--!strict
export type Wood = {
    cell: string,        -- "C1".."D2"
    home: string,        -- Places.FOREST_FOLDER | Places.GRID_FOLDER
    folder: Instance,
    models: number,      -- #folder:GetChildren(), the one counter Places.stats uses
}

export type Plan = {
    want: string?,
    keep: Wood?,          -- standing and wanted: nothing is written
    stand: Wood?,         -- must come OUT of the store
    store: { Wood },      -- must go INTO the store (in the order given)
    anomalies: { string },
    reason: string?,      -- "edit-time" | "missing" | "no-cell" | nil
}

export type Report = {
    want: string?,
    stood: string?,       -- the cell left standing, or nil
    stoodModels: number,
    storedCells: number,
    storedModels: number,
    moved: number,        -- Parent writes made: 0 is the level-triggered common case
    ms: number,
    anomalies: { string },
    reason: string?,
}

Cells.STORE_NAME: string        -- "GridWood"; the child of ServerStorage
Cells.HOME_ATTRIBUTE: string    -- "WoodHome"
Cells.HOMES: { string }         -- { Places.FOREST_FOLDER, Places.GRID_FOLDER }, read off the planter

-- PURE ------------------------------------------------------------------
function Cells.wantedCell(layoutName: string?): string
function Cells.plan(standing: { Wood }, stored: { Wood }, want: string?): Plan

-- READ-ONLY -------------------------------------------------------------
function Cells.standing(world: Instance?): { Wood }
function Cells.stored(store: Instance?): { Wood }
function Cells.isStanding(cellId: string?, world: Instance?): boolean
function Cells.editTime(): boolean

-- THE ONE WRITER OF A CELL FOLDER'S `Parent` ----------------------------
function Cells.reconcile(
    want: string?,
    world: Instance?,                 -- nil = Workspace
    store: Instance?,                 -- nil = ServerStorage
    clock: (() -> number)?,           -- nil = os.clock
    isEdit: boolean?                  -- nil = Cells.editTime(); a spec drives both arms
): Report

function Cells.line(report: Report): string?   -- the console line, or nil when nothing happened
```

### 9.1 What it reads from and writes to other systems

| Reads / writes | Owner | Through |
|---|---|---|
| **writes** `Parent` of a cell folder, `Workspace.<home>` ⇄ `ServerStorage.GridWood` | **this module** | `Cells.reconcile` |
| **writes** the attribute `WoodHome` on a stored cell folder | **this module** | `Cells.reconcile` |
| **creates** `ServerStorage.GridWood`, and a missing home folder in `Workspace` | **this module** | `Cells.reconcile` |
| **reads** which cell is live | `ServerScriptService.ForestTest` | `ForestTest.layoutName()`, handed in by `ForestTestBoot` |
| **reads** the folder names and the cell-folder rule | `ServerScriptService.Places` | `Places.FOREST_FOLDER`, `GRID_FOLDER`, `cellWoodFolders` |
| **reads** whether a string is a cell, and the fallback cell | `ReplicatedStorage.Grid` (frozen data) | `Grid.cellOf`, `Grid.PREVIEW_CELL` |
| **reads** the model count | `ServerScriptService.Places` | `Places.stats(root, name)` |
| **is read by** the ground readers' ignore list | `ServerScriptService.ForestTest` | `ForestTest.GROUND_IGNORE` already carries both home names — **no change** |
| **touched by** nothing else. No `Terrain`, no `Random`, no `Player`, no remote, no `CollectionService` | | |

### 9.2 The gate (BRIEF item 5)

Files task A touches: `src/server/Places/Cells.luau` (new), `src/server/Places/init.luau`,
`src/shared/Places/init.luau`, `src/server/ForestTestBoot.server.luau`,
`tests/server/grid.spec.luau`, `tools/terrainbake.py`.

**None of them is in `TWO_PLAYER_PATHS`** (`tools/agents.py`: `src/server/Match/`,
`src/server/MatchBoot.server.luau`, `src/client/Match/`, `src/client/MatchBoot.client.luau`,
`src/shared/Drive/`, `tests/client/Role.luau`, the named match/tie specs, and the range's solo
picture). **The swap does not touch `src/server/Match/`**: it is called from
`ForestTestBoot`'s `markers` closure, which is the composition root's, not the match's.

⇒ **one-player gate.** `test2` is N/A with that reason. `--scope auto` resolves through
`BLAST_RADIUS` to `places` + `match` (+ `map` for `tools/terrainbake.py`) for a review round; the PR
to `main` needs the full `scope=all` run.

### 9.3 No feature flag, and why

`docs/design/feature-flags.md` governs a **feel-critical path**. This changes no number Karen judges:
the reconcile's answer on her place today is *C1 stands, nothing stored, nothing moved* — bit for
bit the world she has. The one behaviour that could surprise her (a second cell's wood disappearing
from `Workspace`) cannot occur until a second cell is prebuilt (task 336). `Flags.MAX_FLAGS` is 24
and the table holds 24, so a row would also have to retire somebody else's. The rollback is the
revert of one require and one call.

### 9.4 D6, taken: the Director can force a CELL while `GRID_PREVIEW` is on

Today `ForestTestBoot` passes `if gridPreviewOn then Grid.PREVIEW_CELL else
ServerStorage:GetAttribute(Data.LAYOUT_OVERRIDE_ATTRIBUTE)` — so with the preview on (which is how
Karen's place is set: `tools/terrainbake.py` refusal 7 names `GRID_PREVIEW` as one of the two
overrides she has set on purpose) **the cell is pinned to C1 and no swap can ever be driven**. A
system that cannot be exercised in the only place it can be measured is not buildable as designed.

Decided: while the preview is on, a `DHForestLayout` that names a **cell** wins; anything else is
ignored exactly as today.

```luau
local forced = ForestTest.forcedLayout(ServerStorage:GetAttribute(Data.LAYOUT_OVERRIDE_ATTRIBUTE))
ForestTest.layoutForDrive(
    Match.driveNumber(),
    if gridPreviewOn
        then (if Grid.cellOf(forced) ~= nil then forced else Grid.PREVIEW_CELL)
        else ServerStorage:GetAttribute(Data.LAYOUT_OVERRIDE_ATTRIBUTE)
)
```

The reason the old line exists is preserved: a LINE PLACE forced while the preview is on would still
be two answers to *which place is live*, and is still ignored. `ForestTest.forcedLayout` already
returns a cell id in its own spelling (task 327b), so no parsing is added.

---

## 10. The world trim (B)

### 10.1 Where it lives: `tools/terrainbake.py trim` (decision)

Not a `src/` boot step. Three reasons, in order of weight:

1. **Terrain outside the grid cannot be re-created by a boot step.** It is Studio content Karen
   bought; a boot that deletes it deletes it on every session with no backup and no diff.
2. **The refusal ladder already exists there and must not be written twice.** `terrainbake.py`
   refuses: not Edit mode, wrong place id (re-asked before *every* mutating call), a dirty tree, a
   Studio copy that differs from disk, no fresh `--backup .rbxl` outside the repo, a live flag/pose
   override (with the declared `--keep-flags` exception). A second tool would be a second copy of
   those, and *"two correct pieces of code disagreeing"* is what `PROJECT_CONTEXT.md` names as the
   killer.
3. **It is a SECOND DRIVER of one writer, not a second writer** — the precedent this tool already
   set with `plant` driving `Places.dressCell` (design 10.2) and with `archive … --backup` moving
   `GridForest` out by `Parent` only.

### 10.2 The keep set, by region and by instance count

| Keep box | Rectangle | Why it is kept | Parts kept |
|---|---|---|---|
| **K1 — the grid** | `TerrainBake.regionFor(Grid.cellIds())` = `Grid.footprint()` grown by `Relief.BLEND_STUDS 200 + 230 + Grid.maxBendStuds() 60` = **x[-7190..-1720] z[-7090..-3124]** | **The trim keeps exactly what the bake writes**, computed from the same function, never typed. A narrower box would be re-created by the next bake's blur, so the two tools could disagree | `GridForest` 9,318 + 272 markers/seats |
| **K2 — the lobby, the spawn, the range and the wood you see from them** | **x[2200..3900] z[-3500..-1250]** | It contains `Lobby` (885 parts), `LobbyAssets`' built output, `Range.ANCHORS["forest-test"]` (2790,-3090), `shelfFrom` (2850,-2950), `keepOut` (2740,-3060), **`ForestRoadSpawn` the SpawnLocation (3000,-2109)**, the `road` layout (centre 3030,-2097) and the `edge` layout (3400,-3250) — **and `OurForest` (2229..3833, -2896..-1297), all 9,901 parts of it** | 885 + 9,901 + ~51 |

**`OurForest` is kept, and that is a correction to the note's keep set.** Two pieces of evidence:
it is a **template source** (`Places.TEMPLATE_SOURCES = { "OurForest", "LobbyAssets.Trees",
"Session" }`, found through `Places.templates(root)` with `root = Workspace` — remove it and the
planter plants nothing, so no cell can ever be re-planted), and the **SpawnLocation stands inside
its box**: Karen spawns in it and the lobby abuts it at z ≈ -2900 (`Places.PLANS.edge`'s own
measurement: *"THE FAR FOREST IS THIS WORLD'S REAL WOOD (its southern face is at z -2900…)"*).
Removing it would put the lobby and the spawn in a bare field — a visible regression, and the end of
re-planting.

### 10.3 The removal set, by region and by count — and the honest finding about the parts half

| What | Parts | How it is removed |
|---|---|---|
| **`DrivePlaces`** (the four line places) | **9,105** | **By code, not by the tool, and no archive is needed: it is rebuilt from the seed at every boot.** `Places.build`'s loop is `for _, name in ipairs(Forest.LAYOUT_ORDER)` and both the paint and the plant are guarded by `Forest.layoutNamed(name) ~= nil`, which is **nil for a cell id** — so the moment `LAYOUT_ORDER` is the eight cell ids, the loop plants and paints nothing, `DrivePlaces` is created empty, and **not one line changes** (decision D1, §13) |
| **Terrain outside K1 ∪ K2** | 841 of 1,681 lattice nodes occupied; K1+K2 is ~10.5 % of the occupied area | `trim`, Air fills, §10.4. **Irreversible except by the place backup** |
| `Session` (1,533 parts outside), `LobbyAssets` (≤389 outside) | ~1,922 | **NOT removed.** Both are template sources, and `Places.pickTemplate`/`Places.nearestScale` choose a template **by its own scale among every instance of that name**; thinning them changes which instance is the template, which `Places.rescaledReason` then quarantines (*"template-rescaled"*) — and a quarantined name **plants nothing**. Thinning them is a task with a re-measurement of `Places.TEMPLATE_DIMS` (`tools/forest_ground.py dims --write`) in it |
| `Boars` / `HighSeats` / `ForestMarkers` / `Range` (~29 parts outside) | ~29 | Built at run time by their own owners; nothing to archive |

**So the parts half of the trim moves nothing, and the archive container is not needed.** Every part
outside the keep boxes is either rebuilt by code each boot or a template source that must stay
findable in `Workspace`. The archive-first rule (rule 7) is unchanged and is stated in the tool for
the day something qualifies: **a part is MOVED into `Workspace.Archive337` with a note, never
destroyed** — and it is `Workspace` because every non-`Workspace` container the place has is
Rojo-owned and would be cleared at the next Connect (§4.3). That is also why archiving a part buys
nothing today, and the design says so rather than shipping a container with nothing in it.

### 10.4 The terrain half: order of operations, with the backup

Terrain cannot be moved, so **the backup is a precondition of this half and of this half alone**.

```
0  REFUSALS (all of terrainbake's, plus the two below)
1  python tools/terrainbake.py trim plan                  # READ-ONLY. Prints: K1 and K2 as rectangles,
                                                          # the complement as a rectangle list, the block
                                                          # list at the chosen size, the estimated calls,
                                                          # and the 500-stud lattice census BEFORE
2  a fresh --backup <f>.rbxl OUTSIDE the repo, > 0 bytes, `<roblox!`, within BACKUP_MAX_AGE_HOURS
3  python tools/terrainbake.py trim --backup <f>.rbxl --blocks 1    # ONE block, timed. The size of the
                                                          # next step is chosen from THIS reading and
                                                          # never from an estimate
4  python tools/terrainbake.py trim --backup <f>.rbxl --blocks N    # resumable: an Air write over Air is
                                                          # a no-op, and the lattice says what is left
5  python tools/terrainbake.py trim plan                  # the AFTER census: T4 is 0 lattice hits outside
                                                          # K1 u K2, measured with the SAME instrument
```

**Two refusals this command adds, both of them teeth:**

- **Refuse unless every name in `ForestTest.LAYOUT_ORDER` is a cell id.** `ride` (4900,-4540) and
  `track` (4700,-3900) stand **outside K2**, so trimming while the rotation can still deal them
  would hold a drive over a void. This is the one precondition that makes the terrain half wait for
  the switch (§14), and it is a line of code rather than a sentence in a document.
- **Refuse unless the keep list covers `TerrainBake.regionFor(Grid.cellIds())` and K2.** A keep list
  that does not contain the grid is a typo that deletes the game.

**Why Air fills and not `Terrain:Clear()`:** `Clear` takes the keep boxes with it — Karen's lobby
lawn, the baked grid and the ground under `OurForest`'s 9,901 trees (terrain removed under standing
wood is trees hanging in the air, the exact defect `prebuildVerdict` exists to catch). The removal
is therefore the complement of the keep boxes, decomposed into rectangles and written as Air in
blocks.

**Why the block size is measured and not written here:** `TerrainBake.TILE_STUDS` 128 and
`MAX_VOXELS` 24,576 are `WriteVoxels`' own measured ceilings, and the whole world at that tile is
~11,900 tiles — at the bake's measured 0.8 s/tile that is hours. An Air fill is a different call
with different limits, and **I did not verify them**, so step 3 measures one block before step 4
commits to a size. That is this tool's own ladder (`plan` → `measure`/`diff` → the run), not a new
idea.

---

## 11. The proof that dies if the fix is deleted (BRIEF item 7, lesson L-093)

For each of the four producers, the case and **what a reader must delete to redden it**:

1. **`dressCell` no longer fells another cell.**
   Case: a fake `GridForest` holds C2's wood (planted by the real `dressCell`); `dressCell("C1", …)`
   is called; assert C2's folder is the **same Instance**, with the **same model count**, and
   `report.destroyed == 0`.
   *Dies if:* the `keep == nil` arm is restored (C2 is felled ⇒ count 0 ⇒ red), or `keep` is
   re-added and defaulted to `nil` (same).
2. **The reconcile is level-triggered and moves, never destroys.**
   Case: fake world with C1 and C2 standing, empty fake store, `want = "C1"` ⇒ exactly one cell
   folder in the world, named C1; exactly one in the store, named C2, with its **model count
   unchanged** and its first model's `:IsDescendantOf(store)` true. Then `want = "C2"` ⇒ the two
   swap, both counts still unchanged, `moved == 2`. Then call again with the same `want` ⇒
   `moved == 0` and no line.
   *Dies if:* the store branch calls `Destroy` (count 0 ⇒ red); the reconcile is made edge-triggered
   by returning early when `want` has not changed (the second call's assertions go red); the
   store-before-stand order is swapped (a third assertion counts the world's children **between**
   the two writes through an injected `clock` tick and reads 2).
3. **The two names answer differently in a world where the facts differ.**
   Case: C2's wood is in the store; assert `Plan.hasOwnWood("C2") == true` **and**
   `Cells.isStanding("C2", fakeWorld) == false`, and for C1 both true.
   *Dies if:* `isStanding` is re-implemented off `Grid.PLANTED_CELLS` (the exact defect task 335's
   verdict names) — the first pair then reads `true, true` ⇒ red.
4. **The Edit-mode refusal.**
   Case: `reconcile(want, world, store, clock, true)` returns `reason == "edit-time"`,
   `moved == 0`, and the store folder **was not created**.
   *Dies if:* the guard is removed (the store appears ⇒ red), or `isEdit` stops being a parameter
   (the case cannot be written at all, which is why it is a parameter).

Two more that are tripwires and are **not** offered as proofs: the `wantedCell` fallback case (it
asserts a constant until `LAYOUT_ORDER` changes) and the model-count equality after a round trip
(both sides move together unless the row hash is read — which is why T9 exists).

---

## 12. Numeric targets

| # | Target | Status | Why that number | Instrument |
|---|---|---|---|---|
| T1 | A non-active cell contributes **0** parts to `Workspace` | **adopted** | *"we only load one per game thats it"* | `337-census.luau`: `Workspace` holds exactly one cell folder across both homes |
| T2 | Planting cell X leaves cell Y's stored wood with **the same model count** | **adopted** | task 335's keep-set destroy | count Y before/after; `Places.stats(ServerStorage, "GridWood")` |
| T3 | Parts outside K1(+300) ∪ K2 after the trim: **≤ 1,950**, and **every one a template-source instance**; total `Workspace` parts **31,437 → ≤ 22,400** | **CORRECTED** from *"≤ 1,400"* | 1,400 came from a keep set of 1,288 that did **not** include `OurForest`, which §10.2 proves must be kept (template source + the spawn's surroundings). What is actually removable is `DrivePlaces` 9,105; `Session` 1,533 + `LobbyAssets` ≤389 stay, because thinning them re-rolls `Places.pickTemplate`'s answer | `337-census.luau`, the same instrument as the before |
| T4 | Terrain outside K1 ∪ K2: **0 lattice hits** | **adopted**, with K1 = `TerrainBake.regionFor(Grid.cellIds())` (footprint + 490, the bake's own region) and K2 named in §10.2 | the trim either happened or it did not | `337-terrain.luau`, the same 500-stud lattice |
| T5 | Boot to lobby, and join-to-gun: **no worse** than +4 s / +16 s, 0 stacks, 0 error lines | **adopted** | the trim must not cost what it saves | `smoke.sh`, same script |
| T6 | Frame time at C1 stand 8: **no worse** than 21.91 ms mean / 28.56 ms p95 | **adopted as a BOUND, not a win** | with streaming on, a part 6,000 studs away is not on the client; `PART_BUDGET_CELL` is the dial that moves this and it is a different task | `337-frametime.luau`, same stations |
| **T7** | **One swap (store + stand) of a 2,476-model cell: ≤ 500 ms server time, printed** | **new** | `Places.plantOne` measures ~0.45 ms per model (200 models in 0.09 s, `Slice.BUDGET_MS`'s own derivation), so a re-plant of this cell is ~1.11 s. A move clones nothing, casts no ray and scales nothing, so half of that is the first honest ceiling — **to be corrected by the first reading, not defended** | `Cells.reconcile`'s own `ms`, on the boot line and the swap line |
| **T8** | **A no-op reconcile: `moved == 0`, 0 writes, ≤ 1 ms** | **new** | it runs ~1 Hz from the `markers` closure while `Waiting`; `Seats.ensure`'s own standard (*"costs a `FindFirstChild` and casts no ray"*) | the spec asserts `moved == 0` and `Cells.line(report) == nil`; `ms` on the live line |
| **T9** | **Round-trip identity: a stored cell's `rowHash` is unchanged after store → stand** | **new** | T2 counts models; a hash catches a moved tree. The instrument exists: `tools/terrainbake.py`'s `FOREST_ROWS_SEAM` (name + pivot to 1/100 stud + scale + yaw + band, sorted, FNV-1a) | `terrainbake.py rows --cells C1`, and the same expression in a Play probe (328g's `rows` route) |

If T7 is missed, the **named fallback** is a per-model move in `Slice` bites, with
`Slice.ORDER` gaining `store = 1, stand = 2` (store before stand, so the peak is one cell's parts).
It changes the SHAPE and not the owner, and a single `Parent` write on a folder cannot be sliced —
which is why the whole-folder move is the primary and the slice is the fallback.

---

## 13. The open decisions, taken

- **D1 — does `DrivePlaces` still get built once the grid is the world? NO, and it needs no new
  mechanism.** `Places.build`'s loop runs over `Forest.LAYOUT_ORDER` and both of its bodies are
  guarded by `Forest.layoutNamed(name) ~= nil`, which is nil for a cell id (`ForestTest.LAYOUTS`
  holds only the four line places; the cell fallback lives in `ForestTest.layoutOf`, which `build`
  does not call). So when `LAYOUT_ORDER` becomes the eight cell ids, 9,105 parts and 1.36 s stop
  being built and **not one line of `Places.build` changes**. What `LAYOUT_ORDER` means afterwards
  is what it already means — **the rotation**: `ForestTest.nextLayout` walks it, and it becomes the
  list of cells a session deals, which is the input to `Cells.wantedCell`. What breaks if it is
  changed carelessly: `ForestTest.LAYOUTS`' four rows and `Places.PLANS`/`SURFACES` become dead data
  (keep them, rule 7 — `grid-map.md` D-4 already says the four places are superseded, not deleted),
  and `Places.capacity`'s line-place arm keeps its spec. **Not part of task 337**: it is the 327d
  switch's one row.
- **D2 — do `OurForest` and `Session` move out of `Workspace`? NO.** §10.2: template sources found
  through `Places.templates(Workspace)`, the spawn stands inside `OurForest`, and `ServerStorage` —
  the only non-replicated container — is Rojo-owned, so moving them there would have Rojo delete
  24,192 instances of Karen's wood at the next Connect (`CLAUDE.md`, Rojo project format).
- **D3 — one rectangle or a keep-list? A KEEP-LIST OF TWO RECTANGLES**, K1 (the grid, computed from
  `TerrainBake.regionFor`) and K2 (the lobby/spawn/range/`OurForest` box). One rectangle cannot
  contain both without keeping almost everything between them.
- **D4 — `ServerStorage` folder or `Parent = nil`? A WHOLE FOLDER IN `ServerStorage`**
  (`ServerStorage.GridWood`), created at RUN TIME only, with the Edit-mode refusal that makes that
  safe. §4.
- **D5 — scope.** §14.
- **D6 — a forced CELL beats the preview.** §9.4. Without it the swap cannot be driven in the only
  place it can be measured.

---

## 14. Scope: three tasks, in this order (rule 4)

**A and B cannot be one task.** A is `src/` with a spec and is reversible by a revert; B's terrain
half is an irreversible Studio operation whose only rollback is a 29 MB backup file, it needs ~hours
of MCP calls, and it is **blocked on the rotation no longer dealing `ride`/`track`**.

| Task | What it is | Gate | Blocked on |
|---|---|---|---|
| **337** | **Cell loading.** `Places/Cells.luau`; `dressCell` loses `keep` (and `dressCells`/`dressPending` lose `keepIds`, and the tool's `PLANT_SEAM` its keep line); `isPlanted` → `hasOwnWood`; the boot's reconcile at boot and at the drive boundary; the deferred dress retired and archived; D6's one line; the `grid.spec` cases of §11 | one-player `test`; `test2` N/A (no `TWO_PLAYER_PATHS` path). Live claims need Karen's FT and the Director's `DHForestLayout` | nothing |
| **337b** | **The world trim.** `tools/terrainbake.py trim` + its two new refusals; the terrain half run in her place behind a fresh backup; T3/T4 measured before and after with the task-337 instruments | one-player `test` for the tool (`tools/terrainbake.py` → scope `map`); the run itself is a place operation with a `[trim] OK:` line | **the rotation holding no line place** (the 327d switch, or a Director decision reducing `LAYOUT_ORDER`), and a fresh `.rbxl` backup |
| **337c** | **The skirt comes back, and the cell budget with it.** §8.1: under one-cell-at-a-time a neighbour is never standing, so every cell should skirt — +464 sites on C1, past `CELL_PART_CAP` 2,640 and ~11,200 parts against `PART_BUDGET_CELL` 8,000. Needs a re-derived `Places.PARTS_PER_MODEL` (measured 3.76 against the frozen 3.03) and Karen's look | one-player `test` | 337, and the Director's budget decision |

**Task 336's row must say** (it is referenced in TASKS.md row 335 but has no row yet): *re-plant
B1, D1, A2, C2 (and B2/D2 if their landform is released) with `tools/terrainbake.py plant --cells …
--backup <fresh>.rbxl` — **after task 337**, because until `dressCell` stops felling, a plant of one
cell fells the others, and because after 337 every planted cell but the active one is stored at the
next boot. Until 336 runs there is nothing for the swap to swap to: 337's live proof is therefore
the C1 round trip (store C1, stand C1 again), and the two-cell swap is 336's own measurement.*

---

## 15. How it is tested

### Server spec — `tests/server/grid.spec.luau` (scope `places`; it already requires `Planter`)

New `describe("one cell at a time")`, requiring `Cells` the way the file already requires its
siblings: `require(ServerScriptService.Places:WaitForChild("Cells"))`.

1. **`plan` is pure and every branch is named** — standing {C1,C2} / stored {} / want C1; the
   reverse; want in neither (`"missing"`); want nil (`"no-cell"`); the double-wood anomaly; a
   non-cell child ignored. No Instance work beyond two `Folder`s.
2. **`reconcile` over FAKES** — a `Folder` as `world` and a `Folder` as `store`, never `Workspace`
   and never `ServerStorage`, which is `Places.build`'s own discipline (*"a spec hands in a fake …
   so no spec in the DEV place can write DEV's terrain, ever"*). The four assertions of §11.2.
3. **The two names disagree** (§11.3).
4. **`dressCell` never fells another cell** (§11.1) — driven through the real `dressCell` with
   `grid.spec`'s existing `hillside` reader and `fake(name)` template factory.
5. **The Edit refusal, by parameter** (§11.4).
6. **`wantedCell`** — a cell id → itself; `"road"` → `Grid.PREVIEW_CELL`; nil → `Grid.PREVIEW_CELL`;
   plus the tripwire that flips when `ForestTest.LAYOUT_ORDER` becomes cells.
7. **T8** — a second reconcile with the same `want` writes nothing and `Cells.line` is nil.

Existing cases that must stay green and are the regression net: `grid.spec`'s dressed-cell case
(second dress destroys its own wood), the `dressCells`/`dressPending` cases, and
`grid_ground.spec`'s folder-name assertions (`FOREST_FOLDER`, `GRID_FOLDER`, `GROUND_IGNORE`).

### Client spec — none, and the reason

No client file reads a cell folder: the client reads one string (`ReplicatedStorage.ForestTest.Live`
`Layout`) and draws from `Grid` data (`Hud.MapUi.geometryFor`). `grep` for `FOREST_FOLDER` /
`GRID_FOLDER` / `GridForest` across `src/` returns server and shared files only. Nothing on the
client changes, so a client spec would assert a constant.

### Harness, and what it cannot do yet (TASKS.md 6–7)

- `python tools/studio_mcp.py test` — the one-player line, `scope=all` for the PR. In **DEV** the
  whole path is a loud no-op (no templates, `GRID_PREVIEW` off, no `GridForest`), so the harness
  proves the specs and the no-op, **not the swap**.
- **The swap can only be measured in Karen's Forest Test**, and the harness cannot drive a
  cell change there: `DHForestLayout` is a `ServerStorage` attribute set in Edit (the Director's
  route, D6), and the input-scenario file (`tests/client/input_scenarios.txt`) can replay keys and
  mouse, not a server attribute. So the live claims are the Director's runs, each with its line:
  1. boot: `[Places.Cells] want=C1 stood=C1 (2476 models) stored=0 moved=0 in <n> ms` — T1, T8.
  2. force `DHForestLayout = C2` (a cell with no wood yet): `want=C2: MISSING`, C1 stored, **T7's
     store half** timed, `Workspace` holds **no** cell folder (T1 at its extreme).
  3. clear it, next drive: C1 comes back out of the store — **T7's stand half**, and
     `terrainbake.py rows --cells C1` reads the **same `rowHash`** (T9).
  4. `smoke.sh` (T5) and `337-frametime.luau` at C1 stand 8 (T6) at the code commit.
- **Rule 5:** the only visual claim this task makes is *"C1 looks exactly as it did"*. One frame
  from C1 stand 8 before and after, same camera, opened and described — and after step 2, one frame
  of the cell with its wood stored, which must show bare ground and no half-removed trees.

### What the specs cannot prove, said now

The Parent-move cost (T7), the replication behaviour at the swap, and that no client sees a
half-moved cell. All three need a running server with wood in it; all three are the Director's live
runs above. The design's defence is that the swap happens at the `Assigning` edge, while every
player is still held in the results scene at the lodge ~6,000 studs away (`Match.Scene`,
`Lobby.gatherSpot`), so at the instant of the swap no client has either cell streamed in.

---

## 16. Sources (rule 1 and rule 2 — what is borrowed, and from where)

External (all re-stated from the note, which fetched each on 2026-11-08):

1. **Roblox — Instance streaming.** <https://create.roblox.com/docs/workspace/streaming>,
   <https://create.roblox.com/docs/reference/engine/classes/Workspace#StreamingEnabled> — **CC BY
   4.0** (`Roblox/creator-docs`), first-party, maintained. *Good:* the engine's own answer, already
   on in this place, and its stream-out **detaches rather than destroys** — the exact shape this task
   wants. *Bad:* it is a **client** optimisation only; it says nothing about what the server keeps,
   and measured here the server still holds 31,437 parts with streaming on. **Adopted:**
   detach-not-destroy. **Rejected:** streaming as the mechanism.
2. **Roblox — ServerStorage.**
   <https://create.roblox.com/docs/reference/engine/classes/ServerStorage> — same licence,
   maintained. *Good:* documented **"Not Replicated"**; the documented idiom is keep-there,
   move-to-`workspace`. *Bad:* it is storage, not a system — no reconciliation, no cost accounting,
   and the move is not free. **Adopted:** the container. **Written here:** the reconciliation.
3. **Rojo — project format (`$ignoreUnknownInstances`).**
   <https://rojo.space/docs/v7/project-format/> — Rojo **MIT**, 7.7.0 pinned in `rokit.toml`,
   maintained. *Good:* it states plainly that a container with a `$path` deletes what it does not
   know. *Bad:* the deletion happens at **Connect**, not during live sync, so a Studio-made instance
   can look safe for a whole session. **Adopted:** the Edit-time refusal that makes the
   `ServerStorage` store safe. This source is the reason D4 has a guard at all.
4. **Unreal Engine 5 — World Partition.**
   <https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition-in-unreal-engine> —
   Epic, proprietary, free to read, maintained. *Good:* the pattern and the vocabulary — one
   persistent level, streamable **cells**, loaded/unloaded at runtime, and the **world** owns which
   are loaded while the cell knows nothing about who asked. *Bad:* distance-driven and continuous.
   **Adopted:** cell / load / unload and the owner split. **Rejected:** the streaming source.
5. **Unity — additive scene load/unload.**
   <https://docs.unity3d.com/ScriptReference/SceneManagement.SceneManager.LoadScene.html>,
   <https://docs.unity3d.com/Packages/com.unity.addressables@2.0/api/UnityEngine.AddressableAssets.Addressables.UnloadSceneAsync.html>
   — Unity, proprietary, maintained. *Good:* the explicit load/unload **pair** as an interface shape.
   *Bad:* `UnloadSceneAsync` **destroys** every object, so Unity must re-create content on the way
   back, and `LoadSceneAsync` carries an activation handshake we have no equivalent of. **Adopted:**
   the pair (`stand`/`store`). **Refuted by (1) and (2):** destroy-on-unload.
6. **Minecraft — chunks.** <https://minecraft.wiki/w/Chunk> — **CC BY-NC-SA 3.0**,
   community-maintained, active (already borrowed by `docs/design/drive-places.md` 10.1). *Good:*
   the **server** keeps only what is being played — the half Roblox streaming does not do — and a
   chunk's content is a pure function of seed and coordinates, which is `Grid.seedFor` here. *Bad:*
   its loaded set is a radius around every player plus always-loaded spawn chunks — answers to a
   continuous, many-player, infinite world. **Adopted:** both rules. **Rejected:** the radius.

Borrowed inside this repo (rule 2, named so nobody re-invents it):

- `src/serverstorage/MapGen/Contract.luau` — the edit-time predicate
  `IsStudio() and not IsRunning()`, with its doc link.
- `src/server/Places/Slice.luau` — `ORDER`'s *destroy before plant*, re-used as *store before
  stand*, and `MapGen`'s step split behind it.
- `src/server/ForestTest/Seats.luau` (`Seats.ensure`) — the level-triggered call inside the
  `markers` closure, and its *"ONE call site, level-triggered, cannot be missed, cannot fire twice
  and cannot be ordered wrongly"*.
- `tools/terrainbake.py` — the refusal ladder, the `plan → measure → run` ladder, the
  `--backup` precondition, and `FOREST_ROWS_SEAM`'s row hash (T9's instrument).
- `Places.stats(world, folderName)` — one counter for three folders, now four.

**Invented, with the reason (rule 2):** nothing in the mechanism. One thing is ours because no
source has it — **the selector is the round's cell, not a distance** — and the reason is rule 3: the
drive already names a cell, and a distance rule laid over it would be a second answer to a decided
question.

---

## 17. Open decisions that need Karen (feel) or the Director (scope)

**Karen (feel / look):**
- **K-1.** After 337b the ground outside the grid and the lobby box is **gone**, which includes the
  land under the old `ride` and `track` places and everything she can see looking away from the
  lobby. Her sentence authorises it; she has not seen it. One frame from the lobby looking away, and
  one from a C1 stand looking out of the grid, before and after.
- **K-2.** `OurForest` — the wood around her spawn and the lodge — **stays** (it is also the template
  source). Confirm that is what *"we can only focus on those what we have from A1"* meant, because
  the alternative (removing it) ends re-planting.
- **K-3.** §8.1: with one cell at a time, should a cell skirt into its bare neighbours again? Today
  she sees bare ground across C1's roads. It costs the cell's part budget (337c).

**Director (scope):**
- **D-1.** The shipping order of §14, and in particular that **337b waits for the rotation to hold
  no line place** (the 327d switch or a reduced `LAYOUT_ORDER`). The refusal enforces it; the
  decision of when is the Director's.
- **D-2.** Task 336 (re-plant the felled cells) runs **after** 337, and it is what gives the swap a
  second cell. Until then the live proof is the C1 round trip.
- **D-3.** 337b's terrain run is hours of MCP calls and is reversible only by a backup file. Worth
  it before v1, or after?
- **D-4.** `GRID_PREVIEW` expires **2026-11-22** (`src/shared/Flags/init.luau`). Three of this
  design's call sites sit beside it and D6 changes its one forcing line; the flag's retirement (or
  the 327d switch that retires it) is the Director's.

---

## 18. Not verified

- **The cost of a `Parent` move of a 9,318-part subtree in and out of `Workspace`.** The note's
  reading that *"the parts are re-added to the physics and render world on the way back"* is the
  engine's documented shape, not a number. T7 is a derived ceiling to be corrected by the first
  measurement, and the slice fallback is named for the case it is missed.
- **`Terrain:FillBlock`'s per-call limits and cost.** `TerrainBake.MAX_VOXELS` 24,576 is
  `WriteVoxels`' measured ceiling and does not transfer. 337b's step 3 measures one block before any
  size is chosen; nothing in this document asserts a trim duration.
- **Whether a parentless instance is garbage-collected.** Not checked, and the design is written so
  that it does not matter (D4 is argued from visibility, addressability and Rojo, not from GC).
- **Replication behaviour at the instant of a swap** with a client near either cell. The design
  avoids the case (the swap happens while everyone is held at the lodge) rather than measuring it.
- **The exact part counts of `LobbyAssets` and `Session` outside K2.** The BRIEF gives their AABBs
  and totals (389 and 1,538), not the split, so T3's ≤1,950 carries both wholly outside. The
  `337-census.luau` run that measures T3 will narrow it; nothing depends on the split.
- **Anything about Karen's place that needs Studio.** No Studio was available to this run
  (`.agent-evidence/INDEX.md`): every number here is from the BRIEF's measured tables or read off
  the files and symbols named.
