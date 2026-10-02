# Task 105 — Karen's chosen professional gun model replaces the exact-geometry gun

Task: 105
Round: 2
Base: `main` (`088274b`)
Code commit: `b257d6c257cfc4d1011490cc4849ce35d8b80d46`

```
[harness] PASS: 32/32 checks @ b257d6c257cfc4d1011490cc4849ce35d8b80d46 (clean tree)
[harness2] PASS: 34/34 checks @ b257d6c257cfc4d1011490cc4849ce35d8b80d46 (clean tree)
```

Round 1's finding was right and nothing in `src/`, `tests/` or `tools/` changed to answer it: the
frame that carries claim 4 was never described. It is described below, with pixels. Round 1's notes
are queued as `TASKS.md` row 105a.

Karen, 2026-10-02, on the exact-geometry gun: "bad". She picked "Double Barrel Shotgun" by Ryan_Nein
(CC-BY-4.0) and gave the upload OK. Behind `NEW_GUN`, which is still born OFF.

**PR #92 (carry tuning on the old gun) is obsolete after this** — the gun it tuned no longer exists.

## Claims

1. **The split is by NODE and the forend needed no cut.** `tools/gltf_split.py` (new, stdlib only,
   `selftest` = 17 checks) measures the gun's own axes off its geometry and writes one glTF per hinge
   group. The forend is `pasted__base_upper`, its own 60-triangle node — `probe` shows it below the
   bore line, spanning the breech forward. Verify: `python tools/gltf_split.py selftest`, then
   `probe --in <assets-dir>/model-b`.
2. **Both halves assemble at ONE CFrame.** Task 96's two anchor triangles, inward this time so the
   box is exactly the model's. Verify: `gun.spec` "are one mesh each…", "ship as two rows…", and
   `assets_seam.spec` "keeps the viewmodel's rows out of the server's preload".
3. **No shot number moved.** The model is scaled uniformly to `HANDLE_SIZE.Z`; `Gun.muzzle` is still
   on the Handle's axis; the bore line is the model's own. Verify: `gun.spec` "what a shot depends
   on", `gun_client.spec` "draws the muzzle flash on the model's own bore line" and "leaves the OLD
   gun's flash where it has always been".
4. **WHAT `.screenshots/20261002T101650Z-pose-aim.png` SHOWS, LOOKED AT (rule 5).** The aimed view,
   v2, the shipped build. The two barrels run from the lower-left corner up to the centre of the
   frame and read **dark blue-grey and matte**, with two thin lighter lines down them — the valley
   between the tubes and the crown of each tube. There is **no white anywhere on the gun**. The left
   glove (dark brown) and its olive sleeve are above the barrels, upper-centre; the right glove is
   the dark mass at the lower left. The barrels are not a mirror of anything.
   MEASURED, in the same 270×180 patch of each frame (the barrel pair), luma = 0.299R+0.587G+0.114B,
   against this frame's own sky at luma 177:

   | frame | what it was | barrels p50 | p90 | blue − red |
   |---|---|---|---|---|
   | `...100632Z` | v1, the artist's metalness 0.98 | 107 | 131 | +35 |
   | `...101019Z` | v1, `Material.Fabric` (no specular lobe) | 91 | 100 | +10 |
   | `...101650Z` | **v2, shipped** | **48** | **60** | +30 |

5. **WHY THE SHIPPED NUMBERS FIX IT, AND WHAT IS STILL ONLY MEASURED.** What shipped is the MAP
   route, not a material: metalness **0.10** and roughness **0.50** written into the two maps Roblox
   reads, plus the steel's base colour moved off the artist's pale RGB(154, 157, 157) onto blued
   RGB(34, 36, 42) (`asset_prep.py`'s `model-b-barrels` / `model-b-frame`). `ViewmodelAssetsBoot`
   leaves `Material` alone on purpose, so the MATERIAL is not part of the fix.
   The two rows above decompose it: taking the specular away and nothing else (the `Fabric` probe)
   moved the barrels 107 → 91, a sixth, but took the sky bias out — blue over red fell 35 → 10, and
   that bias IS the mirror signature. The rest of the drop, 91 → 48, is the albedo. So the metalness
   and roughness kill the reflection and the darker albedo supplies the colour the reflection used to
   fake; neither alone would have done it.
   **THE LIMIT, PLAINLY:** I did not isolate the two in the shipped build — one frame carries both —
   so "metalness 0.10 and roughness 0.50 are sufficient on their own" is **not** claimed. What is
   claimed is that the shipped combination reads dark blue-grey and matte at `...101650Z`.
6. **A CORRECTION TO ROUND 1, AND IT IS A FACT ABOUT A PROBE, NOT ABOUT THE SHIP.**
   `.screenshots/20261002T100928Z-pose-aim.png` — the `TextureID` + `SmoothPlastic` probe — has a
   barrel patch **identical to the untouched v1 frame to the first decimal in every percentile**
   (p10 85.0, p50 106.9, p90 131.3). Identical pixels mean that frame measured the same gun: the
   viewmodel rebuilds its clone from the published template, and it had almost certainly rebuilt
   between the write and the capture. So that probe says **nothing** either way, and two comments
   that cite it as "did NOT fix it" — in `tools/asset_prep.py`'s `MODEL_B_RECIPE` block and in the
   v2 row block of `src/serverstorage/Assets/init.luau` — overstate their evidence. Queued as 105a;
   they are code comments and this round is paperwork only. Nothing in the shipped behaviour rests
   on that step: the chain that does is v1 → `Fabric` probe → v2, in the table above.
7. **The exact geometry is archived, not kept behind a parameter.** Five of `Gun`'s answers would each
   have had to carry two geometries. The FALLBACK is a measured box per group instead, so an upload
   that did not load still leaves a gun. Verify: `backups/README.md`'s new row; `gun.spec` "still
   draws a gun when nothing was published".
8. **The CC-BY credit is in four places**, because it is the condition of using the model at all:
   `CREDITS.md`, each row's `licence.attribution` (one shared `MODEL_B_LICENCE`), each asset's own
   description on Roblox, and `assets/uploads.json`. Verify: `gun.spec` "ship as two rows of one
   model, at one size, with the author credited".

## What I could not verify

- **The carry pose is wrong for this gun** and I did not fix it: it now sits mostly off the left edge
  (`...101753Z-pose-carry.png`); my one nudge put the left glove over the gun instead (`...101822Z`).
  Content lane, the Director's live pass.
- **The reload pose is unchanged and still does not read like the target**
  (`...101848Z-compare-reload.png`): the gun opens away from the eye. Task 103/104's open problem.
- **The bead is too small to see** at the aim view's 3.7 studs. Nothing measures "visible".
- **Which of metalness/roughness and albedo carries how much of the fix in the SHIPPED build** —
  see claim 5. The decomposition above comes from a probe on v1, not from two v2 uploads.
