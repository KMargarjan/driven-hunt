# Design: map-generator (the v1 map, built by code at edit time)

System: `map-generator` — the Luau code that writes the v1 map (terrain, fields, hedgerows, tree
stands, tracks, a bog, the drive corridor and every gameplay marker) into the DEV place at **edit
time**, and the tool that invokes it. `ROADMAP.md` Milestone 2. Task 33.

Architect, 2026-09-25, read-only session: Read, Grep, Glob only. No Studio, no network. Evidence
precomputed in `.agent-evidence/` (`INDEX.md`), commit `8fb37af8c566e1c547500db86714a7fe4dc53524`.

Inputs, in precedence order: `reviews/task-33/BRIEF.md` (the Director's and Karen's decisions),
`docs/research/2026-09-24-map-generator.md` (rule 1, 13 sources), the code on this commit
(`src/server/TestArena.luau`, `src/server/ArenaBoot.server.luau`, `src/server/Boar/`,
`tools/studio_mcp.py`), `docs/design/drive.md` (the marker contract), `CLAUDE.md`, `ROADMAP.md`,
`GAME_DESIGN.md`, `TASKS.md`, `docs/PROJECT_CONTEXT.md`.

**Nothing here is built until Milestone 1 is closed by Karen's two-player playtest** (the brief says
so). This document exists so that when it starts, it starts from a design.

**Test of this document:** a Builder can build M2.1 from it without asking a question. Every owner is
named, every interface is written out, every number is here, and every Karen click is listed in one
place (§13).

---

## 0. Four facts this design is built on, stated first because they decide everything

1. **The harness is read-only by construction and must stay that way.**
   `tools/studio_mcp.py`'s docstring, "Safety": *"Its Luau is read-only: constant queries, or queries
   templated with JSON data (QUERY_*). There is no command for arbitrary Luau or arbitrary MCP
   tools."* A generator is the opposite of that. **The generator is therefore invoked by a second,
   separate tool, `tools/mapgen.py`** (§6), which imports `studio_mcp.py`'s `Studio` class and its
   `luau_json`, `git_state`, `expected_place_id` and `find_exe` helpers rather than copying them.
   `studio_mcp.py` gains no write path, no new subcommand and no new MCP tool. If a later task is
   tempted to add `python tools/studio_mcp.py generate`, that is a design violation: the file that
   decides whether a PR may be reviewed must not also be the file that can rewrite the world.

2. **`execute_luau` has its own module cache, and a `require()` through it returns a fresh copy of
   the module** — measured twice, 2026-09-25 and again in Task 26, and recorded in
   `tools/studio_mcp.py`'s docstring ("Staging a scenario"). So **no generator state may survive
   between MCP calls.** Every step is a pure function of `(seed, stepIndex)` and the world as it
   already stands (§5.4). This is not a nuisance; it is what forces the generator to be
   reproducible, which is the whole point of map option C.

