# Design: asset-pipeline (how a model Karen makes becomes a thing in the game)

System: `asset-pipeline` — the manifest that names every art asset, the tool that uploads one and
records it, and the one loader that turns a manifest key into an Instance the game's existing owners
can clone. `ROADMAP.md` Milestone 2. Task 37.

Architect, 2026-09-25, read-only session: Read, Grep, Glob only. No Studio, **no network**. Evidence
precomputed in `.agent-evidence/` (`INDEX.md`), commit `3f4e2a9b50bbcb6d8a824d70f082980e1e8e1ef5`.
No `docs/design/asset-pipeline.md` existed at this commit (`.agent-evidence/ls-files.txt`).

Inputs, in precedence order: `reviews/task-37/BRIEF.md` (the Director's decisions — it overrides
anything older), `docs/research/2026-09-24-map-generator.md` §§8–12 (the only research this repo has
on assets), `docs/design/map-generator.md` §§2, 8, `CLAUDE.md`, `GAME_DESIGN.md`'s owner table, the
code on this commit (`src/server/Boar/`, `src/server/Weapon/Hardware.luau`,
`src/client/Camera/Viewmodel.luau`, `src/shared/Shotgun/init.luau`, `tools/studio_mcp.py`),
`TASKS.md`, `ROADMAP.md`, `docs/PROJECT_CONTEXT.md`.

**Nothing is built from this until Karen hands over her first models** (brief). This document exists
so that when that happens, it starts from a design.

**Test of this document:** a Builder can build the first task from it without asking anyone a
question. Every owner is named, every interface is written out, every number is here, and every Karen
click is in one place (§8, §16).

**Warning about the sources in §11, read this first.** This session has no network. Every URL in §11
is named from the Architect's own knowledge and **was not fetched**. This repo has been bitten three
times by exactly that: `docs/research/INDEX.md` records that the hit-zones design's `RaycastHitbox`
URL was wrong and that the drive design's "Rodux is archived" was wrong, and `TASKS.md` row 26a
records **a fabricated devforum URL** in a code header that had to be removed from a public repo.
So: rule 1's research note (`docs/research/2026-09-25-asset-pipeline.md`) is **required before any
code**, its job is to fetch every URL in §11 and every claim marked **[UNVERIFIED]** here, and the
corrections go into `reviews/task-<N>/DESIGN_DELTA.md`, not silently into code comments.

---

## 0. Five facts this design is built on, stated first because they decide everything

