# Research: uploading a prepared asset to Roblox through Open Cloud

Task 73. Written before the code (rule 1). Network was available; every external source below was
fetched on 2026-09-26.

**This note stands on `docs/research/2026-09-26-asset-pipeline.md`**, which already read all fifteen
Open Cloud URLs and recorded seventeen deltas against `docs/design/asset-pipeline.md`. Nothing that
note established is re-derived here. What this note adds is: the request confirmed a second time
against the live page, **what a place actually does with the id afterwards** (the question the design
calls the id→Instance seam), and the decision about where the id is written down.

## What the system must do

Karen gave an explicit upload OK on 2026-09-26 for **one** model: her shotgun as prepared by Task 72
(`<assets-dir>/prepped/shotgun_sxs_r2-20260926T213701Z/`, 19,325 triangles, not decimated). The
Director holds an Open Cloud key in the Windows user environment as `ROBLOX_OPEN_CLOUD_KEY` — scope
`asset` read and write, `authorizedUserId` 8167651842 (Karen), expiring 2026-10-26.

So the tool must: read that key the way `tools/meshy.py` reads `MESHY_API_KEY` (environment, then
`HKCU\Environment`) and **never print, log or commit it**; refuse to upload anything without a
per-asset statement of Karen's OK; send one multipart request; poll the operation; print the asset id
and its moderation state; and write one row of provenance into the repo, where ids — which are not
secrets — belong.

## Sources

### 1. Open Cloud — Assets API guide
<https://create.roblox.com/docs/cloud/guides/usage-assets>
**Licence:** the docs source is CC BY 4.0 (`github.com/Roblox/creator-docs`). **Maintenance:** active.
**Re-confirmed today, quoting the page:** `POST https://apis.roblox.com/assets/v1/assets`; headers
`x-api-key: ${ApiKey}` (or an OAuth bearer token); the multipart parts are exactly **`request`** and
**`fileContent`**; the request JSON is
`{"assetType": "Model", "displayName": …, "description": …, "creationContext": {"creator": {"userId": "${userId}"}}}`;
**Model** accepts *".fbx, .gltf, .glb, .rbxm, .rbxmx"* with content types
*"model/fbx, model/gltf+json, model/gltf-binary, model/x-rbxm"*; **Decal/Image** accepts *".png,
.jpeg, .bmp, .tga"*; the limit is *"up to 20 MB"* per call; and the operation poll returns

```json
{"path": "operations/{operationId}", "done": true,
 "response": {"assetId": "2205400862",
              "moderationResult": {"moderationState": "MODERATION_STATE_APPROVED"}}}
```

**MEASURED AGAINST THE LIVE API, AND THE DOCUMENTED STRING IS NOT WHAT COMES BACK.** The real
upload in this task (asset `117134580332969`) returned
`response.moderationResult.moderationState = "Approved"` — the **short form**, not the
`MODERATION_STATE_APPROVED` the guide prints. So the guide is wrong, or at least stale, about the one
value a caller is most likely to branch on. `docs/research/2026-09-26-asset-pipeline.md`'s delta D13
told this project to *"match on the `MODERATION_STATE_` prefix"*; **that advice would have failed
here**, and this note supersedes it: **record the string, print it, and branch on neither spelling
without checking both.** The tool stores whatever it was given, which is why the real run worked at
all.

**One correction to the repo's own earlier note.** `2026-09-26-asset-pipeline.md` records the
moderation state as a top-level field of `response`; the page shows it **nested under
`moderationResult`**. The tool reads both shapes and says which it found, because a poller that
insists on one spelling reports "unknown" for a perfectly good answer.

**Good:** it is the whole flow, first-party, with no SDK. **Bad:** it publishes no rate limit, and its
"Add Read and Write operation permissions to your selected **game**" wording is written for the
experience-scoped APIs — for an asset upload to a *user* account the creator is set per request by
`creationContext.creator.userId`, which is what this tool does.

### 2. Open Cloud — Manage API keys
<https://create.roblox.com/docs/cloud/auth/api-keys>
**Licence:** CC BY 4.0. **Maintenance:** active.
The two sentences this task is built around: *"Copy and save the API key string to a secure location,
**not a public repository for your code**"* and *"The API key string is equivalent to a password for
your application. Never share it with untrusted parties."* This repo is public, so the key is read
from the environment, is never written to any file the tool produces, never appears in a printed
request, and now has a **shape rule in `tools/privacy_scan.py`** so CI fails if one is ever committed.

### 3. `InsertService` — how a place loads an id at run time
<https://create.roblox.com/docs/reference/engine/classes/InsertService>
**Licence:** CC BY 4.0. **Maintenance:** active.
**What it says:** `LoadAsset` **yields** and returns an `Instance`, and it requires the
**`LoadOwnedAsset`** capability. **Bad:** the page does not spell out the ownership rule in prose, so
"owned" is read from the capability's own name rather than from a sentence. That matters here and the
answer is comfortable: the asset is created with `creationContext.creator.userId = 8167651842`, which
is Karen, who also owns the place — creator and place owner are the same account.

