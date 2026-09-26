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
  Studio MCP server exposes no tool for them either — see **§12** for where that tool list comes
  from and how far it can be trusted, and for the community threads that ask for exactly this
  automation and get no API answer.
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
- **Good:** the limits appear knowable up front. A **MeshPart is reported to cap at 21,000
  triangles** (UGC accessories at 10,000), with **no single texture map above 1024 × 1024** —
  diffuse, normal, roughness and metallic alike — and an import over the limit is reported to
  **fail at import with an error** rather than degrade quietly, which would be the good kind of
  failure.
- **Bad, and it must be said where the numbers are used:** every one of those figures is from a
  **DevForum thread or a vendor page**, not from Roblox documentation. I did not find a first-party
  page stating them. They are the best available and they are probably right, but they are the same
  class of evidence as the part counts in §6 and the numbers table labels them so. Upload can be automated: Open Cloud's
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
- **Bad, and it is why "The smallest first generator task" below is written the way it is:** the
  reference page gives **the signature and nothing else** — no algorithm, no output range, no statement that it is deterministic across
  sessions or engine versions, and **no seed parameter**. Every one of those matters to a generator
  whose whole promise is reproducibility, and none of them can be cited. The first generator task
  measures them.

### 12. The Studio MCP tool list, and the community asking for scripted heightmap import
- **The tool list is a first-hand observation, not a document.** On 2026-09-24, during Task 17, I
  called `tools/list` on the running StudioMCP server through the harness's own MCP client and it
  returned: `character_navigation`, `execute_luau`, `generate_material`, `generate_mesh`,
  `generate_procedural_model`, `generate_texture`, `get_console_output`, `get_studio_state`,
  `http_get`, `insert_asset`, `inspect_instance`, `list_roblox_studios`, `multi_edit`,
  `screen_capture`, `script_grep`, `script_read`, `script_search`, `search_asset`, `segment_mesh`,
  `skill`, `start_stop_play`, `store_image`, `subagent`, `upload_image`, `user_keyboard_input`,
  `user_mouse_input`, `wait_job_finished`. **That is the whole list, enumerated, not sampled** — which
  is what lets the absence of a Terrain-Editor tool be stated as an absence rather than a guess.
