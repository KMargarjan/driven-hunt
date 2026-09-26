# Design: map-generator (the v1 map, built by code at edit time)

System: `map-generator` — the Luau code that writes the v1 map (terrain, fields, hedgerows, tree
stands, tracks, a bog, the drive corridor and every gameplay marker) into the DEV place at **edit
time**, and the tool that invokes it. `ROADMAP.md` Milestone 2.

**Task 42: a regeneration of the Task 33 design against `docs/research/2026-09-26-asset-pipeline.md`
(Task 39) and the regenerated `docs/design/asset-pipeline.md` (Task 40).** The Task 33 design is
superseded by this file in full; it stays in git history (rule 7).

Architect, 2026-09-26, read-only session: Read, Grep, Glob only. **No Studio, no network, no engine.**
Evidence precomputed in `.agent-evidence/` (`INDEX.md`), commit
`beb44a0a43930c3282fd7462ca8166f4928f888e`, branch `task-42-map-design-v2`.

Inputs, in precedence order: `reviews/task-42/BRIEF.md` (the Director's, and it overrides anything
older), `docs/research/2026-09-26-asset-pipeline.md` (**the source of truth for every asset, licence
and limit claim**), `docs/design/asset-pipeline.md` (Task 40), `reviews/task-33/BRIEF.md` (the
Director's decisions of 2026-09-25, kept and restated in §17), `docs/research/2026-09-24-map-generator.md`
(rule 1, 13 sources), `docs/design/drive.md` (the marker contract), the code at this commit, `CLAUDE.md`,
`ROADMAP.md`, `GAME_DESIGN.md`, `TASKS.md`, `docs/PROJECT_CONTEXT.md`.

**Nothing here is built until Milestone 1 is closed by Karen's two-player playtest**
(`reviews/task-33/BRIEF.md`). This document exists so that when it starts, it starts from a design.

**Test of this document:** a Builder can build M2.1 from it without asking a question. Every owner is
named, every interface is written out, every number is here with its basis, and every human action is
in one place (§17 and §14.4).

**What changed against Task 33, in one paragraph.** Five things. (1) Task 39 read the pages: a free
Creator Store model the experience owner does not own is loadable by **no script route at all**
(`AssetService.AllowInsertFreeAssets` is `RobloxScriptSecurity` on read *and* write), so Task 33's §8.2
is wrong and §8 here is rewritten around what an Edit-time generator can and cannot insert. (2) The
asset manifest is **not** `MapGen.Assets` any more: it is `ServerStorage.Assets`, owned by the
asset pipeline (`docs/design/asset-pipeline.md` §2.3), and `MapGen.Props` asks `Assets.Loader` for a
template instead of inserting one itself. (3) The mesh limit is **20,000 triangles and is first-party**;
1024 px is **our** texture budget, not a platform limit; the licence basis of every asset is now a
recorded enum with a CI gate. (4) The backup rule is unchanged in intent and sharper in mechanism: §7.3
says exactly what `tools/mapgen.py` accepts as a backup, and why an unverifiable "I saved it" is
refused. (5) Task 33's cross-references were broken — §7.3, §8.4, §9.2, §12.1 and §13.x were cited
under numbers the document did not have, and the **spawn-pad section it cited seven times did not
exist**. It exists here, as §6, and every reference in this file was checked against its own headings.

---

## 0. Seven facts this design is built on, stated first because they decide everything

1. **The harness is read-only by construction and must stay that way.** `tools/studio_mcp.py`'s
   docstring, "Safety": *"Its Luau is read-only: constant queries, or queries templated with JSON data
   (QUERY_*). There is no command for arbitrary Luau or arbitrary MCP tools."* A generator is the
   opposite of that. **The generator is invoked by a second, separate tool, `tools/mapgen.py`** (§7),
   which imports `studio_mcp.py`'s `Studio` class and its `luau_json`, `git_state`,
   `expected_place_id`, `find_exe`, `synced_nodes` and `compare_synced` helpers rather than copying
   them. `studio_mcp.py` gains no subcommand, no write path and no new MCP tool. If a later task is
   tempted to add `python tools/studio_mcp.py generate`, that is a design violation: the file that
   decides whether a PR may be reviewed must not also be the file that can rewrite the world.

2. **`execute_luau` has its own module cache, and a `require()` through it returns a fresh copy of the
   module** — measured twice, 2026-09-25 and again in Task 26, and recorded in `tools/studio_mcp.py`'s
   docstring ("Staging a scenario"). So **no generator state may survive between MCP calls**: not a
   plan, not a memo table, and — new in this version — **not `Assets.Loader`'s template cache** (§8.4).
   Every step is a pure function of `(seed, stepIndex)` and the world as it already stands (§5.4).
   This is not a nuisance; it is what forces the generator to be reproducible, which is the whole
   point of map option C.

3. **Workspace is not Rojo-mapped.** `default.project.json`'s tree maps `ServerScriptService`,
   `ReplicatedStorage`, `ReplicatedFirst`, `StarterGui`, `StarterPack`, `StarterPlayer.*` and
   `ServerStorage`, and **nothing else** — no `Workspace`, no `Lighting`, no `Terrain`. So the
   generated map is **not in git and has no rollback but a place-file backup**. What is in git is the
   **seed, the code and the digest** (§7.6). The harness never sees generated geometry: its
   disk-vs-Studio comparison walks the Rojo sourcemap (`compare_synced`, `synced_nodes`) and its
   unmanaged scan looks for `LuaSourceContainer` only (`unmanaged_scripts`). That last point is a trap,
   not a comfort — §8.7.

4. **A boar is a physics body on a horizontal velocity plane, and it spawns at a fixed Y, at a
   position the map supplies.** `src/server/Boar/Body.luau`, `Body.create`, builds a `LinearVelocity`
   with `VelocityConstraintMode = Plane` and tangent axes X and Z, so gravity, not code, puts the boar
   on the ground — terrain relief is fine for *walking*. But `src/server/Boar/init.luau`,
   `Runtime:spawn`, overwrites the caller's Y:
   `at = Vector3.new(at.X, self._field.groundY + config.BODY_SIZE.Y / 2 + config.SPAWN_CLEARANCE, at.Z)`
   (`SPAWN_CLEARANCE = 0.5`), and `src/server/Boar/Brain.luau`, `Brain:_outcome`, despawns a boar as
   `outOfBounds` below `field.groundY - config.FALL_LIMIT` (`FALL_LIMIT = 50`). The X and Z it is given
   come from the map: `src/server/Match/init.luau` calls `world.boars:spawn(position)` with a position
   out of `Markers.read`'s `boarSpawns`, which is a tagged part's `Position`. **So the generator must
   deliver a flat pad under every marker the game stands something on, or boars spawn inside hills**
   (§6). This design solves it entirely on the generator's side, with **no change to
   `ServerScriptService.Boar`** — the Director's decision D in `reviews/task-33/BRIEF.md`.

5. **The same is true of players.** `src/server/Match/Body.luau`, `Body.placementFor`, puts a shooter
   at `post.Position + Vector3.new(0, post.Size.Y / 2 + config.STAND_HEIGHT_STUDS, 0)`
   (`STAND_HEIGHT_STUDS = 3.5`, `src/server/Match/init.luau`, `Match.CONFIG`) and a driver across the
   `DriverStart` part's X extent. A post part floating over a slope, or buried in one, is a player
   dropped into a hill. §6 covers posts and the driver start as well as boar spawns.

6. **A free Creator Store model that the experience owner does not own cannot be loaded by any script,
   ever.** `AssetService.AllowInsertFreeAssets` is Access ReadOnly with **`RobloxScriptSecurity` on
   read *and* write**, and `InsertService:LoadAsset` requires the asset be *"created or owned by the
   game creator"*, *"shared by the asset owner"* or *"owned by Roblox"*
   (`docs/research/2026-09-26-asset-pipeline.md` sources 6 and 8, delta D9). Task 33's §8.2 made
   `InsertService:LoadAsset` the primary route for Creator Store props. That is wrong, and §8 is
   rebuilt on the two routes that actually exist at edit time.

7. **The map is baked, so "loading" and "shipping" are the same moment.** The generator inserts an
   asset **once, at edit time**, and what it leaves behind is saved into the place. There is no
   run-time load of a map prop at all. Two consequences: the run-time ownership rules in fact 6 apply
   to the *generator's* insert, not to the game; and the **licence gate that matters is `mayShip`**, not
   `mayUpload` — a prop baked into a published place is published (`docs/design/asset-pipeline.md`
   §4.5). §8.5 puts that check in the generator, where it can actually fire.

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

1. **Build one small v1 map**: European farmland and woods — fields, hedgerows, spruce and birch
   stands, tracks, a bog — with a drive area and a shooter line along a wood edge (Karen,
   `reviews/task-33/BRIEF.md`).
2. **Run at edit time only**, through the Studio MCP server, from code on disk. Never at run time,
   never in a live server, never during Play.
3. **Be reproducible from a seed**: the same commit and the same seed give the same map, provable by a
   digest (§7.6).
4. **Place every gameplay marker as a tagged, script-free instance** that `docs/design/drive.md`'s
   `Match.Markers` already reads (§4.3), on **flat ground** (§6).
5. **Reference every art asset by key through `ServerStorage.Assets`** — never by file, never by a bare
   id in this system's own code, never by a binary in the repo (§8).
6. **Refuse to bake an asset whose licence basis does not permit shipping**, and say which key and
   which basis (§8.5).
7. **Be undoable**: a machine-checked backup condition before every destructive run (§7.3), and
   `MapGen.clear()` as the in-place reset.
8. **Be checkable by machine**: a server spec that the required tags exist, are geometrically sane and
   are **reachable by the boar's own pathfinding agent** (§14.1); a client spec (§14.2); named
   Edit-mode screenshots for rule 5 (§14.3).
9. **Replace `Workspace.TestArena` with no overlap** — never two grounds, decided by one committed
   fact (§10).
10. **Cost the harness nothing**: no `default.project.json` change (so no extra Karen Connect click),
    no new Wally package, no `.rbxm`, no typed value in a `.model.json` (§9).

### 1.2 Must not

Each row is a named failure from `docs/PROJECT_CONTEXT.md`, a boundary an existing owner drew, or a
documented engine fact the Task 39 note established.

| Prohibition | Why | Whose job instead |
|---|---|---|
| Never run at run time. No `.server.luau`, no `.client.luau`, no `init.server.luau` anywhere under the generator | "Invented foundations": a map that rebuilds itself on every server start is a second writer of the world that nobody can see | `tools/mapgen.py`, at edit time, by hand |
| Never be `require`d by any runtime script | the runtime must not depend on a build tool. §14.1 check 9 asserts `ServerStorage.MapGen` contains only ModuleScripts, so nothing can autorun | game code requires `ReplicatedStorage.Map` (§4) and `ServerStorage.Assets` (§8.2) |
| Never own the asset manifest | `docs/design/asset-pipeline.md` §2.3: leaving it in `MapGen` forces either a runtime `require` of a build tool or a second copy of the ids | `ServerStorage.Assets`, which `MapGen` requires and never writes |
| Never call `InsertService:LoadAsset` or `AssetService:CreateMeshPartAsync` itself | one id→Instance seam in the repo (`docs/design/asset-pipeline.md` §2.1) | `Assets.Loader`, with the cache container this system nominates (§8.4) |
| Never write a script, or bake an asset that contains one | `CLAUDE.md`: *"Nothing script-like (Script, LocalScript, ModuleScript) is ever created in Studio"*, and the harness's unmanaged-script check fails **every run from then on** if one exists outside the sourcemap | §8.7: the template is refused, the key falls back to a proxy, and the step fails with the id and the script's name |
| Never bake a key whose licence basis has `mayShip == false` | fact 7. A baked prop is a published prop | §8.5; `Assets.BASES`, and Karen's decision on the Meshy plan (`docs/design/asset-pipeline.md` §16 Karen 1) |
| Never write `Workspace.TestArena`, `Workspace.Boars`, `Workspace.WeaponEffects` or the drive's per-player Instances | four named owners: `ServerScriptService.TestArena` (`src/server/TestArena.luau` header), `ServerScriptService.Boar`, `PlayerScripts.Weapon.Effects`, `Match.Body` (`docs/design/drive.md` §6.4) | those owners |
| Never write `Boar.CONFIG`, `Shotgun.CONFIG`, `Match.CONFIG` or any runtime state | one writer per system | their owners; the map **publishes** its rectangle and the boar's config is checked against it (§11) |
| Never touch `Lighting`, `SoundService`, `Teams` or any player | art, sound and the match are other tasks; `Match.Body` is the only writer of `Teams` and of player characters (`docs/design/drive.md` §3.2). Also: because the generator never writes `Lighting`, a rebuild cannot destroy it, which is what makes §7.3's census check sound | Milestone 2's art task; `Match.Body` |
| Never create a `Water` terrain material in v1 | water changes buoyancy and swimming, and the boar's mover is a horizontal-plane `LinearVelocity` (`src/server/Boar/Body.luau`, `Body.create`) that was never designed to swim. The bog is `Mud` and a dip, not a pond | a v1.1 task, with its own boar work |
| Never commit a Creator Store or Meshy binary, a `.rbxm`, a `.rbxmx` or a `.rbxl` | `CLAUDE.md` bans the first four outright; the Creator Store grant is *"a license to use the asset in Roblox Studio and in Experiences on the Services"* and a public git repo is not "the Services" (§12 source 10); the place file is worse (§12 source 6) | ids in `ServerStorage.Assets`; backups outside the repo |
| Never add a subcommand, a write path or an MCP tool to `tools/studio_mcp.py` | fact 1 | `tools/mapgen.py` |
| Never post keystrokes to Studio, and never claim a save happened | `tools/mapgen.py` cannot verify a menu action, and an unverifiable claim in a tool's output is the false-PASS shape this project has already paid for (`docs/PROJECT_CONTEXT.md`: *"The agent verified its own work with numbers and never looked"*) | §7.4: the tool prints the action and the proof is a reopen |
| Never delete a file to make a map (rule 7) | rule 7 | `MapGen.clear()` destroys *generated runtime instances*, which are not files; disk files are archived to `backups/` |

**One predicate answers one question.** `Map.EXPECTED_WORLD` says which world the committed code
expects. It does not say whether the arena should be built, whether streaming is on, whether an asset
is loadable, or whether the map is any good. Those are the contract's own fields (§4.1),
`Assets.BASES` (§8.5), and Karen.

---

## 2. Ownership

Rule 3: exactly one writer per system, named here, mirrored into `GAME_DESIGN.md` when the code lands.

### 2.1 The owner table (paste into `GAME_DESIGN.md` with the first map task)

| System | Owner (the only writer) | Location on disk → Studio |
|---|---|---|
| **The map contract**: tag names, the drive rectangle, the expected world, the pad, streaming and budget numbers. Frozen data, **no runtime writer at all** | `ReplicatedStorage.Map` — nothing writes it; the Builder edits the file, git records it | `src/shared/Map/init.luau` → `ReplicatedStorage.Map` |
| **The map generator**: `Terrain`, `Workspace.DrivenHuntMap` and everything in it, and the `Workspace` streaming properties. **Edit time only** | `ServerStorage.MapGen` — and within it exactly four modules touch the world: `Ground` (Terrain), `Props` (`…Map.Props`), `Markers` (`…Map.Markers` and every `CollectionService:AddTag` in the map), `Settings` (the Workspace streaming properties) | `src/serverstorage/MapGen/` → `ServerStorage.MapGen` |
| **The asset manifest, the licence policy and the one id→Instance seam** | **not this system: `ServerStorage.Assets` / `Assets.Loader`** (`docs/design/asset-pipeline.md` §2.1). `MapGen` requires it, nominates its cache container, and writes nothing in it | `src/serverstorage/Assets/` |
| **The generator invoker**: the one write path into Studio | `tools/mapgen.py`. The only thing in the repo that sends a mutating `execute_luau`, and the only caller of StudioMCP's `insert_asset` | `tools/mapgen.py` |
| **The markers the game reads** (`DrivenHunt.*` tags) | **at edit time:** `MapGen.Markers` in the generated map, `ServerScriptService.TestArena` in the grey box — never both (§10). **At run time: nobody writes them.** `Match.Markers` reads them (`docs/design/drive.md` §6.2) | as above |
| World geometry: test arena | **unchanged:** `ServerScriptService.TestArena`, booted by `ArenaBoot`, which gains one early return (§10.2) | `src/server/TestArena.luau` |

### 2.2 The modules inside `ServerStorage.MapGen`

`init.luau` plus siblings — the shape `src/server/Boar/`, `src/server/Weapon/` and `src/server/Match/`
already prove green. **Nothing happens on `require`**, the same rule `src/server/Boar/init.luau`
states in its header.

| Module | Is | Never |
|---|---|---|
| `init.luau` | **the entry point**: `VERSION`, `CONFIG`, `steps`, `runStep`, `clear`, `digest`, `census`, `verifyContract`. Holds no state between calls (fact 2) | decides a layout rule itself; writes a voxel; requires `Assets.Loader` (only `Props` does) |
| `Config.luau` | **pure data**: every number in §13, frozen with `Shotgun.deepFreeze` (`src/shared/Shotgun/init.luau`, `Shotgun.deepFreeze`) — **required, not copied**, because `table.freeze` is shallow and this repo has paid for that once (`TASKS.md` row 23a(b)) | anything else |
| `Height.luau` | **pure**: `Height.at(x, z, seed, config) -> number`, domain-warped `math.noise`, **including the pad flattening** (§6.2). The single source of ground height, called by `Ground`, `Props`, `Markers` and the digest, so nothing can disagree about where the ground is | touches Terrain, Instances, services or `Random` |
| `Layout.luau` | **pure**: the corridor, the shooter line, the post positions, the driver start, the boar spawns, the tie trees, the hedgerow polylines, the stand polygons, the track splines, the bog disc and **the pad list `Height` reads** — all plain tables of numbers | as above |
| `Scatter.luau` | **pure**: seeded placement (jittered grid, Poisson-ish) inside a polygon, rejecting the corridor, the tracks, the bog and every pad | as above |
| `Digest.luau` | **pure**: a canonical string digest of a plan plus a terrain sample set (§7.6) | as above |
| `Ground.luau` | **the only writer of `Terrain` in the repo**: one tile per call, `Terrain:WriteVoxels` | reads or writes any Instance |
| `Props.luau` | **the only writer of `Workspace.DrivenHuntMap.Props`**: `withTemplates` (§8.4), clone, anchor, size, and the proxy fallback | writes Terrain or a marker; calls an insert API itself |
| `Markers.luau` | **the only writer of `Workspace.DrivenHuntMap.Markers`** and the only caller of `CollectionService:AddTag` in the generated map | writes Terrain or a prop |
| `Settings.luau` | **the only writer of `Workspace.StreamingEnabled`, `StreamingMinRadius`, `StreamingTargetRadius`, `StreamingIntegrityMode`, `ModelStreamingBehavior`** | writes anything else |

`Height`, `Layout`, `Scatter` and `Digest` are exported as `MapGen.Height`, `MapGen.Layout`… for
specs, exactly as `src/server/Boar/init.luau` exports `Boar.Brain`, and for the same reason: the pure
core must be drivable with no Studio, no Terrain and no assets. **That is what lets a server spec test
the generator's maths in the ordinary harness run, while the generator itself never runs there.**

There is no `MapGen.Assets`. It was in the Task 33 design and it is deleted
(`docs/design/asset-pipeline.md` §15 D1).

### 2.3 What `MapGen` may require, and in which direction

```
ServerStorage.MapGen  ──requires──►  ServerStorage.Assets        (data + BASES + Loader)
ServerStorage.MapGen  ──requires──►  ReplicatedStorage.Map       (tags, field, budgets)
ServerStorage.Assets  ──requires──►  nothing in MapGen           (asserted, §14.1 check 12)
runtime scripts       ──require───►  ReplicatedStorage.Map, ServerStorage.Assets
runtime scripts       ──NEVER─────►  ServerStorage.MapGen
```

`src/serverstorage/` and `src/shared/` are already mapped (`default.project.json`), so every file this
design adds lands under an existing mapping: **no `default.project.json` change, no Rojo restart, no
extra Karen Connect click.**

---

## 3. Where a run happens, in one picture

```
 disk (git)                    tools/mapgen.py                  Studio, Edit mode
 ──────────                    ───────────────                  ─────────────────
 src/serverstorage/MapGen/ ──Rojo──────────────────────────────► ServerStorage.MapGen  (ModuleScripts)
 src/serverstorage/Assets/ ──Rojo──────────────────────────────► ServerStorage.Assets  (ids, licences)
 src/shared/Map/init.luau  ──Rojo──────────────────────────────► ReplicatedStorage.Map (the contract)
                                │
                                │ 0. REFUSE (§7.2): dirty tree / not Edit / wrong PlaceId /
                                │    Studio's MapGen+Assets+Map source != disk / no accepted backup
                                │ 1. execute_luau  MapGen.clear()
                                │ 2. execute_luau  MapGen.runStep(i, seed)   x N   ──► Terrain
                                │    (one call per step; no state survives a call)  ──► Workspace.DrivenHuntMap
                                │    a props step: insert_asset (only if §8.3 route B is needed)
                                │ 3. execute_luau  MapGen.digest()
                                │ 4. capture x 6  ──► .screenshots/
                                ▼
                       .mapgen/<utc>-<seed>.json (git-ignored run log)
                       "[mapgen] OK: 271/271 steps @ <sha> seed=7 digest=<hash> (clean tree)"
                                │
                                ▼  SAVE REQUIRED (§7.4): Karen File -> Save to Roblox, or the
                                   Director posts Alt+Shift+S to the Studio window. No tool here
                                   can verify it; the proof is a reopen plus `mapgen.py contract`.
                       the place now carries the map
```

---

## 4. The map contract — `ReplicatedStorage.Map`

`src/shared/Map/init.luau`, deep-frozen with `Shotgun.deepFreeze`. Tiny, data only, no behaviour. It
is **shared** rather than server-only for the reason `src/shared/Shotgun/` is: one file, one `require`
path, and the Hud may want the map's name later. It replicates a handful of numbers and no secret and
no asset id — ids stay in `ServerStorage.Assets`, server-side, for the reason
`docs/design/asset-pipeline.md` §2.3 gives.

### 4.1 The fields

```luau
export type FieldRect = {
    bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
    exitZ: number,
    groundY: number,
}

Map.VERSION          = "v1"
Map.EXPECTED_WORLD   = "arena"        -- or "map:v1"; THE switch, §10. One committed fact.
Map.SEED             = 0              -- the seed the committed map was built from; 0 while "arena"
Map.DIGEST           = ""             -- the digest that seed produced; "" while "arena"

Map.FIELD: FieldRect                  -- the DRIVE rectangle, not the whole map. Must equal
                                      -- Boar.CONFIG.field, asserted by §14.1 check 7.
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
Map.PAD              = { boarSpawnRadius = 14, postRadius = 10, driverStartHalf = Vector2.new(72, 18),
                         blend = 24, tolerance = 0.75 }   -- §6
Map.CORRIDOR_RELIEF  = 16             -- studs, +/- , inside Map.FIELD.bounds (§6.3)
```

### 4.2 The tag vocabulary has one home now

`docs/design/drive.md` §6.1 defines the five `DrivenHunt.*` tags. The strings exist **twice in code
today**: `src/server/TestArena.luau`, `LAYOUT.drive.tags`, and `src/server/Match/Markers.luau`,
`Markers.TAGS`. `MapGen.Markers` would be the third. That is not a second *writer*, but it is three
copies of one fact, and a typo in one produces a silent empty `GetTagged` — the "two correct pieces of
code disagreeing" shape, which `Markers.luau`'s own header already warns about (*"A TAG IS A STRING
WITH NO SCHEMA, so a typo yields an empty list and a silently dead rule"*).

**Decision: `Map.TAGS` is the one home for the strings.** `MapGen.Markers` writes from there,
`Match.Markers` reads from there, `TestArena` tags from there. Cost: one `require` in each. The swap is
a small change inside each owner's own file and belongs to the first map task — listed in §11 as a
cross-system change, not a blocker.

### 4.3 What the markers are, physically

Every marker is an **`Anchored`, `CanCollide = false`, `CanQuery = false`, `Transparency = 1` `Part`**
under `Workspace.DrivenHuntMap.Markers`, named for its kind and index (`ShooterPost1`…`ShooterPost8`),
sized as `docs/design/drive.md` §6.1 specifies, and tagged. Invisible and inert: a marker that can be
shot, walked into or collided with is a gameplay object pretending to be metadata.

Two shapes are load-bearing and are not the generator's choice:

- **The drive line is exactly one part**, `size = (560, 1, 1)` at the line's z, and its
  `CFrame.LookVector` points at **+Z, toward the drivers**. `src/server/Match/Markers.luau` publishes
  `normal = lines[1].CFrame.LookVector`, `src/server/Weapon/SafetyArc.luau` consumes it, and two
  tagged lines make `complete = false`. Build it with `CFrame.lookAt`, as
  `src/server/TestArena.luau`'s `buildDriveMarkers` does.
- **A shooter post is a part a character is put down on top of**, because
  `src/server/Match/Body.luau`, `Body.placementFor`, adds `post.Size.Y / 2 + STAND_HEIGHT_STUDS`.
  So a post is a **visible, solid** part (a low platform, `CanQuery = true`, `CanCollide = true`,
  `Transparency = 0`) standing on its own flat pad with its base at `groundY` — the one marker kind
  that is real geometry rather than metadata, and the reason §6 covers posts.

`DrivenHunt.Tree` is the other exception: it goes on **≤ 12 real trunk parts near the shooter line**,
chosen by `Layout`, because it is the tie-up anchor (`docs/design/drive.md` §8.4) and a player tied to
a spruce 900 studs away is a teleport. **The forest's other ~2,988 trees are not tagged** —
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
    assetKeys: { string },    -- which manifest keys this step needs; {} for a pure-geometry step
    estimatedMs: number,
}

