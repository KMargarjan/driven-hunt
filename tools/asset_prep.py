"""Driven Hunt asset prep: take a model somebody made, make it usable, and never touch the original.

It drives **headless Blender** (`--background --python`) with `tools/asset_prep_blender.py` and does
the five things a raw generated model needs before it can be a weapon in this game:

  (a) DECIMATE to a held-weapon budget, and report the count it MEASURED rather than the one it asked
      for (Roblox's own ceiling is 20,000 triangles per mesh, so this is about draw cost, not
      legality);
  (b) SPLIT the single mesh into regions BY A PLAN IN THE RECIPE -- position along the long axis,
      position up the model, and texture colour -- because no single cue separates the parts of a
      real model: the barrels and the action are both neutral grey in one atlas (position separates
      them) while the forend shares the barrels' span (only colour does), and on an animal the gold
      tusks and the pink snout share the head end (only colour) while the back and the flank share
      the coat's colour (only height);
  (c) COLOUR-CORRECT each region's pixels in HSV, moving the region's MEDIAN onto a target and
      keeping every pixel's ratio to it -- so the grain and the engraving survive, which a flat fill
      would erase;
  (d) RENDER four previews a human looks at (rule 5), also from the recipe: the gun is photographed
      side, top, muzzle and three-quarter, the animal side, front, top and three-quarter;
  (e) EXPORT `model.fbx` and `model.glb`.

THE INPUT MAY BE `.fbx` OR `.glb`/`.gltf` (Task 69). Meshy hands back a GLB for a refined model and
an FBX for some others, and the difference is the container, not the work. One thing does change with
it and it is not cosmetic: **glTF packs metalness and roughness into ONE image** (occlusion in R,
roughness in G, metalness in B), so both Principled sockets are fed by the same datablock. This tool
writes a number into each map and cannot write two into one -- it used to refuse such a model
outright -- so a packed map is now SPLIT into two single-channel maps before anything is written, and
the report says it happened.

THIS FILE NEVER IMPORTS `bpy`. It spawns a process, so it carries the repository's terms;
`tools/asset_prep_blender.py` runs inside Blender and carries GPL-2.0-or-later, which is what the
Blender Foundation asks of a published script written for Blender. See the research note.

Usage:
  python tools/asset_prep.py probe --in <folder>                      # read-only: what is in there
  python tools/asset_prep.py prep --in <folder> --out <folder>        # the run
        [--preset gun|animal] [--recipe <file.json>] [--model <name>]
        [--target 6000] [--work-px 2048] [--dry-run]
  python tools/asset_prep.py recipe [--preset gun|animal]             # print a preset recipe
  python tools/asset_prep.py selftest                                 # offline, no input needed

Exit codes, the harness's shape: 0 done - 1 the run failed - 2 REFUSED before anything happened.

WHAT IT REFUSES, BEFORE IT TOUCHES ANYTHING:
  1. No Blender. `BLENDER_EXE` in the environment wins; otherwise the usual install locations are
     searched. A missing Blender is a refusal, never a silent skip.
  2. An input folder with no model in it (or no such folder). `.fbx` wins over `.glb` over `.gltf`
     when several are there, shortest path first, and the run SAYS which file it opened --
     `--model <name>` picks one by name when a folder holds a preview beside the real thing.
  3. An output path INSIDE the repository. Everything this tool writes is generated and some of it is
     large binary; the repo takes neither (`.rbxm` is banned outright, CLAUDE.md).
  4. An output folder that already exists and is not empty. Nothing is ever overwritten and nothing
     is ever deleted (rule 7): a second run wants a second folder.

THE INPUT IS COPIED, NOT OPENED. Blender's FBX importer extracts embedded textures into a `.fbm`
folder NEXT TO THE FILE it reads. On Karen's shotgun it happened not to (the images came back
packed), but "it did not this time" is not a guarantee. So the tool copies the input into the output
folder's own `source/` and works from the copy -- and then PROVES the original is untouched by
hashing every file before and after and failing the run on any difference, including a new file
appearing. That guard is the point; the copy is just how it is kept true.

THE RECIPE IS THE RUN. Every number the Blender side uses -- the triangle target, the region split,
the colour targets, the render size -- comes from one JSON document, and that document is written
into the output folder next to the results. A run is repeatable from its own output, and a colour
Karen wants changed is a number in a file rather than an edit to this program.

A PRESET IS A RECIPE WITH A NAME, and the names are `gun` and `animal`. Both live in this file, so
the numbers that decide what an asset looks like are reviewed as a diff rather than carried in a
loose JSON file nobody reads; `--recipe <file.json>` still overrides any of them.

Colours: the gun's were sampled from Karen's own reference photographs of the real gun; the animal's
are the Director's pick from the boar's own textures. Both are changeable (Karen's rule, 2026-09-26:
styling never blocks).

NO NETWORK, EVER. This file has no HTTP client and nothing in it uploads. A model reaching Roblox is
Karen's explicit decision and a different tool.

Note: docs/research/2026-09-26-asset-prep.md
"""

import argparse
import datetime
import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER_SCRIPT = os.path.join(REPO, "tools", "asset_prep_blender.py")
TOOL_VERSION = "asset-prep/1"

# Where Blender usually is on this kind of machine. `BLENDER_EXE` overrides all of it, and nothing
# here is a user path, so the public-repo scan has nothing to find.
BLENDER_CANDIDATES = (
    r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe",
    r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
    r"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe",
    "/usr/bin/blender",
    "/usr/local/bin/blender",
)

