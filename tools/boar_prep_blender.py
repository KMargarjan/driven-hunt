# Driven Hunt boar prep, the half that runs INSIDE Blender.
#
# SPDX-License-Identifier: GPL-2.0-or-later
# This file imports `bpy` and is therefore a script written for Blender; the Blender Foundation asks
# that such a script be licensed GPL-2.0-or-later, so it is, exactly as tools/asset_prep_blender.py
# is. `tools/boar_prep.py` spawns it and carries the repository's own terms.
#
# It is driven entirely by a recipe JSON written by that tool, and it writes one measurements JSON
# back. No decision is taken here: every number arrives in the recipe, and everything this file
# learns about the model is MEASURED and handed back rather than acted on.
#
# Pattern: headless Blender as a batch converter (`blender --background --python`), the same shape
# `tools/asset_prep.py` already uses here.
#   FBX importer / exporter   https://docs.blender.org/manual/en/latest/addons/import_export/scene_fbx.html
#   Slotted Actions (4.4+)    https://developer.blender.org/docs/release_notes/4.4/animation/
#     An action does not apply until an `action_slot` is assigned as well, which is why the
#     evaluation below sets both. Without it every pose read back is the rest pose -- measured on
#     2026-10-03: every clip's foot speed came out 0.000 m/s.
#   Skinned meshes in Roblox  https://create.roblox.com/docs/art/modeling/rigging
#
# Note: docs/research/2026-10-03-boar-skinned-model.md

import json
import math
import os
import sys

import bpy  # noqa: E402  (Blender provides it; this file only ever runs inside Blender)
import mathutils  # noqa: E402  (same: Blender's own vector and quaternion maths)


def say(message):
    print("[boar-prep-blender] " + message, flush=True)


# ---------------------------------------------------------------- the scene


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_fbx(path):
    """Import one FBX and return the objects it added."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def one_of(objects, kind):
    found = [o for o in objects if o.type == kind]
    if len(found) != 1:
        raise SystemExit(
            "[boar-prep-blender] expected exactly one %s in the mesh file, found %d" % (kind, len(found))
        )
    return found[0]


def keep_actions(keep):
    """Rename every wanted action to its short name and delete the rest.

    The package names its actions `Arm_Boar.001|Arm_Boar|Walk_F_IP` -- the armature's name twice and
    then the clip -- so the clip is whatever follows the last `|`. Both spellings seen in this
    package ("Arm_Boar|..." and "Arm_Boar.001|...") fall out of that.
    """
    wanted = {name: None for name in keep}
    for action in list(bpy.data.actions):
        short = action.name.split("|")[-1]
        if short in wanted and wanted[short] is None:
            action.name = short
            action.use_fake_user = True  # survives a save/reload with no user
            wanted[short] = action
        else:
            bpy.data.actions.remove(action)
    missing = [name for name, action in wanted.items() if action is None]
    if missing:
        raise SystemExit("[boar-prep-blender] the animation file has no clip called: " + ", ".join(missing))
    return [wanted[name] for name in keep]


def build_material(name, maps):
    """One Principled material: albedo, roughness, normal. Exactly what Roblox's SurfaceAppearance reads."""
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    tree = material.node_tree
    bsdf = tree.nodes["Principled BSDF"]

    def texture(path, socket, non_color):
        image = bpy.data.images.load(path)
        if non_color:
            image.colorspace_settings.name = "Non-Color"
        node = tree.nodes.new("ShaderNodeTexImage")
        node.image = image
        if socket == "Normal":
            normal = tree.nodes.new("ShaderNodeNormalMap")
            tree.links.new(node.outputs["Color"], normal.inputs["Color"])
            tree.links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
        else:
            tree.links.new(node.outputs["Color"], bsdf.inputs[socket])
        return image

    texture(maps["albedo"], "Base Color", False)
    if maps.get("roughness"):
        texture(maps["roughness"], "Roughness", True)
    if maps.get("normal"):
        texture(maps["normal"], "Normal", True)
    # Metalness is not mapped: this package's Metallic map is black (a boar is not metal) and
    # Roblox's SurfaceAppearance takes a MetalnessMap it would then have to be given. One less file.
    bsdf.inputs["Metallic"].default_value = 0.0
    return material


