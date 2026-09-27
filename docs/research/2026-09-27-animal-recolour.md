# Research: recolouring a generated animal, and the packed map a GLB arrives with

Task 69. Written before the code (rule 1). Every source below was fetched or measured on
2026-09-27; where something was measured on this machine rather than read, it says so.

## What the system must do

Karen kept the refined boar (Director decision, 2026-09-26, answer "a"): run
`boar.body_v1-20260926T1501Z`, `model.glb`, 6,188 triangles, shape and proportions good. What is
wrong is the colour, and `tools/asset_prep.py` already exists to fix colour — it was built for
Karen's shotgun in Tasks 72 and 75. So this is not a new system; it is the second asset through an
existing one, which is the first honest test of whether that tool generalises.

Measured on the model itself before anything was decided (a throwaway Blender probe, the same
seven-sample-per-triangle median the tool classifies with):

| | measured |
|---|---|
| geometry | 6,188 triangles, one mesh `output_unwrapped`, one material `BakedMaterial` |
| bounding box | 0.553 x 1.902 x 1.035 — long axis **Y**, up **Z** |
| base colour | 2048², sRGB, whole-body median **sRGB(135, 128, 119)**, hue 32°, saturation 0.11, value 0.53 |
| metalness + roughness | **ONE 4096² image**, `texture_0_metallic_roughness`, feeding both Principled sockets |
| normal | 2048², separate |
| the snout | hue 20°, saturation 0.25, at the front tenth — farm-pig pink, and the inner ears share it |
| the tusks | hue 36°, saturation 0.35, value **0.90**, at 0.04–0.12 of the length from the head, spread 0.16–0.82 across the width (both sides: a pair, not one lit patch) |

