# Research: headless Blender as an asset-prep step

Task 72. Written before the code (rule 1). Network was available and every source below was fetched
on 2026-09-26; where a page rendered to a fetcher as navigation only, that is said and the claim was
**measured locally instead**.

## What the system must do

Karen made a side-by-side shotgun in her own paid Meshy account through the web UI and dropped it in
`<assets-dir>/incoming/shotgun_solid_barrels_0926204042/`. Measured here (not taken on trust):
**1 mesh, 1 material, 19,325 triangles, 9,661 vertices, one UV map, bbox 2.000 x 0.113 x 0.313**
(long axis X), base colour 2048 x 2048 and metallic and roughness **4096 x 4096**, all three embedded
in the FBX. The shape is right — two barrels side by side, long barrels, walnut stock, splinter
forend, engraved action. The **colours are not**: Karen says the barrels are too shiny and too light
and the stock is too light and too orange.

So the tool has to:

1. bring 19,325 triangles down to a held-weapon budget and **report what it measured**, not what it
   asked for;
2. cut the single mesh into regions that can be coloured separately — and the hard part is that the
   barrels and the action are **both neutral grey in the same atlas**, so colour alone cannot
   separate them;
3. correct the base colour per region while keeping the grain and the engraving;
4. render previews a human looks at (rule 5);
5. export something Roblox's importer accepts;
6. **never modify the input** (rule 7) and never write inside the repo.

## Sources

### 1. Blender, and its licence
<https://www.blender.org/about/license/>
**Licence:** GNU GPL v2 or later. **Maintenance:** the version on this PC is **5.2.1 LTS**, build
date 2026-08-25.
**Good:** the page settles the two questions that matter for a public repo. Output: *"What you create
with Blender is your sole property. All your artwork -- images or movie files -- including the .blend
files and other data files Blender can write, is free for you to use as you like."* So the prepped
FBX, GLB and PNGs carry no obligation. Scripts: the Blender Foundation's position is that **Python
scripts written for Blender must be shared under a GPL-compatible licence if they are published**.
**Bad / what follows:** this repo is public and has **no LICENSE file**, so "GPL-compatible" is
undefined for it today. Handled by splitting the code in two, which is worth doing anyway:
`tools/asset_prep.py` is an ordinary driver that **never imports `bpy`** — it only spawns a process —
and `tools/asset_prep_blender.py` is the part that runs *inside* Blender and carries a
**GPL-2.0-or-later** header of its own. Whether the repo wants a LICENSE file is the Director's and
Karen's, and it is queued rather than decided here.

### 2. Blender's command line: `--background`, `--python`, and `--`
<https://docs.blender.org/manual/en/latest/advanced/command_line/arguments.html>
**Licence:** Blender manual, CC BY-SA 4.0. **Maintenance:** the 5.2 LTS manual, current.
**Bad, and said plainly:** this page renders to a fetcher as a navigation tree — twice, from two
URLs — so **nothing below is quoted from it**. The search index's summary says `-b`/`--background`
runs headless, `-P`/`--python` runs a script, and `--` ends option processing so the rest reaches the
script through `sys.argv`.
**So it was measured instead**, which this project trusts more than a citation:
`blender.exe --background --python probe.py -- hello` printed
`ARGV ['...blender.exe', '--background', '--python', 'probe.py', '--', 'hello']`, and the same run
reported `BLENDER 5.2.1 LTS`, `numpy 2.3.4` bundled, import operators `bpy.ops.import_scene.fbx` and
`bpy.ops.wm.fbx_import`, exporters `bpy.ops.export_scene.fbx` and `.gltf`, and **exactly one render
engine available in this build: `BLENDER_EEVEE`**. The tool is written against what that run showed.

### 3. Roblox mesh specifications
<https://create.roblox.com/docs/art/modeling/specifications>
**Licence:** `Roblox/creator-docs` source is CC BY 4.0. **Maintenance:** actively maintained.
**Good:** the one hard number this task is bounded by — *"Individual meshes can not exceed 20,000
triangles"* — and *"Roblox supports basic color textures and modern PBR textures"*.
**Bad:** the page gives no vertex, texture or file-size limit; those are on other pages (source 4).
**Adopted:** 20,000 is the ceiling, not the target. Karen's model is already inside it at 19,325, so
decimation here is about **draw cost on a held weapon**, not about legality: the default target is
**6,000 triangles**, which is what `tools/meshy.py` already asks Meshy for
(`docs/research/2026-09-26-meshy.md`), so the two routes into this game produce comparable weapons.

### 4. Roblox texture specifications
<https://create.roblox.com/docs/art/modeling/texture-specifications>
**Licence:** CC BY 4.0. **Maintenance:** actively maintained.
**Good:** *"Roblox supports up to 4096x4096 pixel texture resolutions (4K)"*; textures uploaded
separately must be *".png, .jpg, .tga, or .bmp"*; metalness and roughness are each *"Single Channel
Grayscale (8-bit)"* and normal maps are *"RGB (24-bit); Roblox only supports OpenGL format - Tangent
Space normal maps"*.
**Bad:** no file-size limit is stated here either (20 MB per upload is the number
`docs/research/2026-09-26-asset-pipeline.md` recorded from the Open Cloud side).
**Adopted:** 4096 is legal, so the tool **never fails** on Karen's 4096 maps — but a held weapon does
not need them, so the recipe carries `workPx` (default 2048) and the tool reports every size change
it made. Nothing is silently resized without it appearing in the recipe and the report.