def shade_smooth(mesh_object, angle_deg):
    """Smooth the surface, keeping only edges sharper than `angle_deg` hard.

    Task 92 learned this on the gun: a flat-shaded import reads as bright shards with dark seams.
    An animal has no real hard edges at all, so the angle is wide.
    """
    if angle_deg is None:
        return
    for polygon in mesh_object.data.polygons:
        polygon.use_smooth = True
    bpy.context.view_layer.objects.active = mesh_object
    for modifier in list(mesh_object.modifiers):
        if modifier.type == "SMOOTH_BY_ANGLE":
            mesh_object.modifiers.remove(modifier)
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle_deg))
    except (AttributeError, RuntimeError, TypeError) as error:
        # Older Blenders spell this as mesh auto-smooth. Smooth-everything is still applied above,
        # so a failure here loses the sharp edges and not the shading.
        say("shade_smooth_by_angle unavailable (%s); every face is smooth" % type(error).__name__)


# ---------------------------------------------------------------- measuring


def world_bbox(mesh_object):
    """The mesh's own vertex bounds in world space: (min, max, dimensions), in Blender metres."""
    matrix = mesh_object.matrix_world
    points = [matrix @ vertex.co for vertex in mesh_object.data.vertices]
    lo = [min(p[i] for p in points) for i in range(3)]
    hi = [max(p[i] for p in points) for i in range(3)]
    return lo, hi, [hi[i] - lo[i] for i in range(3)]


def activate(armature, action):
    """Make `action` the one the armature evaluates, slot and all (see the header)."""
    armature.animation_data.action = action
    if hasattr(armature.animation_data, "action_slot"):
        slots = list(getattr(action, "slots", []))
        if slots:
            armature.animation_data.action_slot = slots[0]


def bone_track(armature, action, bone_names):
    """Every frame of `action`: each named bone's head, in world space. Reads the EVALUATED object."""
    scene = bpy.context.scene
    activate(armature, action)
    first, last = int(round(action.frame_range[0])), int(round(action.frame_range[1]))
    track = {name: [] for name in bone_names}
    for frame in range(first, last + 1):
        scene.frame_set(frame)
        evaluated = armature.evaluated_get(bpy.context.evaluated_depsgraph_get())
        for name in bone_names:
            bone = evaluated.pose.bones.get(name)
            if bone is not None:
                track[name].append(tuple(evaluated.matrix_world @ bone.head))
    return first, last, track


def lowest_hoof(track):
    """The lowest a hoof ever gets in this clip, in metres, and the mean of the four.

    AN ANIMAL STANDS ON ITS FEET, and that is a number. A clip whose hooves never come near the
    floor is one where the animal is drawn floating -- which is exactly what a pose baked out of
    leftover channels looks like (see `rest_pose`). Comparing an authored clip's figure with the clip
    it was built from is the whole test.
    """
    lows = []
    for positions in track.values():
        if positions:
            lows.append(min(point[2] for point in positions))
    if not lows:
        return 0.0, 0.0
    return min(lows), sum(lows) / len(lows)


def ground_speed(track, fps, contact_fraction):
    """How fast the ground slides under this clip, in metres per second, at playback rate 1.0.

    THE MEASUREMENT THAT DECIDES WHETHER FEET SLIDE. Every locomotion clip here is IN PLACE: the
    root bone does not move (measured: 0.0000 drift on all ten), so the animal's real ground speed
    is carried entirely by the feet. Take each hoof's own height range, call the lowest
    `contact_fraction` of it "planted", and measure how far that hoof travels horizontally per second
    while it is planted. A planted foot moves backwards at exactly the speed the body moves forward,
    so that number IS the clip's ground speed -- and `speed / groundSpeed` is the playback rate at
    which the feet do not slide.

    Returns (metres per second, per-hoof values, how many frames were counted). 0.0 and an empty list
    mean "this clip has no foot cycle", which is the right answer for an idle, a hit or a death.
    """
    per_hoof = []
    counted = 0
    for name, samples in sorted(track.items()):
        if len(samples) < 4:
            continue
        heights = [point[2] for point in samples]
        low, high = min(heights), max(heights)
        if high - low < 1e-6:
            continue  # the hoof never leaves the ground: no cycle to measure
        threshold = low + contact_fraction * (high - low)
        travelled, frames = 0.0, 0
        for index in range(len(samples) - 1):
            if heights[index] <= threshold and heights[index + 1] <= threshold:
                step = samples[index + 1]
                previous = samples[index]
                travelled += math.hypot(step[0] - previous[0], step[1] - previous[1])
                frames += 1
        if frames:
            per_hoof.append(travelled / (frames / float(fps)))
            counted += frames
    if not per_hoof:
        return 0.0, [], 0
    return sum(per_hoof) / len(per_hoof), per_hoof, counted