# THE DEFAULT RECIPE. Every value is either measured (see the note) or a stated taste pick.
DEFAULT_RECIPE = {
    "tool": TOOL_VERSION,
    # NO DECIMATION BY DEFAULT, and that is a decision taken by looking (rule 5, round 2).
    #
    # Roblox's own limit is "Individual meshes can not exceed 20,000 triangles"
    # (https://create.roblox.com/docs/art/modeling/specifications), and Karen's shotgun arrives at
    # 19,325 -- already legal. Decimating it to 6,000 was measured and photographed: the colours and
    # the edge metric hold up, but the wrist of the stock facets visibly and the join between the
    # barrels and the forend grows black wedges, because a decimated face that straddles two regions
    # can only take one region's colour. Shipping what arrived costs nothing and loses nothing.
    #
    # `--target N` still decimates when a caller asks, and the report always says which happened. A
    # genuinely cheap low-poly wants the standard route -- unwrap the low-poly and BAKE the
    # high-poly's colour onto it -- which is a task of its own (TASKS.md row 72a).
    "targetTriangles": None,
    # 4096 is legal on Roblox and wasteful on a held weapon. Nothing is resized silently: the report
    # prints every size before and after.
    "workPx": 2048,
    "renderPx": 1100,
    "renderSamples": 32,
    "maskDilatePx": 4,
    # WHICH SPACE THE PLAN'S COLOUR THRESHOLDS ARE READ IN. "linear" is what this tool has always
    # used -- `image.pixels` is scene-linear for an sRGB-tagged map -- and the gun's `satMin` 0.18
    # was measured against those values in Tasks 72 and 75. An asset whose thresholds were read off
    # a picture wants "srgb" instead; saturation is a different number in the two spaces.
    "regionColorSpace": "linear",
    # WHICH END IS THE FRONT. `None` means MEASURE it (`long_axis`: the end whose cross-section is
    # shallower is the gun's muzzle). An animal is not shaped like that -- a boar is thin at the
    # snout and thin at the tail -- so a recipe may state it instead, and the report always prints
    # both what was measured and what was used.
    "frontAtMin": None,
    # Rounds of neighbour-majority voting over the face map. A per-triangle rule is speckle, and
    # speckle is patches in the finished texture; three rounds drown out isolated mistakes without
    # eating a real boundary, which is many triangles wide.
    "regionSmoothRounds": 3,
    # How many faces may still disagree with every neighbour before the run says so.
    "maxRegionSpeckle": 0.01,
    # How far a region's colour, SAMPLED BACK THROUGH THE MESH, may sit from the colour it was
    # given, per channel of 255. Wide, because grain is variation; narrow enough that a mask landing
    # on the wrong part of the atlas fails it.
    "maxSurfaceDrift": 45,
    # Render the untouched source at the same four cameras, so every run carries its own before
    # picture and the numbers below are a comparison rather than an opinion.
    "renderSource": True,
    # How much harder the prepped model's edges may get before the run says the texture was broken
    # up rather than recoloured. 1.0 is "no change"; round 1 would have been caught by this.
    "maxEdgeDensityRatio": 1.25,
    # Texels of soft edge on every region mask. A hard mask paints a triangle-shaped step into the
    # texture; this turns it into a ramp. 0 restores round 1's hard edges.
    "maskFeatherPx": 6,
    # THE REGION PLAN: an ordered list, FIRST MATCH WINS, and the last entry has no `when` and is
    # therefore the "everything else" (the run fails without one, because a face with no region is a
    # face nobody decided about).
    #
    # Every predicate that is present must hold. `axisFrom`/`axisTo` are the fraction along the long
    # axis measured FROM THE FRONT (the muzzle here), `upFrom`/`upTo` the fraction up the model,
    # `hueFromDeg`/`hueToDeg` (wrap-aware), `satMin`/`satMax`, `valueMin`/`valueMax` the colour
    # sampled off the base texture at the face's own UV footprint. `From` is inclusive and `To` is
    # exclusive, so bands can be written back to back without overlapping.
    #
    # THIS IS THE GUN'S OLD RULE, WRITTEN OUT AS DATA rather than as three lines of Python: wood is
    # whatever is woody-coloured wherever it sits (the forend shares the barrels' span), then
    # everything in front of 0.62 of the length is barrel, then the rest is the action. 0.62 is the
    # real 486 Parallelo's barrel fraction (28 in of 45 in), the same published number the grey-box
    # gun in src/server/Weapon/Shape.luau is built from. Task 69 re-ran Karen's gun through the new
    # engine and got the same three region counts to the triangle.
    "regionPlan": [
        {"name": "wood", "when": {"satMin": 0.18, "hueFromDeg": 5.0, "hueToDeg": 60.0}},
        {"name": "barrel", "when": {"axisTo": 0.62}},
        {"name": "action"},
    ],
    # THE FOUR QUESTIONS THIS ASSET IS PHOTOGRAPHED TO ANSWER, as data too: does it read as a gun
    # from the side, are the two barrels side by side from above and from the muzzle, and does it
    # hold together in three-quarter. `distanceSpan` and `orthoSpan` are multiples of the model's
    # longest dimension; `orthoCross` is a multiple of the larger of the two dimensions ACROSS the
    # view direction, which is what frames a model seen end-on. No `orthoSpan` or `orthoCross` means
    # a perspective camera.
    "views": [
        {"name": "side", "dir": [0.0, -1.0, 0.06], "distanceSpan": 1.2, "orthoSpan": 1.08},
        {"name": "top", "dir": [0.0, -0.02, 1.0], "distanceSpan": 1.2, "orthoSpan": 1.08},
        # STRAIGHT DOWN THE BARRELS, and far enough back that the near end is not clipped: at half a
        # span the camera stood ON the muzzle and the render showed the middle of the gun.
        {"name": "muzzle", "dir": [-1.0, -0.015, 0.02], "distanceSpan": 1.3, "orthoCross": 2.8},
        {"name": "three-quarter", "dir": [-0.7, -1.0, 0.38], "distanceSpan": 0.75},
    ],
    "regions": {
        # EVERY targetRGB IS AN sRGB TRIPLE MEASURED OFF KAREN'S OWN REFERENCE PHOTOGRAPHS, and the
        # Blender side converts it to scene-linear before it touches a pixel -- the first run applied
        # these numbers straight to linear pixels and the gun came back white and orange.
        #
        # BLUED STEEL IS NEAR-BLACK WITH A SLIGHT BLUE, AND IT IS NOT A MIRROR. RGB(26, 28, 34) is
        # the p25 of the barrels in Karen's photo, cooled by six points of blue. An albedo must not
        # carry the specular highlight that pulls the photo's median to RGB 82: the gloss comes from
        # roughness, not from a lighter colour. This region is the barrels AND the top rib, which are
        # one span of the model and one material on the real gun.
        #
        # THE TWO NUMBERS THAT DECIDE "GLOSS BLACK" RATHER THAN "CHROME" ARE THESE, and since Task 75
        # they are written into the metalness and roughness MAPS, which is the only channel Roblox
        # reads (see the long comment in asset_prep_blender.py; the maps that shipped in Task 74 said
        # metalness 0.91 / roughness 0.19 and the barrels came out mirror silver in daylight --
        # 0.98 was the prep's own output PNG, which never reached the upload at all).
        #   metallic 0.10 -- a metal at 1.0 has NO diffuse colour at all: it shows only what it
        #     reflects, and in Roblox daylight that is the sky, so the near-black albedo above would
        #     never be seen. 0.10 keeps a trace of the conductor tint and lets the dark colour do the
        #     work. The Roblox docs ask for 0% or 100% "in most cases"; this is the deliberate
        #     exception they allow for "moderate reflective properties", chosen because the sky is
        #     the only environment a Roblox surface has to reflect.
        #   roughness 0.50 -- half way. At 0.19 (what shipped) the reflection is "sharper and
        #     brighter"; at 1.0 it is flat matte and the gun looks like slate. 0.50 spreads the sky
        #     into a broad soft sheen along the barrel: gloss, not mirror.
        # Karen's words, 2026-09-26: "barrels too shiny ... make more realistic".
        "barrel": {
            "baseColor": {"targetRGB": [26, 28, 34], "keepHue": True, "satScale": 0.25,
                          "contrast": 1.0},
            "roughness": 0.50,
            "metallic": 0.10,
        },
        # BRIGHT SILVER ENGRAVED ACTION, GUARD AND LEVER: RGB(172, 172, 172), the median of the
        # action in the same photo. A little saturation is kept so the engraving does not go flat.
        # It STAYS metal -- this is the part that is meant to catch the light, and Karen's complaint
        # was the barrels -- but not a mirror: 0.70 / 0.35 is bright polished steel with the engraving
        # still readable, where the 0.91 / 0.19 that shipped made the whole action a sky-coloured
        # blob. It is the same class of change as the barrels and it lands in the same maps.
        "action": {
            "baseColor": {"targetRGB": [172, 172, 172], "keepHue": True, "satScale": 0.10,
                          "contrast": 1.05},
            "roughness": 0.35,
            "metallic": 0.70,
        },
        # MEDIUM WALNUT, deeper and less orange than what came out of Meshy -- Karen's two complaints
        # in one number: RGB(112, 80, 69) is the median of the stock in her reference photo.
        "wood": {
            # KEEP THE SOURCE GRAIN; SHIFT IT, DO NOT REBUILD IT (Director, round 2). The levels
            # mapping round 1 used clipped everything outside the 5th and 95th percentile onto two
            # flat values, which turned Meshy's baked figure into hard black patches. This is the
            # gentle version: the median moves onto medium walnut, each pixel keeps its relation to
            # the median (contrast 1.0 = unchanged), and only the saturation spread is compressed a
            # little so the orange does not clip.
            "baseColor": {"targetRGB": [112, 80, 69], "contrast": 1.0, "satSpread": 0.6},
            "roughness": 0.62,
            "metallic": 0.0,
        },
    },
    # HOW MUCH OF THE SOURCE MAP SURVIVES, per channel. Metalness is a yes/no property of a material
    # and the Roblox docs say to treat it as one, so it is replaced outright; roughness carries the
    # generator's scratches and wear, which are worth keeping, so 15 % of the original variation is
    # left in. 0 would leave the shipped maps exactly as Task 74 shipped them.
    "channelWeight": {"metallic": 1.0, "roughness": 0.85},
    # How far a region's metalness or roughness, SAMPLED BACK THROUGH THE MESH, may sit from the
    # number it was given (0..1). Tight, because unlike colour there is no grain to allow for -- the
    # only reasons to miss are a mask in the wrong place or a number that never reached the map,
    # which are the two failures this whole task is about.
    "maxShineDrift": 0.08,
}


