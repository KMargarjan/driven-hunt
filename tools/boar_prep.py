"""Driven Hunt boar prep: turn a bought, rigged animal package into one model this game can wear.

It drives **headless Blender** (`--background --python`) with `tools/boar_prep_blender.py` and does
the four things a bought animal needs before a boar in this game can be it:

  (a) KEEP THE TEN CLIPS the drive actually asks for, out of the package's 74, renamed to their
      short names (the package calls `Walk_F_IP` "Arm_Boar.001|Arm_Boar|Walk_F_IP");
  (b) SCALE THE WHOLE THING so the model is `--length-studs` long, baked into the FBX -- because a
      skinned MeshPart cannot be scaled after import without tearing (`Size`/`ScaleTo` moves the
      mesh and not the bones), which the Director measured on 2026-10-03;
  (c) SHRINK THE TEXTURES to `--texture-px` and drop the albedo's alpha channel, and let a caller
      pick WHICH albedo -- the package ships three colour variants of the same boar;
  (d) EXPORT TWICE: one `model.fbx` carrying the rig and every clip, which is what Open Cloud
      uploads as the Model; and one FBX PER CLIP under `clips/`, which is what Studio's Animation
      Editor takes through "Import -> From FBX Animation", one clip at a time. That second output
      exists because **an animation asset id can only be made in Studio** -- Open Cloud's Assets API
      takes an Animation only as a `.rbxm`/`.rbxmx` "edited inside Roblox Studio", which nothing
      outside Studio can write (research note section 4). A file per clip makes the Director's route
      two clicks each instead of a judgement call.

It also MEASURES the one number the animation layer needs and cannot guess: **how fast the ground
slides under each locomotion clip**. Every clip in this package is in place -- the root bone does not
move -- so the animal's real speed is carried by its feet, and the speed of a planted hoof IS the
clip's ground speed. `speed / groundStudsPerSecond` is then the playback rate at which the feet do
not slide, which is what `Boar.CONFIG.MODEL` is built from.

THIS FILE NEVER IMPORTS `bpy`. It spawns a process, so it carries the repository's terms;
`tools/boar_prep_blender.py` runs inside Blender and carries GPL-2.0-or-later, which is what the
Blender Foundation asks of a published script written for Blender. Same split as `tools/asset_prep.py`.

Usage:
  python tools/boar_prep.py probe --in <fbx-folder> [--animal BoarMale]
  python tools/boar_prep.py prep --in <fbx-folder> --textures <texture-folder> --out <folder>
        [--animal BoarMale] [--albedo 1|2|3] [--length-studs 5.5] [--texture-px 1024]
        [--clips Idle_1,Walk_F_IP,...] [--scale-correction 1.0] [--dry-run]
  python tools/boar_prep.py selftest        # offline: no Blender, no model, no network

Exit codes, the harness's shape: 0 done - 1 the run failed - 2 REFUSED before anything happened.

WHAT IT REFUSES, BEFORE IT TOUCHES ANYTHING:
  1. No Blender. `BLENDER_EXE` in the environment wins; otherwise the usual install locations are
     searched. A missing Blender is a refusal, never a silent skip.
  2. A missing input: the `<animal>_NoAlpha.fbx` mesh, the `<animal>_anim_IP.fbx` clips, or any of
     the texture maps the recipe asks for. Named one by one, so one run says everything that is
     wrong.
  3. An output path INSIDE the repository. Everything this tool writes is generated and large: the
     repo takes none of it, and `.rbxm` is banned outright anyway (CLAUDE.md).
  4. An output folder that already exists and is not empty. Nothing is ever overwritten and nothing
     is ever deleted (rule 7): a second run wants a second folder.
  5. A clip the package does not have, an albedo variant it does not ship, a non-positive length or
     a texture size that is not a power of two between 256 and 4096.

THE INPUT IS COPIED, NOT OPENED, exactly as `tools/asset_prep.py` does it and for the same reason:
Blender's FBX importer extracts embedded textures into a `.fbm` folder NEXT TO THE FILE IT READS. So
the mesh and clip files are copied into the output's own `source/`, Blender works from the copies,
and every original is hashed before and after -- a single difference, including a new file appearing,
fails the run. That guard is the point; the copy is just how it is kept true.

THE RECIPE IS THE RUN. Every number Blender uses is in one JSON document written into the output
folder beside the results, so a run is repeatable from its own output and a change is a number in a
file rather than an edit to this program.

NO NETWORK, EVER. This file has no HTTP client and nothing in it uploads. A model reaching Roblox is
Karen's explicit decision and a different tool (`tools/roblox_upload.py`).

Note: docs/research/2026-10-03-boar-skinned-model.md
"""