def with_floor(metres_per_second, floor):
    """Below `floor`, a clip has NO GAIT and the honest answer is exactly zero.

    MEASURED, 2026-10-03, and the reason this exists: Idle_1 and the two Hit clips came back at
    1e-7..1e-4 m/s -- a planted hoof jittering by a ten-thousandth of a millimetre -- and the two
    Death clips at 0.057 m/s, which is a body settling onto its side. Dividing a real speed by any of
    those gives a playback rate in the hundreds of thousands, which is not a small error but a
    meaningless one. The floor sits between 0.057 (a death) and 0.647 (a turn in place), so every
    clip with a real gait keeps its measurement and every clip without one reads zero.
    """
    return 0.0 if metres_per_second < floor else metres_per_second


# ---------------------------------------------------------------- exporting


# ---------------------------------------------------------------- clips the package does not have
#
# TASK 116. Karen, 2026-10-03: "can fall on side and legs moving like in real life" and "can be hit
# to back part start to do circles with first legs on". Neither can be drawn without a clip, and the
# package's 74 have no animal dying on the ground and none dragging a hindquarter -- MEASURED
# differently and worse first: `Bone.Transform` is the Animator's output and a script's write to it
# survived 0 of 122 frames on the server and 0 of 121 on the client, so there is no runtime way to
# move one leg over a playing track (docs/research/2026-10-04-boar-shot-and-death.md section 4).
#
# SO THE CLIPS ARE AUTHORED HERE, OUT OF THE CLIPS THAT EXIST, which is rule 2 (borrow before
# building) applied to animation: nothing below invents a pose. Every frame is a blend between poses
# the package's own animator made --
#   Death_Paddle_L/R : the last frame of Death_L/Death_R, with the four legs swinging back toward
#                      RUN_F_IP's own leg poses at an amplitude that decays to nothing. A dying
#                      animal's legs do a slowed, failing version of running, and that is literally
#                      what this is.
#   Cripple_Drag     : WALK_F_IP everywhere, with the hind legs (and a little of the rear spine)
#                      blended toward the death pose, so the front legs walk a real walk cycle and
#                      the back end hangs and drags behind them.
# Blending two authored poses cannot produce a bone axis that does not exist on this rig, which is
# the failure every "rotate the leg bone about X" approach risks. Slerp:
#   https://docs.blender.org/api/current/mathutils.html#mathutils.Quaternion.slerp
#
# NOTHING HERE DECIDES ANYTHING: the names, the sources, the bone groups, the rate, the length and
# every blend fraction arrive in the recipe, exactly as the rest of this file works.


def rest_pose(armature):
    """Put every bone back where the rig says it belongs.

    THE BUG THIS EXISTS FOR, and it was visible before it was understood (task 116, 2026-10-03): a
    pose channel an action does NOT key keeps whatever the last evaluated action left in it. So
    reading `Death_L`'s last frame and then reading `Walk_F_IP`'s frames gave walk poses with the
    DEATH pose still sitting in every channel the walk does not animate -- the root included -- and
    the authored clips were baked with it. On a live rig the boar was drawn a stud above its own
    shadow with its legs folded (`.screenshots/boar-116d-drag-*.png`). Clearing to rest first is the
    fix, and `lowestHoofMetres` below is the measurement that would have caught it without eyes.
    """
    for bone in armature.pose.bones:
        bone.matrix_basis.identity()