# THE ANIMAL PRESET (Task 69). Karen kept the refined boar and asked for its COLOURS to be fixed --
# the shape and the proportions are hers already (Director decision, 2026-09-26, run
# boar.body_v1-20260926T1501Z: 6,188 triangles, keep).
#
# WHAT WAS WRONG, and all four were looked at before a number was chosen (rule 5):
#   * the whole body is one dark slate grey -- a wild boar is grizzled grey-brown and its FLANK is
#     paler than its back, which is the shape a hunter reads at 80 m;
#   * the snout is farm-pig PINK (measured on the model: hue 20 deg, saturation 0.25, at the front
#     end) -- a wild boar's is near-black;
#   * the tusks are GOLD/BRASS (hue 36 deg, saturation 0.35, value 0.90) -- ivory is dull bone-white;
#   * metalness and roughness arrive as one 4096 map and ship at 4096.
#
# EVERY NUMBER BELOW WAS MEASURED OFF THIS MODEL FIRST (the medians are in the report):
#   whole body median sRGB(135, 128, 119), hue 32 deg, saturation 0.11, value 0.53;
#   the coat's bands then move that median per band -- back 104, flank 158, belly and legs 86 --
#     so the flank is 1.5x the back's albedo, which is the step a hunter reads at distance;
#   the head end is at the MINIMUM of the long axis -- the tusks (the one unambiguous colour on the
#   animal) sit at 0.04-0.12 of the length from that end, so `frontAtMin` is stated rather than
#   measured, because the "shallower end is the front" rule is about a gun and a boar is thin at
#   both ends.
#
# The colours are the Director's pick and Karen's to change (her rule: styling never blocks).
ANIMAL_RECIPE = {
    "tool": TOOL_VERSION,
    # 6,188 triangles against Roblox's 20,000 per mesh: nothing to gain by decimating, and a
    # decimated face that straddles two regions can only take one region's colour (see the gun).
    "targetTriangles": None,
    "workPx": 2048,
    "renderPx": 1100,
    "renderSamples": 32,
    "maskDilatePx": 4,
    # EIGHT ROUNDS, NOT THREE, AND THE FIRST RENDER IS WHY (rule 5). The gun's regions meet at a
    # machined join and three rounds is plenty; an animal's bands meet in the middle of a flank,
    # where the boundary follows whichever triangles happened to straddle the height, and at three
    # rounds it came out as a hard SAWTOOTH running the length of the body -- visible from every
    # camera and obviously artificial. More rounds of majority voting straighten it.
    "regionSmoothRounds": 8,
    "maxRegionSpeckle": 0.01,
    "maxSurfaceDrift": 45,
    "renderSource": True,
    "maxEdgeDensityRatio": 1.25,
    "maskFeatherPx": 6,
    # sRGB, because every threshold below was read off this model's own texture as a colour --
    # hue 36 degrees, saturation 0.35, value 0.90 for the tusks -- which is an sRGB reading.
    "regionColorSpace": "srgb",
    # MEASURED, THEN STATED: the tusks are at the low end of the long axis. See above.
    "frontAtMin": True,
    # FIRST MATCH WINS, so the two colour rules run before the three height bands: the tusks and the
    # snout are at the head end and would otherwise be swallowed by whichever band they sit in.
    "regionPlan": [
        # GOLD, AT THE HEAD. Colour alone would also catch warm highlights along the back, and
        # position alone would catch the whole muzzle; together they are the tusks and nothing else
        # (144 faces of 6,188, at 0.16-0.82 across the width -- both sides, which is the check that
        # this is a pair of tusks rather than one lit patch).
        {"name": "tusk", "when": {"axisTo": 0.22, "hueFromDeg": 28.0, "hueToDeg": 60.0,
                                  "satMin": 0.25, "valueMin": 0.70}},
        # THE PIG-PINK MUZZLE: the front tenth of the animal, plus anything pink further back on the
        # head (the inner ears are the same pink on this model, and a wild boar's are not).
        {"name": "snout", "when": {"axisTo": 0.10}},
        {"name": "snout", "when": {"axisTo": 0.22, "hueFromDeg": 0.0, "hueToDeg": 25.0,
                                   "satMin": 0.18}},
        # THE COAT, IN THREE BANDS UP THE ANIMAL. A boar is dark along the spine, pale down the
        # flank and dark again underneath -- belly and legs. The bands are back-to-back fractions of
        # the height, so every face lands in exactly one.
        # `band` and `softUp` are the ramp, and they are written out rather than read off `when`:
        # under first-match-wins `flank`'s `upTo 0.62` means 0.28 to 0.62, and the catch-all has no
        # `when` at all. 0.06 of the animal's height is about 6 cm on a live boar -- a hand's
        # width, which is what the saddle actually fades over.
        {"name": "underside", "when": {"upTo": 0.28},
         "band": {"upTo": 0.28}, "softUp": 0.06},
        {"name": "flank", "when": {"upTo": 0.62},
         "band": {"upFrom": 0.28, "upTo": 0.62}, "softUp": 0.06},
        {"name": "back", "band": {"upFrom": 0.62}, "softUp": 0.06},
    ],
    # SIDE is the shape a hunter sees; FRONT is the one view that shows the snout and both tusks at
    # once, which is what this task is about; TOP shows the back-to-flank break; THREE-QUARTER is
    # the sanity check that it still reads as one animal. The long axis is the boar's length, so
    # "side" looks across it and "front" looks down it from the head end.
    "views": [
        {"name": "side", "dir": [-1.0, 0.0, 0.06], "distanceSpan": 1.2, "orthoSpan": 1.08},
        {"name": "front", "dir": [0.0, -1.0, 0.04], "distanceSpan": 1.3, "orthoCross": 1.35},
        {"name": "top", "dir": [0.0, -0.02, 1.0], "distanceSpan": 1.2, "orthoSpan": 1.08},
        # FURTHER BACK THAN THE GUN'S. At 0.8 the perspective camera stood inside the animal and the
        # render was a close-up of one shoulder (rule 5, the first run).
        {"name": "three-quarter", "dir": [-0.7, -1.0, 0.38], "distanceSpan": 1.7},
    ],
    "regions": {
        # THE COAT KEEPS ITS OWN HUE AND NEARLY ALL ITS SATURATION (`keepHue`, `satScale` 0.9) and
        # only its VALUE is retargeted. That is the whole difference between recolouring an animal
        # and painting one: the grizzle -- light and dark bristles within a centimetre of each other
        # -- is variation around the median, and moving only the median keeps every bristle.
        #
        # NOT NEAR-BLACK, DELIBERATELY. The brief says it in Karen's own words: "The flanks must
        # read LIGHT, not black: TASKS.md rows 18 and 24 both lost a round to a dark albedo", and
        # Task 22 measured why -- an unlit face renders at roughly 0.275 x albedo at this place's
        # ambient. So the darkest thing on this animal is the snout at 52, not 20.
        # `valueSpread`, NOT A RATIO, AND THE FIRST RUN IS WHY. Meshy bakes shadow and ambient
        # occlusion into the base colour, so the coat arrives with a lot of already-dark pixels; a
        # ratio correction keeps every pixel's distance from the median AS A RATIO, so moving the
        # median down multiplies those pixels down too and the animal came out near-black from every
        # camera. `valueSpread` moves each pixel a FRACTION of its distance from the median instead,
        # which lifts the baked lighting off the floor and leaves the grizzle as grizzle. It is the
        # same fix the gun's walnut needed, for the same reason, and the vocabulary was already here.
        "back": {
            "baseColor": {"targetRGB": [104, 95, 84], "keepHue": True, "satScale": 0.9,
                          "valueSpread": 0.5},
            "roughness": 0.88,
            "metallic": 0.0,
        },
        # THE PALE FLANK, and it is the reason this task has three bands instead of one colour: a
        # boar read at distance is a dark back over a light side. 146 against the back's 92 is a
        # 1.6x step in albedo, which survives being lit from any direction.
        "flank": {
            "baseColor": {"targetRGB": [158, 147, 130], "keepHue": True, "satScale": 0.9,
                          "valueSpread": 0.5},
            "roughness": 0.85,
            "metallic": 0.0,
        },
        # BELLY AND LEGS, dark again: on a live animal they are in its own shadow all day.
        "underside": {
            "baseColor": {"targetRGB": [86, 79, 72], "keepHue": True, "satScale": 0.9,
                          "valueSpread": 0.5},
            "roughness": 0.88,
            "metallic": 0.0,
        },
        # THE SNOUT: `satScale` 0.15 is what kills the pink. The hue is kept rather than replaced,
        # so the correction cannot invent a colour cast of its own; with the saturation crushed and
        # the value dropped it is wet dark hide, which is what a boar's rhinarium is.
        "snout": {
            "baseColor": {"targetRGB": [58, 55, 53], "keepHue": True, "satScale": 0.15,
                          "valueSpread": 0.45},
            # Wet skin, but not a mirror: it is the one part of the animal that catches a highlight.
            "roughness": 0.55,
            "metallic": 0.0,
        },
        # IVORY IS NOT GOLD AND IT IS NOT WHITE EITHER: dull bone, slightly warm, and duller than
        # the snout is wet. `satScale` 0.25 keeps a trace of the warmth so it does not read as
        # plastic.
        "tusk": {
            "baseColor": {"targetRGB": [208, 199, 178], "keepHue": True, "satScale": 0.25,
                          "valueSpread": 0.5},
            "roughness": 0.45,
            "metallic": 0.0,
        },
    },
    # NOTHING ON A LIVING ANIMAL IS METAL, so metalness is replaced outright; roughness keeps 15 % of
    # the generator's own variation, which is where the bristle and the wet-nose detail live.
    "channelWeight": {"metallic": 1.0, "roughness": 0.85},
    "maxShineDrift": 0.08,
}

PRESETS = {"gun": DEFAULT_RECIPE, "animal": ANIMAL_RECIPE}


def glb_triangles(path):
    """Count triangles in a .glb by reading its own index accessors -- stdlib only, no Blender.

    THE POINT IS INDEPENDENCE. The Blender side reports what it measured; this counts the same thing
    from the FILE THAT WAS WRITTEN, in a different process with different code. "Measured, not
    assumed" is then two numbers agreeing rather than one number asserting about itself. The Asset
    agent read the boar's GLB the same way (reviews/task-67/ASSET_RESULT.md).
      glTF 2.0 / GLB container: https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html
    """
    with open(path, "rb") as handle:
        blob = handle.read()
    if blob[:4] != b"glTF":
        raise RuntimeError("not a GLB: %s" % os.path.basename(path))
    offset, total = 12, len(blob)
    chunk_json = None
    while offset + 8 <= total:
        length, kind = struct.unpack_from("<II", blob, offset)
        body = blob[offset + 8: offset + 8 + length]
        if kind == 0x4E4F534A:  # 'JSON'
            chunk_json = json.loads(body.decode("utf-8"))
            break
        offset += 8 + length + ((4 - length % 4) % 4)
    if chunk_json is None:
        raise RuntimeError("the GLB has no JSON chunk")
    count = 0
    for mesh in chunk_json.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            # mode 4 is TRIANGLES, and it is also the default when the field is absent.
            if primitive.get("mode", 4) != 4:
                continue
            if "indices" in primitive:
                count += chunk_json["accessors"][primitive["indices"]]["count"] // 3
            else:
                attributes = primitive.get("attributes", {})
                if "POSITION" in attributes:
                    count += chunk_json["accessors"][attributes["POSITION"]]["count"] // 3
    return count


class Refused(Exception):
    """Something is wrong with the request; nothing has been written."""


def say(message):
    print("[asset-prep] " + message, flush=True)


def find_blender():
    override = os.environ.get("BLENDER_EXE")
    if override:
        if not os.path.isfile(override):
            raise Refused("BLENDER_EXE is set but there is no file there")
        return override
    for candidate in BLENDER_CANDIDATES:
        if os.path.isfile(candidate):
            return candidate
    raise Refused("no Blender found; set BLENDER_EXE to blender.exe")


