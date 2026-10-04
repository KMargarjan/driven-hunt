# Design: map-generator (v4 — one forest, four drive blocks, block 1 built)

System: `map-generator` — the Luau that writes the world (terrain, the forest roads, the wood, the
stands and every gameplay marker) into the DEV place at **edit time**, plus the tool that invokes it.

**Task 121: a revision of v3 against `reviews/task-121/BRIEF.md`** (the Director, carrying Karen's
decisions of 2026-10-04). The brief overrides anything older in `docs/`, `TASKS.md` and v3. v3 is
superseded **in full** by this file and stays in git history (rule 7). This is a revision of the same
system: no new system, no new owner, no module moves out of `ServerStorage.MapGen`.

Architect, 2026-10-04, read-only session: Read, Grep, Glob only. **No Studio, no network, no engine.**
Evidence precomputed in `.agent-evidence/` (`INDEX.md`), commit
`f2fdffb5587dac7887578712b90410d834e22d63`. Every claim about existing code names a **file and a
symbol**, never a line number.

Inputs, in precedence order: `reviews/task-121/BRIEF.md`; the code as merged (`src/serverstorage/MapGen/`,
`src/shared/Map/init.luau`, `src/serverstorage/Assets/`, `src/server/Match/`, `src/server/Boar/`,
`tools/mapgen.py`, `tests/server/map_contract.spec.luau`); `docs/design/asset-pipeline.md`;
`docs/design/drive.md`; `docs/design/feature-flags.md`; `docs/research/2026-09-24-map-generator.md`;
`GAME_DESIGN.md`; `TASKS.md` rows 79, 79a, 85, 74a; `CLAUDE.md`; `docs/PROJECT_CONTEXT.md`.

**Test of this document:** a Builder can build step **B1a** from it without asking a question, and
every later step's scope is named. Every owner is named, every number has a basis, every human action
is in §17 and §19.

---

## 0. What changed against v3, in one page

| The brief's decision | The change |
|---|---|
| **One big forest, four drive blocks, divided by forest roads** (brief 1) | The map grows from 2,048 to **3,072 studs** and carries **four block rectangles** and **four roads** as DATA (§3, §5). `Config.WORLD.corridor` — one rectangle — becomes `Config.BLOCKS`, four of them |
| **A drive = one block** (brief 1) | **`Map.ACTIVE_BLOCK`**, one committed string beside `Map.EXPECTED_WORLD`. The five `DrivenHunt.*` marker kinds are placed for **the active block only**, because `src/server/Match/Markers.luau`, `Markers.read`, requires **exactly one** `DrivenHunt.DriveLine` and reports `complete = false` otherwise. Four tagged lines would park the match in `Waiting` for ever (§4.2) |
| **Every block a realistic mix**, a dominant character plus patches, young trees, gaps, deadwood, brush, ferns, wet spots (brief 2) | A per-block `character` table: species mix, age-class mix, density tiers, patch list, deadwood and brush rates. Patch **kinds and counts are data; patch positions are seeded** inside the block under declared constraints (§6) |
| **Block 1's character: old oak with a young patch and a gap** (brief 2) | `Config.BLOCKS.block1.character` (§6.2), and block 1 is the only block whose wood is built in this task (§16) |
| **Real numbers** (brief 3) | §15. Roads 3.9 m / 5.6 m with a 6.2 m cleared corridor; stands 2 m up; the hills are ±18 m of roll with a 34 m rim. The block AREA is at ~1:5 of a real 70–100 ha block and the arithmetic for that is written out, not hidden (§15.1) |
| **Gentle hills, never steep enough to block the boar or a driver** (brief 3) | Relief 40 → **64** studs outside the blocks, **28** inside one, rim 44 → **120**. The voxel band grows from 96 to 144 studs and is written in **two passes of the one measured region size** (§5.4) — no new engine assumption |
| **Bought oak pack, `.rbxm` is banned, say how the generator gets the trees** (brief 4) | **Route A: each distinct tree is published once as a PRIVATE Model asset in Karen's account and recorded as a row in `ServerStorage.Assets`**; the generator loads it through the existing `Assets.Loader`. Route B (`AssetService:CreateMeshPartAsync` from the seller's mesh ids) is the named fallback. `MapGen.Assets` is archived — this closes `TASKS.md` row 74a(a) (§11) |
| **Adding a species must be pure data** (brief 4) | A species is one row in `Config.SPECIES` plus its `Assets` keys. Nothing in `Props`, `Scatter` or `Layout` names a species (§6.1) |
| **CC0 ground/road textures as terrain MaterialVariants** (brief 5) | A new `materials` step owned by `MapGen.Ground` (already the only writer of `Terrain` and of material colour), behind measurement **M3**, degrading to the v3 palette that is already measured and shipped (§8) |
| **Our own timber stand; the posts become stands** (brief 6) | `Props.stands`: a drawn timber Drückjagdbock with a **collidable floor at 7.1 studs** (2 m), ladder and rail. The **post marker's bottom face moves onto that floor**, so `src/server/Match/Body.luau`, `Body.placementFor`, needs **no change at all** — it already places a character at `post.Position + post.Size.Y/2 + STAND_HEIGHT_STUDS` (§7) |
| **The map switch stays a commit; the arena stays until Karen looks** (brief 7) | `Map.EXPECTED_WORLD` goes `"map:v1"` → `"map:v2"` in the last step only (§17). Everything before it is built, rebuilt and screenshotted without changing what a player stands in |
| **Performance budget in the design** (brief 8) | §13: a per-species triangle declaration, a **pure** upper bound on baked triangles inside the streaming radius (`Layout.visibleLoad`, asserted at all 8 stands), a measured frame-time report (M7), and the two numbers to turn if it fails |

Three things v3 shipped are **retired by this revision**, each with its reason: the flank **fields**
(there is no room for farmland inside a forest map — the switch stays, §6.6), the **bog** as a feature
(it becomes "wet ground in a hollow", derived from the heightfield, §6.5), and the **one** corridor
(there are four blocks now).

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

1. **Build one forest, 3,072 × 3,072 studs, divided into four drive blocks by four forest roads**, and
   build **block 1's content** now: old oak, a young-oak patch, a gap, deadwood, brush, ferns, wet
   ground in the hollows, and the wood across the road the boars escape into.
2. **Run at edit time only**, through StudioMCP, from code on disk. Never at run time, never in a live
   server, never during Play.
3. **Be reproducible from a seed.** Same commit, same seed, same digest (`MapGen.digest`,
   `tools/mapgen.py verify`).
4. **Place the five gameplay markers for exactly one block**, the one `Map.ACTIVE_BLOCK` names, as
   tagged, script-free, inert instances `src/server/Match/Markers.luau`, `Markers.read`, already reads.
5. **Stand every shooter on something solid.** A shooter post marker's bottom face sits on a
   **collidable stand floor**; the contract proves the floor is under it.
6. **Leave every block walkable for the boar's own agent** (`Boar.CONFIG.AGENT` in
   `src/server/Boar/init.luau`: `AgentRadius = 2`, `AgentCanJump = false`, `AgentCanClimb = false`),
   proved geometrically (§6.3) and empirically by `MapGen.reachability`.
7. **Keep the gravel clear.** Nothing collidable within `halfWidth + keepClear` of any road
   centreline, over the whole length of every road.
8. **Reference every art asset by key** through `ServerStorage.Assets` — one id table in the repo,
   never a binary, never a bare id outside the manifest.
9. **Be undoable**: the machine-checked backup condition in `tools/mapgen.py` before any destructive
   run; `MapGen.clear()` restores the palette **and removes the material variants it created**.
10. **Be checkable by machine**: server specs (§14.1), client specs (§14.2), eleven named screenshots
    (§14.3), and a **pure** triangle bound (§13.2).
11. **Cost the harness nothing new**: no `default.project.json` change (so no extra Karen **Connect**
    click), no new Wally package, no `.rbxm`, no typed value in a `.model.json`.

### 1.2 Must not

Each row is a named failure from `docs/PROJECT_CONTEXT.md`, a boundary an existing owner drew, or a
measured engine fact.

| Prohibition | Why | Whose job instead |
|---|---|---|
| Never run at run time; no `*.server.luau` / `*.client.luau` / `init.server.luau` anywhere under the generator | a map that rebuilds itself is a second writer of the world nobody can see. `MapGen.verifyContract` asserts every descendant of `ServerStorage.MapGen` is a `ModuleScript` | `tools/mapgen.py`, at edit time, by hand |
| Never tag more than one block's markers | `Markers.read` counts drive lines and sets `complete = false` at `#lines ~= 1`; `Map.EXPECTED_COUNTS` is one table of counts | `Map.ACTIVE_BLOCK`, one committed string (§4.2) |
| Never place a collidable obstacle in a block without a proved gap | the hedgerow wall that survived two review rounds in Task 43 (`TASKS.md` row 43a(k)) | §6.3's separation argument plus `MapGen.reachability` |
| Never give a tree's **crown** collision or query | a ray hits a part's **collision geometry**; a whole-tree hull is a convex blob, so a queryable crown eats shots in thin air — the invisible-wall shape Karen cannot see the reason for. The log pile that absorbed slugs (`TASKS.md` row 66, audit-005) is the same class | §10.2: one invisible `Trunk` collider per tree, `CanCollide` and `CanQuery` true; the MeshPart is visuals only |
| Never make a marker shootable, walkable or collidable | `src/server/Weapon/Cast.luau` builds `RaycastParams` with an Exclude filter and **no `RespectCanCollide`**, so `CanCollide = false` alone does not stop a pellet: `CanQuery = false` is the load-bearing one (`Markers.place` already does this) | `MapGen.Markers` |
| Never write `Boar.CONFIG`, `Match.CONFIG`, `Shotgun.CONFIG` or any runtime state | one writer per system | their owners. The map **publishes** its rectangle; `Boar.CONFIG.field` is changed by the boar's own file at the switch (§17) |
| Never write a script, or bake an asset containing one | one surviving `Script` under `Workspace` fails the harness's unmanaged-script scan **every run from then on** | `Assets.Loader`'s `scriptIn` refuses the template and the key proxies (`src/serverstorage/Assets/Loader.luau`) |
| Never write `Workspace.TestArena`, `Workspace.Boars`, `Workspace.WeaponEffects`, `Workspace.DriveMarkers` or any player | four named owners: `ServerScriptService.TestArena`, `ServerScriptService.Boar`, `PlayerScripts.Weapon.Effects`, `Match.Body` | those owners |
| Never leave a template or a cache in a Rojo-owned container | `ServerStorage` and `ReplicatedStorage` are `$ignoreUnknownInstances: false`, so anything parked there is **deleted at Karen's next Connect** (CLAUDE.md) | `Props` points `Assets.Loader` at a folder under the map root and calls `Loader.clear()` in the same step (§11.3) |
| Never leave anything in `Workspace` but `Terrain`, `Camera` and the map root | `tools/mapgen.py`'s `WORKSPACE_ALLOWED` is `("Terrain", "Camera")` plus the root, and `--backup census` **refuses** when anything else is there. A tree template parked in Workspace would break the one backup route that needs no human click | §11.1 route A keeps templates out of Workspace entirely |
| Never turn streaming on as a side effect of a build | audit-004 F4: `Settings.MAY_WRITE = false` and the step **refuses and reports** | M2.6, by hand, with a playtest |
| Never create a `Water` material | the boar's mover is a horizontal-plane `LinearVelocity` (`src/server/Boar/Body.luau`, `Body.create`) that was never designed to swim | wet ground is `Mud`/`Ground` plus a dip (§6.5) |
| Never claim a save happened | `tools/mapgen.py` cannot observe a Studio menu action, and an unverifiable claim is the false-PASS shape this project has paid for | the tool prints the action; the proof is a reopen plus `mapgen.py contract` (measurement **B**) |
| Never commit `.rbxm` / `.rbxmx` / `.rbxl` | banned outright (CLAUDE.md); binary is unreviewable in a PR | ids in `ServerStorage.Assets`; backups outside the repo |
| Never add a subcommand or a write path to `tools/studio_mcp.py` | *"Its Luau is read-only"* (its own docstring). The file that decides whether a PR may be reviewed must not be the file that can rewrite the world | `tools/mapgen.py` |

**One predicate answers one question.** `Map.EXPECTED_WORLD` says which world the committed code
expects. `Map.ACTIVE_BLOCK` says which block the drive runs in. Neither says whether the wood is built,
whether an asset loaded, or whether the forest is any good.

---

## 2. Ownership

Rule 3: exactly one writer per system, named here, mirrored in `GAME_DESIGN.md`.

### 2.1 The owner table

This revision **amends** the three map rows `GAME_DESIGN.md` already carries; it adds no system. The
amendments are listed in §18.1.