def pose_of(armature, action, frame, bone_names):
    """Every named bone's pose (rotation quaternion and location) with `action` at `frame`."""
    rest_pose(armature)
    activate(armature, action)
    bpy.context.scene.frame_set(int(round(frame)))
    bpy.context.view_layer.update()
    out = {}
    for name in bone_names:
        bone = armature.pose.bones.get(name)
        if bone is None:
            continue
        out[name] = (bone.rotation_quaternion.copy(), bone.location.copy())
    return out


def write_pose(armature, action, frame, poses):
    """Key one frame of `action` from a {bone: (quaternion, location)} map. Every bone in the map is
    written, and the rest are cleared first, so nothing carries over from the last evaluation."""
    rest_pose(armature)
    activate(armature, action)
    for name, (rotation, location) in poses.items():
        bone = armature.pose.bones.get(name)
        if bone is None:
            continue
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion = rotation
        bone.location = location
        bone.keyframe_insert("rotation_quaternion", frame=frame)
        bone.keyframe_insert("location", frame=frame)


def blended(a, b, factor):
    """Pose `a` moved `factor` of the way toward pose `b`."""
    rotation = a[0].slerp(b[0], factor)
    location = a[1].lerp(b[1], factor)
    return (rotation, location)


def synth_actions(armature, recipe, fps):
    """Builds every clip in `recipe['synth']` and returns the new actions, in recipe order."""
    spec = recipe.get("synth")
    if not spec:
        return []
    bones = [bone.name for bone in armature.data.bones]
    made = []
    for row in spec:
        source = bpy.data.actions.get(row["from"])
        gait = bpy.data.actions.get(row["gait"])
        if source is None or gait is None:
            raise SystemExit(
                "[boar-prep-blender] clip %r needs %r and %r, and the kept set has %s"
                % (row["name"], row["from"], row["gait"], ", ".join(sorted(a.name for a in bpy.data.actions)))
            )
        legs = [name for name in bones if any(name.startswith(prefix) for prefix in row["legBones"])]
        soft = [name for name in bones if any(name.startswith(prefix) for prefix in row.get("softBones", []))]
        if not legs:
            raise SystemExit(
                "[boar-prep-blender] clip %r matched no leg bone from %s; this rig has %s"
                % (row["name"], row["legBones"], ", ".join(sorted(bones)))
            )

        base_frame = source.frame_range[1] if row["fromFrame"] == "last" else source.frame_range[0]
        base = pose_of(armature, source, base_frame, bones)
        gait_first, gait_last = int(round(gait.frame_range[0])), int(round(gait.frame_range[1]))
        gait_frames = max(gait_last - gait_first + 1, 1)
        gait_poses = [pose_of(armature, gait, gait_first + i, bones) for i in range(gait_frames)]

        made_action = bpy.data.actions.new(row["name"])
        made_action.use_fake_user = True
        total = int(round(row["seconds"] * fps)) if row.get("seconds") else gait_frames
        every = max(int(row.get("keyEvery", 1)), 1)
        # A LOOPED CLIP STOPS ONE FRAME SHORT OF REPEATING ITSELF. Roblox blends a looping track's
        # last frame into its first, so keying both as the same pose is a one-frame pause every lap.
        # A one-shot keeps its final frame, because that is the pose the carcass is held at.
        last_step = total if row["kind"] == "paddle" else total - 1
        for step in range(0, last_step + 1, every):
            t = step / float(fps)
            if row["kind"] == "paddle":
                # The amplitude decays to nothing and then the animal is still: `decayPower` 2 makes
                # the last second nearly motionless, which is an animal going quiet rather than one
                # switched off. The phase runs at the gait's own cycle times `hz`.
                left = max(1.0 - t / row["seconds"], 0.0)
                amplitude = row["amplitude"] * (left ** row["decayPower"])
                phase = int((t * row["hz"] * gait_frames) % gait_frames)
                target = gait_poses[phase]
                frame_pose = dict(base)
                for name in legs:
                    if name in base and name in target:
                        frame_pose[name] = blended(base[name], target[name], amplitude)
                for name in soft:
                    if name in base and name in target:
                        frame_pose[name] = blended(base[name], target[name], amplitude * row["softScale"])
            else:
                # The drag: the gait everywhere, pulled toward the collapsed pose on the back end.
                target = gait_poses[step % gait_frames]
                frame_pose = dict(target)
                for name in legs:
                    if name in base and name in target:
                        frame_pose[name] = blended(target[name], base[name], row["amplitude"])
                for name in soft:
                    if name in base and name in target:
                        frame_pose[name] = blended(target[name], base[name], row["amplitude"] * row["softScale"])
            write_pose(armature, made_action, 1 + step, frame_pose)
        say("authored %-16s %3d frames from %s + %s" % (row["name"], last_step + 1, row["from"], row["gait"]))
        made.append(made_action)
    return made


