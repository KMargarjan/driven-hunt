# Asset pipeline — research note

Rule 1 note for the `asset-pipeline` system (`ROADMAP.md` Milestone 2.7, Task 39; the design is
`docs/design/asset-pipeline.md`, Task 37). Written by the Builder, 2026-09-26.

**Why this note is unusually load-bearing.** The Architect wrote the design in a session with **no
network**: every URL in its §11 is named from memory and was *not fetched*, and the document says so
at the top. This repo has three recorded cases of a design citing a page that said something else or
did not exist (`docs/research/INDEX.md`: the `RaycastHitbox` URL, "Rodux is archived";
`TASKS.md` row 26a). The Architect's own recommendation (design §16 E) is that this note is checked
instead of the design. So the job here is not to re-argue the design — it is to **read the pages** and
say, source by source, whether the design's use of each one is right.

**The design is the Architect's and is not edited by this note.** Everything that turned out wrong is
in **§DESIGN DELTA** at the end, numbered, for the Director to dispatch.

## Method, and what it cannot cover

- Docs-only session, in the `driven-hunt-review` worktree. **No Studio, no `rojo`, no
  `tools/studio_mcp.py`, no harness, no engine.** Nothing here is measured in the engine; every engine
  claim below is a documentation claim.
- Every page in §Sources was fetched **live on 2026-09-26**. Quotes are what the live page returned
  that day. Where a fetch was refused, the status code is recorded rather than the fact being guessed.
- Two pages that previous sessions could not read were read this time, and one of them **only through
  a second route**:
  - `en.help.roblox.com` article pages return **HTTP 403** to both the fetch tool and `curl` with a
    browser user-agent (confirmed twice this session). They are readable as JSON through the
    help-centre API: `https://en.help.roblox.com/api/v2/help_center/en-us/articles/<id>.json`, field
    `article.body` (HTML). **Record this route** — the map-generator note (§8) lost the Creator Store
    licence to exactly this 403, and there was no need to.
  - `create.roblox.com/docs/<path>.md` serves the raw source of a docs page including the property
    metadata (access, read/write security) that the rendered page hides. That metadata is what
    resolved three of the design's `[UNVERIFIED]` markers, so it is worth knowing.
- What this note **cannot** settle, and does not pretend to: anything that needs the engine running
  (design measurements M1–M4), and the Meshy/Roblox licence interaction, which is a decision for
  Karen and is **not legal advice** (§What needs Karen).

## What the system must do

Unchanged from the design §1, restated so this note stands alone:

1. Take a model Karen made (Meshy FBX + PNG maps) or chose (Creator Store) and get it into the DEV
   place **without any binary asset file ever entering git**.
2. Name every asset by a stable key in one manifest on disk, with its id, its provenance and its
   licence, so a licence question is answerable later and a moderated id is traceable.
3. Turn a key into an Instance the existing owners (`Boar.Body`, `Weapon.Hardware`, `MapGen`) can
   clone, off the spawn path, with one owner for the loading.
4. Never change a physics, hit-zone or grip number when art lands: the consumer sets `Size`.
5. Fail visibly and keep the grey box: a missing, pending or rejected asset must not break the game.
6. Hold an Open Cloud API key on a personal PC without leaking it into a public repo.

## Sources

Fifteen. First-party Roblox documentation dominates because the pipeline is entirely first-party; the
two non-Roblox standards (PNG, Creative Commons) are the file and licence formats it touches, and
Meshy is the supplier.

### 1. Open Cloud — Usage guide for assets
- <https://create.roblox.com/docs/cloud/guides/usage-assets> — **this is the canonical URL.** The
  design cites `<https://create.roblox.com/docs/cloud/open-cloud/usage-assets>`, which still serves
  the same page; the `cloud/guides/` path is the one the docs' own search returns.
- Licence: the docs source is **CC BY 4.0** (`github.com/Roblox/creator-docs`, SPDX `CC-BY-4.0`,
  confirmed via the GitHub API this session); the API itself is Roblox's.
  Maintenance: **active** — the docs repo was pushed to 2026-09-25, one day before this note.