| System | Owner (the only writer) | Location on disk → Studio |
|---|---|---|
| **The map contract**: the tag strings, which world, **which block**, the roads, the blocks' rectangles, the stand's geometry, the palette, the material-variant table, streaming and the budgets. Frozen data, **no runtime writer at all** | `ReplicatedStorage.Map` — nothing writes it; the Builder edits the file and git records it | `src/shared/Map/init.luau` |
| **The map generator**: `Terrain` (voxels, material colours **and material variants**), `Workspace.DrivenHuntMap` and everything in it, and `Workspace.StreamingEnabled` | `ServerStorage.MapGen`. Within it exactly four modules touch the world: `Ground` (Terrain, palette, variants), `Props` (`…Map.Props`), `Markers` (`…Map.Markers` and every `CollectionService:AddTag` in the map), `Settings` (the streaming property) | `src/serverstorage/MapGen/` |
| **The generator invoker**: the one write path into Studio | `tools/mapgen.py` — the only thing in the repo that sends a mutating `execute_luau` | `tools/mapgen.py` |
| **The markers the game reads** (`DrivenHunt.*`) | **at edit time:** `MapGen.Markers`, for the active block only. **At run time: nobody writes them**; `Match.Markers` reads them | as above |
| **The asset manifest and the one id→Instance seam** | **`ServerStorage.Assets` and `ServerStorage.Assets.Loader`, from step B1d onward** — the one id table in the repo. `MapGen.Assets` is archived under `backups/` with a note (rule 7); this closes `TASKS.md` row 74a(a) | `src/serverstorage/Assets/` |
| **Where a player stands, and their outfit** | **unchanged: `ServerScriptService.Match` → `Match.Body`.** The map moves the post MARKER; it never places a player | `src/server/Match/Body.luau` |
| **A boar's field rectangle** | **unchanged: `ServerScriptService.Boar`.** `Boar.CONFIG.field` is edited in the boar's own file, by its owner, in the switch commit, and the spec asserts it deep-equals `Map.FIELD` | `src/server/Boar/init.luau` |
| World geometry: test arena | **unchanged:** `ServerScriptService.TestArena`, which `ArenaBoot` declines to build while the world is not `"arena"`. It is still the rollback | `src/server/TestArena.luau` |

### 2.2 The modules inside `ServerStorage.MapGen`

Nothing happens on require, with the one recorded clause (`Contract.luau` clones the contract script in
Edit so a run cannot read a stale one).

| Module | Is | Changes in this revision | Never |
|---|---|---|---|
| `init.luau` | the entry point: `VERSION`, `CONFIG`, `steps`, `runStep`, `clear`, `digest`, `markerDigest`, `builtSeed`, `reachability`, `expectedCounts`, `verifyContract` | the plan gains `materials`, a second terrain **band pass**, `patch`, `deadwood`, `ferns` and `stands`; `clear` reports `variantsRemoved`; `verifyContract` reports `activeBlock`, `variants` and `visibleTris` | decides a layout rule itself; writes a voxel |
| `Contract.luau` | how the generator reaches `ReplicatedStorage.Map`, fresh in Edit | — | anything else |
| `Config.luau` | pure data: every number in §15, deep-frozen with `Shotgun.deepFreeze` | `BLOCKS`, `ROADS`, `SPECIES` (5 rows), `AGE`, `PATCH`, `DEADWOOD`, `FERNS`, `STAND`, the relief and band numbers | anything else |
| `Height.luau` | pure: `at`, `atFlattened`, `benchHeight`, `benchBand`, `edgeFloor`, `offset` | `corridorFalloff` → **`blockFalloff`** (any block, not one corridor); `edgeFloor` to `EDGE_MAX_Y = 120` | touches Terrain, Instances, services or `Random` |
| `Layout.luau` | pure: tiles, pads, markers, roads, tie trees, density, gates | **new**: `blocks`, `blockAt`, `activeBlock`, `roads`, `onRoadKeepClear`, `standPoints`, `patches`, `visibleLoad`, `wetAt`; `tiles` emits one entry per (tile, band pass); `markers` derives from the ACTIVE BLOCK | as above |
| `Scatter.luau` | pure: the seeded half of every placement | **new**: `ageAt`, `patchCentres`, `patchTrees`, `deadwood`, `ferns`; `speciesAt` takes the block's own mix | as above |
| `Digest.luau` | pure: the canonical digest of a plan plus terrain samples | takes the **variant table** as a fourth input, so a hand-changed texture shows in the digest | as above |
| `Ground.luau` | **the only writer of `Terrain` in the repo** | **new**: `applyVariants`, `readVariants`, `clearVariants`; `writeTile` takes a band pass; `surfaceMaterial` gains the `gap` and `wet` cases | reads or writes any Instance other than its own `MaterialVariant`s |
| `Props.luau` | **the only writer of `…Map.Props`** | **new**: `stands`, `deadwood`, `ferns`, `patchTrees`; `placeTree` builds **mesh + invisible trunk collider**; templates come from `Assets.Loader` | writes Terrain or a marker |
| `Markers.luau` | **the only writer of `…Map.Markers`** and the only caller of `AddTag` in the map | the post marker sits on the stand floor; the drive line spans the active block | writes Terrain or a prop |
| `Settings.luau` | **the only writer of `Workspace.StreamingEnabled`**, refusing while `MAY_WRITE == false` | — | writes anything else |
| `Assets.luau` | the old manifest | **archived** at B1d (rule 7) | exist afterwards |

`Height`, `Layout`, `Scatter` and `Digest` stay exported on `MapGen`, for the reason
`src/server/Boar/init.luau` exports `Boar.Brain`: **the pure core must be drivable in the ordinary
harness run, with no Studio, no Terrain and no asset, while the generator itself never runs there.**

### 2.3 What may require what

```
ServerStorage.MapGen  ──requires──►  MapGen.Contract ──►  ReplicatedStorage.Map
ServerStorage.MapGen  ──requires──►  ServerStorage.Assets (+ .Loader)      [from B1d]
runtime scripts       ──require───►  ReplicatedStorage.Map
runtime scripts       ──NEVER─────►  ServerStorage.MapGen
MapGen.reachability   ──requires──►  ServerScriptService.Boar, EDIT TIME ONLY, inside a pcall
```

`src/serverstorage/` and `src/shared/` are already `$path`-mapped: **no `default.project.json` change
and no extra Karen Connect click.**

---

## 3. The forest, in plan

```
 PLAN  (x across, z up the page; 3,072 x 3,072 studs, origin at the centre)

        x=-1536   -1440            -14  0  +14             +1440   +1536
 z=+1536  ┌───────────────────────────────────────────────────────────┐  rim rises to +120
          │  rim / backdrop wood (relief +-64, trees at 0.12)         │
 z=+1300  │ ════════════ ASSEMBLY TRACK (10 studs) ══════════════════ │
 z=+1286  │  ┌──────────────────────┐ │ │ ┌──────────────────────┐    │
          │  │                      │ r │ │                      │    │
          │  │      BLOCK 1         │ i │ │      BLOCK 2         │    │
          │  │  old oak + beech     │ d │ │  (layout only)       │    │
 z=+1180  │  │  ● ● ● ●  BoarSpawn  │ e │ │                      │    │
          │  │  young patch, a gap, │   │ │                      │    │
          │  │  deadwood, wet holl. │ x │ │                      │    │
 z=+100   │  │  ...density rises    │ = │ │                      │    │
 z=-126   │  └──────────────────────┘ 0 │ └──────────────────────┘    │
 z=-140   │ ═══════════ THE MAIN ROAD (20 studs, gravel) ════════════ │
          │     ▲ 8 STANDS behind the road at z=-20, 160 studs apart  │
 z=-200   │        † 12 tie trees                                     │
 z=-260   │        exitZ: the boar has crossed and is gone             │
 z=-454   │  ┌── crossing band: block 3's wood, 300 studs deep ──┐    │
 z=-1246  │  │      BLOCK 3 (layout only)   │ │ BLOCK 4          │    │
 z=-1260  │ ═══════════ THE SOUTH RIDE (14 studs) ═══════════════════ │
 z=-1536  └───────────────────────────────────────────────────────────┘

 SECTION across the main road, at one x

   block 1's wood          verge  ROAD  verge        stand   crossing band
  ~~~~~~~~~~~~~~~~~~\                                 ┌─┐  /~~~~~~~~~~~~~
   relief +-28 inside  \_______ ┌──────┐ _______      │ │ /  relief eased
   a block, eased to            │ flat │        \     └─┘/   to +-6 within
   +-6 within BENCH_BAND        │ y=0  │         \______/    BENCH_BAND
                           26   └──────┘   26
                          verge  20 wide  verge      floor at 7.1 studs
```

**Every drive pushes toward −Z, and that is not a style choice.** `src/server/Boar/Brain.luau`,
`Brain:_outcome`, despawns a fleeing boar at `position.Z <= field.exitZ`, and `Brain._fleeTarget`
returns `Vector3.new(targetX, field.groundY, field.exitZ)`: the escape axis is **baked into the boar**.
So each block has its shooter road on its **−Z edge**, the drivers enter from its **+Z edge**, and the
boars cross that road into the wood beyond. Making the drive axis a parameter is a **boar** task, not a
map task, and it is in §19 as a scope item.

**Everything the game stands a player or a boar on is at a known height**: the roads and the assembly
track are benches at exactly `GROUND_Y = 0`, the four spawn pads are flat discs at `GROUND_Y`, and a
shooter stands on a **stand floor** whose height the contract carries. That is what keeps
`Boar.CONFIG.field.groundY = 0` true — `src/server/Boar/init.luau`, `Runtime:spawn`, overwrites the
caller's Y with `field.groundY + BODY_SIZE.Y/2 + SPAWN_CLEARANCE` and does **no** ground raycast, so a
pad that is not flat spawns a boar inside a hill (its own comment records a sow settling 2 studs high
and cubs vanishing, task 119).

---

## 4. The map contract — `ReplicatedStorage.Map`

`src/shared/Map/init.luau`, deep-frozen with `Shotgun.deepFreeze`. Data only, no behaviour, no runtime
writer. It carries **no asset id** and no secret — keys only.

### 4.1 The fields (additions and changes marked)

```luau
export type FieldRect = {
    bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
    exitZ: number,
    groundY: number,
}
export type Road = {                                   -- NEW
    axis: "x" | "z",       -- "x" runs ALONG x at a constant z
    at: number,
    halfWidth: number,     -- gravel
    verge: number,         -- how far the TERRAIN easing reaches
    keepClear: number,     -- how far NOTHING COLLIDABLE may stand (§5.3)
    from: number, to: number,
}
export type Block = {                                  -- NEW
    bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
    road: string,          -- the Map.ROADS key its shooter line stands on (its -Z edge)
    exitPastRoad: number,  -- studs past that road's centreline the boar is gone
}

Map.VERSION         = "v1"
Map.GENERATOR       = "v4-forest-block1"   -- MapGen.VERSION reads this; one home (row 44a(f))
Map.EXPECTED_WORLD  = "map:v1"             -- THE SWITCH. Becomes "map:v2" in step B1g ONLY (§17)
Map.ACTIVE_BLOCK    = "block1"             -- NEW. THE SECOND COMMITTED STRING (§4.2)
Map.SEED            = 1                    -- the seed the committed place was built from
Map.DIGEST          = "<64 hex>"           -- what that seed produced

Map.FIELD: FieldRect        -- the ACTIVE BLOCK's rectangle plus its exit. Must equal
                            -- Boar.CONFIG.field (asserted). §15.2 for block 1's numbers.
Map.SIZE_STUDS      = 3072                 -- CHANGED from 2048
Map.ROADS           = { main = {...}, ride = {...}, south = {...}, assembly = {...} }   -- NEW (§15.1)
Map.BLOCKS          = { block1 = {...}, block2 = {...}, block3 = {...}, block4 = {...} } -- NEW (§15.2)
Map.STAND           = { floorStuds = 0, offsetZ = -20, railTopStuds = 3.6,   -- NEW (§7)
                        footprintStuds = 7, clearRadius = 12 }
                      -- floorStuds is 0 while the world is "map:v1" (the posts are on the road) and
                      -- 7.1 in the SAME COMMIT that rebuilds the place with stands (§16, §7.3).
                      -- ONE number, read by the live contract check, so one check covers both worlds.
Map.TAGS            = { shooterPost = "DrivenHunt.ShooterPost", driveLine = "DrivenHunt.DriveLine",
                        driverStart = "DrivenHunt.DriverStart", boarSpawn = "DrivenHunt.BoarSpawn",
                        tree = "DrivenHunt.Tree" }      -- unchanged: five strings, one home
Map.EXPECTED_COUNTS = { shooterPost = 8, driveLine = 1, driverStart = 1, boarSpawn = 4, tree = 12 }
                      -- unchanged: the ACTIVE BLOCK's markers, and nothing else is tagged
Map.STREAMING       = { enabled = true, minRadius = 64, targetRadius = 1024,
                        integrityMode = "PauseOutsideLoadedArea", modelBehavior = "Improved",
                        scriptable = { "StreamingEnabled" } }   -- unchanged, and measured
Map.BUDGET          = { parts = 20000, visibleParts = 8000, trees = 1800, brush = 700,
                        ferns = 700, deadwood = 120, hedgeParts = 400, furniture = 250,
                        visibleTris = 7000000 }         -- CHANGED: four new ceilings (§13)
Map.SPAWN_PAD       = { radius = 30, blend = 40, tolerance = 0.75 }   -- unchanged
Map.PALETTE         = { litter = …, rough = …, road = …, wet = … }    -- `bog` renamed `wet` (§6.5)
Map.PALETTE_DEFAULT = { … }                 -- MEASURED 2026-09-26; unchanged
Map.TERRAIN         = {                     -- NEW (§8): CC0 textures, BY KEY, never by id
    variants = {
        litter = { baseMaterial = "LeafyGrass", studsPerTile = 8,  key = "ground.litter" },
        rough  = { baseMaterial = "Grass",      studsPerTile = 8,  key = "ground.grassride" },
        road   = { baseMaterial = "Ground",     studsPerTile = 6,  key = "ground.gravel" },
        wet    = { baseMaterial = "Mud",        studsPerTile = 6,  key = "ground.mud" },
    },
}
```

