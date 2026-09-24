# Map generator — research note

Rule 1. Written before any generator code. System: `ROADMAP.md` Milestone 2, TASKS.md Task 20.
Date: 2026-09-24. **This task is research only — no code, no design.**

**Scale.** 1 stud = 28 cm, stated outright by Roblox's own units page (source 1), so 1 m = 3.57 studs
and 100 m = 357 studs. Every distance below is derived from that and nothing else.

## What the system must do

Karen's decision (**map option C**, recorded in `TASKS.md` row 16): the map is **built by a generator,
code on disk, run in Edit mode through the Studio MCP server**, verified with **Edit-mode
screenshots** and by **Karen walking it**. Assets come from the **Creator Store first**, and from
**Meshy** (Karen makes the models) where nothing fits.

One small v1 map: **European farmland and woods** — fields, hedgerows, spruce and birch stands,
tracks, a bog — with a **drive area** and a **shooter line along a wood edge**.

Three consequences that shape everything below:

1. **The generator runs at edit time, not at run time.** The map is baked into the place and saved,
   not rebuilt when a server starts. So generation may be slow; what must be fast is the *result*.
2. **The map carries no scripts** (CLAUDE.md: nothing script-like is ever created in Studio, and
   Workspace is not Rojo-mapped). Gameplay code has to find its own landmarks — hence tags, §4.
3. **Generation is destructive and hard to undo.** A rebuild replaces terrain and props wholesale.
   That makes the backup step (§10) part of the system, not a nicety.

## Sources

### 1. Roblox units — the scale everything rests on
- <https://create.roblox.com/docs/physics/units>
- Licence: first-party documentation (creator-docs is CC BY 4.0). Maintenance: actively maintained.
- **Good:** states **1 stud = 28 cm** and 1 RMU = 21.952 kg, so every real-world dimension below
  converts without guesswork.
- **Bad:** it is a convention, not enforced by the engine. It has to be obeyed deliberately, and a
  map built at the wrong scale is the most expensive mistake available here — it invalidates the
  boar's speeds and the shotgun's ranges at once.

### 2. `Terrain` — the voxel API the generator writes through
- <https://create.roblox.com/docs/reference/engine/classes/Terrain>
- Licence: first-party. Maintenance: actively maintained; ships with the engine.
- **Good:** confirmed signatures, all callable from a script —
  `Terrain:FillBlock(cframe: CFrame, size: Vector3, material: Enum.Material)`,
  `Terrain:FillRegion(region: Region3, resolution: number, material: Enum.Material)`,
  `Terrain:FillBall(center, radius, material)`, `FillCylinder(cframe, height, radius, material)`,
  `FillWedge(cframe, size, material)`,
  `Terrain:ReadVoxels(region: Region3, resolution: number)`,
  `Terrain:WriteVoxels(region: Region3, resolution: number, materials, occupancy)`,
  `Terrain:ReplaceMaterial(region, resolution, sourceMaterial, targetMaterial)`, `Terrain:Clear()`
  and `Terrain:SetMaterialColor(material, value)`. **`WriteVoxels` is the one that matters**: it
  takes a materials grid *and an occupancy grid*, which is what makes smooth, non-blocky ground
  possible from a heightfield. `Clear()` gives the generator a clean slate, and it is also the reason
  §10 exists.
- **Bad:** the reference page shows `resolution` as `4` in its examples but **does not state that 4
  is the only supported value**, nor any size cap on a `ReadVoxels`/`WriteVoxels` region. Both are
  things the first generator task must **measure and write down**, not assume. Terrain is also a
  single global object with no notion of ownership, so exactly one thing may write it.

### 3. Studio's heightmap/colormap import — **cannot be driven from code or MCP**
- <https://create.roblox.com/docs/studio/terrain-editor>
- Licence: first-party. Maintenance: actively maintained.
- **Good:** the Terrain Editor's **Import** tool "imports a heightmap and optional colormap and
  applies them to a selected region", and its **Generate** tool procedurally creates terrain from
  biomes, blending, caves, biome size and a **seed**.
- **Bad, and this is the decisive finding for this task:** both are **Studio UI plugin features**.
  The documentation contains **no scripting API for importing a heightmap or colormap**, and the
  Studio MCP server exposes no tool for them either (its tool list is `execute_luau`,
  `insert_asset`, `search_asset`, `screen_capture`, `generate_*`, `run/stop play`, input, console —
  nothing that drives the Terrain Editor). Community threads asking to automate multi-heightmap
  imports find no API answer.
  **So: heightmap import is not available to this project's generator.** It would be a manual Karen
  click, with a PNG that lives outside the repo and cannot be reviewed as a diff — which is exactly
  what map option C was chosen to avoid. **The generator therefore computes its own heightfield in
  Luau and writes it with `WriteVoxels`.** The Generate tool is likewise off the table: its seed and
  biomes are UI state, not a file.

