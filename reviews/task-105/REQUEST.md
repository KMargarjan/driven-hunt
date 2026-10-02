# Task 105 — Karen's chosen professional gun model replaces the exact-geometry gun

Task: 105
Round: 1
Base: `main` (`088274b`)
Code commit: `254987d339de1099beb7f8a8ad63b96605315e6c`

```
[harness] PASS: 32/32 checks @ 254987d339de1099beb7f8a8ad63b96605315e6c (clean tree)
[harness2] PASS: 34/34 checks @ 254987d339de1099beb7f8a8ad63b96605315e6c (clean tree)
```

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
   on the Handle's axis; the bore line is the model's own (±0.0388, not the drawn gun's ±0.076).
   Verify: `gun.spec` "what a shot depends on", `gun_client.spec` "draws the muzzle flash on the
   model's own bore line" and "leaves the OLD gun's flash where it has always been".
4. **The sky mirror was measured in the game, not argued.** v1 went in with the artist's metalness
   0.98 and the aimed capture was a WHITE mirror. Four steps (Decal, Workspace clone,
   `AlphaMode.Transparency`, `TextureID`, then `Material.Fabric`) say the defect is the specular
   response; v2 writes metalness 0.10 / roughness 0.50 and darkens the steel's albedo, per group.
   Verify: the `Assets.ROWS` comment above the v2 rows names every screenshot; `asset_prep.py`'s
   `model-b*` presets hold the numbers; `.screenshots/20261002T101650Z-pose-aim.png` is the result.
5. **The exact geometry is archived, not kept behind a parameter.** Five of `Gun`'s answers would each
   have had to carry two geometries. The FALLBACK is a measured box per group instead, so an upload
   that did not load still leaves a gun. Verify: `backups/README.md`'s new row; `gun.spec` "still
   draws a gun when nothing was published".

## What I could not verify

- **The carry pose is wrong for this gun** and I did not fix it: the numbers were tuned for the old
  one, and it now sits mostly off the left edge (`...101753Z-pose-carry.png`); my one nudge put the
  left glove over the gun instead (`...101822Z`). Content lane, the Director's live pass.
- **The reload pose is unchanged and still does not read like the target** (`...101848Z-compare-reload.png`):
  the gun opens away from the eye. That is task 103/104's open problem, not this task's.
- **The bead is too small to see** at the aim view's 3.7 studs. Nothing measures "visible".