import argparse
import datetime
import hashlib
import json
import os
import shutil
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER_SCRIPT = os.path.join(REPO, "tools", "boar_prep_blender.py")
TOOL_VERSION = "boar-prep/1"

# Where Blender usually is on this kind of machine. `BLENDER_EXE` overrides all of it, and nothing
# here is a user path, so the public-repo scan has nothing to find. Same list as asset_prep.py.
BLENDER_CANDIDATES = (
    r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe",
    r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
    r"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe",
    "/usr/bin/blender",
    "/usr/local/bin/blender",
)

# THE TEN CLIPS THE DRIVE ASKS FOR, and the whole list of reasons:
#   Idle_1                  a boar that is standing still is standing still, not sliding
#   Walk_F_IP               WANDER_SPEED, grazing
#   Trot_F_IP               TROT_SPEED, being pushed
#   Run_F_IP                SPRINT_SPEED, bolting from a shot
#   Turn_L_IP, Turn_R_IP    a hard turn, so a boar changing direction does not skate sideways
#   Death_L, Death_R        DOWN: it falls on a side, which is the side Body.collapse rolls it onto
#   Hit_F, Hit_B            the flinch on the tick a pellet lands
# The package has 74. Every one of the other 64 -- swimming, digging, eating, jumping, attacking --
# is a state this game's Brain does not have (docs/design/boar-ai.md section 4), and an animation
# nothing can reach is an asset id nobody reviewed.
DEFAULT_CLIPS = (
    "Idle_1",
    "Walk_F_IP",
    "Trot_F_IP",
    "Run_F_IP",
    "Turn_L_IP",
    "Turn_R_IP",
    "Death_L",
    "Death_R",
    "Hit_F",
    "Hit_B",
)

# THE THREE CLIPS THE PACKAGE DOES NOT HAVE, AUTHORED OUT OF THE ONES IT DOES (task 116).
#
# Karen, 2026-10-03: "can fall on side and legs moving like in real life" and "can be hit to back
# part start to do circles with first legs on". Both need a clip. The package has no animal dying on
# the ground and none dragging a hindquarter, and there is no runtime way to make one: `Bone.Transform`
# is the Animator's output and a script's write to it survived 0 of 122 frames on the server and 0 of
# 121 on the client (docs/research/2026-10-04-boar-shot-and-death.md section 4).
#
# NOTHING IS INVENTED, which is rule 2 applied to animation. Each authored frame is a blend between
# two poses this package's own animator made:
#   Death_Paddle_L/R   Death_L/Death_R's LAST frame -- the pose the carcass holds -- with the four
#                      legs swinging back toward Run_F_IP's leg poses at an amplitude that decays to
#                      nothing over four seconds. A dying animal's legs do a slowed, failing version
#                      of running; this is exactly that, and it ENDS where it began, so the hold
#                      frame after it is the same pose and nothing pops.
#   Cripple_Drag       Walk_F_IP everywhere, with the hind legs pulled 85 % of the way to the death
#                      pose and the rear spine 30 % -- the front legs walk a real walk cycle and the
#                      back end hangs behind them. Looped: it is the walk's own cycle length.
#
# The bone-group prefixes are this rig's (46 bones, measured and listed in
# `measurements.json`): the hind chain is hip_b / thigh_b / shin_b / hoof_b (plus its Helper), and
# the rear spine is Spine_04 / Spine_05 / tail.
SYNTH_CLIPS = (
    {
        "name": "Death_Paddle_L",
        "kind": "paddle",
        "from": "Death_L",
        "fromFrame": "last",
        "gait": "Run_F_IP",
        "legBones": ["thigh_b", "shin_b", "hoof_b", "hip_b", "thigh_f", "shin_f", "hoof_f", "hip_1_f", "hip_2_f"],
        "softBones": ["Spine_", "Neck", "head", "tail_"],
        "softScale": 0.25,  # the body shudders a quarter of what the legs do, not as much
        "amplitude": 0.55,  # how far toward a running leg a paddle ever reaches: half, not a sprint
        "hz": 1.6,  # paddles per second at the start, against the run clip's own cycle
        "decayPower": 2.0,  # squared, so the last second is nearly still: going quiet, not switched off
        "seconds": 4.0,
        "keyEvery": 2,
    },
    {
        "name": "Death_Paddle_R",
        "kind": "paddle",
        "from": "Death_R",
        "fromFrame": "last",
        "gait": "Run_F_IP",
        "legBones": ["thigh_b", "shin_b", "hoof_b", "hip_b", "thigh_f", "shin_f", "hoof_f", "hip_1_f", "hip_2_f"],
        "softBones": ["Spine_", "Neck", "head", "tail_"],
        "softScale": 0.25,
        "amplitude": 0.55,
        "hz": 1.6,
        "decayPower": 2.0,
        "seconds": 4.0,
        "keyEvery": 2,
    },
    {
        "name": "Cripple_Drag",
        "kind": "drag",
        "from": "Death_L",
        "fromFrame": "last",
        "gait": "Walk_F_IP",
        "legBones": ["thigh_b", "shin_b", "hoof_b", "hip_b"],
        "softBones": ["Spine_04", "Spine_05", "tail_"],
        "softScale": 0.35,
        "amplitude": 0.85,  # the hind legs are nearly collapsed; 1.0 would make them rigid corpses
        "keyEvery": 1,
    },
)