### 4. `CollectionService` — how code finds gameplay markers in a script-free map
- <https://create.roblox.com/docs/reference/engine/classes/CollectionService>
- Licence: first-party. Maintenance: actively maintained.
- **Good:** `AddTag(instance, tag)`, `RemoveTag`, `HasTag`, `GetTagged(tag)`, `GetTags(instance)`,
  and `GetInstanceAddedSignal(tag)` / `GetInstanceRemovedSignal(tag)` for reacting as instances
  appear. This is the standard Roblox answer to "the map must carry no scripts": the generator tags
  an empty `Part` or `Attachment` `DriveStart`, `ShooterPost`, `BoarSpawn`, `DriveLine`, and server
  code does `CollectionService:GetTagged("ShooterPost")`. No script in Workspace, no hard-coded
  coordinates in game code, and the map and the rules stay independently replaceable.
- **Bad:** the reference page **does not say whether tags are serialised into the place file**, nor
  give any limit on tag name or count. Tags do persist in practice — the Studio Tag Editor exists for
  exactly that — but **this note is not going to assert it from memory**: the first generator task
  must save, reopen and confirm, because if tags did not survive the save the whole marker scheme
  fails silently. `GetInstanceAddedSignal` also matters with streaming (§5): a tagged part can stream
  out and back in, so code must react to the signal rather than snapshot `GetTagged` once at start.

### 5. Instance streaming — the budget the map is built against
- <https://create.roblox.com/docs/workspace/streaming>
- Licence: first-party. Maintenance: actively maintained.
- **Good:** gives the actual defaults and the recommendation to keep them. `StreamingMinRadius`
  default **64** — "use the default of 64 to maximize how much the engine can scale the game down for
  low-end devices". `StreamingTargetRadius` default **1024** — "a good balance between visibility for
  players on high-end devices and a reasonable memory footprint". `StreamingIntegrityMode`:
  "use `PauseOutsideLoadedArea` to balance gameplay integrity". `ModelStreamingBehavior`: `Improved`.
  Per-model `StreamingMode` — `Nonatomic` (default), `Atomic`, `Persistent`, `PersistentPerPlayer` —
  is how the shooter-line markers stay loaded for everyone while a spruce stand 1,200 studs away does
  not.
- **Bad:** the page warns that "local-only changes to instance properties … can be lost if the
  instance streams out and later streams back in", which is a live trap for anything the client
  decorates. And streaming is not free insurance: the DevForum has standing reports of clients,
  **especially mobile**, running out of memory as content streams *in* faster than it streams out.

### 6. Community part-count and mobile guidance — the numbers Roblox does not publish
- <https://devforum.roblox.com/t/do-part-counts-really-matter-with-streamingenabled/759617> ·
  <https://devforum.roblox.com/t/streamingenabled-maximum-distance-or-part-count/504827>
- Licence: forum posts, cited as figures only. Maintenance: community threads, not a living spec.
- **Good:** the only concrete figures available — keep **visible** parts under ~**50,000** for smooth
  performance on most devices, and **mobile struggles past ~20,000 visible parts**. That is where
  the part budgets in **"Numeric targets"** below come from.
- **Bad:** these are rules of thumb from developers, not measurements of *this* map on *this* device
  set. They are a starting budget to be replaced by measurement, not a specification.

### 7. RTerrainGenerator — the closest open-source Roblox terrain generator
- <https://github.com/TheArturZh/RTerrainGenerator>
- Licence: **MIT** — explicitly permits a closed-source derivative. Maintenance: **~45 commits, no
  visible recent activity and no archive notice**; I could not establish a last-commit date, so treat
  it as *unmaintained until proven otherwise*.
- **Good:** it is exactly the technique this note adopts, already written down — "exponentially
  distributed Perlin noise with **domain warping** to generate a heightmap" — and it generates
  rivers, lakes and forests, not just ground. Domain warping is the trick that stops noise terrain
  looking like noise, and it is worth reading before writing our own.
- **Bad, and why it is not adopted wholesale:** it **does not use Roblox Terrain** — it builds its
  own geometry — which is the opposite of what we want (we want voxel terrain we can paint with
  materials and that the engine streams and collides efficiently). Its forests and rivers assume its
  own world model. So: **read it for the heightfield technique, take no code.** Vendoring an
  unmaintained generator to then fight its world model is the "invented foundations" failure in
  reverse.