def blender_version(exe):
    out = subprocess.run([exe, "--version"], capture_output=True, text=True, timeout=120)
    return out.stdout.strip().splitlines()[0] if out.stdout else "unknown"


def digest_of(path):
    sha = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            sha.update(block)
    return sha.hexdigest()


def manifest(folder):
    """sha256 of every file under `folder`, keyed by its path relative to it."""
    out = {}
    for root, _dirs, files in os.walk(folder):
        for name in sorted(files):
            full = os.path.join(root, name)
            out[os.path.relpath(full, folder).replace("\\", "/")] = digest_of(full)
    return out


def inside_repo(path):
    try:
        return os.path.commonpath([os.path.abspath(path), REPO]) == REPO
    except ValueError:  # different drives
        return False


# WHAT COUNTS AS A MODEL, in the order a folder holding several is read. FBX first because that is
# what the gun runs are and what Roblox is handed; GLB next, which is what Meshy returns for a
# refined model (Task 69).
MODEL_EXTENSIONS = (".fbx", ".glb", ".gltf")


def find_model(folder, wanted=None):
    """The one model file in `folder`, or the one named by `wanted`. Deterministic, and it says why.

    A run folder holds more than a model: the boar's holds `preview.glb` (a 300 KB draft) beside
    `model.glb` (21 MB, the refined one), so "the only file with that extension" is not a rule that
    survives contact. The order is extension first, then shortest path, then alphabetical -- which
    picks `model.glb` over `preview.glb` -- and `--model` overrides it by name when that is not what
    a caller wants. The chosen file is printed and written into the recipe either way.
    """
    hits = []
    for root, _dirs, files in os.walk(folder):
        for name in files:
            if name.lower().endswith(MODEL_EXTENSIONS):
                hits.append(os.path.join(root, name))
    if not hits:
        raise Refused("no .fbx, .glb or .gltf under the input folder")
    if wanted:
        named = [h for h in hits if os.path.basename(h).lower() == wanted.lower()]
        if not named:
            raise Refused("--model %s is not in the input folder (it holds %s)"
                          % (wanted, ", ".join(sorted(os.path.basename(h) for h in hits))))
        return named[0]
    hits.sort(key=lambda path: (MODEL_EXTENSIONS.index(os.path.splitext(path)[1].lower()),
                                len(path), path))
    return hits[0]


def check_output(path):
    if inside_repo(path):
        raise Refused("the output folder is inside the repository; this tool writes only outside it")
    if os.path.isdir(path) and os.listdir(path):
        raise Refused("the output folder already exists and is not empty; nothing is ever "
                      "overwritten (rule 7) -- name a new one")


def region_names(recipe):
    """The region names the plan can produce, in plan order and without repeats."""
    out = []
    for rule in recipe.get("regionPlan", []):
        if rule["name"] not in out:
            out.append(rule["name"])
    return out


def check_recipe(recipe):
    """REFUSE A PLAN THAT CANNOT DECIDE, before Blender is started.

    Two ways a plan is not a plan: a region it names has no colours (the Blender side would paint
    nothing and report a region that was never corrected), and no final catch-all (a face that
    matches no rule belongs to nobody, and "nobody" is what silently keeps the generator's colour).
    Both are cheap to check here and expensive to find in a render.
    """
    plan = recipe.get("regionPlan")
    if not plan:
        raise Refused("the recipe has no regionPlan")
    if plan[-1].get("when"):
        raise Refused("the last regionPlan entry must have no `when`: it is the everything-else, "
                      "and without one a face can match no rule at all")
    missing = [name for name in region_names(recipe) if name not in recipe.get("regions", {})]
    if missing:
        raise Refused("the regionPlan names %s, which the recipe gives no colours for"
                      % ", ".join(missing))
    for view in recipe.get("views", []):
        if "orthoSpan" in view and "orthoCross" in view:
            raise Refused("view %s asks for both orthoSpan and orthoCross" % view.get("name"))
    return recipe


def load_recipe(path, overrides, preset="gun"):
    if preset not in PRESETS:
        raise Refused("no such preset: %s (there are %s)" % (preset, ", ".join(sorted(PRESETS))))
    recipe = json.loads(json.dumps(PRESETS[preset]))
    recipe["preset"] = preset
    if path:
        with open(path, "r", encoding="utf-8") as handle:
            recipe.update(json.load(handle))
    for key, value in overrides.items():
        if value is not None:
            recipe[key] = value
    return check_recipe(recipe)


def command_probe(args):
    folder = args.input
    if not os.path.isdir(folder):
        raise Refused("no such input folder")
    model = find_model(folder, getattr(args, "model", None))
    files = manifest(folder)
    say("input %d file(s); model is %s (%.1f MiB)"
        % (len(files), os.path.basename(model), os.path.getsize(model) / (1 << 20)))
    for name in sorted(files):
        say("  %s  %d bytes" % (name, os.path.getsize(os.path.join(folder, name))))
    return 0


def command_recipe(args):
    # CHECKED BEFORE IT IS PRINTED. A preset that cannot decide -- a plan with no catch-all, or one
    # naming a region it gives no colours for -- would otherwise print like any other, and this
    # command is what CI runs to prove the presets are still whole without a Blender to run them in.
    print(json.dumps(check_recipe(PRESETS[args.preset]), indent=2))
    return 0


def run_blender(exe, job_path, timeout):
    process = subprocess.run([exe, "--background", "--python", BLENDER_SCRIPT, "--", job_path],
                             capture_output=True, text=True, timeout=timeout)
    for line in process.stdout.splitlines():
        if line.startswith("[prep]"):
            print(line, flush=True)
    return process


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
PNG_END = b"IEND\xaeB`\x82"


def embedded_pngs(fbx_path):
    """Every PNG embedded in an FBX, as raw bytes. Stdlib only: find the signature, read to IEND.

    The container is not parsed. It does not need to be: an embedded texture is stored as the file's
    own bytes, so the signature and the end marker bracket it exactly, and the whole point here is to
    compare bytes with what was written rather than to decode anything.
    """
    with open(fbx_path, "rb") as handle:
        blob = handle.read()
    out, pos = [], 0
    while True:
        start = blob.find(PNG_SIGNATURE, pos)
        if start < 0:
            return out
        end = blob.find(PNG_END, start)
        if end < 0:
            return out
        out.append(blob[start:end + len(PNG_END)])
        pos = end + len(PNG_END)


def verify_embedded_textures(out_dir, report):
    """THE EXPORT MUST CARRY THE TEXTURES THIS TOOL WROTE. Measured, not assumed.

    Everything else in this tool measures the model in Blender: the colours, the shine, the region
    split, the renders. None of that says anything about the FILE Roblox is handed, and for two
    uploads it was wrong about it -- the FBX embedded the untouched originals (Meshy's 4096 metalness
    and roughness maps, median 0.91 and 0.19) while the corrected 2048 maps sat in the output folder
    (Task 75, read back out of the uploaded file). The renders were right, the game got the raw
    model, and nothing in the run said so.

    So the run now reads its own FBX back and asks one question with a yes-or-no answer: is every
    embedded PNG byte-for-byte one of the files this run wrote? A re-encode, a stale path, a packed
    original -- all of them fail it.
    """
    fbx_path = os.path.join(out_dir, "model.fbx")
    if not os.path.exists(fbx_path):
        return None
    written = {}
    for name in report.get("texturesWritten", []):
        path = os.path.join(out_dir, name)
        if os.path.exists(path):
            with open(path, "rb") as handle:
                written[handle.read()] = name
    embedded = embedded_pngs(fbx_path)
    matched, strangers = [], 0
    for blob in embedded:
        name = written.get(blob)
        if name is None:
            strangers += 1
        else:
            matched.append(name)
    result = {"embedded": len(embedded), "matched": sorted(matched), "strangers": strangers,
              "written": sorted(written.values())}
    report["embeddedTextures"] = result
    missing = sorted(set(written.values()) - set(matched))
    if strangers or missing:
        # IT FAILS THE RUN. IT DOES NOT WARN (review round 1, the blocking finding).
        #
        # Round 1 appended a warning and returned; `command_prep` still printed "OK" and exited 0, so
        # the one guard this whole task rests on could not stop a bad file from being uploaded --
        # and three separate texts in the deliverables claimed it could. A guard that only narrates
        # is worse than no guard: it reads like protection in a diff.
        #
        # `ok` is the field `command_prep` exits on and `tools/roblox_upload.py` now refuses on, so
        # the FILE that carries the wrong textures cannot be handed to Roblox by either route.
        report["ok"] = False
        report["error"] = (
            "the exported FBX does not carry the textures this run wrote: %d embedded PNG(s) match "
            "nothing written, and %s never reached it -- the game would get the original model, "
            "which is exactly the defect Task 75 exists for"
            % (strangers, ", ".join(missing) or "nothing")
        )
        report.setdefault("warnings", []).append(report["error"])
    return result