### 4.2 `Map.ACTIVE_BLOCK` — why a second committed string, and not a flag

The drive reads the world through tags. `src/server/Match/Markers.luau`, `Markers.read`, calls
`GetTagged` for each of the five strings, requires **exactly one** drive line, and publishes
`complete = false` with the missing names otherwise; `Match` then keeps the match in `Waiting`.
Tagging four blocks' posts would give 32 posts and 4 lines, which is not "four drives available" — it
is one broken drive.

So exactly one block is tagged, and **which one is a committed string, for the same measured reason the
map switch is** (CLAUDE.md, "THE MAP SWITCH IS THE EXCEPTION"; Task 79 measured a flag-off world with
a built map answering `GetTagged("DrivenHunt.ShooterPost") == 16`). The tags live in the **place**;
a flag lives in code and cannot make 8 posts absent. Changing the drive to block 2 is therefore:
flip `Map.ACTIVE_BLOCK`, flip `Map.FIELD` and `Boar.CONFIG.field` together, rebuild, save, commit —
the §17 ritual with one more string in it.

**Per-match block rotation is out of scope and is named as such** (§19, Director D): it needs
`Match.Markers` to read *a* block rather than *the* tags, which is a change to `docs/design/drive.md`'s
system, not to this one.

### 4.3 What the markers are, physically

Unchanged where it is load-bearing: every marker is an **`Anchored`, `CanCollide = false`,
`CanQuery = false`, `CanTouch = false`, `Transparency = 1` `Part`** under
`Workspace.DrivenHuntMap.Markers` (`Markers.place`). Three shapes are not the generator's choice:

- **The drive line is exactly one part**, `(blockWidth, 1, 1)` at the block's road, built with
  `CFrame.lookAt(position, position + Vector3.zAxis)` so its `LookVector` points at **+Z, the
  drivers**. `src/server/Match/Markers.luau` publishes `normal = line.CFrame.LookVector`;
  `src/server/Weapon/SafetyArc.luau`, `SafetyArc.isForbidden`, dots the pellet direction with it.
- **A shooter post is a part a character is put down on top of.** `src/server/Match/Body.luau`,
  `Body.placementFor`, returns `post.Position + (0, post.Size.Y/2 + STAND_HEIGHT_STUDS, 0)`. The
  marker stays `(6, 1, 6)`; what changes is its **Y**: its bottom face sits on the stand floor
  (§7.3). **`Match.Body` needs no change.**
- **`DrivenHunt.Tree` goes on the 12 placed tie trees only.** `Body.anchorFor` scans every tagged tree
  on every violation; a 1,300-tree scan per violation is a different bug. And `Body.tiePointFor` uses
  `math.max(tree.Size.X, tree.Size.Z)/2 + TIE_GAP_STUDS` as the stand-off radius — which is why the
  tagged part must be the **trunk collider** and never a whole-tree MeshPart whose X is its crown
  (§10.2). A 30-stud crown radius would tie a punished shooter 30 studs from the tree.

---

## 5. Roads, blocks and the ground

### 5.1 Four roads, each a bench

A **bench** is a flat strip at exactly `GROUND_Y`, eased into the terrain over `verge` studs each side
and tapered over `taper` studs at each end. `Layout.roads(config)` returns all four (§15.1). The
existing machinery takes them unchanged: `Height.benchBand` and `Height.benchHeight` already loop over
`config.WORLD.benches`, and `Layout.onBench` already includes the taper.

The **main road** is the widest (20 studs, 5.6 m) because it is the one two blocks' drives stand on and
the brief's "main 5–5.5 m"; the two rides are 14 studs (3.92 m, the brief's 3.5–4.5 m); the assembly
track is 10 studs, because nobody shoots from it.

**The roads are level, not contour-following.** Marked K and named as a simplification, with v3's
reason: a longitudinal profile means every stand, and the contract's `tolerance = 0.75` check, stops
being a comparison against one number. It is `ROAD_RELIEF` in `Config` plus a contract check against
`Height.benchHeight` whenever Karen wants it, and it is not in v4.

### 5.2 Four blocks

`Layout.blocks(config)` returns the four rectangles; `Layout.blockAt(x, z, config)` returns the block a
point is in or `nil`; `Layout.activeBlock(config)` returns the one `Map.ACTIVE_BLOCK` names (read
through `MapGen.Contract`, never copied — the rule `Config.SPAWN_PAD = Map.SPAWN_PAD` already follows).

A block's rectangle is **the wood**: its edges stop at `halfWidth + keepClear` from each bordering
road's centreline, so a block and a road never overlap and a spec can assert it.

### 5.3 `keepClear` is not `verge`, and that is the whole point of a forest ride

v3 excluded trees from `onBench(x, z, config)` — the gravel **plus the verge**. With a 24-stud verge
that clears 62 studs (17 m) down every ride: a firebreak, not a forest road. The brief asks for a
**cleared corridor of 4.5–7 m**.

So the two numbers separate:

- **`verge`** stays the TERRAIN easing width, and it is forced by the slope ceiling:
  `BENCH_RELIEF = 6` studs over 26 studs is `atan(6/26) = 13.0°`, inside
  `CORRIDOR_MAX_SLOPE_DEG = 15`.
- **`keepClear = 4`** is how far from the gravel nothing collidable may stand. A ride is then
  `14 + 2×4 = 22` studs = **6.2 m** of cleared corridor, inside the brief's range; the main road is
  `20 + 8 = 28` studs = 7.8 m. Trunks stand on the eased verge slope and crowns overhang the ride,
  which is what a European forest road looks like.

**The guard in `MapGen.verifyContract` is amended, not weakened.** It walks every road end to end and
fails the build for any collidable part within `halfWidth + keepClear` (it was `halfWidth + verge`).
Its purpose is unchanged — *the gravel a shooter stands on and a boar crosses is never blocked* — and
it keeps the property it was written for (a hedge wall across the gravel, Task 58 round 1 finding 1).
`Layout.onRoadKeepClear(x, z, config)` is the one predicate; `Layout.treeDensity`, `Props`' rejection
and the spec all call it, so none of them can disagree.

### 5.4 The heightfield: hills, and a band written in two measured passes

```
h  = fbm(warped x, warped z) * RELIEF                       -- RELIEF 64 (was 40)
h  = h * blockFalloff(x, z)      -- 1 outside every block; BLOCK_RELIEF/RELIEF inside one; 90-stud ease
h  = h * benchBand(x, z)         -- BENCH_RELIEF/RELIEF within BENCH_BAND of any road
h  = h - wetDip(x, z)            -- hollows get wetter and a little deeper (§6.5)
h  = max(h, edgeFloor(x, z))     -- a FLOOR, never a sum: the rim rises to EDGE_MAX_Y = 120
h  = benchOrPad(h, x, z)         -- pads, then benches; a bench WINS over a pad
```

`Height.corridorFalloff` becomes **`Height.blockFalloff`**: the relief is eased to `BLOCK_RELIEF = 28`
inside **any** block, not inside one corridor, so blocks 2–4 are playable the day their content lands
and the slope spec can assert all four now.

**The voxel band grows, and it is written with the one region size that has been measured.** The rim
at +120 and the hollows at −12 need a band of 144 studs; the measurement of record is "a
128 × 128 × 96-stud region at resolution 4 is accepted, and resolutions 8 and 2 are refused"
(`src/serverstorage/MapGen/Ground.luau` header; `docs/research/2026-09-24-map-generator.md` measurement
A). Nothing has ever measured a taller region. So:

- `BAND_Y = { min = -24, max = 120 }`, 144 studs, written as **two passes**: the **lower** pass covers
  `[-24, +72]` (96 studs — exactly the measured region) and the **upper** pass covers `[+72, +120]`
  (48 studs, comfortably smaller).
- `Layout.tiles(config)` emits one entry per (tile, pass) and **omits the upper pass where it is
  provably empty**: outside the edge band no column can exceed `RELIEF = 64 < 72`, so only the tiles
  that intersect `EDGE_BAND` of the rim need it. That is an **analytic** test, not a sampled one —
  24 × 24 tiles give 576 lower passes and 92 upper passes, **668 terrain steps**.
- A spec asserts the invariant that makes the omission safe: over three seeds, no column's height
  exceeds the top of the band its tile was written in (§14.1).

Borrowing the measured region instead of guessing a bigger one is rule 2. If somebody later measures
that a 144-stud region is accepted, the second pass is deleted and nothing else changes.

---

## 6. The mix model: a block's character as data

### 6.1 Species, age and asset keys — all data

A tree is **(species, age, tier)**. Nothing in `Layout`, `Scatter` or `Props` names a species: adding
one is a row here plus rows in `ServerStorage.Assets` (brief 4).

```luau
Config.SPECIES = {
    oak    = { label = "pedunculate oak", trunkStuds = 2.0, heightStuds = 78, crownStuds = 34,
               trunkColor = …, keys = { mature = "tree.oak.mature", young = "tree.oak.young",
                                        veteran = "tree.oak.veteran", backdrop = "tree.oak.backdrop" },
               tris = { mature = 6000, young = 6000, veteran = 6000, backdrop = 3000 } },
    beech  = { … }, birch = { … }, spruce = { … }, alder = { … },
}
Config.AGE = {
    young   = { heightScale = 0.42, trunkScale = 0.45, crownScale = 0.50 },
    mature  = { heightScale = 1.00, trunkScale = 1.00, crownScale = 1.00 },
    veteran = { heightScale = 1.18, trunkScale = 1.40, crownScale = 1.25 },
}
```

A species with no key yet (beech, until Karen buys the 9-species pack) resolves to **oak's** key with
its own geometry and colour, and the step reports the substitution by name. That is the v3 proxy rule
one level up: **the whole forest is buildable with no asset id at all**, and each id later replaces one
proxy with no code change.

**One mesh per (species, age), plus a cheap backdrop mesh.** `RenderFidelity = "Automatic"` is
Roblox's own distance level-of-detail (§12 source 2), so baking a LOD per distance band would be a
second mechanism answering the same question — and a baked band is wrong for drivers, who walk through
the whole block. The seller's lower-detail meshes are used for the **backdrop tier only** (outside
every block, where no player walks), at `RenderFidelity = "Performance"`.

### 6.2 A block's character

```luau
Config.BLOCKS.block1 = {
    bounds = { … }, road = "main", exitPastRoad = 120,          -- §15.2
    content = true,                                            -- blocks 2-4: false (layout only)
    character = {
        label  = "old oak over beech, a young-oak patch and a gap",
        mix    = { oak = 0.56, beech = 0.18, birch = 0.12, spruce = 0.09, alder = 0.05 },
        ages   = { mature = 0.78, young = 0.18, veteran = 0.04 },
        clumpStuds = 300, clumpStrength = 0.65,
        density = { dense = 1.00, drive = 0.34, backdrop = 0.12,
                    denseBandStuds = 240, denseHalfWidth = 580 },
        patches = {
            { kind = "young", count = 1, radiusStuds = 170, spacingScale = 0.55, weight = 0.90,
              age = "young", mix = { oak = 0.75, birch = 0.25 } },
            { kind = "gap",   count = 1, radiusStuds = 130, weight = 0.00,
              ground = "rough", fernsScale = 2.0, deadwoodScale = 2.0 },
        },
        deadwoodPerHa = 1.6, brushPerHa = 34, fernsPerHa = 34,
        crossingBandStuds = 300,                               -- the wood across the road (§6.4)
    },
}
```

**Patch kinds and counts are data; patch centres are seeded** (`Scatter.patchCentres(block, seed,
config)`), under constraints a spec asserts over 20 seeds: a patch may not cover a stand, a spawn pad,
a tie tree, a marker, or come within `keepClear + radius` of a road, and two patches may not overlap.
A named position would be reviewable but would make every seed the same map; a seeded centre with
proved constraints is reproducible **and** honest, and the committed seed is the one world Karen looks
at.

The **wet** patch is not in this list on purpose: wet ground is **derived** from the heightfield
(§6.5), so the mud, the dip, the alder and the ferns cannot end up in different places.

### 6.3 Why the wood is walkable, argued before it is measured

This is the one place a revision can break the game, because the block **is** the drive.

1. **Minimum separation is a property of the sampler.** A jittered grid displaces each candidate at
   most `±jitter·spacing/2` inside its own cell, so two candidates in neighbouring cells are at least
   `spacing·(1 − jitter)` apart: `30 × 0.5 = 15 studs` in the wood, and `16.5 × 0.5 = 8.25 studs`
   inside the young patch (`spacingScale = 0.55`).
2. **The widest trunk collider is a veteran oak at `2.0 × 1.40 = 2.8 studs`.** Worst clear gap in the
   wood: `15 − 1.4 − 1.4 = 12.2 studs`. In the young patch (trunk `2.0 × 0.45 = 0.9`):
   `8.25 − 0.45 − 0.45 = 7.35 studs`.
3. **The boar needs 4** (`Boar.CONFIG.AGENT.AgentRadius = 2`, `AgentCanJump = false`). 12.2 and 7.35
   both clear it, with margin for a patch inside the dense band.
4. **A spec asserts 1–3** over 20 seeds, per patch as well as per block, rather than trusting them.
5. **`MapGen.reachability` is the empirical gate**, from all four spawns and the driver start to five
   points along the line, with the boar's own agent, after `REACH_SETTLE_SECONDS = 6`.