### 8. Creator Store — where the props come from, and what the licence actually covers
- <https://create.roblox.com/docs/production/creator-store> · Terms:
  <https://en.help.roblox.com/hc/en-us/articles/21308223046932-Creator-Store-Terms>
- Licence: **this is the thing I could NOT fully confirm.** The docs page states that purchasing a
  Creator Store asset grants "a license to use the asset in Roblox Studio and in Experiences on the
  Services consistent with the Roblox User and Creator Terms", and that a creator may "distribute and
  make freely available any Model, Plugin, MeshPart, Decal, or audio asset that **you have created
  and uploaded**", excluding composites with restricted dependencies. The Terms page itself returned
  **HTTP 403** to me, so **I have not read the primary licence text**. Maintenance: actively
  maintained by Roblox.
- **Good:** most Creator Store assets are free, and the licence is scoped to *use on Roblox*, which
  is all this project does.
- **Bad, and it is a real risk for a public repo:** the licence is **use-on-Roblox**, not a
  redistributable open-source grant. Two rules follow, and they are not optional:
  1. **Never commit a Creator Store asset to this repository.** Not as `.rbxm` (already banned), not
     as a mesh or texture file. The repo stores the **asset id** and the generator inserts it.
  2. **Record provenance.** Every asset id used gets a row in an asset manifest on disk — id, name,
     creator, where it came from, date — so a later licence question is answerable. A free model
     whose creator uploaded someone else's work is a live hazard, and asset ids get moderated and
     deleted, which will break a map that names them.

### 9. Meshy → Roblox, and the Open Cloud Assets API
- Roblox mesh limits (DevForum and vendor summaries, cited as figures):
  <https://devforum.roblox.com/t/whats-roblox-current-mesh-triangle-limit/2414597> ·
  <https://meshlox.com/learn/roblox-mesh-size-limits>
- Open Cloud Assets API: <https://create.roblox.com/docs/cloud/open-cloud/usage-assets>
- `AssetService`: <https://create.roblox.com/docs/reference/engine/classes/AssetService>
- Licence: first-party docs for the APIs; the mesh-limit figures are community/vendor pages.
  Maintenance: the APIs are current; the limit pages are recent but secondary.
- **Good:** the limits are knowable up front. A **MeshPart caps at 21,000 triangles** (UGC
  accessories at 10,000), and **no single texture map may exceed 1024 × 1024** — diffuse, normal,
  roughness and metallic alike. An import over the limit **fails at import with an error** rather
  than degrading quietly, which is the good kind of failure. Upload can be automated: Open Cloud's
  Assets API takes `POST https://apis.roblox.com/assets/v1/assets` with the key in an **`x-api-key`
  header**, with an API key scoped to **assets / read and write**; `AssetService.CreateAssetAsync`
  and `CreateMeshPartAsync` exist in-engine and require the `AssetCreateUpdate` capability.
- **Bad:** the Open Cloud page gives the header but **says nothing about keeping the key secret** —
  that discipline is ours, and this repo is public. The key lives in an **environment variable**,
  never in a file, never in a commit; CLAUDE.md's secrets section already covers it and the upload
  tool must read `os.environ` and fail loudly if it is unset. Also note the docs list meshes as
  "not available for updating": a changed mesh is a **new asset id**, so the manifest in §8 must be
  versioned, not overwritten.

### 10. Place files and "Save to File" — the backup step
- <https://create.roblox.com/docs/projects/place-files>
- Licence: first-party. Maintenance: actively maintained.
- **Good:** **File → Save to File** writes the whole place to a local `.rbxl`, and that is the only
  rollback that exists for Workspace content, because **Workspace is not Rojo-mapped** — a bad
  generator run destroys terrain and props with no git history behind them. Studio also keeps
  automatic recovery files (Windows:
  `C:\Users\<user>\AppData\Local\Roblox\RobloxStudio\AutoSaves`), but those are a crash safety net,
  not a backup policy.
- **Bad:** it is a **menu click no tool can make**, so it is a `NEEDS KAREN` step before every
  rebuild. And the `.rbxl` must be saved **outside the repository** — it is a large binary, `.rbxm`
  and `.rbxmx` are already banned here for being unreviewable, and a place file is worse.
  `backups/README.md` gets a note pointing at wherever Karen keeps them; the files themselves never
  come near git.

### 11. `math.noise` — the noise function the heightfield is made of
- <https://create.roblox.com/docs/reference/engine/libraries/math>
- Licence: first-party documentation (creator-docs is CC BY 4.0); the function ships with the engine.
  Maintenance: actively maintained.
