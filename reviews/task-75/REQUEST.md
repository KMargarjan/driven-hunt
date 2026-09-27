# Task 75 — the barrels are not a mirror: the shine reaches Roblox

Task: 75
Round: 1
Base: `main` (`ab3dfa1`)
Code commit: `58b3069bd4ba3b32f74c549e033270de842a616b`

```
[harness] NOT RUN -- the Rojo plugin is disconnected (ESCALATE.md, 2026-09-27, NEEDS KAREN)
```

**This request is not reviewable yet and says so.** `src/` changed (the manifest's asset id), so the
gate needs a clean-tree `[harness] PASS` naming the code commit and a `[harness2] PASS` for the same
commit. I moved branches while `rojo serve` was live and the Studio plugin dropped its connection;
pressing **Connect** is a human click. Everything else in the task is finished and committed. One
harness run completes this file.

**What changed.** `tools/asset_prep_blender.py` and `tools/asset_prep.py` (the shine goes in the
maps; the export must carry them; one material), `src/serverstorage/Assets/init.luau` (a version 2
row for asset **103304840285660**, version 1 kept and marked superseded, `byKey` takes an optional
rows table), `tests/server/assets_seam.spec.luau` (two cases), `assets/uploads.json` (two rows, from
the tool), the research note and its index, `TASKS.md` rows 75/75a.

## Claims

1. **KAREN'S NUMBER NEVER REACHED THE ENGINE, AND THAT IS MEASURED.** `SurfaceAppearance` holds
   `ColorMap`, `MetalnessMap`, `RoughnessMap`, `NormalMap`, `AlphaMode` and `Color` — **maps and a
   tint, no scalars**. Task 72 round 2 moved the recipe's metalness and roughness out of the maps and
   onto Blender **materials**, so from then on they reached the four renders and nothing else. Asset
   `117134580332969` — the gun Task 74 shipped — read back in Studio carries Meshy's own maps, and
   the PNGs embedded in that upload measure **metalness 0.91, roughness 0.19**: a mirror, which is
   exactly what Karen and the Director saw. Verify: `docs/research/2026-09-27-roblox-pbr-shine.md`
   source 5, and the header of the shine block in `tools/asset_prep_blender.py`.

2. **WORSE, AND FOUND ONLY BY READING THE UPLOADED FILE BACK: no texture edit this tool has ever
   made had reached Roblox.** The FBX uploaded in Task 73 embedded the **untouched originals** — the
   4096 × 4096 metalness and roughness maps and the raw base colour — while the corrected 2048 maps
   sat unused in the output folder. An FBX-embedded texture arrives in Blender **packed**, and packed
   bytes beat anything written to disk, so `path_mode="COPY", embed_textures=True` embedded those. So
   the walnut and blued **colours** of Tasks 72–74 were never in the game either (74a/75a(a)).

3. **The fix is at the class, and the tool now proves the file carries its own work.** The recipe's
   per-region numbers are written **into the maps**, through the same feathered masks as the colour,
   with both maps forced to **Non-Color** first (glTF 2.0: these values "must be encoded with a
   linear transfer function"). Packed originals are unpacked and `image.filepath` repointed before
   export. `verify_embedded_textures` reads the exported FBX back and fails the run unless **every
   embedded PNG is byte-for-byte one the run wrote**. Verify: selftest checks *"every texture the run
   wrote is embedded in the FBX"* and *"the FBX embeds every one of them, and nothing else"*.

4. **Mutation-checked, twice, each applied, run and restored.** (a) `channelWeight` to 0 — the
   recipe's numbers stop reaching the maps — fails **3** checks, including the surface drift warning
   (`barrel metallic 0.00, wanted 0.10`). (b) The packed original left in place — the Task 73/74
   behaviour — fails **2**, naming `texture_baseColor.png` as the one that never reached the file.
   That second mutation is what identified the cause: the `image.filepath` line alone did not
   reproduce it.

5. **The numbers, and why they are those numbers** (research note, five sources, Roblox's own words
   quoted). Barrel **and rib** metalness **0.10** / roughness **0.50**: a metal at 1.0 has no diffuse
   colour at all — it shows only what it reflects, and in Roblox that is a bright sky, so the
   near-black albedo would never be seen; 0.50 spreads the sky into a broad sheen, which is gloss
   black rather than mirror or slate. Action **0.70 / 0.35** (still bright, no longer a sky-coloured
   blob). Wood **0.00 / 0.62** (an insulator; it shipped at 0.91 metalness, which is why the stock
   never looked like wood). `channelWeight` metalness 1.0, roughness 0.85; `maxShineDrift` 0.08.

6. **Measured back through the mesh, not through the mask that wrote it.** `REPORT["shine"]["surface"]`
   samples each region's triangles against the finished maps: barrel metalness **0.10** (drift 0.00)
   and roughness **0.452** (drift 0.048, the 15 % of the source map `channelWeight` deliberately
   keeps), action **0.70 / 0.322**, wood **0.00 / 0.586**. The same second route the colour check has
   used since Task 72 round 2 caught its mirrored mask.

7. **The old fear about painting the maps was measured and is not real at these values.** Task 72
   round 2 moved the numbers onto materials because painting them added edges to the previews; the
   run's own edge-density ratio against the untouched source is now **0.902 worst of four views** —
   below 1.0, so the prepped model has *fewer* edges than the source, not more.

8. **One material, not one per region.** Roblox builds a `SurfaceAppearance` per material **that has
   maps**: with the shine in the maps, the old three-way split came back from an upload as **four**
   SurfaceAppearance children, one carrying the maps and three empty (measured on asset
   140422686530548 — the first upload of this task, which is a dud for the reason in claim 2 and is
   recorded as such). The corrected upload has exactly one.

9. **The manifest keeps what it replaced (rule 7).** Version 2 carries `103304840285660`; version 1
   stays, with `supersededBy = 2` and a note saying what was wrong with it, because an id that has
   been in a place is provenance. `Assets.byKey` skips a superseded row, and takes an **optional rows
   table** so that rule can be tested rather than assumed — with the real data, "highest version" and
   "highest version that is not superseded" give the same answer. Verify: `assets_seam.spec`,
   `it("keeps the row it replaced, and hands out the new one")` and `it("skips a superseded row even
   when it is the newest one")`.

10. **Karen's OK covers this and nothing else.** Both uploads carry the argument she gave the
    Director verbatim — *"2026-09-26 Karen: put her shotgun in the game; this re-upload fixes the
    barrel shine she asked to fix"* — recorded in `assets/uploads.json` by the tool and quoted in the
    manifest row's licence. Same model, same geometry (Roblox handed back the **same MeshId**), new
    textures. **Two uploads happened, not one**, and the first is dead: it is recorded, not hidden.

## Screens — looked at, and one of them is not what I wanted

Rojo is disconnected, so the gun cannot be photographed **held**. Instead both assets were loaded in
the Edit place, scaled to exactly what the manifest scales them to (4.400 × 0.689 × 0.249 studs),
placed side by side in daylight (ClockTime 14.5), photographed and then removed.

- `.screenshots/20260927T003822Z-task75-old-side.png` — **version 1, the gun in the game today**: the
  barrels and the whole rib are **bright mirror silver**, brighter than the sky behind them. This is
  Karen's complaint, in one picture.
- `.screenshots/20260927T003841Z-task75-new-side-b.png` — **version 2, the sun-facing side**: the
  barrels are **near-black with a single thin highlight along the rib**, the stock and forend are
  warm reddish-brown walnut with the grain showing, and the action and trigger guard are light
  silver. This is what Karen asked for.
- `.screenshots/20260927T003817Z-task75-new-side.png` — **version 2, the shaded side, and it is worth
  saying plainly**: with the sun behind it the whole gun reads very dark — the stock is nearly black
  and the action is dark grey. Metalness 0.0 on the wood means it no longer borrows brightness from
  the sky, so the shaded side is genuinely darker than version 1's was. The barrels are right; whether
  the stock wants a lighter albedo is Karen's eye (75a).

## Not verified

- **No harness run, and no `test2`.** Blocked on the Connect click (`ESCALATE.md`).
- **The gun has not been seen held, or in ADS.** Both need the same click; the task asks for both and
  they are the first thing I will do.
- **Daylight at ClockTime 14.5 only**, and floating in the air rather than in the hands of a
  character under the drive's own lighting.
- **The colours are new to the game as of this upload** (claim 2), so the walnut and the silver have
  never been judged in-engine by anyone.
- **The GLB beside the FBX is not checked** by `verify_embedded_textures`; only the FBX, which is
  what is uploaded.