6. **Deadwood, brush and ferns are `CanCollide = false` and `CanQuery = false`.** A fallen trunk 1.5
   studs high is a wall to an agent that cannot jump, and a bush that eats a slug is an invisible wall
   a shooter cannot see the reason for. A walk-through log is a small visual lie and it is the right
   one for v1; it is Karen's call in §19.

### 6.4 The crossing: a wood on both sides of the road

Karen: *"where animals has to cross road to another forest"*. Block 1's exit is 120 studs past the main
road, inside a **crossing band** — the first `crossingBandStuds = 300` of block 3's wood, built at
block 1's `drive` density. So a boar that beats the line crosses 20 studs of gravel in front of a stand
and goes into trees. Blocks 2 and 4 stay bare ground in this task, and the `forest-wide` screenshot
will show that: say it in the report rather than discovering it in review.

### 6.5 Wet ground, derived

`Layout.wetAt(x, z, seed, config)` returns 0…1 from the heightfield alone: `h < WET_DEPTH = -10`,
smoothstepped over 6 studs. It drives four things through one function, so they cannot disagree:
the extra dip (`Height.at`), the material (`Ground.surfaceMaterial` → `wet`), **alder whatever the
clump says** (`Scatter.speciesAt`), and double ferns. `Config.WORLD.bog` and `Layout.bogDepth` are
**archived** (rule 7): a 120-stud `Mud` disc at a hand-named position was already reported as reading
like a grey mud flat (`TASKS.md` row 44a(c)), and a hollow that is wet because it is low is both more
honest and one less number.

### 6.6 Fields, hedges and the old flank track

The flank farmland and the hedgerow network have **no room** in a forest that fills the map, and the
brief is "1 big forest". They are **switched off**, not deleted: `Config.INCLUDE.fields = false`,
`INCLUDE.hedges = false`, `INCLUDE.tracks = false`, exactly the Task 85 mechanism, and
`Layout.inField`, `Layout.hedgeLines`, `Layout.corridorSpan`, `Scatter.hedgeGates` and
`Layout.widestGap` keep their callers and their specs (the row-43a(m) "function with no reader" smell
is avoided, and the one mechanism that has already caught a wall across a drive stays alive). European
farmland returns as an outer margin or a second map; that is a Director scope item (§19 E).

---

## 7. The stand (ours, because none exists)

### 7.1 Why we build it

Research found **no Drückjagdbock model anywhere** (brief 6). Rule 2's written reason is exactly that:
there is nothing to borrow. So it is drawn from parts now and replaced by one mesh later with no code
change (the same `Assets` key seam every other prop uses: `prop.standtower`).

### 7.2 What it is

| Part | Size (studs) | Properties |
|---|---|---|
| 4 legs | 0.7 × 7.1 × 0.7, 5-stud span | `CanCollide = false`, `CanQuery = false` |
| **floor** | 7 × 0.5 × 7, **top face at 7.1 studs** (2.0 m) | **`CanCollide = true`, `CanQuery = true`** |
| rail, 3 sides (open toward the ladder) | 7 × 1.0 × 0.3 at 2.6 and 3.6 studs above the floor | `CanCollide = false`, `CanQuery = false` |
| ladder, 7 rungs | 2.4 × 0.25 × 0.25 | `CanCollide = false`, `CanQuery = false` |
| roof | 8 × 0.5 × 8 | `CanCollide = false`, `CanQuery = false` |

**Only the floor collides, and that is the whole rule of this layer.** A collidable rail traps a player
on a 7-stud platform, and a queryable rail eats the shot he leans over it to take — which is Task 66's
log pile (audit-005) repeated at eye level. The floor is queryable because a shot into one's own
floorboards must stop.

The stand stands at `Map.STAND.offsetZ = -20` from its road's centreline — 10 studs clear of the
gravel's edge and 6 studs past `keepClear`, so the road guard needs no exemption (§5.3) — and faces the
drive. `Map.STAND.clearRadius = 12` keeps the wood out of it, the mechanism `Layout.highSeats` already
uses.

### 7.3 How a shooter gets onto it, with no change to another owner

`Body.placementFor` places a shooter at `post.Position + post.Size.Y/2 + STAND_HEIGHT_STUDS`
(`config.STAND_HEIGHT_STUDS = 3.5`). So the map puts the **post marker's bottom face on the floor's top
face**: the marker is `(6, 1, 6)` centred at `ground + Map.STAND.floorStuds + 0.5`, and the character's
root lands about a stud above the boards. **`Match.Body` is not touched, `Match.CONFIG` is not touched,
and no number crosses an owner boundary.**

The contract check changes with it, and gets stronger. v3 asserted *"every post's bottom face is within
tolerance of `groundY`"*. v4 asserts:

1. every post's bottom face is within `Map.SPAWN_PAD.tolerance` of
   `ground + Map.STAND.floorStuds` — one expression that is **true in both worlds**, because
   `floorStuds` is 0 while the world is `"map:v1"`; and
2. **a collidable part exists directly under every post**, whose top face equals the post's bottom face
   within tolerance. That is the check the 9.5-stud drop (row 43a(l), audit-004 F9) was missing: the old
   one proved a height, not a floor.

**The safety rule is unaffected by the height, and that is checkable rather than hopeful.**
`src/server/Weapon/SafetyArc.luau`, `SafetyArc.isForbidden`, is a 3-D cone: it dots the pellet
direction with `line.normal`. A shot from 7.1 studs at a boar 40 studs away is pitched 10° down, which
changes the dot by 1.5 % against a 45° half-angle — the same answer. `Match.Penalty` decides from
distance to drivers and teams, not from height.

---

## 8. Terrain materials: the CC0 textures

### 8.1 Two layers, and the proven one ships first

- **The palette** (per-material colour) is **measured and already shipped**: `Get/SetMaterialColor`
  are callable through `execute_luau` in Edit, the values read back, they survive `Terrain:Clear()`
  and they replicate to a client (`src/shared/Map/init.luau`, `Map.PALETTE_DEFAULT` comment,
  measurement N1). It stays, with `bog` renamed `wet`.
- **Material variants** (the CC0 photo textures) are a **new step behind measurement M3**. The variant
  table is in the contract by **key**; the ids live in `ServerStorage.Assets` as `kind = "image"` rows
  — a kind the manifest's type already has and which `Assets.INSERTABLE` deliberately excludes from
  `Loader`, because an image is an id a property carries and not an Instance to insert.

The step `materials` behaves like `Settings.apply`: it writes what it can and **reports what it could
not reach**, and it never fails the build. If M3 says terrain variants are not reachable from
`execute_luau`, the forest ships on the palette alone and the row says so. That is the shape v3's §8.3
fallback had, and it is why block 1 is lookable at before a single texture is uploaded.

### 8.2 Owner, and the teardown

`MapGen.Ground` owns it: it is already the only writer of `Terrain` and of material colour, and a
`MaterialVariant` is the same kind of global, container-less state (`Ground.applyVariants`,
`Ground.readVariants`, `Ground.clearVariants`). `MapGen.clear` calls `clearVariants` and returns
`variantsRemoved: number`, **measured by reading back**, never asserted — because a variant left behind
after a `clear` is exactly audit-004's "a world nobody chose". `MaterialService` is not a Rojo-owned
container (CLAUDE.md's Layout table), so nothing there is deleted at Connect and nothing there is a
script.

### 8.3 Getting a CC0 texture to Roblox, and the human click

`tools/roblox_upload.py` is **Model-only and refuses every other type** (its own docstring, item 3; the
`CONTENT_TYPES` table is keyed per type precisely so `--type Decal` cannot be smuggled through). So
either the tool grows an `Image` type — a tools task of its own — or **the Director uploads the four
textures through Studio's Asset Manager and the ids are recorded in `ServerStorage.Assets` with their
CC0 licence quote.** The second is the default, because it is four clicks against a task, and because
it does not touch the file that gates reviews. Karen's upload OK of 2026-10-04 covers them (brief 5).

---

## 9. The generator's public interface

Declared as it will be after this revision; **changes marked**.

```luau
export type StepSpec   = { index: number, kind: string, label: string, estimatedMs: number }
export type StepReport = {
    index: number, kind: string, label: string,
    ok: boolean, message: string?,
    voxelsWritten: number?, partsCreated: number?,
    proxyUsed: { string }?, substituted: { string }?,   -- `substituted` is NEW (§6.1)
    elapsedMs: number,
}
export type Reach = { from: string, to: string, status: string, waypoints: number }

MapGen.VERSION = Map.GENERATOR
MapGen.CONFIG: Config                                    -- frozen
MapGen.steps(seed: number): { StepSpec }                 -- pure; the whole plan, no side effect
MapGen.runStep(index: number, seed: number): StepReport
MapGen.clear(): { removed: number, terrainCleared: boolean, cellsAfter: number, cellsBefore: number,
                  paletteRestored: boolean, variantsRemoved: number }        -- last field NEW
MapGen.builtSeed(): number?
MapGen.digest(): { digest: string, parts: number, samples: number, seed: number?, version: string }
MapGen.markerDigest(): string
MapGen.reachability(): { ok: boolean, findings: { string }, results: { Reach } }
MapGen.expectedCounts(): { [string]: number }
MapGen.verifyContract(): {
    ok: boolean, findings: { string }, counts: { [string]: number },
    streaming: { [string]: string }, markerDigest: string, seed: number?,
    palette: { [string]: string },
    activeBlock: string,                                 -- NEW
    variants: { [string]: string },                      -- NEW: what MaterialService actually holds
    visibleTris: { [string]: number },                   -- NEW: the §13.2 bound, per stand
}
```

`verifyContract`'s `root == nil` early return **fills every declared field** (rows 45a(c), 47a(d),
48a(c), already fixed once — keep it fixed; `activeBlock` and the two new tables are easy to forget).

### 9.1 The step order, which is also the layer order

| # | Kind | Count | What |
|---|---|---|---|
| 1 | `clear` | 1 | `Terrain:Clear()`, destroy the root, restore the palette, remove the variants; fail loudly if cells remain |
| 2 | `palette` | 1 | `Ground.applyPalette` — second, so every later screenshot is already autumn |
| 3 | `materials` | 1 | **NEW.** `Ground.applyVariants(Map.TERRAIN.variants)`; reports unreachable rather than failing (§8.1) |
| 4 | `terrain` | **668** | `Ground.writeTile(tile, pass, seed, config)` — one (tile, band pass); roads, pads, hollows and materials all resolve per column (§5.4) |
| 5 | `trees` | 12 | one 512-stud sub-block of the active block, plus the crossing band; idempotent per folder |
| 6 | `patch` | 2 | the young patch and the gap, each its own step and its own folder |
| 7 | `brush` | 12 | the same sub-blocks |
| 8 | `ferns` | 12 | the same sub-blocks |
| 9 | `deadwood` | 1 | fallen trunks and stumps |
| 10 | `stands` | 1 | the eight timber stands (§7) |
| 11 | `tieTrees` | 1 | the 12 placed tie trees |
| 12 | `furniture` | 1 | the orange-capped stakes beside each stand, the barriers, the log piles |
| 13 | `markers` | 1 | `Markers.place` + `Markers.tagTieTrees`, **last of the world layers** |
| 14 | `settings` | 1 | `Settings.apply` — refuses while `MAY_WRITE == false` |

**≈714 steps.** Every world-writing step stays **idempotent**: re-running the trees step for sub-block
7 destroys and rebuilds `…Map.Props.Trees.Block07`; it does not add a second wood. Which sub-block,
patch or tile a step is comes from `ordinal()` over the plan (already built that way in
`MapGen.runStep`, so inserting the `materials` step cannot silently shift the terrain tiles — the defect
that comment exists for).

### 9.2 Statelessness, unchanged

> A step may read: its arguments, `MapGen.CONFIG`, the contract through `MapGen.Contract`, the pure
> modules, and the world as it stands. It may **not** read a module upvalue written by an earlier step,
> a cached plan, a memo table, or `Workspace` for anything but its own idempotence.

---

## 10. Props

### 10.1 What is placed, and what each part is for

| Layer | Parts per unit | Collides | Queryable | Why |
|---|---|---|---|---|
| tree | 1 MeshPart + 1 invisible `Trunk` | trunk only | trunk only | §10.2 |
| young-patch tree | the same, at `AGE.young`'s scales | trunk only | trunk only | a thicket a boar can still walk |
| deadwood (log, stump) | 1 | no | no | `AgentCanJump = false`: a log is a wall to the boar |
| brush, ferns | 1 | no | no | cover for the eye; a bush that stops a slug is an invisible wall |
| stand | 10 | **floor only** | **floor only** | §7.2 |
| tie tree | 1 MeshPart + 1 `Trunk` (tagged) | trunk only | trunk only | `Body.tiePointFor` measures the tagged part |
| stake, barrier, log pile | 1 | no | no | unchanged from v3; `Props.sceneryOnly` applies both properties at once |

### 10.2 A tree is a mesh **plus** an invisible trunk collider

This is the load-bearing shape of the whole revision, so it is argued rather than asserted.

A Roblox raycast and a character's collision both use a part's **collision geometry**, not its render
mesh. For a whole-tree MeshPart that means one of three bad answers: `CollisionFidelity = Box` (a 34 ×
78 × 34 box — shots stop in mid-air and the navmesh sees a wall), `Default` (a convex hull — the same,
rounded), or `PreciseConvexDecomposition` (expensive and still a canopy that eats shots). And
`Body.tiePointFor` takes its stand-off radius from `math.max(tree.Size.X, tree.Size.Z)/2`, which on a
whole-tree MeshPart is the **crown** radius.

