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
from mathutils import Matrix, Vector

import bmesh

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
    """Open an .fbx, .glb or .gltf. The container is not the work (Task 69).

    Meshy returns a GLB for a refined model and an FBX for others, and the whole difference to this
    tool is which importer runs -- except for one thing that is NOT cosmetic and is handled below:
    glTF packs metalness and roughness into one image.
    """
    bpy.ops.wm.read_factory_settings(use_empty=True)
    extension = os.path.splitext(path)[1].lower()
    if extension == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif extension in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    else:
        fail("not a model this tool can open: %s" % os.path.basename(path))
    meshes = [ob for ob in bpy.data.objects if ob.type == "MESH"]
    if not meshes:
        fail("the model holds no mesh")
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


def shade(ob, angle_deg):
    """SMOOTH NORMALS, SHARP ONLY WHERE THE MODEL REALLY TURNS (task 92).

    Karen, after playing the first-person build: "Weapon color we need to improve and style now
    feels a bit broken, it has to be smooth and nice." What she is looking at is FLAT SHADING -- the
    export asked for `mesh_smooth_type="FACE"`, so every one of the model's 19,000 triangles was lit
    as its own plane, and a round barrel became a ring of bright shards with dark seams between them.

    The fix is the one Blender has for exactly this: shade the mesh smooth, then mark as sharp only
    the edges whose two faces meet at more than `angle_deg`. A gun wants both -- the barrels, the
    bead and the rounded stock are surfaces, while the action's flats, the trigger guard and the
    breech face are real edges that must stay crisp. 5.x renamed the operator twice, so all three
    spellings are tried and the report says which one answered.

    `None` skips the whole step and keeps flat shading, so the old behaviour is still reachable.
    """
    if angle_deg is None:
        return {"applied": False, "reason": "smoothAngleDeg is null"}
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    # CUSTOM SPLIT NORMALS COME IN WITH THE FBX AND OUTLAST `shade_smooth` (task 94). They are the
    # generator's own per-corner normals, and on a tube built here they are simply absent, so the two
    # halves of the model were lit by different rules: the barrels showed fine lengthwise STRIPES --
    # one band per segment -- while the action was smooth. Clearing them makes the whole model take
    # the smoothing below, which is what "smooth and nice" needs.
    try:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    except RuntimeError as error:  # nothing to clear is not a failure
        log("splitNormalsClear", note=str(error))
    bpy.ops.object.shade_smooth()
    angle = math.radians(float(angle_deg))
    used = None
    for name in ("shade_smooth_by_angle", "shade_auto_smooth"):
        operator = getattr(bpy.ops.object, name, None)
        if operator is None:
            continue
        try:
            operator(angle=angle)
            used = name
            break
        except Exception as error:  # a 5.x signature change must not end the run silently
            log("shadeOperatorFailed", operator=name, error=str(error))
    if used is None:
        # PRE-4.1 BLENDER had the angle on the mesh itself. If even that is missing, the run REFUSES
        # to claim it shaded anything: saying "applied" here would flip the export to EDGE smoothing
        # with not one sharp edge marked, and ship a gun whose action flats had silently melted.
        try:
            ob.data.use_auto_smooth = True
            ob.data.auto_smooth_angle = angle
            used = "use_auto_smooth"
        except AttributeError:
            return {"applied": False, "reason": "no smoothing operator in this Blender",
                    "angleDeg": float(angle_deg)}
    sharp = sum(1 for edge in ob.data.edges if edge.use_edge_sharp)
    # AND WHAT THE POLYGONS THEMSELVES SAY. `use_smooth` per face is the flag every exporter reads;
    # a mesh can carry sharp EDGES and still be flat-shaded everywhere, which is a different defect
    # with the same symptom (task 94, measured after the tubes arrived in Roblox faceted).
    smooth_faces = sum(1 for polygon in ob.data.polygons if polygon.use_smooth)
    modifiers = [m.type for m in ob.modifiers]
    return {"applied": True, "angleDeg": float(angle_deg), "operator": used,
            "edges": len(ob.data.edges), "sharpEdges": sharp,
            "smoothFaces": smooth_faces, "faces": len(ob.data.polygons),
            "modifiers": modifiers}