export type StepReport = {
    index: number, kind: string, label: string,
    ok: boolean, message: string?,
    voxelsWritten: number?, partsCreated: number?,
    assetsUsed: { string }?,          -- keys whose real template was baked
    proxiesUsed: { [string]: number }?, -- key -> count, where a grey proxy stood in (§8.6)
    assetProblems: { [string]: string }?, -- key -> "no-row" | "licence-blocked" | "contains-script"
                                          --        | "insert-failed" | "quarantined" | "not-staged"
    elapsedMs: number,
}

MapGen.VERSION: string
MapGen.CONFIG: Config                       -- frozen
MapGen.steps(seed: number): { StepSpec }     -- pure; the plan of the whole run, no side effect
MapGen.runStep(index: number, seed: number): StepReport   -- performs exactly one step
MapGen.clear(): { removed: number, terrainCleared: boolean }
MapGen.digest(): { digest: string, markerDigest: string, parts: number, samples: number,
                   seed: number, version: string }
MapGen.census(): Census                      -- READ-ONLY. §7.3: what a run could destroy
MapGen.verifyContract(): { ok: boolean, findings: { string }, counts: { [string]: number } }
MapGen.retag(): { tagged: number }           -- only exists if measurement B says tags do not persist
```

Every one returns a plain table. `tools/mapgen.py` wraps the call in `HttpService:JSONEncode`, so an
MCP reply is machine-readable and lands in the run log verbatim — the same discipline
`tools/studio_mcp.py` uses for the test report (`QUERY_REPORT`, `luau_json`).

### 5.2 The layer order, which is also the step order

Each layer is a pure function of the seed and the layers before it, so one can be re-run alone
(`docs/research/2026-09-24-map-generator.md`, pattern point 3):

1. **clear** — `Terrain:Clear()`, destroy `Workspace.DrivenHuntMap`. One step.
2. **terrain** — `Ground.writeTile(tx, tz, seed)`, one step per tile: height → occupancy → material
   (`Grass` field, `LeafyGrass` rough edges, `Ground` track, `Mud` bog). 16 tiles for the 512 slice,
   256 for the full map (§13.2).
3. **hedgerow** — `Props.hedge(line, seed)`, one step per hedgerow polyline.
4. **stand** — `Props.stand(polygon, seed)`, one step per tree stand.
5. **track** — `Ground.paintTrack(spline)` (material only; the height was flattened in 2).
6. **bog** — `Ground.paintBog(disc)`, plus reeds.
7. **props** — fences, gates, stones, the high seats.
8. **markers** — `Markers.place(layout)`. Last of the world layers, so a marker is never orphaned by a
   later step, and the posts stand on pads the terrain step already flattened.
9. **settings** — `Settings.apply(Map.STREAMING)`. Deliberately last: a streaming change during
   generation would make the rest of the run fight the engine. Inert while
   `Map.STREAMING.enabled == false` (M2.6).

### 5.3 The heightfield

`Height.at(x, z, seed, config)` — the technique read out of **RTerrainGenerator** (§12 source 5) and
implemented from scratch on `math.noise`:

```
w  = warp * (noise(x*wf + ox, z*wf + oz), noise(x*wf + ox + 313.7, z*wf + oz + 71.3))
h  = Σ_{o=1..OCTAVES} amp_o * noise((x + w.x + ox) * f_o, (z + w.y + oz) * f_o)
h  = h * RELIEF                          -- studs
h  = h * corridorFalloff(x, z)           -- 1 outside the corridor, -> CORRIDOR_RELIEF/RELIEF inside
h  = flattenPads(h, x, z, layout.pads)   -- §6.2, LAST, so nothing can undo it
return groundY + h
```

**The seed reaches the noise as a coordinate offset** (`ox`, `oz` from `Random.new(seed)`), because
`math.noise` has no seed parameter (§12 source 2). Everything discrete (which tree, where, hedgerow
gaps) comes from `Random.new(seed * 1000 + LAYER_ID)`, **one RNG per layer**, never a shared sequence:
with one shared sequence a step's output would depend on which steps ran before it in that MCP call,
and fact 2 means that is not knowable.

### 5.4 Statelessness, restated as a rule the Builder can check

> A step may read: its arguments, `MapGen.CONFIG`, `ReplicatedStorage.Map`, `ServerStorage.Assets`,
> the pure modules, and the world as it currently stands. A step may not read: a module upvalue
> written by an earlier step, a cached plan, a memo table, **an `Assets.Loader` cache entry from an
> earlier call**, or `Workspace` for anything but its own idempotence check.

Every world-writing step is **idempotent**: re-running step 7 destroys and rebuilds
`…Map.Props.Hedge3`, it does not add a second one. That is how a failed step is retried, and it is the
property that makes `--step` useful.

---

## 6. Flat pads and the height band — the geometry the game's existing code requires

This is the section the Task 33 design cited seven times and did not contain. It is the Director's
decision D (`reviews/task-33/BRIEF.md`): **flatten the pads in terrain; the boar stays untouched.**

### 6.1 Why, with the code that forces it

| Fact | Evidence | What breaks without a pad |
|---|---|---|
| A boar's spawn Y is `field.groundY + BODY_SIZE.Y/2 + SPAWN_CLEARANCE`, whatever the caller passed | `src/server/Boar/init.luau`, `Runtime:spawn` | a `BoarSpawn` marker on ground 12 studs high spawns the boar 12 studs **inside the hill**; on ground 12 studs low it drops |
| The spawn X and Z come from a tagged marker's `Position` | `src/server/Match/init.luua`'s `world.boars:spawn(position)`, fed by `Markers.read`'s `boarSpawns` | the generator, not the boar, decides whether that point is flat |
| A boar below `groundY - FALL_LIMIT` (50) despawns as `outOfBounds` | `src/server/Boar/Brain.luau`, `Brain:_outcome`; `Boar.CONFIG.FALL_LIMIT` | relief deeper than 50 studs inside the field deletes boars silently |
| A shooter is placed at `post.Position + (0, post.Size.Y/2 + 3.5, 0)` | `src/server/Match/Body.luau`, `Body.placementFor`; `Match.CONFIG.STAND_HEIGHT_STUDS` | a post part hovering over a slope drops the player; a buried one embeds them |
| Drivers spread across the `DriverStart` part's X extent | same function, the `Drivers` branch | a 144-stud strip across a slope spawns half the team in the air |

### 6.2 The rule

A **pad** is a disc or rectangle where `Height.at` returns exactly `groundY`, with a smooth blend to
the noise height over `Map.PAD.blend` studs. `Layout` emits the pad list; `Height.flattenPads` applies
it **last**, so no later term can reintroduce a slope:

```
for each pad:
    d = distance from (x, z) to the pad's edge      -- 0 inside
    if d <= 0            then return groundY
    if d <  blend        then h = h * smoothstep(d / blend)