# THE DEFAULT RECIPE. Every value is either measured (see the note) or a stated taste pick.
DEFAULT_RECIPE = {
    "tool": TOOL_VERSION,
    # 2 x 3 x 5.5 studs is `Boar.CONFIG.BODY_SIZE`, and the LENGTH is what the model is fitted by:
    # fitting all three would squash the animal to the grey box's proportions, and a squashed boar
    # measures perfectly (the same rule `Assets` states for the gun). The real male boar in this
    # package is 1.9185 m long and 1.1362 m tall, so at 5.5 studs long it comes out 3.26 studs tall
    # against a 3-stud box -- a hand's breadth of shoulder above the physics envelope, which is
    # right for an animal and invisible to a ray (the box keeps every hit).
    "lengthStuds": 5.5,
    # 4096 is what the package ships and is four times what an animal seen at 20-100 studs needs.
    # Nothing is resized silently: the report prints every size before and after.
    "texturePx": 1024,
    # WHICH OF THE THREE ALBEDOS. 1 is the darkest, which is what a European wild boar looks like;
    # the variant is a flag because Karen's rule is that styling never blocks, and because the
    # female and the cub (not this task) will want their own.
    "albedo": 1,
    # An animal has no hard edges. Wide, so the only thing that stays sharp is a genuine crease.
    "smoothAngleDeg": 60,
    # TWO MEASURED CONSTANTS, and between them they cost this task two uploads on 2026-10-03.
    # Blender's FBX exporter writes CENTIMETRES, so `FBX_SCALE_NONE` multiplies the geometry by 100
    # as well as by `global_scale`; and Roblox's importer reads ONE RAW FBX UNIT AS ONE STUD and
    # ignores the FBX unit header entirely. `export_fbx` in tools/boar_prep_blender.py has both
    # asset ids and both arrival sizes. `--scale-correction` is the dial if Studio ever measures
    # something else again -- and since that export is now re-opened and measured before anything
    # leaves the folder, a wrong answer fails the run instead of an upload.
    "fbxUnitsPerMetre": 100.0,
    "robloxStudsPerFbxUnit": 1.0,
    "scaleCorrection": 1.0,
    # The lowest fraction of a hoof's own height range that counts as "planted on the ground".
    # 0.15 was read off this package's four hooves: all four agree to three decimals on every
    # locomotion clip at that threshold (0.995 m/s walking, 3.573 trotting, 6.003 running), which is
    # what a right threshold looks like -- four independent legs measuring the same ground.
    "contactFraction": 0.15,
    # Below this, a clip has NO GAIT and its ground speed is reported as exactly zero. See
    # `with_floor` in tools/boar_prep_blender.py for the five measurements it sits between.
    "minGroundMetresPerSecond": 0.25,
    # The root bone, so the run can PROVE the clips are in place instead of assuming it, and the
    # four hooves it measures the ground speed from.
    "rootBone": "root_bone",
    "hoofBones": ["hoof_b.L", "hoof_b.R", "hoof_f.L", "hoof_f.R"],
    "fps": 24,  # the package's own frame rate; the Blender side reports what it found
    "lengthAxis": None,  # None = measure it (the longest axis)
    "materialName": "Boar",
    "modelFile": "model.fbx",
    "clipDir": "clips",
    "measurementsFile": "measurements.json",
    # The clips this tool AUTHORS, above. Data, like everything else the Blender half is handed:
    # that file takes no decisions, so every name, source, bone group, rate and blend is here.
    "synth": list(SYNTH_CLIPS),
}

TEXTURE_ROLES = ("albedo", "normal", "roughness")
LEGAL_TEXTURE_PX = (256, 512, 1024, 2048, 4096)


class Refused(Exception):
    """Something is wrong with the request; nothing has been done."""


def say(message):
    print("[boar-prep] " + message, flush=True)


# ---------------------------------------------------------------- pure helpers