3. **Workspace is not Rojo-mapped** (`CLAUDE.md`, Layout: *"Workspace, Lighting and the other
   services are not mapped"*), so the generated map is **not in git and has no rollback but a
   place-file backup**. What is in git is the **seed, the code and the digest** (§6.4). The harness
   never sees generated geometry: its check 4 walks the Rojo sourcemap, and its check 5 scans for
   `LuaSourceContainer` only (`tools/studio_mcp.py`, `QUERY_ALL_SCRIPTS`). That last point is a trap,
   not a comfort — §8.4.

4. **A boar is a physics body on a horizontal velocity plane, and it spawns at a fixed Y.**
   `src/server/Boar/Body.luau`, `Body.create`, builds a `LinearVelocity` with
   `VelocityConstraintMode = Plane` and tangent axes X and Z, so gravity, not code, puts the boar on
   the ground — terrain relief is fine for *walking*. But `src/server/Boar/init.luau`,
   `Runtime:spawn`, overwrites the caller's Y:
   `at = Vector3.new(at.X, self._field.groundY + config.BODY_SIZE.Y / 2 + config.SPAWN_CLEARANCE, at.Z)`,
   with `SPAWN_CLEARANCE = 0.5`; and `src/server/Boar/Brain.luau`, `Brain:_outcome`, despawns a boar
   as `outOfBounds` at `position.Y < field.groundY - config.FALL_LIMIT` (`FALL_LIMIT = 50`).
   **So the generator must deliver a flat spawn pad and a bounded height band, or boars spawn inside
   hills** (§7.3). This design solves it entirely on the generator's side, with **no change to
   `ServerScriptService.Boar`**.

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

1. **Build one small v1 map**: European farmland and woods — fields, hedgerows, spruce and birch
   stands, tracks, a bog — with a drive area and a shooter line along a wood edge (Karen, brief).
2. **Run at edit time only**, through the Studio MCP server, from code on disk. Never at run time,
   never in a live server, never on Play.
3. **Be reproducible from a seed**: the same commit and the same seed give the same map, provable by
   a digest (§6.4).
4. **Place every gameplay marker as a tagged, script-free instance** that `docs/design/drive.md`'s
   `Match.Markers` already knows how to read (§4.2).
5. **Reference every art asset by id, never by file**, with a provenance manifest on disk (§8).
6. **Be undoable**: a place-file backup before every run (a Karen click, gated by the tool), and
   `MapGen.clear()` as the in-place reset.
7. **Be checkable by machine**: a server spec that the required tags exist, are geometrically sane,
   and are **reachable by the boar's own pathfinding agent** (§12.1); a client spec for streaming
   (§12.2); named Edit-mode screenshots for rule 5 (§12.3).
8. **Replace `Workspace.TestArena` with no overlap** — never two grounds, decided by one committed
   fact (§9).
9. **Cost the harness nothing**: no `default.project.json` change (so no Karen Connect click), no new
   Wally package, no `.rbxm`, no typed value in a `.model.json` (§7).

### 1.2 Must not

Each row is a named failure from `docs/PROJECT_CONTEXT.md` or a boundary an existing design drew.

| Prohibition | Why | Whose job instead |
|---|---|---|
| Never run at run time. No `.server.luau`, no `.client.luau`, no `init.server.luau` anywhere under the generator | "Invented foundations": a map that rebuilds itself on every server start is a second writer of the world that nobody can see | `tools/mapgen.py`, at edit time, by hand |
| Never be `require`d by any runtime script | the runtime must not depend on a build tool. §12.1 check 9 asserts `ServerStorage.MapGen` contains only ModuleScripts, so nothing can autorun | game code requires `ReplicatedStorage.Map`, the contract (§4) |
| Never write a script, or place an asset that contains one | `CLAUDE.md`: "Nothing script-like (Script, LocalScript, ModuleScript) is ever created in Studio", and harness check 5 fails the whole run if one exists outside the sourcemap. A free model with a Script in it would do exactly that | §8.4: the generator **refuses** such an asset by id and reports it |
| Never write `Workspace.TestArena`, `Workspace.Boars`, `Workspace.WeaponEffects` or `Workspace.DriveMarkers` | four named owners: `ServerScriptService.TestArena` (`src/server/TestArena.luau` header), `ServerScriptService.Boar`, `PlayerScripts.Weapon.Effects`, `Match.Body` (`docs/design/drive.md` §6.4) | those owners |
| Never write `Boar.CONFIG`, `Shotgun.CONFIG`, `Match.CONFIG` or any runtime state | one writer per system | their owners; the map **publishes** its rectangle and the boar's config is checked against it (§10) |
| Never create a `Water` terrain material in v1 | water changes buoyancy and swimming, and the boar's mover is a horizontal-plane `LinearVelocity` (`src/server/Boar/Body.luau`, `Body.create`) that was never designed to swim. The bog is `Mud` and a dip, not a pond | a v1.1 task, with its own boar work |
| Never touch `Lighting`, `SoundService`, `Teams` or any player | art, sound and the match are other tasks; `Match.Body` is the only writer of `Teams` and of player characters (`docs/design/drive.md` §3.2) | Milestone 2's art task; `Match.Body` |
| Never commit a Creator Store or Meshy binary, a `.rbxm`, a `.rbxmx` or a `.rbxl` | `CLAUDE.md` bans the first four outright; the place file is worse (research note §10) and the repo is public and the licence is use-on-Roblox, not redistribution (research note §8) | ids in `Assets.luau`; backups outside the repo |
| Never add a subcommand, a write path or an MCP tool to `tools/studio_mcp.py` | §0 item 1 | `tools/mapgen.py` |
| Never delete a file to make a map (rule 7) | rule 7 | `MapGen.clear()` destroys *generated runtime instances*, which are not files; disk files are archived to `backups/` |

**One predicate answers one question.** `Map.EXPECTED_WORLD` says which world the committed code
expects. It does not say whether the arena should be built, whether streaming is on, or whether the
map is any good. Those are read from the contract's own fields (§4.1), asserted by §12.1, and judged
by Karen.

---

## 2. Ownership

Rule 3: exactly one writer per system, named here, mirrored into `GAME_DESIGN.md` when the code lands.

### 2.1 The owner table (paste into `GAME_DESIGN.md` with the first map task)

| System | Owner (the only writer) | Location on disk → Studio |
|---|---|---|
| **The map contract**: tag names, the drive rectangle, the expected world, the streaming and budget numbers. Frozen data, **no runtime writer at all** | `ReplicatedStorage.Map` — nothing writes it; the Builder edits the file, git records it | `src/shared/Map/init.luau` → `ReplicatedStorage.Map` |
| **The map generator**: `Terrain`, `Workspace.DrivenHuntMap` and everything in it, and the `Workspace` streaming properties. **Edit time only** | `ServerStorage.MapGen` — and within it, exactly three modules touch the world: `Ground` (Terrain), `Props` (`…Map.Props`), `Markers` (`…Map.Markers` and every `CollectionService:AddTag` in the map). `Settings` is the only writer of the Workspace streaming properties | `src/serverstorage/MapGen/` → `ServerStorage.MapGen` |
| **The asset manifest** (id, name, creator, source, licence note, date, version, kind, budget) | `ServerStorage.MapGen.Assets` — a plain Luau table; the Builder edits the file, Karen supplies the ids | `src/serverstorage/MapGen/Assets.luau` |
| **The generator invoker**: the one write path into Studio | `tools/mapgen.py`. It is the only thing in the repo that sends a mutating `execute_luau`, and the only caller of `insert_asset` | `tools/mapgen.py` |
| **The markers the game reads** (`DrivenHunt.*` tags) | **at edit time:** `MapGen.Markers` in the generated map, `ServerScriptService.TestArena` in the grey box — never both (§9). **At run time: nobody writes them.** `Match.Markers` reads them (`docs/design/drive.md` §6.2) | as above |
| World geometry: test arena | **unchanged:** `ServerScriptService.TestArena`, booted by `ArenaBoot`, which gains one early return (§9.2) | `src/server/TestArena.luau` |

### 2.2 The modules inside `ServerStorage.MapGen`

`init.luau` plus siblings, the shape `src/server/Boar/` and `src/server/Weapon/` already prove green
(`TASKS.md` rows 18 and 24): a folder with `init.luau` takes its siblings as children. **Nothing
happens on `require`** — the same rule `src/server/Boar/init.luau` states in its header.

| Module | Is | Never |
|---|---|---|
| `init.luau` | **the entry point**: `VERSION`, `CONFIG`, `steps`, `runStep`, `clear`, `digest`, `verifyContract`. Holds no state between calls (§0 item 2) | decides a layout rule itself; writes a voxel |
| `Config.luau` | **pure data**: every number in §11, frozen with `Shotgun.deepFreeze` (`src/shared/Shotgun/init.luau`, `Shotgun.deepFreeze`) — **required, not copied**, because `table.freeze` is shallow and this repo has paid for that once (`TASKS.md` row 23a(b)) | anything else |
| `Height.luau` | **pure**: `Height.at(x, z, seed, config) -> number`, domain-warped `math.noise`. The single source of ground height, called by `Ground`, `Props`, `Markers` and the digest, so nothing can disagree about where the ground is | touches Terrain, Instances, services or `Random` |
| `Layout.luau` | **pure**: the corridor, the shooter line, the post positions, the driver start, the boar spawns, the hedgerow polylines, the stand polygons, the track splines and the bog disc — all as plain tables of numbers | as above |
| `Scatter.luau` | **pure**: seeded placement (Poisson-ish jittered grid) of trees and props inside a polygon, rejecting the corridor, the tracks and the bog | as above |
| `Assets.luau` | **pure data**: the manifest (§8) | as above |
| `Digest.luau` | **pure**: a canonical string digest of a plan plus a terrain sample set (§6.4) | as above |
| `Ground.luau` | **the only writer of `Terrain` in the repo**: one tile per call, `Terrain:WriteVoxels` | reads or writes any Instance |
| `Props.luau` | **the only writer of `Workspace.DrivenHuntMap.Props`**: inserts an asset once per run, clones it, anchors it, destroys the template at the end of the run | writes Terrain or a marker |
| `Markers.luau` | **the only writer of `Workspace.DrivenHuntMap.Markers`** and the only caller of `CollectionService:AddTag` in the generated map | writes Terrain or a prop |
| `Settings.luau` | **the only writer of `Workspace.StreamingEnabled`, `StreamingMinRadius`, `StreamingTargetRadius`, `StreamingIntegrityMode`, `ModelStreamingBehavior`** | writes anything else |

`Height`, `Layout`, `Scatter` and `Digest` are exported as `MapGen.Height`, `MapGen.Layout`… for
specs, exactly as `src/server/Boar/init.luau` exports `Boar.Brain`, and for the same reason: the pure
core must be drivable with no Studio, no Terrain and no assets. **That is what lets a server spec
test the generator's maths in the normal harness run, while the generator itself never runs there.**

---

## 3. Where a run happens, in one picture

```
 disk (git)                    tools/mapgen.py                  Studio, Edit mode
 ──────────                    ───────────────                  ─────────────────
 src/serverstorage/MapGen/ ──Rojo──────────────────────────────► ServerStorage.MapGen  (ModuleScripts)
 src/shared/Map/init.luau  ──Rojo──────────────────────────────► ReplicatedStorage.Map (the contract)
                                │
                                │ 0. refuse: dirty tree / not Edit / wrong PlaceId /
                                │    no fresh --backup / Studio's MapGen source ≠ disk
                                │ 1. execute_luau  MapGen.clear()
                                │ 2. execute_luau  MapGen.runStep(i, seed)   × N   ──► Terrain
                                │    (one call per step; no state survives a call)  ──► Workspace.DrivenHuntMap
                                │ 3. execute_luau  MapGen.digest()
                                │ 4. screen_capture × 6  ──► .screenshots/
                                ▼
                       .mapgen/<utc>-<seed>.json (git-ignored run log)
                       "[mapgen] OK: 271/271 steps @ <sha> seed=7 digest=<hash> (clean tree)"
                                │
                                ▼  NEEDS KAREN: File → Save   (StudioMCP has no save tool)
                       the place now carries the map
```

---

## 4. The map contract — `ReplicatedStorage.Map`

`src/shared/Map/init.luau`, deep-frozen with `Shotgun.deepFreeze`. Tiny, data only, no behaviour.
It is **shared** rather than server-only for the reason `src/shared/Shotgun/` is: one file, one
`require` path, and the Hud may want the map's name later. It replicates a handful of numbers and no
secret.

### 4.1 The fields

```luau
export type FieldRect = {
    bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
    exitZ: number,
    groundY: number,
}

Map.VERSION          = "v1"
Map.EXPECTED_WORLD   = "arena"        -- or "map:v1"; THE switch, §9. One committed fact.
Map.SEED             = 0              -- the seed the committed map was built from; 0 while "arena"
Map.DIGEST           = ""             -- the digest that seed produced; "" while "arena"

Map.FIELD: FieldRect                  -- the DRIVE rectangle, not the whole map. Must equal
                                      -- Boar.CONFIG.field, asserted by §12.1 check 7.
Map.SIZE_STUDS       = 2048           -- the whole map, square, centred on the origin
Map.TAGS = {
    shooterPost = "DrivenHunt.ShooterPost",
    driveLine   = "DrivenHunt.DriveLine",
    driverStart = "DrivenHunt.DriverStart",
    boarSpawn   = "DrivenHunt.BoarSpawn",
    tree        = "DrivenHunt.Tree",
}
Map.EXPECTED_COUNTS  = { shooterPost = 8, driveLine = 1, driverStart = 1, boarSpawn = 4, tree = 12 }
Map.STREAMING        = { enabled = false, minRadius = 64, targetRadius = 1024,
                         integrityMode = "PauseOutsideLoadedArea", modelBehavior = "Improved" }
Map.BUDGET           = { parts = 20000, visibleParts = 8000, trees = 3000 }
Map.SPAWN_PAD        = { radius = 14, blend = 24, tolerance = 0.75 }  -- §7.3
```

### 4.2 The tag vocabulary has one home now

`docs/design/drive.md` §6.1 defines the five `DrivenHunt.*` tags and `Match.Markers` reads them. As
written, the tag **strings** would exist in three places: `TestArena.build`, `Match.Markers` and
`MapGen.Markers`. That is not a second writer, but it is three copies of one fact, and a typo in one
of them produces a silent empty `GetTagged` — the "two correct pieces of code disagreeing" shape.

**Decision: `Map.TAGS` is the one home for the strings.** `MapGen.Markers` writes them from there,
`Match.Markers` reads them from there, `TestArena` tags from there. Cost: one `require` in each.
If Task 32 (the drive) ships with literals before this lands, the swap is a three-line change inside
each owner's own file and belongs to the first map task — listed in §10 as a cross-system change, not
a blocker.

### 4.3 What the markers are, physically

Every marker is an **`Anchored`, `CanCollide = false`, `CanQuery = false`, `Transparency = 1` `Part`**
under `Workspace.DrivenHuntMap.Markers`, named for its kind and index (`ShooterPost1`…`ShooterPost8`),
sized as `docs/design/drive.md` §6.1 specifies (the drive line is one part, size `(560, 1, 1)`, its
`LookVector` pointing at **+Z**, toward the drivers), and tagged. Invisible and inert: a marker that
can be shot, walked into or collided with is a gameplay object pretending to be metadata.

`DrivenHunt.Tree` is the exception in kind: it goes on **≤ 12 real trunk parts near the shooter
line**, chosen by `Layout`, because it is the tie-up anchor (`docs/design/drive.md` §8.4) and a player
tied to a spruce 900 studs away is a teleport. **The forest's other ~2,988 trees are not tagged** —
`Match.Markers` would otherwise return 3,000 parts for a nearest-tree search that runs on every
violation.

---

## 5. The generator's public interface

Types are Luau annotations. `luau-lsp analyze` is not in CI (`TASKS.md` row 3), so they document and
help the editor; they are not a gate.

### 5.1 The entry points

```luau
export type StepSpec = {
    index: number,            -- 1-based, stable for a given (seed, config)
    kind: "clear" | "terrain" | "hedgerow" | "stand" | "track" | "bog" | "props" | "markers" | "settings",
    label: string,            -- "terrain tile 7/16 (x=-256..-128, z=0..128)"
    estimatedMs: number,
}

export type StepReport = {
    index: number, kind: string, label: string,
    ok: boolean, message: string?,
    voxelsWritten: number?, partsCreated: number?, assetsInserted: { string }?,
    elapsedMs: number,
}

MapGen.VERSION: string
MapGen.CONFIG: Config                       -- frozen
MapGen.steps(seed: number): { StepSpec }    -- pure; the plan of the whole run, no side effect
MapGen.runStep(index: number, seed: number): StepReport   -- performs exactly one step
MapGen.clear(): { removed: number, terrainCleared: boolean }
MapGen.digest(): { digest: string, parts: number, samples: number, seed: number, version: string }
MapGen.verifyContract(): { ok: boolean, findings: { string }, counts: { [string]: number } }
MapGen.retag(): { tagged: number }          -- only exists if §13 measurement B says tags do not persist
```

Every one of these returns a plain table. `tools/mapgen.py` wraps the call in
`HttpService:JSONEncode`, so an MCP reply is machine-readable and lands in the run log verbatim —
the same discipline `tools/studio_mcp.py` uses for the test report.

### 5.2 The layer order, which is also the step order

Each layer is a pure function of the seed and the layers before it, so one can be re-run alone
(research note, pattern point 3):

1. **clear** — `Terrain:Clear()`, destroy `Workspace.DrivenHuntMap`. One step.
2. **terrain** — `Ground.writeTile(tx, tz, seed)`, one step per tile: height → occupancy → material
   (Grass field, LeafyGrass rough edges, Ground track, Mud bog). 16 tiles for the 512 slice, 256 for
   the full map (§11).
3. **hedgerow** — `Props.hedge(line, seed)`, one step per hedgerow polyline.
4. **stand** — `Props.stand(polygon, seed)`, one step per tree stand.
5. **track** — `Ground.paintTrack(spline)` (material only; the height was already flattened in 2).
6. **bog** — `Ground.paintBog(disc)`, plus reeds.
7. **props** — fences, gates, stones, the hunter's stands.
8. **markers** — `Markers.place(layout)`. Last of the world layers, so a marker is never orphaned by
   a later step.
9. **settings** — `Settings.apply(Map.STREAMING)`. Deliberately last: a streaming change during
   generation would make the rest of the run fight the engine.

### 5.3 The heightfield

`Height.at(x, z, seed, config)` — the technique read out of **RTerrainGenerator** (§11 source 5) and
implemented from scratch on `math.noise`:

```
w  = warp * (noise(x*wf + ox, z*wf + oz), noise(x*wf + ox + 313.7, z*wf + oz + 71.3))
h  = Σ_{o=1..OCTAVES} amp_o * noise((x + w.x + ox) * f_o, (z + w.y + oz) * f_o)
h  = h * RELIEF                          -- studs
h  = h * corridorFalloff(x, z)           -- 1 outside the corridor, → CORRIDOR_RELIEF/RELIEF inside
h  = flattenPads(h, x, z)                -- §7.3: spawn pads, posts, driver start
return groundY + h
```

**The seed reaches the noise as a coordinate offset** (`ox`, `oz` from `Random.new(seed)`), because
`math.noise` has no seed parameter — research note §11 and pattern point 2. Everything discrete
(which tree, where, hedgerow gaps) comes from `Random.new(seed * 1000 + LAYER_ID)`, **one RNG per
layer**, never a shared sequence: with one shared sequence a step's output would depend on which
steps ran before it in that MCP call, and §0 item 2 means that is not knowable.

### 5.4 Statelessness, restated as a rule the Builder can check

> A step may read: its arguments, `MapGen.CONFIG`, `ReplicatedStorage.Map`, the pure modules, and the
> world as it currently stands. A step may not read: a module upvalue written by an earlier step, a
> cached plan, a memo table, or `Workspace` for anything but its own idempotence check.

Every world-writing step is **idempotent**: re-running step 7 destroys and rebuilds
`…Map.Props.Hedge3`, it does not add a second one. That is how a failed step is retried, and it is
the property that makes `--step` useful.

---

## 6. Invoking a run: `tools/mapgen.py`

### 6.1 Commands

```
python tools/mapgen.py plan     [--seed N]                  # read-only: print the steps and the plan
python tools/mapgen.py build    --seed N --backup <path>    # clear, then every step, in order
python tools/mapgen.py step  <i,j,k> --seed N --backup <path>   # re-run named steps only
python tools/mapgen.py clear    --backup <path>             # Terrain:Clear() + destroy the map root
python tools/mapgen.py verify   --seed N --backup <path>    # build, digest, clear, build, digest, compare
python tools/mapgen.py digest                               # read-only
python tools/mapgen.py contract                             # read-only: MapGen.verifyContract()
python tools/mapgen.py shots                                # read-only: the six named captures (§12.3)
```

Exit codes, deliberately the harness's shape: **0** done · **1** a step failed · **2** REFUSED.

### 6.2 What it refuses, before it touches anything

Every one of these is a `REFUSED` (exit 2) with the reason printed. A generator that runs anyway is
how a place gets destroyed.

1. **Studio not in Edit mode**, or `game.PlaceId != servePlaceIds[0]` — reuse `Studio.mode()` and
   `expected_place_id()` from `tools/studio_mcp.py`.
2. **A dirty tree** for any mutating command (`git_state()`), because a map built from uncommitted
   code cannot be reproduced from a commit, and "PASS on a dirty tree is not valid evidence" is
   already this project's rule (`tools/studio_mcp.py`, exit code 3).
3. **Studio's copy of the generator differs from disk.** Read the `Source` of every
   `ServerStorage.MapGen.*` and `ReplicatedStorage.Map` script and compare byte-for-byte with line
   endings normalised — the same comparison `compare_synced` in `tools/studio_mcp.py` makes. Catches
   "Rojo is not connected" and "Karen has not pressed Connect since the last edit", which would
   otherwise build yesterday's map from today's seed.
4. **No usable backup.** `--backup` must name an existing file, **outside the repository**, with
   suffix `.rbxl`, non-empty, modified within `BACKUP_MAX_AGE_HOURS = 6`. Research note §10: File →
   Save to File is the only rollback Workspace has, it is a menu click no tool can make, and this is
   the one place it can be enforced instead of remembered.
5. **`--seed` missing** on `build`/`verify`. There is no default seed: an unnamed seed is an
   unreproducible map.

### 6.3 Chunking, timeouts and progress

One MCP call per step, `Studio._rpc(..., timeout=MAPGEN_CALL_TIMEOUT)` with
`MAPGEN_CALL_TIMEOUT = 180` s against a per-step design target of ≤ 60 s (§11). Reasons, in order:

- `_rpc`'s default timeout is 120 s (`tools/studio_mcp.py`, `Studio._rpc`), and a whole-map run in
  one call would exceed it. Whether StudioMCP has its own ceiling is **unverified**; chunking makes
  the question moot.
- A failed tile names itself. A single 20-minute call that returns "error" names nothing.
- §0 item 2 forbids carrying state across calls anyway, so the chunk boundary is free.

Every step's `StepReport` is printed as it lands and appended to `.mapgen/<utc>-<seed>.json`
(git-ignored, new entry in `.gitignore`). The final line is the one the Builder pastes into
`reviews/task-<N>/REQUEST.md`:

```
[mapgen] OK: 271/271 steps @ <full HEAD sha> seed=7 digest=<64 hex> (clean tree)
```

### 6.4 Reproducibility: the digest

`MapGen.digest()` returns a SHA-shaped hex string over a **canonical** serialisation:

- every instance under `Workspace.DrivenHuntMap`, sorted by full name, as
  `name|ClassName|x|y|z|sx|sy|sz` with each number rounded to 0.01;
- every tag on every tagged instance, sorted;
- `DIGEST_TERRAIN_SAMPLES = 4096` terrain occupancy/material samples on a fixed lattice (64 × 64
  across the map, read with `Terrain:ReadVoxels` in one region per row), rounded to 0.01 occupancy.

`python tools/mapgen.py verify --seed N` builds, digests, clears, builds again and compares. **A
mismatch is the answer to the research note's biggest open question** — whether `math.noise` is
stable within a session and across engine versions (note §11, and pattern point 2). If it is not,
the fallback is already named there: a small seeded value-noise implementation in `Height.luau`,
which is ~40 lines and makes reproducibility ours rather than borrowed. That branch is a
measurement, not a decision, so it blocks nobody.

The digest of the accepted map is committed as `Map.DIGEST`, and §12.1 check 11 asserts the live map
still matches its **marker-and-count** part of it (not the full terrain digest, which is too slow for
a spec). That is the guard against a hand edit in Studio silently becoming the map.

### 6.5 Undo

There is no Ctrl+Z. `ChangeHistoryService` is plugin-security and whether `execute_luau` can reach it
is **unverified**; this design does not rely on it. The three recovery routes, in order of use:

1. `python tools/mapgen.py build --seed <same>` — rebuild, deterministic, no human.
2. `python tools/mapgen.py clear` — back to an empty world, then flip `Map.EXPECTED_WORLD` to
   `"arena"` and the grey box returns at the next server start (§9).
3. Karen opens the `.rbxl` backup — the only route that recovers anything the generator did not
   make.

---

## 7. The typed-value question (`TASKS.md` row 16), answered

**The map generator does not need the harness to learn typed values, and this design deliberately
keeps it that way.** `TASKS.md` row 16 assumed "templates on disk"; there are none.

| Thing you might put on disk | Where it goes instead | Why |
|---|---|---|
| Prop templates (`Part`/`MeshPart` with `Size`, `Color`, `CFrame`) | **nowhere**: props are `Instance.new` in `Props.luau`, or a clone of an asset fetched by id at run time of the generator | A `.model.json` carrying a `Vector3` fails the harness as "cannot compare" (`tools/studio_mcp.py` check 4), and an asset binary is banned outright (`.rbxm`) |
| The map's numbers (sizes, offsets, colours) | `Config.luau` and `src/shared/Map/init.luau`, plain Luau | Luau has `Vector3` and `Color3` natively, selene and StyLua lint it, the harness compares the **source byte-for-byte**, and a diff of a number is readable in a PR. A `.model.json` is strictly worse on every one of those axes |
| Asset ids and provenance | `Assets.luau`, plain Luau table (§8) | same |
| Marker positions | computed by `Layout.luau` from the corridor numbers | a hand-written coordinate table is the thing that goes stale when the corridor moves |

**Recommendation to the Director: `TASKS.md` row 16 stays queued under "before release", and its
"lands with the map generator" note is wrong.** The condition that would revive it: the first time
anyone wants a `.model.json` whose value is a `Vector3`, `CFrame`, `Color3`, `UDim2` or `NumberRange`.
Nothing in Milestone 2 as designed here does. It is still a real hole in the harness — audit-002 #1
stands — it is simply not this system's blocker.

---

## 8. Assets

### 8.1 The manifest, `src/serverstorage/MapGen/Assets.luau`

```luau
export type AssetRow = {
    key: string,          -- "tree.spruce.a" — what Layout and Scatter ask for
    id: number,           -- rbxassetid
    name: string,         -- as listed on the Creator Store / as exported from Meshy
    creator: string,
    source: "creator-store" | "meshy" | "roblox",
    licenceNote: string,  -- one line; for Creator Store: "use on Roblox only, not redistributable"
    added: string,        -- ISO date
    version: number,      -- bumped when a new id replaces this one; the row is APPENDED, never edited
    tris: number?,        -- measured at import, nil until measured
    kind: "mesh" | "model",
}
Assets.ROWS: { AssetRow }
Assets.byKey(key: string): AssetRow?      -- the newest version for that key
```

Research note §8: never commit the binary, always record provenance, and note §9: a changed mesh is a
**new asset id**, so rows are appended and versioned, never overwritten. A moderated-away id is then
diagnosable from the manifest instead of from memory.

### 8.2 Insertion, and caching that does not fight Rojo

`Props.asset(key)` inserts **once per run** into `Workspace.DrivenHuntMap.Assets` (a folder created
at the start of the run and **destroyed at the end of it**), clones from it, and never persists a
template.

That "never persists" is not tidiness. `ServerStorage` and `ReplicatedStorage` are fully Rojo-owned
and default to `$ignoreUnknownInstances: false`, so **a template cached there is deleted at Karen's
next Connect** (`CLAUDE.md`, "Rojo DELETES Studio-created instances in Rojo-owned containers"). A
cache that silently empties itself between sessions is a bug generator. Workspace is the only safe
home, and there it would render, so: in-run only.

Primary route: `InsertService:LoadAsset(id)` from the generator's own Luau. **Whether it is callable
from `execute_luau` in Edit mode is unverified** and is measurement C in §13. Named fallback, no
redesign needed: `tools/mapgen.py` calls StudioMCP's `insert_asset` (enumerated in research note §12)
into the same folder before the step that needs it, and `Props.asset` finds it there. Both routes end
at the same folder, so `Props.luau` does not change between them.

### 8.3 No id yet? A grey-box proxy, not a blocked task

Karen's Meshy models and Creator Store choices do not exist yet (brief). If `Assets.byKey` returns
`nil`, `Props` places a **proxy**: an `Anchored` `Part` of the same footprint and height with the
key's proxy colour, and the step reports `proxyUsed = { key, count }`. The whole map is therefore
buildable and walkable today, in grey box, and each asset id later replaces one proxy with no code
change. This is Milestone 1's own method applied to the world, and it is what removes "we have no
asset ids" from the blocking list.

### 8.4 An asset containing a script is refused, not stripped

After insertion and **before** the first clone, `Props` walks the template for
`LuaSourceContainer` descendants. If it finds one it **destroys the template, places proxies for that
key, and fails the step** with the id and the script's name.

This is not paranoia. Free models routinely carry scripts; a single surviving `Script` under
Workspace makes harness check 5 fail every run from then on (`tools/studio_mcp.py`: *"No script
(LuaSourceContainer) exists anywhere in the DataModel outside the sourcemap"*), and `CLAUDE.md`
forbids it outright. Refusing rather than stripping is deliberate: a stripped model may be
half-functional in ways nobody looks for, and the right answer is a different asset.

---

## 9. Replacing `Workspace.TestArena` cleanly

### 9.1 The hazard, precisely

`src/server/ArenaBoot.server.luau` calls `TestArena.build()` at **every server start**, and
`TestArena.build` is idempotent only against its own folder — it knows nothing about a generated map.
Left alone, the first Play after the map lands puts a 400 × 400 grey plate with its top at y = 0 and
eight concrete pillars in the middle of the farmland, plus a second `SpawnLocation`
(`LAYOUT.spawn`, `ArenaSpawn`). That is Task 17's z-fighting bug (`TASKS.md` row 17) with worse
scenery, and it is exactly "two systems wrote the creature's position" in a new place.

### 9.2 The switch: one committed fact, read by two readers, written by nobody at run time

`Map.EXPECTED_WORLD` is `"arena"` or `"map:v1"`.

```luau
-- src/server/ArenaBoot.server.luau, in full after the change
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage:WaitForChild("Map"))
if Map.EXPECTED_WORLD ~= "arena" then
    return                     -- the generated map is the world; the grey box is not built
end
require(ServerScriptService:WaitForChild("TestArena")).build()
```

Four properties worth naming:

- **It cannot be half-on.** One string, in git, in a diff.
- **It does not sniff Workspace.** "Is there a map?" answered by looking for a folder is a predicate
  that lies the moment a run half-finishes.
- **`TestArena` keeps its owner and its file.** Nothing is archived while the arena is still the
  rollback (§6.5 route 2).
- **The spec cannot go green by accident**, because §12.1 asserts the world the *committed contract*
  names and that the other one is absent — there is no branch where nothing is checked.

### 9.3 The order of the switch, with Karen's clicks in it

1. Karen: **File → Save to File** to a dated `.rbxl` outside the repo (`NEEDS KAREN`).
2. `python tools/mapgen.py build --seed <N> --backup <that file>`.
3. `python tools/mapgen.py contract` and `shots`; the Builder inspects the six images (rule 5).
4. Karen: **File → Save** — StudioMCP's enumerated tool list has no save tool (research note §12), so
   an unsaved map dies with the session (`NEEDS KAREN`).
5. Karen: reopen the place; `python tools/mapgen.py contract` again. **This is measurement B**
   (§13): do `CollectionService` tags survive a save and reopen?
6. The code commit flips `Map.EXPECTED_WORLD` to `"map:v1"`, sets `Map.SEED` and `Map.DIGEST`, sets
   `Map.FIELD` to the drive rectangle (§11), and updates `Boar.CONFIG.field` to the same numbers —
   a data change inside `ServerScriptService.Boar`'s own file, by its owner.
7. Harness run. §12.1 now takes the map branch.
8. Karen walks it (the feel gate; nothing here can judge it).
9. **Only after Karen accepts:** a separate task archives `src/server/TestArena.luau`,
   `src/server/ArenaBoot.server.luau` and `tests/server/test_arena.spec.luau` to `backups/` with a
   note (rule 7), and removes the early return with them.

---

## 10. What this system reads from and writes to other systems

| Direction | What | The other side's owner | Evidence |
|---|---|---|---|
| **writes** | `Terrain` (global) | none existed; **this design gives Terrain its first owner: `MapGen.Ground`** | `Terrain` is a single global object with no notion of ownership (research note §2) |
| **writes** | `Workspace.DrivenHuntMap` and every descendant | `MapGen` (`Props`, `Markers`) | this design |
| **writes** | `Workspace.StreamingEnabled` and the four streaming properties | `MapGen.Settings`; no other writer in the repo | grep: no occurrence in `src/` at this commit |
| **writes** | `CollectionService` tags on map instances, at edit time | `MapGen.Markers` | `docs/design/drive.md` §6.1 |
| **reads** | `Map.TAGS`, `Map.FIELD`, `Map.STREAMING`, `Map.BUDGET` | nobody writes them at run time | §4 |
| **is read by** | the five `DrivenHunt.*` tags, at run time | `Match.Markers` (`docs/design/drive.md` §6.2, `Markers.read`), which validates and reports what is missing and stays in `Waiting` if the map is incomplete | `docs/design/drive.md` §6.2 |
| **is read by** | the ground, by the boar's pathfinding | `ServerScriptService.Boar` — `Boar.defaultWorld`'s `requestPath` uses `PathfindingService:CreatePath(config.AGENT)` | `src/server/Boar/init.luau` |
| **is read by** | the ground and the trees, by the shotgun's rays | `ServerScriptService.Weapon` — `Weapon.Cast` is the only caller of `Workspace:Raycast` in that system | `src/server/Weapon/Cast.luau` |
| **constrains** | `Boar.CONFIG.field` must equal `Map.FIELD` | `ServerScriptService.Boar` owns the change; §12.1 check 7 asserts the equality, replacing the `TestArena.LAYOUT`-vs-`field` assert in `src/server/BoarBoot.server.luau` (which `docs/design/drive.md` §3.5 moves verbatim into `MatchBoot`) | `src/server/BoarBoot.server.luau` |
| **cross-system change** | `Match.Markers` and `TestArena.build` take their tag strings from `Map.TAGS` | their own owners, in their own files | §4.2 |

**Nothing else.** In particular: no change to `src/server/Boar/Brain.luau`, `Body.luau` or
`Wound.luau`; no change to any weapon or camera module; no change to `tools/studio_mcp.py`; no change
to `default.project.json` (both `src/shared` and `src/serverstorage` are already mapped —
`CLAUDE.md`, Layout), so **no Rojo restart and no extra Connect click**.

---

## 11. External sources

Seven, beyond the thirteen in `docs/research/2026-09-24-map-generator.md`, which this design does not
repeat. Each with licence, maintenance, what it does well and badly, and what is taken.

### 1. Roblox `Terrain` — the voxel API the ground is written through
<https://create.roblox.com/docs/reference/engine/classes/Terrain>
Licence: first-party documentation (creator-docs is CC BY 4.0); the API ships with the engine.
Maintenance: actively maintained.
**Good:** `WriteVoxels(region, resolution, materials, occupancy)` takes occupancy as well as material,
which is what makes smooth ground from a heightfield rather than steps; `ReadVoxels` gives the digest
(§6.4) a cheap canonical sample; `Clear()` gives `MapGen.clear` its reset.
**Bad:** the page shows `resolution` as `4` throughout but **does not state that 4 is the only
supported value**, and gives **no size cap** for a `WriteVoxels` region. Both are measured in M2.1
(§13 measurement A); the tile size in §11's table is a conservative guess until then.
**Adopted:** `WriteVoxels` per tile, resolution 4, `Region3` aligned with `ExpandToGrid(4)`.

### 2. Roblox `math.noise` — the noise the heightfield is made of
<https://create.roblox.com/docs/reference/engine/libraries/math>
Licence: first-party (CC BY 4.0 docs); ships with the engine. Maintenance: actively maintained.
**Good:** Perlin noise in the standard library, so the generator needs no dependency at all.
**Bad:** the page gives the signature and nothing else — no output range, no determinism promise
across sessions or engine versions, and **no seed parameter**. That is the single largest unproven
assumption in the whole system.
**Adopted:** `math.noise` with a seed-derived coordinate offset, plus `verify` (§6.4) as the standing
check that it is stable, plus a named fallback to a seeded value-noise function on disk.

### 3. `CollectionService` — how script-free geometry is found by code
<https://create.roblox.com/docs/reference/engine/classes/CollectionService>
Licence: first-party. Maintenance: actively maintained.
**Good:** `AddTag`/`GetTagged`/`GetInstanceAddedSignal` is the standard Roblox answer to "the map
carries no scripts", and `docs/design/drive.md` already consumes it.
**Bad:** the page does **not** say tags are serialised into the place file, and gives no limit on tag
count. The Studio Tag Editor implies persistence; this design does not assert it from implication —
§13 measurement B settles it with a save and a reopen, and §13 names fallback B (markers by folder
and name) if it fails.
**Adopted:** tags as the only marker mechanism, with the vocabulary in `Map.TAGS`.

### 4. Instance streaming — the budget the map is built against
<https://create.roblox.com/docs/workspace/streaming>
Licence: first-party. Maintenance: actively maintained.
**Good:** gives the defaults this design adopts verbatim — `StreamingMinRadius` 64,
`StreamingTargetRadius` 1024, `StreamingIntegrityMode = PauseOutsideLoadedArea`,
`ModelStreamingBehavior = Improved` — with Roblox's own reasoning for each.
**Bad:** warns that local-only property changes are lost when an instance streams out and back in,
which is a live trap for anything the client decorates; and mobile clients are reported to run out of
memory as content streams *in*. Turning streaming on changes client behaviour for every existing
system, which is why §14 gives it **its own build task with a full harness re-run**, not a line in
the first slice.
**Adopted:** the documented defaults, applied by `MapGen.Settings` as the last step, behind
`Map.STREAMING.enabled`.

### 5. RTerrainGenerator — the closest open-source Roblox terrain generator
<https://github.com/TheArturZh/RTerrainGenerator>
Licence: **MIT** (a closed derivative is permitted). Maintenance: **~45 commits, no visible recent
activity, no archive notice — treat as unmaintained**.
**Good:** it documents exactly the technique adopted here — *exponentially distributed Perlin noise
with domain warping* — and domain warping is what stops noise terrain from looking like noise.
**Bad:** it does **not** use Roblox `Terrain`; it builds its own geometry, with its own world model
for rivers and forests. Vendoring it would mean fighting that model forever.
**Adopted: the technique, not a line of the code** — the domain-warp form in §5.3. Rule 2: this is
borrowing, and where it is borrowed from is written in the header of `Height.luau`.

### 6. Rojo project format — why the map is not in git, and what Rojo will delete
<https://rojo.space/docs/v7/project-format/>
Licence: Rojo is MIT; the docs site is the project's own. Maintenance: actively maintained; the CLI
is pinned at 7.7.0 in `rokit.toml`.
**Good:** states that every `$path` node defaults to `$ignoreUnknownInstances: false` — *"whether
instances that Rojo doesn't know about should be deleted"*. That single sentence is why §8.2 refuses
to cache asset templates in ServerStorage and why the map lives in Workspace.
**Bad:** it describes what Rojo does, not when — `CLAUDE.md`'s own 2026-09-24 probe found the
deletion happens at the next **Connect**, not during live sync, so a Studio-made instance can look
safe for a whole session and then vanish.
**Adopted:** Workspace as the only home for generated content; in-run-only asset templates.

### 7. Roblox pathfinding — the reachability the map must guarantee
<https://create.roblox.com/docs/characters/pathfinding>
Licence: first-party. Maintenance: actively maintained. Already the boar's source of record
(`src/server/Boar/init.luau` header).
**Good:** `PathfindingService:CreatePath(agentParams)` + `ComputeAsync` gives a spec a **machine
verdict on whether the map is playable for the boar**, using the boar's own
`Boar.CONFIG.AGENT` (`AgentRadius = 2`, `AgentHeight = 3`, `AgentCanJump = false`,
`AgentCanClimb = false`). That is the check the brief asks for, and it costs nothing to run.
**Bad:** I could not cite, from this session, a documented maximum walkable slope for the navmesh, and
there is no slope field in the agent params. So `CORRIDOR_MAX_SLOPE_DEG` in §11 is a **conservative
target, not a derived limit**, and the reachability spec is what actually proves the corridor.
**Adopted:** `CORRIDOR_MAX_SLOPE_DEG = 15`, and the spec in §12.1 check 5 as the real gate.

**Also considered and rejected, with reasons** (so they are not re-proposed): Studio's Terrain Editor
Import and Generate (research note §3 — UI-only, unreachable from code or MCP, and their state is not
a file); heightmap PNGs as the source of truth (unreviewable as a diff, which is what map option C
exists to avoid); a heightmap plugin from the Creator Store (a Karen click per import, plus a
third-party dependency in the critical path).

---

## 12. Numeric targets

**K** = Karen's taste value: a number she changes after walking it, not a measurement.
Derived at **1 stud = 0.28 m** (research note §1).

### The world

| Quantity | Value | K? | Basis |
|---|---|---|---|
| Map size | **2048 × 2048 studs** (573 × 573 m), centred on the origin | | research note; ~2× `StreamingTargetRadius`, so streaming is actually exercised |
| Reference ground plane `groundY` | **0** | | matches `Boar.CONFIG.field.groundY`, so §0 item 4 needs no boar change |
| Relief, whole map | **± 40 studs** (± 11 m) | K | gentle farmland; well inside `FALL_LIMIT = 50` |
| Relief, inside the drive corridor | **± 16 studs** | K | so a boar is never spawned or despawned by terrain |
| `CORRIDOR_MAX_SLOPE_DEG` | **15°** | | conservative; §11 source 7 — the reachability spec is the real gate |
| Drive corridor | x ∈ **[−340, +340]**, z ∈ **[−800, +800]** | | 680 studs wide (190 m) |
| `Map.FIELD.bounds` | minX −340, maxX +340, minZ −800, maxZ +800 | | must equal `Boar.CONFIG.field` |
| `Map.FIELD.exitZ` | **−760** | | 60 studs behind the line, so a boar that beats the line disappears behind the shooters rather than in their faces (the shape `docs/design/drive.md` §2 uses at 40 studs in the 400-stud arena) |
| Drive length (start → line) | **1400 studs** (390 m) | K | research note's target, unchanged |
| Shooter line | z = **−700**, along a wood edge; **8 posts**, spacing **80 studs** (22 m), span 560 studs | K | 8 posts serves 16 players (8 shooters). The research note said 60 studs; at 8 posts that is a 420-stud span and reads as a firing range. Karen's dial |
| Driver start | z = **+700**, spread over x ± 120 | K | |
| Boar spawns | **4**, z = **+600**, x = −240, −80, +80, +240 | K | `docs/design/drive.md` §6.3 releases boars round-robin with jitter |
| Tie trees (`DrivenHunt.Tree`) | **12**, within 120 studs of the line | | §4.3 |
| `SPAWN_PAD.radius` / `.blend` / `.tolerance` | **14** / **24** / **0.75** studs | | §7.3 |
| Bog | one disc, radius **120**, depth **6**, `Mud`; **no Water material** | K | §1.2 |

### Budgets

| Quantity | Target | Basis |
|---|---|---|
| Terrain voxel resolution | **4 studs** | the value the `Terrain` docs use throughout; whether any other is accepted is unverified (§11 source 1) |
| Vertical terrain band | y ∈ **[−48, +48]**, 24 voxel layers | covers ± 40 relief with margin |
| Tile per `WriteVoxels` call | **128 × 128 studs** = 32 × 32 × 24 = **24,576 voxels** | small enough to be safe against the undocumented region cap; 256 tiles for the full map, 16 for the 512 slice |
| Total parts and meshes in the place | **≤ 20,000** | research note §6: <50,000 visible on desktop, ~20,000 on mobile. Conservative for a v1 that must run on a phone |
| Visible parts at any moment | **≤ 8,000** | leaves headroom for 16 characters, 16 shotguns and 8 boars |
| Trees | **≤ 3,000**, 1 MeshPart each, 2 species × 3 variants | research note |
| Hedgerow segments | ≤ **500** parts (one per ~12 studs, ≤ 6,000 studs of hedge) | inside the budget with room |
| Mesh budget per prop | **≤ 21,000 triangles**, textures **≤ 1024 × 1024** | research note §9 — **community and vendor figures, not first-party**. A background conifer should want hundreds of triangles, not thousands |
| Client memory | **≤ 1.5 GB** on a mid phone | a target, never measured on this project |
| Join-to-playable | **≤ 15 s** on a mid phone | a target, never measured |

### The generator itself

| Quantity | Target | Basis |
|---|---|---|
| Per-step wall clock | **≤ 60 s**, hard timeout **180 s** | `Studio._rpc` defaults to 120 s (`tools/studio_mcp.py`) |
| Full 2048 build | **≤ 20 min** | edit time; slow is fine, unrepeatable is not |
| 512 × 512 slice (M2.1) | **≤ 3 min** | so the first task iterates |
| Determinism | **identical digest** from two builds at the same seed | hard requirement, not a target — `verify` fails otherwise |
| `DIGEST_TERRAIN_SAMPLES` | 4,096 (64 × 64) | enough to catch a shifted heightfield, cheap enough to run every time |
| `BACKUP_MAX_AGE_HOURS` | 6 | §6.2 refusal 4 |

---

## 13. How it is tested

### 13.1 Server spec — `tests/server/map_contract.spec.luau`

Runs in the normal harness Play session. It asserts **the world the committed contract names**, so
neither branch is empty and there is no path where it passes by finding nothing.

1. `Map.EXPECTED_WORLD` is `"arena"` or `"map:<id>"`, and **exactly one** of
   `Workspace.TestArena` / `Workspace.DrivenHuntMap` exists — the one it names.
2. Every tag in `Map.TAGS` resolves to exactly `Map.EXPECTED_COUNTS` instances, all inside the named
   world's root.
3. Exactly one `DrivenHunt.DriveLine`; its `CFrame.LookVector:Dot(Vector3.zAxis) > 0.99`, so the
   normal points at the drivers — the meaning `src/server/Weapon/SafetyArc.luau` and
   `docs/design/drive.md` §6.1 both depend on.
4. Every `DrivenHunt.BoarSpawn` is inside `Map.FIELD.bounds`, and its `Position.Y` is within
   `Map.SPAWN_PAD.tolerance` of `Map.FIELD.groundY` (§7.3 — this is the check that stops a boar
   spawning inside a hill).
5. **Reachability**: for every `BoarSpawn`, and for the `DriverStart`,
   `PathfindingService:CreatePath(Boar.CONFIG.AGENT):ComputeAsync(from, driveLinePoint)` returns
   `Enum.PathStatus.Success` with ≥ 2 waypoints. This uses the boar's **own** agent params, so it
   asserts the map is playable for the actual animal and not for an imaginary one. (`ComputeAsync`
   yields; TestEZ runs each `it` in a coroutine, so this is fine, but it is the one slow check here —
   budget ~5 computations.)
6. No `LuaSourceContainer` anywhere under the named world root. Harness check 5 covers the whole
   DataModel already; this one **names the cause** when a free model brings a script in (§8.4).
7. `Boar.CONFIG.field` deep-equals `Map.FIELD` — replacing the `TestArena.LAYOUT`-vs-`field` assert
   in `src/server/BoarBoot.server.luau`, which the drive moves into `MatchBoot`.
8. *(map branch)* `#root:GetDescendants() <= Map.BUDGET.parts`.
9. `ServerStorage.MapGen` exists and **every descendant is a `ModuleScript`** — nothing in the
   generator can autorun (§1.2).
10. *(map branch)* 64 downward rays on a lattice across the corridor, from `groundY + 200`: each hits
    `Workspace.Terrain`, and every hit Y is inside the corridor relief band.
11. *(map branch)* the marker half of `Map.DIGEST` recomputed from the live markers equals the
    committed value — a hand edit in Studio fails the harness instead of becoming the map.

### 13.2 Client spec — `tests/client/map_client.spec.luau`

No branch: every expectation comes from the contract, so the same assertions hold in both worlds.

1. `Workspace.StreamingEnabled == Map.STREAMING.enabled`, and when enabled, the four radius/mode
   properties match `Map.STREAMING`.
2. The local character is standing on something: a downward ray from the root hits within 12 studs.
   (The previous project shipped "measured correct, looked wrong"; a character in the void measures
   fine.)
3. `Players.LocalPlayer:RequestStreamAroundAsync(driveLinePoint)` returns within 10 s and the
   `DrivenHunt.DriveLine` part is non-nil on the client afterwards — the client can actually see the
   place it is told to shoot toward.

### 13.3 Screenshots (rule 5) — `python tools/mapgen.py shots`

Six named Edit-mode captures with explicit camera and look-at, saved through
`Studio.capture` (`tools/studio_mcp.py`; Task 7 closed 2026-09-25, and Edit-mode capture is the case
it was verified in). The Builder inspects each and says what it shows:

| Name | Camera → look-at | Answers |
|---|---|---|
| `map-wide` | (0, 900, 1400) → (0, 0, 0) | is there a map at all, and is it farmland-shaped |
| `map-line` | (0, 60, −560) → (0, 0, −760) | the shooter line along the wood edge, 8 posts |
| `map-corridor` | (0, 40, 700) → (0, 0, −700) | the drive, from the drivers' eye height |
| `map-hedge` | (−200, 20, 200) → (100, 0, 200) | hedgerows and field edges at eye height |
| `map-stand` | (300, 20, −400) → (300, 0, −600) | a spruce stand: does it read as woods or as poles |
| `map-bog` | (−260, 30, −100) → (−260, 0, −220) | the bog, and whether it is a feature or an annoyance |

### 13.4 What the harness cannot do here, stated rather than discovered

- **It cannot judge whether the farmland reads as European farmland.** Only Karen can (rule: a number
  is not a verification).
- **It cannot run the generator**, by design (§0 item 1). `tools/mapgen.py` is invoked by hand and its
  `[mapgen] OK:` line is pasted into the review request as evidence, exactly as the harness line is.
- **It cannot save the place.** StudioMCP's enumerated tool list has no save tool (research note §12),
  so every rebuild ends in a Karen click, and an unsaved map dies with the session.
- **It cannot prove tags survive a save and reopen** inside one run — that needs a reopen, which is
  measurement B below.
- **Two players are still impossible** (`tools/studio_mcp.py`, "More than one player", Task 30). The
  map changes nothing about that.
- **No input scenario is added.** The map takes no input; a scenario here would test the harness.

### 13.5 The four measurements M2.1 must make and write down

Rule 8, and they are the reason M2.1 is small.

- **A. `WriteVoxels`**: does it accept a 128 × 128 × 96-stud region? Is `resolution` 4 the only
  accepted value? Record both, correct §12's tile row.
- **B. Tags across a save and reopen** (§9.3 step 5). If they do **not** survive: fallback B is
  markers found by **folder and name** under `Workspace.DrivenHuntMap.Markers`, and the only module
  in the repo that changes is `Match.Markers` (`docs/design/drive.md` §6.2). Do **not** ship tags and
  attributes both: two representations of one fact is this project's named failure mode.
- **C. Writes through `execute_luau` in Edit mode** — step 0 of M2.1 is a one-liner that creates an
  empty Folder and reads it back. StudioMCP exposes `insert_asset`, `multi_edit` and
  `generate_procedural_model`, so the server is certainly not read-only, but `execute_luau`
  specifically has only ever been used read-only here. If it cannot write, the whole invocation route
  changes and that is a `ESCALATE.md` entry, not a workaround.
- **D. Cost of 50 trees**: parts, and the place's memory before and after, so the 3,000-tree budget
  is checked by multiplication rather than hope.

---

## 14. Build order

### M2.1 — the smallest first task: a 512 × 512 slice (the research note's own wording)

Scope, and nothing else: `src/shared/Map/init.luau` (contract), `src/serverstorage/MapGen/`
(`init`, `Config`, `Height`, `Layout`, `Scatter`, `Assets`, `Digest`, `Ground`, `Props`, `Markers`),
`tools/mapgen.py`, `tests/server/map_contract.spec.luau` (arena branch — the slice is **not** the
world yet, so `Map.EXPECTED_WORLD` stays `"arena"`), plus the four measurements.

The slice: a noise heightfield written as voxel terrain in two materials (grass field, dirt track),
one hedgerow line, 50 trees from one asset key (**a proxy if there is no id yet**, §8.3), and the
five tagged markers. Then `verify` (same seed twice → same digest), six screenshots, save, reopen,
`contract`.

It is buildable **today**, with no asset ids and no decisions from anyone.

### Then, one task each

| # | Task | Depends on | Notes |
|---|---|---|---|
| M2.2 | The full 2048 heightfield: fields, hedgerow network, tracks, the bog, the corridor flattening | M2.1 (measurement A) | still proxies for props |
| M2.3 | Tree stands: spruce and birch, 2 × 3 variants, 3,000 instances, real asset ids | M2.2, Karen's ids | measurement D decides whether 3,000 survives |
| M2.4 | Props and the shooter line's furniture: fences, gates, stones, hunter's stands; the 12 tie trees | M2.3 | |
| M2.5 | **The switch** (§9): `Map.EXPECTED_WORLD = "map:v1"`, `Boar.CONFIG.field`, `ArenaBoot`'s early return, the map branch of the spec, Karen walks it | M2.4, and Milestone 1 merged | the feel gate |
| M2.6 | Streaming on: `Map.STREAMING.enabled = true`, `MapGen.Settings`, the client spec's radius assertions, **a full harness re-run and a playtest** | M2.5 | §11 source 4: this changes client behaviour for every existing system, so it is alone in its task |
| M2.7 | The Open Cloud upload tool for Karen's Meshy models (key in an environment variable, never in the repo; fail loudly if unset) | M2.3 | research note §9 |
| M2.8 | Archive `TestArena`, `ArenaBoot`, `test_arena.spec` to `backups/` with a note (rule 7) | **Karen has accepted the map** | until then the arena is the rollback |

---

## 15. Open decisions

**None of these blocks building M2.1.** Each has a working default, in the config, changeable by one
number.

### For Karen (feel and taste — nobody else can answer)

1. **Post spacing: 80 studs (22 m), 8 posts, a 560-stud line.** The research note said 60. Walk it and
   say whether it reads as a hunting line or a firing range. `Config.LINE.postSpacing`.
2. **Field size and hedgerow density.** Default: fields of 300–500 studs a side, a hedge on most
   boundaries. This is the single biggest lever on "does it read as European farmland".
3. **How dark the spruce stands are, and how thick.** Default: 3,000 trees total, stands of 40–120
   studs across. A dark stand hides boar; too dark and shooters see nothing.
4. **The bog: feature or annoyance?** Default: one 120-stud disc of mud, 6 studs deep, off the main
   corridor. `Config.BOG.enabled = true` turns it off in one word.
5. **Which Creator Store assets she accepts and which she would rather make in Meshy** (§8). Until
   there are ids, everything is a grey proxy and the map is still walkable.
6. **The two clicks per rebuild** (§9.3 steps 1 and 4): File → Save to File, then File → Save. There
   is no tool route to either.

### For the Director (scope)

A. **`tools/mapgen.py` is new tooling.** `ROADMAP.md` speed rule 1 freezes tooling after Task 11.
   Read literally that blocks this system entirely; read as written ("process improvements"), a
   generator invoker for Karen's map option C is game work, not process. **Recommendation: allow it,
   and say so in the dispatch**, as the Director already did for Task 30.

B. **`TASKS.md` row 16 (typed values) is not this system's blocker** and its note is wrong (§7).
   Recommendation: leave it under "before release" and correct the note.

C. **M2.6 (streaming) is its own task with a full harness re-run and a playtest.** It touches every
   existing client system indirectly. Recommendation: do not fold it into M2.5.

D. **An optional one-line change in `ServerScriptService.Boar`**: `Runtime:spawn` flattens the
   caller's Y to `field.groundY` (`src/server/Boar/init.luau`). This design avoids needing it by
   flattening spawn pads in the terrain (§7.3 / §12.1 check 4), which costs nothing and keeps the
   boar untouched. If a later map wants real relief under the spawns, the change is the boar owner's
   to make, in its own file, with its own spec.