### 5. `KhronosGroup/glTF-Blender-IO` — the exporter itself
<https://github.com/KhronosGroup/glTF-Blender-IO>
**Licence:** Apache-2.0. **Maintenance:** actively maintained; 6,322+ commits, CI on every commit,
and *"Blender 2.80 and higher bundle this addon in the main Blender install package"* — the copy in
use here is the one that shipped inside Blender 5.2.1.
**Good:** it is the official Khronos/Blender glTF importer and exporter, so `.glb` is a first-class
export from the same process that did the editing, with the textures packed in one file.
**Bad:** Roblox's own documentation names `.fbx`, `.obj` and `.gltf` and **not `.glb`** (recorded as
note D14 in `docs/research/2026-09-26-meshy.md`, and still unmeasured — row 67a(b): nobody has
imported a `.glb` into Studio).
**Adopted:** export **both**. FBX is the format Roblox documents and the one Karen's model arrived
in; GLB is one file with everything in it and is what the next tool along would rather read. Neither
is uploaded by this task.

## The pattern adopted, and why

**A thin driver plus a Blender-side script**, which is the shape `tools/mapgen.py` already has with
Studio: the driver validates, refuses, prepares and reports; the other side does the work in the host
application and hands back JSON.

- `tools/asset_prep.py` — stdlib only, never imports `bpy`. It resolves Blender, checks the input,
  refuses to write into the repo or over an existing output, **copies the input to the output's own
  `source/` folder and works from the copy**, writes the recipe, spawns Blender, then verifies the
  input folder is byte-for-byte what it was.
- `tools/asset_prep_blender.py` — runs inside Blender, GPL-2.0-or-later header, does the import,
  decimate, region split, texture correction, renders and exports, and writes `report.json`.

**Why the copy.** The first probe of Karen's FBX printed image paths inside a `...texture.fbm\`
folder **in her input directory** — Blender's FBX importer extracts embedded textures next to the
file. It turned out not to have written it (the images came back packed, and the folder does not
exist), but "it happened not to this time" is not a guarantee, and rule 7 is absolute. So the tool
never opens the original at all: it copies first, and then **proves** the original is untouched by
hashing every input file before and after and failing the run on any difference. That guard is worth
more than the assumption it replaces.

**Why regions are decided by position AND colour, in that order.** The barrels and the action are
both neutral grey in one atlas, so a colour rule alone merges them; the forend sits *under* the
barrels and shares their span along the long axis, so a position rule alone merges **it** with the
barrels. Neither is sufficient and the combination is:

1. a face whose sampled base colour is **woody** (saturation above a threshold, hue in a brown band)
   is `wood`, wherever it is — this catches the stock and the forend;
2. otherwise a face forward of `actionStartT` along the gun is `barrel`, and behind it is `action`.

`actionStartT` defaults to **0.62**, which is the 486 Parallelo's own barrel fraction (28 in of 45 in
overall — `docs/research/2026-09-26-shotgun-model.md`), so the number is the same published one the
grey-box gun is built from rather than a new invention.

**Which end is the muzzle is measured, not assumed.** The tool slices the model along its long axis
and compares the mean vertical extent of the first and last tenth: the muzzle end of a shotgun is
thin and the butt end is deep. The report says which end it picked, so a model that arrives reversed
is visible rather than silently colour-swapped.

**Correction keeps the detail because it is a per-pixel transform, not a fill.** Each region's UV
triangles are rasterised into a mask (dilated a few pixels, so a seam does not show the old colour),
and inside the mask the pixels are moved in HSV: the region's **median** value is mapped onto the
target value and every pixel keeps its ratio to that median, raised to a contrast exponent. Grain and
engraving are variation around the median, so they survive by construction. A flat fill would have
erased exactly what Karen liked about the model.

## The numeric targets

Sampled from Karen's own reference photographs (`<assets-dir>/references`, third-party images —
**looked at, never committed, and nothing but colour is taken from them**), ignoring the white studio
background, on the frame that shows barrels, action and stock together:

| Part | p25 | median | p75 |
|---|---|---|---|
| blued barrels | RGB(34, 35, 37) | RGB(82, 83, 85) | RGB(117, 117, 119) |
| engraved action | RGB(123, 127, 130) | RGB(172, 172, 172) | RGB(208, 210, 209) |
| walnut stock | RGB(100, 70, 59) | RGB(112, 80, 69) | RGB(119, 90, 84) |

Those medians include specular highlight, which an **albedo** map must not: a gloss black barrel is a
near-black surface with a bright reflection, not a mid-grey surface. So the recipe's barrel target
value is **0.12** (about RGB 31, the p25 reading) with roughness pushed down, the action target is
**0.68** (about RGB 174, the median), and the wood target is the measured **RGB(112, 80, 69)**
outright, which is both deeper and less orange than what Meshy produced — Karen's two complaints in
one number.

Everything above is the Director's pick and changeable (Karen's rule, 2026-09-26 — styling never
blocks): all of it lives in the recipe JSON, and the recipe is written into every output folder, so
any run can be repeated or dialled and re-run without editing code.

## What this note does not answer

- **Nothing is uploaded.** Karen's explicit OK is needed before anything reaches Roblox, and the
  Director asks her. The tool has no network code at all.
- Whether the decimation costs anything **visible** is rule 5's question: the four renders are part
  of the task and the answer is in the review request, not here.
- Whether Roblox's importer takes the `.glb` is still unmeasured (row 67a(b)).