Four jobs follow: accept a GLB, split a packed metalness-roughness map, decide regions on an ANIMAL
(where the gun's rule does not apply), and write the shine into the maps as Task 75 established.

**The Director's reading of "albedo median luminance 57/255" is the same number as the 135 above.**
57/255 = 0.224 is the **linear** median; through the sRGB transfer function that is 0.51, which is
sRGB 130. Both are right about the same pixels. It is worth writing down because this project has
lost a round to that confusion before (Task 22's albedo-times-ambient trap), and because the region
thresholds below had to choose one of the two spaces on purpose.

## Sources

1. **glTF 2.0 specification, `pbrMetallicRoughness`** — Khronos Group, royalty-free open standard,
   actively maintained (glTF 2.0 is the current version; the registry is updated in place).
   <https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-material-pbrmetallicroughness>
   *"The metallic-roughness texture. The metalness values are sampled from the B channel. The
   roughness values are sampled from the G channel. These values MUST be encoded with a linear
   transfer function."* — **Good**: it is unambiguous about which channel is which, which is the one
   fact the split turns on. **Bad**: it says nothing about what an importer does with the R channel
   (occlusion by convention, and Meshy leaves it at 1.0 — measured).
2. **Blender glTF 2.0 importer/exporter manual** — Blender Foundation, GPL, shipped with Blender and
   maintained with it. <https://docs.blender.org/manual/en/latest/addons/import_export/scene_gltf2.html>
   **Good**: confirms the importer builds a Principled BSDF and routes the packed texture through a
   Separate Color node — measured here and it does exactly that (Green → Roughness, Blue → Metallic).
   **Bad**: like the rest of the Blender manual (asset-prep note, same problem) the page renders to a
   fetcher as navigation, so the routing was **measured** rather than quoted.
3. **Roblox, "Surface Appearance"** — first-party, current.
   <https://create.roblox.com/docs/art/modeling/surface-appearance>
   *"In most cases, you should set this value to either 0% (non-metal) or 100% (metal)"*, and
   roughness *"At 100%, light and reflections evenly scatter over the model resulting in a less
   reflective matte-like surface."* — **Good**: settles the animal's shine without an opinion (hide
   and bristle are non-metal and matte). **Bad**: nothing about hair or fur specifically; Roblox has
   no hair shader, so a boar is a rough dielectric and that is that.
4. **Deutscher Jagdverband, *Schwarzwild* (wild boar) species page** — the national hunting
   association, the same body the drive note already cites for the safety rule; maintained.
   <https://www.jagdverband.de/wild-und-jagd/wildtierportraits/schwarzwild>
   **Good**: the coat is described as grey-brown to black with a paler, grizzled flank and darker
   legs — which is the three-band shape the recipe encodes, from a source about the animal rather
   than about a game. **Bad**: it is prose, not colour values; every number here is the Director's
   pick from the model's own texture, and Karen's to change.
5. **The repo's own `docs/research/2026-09-26-asset-prep.md` and `2026-09-27-roblox-pbr-shine.md`** —
   the existing decisions this note stands on and does not re-derive: regions by position AND
   colour, correction by moving the region's median, the shine lives in the MAPS, and the export
   must be proved to carry what the run wrote.

## What each approach does well and badly

**Deciding regions by colour alone.** Works for the tusks (gold against grey hide is a 25° hue island
nothing else on the animal occupies) and fails for the coat: the back and the flank are the same
colour on the source model — that is the defect. **Position alone** is the mirror image: it separates
back from flank cleanly and cannot tell a tusk from the muzzle it grows out of, because they are the
same few centimetres of the animal. Neither is enough, which is the same conclusion the gun reached
for different parts, so the fix is to stop writing the rule in Python and let the recipe carry an
ordered PLAN.

**Blurring the finished mask to soften a band boundary.** Tried and measured, and it is wrong: at 110
texels — the width a boar's saddle actually fades over — every region's mask covered the whole 2048
atlas, because a generator packs unrelated UV islands a few texels apart. The belly bled into the
back and the snout finished 59 off its target. Texture-space adjacency is not model-space adjacency.

**A soft band decided on the MODEL.** A face near a band's edge gets a partial weight in both bands,
and that weight is what is painted. Correct by construction — the ramp is a function of height, which
is a fact about the animal — and it costs one float plane per region at rasterise time.

## The pattern adopted, and why

1. **The region plan is data, in the recipe** — an ordered list, first match wins, with a final
   catch-all. Predicates: `axisFrom`/`axisTo` (along the long axis, from the front), `upFrom`/`upTo`
   (up the model), `hueFromDeg`/`hueToDeg`, `satMin`/`satMax`, `valueMin`/`valueMax`. The gun's old
   three lines of Python are now three rules that produce **the same three region counts to the
   triangle** (8,125 / 6,456 / 4,744, re-run and compared).
2. **`regionColorSpace`.** `image.pixels` is scene-linear for an sRGB-tagged map, and saturation is a
   different number in the two spaces — (max−min)/max on 0.9/0.6 is 0.33 in sRGB and 0.59 in linear.
   The gun's `satMin` 0.18 was measured against linear values and its output is proven; the boar's
   thresholds were read off its texture as colours, which is an sRGB reading. So the recipe says
   which, and neither asset has to be re-tuned for the other.
3. **`softUp` and `band` on a plan rule.** The ramp's bounds are written out rather than read off
   `when`, because under first-match-wins they are not the same thing (`flank` is written `upTo 0.62`
   and means 0.28–0.62), and because the catch-all has no `when` at all. A ramp may only reach faces
   that another SOFT band claimed — otherwise the flank's ramp, which is a function of height alone,
   covers the tusks at half the animal's height and paints coat colour over ivory.
4. **`valueSpread`, not a value ratio, for the coat.** Meshy bakes shadow and ambient occlusion into
   the base colour. A ratio correction keeps every pixel's distance from the median as a ratio, so
   moving the median down multiplies the already-dark pixels down too: the first run came back
   near-black from every camera (rule 5). `valueSpread` moves each pixel a fraction of its distance
   from the median instead. Same fix, same reason, as the gun's walnut; the vocabulary was already
   there.
5. **The packed map is split, not refused.** Two single-channel images, G → roughness and B →
   metalness per source 1, each linked to its own socket. The existing refusal — one datablock
   feeding both sockets — stays, because writing into a shared image silently overwrites the first
   value while every number in the report still reads back right.
6. **The split hands back its pixels, and the caller uses those.** A `bpy.data.images.new` datablock
   is GENERATED: its buffer is Blender's to free, and across the region and mask pass it comes back
   regenerated, which for a new image is black. Measured the hard way — the split was provably
   correct in isolation (roughness 0.6196, metalness 0.0000) and the run it was part of wrote a
   roughness map of zeros, with every number in the report agreeing with itself. That is this
   project's oldest failure shape and the selftest now fails on it.

## The numeric targets

sRGB, the Director's pick from the model's own texture, Karen's to change (styling never blocks).

| region | how it is chosen | base colour | roughness | metalness |
|---|---|---|---|---|
| `tusk` | front 22 %, hue 28–60°, sat ≥ 0.25, value ≥ 0.70 | 208, 199, 178 (dull bone) | 0.45 | 0 |
| `snout` | front 10 %; or front 22 % and hue 0–25° with sat ≥ 0.18 | 58, 55, 53 (near-black hide) | 0.55 | 0 |
| `underside` | lowest 28 % of the height | 86, 79, 72 | 0.88 | 0 |
| `flank` | 28–62 % | **158, 147, 130** | 0.85 | 0 |
| `back` | above 62 % | **104, 95, 84** | 0.88 | 0 |

The flank is **1.5x** the back's albedo: that step, not the absolute values, is what a hunter reads
at eighty metres, and it is the thing the model did not have. Nothing goes near black — Karen's brief
says it in her own words (*"The flanks must read LIGHT, not black: TASKS.md rows 18 and 24 both lost
a round to a dark albedo"*) and Task 22 measured why.

Bands blend over `softUp` 0.06 of the animal's height, about a hand's width on a live boar.
`channelWeight` stays 1.0 / 0.85: metalness replaced outright, roughness keeping 15 % of the
generator's own variation, which is where the bristle detail lives. Maps out at **2048**, down from
the 4096 the packed map arrived at.

## What this note does not settle

- **Whether these are the right colours** is Karen's eye at a playtest, not a measurement.
- **The band boundary is still slightly visible** in the side render as an irregular tonal break
  where the ramp crosses triangles. A ramp in the up-coordinate cannot follow a sloping back, which
  is what a real saddle does; a curve or a noise term would, and nothing here needs one yet.
- **Nothing is uploaded.** Karen's OK of 2026-09-26 covers her shotgun and one asset only
  (`tools/roblox_upload.py` records it per asset, deliberately). The boar reaching Roblox is a
  separate decision and a separate run.
