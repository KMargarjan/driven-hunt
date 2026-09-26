# Asset briefs — the one source

These are the inputs to `tools/meshy.py`: one JSON file per asset, carrying Karen's decisions about
what the model must be, plus the reference images they name. They are **data, not code**, and they
contain no path, no key and no email.

**`tools/meshy.py` reads this folder directly. There is no second copy** (Director decision,
`TASKS.md` row 55a(b), 2026-09-26). Task 55 kept a working copy in the drop folder as well, and two
copies of the file that decides what is generated and what is paid for is exactly the drift this
project keeps paying for — with the un-reviewable one being the copy the tool actually read.

Note the asymmetry, and it is deliberate: briefs are **read** from the repo, and everything the tool
**writes** — run records, previews, downloads — still goes outside it, into a folder the tool refuses
if it resolves inside the repository.

## The shape

`<key>_v<N>.brief.json`, where the key and version are **derived from the file name and never
prompted** (`docs/design/asset-pipeline.md` §4.3: *"a typo there becomes a manifest row and an asset
on Roblox that cannot be renamed"*). Required: `key`, `version`, `kind`, `prompt`, `sizeMetres`.
Optional: `references`, `targetTris`, `texturePx`, `notes`.

`references` names **0–4 image files in this folder**, by name and never by path. **PNG, JPEG and
WebP are accepted** (Director decision, row 55a(a)) — Meshy's docs list `.jpg, .jpeg, .png`, and
Karen's reference photographs are JPEG and WebP. Each is sent as a base64 data URI announcing its own
media type, so nothing needs public hosting.

**How many references decides the endpoint**, and it is data rather than a flag: 0 → text-to-3D,
1 → image-to-3D, 2–4 → multi-image-to-3D.

## Before it costs anything

    python tools/meshy.py brief <key>_v<N>              # validate; print what would be sent
    python tools/meshy.py preview <key>_v<N> --dry-run  # the exact request, nothing sent