```

Pads, from `Layout`:

| Pad | Shape | Number |
|---|---|---|
| boar spawn | disc, radius `PAD.boarSpawnRadius` | 4 |
| shooter post | disc, radius `PAD.postRadius` | 8 |
| driver start | rectangle, half-extents `PAD.driverStartHalf` | 1 |

`Scatter` rejects every pad plus its blend ring, so no tree grows out of a spawn point, and
`Ground.paintTrack` / `paintBog` may paint material over a pad but may never change its height.

### 6.3 The corridor band

Inside `Map.FIELD.bounds` the relief is scaled to `Map.CORRIDOR_RELIEF = 16` studs
(`corridorFalloff`, §5.3), against `± 40` for the rest of the map. Two reasons, both numeric: 16 is far
inside `FALL_LIMIT = 50`, so terrain can never despawn a boar; and a 16-stud band over 1,600 studs of
drive is a gentle field rather than a valley the boar's `LinearVelocity` plane has to climb.

### 6.4 What is asserted, and where

- §14.1 check 4: every `BoarSpawn` marker's `Position.Y` is within `Map.PAD.tolerance` (0.75) of
  `Map.FIELD.groundY`. This is the check that stops a boar spawning inside a hill, and it fails on the
  *marker*, which is the thing the game reads.
- §14.1 check 4b: every `ShooterPost` part's **bottom face** is within `tolerance` of `groundY`, and the
  `DriverStart` part's four corners likewise.
- §14.1 check 10: 64 downward rays across the corridor all hit `Workspace.Terrain` inside the corridor
  band.
- A pure spec on `MapGen.Height`: `Height.at` at each pad centre equals `groundY` exactly, and at
  `blend + 1` studs outside a pad it equals the unflattened height — so the blend cannot silently
  swallow the whole map, which a bug in `smoothstep` would do.

---

## 7. Invoking a run: `tools/mapgen.py`

Allowed past `ROADMAP.md` speed rule 1 by the Director: *"A: allowed. `tools/mapgen.py` is game work
for Karen's map option C, not a process improvement; the tooling freeze does not apply to it"*
(`reviews/task-33/BRIEF.md`).

### 7.1 Commands

```
python tools/mapgen.py plan     [--seed N]                   # read-only: the steps and the plan
python tools/mapgen.py census                                # read-only: what a run could destroy (§7.3)
python tools/mapgen.py build    --seed N --backup <accepted>  # clear, then every step, in order
python tools/mapgen.py step  <i,j,k> --seed N --backup <accepted>
python tools/mapgen.py clear    --backup <accepted>           # Terrain:Clear() + destroy the map root
python tools/mapgen.py verify   --seed N --backup <accepted>  # build, digest, clear, build, digest, compare
python tools/mapgen.py digest                                # read-only
python tools/mapgen.py contract                              # read-only: MapGen.verifyContract()
python tools/mapgen.py shots                                 # read-only: the six named captures (§14.3)
```

Exit codes, deliberately the harness's shape: **0** done · **1** a step failed · **2** REFUSED.

### 7.2 What it refuses, before it touches anything

Every one is a `REFUSED` (exit 2) with the reason printed. A generator that runs anyway is how a place
gets destroyed.

1. **Studio not in Edit mode**, or `game.PlaceId != servePlaceIds[0]` — reuse `Studio.mode()` and
   `expected_place_id()` from `tools/studio_mcp.py`.
2. **A dirty tree** for any mutating command (`git_state()`): a map built from uncommitted code cannot
   be reproduced from a commit, and *"PASS on a dirty tree is not valid evidence"* is already this
   project's rule (`tools/studio_mcp.py`, exit code 3).
3. **Studio's copy of the code differs from disk.** Read the `Source` of every
   `ServerStorage.MapGen.*`, `ServerStorage.Assets.*` and `ReplicatedStorage.Map` script and compare
   byte-for-byte with line endings normalised — the comparison `compare_synced` makes. Catches "Rojo is
   not connected" and "Karen has not pressed Connect since the last edit", which would otherwise build
   yesterday's map from today's seed. **`Assets` is in this list now:** building from a stale manifest
   would bake an id the commit does not name.
4. **No accepted backup** — §7.3.
5. **`--seed` missing** on `build`/`verify`. There is no default seed: an unnamed seed is an
   unreproducible map.
6. **A required asset key is missing from `Assets.ROWS` *and* proxies are disabled.** Proxies are on by
   default (§8.6), so this fires only when a task deliberately demands the real thing.

### 7.3 The backup rule, and exactly what the refusal accepts

The brief asks for this explicitly, so here is the whole reasoning, not just the rule.

**What a run can destroy.** Only two things, because §1.2 forbids the rest: the global `Terrain`
(`MapGen.clear` calls `Terrain:Clear()`), and `Workspace.DrivenHuntMap`. It never writes `Lighting`,
`SoundService`, `ServerStorage`, `ReplicatedStorage` or any player. Everything in a Rojo-owned
container is on disk and in git by construction.

**What cannot be automated.** `File → Save to File` writes the `.rbxl` that is the only rollback
Workspace has (§12 source 6). There is **no tool route to it**: StudioMCP's enumerated tool list
(`docs/research/2026-09-24-map-generator.md` §12) has no save tool, and the Director's key-posting
route — the mechanism recorded in `tools/studio_mcp.py`'s docstring under *"Starting it WITHOUT
Karen"*, a PowerShell script outside the repo that brings the DEV Studio window to the front and posts
a key to it — can press **Alt+Shift+S (Save to Roblox)** but has no shortcut for Save to File
(`reviews/task-42/BRIEF.md`). Save to Roblox is not a backup anyway: it *overwrites* the place with
the current state.

**So `--backup` accepts exactly two things, and one of them needs no human:**

| Form | Accepted when | Checked by |
|---|---|---|
| `--backup <path>.rbxl` | the file exists, is **outside the repository**, is non-empty, and was modified within `BACKUP_MAX_AGE_HOURS = 6` | `os.stat` plus a repo-root containment test. Karen's `File → Save to File`, a `NEEDS KAREN` click |
| `--backup census` | `MapGen.census()` proves the place holds **nothing a run could destroy that is not reproducible from committed code plus a seed** — see below | the tool, with one read-only MCP call. **No human** |

```luau
export type Census = {
    workspaceChildren: { { name: string, className: string } },  -- every child of Workspace
    unknownChildren: { string },     -- not in { Camera, Terrain, DrivenHuntMap, TestArena }
    terrainOccupiedRegions: number,  -- count of non-empty sample regions on the digest lattice
    terrainDigest: string,           -- the terrain half of §7.6's digest
    mapRootExists: boolean,
    scriptsUnderWorkspace: number,   -- must be 0 (§8.7)
}
```

`--backup census` is accepted when **all** of:

1. `unknownChildren` is empty. Anything else in `Workspace` is hand-made content with no home on disk,
   and a rebuild is not allowed to proceed on a guess about it. (At this commit that set is exactly
   `Camera` and `Terrain`: `TASKS.md` row 22 moved the default `Baseplate` and `SpawnLocation` into
   `ServerStorage.Archive`, and `src/server/TestArena.luau`'s header records that the arena is the only
   other thing in Workspace.)
2. either `terrainOccupiedRegions == 0` (nothing sculpted), or `terrainDigest` equals the terrain half
   of the committed `Map.DIGEST` — i.e. the terrain that exists is this repo's own output from
   `Map.SEED` and can be rebuilt by `build --seed <Map.SEED>`.
3. `scriptsUnderWorkspace == 0`.

**Why that is sound, stated as the claim it is:** if the only things a run can destroy are (a) nothing
and (b) something a committed seed reproduces, then a place file protects nothing the repository does
not already hold. The moment either stops being true — Karen sculpts a hill, drags in a model, keeps a
prototype in Workspace — condition 1 or 2 fails, the tool refuses, and the `.rbxl` becomes mandatory
again. **The refusal is the safety mechanism, not the backup.**

**And what it refuses to accept, deliberately:** any flag that asserts a save or a backup happened
without evidence — `--backup roblox`, `--saved`, `--i-saved-it`. `tools/mapgen.py` cannot observe a
Studio menu action or a cloud version, and a tool that prints OK on an unverifiable attestation is the
exact failure `docs/PROJECT_CONTEXT.md` opens with. If Roblox's own version history is later shown to
be a usable rollback for this place, that is a new, cited accepted form — **not verified here, and this
design does not rely on it.**

### 7.4 Persisting the result, and what proves it

An unsaved map dies with the Studio session. The save is **not** part of the run, and `mapgen.py` never
posts a keystroke (§1.2). After a successful run the tool prints:

```
SAVE REQUIRED: the map exists only in this Studio session.
  Karen:        File -> Save to Roblox
  the Director: post Alt+Shift+S to the DEV Studio window (the press-F7 mechanism,
                tools/studio_mcp.py docstring, "Starting it WITHOUT Karen"; the script is outside the repo)