def base_colour_image(ob):
    """The material's base-colour image, or None -- needed before the main pass looks one up."""
    material = ob.data.materials[0] if ob.data.materials else None
    tree = material.node_tree if material else None
    if not tree:
        return None
    principled = next((n for n in tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    socket = principled.inputs.get("Base Color") if principled else None
    if socket is None or not socket.is_linked:
        return None
    node = socket.links[0].from_node
    while node and node.type != "TEX_IMAGE":
        linked = [i for i in node.inputs if i.is_linked]
        if not linked:
            return None
        node = linked[0].links[0].from_node
    return node.image if node and node.type == "TEX_IMAGE" else None


def rebuild_barrels(ob, plan, axis, up_axis, front_at_min, lo, hi):
    """CUT THE GENERATED BARRELS OFF AND BUILD CLEAN ONES (task 94).

    KAREN, after her third test (2026-09-27): "gun is not smooth and nice ... nozzle is terrible
    (ending where we aim) ... barrels don't feel smooth". A generated mesh is lumpy BY CONSTRUCTION --
    it is a surface fitted to an image, not a tube -- and task 92 proved that shading it smooth does
    not fix the SHAPE: the silhouette still wobbles and the muzzle ends in a blob. A shotgun barrel
    is the one part of the gun whose true shape is two numbers, so this builds it instead.

    KEPT: everything behind the cut -- Karen's walnut stock and her silver engraved action, which she
    has never complained about, and (when the recipe says so) the wooden forend in front of it.
    BUILT: two round barrels side by side and touching, a rib along the top, a thin-walled muzzle
    with two real openings, and a bead on the rib.

    THE NEW FACES BORROW A TEXEL. In Roblox this model is one MeshPart with one texture, so new
    geometry cannot carry a material of its own: every new face is given ONE UV coordinate, taken
    from a face of the original barrels, so the region pass paints it exactly as it paints the
    barrels -- blued steel at metalness 0.10 / roughness 0.50 today. The bead borrows the brightest
    texel found just behind the cut instead, which on this model is the silver action.

    Every number in the plan is a FRACTION OF THE MODEL'S OWN LENGTH, so the proportions survive a
    model that arrives at a different scale.
    """
    across = [i for i in (0, 1, 2) if i not in (axis, up_axis)][0]
    length = hi - lo
    # The region plan's t: 0 at the FRONT (the muzzle end), 1 at the butt.
    def coordinate(t):
        return lo + t * length if front_at_min else hi - t * length

    cut_t = float(plan["cutAtT"])
    cut = coordinate(cut_t)
    forward_sign = -1.0 if front_at_min else 1.0  # which way along `axis` the muzzle is

    mesh = ob.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.faces.ensure_lookup_table()
    uv_layer = bm.loops.layers.uv.active
    if uv_layer is None:
        fail("the model has no UV layer, so new geometry could not be painted")

    image = base_colour_image(ob)
    pixels = image_array(image) if (image is not None and tuple(image.size) != (0, 0)) else None

    def face_t(face):
        value = (face.calc_center_median()[axis] - lo) / max(length, 1e-9)
        return value if front_at_min else 1.0 - value

    def face_t_of_vert(vert):
        value = (vert.co[axis] - lo) / max(length, 1e-9)
        return value if front_at_min else 1.0 - value

    def face_uv(face):
        total = Vector((0.0, 0.0))
        for loop in face.loops:
            total += Vector(loop[uv_layer].uv)
        return total / len(face.loops)

    def texel(uv):
        # `image_array` is HxWx4 with the TOP row first, and a UV's v runs from the BOTTOM, so the
        # row is flipped here. Measured the hard way: indexing it as a flat array crashed the
        # selftest with "index 61913 is out of bounds for axis 0 with size 256".
        if pixels is None:
            return None
        height, width = pixels.shape[0], pixels.shape[1]
        x = min(max(int(uv.x % 1.0 * width), 0), width - 1)
        y = min(max(int((1.0 - uv.y % 1.0) * height), 0), height - 1)
        row = pixels[y, x]
        return float(row[0]), float(row[1]), float(row[2])

    # ---- the two texels, sampled BEFORE anything is deleted
    band = [f for f in bm.faces if 0.18 <= face_t(f) <= 0.45]
    if not band:
        fail("no faces in the barrel band to take a texel from")
    barrel_uv = sum((face_uv(f) for f in band), Vector((0.0, 0.0))) / len(band)
    # A PATCH, NOT A POINT, AND THE FIRST RUN IS WHY. Collapsing every new face onto one UV
    # coordinate gives the region mask no AREA to rasterise, so the corrector painted nothing and the
    # surface check read the generator's own numbers straight back: "barrel metallic (1.00, wanted
    # 0.10)". The new faces are laid over a small square of the atlas INSIDE the old barrels' own UV
    # island instead -- texels that belonged to the barrel and that nothing else uses now, because
    # the faces that did are the ones being deleted.
    def uv_triangle(face):
        """A face's first three UV corners, shrunk toward its own middle.

        INSIDE ONE FACE'S ISLAND, WHICH IS THE WHOLE POINT. The centroid of a whole BAND of faces
        can land on a different island altogether -- run 2 put the new barrels over texels the ACTION
        also owns, and the action pass, which runs later, wrote metalness 0.45 over the barrel's
        0.10. A patch shrunk inside one face's own triangle cannot overlap another island's texels.
        """
        corners = [Vector(loop[uv_layer].uv) for loop in face.loops][:3]
        if len(corners) < 3:
            return None
        middle = sum(corners, Vector((0.0, 0.0))) / 3.0
        keep = float(plan.get("texelPatch", 0.55))
        return [middle + (corner - middle) * keep for corner in corners]

    def uv_area(face):
        corners = [Vector(loop[uv_layer].uv) for loop in face.loops][:3]
        if len(corners) < 3:
            return 0.0
        a, b, c = corners
        return abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) / 2.0

    barrel_patch = uv_triangle(max(band, key=uv_area))
    if barrel_patch is None:
        fail("the barrel band has no triangle to borrow texels from")
    # THE BEAD borrows the brightest face just BEHIND the cut -- the silver action on this model --
    # and those faces are still here, so overlapping their texels is exactly what is wanted.
    keep_wood = bool(plan.get("keepForendWood", True))
    min_saturation = float(plan.get("forendMinSaturation", 0.18))

    def is_wood(face):
        rgb = texel(face_uv(face))
        if rgb is None:
            return False
        high, low = max(rgb), min(rgb)
        saturation = 0.0 if high <= 0 else (high - low) / high
        return saturation >= min_saturation and rgb[0] >= rgb[2]

    # ANY VERTEX FORWARD, NOT THE CENTRE. Judging a face by its middle leaves every face that
    # STRADDLES the cut behind, stretched over the hole where the barrels were: those are the pale
    # spikes the first renders showed at the front of the action, and in the aim view they are the
    # first thing a player sees.
    # THE BEAD AND THE BREECH FACE borrow texels from the ACTION, and the test is what the region
    # plan will call that face rather than how bright it is in the raw atlas: anything behind the cut
    # that is not wood is painted the action's silver, so the biggest such triangle is the safest
    # patch. Run 14 picked "the brightest raw texel" and got a near-black one, which rendered the
    # breech as a black wedge between the silver action and the barrels.
    bead_patch = barrel_patch
    behind = [f for f in bm.faces
              if cut_t + 0.02 < face_t(f) <= cut_t + 0.12 and uv_area(f) > 0 and not is_wood(f)]
    if behind:
        bead_patch = uv_triangle(max(behind, key=uv_area)) or barrel_patch

    # ---- the cut: everything in front of it goes, except the wood when the recipe keeps it
    forward = [f for f in bm.faces if min(face_t_of_vert(v) for v in f.verts) < cut_t]
    doomed = [f for f in forward if not (keep_wood and is_wood(f))]
    kept_wood_faces = [f for f in forward if f not in set(doomed)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()

    # ---- the shards: whatever is left floating in front of the action, in pieces of its own
    islands, seen = [], set()
    for face in bm.faces:
        if face in seen:
            continue
        island, queue = [], [face]
        seen.add(face)
        while queue:
            current = queue.pop()
            island.append(current)
            for edge in current.edges:
                for other in edge.link_faces:
                    if other not in seen:
                        seen.add(other)
                        queue.append(other)
        islands.append(island)
    biggest = max(len(i) for i in islands) if islands else 0
    strays = []
    for island in islands:
        if len(island) >= max(biggest * 0.02, 40):
            continue  # the gun itself, or a real piece of it (the forend is one)
        strays.extend(island)
    if strays:
        bmesh.ops.delete(bm, geom=strays, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.verts.ensure_lookup_table()
        bm.faces.ensure_lookup_table()

    # ---- the breech: close what the cut opened, so the action ends in a face and not in a rim
    open_edges = [e for e in bm.edges if len(e.link_faces) == 1
                  and all(abs((v.co[axis] - cut) / max(length, 1e-9)) <= 0.06 for v in e.verts)]
    filled = 0
    if open_edges:
        try:
            result = bmesh.ops.holes_fill(bm, edges=open_edges, sides=0)
            made_faces = result.get("faces", [])
            filled = len(made_faces)
            bm.faces.ensure_lookup_table()
            # A FILLED FACE HAS NO UVs, AND AN UNSET UV IS NOT HARMLESS. Measured in runs 12 and 13:
            # the breech face came out with its corners at the atlas origin, so its UV triangle
            # covered the WHOLE map -- the action's own mask with it -- and the action's shine was
            # written over every other region. The wood came back metallic 0.45 and rendered as dark
            # camouflage. The face is given the action's own texels, which is what a breech is.
            for face in made_faces:
                for index, loop in enumerate(face.loops):
                    corner = bead_patch[index % 3]
                    loop[uv_layer].uv = (corner.x, corner.y)
                face.material_index = 0
        except (RuntimeError, TypeError) as error:
            log("breechFillFailed", error=str(error))

    # ---- where the new barrels go: MEASURED off what is left at the cut, not declared
    slab_t = float(plan.get("slabT", 0.05))
    slab = [v for v in bm.verts if abs((v.co[axis] - cut) / max(length, 1e-9)) <= slab_t]
    if len(slab) < 8:
        fail("nothing left at the cut to measure the action against")
    top = max(v.co[up_axis] for v in slab)
    centre_across = (max(v.co[across] for v in slab) + min(v.co[across] for v in slab)) / 2.0

    radius = float(plan["barrelDiameterT"]) * length / 2.0
    barrel_length = float(plan["barrelLengthT"]) * length
    segments = int(plan["segments"])
    wall = float(plan["wallT"]) * length
    rib_thickness = float(plan["ribThicknessT"]) * length
    bead_radius = float(plan["beadDiameterT"]) * length / 2.0
    # A side-by-side's barrels sit at the TOP of the action, and the two tubes TOUCH: their centres
    # are exactly one diameter apart.
    centre_up = top - radius - float(plan.get("dropT", 0.0)) * length
    muzzle = cut + forward_sign * barrel_length
    middle = (cut + muzzle) / 2.0

    def placed(along, sideways, up):
        out = [0.0, 0.0, 0.0]
        out[axis] = along
        out[across] = sideways
        out[up_axis] = up
        return Vector(out)

    def along_axis(centre):
        """A transform that lays a Z-aligned primitive along the model's long axis."""
        if axis == 0:
            rotation = Matrix.Rotation(math.radians(90), 4, "Y")
        elif axis == 1:
            rotation = Matrix.Rotation(math.radians(90), 4, "X")
        else:
            rotation = Matrix.Identity(4)
        return Matrix.Translation(centre) @ rotation

    def faces_of(verts):
        wanted = set(verts)
        return [f for f in bm.faces if all(v in wanted for v in f.verts)]

    built = []

    # NOTHING TOUCHES ANYTHING EXACTLY (task 94, measured IN THE GAME). The first build had the two
    # tubes tangent to each other and the rib's underside tangent to both, and Roblox rendered a
    # bright scalloped shimmer down each barrel where the coincident surfaces fight for the depth
    # buffer -- which in the aim view is the whole barrel. A real side-by-side IS brazed tube to
    # tube; a renderer needs a hair of daylight, and `clearanceT` is it (0.4 mm at this scale).
    clearance = float(plan.get("clearanceT", 0.0003)) * length
    for side in (-1.0, 1.0):
        centre = placed(middle, centre_across + side * (radius + clearance / 2.0), centre_up)
        cone = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments,
                                     radius1=radius, radius2=radius, depth=barrel_length,
                                     matrix=along_axis(centre), calc_uvs=False)
        bm.faces.ensure_lookup_table()
        tube = faces_of(cone["verts"])
        built.extend(cone["verts"])
        # THE MUZZLE IS A TUBE, NOT A DISC. The cap at the front is inset by the wall thickness and
        # the inner face pushed back down the bore: a real opening with a thin rim, which is what
        # "nozzle is terrible" was about.
        caps = [f for f in tube if len(f.verts) == segments]
        front_cap = min(caps, key=lambda f: forward_sign * -f.calc_center_median()[axis]) if caps else None
        if front_cap is not None:
            inset = bmesh.ops.inset_individual(bm, faces=[front_cap], thickness=wall, depth=0.0)
            bm.faces.ensure_lookup_table()
            built.extend(v for f in inset["faces"] for v in f.verts)
            bmesh.ops.translate(bm, verts=list(front_cap.verts),
                                vec=placed(-forward_sign * radius * 1.5, 0.0, 0.0))

    # ---- THE FOREND, SEATED UNDER THE NEW BARRELS (task 95)
    #
    # Karen's wooden forend was carved for the GENERATED barrels, which were far fatter and sat
    # lower: against tubes this slim it hangs below them as a separate dark flap with daylight
    # between -- visible in every carry frame of task 95's first round. It is her wood and it stays
    # her wood, so it is MOVED rather than replaced: up until its top meets the underside of the
    # tubes, and across until it is centred on them.
    #
    # ONLY THE VERTICES THAT BELONG TO THE FOREND ALONE. A vertex shared with the action would tear
    # the mesh open at the cut; those stay where they are, so the wood stretches the last millimetre
    # into place instead of leaving a hole.
    forend_faces = [f for f in kept_wood_faces if f.is_valid]
    seated = None
    if forend_faces:
        wood_verts = set()
        for face in forend_faces:
            wood_verts.update(face.verts)
        exclusive = [v for v in wood_verts
                     if all(f in set(forend_faces) for f in v.link_faces)]
        if exclusive:
            # TWO THINGS ARE WRONG WITH A SPLINTER FOREND CARVED FOR FATTER BARRELS, and the render
            # shows both: it can hang BELOW the new tubes, and it ends short of the action -- the old
            # barrels filled that gap, and tubes this slim leave daylight where the wood should meet
            # the metal. So it is stretched BACK to the cut and lifted only if it needs lifting.
            #
            # ONLY THE VERTICES THAT BELONG TO THE FOREND ALONE: one shared with the action would
            # tear the mesh at the seam, so those stay and the wood stretches the last millimetre.
            target = centre_up - radius + radius / 3.0
            along = [v.co[axis] for v in exclusive]
            front = min(along) if forward_sign < 0 else max(along)
            rear = max(along) if forward_sign < 0 else min(along)
            span = rear - front
            wanted = cut - front
            stretch = (wanted / span) if abs(span) > 1e-9 else 1.0
            top = max(v.co[up_axis] for v in exclusive)
            lift = max(0.0, target - top)  # NEVER push it down: at rest it already meets the barrel
            left = min(v.co[across] for v in exclusive)
            right = max(v.co[across] for v in exclusive)
            shift = centre_across - (left + right) / 2.0
            for vert in exclusive:
                moved = vert.co.copy()
                moved[axis] = front + (moved[axis] - front) * stretch
                moved[up_axis] += lift
                moved[across] += shift
                vert.co = moved
            seated = {
                "verts": len(exclusive),
                "stretchToAction": round(float(stretch), 4),
                "liftT": round(float(lift / max(length, 1e-9)), 5),
                "shiftT": round(float(shift / max(length, 1e-9)), 5),
            }

    # ---- the rib: a thin flat bridge across the top of both barrels
    rib_centre = placed(middle, centre_across,
                        centre_up + radius + clearance + rib_thickness / 2.0)
    rib = bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(rib_centre))
    bm.faces.ensure_lookup_table()
    scale = [0.0, 0.0, 0.0]
    scale[axis] = barrel_length
    scale[across] = 2.0 * radius + clearance
    scale[up_axis] = rib_thickness
    bmesh.ops.scale(bm, verts=rib["verts"], vec=Vector(scale),
                    space=Matrix.Translation(-rib_centre))
    built.extend(rib["verts"])

    # ---- the bead: a small ball on the rib at the muzzle
    bead_centre = placed(muzzle - forward_sign * bead_radius * 1.5, centre_across,
                         centre_up + radius + clearance + rib_thickness + bead_radius * 0.5)
    try:
        bead = bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=bead_radius,
                                         matrix=Matrix.Translation(bead_centre), calc_uvs=False)
    except TypeError:  # older bmesh spells it `diameter`
        bead = bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, diameter=bead_radius,
                                         matrix=Matrix.Translation(bead_centre), calc_uvs=False)
    bm.faces.ensure_lookup_table()
    bead_verts = set(bead["verts"])
    built.extend(bead["verts"])

    # ---- one texel, one material slot, for every face that was built here
    # ---- WHERE THE NEW FACES LIVE IN THE ATLAS: the emptiest corner of it.
    #
    # Runs 2 and 3 borrowed texels from the old barrels' own island and the surface still came back
    # at the ACTION's metalness: every mask is DILATED and FEATHERED by several pixels before it is
    # painted, so a patch a few texels from an action island is written twice and the later pass
    # wins. The new faces are given a square of atlas that NO surviving face is near instead -- the
    # region pass classifies them as barrel (they are in front of the cut), so that square is painted
    # barrel and nothing else can reach it.
    grid = 48
    occupied = np.zeros((grid, grid), dtype=bool)
    building = set(built)
    for face in bm.faces:
        if all(v in building for v in face.verts):
            continue
        # THE WHOLE FOOTPRINT, NOT THE CORNERS. Marking only the corner cells left the middle of a
        # big triangle looking empty, so the "empty corner" of run 4 sat under an action face and the
        # action pass wrote metalness 0.45 over the barrel's 0.10 -- measured, in that run's own
        # surface check.
        uvs = [loop[uv_layer].uv for loop in face.loops]
        x0 = min(max(int(min(uv[0] for uv in uvs) % 1.0 * grid), 0), grid - 1)
        x1 = min(max(int(max(uv[0] for uv in uvs) % 1.0 * grid), 0), grid - 1)
        y0 = min(max(int(min(uv[1] for uv in uvs) % 1.0 * grid), 0), grid - 1)
        y1 = min(max(int(max(uv[1] for uv in uvs) % 1.0 * grid), 0), grid - 1)
        occupied[y0:y1 + 1, x0:x1 + 1] = True
    # THE LARGEST EMPTY SQUARE, not the emptiest single cell (task 94). The barrels' texels have to
    # survive MIP-MAPPING: Roblox halves the texture over and over, and by the third level a patch a
    # few dozen pixels wide has blended into whatever the generator left beside it -- which is what
    # speckled the barrels in the game while Blender's own render, with no mip chain, was perfect.
    # A big block of atlas painted one flat colour is flat at every level that matters.
    best, best_size = None, 0
    for size in range(min(grid // 2, 12), 0, -1):
        for gy in range(grid - size + 1):
            for gx in range(grid - size + 1):
                if not occupied[gy:gy + size, gx:gx + size].any():
                    best, best_size = (gx, gy), size
                    break
            if best:
                break
        if best:
            break
    if best is not None and best_size >= 1:
        # BIG ENOUGH TO HAVE AN INTERIOR. Every mask is feathered by `maskFeatherPx` (6) and dilated
        # by `maskDilatePx` (4) before it is painted, and `push_channel` BLENDS by that weight: a
        # 17-pixel patch is all edge, so the barrel's metalness 0.10 came out at 0.45 -- the source's
        # own 1.00 pulled two thirds of the way, which run 5 measured exactly. The patch fills the
        # empty cell and as much of its clear neighbourhood as there is, so its middle is at full
        # weight.
        # THE UV TRIANGLE IS SMALL AND THE PAINTED BLOCK AROUND IT IS BIG (task 94, measured in the
        # game). Roblox mipmaps every texture: at the second or third level a 40-pixel patch is
        # already blended with whatever the generator left beside it, and the barrels came out
        # speckled and scalloped at exactly the distances where a lower mip is chosen -- which is why
        # Blender's own render, with no mip chain, showed none of it. The triangle stays in the
        # middle of the empty cell and the repaint below covers everything around it.
        centre = Vector(((best[0] + best_size / 2.0) / grid, (best[1] + best_size / 2.0) / grid))
        half = best_size / grid * 0.12  # a small island in the MIDDLE of the block
        barrel_patch = [Vector((centre.x - half, centre.y - half)),
                        Vector((centre.x + half, centre.y - half)),
                        Vector((centre.x, centre.y + half))]
        empty_corner = {"cell": list(best), "emptyCells": best_size, "gridCells": grid}
        # What the repaint covers: the whole clear neighbourhood, so every mip level the barrels can
        # sample is the same flat blued steel.
        block = best_size / grid / 2.0 * 0.96  # the painted square, a hair inside the empty block
        patch_rect = [centre.x - block, centre.y - block, centre.x + block, centre.y + block]
    else:
        empty_corner = {"cell": None, "emptyCells": best_size, "gridCells": grid}
        patch_rect = None

    made = set(built)
    new_faces = 0
    for face in bm.faces:
        if not all(v in made for v in face.verts):
            continue
        corners = bead_patch if all(v in bead_verts for v in face.verts) else barrel_patch
        for index, loop in enumerate(face.loops):
            corner = corners[index % 3]
            loop[uv_layer].uv = (corner.x, corner.y)
        face.material_index = 0
        new_faces += 1

    bmesh.ops.recalc_face_normals(bm, faces=[f for f in bm.faces if all(v in made for v in f.verts)])
    corners_before_free = [v.co.copy() for v in bm.verts]
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    # WHERE THE BEAD ENDED UP, as fractions of the model's own box (task 94). The game aims by the
    # gun's bead -- `Assets` carries a `sightOffsetStuds` and the first-person camera puts that point
    # on the view axis -- so the number has to come from the geometry that was built, not from a
    # measurement somebody takes again on a screenshot.
    corners = corners_before_free
    bead_report = None
    if corners:
        lows = [min(c[i] for c in corners) for i in (0, 1, 2)]
        highs = [max(c[i] for c in corners) for i in (0, 1, 2)]
        span_up = max(highs[up_axis] - lows[up_axis], 1e-9)
        t_bead = (bead_centre[axis] - lo) / max(length, 1e-9)
        bead_report = {
            "alongT": round(float(t_bead if front_at_min else 1.0 - t_bead), 5),
            "upFromCentre": round(float((bead_centre[up_axis]
                                         - (highs[up_axis] + lows[up_axis]) / 2.0) / span_up), 5),
            "acrossFromCentre": round(float((bead_centre[across]
                                             - (highs[across] + lows[across]) / 2.0)
                                            / max(highs[across] - lows[across], 1e-9)), 5),
            "modelBox": [round(float(highs[i] - lows[i]), 4) for i in (0, 1, 2)],
        }

    return {
        "cutAtT": cut_t,
        "bead": bead_report,
        "deletedFaces": len(doomed),
        "keptWoodFacesInFront": len(forward) - len(doomed),
        "segments": segments,
        "barrelDiameterT": round(float(plan["barrelDiameterT"]), 5),
        "barrelLengthT": round(float(plan["barrelLengthT"]), 5),
        "newFaces": new_faces,
        "strayFacesRemoved": len(strays),
        "forendSeated": seated,
        "breechFacesFilled": filled,
        "atlasCorner": empty_corner,
        "patchRect": patch_rect,
        "triangles": triangles(ob),
    }


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


def rasterise_weights(planes, uvs, face_weight, size):
    """Paint each triangle's UV footprint into every region's FLOAT plane, at its own weight.

    THE BAND BOUNDARY HAS TO BE SOFT IN 3D, NOT IN THE ATLAS (Task 69, measured twice). Blurring a
    finished mask by 110 texels -- the width a boar's saddle actually fades over -- made every
    region's mask cover the whole 2048 map, because a generator's atlas packs unrelated islands a
    few texels apart: the belly bled into the back and the snout came out 59 off its target. A face
    that is half-back and half-flank is a fact about the MODEL, so it is decided on the model and
    only then painted.
    """
    for tri_index in range(len(uvs)):
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
        bb = ((y2 - y0) * (gx - x2) + (x0 - x2) * (gy - y2)) / denominator
        c = 1.0 - a - bb
        inside = (a >= -0.002) & (bb >= -0.002) & (c >= -0.002)
        if not inside.any():
            continue
        for name, plane in planes.items():
            weight = float(face_weight[name][tri_index])
            if weight <= 0.0:
                continue
            block = plane[min_y:max_y + 1, min_x:max_x + 1]
            np.maximum(block, np.where(inside, weight, 0.0).astype(np.float32), out=block)


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


def box_blur(weight, radius):
    """A WIDE, CHEAP RAMP: two separable box passes over a float weight, by cumulative sum.

    `feather` above is a 5-point diffusion, and N rounds of it spread about sqrt(N/3) texels -- 24
    rounds is three texels, not twenty-four. That is the right tool for taking the aliasing off a
    seam where the geometry really does change (wood meeting metal) and the wrong one for a
    TRANSITION: a boar's dark saddle fades into its pale flank over a hand's width, and reaching that
    by diffusion would take ten thousand rounds. Measured, and it is why the first two boar runs had
    a sawtooth line drawn along the body (rule 5).

    Two box passes approximate a Gaussian well enough for a mask, and a cumulative sum makes each
    pass O(1) per texel however wide the radius is.
    """
    if radius <= 0:
        return weight
    out = weight.astype(np.float32)
    for _ in range(2):
        for axis in (0, 1):
            padded = np.pad(out, [(radius + 1, radius) if a == axis else (0, 0) for a in (0, 1)],
                            mode="edge")
            summed = np.cumsum(padded, axis=axis, dtype=np.float32)
            lo = np.take(summed, np.arange(0, out.shape[axis]), axis=axis)
            hi = np.take(summed, np.arange(2 * radius + 1, out.shape[axis] + 2 * radius + 1),
                         axis=axis)
            out = (hi - lo) / float(2 * radius + 1)
    return np.clip(out, 0.0, 1.0)


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


def push_channel(array, weights, target, strength):
    """Write `target` into a greyscale map through a FEATHERED region mask -- Karen's shine dial.

    `weights` is the same soft 0..1 mask the colour correction uses, so a metalness or roughness
    boundary is a ramp rather than a triangle-shaped step. `strength` is how much of the source's own
    variation survives: 1.0 replaces it outright (right for metalness, which the Roblox docs say
    should be 0% or 100% "in most cases"), below 1.0 keeps some of the generator's detail (right for
    roughness, where the scratches and wear are worth keeping).
    """
    if target is None:
        return 0
    alpha = np.clip(weights * float(strength), 0.0, 1.0)
    touched = int((alpha > 0.0).sum())
    if touched == 0:
        return 0
    for channel in range(3):
        plane = array[..., channel]
        plane[:] = plane * (1.0 - alpha) + float(target) * alpha
    return touched


def split_packed_shine(material, image, size):
    """glTF packs OCCLUSION-ROUGHNESS-METALNESS into ONE image; split it into two.

    THE CONVENTION IS THE SPEC'S, not a guess: "The metallic-roughness texture. The metalness values
    are sampled from the B channel. The roughness values are sampled from the G channel."
      https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-material-pbrmetallicroughness
    (Measured on the boar as well, before this was written: R median 1.00, G 0.61, B 0.00 -- an
    occlusion channel left white, a rough hide and no metal, which is what that model should say.)

    WHY SPLIT RATHER THAN REFUSE. This tool writes a number into each map, and it used to fail the
    run outright when one datablock fed both sockets -- correctly, because writing roughness into a
    shared image silently overwrites the metalness that was written a moment earlier while every
    number in the report still reads back right. That failure is real and stays; what is wrong is
    treating a GLB's normal, documented layout as that failure. So the one image becomes two
    single-channel images, each linked to its own socket, and from there the run is the same run.

    IT RETURNS THE PIXELS AS WELL AS THE IMAGES, and that is not convenience. A `bpy.data.images.new`
    datablock is GENERATED: its buffer is Blender's to free, and after the region and mask pass -- a
    long stretch of Python between the split and the shine step -- it comes back regenerated, which
    for a new image means BLACK. Measured, and it is exactly the shape of defect this tool exists to
    catch: the split was provably correct when tested on its own (roughness 0.62, metalness 0.00) and
    the run it was part of wrote a roughness map of zeros while every number in the report agreed
    with itself. So the caller uses these arrays and never re-reads the datablock.

    The original is left alone: two new datablocks are made, and the packed one is unlinked.
    """
    array = image_array(image)
    made = {}
    for key, channel, socket_name in (("roughness", 1, "Roughness"), ("metallic", 2, "Metallic")):
        plane = array[..., channel]
        new_image = bpy.data.images.new("dh_" + key, array.shape[1], array.shape[0],
                                        alpha=False, float_buffer=False)
        new_image.colorspace_settings.name = "Non-Color"
        flat = np.empty((array.shape[0], array.shape[1], 4), dtype=np.float32)
        flat[..., 0] = plane
        flat[..., 1] = plane
        flat[..., 2] = plane
        flat[..., 3] = 1.0
        set_image(new_image, flat)
        if tuple(new_image.size) != (size, size):
            new_image.scale(size, size)
        node = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        socket = node.inputs[socket_name]
        for link in list(socket.links):
            material.node_tree.links.remove(link)
        tex = material.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = new_image
        tex.label = "dh_" + key
        material.node_tree.links.new(socket, tex.outputs["Color"])
        made[key] = (new_image, image_array(new_image))
    return made


def ensure_data_map(material, socket_name, size, fill, image_name):
    """The greyscale map behind a Principled input, made if the model has none. Returns the image.

    A MODEL WITHOUT THE MAP IS THE DANGEROUS CASE, not the harmless one: Roblox reads maps and
    ignores material scalars (measured, Task 75), so "this model has no metalness map" means "this
    model ships whatever Roblox defaults to" rather than "this model ships the recipe's number".
    Making a flat one costs a 2048 greyscale PNG and puts the number where the engine can see it.
    """
    node = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if node is None:
        return None, False
    socket = node.inputs.get(socket_name)
    if socket is None:
        return None, False
    for link in socket.links:
        source = link.from_node
        if source.type == "TEX_IMAGE" and source.image is not None:
            # DATA, NOT COLOUR. A metalness map tagged sRGB is read and written through the transfer
            # function, so writing 0.10 would store a byte that means something else entirely.
            source.image.colorspace_settings.name = "Non-Color"
            return source.image, False
    image = bpy.data.images.new(image_name, size, size, alpha=False, float_buffer=False)
    image.colorspace_settings.name = "Non-Color"
    image.pixels.foreach_set(np.tile(np.array([fill, fill, fill, 1.0], dtype=np.float32),
                                     size * size))
    tex = material.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.label = image_name
    material.node_tree.links.new(socket, tex.outputs["Color"])
    return image, True


# ---------------------------------------------------------------- the region plan

def rule_matches(when, t_axis, t_up, hue_deg, saturation, value):
    """One plan rule, as a boolean array over faces. Every predicate present must hold.

    THE PLAN IS DATA BECAUSE NO ONE CUE SEPARATES A MODEL'S PARTS (Task 69). On the gun, position
    separates the barrels from the action and only colour separates the forend from the barrels it
    lies along. On the boar, only colour separates the gold tusks from the pale snout they sit in
    front of, and only height separates the dark back from the pale flank, which are the same
    colour to begin with. Written as three lines of Python per asset, that is a program edit for
    every model; written as a list of rules, it is a recipe, which is the thing this tool already
    writes beside every run.

    `From` is inclusive and `To` is exclusive, so bands can be written back to back and no face
    lands in two. Hue wraps: 330..25 is the reds through zero.
    """
    keep = np.ones(len(t_axis), dtype=bool)
    if "axisFrom" in when:
        keep &= t_axis >= float(when["axisFrom"])
    if "axisTo" in when:
        keep &= t_axis < float(when["axisTo"])
    if "upFrom" in when:
        keep &= t_up >= float(when["upFrom"])
    if "upTo" in when:
        keep &= t_up < float(when["upTo"])
    if "satMin" in when:
        keep &= saturation >= float(when["satMin"])
    if "satMax" in when:
        keep &= saturation < float(when["satMax"])
    if "valueMin" in when:
        keep &= value >= float(when["valueMin"])
    if "valueMax" in when:
        keep &= value < float(when["valueMax"])
    if "hueFromDeg" in when or "hueToDeg" in when:
        low = float(when.get("hueFromDeg", 0.0))
        high = float(when.get("hueToDeg", 360.0))
        if low <= high:
            keep &= (hue_deg >= low) & (hue_deg <= high)
        else:  # wraps through 0
            keep &= (hue_deg >= low) | (hue_deg <= high)
    return keep


def soft_band(t, low, high, soft):
    """Membership of the band [low, high) as a ramp `soft` wide on each open side. 0..1."""
    if soft <= 0.0:
        return ((t >= low) & (t < high)).astype(np.float32)
    weight = np.ones_like(t, dtype=np.float32)
    if low > 0.0:
        weight = np.minimum(weight, np.clip((t - (low - soft)) / (2.0 * soft), 0.0, 1.0))
    if high < 1.0:
        weight = np.minimum(weight, np.clip(((high + soft) - t) / (2.0 * soft), 0.0, 1.0))
    return weight.astype(np.float32)


def soft_weights(plan, labels, t_up):
    """A per-face weight for every region: 1 in its core, a ramp across a soft band boundary.

    ONLY THE `up` BANDS ARE SOFTENED, and only where a rule asks. A colour rule's boundary (gold
    tusk against pale muzzle) is a real boundary on the model and blending it would smear ivory onto
    hide; a height band's boundary is the rule's own invention and a hard one is a line drawn along
    the animal. The hard labels are kept beside these: the counts, the speckle check and the
    verification all still speak about "which region is this face".
    """
    names = []
    for rule in plan:
        if rule["name"] not in names:
            names.append(rule["name"])
    weights = {name: (labels == name).astype(np.float32) for name in names}
    # A RAMP MAY ONLY REACH THE OTHER BANDS. It is a function of height alone, so without this the
    # flank's ramp would cover the tusks -- which sit at half the animal's height -- and the coat
    # colour, applied later in plan order, would paint over the ivory. Bands blend into bands; a
    # region decided by colour keeps the hard boundary it was given, which is a real boundary.
    band_names = [rule["name"] for rule in plan if float(rule.get("softUp", 0.0)) > 0.0]
    in_bands = np.isin(labels.astype(str), np.array(band_names, dtype=str)) if band_names             else np.zeros(len(t_up), dtype=bool)
    for rule in plan:
        # EXPLICIT, NEVER INFERRED. A rule's `when` says what it MATCHES, and under first-match-wins
        # that is not the same as the band it occupies: `flank` is written `upTo 0.62` and means
        # 0.28 to 0.62, because `underside` ran first. Reading the ramp's bounds off `when` would
        # have given the flank a weight of 1 over the whole belly and legs. `band` states them, and
        # the catch-all -- which has no `when` at all -- needs it anyway.
        soft = float(rule.get("softUp", 0.0))
        if soft <= 0.0:
            continue
        bounds = rule.get("band") or rule.get("when") or {}
        low = float(bounds.get("upFrom", 0.0))
        high = float(bounds.get("upTo", 1.0))
        ramp = soft_band(t_up, low, high, soft) * in_bands
        # THE CORE STAYS 1: a face the plan actually gave to this region is fully this region, and
        # the ramp only ADDS the neighbouring faces that are close to the boundary.
        weights[rule["name"]] = np.maximum(weights[rule["name"]], ramp)
    return weights


def apply_plan(plan, t_axis, t_up, hue_deg, saturation, value):
    """Label every face, FIRST MATCH WINS. Returns the labels and a per-rule count."""
    labels = np.full(len(t_axis), "", dtype=object)
    per_rule = []
    for index, rule in enumerate(plan):
        free = labels == ""
        if not rule.get("when"):
            taken = free
        else:
            taken = free & rule_matches(rule["when"], t_axis, t_up, hue_deg, saturation, value)
        labels[taken] = rule["name"]
        per_rule.append({"rule": index, "name": rule["name"], "faces": int(taken.sum())})
    return labels, per_rule


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


def render_views(ob, out_dir, size_px, samples, views, prefix="render"):
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
    # THE VIEWS COME FROM THE RECIPE (Task 69), because the four questions are the asset's, not the
    # tool's: a gun is photographed down its barrels, an animal from the front where its snout and
    # both tusks are in one frame. FRAMED FROM THE MEASURED BOUNDING BOX, and tight: the first pass
    # used twice the span and the gun sat in the middle third of the picture, which is a preview
    # nobody can judge detail from.
    #
    # `orthoCross` frames a model seen END-ON, where its length says nothing about how big it looks:
    # it is a multiple of the larger of the two dimensions ACROSS the view direction.
    # A VIEW MAY LOOK AT A POINT OTHER THAN THE MIDDLE (task 94). `targetAlong` moves the camera's
    # target along the model's longest axis, as a fraction of it from the centre (+ toward the end
    # the model's own axis grows into), and `targetUp` moves it up the same way. That is what a
    # muzzle close-up and a look down the rib are: the same rig, aimed at the muzzle instead of at
    # the middle of the gun.
    longest = int(np.argmax([extent.x, extent.y, extent.z]))
    tallest = 2 if longest != 2 else int(np.argmax([extent.x, extent.y]))
    prepared = []
    for view in views:
        direction = tuple(float(v) for v in view["dir"])
        distance = span * float(view.get("distanceSpan", 1.2))
        target = centre.copy()
        target[longest] += float(view.get("targetAlong", 0.0)) * extent[longest]
        target[tallest] += float(view.get("targetUp", 0.0)) * extent[tallest]
        if "orthoSpan" in view:
            ortho = span * float(view["orthoSpan"])
        elif "orthoCross" in view:
            dominant = int(np.argmax([abs(v) for v in direction]))
            across = max(extent[i] for i in (0, 1, 2) if i != dominant)
            ortho = across * float(view["orthoCross"])
        else:
            ortho = 0.0
        prepared.append((view["name"], direction, distance, ortho, target))
    for name, direction, distance, ortho, target in prepared:
        for constraint in list(camera.constraints):
            camera.constraints.remove(constraint)
        empty.location = target
        bpy.context.view_layer.update()
        look_at(camera, target, distance, direction, ortho)
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

    ob = import_model(JOB.get("model") or JOB["fbx"])
    log("imported", object=ob.name, triangles=triangles(ob), vertices=len(ob.data.vertices),
        materials=[m.name if m else None for m in ob.data.materials])

    # THE SOURCE, PHOTOGRAPHED BEFORE ANYTHING IS DONE TO IT (Director, round 2). Round 1 shipped a
    # model whose wood had turned into angular black-and-orange shards and whose barrels had turned
    # into mirror chrome, and nothing in the tool noticed -- the only comparison available was the
    # Director's memory of his own render. Now every run carries the before picture beside the after
    # one, at the same four cameras, and the numbers from both are in the report.
    views = recipe["views"]
    studio(ob, int(recipe["renderPx"]), int(recipe["renderSamples"]))
    if recipe.get("renderSource", True):
        REPORT["sourceStats"] = render_views(ob, out_dir, int(recipe["renderPx"]),
                                             int(recipe["renderSamples"]), views, prefix="source")
        log("renderedSource", files=REPORT["sourceStats"])

    before, after, ratio = decimate(ob, recipe["targetTriangles"])
    log("decimated", before=before, measuredAfter=after, ratioAsked=round(ratio, 6),
        target=recipe["targetTriangles"])
    REPORT["triangles"] = {"before": before, "after": after, "target": recipe["targetTriangles"]}

    # ---- clean barrels (task 94), BEFORE the shading and the regions
    #
    # It runs here for two reasons and both are order, not taste: the new faces must be shaded by the
    # same `smoothAngleDeg` pass as everything else, and they must be classified by the same region
    # plan -- they are in front of `actionStartT`, so the plan calls them barrel and the colour pass
    # paints them. The orientation is measured TWICE: once to tell the rebuild which way the gun
    # faces, and again afterwards because the new barrels move the bounding box the regions are
    # measured in.
    plan = recipe.get("rebuildBarrels")
    if plan:
        pre_axis, pre_front, pre_lo, pre_hi, _near, _far = long_axis(ob)
        pre_up = 2 if pre_axis != 2 else int(np.argmax([ob.dimensions[0], ob.dimensions[1]]))
        stated_front = recipe.get("frontAtMin")
        REPORT["rebuiltBarrels"] = rebuild_barrels(
            ob, plan, pre_axis, pre_up,
            pre_front if stated_front is None else bool(stated_front), pre_lo, pre_hi)
        log("rebuiltBarrels", **REPORT["rebuiltBarrels"])

    REPORT["shading"] = shade(ob, recipe.get("smoothAngleDeg"))
    log("shaded", **REPORT["shading"])

    axis, measured_at_min, lo, hi, near_depth, far_depth = long_axis(ob)
    # THE RECIPE MAY STATE WHICH END IS THE FRONT, and for an animal it has to. `long_axis` decides
    # it by comparing how deep the model is at each end, which is a fact about a gun -- thin at the
    # muzzle, deep at the butt -- and says nothing about a boar, which is thin at the snout AND thin
    # at the tail. Both numbers are reported, so a stated value that disagrees with the measurement
    # is visible rather than silent.
    stated = recipe.get("frontAtMin")
    front_at_min = measured_at_min if stated is None else bool(stated)
    # UP IS Z, which is what both importers produce: the FBX importer and the glTF importer each
    # convert their file's own convention to Blender's Z-up. The exception is a model whose LONG
    # axis is Z -- a standing tree -- where the bands would be along the length twice over.
    up_axis = 2 if axis != 2 else int(np.argmax([ob.dimensions[0], ob.dimensions[1]]))
    log("oriented", axis="XYZ"[axis], upAxis="XYZ"[up_axis], frontAtMin=front_at_min,
        measuredFrontAtMin=measured_at_min, statedInRecipe=stated, low=round(lo, 4),
        high=round(hi, 4), nearDepth=round(near_depth, 4), farDepth=round(far_depth, 4))
    REPORT["orientation"] = {"axis": "XYZ"[axis], "upAxis": "XYZ"[up_axis],
                             "frontAtMin": front_at_min, "measuredFrontAtMin": measured_at_min,
                             "frontStated": stated is not None,
                             # kept under its old name so an older reader still finds it
                             "muzzleAtMin": front_at_min}

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
        fail("the base colour texture has no pixels (image '%s' did not load from the model)"
             % base_image.name)

    work_px = int(recipe["workPx"])
    # ONE IMAGE FEEDING BOTH SHINE SOCKETS IS glTF'S NORMAL LAYOUT, not a broken model (Task 69) --
    # occlusion in R, roughness in G, metalness in B. It is also a shape this tool genuinely cannot
    # write into, so it is split in two. NOTED HERE, SPLIT AT THE SHINE STEP: the new datablocks are
    # generated images and Blender is free to drop their buffers, so the less that happens between
    # making them and using them the better (see `split_packed_shine`).
    packed_shine = metallic_image if (metallic_image is not None
                                      and metallic_image is roughness_image) else None
    if packed_shine is not None:
        REPORT["packedShineMap"] = {"name": packed_shine.name,
                                    "sourcePx": int(packed_shine.size[0]),
                                    "splitInto": ["metallic", "roughness"]}
        log("packedShineMap", name=packed_shine.name, sourcePx=list(packed_shine.size))
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
    # IN WHICH SPACE ARE THE PLAN'S COLOUR THRESHOLDS READ? It matters and it is not a detail.
    # `base_image.pixels` is scene-LINEAR whenever the image is tagged sRGB, and saturation is a
    # different number in the two spaces -- (max-min)/max on 0.9/0.6 sRGB is 0.33 and on the same
    # colour in linear is 0.59. The gun's rule (`satMin` 0.18) was measured against the LINEAR
    # values in Tasks 72 and 75 and its region counts are proven; a colour read off a picture, as
    # the boar's tusks and snout were, is an sRGB number. So the recipe says which, the gun keeps
    # what it had, and neither has to be re-tuned for the other.
    space = recipe.get("regionColorSpace", "linear")
    if space not in ("linear", "srgb"):
        fail("regionColorSpace must be 'linear' or 'srgb', not %r" % space)
    for_regions = sampled
    if space == "srgb" and base_image.colorspace_settings.name in ("sRGB", "Filmic sRGB"):
        for_regions = linear_to_srgb(sampled)
    hue, saturation, value = rgb_to_hsv(for_regions.reshape((-1, 1, 3)))
    hue = hue.ravel()
    saturation = saturation.ravel()
    # VALUE IS A REGION CUE TOO, and on the boar it is the one that separates the tusks (0.90) from
    # the pale muzzle they stand in front of (0.65).
    value = value.ravel()
    REPORT["regionColorSpace"] = space

    coords = np.array([v.co[:] for v in mesh.vertices], dtype=np.float64)
    tri_pos = np.array([[coords[v] for v in t.vertices] for t in tris]).mean(axis=1)
    t_axis = (tri_pos[:, axis] - lo) / max(hi - lo, 1e-9)
    if not front_at_min:
        t_axis = 1.0 - t_axis
    # HOW FAR UP THE MODEL A FACE IS, 0 at the lowest point and 1 at the highest. The gun's plan
    # never asks; an animal's is three bands of it -- dark back, pale flank, dark belly and legs.
    up_lo = float(coords[:, up_axis].min())
    up_hi = float(coords[:, up_axis].max())
    t_up = (tri_pos[:, up_axis] - up_lo) / max(up_hi - up_lo, 1e-9)

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

    plan = recipe["regionPlan"]
    names = []
    for rule in plan:
        if rule["name"] not in names:
            names.append(rule["name"])
    raw, per_rule = apply_plan(plan, t_axis, t_up, hue * 360.0, saturation, value)
    unplaced = int((raw == "").sum())
    if unplaced:
        # THE DRIVER REFUSES A PLAN WITH NO CATCH-ALL, so reaching this means something worse: a
        # rule matched nothing it should have. A face with no region keeps the generator's colour
        # and nobody decided that.
        fail("%d face(s) matched no rule in the region plan" % unplaced)
    rounds = int(recipe.get("regionSmoothRounds", 3))
    smoothed, changed, neighbours = smooth_regions(list(raw), tris, rounds)
    speckle_before = speckle_of(list(raw), neighbours)
    speckle_after = speckle_of(smoothed, neighbours)
    region_of = np.array(smoothed)
    counts = {name: int((region_of == name).sum()) for name in names}
    REPORT["regionPlanHits"] = per_rule
    log("regions", triangles=counts, plan=per_rule, smoothRounds=rounds, reassigned=changed,
        speckleBefore=speckle_before, speckleAfter=speckle_after)
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

    # A SOFT BAND BOUNDARY, DECIDED ON THE MODEL (Task 69). Where a plan rule asks for it, a face
    # near a height band's edge belongs PARTLY to the band next door, and that partial weight is
    # what gets painted. Without it the two coat bands met along a hard sawtooth -- the triangles
    # that happened to straddle the height -- drawn the length of the animal and visible from every
    # camera (rule 5, two runs). Blurring the finished mask instead was tried and measured: 110
    # texels, the width the saddle really fades over, made every region's mask cover the whole 2048
    # atlas, because a generator packs unrelated islands a few texels apart.
    #
    # THE HARD LABELS STAY exactly as they were: the counts, the speckle check and both
    # verification passes still ask "which region is this face", which is the question that catches
    # a mask in the wrong place.
    soft = soft_weights(plan, region_of, t_up)
    softened = sorted(name for name in names if float(np.abs(soft[name]
                                                             - (region_of == name)).max()) > 0.0)
    if softened:
        planes = {name: np.zeros((size, size), dtype=np.float32) for name in names}
        rasterise_weights(planes, tri_uv, soft, size)
        weights = {name: feather(np.maximum(planes[name], masks[name].astype(np.float32)),
                                 feather_px) for name in names}
        # The correction picks its pixels by the mask and only then lerps by the weight, so the
        # mask has to cover the ramp or the ramp is cut off at the hard region's own edge.
        masks = {name: weights[name] > 0.002 for name in names}
    else:
        weights = {name: feather(mask, feather_px) for name, mask in masks.items()}
    log("masks", pixels={k: int(v.sum()) for k, v in masks.items()}, dilatePx=dilation,
        featherPx=feather_px, softened=softened)
    REPORT["softBands"] = softened

    # `image.pixels` is scene-linear whenever the image is tagged sRGB, which every base colour map
    # out of a generator is. The report says which way it was taken, so a future odd colour has a
    # line to check rather than a mystery.
    linearise = base_image.colorspace_settings.name in ("sRGB", "Filmic sRGB")
    corrections = {"colorspace": base_image.colorspace_settings.name, "linearised": linearise}
    for name in names:
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
    for name in names:
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

    # ---- THE SHINE GOES IN THE MAPS, BECAUSE THE MAPS ARE THE ONLY THING ROBLOX READS.
    #
    # THIS IS TASK 75'S WHOLE POINT, AND IT IS A DEFECT THE PREVIOUS TWO ROUNDS OF THIS TOOL SHIPPED.
    # Task 72 round 2 moved metalness and roughness OUT of the maps and onto one Blender material per
    # region, because painting them into the maps had put visible steps in the EEVEE previews. The
    # previews got better and the game got worse: Roblox's importer builds a `SurfaceAppearance` from
    # the texture MAPS and has nowhere to put a material scalar, so the recipe's numbers reached the
    # four renders and never reached the engine at all.
    #
    # MEASURED, not deduced (Task 75). The uploaded asset 117134580332969, read back in Studio:
    #   SurfaceAppearance ColorMap=91950944543455 MetalnessMap=90465645958960 RoughnessMap=96961706396039
    # and the maps behind those ids were Meshy's own, untouched. Two measurements, and they are of
    # different files, so both numbers are kept: the prep's own output PNGs (which did NOT ship)
    # measured metalness 249/255 = 0.98 and roughness 48/255 = 0.19; the 4096 originals actually
    # embedded in the uploaded FBX measured 232/255 = 0.91 and 49/255 = 0.19.
    # A near-perfect mirror, which is exactly what Karen saw ("barrels too shiny") and what the
    # Director saw in the Task 74 screenshots: bright silver barrels reflecting a bright sky.
    #
    #   "When roughness is at 0%, the surface doesn't scatter light at all, resulting in a much
    #    sharper and brighter reflection and glossiness on your material. At 100%, light and
    #    reflections evenly scatter over the model resulting in a less reflective matte-like surface."
    #   "In most cases, you should set this value to either 0% (non-metal) or 100% (metal), although
    #    you can use partial metalness values when creating surfaces with moderate reflective
    #    properties like satin or silk."
    #     -- create.roblox.com/docs/art/modeling/surface-appearance, read 2026-09-27
    #
    # So the numbers are written into the maps, through the SAME feathered masks as the colour, and
    # the materials below read those maps instead of a scalar: one place a shine number can live, and
    # it is the place the engine looks. The step the previews showed is real and is now what the
    # engine renders too -- the honest answer to it is the feather and the region boundary, not
    # hiding the number where only Blender can see it.
    strength = dict(recipe.get("channelWeight", {"metallic": 1.0, "roughness": 0.85}))
    # THE PACKED MAP IS SPLIT HERE, one step before it is written to, and the pixels come back with
    # the images so nothing has to re-read a generated datablock (see `split_packed_shine`).
    preloaded = {}
    if packed_shine is not None:
        made = split_packed_shine(material, packed_shine, size)
        preloaded = {key: array for key, (_image, array) in made.items()}
        log("splitPackedShine", name=packed_shine.name, splitInto=sorted(made),
            medians={key: round(float(np.median(array[..., 0])), 4)
                     for key, array in preloaded.items()})
        REPORT["packedShineMap"]["medians"] = {
            key: round(float(np.median(array[..., 0])), 4) for key, array in preloaded.items()}
    shine_images = {
        "metallic": ensure_data_map(material, "Metallic", size, 0.0, "dh_metallic"),
        "roughness": ensure_data_map(material, "Roughness", size, 0.5, "dh_roughness"),
    }
    # WHICH IMAGE CARRIED WHICH CHANNEL. One line, and it is the line that says a split map went
    # where it was meant to: with a packed ORM the two names are this tool's own, and if they were
    # ever the same datablock the refusal below would have fired.
    shine = {"created": [], "written": {}, "strength": strength,
             "images": {key: (image.name if image is not None else None)
                        for key, (image, _created) in shine_images.items()}}
    arrays = {}
    # ONE IMAGE CANNOT CARRY TWO VALUES, and a generator that hands back a single combined map is
    # common. The loop below reads, writes and saves each map in turn, so one datablock feeding both
    # sockets would have its metalness overwritten by the roughness pass while
    # `REPORT["shine"]["surface"]` still read the right number out of the in-memory array: measured
    # correct, looked wrong -- the shape this project exists to avoid (review round 1, note).
    metal_image, rough_image = shine_images["metallic"][0], shine_images["roughness"][0]
    if metal_image is not None and metal_image == rough_image:
        fail("one image feeds both the Metallic and the Roughness socket (%s); this tool writes a "
             "value into each map and cannot write two into one" % metal_image.name)
    for key, (image, created) in shine_images.items():
        if image is None:
            REPORT["warnings"].append("no %s map and none could be made: the recipe's %s numbers "
                                      "will not reach the engine" % (key, key))
            continue
        if created:
            shine["created"].append(key)
        elif tuple(image.size) != (size, size):
            # THE MASKS ARE THE BASE COLOUR'S RESOLUTION and a map at any other size cannot be
            # indexed by them. Scaling is honest for these two: by the time they ship they are flat
            # per region apart from the source detail roughness keeps.
            image.scale(size, size)
        # THE SPLIT'S OWN PIXELS WIN over whatever the datablock says now: a generated image's
        # buffer is Blender's to free and comes back black, which is how this run once wrote a
        # roughness map of zeros with every number in the report agreeing with itself.
        arrays[key] = preloaded.get(key)
        if arrays[key] is None:
            arrays[key] = image_array(image)
        for name in names:
            target = recipe["regions"][name].get(key)
            painted = push_channel(arrays[key], weights[name], target, strength.get(key, 1.0))
            shine["written"].setdefault(name, {})[key] = {"target": target, "pixels": painted}
        set_image(image, arrays[key])
    if "metallic" in shine_images and shine_images["metallic"][0] is not None:
        metallic_image = shine_images["metallic"][0]
    if "roughness" in shine_images and shine_images["roughness"][0] is not None:
        roughness_image = shine_images["roughness"][0]

    # ---- THE REBUILT BARRELS' OWN TEXELS, PAINTED BY THE STEP THAT OWNS THEM (task 94)
    #
    # The new faces live in a corner of the atlas that no old face uses, and the region pass paints
    # that corner as barrel -- but MEASURED, over four runs, the barrels still came out at the
    # ACTION's metalness of 0.45. Rather than keep guessing which pass reaches the corner, the step
    # that OWNS those texels writes them itself: the numbers are the barrel region's own, from the
    # recipe. IT RUNS HERE, between the shine pass and the check that samples the surface back
    # through the mesh, for two reasons -- the textures are written to disk further down (a repaint
    # after that reached neither the PNGs nor the export, measured in run 12), and the surface check
    # must measure what actually ships rather than what an earlier pass left.
    rebuilt = REPORT.get("rebuiltBarrels") or {}
    rect = rebuilt.get("patchRect")
    if rect:
        barrel_region = recipe["regions"].get("barrel", {})
        wanted = target_hsv(barrel_region.get("baseColor", {}).get("targetRGB", [26, 28, 34]),
                            linearise)
        painted = {}
        # THE NORMAL MAP IS REPAINTED TOO, AND IT HAS TO BE. MEASURED in the game, not in a render:
        # the borrowed corner of the atlas carries the generator's own normal detail, and on a
        # first-person barrel an inch from the eye that came out as a strong herringbone pattern
        # running down both tubes -- the very "not smooth" Karen is complaining about. A flat tangent
        # normal is (0.5, 0.5, 1.0), so the built tubes are lit by their own geometry and nothing else.
        flat_normal = (0.5, 0.5, 1.0)
        for image, value in ((base_image, None),
                             (metallic_image, barrel_region.get("metallic")),
                             (roughness_image, barrel_region.get("roughness")),
                             (normal_image, flat_normal)):
            if image is None:
                continue
            array = image_array(image)
            height, width = array.shape[0], array.shape[1]
            x0 = max(int(rect[0] * width), 0)
            x1 = min(int(math.ceil(rect[2] * width)), width - 1)
            # the atlas is stored top row first and a v runs from the bottom
            y0 = max(int((1.0 - rect[3]) * height), 0)
            y1 = min(int(math.ceil((1.0 - rect[1]) * height)), height - 1)
            if x1 <= x0 or y1 <= y0:
                continue
            if value is None:
                # `hsv_to_rgb` works on ARRAYS (it paints whole masks), so the one colour is handed
                # to it as a one-element array and read back out.
                channels = hsv_to_rgb(np.array([wanted[0]], dtype=np.float32),
                                      np.array([wanted[1]], dtype=np.float32),
                                      np.array([wanted[2]], dtype=np.float32))[0]
                for channel in range(3):
                    array[y0:y1 + 1, x0:x1 + 1, channel] = float(channels[channel])
                painted["baseColor"] = [round(float(c), 4) for c in channels]
            elif isinstance(value, tuple):
                for channel in range(3):
                    array[y0:y1 + 1, x0:x1 + 1, channel] = float(value[channel])
                painted[image.name] = list(value)
            else:
                array[y0:y1 + 1, x0:x1 + 1, 0:3] = float(value)
                painted[image.name] = float(value)
            set_image(image, array)
        REPORT["rebuiltBarrels"]["repainted"] = painted
        log("repaintedBarrelPatch", **painted)

    # ---- AND SAMPLED BACK THROUGH THE MESH, the same second route the colour uses. A mask that is
    # mirrored, shifted or the wrong region's writes a number that agrees with itself; this one asks
    # the triangles what they actually sit on.
    verified_shine = {}
    for name in names:
        rows = region_of == name
        if not rows.any():
            continue
        coords_here = np.clip((samples[rows] * size).astype(np.int32), 0, size - 1)
        entry = {}
        for key, array in arrays.items():
            picked = array[size - 1 - coords_here[:, :, 1], coords_here[:, :, 0], 0]
            shown = float(np.median(picked))
            target = recipe["regions"][name].get(key)
            entry[key] = {"shown": round(shown, 3), "target": target,
                          "drift": None if target is None else round(abs(shown - float(target)), 3)}
        verified_shine[name] = entry
    REPORT["shine"] = {"maps": shine, "surface": verified_shine}
    log("shine", written=shine, surface=verified_shine)
    ceiling_shine = float(recipe.get("maxShineDrift", 0.08))
    off_shine = sorted(
        "%s %s (%.2f, wanted %.2f)" % (name, key, entry[key]["shown"], entry[key]["target"])
        for name, entry in verified_shine.items()
        for key in entry
        if entry[key]["drift"] is not None and entry[key]["drift"] > ceiling_shine
    )
    if off_shine:
        REPORT["warnings"].append(
            "sampled through the mesh, the shine maps do not carry the numbers they were given "
            "(drift over %.2f): %s" % (ceiling_shine, ", ".join(off_shine)))

    # ---- ONE MATERIAL, DELIBERATELY, AND THE REGIONS LIVE IN THE MAPS.
    #
    # Task 72 round 2 gave each region its own material so the shine could be a material scalar.
    # Task 75 measured what that shipped: nothing. Roblox builds a `SurfaceAppearance` per material
    # THAT HAS MAPS and has nowhere to put a scalar, so the split bought three extra materials and
    # no control at all -- and once the maps carried the numbers, the same split came back from the
    # upload as FOUR SurfaceAppearance children, one with the maps and three empty (measured on
    # asset 140422686530548). A blank SurfaceAppearance on a held weapon is a gun that may render
    # untextured for reasons nobody can see.
    #
    # So: one material, and the region split lives where it is read -- in the base colour, metalness
    # and roughness maps, which is also where `REPORT["shine"]["surface"]` measures it back.
    mesh.update()
    log("materials", slots=[m.name for m in mesh.materials])
    REPORT["materials"] = [m.name for m in mesh.materials]

    # ---- write the corrected textures beside the exports, AND MAKE THE EXPORT USE THEM.
    #
    # THE FBX EXPORTER EMBEDS A FILE, NOT THE PIXELS IN MEMORY. `image.filepath_raw` is where `save()`
    # writes; `image.filepath` is what `path_mode="COPY", embed_textures=True` copies. Setting only
    # the first means the tool writes a corrected PNG beside the results, shows it in its own renders
    # -- and embeds the UNTOUCHED ORIGINAL in the file it hands to Roblox.
    #
    # That is not a hypothesis. The FBX uploaded in Task 73 and shipped in Task 74 was read back byte
    # by byte (Task 75): its three embedded PNGs were the 2048 original base colour and Meshy's
    # 4096x4096 metalness and roughness maps -- medians 0.91 and 0.19, a mirror -- while the 2048
    # corrected maps sat unused in the output folder. Every colour and shine number this tool has
    # ever produced reached the four renders and never reached the game.
    #
    # `verify_embedded_textures` in tools/asset_prep.py now reads the exported FBX back and fails the
    # run unless every embedded PNG is byte-for-byte one of these files.
    written = []
    # THE NORMAL MAP IS HERE BECAUSE IT SHIPS TOO. It is not edited, but it arrives packed like the
    # others, and a packed original is embedded whatever the filepath says -- so a model with a
    # normal map would put a stranger in the FBX and fail `verify_embedded_textures` (review round 1,
    # note). Karen's gun has none; the next asset might.
    for name, image in (("baseColor", base_image), ("metallic", metallic_image),
                        ("roughness", roughness_image), ("normal", normal_image)):
        if image is None:
            continue
        path = os.path.join(out_dir, "texture_%s.png" % name)
        if image.packed_file is not None:
            # An FBX-embedded texture arrives PACKED into the blend, and packed bytes are the
            # ORIGINAL bytes: they win over anything written to disk, which is exactly how two
            # uploads shipped Meshy's raw maps (Task 75, mutation-checked twice: with this line
            # gone the run exits 1 and the uploader refuses the folder).
            image.unpack(method="REMOVE")
        image.filepath_raw = path
        image.file_format = "PNG"
        image.save()
        image.filepath = path
        written.append(os.path.basename(path))
    log("wroteTextures", files=written)
    REPORT["texturesWritten"] = written

    # The lighting rig is already up (the source renders needed it). Without it every render comes
    # out pure black, which is exactly what the first version of this tool produced.
    measured = render_views(ob, out_dir, int(recipe["renderPx"]), int(recipe["renderSamples"]),
                            views)
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
    # "FACE" -- SMOOTHING GROUPS -- AND TASK 92 HAD THE REASON BACKWARDS. `FACE` does not mean "flat
    # shade everything": it writes a smoothing GROUP per polygon, which is the only smoothing
    # information Roblox's FBX importer reads. Task 92 saw a flat-shaded gun and blamed this setting,
    # when the cause was that nothing had ever called `shade_smooth`; switching to `EDGE` then sent
    # Roblox a file with no smoothing groups at all, and MEASURED IN THE GAME (task 94): the rebuilt
    # tubes, perfectly smooth in Blender's own render, arrived in Roblox as a herringbone of flat
    # triangles down both barrels. With the mesh shaded smooth by angle above, `FACE` carries that
    # shading across.
    smooth_type = "FACE"
    bpy.ops.export_scene.fbx(filepath=fbx_path, use_selection=True, path_mode="COPY",
                             embed_textures=True, mesh_smooth_type=smooth_type)
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