So: the MeshPart is `CanCollide = false`, `CanQuery = false`, `CollisionFidelity = Box` (nothing
queries it, so the cheapest hull is right), and a separate `Trunk` Part of
`trunkStuds × trunkHeight × trunkStuds` at the bole is `Anchored`, `CanCollide = true`,
`CanQuery = true`, `Transparency = 1`, and is the Model's **`PrimaryPart`**. That keeps every existing
reader correct with no change: `Props.trunks` already returns `model.PrimaryPart`, `Markers.tagTieTrees`
tags it, `Body.anchorFor` finds it, `Body.tiePointFor` measures a 2-stud trunk instead of a 34-stud
crown, and `MapGen.reachability` paths past 2-stud obstacles.

**The consequence, stated plainly: a shot passes through leaves.** Trunks stop shot; crowns do not.
That is the opposite of v3's proxy (whose crown was queryable) and it is deliberate — an invisible
convex blob that swallows a slug near a tree is unexplainable on screen, which is this project's named
failure. It is Karen's to overturn (§19 Karen 3), and overturning it costs one `CanQuery` and a
`CollisionFidelity`.

---

## 11. How the trees get in

### 11.1 Route A (adopted): one private Model asset per tree, through the existing loader

Karen bought BuiltByBit's "Realistic Oak Tree Pack" as an `.rbxm` whose MeshParts reference **five
meshes the seller uploaded** (brief 4). `.rbxm` is banned in the repo, and the ids in it are **mesh**
ids — which `InsertService:LoadAsset` cannot load, because it loads a **Model** asset.

So, once per distinct tree, by hand, by the Director in Karen's own Studio:

1. insert the `.rbxm` into an Edit session (not the DEV place's Workspace — a scratch place, so
   `mapgen.py --backup census` keeps working);
2. **Publish each tree as a PRIVATE Model asset in Karen's account** (right-click → Save to Roblox).
   It must **not** be listed on the Creator Store: the BuiltByBit Standard EULA allows commercial use,
   hosting and modification and **forbids redistribution and resale** (brief 4), and a listed asset is
   redistribution;
3. record one `AssetRow` per key in `src/serverstorage/Assets/init.luau` with
   `kind = "model"`, `source = "creator-store"`-equivalent (a new `"bought"` source value), the licence
   **quote, `quotedFrom`, `readOn`** the `Licence` type already requires, `trisDeclared` measured,
   `naturalSizeStuds` measured, and `sizeStuds` = the species row's target box.

Then **nothing new is built at all**: `Assets.Loader` already inserts a `kind = "model"` template,
refuses one containing a script, checks the aspect against `naturalSizeStuds`, bounds the wait, adopts a
late arrival and falls back to nil meaning "wear the grey box". `LoadAsset` needs the
`LoadOwnedAsset` capability and the asset's creator is also the place's owner (the Loader's own header
records this) — which route A satisfies and route B may not.

And because the generator runs at **edit time**, the insert happens once, in Karen's Studio; the
MeshParts are saved with the place; a player never loads an asset to see a tree.

### 11.2 Route B (the named fallback)

If publishing a Model asset is refused or Karen declines the clicks: a new `kind = "mesh"` row carrying
the **seller's mesh id** plus the four map ids, and a second route in `Assets.Loader` built on
`AssetService:CreateMeshPartAsync` — the API `TASKS.md` row 74a(h) already records as having no caller.
The map ids must be read **once through the harness**, because a normal script cannot read
`SurfaceAppearance.ColorMap` at all (measured 2026-10-01: *"The current thread cannot read 'ColorMap'
(lacking capability Plugin)"*, `src/serverstorage/Assets/init.luau`, `textureId`), and `execute_luau` is
a plugin context. This is more machinery for the same picture, which is why it is the fallback.

Either way: **one id table** (`ServerStorage.Assets`), no binary in git, every id in a diff.

### 11.3 `MapGen.Props` moves onto `Assets.Loader`, and `MapGen.Assets` is archived

Closing `TASKS.md` row 74a(a) at step B1d, with the cache seam the Loader was designed for:

```luau
-- once per step, at the top
local live = Loader.setState(Loader.newState())
Loader.setCacheParent(assetsFolder(root))        -- under the MAP ROOT, never ServerStorage
Loader.preload(keysFor(block, config))           -- yields; a step has 60 s
… Loader.template(key) per tree …                -- never yields
Loader.clear(); Loader.setState(live)            -- destroys only what this state created
```

`Loader.setCacheParent` exists exactly so a caller can nominate a container, and `Loader.clear()`
"destroys only what this state put there" — so an edit-time generator run cannot reach, or leave, a
template the live server preloaded. It also keeps the rule `Props.clearAssets` was written for: **no
template outlives the run**, and nothing is parked in a Rojo-owned container to be deleted at Karen's
next Connect.

`src/serverstorage/MapGen/Assets.luau` is archived under `backups/` with a note (rule 7) and
`Config.SPECIES` names `Assets.KEYS` instead. After that there is **one** id table in the repo, which
is what §12.2 of v3 promised and `GAME_DESIGN.md` still records as outstanding.

---

## 12. External sources

**How each was read, because this repo has recorded cases of a design citing a page that said something
else** (`TASKS.md` row 26a):

- **This session had no network.** Nothing below was fetched by me.
- Sources 1, 2, 5, 6 and 8 are quoted from repo research notes and code comments whose sessions did
  have network or a measurement; **those are the citation of record**, and where they and this file
  differ, they are right.
- Sources 3, 4 and 7 are **unfetched** and are the Builder's to confirm in the research note before
  code (rule 1). Each is paired with a measurement in §14.5 and a fallback, so none of them can block.

### 1. Roblox `Terrain` — voxels, material colour
<https://create.roblox.com/docs/reference/engine/classes/Terrain> ·
<https://create.roblox.com/docs/reference/engine/datatypes/Region3>
Licence: first-party documentation (creator-docs is CC BY 4.0); the API ships with the engine.
Maintenance: actively maintained.
**Good:** `WriteVoxels(region, resolution, materials, occupancy)` takes occupancy, which is what makes
smooth ground from a heightfield rather than steps; `CountCells` is the only number that distinguishes a
3-million-voxel world from an empty one (audit-004 must-fix 1); `Get/SetMaterialColor` are measured
callable, persistent and replicated.
**Bad:** the page gives **no region size cap** and never said 4 was the only legal resolution — both
had to be measured here (`"Resolution has to be 4"`, 128 × 128 × 96 accepted). That absence is exactly
why §5.4 writes a 144-stud band as **two passes of the measured size** instead of one taller region.
**Adopted:** `WriteVoxels` per (tile, band pass) at resolution 4; `CountCells` as the proof a build ran;
one owner for colour.

### 2. Roblox `MeshPart` — `RenderFidelity` and `CollisionFidelity`
<https://create.roblox.com/docs/reference/engine/classes/MeshPart> ·
<https://create.roblox.com/docs/parts/meshes>
Licence: first-party. Maintenance: actively maintained.
**Good:** `RenderFidelity = Automatic` is the engine's own distance level-of-detail, so the forest gets
LOD without a second mechanism; `CollisionFidelity` is per-part, so a visual mesh can carry the
cheapest hull while a separate box carries the collision that matters.
**Bad:** it does not publish the switch distances, so "LOD use" cannot be *verified* from the docs —
only measured as a frame time (M7). And it is the page that makes §10.2 necessary: a raycast meets
collision geometry, so a canopy either eats shots or is invisible to them, and no middle setting exists.
**Adopted:** `Automatic` inside a block, `Performance` for the backdrop tier, `CollisionFidelity = Box`
on a non-queryable visual mesh, and one invisible trunk collider per tree.

### 3. Roblox `AssetService:CreateMeshPartAsync` and `InsertService:LoadAsset`
<https://create.roblox.com/docs/reference/engine/classes/AssetService> ·
<https://create.roblox.com/docs/reference/engine/classes/InsertService>
Licence: first-party. Maintenance: actively maintained. **`LoadAsset` is already the repo's route of
record** (`src/serverstorage/Assets/Loader.luau`), measured working in this place for Karen-owned
assets.
**Good:** `LoadAsset` needs no new code here at all; `CreateMeshPartAsync` takes a **mesh** id, which is
what the bought pack actually contains.
**Bad (and unfetched this session):** `LoadAsset` requires the `LoadOwnedAsset` capability, which is
why route A publishes under Karen's account; and `CreateMeshPartAsync` cannot carry a
`SurfaceAppearance`, so route B must also record four map ids per mesh and can only read them from a
plugin context (measured, task 99).
**Adopted:** route A (§11.1), with route B named and costed rather than discovered.

### 4. Roblox `MaterialService` / `MaterialVariant`, including terrain variants
<https://create.roblox.com/docs/reference/engine/classes/MaterialVariant> ·
<https://create.roblox.com/docs/parts/materials>
Licence: first-party. Maintenance: actively maintained.
**Good:** it is the documented way to put a custom texture on a terrain material, which is what the
brief asks for; the variant is an Instance, so it is inspectable and removable, and `MaterialService`
is not a Rojo-owned container.
**Bad, and stated as a risk:** I did not fetch it, so whether a terrain-bound variant can be created
from `execute_luau` in Edit, whether it persists with the place and whether it replicates are **all
unknown here**. That is measurement **M3**, and §8.1's fallback is the palette that is already proven.
**Adopted:** a `materials` step that reports what it could not reach, exactly as `Settings.apply` does.

### 5. Red Blob Games — "Making maps with noise functions" (Amit Patel)
<https://www.redblobgames.com/maps/terrain-from-noise/>
Licence: an article, © Amit Patel, snippets published for reuse (not a package licence).
Maintenance: long-lived and revised; the canonical reference on the technique. **Unfetched this
session; cited from v3's §14 source 4, which carries the same note.**
**Good:** the standard treatment of **shaping noise with a separate mask** (`elevation × mask`) — the
shape of all four masks in §5.4 — and of using **a second low-frequency field to choose biomes** rather
than deriving them from elevation, which is the species clump field.
**Bad:** 2-D tile-map oriented; nothing about voxels, nothing about Roblox, and nothing about
guaranteeing a **traversable** result, which is the property this map must have.
**Adopted:** mask multiplication for the block and bench bands; a `max()` floor for the rim; a separate
low-frequency field for species. **Invented here, with the reason written down:** the *bench* (a flat
strip at a fixed height with an eased verge and a tapered end), because everything the game stands
somebody on must be at one known height and no general terrain technique gives you that.

### 6. Bridson — "Fast Poisson Disk Sampling in Arbitrary Dimensions" (SIGGRAPH 2007 sketch)
<https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf>
Licence: an academic sketch, freely distributed by the author; the algorithm is not ours to licence.
Maintenance: a 2007 paper — stable, not maintained, and it does not need to be.
**Good:** it is the reference for "no two points closer than r", which is the exact property §6.3 needs,
and it states the guarantee the jittered grid only approximates.
**Bad:** it is sequential with an active list, so a block's output would depend on where the sampler
started — fatal for a generator that must be reproducible per sub-block step and whose steps are
stateless (§9.2).
**Adopted: the *bound*, not the algorithm.** The jittered grid gives
`spacing × (1 − jitter)` as a **provable** minimum separation per cell pair, independent of step order,
and §6.3 turns that into 12.2 and 7.35 studs against the boar's 4. Inventing nothing: this is v3's
sampler with the patch case added, and the spec asserts the bound over 20 seeds.

### 7. Poly Haven and ambientCG — the CC0 ground textures
<https://polyhaven.com/textures> · <https://ambientcg.com/>
Licence: **CC0 1.0** on both libraries (no attribution required, commercial use allowed). Maintenance:
both actively publishing. **Unfetched this session** — the Builder records the licence text per file in
the `Assets` row's `licence.quote`/`quotedFrom`/`readOn`, which the type already requires.
**Good:** CC0 removes the licence question the Creator Store grant creates (v3 §1.2) and the files are
high-resolution PBR sets, so one download covers colour, normal and roughness.
**Bad:** nothing in them is Roblox-shaped — tiling scale (`StudsPerTile`) is a judgement, 4K maps must
come down to 1024 the way `tools/asset_prep.py` already does for meshes, and **`tools/roblox_upload.py`
cannot upload an image at all** (§8.3), so there is a human click per texture.
**Adopted:** four textures (forest floor, grass ride, gravel road, mud), uploaded by hand, recorded as
`kind = "image"` rows, bound by the `materials` step behind M3.

### 8. The driven hunt itself — Deutscher Jagdverband, plus the Director's forest numbers
DJV driven-hunt guidance, fetched and quoted in `docs/research/2026-09-25-drive.md` §2/§2b (that note is
the citation of record). The forest-structure numbers — a block of 70–100 ha, stands ~300 m apart on the
escape routes, shots ≤ 60–80 m downward, roads 3.5–4.5 m with a 4.5–7 m cleared corridor, a stand floor
1.8–2 m — are the **Director's research of 2026-10-04**, transcribed in `reviews/task-121/BRIEF.md`
item 3, and the Builder's research note is where they get their own named sources (rule 1).
Licence: association publications. Maintenance: live pages.
**Good:** it is primary on the two things the geometry must respect — the rule is *"in the direction of
fellow hunters"* rather than a cone (which is why `Penalty.judge` is a line test), and the neighbour
rule carries a number: *"Der Schusswinkel zum Nachbarn muss grösser als 30 Grad sein"*. At 160-stud
spacing a boar crossing 20 studs in front of a stand sits about 7° off the neighbour's line, so **this
geometry makes the v1.1 neighbour rule (`TASKS.md` row 35a) a real rule, not a nicety** — and raising
the shooters 7.1 studs is what makes a downward shot the safe one.
**Bad:** it is safety guidance, not map geometry: no stem density, no block layout. Those are the
brief's, and §15.1 says where each number came from.

**Also considered and rejected, so they are not re-proposed:** Studio's Terrain Editor Import/Generate
(UI-only, unreachable from code or MCP, and its state is not a file); heightmap PNGs as the source of
truth (unreviewable as a diff, which is what a code-generated map exists to avoid); a real stem count
(§13.1: 400–800 stems/ha over 19 ha is 7,600–15,200 mesh trees); one MeshPart per tree with no separate
collider (§10.2); baked per-distance LOD (§6.1: `RenderFidelity = Automatic` already answers it, and a
baked band is wrong for a driver walking through); `Water` for the wet ground (§1.2); a billboard
tree-line for the backdrop (a second way of drawing a tree, and the backdrop mesh is already 3k).

---

## 13. Performance

### 13.1 The honest arithmetic first

At 1 stud = 0.28 m, one hectare is 127,551 studs². Block 1's wood is
`1,426 × 1,412 = 2.013 M studs² = 15.8 ha`, and with the crossing band **19.1 ha**. A managed European
wood carries 400–800 stems/ha, so a real block 1 is **7,600–15,200 trees**.

This design plants **≈1,300**, which is **68 stems/ha** — about a tenth of reality. That number is the
single biggest honesty point in this document, and it is a GPU constraint, not a taste call: at 400/ha
the baked triangles inside one streaming radius would be about 45 million. What carries the visual
density instead is the young patch, the brush, the ferns and the deadwood, which are boxes.

### 13.2 A pure upper bound, asserted

`Layout.visibleLoad(point, config, seed)` sums, over every tree whose planted position lies within
`Map.STREAMING.targetRadius` of `point`, the tris its (species, age, tier) declares. It is **pure** —
no world, no Studio — so a server spec asserts it at **all eight stands and the driver start** against
`Map.BUDGET.visibleTris = 7,000,000`, and the trees step fails the build if a sub-block pushes it over.

It is an upper bound on **baked** geometry, not on what is drawn: `RenderFidelity = Automatic` reduces
distant meshes and identical meshes instance. What the bound does is turn "hundreds of trees, LOD,
streaming" into a number a machine can refuse, which is the only kind of budget this project has found
to work (`Map.BUDGET.trees` already fails a step rather than appearing in a document).

### 13.3 The measured gate, and the two numbers to turn

**M7:** standing on stand 4 with a sounder on the field, one player, the median and 95th-percentile
`RenderStepped` delta over 120 frames; then the same with two players. Karen's PC is the instrument and
the number is a tripwire against regression, not a promise about anybody else's machine.

If M7 is bad, in order: `TREE_DENSITY.drive` (0.34), `TREE_SPACING` (30), then
`Map.STREAMING.targetRadius` (1,024 → 768, which is M2.6's property and its own task). Each is one
number, and each gets a `TASKS.md` row with the measurement attached — **never a quiet tweak**.

### 13.4 Two costs the Director must know about before dispatching

- **The build gets longer:** ≈714 steps against 274, and the terrain steps now compute relief
  (`Height.at` returns early today, `INCLUDE.relief = false`). Target ≤ 40 min, ≤ 60 s per step,
  **measured** (M5).
- **The harness gets slower.** Task 79a(i) measured the suite at **412 s** in the built map world
  against ~92 s in the arena, and 85 brought it back to 93 s by emptying the world. The forest puts it
  back up, on every run, for every task. That is measurement **M8** and it is a scope fact, not a
  surprise: `tools/studio_mcp.py`'s `BLAST_RADIUS` already maps `src/shared/Map` and
  `src/serverstorage/MapGen` to the `map` scope, but any change that reaches a spec runs the whole
  suite.

---

## 14. How it is tested

### 14.1 Server specs — `tests/server/map_contract.spec.luau`

The file's two jobs and its `measuring(c, …)` guard stay exactly as they are: **a case that measures a
layer refuses to run on a config where that layer is off**, which is what stopped five cases passing
vacuously in Task 85 round 1. Every new case names its layers.

Live-world cases (against the world `Map.EXPECTED_WORLD` names):

1. *(amended)* exactly one world root exists, and `Ground.cells() > 0` in the map branch.
2. *(amended)* every tag resolves to exactly `Map.EXPECTED_COUNTS`, **all inside the block
   `Map.ACTIVE_BLOCK` names** (plus its road strip and far wood) — so a second block's markers cannot
   hide in the count.
3. *(unchanged)* exactly one drive line, `LookVector:Dot(Vector3.zAxis) > 0.99`.
4. *(amended)* every `BoarSpawn`'s `Position.Y` within `Map.SPAWN_PAD.tolerance` of
   `Map.FIELD.groundY`; every post's bottom face within tolerance of
   `ground + Map.STAND.floorStuds`; the `DriverStart`'s four corners at `groundY`.
5. **NEW, and it is the check the 9.5-stud drop never had:** under every post there is a **collidable**
   part whose top face equals the post's bottom face within tolerance.
6. **NEW.** No collidable part stands within `halfWidth + keepClear` of **any** road's centreline, over
   that road's whole length (§5.3) — the amended form of the guard in `verifyContract`.
7. *(amended)* the palette equals `Map.PALETTE` in the map branch and `Map.PALETTE_DEFAULT` in the
   arena branch; **and** the material variants either match `Map.TERRAIN.variants` or are reported
   unreachable with a reason (§8.1).
8. *(amended)* budgets: trees, brush, ferns, deadwood and furniture each ≤ their ceiling **and ≥ half
   of it**, so an empty wood fails instead of passing.
9. *(unchanged)* no `LuaSourceContainer` under the world root; every descendant of
   `ServerStorage.MapGen` is a `ModuleScript`.
10. *(unchanged)* `Boar.CONFIG.field` deep-equals `Map.FIELD`; `MapGen.VERSION == Map.GENERATOR`.
11. **NEW.** `Map.ACTIVE_BLOCK` names a block in `Config.BLOCKS`, that block's `content` is true, and
    no other block has any marker in it.

Pure cases (no world; this is where the new geometry is actually proved):

| Spec | Asserts |
|---|---|
| `Height` | pads exactly `GROUND_Y` at centre; every road flat at `GROUND_Y` over 200 sampled points; at `verge + 1` outside a road the unflattened height returns; `edgeFloor` never exceeds `EDGE_MAX_Y`; determinism per seed |
| band | **NEW:** over three seeds, no column's height leaves the band its tile was written in, and the upper pass is omitted only where no column can reach `BAND_Y` mid (§5.4) |
| slope | over three seeds, on a 20-stud lattice **inside every one of the four blocks**, the worst slope `< 15°` **and** `> 0.02°` (the lower bound is what stops the assertion being an identity a flat map passes) |
| `Layout` blocks | the four blocks are disjoint, none overlaps a road's `halfWidth + keepClear`, each one's `road` key exists, and `activeBlock` is one of them |
| `Layout` markers | 8 posts at `postSpacing` centred on the active block, all inside it; the line spans the block; the stand strip is clear of the gravel |
| `Layout.patches` | over 20 seeds: inside the block, never over a stand, pad, tie tree or marker, never within `keepClear + radius` of a road, never overlapping another patch |
| `Scatter` walkability | over 20 seeds, per block **and per patch**: minimum pairwise trunk-surface gap ≥ 4 studs (§6.3) |
| `Scatter.speciesAt` / `ageAt` | the mix is within ±25 % of the block's declared `mix` and `ages` for the committed seed; **every** tree in wet ground is alder; the species drawn is independent of the density (v3's Task 63 defect — a separate stream per question) |
| `Layout.visibleLoad` | ≤ `Map.BUDGET.visibleTris` at all eight stands and the driver start (§13.2) |
| `Assets` keys | every key named in `Config.SPECIES`, `Config.BLOCKS` and `Map.TERRAIN.variants` exists in `Assets.KEYS` — a typo is a failure, not a silent grey box |
| `Digest` | stable for a fixed input; **changes** when a palette colour or a variant key changes |

### 14.2 Client specs

`tests/client/map_client.spec.luau` (amended): streaming matches `Map.STREAMING.enabled`; a downward
ray from the character's root hits within 12 studs (a character in the void measures fine — this project
has shipped "measured correct, looked wrong"); `RequestStreamAroundAsync(driveLinePoint)` returns within
10 s and the drive line is non-nil afterwards; the palette the client sees equals the server's.