PROOF: reopen the place, then `python tools/mapgen.py contract`. Nothing here can verify a save.
```

That reopen-and-`contract` is the same action as **measurement B** (§14.5): it answers "did the save
happen" and "do `CollectionService` tags survive a save and a reopen" in one pass.

### 7.5 Chunking, timeouts and progress

One MCP call per step, `Studio._rpc(..., timeout=MAPGEN_CALL_TIMEOUT)` with
`MAPGEN_CALL_TIMEOUT = 180` s against a per-step design target of ≤ 60 s (§13.3). Reasons, in order:

- `_rpc`'s default timeout is 120 s (`tools/studio_mcp.py`, `Studio._rpc(self, method, params,
  timeout=120)`), and a whole-map run in one call would exceed it. Whether StudioMCP has its own
  ceiling is **unverified**; chunking makes the question moot.
- A failed tile names itself. A single 20-minute call that returns "error" names nothing.
- Fact 2 forbids carrying state across calls anyway, so the chunk boundary is free.

Every `StepReport` is printed as it lands and appended to `.mapgen/<utc>-<seed>.json` (git-ignored; new
`.gitignore` entry). The final line is the one the Builder pastes into `reviews/task-<N>/REQUEST.md`:

```
[mapgen] OK: 271/271 steps @ <full HEAD sha> seed=7 digest=<64 hex> (clean tree)
```

It is **not** a harness line and never substitutes for one (`CLAUDE.md`, git workflow step 4).

### 7.6 Reproducibility: the digest

`MapGen.digest()` returns two hex strings over a **canonical** serialisation:

- `markerDigest` — every instance under `Workspace.DrivenHuntMap.Markers`, sorted by full name, as
  `name|ClassName|x|y|z|sx|sy|sz` with each number rounded to 0.01, plus every tag on every tagged
  instance, sorted.
- `digest` — `markerDigest`, plus the same serialisation for `…Map.Props`, plus
  `DIGEST_TERRAIN_SAMPLES = 4096` terrain occupancy/material samples on a fixed 64 × 64 lattice (read
  with `Terrain:ReadVoxels`, one region per row), occupancy rounded to 0.01.

`python tools/mapgen.py verify --seed N` builds, digests, clears, builds again and compares. **A
mismatch is the answer to the research note's biggest open question** — whether `math.noise` is stable
within a session and across engine versions (§12 source 2). If it is not, the fallback is named there:
a small seeded value-noise implementation in `Height.luau`, ~40 lines, which makes reproducibility ours
rather than borrowed. That branch is a measurement, not a decision, so it blocks nobody.

The digest of the accepted map is committed as `Map.DIGEST`, and §14.1 check 11 asserts the live
`markerDigest` still matches its committed half (not the full terrain digest, which is too slow for a
spec). That is the guard against a hand edit in Studio silently becoming the map — and it is the same
number `--backup census` condition 2 leans on.

### 7.7 Recovery

There is no Ctrl+Z. `ChangeHistoryService` is plugin-security and whether `execute_luau` can reach it
is **unverified**; this design does not rely on it. Three routes, in order of use:

1. `python tools/mapgen.py build --seed <same>` — rebuild, deterministic, no human.
2. `python tools/mapgen.py clear` — back to an empty world, then flip `Map.EXPECTED_WORLD` to
   `"arena"` and the grey box returns at the next server start (§10).
3. Karen opens the `.rbxl` — the only route that recovers anything the generator did not make, and the
   only reason §7.3's first form exists.

---

## 8. Assets at edit time — rewritten for D9

### 8.1 What Task 39 changed

Task 33 §8.2 said: *"Primary route: `InsertService:LoadAsset(id)` from the generator's own Luau"*, for
Creator Store props. `docs/research/2026-09-26-asset-pipeline.md` D9 killed that for anything Karen
does not own: `LoadAsset` requires the asset be *"created or owned by the game creator"*, *"shared by
the asset owner"* or *"owned by Roblox"*; the documented escape is
`AssetService:LoadAssetAsync` **with `AssetService.AllowInsertFreeAssets`**, and that property is
Access ReadOnly with **`RobloxScriptSecurity` on read *and* write**. No script can set it. There is no
workaround and there is no measurement that will produce one.

What survives, and it is most of the plan: **Karen's own uploads are fine by construction.** Everything
`tools/assets.py` puts on her account satisfies *"created or owned by the game creator"*
(`docs/design/asset-pipeline.md` §5.5 route A). The narrowing is only about models she did not make.

### 8.2 The manifest is not this system's

`ServerStorage.Assets` owns the ids, the licence bases and the loader
(`docs/design/asset-pipeline.md` §2.1). `MapGen` **requires** it and writes nothing in it. The reason
is in that design's §2.3 and it is a real defect in Task 33: the generator may not be required by a
runtime script (§1.2), `Boar.Body` is a runtime script that needs an id, so a manifest inside `MapGen`
forces either a runtime `require` of a build tool or a second copy of the ids.

`MapGen` uses exactly these, all read-only: `Assets.byKey(key)`, `Assets.BASES`, `Assets.budget(key)`,
`Assets.KEYS`, `Assets.keysFor("map")`, and `Assets.Loader`.

### 8.3 The two insertion routes at edit time, and which is which

| Route | Mechanism | For | Reproducible from git? |
|---|---|---|---|
| **A — primary** | `Assets.Loader.preload{…}` → `InsertService:LoadAsset(row.modelId)` inside a `pcall`, into the container this system nominates | **every asset Karen owns**: her Meshy uploads (`meshy-paid-owned`, `meshy-free-ccby`), her own work, a **purchased** Creator Store asset, a free one whose creator ticked share, anything Roblox owns | **Yes.** id + seed + code |
| **B — named fallback, unverified** | `tools/mapgen.py` calls StudioMCP's `insert_asset` into `Workspace.DrivenHuntMap.Staging` **before** the step that needs the key; `Props` finds the template there by key name and treats it exactly like A's | a **licensed** model that route A cannot load: in practice a shared-free or purchased Store model whose route-A load fails, and nothing else | **Partly.** The insert is a tool call, not Luau; the run log records the id, and the step fails loudly if the staged template is absent (`not-staged`) |

`insert_asset` is in StudioMCP's enumerated tool list
(`docs/research/2026-09-24-map-generator.md` §12) and has **never been called by this repo** — the
harness is read-only by construction. Whether it can place a model the place's owner does not own, and
whether it works in Edit mode at all, is **measurement M5** (§14.5). `tools/mapgen.py` reaches it
through `Studio._call("insert_asset", …)` in one adapter function, because `tools/studio_mcp.py` must
not grow a public write path (§1.2); that is a deliberate use of a private method and it is the only
one.

**Route C, for completeness, is not a route:** Karen inserts a model by hand in Studio and the
generator adopts it from `…Map.Staging`. Mechanically identical to B without the tool call. It costs a
click per rebuild and it is the last resort, not a plan. Exporting such a model to
`src/serverstorage/` as `.model.json` is the *other* last resort and it needs `TASKS.md` row 16 (§9).

### 8.4 Templates live for one MCP call, not one run

Task 33 said "insert once per run". **Fact 2 makes that impossible**: `execute_luau` hands every call a
fresh copy of every module, so `Assets.Loader`'s cache table is empty at the start of every step. The
correct unit is the **call**:

```luau
-- Props.luau
function Props.withTemplates(keys: { string }, stepIndex: number, fn: (get: (string) -> Instance?) -> ())
    local staging = Instance.new("Folder")          -- …Map.Staging.Step<i>, created here
    staging.Name = string.format("Step%d", stepIndex)
    staging.Parent = stagingRoot()                  -- Workspace.DrivenHuntMap.Staging
    Assets.Loader.setCacheParent(staging)           -- NOT ServerStorage.AssetCache: see below
    local reports = Assets.Loader.preload(keys)     -- yields; edit time, so that is fine
    fn(function(key) return Assets.Loader.template(key) end)
    Assets.Loader.clear()                           -- destroys only what it created (rule 7)
    Assets.Loader.setCacheParent(nil)
    staging:Destroy()                               -- nothing survives the call