def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def tree_hashes(folder):
    """Every file under `folder`, relative path -> sha256. The before/after guard compares two of these."""
    out = {}
    for root, _directories, files in os.walk(folder):
        for name in sorted(files):
            full = os.path.join(root, name)
            out[os.path.relpath(full, folder).replace("\\", "/")] = sha256_of(full)
    return out


def find_blender():
    """Blender's path, or None. `BLENDER_EXE` wins, then the usual places, then PATH."""
    from_env = os.environ.get("BLENDER_EXE")
    if from_env:
        return from_env if os.path.isfile(from_env) else None
    for candidate in BLENDER_CANDIDATES:
        if os.path.isfile(candidate):
            return candidate
    return shutil.which("blender")


def inside_repo(path):
    """True when `path` is the repository or anything under it. Case-insensitive: this is Windows."""
    target = os.path.normcase(os.path.abspath(path))
    repo = os.path.normcase(os.path.abspath(REPO))
    return target == repo or target.startswith(repo + os.sep)


def texture_names(animal, albedo):
    """The package's own file names for one animal's three maps.

    The male's files are `Boar_Male_Albedo1.png`; the female's and the cub's are `BoarFemale_*` and
    `BoarCub_*`. One underscore of difference, so the mapping is data and not a format string.
    """
    stem = {"BoarMale": "Boar_Male", "BoarFemale": "BoarFemale", "BoarCub": "BoarCub"}.get(animal, animal)
    return {
        "albedo": "%s_Albedo%d.png" % (stem, albedo),
        "normal": "%s_Normal.png" % stem,
        "roughness": "%s_Roughness.png" % stem,
    }


def playback_rate(world_studs_per_second, clip_studs_per_second):
    """The rate a clip must play at for its feet to match `world_studs_per_second`.

    0 when the clip has no ground speed at all (an idle, a hit, a death): there is no rate that makes
    a still animal travel, and the caller's answer to that is a different clip, never a faster one.
    """
    if clip_studs_per_second <= 0:
        return 0.0
    return world_studs_per_second / clip_studs_per_second


def validate(args, recipe):
    """Every refusal, as a list, so one run says everything that is wrong (Refused on any)."""
    problems = []
    if recipe["lengthStuds"] <= 0:
        problems.append("--length-studs must be positive, not %r" % recipe["lengthStuds"])
    if recipe["texturePx"] not in LEGAL_TEXTURE_PX:
        problems.append(
            "--texture-px must be one of %s, not %r"
            % (", ".join(str(px) for px in LEGAL_TEXTURE_PX), recipe["texturePx"])
        )
    if recipe["albedo"] not in (1, 2, 3):
        problems.append("--albedo must be 1, 2 or 3, not %r" % recipe["albedo"])
    if recipe["scaleCorrection"] <= 0:
        problems.append("--scale-correction must be positive, not %r" % recipe["scaleCorrection"])
    if not recipe["clips"]:
        problems.append("--clips is empty: a model with no clip is the grey box with a texture")
    for clip in recipe["clips"]:
        if clip not in DEFAULT_CLIPS:
            problems.append(
                "clip %r is not one of the ten this game asks for (%s). Add it to DEFAULT_CLIPS with "
                "a reason first: an animation nothing can reach is an asset id nobody reviewed."
                % (clip, ", ".join(DEFAULT_CLIPS))
            )
    if args.out and inside_repo(args.out):
        problems.append("--out is inside the repository; everything this tool writes stays outside it")
    if args.out and os.path.isdir(args.out) and os.listdir(args.out):
        problems.append("--out already exists and is not empty; a second run wants a second folder")
    return problems


IMAGE_SUFFIXES = (".png", ".jpg", ".jpeg", ".tga", ".bmp", ".exr", ".tif", ".tiff")


def embedded_media(fbx_path):
    """Every image file name the FBX mentions, as basenames.

    WHAT THIS IS FOR: `tools/roblox_upload.py` refuses a prepared folder whose model carries a
    texture the run did not write -- "uploading it would ship the original model". That guard reads
    an `embeddedTextures` block out of the run's report, so a run that does not write one is a run
    the guard cannot protect. This is how the block is filled.

    An FBX -- binary or ASCII -- stores each embedded image's name as a plain byte string, so the
    names can be read without parsing the container: take every run of printable bytes that ends in
    an image suffix. A false POSITIVE here can only ever make the guard stricter, never looser.
    """
    with open(fbx_path, "rb") as handle:
        data = handle.read()
    found = set()
    token = bytearray()
    for byte in data:
        if 32 <= byte < 127:
            token.append(byte)
            continue
        if len(token) >= 5:
            text = token.decode("ascii")
            lowered = text.lower()
            for suffix in IMAGE_SUFFIXES:
                if lowered.endswith(suffix):
                    found.add(os.path.basename(text.replace("\\", "/")))
                    break
        token = bytearray()
    return sorted(found)