`tests/client/map_perf.spec.luau` (**new, and deliberately loose**): the median and p95
`RenderStepped` delta over 120 frames. It **asserts only a catastrophe ceiling** (p95 < 100 ms) and
**reports** the median for the Director to read. A tight threshold here would be a flaky spec on a
machine nobody controls, and a flaky spec is worse than none (this repo's own lesson, `TASKS.md` row
82a(c)/(d)). The number that decides is M7, read by a human.

### 14.3 Screenshots (rule 5) — `python tools/mapgen.py shots`

Eleven named Edit-mode captures. **Every one is a question, and the Builder says what it shows.**

| Name | Camera → look-at | Answers |
|---|---|---|
| `forest-wide` | (0, 1900, 2300) → (0, 0, -200) | four blocks and a road grid, or one green rectangle? (blocks 2 and 4 are bare: does that read as unfinished or as a clearing?) |
| `forest-edge` | (900, 10, -140) → (1536, 40, -140) | does the rim read as hills, or as a wall round a box? |
| `block1-hills` | (-727, 14, 1270) → (-727, 4, -140) | the "mountains a bit" down the length of the drive |
| `block1-road` | (-1287, 9, -140) → (-167, 9, -140) | standing on the gravel: do eight stands read at 160 studs? is the corridor 6 m or a firebreak? |
| `block1-stand` | (-727, 11, -156) → (-727, 6, 300) | **from the floorboards**: can a shooter see far enough to shoot? how much of the frame is trunk? |
| `block1-crossing` | (-727, 4, 200) → (-727, 3, -400) | the boar's view: is the road a gap between two woods? |
| `block1-oak` | (-600, 6, 500) → (-500, 10, 560) | close in the mature oak: bark, crown, litter — does an oak read as an oak? |
| `block1-young` | at the young patch, eye level | a thicket a boar hides in, or a plantation grid? |
| `block1-gap` | at the gap, eye level | a clearing you could shoot across |
| `block1-deadwood` | eye level among logs, brush and ferns | does the floor read as a forest floor? |
| `block1-wet` | at the deepest hollow | alder, ferns, mud — wet ground, or a grey hole? |

### 14.4 `tools/mapgen.py`

Commands, refusals (dirty tree, not Edit, wrong `PlaceId`, Studio's copy ≠ disk, no accepted backup,
orphan terrain), `--backup census`, the run log and the `[mapgen] OK:` line are **unchanged**. Two
changes only: the `SHOTS` table becomes §14.3's eleven, and the docstring's step and shot counts are
derived from the plan rather than typed (`TASKS.md` row 79a(a): the tool said seven, took nine, and the
design said eight — three numbers for one list).

`reachability` needs **no change**: it reads the tagged line and spawns, which are the active block's.

The `[mapgen]` line is **not** a harness line and never substitutes for one.

### 14.5 Measurements this revision needs written down (rules 1, 6, 8)

