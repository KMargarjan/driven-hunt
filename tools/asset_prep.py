"""Driven Hunt asset prep: take a model somebody made, make it usable, and never touch the original.

It drives **headless Blender** (`--background --python`) with `tools/asset_prep_blender.py` and does
the five things a raw generated model needs before it can be a weapon in this game:

  (a) DECIMATE to a held-weapon budget, and report the count it MEASURED rather than the one it asked
      for (Roblox's own ceiling is 20,000 triangles per mesh, so this is about draw cost, not
      legality);
  (b) SPLIT the single mesh into regions -- barrels, action, wood -- by position along the long axis
      AND by texture colour, because the barrels and the action are both neutral grey in one atlas
      (position separates them) while the forend shares the barrels' span (only colour separates
      that);
  (c) COLOUR-CORRECT each region's pixels in HSV, moving the region's MEDIAN onto a target and
      keeping every pixel's ratio to it -- so the grain and the engraving survive, which a flat fill
      would erase;
  (d) RENDER four previews a human looks at (rule 5): side, top, muzzle, three-quarter;
  (e) EXPORT `model.fbx` and `model.glb`.

THIS FILE NEVER IMPORTS `bpy`. It spawns a process, so it carries the repository's terms;
`tools/asset_prep_blender.py` runs inside Blender and carries GPL-2.0-or-later, which is what the
Blender Foundation asks of a published script written for Blender. See the research note.

Usage:
  python tools/asset_prep.py probe --in <folder>                      # read-only: what is in there
  python tools/asset_prep.py prep --in <folder> --out <folder>        # the run
        [--recipe <file.json>] [--target 6000] [--work-px 2048] [--dry-run]
  python tools/asset_prep.py recipe                                   # print the default recipe
  python tools/asset_prep.py selftest                                 # offline, no input needed

Exit codes, the harness's shape: 0 done - 1 the run failed - 2 REFUSED before anything happened.

WHAT IT REFUSES, BEFORE IT TOUCHES ANYTHING:
  1. No Blender. `BLENDER_EXE` in the environment wins; otherwise the usual install locations are
     searched. A missing Blender is a refusal, never a silent skip.
  2. An input folder with no `.fbx` (or no such folder).
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

Colours: the defaults were sampled from Karen's own reference photographs of the real gun and are the
Director's pick, changeable (her rule, 2026-09-26: styling never blocks).

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
    # Roblox's ceiling is 20,000 triangles per mesh; 6,000 is what tools/meshy.py already asks Meshy
    # for, so both routes into this game produce comparable weapons.
    "targetTriangles": 6000,
    # 4096 is legal on Roblox and wasteful on a held weapon. Nothing is resized silently: the report
    # prints every size before and after.
    "workPx": 2048,
    "renderPx": 1100,
    "renderSamples": 32,
    "maskDilatePx": 4,
    # How hard a metallic/roughness target is applied: 0 leaves the map alone, 1 flattens it.
    "channelWeight": 0.85,
    # Where the action begins, as a fraction of the gun's length FROM THE MUZZLE. 0.62 is the real
    # 486 Parallelo's barrel fraction (28 in of 45 in), the same published number the grey-box gun in
    # src/server/Weapon/Shape.luau is built from.
    "actionStartT": 0.62,
    "regions": {
        # EVERY targetRGB IS AN sRGB TRIPLE MEASURED OFF KAREN'S OWN REFERENCE PHOTOGRAPHS, and the
        # Blender side converts it to scene-linear before it touches a pixel -- the first run applied
        # these numbers straight to linear pixels and the gun came back white and orange.
        #
        # GLOSS BLACK BLUED BARRELS AND RIB: RGB(34, 35, 37) is the p25 of the barrels in the photo.
        # An albedo must not carry the specular highlight that pulls the photo's median to RGB 82;
        # the gloss comes from roughness, not from a lighter colour.
        "barrel": {
            "baseColor": {"targetRGB": [34, 35, 37], "keepHue": True, "satScale": 0.05,
                          "contrast": 1.0},
            "roughness": 0.30,
            # NOT A MIRROR. Blued steel is metal, but at metallic 1.0 and low roughness the surface
            # shows the room instead of its own colour, and the first render came back chrome-white
            # (rule 5). 0.55 keeps a sheen and lets the dark albedo read as dark.
            "metallic": 0.55,
        },
        # BRIGHT SILVER ENGRAVED ACTION, GUARD AND LEVER: RGB(172, 172, 172), the median of the
        # action in the same photo. A little saturation is kept so the engraving does not go flat.
        "action": {
            "baseColor": {"targetRGB": [172, 172, 172], "keepHue": True, "satScale": 0.10,
                          "contrast": 1.05},
            "roughness": 0.38,
            "metallic": 0.70,
        },
        # MEDIUM WALNUT, deeper and less orange than what came out of Meshy -- Karen's two complaints
        # in one number: RGB(112, 80, 69) is the median of the stock in her reference photo.
        "wood": {
            "rule": {"satMin": 0.18, "hueLoDeg": 5.0, "hueHiDeg": 60.0},
            # satSpread 0.45 keeps the figure and stops it clipping to orange; contrast 0.9 lifts
            # the black streaks Meshy baked in, so the grain reads as grain and not as paint.
            "baseColor": {"targetRGB": [112, 80, 69], "satSpread": 0.45,
                          "levels": {"lowPct": 5, "highPct": 95, "lowScale": 0.42, "highScale": 1.15}},
            "roughness": 0.55,
            "metallic": 0.0,
        },
    },
}


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


def find_fbx(folder):
    hits = []
    for root, _dirs, files in os.walk(folder):
        for name in files:
            if name.lower().endswith(".fbx"):
                hits.append(os.path.join(root, name))
    if not hits:
        raise Refused("no .fbx under the input folder")
    hits.sort(key=lambda p: (len(p), p))
    return hits[0]


def check_output(path):
    if inside_repo(path):
        raise Refused("the output folder is inside the repository; this tool writes only outside it")
    if os.path.isdir(path) and os.listdir(path):
        raise Refused("the output folder already exists and is not empty; nothing is ever "
                      "overwritten (rule 7) -- name a new one")


def load_recipe(path, overrides):
    recipe = json.loads(json.dumps(DEFAULT_RECIPE))
    if path:
        with open(path, "r", encoding="utf-8") as handle:
            recipe.update(json.load(handle))
    for key, value in overrides.items():
        if value is not None:
            recipe[key] = value
    return recipe


def command_probe(args):
    folder = args.input
    if not os.path.isdir(folder):
        raise Refused("no such input folder")
    fbx = find_fbx(folder)
    files = manifest(folder)
    say("input %d file(s); model is %s (%.1f MiB)"
        % (len(files), os.path.basename(fbx), os.path.getsize(fbx) / (1 << 20)))
    for name in sorted(files):
        say("  %s  %d bytes" % (name, os.path.getsize(os.path.join(folder, name))))
    return 0


def command_recipe(_args):
    print(json.dumps(DEFAULT_RECIPE, indent=2))
    return 0


def run_blender(exe, job_path, timeout):
    process = subprocess.run([exe, "--background", "--python", BLENDER_SCRIPT, "--", job_path],
                             capture_output=True, text=True, timeout=timeout)
    for line in process.stdout.splitlines():
        if line.startswith("[prep]"):
            print(line, flush=True)
    return process


def prep(input_dir, out_dir, recipe, exe, timeout=1800, keep_source=True):
    """The whole run. Returns the Blender side's report. Raises Refused before anything is written."""
    if not os.path.isdir(input_dir):
        raise Refused("no such input folder")
    check_output(out_dir)
    fbx_name = os.path.relpath(find_fbx(input_dir), input_dir)

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
    recipe["sourceModel"] = fbx_name.replace("\\", "/")
    recipe_path = os.path.join(out_dir, "recipe.json")
    with open(recipe_path, "w", encoding="utf-8") as handle:
        json.dump(recipe, handle, indent=2)

    job = {
        "fbx": os.path.join(source_dir, fbx_name),
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
    if not keep_source:
        shutil.rmtree(source_dir, ignore_errors=True)
    with open(job["reportPath"], "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
    return report


def command_prep(args):
    exe = find_blender()
    recipe = load_recipe(args.recipe, {"targetTriangles": args.target, "workPx": args.work_px})
    if args.dry_run:
        say("would run %s" % os.path.basename(exe))
        print(json.dumps(recipe, indent=2))
        return 0
    say("blender: %s" % blender_version(exe))
    report = prep(args.input, args.output, recipe, exe, keep_source=not args.no_source)
    if not report.get("ok"):
        say("FAILED: %s" % report.get("error", "no reason given"))
        return 1
    tri = report["triangles"]
    regions = report.get("regions", {})
    say("triangles %d -> %d (target %d, MEASURED)" % (tri["before"], tri["after"], tri["target"]))
    say("regions (triangles): " + ", ".join("%s %d" % (k, regions[k]) for k in sorted(regions)))
    for name in ("barrel", "action", "wood"):
        got = report.get("corrections", {}).get(name, {})
        if got.get("pixels"):
            say("colour %-7s asked for RGB%-16s got RGB%s"
                % (name, tuple(got["targetRGB"]), tuple(got["achievedRGB"])))
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
# One material, one atlas, half grey and half brown -- the very case the region rule exists for.
image = bpy.data.images.new("atlas", 256, 256)
# ONE TONE PER FIXTURE, so each run isolates ONE rule. A half-and-half atlas made the outcome depend
# on where smart_project happened to put each island, which is luck, not a test.
colour = [0.45, 0.45, 0.46, 1.0] if tone == "neutral" else [0.60, 0.36, 0.18, 1.0]
image.pixels = colour * (256 * 256)
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

        regions = report.get("regions", {})
        ok("three regions exist", set(regions) == {"barrel", "action", "wood"}, str(regions))
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
        ok("one material per region", len(report.get("materials", [])) >= 3,
           str(report.get("materials")))
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
            find_fbx(os.path.join(tmp, "in-neutral", "no-such-place"))
            ok("it refuses an input with no FBX", False)
        except (Refused, OSError):
            ok("it refuses an input with no FBX", True)
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
    recipe = sub.add_parser("recipe")
    run = sub.add_parser("prep")
    run.add_argument("--in", dest="input", required=True)
    run.add_argument("--out", dest="output", required=True)
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