- Licence / maintenance: **not applicable — it is not a published source.** StudioMCP ships with
  Roblox Studio, which auto-updates and is **not pinned** (CLAUDE.md's toolchain table), so the list
  can change under us without notice. **It is also not reproducible from this repository**: the
  in-repo record is partial — `docs/research/2026-09-24-toolchain.md` names only
  `start_stop_play`, `get_console_output`, `execute_luau` and `screen_capture`, and
  `tools/studio_mcp.py` deliberately wraps only the first three, because the harness is built to be
  read-only by construction. Anyone re-checking this must call `tools/list` themselves.
- **Good:** it settles the question the Director asked to be answered plainly. **Bad:** it is a
  point-in-time observation of an unpinned dependency, and the first generator task should re-check
  it rather than trust this line.

### 13. Community requests for scripted heightmap import — the corroboration
- <https://devforum.roblox.com/t/is-there-any-way-to-import-terrain-from-multiple-heightmaps-automatically/2184196>
  · <https://devforum.roblox.com/t/terrain-heightmap-import/58469>
  · <https://devforum.roblox.com/t/smooth-terrain-heightmapcolormap-importer-release/295883>
- Licence: forum posts, cited as corroboration only. Maintenance: community threads, not a spec.
- **Good:** developers asking precisely "can I import many heightmaps automatically?" get no API
  answer — only UI workflows and third-party plugins. That is weak evidence on its own but it agrees
  with §3 and §12, and three independent kinds of evidence pointing the same way is why the note
  states the conclusion without hedging.
- **Bad:** absence of an answer on a forum is not proof an API does not exist. The load-bearing
  evidence is §3 (the documentation) and §12 (the enumerated tool list); this is corroboration.

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
| **Mesh budget per prop** | **≤ 21,000 triangles**, textures **≤ 1024 × 1024** | **Community/vendor figures, not first-party** (§9): the DevForum and a vendor page give these as the import limits, and I found no Roblox documentation page stating them. Treat them as a ceiling to confirm at the first import, not as a specification. Trees should be **far** under either way: a background conifer wants hundreds of triangles, not thousands, at 3,000 instances |
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

## Measurements, Milestone 2.1 (Task 43, 2026-09-26)

The four the design asks for (`docs/design/map-generator.md` section 13.5), plus two the build forced.
Every number here was produced by a probe in this repo's Edit session, Studio **0.740.19.7400931**,
and every one of them is a fact about *that* Studio, not a promise about the next one.

### A. `Terrain:WriteVoxels` — the region limit and the resolution

    grid=32x24x32 voxels=24576
    writeVoxels_128x96x128_res4 = true
    readVoxels_res4 = true
    writeVoxels_res8 = false   -- "Resolution has to be 4"
    writeVoxels_res2 = false   -- "Resolution has to be 4"

So a 128 x 128-stud tile through a 96-stud vertical band is accepted in one call, and **resolution 4
is not a preference, it is the only value the API takes**. The design's tile row is correct and its
"unverified" on the resolution is closed. `Config.VOXEL = 4` carries this measurement as a comment.

The whole 512-stud slice is 16 such tiles, and all 16 wrote 24,576 voxels each with no failure and no
chunking trouble. One of the sixteen lines, verbatim:

    [mapgen] OK  step 2/22 · terrain tile 1/16 (x=-256..-128, z=-256..-128) · voxelsWritten=24576 · 6 ms

### B. Do tags survive a save and a reopen? — **NOT MEASURED**

It needs a File → Save to File and a reopen of the place, which are two clicks no tool in this repo
can make (the StudioMCP tool list has no save; `docs/research/2026-09-24-map-generator.md` section 12).
The slice is built and tagged in the place right now, so the measurement is one save and one reopen
away, and `python tools/mapgen.py contract` is the command that answers it afterwards: it counts the
five tags inside `Workspace.DrivenHuntMap` and prints them.

**If tags do not survive**, the fallback is already named (design section 13.5 B): markers found by
folder and name under `Workspace.DrivenHuntMap.Markers`, and the only module in the repo that changes
is `Match.Markers`. Tags and attributes are never shipped both — two representations of one fact is
this project's named failure mode.

### C. Can `execute_luau` write in Edit mode? — **YES**

    WRITE: true|41      -- created a Folder in Workspace and read its name back
    CLEANED: true       -- and destroyed it again

Measured before any generator code was written, because the design says a No here changes the whole
invocation route and is an `ESCALATE.md` entry rather than a workaround. It is a Yes: every step of
the 22-step build writes through `execute_luau`, including 393,216 voxels of terrain and 153 parts.

### D. What 50 trees cost

    parts:   153 under Workspace.DrivenHuntMap  (50 trees x 2 parts, 39 hedge segments, 14 markers)
    Stats:GetMemoryUsageMbForTag(Instances):  92.31 built -> 92.33 cleared -> 92.37 rebuilt
    Stats:GetTotalMemoryUsageMb():          1582.65 built -> 1586.89 cleared -> 1597.14 rebuilt

**The memory half of this measurement failed honestly, and saying so is the measurement.** Studio's
own totals drifted upward across the three samples regardless of what was in the place — the "cleared"
reading is higher than the "built" one — so an Edit session cannot resolve 100 parts against its own
noise. What survives is the part count, which is exact: **two parts per tree**. The design's 3,000-tree
budget is therefore 6,000 parts, well inside `Map.BUDGET.parts = 20000`, and the budget stands on
multiplication. The memory question needs a Play session with 3,000 real meshes in it, which is M2.3's
business and not answerable with proxies.

### E. Studio's require cache survives between `execute_luau` calls — and Rojo does not clear it

Not in the design's list; the build found it. `build` reported "46 of 50 trees" twice from a
`Config.luau` that already said otherwise: Rojo had replaced the ModuleScript's `Source` in Studio (the
harness's own byte-for-byte comparison passed), but the **already-required module kept its old return
value**. A generator that builds from code the file no longer holds is exactly what refusals 2 and 3
exist to prevent, so it is now prevented three ways:

* `tools/mapgen.py` requires a **parentless clone** of `ServerStorage.MapGen` on every call. A clone
  loads the current source, and leaves nothing in the DataModel for the harness's "no unmanaged
  script" check to trip over. Measured: `parentless=true/6` — the clone saw the new value, the
  cached module still said 3.
* `MapGen.Contract` does the same for `ReplicatedStorage.Map`, which `Config`, `Markers` and `init`
  reach by absolute path where a clone of the generator cannot help. At run time it is exactly
  `require(ReplicatedStorage.Map)`.
* `mapgen.py` prints a note when the session's own cached contract is older than the file, because
  only reopening the place fixes that, and no tool can do it.

### F. Four of the five streaming properties are not reachable from Luau

    StreamingEnabled=true ; StreamingMinRadius=MISSING ; StreamingTargetRadius=MISSING
    StreamingIntegrityMode=MISSING ; ModelStreamingBehavior=MISSING ; StreamOutBehavior=MISSING

Each of the four raises "not a valid member of Workspace". They are Studio-panel place settings, so
**M2.6 is a Karen click plus a playtest, not a line of code**, and `MapGen.Settings` writes the one
property it can and reports the four it cannot.

And the first half of that line is the bigger fact: **`Workspace.StreamingEnabled` is already `true`
in the DEV place** — the engine's default for a new place — so every Milestone 1 system has always run
with streaming on. The design assumed it was off until M2.6. `Map.STREAMING.enabled` now says `true`,
because the contract must say what the place is; turning it off would change client behaviour for
every existing system, which is M2.6's task with a playtest and not M2.1's.

### The reproducibility question, answered for one session

`python tools/mapgen.py verify --seed 7` built the slice, digested it, cleared it, built it again and
digested it again:

    [mapgen] build 1: digest=87abf2678bfa13bdbe3e936fb34c1d0582b1109f8aef56492de14bff476add99 parts=153
    [mapgen] build 2: digest=87abf2678bfa13bdbe3e936fb34c1d0582b1109f8aef56492de14bff476add99 parts=153
    [mapgen] OK: same seed twice, same digest @ afb983a8208edbaff329625bd4f6f845f28ec16d seed=7 digest=87abf2678bfa13bdbe3e936fb34c1d0582b1109f8aef56492de14bff476add99 (clean tree)

The digest covers 153 instances with their positions, sizes and tags **and 4,096 terrain occupancy
samples**, so this says `math.noise` is stable within a session and the whole pipeline is
deterministic. **Across engine versions it is still unverified** — that needs a Studio update to
happen, and the named fallback (a seeded value-noise implementation inside `Height.luau`) is unchanged.

## What needs Karen

1. **Taste, and only she can judge it:** does the farmland read as *European* farmland? Field sizes,
   hedgerow density, how dark the spruce stands are, whether the bog is a feature or an annoyance.
2. **Assets:** which Creator Store trees, fences and rocks she accepts, and which ones she would
   rather make in Meshy. The generator cannot start on real props until there are ids.
3. **The backup click** before every rebuild (§10), and the Rojo **Connect** click that is already
   outstanding.
4. **The shooter line's feel:** 600 studs with posts every 60 is a guess. She will know in one walk
   whether it reads as a hunting line or a firing range.
