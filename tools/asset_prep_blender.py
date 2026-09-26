# SPDX-License-Identifier: GPL-2.0-or-later
#
# Driven Hunt -- the Blender half of tools/asset_prep.py. THIS FILE RUNS INSIDE BLENDER and imports
# `bpy`, so it carries Blender's own licence (GPL-2.0-or-later) rather than the repository's terms;
# `tools/asset_prep.py`, which only spawns a process and never imports bpy, does not.
# Blender: https://www.blender.org/about/license/  ("What you create with Blender is your sole
# property" -- the prepped FBX, GLB and PNGs this writes carry no obligation.)
#
# It is invoked as:
#   blender --background --python tools/asset_prep_blender.py -- <job.json>
# and does exactly what the job says, writing `report.json` beside it. It decides NOTHING: every
# number it uses comes from the recipe the driver wrote, so a run is reproducible from that file.
#
# Note: docs/research/2026-09-26-asset-prep.md
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

REPORT = {"steps": [], "warnings": []}


def log(step, **fields):
    entry = {"step": step}
    entry.update(fields)
    REPORT["steps"].append(entry)
    print("[prep] " + step + " " + json.dumps(fields, default=str), flush=True)


def fail(message):
    REPORT["ok"] = False
    REPORT["error"] = message
    print("[prep] FAILED: " + message, flush=True)
    write_report()
    sys.exit(1)


def write_report():
    with open(JOB["reportPath"], "w", encoding="utf-8") as handle:
        json.dump(REPORT, handle, indent=2, default=str)


# ---------------------------------------------------------------- the mesh

