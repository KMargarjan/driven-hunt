=== BEGIN ASSET_RESULT ===
Task: 67
Round: 1
Key: boar.body v1
Run: boar.body_v1-20260926T1501Z   state: fetched, 35 credits, expires 2026-09-29T18:17:05Z
Credits spent for this inspection: 0 (no network call; files read from disk)

## The remeshed model, as far as it can be read without Studio
model.glb — **20,891,952 bytes (19.92 MiB)**, just under Roblox's 20 MiB per-call cap, and almost
all of it is three embedded PNGs rather than geometry.
**TRIANGLES: 6,188 — MEASURED, not declared.** Counted from the GLB's own index accessor
(`indices.count / 3`), stdlib only, no FBX parser. The record's `trisDeclared` is 6,000, so Meshy
came in **3.1% over target**. Comfortably inside Roblox's per-MeshPart limit.
This is worth recording against research note **D5** and the standing line "the triangle count is
DECLARED, never measured": that is true of the *remesh API response*, which carries no polycount,
but it is **not** true of the delivered GLB. The count is there and it is cheap to read.
1 mesh, 1 primitive, 1 material (`BakedMaterial`), carrying baseColorTexture, metallicRoughness-
Texture and normalTexture. Embedded images: `texture_0`, `texture_0_metallic_roughness`, `normal`.
Bounding box 1.9015 long × 1.0352 tall × 0.5528 wide → **1 : 0.544 : 0.291**. The brief's
sizeMetres is 1 : 0.545 : 0.364, so the **height ratio matches almost exactly** and the animal is
slimmer than its collision box — expected, since the box is a grey box, not art.
Files beside it: texture_base_color.png (6,736,271 B, 2048²), texture_normal.png (5,769,748 B,
2048²), texture_roughness.png (2,889,278 B, **4096²**), texture_metallic.png (1,693,016 B,
**4096²**), refine.png, preview.png, preview.glb, run.json. **No model.fbx** — correct since Task
67 made the GLB the deliverable (`MODEL_FILES` now leads with glb). The run's own validation is
`ok: true, problems: []`, with the two 4096 maps demoted to notes.

## What I could not verify
Anything needing Studio: import, material behaviour, scale in studs, how it looks in-engine. I did
not open Roblox. The colour finding from my earlier session stands and is unchanged by this
inspection: median albedo luminance 57/255, 54% of the textured surface under 60/255 — dark, with
no lighter flank, against a brief that asked for a paler grizzled flank.

## Needs Karen
Nothing new here. The open question is still the one from the refine: accept the dark coat and
lighten it downstream, or shoot a v2 from her reference photo.
=== END ASSET_RESULT ===