- **Good:** Roblox ships a Perlin noise function in the standard library, so the generator needs no
  noise dependency at all. Confirmed signature: `math.noise(x: number, y: number, z: number): number`.
- **Bad, and it is why §12 below is written the way it is:** the reference page gives **the signature
  and nothing else** — no algorithm, no output range, no statement that it is deterministic across
  sessions or engine versions, and **no seed parameter**. Every one of those matters to a generator
  whose whole promise is reproducibility, and none of them can be cited. The first generator task
  measures them.

## Numeric targets

Derived at 1 stud = 0.28 m. These are **targets to be measured against**, not measurements.

| Quantity | Target | Basis |
|---|---|---|
| **Map size, v1** | **2048 × 2048 studs** = **573 × 573 m** | Big enough for a real drive: a European driven hunt pushes game a few hundred metres. Small enough that one person can build and walk it, and that it is ~2× `StreamingTargetRadius` so streaming is actually exercised rather than loading everything |
| **Drive length** | ~**1400 studs** (390 m) from the drive start to the shooter line | Leaves ~300 studs of margin at each end. Feel number: Karen decides after walking it |
| **Shooter line** | ~**600 studs** (170 m) along a wood edge, posts every ~**60 studs** (17 m) | 60 m between neighbouring guns is the conventional safe spacing; 17 m is far tighter and is a **game** number, chosen so 8 shooters fit a walkable line. Feel number |
| **Terrain voxel resolution** | **4 studs** | The value the `Terrain` docs use throughout. **Whether any other value is accepted is unverified** (§2) |
| **Heightfield grid** | 512 × 512 samples at 4 studs | 2048 / 4. ~262k samples; the generator is edit-time, so cost is acceptable, but `WriteVoxels` region limits are **unverified** and the generator will probably have to write in tiles |
| **Total parts/meshes in the place** | **≤ 20,000** | Community guidance is <50,000 visible for desktop and ~20,000 for mobile (source 6). With streaming at 1024 studs a player sees a fraction of the map, so 20,000 total is a deliberately conservative ceiling for a v1 that must run on a phone |
| **Visible parts at any moment** | **≤ 8,000** | Well inside the mobile figure, leaving headroom for 16 players' characters, a shotgun each and the boar |
| **Trees** | ~**3,000** across all stands, 1 MeshPart each | Inside the part budget with room to spare. Spruce and birch: 2 species × 3 variants is enough visual variety at hunting distances |
| **Mesh budget per prop** | **≤ 21,000 triangles**, textures **≤ 1024 × 1024** | Roblox's hard import limits (§9). Trees should be **far** under: a background conifer wants hundreds of triangles, not thousands, at 3,000 instances |
| **Client memory** | **≤ 1.5 GB** on a mid phone | A target, not a measurement. Mobile clients crash on memory with streaming (§5), so this is the number to watch first |
| **Join-to-playable** | **≤ 15 s** on a mid phone | A target. Streaming means the whole map need not load, so this should be achievable; it must be measured |
| **Generator run time** | no limit | It runs at edit time through MCP. Slow is fine; correct and repeatable is not optional |

**Every one of these is unverified.** Nothing in this project has yet run on a phone, and the map does
not exist. They are the numbers the first generator task measures against and then corrects.

## Pattern adopted, and why

**A seeded, deterministic Luau generator that writes voxel terrain and tagged props at edit time,
driven through the Studio MCP server, with assets referenced by id and never committed.**

1. **Heightfield in Luau, not an imported PNG.** Forced by §3: heightmap import is Studio-UI-only and
   unreachable from code or MCP. The generator computes a heightfield from `math.noise` — Roblox's
   built-in Perlin (§11) — with **domain warping**, the technique RTerrainGenerator documents (§7),
   and writes it with `Terrain:WriteVoxels`, which takes occupancy as well as material and so gives
   smooth ground rather than steps.