- **What it actually says** (load-bearing quotes):
  - *"The Assets API of Open Cloud allows you to upload and update assets with a single HTTP request
    rather than manually importing them to Studio."*
  - Endpoints: `POST https://apis.roblox.com/assets/v1/assets`,
    `PATCH https://apis.roblox.com/assets/v1/assets/{assetId}`,
    `GET https://apis.roblox.com/assets/v1/operations/{operationId}`.
  - Header: `x-api-key: ${ApiKey}`, required on all endpoints.
  - Key permissions: *"When creating an API key, make sure to add the following permissions:
    1. Add `assets` to Access Permissions. 2. Add Read and Write operation permissions to your
    selected game, depending on the required scopes of the endpoints you plan to call."*
  - The multipart parts are exactly **`request`** (the JSON) and **`fileContent`** (the bytes), and
    the example is
    `--form 'request="{...}"' --form 'fileContent=@"/filepath/model.fbx";type=model/fbx'`.
  - The request JSON: `{"assetType": "Model", "displayName": ..., "description": ...,
    "creationContext": {"creator": {"userId": "${userId}"}}}`.
  - Supported types and limits, from the table:

    | assetType | Format | Content type | Restrictions |
    |---|---|---|---|
    | Animation | .rbxm, .rbxmx | model/x-rbxm | files edited outside Studio may not upload |
    | Audio | .mp3, .ogg, .wav, .flac | audio/* | max 7 min; 100 uploads/month (ID-verified) or 10/month; **not updatable** |
    | **Decal, Image** | **.png**, .jpeg, .bmp, .tga | **image/png**, … | **max 8000x8000 px**; **not updatable** |
    | **Mesh** | **Roblox only** | model/x-file-mesh-data | **"Only Asset delivery API content accepted"**; not updatable |
    | **Model** | **.fbx**, .gltf, .glb, .rbxm, .rbxmx | **model/fbx**, … | **"Imports as Model container with MeshPart objects"** |
    | Video | .mp4, .mov | video/* | max 5 min, 4096x2160, 3.75 GB; 20 uploads/day; not updatable |

  - *"For each call, you can only create or update one asset with the file size up to 20 MB"*.
  - *"Currently, you can only update the asset content for .fbx files. The update creates a new
    version."*
  - Operation shape: `path` is `"operations/${operationId}"`, with `done`; on success the asset id is
    at **`response.assetId`** (the example shows `"assetId": "2205400862"` — a **string**), and the
    response carries **`"moderationState": "MODERATION_STATE_APPROVED"`**.
- **Good:** it gives the whole flow the design adopts, first-party, with no SDK and no third-party
  uploader. Everything the design marked `[UNVERIFIED]` in §7.4 steps 1–4 is on this page, and the
  design **guessed all of it correctly** except the moderation string values.
- **Bad:** the "Add Read and Write operation permissions to your selected **game**" wording is written
  for the experience-scoped APIs and is confusing for an asset upload to a *user* account, where the
  creator target is set per request by `creationContext.creator.userId`. The page states no per-minute
  rate limit. It says nothing about keeping the key secret — but the design blames the wrong page for
  that (see source 2).
- **Is the design's use right?** Yes for §7.4 steps 1–4, §7.5 and `MAX_FILE_BYTES`. No for the
  moderation strings, for `Mesh`-vs-`Model`, and for two "ours, not Roblox's" labels — deltas
  **D3, D5, D12, D13**.

### 2. Open Cloud — Manage API keys
- <https://create.roblox.com/docs/cloud/auth/api-keys>. The dashboard page is
  <https://create.roblox.com/dashboard/credentials> (API Keys tab: `?activeTab=ApiKeysTab`) — the
  design's URL is **right**.
- Licence: CC BY 4.0 docs source. Maintenance: active.
- **What it actually says:**
  - *"In the Creator Dashboard, go to the API Keys page. Click the Create API Key button."*
  - *"Enter a unique name for your API key"*; *"In the Access Permissions section, select an API from
    the **Select API System** menu"*; *"If applicable, select the game that you want to access with
    the API key"*; *"From the **Select Operations** dropdown, select the operations that you want to
    enable"*.
  - *"In the Security section, explicitly restrict IP access to the key using CIDR notation … add it
    to the **Accepted IP Addresses** section … you can leave the **Restrict IP addresses** toggle
    unchecked to allow any IP to use your API key."* The example given is `192.168.0.0/24`.
  - *"To add additional protection for your resources, set an expiration date for your key."*
  - *"Copy and save the API key string to a secure location, **not a public repository for your
    code**."*
  - *"The API key string is equivalent to a password for your application. Never share it with
    untrusted parties."*
- **Good:** it is the authority on §8.1's clicks, and it gives the two controls that make a key on a
  personal PC acceptable — CIDR IP restriction and an expiry date. It also **does** tell you to keep
  the key out of a public repo, in almost the words `CLAUDE.md` uses.
- **Bad:** it is a walkthrough of a dashboard that gets redesigned, and several of the design's quoted
  labels have already drifted. It does **not** say the key is shown only once (the design asserts
  that). It gives **no** rotation policy and **no** statement of how many keys a user may have or any
  per-key rate limit — so the 30-day expiry is genuinely ours.
- **Is the design's use right?** The *policy* (least privilege, `/32`, short expiry, GUI env var, never
  `setx`) is right and is unchanged by anything on this page. The *labels* in §8.1 are wrong in detail,
  and §11 source 1's "Bad" blames the wrong page for the secrecy gap — delta **D11**.

### 3. Rate limits (Open Cloud)
- <https://create.roblox.com/docs/cloud/reference/rate-limits>. The design does not cite this page. It
  should: it is what justifies §12.2's backoff numbers. Note `docs/cloud/open-cloud/rate-limits` is
  **404**.
- Licence: CC BY 4.0 docs source. Maintenance: active.
- **What it actually says:** *"Public rate limits can be found under the Limits section for each
  endpoint on their documentation pages."* · *"Additional, undocumented limits may apply, including
  for DDoS protection and service stability."* · *"Always ensure your application handles HTTP 429
  rate limit responses."* · *"When rate limited, check the `retry-after` response header as a
  guideline for when to retry."*
- **Good:** it settles the question the design left open. There is **no published per-minute limit for
  the Assets API** — the Assets page's "Limits" are file size plus per-month/per-day upload counts for
  audio and video only. And Roblox explicitly asks for exactly what §7.7 does: handle 429, honour
  `Retry-After`.
- **Bad:** "additional, undocumented limits may apply" means no client can be proven polite enough. A
  fixed gap is a guess, not a compliance measure.
- **Is the design's use right?** Yes, and better than it claims: `MIN_REQUEST_GAP_S = 1.0` is filed
  under "politeness, since no documented rate limit could be cited", and the 429/`Retry-After`
  handling is filed as ours. Both are now **documented guidance** — delta **D10** (relabel only).

### 4. Mesh specifications
- <https://create.roblox.com/docs/art/modeling/specifications>
- Licence: CC BY 4.0 docs source. Maintenance: active.
- **What it actually says:** **_"Individual meshes can not exceed 20,000 triangles."_** Also
  *"A vertex can not be influenced by more than 4 bones or joints"*. It states **no** maximum vertex
  count, **no** stud size limit, **no** texture resolution, nothing about pivot or units, and nothing
  about how many materials one mesh may carry.
- **Good:** the triangle limit is first-party, single-sentence and unambiguous. Every figure in the
  design's §12.1 table (900–6,000) sits far inside it.
- **Bad:** it is the *only* number on the page. The design's per-key budgets remain unmeasured
  taste-and-performance figures, and this page cannot validate them — only the map design's
  measurement D (cost of 50 trees) can.
- **Is the design's use right?** No. `MESHPART_TRI_LIMIT = 21,000`, labelled *"community/vendor,
  research note §9. Labelled as such wherever printed"*, is wrong in **both** halves: the real figure
  is **20,000** and it **is** first-party — delta **D1**. This also corrects
  `docs/research/2026-09-24-map-generator.md` §9, which is where the 21,000 came from.

### 5. Texture specifications
- <https://create.roblox.com/docs/art/modeling/texture-specifications>
- Licence: CC BY 4.0 docs source. Maintenance: active.
- **What it actually says:**
  - *"File formats for textures that are uploaded separately in Studio must be submitted as a .png,
    .jpg, .tga, or .bmp."*
  - **_"Roblox supports up to 4096x4096 pixel texture resolutions (4K)."_**
  - In the UV section: *"Roblox supports up to 1024x1024 pixel spaces for texture maps"* — this is
    about **UV space**, not a cap on the uploaded image.
  - Recommendations by object scale: 256x256 for a 5x5-stud object, 512x512 for 10x10, **1024x1024 for
    20x20**.
  - PBR map formats: Albedo RGB 24-bit; Normal *"RGB (24-bit); Roblox only supports OpenGL format -
    Tangent Space normal maps"*; Roughness, Metalness and Emissive Mask single-channel greyscale
    8-bit. UVs *"within a 0:1 space"*.
  - *"Even still, manually sizing textures before you upload them can improve memory usage in some
    situations."*
- **Good:** it gives the one thing the design needs (albedo is plain 24-bit RGB PNG, which is what
  Meshy exports) and it puts 1024 exactly where the design puts it — the right size for a 20-stud
  object, which the boar, the high seat and the trees are or are near.
- **Bad:** the 1024 figure appears twice in two different meanings, and a careless read turns a
  *recommendation* into a *limit*. The normal-map handedness (OpenGL / tangent space) is a real trap
  that no assertion in the design catches and only a screenshot would show.
- **Is the design's use right?** The *number* yes, the *label* no. `TEXTURE_MAX_PX = 1024` is filed as
  *"community/vendor"*; it is in fact **our budget**, matching Roblox's own recommendation, and the
  platform limits are 4096x4096 generally and 8000x8000 for a Decal/Image upload — delta **D2**.

### 6. `AssetService`, and the `Content` datatype
- <https://create.roblox.com/docs/reference/engine/classes/AssetService> ·
  <https://create.roblox.com/docs/reference/engine/classes/AssetService.md> (raw source, carries the
  security metadata) · <https://create.roblox.com/docs/reference/engine/datatypes/Content>
- Licence: CC BY 4.0 docs source. Maintenance: active.
- **What it actually says:**
  - **`AssetService:CreateMeshPartAsync(meshContent: Content, options?: Dictionary): MeshPart`** —
    `meshContent` is a *"Reference to asset content stored externally or as an object within the
    place"*; the options dictionary keys are exactly **`CollisionFidelity`**, **`RenderFidelity`**,
    **`FluidFidelity`**. *"Since `MeshPart.MeshId` is read-only, this method allows mesh creation
    through scripts."* Security None, **Yields: Yes**, Thread Safety Unsafe, Capabilities Basic.
  - `Content` constructors: **`Content.fromUri(uri: string)`**, **`Content.fromAssetId(assetId:
    number)`**, `Content.fromObject(object)`; plus `Content.none` and `Content.SourceType`.
  - **`AssetService:LoadAssetAsync(assetId: int64): Instance`** — *"Loads the latest version of an
    asset from the given `assetId` and returns it wrapped in a Model."*
  - **`AssetService.AllowInsertFreeAssets`** — boolean, **Access ReadOnly**, and **read *and* write
    security `RobloxScriptSecurity`**. *"When `false` (default), `AssetService:LoadAssetAsync()` can
    only load assets that meet one of the following: The asset must be created or owned by the game
    creator, shared by the asset owner, or owned by Roblox. When `true`, it can load any public free
    asset on the Creator Store."*
- **Good:** `CreateMeshPartAsync` is the documented, script-only way to pick `CollisionFidelity` and
  `RenderFidelity` at creation — and it is the **only** way, because both properties are otherwise
  closed to scripts (source 7). It yields, exactly as §5.2 assumes.
- **Bad:** the rendered page carries no limits, no throttling and no caching statement, and does not
  say which *kind* of asset id a mesh `Content` may name. The community answer — a devforum
  measurement of *22 ms fixed plus ~0.27 ms per 1k triangles* per call
  (<https://devforum.roblox.com/t/allow-applying-baked-mesh-content-to-a-meshpart-without-a-lag-spike/4752538>,
  community evidence, not first-party) — is the only cost figure available, and is a good reason for
  §5.2's "never on the spawn path".
- **Is the design's use right?** Not as written. The signature is `(meshContent: Content, …)`, not
  `(id, options)` — delta **D4**. And the design treats `CreateMeshPartAsync` and `InsertService` as
  two interchangeable routes "chosen by measurement"; the docs already decide it — delta **D5**.
  `AllowInsertFreeAssets` being `RobloxScriptSecurity` for *both* read and write is the delta that
  reaches furthest — **D9**.

### 7. `MeshPart` and `TriangleMeshPart` — which properties a script may write
- <https://create.roblox.com/docs/reference/engine/classes/MeshPart.md> ·
  <https://create.roblox.com/docs/reference/engine/classes/TriangleMeshPart.md>
- Licence: CC BY 4.0 docs source. Maintenance: active.
- **What it actually says** (raw property metadata, which the rendered page hides):
  - **`MeshId`** — Access **ReadOnly**; write security **`NotAccessibleSecurity`**. *"The asset URIs of
    the mesh that is displayed on the MeshPart."* Cannot be changed at run time; use
    `AssetService:CreateMeshPartAsync()` or `MeshPart:ApplyMesh()`. **Read** security is None, so a
    script *can read* a `MeshId` off an imported `MeshPart`.
  - **`TextureID`** — Access **ReadWrite**; read security None, **write security None**. *"The texture
    applied to the MeshPart."* Settable at run time, and settable to `""` to remove the texture.
  - **`RenderFidelity`** — Access **ReadOnly**; **write security `PluginSecurity`**. *"This property
    determines the level of detail that the MeshPart will be shown in."*
  - **`CollisionFidelity`** (inherited from `TriangleMeshPart`) — *"This property cannot be read or
    manipulated by scripts during runtime."*
  - `DoubleSided` — ReadWrite, no security.
- **Good:** this settles two of the design's own measurements without the engine. **M3's first half is
  yes**: `MeshPart.TextureID` *is* assignable from a script at run time, so a separately uploaded
  colour map can be applied by the Loader. And the reason `CreateMeshPartAsync` exists is now plain.
- **Bad:** the two fidelity properties are **closed to game scripts**. That is a constraint the design
  does not have, and it lands directly on a manifest field.
- **Is the design's use right?** Half. §6.6 decision 1's `[UNVERIFIED]` on `TextureID` resolves in the
  design's favour — delta **D7** (a correction *towards* the design). But `renderFidelity` in the
  manifest, `"Precise"` for the shotgun, **cannot be applied by the Loader on the `InsertService`
  route** — delta **D6**.

### 8. `InsertService`
- <https://create.roblox.com/docs/reference/engine/classes/InsertService> ·
  <https://create.roblox.com/docs/reference/engine/classes/InsertService.md>
- Licence: CC BY 4.0 docs source. Maintenance: active.
- **What it actually says:**
  - *"The LoadAsset function fetches an asset given its ID and returns a Model containing the asset."*
    Yields; Security None; **Capabilities `LoadOwnedAsset`**.
  - Ownership, as a list: *"The asset must be created or owned by the game creator."* ·
    *"The asset must be shared by the asset owner."* · *"The asset must be owned by Roblox."* ·
    *"Benign asset types such as t-shirts, shirts, pants and avatar accessories are loadable from any
    game."*
  - **_"To load assets which do not meet the above criteria, such as free Models published on the
    Store, you must use `AssetService:LoadAssetAsync()` and enable
    `AssetService.AllowInsertFreeAssets`."_**
  - `LoadAssetVersion(assetVersionId)` *"Returns a model inserted into InsertService containing the
    asset with the given assetVersionId"*, same capability.
- **Good:** for **Karen's own uploads** — everything this pipeline creates through Open Cloud with
  `creationContext.creator.userId` set to her id — the first bullet is satisfied and `LoadAsset` is
  exactly right. It returns a Model, server-side, matching what an FBX upload produces (source 1). The
  map generator already assumes this route, so one implementation serves both.
- **Bad:** the page does **not** say it errors rather than returning `nil`. That is community knowledge
  — <https://devforum.roblox.com/t/asset-is-not-trusted-for-this-place/559187> and
  <https://devforum.roblox.com/t/insertserviceloadasset-does-not-work-with-the-new-model-permissions/3652107>
  — so the `pcall` stays, on community evidence. There is no caching statement, so the cache is ours.
  And the quoted sentence above is a wall in front of free Creator Store props.
- **Is the design's use right?** For Karen's own assets, yes, and §5.3's `pcall` is right for the right
  reason even if the cited page does not give it. For **Creator Store** assets it is wrong, and so is
  `docs/design/map-generator.md` §8.2 — delta **D9**. Whether `LoadAsset` works from the harness's
  `execute_luau` in Edit mode (the map design's measurement C) is **still unverified**: no engine here.

### 9. `Highlight`, and "Highlighting objects"
- <https://create.roblox.com/docs/reference/engine/classes/Highlight> (properties only) ·
  <https://create.roblox.com/docs/effects/highlighting> (**the page with the numbers** — the design
  does not cite it, and it is the one that matters)
- Licence: CC BY 4.0 docs source. Maintenance: active — the limit was raised recently
  (<https://devforum.roblox.com/t/lights-camera-more-highlights/4061534>).
- **What it actually says:**
  - **_"Studio only displays 255 simultaneous Highlight instances on the client-side at a time."_**
  - **_"While a disabled Highlight doesn't display, it still takes one of the 255 available Highlight
    slots."_**
  - *"The first Highlight rendered on the screen incurs most of the performance cost (up to 1
    millisecond of GPU time on mobile devices). For additional highlights beyond the first, you should
    not see a significant performance impact on any platform."*
  - **_"Adding or removing a Highlight can cause a geometry rebuilding step that might lead to
    performance spikes and extra draw calls."_** versus *"changing any property of the Highlight
    instance is lightweight and doesn't impact performance."*
- **Good:** it **confirms the design's central choice** on evidence the design did not have: a
  `Highlight` per boar, created once and toggled by `Enabled` / `FillTransparency`, is the documented
  cheap pattern, and adding or removing one per hit is the documented expensive one. That is exactly
  §6.5, and exactly `Body.stepFlash`'s existing "two property writes per hit, never one per frame". At
  `Boar.CONFIG.maxBoars = 8` the budget is not close to binding.
- **Bad:** the 255 slots are **client-side and global**, and a *disabled* Highlight still occupies one.
  So the budget is not "8 boars" but "every Highlight the place ever instantiates, enabled or not" — a
  constraint for later systems (props, interaction prompts), not for the boar.
- **Is the design's use right?** The pattern yes; the number no. §11 source 5's "Bad" says the limit is
  *"single digits to low tens"* and concludes *"not fine if highlights are ever used for anything
  else … keep it to the boar"*. It is **255**, and the real caution is a different one — delta **D8**.

### 10. PBR textures and `SurfaceAppearance`
- <https://create.roblox.com/docs/art/modeling/surface-appearance> ·
  <https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance>
- Licence: CC BY 4.0 docs source. Maintenance: active.
- **What it actually says:**
  - *"You can add PBR textures to any MeshPart by adding a SurfaceAppearance object which overwrites
    the original assigned texture."*
  - **_"In general, you can't modify SurfaceAppearance properties by scripts during a game because the
    engine requires some pre-processing to display these graphics."_**
  - *"The ColorMap property sets the color data of the surface, including any transparency present in
    the map."* · Normal *"adds texture depth to your surface"* · *"Roughness maps determine how light
    is spread across your model's surface."* · *"Metalness determines the reflectivity of a surface."*
  - `AlphaMode` has four modes: Opaque, Overlay, Transparency, TintMask.
- **Good:** it confirms the design's v1 decision to use `MeshPart.TextureID` and **not**
  `SurfaceAppearance`, and gives a much better reason than the one in §6.6 ("a property survives
  `Clone()`"): a `SurfaceAppearance` cannot be assembled by a script at run time at all, so a
  `TextureID` is the only map the Loader can apply.
- **Bad:** it does not say whether the 3D Importer creates a `SurfaceAppearance` from an FBX's PBR
  textures, which is the practical question. That stays a measurement.
- **Is the design's use right?** Yes on the decision, and this note strengthens it. But §6.6's plan for
  "whenever `SurfaceAppearance` does arrive" must have it arrive **with the asset at import time**,
  never assigned by the Loader — delta **D7**.

### 11. Studio's 3D Importer
- <https://create.roblox.com/docs/art/modeling/3d-importer>
- Licence: CC BY 4.0 docs source. Maintenance: active.
- **What it actually says:** *"The .fbx and .gltf formats support multiple mesh objects and
  hierachies, basic and PBR textures."* · "Merge Meshes" imports *"as a single MeshPart"* (so the
  default produces several) · *"If enabled, the Importer sets the pivot point of the entire model to
  the scene origin"* · "Insert Using Scene Position" *"uses the current scene position when inserting
  the model into the workspace"* · a units setting that *"Sets what units the file was modeled in so
  that it's sized appropriately when imported"* · "World Forward" and "World Up" axis settings ·
  *"If enabled, the Importer adds the model to your Toolbox and Asset Manager inventory as a new
  asset."*
- **Good:** it makes §7.6's named fallback real. The importer takes the same FBX, has explicit controls
  for the two things the design worries about (pivot → scene origin, orientation via World Forward /
  World Up), and publishes the result as an asset with one tick — so the fallback costs Karen clicks
  and costs the pipeline nothing.
- **Bad:** it says nothing about textures embedded *in* the FBX, or about whether a
  `SurfaceAppearance` is produced. Every one of those controls is a Studio dialog — a `NEEDS KAREN`
  click, not something a tool can drive.
- **Is the design's use right?** Yes. §7.6 is a real fallback, and §6.2/§6.3 (pivot tolerance,
  `rotationDeg`) point at the right two problems. The importer's own pivot and axis settings are worth
  naming in the fallback text as the *first* fix, before `rotationDeg` — delta **D17** (minor).

### 12. PNG specification (third edition)
- <https://www.w3.org/TR/png-3/>
- Licence: *"Copyright © 1996-2025 World Wide Web Consortium. W3C liability, trademark and permissive
  document license rules apply"* — the **W3C Software and Document Notice and License**. The format is
  unencumbered. Maintenance: **W3C Recommendation, 24 June 2025**, third edition.
- **What it actually says:** *"The first eight bytes of a PNG datastream always contain the following
  hexadecimal values: 89 50 4E 47 0D 0A 1A 0A"* (decimal 137 80 78 71 13 10 26 10) ·
  *"The IHDR chunk shall be the first chunk in the PNG datastream."* · IHDR fields in order: Width
  4 bytes, Height 4 bytes, Bit depth 1, Colour type 1, Compression method 1, Filter method 1,
  Interlace method 1.
- **Good:** exactly as the design says — "is this a PNG and how big is it" is a fixed-offset read of
  24 bytes with no library. `IHDR` being *required first* is what makes the offsets constant.
- **Bad:** as the design says, it tells you nothing about content. A 1024x1024 PNG can still be the
  normal map filed as albedo — and per source 5 it can also be a normal map in the wrong handedness.
  Only the screenshot catches that.
- **Is the design's use right?** Yes, and it is the only source in §11 the design describes without
  error. One citation fix: the current edition is the **2025** W3C Recommendation, not *"third
  edition, 2023"* — delta **D14** (cosmetic).

### 13. Meshy — Terms of Use, and the plan-by-plan licence
- <https://www.meshy.ai/terms-of-use> (**the design's `https://www.meshy.ai/terms` is 404**) ·
  <https://help.meshy.ai/en/articles/9992001-can-i-use-meshy-assets-commercially-license-copyright-explained> ·
  <https://help.meshy.ai/en/articles/10137554-what-is-the-ownership-of-the-generated-models> ·
  <https://www.meshy.ai/pricing>
- Licence of the *output*: **see below — this is the answer the design could not give.**
  Maintenance: Terms of Use **last updated 19 September 2026**, a week before this note.
- **What it actually says:**
  - Terms §3.2 *Ownership of User Content; Rights Granted to Meshy* — **free plan:** *"Meshy owns all
    right, title, and interest, including all intellectual property rights, in and to the Customer
    Output"*, made available under the *"Creative Commons Attribution 4.0 International License"*
    with attribution to Meshy required. **Paid plan:** *"customers on a paid Meshy plan own their
    Customer Output."*
  - Help centre, both articles: *"If you are on a free plan, we grant you a CC BY 4.0 license
    instead."* · *"If you are a paid customer, you own the assets created through our platform,
    provided that you have used materials that do not violate the copyrights of others."* ·
    *"We kindly ask that you credit Meshy for the tool's use in the description of your project"*,
    with the suggested form **"Model created with Meshy – CC BY 4.0 License"**. Paid: *"you retain
    full private ownership of all assets you create with Meshy"*.
  - Terms §3.3 *Community License*: anything posted to Meshy's community page goes out as **CC0 1.0**
    for 3D models (and CC BY-NC 4.0 for other content).
  - Terms §2.9: *"Meshy may use Customer Inputs and Customer Outputs from non-Enterprise Customers to
    train, validate, test, or improve Services unless otherwise agreed to in the Order."*
  - Pricing page: Free = 100 credits/month, licence *"CC BY 4.0"* which *"allows commercial use with
    attribution"*, exports `.fbx .obj .usdz .glb .stl .blend`; Pro = 1,000 credits/month,
    *"60% faster generation, API access, private asset ownership"*. For premium subscribers,
    *"the models you create using Meshy are exclusively yours, and you have full rights to distribute
    and sell them"*.
- **Good:** Meshy is the only route Karen has to bespoke models, it remeshes to a triangle target in
  the tool, and it exports FBX with PBR maps — which is why the pipeline can be as thin as it is. And
  the licence position is **published and plain**, not something that needed guessing.
- **Bad, and this is the real finding:** on the **free plan Meshy keeps ownership** and grants CC BY
  4.0. CC BY 4.0 permits commercial use, so a monetised game is fine *on its face* — but see source 14
  for the clause that makes this Karen's decision rather than a tick-box. Also: a Driven Hunt model
  must **never** be posted to the Meshy community page (that would put it under CC0), and on any
  non-Enterprise plan Meshy may train on the inputs and outputs.
- **Is the design's use right?** §11 source 7's refusal to guess was correct, and its instinct —
  *"free-tier output is commonly granted under an attribution licence while paid tiers grant
  commercial use"* — is **right in outcome and wrong in the load-bearing detail**: the free tier does
  allow commercial use; what it withholds is **ownership** and, per source 14, the right to
  sublicense. `licenceNote` per row is the right mechanism. Delta **D15**, and the Karen decision
  below.

### 14. CC BY 4.0 legal code, and Roblox's Creator Terms — the clause that collides
- <https://creativecommons.org/licenses/by/4.0/legalcode.en> · Roblox User and Creator Terms, article
  115004647846, read through the help-centre API (the HTML page is 403):
  <https://en.help.roblox.com/hc/en-us/articles/115004647846-Roblox-Terms-of-Use>, last updated
  **2026-09-22**.
- Licence: the CC legal code is published by Creative Commons for use as a licence; the Roblox Terms
  are Roblox's. Maintenance: both current.
- **What it actually says:**
  - CC BY 4.0 §2(a)(1): the licence is **"non-sublicensable"**. §2(a)(5) instead gives each downstream
    recipient a direct offer: *"Every recipient of the Licensed Material automatically receives an
    offer from the Licensor to exercise the Licensed Rights under the terms and conditions of this
    Public License."* and *"You may not offer or impose any additional or different terms or
    conditions on … the Licensed Material if doing so restricts exercise of the Licensed Rights by any
    recipient of the Licensed Material."*
  - CC BY 4.0 §3(a)(1) attribution: you must retain *"identification of the creator(s) of the Licensed
    Material and any others designated to receive attribution"*, *"a copyright notice"*, *"a notice
    that refers to this Public License"*, *"a notice that refers to the disclaimer of warranties"*,
    and *"a URI or hyperlink to the Licensed Material to the extent reasonably practicable"*, and
    indicate any modifications.
  - Roblox **Creator Terms**, *Roblox License to UGC*: *"Creator grants Roblox a perpetual, worldwide,
    non-exclusive, royalty-free right and license (**with the right to sublicense to any person or
    entity**, including without limitation other Users and Creators) to host, store, transfer, …
    modify, adapt, create derivative works of, … distribute, and use for any business purpose … any
    UGC … that Creator Publishes or makes available on or through the Services."*
  - Roblox **Creator Terms**, *Authorization to Publish UGC to Services*: *"Creator must not Publish or
    otherwise make any UGC available on the Services if Creator is not the owner of or is not fully
    authorized to grant rights in all parts of that UGC."*
  - Roblox **Creator Terms** — the free-asset licence, the sentence that pairs with source 8:
    *"Creator, when Publishing certain UGC onto the Service, may be asked if Creator would like to
    share such UGC directly with other Users. Creator is not required to do so, but if Creator does
    agree to grant this right, then other Users may use Creator's UGC to create their own Experiences
    and other UGC on the Services without any further obligation to Creator."*
- **Good:** this is the pair of documents that turns "what is the Meshy licence" into a decision with a
  clear cheap answer, and it also explains *why* `licenceNote` must be a quote and not a label.
- **Bad:** it is a genuine tension, not a settled fact, and nobody in this workflow is qualified to
  resolve it. Publishing free-plan Meshy output into a Roblox experience means granting Roblox a
  **sublicensable** licence to material Karen does not own, under a licence that is expressly
  **non-sublicensable**, while warranting she is *"fully authorized to grant rights in all parts"*.
- **Is the design's use right?** The design is right that this *"blocks **publishing** a monetised game
  with her models in it"* and not building, and right to make it §16 Karen 1. This note adds the
  clause it collides with and the cheapest resolution — delta **D15**, and §What needs Karen.

### 15. Creator Store Terms — read at last
- <https://en.help.roblox.com/hc/en-us/articles/21308223046932-Creator-Store-Terms>, last updated
  **2026-09-22**. **The HTML page returns HTTP 403** to the fetch tool *and* to `curl` with a browser
  user-agent. It is readable at
  `https://en.help.roblox.com/api/v2/help_center/en-us/articles/21308223046932.json`.
- Licence: Roblox's terms document. Maintenance: current.
- **What it actually says:**
  - §1 *Creator Store*: *"Roblox provides the Creator Store as a marketplace by and through which
    Creators may publish, sell, and obtain assets (including models, decals, audio, videos, meshes,
    and plugins) for use on the Services. Only Creator assets intended for use in Roblox Studio may be
    published, sold, or obtained on the Creator Store…"*
  - **§License, in full:** **_"By purchasing assets on the Creator Store, User is granted a license to
    use the asset in Roblox Studio and in Experiences on the Services consistent with the Roblox User
    and Creator Terms."_**
- **Good:** it closes the hole `docs/research/2026-09-24-map-generator.md` §8 left open —
  *"The Terms page itself returned HTTP 403 to me, so I have not read the primary licence text."* The
  licence is real, and it is exactly what that note guessed: **use on Roblox, in Studio and in
  Experiences**. Both rules that note derived stand, unchanged and now on primary evidence:
  **never commit a Creator Store asset**, and **record provenance per row**.
- **Bad:** the grant is written for **purchased** assets. A *free* asset is not purchased, and this
  document says nothing about it. The licence for a free one comes from the Creator Terms sentence in
  source 14 — it exists **only if its creator agreed to share it**. And nothing here is a
  redistribution grant: a public git repo is not "the Services".
- **Is the design's use right?** Yes, and stronger than it claims. But the free-asset case is the same
  flag as source 8's *"shared by the asset owner"*: **one tick by the original creator decides both
  whether Karen is licensed and whether any script can load it** — delta **D9**, and it is the most
  useful single fact in this note.

### Also considered and rejected, so they are not re-proposed

The design's own rejected list stands and this note found nothing to reopen it: a geometry parser
(`pyassimp` / Blender `bpy`) to count triangles before upload — Roblox enforces 20,000 itself and Meshy
sets the target, so the dependency buys nothing; a `.rbxm` template in the repo — banned by
`CLAUDE.md` and grepped by CI; a `.model.json` template — needs `TASKS.md` row 16; a community uploader
library — a third-party dependency in the one program that holds a secret; `tools/studio_mcp.py upload`
— the harness is the test gate and nothing else. **Added to that list by this note:** setting
`AssetService.AllowInsertFreeAssets` from code (impossible: `RobloxScriptSecurity` on read *and*
write), and assembling a `SurfaceAppearance` in the Loader (documented not to work at run time).

## Pattern adopted, and why

Unchanged in shape from the design — **manifest on disk, one Loader owner, ids never binaries** — and
this note found no reason to change any of it. What the reading changes is three mechanisms inside it:

1. **One upload route, not two.** Open Cloud FBX → a **Model** asset → `InsertService:LoadAsset` in a
   `pcall`, cached once per key. `CreateMeshPartAsync` is **not** an alternative first route, because
   Open Cloud cannot mint a **Mesh** asset at all (source 1: *"Only Asset delivery API content
   accepted"*). It becomes an optional **second, derived** step: read `MeshId` off the imported
   `MeshPart` (readable), record it, and use `Content.fromAssetId` when a per-instance
   `CollisionFidelity` / `RenderFidelity` is actually needed. `Loader.template` still hides both.
2. **Fidelity is set at import, not at load.** `RenderFidelity` is `PluginSecurity` to write and
   `CollisionFidelity` cannot be touched at run time. So the manifest's `renderFidelity` is a
   **recorded property of the asset** — set in Studio at import, asserted by a spec — not an
   instruction the Loader executes. The one way to set it from code is route 1's second step.
3. **Textures: `TextureID` only, and that is now a fact rather than a hope.** `TextureID` is ReadWrite
   with no security; `SurfaceAppearance` is documented as not script-modifiable at run time. So v1
   applies a colour map by id, and any PBR upgrade arrives **with the asset**, never from the Loader.

Everything else the design borrowed is borrowed, per rule 2: the endpoint, header, multipart shape and
operation polling are Roblox's own guide; 429 + `Retry-After` is Roblox's own instruction; the
`Highlight`-toggle pattern is the documented cheap path; the PNG signature + IHDR read is the
standard's own fixed layout; least privilege + CIDR + expiry is the api-keys page's own advice.

## Numeric targets

Corrected labels in **bold**. The design's per-key budgets (§12.1) are unchanged and remain
**unmeasured taste-and-performance figures**, which this note cannot validate.

| Quantity | Value | Basis — corrected |
|---|---|---|
| `MESHPART_TRI_LIMIT` | **20,000** | **first-party**: *"Individual meshes can not exceed 20,000 triangles."* — mesh specifications page. **Not** 21,000, and **not** community/vendor |
| `TEXTURE_MAX_PX` | 1024 | **ours.** Roblox's platform limits are **4096x4096** generally and **8000x8000** for a Decal/Image upload. 1024 is also Roblox's own *recommendation* for a 20-stud object |
| `MAX_FILE_BYTES` | 20 MB | **Roblox's, documented**: *"you can only create or update one asset with the file size up to 20 MB"*. Not ours |
| maps per asset | <= 4; v1 albedo only | design decision, and now also forced: a `SurfaceAppearance` cannot be built at run time |
| bone influences per vertex | <= 4 | first-party, mesh specifications. Not in the design; free constraint, matters only if the boar is ever skinned |
| `UPLOAD_TIMEOUT_S` | 60 | ours |
| `POLL_INTERVAL_S` / `POLL_DEADLINE_S` | 2 / 120 | ours |
| `RETRIES` / backoff | 3 / 2, 4, 8 s, `Retry-After` wins | **Roblox's instruction**: *"Always ensure your application handles HTTP 429"*, *"check the `retry-after` response header"* |
| `MIN_REQUEST_GAP_S` | 1.0 | ours, and necessarily a guess: *"Public rate limits can be found under the Limits section for each endpoint"* — and the Assets page publishes none for create / update / operations |
| `MAX_UPLOADS_PER_RUN` | 20 | ours |
| `KEY_EXPIRY_DAYS` | 30 | ours. The api-keys page offers an expiry but no rotation policy |
| simultaneous `Highlight`s | **<= 255, client-side, enabled *or* disabled** | **first-party**: *"Studio only displays 255 simultaneous Highlight instances on the client-side at a time"*; *"a disabled Highlight … still takes one of the 255 available Highlight slots"*. Not "single digits to low tens" |
| first `Highlight` GPU cost | up to **1 ms** on mobile; additional ones negligible | first-party, highlighting page |
| `CreateMeshPartAsync` cost | ~**22 ms** fixed + ~**0.27 ms per 1k tris** | **community** (devforum), the only figure available. Reason enough for §5.2 |
| PNG header read | **24 bytes**: 8-byte signature + 8-byte chunk header + IHDR width/height | first-party standard: IHDR *"shall be the first chunk"* |
| `LOAD_TIMEOUT_S` / `PRELOAD_BUDGET_S` | 10 / 15 | ours |
| `ASPECT_TOLERANCE` / `PIVOT_TOLERANCE_STUDS` | 0.05 / 0.25 | ours |
| flash `FillTransparency` | 0.5 | K (Karen's taste) |

## DESIGN DELTA

For the Director. The design is the Architect's and this note does not edit it. **D5, D6 and D9 change
what gets built**; the rest are labels, names and numbers. Nothing here blocks starting M2.7a.

1. **D1 — `MESHPART_TRI_LIMIT` is 20,000 and is first-party.** §12.2 has 21,000 filed as
   *"community/vendor, research note §9. Labelled as such wherever printed"*. Source 4 states 20,000
   in one sentence. Fix the value, the label, and the place it came from:
   `docs/research/2026-09-24-map-generator.md` §9 is the origin of the 21,000 and needs a correction
   note. *Non-blocking: every budget in §12.1 is far inside both numbers.*
2. **D2 — `TEXTURE_MAX_PX = 1024` is ours, not community/vendor.** Platform limits are 4096x4096
   (texture specifications) and 8000x8000 for a Decal/Image upload (Assets API). 1024 is Roblox's
   *recommendation* for a 20-stud object, which is the right basis to cite. Same correction needed in
   the map-generator note §9, which also states "no single texture map above 1024x1024" as a limit.
3. **D3 — `MAX_FILE_BYTES = 20 MB` is Roblox's, not ours.** §12.2 files it as *"ours, not Roblox's. A
   20 MB FBX is not a v1 prop"*. The Assets guide states it as the per-call cap. Relabel; the value is
   right.
4. **D4 — `CreateMeshPartAsync` signature.** §11 source 3 and §5 write
   `CreateMeshPartAsync(id, options)`. It is
   `CreateMeshPartAsync(meshContent: Content, options?: Dictionary)`, so the id must be wrapped —
   `Content.fromAssetId(<number>)` or `Content.fromUri(<string>)` — and the options keys are exactly
   `CollisionFidelity`, `RenderFidelity`, `FluidFidelity`.
5. **D5 — the Loader's "two routes chosen by measurement" is already decided by the docs, and
   measurement M2 is the wrong question.** Open Cloud **cannot create a `Mesh` asset**: *"Mesh |
   Roblox only | Only Asset delivery API content accepted"*. An FBX upload creates a **Model** —
   *"Imports as Model container with MeshPart objects"*. `CreateMeshPartAsync` wants a **mesh**
   `Content`. So an Open Cloud upload yields a Model id, and the route for it is
   `InsertService:LoadAsset` (or `AssetService:LoadAssetAsync`), full stop. `CreateMeshPartAsync` is
   reachable only from a **mesh** id, which this pipeline can obtain only by reading `MeshPart.MeshId`
   off the imported model (read security None). **Suggested shape:** the manifest row carries `modelId`
   (from the upload) and an optional `meshId` (recorded later), and §5.1's `Loader.template` branches
   on which is present. M2 becomes "is the derived `meshId` worth recording", not "which route".
6. **D6 — the Loader cannot apply `renderFidelity`.** `MeshPart.RenderFidelity` is Access ReadOnly with
   write security **`PluginSecurity`**; `CollisionFidelity` *"cannot be read or manipulated by scripts
   during runtime"*. So the manifest's `renderFidelity: "Precise"` for the shotgun is **not
   executable** on the `InsertService` route: it must be set at import time in Studio (a Karen click,
   belongs in §8) or via `CreateMeshPartAsync`'s options on D5's derived route. Either way the field
   becomes a **recorded property asserted by a spec**, not an instruction. §13's specs should assert
   the value rather than assume the Loader wrote it.
7. **D7 — two `[UNVERIFIED]`s resolve, one for the design and one against.** *For:*
   `MeshPart.TextureID` is Access ReadWrite with no read or write security, so it **is** assignable at
   run time — §6.6 decision 1 and the first half of measurement M3 are answered yes, and the
   Decal-vs-Image fork in §7.6 stays a real fork but a shallow one. *Against:* a `SurfaceAppearance` is
   documented as **not** script-modifiable during a game (*"the engine requires some
   pre-processing"*), so §6.6's "whenever `SurfaceAppearance` does arrive" must have it arrive **with
   the imported asset**. The `Viewmodel` sweep fix stays necessary and stays the camera owner's.
8. **D8 — the `Highlight` limit is 255, and the caution is a different one.** §11 source 5 says
   *"single digits to low tens"* and concludes *"not fine if highlights are ever used for anything
   else … keep it to the boar"*. The documented figure is **255 client-side simultaneous**, and a
   **disabled** Highlight still occupies a slot. At `maxBoars = 8` this is not close. Replace the
   caution with the real one — the budget is global and counts disabled instances — and add the
   sentence that *confirms* §6.5: *"Adding or removing a Highlight can cause a geometry rebuilding step
   that might lead to performance spikes"* versus *"changing any property … is lightweight"*. Cite
   `docs/effects/highlighting`, not the class page, which carries none of it.
9. **D9 — free Creator Store props cannot be loaded by any script route, and that reaches into the map
   design.** `InsertService:LoadAsset` requires the asset be *created or owned by the game creator*,
   *shared by the asset owner*, or *owned by Roblox*; *"To load assets which do not meet the above
   criteria, such as free Models published on the Store, you must use `AssetService:LoadAssetAsync()`
   and enable `AssetService.AllowInsertFreeAssets`"* — and `AllowInsertFreeAssets` is **Access ReadOnly
   with `RobloxScriptSecurity` on read *and* write**, so no game script can enable it. Consequences:
   - Everything **Karen uploads herself** through this pipeline is fine: she is the game creator.
   - A **free Creator Store model she did not make** is loadable by script **only if its creator ticked
     share** (the Creator Terms sentence in source 14 — which is also the only thing that licenses her
     to use it). Otherwise it must be inserted in Studio by hand and exported to `src/serverstorage/`
     as `.model.json`, and that needs `TASKS.md` row 16 (typed values).
   - **This contradicts `docs/design/map-generator.md` §8.2**, which makes `InsertService:LoadAsset`
     the primary route for Creator Store assets, and it narrows §16 Karen 3's default (*"the map's
     small props are Creator Store where they fit"*).
   - **Unverified, and it is the one thing here worth measuring:** whether free Creator Store models
     are in fact flagged *shared by the asset owner*. No engine in this session. Recommend it as a
     measurement on the first map-props task, not a blocker for M2.7a — which uses only Karen's own
     uploads.
10. **D10 — relabel the rate-limit numbers as documented guidance.** §12.2 files 429 / `Retry-After`
    handling and `MIN_REQUEST_GAP_S` as politeness. Roblox's rate-limits page says *"Always ensure your
    application handles HTTP 429"* and *"check the `retry-after` response header as a guideline for
    when to retry"*, and warns *"Additional, undocumented limits may apply"*. Cite it
    (`docs/cloud/reference/rate-limits` — the `open-cloud/rate-limits` path is 404). The design's
    handling is correct as designed.
11. **D11 — §8.1's clicks: the labels have drifted, and one step is wrong.** Actual labels: Creator
    Dashboard → **Credentials** (`create.roblox.com/dashboard/credentials`, API Keys tab
    `?activeTab=ApiKeysTab`) → **Create API Key** → a unique **name** → **Access Permissions**, then
    *"select an API from the **Select API System** menu"* → *"If applicable, select the game that you
    want to access"* → *"From the **Select Operations** dropdown, select the operations"* →
    **Security**: a **Restrict IP addresses** toggle plus an **Accepted IP Addresses** section in CIDR
    → an **expiration date**. Specifically:
    - The design's step 4 says *"Add API System"*; it is **Select API System**.
    - The design's step 5 ("Add Experience / choose the creator: select her own user account") has no
      counterpart: the docs only offer *"select the game"*, and for the Assets API the creator is
      chosen **per request** by `creationContext.creator.userId`. **This is the one step Karen must
      report back**, because the Assets guide still says *"Add Read and Write operation permissions to
      your selected game"* and it is not clear what that means for a user-account upload.
    - The design's step 7 calls it an *"IP Allowlist"*; the UI calls it **Accepted IP Addresses**
      behind a **Restrict IP addresses** toggle. `/32` is sound (the docs' own example is `/24`), and
      the docs never mention `0.0.0.0/0` — leaving the toggle off is the documented way to allow any
      IP.
    - The design's step 9 asserts the key *"is shown once"*. The docs say *"Copy and save the API key
      string to a secure location, not a public repository for your code"* and do **not** state
      single-display. Keep the behaviour, drop the claim.
    - **§11 source 1's "Bad" blames the wrong page.** It says the Open Cloud page *"says nothing about
      keeping the key secret — all of §8 is ours"*. The **api-keys** page says *"The API key string is
      equivalent to a password for your application. Never share it with untrusted parties"* and names
      public repositories explicitly. §8's discipline is **corroborated**, not invented. (The `setx` /
      PowerShell-history reasoning genuinely is ours, and it is good.)
12. **D12 — asset type names, and what is updatable.** Both **`Decal`** and **`Image`** accept `.png`
    with content type `image/png`, and `Enum.AssetType` has them as distinct items (`Image` = 1,
    `Decal` = 13) — so §7.6's "Decal-id-versus-Image-id trap" is real, the API lets you *choose*, and
    `Image` is the one to ask for when the id must go into `TextureID`. §7.4 step 1's multipart shape
    (`request` + `fileContent`, `type=model/fbx`) is **exactly right**. And updatability is narrower
    than the design or the map note says: *"Currently, you can only update the asset content for .fbx
    files. The update creates a new version."* — Decal / Image and Mesh are **not updatable**. So the
    manifest's `version` is meaningful only for FBX Models; a changed texture is a **new id**. The map
    note §9's *"a changed mesh is a new asset id"* is therefore half wrong for FBX Models.
13. **D13 — the moderation strings are wrong.** §7.7 keys on `moderationState = "Reviewing"` and
    `"Rejected"`. The documented value is prefixed: the example shows
    `"moderationState": "MODERATION_STATE_APPROVED"`. Match on the `MODERATION_STATE_` prefix and treat
    any unknown value as "not approved", rather than hard-coding two spellings. Also: the asset id at
    `response.assetId` is a **string** in the example, so the tool must coerce before printing a Luau
    number.
14. **D14 — PNG citation edition.** §11 source 6 says *"third edition, 2023"*. The current document at
    that URL is the third edition as a **W3C Recommendation of 24 June 2025**. The licence line is
    right in substance: W3C Software and Document Notice and License.
15. **D15 — Meshy: the licence is published, and the collision is nameable.** §11 source 7 declines to
    state it. Meshy Terms of Use (**last updated 19 September 2026**; the design's `meshy.ai/terms` URL
    is **404**, the live one is `meshy.ai/terms-of-use`) §3.2: on a **free plan Meshy owns the output**
    and grants **CC BY 4.0**; on a **paid plan** *"customers on a paid Meshy plan own their Customer
    Output."* CC BY 4.0 permits commercial use, so the design's instinct is right in outcome. What it
    did not have is the clause: CC BY 4.0 is **"non-sublicensable"** (§2(a)(1)), while Roblox's Creator
    Terms require a licence *"with the right to sublicense to any person or entity"* and require the
    Creator be *"the owner of or … fully authorized to grant rights in all parts of that UGC"*. Also
    §3.3: posting a model to Meshy's community page puts it under **CC0**; §2.9: Meshy may train on
    non-Enterprise inputs and outputs. `licenceNote` per row stays exactly right, and should quote the
    plan and the date. **Karen's call — see below.**
16. **D16 — the Creator Store licence has been read; record the route.** Creator Store Terms (updated
    2026-09-22) **§License**: *"By purchasing assets on the Creator Store, User is granted a license to
    use the asset in Roblox Studio and in Experiences on the Services consistent with the Roblox User
    and Creator Terms."* Both rules the map note derived stand on primary evidence now: **never commit
    a Creator Store asset**, **record provenance per row**. Two additions: the grant is written for
    **purchased** assets, so the free case rests on the Creator Terms share sentence (D9); and
    `docs/research/2026-09-24-map-generator.md` §8's *"I have not read the primary licence text"* can
    be closed, with the help-centre API route noted so the next session does not lose another page to a
    403.
17. **D17 — name the importer's own pivot and axis settings in §7.6 (minor).** The 3D Importer has
    *"If enabled, the Importer sets the pivot point of the entire model to the scene origin"* plus
    World Forward / World Up. Those are the **first** fix for a badly pivoted or rotated Meshy mesh,
    before §6.2's tolerance and §6.3's `rotationDeg`. Worth one sentence, because it moves a class of
    problem out of code and into a Studio dialog Karen already has to open on the fallback path.

## What could not be verified (rule 8)

- **Nothing here is measured in the engine.** No Studio, no harness, no `rojo` in this session. Every
  engine statement above is a documentation statement. The design's measurements **M1** (can Open Cloud
  take this FBX from this account), **M2** (now reframed by D5), **M3's second half** (does the colour
  map survive the import) and **M4** all still need the first build task.
- **Whether free Creator Store models are flagged "shared by the asset owner"** — the fact D9 turns on.
  Needs an engine and a real asset id.
- **Whether `InsertService:LoadAsset` works from the harness's `execute_luau` in Edit mode** — the map
  design's measurement C, still open.
- **Whether Studio's 3D Importer produces a `SurfaceAppearance` from an FBX's PBR maps** — the docs do
  not say.
- **What the API-key dashboard actually shows for an Assets key on a personal account** (D11): the
  docs' *"select the game"* step does not obviously apply, and only Karen's screen can settle it.
- **Roblox's per-minute rate limit for the Assets API** — not published, and explicitly may include
  *"additional, undocumented limits"*.
- **The Meshy / Roblox licence tension is stated, not resolved.** This note quotes the clauses; it is
  **not legal advice** and nobody in this workflow should treat it as such.
- `en.help.roblox.com` HTML pages are **403** to every tool here; they were read through the
  help-centre JSON API. If that route ever closes, those two licences become a Karen-with-a-browser
  task.

## What needs Karen

1. **The Meshy plan, and it should be answered now rather than at release.** Free-plan output is
   **owned by Meshy** and licensed **CC BY 4.0**, which is **non-sublicensable**, while publishing to
   Roblox grants Roblox a **sublicensable** licence and warrants she is *"fully authorized to grant
   rights in all parts"* of it. **Recommendation: a paid Meshy plan for anything that ships**
   (*"customers on a paid Meshy plan own their Customer Output"*), which makes the question disappear
   for the price of a subscription. If she stays on free: attribution per CC BY 4.0 §3(a)(1) — creator
   identification, copyright notice, licence notice, disclaimer notice and a link — must appear where
   the models do (the experience description), the suggested wording being *"Model created with Meshy –
   CC BY 4.0 License"*, and she should take the sublicensing question to someone qualified before
   monetising. Either way: **never post a Driven Hunt model to the Meshy community page** — that would
   publish it under **CC0**. Not legal advice.
2. **The API key, once** (design §8.1–§8.2) — still `NEEDS KAREN`, and now with corrected labels (D11).
   Two things to **report back** so this note can be fixed: what the **Access Permissions** step offers
   for an `assets` key on a personal account (is there a creator/user choice, or only "select the
   game"?), and whether the key is in fact shown only once.
3. **Which props are Creator Store** (§16 Karen 3) — now a narrower question than the design thought. A
   free Store model is usable and loadable only if its creator shared it (D9, D16). Anything she makes
   in Meshy herself has none of that problem. **Recommendation: Meshy for everything in §12.1, and
   treat Creator Store props as a later, separately-verified route.**
4. Unchanged from the design, and all needing her eyes rather than a number: does the boar look right;
   does the flash still read once textured; `ZONE_TINT` off or on; the gun's triangle budget.

## For the Director

- **D5, D6 and D9 change what M2.7a builds**, so they should be resolved into the dispatch (or into a
  short design amendment) before the Builder writes `Assets` / `Loader`. Everything else is labels,
  URLs and numbers and can ride along.
- The design's §16 A (**two tasks, not one**) looks better after this reading, not worse: 7a's risk is
  the upload, and D5, D12 and D13 all land in the upload half.
- Three corrections belong to **`docs/research/2026-09-24-map-generator.md`** rather than here: §9's
  21,000 triangles and 1024 texture cap (D1, D2), §9's "a changed mesh is a new asset id" (D12), and
  §8's "I have not read the primary licence text" (D16). And **`docs/design/map-generator.md` §8.2**
  needs D9. Recommend one small docs task rather than regenerating a 900-line design.