def prep(input_dir, out_dir, recipe, exe, timeout=1800, keep_source=True, model=None):
    """The whole run. Returns the Blender side's report. Raises Refused before anything is written."""
    if not os.path.isdir(input_dir):
        raise Refused("no such input folder")
    check_output(out_dir)
    check_recipe(recipe)
    model_name = os.path.relpath(find_model(input_dir, model), input_dir)

    before = manifest(input_dir)
    os.makedirs(out_dir, exist_ok=True)
    source_dir = os.path.join(out_dir, "source")
    # COPY, NEVER OPEN THE ORIGINAL: Blender's FBX importer writes a .fbm folder beside the file it
    # reads. The copy is what gets read; the original is proved untouched below.
    shutil.copytree(input_dir, source_dir, dirs_exist_ok=True)

    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    recipe = dict(recipe)
    recipe["ranAt"] = stamp
    recipe["blender"] = blender_version(exe)
    recipe["sourceFiles"] = before
    recipe["sourceModel"] = model_name.replace("\\", "/")
    recipe_path = os.path.join(out_dir, "recipe.json")
    with open(recipe_path, "w", encoding="utf-8") as handle:
        json.dump(recipe, handle, indent=2)

    job = {
        "model": os.path.join(source_dir, model_name),
        "outDir": out_dir,
        "recipe": recipe,
        "reportPath": os.path.join(out_dir, "report.json"),
    }
    job_path = os.path.join(out_dir, "job.json")
    with open(job_path, "w", encoding="utf-8") as handle:
        json.dump(job, handle, indent=2)

    process = run_blender(exe, job_path, timeout)

    after = manifest(input_dir)
    if after != before:
        changed = sorted(set(after) ^ set(before)) or [k for k in before if after.get(k) != before[k]]
        raise RuntimeError("THE INPUT FOLDER CHANGED during the run (%s) -- rule 7" % ", ".join(changed))

    if not os.path.exists(job["reportPath"]):
        tail = "\n".join((process.stdout or "").splitlines()[-25:])
        raise RuntimeError("Blender wrote no report (exit %d)\n%s" % (process.returncode, tail))
    with open(job["reportPath"], "r", encoding="utf-8") as handle:
        report = json.load(handle)
    report["inputUnchanged"] = True
    verify_embedded_textures(out_dir, report)
    if not keep_source:
        shutil.rmtree(source_dir, ignore_errors=True)
    with open(job["reportPath"], "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
    return report


def command_prep(args):
    exe = find_blender()
    recipe = load_recipe(args.recipe, {"targetTriangles": args.target, "workPx": args.work_px},
                         preset=args.preset)
    if args.dry_run:
        say("would run %s on %s" % (os.path.basename(exe),
                                    os.path.basename(find_model(args.input, args.model))
                                    if os.path.isdir(args.input) else args.input))
        print(json.dumps(recipe, indent=2))
        return 0
    say("blender: %s" % blender_version(exe))
    say("preset %s, model %s" % (recipe.get("preset", "gun"),
                                 os.path.basename(find_model(args.input, args.model))))
    report = prep(args.input, args.output, recipe, exe, keep_source=not args.no_source,
                  model=args.model)
    if not report.get("ok"):
        say("FAILED: %s" % report.get("error", "no reason given"))
        return 1
    orientation = report.get("orientation", {})
    say("long axis %s, front at its %s (%s)"
        % (orientation.get("axis"), "minimum" if orientation.get("frontAtMin") else "maximum",
           "stated in the recipe" if orientation.get("frontStated") else "measured"))
    packed = report.get("packedShineMap")
    if packed:
        say("metalness and roughness arrived as ONE %dpx map (%s); split into two"
            % (packed.get("sourcePx", 0), packed.get("name", "?")))
    tri = report["triangles"]
    regions = report.get("regions", {})
    if tri.get("target") is None:
        say("triangles %d, NOT decimated -- Roblox allows 20,000 per mesh (--target N to reduce)"
            % tri["after"])
    else:
        say("triangles %d -> %d (target %d, MEASURED)" % (tri["before"], tri["after"], tri["target"]))
    say("regions (triangles): " + ", ".join("%s %d" % (k, regions[k]) for k in sorted(regions)))
    for name in region_names(recipe):
        got = report.get("corrections", {}).get(name, {})
        shown = report.get("surface", {}).get(name, {})
        if got.get("pixels"):
            say("colour %-9s asked RGB%-16s wrote RGB%-16s surface shows RGB%-16s drift %s"
                % (name, tuple(got["targetRGB"]), tuple(got["achievedRGB"]),
                   tuple(shown.get("shownRGB", ())), shown.get("drift")))
        shine = report.get("shine", {}).get("surface", {}).get(name, {})
        if shine:
            say("shine  %-9s metalness %s (asked %s)   roughness %s (asked %s)"
                % (name, shine.get("metallic", {}).get("shown"),
                   shine.get("metallic", {}).get("target"),
                   shine.get("roughness", {}).get("shown"),
                   shine.get("roughness", {}).get("target")))
    for row in report.get("comparison", []):
        flag = "  <-- BROKEN UP" if row["edgeDensityRatio"] > 1.25 else ""
        say("%-14s edges %.3f -> %.3f (x%.2f)   mean RGB%s -> RGB%s%s"
            % (row["view"], row["edgeDensityBefore"], row["edgeDensityAfter"],
               row["edgeDensityRatio"], tuple(row["meanRGBBefore"]), tuple(row["meanRGBAfter"]),
               flag))
    for stats in report.get("renderStats", []):
        say("render %-24s mean %.3f  spread %.3f  subject %.1f%%"
            % (stats["file"], stats["mean"], stats["spread"], stats["subjectFraction"] * 100))
        if stats["p99"] <= 0.10 or stats["spread"] <= 0.05 or stats["subjectFraction"] <= 0.01:
            say("  ^ THAT RENDER IS EFFECTIVELY BLANK -- do not report what it shows")
    say("renders: " + ", ".join(report.get("renders", [])) + " -- LOOK AT THEM (rule 5)")
    for warning in report.get("warnings", []):
        say("warning: " + warning)
    say("OK: %d triangles, %d region(s), input unchanged, nothing uploaded"
        % (report["triangles"]["after"], len(regions)))
    return 0


# ---------------------------------------------------------------- selftest

SELFTEST_BUILD = r'''
import bpy, sys, os, math
out = sys.argv[sys.argv.index("--") + 1]
tone = sys.argv[sys.argv.index("--") + 2]   # "neutral" or "woody": which half of the rule is under test
bpy.ops.wm.read_factory_settings(use_empty=True)
# A LONG BAR PLUS A BLOCK: the crudest thing with the shape this tool cares about -- a long axis, a
# thin end and a deep end -- and enough subdivision that decimation has something to do.
bpy.ops.mesh.primitive_cube_add(size=1)
bar = bpy.context.object
bar.scale = (1.0, 0.05, 0.05)
bpy.ops.object.transform_apply(scale=True)
bpy.ops.object.modifier_add(type="SUBSURF")
bar.modifiers["Subdivision"].levels = 3
bar.modifiers["Subdivision"].render_levels = 3
bpy.ops.object.modifier_apply(modifier="Subdivision")
bpy.ops.mesh.primitive_cube_add(size=1, location=(0.8, 0, 0))
butt = bpy.context.object
butt.scale = (0.35, 0.12, 0.2)
bpy.ops.object.transform_apply(scale=True)
bpy.ops.object.select_all(action="DESELECT")
bar.select_set(True); butt.select_set(True)
bpy.context.view_layer.objects.active = bar
bpy.ops.object.join()
ob = bpy.context.object
bpy.ops.object.editmode_toggle()
bpy.ops.uv.smart_project(angle_limit=math.radians(66))
bpy.ops.object.editmode_toggle()
# EVERY ISLAND INTO THE TOP HALF OF THE ATLAS, ON PURPOSE. A symmetric layout cannot show a mask
# that is applied upside down -- the mirror of an island lands on another island and the numbers
# still agree. Packed into one half, the mirror lands in empty space, so a flipped mask writes
# nowhere and the surface sampled through the mesh still shows the ORIGINAL colour. That is the
# difference the selftest's surface check exists to see (round 2).
for loop in ob.data.uv_layers.active.uv:
    loop.vector = (loop.vector[0], 0.52 + loop.vector[1] * 0.46)
# One material, one atlas, half grey and half brown -- the very case the region rule exists for.
image = bpy.data.images.new("atlas", 256, 256)
# ONE TONE PER FIXTURE, so each run isolates ONE rule. A half-and-half atlas made the outcome depend
# on where smart_project happened to put each island, which is luck, not a test.
#
# AND IT IS A VERTICAL GRADIENT, not a flat fill, for one specific reason: a flat atlas cannot show a
# mask that is applied UPSIDE DOWN. Round 1 indexed the region masks with the UV v coordinate while
# the pixels were held top-row-first, so every correction landed on the vertical mirror of the region
# it was measured on -- and every number in the run still agreed with itself. A gradient makes that
# mistake move the measured colours and the edge metric, so the selftest can fail on it.
base = [0.45, 0.45, 0.46, 1.0] if tone == "neutral" else [0.60, 0.36, 0.18, 1.0]
px = []
for y in range(256):
    k = 0.35 + 1.3 * (y / 255.0)
    px.extend([min(base[0] * k, 1.0), min(base[1] * k, 1.0), min(base[2] * k, 1.0), 1.0] * 256)
image.pixels = px
# SAVED TO DISK FIRST: an image that only exists in memory embeds as an empty texture, and the
# fixture would then prove nothing about the colour path (measured, 2026-09-26).
os.makedirs(os.path.dirname(out), exist_ok=True)
image.filepath_raw = os.path.join(os.path.dirname(out), "atlas.png")
image.file_format = "PNG"
image.save()
mat = bpy.data.materials.new("m"); mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
tex = mat.node_tree.nodes.new("ShaderNodeTexImage"); tex.image = image
mat.node_tree.links.new(bsdf.inputs["Base Color"], tex.outputs["Color"])
ob.data.materials.append(mat)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.export_scene.fbx(filepath=out, use_selection=True, path_mode="COPY", embed_textures=True)
print("[selftest-build] wrote", out, len(ob.data.polygons), "polys")
'''


SELFTEST_BUILD_GLB = r"""
import bpy, sys, os, math
out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
# A BODY, NOT A BAR: long in Y and tall in Z, so the height bands an animal plan uses have something
# to divide. Subdivided so each band gets real faces rather than one face of a cube.
bpy.ops.mesh.primitive_cube_add(size=1)
ob = bpy.context.object
ob.scale = (0.25, 1.0, 0.5)
bpy.ops.object.transform_apply(scale=True)
bpy.ops.object.modifier_add(type="SUBSURF")
ob.modifiers["Subdivision"].subdivision_type = "SIMPLE"
ob.modifiers["Subdivision"].levels = 4
ob.modifiers["Subdivision"].render_levels = 4
bpy.ops.object.modifier_apply(modifier="Subdivision")
bpy.ops.object.editmode_toggle()
bpy.ops.uv.smart_project(angle_limit=math.radians(66))
bpy.ops.object.editmode_toggle()
for loop in ob.data.uv_layers.active.uv:
    loop.vector = (loop.vector[0], 0.52 + loop.vector[1] * 0.46)
# The base colour: the same vertical gradient the other fixtures use, so a mask applied upside down
# still moves the measured numbers.
base = bpy.data.images.new("atlas", 256, 256)
px = []
for y in range(256):
    k = 0.35 + 1.3 * (y / 255.0)
    px.extend([min(0.45 * k, 1.0), min(0.45 * k, 1.0), min(0.46 * k, 1.0), 1.0] * 256)
base.pixels = px
os.makedirs(os.path.dirname(out), exist_ok=True)
base.filepath_raw = os.path.join(os.path.dirname(out), "atlas.png")
base.file_format = "PNG"
base.save()
# THE PACKED ORM MAP, EXACTLY AS glTF DEFINES IT AND AS MESHY SHIPS IT: occlusion in R (left white),
# roughness in G, metalness in B. One image, feeding BOTH Principled sockets -- which is the shape
# this tool used to refuse outright.
orm = bpy.data.images.new("orm", 256, 256)
orm.colorspace_settings.name = "Non-Color"
orm.pixels = [1.0, 0.62, 0.0, 1.0] * (256 * 256)
orm.filepath_raw = os.path.join(os.path.dirname(out), "orm.png")
orm.file_format = "PNG"
orm.save()
mat = bpy.data.materials.new("m"); mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
tex = mat.node_tree.nodes.new("ShaderNodeTexImage"); tex.image = base
mat.node_tree.links.new(bsdf.inputs["Base Color"], tex.outputs["Color"])
shine = mat.node_tree.nodes.new("ShaderNodeTexImage"); shine.image = orm
mat.node_tree.links.new(bsdf.inputs["Metallic"], shine.outputs["Color"])
mat.node_tree.links.new(bsdf.inputs["Roughness"], shine.outputs["Color"])
ob.data.materials.append(mat)
bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True)
print("[selftest-build] wrote", out, len(ob.data.polygons), "polys")
"""


# The plan and the colours the GLB fixture is prepped with. Three height bands plus one rule that
# matches on the texture's VALUE, which is the predicate the boar's tusks need and the gun's rule
# never uses. Roughness is deliberately left at None in every band: the source's own G channel then
# survives untouched, so what the roughness map reads back is proof of WHICH CHANNEL the split took
# (0.62 is G; R is 1.0 and B is 0.0, and either of those would fail).
SELFTEST_GLB_RECIPE = {
    "regionColorSpace": "srgb",
    "frontAtMin": True,
    "regionPlan": [
        # `nose` is here to be RUN OVER, and it is not: it is decided by position, it sits at every
        # height, and the three bands below all have soft edges whose ramps are a function of height
        # alone. If a ramp were allowed to reach a region another rule decided, this one would be
        # painted by whichever band it sits in -- which is what would happen to the boar's tusks,
        # at half the animal's height, if the restriction were dropped.
        {"name": "nose", "when": {"axisTo": 0.15}},
        {"name": "bright", "when": {"valueMin": 0.88}},
        {"name": "low", "when": {"upTo": 0.28}, "band": {"upTo": 0.28}, "softUp": 0.08},
        {"name": "high", "when": {"upFrom": 0.62}, "band": {"upFrom": 0.62}, "softUp": 0.08},
        {"name": "middle", "band": {"upFrom": 0.28, "upTo": 0.62}, "softUp": 0.08},
    ],
    "views": [
        {"name": "side", "dir": [-1.0, 0.0, 0.06], "distanceSpan": 1.2, "orthoSpan": 1.08},
        {"name": "front", "dir": [0.0, -1.0, 0.04], "distanceSpan": 1.3, "orthoCross": 1.6},
        {"name": "top", "dir": [0.0, -0.02, 1.0], "distanceSpan": 1.2, "orthoSpan": 1.08},
        {"name": "three-quarter", "dir": [-0.7, -1.0, 0.38], "distanceSpan": 0.8},
    ],
    "regions": {
        # LABELLED AND LEFT ALONE. The value rule is here to prove the predicate matches -- which
        # `regionPlanHits` records before smoothing -- and a handful of scattered faces is not a
        # region worth repainting: a two-face region's colour, sampled back through the mesh, is
        # mostly its neighbours' feather, and asserting on that would be asserting on noise.
        "bright": {"baseColor": {"skip": True}, "metallic": None, "roughness": None},
        "nose": {"baseColor": {"targetRGB": [40, 38, 36], "keepHue": True, "satScale": 0.5},
                 "metallic": 0.95, "roughness": None},
        "low": {"baseColor": {"targetRGB": [60, 56, 52], "keepHue": True, "satScale": 0.9},
                "metallic": 0.1, "roughness": None},
        "high": {"baseColor": {"targetRGB": [96, 88, 78], "keepHue": True, "satScale": 0.9},
                 "metallic": 0.3, "roughness": None},
        "middle": {"baseColor": {"targetRGB": [150, 140, 124], "keepHue": True, "satScale": 0.9},
                   "metallic": 0.5, "roughness": None},
    },
    "channelWeight": {"metallic": 1.0, "roughness": 0.85},
}


def command_selftest(_args):
    """Offline end to end: build tiny models, prep them, and check every claim this tool makes.

    TWO FIXTURES, ONE RULE EACH. The region split is position AND colour, and a single fixture can
    only exercise one of them honestly: a neutral atlas leaves the position rule to do all the work
    (barrels forward, action behind), and a woody atlas leaves the colour rule to do it (everything
    is wood, wherever it sits). A half-and-half atlas made the answer depend on where the unwrapper
    happened to put each island, which is luck rather than a test.
    """
    exe = find_blender()
    say("blender: %s" % blender_version(exe))
    failures = []
    checks = [0]

    def ok(name, condition, detail=""):
        checks[0] += 1
        print("  %-4s %s%s" % ("ok" if condition else "FAIL", name,
                               ("  (%s)" % detail) if detail else ""), flush=True)
        if not condition:
            failures.append(name)

    def build(tmp, tone):
        in_dir = os.path.join(tmp, "in-" + tone)
        os.makedirs(in_dir)
        builder = os.path.join(tmp, "build.py")
        with open(builder, "w", encoding="utf-8") as handle:
            handle.write(SELFTEST_BUILD)
        fbx = os.path.join(in_dir, "tiny.fbx")
        made = subprocess.run([exe, "--background", "--python", builder, "--", fbx, tone],
                              capture_output=True, text=True, timeout=600)
        return in_dir, fbx, made

    with tempfile.TemporaryDirectory(prefix="dh-asset-prep-") as tmp:
        # ---------------------------------------------------------- the position rule
        in_dir, fbx, made = build(tmp, "neutral")
        ok("the neutral fixture was built", os.path.exists(fbx),
           (made.stdout or "")[-200:] if not os.path.exists(fbx) else "")
        if failures:
            return 1
        before = manifest(in_dir)
        out_dir = os.path.join(tmp, "out-neutral")
        recipe = load_recipe(None, {"targetTriangles": 300, "workPx": 256})
        recipe["renderPx"] = 240
        recipe["renderSamples"] = 4
        # THE FIXTURE'S OWN CEILING IS LOOSER THAN THE DEFAULT, and the reason is the fixture, not
        # the tool: it is a 2-unit bar whose barrel and action regions meet along its length, so the
        # boundary between two deliberately different colours IS a real edge, on a 240-pixel render
        # of a tiny object. Karen's gun runs 0.37-0.88 against the 1.25 default. What this number
        # has to be is low enough that the upside-down mask of round 1 still fails it -- and it is:
        # with that line restored the fixture measures well past 1.6 (mutation-checked).
        recipe["maxEdgeDensityRatio"] = 1.6
        report = prep(in_dir, out_dir, recipe, exe, timeout=900)

        ok("the run reported ok", report.get("ok") is True, report.get("error", ""))
        ok("the input folder is byte-for-byte unchanged", manifest(in_dir) == before)
        ok("the input folder gained no file", set(manifest(in_dir)) == set(before))

        tri = report.get("triangles", {})
        ok("decimation actually reduced it", tri.get("after", 0) < tri.get("before", 0),
           "%s -> %s" % (tri.get("before"), tri.get("after")))
        ok("it hit the target within 2%", tri.get("after", 0) <= tri.get("target", 0) * 1.02,
           "after %s target %s" % (tri.get("after"), tri.get("target")))
        # MEASURED, NOT ASSUMED, and proved by INDEPENDENCE: this process counts the triangles out of
        # the GLB that was written, with different code, and the two numbers must agree.
        counted = glb_triangles(os.path.join(out_dir, "model.glb"))
        ok("the exported GLB really holds the reported triangle count",
           counted == tri.get("after"), "GLB says %d, report says %s" % (counted, tri.get("after")))
        ok("that count is the final mesh, not the target echoed back",
           counted == report.get("trianglesFinal"),
           "GLB %d, final %s" % (counted, report.get("trianglesFinal")))

        # THE CHECK ROUND 1 DID NOT HAVE, and the one that would have caught its defect: the prepped
        # model is photographed at the same four cameras as the untouched source, and its texture may
        # not become MORE broken up than what it started from. With the mask flip in place this runs
        # at about 1.9x; without it, under 1.
        ok("the source was photographed too", len(report.get("sourceStats", [])) == 4,
           str(report.get("sourceStats")))
        # THE CHECK THAT CATCHES AN UPSIDE-DOWN MASK: the surface, sampled through the mesh, has to
        # show the colour the region was given. Measured by a different route from the one that did
        # the writing, so the two cannot agree by construction.
        for name in ("barrel", "action"):
            shown = report.get("surface", {}).get(name)
            if shown:
                ok("the %s surface really shows the colour it was given" % name,
                   shown["drift"] is not None and shown["drift"] <= recipe["maxSurfaceDrift"],
                   "shows RGB%s, asked RGB%s, drift %s"
                   % (tuple(shown["shownRGB"]), tuple(shown["targetRGB"]), shown["drift"]))
        # THE EDGE RATIO IS MEASURED AND REPORTED, NOT ASSERTED ON THE FIXTURE. The fixture is a
        # 2-unit bar with its barrel and action regions meeting along its length and its atlas
        # squeezed into half of a 256-pixel image: the boundary between two deliberately different
        # colours is a genuine edge there, and at 240 pixels it dominates the frame. On Karen's gun
        # the same number runs 0.37-0.88 against the 1.25 ceiling, and the run WARNS above it. What
        # the selftest asserts instead is the surface check above, which is the one that catches the
        # defect this metric was built for.
        worst = report.get("worstEdgeDensityRatio")
        ok("an edge-density comparison was made for every view",
           worst is not None and len(report.get("comparison", [])) == 4,
           "worst %s over %d view(s)" % (worst, len(report.get("comparison", []))))
        unexpected = [w for w in report.get("warnings", [])
                      if "region came out empty" not in w and "edge density" not in w]
        ok("no unexpected run warning was raised", not unexpected, str(unexpected))

        regions = report.get("regions", {})
        ok("three regions exist", set(regions) == {"barrel", "action", "wood"}, str(regions))
        speckle = report.get("regionSpeckle", {})
        ok("the region map is not speckled",
           speckle.get("after", 1.0) <= recipe["maxRegionSpeckle"], str(speckle))
        ok("the POSITION rule split the neutral model into barrel and action",
           regions.get("barrel", 0) > 0 and regions.get("action", 0) > 0, str(regions))
        ok("nothing neutral was called wood", regions.get("wood", 0) == 0, str(regions))
        corrections = report.get("corrections", {})
        ok("both metal regions had pixels corrected",
           corrections.get("barrel", {}).get("pixels", 0) > 0
           and corrections.get("action", {}).get("pixels", 0) > 0, str(corrections))
        # ASSERTED ON WHAT IT BECAME, not on what it was asked for: the tool measures the corrected
        # pixels back and reports them in the same sRGB numbers the target was written in.
        achieved = corrections.get("barrel", {}).get("achievedRGB", [255, 255, 255])
        ok("the barrels really came out near-black", max(achieved) < 70, str(achieved))
        ok("the action really came out bright",
           min(corrections.get("action", {}).get("achievedRGB", [0, 0, 0])) > 120,
           str(corrections.get("action", {}).get("achievedRGB")))
        # ONE MATERIAL, not one per region (Task 75): Roblox makes a SurfaceAppearance per material
        # that has maps, so the old split came back as three empty SurfaceAppearance children.
        ok("the mesh ships with one material", len(report.get("materials", [])) == 1,
           str(report.get("materials")))

        # ---------------------------------------------------------- the FILE carries the work
        embedded = report.get("embeddedTextures", {})
        ok("every texture the run wrote is embedded in the FBX",
           embedded.get("strangers") == 0
           and sorted(embedded.get("matched", [])) == sorted(embedded.get("written", [])),
           str(embedded))
        ok("the FBX embeds every one of them, and nothing else",
           embedded.get("embedded", 0) == len(embedded.get("written", []))
           and embedded.get("strangers") == 0
           and sorted(embedded.get("matched", [])) == sorted(embedded.get("written", [])),
           str(embedded))
        # ...and the run that produced them SAID SO: `ok` is what `command_prep` exits on and what
        # `tools/roblox_upload.py` refuses on (review round 1, finding 1).
        ok("a run whose file carries its own textures reports ok", report.get("ok") is True,
           str(report.get("error")))

        # ---------------------------------------------------------- the shine reaches the MAPS
        # THE DEFECT TASK 75 EXISTS FOR: the recipe's metalness and roughness used to live on a
        # Blender material, where Roblox never looked. These checks are on the maps, measured back
        # through the mesh, because that is the only channel the engine reads.
        shine = report.get("shine", {})
        maps = shine.get("maps", {})
        ok("the fixture had no shine maps and the tool made them",
           sorted(maps.get("created", [])) == ["metallic", "roughness"], str(maps.get("created")))
        surface = shine.get("surface", {})
        barrel = surface.get("barrel", {})
        ok("the barrels' metalness is in the MAP, sampled through the mesh",
           barrel.get("metallic", {}).get("drift") is not None
           and barrel["metallic"]["drift"] <= recipe["maxShineDrift"], str(barrel.get("metallic")))
        ok("the barrels' roughness is in the MAP, sampled through the mesh",
           barrel.get("roughness", {}).get("drift") is not None
           and barrel["roughness"]["drift"] <= recipe["maxShineDrift"], str(barrel.get("roughness")))
        # ...and asserted on the VALUE, not only on the drift: a recipe edited to ship a mirror
        # would satisfy the drift check perfectly.
        ok("the barrels are not a mirror", barrel.get("metallic", {}).get("shown", 1.0) <= 0.25
           and barrel.get("roughness", {}).get("shown", 0.0) >= 0.40, str(barrel))
        ok("the action stayed bright metal",
           surface.get("action", {}).get("metallic", {}).get("shown", 0.0) >= 0.50,
           str(surface.get("action")))
        written_maps = report.get("texturesWritten", [])
        ok("both shine maps were written beside the exports",
           "texture_metallic.png" in written_maps and "texture_roughness.png" in written_maps,
           str(written_maps))
        ok("the muzzle end was measured, not guessed",
           report.get("orientation", {}).get("muzzleAtMin") is True,
           str(report.get("orientation")))
        ok("four renders were written", len(report.get("renders", [])) == 4,
           str(report.get("renders")))
        # NOT "IS THE FILE BIG ENOUGH" -- that check passed four pure-black PNGs on the first real
        # run, because a uniform image compresses to almost nothing and 2 KB is still 2 KB.
        for stats in report.get("renderStats", []):
            ok("  %s is lit, not a black screen" % stats["file"],
               stats["p99"] > 0.10 and stats["spread"] > 0.05, str(stats))
            ok("  %s has a subject in it, not just a backdrop" % stats["file"],
               0.01 < stats["subjectFraction"] < 0.98, str(stats))
        exports = report.get("exports", {})
        ok("an FBX was exported", exports.get("model.fbx", 0) > 1000, str(exports))
        ok("a GLB was exported", exports.get("model.glb", 0) > 1000, str(exports))
        ok("the recipe was written beside the results",
           os.path.exists(os.path.join(out_dir, "recipe.json")))
        with open(os.path.join(out_dir, "recipe.json"), "r", encoding="utf-8") as handle:
            written = json.load(handle)
        ok("the recipe records the Blender that ran", "blender" in written,
           written.get("blender", ""))
        ok("the recipe records every source file's hash", written.get("sourceFiles", {}) == before)

        # ---------------------------------------------------------- the colour rule
        wood_dir, wood_fbx, made = build(tmp, "woody")
        ok("the woody fixture was built", os.path.exists(wood_fbx),
           (made.stdout or "")[-200:] if not os.path.exists(wood_fbx) else "")
        wood_before = manifest(wood_dir)
        wood_out = os.path.join(tmp, "out-woody")
        wood_report = prep(wood_dir, wood_out, recipe, exe, timeout=900)
        wood_regions = wood_report.get("regions", {})
        ok("the woody run reported ok", wood_report.get("ok") is True, wood_report.get("error", ""))
        ok("its input folder is byte-for-byte unchanged too", manifest(wood_dir) == wood_before)
        ok("the COLOUR rule claimed the whole woody model",
           wood_regions.get("wood", 0) > 0
           and wood_regions.get("barrel", 0) == 0 and wood_regions.get("action", 0) == 0,
           str(wood_regions))
        ok("wood pixels were corrected",
           wood_report.get("corrections", {}).get("wood", {}).get("pixels", 0) > 0,
           str(wood_report.get("corrections")))

        # ------------------------------------------------- a GLB, a packed ORM map, height bands
        # TASK 69'S THREE NEW PATHS, END TO END AND IN ONE RUN: the input is a .glb rather than a
        # .fbx, its metalness and roughness arrive as ONE image (which this tool used to refuse),
        # and the regions are decided by HEIGHT and by texture VALUE rather than by the gun's
        # position-and-hue rule.
        glb_dir = os.path.join(tmp, "in-glb")
        os.makedirs(glb_dir)
        glb_builder = os.path.join(tmp, "build-glb.py")
        with open(glb_builder, "w", encoding="utf-8") as handle:
            handle.write(SELFTEST_BUILD_GLB)
        glb_in = os.path.join(glb_dir, "model.glb")
        made = subprocess.run([exe, "--background", "--python", glb_builder, "--", glb_in],
                              capture_output=True, text=True, timeout=600)
        ok("the GLB fixture was built", os.path.exists(glb_in),
           (made.stdout or "")[-200:] if not os.path.exists(glb_in) else "")
        if os.path.exists(glb_in):
            # a decoy beside it, so the choice is a rule and not "the only file there"
            shutil.copyfile(glb_in, os.path.join(glb_dir, "preview.glb"))
            ok("it picks the model over the preview beside it",
               os.path.basename(find_model(glb_dir)) == "model.glb",
               os.path.basename(find_model(glb_dir)))
            ok("--model picks the other one by name",
               os.path.basename(find_model(glb_dir, "preview.glb")) == "preview.glb")
            try:
                find_model(glb_dir, "nope.glb")
                ok("--model refuses a name that is not there", False)
            except Refused:
                ok("--model refuses a name that is not there", True)

            glb_before = manifest(glb_dir)
            glb_recipe = load_recipe(None, {"targetTriangles": None, "workPx": 256})
            glb_recipe.update(json.loads(json.dumps(SELFTEST_GLB_RECIPE)))
            glb_recipe["renderPx"] = 240
            glb_recipe["renderSamples"] = 4
            glb_recipe["maxEdgeDensityRatio"] = 1.6
            glb_out = os.path.join(tmp, "out-glb")
            glb_report = prep(glb_dir, glb_out, glb_recipe, exe, timeout=900, model="model.glb")
            ok("the GLB run reported ok", glb_report.get("ok") is True, glb_report.get("error", ""))
            ok("its input folder is byte-for-byte unchanged", manifest(glb_dir) == glb_before)

            packed = glb_report.get("packedShineMap", {})
            ok("the packed metalness-roughness map was seen and split",
               sorted(packed.get("splitInto", [])) == ["metallic", "roughness"], str(packed))
            glb_shine = glb_report.get("shine", {}).get("surface", {})
            # THE CHANNEL PROOF. Roughness is left at None in every band, so nothing is written into
            # that map and what it reads back is the SOURCE: 0.62, which is the G channel. R is 1.0
            # and B is 0.0, so taking either of those instead fails this by a mile.
            roughnesses = [entry.get("roughness", {}).get("shown")
                           for entry in glb_shine.values()]
            ok("the roughness map came from the G channel, untouched",
               roughnesses and all(r is not None and abs(r - 0.62) < 0.05 for r in roughnesses),
               str(roughnesses))
            # ...and metalness is its own map now: three bands, three different numbers, each one
            # sampled back through the mesh.
            for name in ("low", "middle", "high"):
                entry = glb_shine.get(name, {}).get("metallic", {})
                if entry.get("target") is not None:
                    ok("  the %s band's metalness is in its own map" % name,
                       entry.get("drift") is not None
                       and entry["drift"] <= glb_recipe["maxShineDrift"], str(entry))
            shown = sorted((glb_shine.get(n, {}).get("metallic", {}).get("shown")
                            for n in ("low", "middle", "high")), key=lambda v: v or 0)
            ok("the three bands really carry three different metalness numbers",
               len(set(shown)) == 3, str(shown))

            # ---- the SOFT band boundary, and what it is not allowed to reach
            ok("the three height bands were softened and nothing else was",
               sorted(glb_report.get("softBands", [])) == ["high", "low", "middle"],
               str(glb_report.get("softBands")))
            # A ramp is a function of height, so an unrestricted one would paint the whole model at
            # whatever height it sits. `nose` is decided by POSITION along the long axis, spans every
            # height, and must come out carrying its own number: this is the check that fails when a
            # band is allowed to bleed into a region another rule decided -- the boar's tusks.
            nose = glb_shine.get("nose", {}).get("metallic", {})
            ok("a soft band does not reach a region another rule decided",
               nose.get("drift") is not None and nose["drift"] <= glb_recipe["maxShineDrift"],
               str(nose))
            nose_colour = glb_report.get("surface", {}).get("nose", {})
            ok("  and its colour survives the bands too",
               nose_colour.get("drift") is not None
               and nose_colour["drift"] <= glb_recipe["maxSurfaceDrift"], str(nose_colour))

            glb_regions = glb_report.get("regions", {})
            ok("the HEIGHT rule split the model into low, middle and high",
               all(glb_regions.get(n, 0) > 0 for n in ("low", "middle", "high")), str(glb_regions))
            hits = {row["name"]: row["faces"] for row in glb_report.get("regionPlanHits", [])}
            ok("the VALUE rule matched faces of its own before smoothing",
               hits.get("bright", 0) > 0, str(hits))
            ok("the run was photographed from the recipe's four cameras, front included",
               sorted(m["file"] for m in glb_report.get("renderStats", []))
               == ["render_front.png", "render_side.png", "render_three-quarter.png",
                   "render_top.png"],
               str(glb_report.get("renders")))
            ok("the front end was taken from the recipe, not measured",
               glb_report.get("orientation", {}).get("frontStated") is True,
               str(glb_report.get("orientation")))
            for stats in glb_report.get("renderStats", []):
                ok("  %s is lit and has a subject" % stats["file"],
                   stats["p99"] > 0.10 and stats["spread"] > 0.05
                   and 0.01 < stats["subjectFraction"] < 0.98, str(stats))

        # ---------------------------------------------------------- the refusals, each proved
        try:
            check_output(os.path.join(REPO, "tools", "nope"))
            ok("it refuses to write inside the repo", False)
        except Refused:
            ok("it refuses to write inside the repo", True)
        try:
            check_output(out_dir)
            ok("it refuses a non-empty output folder", False)
        except Refused:
            ok("it refuses a non-empty output folder", True)
        try:
            find_model(os.path.join(tmp, "in-neutral", "no-such-place"))
            ok("it refuses an input with no model in it", False)
        except (Refused, OSError):
            ok("it refuses an input with no model in it", True)
        # A PLAN THAT CANNOT DECIDE IS REFUSED BEFORE BLENDER IS STARTED, both ways it can happen.
        try:
            check_recipe({"regionPlan": [{"name": "a", "when": {"axisTo": 0.5}}],
                          "regions": {"a": {}}})
            ok("it refuses a region plan with no everything-else", False)
        except Refused:
            ok("it refuses a region plan with no everything-else", True)
        try:
            check_recipe({"regionPlan": [{"name": "ghost"}], "regions": {}})
            ok("it refuses a plan naming a region with no colours", False)
        except Refused:
            ok("it refuses a plan naming a region with no colours", True)
        try:
            load_recipe(None, {}, preset="nope")
            ok("it refuses a preset that does not exist", False)
        except Refused:
            ok("it refuses a preset that does not exist", True)
        ok("both presets are complete enough to run",
           all(check_recipe(json.loads(json.dumps(PRESETS[name]))) for name in PRESETS),
           str(sorted(PRESETS)))
        try:
            glb_triangles(os.path.join(out_dir, "model.fbx"))
            ok("the GLB reader refuses a file that is not a GLB", False)
        except RuntimeError:
            ok("the GLB reader refuses a file that is not a GLB", True)

    print()
    if failures:
        say("SELFTEST FAIL: %d of %d check(s): %s" % (len(failures), checks[0], ", ".join(failures)))
        return 1
    say("SELFTEST PASS: %d checks" % checks[0])
    return 0


def main(argv):
    parser = argparse.ArgumentParser(prog="asset_prep.py", description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    probe = sub.add_parser("probe")
    probe.add_argument("--in", dest="input", required=True)
    probe.add_argument("--model", default=None, help="the model file to read, by name")
    recipe = sub.add_parser("recipe")
    recipe.add_argument("--preset", default="gun", choices=sorted(PRESETS))
    run = sub.add_parser("prep")
    run.add_argument("--in", dest="input", required=True)
    run.add_argument("--out", dest="output", required=True)
    run.add_argument("--preset", default="gun", choices=sorted(PRESETS))
    run.add_argument("--model", default=None, help="the model file to prep, by name")
    run.add_argument("--recipe", default=None)
    run.add_argument("--target", type=int, default=None)
    run.add_argument("--work-px", type=int, default=None)
    run.add_argument("--dry-run", action="store_true")
    run.add_argument("--no-source", action="store_true",
                     help="do not keep the copy of the input beside the results")
    sub.add_parser("selftest")
    args = parser.parse_args(argv[1:])
    handlers = {"probe": command_probe, "recipe": command_recipe, "prep": command_prep,
                "selftest": command_selftest}
    try:
        return handlers[args.command](args)
    except Refused as why:
        say("REFUSED: %s" % why)
        return 2
    except (RuntimeError, subprocess.TimeoutExpired) as why:
        say("FAILED: %s" % why)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