end
```

Three properties that are not tidiness:

- **`setCacheParent` must point into `Workspace`, never `ServerStorage`.** `ServerStorage` and
  `ReplicatedStorage` are fully Rojo-owned and default to `$ignoreUnknownInstances: false`, so a
  template cached there is **deleted at Karen's next Connect** (`CLAUDE.md`, "Rojo DELETES
  Studio-created instances in Rojo-owned containers"). The Loader's default
  `ServerStorage.AssetCache` is correct at run time and wrong at edit time; this is why its interface
  takes a container (`docs/design/asset-pipeline.md` §6.8).
- **The staging folder is destroyed inside the same call.** A template left in Workspace renders, gets
  screenshotted, and ends up in the digest.
- **Cost, named:** one insert per key per step instead of per run. At edit time that is acceptable and
  it is not optional. §13.3 budgets it.

### 8.5 The licence gate, in the generator, where it can fire

Fact 7: baking is shipping. So before `Props` uses a real template for a key:

```luau
local row = Assets.byKey(key)
if not row then                                     -- proxy, report "no-row"
elseif not Assets.BASES[row.licence.basis].mayShip then  -- proxy, report "licence-blocked"
else ... use the template ...
```

Two consequences worth stating plainly rather than discovering:

- `Assets.BASES["meshy-free-ccby"].mayShip` defaults to **false** (`docs/design/asset-pipeline.md`
  §4.5). So **until Karen answers the Meshy-plan question, every free-plan Meshy prop is a grey
  proxy** and the step says so. That blocks **M2.3**, not M2.1 or M2.2, and it is her one-boolean
  decision, not the Architect's.
- The Loader's own refusals (`quarantined`, `contains-script`, `insert-failed`) stay where they are; this
  gate is additional and stricter, because `mayUpload` is not `mayShip`.

### 8.6 No id yet? A grey-box proxy, not a blocked task

If `Assets.byKey` returns `nil`, or the licence gate refuses, or the insert fails, `Props` places a
**proxy**: an `Anchored` `Part` of `row.sizeStuds`' footprint and height (or the config's proxy size
for a key with no row at all), in the key's proxy colour, `CanCollide` as the real prop would be. The
step reports `proxiesUsed[key]`.

**The whole map is therefore buildable and walkable today**, with no asset ids and no decisions from
anyone, and each id later replaces one proxy with no code change. This is Milestone 1's own method
applied to the world, and `docs/design/asset-pipeline.md` §5.3 already mirrors it for game models.

Proxy colours are picked for the Task 22 albedo trap: at the place's default ambient an unlit face
renders at roughly 0.275 × albedo (`src/server/Boar/init.luau`, the `BODY_COLOR` comment), so a proxy
at RGB(60, 70, 50) reads black on screen and **looks like a hole in the map**. Proxy albedo is never
below RGB(120, 120, 120) on any channel-max.

### 8.7 A template containing a script is refused, not stripped

`Assets.Loader` walks a template for `LuaSourceContainer` descendants before the first clone and
refuses it with `contains-script` (`docs/design/asset-pipeline.md` §5.4). For a **route B** staged
template the Loader never saw it, so **`Props` performs the same walk itself** on anything it finds in
`…Map.Staging`, destroys it, proxies the key and fails the step with the id and the script's name.

This is not paranoia. Free models routinely carry scripts, and one surviving `Script` under Workspace
makes the harness's unmanaged-script check fail **every run from then on**
(`tools/studio_mcp.py`, `unmanaged_scripts`). Refusing rather than stripping is deliberate: a stripped
model is half-functional in ways nobody looks for, and the right answer is a different asset.

### 8.8 Which props are Creator Store, as of this document

`docs/design/asset-pipeline.md` §16 Karen 3 and its Director item A: *"treat 'the map's small props are
Creator Store where they fit' as withdrawn"* until measurement M5, and **Meshy for everything in the
per-key budget table**. This design adopts that. `ROADMAP.md` speed rule 6 ("Creator Store assets
first") is therefore **narrowed by evidence, not by preference**: a free Store model is licensed *and*
script-loadable only if one flag was ticked by its creator (`docs/research/2026-09-26-asset-pipeline.md`
sources 8, 14 and 15), and that is the Director's call to record.

---

## 9. The typed-value question (`TASKS.md` row 16), answered

**The map generator does not need the harness to learn typed values, and this design deliberately
keeps it that way.** Row 16's note assumed "templates on disk"; there are none.

| Thing you might put on disk | Where it goes instead | Why |
|---|---|---|
| Prop templates (`Part`/`MeshPart` with `Size`, `Color`, `CFrame`) | **nowhere**: props are `Instance.new` in `Props.luau`, or a clone of a template the Loader made from an id | a `.model.json` carrying a `Vector3` fails the harness as "cannot compare" (`tools/studio_mcp.py`, `is_plain`/`same_value`), and an asset binary is banned outright |
| The map's numbers (sizes, offsets, colours) | `Config.luau` and `src/shared/Map/init.luau`, plain Luau | Luau has `Vector3` and `Color3` natively, selene and StyLua lint it, the harness compares the **source byte-for-byte**, and a diff of a number is readable in a PR |
| Asset ids and provenance | `src/serverstorage/Assets/init.luau` (not this system, §8.2) | same |
| Marker positions | computed by `Layout.luau` from the corridor numbers | a hand-written coordinate table is what goes stale when the corridor moves |

**One case does need row 16, and D9 created it:** a free Creator Store model whose creator did **not**
tick share cannot be loaded by any script, so the only way to keep one is to insert it in Studio by
hand and export it as `.model.json` — typed values. §8.3 route C. **The recommendation is to avoid the
case, not to unblock row 16 for it.**

**Recommendation to the Director, unchanged and already agreed (`reviews/task-33/BRIEF.md` decision B):
row 16 stays under "before release", and its "lands with the map generator" note is wrong.** It is
still a real hole in the harness — audit-002 #1 stands — it is simply not this system's blocker.

---

## 10. Replacing `Workspace.TestArena` cleanly

### 10.1 The hazard, precisely

`src/server/ArenaBoot.server.luau` calls `TestArena.build()` at **every server start**, and
`TestArena.build` is idempotent only against its own folder — it knows nothing about a generated map.
Left alone, the first Play after the map lands puts a 400 × 400 grey plate with its top at y = 0
(`LAYOUT.ground`), eight concrete blocks and a second `SpawnLocation` (`LAYOUT.spawn`, `ArenaSpawn`) in
the middle of the farmland — **and a second full set of the five `DrivenHunt.*` tags**
(`buildDriveMarkers`), which is worse than the geometry: `Match.Markers` would see two drive lines and
report `complete = false`, so the drive would sit in `Waiting` for ever. That is Task 17's z-fighting
bug with better scenery and a dead match.

### 10.2 The switch: one committed fact, read by two readers, written by nobody at run time

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
  rollback (§7.7 route 2).
- **The spec cannot go green by accident**, because §14.1 asserts the world the *committed contract*
  names and that the other one is absent — there is no branch where nothing is checked.

### 10.3 The order of the switch, with every human action in it

1. **Backup:** `--backup census` if §7.3's conditions hold (no human), otherwise Karen's
   `File → Save to File` outside the repo (`NEEDS KAREN`).
2. `python tools/mapgen.py build --seed <N> --backup <accepted>`.
3. `python tools/mapgen.py contract` and `shots`; the Builder inspects the six images (rule 5).
4. **Save:** Karen `File → Save to Roblox`, or the Director posts Alt+Shift+S (§7.4).
5. Reopen the place; `python tools/mapgen.py contract` again. **This is measurement B** (§14.5): do
   tags and terrain survive a save and a reopen?
6. The code commit flips `Map.EXPECTED_WORLD` to `"map:v1"`, sets `Map.SEED` and `Map.DIGEST`, sets
   `Map.FIELD` to the drive rectangle (§13.1), and updates `Boar.CONFIG.field` to the same numbers — a
   data change inside `ServerScriptService.Boar`'s own file, by its owner.
7. Harness run. §14.1 now takes the map branch.
8. Karen walks it (the feel gate; nothing here can judge it).
9. **Only after Karen accepts:** a separate task archives `src/server/TestArena.luau`,
   `src/server/ArenaBoot.server.luau` and `tests/server/test_arena.spec.luau` to `backups/` with a note
   (rule 7), and removes the early return with them.

---

## 11. What this system reads from and writes to other systems

| Direction | What | The other side's owner | Evidence |
|---|---|---|---|
| **writes** | `Terrain` (global) | none existed; **this design gives Terrain its first owner: `MapGen.Ground`** | `Terrain` is a single global object with no notion of ownership (§12 source 1) |
| **writes** | `Workspace.DrivenHuntMap` and every descendant | `MapGen` (`Props`, `Markers`) | this design |
| **writes** | `Workspace.StreamingEnabled` and the four streaming properties | `MapGen.Settings`; no other writer in the repo | grep: no occurrence in `src/` at this commit |
| **writes** | `CollectionService` tags on map instances, at edit time | `MapGen.Markers` | `docs/design/drive.md` §6.1 |
| **reads** | `Map.TAGS`, `Map.FIELD`, `Map.PAD`, `Map.STREAMING`, `Map.BUDGET` | nobody writes them at run time | §4 |
| **reads** | `Assets.byKey`, `Assets.BASES`, `Assets.budget`, `Assets.KEYS` | `ServerStorage.Assets` (data, no runtime writer) | `docs/design/asset-pipeline.md` §4.2 |
| **calls** | `Assets.Loader.setCacheParent` / `preload` / `template` / `clear`, at **edit time only** | `ServerStorage.Assets.Loader` — the only caller of `InsertService:LoadAsset` in the repo | `docs/design/asset-pipeline.md` §2.1, §6.8 |
| **is read by** | the five `DrivenHunt.*` tags, at run time | `Match.Markers` (`Markers.read`), which validates and reports what is missing and keeps the match in `Waiting` if the map is incomplete | `src/server/Match/Markers.luau` |
| **is read by** | the ground, by the boar's pathfinding | `ServerScriptService.Boar` — `Boar.defaultWorld`'s `requestPath` uses `PathfindingService:CreatePath(config.AGENT)` | `src/server/Boar/init.luau` |
| **is read by** | the ground and the trees, by the shotgun's rays | `ServerScriptService.Weapon` — `Weapon.Cast` is the only caller of `Workspace:Raycast` in that system | `src/server/Weapon/Cast.luau` |
| **is read by** | post parts and the driver start, when a character is placed | `Match.Body` (`Body.placementFor`, `Body.place`) | `src/server/Match/Body.luau` |
| **constrains** | `Boar.CONFIG.field` must equal `Map.FIELD` | `ServerScriptService.Boar` owns the change; §14.1 check 7 asserts the equality | `src/server/Boar/init.luau`, `Boar.CONFIG.field` |
| **cross-system change** | `Match.Markers` (`Markers.TAGS`) and `TestArena` (`LAYOUT.drive.tags`) take their tag strings from `Map.TAGS` | their own owners, in their own files | §4.2 |
| **cross-system change** | `ArenaBoot` gains the early return | `ServerScriptService.TestArena`'s owner | §10.2 |

**Nothing else.** In particular: no change to `src/server/Boar/Brain.luau`, `Body.luau` or
`Wound.luau`; no change to any weapon, camera, Hud or Match module beyond the tag-string swap; no
change to `tools/studio_mcp.py`; no change to `default.project.json`.

---

## 12. External sources

Eleven. **Honesty about how each was read**, because this repo has three recorded cases of a design
citing a page that said something else (`docs/research/INDEX.md`; `TASKS.md` row 26a):

- **This session had no network.** Nothing below was fetched by me.
- Sources 1–7 are quoted from `docs/research/2026-09-24-map-generator.md`, whose session did have
  network (it records an HTTP 403 where a fetch failed). That note is their citation of record.
- Sources 8–11 are quoted from `docs/research/2026-09-26-asset-pipeline.md`, which **fetched every one
  live on 2026-09-26** and is their citation of record. Where this section and that note differ, **the
  note is right**.

### 1. Roblox `Terrain` — the voxel API the ground is written through
<https://create.roblox.com/docs/reference/engine/classes/Terrain>
Licence: first-party documentation (creator-docs is CC BY 4.0); the API ships with the engine.
Maintenance: actively maintained.
**Good:** `WriteVoxels(region, resolution, materials, occupancy)` takes occupancy as well as material,
which is what makes smooth ground from a heightfield rather than steps; `ReadVoxels` gives the digest
(§7.6) a cheap canonical sample; `Clear()` gives `MapGen.clear` its reset.
**Bad:** the page shows `resolution` as `4` throughout but **does not state that 4 is the only
supported value**, and gives **no size cap** for a `WriteVoxels` region. Both are measurement A
(§14.5); the tile size in §13.2 is a conservative guess until then.
**Adopted:** `WriteVoxels` per tile, resolution 4, `Region3` aligned with `ExpandToGrid(4)`.

### 2. Roblox `math.noise` — the noise the heightfield is made of
<https://create.roblox.com/docs/reference/engine/libraries/math>
Licence: first-party (CC BY 4.0 docs); ships with the engine. Maintenance: actively maintained.
**Good:** Perlin noise in the standard library, so the generator needs no dependency at all.
**Bad:** the page gives the signature and nothing else — no output range, no determinism promise across
sessions or engine versions, and **no seed parameter**. That is the single largest unproven assumption
in the whole system.
**Adopted:** `math.noise` with a seed-derived coordinate offset, plus `verify` (§7.6) as the standing
check that it is stable, plus a named fallback to a seeded value-noise function on disk.

### 3. `CollectionService` — how script-free geometry is found by code
<https://create.roblox.com/docs/reference/engine/classes/CollectionService>
Licence: first-party. Maintenance: actively maintained.
**Good:** `AddTag`/`GetTagged`/`GetInstanceAddedSignal` is the standard Roblox answer to "the map
carries no scripts", and `src/server/Match/Markers.luau` already consumes it in production.
**Bad:** the page does **not** say tags are serialised into the place file, and gives no limit on tag
count. The Studio Tag Editor implies persistence; this design does not assert it from implication —
measurement B (§14.5) settles it with a save and a reopen, and names fallback B (markers by folder and
name) if it fails.
**Adopted:** tags as the only marker mechanism, with the vocabulary in `Map.TAGS`.

### 4. Instance streaming — the budget the map is built against
<https://create.roblox.com/docs/workspace/streaming>
Licence: first-party. Maintenance: actively maintained.
**Good:** gives the defaults this design adopts verbatim — `StreamingMinRadius` 64,
`StreamingTargetRadius` 1024, `StreamingIntegrityMode = PauseOutsideLoadedArea`,
`ModelStreamingBehavior = Improved` — with Roblox's own reasoning for each, and per-model
`StreamingMode` (`Persistent`) as the way to keep the markers loaded for everybody.
**Bad:** warns that local-only property changes are lost when an instance streams out and back in,
which is a live trap for anything the client decorates; and mobile clients are reported to run out of
memory as content streams *in*. Turning streaming on changes client behaviour for every existing
system, which is why it is **its own build task with a full harness re-run** (§16, and the Director's
decision C).
**Adopted:** the documented defaults, applied by `MapGen.Settings` as the last step, behind
`Map.STREAMING.enabled`.

### 5. RTerrainGenerator — the closest open-source Roblox terrain generator
<https://github.com/TheArturZh/RTerrainGenerator>
Licence: **MIT** (a closed derivative is permitted). Maintenance: **~45 commits, no visible recent
activity, no archive notice — treat as unmaintained**.
**Good:** it documents exactly the technique adopted here — *exponentially distributed Perlin noise
with domain warping* — and domain warping is what stops noise terrain from looking like noise.
**Bad:** it does **not** use Roblox `Terrain`; it builds its own geometry, with its own world model for
rivers and forests. Vendoring it would mean fighting that model forever.
**Adopted: the technique, not a line of the code** — the domain-warp form in §5.3. Rule 2: this is
borrowing, and where it is borrowed from goes in the header of `Height.luau`.

### 6. Rojo project format, and Roblox place files — why the map is not in git
<https://rojo.space/docs/v7/project-format/> · <https://create.roblox.com/docs/projects/place-files>
Licence: Rojo is MIT, its docs are the project's own; the place-files page is first-party.
Maintenance: both actively maintained; the Rojo CLI is pinned at 7.7.0 in `rokit.toml`.
**Good:** the project-format page states that every `$path` node defaults to
`$ignoreUnknownInstances: false` — *"whether instances that Rojo doesn't know about should be
deleted"*. That single sentence is why §8.4 refuses to cache templates in `ServerStorage` and why the
map lives in `Workspace`. The place-files page gives `File → Save to File` as the only whole-place
rollback (§7.3).
**Bad:** Rojo's page describes what Rojo does, not when — `CLAUDE.md`'s own 2026-09-24 probe found the
deletion happens at the next **Connect**, not during live sync, so a Studio-made instance can look
safe for a whole session and then vanish. And Save to File is a menu click no tool can make, which is
the entire reason §7.3 exists.
**Adopted:** Workspace as the only home for generated content; per-call staging; the two-form backup
rule.

### 7. Roblox pathfinding — the reachability the map must guarantee
<https://create.roblox.com/docs/characters/pathfinding>
Licence: first-party. Maintenance: actively maintained. Already the boar's source of record
(`src/server/Boar/init.luau` header).
**Good:** `PathfindingService:CreatePath(agentParams)` + `ComputeAsync` gives a spec a **machine
verdict on whether the map is playable for the boar**, using the boar's own `Boar.CONFIG.AGENT`
(`AgentRadius = 2`, `AgentHeight = 3`, `AgentCanJump = false`, `AgentCanClimb = false`). That is the
check `reviews/task-33/BRIEF.md` asks for, and it costs nothing to run.
**Bad:** no documented maximum walkable slope for the navmesh could be cited, and there is no slope
field in the agent params. So `CORRIDOR_MAX_SLOPE_DEG` in §13.1 is a **conservative target, not a
derived limit**, and the reachability spec is what actually proves the corridor.
**Adopted:** `CORRIDOR_MAX_SLOPE_DEG = 15`, and §14.1 check 5 as the real gate.

### 8. Mesh specifications — the triangle limit, corrected
<https://create.roblox.com/docs/art/modeling/specifications>
Licence: CC BY 4.0 docs source. Maintenance: active (the docs repo was pushed 2026-09-25).
**Good:** one unambiguous first-party sentence: **_"Individual meshes can not exceed 20,000
triangles."_** Also *"A vertex can not be influenced by more than 4 bones or joints"*.
**Bad:** it is the *only* number on the page — no texture resolution, no stud size, nothing about
pivots or units. It cannot validate any per-prop budget; only measurement D can.
**Adopted:** `MESH_TRI_LIMIT = 20,000`, **first-party**, replacing Task 33's *"≤ 21,000 triangles,
community/vendor"* (§15 C1).

### 9. Texture specifications — what 1024 actually is
<https://create.roblox.com/docs/art/modeling/texture-specifications>
Licence: CC BY 4.0 docs source. Maintenance: active.
**Good:** **_"Roblox supports up to 4096x4096 pixel texture resolutions (4K)."_** and a
recommendation table by object scale: 256² for a 5 × 5-stud object, 512² for 10 × 10, **1024² for
20 × 20** — which is where a tree, a high seat and the boar sit.
**Bad:** *"Roblox supports up to 1024x1024 pixel spaces for texture maps"* appears in the **UV**
section and means UV space, not an upload cap. A careless read turns a recommendation into a limit —
which is exactly what Task 33 and the 2026-09-24 research note did.
**Adopted:** `TEXTURE_MAX_PX = 1024` as **our budget, matching Roblox's recommendation**; the platform
limits are 4096² generally and 8000² for a Decal/Image upload (§15 C2).

### 10. `InsertService` and `AssetService` — the D9 pair
<https://create.roblox.com/docs/reference/engine/classes/InsertService> ·
<https://create.roblox.com/docs/reference/engine/classes/AssetService.md> (the raw source carries the
security metadata the rendered page hides)
Licence: CC BY 4.0 docs source. Maintenance: active.
**Good:** `LoadAsset` *"fetches an asset given its ID and returns a Model containing the asset"*, with
the ownership list spelled out, so **route A is exactly right for everything Karen owns**. The raw
`AssetService` page gives what settles the rest: `AllowInsertFreeAssets` is Access ReadOnly with
**`RobloxScriptSecurity` on read *and* write**.
**Bad:** *"To load assets which do not meet the above criteria, such as free Models published on the
Store, you must use `AssetService:LoadAssetAsync()` and enable `AssetService.AllowInsertFreeAssets`"* —
a wall, not a door, since no script can set that property. Neither page says `LoadAsset` errors rather
than returning `nil` (that is community knowledge, hence the `pcall`), and neither says anything about
Edit mode, which is measurement C.
**Adopted:** §8.3's two routes, and the deletion of Task 33 §8.2's Creator Store plan.

### 11. Creator Store Terms and the Roblox Creator Terms — the licence text, finally read
<https://en.help.roblox.com/hc/en-us/articles/21308223046932-Creator-Store-Terms> (HTML is **HTTP
403** to tools; readable at
`https://en.help.roblox.com/api/v2/help_center/en-us/articles/21308223046932.json`) ·
Roblox User and Creator Terms, article 115004647846, same route
Licence: Roblox's own terms documents. Maintenance: both updated 2026-09-22.
**Good:** **_"By purchasing assets on the Creator Store, User is granted a license to use the asset in
Roblox Studio and in Experiences on the Services consistent with the Roblox User and Creator
Terms."_** Both rules the 2026-09-24 note derived now stand on primary evidence: **never commit a
Creator Store asset**, and **record provenance per row**.
**Bad:** the grant is written for **purchased** assets. A *free* one is licensed only if its creator
agreed to share it — the same flag that decides whether any script can load it (source 10). A public
git repo is not "the Services".
**Adopted:** `ServerStorage.Assets`' licence basis enum as the gate (§8.5), and §8.8's narrowing.

