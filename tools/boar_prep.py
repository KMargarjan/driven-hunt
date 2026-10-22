"""Driven Hunt animal prep: turn a bought, rigged animal package into one model this game can wear.

TWO SPECIES SINCE TASK 223, AND THE SECOND ONE IS WHY `SPECIES` EXISTS. Karen bought a red deer
family on 2026-10-20 -- stag, hind and calf -- and it arrives in exactly this package's shape
(`<animal>_NoAlpha.fbx` + `<animal>_anim_IP.fbx`, `<Stem>_Albedo1..4/Normal/Roughness`) with
exactly this tool's problems. So the species is DATA in one table (`SPECIES` below) rather than a
second copy of this program: the animal names, the texture stems, the clip list, the authored clips
and the material name. `docs/design/red-deer.md` section 9 is the decision and its three
requirements, the third of which is that **the boar's values are the same objects they always
were** -- `DEFAULT_CLIPS` and `SYNTH_CLIPS` go into the `boar` row BY IDENTITY, and `selftest`
asserts that by `is`, so this change cannot have moved a character of the boar's recipe.

The file keeps the name `boar_prep.py` this task. `tools/animal_prep.py` is the right name and it
goes with the `src/server/Boar` -> `src/server/Animal` rename, which is a LATER task
(`docs/design/red-deer.md` section 11.1).

It drives **headless Blender** (`--background --python`) with `tools/boar_prep_blender.py` and does
the four things a bought animal needs before an animal in this game can be it:

  (a) KEEP THE CLIPS THE GAME ASKS FOR, out of the package's 74 (77 for the deer, 80 for the calf),
      renamed to their short names (the package calls `Walk_F_IP` "Arm_Boar.001|Arm_Boar|Walk_F_IP").
      `SPECIES[<name>]["clips"]` is that list -- the boar's drive ten since task 115 plus the calm
      repertoire's six since task 117, and the deer's eleven since task 223 -- and `selftest`
      names every one of them, so a dropped or misspelt clip fails offline in a second;
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
  python tools/boar_prep.py species                   # print the table: who knows which animal
  python tools/boar_prep.py selftest        # offline: no Blender, no model, no network

`--animal` IS WHAT SAYS WHICH SPECIES, and there is deliberately no `--species` flag: two flags that
can disagree about one animal is the "two correct pieces of code disagreeing" failure
docs/PROJECT_CONTEXT.md names. Every animal name belongs to exactly one row of `SPECIES`, so
`--animal Red_Deer` is a deer run and `--animal BoarMale` is a boar run, and an animal in no row is
refused by name with the known ones listed (refusal 6).

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
  5. A clip the package does not have FOR THAT SPECIES, an albedo variant it does not ship, a
     non-positive length or a texture size that is not a power of two between 256 and 4096. The
     refusal NAMES THE SPECIES, because "clip 'Hit_F' is not one of the 11 this game asks for" is
     unreadable without it: `Hit_F` is a real boar clip and a real deer typo.
  6. An `--animal` that belongs to no `SPECIES` row, with the known animals listed. This is
     stricter than the fallback it replaced (an unknown name used to take the boar's clips and its
     own name as the texture stem, and then fail at the missing mesh): a typo'd deer name must not
     become a boar run.

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
    # TASK 117, THE CALM BOAR. Karen, 2026-10-03: "boar also can move alon and walk and lift head
    # like smell ect". Which clip does what was MEASURED off the head and nose bones in Blender,
    # over the whole package (`docs/` has no note for this task; the numbers are in the config):
    #   Idle_5          the ONLY clip whose nose rises ABOVE horizontal: -18.9 to +11.5 deg, a
    #                   30.4 deg lift, head +0.112 m, and the hooves never move (travel 0.000 m).
    #                   That is the head-up smell. Idle_4 is its opposite (nose to -72 deg, head
    #                   DOWN 0.279 m), and Idle_2/3/6 are ground-level fidgets of 9-15 deg.
    #   Eat_loop_1/2    head at 0.45-0.55 m and the nose at -70 to -40 deg: grazing. _1 is steady,
    #                   _2 pulls and chews (head moves 0.098 m against _1's 0.001).
    #   EatDrink_start  the transition, 1.08 s, head 0.505 <-> 0.788 m -- standing height to
    #   EatDrink_end    grazing height and back, so the head does not teleport into the grass.
    #   Dig_walk_IP     head low (nose -72 to -59 deg) AND hooves travelling: 1.901 studs/s against
    #                   the walk's 2.852, i.e. two thirds of a walk. (In BLENDER metres, which are
    #                   the model's own and not this project's 1 stud = 0.28 m, that is 0.663 against
    #                   0.995 -- the same ratio.) Rooting along the ground, Karen's "move alon".
    "Idle_5",
    "Eat_loop_1",
    "Eat_loop_2",
    "EatDrink_start",
    "EatDrink_end",
    "Dig_walk_IP",
)

# THE TWELVE CLIPS THE RED DEER ASKS FOR (task 223, and the leap in task 245), and the whole list
# of reasons -- which is
# `docs/design/red-deer.md` section 6.2, table by table. The names are NOT the boar's: this package
# has `Hit_Front`/`Hit_Back`/`Hit_Middle` where the boar has `Hit_F`/`Hit_B`, ONE `Eat_loop` where
# the boar has two, and `Eat_walk_IP`/`EatDig_loop` where the boar has `Dig_walk_IP`. Measured with
# headless Blender on 2026-10-20 over all three deer FBX (reviews/task-223/BRIEF.md section 2).
#
#   Idle_1          standing still is standing still, and it is what every missing clip falls back to
#   Walk_F_IP       WANDER_SPEED, and the band MODEL.WALK_FROM..TROT_FROM
#   Trot_F_IP       TROT_SPEED -- being pushed, which is most of a drive
#   Run_F_IP        SPRINT_SPEED x runScale -- bolting
#   Turn_L_IP       a pivot below WALK_FROM, so a turning deer does not skate
#   Turn_R_IP       the other way
#   Death_L/R       DOWN: it falls on the side Body.collapse rolls it onto
#   Hit_Front/Back  the flinch on the tick a pellet lands, chosen off `handle.hitFromBehind`
#   Idle_5          MODEL.ALERT_CLIP -- head up. The single most characteristic thing a deer does,
#                   and the one the ALERT state already asks for by name, which is why it is the one
#                   piece of the calm repertoire that is in v1 (design section 6.3).
#   Jump_Run_IP     THE LEAP OVER THE ROAD (task 245). Karen, 2026-10-22: *"they usually jump when
#                   is cross road so can we do that"*. A running bound, in place like every other
#                   clip here, so the body keeps crossing at its own speed while the mesh leaves the
#                   ground -- see `Body.clipFor`'s leap branch.
#
# `Jump_Run_IP` IS IN ALL THREE FILES AND `Run_Jump_F_IP` IS IN ONE. MEASURED 2026-10-22 by reading
# the `AnimStack` names out of the three `*_anim_IP.fbx` directly: the stag and the Doe ship 77 clips
# each and the Calf 80, and the Calf's three extras are exactly `Run_Jump_F_IP`, `Run_Jump_L_IP` and
# `Run_Jump_R_IP`. So the dispatch's second name would have been a stag run that refused; the one
# name that serves all three kinds is `Jump_Run_IP`, and that is what is taken.
#
# EVERY ONE OF THESE IS A HAND PUBLISH IN STUDIO'S ANIMATION EDITOR -- twelve of Karen's clicks --
# which is the whole reason the grazing four (`Eat_loop`, `EatDrink_start`, `EatDrink_end`,
# `Eat_walk_IP`) and `Hit_Middle` are out of v1 rather than "free to add".
DEER_CLIPS = (
    "Idle_1",
    "Walk_F_IP",
    "Trot_F_IP",
    "Run_F_IP",
    "Turn_L_IP",
    "Turn_R_IP",
    "Death_L",
    "Death_R",
    "Hit_Front",
    "Hit_Back",
    "Idle_5",
    "Jump_Run_IP",
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


# WHICH ANIMALS THIS TOOL KNOWS, AND WHAT EACH SPECIES BRINGS WITH IT (task 223,
# `docs/design/red-deer.md` section 9). One row per species, and the row is DATA: the animal names
# the package ships, the texture stem each one's maps are named with, the clip list, the authored
# clips and the material name.
#
# THE BOAR'S VALUES ARE THE SAME OBJECTS THEY ALWAYS WERE, by identity and not by retyping --
# `DEFAULT_CLIPS` and `SYNTH_CLIPS` go in as the tuples themselves. `selftest` asserts that with
# `is`, so this generalisation provably did not move one character of the recipe that produced the
# boar in Karen's game. A retyped copy would measure correct on the day and drift on the next edit.
#
# `root` AND `hooves` ARE NOT HERE, and that is a measurement rather than an oversight: `Arm_Deer`
# (42 bones) carries `root_bone` and `hoof_b.L/R` + `hoof_f.L/R` under exactly the names `Arm_Boar`
# (46 bones) does, so the ground-speed measurement needs nothing per species. The ONE bone-name
# difference the brief measured is the neck -- `Neck` on the boar, `neck_01`/`neck_02` on the deer --
# and it is recorded in `bones` for the later task that authors the deer's death-paddle clips, which
# are the only thing that reads a neck. Nothing in v1 reads `bones`; it is a note in the one place a
# note cannot get lost, and `selftest` asserts it so it cannot quietly become wrong either.
SPECIES = {
    "boar": {
        "animals": ("BoarMale", "BoarFemale", "BoarCub"),
        # The male's files are `Boar_Male_Albedo1.png`; the female's and the cub's are `BoarFemale_*`
        # and `BoarCub_*`. One underscore of difference, so the mapping is data and not a format
        # string -- which is the sentence `texture_names` has carried since task 119.
        "textures": {"BoarMale": "Boar_Male", "BoarFemale": "BoarFemale", "BoarCub": "BoarCub"},
        "clips": DEFAULT_CLIPS,  # BY IDENTITY
        "synth": SYNTH_CLIPS,  # BY IDENTITY
        "albedos": (1, 2, 3),  # the package ships three colour variants of the same boar
        "material": "Boar",
        "armature": "Arm_Boar",
        "bones": {"neck": ("Neck",)},
        # None = MEASURE IT (the longest axis), which is right for a boar: this package's male is
        # 1.9185 m long against 1.1362 m tall, so the longest axis IS the length and always was.
        "lengthAxis": None,
    },
    "reddeer": {
        # Karen's "Red Deer Family" (RedDeer, Fab, bought 2026-10-20). The package's own file stems,
        # and they are not spelt the same way twice: the stag's mesh is `Red_Deer_NoAlpha.fbx` while
        # his textures are `Red_Deer_*`, the hind's mesh is `RedDeer_Doe_*` while her textures are
        # `RedDeerDoe_*`. Exactly the boar's situation, which is why this is a table.
        "animals": ("Red_Deer", "RedDeer_Doe", "RedDeer_Calf"),
        "textures": {"Red_Deer": "Red_Deer", "RedDeer_Doe": "RedDeerDoe", "RedDeer_Calf": "RedDeerCalf"},
        "clips": DEER_CLIPS,
        # NO AUTHORED CLIPS IN V1 (design section 6.6). `Body.clipFor` then returns the fall and
        # holds it and a crippled deer plays its gait -- the pre-task-116 behaviour, which is tested.
        "synth": (),
        "albedos": (1, 2, 3, 4),  # this package ships FOUR, where the boar's ships three
        "material": "Deer",
        "armature": "Arm_Deer",
        "bones": {"neck": ("neck_01", "neck_02")},
        # 1 (Blender's Y), PINNED, AND IT IS THE TRAP `docs/design/red-deer.md` SECTION 7.1 NAMED --
        # *"the one number that would silently make a stag 7.9 studs tall"*. **This was measured
        # going wrong before it was fixed:** the first stag run on 2026-10-20 took the default
        # "longest axis" and came back *"2.2187 m long on axis 2"*, which is the ANTLER HEIGHT, so
        # it baked antler-tip-to-hoof at 7.05 studs and left the body 6.275. An animal that carries
        # headgear breaks the "longest axis is the length" rule, and the calf breaks it a second way:
        # its Y is 0.9757 against a Z of 0.9731, so which axis wins is a coin flip of 2.6 mm. One
        # pinned axis also keeps THE THREE IN PROPORTION TO EACH OTHER, which "whichever is longest"
        # cannot promise.
        "lengthAxis": 1,
    },
}


def species_of(animal):
    """Which species that animal is, or None when no row claims it.

    `--animal` is the only flag that says which species a run is (see the usage block): two flags
    that can disagree about one animal is a bug waiting for a typo.
    """
    for name, row in SPECIES.items():
        if animal in row["animals"]:
            return name
    return None


def known_animals():
    """Every animal this tool knows, as `species/animal`, for a refusal message."""
    return [
        "%s/%s" % (species, animal)
        for species in sorted(SPECIES)
        for animal in SPECIES[species]["animals"]
    ]


# THE DEFAULT RECIPE. Every value is either measured (see the note) or a stated taste pick.
DEFAULT_RECIPE = {
    "tool": TOOL_VERSION,
    # WHICH ANIMAL, AND THEREFORE WHICH SPECIES (task 223). `run_prep` overwrites both off
    # `--animal`; they are here with the boar male's values so that the recipe is complete on its
    # own and `selftest`'s `validate` cases read like a real run rather than a half-filled one.
    "animal": "BoarMale",
    "species": "boar",
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

    The stems live in `SPECIES[<species>]["textures"]` since task 223, because two packages name
    them two ways and neither is derivable from the animal: the boar male's files are
    `Boar_Male_Albedo1.png` against his `BoarMale`, and the deer hind's are `RedDeerDoe_Albedo1.png`
    against her `RedDeer_Doe`. The mapping is data and not a format string.

    AN UNKNOWN ANIMAL FALLS BACK TO ITS OWN NAME, which is what this function did before the table
    existed. It is unreachable from the two commands -- both refuse an unknown animal by name
    (refusal 6) -- and it is kept so that this helper alone is never the thing that raises.
    """
    species = species_of(animal)
    stems = SPECIES[species]["textures"] if species else {}
    stem = stems.get(animal, animal)
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
    """Every refusal, as a list, so one run says everything that is wrong (Refused on any).

    `recipe["species"]` decides the clip list and the legal albedo variants; an animal in no
    `SPECIES` row is refused here by name, which is refusal 6 and is the first thing checked,
    because every later message would otherwise be written about the wrong animal.
    """
    problems = []
    species = recipe.get("species")
    if species is None:
        problems.append(
            "--animal %r is not an animal this tool knows. The known ones are: %s. Add it to "
            "SPECIES with its texture stems and its clip list first."
            % (recipe.get("animal"), ", ".join(known_animals()))
        )
    row = SPECIES.get(species) or {}
    clips = row.get("clips", ())
    albedos = row.get("albedos", (1, 2, 3))
    if recipe["lengthStuds"] <= 0:
        problems.append("--length-studs must be positive, not %r" % recipe["lengthStuds"])
    if recipe["texturePx"] not in LEGAL_TEXTURE_PX:
        problems.append(
            "--texture-px must be one of %s, not %r"
            % (", ".join(str(px) for px in LEGAL_TEXTURE_PX), recipe["texturePx"])
        )
    if species is not None and recipe["albedo"] not in albedos:
        problems.append(
            "--albedo must be one of %s for %s, not %r"
            % (", ".join(str(one) for one in albedos), species, recipe["albedo"])
        )
    if recipe["scaleCorrection"] <= 0:
        problems.append("--scale-correction must be positive, not %r" % recipe["scaleCorrection"])
    if not recipe["clips"]:
        problems.append("--clips is empty: a model with no clip is the grey box with a texture")
    for clip in recipe["clips"]:
        if species is not None and clip not in clips:
            # THE SPECIES IS NAMED, because `Hit_F` is a real boar clip and a real deer typo, and a
            # message that does not say which animal it is talking about cannot tell you which.
            problems.append(
                "clip %r is not one of the %d this game asks for a %s (%s). Add it to that "
                "species' clip list with a reason first: an animation nothing can reach is an asset "
                "id nobody reviewed." % (clip, len(clips), species, ", ".join(clips))
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
    species = species_of(animal)
    if species is None:
        raise Refused(
            "--animal %r is not an animal this tool knows. The known ones are: %s"
            % (animal, ", ".join(known_animals()))
        )
    say("%s is a %s (armature %s)" % (animal, species, SPECIES[species]["armature"]))
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
    clips = SPECIES[species]["clips"]
    say("the %d clips this game asks for a %s: %s" % (len(clips), species, ", ".join(clips)))
    return 0


def run_prep(args):
    recipe = dict(DEFAULT_RECIPE)
    recipe["lengthStuds"] = args.length_studs
    recipe["texturePx"] = args.texture_px
    recipe["albedo"] = args.albedo
    recipe["scaleCorrection"] = args.scale_correction
    recipe["animal"] = args.animal
    # THE SPECIES COMES OFF THE ANIMAL and nothing else (task 223), and everything the species owns
    # is read here, once, at this one boundary: the clip list, the authored clips and the material
    # name. `None` for an unknown animal, which `validate` refuses by name before anything is done.
    recipe["species"] = species_of(args.animal)
    row = SPECIES.get(recipe["species"]) or {}
    if row:
        recipe["synth"] = list(row["synth"])
        recipe["materialName"] = row["material"]
        recipe["lengthAxis"] = row["lengthAxis"]
    # `--clips` DEFAULTS TO THIS SPECIES' OWN LIST, which is why its argparse default is None: a
    # default computed at parse time could only ever be one species', and it would silently hand a
    # deer run the boar's sixteen names.
    wanted = args.clips if args.clips is not None else ",".join(row.get("clips", ()))
    recipe["clips"] = [clip.strip() for clip in wanted.split(",") if clip.strip()]

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


def run_species(_args):
    """Read-only: the table. Which animals this tool knows, and what each species brings."""
    for name in sorted(SPECIES):
        row = SPECIES[name]
        say("%s  armature %s  material %s  albedos %s" % (
            name, row["armature"], row["material"], ",".join(str(one) for one in row["albedos"])
        ))
        for animal in row["animals"]:
            maps = texture_names(animal, row["albedos"][0])
            say("    %-14s textures %s" % (animal, maps["albedo"]))
        say("    %d clips: %s" % (len(row["clips"]), ", ".join(row["clips"])))
        say("    %d authored clips: %s" % (
            len(row["synth"]), ", ".join(clip["name"] for clip in row["synth"]) or "none"
        ))
    return 0


def run_selftest(_args):
    """Offline, no Blender, no model, no network. Every pure rule this tool rests on."""
    failures = []

    def check(name, got, want):
        if got != want:
            failures.append("%s: got %r, want %r" % (name, got, want))

    def check_close(name, got, want, tolerance=1e-9):
        if abs(got - want) > tolerance:
            failures.append("%s: got %r, want %r (+-%r)" % (name, got, want, tolerance))

    # 1. THE CLIP LIST IS THE CLIPS, BY NAME. This was a bare count -- `len(DEFAULT_CLIPS) == 10` --
    #    and a count is the one thing about a list that does not say which list it is: task 117 added
    #    six calm clips and the count went to sixteen, so CI went red while saying "ten clips" and
    #    nothing anywhere said WHICH clip had gone (review round 3, the finding this round fixes).
    #    Named, a clip that is dropped or misspelt fails here -- offline, in a second -- instead of
    #    twenty minutes into a Blender run or, worse, in a silent config whose row has no id.
    #    An ADDITION fails too, deliberately: this list is the declaration that the change was meant.
    wanted = (
        # The drive's own ten (task 115): stand, the three gaits, the two turns, the two deaths and
        # the two flinches.
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
        # The calm repertoire (task 117): the head-up smell, the two grazing loops, the two
        # transitions into and out of the grass, and rooting along the ground.
        "Idle_5",
        "Eat_loop_1",
        "Eat_loop_2",
        "EatDrink_start",
        "EatDrink_end",
        "Dig_walk_IP",
    )
    check("every clip this game asks for is in the tuple", sorted(set(wanted) - set(DEFAULT_CLIPS)), [])
    check("and nothing else is", sorted(set(DEFAULT_CLIPS) - set(wanted)), [])
    check("no duplicate clip", len(set(DEFAULT_CLIPS)), len(DEFAULT_CLIPS))

    # 1b. THE DEER'S ELEVEN, BY NAME, for exactly the same reason (task 223). A deer clip that is
    #     dropped, misspelt or quietly added fails here, offline, instead of becoming a key with no
    #     row -- or worse, one of Karen's eleven clicks spent on a clip nothing plays.
    deer_wanted = (
        # The drive's: stand, the three gaits, the two turns, the two deaths, the two flinches.
        "Idle_1",
        "Walk_F_IP",
        "Trot_F_IP",
        "Run_F_IP",
        "Turn_L_IP",
        "Turn_R_IP",
        "Death_L",
        "Death_R",
        "Hit_Front",
        "Hit_Back",
        # The one piece of the calm repertoire that is in v1: MODEL.ALERT_CLIP, the head-up look.
        "Idle_5",
        # The leap over the road (task 245), the only clip here that is neither a gait nor a
        # reaction: it is asked for by WHERE the animal is, not by what it is doing.
        "Jump_Run_IP",
    )
    check("every deer clip asked for is in the tuple", sorted(set(deer_wanted) - set(DEER_CLIPS)), [])
    check("and nothing else is", sorted(set(DEER_CLIPS) - set(deer_wanted)), [])
    check("no duplicate deer clip", len(set(DEER_CLIPS)), len(DEER_CLIPS))
    check("twelve deer clips, twelve clicks", len(DEER_CLIPS), 12)
    # THE LEAP'S NAME IS THE ONE ALL THREE PACKAGES SHARE (task 245). `Run_Jump_F_IP` exists only in
    # the Calf's file -- measured, see the tuple's comment -- so asking for it would refuse a stag
    # run, and the two names must never be swapped by a reader who met the other one first.
    check("the leap is Jump_Run_IP", "Jump_Run_IP" in DEER_CLIPS, True)
    check("and not Run_Jump_F_IP", "Run_Jump_F_IP" in DEER_CLIPS, False)
    check("the boar does not leap", "Jump_Run_IP" in DEFAULT_CLIPS, False)

    # 1c. THE DIFFERENCE BETWEEN THE TWO LISTS, by name. Nine clip names are in BOTH packages under
    #     the same spelling (the three gaits, the two turns, the two deaths, `Idle_1`, `Idle_5`), so
    #     "the two lists do not overlap" would be FALSE and is not the rule. The rule is that each
    #     species asks for its own package's spelling, and these four cases are where the two
    #     packages genuinely disagree (reviews/task-223/BRIEF.md section 2, fact 3).
    # BY IDENTITY, which is design section 9's first hard requirement: the boar's row holds the same
    # tuple OBJECTS, not retyped copies, so this generalisation cannot have moved one character of
    # the recipe that made the boar in Karen's game.
    check("the boar's clips are the same object", SPECIES["boar"]["clips"] is DEFAULT_CLIPS, True)
    check("the boar's synth clips are too", SPECIES["boar"]["synth"] is SYNTH_CLIPS, True)
    check("the deer authors no clip in v1", SPECIES["reddeer"]["synth"], ())
    # Three clip names the boar has and the deer does not, and one the deer has and the boar does
    # not -- the measured difference (reviews/task-223/BRIEF.md section 2, fact 3). Asserted so that
    # "the deer has Hit_F" can never become true by a copy-paste.
    check("the deer has no Hit_F", "Hit_F" in DEER_CLIPS, False)
    check("the deer has no Eat_loop_1", "Eat_loop_1" in DEER_CLIPS, False)
    check("the deer has no Dig_walk_IP", "Dig_walk_IP" in DEER_CLIPS, False)
    check("the boar has no Hit_Front", "Hit_Front" in DEFAULT_CLIPS, False)

    # 1d. WHICH SPECIES AN ANIMAL IS, which is the only thing `--animal` decides.
    check("the male is a boar", species_of("BoarMale"), "boar")
    check("the cub is a boar", species_of("BoarCub"), "boar")
    check("the stag is a deer", species_of("Red_Deer"), "reddeer")
    check("the hind is a deer", species_of("RedDeer_Doe"), "reddeer")
    check("the calf is a deer", species_of("RedDeer_Calf"), "reddeer")
    check("an unknown animal is nobody's", species_of("RedDeer_Stag"), None)
    check("no animal is in two species", len(known_animals()), len(set(known_animals())))
    # The ONE bone-name difference the brief measured, recorded where the later task that authors
    # the deer's death-paddle clips will read it (design section 6.6).
    check("the boar's neck", SPECIES["boar"]["bones"]["neck"], ("Neck",))
    check("the deer's neck is two bones", SPECIES["reddeer"]["bones"]["neck"], ("neck_01", "neck_02"))
    check("the deer's armature", SPECIES["reddeer"]["armature"], "Arm_Deer")
    # THE LENGTH AXIS, which is the one thing this table fixes that a measurement got wrong: the
    # boar measures its own (the longest axis IS its length) and the deer pins Y, because the stag's
    # longest axis is his ANTLERS. Asserted both ways so neither can be "tidied" into the other.
    check("the boar measures its own length axis", SPECIES["boar"]["lengthAxis"], None)
    check("the deer pins Y as its length", SPECIES["reddeer"]["lengthAxis"], 1)

    # 2. The texture names, per animal. One underscore of difference between the male and the rest.
    check("male albedo 1", texture_names("BoarMale", 1)["albedo"], "Boar_Male_Albedo1.png")
    check("male albedo 3", texture_names("BoarMale", 3)["albedo"], "Boar_Male_Albedo3.png")
    check("male normal", texture_names("BoarMale", 1)["normal"], "Boar_Male_Normal.png")
    check("female albedo 2", texture_names("BoarFemale", 2)["albedo"], "BoarFemale_Albedo2.png")
    check("cub roughness", texture_names("BoarCub", 1)["roughness"], "BoarCub_Roughness.png")
    # 2b. The deer's three stems, by name, which is design section 9's third requirement. The stag's
    #     mesh is `Red_Deer_*` and so are his textures; the hind's mesh is `RedDeer_Doe_*` and her
    #     textures are `RedDeerDoe_*` -- no underscore. Measured off the package on 2026-10-20.
    check("stag albedo 1", texture_names("Red_Deer", 1)["albedo"], "Red_Deer_Albedo1.png")
    check("stag normal", texture_names("Red_Deer", 1)["normal"], "Red_Deer_Normal.png")
    check("hind albedo 1", texture_names("RedDeer_Doe", 1)["albedo"], "RedDeerDoe_Albedo1.png")
    check("hind roughness", texture_names("RedDeer_Doe", 1)["roughness"], "RedDeerDoe_Roughness.png")
    check("calf albedo 4", texture_names("RedDeer_Calf", 4)["albedo"], "RedDeerCalf_Albedo4.png")
    check("calf normal", texture_names("RedDeer_Calf", 1)["normal"], "RedDeerCalf_Normal.png")

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

    # 5b. THE SPECIES GATE (task 223), which is the half of `validate` the deer added. Each case
    #     enters an arm that did not exist: an unknown animal, a clip that is the OTHER species'
    #     spelling in both directions, and an albedo variant one package ships and the other
    #     does not.
    def deer(**overrides):
        fields = {"animal": "Red_Deer", "species": "reddeer", "clips": list(DEER_CLIPS)}
        fields.update(overrides)
        return problems_for(**fields)

    check("a good deer recipe is accepted", deer(), [])
    check("the deer's eleven are accepted", deer(clips=["Hit_Front", "Hit_Back"]), [])
    # THE CROSS-SPECIES CLIP, BOTH WAYS. This is the one a copy-pasted command line produces, and
    # before the species table it was accepted for the deer and would have asked Blender for a clip
    # `Arm_Deer` does not have -- twenty minutes in, or a key with no row.
    boar_clip_for_deer = deer(clips=["Hit_F"])
    check("a boar clip is refused for a deer", len(boar_clip_for_deer), 1)
    check("and the refusal names the species", "reddeer" in boar_clip_for_deer[0], True)
    check("a deer clip is refused for a boar", len(problems_for(clips=["Hit_Front"])), 1)
    check("and that one names the boar", "boar" in problems_for(clips=["Hit_Front"])[0], True)
    # Albedo 4 exists for the deer and not for the boar, which is why `albedos` is per species.
    check("albedo 4 is accepted for a deer", deer(albedo=4), [])
    check("albedo 5 is refused for a deer", len(deer(albedo=5)), 1)
    unknown = problems_for(animal="RedDeer_Stag", species=None, clips=list(DEER_CLIPS))
    # One line only: the species is unknown, so the clip list cannot be judged at all and the run
    # must not also be told its eleven real clips are wrong.
    check("an unknown animal is refused", len(unknown), 1)
    check("and it is told the known ones", "reddeer/Red_Deer" in unknown[0], True)

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
    # 12 groups since task 223: 1, 1b, 1c, 1d, 2, 2b, 3, 4, 5, 5b, 6, 7 -- counted as the
    # numbered blocks above, so a block that is deleted shows up as a number that moved.
    total = 12
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
        target.add_argument(
            "--animal",
            default="BoarMale",
            help="which animal, and therefore which species: " + ", ".join(known_animals()),
        )
        target.add_argument(
            "--albedo", type=int, default=DEFAULT_RECIPE["albedo"], help="which colour variant (1-3 boar, 1-4 deer)"
        )

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
    # None, not a joined list: the default is THIS SPECIES' clips and is resolved in `run_prep`.
    prep.add_argument("--clips", default=None)
    prep.add_argument("--scale-correction", type=float, default=DEFAULT_RECIPE["scaleCorrection"])
    prep.add_argument("--dry-run", action="store_true")

    sub.add_parser("species", help="print the table: which animals this tool knows")
    sub.add_parser("selftest", help="offline: no Blender, no model, no network")

    args = parser.parse_args(argv)
    handler = {"probe": run_probe, "prep": run_prep, "species": run_species, "selftest": run_selftest}[args.command]
    try:
        return handler(args)
    except Refused as refused:
        say(str(refused))
        return 2


if __name__ == "__main__":
    sys.exit(main())