def import_model(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    meshes = [ob for ob in bpy.data.objects if ob.type == "MESH"]
    if not meshes:
        fail("the FBX holds no mesh")
    if len(meshes) > 1:
        # JOINED, NOT PICKED: a model that arrives in pieces is still one weapon, and silently
        # keeping the biggest piece is how half a gun ships.
        bpy.ops.object.select_all(action="DESELECT")
        for ob in meshes:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()
        meshes = [bpy.context.view_layer.objects.active]
        REPORT["warnings"].append("%d mesh objects were joined into one" % len(meshes))
    return meshes[0]


def triangles(ob):
    """The MEASURED triangle count of the evaluated object -- modifiers included."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = ob.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    count = len(mesh.loop_triangles)
    evaluated.to_mesh_clear()
    return count


def decimate(ob, target):
    """Collapse-decimate towards `target` triangles, or not at all when `target` is null.

    `None` IS A DECISION, NOT A MISSING VALUE: Roblox allows 20,000 triangles per mesh and Karen's
    shotgun arrives at 19,325, so the default is to ship what arrived. The recipe says why.
    """
    before = triangles(ob)
    if target is None:
        return before, before, 1.0
    target = int(target)
    if before <= target:
        return before, before, 1.0
    ratio = float(target) / float(before)
    modifier = ob.modifiers.new(name="AssetPrepDecimate", type="DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = ratio
    modifier.use_collapse_triangulate = True
    after = triangles(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return before, after, ratio


def long_axis(ob):
    """The index of the model's longest local axis, and whether the muzzle is at its MINIMUM.

    MEASURED, NOT ASSUMED: a shotgun is thin at the muzzle and deep at the butt, so the end whose
    slice is shallower is the muzzle. A model that arrives reversed then shows up in the report
    instead of coming back with a black stock.
    """
    coords = np.array([v.co[:] for v in ob.data.vertices], dtype=np.float64)
    extent = coords.max(axis=0) - coords.min(axis=0)
    axis = int(np.argmax(extent))
    others = [i for i in (0, 1, 2) if i != axis]
    lo, hi = coords[:, axis].min(), coords[:, axis].max()
    span = hi - lo
    near = coords[coords[:, axis] < lo + span * 0.1]
    far = coords[coords[:, axis] > hi - span * 0.1]

    def depth(block):
        if len(block) == 0:
            return 0.0
        return float(max(block[:, i].max() - block[:, i].min() for i in others))

    muzzle_at_min = depth(near) < depth(far)
    return axis, muzzle_at_min, float(lo), float(hi), depth(near), depth(far)


# ---------------------------------------------------------------- the textures

def image_array(image):
    """An image as a float32 HxWx4 array, top row first (Blender stores bottom row first)."""
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    return pixels.reshape((height, width, 4))[::-1].copy()


def set_image(image, array):
    flipped = np.ascontiguousarray(array[::-1], dtype=np.float32)
    image.pixels.foreach_set(flipped.ravel())
    image.update()


def resized(image, px):
    if max(image.size) > px:
        image.scale(px, px)
    return image


def srgb_to_linear(value):
    """One sRGB channel (0..1) to scene-linear.

    THE TARGETS ARE MEASURED FROM A PHOTOGRAPH AND PHOTOGRAPHS ARE sRGB; `image.pixels` is
    scene-linear float. The first run applied sRGB numbers straight to linear pixels and every
    region came out far too light -- the barrels asked for RGB 31 and rendered near-white. There is
    no way to see that in a number: it took a render (rule 5).
      sRGB transfer function: IEC 61966-2-1, as used by Blender's colour management.
    """
    value = np.asarray(value, dtype=np.float64)
    return np.where(value <= 0.04045, value / 12.92, ((value + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(value):
    value = np.asarray(value, dtype=np.float64)
    return np.where(value <= 0.0031308, value * 12.92, 1.055 * np.power(np.maximum(value, 0.0), 1 / 2.4) - 0.055)


def target_hsv(rgb255, linearise):
    """A measured sRGB triple (0..255) as the (hue, saturation, value) the correction aims at."""
    rgb = np.array(rgb255, dtype=np.float64) / 255.0
    if linearise:
        rgb = srgb_to_linear(rgb)
    block = rgb.reshape((1, 1, 3)).astype(np.float32)
    hue, saturation, value = rgb_to_hsv(block)
    return float(hue[0, 0]), float(saturation[0, 0]), float(value[0, 0])


def rgb_to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    maxc, minc = np.max(rgb[..., :3], axis=-1), np.min(rgb[..., :3], axis=-1)
    value = maxc
    delta = maxc - minc
    saturation = np.where(maxc > 0, delta / np.maximum(maxc, 1e-8), 0.0)
    hue = np.zeros_like(maxc)
    safe = delta > 1e-8
    rmax = safe & (maxc == r)
    gmax = safe & (maxc == g) & ~rmax
    bmax = safe & ~rmax & ~gmax
    hue[rmax] = ((g - b)[rmax] / delta[rmax]) % 6.0
    hue[gmax] = ((b - r)[gmax] / delta[gmax]) + 2.0
    hue[bmax] = ((r - g)[bmax] / delta[bmax]) + 4.0
    return (hue / 6.0) % 1.0, saturation, value


def hsv_to_rgb(hue, saturation, value):
    i = np.floor(hue * 6.0)
    f = hue * 6.0 - i
    p = value * (1.0 - saturation)
    q = value * (1.0 - f * saturation)
    t = value * (1.0 - (1.0 - f) * saturation)
    i = (i % 6).astype(np.int32)
    out = np.zeros(hue.shape + (3,), dtype=np.float32)
    for index, (rr, gg, bb) in enumerate(((value, t, p), (q, value, p), (p, value, t),
                                          (p, q, value), (t, p, value), (value, p, q))):
        m = i == index
        out[m, 0], out[m, 1], out[m, 2] = rr[m], gg[m], bb[m]
    return out


def rasterise(masks, uvs, region_of, size):
    """Paint each triangle's UV footprint into its region's boolean mask, at `size` x `size`."""
    for tri_index, region in enumerate(region_of):
        mask = masks[region]
        # THE ROW IS (1 - v), NOT v, AND THIS ONE LINE WAS THE WHOLE DEFECT OF ROUND 1.
        # `image_array` flips the image so row 0 is the TOP, which is what the classifier samples
        # with; this function indexed the mask with v directly, so every region's mask was the
        # VERTICAL MIRROR of the pixels it then edited. The barrels' near-black was painted onto
        # whatever wood texels sat at the mirrored position and the walnut onto the barrels -- hard
        # triangle-shaped patches of the wrong colour over the whole gun, which is exactly the
        # black-and-orange camouflage the Director saw. Every colour still landed on its target
        # because the median was measured through the same mirrored mask: the numbers agreed with
        # each other and with nothing in the world (docs/PROJECT_CONTEXT.md, "things measured
        # correct and looked wrong").
        uv = uvs[tri_index].copy()
        uv[:, 1] = 1.0 - uv[:, 1]
        uv = uv * size
        min_x = max(int(math.floor(uv[:, 0].min())) - 1, 0)
        max_x = min(int(math.ceil(uv[:, 0].max())) + 1, size - 1)
        min_y = max(int(math.floor(uv[:, 1].min())) - 1, 0)
        max_y = min(int(math.ceil(uv[:, 1].max())) + 1, size - 1)
        if max_x < min_x or max_y < min_y:
            continue
        xs = np.arange(min_x, max_x + 1) + 0.5
        ys = np.arange(min_y, max_y + 1) + 0.5
        gx, gy = np.meshgrid(xs, ys)
        (x0, y0), (x1, y1), (x2, y2) = uv
        denominator = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(denominator) < 1e-12:
            continue
        a = ((y1 - y2) * (gx - x2) + (x2 - x1) * (gy - y2)) / denominator
        b = ((y2 - y0) * (gx - x2) + (x0 - x2) * (gy - y2)) / denominator
        c = 1.0 - a - b
        inside = (a >= -0.002) & (b >= -0.002) & (c >= -0.002)
        if inside.any():
            mask[min_y:max_y + 1, min_x:max_x + 1] |= inside


def feather(mask, rounds):
    """A boolean mask as a float weight with a soft edge.

    A HARD MASK IS A HARD EDGE IN THE FINISHED TEXTURE. The mask follows triangle boundaries, so
    wherever the region rule ran through the middle of a continuous surface the atlas got an angular
    step -- which is what the Director saw as camouflage shards. Blurring the mask turns the step
    into a ramp a few texels wide; a real boundary (wood meeting metal) is still a boundary, because
    the geometry there is a boundary too.
    """
    weight = mask.astype(np.float32)
    for _ in range(max(rounds, 0)):
        padded = np.pad(weight, 1, mode="edge")
        weight = (padded[:-2, 1:-1] + padded[2:, 1:-1] + padded[1:-1, :-2] + padded[1:-1, 2:]
                  + weight * 2.0) / 6.0
    return weight


def dilate(mask, rounds):
    """Grow a mask by `rounds` pixels, so a UV seam does not show the old colour."""
    out = mask.copy()
    for _ in range(rounds):
        grown = out.copy()
        grown[1:, :] |= out[:-1, :]
        grown[:-1, :] |= out[1:, :]
        grown[:, 1:] |= out[:, :-1]
        grown[:, :-1] |= out[:, 1:]
        out = grown
    return out


def correct_colour(array, mask, op, linearise, weight=None):
    """Move the masked pixels onto a measured target in HSV, keeping each pixel's ratio to the median.

    THE DETAIL SURVIVES BY CONSTRUCTION: grain and engraving are variation AROUND the region's
    median, and only the median is moved. A flat fill would erase exactly what is worth keeping.

    THE TARGET IS AN sRGB TRIPLE, because that is what a colour sampled off a photograph is, and it
    is converted to scene-linear here when the image is linear float. Getting that wrong is invisible
    in every number the run prints and obvious in the first render.
    """
    if not mask.any() or op.get("skip"):
        # `skip` is how a region is left exactly as it arrived -- used to bisect which half of a run
        # changed something, which is how round 2 found out where the damage actually was.
        return {"pixels": 0, "skipped": bool(op.get("skip"))}
    target_hue, target_saturation, target_value = target_hsv(op["targetRGB"], linearise)
    rgb = array[..., :3]
    hue, saturation, value = rgb_to_hsv(rgb)
    selected = mask
    median_value = max(float(np.median(value[selected])), 1e-4)
    contrast = float(op.get("contrast", 1.0))
    if "levels" in op:
        # LEVELS, and this is the one that actually worked on the wood. A generator bakes shadow and
        # ambient occlusion into the base colour, so Meshy's walnut arrives as near-BLACK figure on
        # bright orange. Every multiplicative rule -- exponent, median ratio, spread -- leaves a
        # pixel that is already at zero at zero, so the gun rendered as orange tiger stripe three
        # runs in a row (rule 5). This maps the region's own low and high percentiles onto a band
        # around the target instead, which LIFTS the baked black off the floor. An albedo should not
        # carry lighting in the first place; this is how it is taken back out.
        spec = op["levels"]
        low = float(np.percentile(value[selected], float(spec.get("lowPct", 5.0))))
        high = float(np.percentile(value[selected], float(spec.get("highPct", 95.0))))
        span = max(high - low, 1e-4)
        floor_value = target_value * float(spec.get("lowScale", 0.45))
        ceiling = target_value * float(spec.get("highScale", 1.6))
        new_value = np.clip(floor_value + (value[selected] - low) * (ceiling - floor_value) / span,
                            0.0, 1.0)
    elif "valueSpread" in op:
        # THE SAME COMPRESSION AS `satSpread`, AND THE WOOD NEEDED IT MORE. A generator bakes shadow
        # and ambient occlusion into the base colour, so the walnut arrives as near-black figure on
        # bright orange; a multiplicative exponent keeps that ratio however far the median moves, and
        # the gun rendered as tiger stripe three times running (rule 5). Moving each pixel a fraction
        # of its distance from the median flattens the baked lighting -- which an albedo should not
        # carry anyway -- and leaves the grain as grain.
        new_value = np.clip(
            target_value + (value[selected] - median_value) * float(op["valueSpread"]), 0.0, 1.0)
    else:
        new_value = np.clip(
            target_value * np.power(value[selected] / median_value, contrast), 0.0, 1.0)
    if op.get("keepHue", False):
        # A NEUTRAL REGION: keep whatever hue the pixel had and crush the saturation, so blued steel
        # and silver stay grey without inventing a colour cast.
        new_hue = hue[selected]
        new_saturation = np.clip(saturation[selected] * float(op.get("satScale", 0.0)), 0.0, 1.0)
    else:
        new_hue = np.full_like(hue[selected], target_hue)
        median_saturation = max(float(np.median(saturation[selected])), 1e-4)
        # SATURATION IS COMPRESSED TOWARDS THE TARGET, NOT SCALED BY RATIO. Scaling kept each
        # pixel's ratio to the median, which sounds even-handed and is not: a grain pixel at twice
        # the median clips at fully saturated, and Meshy's walnut is full of them -- the first pass
        # rendered as orange tiger stripe (rule 5). `satSpread` is how much of the original spread
        # survives: 1.0 is the old behaviour, 0 is a flat colour, and the grain is what lives in
        # between.
        spread = float(op.get("satSpread", 1.0))
        new_saturation = np.clip(
            target_saturation + (saturation[selected] - median_saturation) * spread, 0.0, 1.0)
    out = hsv_to_rgb(new_hue, new_saturation, new_value)
    if weight is None:
        array[..., :3][selected] = out
    else:
        # LERP, NOT REPLACE: the mask's soft edge is what stops a region boundary becoming a shard.
        blend = weight[selected][:, None]
        array[..., :3][selected] = array[..., :3][selected] * (1.0 - blend) + out * blend
    # WHAT IT ACTUALLY BECAME, in the same sRGB numbers the target was written in. Without this the
    # only way to check a correction landed is to squint at a render, and three runs were spent
    # doing exactly that while the textures were in fact changing every time.
    achieved = np.median(out, axis=0)
    achieved_srgb = [int(round(float(c) * 255)) for c in linear_to_srgb(achieved)] if linearise         else [int(round(float(c) * 255)) for c in achieved]
    return {"pixels": int(selected.sum()),
            "medianValueBefore": round(median_value, 4),
            "targetRGB": list(op["targetRGB"]),
            "achievedRGB": achieved_srgb,
            "targetValueLinear": round(target_value, 4),
            "linearised": bool(linearise)}


def push_channel(array, mask, target, weight):
    """Blend a greyscale map's masked pixels towards `target` -- Karen's "too shiny" dial."""
    if not mask.any() or target is None:
        return 0
    for channel in range(3):
        plane = array[..., channel]
        plane[mask] = plane[mask] * (1.0 - weight) + float(target) * weight
    return int(mask.sum())


# ---------------------------------------------------------------- rendering

def studio(ob, size_px, samples):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = size_px
    scene.render.resolution_y = int(size_px * 0.66)
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("prep")
    world.use_nodes = True
    # AN 18% GREY STUDIO, which is what Karen's reference photographs were shot in and the only
    # honest background for judging metal: a metallic surface shows the room, so a black room makes
    # a bright silver action render black and a white room makes a blued barrel render chrome. Both
    # of those happened here before this line was a measured choice (rule 5).
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.18, 0.185, 0.19, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scene.world = world
    try:
        scene.eevee.taa_render_samples = samples
    except AttributeError:
        pass
    # STANDARD, NOT AgX. The default view transform is a film emulation: it rolls off highlights and
    # desaturates them, so a preview taken through it answers "how would this be graded" and not
    # "what colour is this texture" -- which is the only question these four renders exist to answer.
    try:
        scene.view_settings.view_transform = "Standard"
        scene.view_settings.look = "None"
    except (AttributeError, TypeError):
        REPORT["warnings"].append("could not set the Standard view transform")
    # MEASURED BY LOOKING (rule 5): at 900 W these three lamps blew a 2 m object to white and the
    # barrels rendered as chrome whatever the albedo said. Scaled to the model instead of fixed, so a
    # bigger or smaller asset is lit the same way.
    unit = max(max(ob.dimensions), 0.2) ** 2
    for name, location, energy in (("KeyLight", (2.5, -3.0, 3.0), 30.0 * unit),
                                   ("FillLight", (-3.0, -2.0, 1.2), 10.0 * unit),
                                   ("RimLight", (0.0, 3.5, 2.0), 18.0 * unit)):
        light_data = bpy.data.lights.new(name, type="AREA")
        light_data.energy = energy
        light_data.size = 3.0
        light = bpy.data.objects.new(name, light_data)
        light.location = location
        constraint = light.constraints.new("TRACK_TO")
        constraint.target = ob
        bpy.context.collection.objects.link(light)


def look_at(camera, target, distance, direction, ortho_scale):
    camera.location = target + Vector(direction).normalized() * distance
    if ortho_scale:
        camera.data.type = "ORTHO"
        camera.data.ortho_scale = ortho_scale
    else:
        camera.data.type = "PERSP"
    constraint = camera.constraints.new("TRACK_TO")
    constraint.target = bpy.data.objects.get("PrepTarget")


def measure_render(path):
    """Load a written render back and say how bright it actually is.

    A RENDER NOBODY MEASURES IS A BLANK SCREEN WAITING TO HAPPEN -- docs/PROJECT_CONTEXT.md records a
    visibility audit that "certified a blank screen twice", and the first version of this tool wrote
    four pure-black PNGs because the lighting function was never called and a file-size check passed
    them. So every render reports its own luminance, and the selftest fails on a flat image.
    """
    image = bpy.data.images.load(path)
    try:
        pixels = np.empty(len(image.pixels), dtype=np.float32)
        image.pixels.foreach_get(pixels)
        rgb = pixels.reshape((-1, 4))[:, :3]
        luma = rgb.mean(axis=1)
        median = float(np.median(luma))
        width, height = image.size
        grid = luma.reshape((height, width))
        subject = np.abs(grid - median) > 0.02
        # EDGE DENSITY: how much of the SUBJECT is a hard boundary. Smooth wood grain is low; the
        # angular black-and-orange shards a scrambled UV produces are high. This is the number that
        # catches "the tool wrecked the texture" without a human in the loop (Director, round 2).
        dx = np.abs(np.diff(grid, axis=1))
        dy = np.abs(np.diff(grid, axis=0))
        edges = np.zeros_like(grid, dtype=bool)
        edges[:, :-1] |= dx > 0.06
        edges[:-1, :] |= dy > 0.06
        subject_count = max(int(subject.sum()), 1)
        rgb_grid = rgb.reshape((height, width, 3))
        subject_rgb = rgb_grid[subject] if subject.any() else rgb_grid.reshape((-1, 3))
        mean_linear = subject_rgb.mean(axis=0)
        mean_srgb = [int(round(float(c) * 255)) for c in linear_to_srgb(mean_linear)]
        return {
            "edgeDensity": round(float((edges & subject).sum()) / subject_count, 4),
            "subjectMeanRGB": mean_srgb,
            "file": os.path.basename(path),
            "mean": round(float(luma.mean()), 4),
            "max": round(float(luma.max()), 4),
            "p99": round(float(np.percentile(luma, 99)), 4),
            "p01": round(float(np.percentile(luma, 1)), 4),
            # THE TWO NUMBERS THAT CATCH A BLANK PREVIEW, and neither is brightness: `spread` is
            # dark-to-light across the frame, and `subjectFraction` is how much of the frame differs
            # from the background at all. A black render fails on spread; a render of an empty grey
            # studio fails on subject. The first version of this check asked "is it bright", which a
            # picture of nothing but a lit backdrop passes.
            "spread": round(float(np.percentile(luma, 99) - np.percentile(luma, 1)), 4),
            "subjectFraction": round(float((np.abs(luma - median) > 0.02).mean()), 4),
        }
    finally:
        bpy.data.images.remove(image)


def render_views(ob, out_dir, size_px, samples, prefix="render"):
    # ONE RIG PER CALL, and it is removed at the end: this runs twice (once on the source, once on
    # the prepped model) and a second PrepTarget would make the TRACK_TO constraints point at the
    # wrong empty.
    for stale in ("PrepTarget", "PrepCamera"):
        old_object = bpy.data.objects.get(stale)
        if old_object:
            bpy.data.objects.remove(old_object, do_unlink=True)
    bpy.ops.object.empty_add(location=ob.location)
    empty = bpy.context.object
    empty.name = "PrepTarget"
    corners = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    centre = sum(corners, Vector((0, 0, 0))) / 8.0
    empty.location = centre
    extent = Vector((max(c.x for c in corners) - min(c.x for c in corners),
                     max(c.y for c in corners) - min(c.y for c in corners),
                     max(c.z for c in corners) - min(c.z for c in corners)))
    span = max(extent)
    camera_data = bpy.data.cameras.new("PrepCamera")
    camera_data.clip_start = 0.01
    camera_data.clip_end = max(span * 20.0, 100.0)
    camera = bpy.data.objects.new("PrepCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    written = []
    # THE FOUR QUESTIONS: does it read as a gun from the side, are the two barrels side by side from
    # above and from the muzzle, and does it hold together in a three-quarter view.
    # FRAMED FROM THE MEASURED BOUNDING BOX, and tight: the first pass used twice the span and the
    # gun sat in the middle third of the picture, which is a preview nobody can judge detail from.
    views = (("side", (0.0, -1.0, 0.06), span * 1.2, span * 1.08),
             ("top", (0.0, -0.02, 1.0), span * 1.2, span * 1.08),
             # STRAIGHT DOWN THE BARRELS, and far enough back that the near end is not clipped: at
             # half a span the camera stood ON the muzzle and the render showed the middle of the gun.
             ("muzzle", (-1.0, -0.015, 0.02), span * 1.3, max(extent.y, extent.z) * 2.8),
             ("three-quarter", (-0.7, -1.0, 0.38), span * 0.75, 0.0))
    for name, direction, distance, ortho in views:
        for constraint in list(camera.constraints):
            camera.constraints.remove(constraint)
        look_at(camera, centre, distance, direction, ortho)
        bpy.context.view_layer.update()
        path = os.path.join(out_dir, "%s_%s.png" % (prefix, name))
        bpy.context.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        written.append(measure_render(path))
    bpy.data.objects.remove(empty, do_unlink=True)
    bpy.data.objects.remove(camera, do_unlink=True)
    return written


# ---------------------------------------------------------------- the run

def main():
    global JOB
    argv = sys.argv[sys.argv.index("--") + 1:]
    with open(argv[0], "r", encoding="utf-8") as handle:
        JOB = json.load(handle)
    recipe = JOB["recipe"]
    out_dir = JOB["outDir"]

    ob = import_model(JOB["fbx"])
    log("imported", object=ob.name, triangles=triangles(ob), vertices=len(ob.data.vertices),
        materials=[m.name if m else None for m in ob.data.materials])

    # THE SOURCE, PHOTOGRAPHED BEFORE ANYTHING IS DONE TO IT (Director, round 2). Round 1 shipped a
    # model whose wood had turned into angular black-and-orange shards and whose barrels had turned
    # into mirror chrome, and nothing in the tool noticed -- the only comparison available was the
    # Director's memory of his own render. Now every run carries the before picture beside the after
    # one, at the same four cameras, and the numbers from both are in the report.
    studio(ob, int(recipe["renderPx"]), int(recipe["renderSamples"]))
    if recipe.get("renderSource", True):
        REPORT["sourceStats"] = render_views(ob, out_dir, int(recipe["renderPx"]),
                                             int(recipe["renderSamples"]), prefix="source")
        log("renderedSource", files=REPORT["sourceStats"])

    before, after, ratio = decimate(ob, recipe["targetTriangles"])
    log("decimated", before=before, measuredAfter=after, ratioAsked=round(ratio, 6),
        target=recipe["targetTriangles"])
    REPORT["triangles"] = {"before": before, "after": after, "target": recipe["targetTriangles"]}

    axis, muzzle_at_min, lo, hi, near_depth, far_depth = long_axis(ob)
    log("oriented", axis="XYZ"[axis], muzzleAtMin=muzzle_at_min, low=round(lo, 4), high=round(hi, 4),
        nearDepth=round(near_depth, 4), farDepth=round(far_depth, 4))
    REPORT["orientation"] = {"axis": "XYZ"[axis], "muzzleAtMin": muzzle_at_min}

    # ---- the base colour image, and the regions
    material = ob.data.materials[0] if ob.data.materials else None
    if material is None or not material.node_tree:
        fail("the mesh has no material with a node tree")
    base_image = metallic_image = roughness_image = None
    principled = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if principled is None:
        fail("the material has no Principled BSDF")

    def linked_image(socket_name):
        socket = principled.inputs.get(socket_name)
        if socket is None or not socket.is_linked:
            return None
        node = socket.links[0].from_node
        while node and node.type != "TEX_IMAGE":
            if not node.inputs or not any(i.is_linked for i in node.inputs):
                return None
            node = next(i.links[0].from_node for i in node.inputs if i.is_linked)
        return node.image if node and node.type == "TEX_IMAGE" else None

    base_image = linked_image("Base Color")
    metallic_image = linked_image("Metallic")
    roughness_image = linked_image("Roughness")
    normal_image = linked_image("Normal")
    if base_image is None:
        fail("the material has no base colour texture")
    if tuple(base_image.size) == (0, 0):
        fail("the base colour texture has no pixels (image '%s' did not load from the FBX)"
             % base_image.name)

    work_px = int(recipe["workPx"])
    sizes_before = {}
    for name, image in (("baseColor", base_image), ("metallic", metallic_image),
                        ("roughness", roughness_image), ("normal", normal_image)):
        if image is not None:
            sizes_before[name] = list(image.size)
            resized(image, work_px)
    log("textures", before=sizes_before, workPx=work_px,
        after={k: list(v.size) for k, v in (("baseColor", base_image), ("metallic", metallic_image),
                                            ("roughness", roughness_image), ("normal", normal_image))
               if v is not None})
    REPORT["textures"] = {"before": sizes_before, "workPx": work_px}

    mesh = ob.data
    mesh.calc_loop_triangles()
    uv_layer = mesh.uv_layers.active
    if uv_layer is None:
        fail("the mesh has no UV map")
    uv_data = np.empty(len(mesh.loops) * 2, dtype=np.float32)
    uv_layer.uv.foreach_get("vector", uv_data)
    uv_data = uv_data.reshape((-1, 2))
    tris = list(mesh.loop_triangles)
    tri_uv = np.array([[uv_data[li] for li in t.loops] for t in tris], dtype=np.float32)
    tri_centre_uv = tri_uv.mean(axis=1)

    base = image_array(base_image)
    size = base.shape[0]
    # SEVEN SAMPLES PER TRIANGLE, AND THE MEDIAN OF THEM -- not one texel at the centroid.
    # ONE TEXEL IS WHAT BROKE ROUND 1. Meshy bakes near-black figure into the walnut, so a triangle
    # whose centroid happened to land on a dark streak read as unsaturated, failed the "is it woody"
    # test, and was recoloured as barrel (near-black) or action (silver) in the middle of the stock.
    # Triangle by triangle, that is exactly the black-and-orange camouflage the Director saw.
    barycentric = np.array([[1 / 3, 1 / 3, 1 / 3],
                            [0.6, 0.2, 0.2], [0.2, 0.6, 0.2], [0.2, 0.2, 0.6],
                            [0.45, 0.45, 0.1], [0.45, 0.1, 0.45], [0.1, 0.45, 0.45]])
    samples = np.einsum("sk,tkc->tsc", barycentric, tri_uv)  # (triangles, 7, 2)
    coords = np.clip((samples * size).astype(np.int32), 0, size - 1)
    picked = base[size - 1 - coords[:, :, 1], coords[:, :, 0], :3]  # (triangles, 7, 3)
    sampled = np.median(picked, axis=1)
    hue, saturation, _ = rgb_to_hsv(sampled.reshape((-1, 1, 3)))
    hue = hue.ravel()
    saturation = saturation.ravel()

    coords = np.array([v.co[:] for v in mesh.vertices], dtype=np.float64)
    tri_pos = np.array([[coords[v] for v in t.vertices] for t in tris]).mean(axis=1)
    t_axis = (tri_pos[:, axis] - lo) / max(hi - lo, 1e-9)
    if not muzzle_at_min:
        t_axis = 1.0 - t_axis

    def smooth_regions(labels, tris_list, rounds):
        """Majority vote over neighbouring faces, `rounds` times.

        A PER-TRIANGLE DECISION WITH NO NEIGHBOURHOOD IS SPECKLE, and speckle in a region map is
        visible as hard-edged patches in the finished texture -- one triangle of silver in the middle
        of a stock is a shard. Faces that share two vertices are neighbours; three rounds is enough
        to drown out isolated mistakes without eating a real boundary, which is many triangles wide.
        """
        by_vertex = {}
        for index, tri in enumerate(tris_list):
            for vertex in tri.vertices:
                by_vertex.setdefault(vertex, []).append(index)
        neighbours = []
        for index, tri in enumerate(tris_list):
            seen = {}
            for vertex in tri.vertices:
                for other in by_vertex[vertex]:
                    if other != index:
                        seen[other] = seen.get(other, 0) + 1
            neighbours.append([other for other, shared in seen.items() if shared >= 2])
        changed_total = 0
        labels = list(labels)
        for _ in range(rounds):
            updated = list(labels)
            changed = 0
            for index, mates in enumerate(neighbours):
                if not mates:
                    continue
                votes = {labels[index]: 1}
                for other in mates:
                    votes[labels[other]] = votes.get(labels[other], 0) + 1
                best = max(votes.items(), key=lambda kv: (kv[1], kv[0] == labels[index]))[0]
                if best != labels[index]:
                    changed += 1
                updated[index] = best
            labels = updated
            changed_total += changed
            if changed == 0:
                break
        return labels, changed_total, neighbours

    def speckle_of(labels, neighbours):
        """The fraction of faces that disagree with every one of their neighbours."""
        lonely = 0
        for index, mates in enumerate(neighbours):
            if mates and all(labels[other] != labels[index] for other in mates):
                lonely += 1
        return round(lonely / max(len(labels), 1), 4)

    wood_rule = recipe["regions"]["wood"]["rule"]
    woody = ((saturation >= float(wood_rule["satMin"]))
             & (hue * 360.0 >= float(wood_rule["hueLoDeg"]))
             & (hue * 360.0 <= float(wood_rule["hueHiDeg"])))
    action_start = float(recipe["actionStartT"])
    raw = np.where(woody, "wood", np.where(t_axis < action_start, "barrel", "action"))
    rounds = int(recipe.get("regionSmoothRounds", 3))
    smoothed, changed, neighbours = smooth_regions(list(raw), tris, rounds)
    speckle_before = speckle_of(list(raw), neighbours)
    speckle_after = speckle_of(smoothed, neighbours)
    region_of = np.array(smoothed)
    counts = {name: int((region_of == name).sum()) for name in ("barrel", "action", "wood")}
    log("regions", triangles=counts, actionStartT=action_start, rule=wood_rule,
        smoothRounds=rounds, reassigned=changed, speckleBefore=speckle_before,
        speckleAfter=speckle_after)
    REPORT["regions"] = counts
    REPORT["regionSpeckle"] = {"before": speckle_before, "after": speckle_after,
                               "reassigned": changed, "rounds": rounds}
    ceiling_speckle = float(recipe.get("maxRegionSpeckle", 0.01))
    if speckle_after > ceiling_speckle:
        REPORT["warnings"].append(
            "%.1f%% of faces still disagree with every neighbour after smoothing (ceiling %.1f%%): "
            "the region map is speckled and the texture will show it as patches"
            % (speckle_after * 100, ceiling_speckle * 100))
    if min(counts.values()) == 0:
        REPORT["warnings"].append("a region came out empty: %s" % counts)

    masks = {name: np.zeros((size, size), dtype=bool) for name in counts}
    rasterise(masks, tri_uv, list(region_of), size)
    dilation = int(recipe.get("maskDilatePx", 4))
    masks = {name: dilate(mask, dilation) for name, mask in masks.items()}
    feather_px = int(recipe.get("maskFeatherPx", 6))
    weights = {name: feather(mask, feather_px) for name, mask in masks.items()}
    log("masks", pixels={k: int(v.sum()) for k, v in masks.items()}, dilatePx=dilation,
        featherPx=feather_px)

    # `image.pixels` is scene-linear whenever the image is tagged sRGB, which every base colour map
    # out of a generator is. The report says which way it was taken, so a future odd colour has a
    # line to check rather than a mystery.
    linearise = base_image.colorspace_settings.name in ("sRGB", "Filmic sRGB")
    corrections = {"colorspace": base_image.colorspace_settings.name, "linearised": linearise}
    for name in ("barrel", "action", "wood"):
        op = dict(recipe["regions"][name]["baseColor"])
        corrections[name] = correct_colour(base, masks[name], op, linearise, weights[name])
    set_image(base_image, base)

    # ---- WHAT THE SURFACE ACTUALLY SHOWS, sampled back THROUGH THE MESH.
    #
    # The `achievedRGB` above is measured through the same mask that did the writing, so it agrees
    # with itself no matter where the mask landed -- round 1 reported every colour dead on target
    # while the gun was painted in camouflage, because the mask was the vertical mirror of the
    # region it was measured on. This measurement uses a different route: it takes each region's
    # TRIANGLES, samples the corrected texture at their UV footprints, and reports the median. If
    # the mask is upside down, or shifted, or the wrong region's, the two numbers disagree -- which
    # is the only way a program can notice, and it is how the selftest now catches that defect.
    verified = {}
    for name in ("barrel", "action", "wood"):
        rows = region_of == name
        if not rows.any():
            continue
        coords_here = np.clip((samples[rows] * size).astype(np.int32), 0, size - 1)
        picked_here = base[size - 1 - coords_here[:, :, 1], coords_here[:, :, 0], :3]
        median_rgb = np.median(picked_here.reshape((-1, 3)), axis=0)
        shown = [int(round(float(c) * 255)) for c in linear_to_srgb(median_rgb)] if linearise             else [int(round(float(c) * 255)) for c in median_rgb]
        wanted = recipe["regions"][name]["baseColor"].get("targetRGB")
        drift = max(abs(a - b) for a, b in zip(shown, wanted)) if wanted else None
        verified[name] = {"shownRGB": shown, "targetRGB": wanted, "drift": drift}
    REPORT["surface"] = verified
    log("surface", shown=verified)
    ceiling_drift = float(recipe.get("maxSurfaceDrift", 45))
    off = {k: v for k, v in verified.items() if v["drift"] is not None and v["drift"] > ceiling_drift}
    if off:
        REPORT["warnings"].append(
            "sampled through the mesh, %s do not show the colour they were given (drift over %d): "
            "the masks are not where the correction thinks they are"
            % (", ".join(sorted(off)), ceiling_drift))

    REPORT["corrections"] = corrections
    log("baseColour", corrections=corrections)

    # ---- ONE MATERIAL PER REGION, AND THE PBR VALUES LIVE ON THE MATERIAL, NOT IN THE MAP.
    #
    # Round 1 painted each region's roughness and metallic INTO the shared maps through the same
    # triangle-shaped masks, and a step in roughness is as visible as a step in colour: with the
    # albedo left completely untouched the prepped model still came back with 1.4x the source's edge
    # density (measured, round 2). A material scalar has no edges at all -- the boundary is the
    # boundary between two materials, which is where the model's own geometry already is -- and it is
    # what "give each region its own material" is for. The map is disconnected on that material so
    # the scalar is the value that ships.
    made = {}
    for name in ("barrel", "action", "wood"):
        new_material = material.copy()
        new_material.name = "dh_%s" % name
        settings = recipe["regions"][name]
        node = next((n for n in new_material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if node is not None:
            for socket_name, key in (("Metallic", "metallic"), ("Roughness", "roughness")):
                value = settings.get(key)
                socket = node.inputs.get(socket_name)
                if value is None or socket is None:
                    continue
                for link in list(socket.links):
                    new_material.node_tree.links.remove(link)
                socket.default_value = float(value)
        made[name] = len(mesh.materials)
        mesh.materials.append(new_material)
    log("materialValues", values={name: {"metallic": recipe["regions"][name].get("metallic"),
                                         "roughness": recipe["regions"][name].get("roughness")}
                                  for name in ("barrel", "action", "wood")})
    slot_of = {name: made[name] for name in made}
    indices = np.array([slot_of[r] for r in region_of], dtype=np.int32)
    poly_material = np.zeros(len(mesh.polygons), dtype=np.int32)
    for tri, index in zip(tris, indices):
        poly_material[tri.polygon_index] = index
    mesh.polygons.foreach_set("material_index", poly_material)
    mesh.update()
    log("materials", slots=[m.name for m in mesh.materials], assigned=slot_of)
    REPORT["materials"] = [m.name for m in mesh.materials]

    # ---- write the corrected textures beside the exports
    written = []
    for name, image in (("baseColor", base_image), ("metallic", metallic_image),
                        ("roughness", roughness_image)):  # the last two are unchanged since Task 72r2
        if image is None:
            continue
        path = os.path.join(out_dir, "texture_%s.png" % name)
        image.filepath_raw = path
        image.file_format = "PNG"
        image.save()
        written.append(os.path.basename(path))
    log("wroteTextures", files=written)
    REPORT["texturesWritten"] = written

    # The lighting rig is already up (the source renders needed it). Without it every render comes
    # out pure black, which is exactly what the first version of this tool produced.
    measured = render_views(ob, out_dir, int(recipe["renderPx"]), int(recipe["renderSamples"]))
    log("rendered", files=measured)
    REPORT["renderStats"] = measured
    REPORT["renders"] = [m["file"] for m in measured]

    # ---- BEFORE AGAINST AFTER, as numbers. A colour is MEANT to move; the texture's structure is
    # not. `edgeDensityRatio` above 1 means the prepped model has harder boundaries than the source
    # -- shards where there was grain -- and that is the failure round 1 shipped.
    source_by_view = {m["file"].split("_", 1)[1]: m for m in REPORT.get("sourceStats", [])}
    comparison = []
    worst = 0.0
    for after in measured:
        view = after["file"].split("_", 1)[1]
        before = source_by_view.get(view)
        if not before:
            continue
        ratio = after["edgeDensity"] / max(before["edgeDensity"], 1e-4)
        worst = max(worst, ratio)
        comparison.append({
            "view": view,
            "edgeDensityBefore": before["edgeDensity"],
            "edgeDensityAfter": after["edgeDensity"],
            "edgeDensityRatio": round(ratio, 3),
            "meanRGBBefore": before["subjectMeanRGB"],
            "meanRGBAfter": after["subjectMeanRGB"],
        })
    REPORT["comparison"] = comparison
    REPORT["worstEdgeDensityRatio"] = round(worst, 3)
    ceiling = float(recipe.get("maxEdgeDensityRatio", 1.25))
    if worst > ceiling:
        REPORT["warnings"].append(
            "the prepped model has %.2fx the edge density of the source (ceiling %.2f): the texture "
            "has been broken up, not just recoloured" % (worst, ceiling))
    log("compared", worstEdgeDensityRatio=round(worst, 3), ceiling=ceiling, views=comparison)

    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    fbx_path = os.path.join(out_dir, "model.fbx")
    bpy.ops.export_scene.fbx(filepath=fbx_path, use_selection=True, path_mode="COPY",
                             embed_textures=True, mesh_smooth_type="FACE")
    glb_path = os.path.join(out_dir, "model.glb")
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", use_selection=True)
    REPORT["exports"] = {
        "model.fbx": os.path.getsize(fbx_path),
        "model.glb": os.path.getsize(glb_path),
    }
    log("exported", sizes=REPORT["exports"])

    REPORT["ok"] = True
    REPORT["trianglesFinal"] = triangles(ob)
    write_report()
    print("[prep] done", flush=True)


if __name__ == "__main__":
    # A CRASH MUST STILL BE A REPORT. Without this the driver could only say "Blender wrote no
    # report", which hides the one line that says what actually went wrong.
    try:
        main()
    except SystemExit:
        raise
    except Exception as why:  # noqa: BLE001 -- the traceback is the product here
        import traceback
        REPORT["ok"] = False
        REPORT["error"] = "%s: %s" % (type(why).__name__, why)
        REPORT["traceback"] = traceback.format_exc()
        print("[prep] CRASHED: " + REPORT["error"], flush=True)
        try:
            write_report()
        finally:
            sys.exit(1)