**Also considered and rejected, so they are not re-proposed:** Studio's Terrain Editor Import and
Generate (`docs/research/2026-09-24-map-generator.md` §3 — UI-only, unreachable from code or MCP, and
their state is not a file); heightmap PNGs as the source of truth (unreviewable as a diff, which is
what map option C exists to avoid); a heightmap plugin from the Creator Store (a Karen click per
import, plus a third-party dependency in the critical path); setting `AllowInsertFreeAssets` from code
(impossible, source 10); caching templates in `ServerStorage` (deleted at the next Connect, source 6);
a `--saved` flag or any other unverifiable backup attestation (§7.3).

---

## 13. Numeric targets

**K** = Karen's taste value: a number she changes after walking it, not a measurement.
Derived at **1 stud = 0.28 m** (`docs/research/2026-09-24-map-generator.md` §1).
Karen's taste items keep their defaults until she walks the first slice
(`reviews/task-33/BRIEF.md`).

### 13.1 The world

| Quantity | Value | K? | Basis |
|---|---|---|---|
| Map size | **2048 × 2048 studs** (573 × 573 m), centred on the origin | | research note; ~2× `StreamingTargetRadius`, so streaming is actually exercised |
| Reference ground plane `groundY` | **0** | | matches `Boar.CONFIG.field.groundY`, so fact 4 needs no boar change |
| Relief, whole map | **± 40 studs** (± 11 m) | K | gentle farmland; inside `FALL_LIMIT = 50` |
| Relief inside the corridor (`Map.CORRIDOR_RELIEF`) | **± 16 studs** | K | §6.3 |
| `CORRIDOR_MAX_SLOPE_DEG` | **15°** | | conservative; §12 source 7 — the reachability spec is the real gate |
| Drive corridor | x ∈ **[−340, +340]**, z ∈ **[−800, +800]** | | 680 studs wide (190 m) |
| `Map.FIELD.bounds` | minX −340, maxX +340, minZ −800, maxZ +800 | | must equal `Boar.CONFIG.field.bounds` |
| `Map.FIELD.exitZ` | **−760** | | 60 studs behind the line, so a boar that beats the line disappears behind the shooters rather than in their faces (the shape `src/server/TestArena.luau`'s `LAYOUT.drive` uses at 40 studs in the 400-stud arena) |
| Drive length (start → line) | **1400 studs** (390 m) | K | research note's target, unchanged |
| Shooter line | z = **−700**, along a wood edge; **8 posts**, spacing **80 studs** (22 m), span 560 studs | K | 8 posts serves 16 players. The research note said 60 studs; at 8 posts that is a 420-stud span and reads as a firing range. `Config.LINE.postSpacing` |
| Post part | **12 × 1 × 12 studs**, solid, visible, base at `groundY` | K | §4.3: a character is put down 3.5 studs above its top face |
| Driver start | z = **+700**, part **144 × 1 × 36**, spread over x ± 120 | K | `Body.placementFor` spreads drivers across its X extent |
| Boar spawns | **4**, z = **+600**, x = −240, −80, +80, +240 | K | `docs/design/drive.md` §6.3 releases boars round-robin with jitter |
| Drive line part | **560 × 1 × 1** at z = −700, `LookVector` → **+Z** | | `Markers.read` publishes its `LookVector` as the normal; `SafetyArc` consumes it |
| Tie trees (`DrivenHunt.Tree`) | **12**, within 120 studs of the line | | §4.3 |
| `Map.PAD` | boar spawn radius **14**, post radius **10**, driver start half-extents **(72, 18)**, blend **24**, tolerance **0.75** | | §6.2 |
| Bog | one disc, radius **120**, depth **6**, `Mud`; **no Water material** | K | §1.2 |
| Fields | 300–500 studs a side, a hedge on most boundaries | K | the biggest single lever on "does it read as European farmland" |

### 13.2 Budgets — **corrected against Task 39**

| Quantity | Target | Basis |
|---|---|---|
| Terrain voxel resolution | **4 studs** | the value the `Terrain` docs use throughout; whether any other is accepted is measurement A |
| Vertical terrain band | y ∈ **[−48, +48]**, 24 voxel layers | covers ± 40 relief with margin |
| Tile per `WriteVoxels` call | **128 × 128 studs** = 32 × 32 × 24 = **24,576 voxels** | conservative against the undocumented region cap; 256 tiles for the full map, 16 for the 512 slice |
| Total parts and meshes in the place (`Map.BUDGET.parts`) | **≤ 20,000** | community guidance: <50,000 visible on desktop, ~20,000 on mobile (`docs/research/2026-09-24-map-generator.md` §6). **Community, not first-party** |
| Visible parts at any moment | **≤ 8,000** | leaves headroom for 16 characters, 16 shotguns and 8 boars (`Boar.CONFIG.maxBoars = 8`) |
| Trees (`Map.BUDGET.trees`) | **≤ 3,000**, 1 MeshPart each | split **1,800 spruce / 900 birch / 300 oak**, matching `docs/design/asset-pipeline.md` §12.1's per-key instance ceilings exactly |
| Tree variety | **three keys** (`tree.spruce.a`, `tree.birch.a`, `tree.oak.a`) with per-instance **scale and yaw jitter** | corrected: Task 33 said "2 species × 3 variants", but the manifest has one key per species and *"rows are appended, never edited"* — a new variant is a new key and a new row, i.e. Karen's work, not the generator's |
| Triangles per mesh | **≤ 20,000, and that is the engine's hard limit** — first-party: *"Individual meshes can not exceed 20,000 triangles."* Our budgets sit far inside it: spruce/birch **900**, oak **1,200**, high seat **1,500** | §12 source 8; `docs/design/asset-pipeline.md` §12.1 owns the per-key column. **Replaces Task 33's "≤ 21,000, community/vendor"** |
| Texture per prop | **≤ 1024 × 1024, which is OUR budget**, matching Roblox's recommendation for a 20-stud object; trees and props target **512²**. Platform limits: **4096²** generally, **8000²** for a Decal/Image upload | §12 source 9. **Replaces Task 33's "textures ≤ 1024 × 1024" presented as a limit** |
| Hedgerow segments | ≤ **500** parts (one per ~12 studs, ≤ 6,000 studs of hedge) | inside the part budget with room |
| Client memory | **≤ 1.5 GB** on a mid phone | a target, never measured on this project |
| Join-to-playable | **≤ 15 s** on a mid phone | a target, never measured |

### 13.3 The generator itself

| Quantity | Target | Basis |
|---|---|---|
| Per-step wall clock | **≤ 60 s**, hard timeout `MAPGEN_CALL_TIMEOUT = 180` s | `Studio._rpc` defaults to 120 s (`tools/studio_mcp.py`) |
| Full 2048 build | **≤ 20 min** | edit time; slow is fine, unrepeatable is not |
| 512 × 512 slice (M2.1) | **≤ 3 min** | so the first task iterates |
| Asset inserts per step | **one per key used by that step** (fact 2, §8.4), budget **≤ 6 keys per step**, `PRELOAD_BUDGET_S = 15` per call | `docs/design/asset-pipeline.md` §12.2 owns the loader numbers |
| Determinism | **identical digest** from two builds at the same seed | hard requirement, not a target — `verify` fails otherwise |
| `DIGEST_TERRAIN_SAMPLES` | 4,096 (64 × 64) | enough to catch a shifted heightfield, cheap enough to run every time |
| `BACKUP_MAX_AGE_HOURS` | 6 | §7.3 |

---

## 14. How it is tested

### 14.1 Server spec — `tests/server/map_contract.spec.luau`

Runs in the ordinary harness Play session. It asserts **the world the committed contract names**, so
neither branch is empty and there is no path where it passes by finding nothing.

1. `Map.EXPECTED_WORLD` is `"arena"` or `"map:<id>"`, and **exactly one** of `Workspace.TestArena` /
   `Workspace.DrivenHuntMap` exists — the one it names.
2. Every tag in `Map.TAGS` resolves to exactly `Map.EXPECTED_COUNTS` instances, all inside the named
   world's root. (This is also the check that would catch §10.1's double tag set.)