1. **The previous project died of a hand-written FBX reader and a home-grown upload tool**
   (`docs/PROJECT_CONTEXT.md`, "Invented foundations": *"Cutting a mesh into pieces, a hand-written
   FBX reader, a home-grown viewmodel system. Each produced a run of bugs"*). The brief repeats it.
   **So nothing in this repo ever parses geometry.** No FBX reader, no OBJ reader, no vertex maths.
   The only file this pipeline looks inside is a PNG, and only at the 8-byte IHDR header the PNG spec
   fixes (§7.3) — and even that is bounded: if the signature is not exactly PNG's, the file is
   refused rather than guessed at. Triangle counts are **declared by Karen** (she remeshes to a
   target in Meshy — brief) and enforced by **Roblox's own importer**, which is the only thing in the
   world that actually knows.

2. **The upload needs no Studio at all.** Open Cloud is an HTTPS API with a key in a header (research
   note §9). That is the single most important structural fact here, because it means the upload tool
   is a plain stdlib Python program with no MCP, no Rojo, no Studio mode, no Karen Connect click, and
   it can be tested offline against fixtures. It also means `tools/studio_mcp.py` gains **nothing**:
   its docstring's "Safety" paragraph (*"Its Luau is read-only… There is no command for arbitrary
   Luau or arbitrary MCP tools"*) stays true, and the same prohibition
   `docs/design/map-generator.md` §0 item 1 wrote for the map generator applies word for word here.
   The file that decides whether a PR may be reviewed must not also be the file that holds an API key.

3. **A template cannot be cached on disk or in Studio.** `.rbxm`/`.rbxmx` are banned outright
   (`CLAUDE.md`, "File types in Rojo-owned paths"; CI's "No binary models in synced paths" step
   greps the sourcemap for them). A `.model.json` cannot carry a `Vector3` yet (`TASKS.md` row 16,
   audit-002 #1 — the harness fails such a value as "cannot compare"). And an instance created in
   Studio inside a Rojo-owned container is **deleted at the next Connect** (`CLAUDE.md`, "Rojo
   DELETES Studio-created instances"), which is all of `ServerStorage`. **Therefore every model is
   built by code at run time, from an id.** That is the same answer `docs/design/map-generator.md` §7
   gave, and it is why row 16 is not this system's blocker either (§9).

4. **Two owners already own the Instances this pipeline feeds, and neither may be taken over.**
   `src/server/Boar/Body.luau`'s header: *"the only writer of a boar's Instances… Nothing else in the
   codebase may touch Workspace.Boars"*. `src/server/Weapon/Hardware.luau`'s header: *"the ONLY
   writer of Tool Instances in this system"*. So the asset pipeline **hands out data and templates
   and writes nothing they own**. It has no opinion about where the boar stands or how the gun is
   gripped. Overlapping owners is failure #3 in `docs/PROJECT_CONTEXT.md` and it is the one this
   design spends the most effort avoiding.

5. **A grey box with a texture on it is where this project's worst bugs live.** The list from
   `docs/PROJECT_CONTEXT.md` is *"a knife held backwards for three rounds, purple untextured legs"*,
   and this repo has already produced two of its own: `TASKS.md` row 18 (the boar measured correct
   and read **near-black** from every side but the top) and row 24 (`HANDLE_COLOR` the same way).
   §13 is therefore built so that every claim of the form "it looks right" has both a machine check
   that can fail **and** a named screenshot, and says which half each covers. Three of the traps are
   already visible in the code at this commit and are dealt with in §6.4–§6.6: the grey box would
   poke through the mesh, the hit flash would stop being visible, and the viewmodel would strip the
   texture.

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

1. **Name every art asset once**, by key, with its id, source, licence, provenance and budget, in one
   file, append-only and versioned (§4).
2. **Upload one file to Roblox from the command line**, with the key in an environment variable, and
   record what came back — including the moderation state (§7).
3. **Refuse a file before uploading it** when its name, size, type or declared budget is wrong, and
   say exactly why (§7.3).
4. **Resolve a key to an Instance at run time**, once, in one place, without yielding at the point of
   use (§5).
5. **Let the game look right or stay grey, never break.** A missing, failed, pending or moderated-away
   asset leaves the grey box exactly as it is today and says so loudly in the report (§5.3).
6. **Keep the repo binary-free and licence-clean**: no mesh, no texture, no FBX, no `.rbxm`, no place
   file, ever committed (§1.2, §15).
7. **Keep the key out of the repo, the logs, the reports and the console** (§8.4).
8. **Be provable**: two server specs and one client spec that can fail, plus named screenshots (§13).

### 1.2 Must not

Each row is a named failure from `docs/PROJECT_CONTEXT.md`, the brief, or a boundary an existing
owner drew.

| Prohibition | Why | Whose job instead |
|---|---|---|
| Never parse a mesh file (FBX, OBJ, glTF) | §0 item 1; the brief names the old project's FBX reader and its "run of normals bugs" | Meshy (remesh to target), then Roblox's importer, which rejects an over-limit mesh |
| Never commit a mesh, texture, FBX, `.rbxm`, `.rbxmx`, `.rbxl` or any other binary asset | `CLAUDE.md` bans the model formats; Creator Store's licence is **use-on-Roblox, not redistribution** (research note §8) and the repo is **public** | ids in the manifest; Karen's drop folder outside the repo |
| Never read anything from inside the repository as an upload source | a file that can be uploaded from the tree is a file someone will commit | `ASSET_DROP_DIR`, refused if it resolves inside the repo (§7.2) |
| Never put the API key in a file, a commit, an argv, a log, a run report or a printed line | `CLAUDE.md`, "Public repository: never commit secrets"; the brief | one Windows user environment variable (§8) |
| Never add a subcommand, a write path, an MCP tool or a network call to `tools/studio_mcp.py` | §0 item 2 | `tools/assets.py` |
| Never write a boar Instance, a Tool Instance, anything in `Workspace`, or anything drawn | §0 item 4; `GAME_DESIGN.md` owner rows for `Boar`, `Weapon`, `PlayerScripts.Hud` | `Boar.Body`, `Weapon.Hardware`, `MapGen.Props`, `Hud` — each clones and places for itself |
| Never write `Boar.CONFIG`, `Shotgun.CONFIG`, `Match.CONFIG` or any runtime state | one writer per system | their owners |
| Never be required by a build tool, and never require one | `docs/design/map-generator.md` §1.2: the generator may not be required by any runtime script. The manifest is required by **both**, so it must depend on neither | the manifest is pure data with no service calls (§4) |
| Never yield at the point a model is used | `Body.create` is called inside the boar's spawn path and is followed by `SetNetworkOwner`; a yield there interleaves it. `Hardware.give`'s header records exactly this bug: *"that wait made the grant interleavable… a player ended up with two Tools"* | `Loader.preload` yields, once, from a boot script; `Loader.template` never yields (§5.2) |
| Never place an asset that contains a script | `CLAUDE.md`: nothing script-like is ever created in Studio, and harness check 5 fails the whole run if a `LuaSourceContainer` exists outside the sourcemap | `Loader` **refuses** the template and reports the id and the script's name (§5.4) — the rule `docs/design/map-generator.md` §8.4 already set |
| Never delete Karen's source file, and never move it | rule 7 | the tool only reads; Karen owns her folder |
| Never decide whether a model looks right | only Karen can (rule: a number is not a verification) | Karen, from the screenshots and a playtest |
| Never upload from CI | CI has no key and must never have one; an unattended upload creates assets nobody asked for | Karen's PC, by hand, one command |

**One predicate answers one question.** `Assets.byKey(key)` answers "which row is current for this
key", and nothing else. It does not say whether the asset is loaded, whether it is moderated, whether
the grey box should be hidden, or whether the model is any good. Those are `Loader.stats()`, the row's
own `moderation` field, `Boar.CONFIG.MODEL.hideGreyBox`, and Karen. The previous project's worst bug
was one predicate answering two questions (`docs/PROJECT_CONTEXT.md`: *"One predicate answered two
unrelated questions, so mounting hid both the crosshair and the weapon"*).

---

## 2. Ownership

Rule 3: exactly one writer per system, named here, mirrored into `GAME_DESIGN.md` when the code lands.

### 2.1 The owner table (paste into `GAME_DESIGN.md` with the first asset task)

| System | Owner (the only writer) | Location on disk → Studio |
|---|---|---|
| **The asset manifest**: every key's id, source, creator, licence note, provenance, budgets, dimensions, moderation state. Frozen data, **no runtime writer at all** | `ServerStorage.Assets` — nothing writes it at run time; **the Builder edits the file** and git records it, from what `tools/assets.py` printed | `src/serverstorage/Assets/init.luau` → `ServerStorage.Assets` |
| **Asset templates**: the one place an asset id becomes an Instance, and the only writer of `ServerStorage.AssetCache` (run time) or of the cache container a caller nominates (edit time) | `ServerStorage.Assets.Loader` — **the only caller of `InsertService:LoadAsset` and `AssetService:CreateMeshPartAsync` in the repo** | `src/serverstorage/Assets/Loader.luau` |
| **Upload and validation**: the only holder of an Open Cloud key and the only authenticated caller of `apis.roblox.com` in the repo | `tools/assets.py` | `tools/assets.py` |
| The boar's visible model (a cosmetic MeshPart welded to the trunk, the grey box's visibility, the hit flash) | **unchanged: `ServerScriptService.Boar` → `Boar.Body`.** It clones the Loader's template. Nothing else touches `Workspace.Boars` | `src/server/Boar/Body.luau` |
| The gun's visible model (the Tool's `Handle`) | **unchanged: `ServerScriptService.Weapon` → `Weapon.Hardware`** | `src/server/Weapon/Hardware.luau` |
| The first-person copy of the gun | **unchanged: `PlayerScripts.Camera.Viewmodel`**, which clones the `Handle` and never writes the original | `src/client/Camera/Viewmodel.luau` |
| Map props | **unchanged: `MapGen.Props`** (`docs/design/map-generator.md` §2.1) — but it asks `Assets.Loader` for the template instead of inserting one itself (§15 delta D1) | `src/serverstorage/MapGen/Props.luau` |

### 2.2 The modules inside `ServerStorage.Assets`

A folder with `init.luau` taking its siblings as children — the shape `src/server/Boar/`,
`src/server/Weapon/` and `src/server/Match/` already prove green. **Nothing happens on `require`.**

| Module | Is | Never |
|---|---|---|
| `init.luau` | **pure data and pure lookups**: `VERSION`, `ROWS`, `KEYS`, `byKey`, `describe`, `budget`, `keysFor`. Deep-frozen with `Shotgun.deepFreeze` (`src/shared/Shotgun/init.luau`, `Shotgun.deepFreeze`) — **required, not copied**, because `table.freeze` is shallow and this repo has paid for that once (`TASKS.md` row 23a(b)) | calls a service, creates an Instance, yields, holds state, knows what is loaded |
| `Loader.luau` | **the one id→Instance seam**: `preload` (yields), `template` (never yields), `stats`, `setCacheParent`, `setInsert`. Holds the cache table and refuses a template containing a script | writes anything outside its cache container; writes `Workspace`; decides a size, a pivot or a colour |

`Loader` is exported as `Assets.Loader` (as `src/server/Boar/init.luau` exports `Boar.Brain`) so a
spec can drive it with an injected fake insert function and no network. That is what lets the loader
be tested in the ordinary harness run while no real asset exists.

### 2.3 Why the manifest is **not** inside `MapGen` (a correction to an existing design)

`docs/design/map-generator.md` §2.1 puts the manifest at `src/serverstorage/MapGen/Assets.luau` →
`ServerStorage.MapGen.Assets`. **That cannot stand once game code needs an id.** The same design's
§1.2 forbids the generator being required by any runtime script — *"the runtime must not depend on a
build tool"* — and `Boar.Body` is a runtime script. Leaving it there forces one of: a runtime require
of a build tool, or a second copy of the ids. Two copies of one fact is the shape
`docs/PROJECT_CONTEXT.md` calls *"two correct pieces of code disagreeing"*.

**Decision: the manifest is its own owner, `ServerStorage.Assets`, and `MapGen` requires it.** The
map generator loses `MapGen.Assets` entirely. `src/serverstorage/` is already mapped
(`default.project.json`, `ServerStorage.$path`), so this adds files under an existing mapping: **no
`default.project.json` change, no Rojo restart, no Karen Connect click.** Recorded as delta D1 in
§15 for the next regeneration of `docs/design/map-generator.md`.

Why `ServerStorage` and not `ReplicatedStorage`: no client needs an id. The client sees models because
the server created them and replication carried them; `Viewmodel` clones a `Handle` that is already
in the client's DataModel (`src/client/Camera/Viewmodel.luau`, the local `build`). Server-only keeps
the surface small, and `CLAUDE.md`'s layout row for `src/serverstorage/` is exactly this case:
*"Server-only templates… never replicated to clients"*. **The condition that would move it:** the
first time client-only code must build something from an id (a menu preview, a cosmetics shop). Then
the *manifest* moves to `src/shared/Assets/` and the *Loader* stays server-side.

---

## 3. The whole pipeline in one picture

```
 Karen's PC, outside the repo            tools/assets.py                  Roblox
 ───────────────────────────             ──────────────                   ──────
 C:\Users\karen\Desktop\                       │
   driven-hunt-assets\                         │ 0. refuse: key unset / drop dir inside the repo /
     boar.body_v1.fbx                          │    bad name / >20 MB / PNG >1024 / no sidecar
     boar.body_v1.json      (sidecar) ─────────┤
     boar.body_v1_albedo.png                   │ 1. POST /assets/v1/assets  (x-api-key, multipart)  ──►
                                               │ 2. GET  /assets/v1/operations/{id}  until done     ──►
                                               │ 3. print the manifest row + moderation state
                                               ▼
                                   .assets/<utc>.json  (git-ignored run log, no key, no paths)
                                   "[assets] OK: 2/2 uploaded  boar.body v1 id=<n> state=Reviewing"
                                               │
                                               │  the BUILDER pastes the row (§7.5)
                                               ▼
 git ────► src/serverstorage/Assets/init.luau ──Rojo──► ServerStorage.Assets        (ids, licence, budgets)
           src/serverstorage/Assets/Loader.luau ─Rojo─► ServerStorage.Assets.Loader (the one id→Instance)
                                               │
                        run time, server boot:  │ MatchBoot / WeaponBoot: Loader.preload(keys)  ──► LoadAsset
                                               ▼
                        Boar.Body.create ──► Loader.template("boar.body") ──► :Clone() ──► Workspace.Boars
                        Weapon.Hardware.build ──► Loader.template("shotgun.handle") ──► the Tool's Handle
                        MapGen.Props (edit time) ──► Loader.template("tree.spruce.a") ──► the map run's folder
```

Nothing crosses that diagram sideways. The tool never touches Studio. The manifest never touches an
Instance. The Loader never touches `Workspace`. The consumers never touch an id.

---

## 4. The manifest — `ServerStorage.Assets`

`src/serverstorage/Assets/init.luau`, deep-frozen. Data and pure lookups, no behaviour.

### 4.1 The row

```luau
export type Source = "meshy" | "creator-store" | "roblox" | "own"
export type Kind = "model" | "mesh" | "image"
export type Moderation = "approved" | "reviewing" | "rejected" | "unknown"

export type AssetRow = {
    key: string,              -- "boar.body", "tree.spruce.a"; lower case, dot-separated (§4.3)
    version: number,          -- APPENDED, never edited: a changed mesh is a new id (research note §9)
    id: number,               -- the numeric asset id; 0 is never valid
    kind: Kind,
    displayName: string,      -- what was sent as displayName, so the id is findable on the Hub
    fileName: string,         -- the DROPPED FILE'S NAME ONLY. Never a path: CLAUDE.md's history
                              -- check greps every commit for local paths
    sourceSha256: string,     -- 64 hex of the dropped file's bytes: which file is this id, forever
    source: Source,
    creator: string,          -- the Roblox user or the Creator Store publisher
    licenceNote: string,      -- one line, mandatory, never "" (§4.4)
    added: string,            -- ISO date
    moderation: Moderation,
    trisDeclared: number,     -- what Karen remeshed to in Meshy. DECLARED, not measured (§0 item 1)
    texturePx: number?,       -- the largest map's longest side, read from the PNG IHDR
    sizeStuds: Vector3,       -- the TARGET bounding box in studs; the consumer sets Size to this
    naturalSizeStuds: Vector3?,  -- measured by Loader at first load; nil until measured (§6.2)
    offsetStuds: Vector3,     -- pivot correction, applied by the consumer. Vector3.zero normally
    rotationDeg: Vector3,     -- orientation correction: the backwards-knife fix (§6.3)
    collisionFidelity: "Box" | "Default" | "Hull" | "PreciseConvexDecomposition",
    renderFidelity: "Automatic" | "Precise" | "Performance",
    textureId: number?,       -- the colour map's asset id, when it is a separate upload (§7.6)
    notes: string?,
}
```

### 4.2 The interface

```luau
Assets.VERSION: string
Assets.ROWS: { AssetRow }                     -- append-only, deep-frozen
Assets.KEYS: { [string]: string }             -- the key strings, ONE home: Assets.KEYS.boarBody = "boar.body"
Assets.byKey(key: string): AssetRow?          -- the highest version whose moderation ~= "rejected"
Assets.describe(key: string): AssetRow?       -- alias of byKey, kept because consumers read like this
Assets.budget(key: string): { tris: number, texturePx: number, instances: number }  -- from §12.1
Assets.keysFor(scope: "runtime" | "map"): { string }   -- what a boot script preloads
```

Every one of these is pure: no service, no Instance, no yield, no `os.clock`. That is what lets
`tests/server/assets_manifest.spec.luau` run the whole file with no world (§13.1), the same property
`Boar.Wound`, `Match.Phase` and `Weapon.Pattern` are built on.

`Assets.KEYS` is the one home for the key **strings**, for the reason `docs/design/map-generator.md`
§4.2 made `Map.TAGS` the one home for the tag strings: a typo in a literal produces a silent `nil`
and a grey box that nobody can explain. `Boar.CONFIG.MODEL.key = Assets.KEYS.boarBody` is not
possible (the boar's config must not require the manifest, or a boar spec drags the manifest in), so
instead: **`Boar.CONFIG.MODEL.key` is a string literal and §13.1 asserts it resolves.** One
committed fact, one spec that fails if the two drift.

### 4.3 Key grammar, which is also the file-name grammar

```
key      ::= segment ("." segment)*        segment ::= [a-z][a-z0-9]*
file     ::= key "_v" digits "." ("fbx" | "png")
map file ::= key "_v" digits "_" ("albedo"|"normal"|"roughness"|"metalness") ".png"
sidecar  ::= key "_v" digits ".json"
```

`boar.body_v1.fbx`, `boar.body_v1_albedo.png`, `boar.body_v1.json`, `tree.spruce.a_v2.fbx`. The tool
derives the key and the version from the name and **never guesses**: anything the grammar does not
match is refused with the expected shape printed. Reason: the alternative is Karen typing a key at a
prompt, and a typo there becomes a manifest row and an asset on Roblox that cannot be renamed.

### 4.4 Rows are appended; `licenceNote` is mandatory; nothing is ever deleted

- **Append, never edit** (research note §9: meshes are *"not available for updating"* **[UNVERIFIED]** —
  and it does not matter, because appending is correct either way: the row records what a given id
  *is*, and an id whose content changed under it would be undiagnosable).
- **`licenceNote` is never empty and never inferred.** For Creator Store: *"use on Roblox only, not
  redistributable"* (research note §8, which also records that the Terms page returned **HTTP 403**
  to the researcher, so the primary licence text has never been read by this project). For Meshy:
  **the exact grant depends on Karen's plan and must be quoted from her own account** (§16, Karen 1).
  The tool refuses a sidecar with no licence line. A free model whose uploader did not own the work
  is a live hazard for a public, monetised game, and the manifest is the only place that question
  stays answerable.
- **A rejected or moderated-away id keeps its row** (rule 7), with `moderation = "rejected"`, and
  `byKey` skips it. That is how "the tree disappeared last Tuesday" is diagnosable from the file
  instead of from memory.

---

## 5. The loader — `ServerStorage.Assets.Loader`

### 5.1 Interface

```luau
export type LoadReport = {
    key: string, version: number?, id: number?,
    ok: boolean,
    reason: string?,                 -- "no-row" | "insert-failed" | "contains-script" | "no-meshpart"
                                     -- | "timeout" | "aspect" | "not-preloaded"
    meshParts: number?,
    naturalSizeStuds: Vector3?,      -- the template's bounding box, MEASURED
    pivotOffsetStuds: Vector3?,      -- bounding-box centre minus the template's pivot, MEASURED
    elapsedMs: number,
}

Loader.CONFIG: { LOAD_TIMEOUT_S: number, PRELOAD_BUDGET_S: number, ASPECT_TOLERANCE: number,
                 PIVOT_TOLERANCE_STUDS: number }                      -- frozen; §12.2

Loader.setInsert(fn: ((id: number) -> Instance?)?)        -- nil restores the real InsertService route
Loader.setCacheParent(container: Instance?)               -- nil means ServerStorage.AssetCache
Loader.preload(keys: { string }): { LoadReport }          -- YIELDS. Called by a boot script only.
Loader.template(key: string): (Instance?, LoadReport?)    -- NEVER yields. nil = use the grey box.
Loader.stats(): { requested: number, loaded: number, failed: number, refusedScripts: number,
                  proxies: number, lastReasons: { [string]: string } }
Loader.clear()                                            -- destroys only what it created (rule 7)
```

### 5.2 The yield boundary, which is the whole point of splitting these two functions

`InsertService:LoadAsset` and `AssetService:CreateMeshPartAsync` both yield and both hit the network.
`Body.create` may not yield (§1.2, with `Hardware.give`'s header as the evidence of what a yield in a
grant path costs). So:

- **`preload` yields**, is called exactly twice per server — `MatchBoot` for the runtime keys,
  `WeaponBoot` for the gun — is idempotent, and returns one `LoadReport` per key. Wiring lives in the
  boot scripts because that is this repo's composition-root idiom (`GAME_DESIGN.md`: *"MatchBoot…
  the one composition root of the drive"*; `docs/design/shotgun.md` §6: the wiring lives in the boot
  script *"so neither owner requires the other"*).
- **`template` never yields.** It returns the cached template or `nil`. `nil` is not an error; it is
  "wear the grey box", and `stats().proxies` counts it.
- `preload` is bounded by `PRELOAD_BUDGET_S`. Past it, boot **continues** with whatever loaded and
  warns. A boot that blocks on a moderation queue is a game that will not start.

### 5.3 A failure never breaks the game

Every branch ends in a playable state, and the reason is recorded:

| Situation | What the player sees | What the report says |
|---|---|---|
| no row for the key | today's grey box | `no-row` |
| `LoadAsset` errors (pcall) | today's grey box | `insert-failed` + the error |
| the template has no MeshPart | today's grey box | `no-meshpart` |
| aspect ratio off by > `ASPECT_TOLERANCE` | today's grey box | `aspect` + both sizes |
| pending moderation | whatever Roblox serves (possibly untextured) | the row's `moderation = "reviewing"` |
| the template contains a script | today's grey box | `contains-script` + the script's name (§5.4) |

This is the grey-box proxy rule `docs/design/map-generator.md` §8.3 already set, applied to game
models: *"The whole map is therefore buildable and walkable today, in grey box, and each asset id
later replaces one proxy with no code change."*

### 5.4 A template containing a script is refused, not stripped

After insert and **before** the first clone, `Loader` walks the template for `LuaSourceContainer`
descendants. If it finds one, it destroys the template, returns `nil` with `contains-script`, and
counts it in `stats().refusedScripts`.

Not paranoia: harness check 5 is *"No script (LuaSourceContainer) exists anywhere in the DataModel
outside the sourcemap"* (`tools/studio_mcp.py` docstring), so one surviving `Script` fails **every
harness run from then on**, and `CLAUDE.md` forbids it outright. Refusing rather than stripping is
deliberate — a stripped free model is half-functional in ways nobody looks for, and the right answer
is a different asset. Karen's own Meshy exports cannot contain a script, so in practice this fires
only on Creator Store models, which is exactly where it must.

---

## 6. How a mesh becomes a usable in-game model

### 6.1 The rule that kills the scale bug: the consumer sets `Size`, always

`MeshPart.Size` scales the mesh, so **the exported scale never reaches the game**. Every consumer
writes `part.Size = row.sizeStuds` and the manifest derives `sizeStuds` from real-world metres at
**1 stud = 0.28 m** (research note §1, Roblox's own units page). Meshy's export units are not trusted,
not converted and not inspected.

The check that makes this safe rather than merely convenient: `Loader` measures the template's
**natural** bounding box and compares its aspect ratios with `sizeStuds`. Beyond
`ASPECT_TOLERANCE = 0.05` the load fails as `aspect`, because a non-uniform `Size` write is a
**squashed boar** — and a squashed boar measures perfectly. `naturalSizeStuds` is then pasted into the
row by the Builder so the check is against a committed number from that point on.

The v1 sizes are pinned to numbers that already exist in the code, so the physics cannot move:

| key | `sizeStuds` | comes from | metres |
|---|---|---|---|
| `boar.body` | `Vector3.new(2, 3, 5.5)` | `Boar.CONFIG.BODY_SIZE` (`src/server/Boar/init.luau`) | 0.56 × 0.84 × 1.54 |
| `shotgun.handle` | `Vector3.new(0.4, 0.5, 4.4)` | `Shotgun.CONFIG.HANDLE_SIZE` (`src/shared/Shotgun/init.luau`) | 0.11 × 0.14 × 1.23 |

**The mesh is exactly the grey box's size, so nothing that was tuned to the grey box changes.** The
boar's mass, its `MAX_FORCE`, its three zone offsets (`Boar.CONFIG.ZONES`, each written in trunk-local
coordinates — the head zone sits *1.15 studs proud of the front face*), the gun's `GRIP` and
`MUZZLE_OFFSET`: all still correct, all still covered by the 234 server specs on `main`
(`TASKS.md` row 34). This is the single most valuable property of the design and it is worth
defending: **a model that changes the hitbox invalidates every hit-zone test in the repo.**

### 6.2 Pivot: measured, corrected by data, tolerated only up to a limit

`Loader` reports `pivotOffsetStuds` = bounding-box centre − template pivot. The consumer applies
`row.offsetStuds` when it welds the mesh on. `PIVOT_TOLERANCE_STUDS = 0.25` with `offsetStuds`
applied; past that the spec fails, because a 1-stud offset is a boar whose model walks beside its own
hitbox. This is a **machine** check and it covers translation only.

### 6.3 Orientation: `rotationDeg`, and only a screenshot can check it

There is no machine test for "the nose points forward": a mesh has no notion of forward. What the code
knows is the convention, and it is written down in two places already —
`src/server/Boar/init.luau`, `BODY_SIZE`: *"a Part's LookVector is its -Z"*, and
`src/shared/Shotgun/init.luau`, `GRIP`: *"the Handle's -Z is the muzzle, so the barrel points away"*.
`row.rotationDeg` is the correction the consumer applies, its default is `Vector3.zero`, and **the
only check is the screenshot in §13.3.** The knife held backwards for three rounds
(`docs/PROJECT_CONTEXT.md`) is this exact bug, and pretending a number can catch it is how it survives
three rounds again.

### 6.4 The boar wears the mesh as a **cosmetic** part, and the grey box goes invisible, not away

`Boar.Body` gains one welded child of the trunk, built in `Body.create` beside the existing
`buildZones` call:

```
MeshPart "Model"   Size = row.sizeStuds,  CFrame = trunk.CFrame * CFrame.new(row.offsetStuds)
                                                            * CFrame.Angles(row.rotationDeg…)
                   Massless = true       -- the assembly's mass, centre of mass and inertia are
                                         -- untouched, so MAX_FORCE / MAX_TORQUE / ACCEL stay correct
                                         -- (the reason buildZones already sets it)
                   CanCollide = false    -- the collision body stays the plain box
                   CanQuery = false      -- IT MUST NEVER BE HIT: a ray returns the nearest surface,
                                         -- so a queryable mesh over the zone parts would swallow
                                         -- every head and chest shot and report "body"
                   CanTouch = false, Anchored = false, CastShadow = true
                   CollisionFidelity = Box, RenderFidelity = row.renderFidelity
                   + WeldConstraint to the trunk
```

`CanQuery = false` is the load-bearing line. `src/server/Boar/Body.luau`'s header already explains
the mechanism for the zone parts — *"THE ZONE PARTS PROTRUDE, AND THAT IS THE WHOLE TRICK. A ray
returns the nearest surface"* — and a queryable cosmetic mesh is the same trick run backwards.
`Camera.Viewmodel` sets `CanQuery = false` on its clone for the same reason.

**And the grey box must become invisible.** At this commit `buildZones` writes
`zonePart.Color = if zones.ZONE_TINT then spec.tint else config.BODY_COLOR` — with `ZONE_TINT = false`
the zone parts are still fully **opaque**, and `ZoneHead` sticks 1.15 studs out of the boar's face.
So `Boar.CONFIG.MODEL.hideGreyBox = true` makes `Body.create` set `Transparency = 1` on the trunk and
all three zone parts. They keep `CanQuery = true` and the trunk keeps `CanCollide = true`:
transparency does not affect queries or collisions, which is why hiding is correct and destroying
would be catastrophic. `Boar.CONFIG.ZONES.ZONE_TINT`'s own comment already anticipates this —
*"a grey-box teaching aid, off when the model arrives"*.

### 6.5 The hit flash must be re-owned, or the model silently deletes the player's only hit feedback

`Body.setFlash` / `stepFlash` / `paint` implement the flash by writing `Color` on the trunk and the
three zone parts (`src/server/Boar/Body.luau`). Once those four parts are `Transparency = 1`, **the
flash is invisible.** `Boar.Body`'s own header calls the flash *"the cheapest unambiguous answer to
'did I hit it?' at 100 studs with no sound and no animation"*, and Karen confirmed it reads
(`TASKS.md` row 28: *"the flash plus the bolt read as a hit"*). Losing it to an art change would be a
pure regression that every existing spec still passes, because every existing spec asserts `Color`.

**Decision: when a model is present, the flash is a `Highlight`.** One `Highlight` created once in
`Body.create`, parented to the trunk, `FillColor = config.FLASH_COLOR`, `FillTransparency ≈ 0.5`,
`OutlineTransparency = 1`, `DepthMode = AlwaysOnTop`'s opposite (`Occluded`), and `Enabled` toggled by
the existing `paint` on the existing two-writes-per-hit transition. It stays inside `Boar.Body` — the
flash is a boar cosmetic and the owner does not change — and `boar_body.spec` gains an assertion on
`Enabled` alongside the existing `Color` one, branching on whether a model is present, so neither
branch is empty.

### 6.6 The gun: `Hardware.build` returns a MeshPart Handle, and `Viewmodel` must stop stripping it

`Hardware.build` creates `Instance.new("Part")` named `Handle` with the `Muzzle` Attachment on it.
With a model key it instead clones the template's MeshPart, names it `Handle`, sets `Size`,
`Massless`, `CanCollide = false` and the same `TopSurface`/`BottomSurface`, and parents the same
`Muzzle` Attachment with the same `MUZZLE_OFFSET`. Everything downstream is unchanged:
`Hardware.muzzlePosition` finds `Handle.Muzzle` by name, and `Viewmodel` finds the `Handle` by name.

**But `Viewmodel` would strip the texture.** The local `build` in `src/client/Camera/Viewmodel.luau`
does:

```
for _, child in ipairs(clone:GetChildren()) do
    if not child:IsA("Attachment") then
        child:Destroy()   -- "no scripts, no welds, no sounds: a shape and nothing else"
    end
end
```

A `SurfaceAppearance`, a `Texture` or a `Decal` child is not an `Attachment`, so **the first-person gun
would lose its PBR maps while the third-person gun kept them.** That is "purple untextured legs" with
a case attached: it would appear only in ADS, only for the player holding it, and no spec on `main`
would notice.

Two decisions follow:

1. **v1 uses `MeshPart.TextureID` only, not `SurfaceAppearance`.** A property survives `Clone()`,
   costs no Instance, and cannot be destroyed by a child sweep. Normal, roughness and metalness maps
   wait until a model actually needs them. **[UNVERIFIED]** whether `TextureID` is assignable from a
   script at run time; if it is not, the colour map must come **with** the mesh from the import, which
   is `AssetService:CreateMeshPartAsync`'s job, and that is measurement M3 in §13.5. Either way the
   manifest row is the same and no owner moves.
2. **Whenever `SurfaceAppearance` does arrive, the fix is the camera owner's**, in its own file:
   allow `Attachment`, `SurfaceAppearance` and `Texture` through the sweep and keep destroying the
   rest. Listed as a cross-system change in §10, not done speculatively.

### 6.7 Map props are unchanged in behaviour and change one line in ownership

`MapGen.Props` keeps everything `docs/design/map-generator.md` §8.2 says — insert once per run into
the run's own folder, clone, anchor, destroy the template at the end, never persist a cache in a
Rojo-owned container — but it gets the template from `Loader` with
`Loader.setCacheParent(runFolder)` instead of calling an insert itself. One caller of `LoadAsset` in
the repo, one script-refusal implementation, one cache-shape decision, two cache locations chosen by
the caller. The StudioMCP `insert_asset` fallback that design names still works unchanged: it lands
the template in the same folder, and `Loader.template` finds it there.

---

## 7. The upload tool — `tools/assets.py`

Plain Python 3, **stdlib only** (`urllib.request`, `json`, `hashlib`, `os`, `struct`), matching
`tools/studio_mcp.py`'s dependency profile (its imports are all stdlib). No `requests`, no SDK: a
third-party HTTP library in the one program that holds a secret is a supply-chain surface for no gain.

### 7.1 Commands

```
python tools/assets.py key                          # is the key set? prints "set"/"not set" + a fingerprint
python tools/assets.py init                          # write sidecar stubs for dropped files that lack one
python tools/assets.py validate                      # read-only: every dropped file, pass/refuse, why
python tools/assets.py upload [<key>...] [--dry-run] # validate, upload, poll, print the manifest rows
python tools/assets.py check <id>...                 # re-poll moderation for ids already in the manifest
python tools/assets.py resume <operationPath>        # finish a poll that was interrupted (§7.7)
python tools/assets.py selftest                      # offline: validator + request + response parsing
```

Exit codes, deliberately the harness's shape (`tools/studio_mcp.py`): **0** done · **1** something
failed · **2** REFUSED (key unset, drop dir wrong, validation refused before any request).

`--dry-run` does everything except the two HTTP calls and prints the exact request it *would* send,
with the key replaced by `***`. **The whole tool is therefore reviewable, and `selftest` runs in CI,
with no key and no network.**

### 7.2 Where the files come from

- `ASSET_DROP_DIR`, defaulting to `C:\Users\karen\Desktop\driven-hunt-assets` (brief).
- **Refused if it resolves inside the repository** (`os.path.commonpath` against `REPO`). The repo is
  public and the licence is use-on-Roblox; a source tree that can be uploaded from is a source tree
  someone commits.
- Refused if it does not exist, printed as `<drop dir>` and never as an absolute path: `CLAUDE.md`'s
  history check greps every commit for *"local paths"*, and a review request quotes the tool's stdout.

### 7.3 Validation, before any request

Every refusal names the file, the rule and the fix. In order:

1. **Name** matches §4.3's grammar. Key and version derived, never prompted.
2. **Sidecar present** (`<key>_v<N>.json`) and parses, with `source`, `creator`, `licenceNote`,
   `trisDeclared`, `sizeMetres` (or `sizeStuds`), optional `offsetStuds`, `rotationDeg`, `notes`.
   `licenceNote` non-empty. `init` writes stubs so Karen fills in four fields, not a schema.
3. **Type**: `.fbx` for a model, `.png` for an image. `.jpg`, `.tga`, `.bmp`, `.obj`, `.glb`,
   `.blend` are **refused** — one format per job, so there is no "which of the five paths did this
   take" question later.
4. **Size** ≤ `MAX_FILE_BYTES = 20 MB` (ours, not Roblox's — §12.2).
5. **PNG only**: the 8-byte signature `89 50 4E 47 0D 0A 1A 0A` must match exactly, then width and
   height are the two big-endian uint32s of the `IHDR` chunk at a fixed offset (PNG spec, §11 source
   6). Refused above `TEXTURE_MAX_PX = 1024`. That is the whole of the file parsing in this pipeline,
   it is ~8 lines, the offsets are fixed by an ISO spec, and a non-PNG is refused rather than
   mis-read. §0 item 1 is not violated: no geometry, no compression, no interpretation.
6. **`trisDeclared`** ≤ the key's budget (§12.1) and ≤ `MESHPART_TRI_LIMIT = 21,000`
   (community/vendor figure, research note §9 — **labelled as such wherever it appears**).
   Declared, not measured: Roblox's importer is the enforcer, and it *"fail[s] at import with an
   error"* rather than degrading quietly (research note §9, **[UNVERIFIED]**).
7. **Duplicate check**: the file's SHA-256 already in the manifest under this key ⇒ refuse ("already
   uploaded as id N version M"). This is what stops a second identical asset being created because
   somebody re-ran the command.

### 7.4 The Open Cloud flow

Marked **[UNVERIFIED]** where this session could not read the page. The research note fetches all of
it; the tool's **shape** does not change under any of the answers, which is why none of this blocks
building.

1. `POST https://apis.roblox.com/assets/v1/assets`, header `x-api-key: <key>`,
   `multipart/form-data` with two parts: `request` (JSON) and `fileContent` (the bytes, with
   `Content-Type: model/fbx` or `image/png`). **[UNVERIFIED: part names, the FBX content type.]**
2. The `request` JSON: `assetType` (`"Model"` for FBX, `"Decal"`/`"Image"` for PNG —
   **[UNVERIFIED: which type names v1 accepts, and which one yields an id usable as a colour map]**),
   `displayName`, `description`, and
   `creationContext: { creator: { userId: "<ASSET_CREATOR_USER_ID>" } }`. The user id comes from an
   environment variable too, not a literal: it is not a secret, but it is Karen's account and it does
   not belong in a public file.
3. The reply is a long-running **operation**: `{ path: "operations/<id>", done: false }`. **Write that
   path into the run log before polling** (§7.7).
4. `GET https://apis.roblox.com/assets/v1/operations/<id>` every `POLL_INTERVAL_S = 2` up to
   `POLL_DEADLINE_S = 120`, until `done`, then read the asset id and the moderation state out of the
   response. **[UNVERIFIED: the exact response field names.]**
5. Print the manifest row and the moderation state. Append to `.assets/<utc>.json`.

### 7.5 The tool prints the row; the **Builder** pastes it

`tools/assets.py` never writes a file under `src/`. It prints a StyLua-shaped block (tabs,
`indent_width = 4`, double quotes — `stylua.toml`) ready to paste into
`src/serverstorage/Assets/init.luau`.

Why not write it: `CLAUDE.md` makes the Builder *"the only writer of code in `src/`"*, the manifest is
a linted, formatted `.luau` file, and `docs/design/map-generator.md` §2.1 already said the manifest is
the file *"the Builder edits… Karen supplies the ids"*. A generator that emits Luau is a formatter
bug waiting to fail CI, for the sake of saving one paste per model. The facts come from the tool; the
commit comes from the Builder; the diff is reviewable as a diff.

### 7.6 If Open Cloud cannot take an FBX: the named fallback, same manifest

If `assetType: "Model"` from FBX is not available on this account (§7.4 step 2), the route becomes
**Studio's own 3D Importer** — Karen clicks Add → 3D Importer, picks the file, imports, and publishes
the result — and `tools/assets.py` keeps **every** other job: `validate`, the duplicate check, `check`
for moderation, and printing the row from an id she pastes in (`python tools/assets.py record <key>
<id>`). The manifest, the Loader, the specs, the budgets and all of §6 are unchanged. That is why
this fork is a measurement (M1, §13.5) and not a blocking decision.

Similarly, if a PNG uploaded as a `Decal` yields an id that a colour map will not accept (the classic
Decal-id-versus-Image-id trap), the colour map comes **with** the FBX import instead, `textureId`
stays `nil`, and §13's texture assertion reads the MeshPart's own texture rather than the row's id.
Both branches are asserted by the same spec, which branches on `row.textureId`.

### 7.7 Failure modes, and how each is loud

| Failure | What the tool does |
|---|---|
| `DRIVEN_HUNT_ROBLOX_API_KEY` unset | **exit 2**, names the variable and §8. Never prompts, never reads stdin: a typed key lands in the terminal's scrollback |
| 401 / 403 | prints the status, the endpoint and the body **with every header redacted**; says the three causes in order: key revoked, key expired, **caller IP not in the key's allowlist** |
| 429 | honours `Retry-After`, else backs off 2 / 4 / 8 s; after `RETRIES = 3` it stops the **whole run**, because hammering a rate limit with a key is how a key gets suspended |
| 5xx / connection reset | same backoff, then fail this file and continue with the next |
| operation still `done: false` at 120 s | **not a failure**: prints `pending-operation` and the operation path, and says `python tools/assets.py resume <path>`. The id may already exist; re-uploading would create a duplicate asset that nobody can tell from the first |
| `moderationState = Reviewing` | row printed with `moderation = "reviewing"`. **Loud, because this is the grey-model trap**: a pending texture can render blank or grey, so a model that looks wrong may be waiting for moderation rather than broken. §13.4 says this is not a bug to chase |
| `Rejected` | row printed with `moderation = "rejected"`; `byKey` will skip it; the game keeps the grey box |
| more than `MAX_UPLOADS_PER_RUN = 20` files | refuses the run and asks for explicit keys. A folder-wide accident uploads Karen's whole Desktop |
| any exception after the POST | the run log already holds the operation path (§7.4 step 3), so nothing is orphaned |

---

## 8. The key: Karen's clicks, once

### 8.1 Creating it (exact clicks — **[UNVERIFIED]**: the labels are quoted from the Open Cloud docs as remembered, not as read this session. Karen should report what she actually sees and the Builder corrects the research note)

1. Open <https://create.roblox.com/dashboard/credentials> signed in as **the account that will own
   the assets**.
2. Tab **"API Keys"** (Open Cloud API Keys) → **Create API Key**.
3. **Name:** `driven-hunt-assets`. **Description:** "Driven Hunt asset uploads from Karen's PC".
4. **Access Permissions → Add API System →** choose **"Assets"**.
5. Under it, **Add Experience / choose the creator:** select **her own user account** (not a group).
6. **Operations:** tick **read** and **write**. Nothing else. No `universe-places`, no
   `datastores`, no `messaging`.
7. **Security → IP Allowlist:** her own address as `A.B.C.D/32`. `0.0.0.0/0` means **a leaked key
   works from anywhere in the world**; use it only if her IP moves, and then keep the expiry short.
8. **Expiry:** 30 days. Short expiry is the cheapest rotation policy there is.
9. **Save & Generate Key**, then **copy it — it is shown once.**

### 8.2 Storing it (Windows, GUI path first, and the reason matters)

1. Start → "Edit the system environment variables" → **Environment Variables…** → under **User
   variables** → **New…**
   - Name: `DRIVEN_HUNT_ROBLOX_API_KEY`  Value: the key.
   - Add a second: `ASSET_CREATOR_USER_ID` = her numeric Roblox user id.
2. **OK** three times, then **close and reopen the terminal** (a running shell keeps its old
   environment).

**Do not use `setx`.** It puts the key in a command line, and a command line lands in the shell's
history — PowerShell writes `ConsoleHost_history.txt` to disk by default. The GUI dialog writes no
history. Same reason the tool refuses to take the key as an argument.

### 8.3 Checking it without revealing it

`python tools/assets.py key` prints one of:

```
[assets] DRIVEN_HUNT_ROBLOX_API_KEY: not set   (see docs/design/asset-pipeline.md section 8)
[assets] DRIVEN_HUNT_ROBLOX_API_KEY: set, fingerprint 3f9c2a14, ASSET_CREATOR_USER_ID: set
```

The fingerprint is the first 8 hex of the key's SHA-256: enough to tell "did the variable actually
change" and "is this the same key as yesterday" apart, and not invertible. **It is printed, never
written to a file, never committed, never pasted into a review request.**

### 8.4 The rules that hold everywhere else

- The key is read **once**, into a local, from `os.environ`. It is never logged, never printed, never
  put in an exception message, never written into `.assets/`, and every request's headers are redacted
  before any print. `--dry-run` prints `x-api-key: ***`.
- `.gitignore` gains `/.assets/`.
- **CI never has it** and never will: `.github/workflows/ci.yml` gets `selftest`, which is offline.
- If it leaks: Creator Hub → delete the key → create a new one → tell Karen. `CLAUDE.md` already says
  revoke first, and removing it from history does not un-publish it.

---

## 9. The typed-value question (`TASKS.md` row 16), answered again

**This system does not need the harness to learn typed values, and is deliberately built to keep it
that way.** Row 16's note still says it *"lands with the map generator, before any positioned
geometry"*, and `docs/design/map-generator.md` §7 already showed that assumption was wrong. The asset
pipeline is the second system that would have needed it and does not:

| What you might put on disk | Where it goes instead | Why |
|---|---|---|
| a boar/gun/tree template (`MeshPart` with `Size`, `CFrame`, `MeshId`) | nowhere: built by code from a manifest row at run time (§6) | `.rbxm` is banned; a `.model.json` `Vector3` fails the harness as "cannot compare"; and an instance made in Studio inside `ServerStorage` is deleted at the next Connect |
| ids, licences, budgets, dimensions | `src/serverstorage/Assets/init.luau`, plain Luau | Luau has `Vector3` natively, selene and StyLua lint it, the harness compares the **source byte-for-byte**, and a changed id is one readable line in a PR |
| the mesh and texture files | Karen's drop folder, outside the repo | licence (use-on-Roblox), public repo, binary size |

**Recommendation to the Director, unchanged from the map design: row 16 stays under "before release",
and its "lands with the map generator" note is wrong.** The condition that revives it is still the
first `.model.json` whose value is a `Vector3`, `CFrame`, `Color3`, `UDim2` or `NumberRange`. Nothing
in this design produces one. It remains a real hole in the harness (audit-002 #1); it is not this
system's blocker.

---

## 10. What this system reads from and writes to other systems

| Direction | What | The other side's owner | Evidence |
|---|---|---|---|
| **writes** | `ServerStorage.AssetCache` and everything in it, at run time | `Assets.Loader`; no other writer | this design. Hazard, stated: an instance created there **in Edit mode** is deleted at Karen's next Connect (`CLAUDE.md`), so the cache is run-time only, and at edit time the caller nominates the container |
| **writes** | nothing else in the DataModel, ever | — | §1.2 |
| **is read by** | `Assets.byKey` / `describe` / `budget` / `keysFor` | nobody writes them; `Shotgun.deepFreeze`d | §4.2 |
| **is read by** | `Loader.template`, by `Boar.Body` (`Body.create`) | `ServerScriptService.Boar` clones and places; the pipeline never touches `Workspace.Boars` | `src/server/Boar/Body.luau` header |
| **is read by** | `Loader.template`, by `Weapon.Hardware` (`Hardware.build`) | `ServerScriptService.Weapon` | `src/server/Weapon/Hardware.luau` header |
| **is read by** | `Loader.template`, by `MapGen.Props`, at edit time | `ServerStorage.MapGen` | `docs/design/map-generator.md` §2.1 |
| **is called by** | `Loader.preload(Assets.keysFor("runtime"))` | `ServerScriptService.MatchBoot` — the drive's composition root | `GAME_DESIGN.md`, Match row |
| **is called by** | `Loader.preload({ "shotgun.handle" })` | `ServerScriptService.WeaponBoot` | `GAME_DESIGN.md`, Weapon row |
| **cross-system change** | `Boar.CONFIG` gains `MODEL = { key, enabled, hideGreyBox }`; `Body.create` welds the cosmetic MeshPart, hides the grey box, and flashes with a `Highlight`; `ZONES.ZONE_TINT` → `false` | `ServerScriptService.Boar`, in its own file, by its owner | §6.4–§6.5 |
| **cross-system change** | `Shotgun.CONFIG` gains `MODEL = { key, enabled }`; `Hardware.build` clones a MeshPart Handle, same name, same `Muzzle`, same `Size` | `ServerScriptService.Weapon` | §6.6 |
| **cross-system change, only when `SurfaceAppearance` arrives** | the local `build` in `Viewmodel.luau` must keep `SurfaceAppearance` and `Texture` children, not only `Attachment` | `PlayerScripts.Camera.Viewmodel` | §6.6 |
| **docs change** | `assets/source/README.md` and `assets/ready/README.md` stop inviting binaries and `ASSET_IDS.md`, and point at the manifest | the Builder (they are not Architect files) | §15 delta D3 |

**Nothing else.** No change to `Boar.Brain`, `Boar.Wound`, `Match`, `Hud`, `Camera.Rig`,
`Camera.Mode`, `Weapon.Cast`, `Weapon.Pattern`, `tools/studio_mcp.py`, or `default.project.json` —
`src/serverstorage` is already mapped, so **no Rojo restart and no extra Connect click**.

---

## 11. External sources

Six, plus what the research note already holds. **None was fetched in this session** (no network):
every licence and maintenance line below is the Architect's knowledge, and the research note's first
job is to confirm or correct each one. Read the warning at the top of this document.

### 1. Roblox Open Cloud — Assets API usage guide
<https://create.roblox.com/docs/cloud/open-cloud/usage-assets>
Licence: first-party documentation (creator-docs is CC BY 4.0); the API is Roblox's. Maintenance:
actively maintained. Already the source of record for this repo's upload plan (research note §9).
**Good:** gives the whole flow this design adopts — `POST /assets/v1/assets`, the key in an
**`x-api-key` header**, a key scoped to **assets read + write**, and a long-running **operation** to
poll. It is first-party, so the pipeline needs no third-party uploader and no SDK.
**Bad:** research note §9 records that the page *"says nothing about keeping the key secret"* — all
of §8 is ours. It does not state rate limits in a form this project can plan against, and the exact
asset-type names, part names and response fields are the things this session could not read
(**[UNVERIFIED]**, §7.4).
**Adopted:** the endpoint, the header, multipart upload and operation polling, verbatim; §7.7's
failure handling on top, because the page describes the happy path.

### 2. Roblox Open Cloud — API keys (scopes, IP allowlist, expiry)
<https://create.roblox.com/docs/cloud/auth/api-keys>
Licence: first-party. Maintenance: actively maintained.
**Good:** it is the only authority on what §8.1's clicks are, and it gives the two controls that make
a key on a personal PC acceptable: **per-system scoping** (assets only, read + write only) and an
**IP allowlist**, plus an expiry.
**Bad:** it is a UI walkthrough of a dashboard that gets redesigned, so §8.1's labels will drift —
which is why Karen is asked to report what she sees. It offers no rotation policy, so the 30-day
expiry is ours.
**Adopted:** least privilege (one system, one account, read + write), an IP allowlist of `/32`, a
30-day expiry, and the GUI environment-variable route instead of `setx`.

### 3. `AssetService` — building a MeshPart from an id at run time
<https://create.roblox.com/docs/reference/engine/classes/AssetService>
Licence: first-party. Maintenance: actively maintained; already cited by the research note (§9).
**Good:** `CreateMeshPartAsync(id, options)` is the documented way to get a `MeshPart` from an id in
code, with `CollisionFidelity` chosen at creation — which is exactly what §0 item 3 forces on this
project, since no template may live on disk or in Studio.
**Bad:** it yields and is rate-limited per server, so it cannot be called from a spawn path (§5.2),
and the page does not make the **mesh-id versus model-id** distinction plain enough to plan an upload
around it (**[UNVERIFIED]**, and it is measurement M2).
**Adopted:** as one of the Loader's two routes, chosen by measurement, behind the same
`Loader.template` seam either way.

### 4. `InsertService` — loading a published Model on the server
<https://create.roblox.com/docs/reference/engine/classes/InsertService>
Licence: first-party. Maintenance: actively maintained. Already the map generator's primary route
(`docs/design/map-generator.md` §8.2).
**Good:** `LoadAsset(id)` returns a Model containing whatever was uploaded, server-side, which is the
right route when the upload produced a **Model** asset from an FBX. It is also the route the map
generator already assumes, so one implementation serves both.
**Bad:** it errors rather than returning nil on a moderated, private or missing asset (so every call
is inside a `pcall`), it has no caching of its own (so the cache is ours), and whether it is callable
from `execute_luau` in Edit mode is **still unverified** — the map design's measurement C.
**Adopted:** the primary route, in a `pcall`, once per key, behind `Loader.template`.

### 5. `Highlight` — how a hit still reads on a textured animal
<https://create.roblox.com/docs/reference/engine/classes/Highlight>
Licence: first-party. Maintenance: actively maintained.
**Good:** one instance, `FillColor` + `FillTransparency` + `DepthMode`, toggled by `Enabled`, tints a
whole model regardless of its texture — which is what a `Color` write cannot do once a colour map is
on the mesh (§6.5). It costs one Instance per boar and two property writes per hit, matching
`Body.stepFlash`'s existing "two property writes per part per hit, never one per frame".
**Bad:** the documented number of simultaneously rendered Highlights is small (single digits to low
tens) and exceeding it degrades silently — fine at `Boar.CONFIG.maxBoars = 8`, **not** fine if
highlights are ever used for anything else. Say so in the header and keep it to the boar.
**Adopted:** the flash becomes a `Highlight` when a model is present, and stays a `Color` write when
it is not, so the grey box keeps its tested behaviour.

### 6. PNG specification (ISO/IEC 15948, W3C) — the only file this pipeline reads
<https://www.w3.org/TR/png-3/>
Licence: W3C document licence / ISO standard; the format is patent-free and unencumbered.
Maintenance: actively maintained (third edition, 2023).
**Good:** the signature is 8 fixed bytes and `IHDR` is the first chunk, with width and height as two
big-endian uint32s at a fixed offset. That makes "is this a PNG, and how big is it" a ~8-line read
with no library and no guessing — the smallest possible amount of file parsing that still enforces
the texture budget.
**Bad:** it tells us nothing about the *content* — a 1024×1024 PNG can still be the wrong texture, or
mostly empty, or the normal map filed as albedo. The budget check is real; the "is it right" check is
the screenshot.
**Adopted:** signature + `IHDR` only. Nothing else in any file is ever parsed (§0 item 1).

### 7. Meshy — where Karen's models come from, and the licence that decides whether they can ship
<https://www.meshy.ai/> · terms and licensing pages on that site
Licence: **this is the one I cannot state and must not guess.** The grant for generated assets depends
on the plan, and free-tier output is commonly granted under an attribution licence while paid tiers
grant commercial use. **A public, monetised Roblox game is exactly the case where the difference
matters**, and this project has already been burned by an unread licence page: research note §8
records that the Creator Store Terms returned **HTTP 403** and *"I have not read the primary licence
text"*.
**Good:** Meshy is the only route Karen has to bespoke models, it remeshes to a triangle target
inside the tool (brief), and it exports FBX with textures — which is why the pipeline can be this
thin.
**Bad:** the licence, unread; and generated meshes are commonly non-manifold or oddly pivoted, which
is what §6.2's pivot tolerance and §6.3's `rotationDeg` exist to absorb.
**Adopted:** Meshy as the source, with **`licenceNote` quoted per row from Karen's own account page**
and §16 Karen 1 as a blocking question for *publishing*, not for building.

**Also considered and rejected, so they are not re-proposed:** `pyassimp` / Blender `bpy` to count
triangles before upload (a geometry parser in the one place §0 item 1 forbids one, plus a heavy
dependency in CI, to re-derive a number Karen already set in Meshy and Roblox already enforces);
a `.rbxm` template committed to the repo (banned by `CLAUDE.md`, and CI greps for it); a
`.model.json` template (needs `TASKS.md` row 16, §9); a community uploader library (a third-party
dependency in the one program holding a secret); `tools/studio_mcp.py upload` (§0 item 2).

---

## 12. Numeric targets

**K** = Karen's taste value: a number she changes after looking, not a measurement.
Derived at **1 stud = 0.28 m** (research note §1).

### 12.1 Per-key budgets (v1)

Every triangle figure is a **target to be measured**, and `MESHPART_TRI_LIMIT` is a
**community/vendor** figure, not first-party (research note §9). The instance counts come from
`docs/design/map-generator.md` §12 and `Boar.CONFIG.maxBoars = 8` (`TASKS.md` row 32).

| key | what | `sizeStuds` | metres | tris ≤ | texture ≤ | `renderFidelity` | instances |
|---|---|---|---|---|---|---|---|
| `boar.body` | the boar | 2, 3, 5.5 | 0.56 × 0.84 × 1.54 | 6,000 | 1024² | Automatic | ≤ 8 |
| `shotgun.handle` | break-action shotgun | 0.4, 0.5, 4.4 | 0.11 × 0.14 × 1.23 | 4,000 | 1024² | **Precise** (seen in ADS) | ≤ 16 + 1 viewmodel |
| `prop.highseat` | hunter's high seat | 4.3, 14.3, 4.3 | 1.2 × 4.0 × 1.2 | 1,500 | 512² | Automatic | ≤ 12 |
| `tree.spruce.a` | spruce | 14, 71, 14 | 3.9 × 20 × 3.9 | 900 | 512² | Automatic | ≤ 1,800 |
| `tree.birch.a` | birch | 18, 64, 18 | 5 × 18 × 5 | 900 | 512² | Automatic | ≤ 900 |
| `tree.oak.a` | oak | 32, 64, 32 | 9 × 18 × 9 | 1,200 | 512² | Automatic | ≤ 300 |

At those numbers the woods are ~2.4 M triangles of unique geometry instanced across ≤ 3,000 parts,
inside the map design's `BUDGET.trees = 3000` and `parts = 20000`. **Unmeasured.** The map design's
measurement D (cost of 50 trees) is what corrects this table, and if it must come down, the tree
budget comes down before the boar's — a background conifer at hunting distance wants hundreds of
triangles, not thousands (research note §9).

### 12.2 Pipeline and loader numbers

| Quantity | Value | Basis |
|---|---|---|
| `MESHPART_TRI_LIMIT` | 21,000 | community/vendor, research note §9. Labelled as such wherever printed |
| `TEXTURE_MAX_PX` | 1024 | same |
| `MAX_FILE_BYTES` | 20 MB | **ours**, not Roblox's. A 20 MB FBX is not a v1 prop |
| maps per asset | ≤ 4 (albedo, normal, roughness, metalness); **v1 uses albedo only** | §6.6 decision 1 |
| `UPLOAD_TIMEOUT_S` | 60 per HTTP request | |
| `POLL_INTERVAL_S` / `POLL_DEADLINE_S` | 2 / 120 | past the deadline is `pending-operation`, not a failure (§7.7) |
| `RETRIES` / backoff | 3 / 2, 4, 8 s, `Retry-After` wins | a key that hammers a 429 gets suspended |
| `MIN_REQUEST_GAP_S` | 1.0 | politeness, since no documented rate limit could be cited |
| `MAX_UPLOADS_PER_RUN` | 20 | a folder-wide accident |
| `KEY_EXPIRY_DAYS` | 30 (recommended to Karen) | §8.1 |
| `LOAD_TIMEOUT_S` (per key) | 10 | |
| `PRELOAD_BUDGET_S` (whole boot) | 15, then continue with proxies | a boot must never block on moderation |
| `ASPECT_TOLERANCE` | 0.05 | beyond it, a `Size` write squashes the model (§6.1) |
| `PIVOT_TOLERANCE_STUDS` | 0.25 | beyond it, the model walks beside its hitbox (§6.2) |
| flash `FillTransparency` | 0.5 | K — it must read at 100 studs, which is what the flash is for |
| unique textures in v1 | ≤ 12 | keeps the place's texture memory boring |

### 12.3 Hard requirements, not targets

- **No binary asset file is ever tracked by git.** Checked by §15 delta D4.
- **No raw `rbxassetid` or bare numeric id appears anywhere in `src/` outside the manifest.** Checked
  by §15 delta D4.
- **The visible model's size equals the grey box's size** (§6.1), so no physics, hit-zone or grip
  number changes when art lands.
- **`CanQuery = false` on every cosmetic mesh.** A queryable mesh over the zone parts silently turns
  every head shot into a body shot (§6.4).

---

## 13. How it is tested

### 13.1 Server spec — `tests/server/assets_manifest.spec.luau` (pure, no world, no network)

1. Every row has every mandatory field; `id > 0`; `version >= 1`; `licenceNote ~= ""`;
   `added` parses as a date; `kind` and `source` are in their enums.
2. No two rows share `(key, version)`. `byKey` returns the **highest** version, and **skips**
   `moderation == "rejected"`.
3. `sourceSha256` is 64 hex characters and unique across rows (the duplicate-upload guard, asserted
   from the committed side too).
4. `fileName` contains no `/`, no `\` and no `:` — **the path-leak check** (`CLAUDE.md`'s history grep
   looks for local paths; this makes it a test instead of a habit).
5. Every row's `trisDeclared` ≤ its `budget().tris` ≤ 21,000; `texturePx` ≤ `budget().texturePx`.
6. Every key any code names resolves, **or** its owner says it is disabled: for
   `Boar.CONFIG.MODEL.key` and `Shotgun.CONFIG.MODEL.key`, either `Assets.byKey(key) ~= nil` or
   `MODEL.enabled == false`. **Both branches assert something**, so the spec cannot pass by finding
   nothing — the shape `docs/design/map-generator.md` §12.1 check 1 uses.
7. `sizeStuds` deep-equals `Boar.CONFIG.BODY_SIZE` for `boar.body` and `Shotgun.CONFIG.HANDLE_SIZE`
   for `shotgun.handle` (§6.1's promise, as an assertion).
8. The manifest is deep-frozen: a write to `Assets.ROWS` and to a nested row **raises**
   (`table.freeze` is shallow — `TASKS.md` row 23a(b)).

### 13.2 Server spec — `tests/server/assets_loader.spec.luau` (fake transport, plus one real branch)

With `Loader.setInsert(fake)` and `Loader.setCacheParent(a spec-made folder)`:

1. `preload` returns one report per key, `ok` where the fake returns a template and `ok == false` with
   the right `reason` where it does not.
2. **A template containing a `ModuleScript` is refused**: `template` returns `nil`, `reason ==
   "contains-script"`, `stats().refusedScripts == 1`, and the template is destroyed. (§5.4 — this is
   the one that keeps harness check 5 green forever.)
3. `template` called twice inserts **once** (the fake counts its calls).
4. `template` for an unknown key returns `nil` and does not raise; `stats().proxies` rises.
5. `template` **does not yield**: it is called inside a `coroutine.wrap` and the coroutine is `dead`
   immediately after, not `suspended`. That is the assertion, not a comment, because §1.2's rule is
   the one a future change will break silently.
6. Nothing was parented into `Workspace`: the spec's nominated cache folder holds the template and
   `Workspace` has no child of that name.
7. A template whose bounding box aspect differs from `sizeStuds` by more than `ASPECT_TOLERANCE`
   fails as `aspect`, and one inside it passes with `naturalSizeStuds` and `pivotOffsetStuds`
   reported.
8. **The real branch**, `Loader.setInsert(nil)`: if `Assets.byKey("boar.body")` exists, the real
   template loads inside `LOAD_TIMEOUT_S`, contains ≥ 1 `MeshPart`, its `MeshId ~= ""`, and its
   pivot offset is within `PIVOT_TOLERANCE_STUDS` of the row's `offsetStuds`. If no row exists, it
   asserts the proxy path instead (`stats().proxies > 0` and the boar still spawned). Branching on
   committed data, both branches non-empty.

### 13.3 Client spec — `tests/client/boar_model.spec.luau` (what the player's machine actually has)

The client cannot read `ServerStorage`, so it asserts **structure**, which is enough to catch the
whole "purple untextured legs" class except the colours themselves:

1. For each boar in `Workspace.Boars`: if a child named `Model` exists, it `IsA("MeshPart")`,
   `MeshId ~= ""`, `Transparency < 1`, `CanQuery == false`, `CanCollide == false`, `Massless == true`,
   and `Size` is non-zero on all three axes.
2. **A texture is present**: `TextureID ~= ""` **or** a `SurfaceAppearance` child exists. This is the
   machine half of "not untextured"; it cannot tell a right texture from a wrong one.
3. When `Model` exists, the trunk and all three zone parts have `Transparency == 1` (§6.4: the grey
   box is hidden, not doubled), and the trunk still has `CanCollide == true` and the zone parts still
   `CanQuery == true` — hiding must not disarm the hit zones.
4. When `Model` does **not** exist, the trunk's `Transparency == 0` and the grey box is intact. No
   empty branch.
5. The gun: when the local player holds the Tool, `Handle` is a `MeshPart` with a non-empty `MeshId`
   **or** `Shotgun.CONFIG.MODEL.enabled == false`.
6. **In ADS, the viewmodel keeps its texture**: `Viewmodel.current()`'s `Handle` has the same
   `MeshId` and a non-empty `TextureID`/`SurfaceAppearance` as the source `Handle`. This is the
   assertion that would have caught §6.6's child-sweep bug, and it is the reason it is in this list.

### 13.4 Screenshots (rule 5) — the half no assertion covers

`python tools/studio_mcp.py capture <name> [camera x,y,z] [look-at x,y,z]` (Task 7, closed
2026-09-25; works in Edit and during Play). The boar moves, so the Builder reads its position from the
spec's own `TestKit.note` output (the harness prints notes under `----- server notes -----`) and
computes the four camera positions from it. The Builder inspects each image and **says what it
shows** — not that it was taken.

| Name | Camera → look-at | Answers, and only a human can |
|---|---|---|
| `boar-front` | 14 studs ahead of the boar, y + 4 → the boar | **is the nose at the front** (§6.3, the backwards knife) |
| `boar-side` | 14 studs to the side → the boar | is it a boar-shaped boar, is it the right size against the 400 × 400 plate |
| `boar-rear` / `boar-above` | 14 behind / 12 above | are the sides textured and lit (`TASKS.md` row 18's near-black sides came from exactly these views), is any grey box poking out (§6.4) |
| `boar-flash` | as `boar-side`, during the 0.25 s flash | **does a hit still read** once the animal is textured (§6.5) |
| `gun-third` | over the shoulder, gun in hand | is the gun held the right way round, is the scale sane in the hand |
| `gun-ads` | first person, aiming | **does the viewmodel have its texture** (§6.6), is the muzzle where the muzzle is |
| `prop-edit` | Edit mode, the template in the cache folder | what the import actually produced, before any of our code touched it |

### 13.5 What the harness cannot do here, stated rather than discovered

- **It cannot upload.** No key in the harness, ever (§8.4). The upload's evidence is
  `tools/assets.py`'s own `[assets] OK:` line, pasted into the review request exactly as the
  `[harness]` and `[mapgen]` lines are.
- **It cannot count triangles.** No triangle-count API could be cited from this session, so
  `trisDeclared` is declared and Roblox's importer is the enforcer (§0 item 1). Anybody tempted to
  fix this with a geometry parser should read §0 item 1 again.
- **It cannot tell a pending-moderation asset from a broken one.** A grey or blank model may be
  `Reviewing`. `moderation` in the row and `python tools/assets.py check <id>` answer it; **do not
  spend a round debugging it** — that is how the previous project lost rounds to bugs that did not
  exist (`docs/PROJECT_CONTEXT.md`).
- **It cannot judge whether the boar looks like a boar, or whether the woods look European.** Karen.
- **It cannot check the viewmodel with two players**: `test2`'s replay reaches the shooter's client
  only (`tools/studio_mcp.py` docstring), and `TASKS.md` row 34a item 1 is the open work there.
- **No new input scenario is added.** An asset takes no input; a scenario here would test the
  harness, which rule 6 forbids.
- **`python tools/assets.py selftest`** is the only automated test the Python tool gets; it is offline
  and covers the validator, the request builder and the response parser. The network path is covered
  by `--dry-run` plus the one real upload a human watches.

### 13.6 The four measurements the first task must make and write down (rule 8)

- **M1. Does Open Cloud accept an FBX as a Model from this account?** If not, §7.6's Studio 3D
  Importer route, and `tools/assets.py` becomes validate + record. Write down the request that worked,
  verbatim, with the key redacted.
- **M2. Which id can be used how**: does the uploaded id come back as a Model (→ `InsertService`) or
  as something `AssetService:CreateMeshPartAsync` accepts? Record which of the Loader's two routes is
  the real one, and delete the other or keep it with a reason.
- **M3. Does the colour map survive the import**, or must a PNG be uploaded separately and assigned?
  Is `MeshPart.TextureID` assignable from a script at run time? This decides whether `textureId` in
  the row is used or always `nil`.
- **M4. The cost of one boar mesh**: parts, the place's memory before and after, and the load time of
  one `preload`. So the §12.1 tree budget is checked by multiplication rather than hope (the map
  design's measurement D, with a real number in it).

---

## 14. Build order — and the smallest first task

### The smallest first task, and a recommended split

The brief asks for "one model end to end". That is two things with very different risk: a tool whose
API surface is unverified, and a change to the boar, which 234 server specs and Karen's accepted
playtest depend on. **Recommendation: two tasks, `7a` then `7b`.** The Director may collapse them;
§16 Director A says what that costs.

**M2.7a — the pipeline, no game code.** Deliverable: an id in the manifest and a spec that loads it.
- `docs/research/2026-09-25-asset-pipeline.md` + `INDEX.md` (rule 1) — every URL in §11 fetched, every
  **[UNVERIFIED]** resolved, M1–M3 answered.
- `tools/assets.py` (`key`, `init`, `validate`, `upload`, `check`, `resume`, `record`, `selftest`,
  `--dry-run`).
- `src/serverstorage/Assets/init.luau` + `Loader.luau`.
- `tests/server/assets_manifest.spec.luau`, `tests/server/assets_loader.spec.luau`.
- `.gitignore` `/.assets/`; the two `assets/*/README.md` corrections (§15 D3); the CI additions
  (§15 D4) if the Director allows them.
- **NEEDS KAREN:** create the key (§8.1), store it (§8.2), drop `boar.body_v1.*`.
- Buildable and reviewable **before** Karen's click: `selftest` and `--dry-run` need no key, and the
  Loader's real branch (§13.2 item 8) asserts the proxy path while no row exists.

**M2.7b — the boar wears it.** `Boar.CONFIG.MODEL`, `Body.create`'s cosmetic MeshPart, the hidden
grey box, the `Highlight` flash, `ZONE_TINT = false`, `MatchBoot`'s `preload`,
`tests/client/boar_model.spec.luau`, the five boar screenshots, and **Karen looks at it** (feel gate:
she accepted the grey boar, and only she can accept this one).

### Then, one task each

| # | Task | Depends on | Notes |
|---|---|---|---|
| M2.7c | The shotgun mesh: `Shotgun.CONFIG.MODEL`, `Hardware.build`, `WeaponBoot` preload, `gun-third` + `gun-ads` screenshots | 7b | if a `SurfaceAppearance` is needed, the `Viewmodel` sweep fix (§6.6) lands here, in the camera owner's file |
| M2.7d | Trees and props for the map: spruce, birch, oak, high seat; `MapGen.Props` moves onto `Loader`; the map design's measurement D | 7a, **and the map generator's M2.1** | this is where §12.1's tree budget is measured and corrected |
| M2.7e | Boar animation and sound | 7b | own design; nothing here covers either |

---

## 15. Deltas this design imposes on documents that already exist

Named so they are not discovered in review. D1 and D2 are **Architect-owned** files and need a
regeneration (`docs/design/map-generator.md`); D3–D5 are the Builder's, in the first task.

- **D1. `docs/design/map-generator.md` §2.1 and §8.1–§8.2:** `MapGen.Assets` is **deleted**; the
  manifest is `ServerStorage.Assets` (§2.3). `MapGen.Props` gets its templates from
  `Assets.Loader` with `Loader.setCacheParent(the run folder)` instead of inserting and
  script-checking for itself. Everything that design says about in-run-only caching, proxies and
  refusing scripted assets stays true and now has one implementation.
- **D2. `docs/design/map-generator.md` §14, task M2.7** ("the Open Cloud upload tool") is superseded
  by §14 here.
- **D3. `assets/source/README.md` and `assets/ready/README.md`.** `assets/ready/`'s README currently
  says *"record the asset ID next to the file name, for example in `ASSET_IDS.md`"* — that is a
  **second home for the ids**, which is the exact failure §4.2 exists to prevent, and it invites
  committing `.fbx`, `.png` and `.ogg` into a public repo whose asset licences are use-on-Roblox.
  Both READMEs must say: **no binary art in this repository**, sources live in Karen's drop folder,
  and the one home for ids and licences is `src/serverstorage/Assets/init.luau`. The directories stay
  (rule 7; and the Layout table in `CLAUDE.md` names them) as text-only pointers.
- **D4. `.gitignore` and CI.** `.gitignore` gains `/.assets/` and, as a safety net,
  `*.fbx`, `*.obj`, `*.glb`, `*.gltf`, `*.blend`, `*.psd`, `*.kra`. CI gains two steps in the shape
  of the existing "No binary models in synced paths" step: **(i)** `git ls-files` contains no binary
  art extension; **(ii)** no `rbxassetid` and no bare id outside `src/serverstorage/Assets/`.
  **(iii)** `python tools/assets.py selftest`. This is a tooling change — §16 Director B.
- **D5. `GAME_DESIGN.md`:** the three owner rows from §2.1, plus the boar and weapon rows amended for
  the cosmetic mesh and the MeshPart Handle when 7b and 7c land (rule 3: the table mirrors the
  designs).
- **D6. `CLAUDE.md`** needs one line in "Toolchain: what is pinned and what is not" or a new short
  section: `tools/assets.py` exists, it holds the only credential path in the repo, the variable is
  `DRIVEN_HUNT_ROBLOX_API_KEY`, and it is never in CI. The secrets section already covers the rule;
  this is the pointer.

---

## 16. Open decisions

**None of these blocks building M2.7a.** Each has a working default, in the config or in this
document, changeable by one value.

### For Karen (feel, taste and licence — nobody else can answer)

1. **The Meshy licence on her own plan** (§11 source 7). Quote it into `licenceNote`. This does not
   block *building*; it blocks **publishing** a monetised game with her models in it, and it is the
   one item here with a legal edge, so it should be answered early rather than at release.
2. **The key's clicks** (§8.1–§8.2), including the IP allowlist choice (`/32` or `0.0.0.0/0`) and the
   expiry. `NEEDS KAREN`, and the first task stops at the upload without it.
3. **Which assets are Creator Store and which she makes in Meshy** (brief, and research note §8's
   warning about free models). Default: everything in §12.1 is Meshy; the map's small props are
   Creator Store where they fit.
4. **Does the boar look right** — size, colour, texture, and whether the flash still reads once it is
   textured (§6.5). Default: the model as delivered, `FillTransparency = 0.5`.
5. **`ZONE_TINT` off when the model lands?** The config comment says yes. Default: `false` in 7b,
   which makes the coloured zone boxes invisible under the mesh. She can turn them back on to see
   where the zones are.
6. **The gun's triangle budget**: 4,000 is generous because it is seen in ADS at arm's length. If it
   reads poorly, the number goes up before anything else does.

### For the Director (scope)

A. **One task or two** (§14). **Recommendation: two.** 7a's risk is an unverified API; 7b's risk is a
   regression in the boar. Collapsing them means an Open Cloud surprise blocks a commit that has
   already changed `Boar.Body`, and `MAX_ROUNDS` is 3.

B. **The CI additions and `tools/assets.py` are new tooling**, and `ROADMAP.md` speed rule 1 freezes
   tooling after Task 11. **Recommendation: allow both, and say so in the dispatch**, as was done for
   `tools/mapgen.py` (map design §15 A) and Task 30. The CI steps are six lines in the shape of the
   existing `.rbxm` step, and they enforce a **public-repo licence rule** and the "no raw id in code"
   rule that this design otherwise leaves to habit.

C. **`TASKS.md` row 16 (typed values) is not this system's blocker either** (§9), and its "lands with
   the map generator" note is still wrong. Recommendation: leave it under "before release", correct
   the note once.

D. **The map-generator design needs regenerating** for D1/D2 (§15). Recommendation: do it when M2.7d
   starts, not now — the delta is recorded here and in `reviews/task-37/DESIGN_DELTA.md`, and
   regenerating a 900-line design is a paid session.

E. **The research note is mandatory before code** (rule 1), and its specific job here is unusually
   load-bearing: every URL in §11 is unfetched, and this repo has three recorded cases of a design
   citing a page that said something else or did not exist (`docs/research/INDEX.md`;
   `TASKS.md` row 26a). Recommendation: the note is the first half of M2.7a, and the Reviewer should
   be told to check the citations against the note rather than against this document.