def clear_nla(armature):
    for track in list(armature.animation_data.nla_tracks):
        armature.animation_data.nla_tracks.remove(track)
    armature.animation_data.action = None


def export_fbx(path, global_scale):
    """One FBX, with whatever animation the armature is currently carrying.

    THE SCALE GOES INTO THE GEOMETRY, AND THAT IS A MEASUREMENT, NOT A PREFERENCE.
    It has to be baked in somewhere, because a skinned MeshPart cannot be resized afterwards:
    `Size`/`ScaleTo` moves the mesh and not the bones, which tears the model as soon as a clip plays
    (Director, 2026-10-03).
    TWO UPLOADS MEASURED THE RULE, and it is one sentence: **Roblox reads one RAW FBX geometry unit
    as one stud, and does not read the FBX unit header at all.**
      * asset 73934667856496: `global_scale=0.028668` with `apply_scale_options='FBX_SCALE_ALL'`
        ("apply custom scaling and units scaling to FBX scale") left the geometry at Blender metres,
        1.9185 raw units -- and it arrived as a MeshPart 1.9185 studs long. The header was ignored.
      * asset 95872773434675: `global_scale=2.866849` with `FBX_SCALE_NONE` ("...to each object
        transformation") wrote 1.9185 x 2.866849 x 100 = 550 raw units -- and it arrived 550 studs
        long. The 100 is Blender's own metre-to-centimetre unit scaling, which `FBX_SCALE_NONE` also
        pushes into the geometry.
    So `FBX_SCALE_NONE` is right -- it is the only option that puts the scale in the vertices AND the
    bone rest matrices together, which is the only place the mesh and the skeleton can agree about it
    -- and `global_scale` has to carry that 100 as well. `exported_units` below is the guard: the
    run FAILS if what came back out is not the length that was asked for.
    """
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=path,
        path_mode="COPY",
        embed_textures=True,
        add_leaf_bones=False,
        bake_anim=True,
        bake_anim_use_all_actions=True,
        bake_anim_use_nla_strips=False,
        bake_anim_simplify_factor=0.0,
        global_scale=global_scale,
        apply_scale_options="FBX_SCALE_NONE",
    )


# ---------------------------------------------------------------- the run