3. Exactly one `DrivenHunt.DriveLine`; its `CFrame.LookVector:Dot(Vector3.zAxis) > 0.99`, so the normal
   points at the drivers — the meaning `src/server/Weapon/SafetyArc.luau` and
   `src/server/Match/Markers.luau` both depend on.
4. **Pads.** Every `DrivenHunt.BoarSpawn` is inside `Map.FIELD.bounds` and its `Position.Y` is within
   `Map.PAD.tolerance` of `Map.FIELD.groundY`. **4b:** every `ShooterPost`'s bottom face
   (`Position.Y - Size.Y/2`) and all four corners of the `DriverStart` part likewise. §6.4.
5. **Reachability**: for every `BoarSpawn`, and for the `DriverStart`,
   `PathfindingService:CreatePath(Boar.CONFIG.AGENT):ComputeAsync(from, driveLinePoint)` returns
   `Enum.PathStatus.Success` with ≥ 2 waypoints. This uses the boar's **own** agent params, so it
   asserts the map is playable for the actual animal. (`ComputeAsync` yields; TestEZ runs each `it` in
   a coroutine, so this is fine, but it is the slow check here — budget ~5 computations.)
6. No `LuaSourceContainer` anywhere under the named world root. The harness's unmanaged scan covers the
   whole DataModel already; this one **names the cause** when a model brings a script in (§8.7).
7. `Boar.CONFIG.field` deep-equals `Map.FIELD`.
8. *(map branch)* `#root:GetDescendants() <= Map.BUDGET.parts`.
9. `ServerStorage.MapGen` exists and **every descendant is a `ModuleScript`** — nothing in the
   generator can autorun (§1.2).
10. *(map branch)* 64 downward rays on a lattice across the corridor, from `groundY + 200`: each hits
    `Workspace.Terrain`, and every hit Y is inside `± Map.CORRIDOR_RELIEF`.
11. *(map branch)* `markerDigest` recomputed from the live markers equals the committed value — a hand
    edit in Studio fails the harness instead of becoming the map.
12. **`ServerStorage.Assets` does not reference `MapGen`** (a source scan of the manifest's own
    `Source` for the string `MapGen`), so the dependency direction in §2.3 cannot invert silently.
13. *(map branch)* Every key any step declares in `StepSpec.assetKeys` either resolves through
    `Assets.byKey` **with `mayShip == true`**, or is recorded in the run log as a proxy. A baked prop
    with a blocked licence fails here (§8.5).

Plus the pure specs, which need no world at all and run in every branch: `MapGen.Height` (pads, blend,
corridor falloff, determinism for a fixed seed), `MapGen.Layout` (counts, spacing, pads cover every
marker), `MapGen.Scatter` (nothing inside a pad, the corridor, a track or the bog),
`MapGen.Digest` (stable for a fixed input, changes for a moved part).

### 14.2 Client spec — `tests/client/map_client.spec.luau`

No branch: every expectation comes from the contract, so the same assertions hold in both worlds.

1. `Workspace.StreamingEnabled == Map.STREAMING.enabled`, and when enabled, the four radius/mode
   properties match `Map.STREAMING`.
2. The local character is standing on something: a downward ray from the root hits within 12 studs.
   (The previous project shipped "measured correct, looked wrong"; a character in the void measures
   fine.)
3. `Players.LocalPlayer:RequestStreamAroundAsync(driveLinePoint)` returns within 10 s and the
   `DrivenHunt.DriveLine` part is non-nil on the client afterwards — the client can actually see the
   place it is told to shoot toward.

### 14.3 Screenshots (rule 5) — `python tools/mapgen.py shots`

Six named Edit-mode captures with explicit camera and look-at, through `Studio.capture`
(`tools/studio_mcp.py`; Task 7 closed 2026-09-25, and Edit-mode capture is the case it was verified
in). The Builder inspects each and says what it shows:

| Name | Camera → look-at | Answers |
|---|---|---|
| `map-wide` | (0, 900, 1400) → (0, 0, 0) | is there a map at all, and is it farmland-shaped |
| `map-line` | (0, 60, −560) → (0, 0, −760) | the shooter line along the wood edge, 8 posts on flat pads |
| `map-corridor` | (0, 40, 700) → (0, 0, −700) | the drive, from the drivers' eye height |
| `map-hedge` | (−200, 20, 200) → (100, 0, 200) | hedgerows and field edges at eye height |
| `map-stand` | (300, 20, −400) → (300, 0, −600) | a spruce stand: does it read as woods or as poles |
| `map-bog` | (−260, 30, −100) → (−260, 0, −220) | the bog, and whether it is a feature or an annoyance |