2. **Seeded and deterministic — and here is how the seed actually reaches the terrain**, because
   `math.noise` has **no seed parameter** (§11). Two distinct mechanisms, and conflating them is a
   mistake this note made in its first draft:
   - **Terrain shape:** the seed is turned into a large **coordinate offset** into the noise field,
     `math.noise((x + offsetX) * frequency, (z + offsetZ) * frequency)`. Different seeds sample
     different parts of the same fixed field, which is the standard way to "seed" an unseedable
     noise function. The field itself is whatever the engine implements, identical for every seed.
   - **Everything discrete** — which trees, where props sit, hedgerow gaps — comes from
     `Random.new(seed)`, which *is* seedable and documented.

   So one `seed` number in a config table reproduces the map exactly **provided `math.noise` is
   stable across sessions and engine versions, which the documentation does not promise** (§11).
   That is the single biggest unproven assumption in this note, and it is the first thing the first
   generator task measures: generate twice from the same seed and compare. If `math.noise` turns out
   not to be stable, the fallback is a small seeded noise implementation on disk — more code, but
   then reproducibility is ours rather than borrowed.

   Reproducibility is what makes a generated map reviewable as a diff: the repo holds the seed and
   the rules, not the geometry. It is also what makes a regression visible — the same seed must give
   the same map.
3. **Layers, each independent and re-runnable:** ground height → materials (field, track, bog) →
   hedgerows → tree stands → props → **markers**. Each layer is a pure function of the seed and the
   layers before it, so one can be re-run without rebuilding the world.
4. **Markers are tags, not scripts** (§4). The generator places empty parts tagged `BoarSpawn`,
   `DriveStart`, `ShooterPost`, `DriveLine`; gameplay code finds them with
   `CollectionService:GetTagged` and reacts with `GetInstanceAddedSignal` so streaming cannot break
   it. **This is the seam between the map and the game**: it means the Milestone 1 grey-box arena and
   the Milestone 2 map are interchangeable to the boar and the shotgun.
5. **Assets by id, with a manifest** (§8). No Creator Store or Meshy binary ever enters this
   repository. The generator holds ids; a manifest on disk records id, name, creator, source and date
   so licence and moderation questions stay answerable.
6. **Backup before every rebuild** (§10): Karen's **File → Save to File** to a dated `.rbxl` outside
   the repo. It is a `NEEDS KAREN` click and it belongs in the task's checklist, not in someone's
   memory.

**Nothing here is invented** (rule 2). Noise heightfields with domain warping, voxel terrain writes,
tag-based markers, id-referenced assets and seeded generation are all standard. The only
project-specific thing is the *layer order* and the tag vocabulary, which is a naming decision, not a
technique.

**Not adopted, with reasons:** the Terrain Editor's Import and Generate tools (§3 — unreachable from
code, and their state is not a file); RTerrainGenerator's code (§7 — MIT and readable, but it does
not use Roblox Terrain and appears unmaintained); heightmap PNGs as the source of truth (they cannot
be reviewed as a diff, which is the whole point of option C).

## The smallest first generator task

Not "the map". One vertical slice that proves every risky link, and nothing else:

> **Generate a 512 × 512 stud test patch through MCP: a noise heightfield written as voxel terrain in
> two materials (grass field, dirt track), one hedgerow line, 50 trees from one Creator Store asset
> id, and four tagged markers (`BoarSpawn`, `DriveStart`, `ShooterPost`, `DriveLine`). Then save,
> reopen, and confirm the tags and the terrain survived.**

It is small, and it answers every question this note could not:

- does `WriteVoxels` accept the region size we want, and is `resolution` 4 the only value? (§2)
- what does `math.noise` actually return, and **is it stable across runs and engine versions**?
  (§11, and pattern point 2 — this is the assumption the whole seed story rests on)
- **do `CollectionService` tags survive a save and reopen?** (§4 — if not, the marker scheme dies
  and this is the cheapest possible place to find out)
- does an Edit-mode `screen_capture` through MCP give evidence good enough for rule 5? (Task 7 is
  unsolved for *play-time* screenshots, but this generator runs in **Edit** mode, where
  `screen_capture` does work — so Milestone 2 may be the first visual work in this project that can
  meet rule 5 without Karen)
- how many parts and how much memory do 50 trees actually cost (§6's budgets), so the 3,000-tree
  figure can be checked by multiplication rather than hope?

Everything else — the bog, spruce/birch variety, the full 2048-stud map, Meshy uploads, Open Cloud —
waits until that slice is on screen and Karen has walked it.

## What needs Karen

1. **Taste, and only she can judge it:** does the farmland read as *European* farmland? Field sizes,
   hedgerow density, how dark the spruce stands are, whether the bog is a feature or an annoyance.
2. **Assets:** which Creator Store trees, fences and rocks she accepts, and which ones she would
   rather make in Meshy. The generator cannot start on real props until there are ids.
3. **The backup click** before every rebuild (§10), and the Rojo **Connect** click that is already
   outstanding.
4. **The shooter line's feel:** 600 studs with posts every 60 is a guess. She will know in one walk
   whether it reads as a hunting line or a firing range.
