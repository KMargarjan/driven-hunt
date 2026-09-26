# Design: asset-pipeline (how a model Karen makes becomes a thing in the game)

System: `asset-pipeline` — the manifest that names every art asset, the tool that uploads one and
records it, and the one loader that turns a manifest key into an Instance the game's existing owners
can clone. `ROADMAP.md` Milestone 2.7. **Task 40: a regeneration of the Task 37 design against the
Task 39 research note.**

Architect, 2026-09-26, read-only session: Read, Grep, Glob only. No Studio, no network, no engine.
Evidence precomputed in `.agent-evidence/` (`INDEX.md`), commit
`3d0ec810a62903ed10d40db656a17e0a55afed62`.

Inputs, in precedence order: `reviews/task-40/BRIEF.md` (the Director's, and it overrides anything
older), `docs/research/2026-09-26-asset-pipeline.md` (**the source of truth wherever it conflicts with
the Task 37 design**), `reviews/task-37/BRIEF.md` (the Director's decisions of 2026-09-25 night, kept),
`TASKS.md` rows 16, 18, 24, 26a, 32, 34, 39, 39a, `docs/design/map-generator.md`, `CLAUDE.md`,
`GAME_DESIGN.md`, `ROADMAP.md`, `docs/PROJECT_CONTEXT.md`, and the code at this commit.

**What changed and why this document exists.** The Task 37 design was written with **no network**: its
§11 named fifteen claims from memory. Task 39 fetched every page live on 2026-09-26 and returned
**17 deltas**. Three of them change what gets built (D5, D6, D9) and the rest are values, labels,
URLs and one whole class of licence fact that was previously unreadable. The Task 37 design is
**superseded by this file in full**; it stays in git history (rule 7). Every `[UNVERIFIED]` marker is
gone: each one is now either answered below or listed in §13.6 as a measurement that needs an engine.

**Test of this document:** a Builder can build M2.7a from it without asking anyone a question. Every
owner is named, every interface is written out, every number is here with its basis, and every Karen
click is in one place (§8, §16).

---

## 0. Six facts this design is built on, stated first because they decide everything

1. **Nothing in this repo ever parses geometry.** `docs/PROJECT_CONTEXT.md`, "Invented foundations":
   *"Cutting a mesh into pieces, a hand-written FBX reader, a home-grown viewmodel system. Each
   produced a run of bugs."* The only file this pipeline looks inside is a PNG, and only at the fixed
   24-byte signature-plus-IHDR prefix the standard guarantees (§7.3). Triangle counts are **declared**
   by Karen, who remeshes to a target in Meshy, and enforced by Roblox, which states one limit in one
   sentence: *"Individual meshes can not exceed 20,000 triangles."* (§11 source 4.)

2. **The upload needs no Studio.** Open Cloud is HTTPS with a key in an `x-api-key` header (§11
   source 1). So the upload tool is a stdlib Python program with no MCP, no Rojo, no Studio mode and
   no Karen Connect click, testable offline against fixtures. `tools/studio_mcp.py` gains **nothing**
   and must not be touched: the file that decides whether a PR may be reviewed must not also be the
   file that holds an API key.

3. **A template cannot be cached on disk or in Studio.** `.rbxm`/`.rbxmx` are banned (`CLAUDE.md`,
   "File types in Rojo-owned paths"; the CI step "No binary models in synced paths" greps the
   sourcemap). A `.model.json` cannot carry a `Vector3` yet (`TASKS.md` row 16). And an instance
   created in Studio inside a Rojo-owned container is deleted at the next Connect (`CLAUDE.md`,
   "Rojo DELETES Studio-created instances"), which is all of `ServerStorage`
   (`default.project.json`, `ServerStorage.$path = "src/serverstorage"`). **Therefore every model is
   built by code at run time, from an id.**

4. **Two owners already own the Instances this pipeline feeds, and neither may be taken over.**
   `src/server/Boar/Body.luau`'s header: *"the only writer of a boar's Instances… Nothing else in the
   codebase may touch Workspace.Boars"*. `src/server/Weapon/Hardware.luau`'s header: *"the ONLY writer
   of Tool Instances in this system"*. The asset pipeline hands out data and templates and writes
   nothing they own. Overlapping owners is failure #3 in `docs/PROJECT_CONTEXT.md`.

5. **A grey box with a texture on it is where this project's worst bugs live.** *"a knife held
   backwards for three rounds, purple untextured legs"* (`docs/PROJECT_CONTEXT.md`), plus this repo's
   own two: `TASKS.md` row 18 (the boar measured correct and read near-black from every side but the
   top) and row 24 (`HANDLE_COLOR` the same way). §13 is built so every "it looks right" claim has a
   machine check that can fail **and** a named screenshot, and says which half each covers.

6. **New, and it is the one that reshapes the Loader: an Open Cloud upload can only ever produce a
   *Model* asset.** The Assets API table (§11 source 1) reads `Mesh | Roblox only |
   model/x-file-mesh-data | "Only Asset delivery API content accepted"`, and `Model | .fbx, .gltf,
   .glb, .rbxm, .rbxmx | "Imports as Model container with MeshPart objects"`. `CreateMeshPartAsync`
   wants a **mesh** `Content`. So the Task 37 design's "two routes chosen by measurement M2" was never
   a choice: **one upload route, `InsertService:LoadAsset` on a Model id**, with
   `CreateMeshPartAsync` reachable only as a *derived second step* from a `MeshId` read off the
   imported MeshPart (research note D5). §5 is built on that.

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

1. **Name every art asset once**, by key, with its id, source, provenance, budget and a **licence
   basis that is a recorded enum and not prose** (§4).
2. **Upload one file to Roblox from the command line**, key in an environment variable, and record
   what came back — including the moderation state (§7).
3. **Refuse a file before uploading it** when its name, size, type, declared budget or licence basis
   is wrong, and say exactly why (§7.3).
4. **Resolve a key to an Instance at run time**, once, in one place, without yielding at the point of
   use (§5).
5. **Let the game look right or stay grey, never break.** A missing, failed, pending, moderated-away
   or licence-quarantined asset leaves today's grey box exactly as it is and says so loudly (§5.3).
6. **Keep the repo binary-free and licence-clean**: no mesh, no texture, no FBX, no `.rbxm`, no place
   file, ever committed (§1.2, §15).
7. **Keep the key out of the repo, the logs, the reports and the console** (§8.4).
8. **Refuse to ship an asset whose licence basis is unresolved** — in CI, not in a habit (§4.5,
   §15 D4). The Director's requirement in `reviews/task-40/BRIEF.md`.
9. **Be provable**: two server specs and one client spec that can fail, plus named screenshots (§13).

### 1.2 Must not

Each row is a named failure from `docs/PROJECT_CONTEXT.md`, a brief, a boundary an existing owner
drew, or — the last four — a documented engine fact the research note established.

| Prohibition | Why | Whose job instead |
|---|---|---|
| Never parse a mesh file (FBX, OBJ, glTF) | §0 item 1 | Meshy (remesh to target), then Roblox's importer, which enforces 20,000 triangles |
| Never commit a mesh, texture, FBX, `.rbxm`, `.rbxmx`, `.rbxl` or any other binary asset | `CLAUDE.md` bans the model formats; the Creator Store grant is *"a license to use the asset in Roblox Studio and in Experiences on the Services"* (§11 source 15) and a public git repo is **not** "the Services" | ids in the manifest; Karen's drop folder outside the repo |
| Never read anything from inside the repository as an upload source | a file that can be uploaded from the tree is a file someone will commit | `ASSET_DROP_DIR`, refused if it resolves inside the repo (§7.2) |
| Never put the API key in a file, a commit, an argv, a log, a run report or a printed line | `CLAUDE.md`, "Public repository"; and the api-keys page itself: *"Copy and save the API key string to a secure location, **not a public repository for your code**"* | one Windows user environment variable (§8) |
| Never add a subcommand, a write path, an MCP tool or a network call to `tools/studio_mcp.py` | §0 item 2 | `tools/assets.py` |
| Never write a boar Instance, a Tool Instance, anything in `Workspace`, or anything drawn | §0 item 4; `GAME_DESIGN.md` owner rows | `Boar.Body`, `Weapon.Hardware`, `MapGen.Props`, `Hud` |
| Never write `Boar.CONFIG`, `Shotgun.CONFIG`, `Match.CONFIG` or any runtime state | one writer per system | their owners |
| Never be required by a build tool, and never require one | `docs/design/map-generator.md` §1.2: the generator may not be required by any runtime script, and the manifest is required by both | the manifest is pure data with no service calls (§4) |
| Never yield at the point a model is used | `Body.create` is on the spawn path and is followed by `SetNetworkOwner`; `Hardware.give`'s header records what a yield in a grant path cost: *"that wait made the grant interleavable… a player ended up with two Tools"* | `Loader.preload` yields, once, from a boot script; `Loader.template` never yields (§5.2) |
| Never place an asset that contains a script | `CLAUDE.md`: nothing script-like is created in Studio; harness check 5 ("No script exists outside Rojo-managed paths", `tools/studio_mcp.py`) then fails **every** run | `Loader` **refuses** the template and reports the id and the script's name (§5.4) |
| Never delete Karen's source file, and never move it | rule 7 | the tool only reads |
| Never decide whether a model looks right | a number is not a verification | Karen |
| Never upload from CI | CI has no key and must never have one | Karen's PC, one command |
| **New (D6):** never write `MeshPart.RenderFidelity` or `CollisionFidelity` from a game script | `RenderFidelity` is Access ReadOnly with write security **`PluginSecurity`**; `CollisionFidelity` *"cannot be read or manipulated by scripts during runtime"* (§11 source 7). A line that writes them is dead code that lints green | set at **import** (Karen's 3D Importer click) or by `CreateMeshPartAsync`'s options on the derived route (§5.5); **asserted** by a spec, never applied by the Loader |
| **New (D7):** never assemble or edit a `SurfaceAppearance` at run time | *"In general, you can't modify SurfaceAppearance properties by scripts during a game because the engine requires some pre-processing"* (§11 source 10) | a `SurfaceAppearance` arrives **with the imported asset** or not at all; v1 uses `MeshPart.TextureID` (§6.6) |
| **New (D9):** never try to set `AssetService.AllowInsertFreeAssets` | Access ReadOnly with **`RobloxScriptSecurity` on read *and* write** (§11 source 6). No game script can enable it, ever | a free Creator Store model nobody shared is inserted **in Studio by hand** and exported, which needs `TASKS.md` row 16 (§9) |
| **New:** never put a row whose licence basis is `"unresolved"` into `Assets.ROWS` | the Director's requirement; and the upload itself is Publishing UGC (§4.5) | `Assets.Quarantine`, which the Loader never reads (§4.5) |

**One predicate answers one question.** `Assets.byKey(key)` answers "which row is current for this
key", and nothing else. It does not say whether the asset is loaded, whether it is moderated, whether
the grey box should be hidden, or whether the model is any good. Those are `Loader.stats()`, the row's
own `moderation`, `Boar.CONFIG.MODEL.hideGreyBox`, and Karen. The previous project's worst bug was one
predicate answering two questions (`docs/PROJECT_CONTEXT.md`: *"mounting hid both the crosshair and
the weapon"*).

---

## 2. Ownership

Rule 3: exactly one writer per system, named here, mirrored into `GAME_DESIGN.md` when the code lands.

### 2.1 The owner table (paste into `GAME_DESIGN.md` with the first asset task)

| System | Owner (the only writer) | Location on disk → Studio |
|---|---|---|
| **The asset manifest**: every key's ids, source, creator, licence basis and quote, provenance, budgets, dimensions, moderation state. Frozen data, **no runtime writer at all** | `ServerStorage.Assets` — nothing writes it at run time; **the Builder edits the file** from what `tools/assets.py` printed, and git records it | `src/serverstorage/Assets/init.luau` → `ServerStorage.Assets` |
| **The licence quarantine**: ids recorded for traceability that may not be loaded or shipped | `ServerStorage.Assets.Quarantine` — data only, required by the manifest spec and by nothing else | `src/serverstorage/Assets/Quarantine.luau` |
| **Asset templates**: the one place an asset id becomes an Instance, and the only writer of `ServerStorage.AssetCache` (run time) or of a cache container a caller nominates (edit time) | `ServerStorage.Assets.Loader` — **the only caller of `InsertService:LoadAsset` and of `AssetService:CreateMeshPartAsync` in the repo** | `src/serverstorage/Assets/Loader.luau` |
| **Upload and validation**: the only holder of an Open Cloud key and the only authenticated caller of `apis.roblox.com` in the repo | `tools/assets.py` | `tools/assets.py` |
| The boar's visible model (a cosmetic MeshPart welded to the trunk, the grey box's visibility, the hit flash) | **unchanged: `ServerScriptService.Boar` → `Boar.Body`.** It clones the Loader's template | `src/server/Boar/Body.luau` |
| The gun's visible model (the Tool's `Handle`) | **unchanged: `ServerScriptService.Weapon` → `Weapon.Hardware`** | `src/server/Weapon/Hardware.luau` |
| The first-person copy of the gun | **unchanged: `PlayerScripts.Camera.Viewmodel`**, which clones the `Handle` and never writes the original | `src/client/Camera/Viewmodel.luau` |
| Map props | **unchanged: `MapGen.Props`** (`docs/design/map-generator.md` §2.1) — but it asks `Assets.Loader` for the template instead of inserting one itself (§15 D1) | `src/serverstorage/MapGen/Props.luau` |

### 2.2 The modules inside `ServerStorage.Assets`

A folder with `init.luau` taking its siblings as children — the shape `src/server/Boar/`,
`src/server/Weapon/` and `src/server/Match/` already prove green. **Nothing happens on `require`.**

| Module | Is | Never |
|---|---|---|
| `init.luau` | **pure data and pure lookups**: `VERSION`, `ROWS`, `KEYS`, `BASES`, `byKey`, `describe`, `budget`, `keysFor`. Deep-frozen with `Shotgun.deepFreeze` (`src/shared/Shotgun/init.luau`, `Shotgun.deepFreeze`) — **required, not copied**, because `table.freeze` is shallow and this repo has paid for that once (`TASKS.md` row 23a(b)) | calls a service, creates an Instance, yields, holds state, knows what is loaded |
| `Quarantine.luau` | **pure data**: rows whose licence basis is `"unresolved"`, or whose id was rejected. Recorded so a question stays answerable (rule 7) | be required by `Loader.luau` or by any runtime script |
| `Loader.luau` | **the one id→Instance seam**: `preload` (yields), `template` (never yields), `stats`, `setCacheParent`, `setInsert`, `setCreateMeshPart`, `clear`. Holds the cache table and refuses a template containing a script | writes anything outside its cache container; writes `Workspace`; writes a size, a pivot, a colour or a fidelity |

`Loader` is exported as `Assets.Loader` (as `src/server/Boar/init.luau` exports `Boar.Brain` and
`Boar.Wound`) so a spec can drive it with injected fakes and no network. That is what lets the Loader
be tested in the ordinary harness run while no real asset exists.

### 2.3 Why the manifest is **not** inside `MapGen` (a correction to an existing design)

`docs/design/map-generator.md` §2.1 puts the manifest at `src/serverstorage/MapGen/Assets.luau`.
**That cannot stand once game code needs an id.** The same design's §1.2 forbids the generator being
required by any runtime script, and `Boar.Body` is a runtime script. Leaving it there forces either a
runtime require of a build tool or a second copy of the ids — *"two correct pieces of code
disagreeing"* (`docs/PROJECT_CONTEXT.md`).

**Decision, unchanged from Task 37: the manifest is its own owner, `ServerStorage.Assets`, and
`MapGen` requires it.** `src/serverstorage/` is already mapped, so this adds files under an existing
mapping: **no `default.project.json` change, no Rojo restart, no Karen Connect click.** Recorded as
delta D1 in §15.

Why `ServerStorage` and not `ReplicatedStorage`: no client needs an id. `Viewmodel` clones a `Handle`
already in the client's DataModel (`src/client/Camera/Viewmodel.luau`, the local `build`).
**The condition that would move it:** the first time client-only code must build something from an id
(a menu preview, a cosmetics shop). Then the *manifest* moves to `src/shared/Assets/` and the *Loader*
stays server-side.

---

## 3. The whole pipeline in one picture

```
 Karen's PC, outside the repo            tools/assets.py                  Roblox
 ───────────────────────────             ──────────────                   ──────
 <assets-dir>/                                 │
   boar.body_v1.fbx                            │ 0. refuse: key unset / drop dir unset or inside the
   boar.body_v1.json      (sidecar) ───────────┤    repo / bad name / >20 MB / PNG >1024 / no sidecar
   boar.body_v1_albedo.png                     │    / licence basis missing or unknown
                                               │ 1. POST /assets/v1/assets  (x-api-key, multipart)  ──►
                                               │ 2. GET  /assets/v1/operations/{id}  until done     ──►
                                               │ 3. print the manifest row + MODERATION_STATE_*
                                               ▼
                                   .assets/<utc>.json  (git-ignored run log; no key, no paths)
                                   "[assets] OK: 2/2 uploaded  boar.body v1 id=<n> state=APPROVED"
                                               │
                                               │  the BUILDER pastes the row (§7.5)
                                               ▼
 git ──► src/serverstorage/Assets/init.luau ──Rojo──► ServerStorage.Assets        (ids, licences, budgets)
         src/serverstorage/Assets/Quarantine.luau ──► ServerStorage.Assets.Quarantine  (never loaded)
         src/serverstorage/Assets/Loader.luau ─Rojo─► ServerStorage.Assets.Loader (the one id→Instance)
                                               │
                        run time, server boot:  │ MatchBoot / WeaponBoot: Loader.preload(keys)
                                               │   └─► InsertService:LoadAsset(row.modelId)   [primary]
                                               │   └─► AssetService:CreateMeshPartAsync(
                                               │          Content.fromUri(row.meshUri), opts)  [derived]
                                               ▼
                        Boar.Body.create ──► Loader.template("boar.body") ──► :Clone() ──► Workspace.Boars
                        Weapon.Hardware.build ──► Loader.template("shotgun.handle") ──► the Tool's Handle
                        MapGen.Props (edit time) ──► Loader.template("tree.spruce.a") ──► the run's folder
```

Nothing crosses that diagram sideways. The tool never touches Studio. The manifest never touches an
Instance. The Loader never touches `Workspace`. The consumers never touch an id.

---

## 4. The manifest — `ServerStorage.Assets`

`src/serverstorage/Assets/init.luau`, deep-frozen. Data and pure lookups, no behaviour.

### 4.1 The row

```luau
export type Source = "meshy" | "creator-store" | "roblox" | "own"

-- "meshpart": the template is EXACTLY ONE MeshPart (the import used Merge Meshes). The Loader
--             returns that MeshPart and destroys the Model wrapper. Boar and gun are this.
-- "model":    the template is a tree; the Loader returns the Model. Map props may be this.
-- "image":    a texture upload; there is no template, only an id for TextureID (§6.6).
export type Kind = "meshpart" | "model" | "image"

export type Moderation = "approved" | "reviewing" | "rejected" | "unknown"

export type Licence = {
    basis: LicenceBasis,      -- §4.5; the enum is the gate, the quote is the evidence
    quote: string,            -- the exact sentence that grants it, from the source below
    quotedFrom: string,       -- the URL the quote was read at
    readOn: string,           -- ISO date it was read (a licence page changes: Meshy's moved on
                              -- 2026-09-19, Roblox's on 2026-09-22)
    attribution: string?,     -- the text that must appear where the model does, when the basis
                              -- needs it (CC BY 4.0 s3(a)(1)); nil when it does not
}

export type AssetRow = {
    key: string,              -- "boar.body", "tree.spruce.a"; lower case, dot-separated (§4.3)
    version: number,          -- APPENDED, never edited (§4.4)
    kind: Kind,

    modelId: number,          -- THE id the Open Cloud upload returned. 0 is never valid.
                              -- For kind == "image" this is the Decal/Image id instead (§7.6).
    meshUri: string?,         -- DERIVED, optional, recorded later: MeshPart.MeshId read off the
                              -- imported MeshPart. A URI STRING, not a number -- MeshId is
                              -- documented as "The asset URIs of the mesh" -- so it is handed to
                              -- Content.fromUri unparsed (research note D5, note 39a(d)).
    textureId: number?,       -- the colour map's asset id when it is a separate Image upload (§7.6)

    displayName: string,      -- what was sent as displayName, so the id is findable on the Hub
    fileName: string,         -- THE DROPPED FILE'S NAME ONLY. Never a path: CLAUDE.md's history
                              -- check greps every commit for local paths
    sourceSha256: string,     -- 64 hex of the dropped file's bytes: which file is this id, forever
    source: Source,
    creator: string,          -- the Roblox user, or the Creator Store publisher
    licence: Licence,         -- mandatory, never nil (§4.5)
    added: string,            -- ISO date
    moderation: Moderation,

    trisDeclared: number,     -- what Karen remeshed to in Meshy. DECLARED, not measured (§0 item 1)
    texturePx: number?,       -- the largest map's longest side, read from the PNG IHDR
    sizeStuds: Vector3,       -- the TARGET bounding box in studs; the consumer sets Size to this
    naturalSizeStuds: Vector3?,  -- measured by the Loader at first load; nil until measured (§6.2)
    offsetStuds: Vector3,     -- pivot correction, applied by the consumer. Vector3.zero normally
    rotationDeg: Vector3,     -- orientation correction: the backwards-knife fix (§6.3)

    -- RECORDED PROPERTIES OF THE IMPORT, NOT INSTRUCTIONS. The Loader never writes either
    -- (research note D6; §11 source 7). renderFidelity is asserted by a spec; collisionFidelity
    -- cannot even be READ by a script at run time, so it is documentation plus §6.4's CanCollide.
    renderFidelity: "Automatic" | "Precise" | "Performance",
    collisionFidelity: "Box" | "Default" | "Hull" | "PreciseConvexDecomposition",

    notes: string?,
}
```

**Why `modelId` and not `id`.** D5: the Open Cloud upload of an FBX yields a **Model**. The name says
which kind of id it is, so nobody hands it to `Content.fromAssetId` and spends a round on
`CreateMeshPartAsync` refusing it. `meshUri` is the only mesh reference this pipeline can ever hold,
and it is derived, not uploaded.

### 4.2 The interface

```luau
Assets.VERSION: string
Assets.ROWS: { AssetRow }                     -- append-only, deep-frozen, every licence resolved
Assets.KEYS: { [string]: string }             -- the key strings, ONE home: Assets.KEYS.boarBody = "boar.body"
Assets.BASES: { [LicenceBasis]: BasisPolicy } -- §4.5, the whole licence policy in one table
Assets.byKey(key: string): AssetRow?          -- the highest version whose moderation ~= "rejected"
Assets.describe(key: string): AssetRow?       -- alias of byKey, kept because consumers read like this
Assets.budget(key: string): { tris: number, texturePx: number, instances: number }  -- from §12.1
Assets.keysFor(scope: "runtime" | "map"): { string }   -- what a boot script preloads
```

Every one is pure: no service, no Instance, no yield, no `os.clock`. That is what lets
`tests/server/assets_manifest.spec.luau` run the whole file with no world (§13.1) — the same property
`Boar.Wound`, `Match.Phase` and `Weapon.Pattern` are built on.

`Assets.KEYS` is the one home for the key **strings**, for the reason `docs/design/map-generator.md`
§4.2 made `Map.TAGS` the one home for the tag strings: a typo in a literal produces a silent `nil` and
a grey box nobody can explain. `Boar.CONFIG.MODEL.key = Assets.KEYS.boarBody` is not possible (the
boar's config must not require the manifest, or a boar spec drags the manifest in), so instead:
**`Boar.CONFIG.MODEL.key` is a string literal and §13.1 item 6 asserts it resolves.**

### 4.3 Key grammar, which is also the file-name grammar

```
key      ::= segment ("." segment)*        segment ::= [a-z][a-z0-9]*
file     ::= key "_v" digits "." ("fbx" | "png")
map file ::= key "_v" digits "_" ("albedo"|"normal"|"roughness"|"metalness") ".png"
sidecar  ::= key "_v" digits ".json"
```

`boar.body_v1.fbx`, `boar.body_v1_albedo.png`, `boar.body_v1.json`, `tree.spruce.a_v2.fbx`. The tool
derives the key and the version from the name and **never guesses**: anything the grammar does not
match is refused with the expected shape printed. The alternative is Karen typing a key at a prompt,
and a typo there becomes a manifest row *and* an asset on Roblox that cannot be renamed.

### 4.4 Rows are appended, never edited

- **Append.** The row records what a given id *is*. D12 sharpens the reason: *"Currently, you can only
  update the asset content for .fbx files. The update creates a new version."* — so a Decal/Image or
  Mesh asset is **not updatable at all**, a changed texture is a **new id**, and even an updatable FBX
  Model gets a new version rather than a silent content swap. (This also corrects
  `docs/research/2026-09-24-map-generator.md` §9's blanket *"a changed mesh is a new asset id"*, which
  is half wrong for FBX Models — §15 D7.)
- **A rejected or moderated-away id keeps its row** (rule 7), with `moderation = "rejected"`, and
  `byKey` skips it. That is how "the tree disappeared last Tuesday" is diagnosable from the file
  rather than from memory.

### 4.5 Licence basis: an enum, a quote, a policy table, and a CI gate

This section is the Director's requirement in `reviews/task-40/BRIEF.md`:
*"design the manifest so every asset records its licence basis and the CI refuses a shipping asset
whose basis is unresolved."*

```luau
export type LicenceBasis =
      "own-work"                  -- Karen modelled it herself, no generator involved
    | "meshy-paid-owned"          -- "customers on a paid Meshy plan own their Customer Output"
    | "meshy-free-ccby"           -- free plan: MESHY owns the output and grants CC BY 4.0
    | "creator-store-purchased"   -- "By purchasing assets on the Creator Store, User is granted a
                                  --  license to use the asset in Roblox Studio and in Experiences"
    | "creator-store-shared-free" -- free, AND its creator ticked share (Creator Terms; D9/D16)
    | "roblox-owned"              -- owned by Roblox
    | "unresolved"                -- not established. May not be in ROWS at all (below)

export type BasisPolicy = {
    mayUpload: boolean,       -- may this basis be uploaded to Roblox at all
    mayShip: boolean,         -- may it be in a place published to players
    needsAttribution: boolean,
    why: string,              -- one line, quoting the clause
}
```

`Assets.BASES` is the whole policy, in one table, with one line of evidence each. The default values:

| basis | mayUpload | mayShip | attribution | why |
|---|---|---|---|---|
| `own-work` | yes | yes | no | Karen owns it |
| `meshy-paid-owned` | yes | yes | no | *"customers on a paid Meshy plan own their Customer Output."* Terms of Use §3.2 |
| `meshy-free-ccby` | yes | **no, pending Karen** | **yes** | Meshy owns the output and grants **CC BY 4.0**, which is *"non-sublicensable"* (§2(a)(1)); Roblox's Creator Terms require a licence *"with the right to sublicense to any person or entity"* and that the Creator be *"the owner of or … fully authorized to grant rights in all parts"*. §16 Karen 1 |
| `creator-store-purchased` | n/a (never uploaded by us) | yes | no | Creator Store Terms §License |
| `creator-store-shared-free` | n/a | yes | no | Creator Terms: *"other Users may use Creator's UGC to create their own Experiences"* |
| `roblox-owned` | n/a | yes | no | owned by Roblox |
| `unresolved` | **no** | **no** | — | nothing is known |

**Blunt, and it is the reason `mayShip` for `meshy-free-ccby` defaults to `false`:** uploading through
Open Cloud **is** Publishing UGC. The sublicensing collision therefore bites at the moment of upload,
not at release. The research note is explicit that it *"is not legal advice"* and neither is this
paragraph. The design's job is to make the state machine-readable and the default safe; the decision
is Karen's (§16 Karen 1), and it is **one boolean** in `Assets.BASES`.

**Where an unresolved row lives.** Not in `ROWS`. `src/serverstorage/Assets/Quarantine.luau` holds it:
same `AssetRow` shape, `licence.basis == "unresolved"` (or a rejected id), required by the manifest
spec and by nothing else. The key is in exactly one of the two files and §13.1 asserts they are
disjoint, so this is a quarantine, not a second home for an id.

**The three gates, each where it can actually run:**

1. **CI, text only, no Luau parser** (§15 D4 step (iv)): if
   `src/serverstorage/Assets/init.luau` exists and contains the token `unresolved`, the build fails
   with *"an asset whose licence basis is unresolved may not be in Assets.ROWS; record it in
   Quarantine.luau"*. That is a `grep`, it needs no engine, and it cannot be fooled in the direction
   that matters: an unresolved row cannot be committed into `ROWS` with CI green. Stated limit: it is a
   token check, not a parse; the authoritative check is (2).
2. **The manifest spec** (§13.1 items 9–11), in real Luau with the real table: every `ROWS` row's
   basis exists in `Assets.BASES` and has `mayUpload == true`; every basis needing attribution has a
   non-empty `licence.attribution`; `ROWS` and `Quarantine` share no key.
3. **The publish step** (`TASKS.md` row 2, before first public release): every `ROWS` row's basis has
   `mayShip == true`, or the release stops. This is the gate the BRIEF's word "shipping" names, and it
   is the one that `meshy-free-ccby` trips today.

The tool refuses to print a `ROWS` row at all when the sidecar's basis is missing or unknown; it
prints a `Quarantine` row instead (§7.3 item 8, §7.5).

---

## 5. The loader — `ServerStorage.Assets.Loader`

### 5.1 Interface

```luau
export type LoadReport = {
    key: string, version: number?, modelId: number?,
    ok: boolean,
    reason: string?,     -- "no-row" | "quarantined" | "insert-failed" | "contains-script"
                         -- | "no-meshpart" | "multi-meshpart" | "timeout" | "aspect"
                         -- | "not-preloaded"
    route: ("insert" | "createmeshpart")?,   -- which of §5.5's two it actually used
    meshParts: number?,
    naturalSizeStuds: Vector3?,      -- the template's bounding box, MEASURED
    pivotOffsetStuds: Vector3?,      -- bounding-box centre minus the template's pivot, MEASURED
    renderFidelity: string?,         -- READ off the template, never written (D6)
    elapsedMs: number,
}

Loader.CONFIG: { LOAD_TIMEOUT_S: number, PRELOAD_BUDGET_S: number, ASPECT_TOLERANCE: number,
                 PIVOT_TOLERANCE_STUDS: number }                      -- frozen; §12.2

Loader.setInsert(fn: ((modelId: number) -> Instance?)?)        -- nil restores InsertService
Loader.setCreateMeshPart(fn: ((uri: string, options: { [string]: any }) -> Instance?)?)  -- nil
                                                               -- restores AssetService
Loader.setCacheParent(container: Instance?)                    -- nil means ServerStorage.AssetCache
Loader.preload(keys: { string }): { LoadReport }               -- YIELDS. A boot script only.
Loader.template(key: string): (Instance?, LoadReport?)         -- NEVER yields. nil = use the grey box.
Loader.stats(): { requested: number, loaded: number, failed: number, refusedScripts: number,
                  quarantined: number, proxies: number, lastReasons: { [string]: string } }
Loader.clear()                                                 -- destroys only what it created (rule 7)
```

### 5.2 The yield boundary, which is the whole point of splitting these two functions

`InsertService:LoadAsset` and `AssetService:CreateMeshPartAsync` both yield (`CreateMeshPartAsync`:
*"Yields: Yes"*) and both hit the network. `Body.create` may not yield (§1.2, with `Hardware.give`'s
header as the evidence of what a yield in a grant path costs). So:

- **`preload` yields**, is called exactly twice per server — `MatchBoot` for the runtime keys,
  `WeaponBoot` for the gun — is idempotent, and returns one `LoadReport` per key. Wiring lives in the
  boot scripts because that is this repo's composition-root idiom (`GAME_DESIGN.md`: MatchBoot is the
  one composition root of the drive; `docs/design/shotgun.md` §6 puts the wiring in the boot script
  *"so neither owner requires the other"*).
- **`template` never yields.** It returns the cached template or `nil`. `nil` is not an error; it is
  "wear the grey box", and `stats().proxies` counts it.
- `preload` is bounded by `PRELOAD_BUDGET_S`. Past it, boot **continues** with whatever loaded and
  warns. A boot that blocks on a moderation queue is a game that will not start.
- Cost evidence for "never on the spawn path": the only published figure for `CreateMeshPartAsync` is
  a devforum measurement of **~22 ms fixed + ~0.27 ms per 1k triangles** per call (§11 source 6, and
  it is community evidence, not first-party). `InsertService:LoadAsset` has no published figure at
  all, which is a reason to be more careful, not less.

### 5.3 A failure never breaks the game

Every branch ends in a playable state, and the reason is recorded:

| Situation | What the player sees | What the report says |
|---|---|---|
| no row for the key | today's grey box | `no-row` |
| the key is in `Quarantine` | today's grey box | `quarantined` (and `stats().quarantined` rises) |
| `LoadAsset` errors (pcall) | today's grey box | `insert-failed` + the error |
| the template has no MeshPart | today's grey box | `no-meshpart` |
| `kind == "meshpart"` but the template has more than one | today's grey box | `multi-meshpart` + the count (the import needed **Merge Meshes**; §6.7) |
| aspect ratio off by > `ASPECT_TOLERANCE` | today's grey box | `aspect` + both sizes |
| pending moderation | whatever Roblox serves (possibly untextured) | the row's `moderation = "reviewing"` |
| the template contains a script | today's grey box | `contains-script` + the script's name (§5.4) |

This is the grey-box proxy rule `docs/design/map-generator.md` §8.3 already set, applied to game
models: *"each asset id later replaces one proxy with no code change."*

### 5.4 A template containing a script is refused, not stripped

After insert and **before** the first clone, `Loader` walks the template for `LuaSourceContainer`
descendants. If it finds one, it destroys the template, returns `nil` with `contains-script`, and
counts it in `stats().refusedScripts`.

Not paranoia: harness check 5 is *"No script (LuaSourceContainer) exists anywhere in the DataModel
outside the sourcemap"* (`tools/studio_mcp.py` docstring; the check prints as "No script exists
outside Rojo-managed paths"), so one surviving `Script` fails **every harness run from then on**.
Refusing rather than stripping is deliberate: a stripped free model is half-functional in ways nobody
looks for, and the right answer is a different asset. Karen's own Meshy exports cannot contain a
script, so in practice this fires only on Creator Store models — which, per D9, is also the only place
it can fire at all.

### 5.5 The two routes, and which is which (D5)

There is **one** upload route and therefore **one** primary load route. The second is derived and
optional.

**Route A — primary, always available: `InsertService:LoadAsset(row.modelId)`**, inside a `pcall`,
once per key, into the cache container.
- Why this one: the Open Cloud upload of an FBX produces a Model (*"Imports as Model container with
  MeshPart objects"*), and `LoadAsset` *"fetches an asset given its ID and returns a Model containing
  the asset"*. The ownership condition is satisfied by construction — *"The asset must be created or
  owned by the game creator"* — because the upload set
  `creationContext.creator.userId` to Karen's id and Karen owns the place.
- The `pcall` stays, but on honest grounds: the docs page does **not** say `LoadAsset` errors rather
  than returning `nil`. That is community knowledge (§11 source 8's two devforum threads), so the
  `pcall` is cheap insurance, not a documented requirement.
- `AssetService:LoadAssetAsync(assetId)` is the documented alternative and is **not used**: it buys
  nothing for owned assets, and the only thing it can do that `LoadAsset` cannot needs
  `AllowInsertFreeAssets`, which no script can set (§1.2, D9).

**Route B — derived, optional: `AssetService:CreateMeshPartAsync(Content.fromUri(row.meshUri),
{ CollisionFidelity = …, RenderFidelity = …, FluidFidelity = … })`.**
- Reachable **only** when `row.meshUri` has been recorded, and `meshUri` can only come from reading
  `MeshPart.MeshId` off a MeshPart the import produced (`MeshId` read security is None; write security
  is `NotAccessibleSecurity`).
- The signature is `(meshContent: Content, options?: Dictionary)` and the option keys are exactly
  `CollisionFidelity`, `RenderFidelity`, `FluidFidelity` (§11 source 6). `MeshId` is documented as
  *"The asset URIs of the mesh"* — a **string** — so it is passed to `Content.fromUri` unparsed. Do
  not dig a number out of it for `Content.fromAssetId` (research note note 39a(d)).
- **The only reason to use it:** the import's `RenderFidelity`/`CollisionFidelity` are wrong and
  re-importing is not wanted. It is the one route by which a script can choose either property at all.
- `Loader.template` hides which route ran; `LoadReport.route` records it, so a spec and a review can
  see it.

**Route selection, written out so it is not a judgement call:** use B when `row.meshUri ~= nil` **and**
the template produced by A reports a `RenderFidelity` other than `row.renderFidelity`. Otherwise A.
That makes B a repair path with a trigger, not a fork.

---

## 6. How a mesh becomes a usable in-game model

### 6.1 The rule that kills the scale bug: the consumer sets `Size`, always

`MeshPart.Size` scales the mesh, so **the exported scale never reaches the game**. Every consumer
writes `part.Size = row.sizeStuds`, and the manifest derives `sizeStuds` from real-world metres at
**1 stud = 0.28 m** (the constant `src/server/Boar/init.luau` and `src/shared/Shotgun/init.luau`
headers already cite). Meshy's export units are not trusted, not converted and not inspected.

The check that makes this safe rather than merely convenient: `Loader` measures the template's
**natural** bounding box and compares its aspect ratios with `sizeStuds`. Beyond
`ASPECT_TOLERANCE = 0.05` the load fails as `aspect`, because a non-uniform `Size` write is a
**squashed boar** — and a squashed boar measures perfectly. `naturalSizeStuds` is then pasted into the
row by the Builder so the check is against a committed number from that point on.

The v1 sizes are pinned to numbers already in the code, so the physics cannot move:

| key | `sizeStuds` | comes from | metres |
|---|---|---|---|
| `boar.body` | `Vector3.new(2, 3, 5.5)` | `Boar.CONFIG.BODY_SIZE` (`src/server/Boar/init.luau`) | 0.56 × 0.84 × 1.54 |
| `shotgun.handle` | `Vector3.new(0.4, 0.5, 4.4)` | `Shotgun.CONFIG.HANDLE_SIZE` (`src/shared/Shotgun/init.luau`) | 0.11 × 0.14 × 1.23 |

**The mesh is exactly the grey box's size, so nothing tuned to the grey box changes.** The boar's mass,
its `MAX_FORCE`, the three zone offsets in `Boar.CONFIG.ZONES` (the head zone sits 1.15 studs proud of
the front face), the gun's `GRIP` and `MUZZLE_OFFSET`: all still correct, all still covered by the 234
server specs on `main` (`TASKS.md` row 34). **A model that changes the hitbox invalidates every
hit-zone test in the repo.**

### 6.2 Pivot: measured, corrected by data, tolerated only up to a limit

`Loader` reports `pivotOffsetStuds` = bounding-box centre − template pivot. The consumer applies
`row.offsetStuds` when it welds the mesh on. `PIVOT_TOLERANCE_STUDS = 0.25` with `offsetStuds`
applied; past that the spec fails, because a 1-stud offset is a boar whose model walks beside its own
hitbox. A **machine** check, covering translation only.

**First fix before either (D17):** Studio's 3D Importer has *"If enabled, the Importer sets the pivot
point of the entire model to the scene origin"* plus **World Forward** and **World Up** settings. A
badly pivoted or rotated Meshy export is fixed there, in the dialog Karen already has open on the
import, before anything reaches `offsetStuds` or `rotationDeg`.

### 6.3 Orientation: `rotationDeg`, and only a screenshot can check it

There is no machine test for "the nose points forward": a mesh has no notion of forward. The
convention is written down in two places already — `src/server/Boar/init.luau`, `BODY_SIZE`: *"a
Part's LookVector is its -Z"*, and `src/shared/Shotgun/init.luau`, `GRIP`: *"the Handle's -Z is the
muzzle, so the barrel points away"*. `row.rotationDeg` is the correction the consumer applies, default
`Vector3.zero`, and **the only check is the screenshot in §13.4**. The knife held backwards for three
rounds (`docs/PROJECT_CONTEXT.md`) is this exact bug, and pretending a number catches it is how it
survives three rounds again.

### 6.4 The boar wears the mesh as a **cosmetic** part, and the grey box goes invisible, not away

`Boar.Body` gains one welded child of the trunk, built in `Body.create` beside the existing
`buildZones` call. **Corrected against Task 37 by D6 and research note 39a(b):**

```
the clone of Loader.template("boar.body")   -- a MeshPart, kind == "meshpart"
   Name       = "Model"
   Size       = row.sizeStuds
   CFrame     = trunk.CFrame * CFrame.new(row.offsetStuds) * CFrame.Angles(row.rotationDeg…)
   Massless   = true     -- the assembly's mass, centre of mass and inertia are untouched, so
                         -- MAX_FORCE / MAX_TORQUE / ACCEL stay correct (the reason buildZones
                         -- already sets it)
   CanCollide = false    -- the collision body stays the plain box
   CanQuery   = false    -- IT MUST NEVER BE HIT (below)
   CanTouch   = false, Anchored = false, CastShadow = true
   + WeldConstraint to the trunk

   NOT WRITTEN: RenderFidelity (PluginSecurity), CollisionFidelity (not scriptable at run time).
   Both arrive with the clone from the import and are asserted, not applied (§13.2 item 9).
```

Task 37's version of this block wrote `CollisionFidelity = Box, RenderFidelity = row.renderFidelity`.
**That is not executable** and a Builder copying it would ship two dead lines that lint green. Because
`CanCollide = false`, the cosmetic mesh's collision fidelity is irrelevant to the game anyway; it
matters only for map props, where it is an import setting.

`CanQuery = false` is the load-bearing line. `src/server/Boar/Body.luau`'s header already explains the
mechanism for the zone parts — *"THE ZONE PARTS PROTRUDE, AND THAT IS THE WHOLE TRICK. A ray returns
the nearest surface"* — and a queryable cosmetic mesh is that trick run backwards: it would swallow
every head and chest shot and report "body". `Camera.Viewmodel` sets `CanQuery = false` on its clone
for the same reason.

**And the grey box must become invisible.** `buildZones` writes
`zonePart.Color = if zones.ZONE_TINT then spec.tint else config.BODY_COLOR` — with `ZONE_TINT = false`
the zone parts are still fully **opaque**, and `ZoneHead` sticks 1.15 studs out of the boar's face. So
`Boar.CONFIG.MODEL.hideGreyBox = true` makes `Body.create` set `Transparency = 1` on the trunk and all
three zone parts. They keep `CanQuery = true` and the trunk keeps `CanCollide = true`: transparency
affects neither queries nor collisions, which is why hiding is correct and destroying would be
catastrophic. `Boar.CONFIG.ZONES.ZONE_TINT`'s own comment anticipates this — *"a grey-box teaching
aid, off when the model arrives"*.

### 6.5 The hit flash must be re-owned, or the model silently deletes the player's only hit feedback

`Body.setFlash` / `Body.stepFlash` / the local `paint` implement the flash by writing `Color` on the
trunk and the three zone parts. Once those four parts are `Transparency = 1`, **the flash is
invisible.** `Boar.Body`'s header calls it *"the cheapest unambiguous answer to 'did I hit it?' at 100
studs with no sound and no animation"*, and Karen confirmed it reads (`TASKS.md` row 28: *"the flash
plus the bolt read as a hit"*). Losing it to an art change is a pure regression that every existing
spec still passes, because every existing spec asserts `Color`.

**Decision: when a model is present, the flash is a `Highlight`.** One `Highlight` created once in
`Body.create`, parented to the trunk, `FillColor = config.WOUND.FLASH_COLOR`,
`FillTransparency = 0.5`, `OutlineTransparency = 1`, `DepthMode = Enum.HighlightDepthMode.Occluded`,
and `Enabled` toggled by the existing `paint` on the existing two-writes-per-hit transition. It stays
inside `Boar.Body` — the flash is a boar cosmetic and the owner does not change — and
`boar_body.spec` gains an assertion on `Enabled` alongside the existing `Color` one, branching on
whether a model is present, so neither branch is empty.

**D8 replaces Task 37's reasoning here with the real numbers, and they support the choice more
strongly than the guess did.** From `docs/effects/highlighting` (§11 source 9):
*"Adding or removing a Highlight can cause a geometry rebuilding step that might lead to performance
spikes and extra draw calls"* versus *"changing any property of the Highlight instance is lightweight
and doesn't impact performance."* Create once, toggle `Enabled` — exactly what `Body.stepFlash`
already does with `Color`. The limit is **255 simultaneous, client-side**, and *"a disabled Highlight
… still takes one of the 255 available Highlight slots"*. At `Boar.CONFIG.maxBoars = 8` that is not
close. **The real caution, which Task 37 got wrong in both directions:** the budget is global and
counts disabled instances, so it is a constraint on *later* systems (props, interaction prompts), not
on the boar. Put that sentence in the header, not "keep it to the boar".

### 6.6 The gun: `Hardware.build` returns a MeshPart Handle, and `Viewmodel` must stop stripping it

`Hardware.build` creates `Instance.new("Part")` named `Handle` with the `Muzzle` Attachment on it.
With a model key it instead clones the template's MeshPart, names it `Handle`, sets `Size`, `Massless`,
`CanCollide = false` and the same `TopSurface`/`BottomSurface`, and parents the same `Muzzle`
Attachment at the same `MUZZLE_OFFSET`. Everything downstream is unchanged:
`Hardware.muzzlePosition` finds `Handle.Muzzle` by name, and `Viewmodel` finds the `Handle` by name.

**But `Viewmodel` would strip the texture.** The local `build` in `src/client/Camera/Viewmodel.luau`
destroys every child that is not an `Attachment` — *"no scripts, no welds, no sounds: a shape and
nothing else"*. A `SurfaceAppearance`, a `Texture` or a `Decal` child is not an `Attachment`, so **the
first-person gun would lose its maps while the third-person gun kept them**: "purple untextured legs"
that appears only in ADS, only for the player holding it, and that no spec on `main` would notice.

Two decisions, and **D7 turned both from hopes into facts**:

1. **v1 uses `MeshPart.TextureID`, not `SurfaceAppearance`.** `TextureID` is Access **ReadWrite** with
   **no read or write security**, so a script can assign it at run time — the first half of
   measurement M3 is answered **yes**. A property survives `Clone()`, costs no Instance, and cannot be
   destroyed by a child sweep.
2. **A `SurfaceAppearance` can never be assembled by the Loader.** *"In general, you can't modify
   SurfaceAppearance properties by scripts during a game because the engine requires some
   pre-processing to display these graphics."* So if PBR maps ever arrive, they arrive **with the
   imported asset**, and the `Viewmodel` sweep fix — allow `Attachment`, `SurfaceAppearance` and
   `Texture` through, keep destroying the rest — becomes necessary. That fix is the **camera owner's**,
   in its own file, listed in §10 and done when it is needed, not speculatively.

### 6.7 Imports produce one MeshPart per key, deliberately

The 3D Importer's **Merge Meshes** imports *"as a single MeshPart"*, and the default does not — *"The
.fbx and .gltf formats support multiple mesh objects and hierachies"* (§11 source 11). For
`boar.body` and `shotgun.handle`, `kind = "meshpart"` and the Loader **fails** a multi-part template
as `multi-meshpart` rather than picking one. One mesh per key means one `Size` write, one pivot, one
texture and one thing to look at in a screenshot. Map props may be `kind = "model"` when a tree really
is several parts.

### 6.8 Map props are unchanged in behaviour and change one line in ownership

`MapGen.Props` keeps everything `docs/design/map-generator.md` §8.2 says — insert once per run into
the run's own folder, clone, anchor, destroy the template at the end, never persist a cache in a
Rojo-owned container — but it gets the template from `Loader` with `Loader.setCacheParent(runFolder)`
instead of calling an insert itself. One caller of `LoadAsset` in the repo, one script-refusal
implementation, one cache-shape decision, two cache locations chosen by the caller. The StudioMCP
`insert_asset` fallback that design names still works unchanged: it lands the template in the same
folder and `Loader.template` finds it there.

**But that design's §8.2 is now wrong about Creator Store assets and must be corrected (§15 D2).**

---

## 7. The upload tool — `tools/assets.py`

Plain Python 3, **stdlib only** (`urllib.request`, `json`, `hashlib`, `os`, `struct`), matching
`tools/studio_mcp.py`'s dependency profile. No `requests`, no SDK: a third-party HTTP library in the
one program that holds a secret is a supply-chain surface for no gain.

### 7.1 Commands

```
python tools/assets.py key                          # is the key set? prints set/not set + fingerprint
python tools/assets.py init                          # write sidecar stubs for dropped files lacking one
python tools/assets.py validate                      # read-only: every dropped file, pass/refuse, why
python tools/assets.py upload [<key>...] [--dry-run] # validate, upload, poll, print the manifest rows
python tools/assets.py check <id>...                 # re-poll moderation for ids already in the manifest
python tools/assets.py resume <operationPath>        # finish a poll that was interrupted (§7.7)
python tools/assets.py record <key> <id>             # print a row for an id imported through Studio (§7.6)
python tools/assets.py licences                      # print each dropped file's basis and whether it may
                                                     # be uploaded, from the sidecars; no network
python tools/assets.py selftest                      # offline: validator + request + response parsing
```

Exit codes, deliberately the harness's shape: **0** done · **1** something failed · **2** REFUSED (key
unset, drop dir unset or wrong, validation refused before any request).

`--dry-run` does everything except the two HTTP calls and prints the exact request it *would* send,
with the key replaced by `***`. **The whole tool is therefore reviewable, and `selftest` runs in CI,
with no key and no network.**

### 7.2 Where the files come from

- **`ASSET_DROP_DIR`, and there is no default.** Unset ⇒ **exit 2** naming the variable. Karen's drop
  folder is a path on her PC, outside the repo; this document calls it `<assets-dir>` and never writes
  it out, because the repo is public and `CLAUDE.md`'s history check greps every commit for local
  paths (`TASKS.md` row 39a(h) raised exactly this against the Task 37 design, which hard-coded it).
- **Refused if it resolves inside the repository** (`os.path.commonpath` against the repo root). A
  source tree that can be uploaded from is a source tree someone commits.
- Refused if it does not exist. Printed as `<drop dir>`, never as an absolute path — a review request
  quotes the tool's stdout.
- `.assets/<utc>.json` records file **names**, never paths, and never the key.

### 7.3 Validation, before any request

Every refusal names the file, the rule and the fix. In order:

1. **Name** matches §4.3's grammar. Key and version derived, never prompted.
2. **Sidecar present** (`<key>_v<N>.json`) and parses, with `source`, `creator`, `licenceBasis`,
   `licenceQuote`, `licenceQuotedFrom`, `licenceReadOn`, `trisDeclared`, `sizeMetres` (or
   `sizeStuds`), optional `offsetStuds`, `rotationDeg`, `notes`. `init` writes stubs so Karen fills in
   fields, not a schema.
3. **Type**: `.fbx` for a model, `.png` for an image. `.jpg`, `.tga`, `.bmp`, `.obj`, `.glb`, `.blend`
   are **refused** — one format per job, so there is no "which of five paths did this take" later.
   (Roblox accepts more; we do not.)
4. **Size** ≤ `MAX_FILE_BYTES = 20 MB`. **This is Roblox's limit, not ours** (D3): *"For each call, you
   can only create or update one asset with the file size up to 20 MB"*.
5. **PNG only**: the 8-byte signature `89 50 4E 47 0D 0A 1A 0A` must match exactly, then width and
   height are the two big-endian uint32s at the head of the `IHDR` chunk, which *"shall be the first
   chunk in the PNG datastream"*. Twenty-four bytes, fixed offsets, no library. Refused above
   `TEXTURE_MAX_PX = 1024` — **our budget** (D2), matching Roblox's own recommendation for a 20-stud
   object; the platform limits are 4096×4096 generally and 8000×8000 for a Decal/Image upload.
   §0 item 1 is not violated: no geometry, no compression, no interpretation.
6. **`trisDeclared`** ≤ the key's budget (§12.1) and ≤ `MESHPART_TRI_LIMIT = 20,000`. **First-party,
   one sentence** (D1): *"Individual meshes can not exceed 20,000 triangles."* Task 37 printed 21,000
   labelled "community/vendor"; both halves were wrong. Declared, not measured: Roblox's importer is
   the enforcer.
7. **Duplicate check**: the file's SHA-256 already in the manifest under this key ⇒ refuse ("already
   uploaded as id N version M"). This is what stops a second identical asset because somebody re-ran
   the command.
8. **Licence**: `licenceBasis` is one of `Assets.BASES`'s keys **and** its `mayUpload` is true.
   `"unresolved"` ⇒ refuse with exit 2 and print what would have to be established. An unknown string
   ⇒ refuse; the tool never invents a basis. `licenceQuote` non-empty.

### 7.4 The Open Cloud flow

Every line here is quoted from the page, fetched 2026-09-26 (§11 source 1).

1. `POST https://apis.roblox.com/assets/v1/assets`, header `x-api-key: <key>`,
   `multipart/form-data` with exactly two parts: **`request`** (the JSON) and **`fileContent`** (the
   bytes), the file part carrying `type=model/fbx` or `type=image/png`. The page's own example is
   `--form 'request="{...}"' --form 'fileContent=@"…/model.fbx";type=model/fbx'`.
2. The `request` JSON: `{"assetType": …, "displayName": …, "description": …, "creationContext":
   {"creator": {"userId": "${userId}"}}}`.
   - `assetType` is **`"Model"`** for an FBX. **Never `"Mesh"`**: that type is *"Roblox only … Only
     Asset delivery API content accepted"* (D5, §0 item 6).
   - For a PNG, `Decal` and `Image` both accept `image/png` and are **distinct** `Enum.AssetType`
     items. **Ask for `Image`** when the id is destined for `MeshPart.TextureID` (D12). This is the
     real "Decal-id-versus-Image-id trap", and the API lets you choose, so choose.
   - The user id comes from an environment variable (`ASSET_CREATOR_USER_ID`), not a literal: it is
     not a secret, but it is Karen's account and does not belong in a public file.
3. The reply is a long-running **operation**: `{"path": "operations/<id>", "done": false}`. **Write
   that path into the run log before polling** (§7.7).
4. `GET https://apis.roblox.com/assets/v1/operations/<id>` every `POLL_INTERVAL_S = 2` up to
   `POLL_DEADLINE_S = 120`, until `done`. The asset id is at **`response.assetId`** and is a **string**
   in the documented example (`"assetId": "2205400862"`) — **coerce it before printing a Luau number**
   (D13).
5. Moderation is at `response.moderationState` and the documented value is **prefixed**:
   `"MODERATION_STATE_APPROVED"`. **Match on the `MODERATION_STATE_` prefix and treat every unknown
   value as "not approved"** (D13). Task 37 keyed on `"Reviewing"` and `"Rejected"`, which are not the
   documented spellings; hard-coding two strings is how a rejected asset quietly reads as fine.
6. Print the manifest row and the moderation state. Append to `.assets/<utc>.json`.

### 7.5 The tool prints the row; the **Builder** pastes it

`tools/assets.py` never writes a file under `src/`. It prints a StyLua-shaped block (tabs,
`indent_width = 4`, double quotes — `stylua.toml`) ready to paste into
`src/serverstorage/Assets/init.luau`, or into `Quarantine.luau` when the basis is unresolved.

Why not write it: `CLAUDE.md` makes the Builder *"the only writer of code in `src/`"*, the manifest is
a linted, formatted `.luau` file, and `docs/design/map-generator.md` §2.1 already said the manifest is
the file *"the Builder edits… Karen supplies the ids"*. A generator that emits Luau is a formatter bug
waiting to fail CI, to save one paste per model. The facts come from the tool; the commit comes from
the Builder; the diff is reviewable as a diff.

### 7.6 The named fallback: Studio's 3D Importer, same manifest

If Open Cloud will not take an FBX as a Model from this account (measurement M1), the route becomes
**Studio's own 3D Importer** and `tools/assets.py` keeps every other job: `validate`, the duplicate
check, `licences`, `check` for moderation, and `record <key> <id>` to print the row from an id Karen
pastes in. The manifest, the Loader, the specs, the budgets and all of §6 are unchanged.

The importer is a good fallback rather than a bad one (§11 source 11): it takes the same FBX, it
publishes the result with one tick — *"the Importer adds the model to your Toolbox and Asset Manager
inventory as a new asset"* — and it has explicit controls for the two things §6.2 and §6.3 worry
about: pivot to scene origin, and **World Forward** / **World Up**. It is also the **only** place
`RenderFidelity` and `CollisionFidelity` can be chosen without route B (D6). Every one of those
controls is a Studio dialog, so this path costs Karen clicks and costs the pipeline nothing.

For a colour map: if an `Image` upload's id will not take on `TextureID`, the map comes **with** the
FBX import instead, `textureId` stays `nil`, and §13's texture assertion reads the MeshPart's own
`TextureID` rather than the row's id. Both branches are asserted by the same spec, branching on
`row.textureId`.

### 7.7 Failure modes, and how each is loud

| Failure | What the tool does |
|---|---|
| `DRIVEN_HUNT_ROBLOX_API_KEY` unset | **exit 2**, names the variable and §8. Never prompts, never reads stdin: a typed key lands in the terminal's scrollback |
| `ASSET_DROP_DIR` unset or inside the repo | **exit 2** (§7.2) |
| 401 / 403 | prints the status, the endpoint and the body **with every header redacted**; names the three causes in order: key revoked, key expired, **caller IP not in Accepted IP Addresses** |
| 429 | honours `Retry-After`, else backs off 2 / 4 / 8 s; after `RETRIES = 3` it stops the **whole run**. This is not politeness: the rate-limits page says *"Always ensure your application handles HTTP 429 rate limit responses"* and *"check the `retry-after` response header as a guideline for when to retry"* (D10) |
| 5xx / connection reset | same backoff, then fail this file and continue with the next |
| operation still `done: false` at 120 s | **not a failure**: prints `pending-operation` and the operation path, and says `python tools/assets.py resume <path>`. The id may already exist; re-uploading creates a duplicate nobody can tell from the first |
| `moderationState` not `MODERATION_STATE_APPROVED` | row printed with `moderation = "reviewing"` (or `"rejected"` / `"unknown"`). **Loud, because this is the grey-model trap**: a pending texture can render blank, so a model that looks wrong may be waiting for moderation rather than broken. §13.5 says this is not a bug to chase |
| more than `MAX_UPLOADS_PER_RUN = 20` files | refuses the run and asks for explicit keys. A folder-wide accident uploads Karen's whole Desktop |
| any exception after the POST | the run log already holds the operation path (§7.4 step 3), so nothing is orphaned |

---

## 8. The key: Karen's clicks, once

### 8.1 Creating it — labels corrected against the live page (D11)

Task 37's step list had four wrong labels and one step that does not exist. This list quotes the
api-keys page as read on 2026-09-26.

1. Open <https://create.roblox.com/dashboard/credentials> (the **Credentials** page; API Keys tab is
   `?activeTab=ApiKeysTab`), signed in as **the account that will own the assets**.
2. **Create API Key**.
3. *"Enter a unique name for your API key"*: `driven-hunt-assets`. Description: "Driven Hunt asset
   uploads".
4. **Access Permissions** → *"select an API from the **Select API System** menu"* → **Assets**.
   (Task 37 said "Add API System".)
5. *"If applicable, select the game that you want to access with the API key."* **This is the one step
   Karen must report back.** The Assets guide says *"Add Read and Write operation permissions to your
   selected game"*, which is written for the experience-scoped APIs; for an asset upload to a *user*
   account the creator is chosen **per request** by `creationContext.creator.userId`. Task 37 invented
   a step here ("Add Experience / choose the creator: select her own user account") that has no
   counterpart in the docs. Only Karen's screen settles it.
6. *"From the **Select Operations** dropdown, select the operations"*: **read** and **write**, nothing
   else. No `universe-places`, no `datastores`, no `messaging`.
7. **Security**: turn on **Restrict IP addresses** and put her own address in **Accepted IP
   Addresses** in CIDR — `A.B.C.D/32`. (The docs' own example is `/24`.) Leaving the toggle **off** is
   the documented way to allow any IP; `0.0.0.0/0` is not mentioned by the docs and should not be
   typed. A key with no IP restriction works from anywhere in the world if it leaks.
8. *"To add additional protection for your resources, set an expiration date for your key."* Use 30
   days. Short expiry is the cheapest rotation policy there is, and the page offers no other.
9. Save, then **copy the key**: *"Copy and save the API key string to a secure location, **not a public
   repository for your code**."* Task 37 asserted the key *"is shown once"*; the docs do not say that.
   Behave as if it is; **do not claim it**, and Karen can report whether it is (§16 Karen 2).

### 8.2 Storing it (Windows, GUI path, and the reason matters)

1. Start → "Edit the system environment variables" → **Environment Variables…** → under **User
   variables** → **New…**
   - `DRIVEN_HUNT_ROBLOX_API_KEY` = the key.
   - `ASSET_CREATOR_USER_ID` = her numeric Roblox user id.
   - `ASSET_DROP_DIR` = her drop folder (§7.2).
2. **OK** three times, then **close and reopen the terminal** (a running shell keeps its old
   environment).

**Do not use `setx`.** It puts the key in a command line, and a command line lands in the shell's
history — PowerShell writes `ConsoleHost_history.txt` to disk by default. The GUI dialog writes no
history. Same reason the tool refuses to take the key as an argument. *(This reasoning is ours; the
discipline around it is **corroborated** by the api-keys page, not invented — D11 corrected Task 37,
which credited the wrong page with saying nothing: the api-keys page says *"The API key string is
equivalent to a password for your application. Never share it with untrusted parties."*)*

### 8.3 Checking it without revealing it

`python tools/assets.py key` prints one of:

```
[assets] DRIVEN_HUNT_ROBLOX_API_KEY: not set   (see docs/design/asset-pipeline.md section 8)
[assets] DRIVEN_HUNT_ROBLOX_API_KEY: set, fingerprint 3f9c2a14, ASSET_CREATOR_USER_ID: set
```

The fingerprint is the first 8 hex of the key's SHA-256: enough to tell "did the variable change" and
"is this yesterday's key" apart, and not invertible. **Printed, never written to a file, never
committed, never pasted into a review request.**

### 8.4 The rules that hold everywhere else

- The key is read **once**, into a local, from `os.environ`. Never logged, never printed, never put in
  an exception message, never written into `.assets/`; every request's headers are redacted before any
  print. `--dry-run` prints `x-api-key: ***`.
- `.gitignore` gains `/.assets/`.
- **CI never has it** and never will: `.github/workflows/ci.yml` gets `selftest`, which is offline.
- If it leaks: Creator Dashboard → delete the key → create a new one → tell Karen. `CLAUDE.md` already
  says revoke first, and removing it from history does not un-publish it.

---

## 9. The typed-value question (`TASKS.md` row 16), answered again

**This system does not need the harness to learn typed values, and is deliberately built to keep it
that way.** Row 16's note still says it *"lands with the map generator, before any positioned
geometry"*; `docs/design/map-generator.md` §7 already showed that assumption was wrong, and the asset
pipeline is the second system that would have needed it and does not:

| What you might put on disk | Where it goes instead | Why |
|---|---|---|
| a boar/gun/tree template (`MeshPart` with `Size`, `CFrame`, `MeshId`) | nowhere: built by code from a manifest row at run time (§6) | `.rbxm` is banned; a `.model.json` `Vector3` fails the harness as "cannot compare"; an instance made in Studio inside `ServerStorage` is deleted at the next Connect; and `MeshId` is `NotAccessibleSecurity` to write anyway |
| ids, licences, budgets, dimensions | `src/serverstorage/Assets/init.luau`, plain Luau | Luau has `Vector3` natively, selene and StyLua lint it, the harness compares the **source byte-for-byte**, and a changed id is one readable line in a PR |
| the mesh and texture files | `<assets-dir>`, outside the repo | licence, public repo, binary size |

**One new case does need row 16, and it is the one D9 created:** a free Creator Store model whose
creator did **not** tick share is loadable by no script route at all, so the only way to use it is to
insert it in Studio by hand and export it to `src/serverstorage/` as `.model.json` — which needs typed
values. That is a *map-props* problem (§16 Karen 3), not an M2.7a problem, and the recommendation is to
avoid the case rather than to unblock row 16 for it.

**Recommendation to the Director, unchanged: row 16 stays under "before release", and its "lands with
the map generator" note is wrong.**

---

## 10. What this system reads from and writes to other systems

| Direction | What | The other side's owner | Evidence |
|---|---|---|---|
| **writes** | `ServerStorage.AssetCache` and everything in it, at run time | `Assets.Loader`; no other writer | this design. Hazard, stated: an instance created there **in Edit mode** is deleted at Karen's next Connect (`CLAUDE.md`), so the cache is run-time only, and at edit time the caller nominates the container |
| **writes** | nothing else in the DataModel, ever | — | §1.2 |
| **is read by** | `Assets.byKey` / `describe` / `budget` / `keysFor` / `BASES` | nobody writes them; `Shotgun.deepFreeze`d | §4.2 |
| **is read by** | `Loader.template`, by `Boar.Body` (`Body.create`) | `ServerScriptService.Boar` clones and places; the pipeline never touches `Workspace.Boars` | `src/server/Boar/Body.luau` header |
| **is read by** | `Loader.template`, by `Weapon.Hardware` (`Hardware.build`) | `ServerScriptService.Weapon` | `src/server/Weapon/Hardware.luau` header |
| **is read by** | `Loader.template`, by `MapGen.Props`, at edit time | `ServerStorage.MapGen` | `docs/design/map-generator.md` §2.1 |
| **is called by** | `Loader.preload(Assets.keysFor("runtime"))` | `ServerScriptService.MatchBoot` — the drive's composition root | `GAME_DESIGN.md`, Match row |
| **is called by** | `Loader.preload({ Assets.KEYS.shotgunHandle })` | `ServerScriptService.WeaponBoot` | `GAME_DESIGN.md`, Weapon row |
| **cross-system change** | `Boar.CONFIG` gains `MODEL = { key, enabled, hideGreyBox }`; `Body.create` welds the cosmetic MeshPart (**writing no fidelity property**), hides the grey box, and flashes with a `Highlight`; `ZONES.ZONE_TINT` → `false` | `ServerScriptService.Boar`, in its own file, by its owner | §6.4–§6.5 |
| **cross-system change** | `Shotgun.CONFIG` gains `MODEL = { key, enabled }`; `Hardware.build` clones a MeshPart Handle, same name, same `Muzzle`, same `Size` | `ServerScriptService.Weapon` | §6.6 |
| **cross-system change, only when `SurfaceAppearance` arrives with an import** | the local `build` in `Viewmodel.luau` must keep `SurfaceAppearance` and `Texture` children, not only `Attachment` | `PlayerScripts.Camera.Viewmodel` | §6.6 |
| **docs change** | `assets/source/README.md` and `assets/ready/README.md` stop inviting binaries and `ASSET_IDS.md`, and point at the manifest | the Builder (they are not Architect files) | §15 D5 |

**Nothing else.** No change to `Boar.Brain`, `Boar.Wound`, `Match`, `Hud`, `Camera.Rig`, `Camera.Mode`,
`Weapon.Cast`, `Weapon.Pattern`, `tools/studio_mcp.py`, or `default.project.json` —
`src/serverstorage` is already mapped, so **no Rojo restart and no extra Connect click**.

---

## 11. External sources

Fifteen. **Every one was fetched live on 2026-09-26** and is quoted in
`docs/research/2026-09-26-asset-pipeline.md`, which is the citation of record for this design: where
this section and that note differ, **the note is right** (`reviews/task-40/BRIEF.md`). Roblox
first-party documentation dominates because the pipeline is entirely first-party. Licence of the
Roblox docs source throughout: **CC BY 4.0** (`github.com/Roblox/creator-docs`, SPDX `CC-BY-4.0`);
maintenance **active** (the docs repo was pushed to 2026-09-25).

Two access facts worth keeping, because this project has already lost a licence page to one of them:
`en.help.roblox.com` HTML returns **HTTP 403** to tools and to `curl`, and is readable as
`https://en.help.roblox.com/api/v2/help_center/en-us/articles/<id>.json` (field `article.body`);
and `create.roblox.com/docs/<path>.md` serves the raw source including the property security metadata
the rendered page hides.

1. **Open Cloud — Assets API usage guide.**
   <https://create.roblox.com/docs/cloud/guides/usage-assets> (the canonical path; Task 37's
   `cloud/open-cloud/usage-assets` still serves it).
   **Good:** the whole flow, first-party, no SDK — endpoints, `x-api-key`, the `request` + `fileContent`
   multipart, the operation, `response.assetId`, the supported-type table, the 20 MB cap.
   **Bad:** the *"select the game"* wording is written for experience-scoped APIs and is confusing for
   an upload to a user account; no per-minute rate limit is published.
   **Adopted:** §7.4 verbatim, `MAX_FILE_BYTES`, and — decisively — §0 item 6 / D5.

2. **Open Cloud — Manage API keys.** <https://create.roblox.com/docs/cloud/auth/api-keys>.
   **Good:** the authority on §8.1, and it gives the two controls that make a key on a personal PC
   acceptable: **Accepted IP Addresses** in CIDR and an **expiration date**. It also names public
   repositories as the thing not to put a key in.
   **Bad:** a walkthrough of a dashboard that gets redesigned; no rotation policy; it does **not** say
   the key is shown once.
   **Adopted:** least privilege, `/32`, 30-day expiry, GUI env var instead of `setx`.

3. **Open Cloud — rate limits.** <https://create.roblox.com/docs/cloud/reference/rate-limits>
   (`cloud/open-cloud/rate-limits` is 404). Task 37 did not cite this and should have.
   **Good:** *"Always ensure your application handles HTTP 429"*, *"check the `retry-after` response
   header"* — §7.7's behaviour is Roblox's instruction, not our manners.
   **Bad:** *"Additional, undocumented limits may apply"*, so no client can be proven polite;
   `MIN_REQUEST_GAP_S` is a guess and is labelled one.
   **Adopted:** 429 + `Retry-After`, relabelled (D10).

4. **Mesh specifications.** <https://create.roblox.com/docs/art/modeling/specifications>.
   **Good:** *"Individual meshes can not exceed 20,000 triangles."* One sentence, unambiguous,
   first-party. Also *"A vertex can not be influenced by more than 4 bones or joints"*.
   **Bad:** it is the only number on the page — no vertex cap, no stud size, no texture resolution. The
   per-key budgets in §12.1 stay unmeasured taste-and-performance figures and this page cannot validate
   them.
   **Adopted:** `MESHPART_TRI_LIMIT = 20,000`, first-party (D1).

5. **Texture specifications.** <https://create.roblox.com/docs/art/modeling/texture-specifications>.
   **Good:** albedo is plain 24-bit RGB PNG, which is what Meshy exports; *"Roblox supports up to
   4096x4096 pixel texture resolutions (4K)"*; and 1024×1024 is its **recommendation** for a 20-stud
   object, which the boar, the high seat and the trees are or are near.
   **Bad:** "1024" appears twice in two meanings (UV space vs recommended map size) and a careless read
   turns a recommendation into a limit — which is what Task 37 did. Normal maps must be *"OpenGL format
   - Tangent Space"*, a trap no assertion here catches and only a screenshot shows.
   **Adopted:** `TEXTURE_MAX_PX = 1024` **as our budget** (D2).

6. **`AssetService`, and the `Content` datatype.**
   <https://create.roblox.com/docs/reference/engine/classes/AssetService> ·
   `…/AssetService.md` (raw, carries the security metadata) ·
   <https://create.roblox.com/docs/reference/engine/datatypes/Content>.
   **Good:** `CreateMeshPartAsync(meshContent: Content, options?: Dictionary)` with option keys
   `CollisionFidelity`, `RenderFidelity`, `FluidFidelity`; *"Since MeshPart.MeshId is read-only, this
   method allows mesh creation through scripts"*; `Content.fromUri` / `fromAssetId`; **Yields: Yes**.
   And `AllowInsertFreeAssets` is Access ReadOnly with **`RobloxScriptSecurity` on read and write**.
   **Bad:** no limits, no throttling, no caching statement, and it does not say which *kind* of asset
   id a mesh `Content` may name. The only cost figure anywhere is community (~22 ms + ~0.27 ms/1k tris,
   devforum).
   **Adopted:** route B and its exact signature (D4); and D9's prohibition.

7. **`MeshPart` / `TriangleMeshPart` — which properties a script may write.**
   `…/classes/MeshPart.md` · `…/classes/TriangleMeshPart.md` (raw sources).
   **Good:** it settles two questions with no engine. `TextureID` is Access ReadWrite with **no**
   security ⇒ assignable at run time. `MeshId` read security is None ⇒ `meshUri` is obtainable.
   **Bad:** `RenderFidelity` is write-security `PluginSecurity`; `CollisionFidelity` *"cannot be read or
   manipulated by scripts during runtime"*. Two manifest fields stop being instructions.
   **Adopted:** D6 and D7 — §1.2's two new prohibitions, §6.4's corrected block, §13.2 item 9.

8. **`InsertService`.** <https://create.roblox.com/docs/reference/engine/classes/InsertService>.
   **Good:** *"The LoadAsset function fetches an asset given its ID and returns a Model containing the
   asset"*, server-side, capability `LoadOwnedAsset`; and the ownership list whose first bullet —
   *"created or owned by the game creator"* — Karen's own uploads satisfy by construction.
   **Bad:** it does not say it errors rather than returning `nil` (community knowledge; the `pcall`
   stays on community evidence), there is no caching statement, and it contains the wall:
   *"To load assets which do not meet the above criteria, such as free Models published on the Store,
   you must use `AssetService:LoadAssetAsync()` and enable `AssetService.AllowInsertFreeAssets`."*
   **Adopted:** route A, in a `pcall`, once per key, behind `Loader.template`; and D9.

9. **Highlighting objects.** <https://create.roblox.com/docs/effects/highlighting> — **the page with
   the numbers**, which Task 37 did not cite (it cited the class page, which carries none of them).
   **Good:** *"Studio only displays 255 simultaneous Highlight instances on the client-side at a time"*;
   *"Adding or removing a Highlight can cause a geometry rebuilding step that might lead to performance
   spikes"* versus *"changing any property … is lightweight"*. That is §6.5's pattern, confirmed.
   **Bad:** *"a disabled Highlight … still takes one of the 255 available Highlight slots"* — the budget
   is global and counts things that are not drawn, so it constrains later systems.
   **Adopted:** create once, toggle `Enabled`; the caution rewritten (D8).

10. **PBR textures and `SurfaceAppearance`.**
    <https://create.roblox.com/docs/art/modeling/surface-appearance> ·
    `…/classes/SurfaceAppearance`.
    **Good:** *"In general, you can't modify SurfaceAppearance properties by scripts during a game
    because the engine requires some pre-processing"* — a better reason for v1's `TextureID` choice
    than Task 37's "a property survives `Clone()`".
    **Bad:** it does not say whether the 3D Importer creates one from an FBX's PBR maps, which is the
    practical question and stays a measurement.
    **Adopted:** D7 — `TextureID` in v1, `SurfaceAppearance` only ever with the import.

11. **Studio's 3D Importer.** <https://create.roblox.com/docs/art/modeling/3d-importer>.
    **Good:** "Merge Meshes" imports *"as a single MeshPart"*; pivot to scene origin; World Forward /
    World Up; *"adds the model to your Toolbox and Asset Manager inventory as a new asset"*. It makes
    §7.6 a real fallback and §6.7 an achievable rule.
    **Bad:** nothing about textures embedded in the FBX, nothing about `SurfaceAppearance`, and every
    control is a dialog — a Karen click, not something a tool can drive.
    **Adopted:** §7.6, §6.7, and D17's ordering in §6.2.

12. **PNG specification (third edition).** <https://www.w3.org/TR/png-3/>. Licence: **W3C Software and
    Document Notice and License**; the format is unencumbered. Maintenance: **W3C Recommendation,
    24 June 2025** (Task 37 said "third edition, 2023" — D14).
    **Good:** the 8-byte signature is fixed and *"The IHDR chunk shall be the first chunk"*, so width
    and height are at constant offsets: 24 bytes, no library.
    **Bad:** it says nothing about content. A 1024×1024 PNG can be the normal map filed as albedo, in
    the wrong handedness. Only the screenshot catches that.
    **Adopted:** signature + IHDR only (§7.3 item 5).

13. **Meshy — Terms of Use and the plan-by-plan licence.** <https://www.meshy.ai/terms-of-use>
    (Task 37 pointed at the site root; `meshy.ai/terms` is 404) ·
    <https://help.meshy.ai/en/articles/9992001-…> · <https://www.meshy.ai/pricing>. Terms **last
    updated 19 September 2026**.
    **Good:** the position is published and plain, not a guess. §3.2: on a **free plan**, *"Meshy owns
    all right, title, and interest … in and to the Customer Output"*, made available under
    **CC BY 4.0**; on a **paid plan**, *"customers on a paid Meshy plan own their Customer Output."*
    Meshy remeshes to a triangle target and exports FBX with PBR maps, which is why this pipeline can
    be thin.
    **Bad:** free-plan output is **not owned by Karen**; §3.3 puts anything posted to the community page
    under **CC0**; §2.9 lets Meshy train on non-Enterprise inputs and outputs.
    **Adopted:** `basis = "meshy-free-ccby"` / `"meshy-paid-owned"` in §4.5, with the quote and the date
    recorded per row.

14. **CC BY 4.0 legal code, and Roblox's User and Creator Terms.**
    <https://creativecommons.org/licenses/by/4.0/legalcode.en> · Roblox Terms, article 115004647846,
    read through the help-centre JSON API; last updated **2026-09-22**.
    **Good:** it names the collision exactly. CC BY 4.0 §2(a)(1) is **"non-sublicensable"**; §3(a)(1)
    lists what attribution must carry. Roblox's Creator Terms grant Roblox a licence *"with the right
    to sublicense to any person or entity"* and require that the Creator *"must not Publish … any UGC
    if Creator is not the owner of or is not fully authorized to grant rights in all parts of that
    UGC."* Also the sentence that licenses a *free* Store asset: sharing is a thing the creator
    **may** agree to, not a default.
    **Bad:** it is a genuine tension and **nobody in this workflow is qualified to resolve it**. This
    design states it and makes it machine-readable; it is not legal advice.
    **Adopted:** §4.5's `mayShip = false` default for `meshy-free-ccby`, and §16 Karen 1.

15. **Creator Store Terms.** article 21308223046932, last updated **2026-09-22**, read through the
    help-centre JSON API (the HTML is 403).
    **Good:** the grant, in full: *"By purchasing assets on the Creator Store, User is granted a license
    to use the asset in Roblox Studio and in Experiences on the Services consistent with the Roblox
    User and Creator Terms."* It closes the hole `docs/research/2026-09-24-map-generator.md` §8 left
    open (*"I have not read the primary licence text"*), and both rules that note derived now stand on
    primary evidence: **never commit a Creator Store asset**, **record provenance per row**.
    **Bad:** the grant is written for **purchased** assets and says nothing about free ones; and nothing
    in it is a redistribution grant — a public git repo is not "the Services".
    **Adopted:** `creator-store-purchased` and `creator-store-shared-free` as two different bases in
    §4.5, because they rest on two different documents.

**Also considered and rejected, so they are not re-proposed:** a geometry parser (`pyassimp`, Blender
`bpy`) to count triangles before upload — Roblox enforces 20,000 itself and Meshy sets the target;
a `.rbxm` template in the repo — banned and grepped by CI; a `.model.json` template — needs
`TASKS.md` row 16; a community uploader library — a third-party dependency in the one program holding
a secret; `tools/studio_mcp.py upload` — the harness is the test gate and nothing else;
**setting `AssetService.AllowInsertFreeAssets` from code** — impossible, `RobloxScriptSecurity` on read
and write; **assembling a `SurfaceAppearance` in the Loader** — documented not to work at run time.

---

## 12. Numeric targets

**K** = Karen's taste value: a number she changes after looking, not a measurement.
Derived at **1 stud = 0.28 m**.

### 12.1 Per-key budgets (v1)

Every triangle figure is a **target to be measured**. The instance counts come from
`docs/design/map-generator.md` §12 and `Boar.CONFIG.maxBoars = 8`.

| key | what | `sizeStuds` | metres | tris ≤ | texture ≤ | `renderFidelity` (at import) | instances |
|---|---|---|---|---|---|---|---|
| `boar.body` | the boar | 2, 3, 5.5 | 0.56 × 0.84 × 1.54 | 6,000 | 1024² | Automatic | ≤ 8 |
| `shotgun.handle` | break-action shotgun | 0.4, 0.5, 4.4 | 0.11 × 0.14 × 1.23 | 4,000 | 1024² | **Precise** (seen in ADS) | ≤ 16 + 1 viewmodel |
| `prop.highseat` | hunter's high seat | 4.3, 14.3, 4.3 | 1.2 × 4.0 × 1.2 | 1,500 | 512² | Automatic | ≤ 12 |
| `tree.spruce.a` | spruce | 14, 71, 14 | 3.9 × 20 × 3.9 | 900 | 512² | Automatic | ≤ 1,800 |
| `tree.birch.a` | birch | 18, 64, 18 | 5 × 18 × 5 | 900 | 512² | Automatic | ≤ 900 |
| `tree.oak.a` | oak | 32, 64, 32 | 9 × 18 × 9 | 1,200 | 512² | Automatic | ≤ 300 |

At those numbers the woods are ~2.4 M triangles of unique geometry instanced across ≤ 3,000 parts,
inside the map design's `BUDGET.trees = 3000` and `parts = 20000`. Every figure is far inside the
20,000-triangle limit. **Unmeasured**, and the mesh-specifications page cannot validate them — only the
map design's measurement D (cost of 50 trees) can. If they must come down, the tree budget comes down
before the boar's.

**`renderFidelity` here is a column of import settings, not of Loader instructions** (D6). The row
records it and a spec asserts it; nothing writes it.

### 12.2 Pipeline and loader numbers, with corrected bases

| Quantity | Value | Basis |
|---|---|---|
| `MESHPART_TRI_LIMIT` | **20,000** | **first-party**: *"Individual meshes can not exceed 20,000 triangles."* (Task 37 said 21,000 "community/vendor"; wrong in both halves — D1) |
| bone influences per vertex | ≤ 4 | first-party. Free constraint; matters only if the boar is ever skinned |
| `TEXTURE_MAX_PX` | 1024 | **ours.** Platform limits are 4096×4096, and 8000×8000 for a Decal/Image upload. 1024 is also Roblox's recommendation for a 20-stud object (D2) |
| `MAX_FILE_BYTES` | 20 MB | **Roblox's, documented** per call (D3) |
| maps per asset | ≤ 4; **v1 albedo only** | design decision, and now forced: a `SurfaceAppearance` cannot be built at run time |
| `UPLOAD_TIMEOUT_S` | 60 per HTTP request | ours |
| `POLL_INTERVAL_S` / `POLL_DEADLINE_S` | 2 / 120 | ours. Past the deadline is `pending-operation`, not a failure |
| `RETRIES` / backoff | 3 / 2, 4, 8 s, `Retry-After` wins | **Roblox's instruction** (D10) |
| `MIN_REQUEST_GAP_S` | 1.0 | **ours, and necessarily a guess**: no per-endpoint limit is published for create/update/operations, and *"additional, undocumented limits may apply"* |
| `MAX_UPLOADS_PER_RUN` | 20 | ours. A folder-wide accident |
| `KEY_EXPIRY_DAYS` | 30 | ours. The api-keys page offers an expiry but no rotation policy |
| simultaneous `Highlight`s | **≤ 255, client-side, enabled *or* disabled** | **first-party** (D8) |
| first `Highlight` GPU cost | up to **1 ms** on mobile; additional ones negligible | first-party |
| `CreateMeshPartAsync` cost | ~**22 ms** + ~**0.27 ms per 1k tris** | **community** (devforum); the only figure available, and reason enough for §5.2 |
| PNG header read | **24 bytes** | first-party standard |
| `LOAD_TIMEOUT_S` (per key) / `PRELOAD_BUDGET_S` (whole boot) | 10 / 15 | ours. A boot must never block on moderation |
| `ASPECT_TOLERANCE` | 0.05 | ours. Beyond it a `Size` write squashes the model (§6.1) |
| `PIVOT_TOLERANCE_STUDS` | 0.25 | ours. Beyond it the model walks beside its hitbox (§6.2) |
| flash `FillTransparency` | 0.5 | **K** — it must read at 100 studs |
| unique textures in v1 | ≤ 12 | ours. Keeps the place's texture memory boring |

### 12.3 Hard requirements, not targets

- **No binary asset file is ever tracked by git** (§15 D4).
- **No raw `rbxassetid` or bare numeric id anywhere in `src/` outside `src/serverstorage/Assets/`**
  (§15 D4).
- **No row with an unresolved licence basis in `Assets.ROWS`** (§4.5, §15 D4).
- **The visible model's size equals the grey box's size** (§6.1), so no physics, hit-zone or grip
  number changes when art lands.
- **`CanQuery = false` on every cosmetic mesh.** A queryable mesh over the zone parts silently turns
  every head shot into a body shot (§6.4).
- **No game script writes `RenderFidelity` or `CollisionFidelity`** (§1.2, D6).

---

## 13. How it is tested

### 13.1 Server spec — `tests/server/assets_manifest.spec.luau` (pure, no world, no network)

1. Every row has every mandatory field; `modelId > 0`; `version >= 1`; `added` parses as a date;
   `kind` and `source` are in their enums.
2. No two rows share `(key, version)`. `byKey` returns the **highest** version and **skips**
   `moderation == "rejected"`.
3. `sourceSha256` is 64 hex characters and unique across rows (the duplicate-upload guard, asserted
   from the committed side too).
4. `fileName` contains no `/`, no `\` and no `:` — **the path-leak check** (`CLAUDE.md`'s history grep
   looks for local paths; this makes it a test instead of a habit).
5. Every row's `trisDeclared` ≤ its `budget().tris` ≤ **20,000**; `texturePx` ≤ `budget().texturePx`.
6. Every key any code names resolves, **or** its owner says it is disabled: for
   `Boar.CONFIG.MODEL.key` and `Shotgun.CONFIG.MODEL.key`, either `Assets.byKey(key) ~= nil` or
   `MODEL.enabled == false`. **Both branches assert something**, so the spec cannot pass by finding
   nothing.
7. `sizeStuds` deep-equals `Boar.CONFIG.BODY_SIZE` for `boar.body` and `Shotgun.CONFIG.HANDLE_SIZE`
   for `shotgun.handle` (§6.1's promise, as an assertion).
8. The manifest is deep-frozen: a write to `Assets.ROWS` **and** to a nested row **raises**
   (`table.freeze` is shallow — `TASKS.md` row 23a(b)).
9. **Licence, the authoritative gate (§4.5):** every row's `licence.basis` is a key of `Assets.BASES`;
   its `mayUpload == true`; `licence.quote`, `licence.quotedFrom` and `licence.readOn` are non-empty;
   and where `BASES[basis].needsAttribution` is true, `licence.attribution` is non-empty.
10. **`ROWS` and `Quarantine` share no key**, and every `Quarantine` row's basis is `"unresolved"` or
    its `moderation` is `"rejected"`.
11. `Assets.BASES` has exactly the `LicenceBasis` values as keys — so adding a basis without a policy
    fails here rather than at publish.
12. `Assets.KEYS`'s values are exactly the distinct keys in `ROWS` (one home for the strings).

### 13.2 Server spec — `tests/server/assets_loader.spec.luau` (fake transport, plus one real branch)

With `Loader.setInsert(fake)`, `Loader.setCreateMeshPart(fake)` and `Loader.setCacheParent(a spec-made
folder)`:

1. `preload` returns one report per key, `ok` where the fake returns a template and `ok == false` with
   the right `reason` where it does not.
2. **A template containing a `ModuleScript` is refused**: `template` returns `nil`,
   `reason == "contains-script"`, `stats().refusedScripts == 1`, and the template is destroyed. (§5.4 —
   this is the one that keeps harness check 5 green forever.)
3. `template` called twice inserts **once** (the fake counts its calls).
4. `template` for an unknown key returns `nil` and does not raise; `stats().proxies` rises.
5. **A key in `Quarantine` returns `nil` with `reason == "quarantined"`** and never reaches the insert
   fake (the fake's call count does not move). This is the run-time half of §4.5.
6. `template` **does not yield**: it is called inside a `coroutine.wrap` and the coroutine is `dead`
   immediately after, not `suspended`. An assertion, not a comment, because §1.2's rule is the one a
   future change breaks silently.
7. Nothing was parented into `Workspace`: the nominated cache folder holds the template and
   `Workspace` has no child of that name.
8. A template whose bounding-box aspect differs from `sizeStuds` by more than `ASPECT_TOLERANCE` fails
   as `aspect`; one inside it passes with `naturalSizeStuds` and `pivotOffsetStuds` reported. A
   `kind == "meshpart"` row whose template has two MeshParts fails as `multi-meshpart`.
9. **Route selection (D5/D6):** with `meshUri = nil` the report's `route == "insert"`. With a
   `meshUri` set and the insert fake returning a template whose `RenderFidelity` differs from the row,
   the report's `route == "createmeshpart"` and the createMeshPart fake was called with
   **the URI string unparsed** and an options table whose keys are a subset of
   `{CollisionFidelity, RenderFidelity, FluidFidelity}`. **And in both cases the Loader wrote neither
   property on the template** — asserted by giving the fake a template with a known `RenderFidelity`
   and checking it is unchanged. This is the spec that stops a Builder re-adding Task 37's dead lines.
10. **The real branch**, `Loader.setInsert(nil)`: if `Assets.byKey("boar.body")` exists, the real
    template loads inside `LOAD_TIMEOUT_S`, contains exactly 1 `MeshPart`, its `MeshId ~= ""`, its
    `RenderFidelity` equals `row.renderFidelity` (**the D6 assertion; `CollisionFidelity` is not
    asserted because a script cannot read it**), and its pivot offset is within
    `PIVOT_TOLERANCE_STUDS` of `row.offsetStuds`. If no row exists, it asserts the proxy path instead
    (`stats().proxies > 0` and the boar still spawned). Branching on committed data, both branches
    non-empty.

### 13.3 Client spec — `tests/client/boar_model.spec.luau` (what the player's machine actually has)

The client cannot read `ServerStorage`, so it asserts **structure**, which catches the whole "purple
untextured legs" class except the colours themselves:

1. For each boar in `Workspace.Boars`: if a child named `Model` exists, it `IsA("MeshPart")`,
   `MeshId ~= ""`, `Transparency < 1`, `CanQuery == false`, `CanCollide == false`, `Massless == true`,
   and `Size` is non-zero on all three axes.
2. **A texture is present**: `TextureID ~= ""` **or** a `SurfaceAppearance` child exists. The machine
   half of "not untextured"; it cannot tell a right texture from a wrong one.
3. When `Model` exists, the trunk and all three zone parts have `Transparency == 1` (§6.4), and the
   trunk still has `CanCollide == true` and the zone parts still `CanQuery == true` — hiding must not
   disarm the hit zones.
4. When `Model` does **not** exist, the trunk's `Transparency == 0` and the grey box is intact. No
   empty branch.
5. **The flash**: when `Model` exists, the trunk has exactly one `Highlight` child; it is created once
   (its identity does not change across a hit) and only `Enabled` moves. Adding or removing one per hit
   is the documented expensive path (§6.5), so identity-stability is the assertion, not a comment.
6. The gun: when the local player holds the Tool, `Handle` is a `MeshPart` with a non-empty `MeshId`
   **or** `Shotgun.CONFIG.MODEL.enabled == false`.
7. **In ADS, the viewmodel keeps its texture**: `Viewmodel.current()`'s `Handle` has the same `MeshId`
   and a non-empty `TextureID` (or a `SurfaceAppearance`) as the source `Handle`. This is the assertion
   that would have caught §6.6's child-sweep bug, and it is why it is in this list.

### 13.4 Screenshots (rule 5) — the half no assertion covers

`python tools/studio_mcp.py capture <name> [camera x,y,z] [look-at x,y,z]` (Task 7, closed 2026-09-25;
works in Edit and during Play). The boar moves, so the Builder reads its position from the spec's own
`TestKit.note` output and computes the camera positions from it. The Builder inspects each image and
**says what it shows** — not that it was taken.

| Name | Camera → look-at | Answers, and only a human can |
|---|---|---|
| `boar-front` | 14 studs ahead, y + 4 → the boar | **is the nose at the front** (§6.3, the backwards knife) |
| `boar-side` | 14 studs to the side | is it a boar-shaped boar, is it the right size against the 400 × 400 plate |
| `boar-rear` / `boar-above` | 14 behind / 12 above | are the sides textured and lit (`TASKS.md` row 18's near-black sides came from these views), is any grey box poking out (§6.4) |
| `boar-flash` | as `boar-side`, during the 0.25 s flash | **does a hit still read** once the animal is textured (§6.5) |
| `gun-third` | over the shoulder, gun in hand | is the gun held the right way round, is the scale sane in the hand |
| `gun-ads` | first person, aiming | **does the viewmodel have its texture** (§6.6), is the muzzle where the muzzle is |
| `prop-edit` | Edit mode, the template in the cache folder | what the import actually produced, before any of our code touched it — including whether the normal map is the right handedness, which no assertion can see |

### 13.5 What the harness cannot do here, stated rather than discovered

- **It cannot upload.** No key in the harness, ever (§8.4). The upload's evidence is
  `tools/assets.py`'s own `[assets] OK:` line, pasted into the review request exactly as the
  `[harness]` line is.
- **It cannot count triangles.** No triangle-count API could be cited, so `trisDeclared` is declared
  and Roblox's importer is the enforcer (§0 item 1).
- **It cannot read `CollisionFidelity`.** The property is closed to scripts at run time, so no spec can
  assert it, ever. §6.4's `CanCollide = false` is what makes that acceptable for the boar and the gun;
  for a tree it is a screenshot and a walk.
- **It cannot tell a pending-moderation asset from a broken one.** A grey or blank model may be
  `MODERATION_STATE_REVIEWING`. The row and `python tools/assets.py check <id>` answer it; **do not
  spend a round debugging it** — that is how the previous project lost rounds to bugs that did not
  exist.
- **It cannot judge whether the boar looks like a boar, or whether the woods look European.** Karen.
- **It cannot check the viewmodel with two players**: `test2`'s replay reaches the shooter's client
  only (`tools/studio_mcp.py` docstring), and `TASKS.md` row 34a item 1 is the open work there.
- **No new input scenario is added.** An asset takes no input; a scenario here would test the harness,
  which rule 6 forbids.
- **`python tools/assets.py selftest`** is the only automated test the Python tool gets; it is offline
  and covers the validator, the request builder, the response parser (including the
  `MODERATION_STATE_` prefix match and the string-`assetId` coercion) and the licence gate. The network
  path is covered by `--dry-run` plus the one real upload a human watches.

### 13.6 The measurements the first tasks must make and write down (rule 8)

Reframed against the research note: **nothing in that note was measured in an engine**, so all of these
are still open, but M2 is now a much smaller question than Task 37 thought.

- **M1. Does Open Cloud accept this FBX as a `Model` from this account?** If not, §7.6's importer
  route, and `tools/assets.py` becomes validate + record. Write down the request that worked, verbatim,
  key redacted.
- **M2 (reframed by D5). Is the derived `meshUri` worth recording?** Not "which route" — the docs
  decided that. Read `MeshId` off the imported MeshPart; check whether the import's `RenderFidelity`
  already matches the row. If it does, route B is never taken and `meshUri` is documentation.
- **M3. Does the colour map survive the FBX import?** Its first half is **answered yes** by D7
  (`TextureID` is run-time assignable). What is open: does the import produce a textured MeshPart, or
  must a PNG go up separately as an `Image` and be assigned? This decides whether `textureId` is used.
- **M4. The cost of one boar mesh**: parts, the place's memory before and after, and the wall time of
  one `preload`. So §12.1's tree budget is checked by multiplication rather than hope.
- **M5 (new, from D9, and it belongs to the first map-props task, not M2.7a). Are free Creator Store
  models in fact flagged *shared by the asset owner*?** The whole Creator Store route turns on it.
  Needs an engine and a real asset id. M2.7a uses only Karen's own uploads and is not blocked by it.

---

## 14. Build order — and the smallest first task

The Director decided on 2026-09-25 (`reviews/task-37/BRIEF.md`): **two tasks, 7a then 7b**;
`tools/assets.py` and the CI steps are **allowed** past the tooling freeze; the research note comes
first (done — Task 39).

**M2.7a — the pipeline, no game code.** Deliverable: an id in the manifest and a spec that loads it.
- `tools/assets.py` (`key`, `init`, `validate`, `upload`, `check`, `resume`, `record`, `licences`,
  `selftest`, `--dry-run`).
- `src/serverstorage/Assets/init.luau`, `Quarantine.luau`, `Loader.luau`.
- `tests/server/assets_manifest.spec.luau`, `tests/server/assets_loader.spec.luau`.
- `.gitignore` `/.assets/`; the two `assets/*/README.md` corrections (§15 D5); the CI additions
  (§15 D4).
- **NEEDS KAREN:** create the key (§8.1), store it (§8.2), drop `boar.body_v1.*`.
- **Buildable and reviewable before Karen's click**: `selftest` and `--dry-run` need no key, and the
  Loader's real branch (§13.2 item 10) asserts the proxy path while no row exists.
- The research note is already written (Task 39) and is the citation of record; code headers cite it
  and this design, per rule 9.

**M2.7b — the boar wears it.** `Boar.CONFIG.MODEL`, `Body.create`'s cosmetic MeshPart (**no fidelity
writes**), the hidden grey box, the `Highlight` flash, `ZONE_TINT = false`, `MatchBoot`'s `preload`,
`tests/client/boar_model.spec.luau`, the boar screenshots, and **Karen looks at it** (feel gate: she
accepted the grey boar, and only she can accept this one).

### Then, one task each

| # | Task | Depends on | Notes |
|---|---|---|---|
| M2.7c | The shotgun mesh: `Shotgun.CONFIG.MODEL`, `Hardware.build`, `WeaponBoot` preload, `gun-third` + `gun-ads` screenshots | 7b | if a `SurfaceAppearance` arrives with the import, the `Viewmodel` sweep fix (§6.6) lands here, in the camera owner's file |
| M2.7d | Trees and props: spruce, birch, oak, high seat; `MapGen.Props` moves onto `Loader`; the map design's measurement D; **and M5** | 7a, **and the map generator's M2.1** | this is where §12.1's tree budget is measured, and where D9's Creator Store question is settled before anything depends on it |
| M2.7e | Boar animation and sound | 7b | own design; nothing here covers either |

---

## 15. Deltas this design imposes on documents that already exist

Named so they are not discovered in review. D1–D3 are **Architect-owned** files and need a
regeneration; D4–D7 are the Builder's.

- **D1. `docs/design/map-generator.md` §2.1, §8.1:** `MapGen.Assets` is **deleted**; the manifest is
  `ServerStorage.Assets` (§2.3). `MapGen.Props` gets its templates from `Assets.Loader` with
  `Loader.setCacheParent(the run folder)` instead of inserting and script-checking for itself.
  Everything that design says about in-run-only caching, proxies and refusing scripted assets stays
  true and now has one implementation.
- **D2. `docs/design/map-generator.md` §8.2 is wrong and this is the one that matters.** It makes
  `InsertService:LoadAsset` the primary route for **Creator Store** assets. Per D9, a free Store model
  is loadable by that route **only if its creator ticked share**, and the documented escape —
  `AssetService.AllowInsertFreeAssets` — is `RobloxScriptSecurity` on read *and* write, so no script
  can take it. The alternatives are: buy the asset, use only shared ones, or insert it in Studio by
  hand and export a `.model.json` (which needs `TASKS.md` row 16). Also §14's task M2.7 ("the Open
  Cloud upload tool") is superseded by §14 here.
- **D3. `docs/design/map-generator.md` §12** carries the same 21,000-triangle and 1024-texture figures
  as Task 37 (see D6 below for the research-note side): 20,000 is the first-party limit and 1024 is our
  budget.
- **D4. `.gitignore` and CI.** `.gitignore` gains `/.assets/` and, as a safety net, `*.fbx`, `*.obj`,
  `*.glb`, `*.gltf`, `*.blend`, `*.psd`, `*.kra`. CI gains four steps in the shape of the existing
  "No binary models in synced paths" step, each `if: success() || failure()` so one run reports every
  problem:
  **(i)** `git ls-files` contains no binary art extension;
  **(ii)** no `rbxassetid` and no bare id outside `src/serverstorage/Assets/`;
  **(iii)** `python tools/assets.py selftest`;
  **(iv)** **the licence gate (§4.5)**: if `src/serverstorage/Assets/init.luau` exists and contains the
  token `unresolved`, fail with *"an asset whose licence basis is unresolved may not be in Assets.ROWS;
  record it in Quarantine.luau"*. The file-exists test matters: the step lands before the file does.
  Allowed past `ROADMAP.md` speed rule 1 by the Director (`reviews/task-37/BRIEF.md`, decision B).
- **D5. `assets/source/README.md` and `assets/ready/README.md`.** `assets/ready/`'s README currently
  says *"record the asset ID next to the file name, for example in `ASSET_IDS.md`"* — a **second home
  for the ids**, which is the exact failure §4.2 exists to prevent, and it invites committing `.fbx`,
  `.png` and `.ogg` into a public repo. `assets/source/`'s says to record licences *"next to the file
  or in a `SOURCES.md`"* — a second home for the licences, now that §4.5 makes the manifest the one
  home. Both must say: **no binary art in this repository**, sources live in `<assets-dir>`, and the one
  home for ids and licences is `src/serverstorage/Assets/init.luau`. The directories stay (rule 7;
  `CLAUDE.md`'s Layout table names them) as text-only pointers.
- **D6. `docs/research/2026-09-24-map-generator.md`** needs a correction note in §8 and §9, as the Task
  39 note itself recommends: the 21,000 triangles and the 1024 texture "limit" (§9), *"a changed mesh is
  a new asset id"* (§9 — half wrong for FBX Models, which update in place as a new version), and §8's
  *"I have not read the primary licence text"* (§11 source 15 read it; record the help-centre JSON
  route so the next session does not lose another page to a 403). **One small Builder docs task, not a
  regeneration.**
- **D7. `GAME_DESIGN.md`:** the four owner rows from §2.1, plus the boar and weapon rows amended for the
  cosmetic mesh and the MeshPart Handle when 7b and 7c land (rule 3: the table mirrors the designs).
- **D8. `CLAUDE.md`** needs one line: `tools/assets.py` exists, it holds the only credential path in the
  repo, the variables are `DRIVEN_HUNT_ROBLOX_API_KEY`, `ASSET_CREATOR_USER_ID` and `ASSET_DROP_DIR`,
  and none of them is ever in CI. The secrets section already covers the rule; this is the pointer.

---

## 16. Open decisions

**None of these blocks building M2.7a.** Each has a working default, in the config, in
`Assets.BASES` or in this document, changeable by one value.

### For Karen (feel, taste and licence — nobody else can answer)

1. **The Meshy plan. Answer it now, not at release.** Free-plan output is **owned by Meshy** and
   licensed **CC BY 4.0**, which is **non-sublicensable**, while publishing to Roblox grants Roblox a
   **sublicensable** licence and warrants she is *"fully authorized to grant rights in all parts"*. And
   uploading through Open Cloud **is** publishing UGC, so the question bites at the first upload, not
   at release. **Recommendation: a paid Meshy plan for anything that ships** — *"customers on a paid
   Meshy plan own their Customer Output"* — which makes the question disappear for the price of a
   subscription. If she stays on free: `Assets.BASES["meshy-free-ccby"].mayShip` is the one boolean to
   flip, attribution per CC BY 4.0 §3(a)(1) (creator identification, copyright notice, licence notice,
   disclaimer notice, a link) must appear where the models do, the suggested wording being *"Model
   created with Meshy – CC BY 4.0 License"*, and the sublicensing question should go to someone
   qualified before monetising. Either way: **never post a Driven Hunt model to the Meshy community
   page** — §3.3 puts it under **CC0**. **Not legal advice.**
2. **The key's clicks** (§8.1–§8.2), including the IP restriction and the expiry. `NEEDS KAREN`, and
   the first task stops at the upload without it. **Two things to report back**, because only her screen
   can settle them: what the **Access Permissions** step offers for an `assets` key on a personal
   account (is there a creator/user choice, or only *"select the game"*?), and whether the key really is
   shown only once.
3. **Which assets are Creator Store and which she makes in Meshy.** **Narrower than Task 37 thought**
   (D9, D16): a free Store model is both *licensed* and *loadable by script* only if its creator ticked
   share — one flag decides both. **Recommendation: Meshy for everything in §12.1, and treat Creator
   Store props as a later, separately-verified route** (measurement M5, on the first map-props task).
4. **Does the boar look right** — size, colour, texture, and whether the flash still reads once it is
   textured (§6.5). Default: the model as delivered, `FillTransparency = 0.5`.
5. **`ZONE_TINT` off when the model lands?** The config comment says yes. Default: `false` in 7b, which
   makes the coloured zone boxes invisible under the mesh. She can turn them back on to see where the
   zones are.
6. **The gun's triangle budget**: 4,000 is generous because it is seen in ADS at arm's length. If it
   reads poorly, that number goes up before anything else does.

### For the Director (scope)

The five Task 37 items are **decided** (`reviews/task-37/BRIEF.md`) and are not reopened: A two tasks;
B `tools/assets.py` and the CI steps allowed; C row 16 stays "before release"; D regenerate the map
design when M2.7d starts; E the research note first — done, Task 39. What is left:

A. **D2 is now a design contradiction, not a note.** `docs/design/map-generator.md` §8.2 says free
   Creator Store models load through `InsertService:LoadAsset`; they do not. **Recommendation: keep the
   regeneration at M2.7d as decided, but dispatch measurement M5 with it, and until then treat "the
   map's small props are Creator Store where they fit" as withdrawn.** Nothing in M2.7a or 7b touches
   it.

B. **The three research-note corrections (§15 D6) are one small Builder docs task**, not a
   regeneration of a 900-line design. Worth queuing before M2.7d so the tree budgets are read off
   corrected numbers.

C. **`Assets.BASES["meshy-free-ccby"].mayShip = false` is a default this design chose, not a decision
   Karen has made.** If she wants to ship free-plan models before answering §16 Karen 1, that is one
   boolean and it is her call, not the Architect's — but the publish gate (§4.5 gate 3) should then be
   recorded as consciously waived in `ESCALATE.md`, not quietly flipped.