**A proxy map is still a rule-5 subject.** Grey boxes on grey terrain is exactly the screen that hid
this project's worst bugs, so §8.6's minimum proxy albedo is what makes these six images readable at
all.

### 14.4 What the harness cannot do here, stated rather than discovered

- **It cannot judge whether the farmland reads as European farmland.** Only Karen can.
- **It cannot run the generator**, by design (fact 1). `tools/mapgen.py` is invoked by hand and its
  `[mapgen] OK:` line is pasted into the review request as evidence, alongside — never instead of —
  the harness line.
- **It cannot save the place**, and neither can `mapgen.py` (§7.4). The Director can post Alt+Shift+S;
  nothing here can verify the result.
- **There is no tool route to `File → Save to File` at all**, which is why §7.3 has two accepted forms
  instead of one.
- **It cannot prove tags survive a save and reopen** inside one run — that needs a reopen
  (measurement B).
- **`test2` is not evidence for this system.** A `[harness2]` line runs none of `test`'s checks 4–6
  (`tools/studio_mcp.py`), and the map changes nothing about two players.
- **No input scenario is added.** The map takes no input; a scenario here would test the harness.

### 14.5 The measurements the first map tasks must make and write down (rule 8)

- **A. `WriteVoxels`**: does it accept a 128 × 128 × 96-stud region? Is `resolution` 4 the only
  accepted value? Record both; correct §13.2's tile row.
- **B. Tags and terrain across a save and a reopen** (§10.3 step 5). If tags do **not** survive:
  fallback B is markers found by **folder and name** under `Workspace.DrivenHuntMap.Markers`, and the
  only module in the repo that changes is `Match.Markers`. Do **not** ship tags and attributes both:
  two representations of one fact is this project's named failure mode.
- **C. Writes through `execute_luau` in Edit mode** — step 0 of M2.1 is a one-liner that creates an
  empty Folder and reads it back. StudioMCP exposes `insert_asset`, `multi_edit` and
  `generate_procedural_model`, so the server is certainly not read-only, but `execute_luau`
  specifically has only ever been used read-only here. If it cannot write, the whole invocation route
  changes and that is an `ESCALATE.md` entry, not a workaround.
- **D. Cost of 50 trees**: parts, triangles and the place's memory before and after, so the 3,000-tree
  budget is checked by multiplication rather than hope. This is also the only check that can validate
  `docs/design/asset-pipeline.md` §12.1's per-key triangle figures (its own §12.1 says so).
- **E. `InsertService:LoadAsset` in Edit mode**, for an id **Karen owns**: does route A work at all
  from `execute_luau`? This is the one that decides whether M2.3 needs route B.
- **M5. Are free Creator Store models flagged *shared by the asset owner*?** — the fact D9 turns on,
  and the only thing that could reopen §8.8. Needs an engine and a real asset id. `insert_asset`'s
  behaviour for a non-owned free model is the second half of the same measurement. **Neither blocks
  anything in M2.1–M2.4**, because proxies do not need ids.

---

## 15. Corrections this design carries into other documents

Named so they are not discovered in review. **A–B are this Architect's own files and are done here;
C–F are the Builder's, in files the Architect never edits.**

- **A. This file replaces `docs/design/map-generator.md` (Task 33) in full.** Its `MapGen.Assets`
  module is deleted (§2.1), its §8.2 Creator Store route is deleted (§8.1), and its broken
  cross-references are gone: Task 33 cited **§7.3** (spawn pads, which did not exist — now §6),
  **§8.4**, **§9.2**, **§11**, **§12.1** and **§13.x** under numbers its own headings did not carry.
  Every reference in this file points at a heading in this file.
- **B. `docs/design/asset-pipeline.md` (Task 40) needs one correction at its next regeneration, from
  this design:** its §6.8 says `MapGen.Props` inserts *"once per run"*. Under fact 2 a run is N MCP
  calls with a fresh module copy each time, so the unit is **once per step, in a staging folder
  destroyed inside the same call** (§8.4). Everything else that design says about the Loader, the
  cache container, proxies and script refusal stands unchanged.
- **C. `docs/research/2026-09-24-map-generator.md` needs four corrections** — the four Task 39 named
  as belonging here (`docs/research/2026-09-26-asset-pipeline.md`, "For the Director"):
  1. **§9's 21,000 triangles.** The limit is **20,000** and it **is first-party**:
     *"Individual meshes can not exceed 20,000 triangles."* Correct the value, the label and the
     numbers table's "community/vendor" basis.
  2. **§9's "no single texture map above 1024 × 1024"** is not a limit. Platform limits are **4096²**
     generally and **8000²** for a Decal/Image upload; 1024 is Roblox's **recommendation** for a
     20-stud object and **our** budget.
  3. **§9's "a changed mesh is a new asset id"** is half wrong. *"Currently, you can only update the
     asset content for .fbx files. The update creates a new version."* — an FBX **Model** updates in
     place as a new version; a **Decal/Image** and a **Mesh** are not updatable at all, so a changed
     texture *is* a new id.
  4. **§8's "I have not read the primary licence text"** can be closed: the Creator Store Terms were
     read on 2026-09-26 via `https://en.help.roblox.com/api/v2/help_center/en-us/articles/<id>.json`
     (the HTML is HTTP 403 to every tool here). Record that route so the next session does not lose
     another page to a 403.
  **One small Builder docs task, not a regeneration.** Worth doing before M2.3 so the tree budgets are
  read off corrected numbers.
- **D. `.gitignore`** gains `/.mapgen/`.
- **E. `GAME_DESIGN.md`** gains §2.1's owner rows when the first map task lands (rule 3: the table
  mirrors the designs), and its arena row is amended when §10's switch flips.
- **F. `TASKS.md` row 16**'s note (*"it lands with the map generator, before any positioned
  geometry"*) is wrong and stays wrong until someone corrects it (§9). The Director already agreed
  (`reviews/task-33/BRIEF.md` decision B).

---

## 16. Build order

### M2.1 — the smallest first task: a 512 × 512 slice

Scope, and nothing else: `src/shared/Map/init.luau` (the contract), `src/serverstorage/MapGen/`
(`init`, `Config`, `Height`, `Layout`, `Scatter`, `Digest`, `Ground`, `Props`, `Markers`),
`tools/mapgen.py`, `tests/server/map_contract.spec.luau` (arena branch — the slice is **not** the world
yet, so `Map.EXPECTED_WORLD` stays `"arena"`), the pure specs, and measurements A, B, C, D.

The slice: a noise heightfield written as voxel terrain in two materials (grass field, dirt track), one
hedgerow line, 50 trees **as proxies** (§8.6), the pads under all 13 markers, and the five tagged
markers. Then `verify` (same seed twice → same digest), six screenshots, save, reopen, `contract`.

**It is buildable today, with no asset ids, no `ServerStorage.Assets` and no decisions from anyone** —
`Props` takes `Assets` as an optional dependency and proxies everything when it is absent, which is
also how its spec runs.

### Then, one task each

| # | Task | Depends on | Notes |
|---|---|---|---|
| M2.2 | The full 2048 heightfield: fields, hedgerow network, tracks, the bog, the corridor band, every pad | M2.1 (measurement A) | still proxies |
| M2.3 | Tree stands: 1,800 spruce / 900 birch / 300 oak from **Karen's own uploaded ids**, through `Assets.Loader` | M2.2; `ServerStorage.Assets` exists (M2.7a/b); **Karen's Meshy-plan answer** (§8.5) | measurements D and E decide whether 3,000 survives and whether route A works in Edit |
| M2.4 | Props and the line's furniture: fences, gates, stones, high seats; the 12 tie trees; the post parts as real geometry | M2.3 | |
| M2.5 | **The switch** (§10): `Map.EXPECTED_WORLD = "map:v1"`, `Boar.CONFIG.field`, `ArenaBoot`'s early return, the map branch of the spec, Karen walks it | M2.4, and Milestone 1 merged | the feel gate |
| M2.6 | Streaming on: `Map.STREAMING.enabled = true`, `MapGen.Settings`, the client spec's radius assertions, **a full harness re-run and a playtest** | M2.5 | its own task, alone — the Director's decision C |
| M2.7 | Archive `TestArena`, `ArenaBoot`, `test_arena.spec` to `backups/` with a note (rule 7) | **Karen has accepted the map** | until then the arena is the rollback |

Task 33's M2.7 ("the Open Cloud upload tool") is **not here**: it is the asset pipeline's own
Milestone 2.7 (`docs/design/asset-pipeline.md` §14), which supersedes it.

---

## 17. Open decisions

**None of these blocks building M2.1.** Each has a working default, in the config or in this document,
changeable by one value.

### Already decided, recorded so they are not reopened

`reviews/task-33/BRIEF.md`, the Director, 2026-09-25: **A** `tools/mapgen.py` is allowed, the tooling
freeze does not apply; **B** `TASKS.md` row 16 stays "before release" and its note is corrected by the
Builder; **C** M2.6 (streaming) is its own task with a full harness run and a playtest; **D** spawn
pads are flattened in terrain and the boar stays untouched. Karen's taste items keep their defaults
until she walks the first slice.

### For Karen (feel, taste and licence — nobody else can answer)

1. **Post spacing: 80 studs, 8 posts, a 560-stud line.** The research note said 60. Walk it and say
   whether it reads as a hunting line or a firing range. `Config.LINE.postSpacing`.
2. **Field size and hedgerow density.** Default: fields of 300–500 studs a side, a hedge on most
   boundaries. The single biggest lever on "does it read as European farmland".
3. **How dark the spruce stands are, and how thick.** Default: 3,000 trees, stands of 40–120 studs
   across. A dark stand hides boar; too dark and shooters see nothing.
4. **The bog: feature or annoyance?** Default: one 120-stud disc of mud, 6 studs deep, off the main
   corridor. `Config.BOG.enabled` turns it off in one word.
5. **The Meshy plan** — and this one has a deadline the others do not. While
   `Assets.BASES["meshy-free-ccby"].mayShip` is `false`, **every free-plan Meshy prop bakes as a grey
   proxy** (§8.5) and M2.3 cannot deliver a wood. The recommendation is
   `docs/design/asset-pipeline.md` §16 Karen 1's: a paid plan for anything that ships. **Not legal
   advice.**
6. **The clicks per rebuild.** With `--backup census` (§7.3) a rebuild of an empty-or-reproducible
   place needs **no human at all** except the save, which the Director can now post. With hand-made
   content in the place it needs `File → Save to File` first, and there is no tool route to it.

### For the Director (scope)

A. **The backup rule is now two-form (§7.3), and the second form is machine-checked rather than
   human-attested.** Recommendation: accept it, and say in the dispatch that `--backup census` is
   allowed for M2.1 and M2.2 (where the place is empty and the map is reproducible), so the first
   slices can iterate headless. The `.rbxl` stays mandatory the moment the census is not clean.

B. **Who presses the save, and with what.** §7.4 names two routes and `mapgen.py` performs neither.
   The key-posting script lives outside the repo and only the `press-F7` sibling is recorded
   (`tools/studio_mcp.py` docstring). Recommendation: the Director owns the Alt+Shift+S route and says
   so in the dispatch, and the Builder's report always ends with the reopen-plus-`contract` proof
   rather than a claim that the place was saved.

C. **Creator Store props are withdrawn until M5** (§8.8), which narrows `ROADMAP.md` speed rule 6
   ("Creator Store assets first"). Recommendation: confirm the narrowing in `ROADMAP.md`, and dispatch
   M5 with M2.4 rather than blocking on it.

D. **M2.3 is gated on Karen's Meshy answer, not on the generator** (§8.5). Recommendation: either get
   the answer before M2.3 is dispatched, or dispatch M2.3 explicitly as "proxies, with the real ids to
   follow", so nobody discovers the grey wood in a screenshot review.