def main():
    recipe_path = sys.argv[-1]
    with open(recipe_path, "r", encoding="utf-8") as handle:
        recipe = json.load(handle)

    out = recipe["out"]
    reset()

    added = import_fbx(recipe["meshFbx"])
    armature = one_of(added, "ARMATURE")
    mesh = one_of(added, "MESH")

    # The animation file carries its own copy of the rig and mesh. Keep its ACTIONS and throw its
    # objects away, so there is exactly one armature in the scene to export.
    for extra in import_fbx(recipe["animFbx"]):
        bpy.data.objects.remove(extra, do_unlink=True)

    actions = keep_actions(recipe["clips"])
    say("kept %d clip(s): %s" % (len(actions), ", ".join(action.name for action in actions)))

    # THE AUTHORED CLIPS ARE BUILT BEFORE ANYTHING IS MEASURED OR EXPORTED, so they are measured,
    # exported and reported exactly like the ones that came in the package (task 116).
    armature.animation_data_create()
    actions = actions + synth_actions(armature, recipe, recipe["fps"])

    material = build_material(recipe["materialName"], recipe["maps"])
    mesh.data.materials.clear()
    mesh.data.materials.append(material)
    shade_smooth(mesh, recipe.get("smoothAngleDeg"))

    lo, hi, dimensions = world_bbox(mesh)
    triangles = sum(len(polygon.vertices) - 2 for polygon in mesh.data.polygons)
    # WHICH AXIS IS THE LENGTH IS MEASURED, not assumed: the longest one. A recipe may pin it
    # (`lengthAxis`) for a model whose longest axis is not what it is meant to be fitted by.
    length_axis = recipe.get("lengthAxis")
    if length_axis is None:
        length_axis = max(range(3), key=lambda index: dimensions[index])
    length_m = dimensions[length_axis]
    studs_per_metre = recipe["lengthStuds"] / length_m
    # THE SCALE IS BAKED INTO THE GEOMETRY AND IS COMPUTED FROM THE MODEL'S OWN MEASURED LENGTH,
    # which is why it is decided here and not by the caller: `tools/boar_prep.py` cannot read an FBX.
    # MEASURED (asset 73934667856496, 2026-10-03): Roblox's importer reads one FBX geometry unit as
    # one stud. So the ratio IS studs per metre, and `robloxStudsPerFbxUnit` is the measurement
    # written down rather than a convention assumed. `scaleCorrection` is the one dial for "Studio
    # measured something else again"; the default 1.0 says nobody has had to use it.
    global_scale = (
        studs_per_metre
        / (recipe["fbxUnitsPerMetre"] * recipe["robloxStudsPerFbxUnit"])
        * recipe["scaleCorrection"]
    )

    measured = {}
    for action in actions:
        first, last, track = bone_track(armature, action, recipe["hoofBones"])
        root = bone_track(armature, action, [recipe["rootBone"]])[2][recipe["rootBone"]]
        drift = 0.0
        if root:
            drift = max(math.hypot(p[0] - root[0][0], p[1] - root[0][1]) for p in root)
        raw, per_hoof, frames = ground_speed(track, recipe["fps"], recipe["contactFraction"])
        floor_m, mean_floor_m = lowest_hoof(track)
        metres_per_second = with_floor(raw, recipe["minGroundMetresPerSecond"])
        measured[action.name] = {
            "firstFrame": first,
            "lastFrame": last,
            "frames": last - first + 1,
            # A CLIP'S LENGTH IS ITS INTERVALS, NOT ITS KEYS, and this tool said keys for a whole
            # task. MEASURED by loading each published asset back with `Animator:LoadAnimation` and
            # reading `AnimationTrack.Length` (2026-10-03): Walk_F_IP 25 keys -> 1.0000 s, Death_L
            # 30 -> 1.2083, Cripple_Drag 25 -> 1.0000, Death_Paddle_L 97 -> 4.0000. Every one of them
            # is (keys - 1) / fps. `frames / fps` is one frame long, which is how the ten package
            # clips' lengths had to be corrected by hand after Task 115 published them, and how the
            # three this tool authored arrived 42 ms long in the same way.
            "seconds": (last - first) / float(recipe["fps"]),
            "rootDriftMetres": drift,
            "groundMetresPerSecond": metres_per_second,
            "groundMetresPerSecondRaw": raw,
            "hasGait": metres_per_second > 0.0,
            "groundStudsPerSecond": metres_per_second * studs_per_metre,
            "perHoofMetresPerSecond": per_hoof,
            "contactFrames": frames,
            # Where the feet are, not just how fast they move: see `lowest_hoof`.
            "lowestHoofMetres": floor_m,
            "meanLowestHoofMetres": mean_floor_m,
        }
        say(
            "%-16s %3d keys  %.3f s  ground %.3f m/s -> %.3f studs/s  lowest hoof %.3f m"
            % (
                action.name,
                measured[action.name]["frames"],
                measured[action.name]["seconds"],
                metres_per_second,
                measured[action.name]["groundStudsPerSecond"],
                floor_m,
            )
        )

    # (a) ONE FILE WITH EVERY CLIP: what Open Cloud uploads as the Model, and what Studio's 3D
    #     importer opens when somebody wants the whole rig at once.
    clear_nla(armature)
    for action in actions:
        track = armature.animation_data.nla_tracks.new()
        track.name = action.name
        track.strips.new(action.name, int(round(action.frame_range[0])), action)
    armature.animation_data.action = None
    export_fbx(os.path.join(out, recipe["modelFile"]), global_scale)

    # (b) ONE FILE PER CLIP: what the Animation Editor's "Import -> From FBX Animation" takes, one
    #     clip at a time, which is the ONLY route to an animation asset id (research note section 4).
    #     A file per clip is what makes that a mechanical two clicks instead of a judgement call.
    clear_nla(armature)
    for action in actions:
        activate(armature, action)
        export_fbx(os.path.join(out, recipe["clipDir"], action.name + ".fbx"), global_scale)
    clear_nla(armature)

    # EVERYTHING THE REPORT NEEDS IS READ BEFORE THE SCENE IS WIPED. `reset()` below invalidates
    # every Blender object held here, and reading one afterwards is a ReferenceError (measured).
    vertices = len(mesh.data.vertices)
    bone_names = sorted(bone.name for bone in armature.data.bones)

    # THE EXPORT IS RE-OPENED AND MEASURED, which costs a second and closes the hole this task fell
    # into once already: the scale was wrong for a whole upload before anything measured it. With
    # `FBX_SCALE_NONE` the file's unit factor is 1.0, so what Blender reads back IS the geometry, and
    # the number below is what Roblox's importer will see.
    model_path = os.path.join(out, recipe["modelFile"])
    reset()
    checked = import_fbx(model_path)
    check_mesh = [o for o in checked if o.type == "MESH"]
    if len(check_mesh) != 1:
        raise SystemExit(
            "[boar-prep-blender] the export re-opens as %d mesh objects, not 1: it cannot be measured"
            % len(check_mesh)
        )
    # The importer undoes the metre-to-centimetre scaling the exporter applied, so what it hands
    # back is metres and the RAW units are that times `fbxUnitsPerMetre`. Raw units are what Roblox
    # reads, so raw units are what this checks.
    _lo, _hi, reimported = world_bbox(check_mesh[0])
    exported_units = [value * recipe["fbxUnitsPerMetre"] for value in reimported]
    say(
        "re-opened the export: %.3f x %.3f x %.3f raw FBX units; the length is %.4f and should be %.4f"
        % (
            exported_units[0],
            exported_units[1],
            exported_units[2],
            exported_units[length_axis],
            recipe["lengthStuds"],
        )
    )
    # THE GUARD, and it is the whole reason the export is re-opened. Both uploads above were made
    # before anything measured the file, and the first of them was wrong by a factor of one and the
    # second by a factor of a hundred. 0.1 % is tighter than any error either of them made and
    # looser than an FBX round trip's own float noise.
    drift = abs(exported_units[length_axis] - recipe["lengthStuds"]) / recipe["lengthStuds"]
    if drift > 0.001:
        raise SystemExit(
            "[boar-prep-blender] the export is %.4f raw units long but %.4f studs were asked for"
            " (%.2f %% out). Roblox reads raw units as studs, so this model would arrive the wrong"
            " size. Check `fbxUnitsPerMetre`, `robloxStudsPerFbxUnit` and `scaleCorrection`."
            % (exported_units[length_axis], recipe["lengthStuds"], drift * 100.0)
        )

    report = {
        "triangles": triangles,
        "exportedBboxRawUnits": exported_units,
        "exportedLengthRawUnits": exported_units[length_axis],
        "vertices": vertices,
        "bones": len(bone_names),
        "boneNames": bone_names,
        "bboxMinMetres": lo,
        "bboxMaxMetres": hi,
        "bboxMetres": dimensions,
        "lengthMetres": length_m,
        "lengthAxis": length_axis,
        "studsPerMetre": studs_per_metre,
        "globalScale": global_scale,
        # What the model SHOULD measure in Studio once imported. Nothing here can check it: the
        # answer is Roblox's importer's, so `tools/boar_prep.py` prints it as a thing to measure.
        "expectedSizeStuds": [dimension * studs_per_metre for dimension in dimensions],
        "clips": measured,
    }
    with open(os.path.join(out, recipe["measurementsFile"]), "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
    say(
        "measured %d triangles, %d bones, %.4f m long on axis %d; global_scale %.6f"
        % (triangles, len(bone_names), length_m, length_axis, global_scale)
    )


if __name__ == "__main__":
    main()