### 4. `AssetService` — the other half of the seam
<https://create.roblox.com/docs/reference/engine/classes/AssetService>
**Licence:** CC BY 4.0. **Maintenance:** active.
**What it says:** `CreateMeshPartAsync(meshContent: Content, options: Dictionary = nil)`, and it
**yields**. **Bad:** the page gives no prose description, no statement about which ids it accepts, and
nothing about `MeshPart.MeshId` at run time — so the run-time settability of `MeshId` is **not
established by a source** and is not assumed anywhere in this task.

## The seam: what a place does with the id

Two routes exist, and the difference is *when*:

- **Edit time, through Rojo.** A `.model.json` can describe a `MeshPart` and set `MeshId` and
  `TextureID`, because both are **strings** and CLAUDE.md's layout rules allow plain JSON values
  (a `Vector3` `Size` still cannot be expressed, which is the harness limitation `TASKS.md` row 16
  tracks). Nothing loads anything at run time; the mesh ships inside the place.
- **Run time, through the one seam.** `InsertService:LoadAsset(id)` returns the uploaded Model — the
  Assets guide's own words for the Model type are *"Imports as Model container with MeshPart
  objects"* — and `AssetService:CreateMeshPartAsync` builds a single MeshPart from mesh content.

**For the gun, it has to be the run-time route**, and not by preference: `Weapon.Hardware` builds the
Tool with `Instance.new` at run time (`docs/design/shotgun.md` §3.1), the uploaded FBX becomes a Model
of MeshParts whose individual mesh ids nobody has, and source 4 does not establish that `MeshId` can
be assigned at run time. `InsertService:LoadAsset` on a creator-owned asset is the route the repo
already uses (`MapGen.Props.template`) and the one `docs/design/asset-pipeline.md` §2.1 names.

**So this task adds no new decision — it mirrors one that already exists.** §2.1 of that design
already names the owner of the manifest, of the quarantine, of the id→Instance seam and of the
uploader. audit-005 must-fix 1's finding was that **`GAME_DESIGN.md` has no row for any of them**, and
its own gate sentence says a system with no row may not be written to. That is what this task closes:
the rows are copied into `GAME_DESIGN.md` from the design, with the state of each recorded honestly —
`ServerStorage.Assets` and `Assets.Loader` are **designed and not yet built** (M2.7a), and until they
are, `docs/design/map-generator.md` §12.2 stands: **`MapGen.Assets` is the only id table in the repo
and no task may add a second one.**

## Where the id is written down

Not in a Luau table, and that is the point. `map-generator.md` §12.2 forbids a second id table before
M2.7a, and the manifest module the design wants (`src/serverstorage/Assets/init.luau`) is that task's
work, not this one's. But an id that exists only in a terminal is an id that is lost, and
`asset-pipeline.md` §2.1 says the manifest row is written by **the Builder, from what the tool
printed**.

So the tool appends to **`assets/uploads.json`** — a plain JSON array in the repo, one object per
upload, carrying the asset id, the moderation state, the operation path, the file and its sha256, the
creator id, the tool version, the UTC time and **the exact text of Karen's OK**. It is provenance,
not a second id table: nothing in `src/` reads it, Rojo does not sync `assets/`, and it holds no
secret. When M2.7a builds the real manifest, these rows are what it is built from.

## The numeric targets and the refusals

| Thing | Value | Where it comes from |
|---|---|---|
| Endpoint | `POST https://apis.roblox.com/assets/v1/assets` | source 1 |
| Poll | `GET https://apis.roblox.com/assets/v1/operations/{id}` | source 1 |
| Max file | 20 MB per call | source 1 |
| Asset type | `Model` for `.fbx` / `.glb` | source 1's table |
| Content type | `model/fbx`, `model/gltf-binary` | source 1's table |
| Creator | `userId` 8167651842 (Karen) | the Director's introspect call |
| Poll budget | 2 s between polls, 180 s total | ours — source 1 publishes no rate limit, so it is a conservative guess and is labelled one |

**What the tool refuses, before any byte leaves the process:** no key; **no `--karen-ok`**; a
`--karen-ok` that does not carry both a date and words (so "yes" cannot stand in for a record); a file
over 20 MB; a file whose extension is not one source 1 lists for `Model`; and a file whose sha256 is
already in `assets/uploads.json` (the same bytes twice is an accident, and `--again` is how a
deliberate re-upload says so). Karen's OK is **per asset**: it is recorded verbatim in the row, so
what she approved is answerable later from git rather than from memory.

## What this note does not answer

- **Which moderation strings exist besides `"Approved"`** is unknown: one upload returned one value.
  Whether a rejected or pending asset says `"Rejected"` / `"Reviewing"` or the long form is
  unmeasured, and the tool deliberately does not branch on it.
- **Whether the uploaded model looks right in Studio** is the next task's question, with the harness
  and screenshots. Nothing is swapped into the game here.
- **`MeshPart.MeshId` at run time** is unestablished (source 4) and nothing depends on it.
- **The rate limit** is unpublished; the poll budget above is ours and stated as such.