# ---------------------------------------------------------------- textures


def shrink_texture(source, destination, px, drop_alpha):
    """One map, resampled to px x px. Returns (before, after, mode-before, mode-after).

    The albedo's alpha is DROPPED rather than carried: this package's albedo has one, Roblox reads an
    alpha channel on a ColorMap as transparency, and a semi-transparent boar is not a boar. The
    package ships a `_NoAlpha` MESH for the same reason.
    """
    from PIL import Image

    with Image.open(source) as image:
        before, mode_before = image.size, image.mode
        if drop_alpha and image.mode in ("RGBA", "LA", "P"):
            image = image.convert("RGB")
        resized = image.resize((px, px), Image.LANCZOS)
        os.makedirs(os.path.dirname(destination), exist_ok=True)
        resized.save(destination, format="PNG", optimize=True)
        return before, resized.size, mode_before, resized.mode


# ---------------------------------------------------------------- the commands


def run_probe(args):
    """Read-only: what is in the input folder."""
    animal = args.animal
    mesh = os.path.join(args.inp, "%s_NoAlpha.fbx" % animal)
    clips = os.path.join(args.inp, "%s_anim_IP.fbx" % animal)
    for label, path in (("mesh", mesh), ("clips", clips)):
        if os.path.isfile(path):
            say("%-6s %s  %.1f MB  sha256 %s" % (label, os.path.basename(path), os.path.getsize(path) / 1e6, sha256_of(path)[:16]))
        else:
            say("%-6s MISSING: %s" % (label, os.path.basename(path)))
    if args.textures:
        for role, name in sorted(texture_names(animal, args.albedo).items()):
            path = os.path.join(args.textures, name)
            if os.path.isfile(path):
                say("%-9s %s  %.1f MB" % (role, name, os.path.getsize(path) / 1e6))
            else:
                say("%-9s MISSING: %s" % (role, name))
    say("the ten clips this game asks for: " + ", ".join(DEFAULT_CLIPS))
    return 0


