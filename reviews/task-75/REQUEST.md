# Task 75 — the barrels are not a mirror: the shine reaches Roblox

Task: 75
Round: 2
Base: `main` (`ab3dfa1`)
Code commit: `9ccd0f3de240b4d3d6e3adccfdd9d626e6ca31c0`

```
[harness] PASS: 30/30 checks @ 9ccd0f3de240b4d3d6e3adccfdd9d626e6ca31c0 (clean tree)
```

`[tests:server] PASS: 404 passed, 0 failed, 0 skipped, 0 errors, 24 spec files`, client 85 passed.
`src/` changed again this round (`Assets.keysFor`, and the version 1 row's `texturePx`), so `test2`
is part of the gate; it is the Director's run and this file is updated with the `[harness2]` line for
the same commit before the review.

**Round 1's finding was right, and it was the sharpest kind: the guard this whole task rests on did
not bite.** `verify_embedded_textures` appended a warning, `command_prep` still printed `OK` and
exited 0, and three separate texts — the Blender-side comment, the research note and claim 3 — said
it failed the run. It does now, and the refusal reaches the one place that matters: the uploader.

**The Rojo plugin had dropped its connection** (I moved branches while `rojo serve` was live) and the
Director pressed **Connect**; the `ESCALATE.md` entry is closed. Worth one line, because it cost me a
wrong measurement first: a probe that `require`d `ServerStorage.Assets` reported the OLD row after the
reconnect, because **Studio's Edit-mode require cache is stale for a module required earlier in the
session**. Reading the ModuleScript's `Source` instead showed the new id and the new spec. The same
trap has now bitten this project three times.

**What changed.** `tools/asset_prep_blender.py` and `tools/asset_prep.py` (the shine goes in the
maps; the export must carry them, and a run that cannot prove it **fails**; one material),
`tools/roblox_upload.py` (refuses a failed prep), `src/serverstorage/Assets/init.luau` (a version 2
row for asset **103304840285660**, version 1 kept and marked superseded, `byKey` takes an optional
rows table, `keysFor` returns one key once), `tests/server/assets_seam.spec.luau` (three cases),
`assets/uploads.json` (two rows, from the tool), the research note and its index, `TASKS.md` rows
75/75a. Selftests **54** (asset-prep) and **36** (upload).

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

3. **The fix is at the class, and the tool now proves the file carries its own work — by failing.**
   The recipe's per-region numbers are written **into the maps**, through the same feathered masks as
   the colour, with both maps forced to **Non-Color** first (glTF 2.0: these values "must be encoded
   with a linear transfer function"). Packed originals are unpacked and `image.filepath` repointed
   before export. `verify_embedded_textures` reads the exported FBX back and, unless **every embedded
   PNG is byte-for-byte one the run wrote**, sets `report.ok = false` with the reason — which is the
   field `command_prep` exits on (**exit 1**, no `OK` line) and the field the uploader refuses on.
   Round 1 only appended a warning here, so the run still said OK: a guard that narrates is worse
   than no guard, because it reads like protection in a diff.

4. **THE FILE CANNOT REACH ROBLOX, not just the run cannot pass.** `tools/roblox_upload.py` calls
   `refuse_a_failed_prep(folder)` **first in `upload()`, before any bytes move**: it refuses a folder
   whose `report.json` says the run failed, and also one whose `embeddedTextures` do not line up,
   which is the same defect seen from the other end. A folder with **no** report is still allowed —
   that is the tool's older contract and the selftest's fixtures are exactly that — and the run says
   so out loud (`prep  no report.json beside the model…`). Verify: the four new upload-selftest
   checks, two refusals and two allowances.

5. **Mutation-checked three times, each applied, run and restored.** (a) `channelWeight` to 0 — the
   recipe's numbers stop reaching the maps — fails **3** asset-prep checks. (b) The packed original
   left in place — the Task 73/74 behaviour — fails **2**, and this round it was also run **for real
   on Karen's model**: `[asset-prep] FAILED: the exported FBX does not carry the textures this run
   wrote: 3 embedded PNG(s) match nothing written…`, **exit 1**, and
   `tools/roblox_upload.py` then refused that very folder — *"the prep run that produced this folder
   FAILED … do not upload this"*, **exit 2**. (c) The uploader not reading the report at all: the
   selftest's mocked sender fires, *"the network was touched: the refusal did not come first"*.

6. **The numbers, and why they are those numbers** (research note, five sources, Roblox's own words
   quoted). Barrel **and rib** metalness **0.10** / roughness **0.50**: a metal at 1.0 has no diffuse
   colour at all — it shows only what it reflects, and in Roblox that is a bright sky, so the
   near-black albedo would never be seen; 0.50 spreads the sky into a broad sheen, which is gloss
   black rather than mirror or slate. Action **0.70 / 0.35** (still bright, no longer a sky-coloured
   blob). Wood **0.00 / 0.62** (an insulator; it shipped at 0.91 metalness, which is why the stock
   never looked like wood). `channelWeight` metalness 1.0, roughness 0.85; `maxShineDrift` 0.08.

7. **Measured back through the mesh, not through the mask that wrote it.** `REPORT["shine"]["surface"]`
   samples each region's triangles against the finished maps: barrel metalness **0.10** (drift 0.00)
   and roughness **0.452** (drift 0.048, the 15 % of the source map `channelWeight` deliberately
   keeps), action **0.70 / 0.322**, wood **0.00 / 0.586**. The same second route the colour check has
   used since Task 72 round 2 caught its mirrored mask. **And the old fear about painting the maps
   was measured too**: Task 72 round 2 moved the numbers onto materials because painting them added
   edges to the previews, and the run's own edge-density ratio against the untouched source is now
   **0.902 worst of four views** — below 1.0, so the prepped model has *fewer* edges than the source,
   not more.

8. **One material, not one per region.** Roblox builds a `SurfaceAppearance` per material **that has
   maps**. Measured on asset 140422686530548 — the first upload of this task, and a dud for the
   reason in claim 2 — the three-way material split came back as **four** SurfaceAppearance children,
   one carrying maps and three empty; the maps it carried were the old ones, which is the dud part,
   and the four children are the split's doing either way. The corrected upload has exactly one.

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

## Screens — four, looked at, and they do not all flatter the change

**In Play, daylight (ClockTime 14.5), the gun the player is actually holding:**

- `.screenshots/20260927T005014Z-task75-held-turned.png` — **third person, held**. The gun hangs low
  across the character's front, pointing down and to the left: a **dark, near-black** forend and
  barrel with a dull sheen, and the stock dark over the shoulder. It is unmistakably not the bright
  silver of version 1 — and it is also a poor look at the gun, because the default carry never
  presents its flank to the camera (the same complaint as 71a(b) and 74a(d), not new here).
- `.screenshots/20260927T005018Z-task75-ads.png` — **ADS**. Looking straight down the gun: the
  **walnut stock** fills the lower frame with its grain, the standing breech and top lever above it
  read **blue-grey steel with visible engraving texture**, and two barrel mouths show as dark circles.
  **The barrels themselves are invisible at this angle** — they foreshorten into the breech — so this
  picture proves the gun is textured and says nothing about the shine. No untextured or purple
  surface anywhere.
- `…T005010Z-task75-held-thirdperson.png` is the same scene before the camera was turned, with the
  gun mostly behind the character.

**In Edit, both assets side by side** at exactly the size the manifest scales them to
(4.400 × 0.689 × 0.249 studs), same sky, then removed again — because this is the only view that
answers Karen's question properly:

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

- **A PLAYER WHO SPAWNS IN THE FIRST SECOND OF A SERVER GETS THE PARTS GUN AND KEEPS IT.** Measured
  here, twice: the server logged `[WeaponBoot] shotgun.handle loaded: model 103304840285660, 1 mesh
  part(s), 1227 ms`, and the Tool the player was holding had `BarrelLeft` and no `Model` — for two
  minutes, because nothing rebuilds a Tool that was granted before the template arrived. I took the
  gun away once, on the server, and the re-arm sweep handed back the mesh gun; **both Play
  screenshots were taken after that**, and they are honest about it. This is Task 74's ordering
  (`Weapon.start()` before `preload`, which is what round 2's finding asked for), not anything this
  task changed, and in a live server the boot finishes long before a player joins. Queued as 75a(h);
  it is a real defect and it is not mine to fix in this task.
- **`test2` is the Director's run**, at this branch's head; this file is updated with the
  `[harness2]` line for the same commit before the review. Round 1's pair was
  `[harness] 30/30` and `[harness2] 32/32` at `4bb0162`.
- **Daylight at ClockTime 14.5 only**, on the test arena's platform rather than in the wood under the
  drive's own lighting; dusk is unjudged.
- **The ADS picture cannot judge the barrels** (they foreshorten out of sight), and the third-person
  carry never shows the gun's flank. The Edit-mode pair is what carries the barrel claim.
- **The colours are new to the game as of this upload** (claim 2), so the walnut and the silver have
  never been judged in-engine by anyone, and the shaded side of the gun is now genuinely darker than
  version 1's.
- **The GLB beside the FBX is not checked** by `verify_embedded_textures`; only the FBX, which is
  what is uploaded. A `.glb` upload would therefore pass the guard without it having looked.
- **The uploader's refusal is proved on a real failed folder and on mocked reports**, never against
  the live API: nothing was uploaded this round.
- **Three review notes are queued, not fixed** (75a(i)–(k)): `Assets.byKey`'s signature no longer
  matches design §4.2, one sentence of Karen's OK now covers two asset ids, and the mutation runs
  left two prepped folders outside the repo.