| # | Measurement | If the answer is no |
|---|---|---|
| **M1** | *(the Director's, before the Builder starts — brief 4)* the oak pack: scripts inside? do the seller's meshes load in Karen's place? triangles, LOD sets, the cost of 100+ in one place | the pack proxies; §6.1's substitution path covers it and the forest is still buildable |
| **M2** | Route A: does a tree published as a private Model asset in Karen's account load through `Assets.Loader` in the Edit session, with its `SurfaceAppearance` and its aspect inside `ASPECT_TOLERANCE`? | route B (§11.2), which is a `TASKS.md` row with the map ids attached |
| **M3** | Can a terrain-bound `MaterialVariant` be created from `execute_luau` in Edit? Does it persist with the place? Does it replicate? | §8.1: the forest ships on the measured palette and the `materials` step reports unreachable |
| **M4** | Is a 128 × 128 × 48 region accepted at resolution 4, and is the join between the two band passes seamless? (a spec plus `forest-edge`) | shrink the tile laterally to 64 × 64 and accept 4× the terrain steps |
| **M5** | Per-tile wall clock with relief ON, and the whole build's wall clock | `TILE_STUDS` or the octave count; both are one number, and a measured 144-stud region would delete 92 steps |
| **M6** | The real tree, patch, brush, fern and deadwood counts at the committed seed, and `visibleLoad` at each stand | §15.3's estimates are corrected in `Config` and in this file's table |
| **M7** | Frame time at stand 4 with a sounder, one player and then two (§13.3) | `TREE_DENSITY.drive`, then `TREE_SPACING`, then `targetRadius` — each a `TASKS.md` row |
| **M8** | The harness suite's wall clock in the forest world, against 93 s today | a scope decision for the Director, not a map change |
| **M9** | Standing on a stand: the drop (must be zero), whether a shot clears the rail, whether the drive is visible over the brush | `Map.STAND`'s numbers, or `Match.CONFIG.STAND_HEIGHT_STUDS` — which is the drive owner's, so it is a report to them |
| **B** | *(still open since Task 43)* do `CollectionService` tags and terrain survive a save and a reopen? | fallback B: markers found by folder and name, changing only `Match.Markers`. **Never ship tags and names both** |

---

## 15. Numeric targets

**K** = Karen's taste value: a number she changes after walking it, not a measurement.
Derived at **1 stud = 0.28 m**.

### 15.1 The forest and its roads

| Quantity | Value | K? | Basis |
|---|---|---|---|
| Map size | **3,072 × 3,072 studs** (860 m, 74 ha), centred on the origin | | four blocks of ~15 ha plus roads and a rim; 1.5 × `StreamingTargetRadius` from centre to edge |
| `GROUND_Y` | **0** | | matches `Boar.CONFIG.field.groundY`, so no boar change |
| Relief, outside a block (`RELIEF`) | **± 64 studs** (18 m) | K | "mountains a bit"; stays under `BAND_Y.max − 8`, which is what lets §5.4 omit 484 upper passes |
| Relief inside a block (`BLOCK_RELIEF`) | **± 28 studs** (8 m) | K | rolling ground in the drive; 28 studs over a ~450-stud half-wavelength is 3.6° |
| Relief within `BENCH_BAND` of a road | **± 6 studs** | | 6 over a 26-stud verge is 13.0°, inside the 15° ceiling |
| `BENCH_BAND` | **140 studs**, smoothstepped | | |
| Rim (`EDGE_MAX_Y` / `EDGE_BAND`) | **120 studs / outer 400**, as a floor, suppressed in a road's lateral band | | 34 m of hill; a floor keeps the maximum at 120, inside `BAND_Y.max` |
| `BAND_Y` | **{ −24, +120 }**, two passes: **[−24, +72]** (96 studs, the measured region) and **[+72, +120]** | | §5.4 |
| `CORRIDOR_MAX_SLOPE_DEG` | **15°**, enforced inside **all four** blocks, over three seeds | | conservative (§12 source 1's silence on walkable slope) |
| Main road | along x at **z = −140**, halfWidth **10** (20 studs, **5.60 m**), verge **26**, keepClear **4**, x ∈ [−1,440, 1,440] | K | brief: main 5–5.5 m; cleared corridor 28 studs = 7.8 m |
| Centre ride | along z at **x = 0**, halfWidth **7** (14 studs, **3.92 m**), verge **24**, keepClear **4** | K | brief: 3.5–4.5 m; cleared corridor 22 studs = **6.2 m** |
| South ride | along x at **z = −1,260**, as the centre ride | K | blocks 3 and 4's shooter road |
| Assembly track | along x at **z = +1,300**, halfWidth **5**, verge **20**, keepClear **4** | | the drivers form up and walk in; it also flattens the 1,120-stud `DriverStart` |
| Bench taper | **60 studs** at each end | | a road runs out, it does not end in a cliff |

### 15.2 The blocks, and block 1's drive

| Block | x | z | studs | ha | line road | drive length | content |
|---|---|---|---|---|---|---|---|
| **block1** (NW) | −1,440 … −14 | −126 … +1,286 | 1,426 × 1,412 | **15.8** | `main` | 1,426 | **built now** |
| block2 (NE) | +14 … +1,440 | −126 … +1,286 | 1,426 × 1,412 | 15.8 | `main` | 1,426 | layout only |
| block3 (SW) | −1,440 … −14 | −1,246 … −154 | 1,426 × 1,092 | 12.2 | `south` | 1,106 | layout only (its first 300 studs are block 1's crossing band) |
| block4 (SE) | +14 … +1,440 | −1,246 … −154 | 1,426 × 1,092 | 12.2 | `south` | 1,106 | layout only |

| Block 1's drive | Value | K? | Basis |
|---|---|---|---|
| Shooter stands | **8**, spacing **160 studs** (45 m), span 1,120, centred at x = **−727** | K | 8 shooters of 16 players; the brief's reality is 300 m, compressed ~6× so a 10-minute drive ends (§15.4) |
| Stand offset / floor | **z = −160** (20 studs behind the road centreline), floor top **7.1 studs** (2.0 m) | K | brief: a driven-hunt stand floor is 1.8–2 m; 10 studs clear of the gravel edge |
| Post marker | **6 × 1 × 6**, bottom face **on the floor** | | §7.3; `Match.Body` untouched |
| Drive line part | **1,426 × 1 × 1** at z = −140, `LookVector` → **+Z** | | the block's full width |
| Driver start | part **1,120 × 1 × 20** at z = +1,300, centred at x = −727 | | 8 drivers ~140 studs (39 m) apart |
| Drive length (start → line) | **1,440 studs** (403 m) | K | ~90 s at `WalkSpeed` 16 |
| Boar spawns | **4** at z = **+1,180**, x = **−1,177, −877, −577, −277** | K | 120 studs inside the block; 300 studs apart, so pads never overlap |
| Spawn pad | radius **30**, blend **40**, tolerance **0.75** | | unchanged and measured; a sounder of five spawns inside one |
| `exitZ` | **−260** (120 studs past the road) | | the boar crosses the gravel and is gone in trees |
| `Map.FIELD` (block 1) | bounds x ∈ [−1,440, −14], z ∈ [−320, +1,286]; `exitZ = −260`; `groundY = 0` | | `Boar.CONFIG.field` becomes the same numbers, in the boar's own file, at the switch |
| Tie trees | **12** at z = **−200**, span 1,120 | | behind the line in the crossing band: within sight of the stand they left, never between a shooter and the drive |
| Crossing band | block 3's first **300 studs** (z ∈ [−454, −154]), at block 1's `drive` density | | 3.35 ha; what makes the crossing forest-to-forest |

### 15.3 The wood of block 1

| Quantity | Value | K? | Basis |
|---|---|---|---|
| Candidate spacing / jitter | **30 studs / 0.5** | | jitter 0.5 is forced by §6.3: a 15-stud minimum separation against the boar's 4-stud need |
| Density (dense / drive / backdrop) | **1.00 / 0.34 / 0.12** | K | the single biggest lever on both "does it read as a wood" and the frame time |
| Dense band | within **240 studs** of the line, \|x − (−727)\| ≤ **580** | K | where a shooter's eye actually is |
| Species mix | oak **0.56**, beech **0.18**, birch **0.12**, spruce **0.09**, alder **0.05** | K | brief 2: block 1 is old oak, with beech where we have it |
| Age mix | mature **0.78**, young **0.18**, veteran **0.04** | K | a managed oak stand with regeneration under it |
| Clump size / strength | **300 studs / 0.65** | K | clumps read at ~84 m, so the drive crosses stands rather than a species salad |
| Young patch | 1, radius **170**, spacing × **0.55**, weight **0.90**, all `young` | K | ~300 stems; the minimum gap is 7.35 studs (§6.3) |
| Gap (clearing) | 1, radius **130**, weight **0**, ground `rough`, double ferns and deadwood | K | somewhere a boar is visible and shootable |
| Wet ground | `h < −10` studs, smoothstepped over 6; alder forced, `wet` material, double ferns | | derived, not placed (§6.5) |
| Deadwood / brush / ferns | **1.6 / 34 / 34 per ha** → ~31 / ~650 / ~650 | K | all non-collidable, non-queryable |
| Trees planted (estimate) | **≈1,300** (dense ~291, drive ~662, young patch ~300, crossing band ~162, exclusions −115) | | ceiling `Map.BUDGET.trees = 1800`; **the Builder measures the real number** (M6) and the step fails over budget |
| Stems per hectare | **≈68** against reality's 400–800 | | §13.1, stated rather than discovered |
| Tree parts | **2** per tree (MeshPart + trunk collider) | | §10.2 |
| Declared triangles | mature/young/veteran **6,000**, backdrop **3,000** | | the brief's seller figures; confirmed by M1 |
| `visibleTris` bound | **≤ 7,000,000** at every stand and the driver start | | §13.2, pure and asserted |
| Total parts, block 1 | **≈ 3,800** of `Map.BUDGET.parts = 20000` | | 1,300×2 + 650 + 650 + 31×3 + 80 (stands) + 32 (stakes) + 14 (markers) + 24 (tie trees) |
| Visible parts | target **≤ 8,000** | | at `targetRadius = 1,024` |
| Proxy albedo floor | **no channel maximum below 120** | | the Task 22 measurement: an unlit face renders at ~0.275 × albedo and RGB(90, 80, 70) went near-black |

### 15.4 What is at scale and what is not — say it before Karen asks

| Quantity | Reality (brief 3) | Here | Ratio |
|---|---|---|---|
| Shot distance | 60–80 m | a crossing boar at 6–25 m; the longest shot down the drive ~45 m | **≈ 1:1** |
| Stand floor | 1.8–2.0 m | 2.0 m | **1:1** |
| Road width / cleared corridor | 3.5–4.5 m (main 5–5.5), 4.5–7 m | 3.92 m / 6.2 m; main 5.60 m / 7.8 m | **1:1** |
| Stand spacing | ~300 m | 45 m | **1:6.7** |
| Block area | 70–100 ha | 15.8 ha | **1:5** |

The things a player *feels through the sights* are at full scale; the things that decide how long a
drive takes and how many of sixteen players see an animal are compressed by five to seven. A 1:1 block
needs a ~7,000-stud map and ~2,300 terrain tiles, and 16 players spread over 300 m would mean most of
them see nothing in ten minutes.

### 15.5 The generator and the run

| Quantity | Target | Basis |
|---|---|---|
| Voxel resolution | **4** | measured: 8 and 2 are both refused |
| Region per `WriteVoxels` | **128 × 128 × 96** (lower pass) and **128 × 128 × 48** (upper) | the measured size, and a smaller one; §5.4 |
| Steps per build | **≈714** (1 clear, 1 palette, 1 materials, 668 terrain, 12 trees, 2 patch, 12 brush, 12 ferns, 1 deadwood, 1 stands, 1 tieTrees, 1 furniture, 1 markers, 1 settings) | §9.1 |
| Per-step wall clock | **≤ 60 s**, hard timeout `MAPGEN_CALL_TIMEOUT = 180 s` | `Studio._rpc` defaults to 120 s |
| Full build | **≤ 40 min** | edit time, so slow is fine and unrepeatable is not; **measured** (M5) |
| Determinism | **identical digest** from two builds at one seed | hard requirement; `mapgen.py verify` fails otherwise |
| `DIGEST_TERRAIN_SAMPLES` | 4,096 (64 × 64), round 100, plus the palette **and the variant table** | §8.2 |
| `REACH_SETTLE_SECONDS` | **6** | measured: the navmesh lags the map by ~5 s |
| Reachability computes | **5 froms × 5 targets = 25** | unchanged |
| `BACKUP_MAX_AGE_HOURS` | 6 | unchanged |

---

## 16. Build order, for block 1 only

One task per round (rule 4), smallest first, each green and reviewable on its own.
**`Map.EXPECTED_WORLD` stays `"map:v1"` until B1g**, so none of B1a–B1f changes what a player stands in.

**The rule that makes that safe, stated once:** a step that changes the BUILT world's shape must
(a) express the change as a **contract field the live check reads** (`Map.STAND.floorStuds` is the
worked example: 0 today, 7.1 the day the stands are built, one check either way), and (b) **be
accompanied by a rebuild of the place in the same round** — `python tools/mapgen.py build --seed N
--backup <accepted>`, whose `[mapgen] OK:` line goes in the request beside the harness line. A step
whose world nobody looked at is the failure mode this project has already paid for.

| # | Task | Scope | Evidence |
|---|---|---|---|
| **B1a** | **The forest grid and the ground.** No props, no stands, no trees | `Map` (`SIZE_STUDS`, `ROADS`, `BLOCKS`, `ACTIVE_BLOCK`, `STAND` with `floorStuds = 0`, `BUDGET`, `FIELD` for block 1, `PALETTE.wet`); `Config` (`BLOCKS`, `ROADS`, relief and band numbers, `INCLUDE` for the retired layers); `Height` (`blockFalloff`, the new rim); `Layout` (`blocks`, `blockAt`, `activeBlock`, `roads`, `onRoadKeepClear`, `tiles` per band pass, `markers` from the active block, `wetAt`); `Ground` (band pass, the `wet` case); `Digest`; `init` (the plan); `mapgen.py` (shots); the specs | build + `verify` (same digest twice) + `reach` + `contract`; `forest-wide`, `forest-edge`, `block1-hills`, `block1-road` inspected; M4, M5 |
| **B1b** | **The stand**, and the post marker on its floor | `Config.STAND`, `Map.STAND.floorStuds = 7.1`, `Props.stands`, `Layout.standPoints`, `Markers.place`'s Y, the two contract checks (§14.1 cases 4 and 5), the road guard's `keepClear` | rebuild; `block1-stand` and `block1-road` inspected; M9. **Karen stands on one** |
| **B1c** | **The wood of block 1**, as proxies | `Config.SPECIES`/`AGE`/patches, `Scatter.ageAt`/`patchCentres`/`patchTrees`, `Layout.treeDensity`/`treeBlocks`/`visibleLoad`, `Props.trees` in the mesh+collider shape, the crossing band, the walkability and species specs, the budgets | rebuild; counts and `visibleLoad` (M6); `reach` green at 25 routes; `block1-oak`, `block1-young`, `block1-gap`, `block1-crossing` inspected |
| **B1d** | **The real oak**, and one id table | `ServerStorage.Assets` rows (route A), `Props` onto `Assets.Loader` with `setCacheParent`, `MapGen.Assets` archived (rule 7) — closes `TASKS.md` row 74a(a) | M2; rebuild; `block1-oak` and `block1-stand` inspected; M7 |
| **B1e** | **The forest floor**: deadwood, brush, ferns, wet ground | `Props.deadwood`/`ferns`, `Scatter.deadwood`/`ferns`, the `wet` material and fern rules | rebuild; `block1-deadwood`, `block1-wet` inspected |
| **B1f** | **The CC0 terrain materials** | four `image` rows in `Assets` (uploaded by hand, §8.3), `Map.TERRAIN`, `Ground.applyVariants`/`readVariants`/`clearVariants`, `clear`'s `variantsRemoved`, the contract case | M3; rebuild; `block1-road`, `block1-oak`, `block1-wet` inspected |
| **B1g** | **The switch to `map:v2`** | `Map.EXPECTED_WORLD`, `SEED`, `DIGEST`, `FIELD`, and **`Boar.CONFIG.field` to the same numbers in the boar's own file** | §17; **Karen walks it**; M7, M8 |
| later | Blocks 2–4's content, with the 9-species pack | each block one task: its `character` table and `content = true` | the same shots, per block |
| M2.6 | **Streaming on**, alone, with a playtest | `Settings.MAY_WRITE = true`, the four Studio-panel values by hand (Karen) | a full harness re-run plus a playtest |

### 16.1 What Karen checks when she first walks block 1 (3–5 things)

1. **Stand on a stand and look down the road.** Eight stands at 45 m: a hunting line, or a firing
   range? And is 2 m up right, or do you want to see further?
2. **Look into the drive from the floorboards.** Can you see far enough to shoot? How often does a shot
   hit a trunk instead of the boar — and is that right?
3. **Walk the drive from the assembly track to the road.** Dark enough to hide a boar, open enough to
   walk? Do the young patch and the gap read as a real wood's variety?
4. **Watch a boar cross.** Is the road a gap worth watching, and does the far wood look like somewhere
   it went?
5. **The hills and the colours**: "mountains a bit", or flat? Autumn oak, or mud?

---

## 17. The switch, and the rollback

`Map.EXPECTED_WORLD` and `Map.ACTIVE_BLOCK` are two committed strings, read by
`tests/server/map_contract.spec.luau` and by `src/server/ArenaBoot.server.luau`. The order, with every
human action in it:

1. Backup: `--backup census` if its conditions hold (no human), else Karen's `File → Save to File`
   outside the repo (`NEEDS KAREN`).
2. `python tools/mapgen.py build --seed <N> --backup <accepted>`.
3. `contract`, `reach`, `shots`; the Builder inspects all eleven images.
4. Save: Karen `File → Save to Roblox`, or the Director posts Alt+Shift+S. **Nothing here can verify
   it** (`TASKS.md` row 79a(j): the last attempt showed no confirmation dialog).
5. Reopen; `contract` again, and compare the marker digest — this is measurement **B**.
6. The code commit sets `Map.EXPECTED_WORLD = "map:v2"`, `Map.SEED`, `Map.DIGEST`, `Map.FIELD`
   (§15.2's block 1 rectangle) **and `Boar.CONFIG.field` to the same numbers** — a data change inside
   `ServerScriptService.Boar`'s own file, by its owner.
7. Harness run (`test`; `test2` is **N/A** — `TWO_PLAYER_PATHS` in `tools/agents.py` is the match, the
   drive, the tie and the teams, and none of this touches them. The forest behaves the same with one
   player as with two. The exception is M7's two-player frame time, which is a **measurement the
   Director takes**, not a gate).
8. **Karen walks it.** The feel gate; nothing here can judge it.
9. Only after Karen accepts: a separate task archives `src/server/TestArena.luau`,
   `src/server/ArenaBoot.server.luau` and `tests/server/test_arena.spec.luau` (rule 7).

**The rollback.** `"map:v1"`'s generator no longer exists in the working tree, so the rollback is
**`git revert` of the v4 commits plus `python tools/mapgen.py clear --backup <accepted>` and a
rebuild** — not a one-string flip. That is a real cost of a revision this size and it is why §16's
every step keeps `EXPECTED_WORLD` at `"map:v1"` until the end: until B1g the rollback is "do not
rebuild the place", which costs nothing.

---

## 18. Deltas and dispositions

### 18.1 Corrections this design imposes on other documents

**A — Architect-owned (named here for the next regeneration):**

- **A1.** This file replaces `docs/design/map-generator.md` (v3) **in full**.
- **A2. `docs/design/asset-pipeline.md`** needs, at its next regeneration: a `"bought"` value for
  `Source`; a `kind = "mesh"` row shape plus the `CreateMeshPartAsync` route (§11.2) **or** a line
  recording that route A made it unnecessary; the tree and image keys of §6.1 and §8.1 in its §12.1
  table; and the note that `MapGen.Assets` is archived, which closes its own §12.2.
- **A3. `docs/design/drive.md`** needs two lines: that the drive runs in **the block
  `Map.ACTIVE_BLOCK` names**, and that per-match block rotation would be a change to `Match.Markers`
  (§4.2, §19 D). Its §6.1 marker table also still carries the arena's coordinates.
- **A4. `docs/design/boar-ai.md` / `boar-behaviour.md`**: the escape axis is **−Z** in
  `Brain:_outcome` and `Brain._fleeTarget`, and this design is built around it. If a later block wants
  a different axis, that is a boar change and the design should say where.

**B — the Builder's, in files the Architect never edits:**

- **B1.** A research note before code (rule 1): the forest-structure sources behind §15's real numbers,
  the oak pack's licence quote, the CC0 licences, and measurements M1–M9 plus B. Add it to
  `docs/research/INDEX.md`.
- **B2.** **Code comments cite the design by heading text, not by section number** — the rule v3 §19.1
  B1 introduced after three reviews spent on stale citations. Every comment this revision touches gets
  the new form.
- **B3. `GAME_DESIGN.md`**: the generated-map row gains the four blocks, the active-block string, the
  stands and the material variants; the map-contract row gains `ACTIVE_BLOCK`, `ROADS`, `BLOCKS`,
  `STAND` and `TERRAIN`; the manifest and id-seam rows lose "`MapGen.Assets` still exists" at B1d.
- **B4. `backups/`**: `MapGen/Assets.luau` (B1d), and `Config.WORLD.bog` plus `Layout.bogDepth`
  (§6.5), each with a note.
- **B5. `TASKS.md`**: row 74a(a) is closed by B1d; rows 79a(b) (a shot camera at crown height) and
  79a(a) (nine shots against a design's eight) are closed by §14.3 and §14.4; row 79a(l) (no
  `SpawnLocation` in the map world) is **still open and is not this design's** — where a player stands
  before the drive claims them is `Match.Body`'s, and §19 F puts it to the Director.

### 18.2 v3's queued notes, and what this design does with each

| Row | Disposition |
|---|---|
| 79a(a) — nine shots, a tool that says seven, a design that says eight | **closed**: §14.3's eleven, and the counts are derived (§14.4) |
| 79a(b) — `map-drive`'s camera is up among the crowns | **closed**: `block1-hills` and `block1-stand` are at eye height, and each shot carries its question |
| 79a(c) — `map-wide` is lost in fog | **open and not ours**: that is the place's `Lighting`, which this system may never write (§1.2). A `TASKS.md` row for the art task |
| 79a(d) — the wood reads as a colonnade | **answered by the real meshes** (§11) and by brush, ferns and the young patch at eye level. Karen judges |
| 79a(e) — the autumn is patchy | **Karen's** (§19 Karen 5) |
| 79a(f) — the posts do not read from the road | **answered twice**: a 7-stud timber stand is visible, and the orange-capped stakes stay |
| 79a(h) — §17's step list assumes switch and save together | **closed**: §17 keeps them separate and §16 states the rebuild rule |
| 79a(l) — no `SpawnLocation` in the map world | **open, and it has an owner question**: §19 F |
| 44a(c) — the bog reads dry | **closed by deletion**: wet ground is derived from hollows (§6.5) |
| 43a(h) — the arena spec spells the tags literally | **keep, and comment as deliberate**: a spec that re-derives the contract from the contract checks nothing |
| 43a(m) — functions with no reader | §6.6 keeps the hedge and field mechanisms behind `INCLUDE` with live callers rather than orphaning them |

---

## 19. Open decisions

**None of these blocks building B1a.** Each has a working default, in `Config` or in this document,
changeable by one value.

### Already decided, recorded so they are not reopened

`reviews/task-121/BRIEF.md`, the Director carrying Karen, 2026-10-04: **one forest, four blocks divided
by forest roads**; **a drive is one block**; **every block a realistic mix**; **block 1 is old oak with
a young patch and a gap**; **the bought oak pack**; **CC0 ground textures**; **our own timber stand**;
**the map switch stays a commit**; **the arena stays the default until Karen sees the forest**. And
Karen, 2026-10-04: *"do all without me until first forrest"* — every taste call below runs on its
default until she walks it.

### For Karen (feel and taste — nobody else can answer)

1. **Stand spacing: 160 studs (45 m), 8 stands, a 1,120-stud line**, in a block whose real-world twin
   would space them 300 m. Walk it. And note §12 source 8: at this spacing the DJV's 30° neighbour rule
   bites, which makes `TASKS.md` row 35a a real rule.
2. **How thick the wood is** — 1.00 / 0.34 / 0.12 and ~68 stems/ha against reality's 400–800 (§13.1).
   The single biggest lever on whether the drive is fun, and the one the frame time constrains.
3. **Should a crown stop a shot?** Today trunks do and leaves do not (§10.2), because an invisible
   convex blob that eats slugs is unexplainable on screen. If a shot stopped by the canopy feels right,
   it is one `CanQuery` and one `CollisionFidelity`.
4. **The stand**: 2 m up, 7 studs square, a rail at 3.6, a ladder, a roof. Height, size, and whether
   you want to climb it rather than be placed on it.
5. **The autumn palette and the hills**: four colours, oak at 0.56 of the mix, ±18 m of roll and a
   34 m rim. Numbers she changes after looking.
6. **Should deadwood collide?** No today, because the boar's agent cannot jump (§6.3 item 6). A
   collidable log needs a proved gap and a reachability run.
7. **Blocks 2 and 4 are bare ground in this task** and are visible in `forest-wide`. Is that acceptable
   while block 1 is judged, or should they carry the backdrop tier at 0.12 (about +900 trees and a frame
   time cost)?

### For the Director (scope)

A. **The map grows from 2,048 to 3,072 studs.** It costs 668 terrain steps against 256, a build of
   ≤ 40 min against 22 s, and a slower harness on every run (M8, and Task 79a(i) measured 412 s against
   93 s the last time the world was full). **Recommendation: accept.** Four blocks of 15 ha cannot fit
   in 2,048 studs with a 1,120-stud shooter line, and 1:1 blocks would need 7,000 studs and ~2,300
   tiles.

B. **2×2, not four in a row.** Each block then borders two roads, each drive looks a different way, and
   the map stays square so the streaming circle wastes less. Four in a row needs five parallel roads
   and makes every drive the same view. **Recommendation: confirm.**

C. **The oak arrives as route A** — each tree published once as a **private** Model asset in Karen's
   account, recorded as an `Assets` row, loaded through the existing `Assets.Loader` (§11.1). It costs
   3–5 human clicks and no new engine code. Route B is named and costed. **Recommendation: A, and
   confirm the asset must never be listed on the Creator Store** (the EULA forbids redistribution).

D. **Markers exist for one block, named by a committed string.** Per-match block rotation is **out of
   scope** and needs `Match.Markers` to read *a* block — a drive-design change with its own round.
   **Recommendation: confirm, and queue the rotation as a drive task after Karen has played one block.**

E. **European farmland is not in this map.** The brief says one big forest, and four blocks fill the
   3,072 studs. The mechanism is switched off, not deleted (§6.6). **Recommendation: accept, and decide
   later whether farmland is an outer margin, a fifth block, or a second map.**

F. **There is still no `SpawnLocation` in the map world** (`TASKS.md` row 79a(l)). A joining player gets
   Roblox's origin fallback until the drive places them — at the origin, which in v4 is the crossroads
   of two forest roads. It is not broken, and it is not this system's call: the map builds geometry,
   `Match.Body` places players. **Recommendation: decide the owner now** — either the map builds a
   tagged spawn pad beside the assembly track (one marker kind, one `EXPECTED_COUNTS` row) or
   `Match.Body` places a waiting player on the driver start.

G. **The CC0 textures need a human upload** (§8.3), because `tools/roblox_upload.py` is Model-only by
   design. **Recommendation: four Asset Manager clicks by the Director, ids recorded in `Assets`,**
   rather than growing the upload tool in the middle of a map task.

H. **M3 (terrain MaterialVariants) and M7 (frame time) are the two measurements that can send a step
   back.** If M3 fails, the forest ships on the measured palette and §8.1's step reports it. If M7
   fails, the answer is `TREE_DENSITY.drive`, then `TREE_SPACING`, then `targetRadius` — **each a
   `TASKS.md` row with the measurement attached, never a quiet tweak.**