def run_prep(args):
    recipe = dict(DEFAULT_RECIPE)
    recipe["lengthStuds"] = args.length_studs
    recipe["texturePx"] = args.texture_px
    recipe["albedo"] = args.albedo
    recipe["scaleCorrection"] = args.scale_correction
    recipe["animal"] = args.animal
    recipe["clips"] = [clip.strip() for clip in args.clips.split(",") if clip.strip()]

    blender = find_blender()
    problems = validate(args, recipe)
    if blender is None:
        problems.insert(
            0,
            "no Blender found. Set BLENDER_EXE, or install it in one of: "
            + ", ".join(BLENDER_CANDIDATES),
        )

    mesh_fbx = os.path.join(args.inp, "%s_NoAlpha.fbx" % args.animal)
    anim_fbx = os.path.join(args.inp, "%s_anim_IP.fbx" % args.animal)
    for label, path in (("the mesh", mesh_fbx), ("the clips", anim_fbx)):
        if not os.path.isfile(path):
            problems.append("%s is missing: %s" % (label, path))
    maps = texture_names(args.animal, args.albedo)
    for role, name in sorted(maps.items()):
        if not os.path.isfile(os.path.join(args.textures, name)):
            problems.append("the %s map is missing: %s" % (role, name))
    if problems:
        raise Refused("\n  - ".join(["this run was refused and nothing was done:"] + problems))

    if args.dry_run:
        say("DRY RUN. Blender: %s" % blender)
        say("mesh:  %s" % mesh_fbx)
        say("clips: %s" % anim_fbx)
        say("maps:  " + ", ".join("%s=%s" % (role, name) for role, name in sorted(maps.items())))
        say("recipe: " + json.dumps({key: value for key, value in sorted(recipe.items())}, default=str))
        return 0

    os.makedirs(args.out, exist_ok=True)
    source_dir = os.path.join(args.out, "source")
    os.makedirs(source_dir, exist_ok=True)

    # THE ORIGINALS ARE HASHED FIRST, and compared again at the end. Blender's FBX importer writes a
    # `.fbm` folder next to the file it reads, so it reads copies -- and this is what keeps that
    # claim true rather than hoped for.
    before = tree_hashes(args.inp)

    say("copying the inputs into %s" % os.path.relpath(source_dir, args.out))
    for path in (mesh_fbx, anim_fbx):
        shutil.copy2(path, os.path.join(source_dir, os.path.basename(path)))

    texture_report = {}
    for role, name in sorted(maps.items()):
        destination = os.path.join(args.out, "texture_%s.png" % role)
        was, now, mode_was, mode_now = shrink_texture(
            os.path.join(args.textures, name), destination, recipe["texturePx"], drop_alpha=(role == "albedo")
        )
        texture_report[role] = {
            "sourceFile": name,
            "sourceSha256": sha256_of(os.path.join(args.textures, name)),
            "fromPx": list(was),
            "toPx": list(now),
            "fromMode": mode_was,
            "toMode": mode_now,
            "file": os.path.basename(destination),
        }
        say("%-9s %dx%d %s -> %dx%d %s" % (role, was[0], was[1], mode_was, now[0], now[1], mode_now))

    recipe["out"] = os.path.abspath(args.out)
    recipe["meshFbx"] = os.path.join(source_dir, os.path.basename(mesh_fbx))
    recipe["animFbx"] = os.path.join(source_dir, os.path.basename(anim_fbx))
    recipe["maps"] = {
        role: os.path.join(os.path.abspath(args.out), "texture_%s.png" % role) for role in TEXTURE_ROLES
    }
    recipe["textures"] = texture_report
    recipe["inputs"] = {
        "mesh": {"file": os.path.basename(mesh_fbx), "sha256": sha256_of(mesh_fbx)},
        "clips": {"file": os.path.basename(anim_fbx), "sha256": sha256_of(anim_fbx)},
    }
    recipe["ranAt"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    recipe_path = os.path.join(args.out, "recipe.json")
    with open(recipe_path, "w", encoding="utf-8") as handle:
        json.dump(recipe, handle, indent=2, sort_keys=True)

    say("running Blender")
    completed = subprocess.run(
        [blender, "--background", "--factory-startup", "--python", BLENDER_SCRIPT, "--", recipe_path],
        capture_output=True,
        text=True,
    )
    for line in (completed.stdout or "").splitlines():
        if line.startswith("[boar-prep-blender]"):
            print(line, flush=True)
    measurements_path = os.path.join(args.out, recipe["measurementsFile"])
    if completed.returncode != 0 or not os.path.isfile(measurements_path):
        tail = "\n".join((completed.stdout or "").splitlines()[-25:])
        say("Blender failed (exit %d). Last lines:\n%s\n%s" % (completed.returncode, tail, completed.stderr or ""))
        return 1

    after = tree_hashes(args.inp)
    if after != before:
        changed = sorted(set(after) ^ set(before)) + sorted(
            name for name in set(after) & set(before) if after[name] != before[name]
        )
        say("THE ORIGINALS CHANGED, which must never happen: " + ", ".join(changed))
        return 1
    say("the originals are byte-for-byte what they were (%d files hashed)" % len(before))

    with open(measurements_path, "r", encoding="utf-8") as handle:
        measured = json.load(handle)

    # THE EMBEDDED-TEXTURE BLOCK the uploader's guard reads (see `embedded_media`). `written` is what
    # this run put beside the model; `matched` is what the model actually carries of it; `strangers`
    # is anything else, which would mean the original 4096 maps -- or another model's -- went in.
    written = sorted(entry["file"] for entry in texture_report.values())
    present = embedded_media(os.path.join(args.out, recipe["modelFile"]))
    matched = sorted(name for name in present if name in written)
    strangers = sorted(name for name in present if name not in written)
    say("embedded in the model: %d of %d written, %d stranger(s)" % (len(matched), len(written), len(strangers)))

    report = {
        "tool": TOOL_VERSION,
        "ok": not strangers and matched == written,
        "embeddedTextures": {
            "embedded": len(present),
            "written": written,
            "matched": matched,
            "strangers": strangers,
        },
        "ranAt": recipe["ranAt"],
        "animal": args.animal,
        "recipe": os.path.basename(recipe_path),
        "inputs": recipe["inputs"],
        "textures": texture_report,
        "measured": measured,
        "originalsUnchanged": True,
        # What the LAYER THAT PLAYS THESE CLIPS needs, worked out here so nobody does it by hand:
        # at each of the game's three speeds, the rate each locomotion clip must play at.
        "playbackRates": {
            clip: {
                "wander4": playback_rate(4, data["groundStudsPerSecond"]),
                "trot18": playback_rate(18, data["groundStudsPerSecond"]),
                "sprint38": playback_rate(38, data["groundStudsPerSecond"]),
            }
            for clip, data in sorted(measured.get("clips", {}).items())
            if data["groundStudsPerSecond"] > 0
        },
    }
    with open(os.path.join(args.out, "report.json"), "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)

    size = measured["expectedSizeStuds"]
    # NAMED BY AXIS, NEVER AS "w x h x l": Blender's up axis is Z and this package's length is Y, so
    # any fixed order here would be a lie about one of them. The length axis is the measured one.
    say(
        "EXPECTED IN STUDIO: X %.3f, Y %.3f, Z %.3f studs (Blender axes; the length is axis %d at"
        " %.3f). MEASURE IT: this tool cannot, the answer is Roblox's importer's."
        % (size[0], size[1], size[2], measured["lengthAxis"], size[measured["lengthAxis"]])
    )
    # COUNTED, NOT ASSUMED: the authored clips (SYNTH_CLIPS) are exported too, so `recipe["clips"]`
    # is not the number of files and saying it was is how a publishing step misses three of them.
    clip_dir = os.path.join(args.out, recipe["clipDir"])
    written = sorted(name for name in os.listdir(clip_dir) if name.endswith(".fbx"))
    say("model: %s   clips: %s/ (%d files)" % (recipe["modelFile"], recipe["clipDir"], len(written)))
    authored = [row["name"] + ".fbx" for row in recipe.get("synth", [])]
    if authored:
        say("AUTHORED BY THIS TOOL, and they need publishing like any other: " + ", ".join(authored))
    say("done: %s" % os.path.abspath(args.out))
    return 0


# ---------------------------------------------------------------- selftest


def run_selftest(_args):
    """Offline, no Blender, no model, no network. Every pure rule this tool rests on."""
    failures = []

    def check(name, got, want):
        if got != want:
            failures.append("%s: got %r, want %r" % (name, got, want))

    def check_close(name, got, want, tolerance=1e-9):
        if abs(got - want) > tolerance:
            failures.append("%s: got %r, want %r (+-%r)" % (name, got, want, tolerance))

    # 1. The clip list is exactly the ten the drive asks for, with no duplicate.
    check("ten clips", len(DEFAULT_CLIPS), 10)
    check("no duplicate clip", len(set(DEFAULT_CLIPS)), 10)

    # 2. The texture names, per animal. One underscore of difference between the male and the rest.
    check("male albedo 1", texture_names("BoarMale", 1)["albedo"], "Boar_Male_Albedo1.png")
    check("male albedo 3", texture_names("BoarMale", 3)["albedo"], "Boar_Male_Albedo3.png")
    check("male normal", texture_names("BoarMale", 1)["normal"], "Boar_Male_Normal.png")
    check("female albedo 2", texture_names("BoarFemale", 2)["albedo"], "BoarFemale_Albedo2.png")
    check("cub roughness", texture_names("BoarCub", 1)["roughness"], "BoarCub_Roughness.png")

    # 3. THE PLAYBACK RATE, which is the one number a sliding foot would come from. The clip speeds
    #    are this package's own measurements (2026-10-03, at 5.5 studs long: walk 2.852, trot 10.243,
    #    run 17.207 studs/s), so these cases are the real arithmetic and not an invented one.
    check_close("walk at wander", playback_rate(4, 2.852), 1.40252454, 1e-6)
    check_close("trot at TROT_SPEED", playback_rate(18, 10.243), 1.75729767, 1e-6)
    check_close("run at SPRINT_SPEED", playback_rate(38, 17.207), 2.20840356, 1e-6)
    check_close("a still clip has no rate", playback_rate(18, 0.0), 0.0)
    check_close("a still clip at a standstill too", playback_rate(0, 0.0), 0.0)
    check_close("rate 1 when the clip already matches", playback_rate(10.243, 10.243), 1.0)

    # 4. The repository boundary: nothing this tool writes may land inside it.
    check("the repo itself is inside it", inside_repo(REPO), True)
    check("a folder under src/", inside_repo(os.path.join(REPO, "src", "server")), True)
    check("a sibling of the repo", inside_repo(os.path.join(os.path.dirname(REPO), "driven-hunt-assets")), False)
    # A path whose NAME merely starts with the repo's is not inside it (the separator matters).
    check("a sibling with the same prefix", inside_repo(REPO + "-assets"), False)

    # 5. Every refusal, driven through `validate` with a fake argument object.
    class Args(object):
        out = os.path.join(os.path.dirname(REPO), "boar-prep-selftest-never-created")

    def problems_for(**overrides):
        recipe = dict(DEFAULT_RECIPE)
        recipe["clips"] = list(DEFAULT_CLIPS)
        recipe.update(overrides)
        return validate(Args(), recipe)

    check("a good recipe is accepted", problems_for(), [])
    check("a zero length is refused", len(problems_for(lengthStuds=0)), 1)
    check("a negative length is refused", len(problems_for(lengthStuds=-5.5)), 1)
    check("777 px is refused", len(problems_for(texturePx=777)), 1)
    check("1024 px is accepted", problems_for(texturePx=1024), [])
    check("albedo 4 is refused", len(problems_for(albedo=4)), 1)
    check("albedo 0 is refused", len(problems_for(albedo=0)), 1)
    check("a zero scale correction is refused", len(problems_for(scaleCorrection=0)), 1)
    check("no clips is refused", len(problems_for(clips=[])), 1)
    check("an unknown clip is refused", len(problems_for(clips=["Swim_F_IP"])), 1)
    check("one real clip is accepted", problems_for(clips=["Walk_F_IP"]), [])
    # Several faults at once are reported together, not one per run.
    check("three faults, three lines", len(problems_for(albedo=9, texturePx=7, lengthStuds=0)), 3)

    class RepoArgs(object):
        out = os.path.join(REPO, "assets", "boar")

    inside = validate(RepoArgs(), dict(DEFAULT_RECIPE, clips=list(DEFAULT_CLIPS)))
    check("an output inside the repo is refused", len(inside), 1)

    # 6. The recipe carries what the Blender side reads, and nothing it does not.
    needed = (
        "lengthStuds",
        "texturePx",
        "albedo",
        "smoothAngleDeg",
        "fbxUnitsPerMetre",
        "robloxStudsPerFbxUnit",
        "scaleCorrection",
        "contactFraction",
        "minGroundMetresPerSecond",
        "rootBone",
        "hoofBones",
        "fps",
        "materialName",
        "modelFile",
        "clipDir",
        "measurementsFile",
    )
    missing = [key for key in needed if key not in DEFAULT_RECIPE]
    check("the default recipe is complete", missing, [])
    check("four hooves are measured", len(DEFAULT_RECIPE["hoofBones"]), 4)
    check("the length is the grey box's", DEFAULT_RECIPE["lengthStuds"], 5.5)

    # 7. The Blender side exists and declares its licence, which is the condition for shipping it.
    with open(BLENDER_SCRIPT, "r", encoding="utf-8") as handle:
        head = handle.read(2000)
    check("the Blender script is GPL", "SPDX-License-Identifier: GPL-2.0-or-later" in head, True)
    # The split this file's header claims: Blender's own API is never imported HERE, so this file
    # carries the repository's terms and the GPL one carries Blender's. A substring would match the
    # sentence that says so, so the check is for a real import STATEMENT at the start of a line.
    own_source = open(__file__, encoding="utf-8").read()
    imports_bpy = any(
        line.strip().startswith(("import bpy", "from bpy")) for line in own_source.splitlines()
    )
    check("this file never imports bpy", imports_bpy, False)

    for failure in failures:
        print("FAIL " + failure)
    total = 7
    if failures:
        print("[boar-prep] selftest FAIL: %d problem(s) over %d groups" % (len(failures), total))
        return 1
    print("[boar-prep] selftest PASS: %d groups" % total)
    return 0


# ---------------------------------------------------------------- argv


def main(argv=None):
    parser = argparse.ArgumentParser(prog="boar_prep.py", description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)

    def common(target):
        target.add_argument("--animal", default="BoarMale", help="BoarMale (default), BoarFemale or BoarCub")
        target.add_argument("--albedo", type=int, default=DEFAULT_RECIPE["albedo"], help="1, 2 or 3")

    probe = sub.add_parser("probe", help="read-only: what is in the input folder")
    probe.add_argument("--in", dest="inp", required=True)
    probe.add_argument("--textures", default=None)
    common(probe)

    prep = sub.add_parser("prep", help="the run")
    prep.add_argument("--in", dest="inp", required=True)
    prep.add_argument("--textures", required=True)
    prep.add_argument("--out", required=True)
    common(prep)
    prep.add_argument("--length-studs", type=float, default=DEFAULT_RECIPE["lengthStuds"])
    prep.add_argument("--texture-px", type=int, default=DEFAULT_RECIPE["texturePx"])
    prep.add_argument("--clips", default=",".join(DEFAULT_CLIPS))
    prep.add_argument("--scale-correction", type=float, default=DEFAULT_RECIPE["scaleCorrection"])
    prep.add_argument("--dry-run", action="store_true")

    sub.add_parser("selftest", help="offline: no Blender, no model, no network")

    args = parser.parse_args(argv)
    handler = {"probe": run_probe, "prep": run_prep, "selftest": run_selftest}[args.command]
    try:
        return handler(args)
    except Refused as refused:
        say(str(refused))
        return 2


if __name__ == "__main__":
    sys.exit(main())
