# Roblox PBR: why a blued barrel came out chrome, and which number the engine actually reads

Task 75. Written before the code, as rule 1 requires.

## What the system must do

Karen's words about her own model, 2026-09-26: **"barrels too shiny … make more realistic"**. The
real Beretta 486 Parallelo has **gloss black blued barrels**. Task 72's Blender renders show exactly
that; the same model in Roblox daylight (Task 74's screenshots, which the Director looked at) shows
**bright silver barrels reflecting the sky**.

So the system must let a recipe say "this region is a dark, gently glossy metal" and have that
survive Blender → FBX → Open Cloud → `SurfaceAppearance` → a Roblox server at noon.

## Sources

1. **Roblox Creator Documentation — "Surface appearance"**
   <https://create.roblox.com/docs/art/modeling/surface-appearance> (read 2026-09-27).
   Licence: Roblox's documentation is published under **CC BY 4.0**
   (<https://github.com/Roblox/creator-docs>). Maintained continuously by Roblox.
   *Well:* it is the only authority on what Studio does with each map, and it says what the values
   mean in words a recipe can be written against:
   > "When roughness is at 0%, the surface doesn't scatter light at all, resulting in a much sharper
   > and brighter reflection and glossiness on your material. At 100%, light and reflections evenly
   > scatter over the model resulting in a less reflective matte-like surface."
   > "In most cases, you should set this value to either 0% (non-metal) or 100% (metal), although you
   > can use partial metalness values when creating surfaces with moderate reflective properties like
   > satin or silk."
   *Badly:* it never says what happens to a **material scalar** on import, which is the whole
   question this task turned on; and it gives no guidance about what a metal reflects when the only
   environment is a bright skybox.

2. **Roblox Creator Documentation — "Texture specifications"**
   <https://create.roblox.com/docs/art/modeling/texture-specifications> (read 2026-09-27). Same
   licence and maintenance.
   *Well:* it pins the format — metalness and roughness must be **"Single Channel Grayscale
   (8-bit)"**, which is what the prep writes.
   *Badly:* it lists the budget headings without the numbers, and says nothing about FBX vs glTF
   import differences.

3. **Roblox Engine API — `SurfaceAppearance`**
   <https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance> (read 2026-09-27).
   Same licence.
   *Well:* it is the definitive list of what the instance can hold: `ColorMap`, `MetalnessMap`,
   `RoughnessMap`, `NormalMap`, `AlphaMode`, `Color`. **Every one of them is a map or a tint. There
   is no metalness FLOAT and no roughness FLOAT anywhere on the instance.**
   *Badly:* the property table carries no prose at all, so it answers "what exists" and not "what it
   does".

4. **glTF 2.0 specification, Khronos Group** — `pbrMetallicRoughness`
   <https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html> (read 2026-09-27). Licence: Khronos
   specification copyright, free to implement. Maintained (2.0 is stable, errata ongoing).
   *Well:* it is where "metalness" and "roughness" are defined for every modern engine — the
   **green** channel is roughness and the **blue** channel is metalness, the factors are linear
   multipliers over the sampled texture, and the values "must be encoded with a linear transfer
   function". That last sentence is why the prep forces both maps to **Non-Color** before touching a
   pixel.
   *Badly:* it describes a format Roblox does not ingest directly here (the upload is FBX), so it
   explains the semantics and not the pipeline.

5. **Measured, in this project, because no document answered it** (Task 75, and the reason this note
   exists at all). Asset `117134580332969` — the gun shipped in Task 74 — read back in Studio:
   ```
   SurfaceAppearance ColorMap=91950944543455 MetalnessMap=90465645958960 RoughnessMap=96961706396039
   ```
   and the maps behind those ids were Meshy's own. Measured with PIL, and the two measurements are
   of different files, so both are kept: the prep's own output PNGs — the ones it believed it was
   shipping — read **metalness 0.98 / roughness 0.19**, and the 4096 originals actually embedded
   in the uploaded FBX read **0.91 / 0.19**. Either way a near-perfect mirror. The prep recipe at
   the time asked for metalness 0.30 and roughness 0.55 — on a Blender **material**, which Roblox
   has nowhere to put.

   Then, reading the uploaded FBX back byte by byte: its three embedded PNGs were Meshy's
   **untouched 4096 × 4096** metalness and roughness maps and the **untouched** base colour, while
   the corrected 2048 maps sat unused in the output folder. `image.filepath_raw` is where Blender's
   `save()` writes; an FBX-embedded texture arrives **packed**, and the packed bytes are the
   original ones, so `path_mode="COPY", embed_textures=True` embedded those.

## The pattern adopted, and why

**The shine lives in the maps, and the run proves the file carries them.**

- The recipe's per-region metalness and roughness are written **into the greyscale maps**, through
  the same feathered region masks the colour correction uses, and the materials read those maps. One
  place a shine number can live, and it is the place the engine looks. (Task 72 round 2 moved them
  out of the maps and onto materials because painting them put steps in the EEVEE previews; that
  made the previews prettier and the game wrong. Measured at the new values, the edge-density ratio
  is **0.90 — below 1.0**, so the fear was unfounded at these numbers.)
- The maps are forced to **Non-Color** before editing (source 4).
- Packed originals are **unpacked** before the corrected PNG is saved, and `image.filepath` is
  repointed at it.
- `verify_embedded_textures` reads the exported FBX back and fails the run unless **every embedded
  PNG is byte-for-byte one of the files the run wrote**. Two of the tool's own checks and one
  mutation cover it.
- One material, not one per region: Roblox builds a `SurfaceAppearance` per material that has maps,
  and the old split came back from an upload as **four** SurfaceAppearance children, three of them
  empty.

Borrowed rather than invented (rule 2): the values and their meanings come from sources 1 and 4; the
only invention is the per-region painting, which is the same masking machinery Task 72 already built
for colour.

## Numeric targets

| Region | metalness | roughness | why |
|---|---|---|---|
| barrel + rib | **0.10** | **0.50** | A metal at 1.0 has no diffuse colour at all: it shows only what it reflects, and in Roblox the only thing to reflect is a bright sky, so the near-black albedo would never be seen. 0.10 keeps a trace of the conductor tint. 0.50 spreads the sky into a broad soft sheen — gloss black, not mirror, and not the flat slate that 1.0 would give. |
| action, guard, lever | **0.70** | **0.35** | This is the part that is *meant* to catch the light. Bright polished steel with the engraving still readable, where the 0.91 / 0.19 that shipped made it a sky-coloured blob. |
| wood | **0.00** | **0.62** | Wood is an insulator: source 1's "0% (non-metal)". It shipped at 0.91 metalness, which is why the stock never looked like wood in daylight. |

Tolerances: `channelWeight` metalness **1.0** (replace outright — source 1 treats metalness as a
yes/no property), roughness **0.85** (keep 15 % of the generator's scratches). `maxShineDrift`
**0.08** in 0..1, measured by sampling the finished maps back **through the mesh**, which is a
different route from the mask that wrote them.

## What this note does not answer

- Whether Roblox's importer would take a metalness scalar from a **glTF** upload instead of FBX.
  Nothing here tested it; the manifest ships FBX.
- What a metalness of 0.10 looks like at dusk or under the drive's own lighting. The screenshots in
  this task are daylight only.
