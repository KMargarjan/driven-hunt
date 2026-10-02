"""Split a glTF scene into the HINGE GROUPS a break-action gun needs, aligned to the game's frame.

WHY IT EXISTS (task 105). Karen looked at the overnight exact-geometry gun on 2026-10-02 and said
"bad" -- it reads as Roblox blocks next to the target -- and picked a professional CC-BY model
instead: "Double Barrel Shotgun" by Ryan_Nein. That model arrives as a Sketchfab glTF: NINE mesh
nodes, every one carrying its own 4x4 matrix, the whole gun tilted 82 degrees by a `group` node, and
its long axis nowhere near an axis of the file.

`tools/asset_prep.py` cannot be the thing that fixes that, and the reason is not effort:

  1. ITS SPLIT IS A PLANE (`rebuildBarrels.splitAtCut`, task 96), and this model's groups OVERLAP
     along the long axis -- the forend runs from 0.29 to 0.51 of the way back and the action starts
     at 0.29 -- so any plane cuts through one of them. The split that is wanted here is BY NODE, and
     the node identity is gone by the time Blender has joined the meshes into one object.
  2. IT MEASURES AND NEVER MOVES (`long_axis` reads local coordinates; nothing is ever rotated). A
     model whose long axis is 8 degrees off an axis would be baked into a MeshPart whose bounding box
     is the TILTED box, and `sizeStuds` would then describe a box the gun does not fill.

So this tool is the step BEFORE prep: it reads the glTF, MEASURES the gun's own three axes off its
own geometry, rewrites every vertex into the game's Handle frame in studs, and writes one
self-contained glTF per hinge group. `asset_prep.py` then runs on each group folder unchanged -- the
textures, the smoothing, the embedded-texture FBX export and the previews are all its proven work and
none of it is touched here.

THE TWO ANCHOR TRIANGLES ARE BORROWED, NOT INVENTED (rule 2). Task 96 already solved "two MeshParts
that must assemble at one CFrame": give each piece two triangles a ten-thousandth of the model across
at the WHOLE model's opposite bounding-box corners, so Roblox imports both at the same size and the
same origin and the consumer needs no measured per-piece offset. Same trick, same reason, and
`tools/asset_prep_blender.py:split_export` is where it is written down.

HOW THE FRAME IS MEASURED, and every step is a fact about the geometry rather than a convention:
  * FORWARD is the dominant axis of the BARREL node's own vertex covariance -- a pair of parallel
    tubes is the one part of a gun whose principal axis IS the bore line. Not the whole gun's: the
    stock's drop pulls that axis degrees off the bores.
  * RIGHT is the WEAKEST axis of the whole gun's covariance (a gun is far thinner across than it is
    deep), orthogonalised against forward.
  * UP is right x forward, and its SIGN is settled by a named node that must be above the bores (the
    top lever). Not by the file's own +Y, which the Sketchfab tilt has already moved.
  * The MUZZLE is the barrel node's extreme along forward; the BORE LINE is the midpoint of the
    barrel node's extent along up, because two tubes side by side put their common axis exactly
    there.
  * The origin is then the Handle's: X centred on the gun, Y on the bore line plus `boreUpStuds`,
    Z with the muzzle at -`lengthStuds`/2. Those three numbers are the game's, passed in by the plan.

A PLAN IS A NAMED SPLIT, and the plans live in this file for the reason `asset_prep.py` keeps its
presets in its own: the node names that decide what swings are then reviewed as a diff rather than
carried in a loose JSON file nobody reads. `--plan <file.json>` still overrides.

NO NETWORK, NO BLENDER, NO `bpy`, AND IT WRITES NOTHING IT WAS NOT ASKED TO. Standard library only,
so `selftest` runs anywhere CI runs.

Usage:
  python tools/gltf_split.py probe --in <folder>                    # read-only: nodes, in the frame
  python tools/gltf_split.py split --in <folder> --out <folder> [--plan model-b|<file.json>]
  python tools/gltf_split.py plan [--plan model-b]                  # print a plan
  python tools/gltf_split.py selftest                               # offline, no input needed

Exit codes, the harness's shape: 0 done - 1 the run failed - 2 REFUSED before anything happened.

WHAT IT REFUSES, BEFORE IT WRITES ANYTHING:
  1. No `.gltf` in the input folder, or a `.glb` (one file, binary: this tool reads the text form,
     which is what Sketchfab hands back).
  2. An output path INSIDE the repository, for the reason `asset_prep.py` refuses one: everything it
     writes is generated and some of it is large binary.
  3. An output folder that already exists and is not empty (rule 7: a second run wants a second
     folder).
  4. A node the plan names that the file does not have, OR a mesh node the plan does not place in any
     group. Nothing is dropped silently -- a forend nobody assigned is a forend that vanishes.

Note: docs/research/2026-10-01-exact-metal-gun.md (why the gun was parts), TASKS.md row 105
"""

import argparse
import hashlib
import json
import math
import os
import shutil
import struct
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL_VERSION = "gltf-split/1"

# glTF component types: code -> (struct format, byte size)
COMPONENT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2),
             5125: ("I", 4), 5126: ("f", 4)}
COUNTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}

# THE GAME'S OWN NUMBERS, and they are the plan's rather than this file's because they belong to
# `Shotgun.CONFIG` and `Gun`: HANDLE_SIZE.Z is 4.4 studs and the bore line sits 0.12 above the
# Handle's axis. A plan states them so that a run is readable against the Luau beside it.
MODEL_B_PLAN = {
    "tool": TOOL_VERSION,
    "name": "model-b",
    # The gun is scaled UNIFORMLY so that its own length is exactly this. Nothing else is scaled, so
    # no shot or hit number moves: `Shotgun.CONFIG.HANDLE_SIZE.Z`.
    "lengthStuds": 4.4,
    # Where the bore line lands in the Handle's frame: `Gun.BARREL_Y`.
    "boreUpStuds": 0.12,
    # The node whose principal axis IS the bore line.
    "axisFromNode": "pasted__barrel",
    # A node that must come out ABOVE the bores, which settles the sign of "up". The top lever of a
    # break-action sits on the tang, above the barrels, and nothing else on this gun does.
    "upTowardNode": "pasted__lever",
    # ...and one that must come out BEHIND the muzzle, which settles the sign of "forward".
    "backTowardNode": "pasted__base",
    # Two triangles this fraction of the gun's length across, at the whole model's opposite corners,
    # in every group: task 96's trick, so both groups import at one size and one origin. 1e-4 of 4.4
    # studs is 4.4e-4 studs, which is smaller than any pixel this game draws.
    "anchorSize": 1.0e-4,
    # THE HINGE GROUPS. MEASURED off this file (`probe`), not read off the node names:
    #   * `pasted__barrel` is the two tubes: 0.078 studs across the pair's height, which is one
    #     12-gauge tube (21.7 mm at this scale), and 2.72 studs long -- 0.617 of the gun, against the
    #     28-of-45-inch spec sheet's 0.622.
    #   * `pasted__base_upper` IS THE FOREND, whatever its name says, and nothing had to be cut to
    #     find it: it is its OWN glTF node of 60 triangles, it sits BELOW the bore line (up to 0.118
    #     against the bores' 0.120) and it spans the 1.03 studs from the breech forward. On a real
    #     break-action the forend is screwed to the barrels and swings with them, so it is in the
    #     barrel group.
    #   * everything else is the frame: the action and stock (`pasted__base`), the trigger, its guard
    #     (`pasted__trigger_outer`), the top lever and the safety knob.
    # The two SHELLS the artist left in the scene are their own group: a shell is not part of a gun.
    "groups": [
        {"name": "barrels", "nodes": ["pasted__barrel", "pasted__base_upper"]},
        {"name": "frame", "nodes": ["pasted__base", "pasted__trigger", "pasted__trigger_outer",
                                    "pasted__lever", "pasted__knob"]},
        # A LOOSE SHELL IS NOT IN THE GUN'S BOUNDING BOX, so it gets its own: anchoring it to the
        # gun's corners would make a 0.08-stud cartridge a 4.4-stud MeshPart. It also lies at an
        # angle where the artist dropped it, so it gets its OWN FRAME as well -- measured the same
        # way the gun's is -- or its MeshPart would be the bounding box of a tilted cartridge.
        # `ownFrame` keeps the GUN'S scale, so the shell's size in studs is its real size against
        # the gun it goes in.
        {"name": "shell", "nodes": ["shell_low"], "ownBox": True, "ownFrame": True},
    ],
    # The artist's second shell is a duplicate of the first, posed differently. One shell is enough:
    # the game draws its own, two per gun, from one template. Listed so it is DROPPED on purpose
    # rather than caught by refusal 4.
    "dropNodes": ["shell_low.001"],
}

PLANS = {"model-b": MODEL_B_PLAN}


class Refused(Exception):
    """Something was wrong before anything was written."""


# ---------------------------------------------------------------- small linear algebra, stdlib only


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def scale(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def norm(a):
    length = math.sqrt(dot(a, a))
    if length == 0.0:
        raise Refused("a zero-length axis: the model has no extent to measure")
    return scale(a, 1.0 / length)


def covariance(points):
    """The 3x3 covariance of a point cloud about its own mean."""
    n = float(len(points))
    mean = [sum(p[i] for p in points) / n for i in (0, 1, 2)]
    out = [[0.0] * 3 for _ in range(3)]
    for p in points:
        d = (p[0] - mean[0], p[1] - mean[1], p[2] - mean[2])
        for i in range(3):
            for j in range(3):
                out[i][j] += d[i] * d[j]
    for i in range(3):
        for j in range(3):
            out[i][j] /= n
    return out


def eigen3(matrix, sweeps=64):
    """Every eigenvalue and eigenvector of a 3x3 SYMMETRIC matrix, by Jacobi rotations.

    Jacobi is used rather than power iteration because this tool needs the WEAKEST axis as well as
    the strongest, and it is 30 lines with no library. It is the textbook method:
    https://en.wikipedia.org/wiki/Jacobi_eigenvalue_algorithm

    Returns [(eigenvalue, unit eigenvector), ...] sorted LARGEST eigenvalue first.
    """
    a = [row[:] for row in matrix]
    v = [[1.0 if i == j else 0.0 for j in range(3)] for i in range(3)]
    for _ in range(sweeps):
        off = sum(abs(a[i][j]) for i, j in ((0, 1), (0, 2), (1, 2)))
        if off < 1e-18:
            break
        for p, q in ((0, 1), (0, 2), (1, 2)):
            if abs(a[p][q]) < 1e-20:
                continue
            theta = (a[q][q] - a[p][p]) / (2.0 * a[p][q])
            t = (1.0 if theta >= 0 else -1.0) / (abs(theta) + math.sqrt(theta * theta + 1.0))
            c = 1.0 / math.sqrt(t * t + 1.0)
            s = t * c
            for k in range(3):
                akp, akq = a[k][p], a[k][q]
                a[k][p] = c * akp - s * akq
                a[k][q] = s * akp + c * akq
            for k in range(3):
                apk, aqk = a[p][k], a[q][k]
                a[p][k] = c * apk - s * aqk
                a[q][k] = s * apk + c * aqk
            for k in range(3):
                vkp, vkq = v[k][p], v[k][q]
                v[k][p] = c * vkp - s * vkq
                v[k][q] = s * vkp + c * vkq
    pairs = [(a[i][i], (v[0][i], v[1][i], v[2][i])) for i in range(3)]
    pairs.sort(key=lambda pair: -pair[0])
    return [(value, norm(vector)) for value, vector in pairs]


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def det3(m):
    return (m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
            - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
            + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]))


def apply4(m, p):
    return (m[0][0] * p[0] + m[0][1] * p[1] + m[0][2] * p[2] + m[0][3],
            m[1][0] * p[0] + m[1][1] * p[1] + m[1][2] * p[2] + m[1][3],
            m[2][0] * p[0] + m[2][1] * p[1] + m[2][2] * p[2] + m[2][3])


def apply3(m, p):
    return (m[0][0] * p[0] + m[0][1] * p[1] + m[0][2] * p[2],
            m[1][0] * p[0] + m[1][1] * p[1] + m[1][2] * p[2],
            m[2][0] * p[0] + m[2][1] * p[1] + m[2][2] * p[2])


def inverse_transpose3(m):
    """The matrix NORMALS transform by. A mirror makes this differ from the matrix itself, and a
    normal transformed by the matrix instead points into the surface."""
    d = det3(m)
    if abs(d) < 1e-30:
        raise Refused("a singular node matrix: the model cannot be transformed")
    cof = [[0.0] * 3 for _ in range(3)]
    for i in range(3):
        for j in range(3):
            rows = [r for r in range(3) if r != i]
            cols = [c for c in range(3) if c != j]
            minor = (m[rows[0]][cols[0]] * m[rows[1]][cols[1]]
                     - m[rows[0]][cols[1]] * m[rows[1]][cols[0]])
            cof[i][j] = ((-1.0) ** (i + j)) * minor
    # inverse = cof^T / det, so inverse^T = cof / det
    return [[cof[i][j] / d for j in range(3)] for i in range(3)]


# ---------------------------------------------------------------- reading the glTF


def find_gltf(folder):
    if not os.path.isdir(folder):
        raise Refused("no such input folder: %s" % folder)
    names = sorted(n for n in os.listdir(folder) if n.lower().endswith(".gltf"))
    if not names:
        glb = [n for n in os.listdir(folder) if n.lower().endswith(".glb")]
        if glb:
            raise Refused("that folder holds a .glb (%s); this tool reads the .gltf text form"
                          % glb[0])
        raise Refused("no .gltf in %s" % folder)
    return os.path.join(folder, names[0])


class Scene(object):
    """One glTF document, its buffers, and every mesh node's baked geometry."""

    def __init__(self, path):
        self.path = path
        self.dir = os.path.dirname(os.path.abspath(path))
        with open(path, "r", encoding="utf-8") as handle:
            self.doc = json.load(handle)
        self._buffers = {}
        self.nodes = {}  # name -> {"positions", "normals", "uvs", "triangles", "material", "det"}
        self._read_nodes()

    def buffer(self, index):
        if index not in self._buffers:
            uri = self.doc["buffers"][index].get("uri")
            if not uri or uri.startswith("data:"):
                raise Refused("buffer %d is embedded or missing a uri; this tool reads the "
                              "separate .bin form" % index)
            with open(os.path.join(self.dir, uri), "rb") as handle:
                self._buffers[index] = handle.read()
        return self._buffers[index]

    def accessor(self, index):
        spec = self.doc["accessors"][index]
        view = self.doc["bufferViews"][spec["bufferView"]]
        data = self.buffer(view.get("buffer", 0))
        start = view.get("byteOffset", 0) + spec.get("byteOffset", 0)
        fmt, size = COMPONENT[spec["componentType"]]
        count = COUNTS[spec["type"]]
        stride = view.get("byteStride") or size * count
        out = []
        for k in range(spec["count"]):
            out.append(struct.unpack_from("<" + fmt * count, data, start + k * stride))
        return out

    def _matrix(self, node):
        if "matrix" in node:
            flat = node["matrix"]
            # glTF stores a matrix COLUMN-major: the first four numbers are the first column.
            return [[flat[0], flat[4], flat[8], flat[12]],
                    [flat[1], flat[5], flat[9], flat[13]],
                    [flat[2], flat[6], flat[10], flat[14]],
                    [flat[3], flat[7], flat[11], flat[15]]]
        out = [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]
        if "scale" in node:
            for i in range(3):
                out[i][i] = node["scale"][i]
        if "translation" in node:
            for i in range(3):
                out[i][3] = node["translation"][i]
        if "rotation" in node:
            x, y, z, w = node["rotation"]
            rot = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), 0.0],
                   [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), 0.0],
                   [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), 0.0],
                   [0.0, 0.0, 0.0, 1.0]]
            out = mat_mul(out, rot)
        return out

    def _read_nodes(self):
        nodes = self.doc["nodes"]
        parent = {}
        for index, node in enumerate(nodes):
            for child in node.get("children", []):
                parent[child] = index

        def world(index):
            chain = []
            at = index
            while True:
                chain.append(at)
                if at in parent:
                    at = parent[at]
                else:
                    break
            out = [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]
            for step in reversed(chain):
                out = mat_mul(out, self._matrix(nodes[step]))
            return out

        for index, node in enumerate(nodes):
            if "mesh" not in node:
                continue
            # SKETCHFAB NAMES THE MESH NODE "<thing>_<material>_0" AND ITS PARENT "<thing>", and the
            # parent is the name a human reads in the outliner, so that is the name a plan uses.
            name = nodes[parent[index]].get("name") if index in parent else node.get("name")
            matrix = world(index)
            linear = [row[:3] for row in matrix[:3]]
            normal_matrix = inverse_transpose3(linear)
            mirrored = det3(linear) < 0.0
            positions, normals, uvs, triangles, material = [], [], [], [], None
            for primitive in self.doc["meshes"][node["mesh"]]["primitives"]:
                attributes = primitive["attributes"]
                base = len(positions)
                for point in self.accessor(attributes["POSITION"]):
                    positions.append(apply4(matrix, point))
                if "NORMAL" in attributes:
                    for vector in self.accessor(attributes["NORMAL"]):
                        normals.append(norm(apply3(normal_matrix, vector)))
                else:
                    for _ in range(len(positions) - base):
                        normals.append((0.0, 0.0, 1.0))
                if "TEXCOORD_0" in attributes:
                    for uv in self.accessor(attributes["TEXCOORD_0"]):
                        uvs.append((uv[0], uv[1]))
                else:
                    for _ in range(len(positions) - base):
                        uvs.append((0.0, 0.0))
                indices = [i[0] for i in self.accessor(primitive["indices"])]
                for k in range(0, len(indices) - 2, 3):
                    a, b, c = indices[k] + base, indices[k + 1] + base, indices[k + 2] + base
                    # A MIRRORED TRANSFORM TURNS EVERY TRIANGLE INSIDE OUT. Reversing the winding is
                    # what puts the front face back on the outside; the normals are already right,
                    # because they went through the inverse transpose.
                    triangles.append((a, c, b) if mirrored else (a, b, c))
                if material is None:
                    material = primitive.get("material", 0)
            self.nodes[name] = {"positions": positions, "normals": normals, "uvs": uvs,
                                "triangles": triangles, "material": material,
                                "mirrored": mirrored}


# ---------------------------------------------------------------- the frame


def bounds(points):
    lo = [min(p[i] for p in points) for i in (0, 1, 2)]
    hi = [max(p[i] for p in points) for i in (0, 1, 2)]
    return lo, hi


def measure_frame(scene, plan):
    """The gun's own three axes, its scale and its origin -- all off its geometry (see the header)."""
    for key in ("axisFromNode", "upTowardNode", "backTowardNode"):
        if plan[key] not in scene.nodes:
            raise Refused("the plan's %s names '%s', which this file has no node for (it has: %s)"
                          % (key, plan[key], ", ".join(sorted(scene.nodes))))
    kept = set()
    for group in plan["groups"]:
        kept.update(group["nodes"])
    body = [name for name in kept if name not in {g["name"] for g in plan["groups"]}]
    # The frame is measured off the GUN, not off a loose shell: every node in a group that is not
    # carried in its own box.
    in_gun = []
    for group in plan["groups"]:
        if not group.get("ownBox"):
            in_gun.extend(group["nodes"])
    gun_points = []
    for name in in_gun:
        gun_points.extend(scene.nodes[name]["positions"])
    barrel = scene.nodes[plan["axisFromNode"]]["positions"]

    forward = eigen3(covariance(barrel))[0][1]
    back_centre = centroid(scene.nodes[plan["backTowardNode"]]["positions"])
    if dot(sub(centroid(barrel), back_centre), forward) < 0.0:
        forward = scale(forward, -1.0)

    right = eigen3(covariance(gun_points))[2][1]
    right = norm(sub(right, scale(forward, dot(right, forward))))
    up = norm(cross(right, forward))
    if dot(sub(centroid(scene.nodes[plan["upTowardNode"]]["positions"]), centroid(barrel)), up) < 0.0:
        right = scale(right, -1.0)
        up = norm(cross(right, forward))

    def project(points):
        return [(dot(p, right), dot(p, up), -dot(p, forward)) for p in points]

    gun_lo, gun_hi = bounds(project(gun_points))
    barrel_lo, barrel_hi = bounds(project(barrel))
    length = gun_hi[2] - gun_lo[2]
    if length <= 0.0:
        raise Refused("the gun has no length along the axis that was measured")
    studs = float(plan["lengthStuds"]) / length
    # The origin, in the PROJECTED frame, before scaling: X on the gun's centre line, Y on the bore
    # line (the midpoint of the barrel pair's own height), Z at the muzzle.
    origin = ((gun_lo[0] + gun_hi[0]) / 2.0,
              (barrel_lo[1] + barrel_hi[1]) / 2.0,
              barrel_lo[2])
    return {"right": right, "up": up, "forward": forward, "studs": studs, "origin": origin,
            # WHERE THE MEASURED ORIGIN GOES IN THE HANDLE'S FRAME: the bore line `boreUpStuds` above
            # the Handle's axis, and the muzzle at -length/2, which is `Shotgun.CONFIG.MUZZLE_OFFSET`.
            "shift": (0.0, float(plan["boreUpStuds"]), -float(plan["lengthStuds"]) / 2.0),
            "lengthSource": length, "unused": sorted(body)}


def centroid(points):
    n = float(len(points))
    return tuple(sum(p[i] for p in points) / n for i in (0, 1, 2))


def measure_own_frame(points, studs):
    """A loose part's own three axes, at the GUN's scale (`ownFrame`).

    THE MOUTH IS THE THINNER END, and that is a fact about a shotgun cartridge rather than a guess: a
    12-gauge shell is a plastic hull with a BRASS HEAD whose rim stands proud of it, so the end whose
    cross-section is wider is the head. The axis is the cloud's own dominant one -- a cartridge is a
    cylinder, so that IS its length -- and the origin is its bounding-box centre, which is where
    Roblox puts a MeshPart's pivot.
    """
    axes = eigen3(covariance(points))
    forward = axes[0][1]
    right = norm(sub(axes[2][1], scale(forward, dot(axes[2][1], forward))))
    up = norm(cross(right, forward))
    along = [dot(p, forward) for p in points]
    lo, hi = min(along), max(along)
    span = hi - lo

    def width(near_low):
        block = [p for p, t in zip(points, along)
                 if (t < lo + span * 0.25 if near_low else t > hi - span * 0.25)]
        if not block:
            return 0.0
        return max(max(dot(p, axis) for p in block) - min(dot(p, axis) for p in block)
                   for axis in (right, up))

    if width(True) < width(False):
        # The thin end is at the LOW end of the axis, so the axis already points head-first: turn it
        # round so `forward` is the mouth.
        forward = scale(forward, -1.0)
        up = norm(cross(right, forward))
    projected = [(dot(p, right), dot(p, up), -dot(p, forward)) for p in points]
    lo3, hi3 = bounds(projected)
    centre = tuple((lo3[i] + hi3[i]) / 2.0 for i in (0, 1, 2))
    # NOTHING IS SHIFTED: a loose part is written about its own centre, which is where Roblox puts a
    # MeshPart's pivot, so the consumer places it and this file says nothing about where.
    return {"right": right, "up": up, "forward": forward, "studs": studs, "origin": centre,
            "shift": (0.0, 0.0, 0.0), "lengthSource": hi3[2] - lo3[2]}


def to_handle(frame, point):
    """One source point, in the frame's own target frame, in studs: rotate, re-origin, scale, shift."""
    return (
        (dot(point, frame["right"]) - frame["origin"][0]) * frame["studs"] + frame["shift"][0],
        (dot(point, frame["up"]) - frame["origin"][1]) * frame["studs"] + frame["shift"][1],
        (-dot(point, frame["forward"]) - frame["origin"][2]) * frame["studs"] + frame["shift"][2],
    )


def to_handle_normal(frame, vector):
    """A direction in the Handle's frame. The frame is a pure rotation, so the same three dots."""
    return norm((dot(vector, frame["right"]), dot(vector, frame["up"]),
                 -dot(vector, frame["forward"])))


# THE EXPORT TURN, and it is one line with a measured reason. `tools/asset_prep.py` exports what it is
# given, and the two halves of Karen's gun already in the manifest arrive in Roblox with their long
# axis along the MeshPart's own X -- which is why both their rows carry `rotationDeg = (0, 90, 0)`.
# Writing this model out the same way (long axis along the file's X, muzzle at +X, up at +Y) keeps
# that turn the one that is already proven in the game rather than a second unknown.
#   handle (x, y, z) -> file (-z, y, x), which is a right-handed turn: det = +1.
def to_file(point):
    return (-point[2], point[1], point[0])


# ---------------------------------------------------------------- writing one group


def group_mesh(scene, plan, frames, group, whole_lo, whole_hi):
    """One group's vertices, triangles and material, in the FILE's axes, anchors included."""
    frame = frames[group["name"]]
    positions, normals, uvs, triangles, materials = [], [], [], [], []
    for name in group["nodes"]:
        node = scene.nodes[name]
        base = len(positions)
        for point in node["positions"]:
            positions.append(to_file(to_handle(frame, point)))
        for vector in node["normals"]:
            normals.append(to_file(to_handle_normal(frame, vector)))
        uvs.extend(node["uvs"])
        for a, b, c in node["triangles"]:
            triangles.append((a + base, b + base, c + base))
        if node["material"] not in materials:
            materials.append(node["material"])
    if len(materials) != 1:
        raise Refused("group '%s' spans %d materials (%s); one MeshPart is one material"
                      % (group["name"], len(materials), materials))
    anchors = 0
    if not group.get("ownBox"):
        size = float(plan["anchorSize"]) * float(plan["lengthStuds"])
        # EACH ANCHOR GROWS INWARD, which task 96's did not: a triangle hung off the HIGH corner in
        # +X and +Y makes the box `anchorSize` bigger than the model, and then `sizeStuds` describes a
        # box the gun does not quite fill. Inward, the box is EXACTLY the model's.
        for corner, inward in ((whole_lo, +1.0), (whole_hi, -1.0)):
            base = len(positions)
            positions.extend([corner,
                              (corner[0] + size * inward, corner[1], corner[2]),
                              (corner[0], corner[1] + size * inward, corner[2])])
            normals.extend([(0.0, 0.0, 1.0)] * 3)
            uvs.extend([(0.0, 0.0)] * 3)
            triangles.append((base, base + 1, base + 2))
            anchors += 1
    return {"positions": positions, "normals": normals, "uvs": uvs, "triangles": triangles,
            "material": materials[0], "anchors": anchors}


def write_group(mesh, source, out_dir, name):
    """One self-contained glTF: `scene.gltf`, `scene.bin`, and the textures it names, copied."""
    os.makedirs(os.path.join(out_dir, "textures"), exist_ok=True)
    blob = bytearray()
    views, accessors = [], []

    def add(data, target, kind, component, values, mins=True):
        offset = len(blob)
        blob.extend(data)
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(data), "target": target})
        spec = {"bufferView": len(views) - 1, "componentType": component, "count": len(values),
                "type": kind}
        if mins and values:
            width = COUNTS[kind]
            spec["min"] = [min(v[i] for v in values) for i in range(width)]
            spec["max"] = [max(v[i] for v in values) for i in range(width)]
        accessors.append(spec)
        return len(accessors) - 1

    flat = bytearray()
    for p in mesh["positions"]:
        flat.extend(struct.pack("<3f", *p))
    position = add(bytes(flat), 34962, "VEC3", 5126, mesh["positions"])
    flat = bytearray()
    for n in mesh["normals"]:
        flat.extend(struct.pack("<3f", *n))
    normal = add(bytes(flat), 34962, "VEC3", 5126, mesh["normals"])
    flat = bytearray()
    for uv in mesh["uvs"]:
        flat.extend(struct.pack("<2f", *uv))
    texcoord = add(bytes(flat), 34962, "VEC2", 5126, mesh["uvs"])
    flat = bytearray()
    for tri in mesh["triangles"]:
        flat.extend(struct.pack("<3I", *tri))
    indices = add(bytes(flat), 34963, "SCALAR", 5125,
                  [(i,) for tri in mesh["triangles"] for i in tri], mins=False)

    # The material, with every texture, sampler and image it names copied over and renumbered.
    material = json.loads(json.dumps(source.doc["materials"][mesh["material"]]))
    images, textures, samplers = [], [], []

    def remap(slot):
        if slot is None:
            return None
        old = source.doc["textures"][slot["index"]]
        image = source.doc["images"][old["source"]]
        uri = image["uri"]
        shutil.copyfile(os.path.join(source.dir, uri),
                        os.path.join(out_dir, "textures", os.path.basename(uri)))
        images.append({"uri": "textures/" + os.path.basename(uri)})
        sampler = source.doc["samplers"][old["sampler"]] if "sampler" in old else {}
        samplers.append(json.loads(json.dumps(sampler)))
        textures.append({"sampler": len(samplers) - 1, "source": len(images) - 1})
        out = dict(slot)
        out["index"] = len(textures) - 1
        return out

    pbr = material.setdefault("pbrMetallicRoughness", {})
    for holder, key in ((pbr, "baseColorTexture"), (pbr, "metallicRoughnessTexture"),
                        (material, "normalTexture")):
        if key in holder:
            holder[key] = remap(holder[key])

    doc = {
        "asset": {"version": "2.0", "generator": TOOL_VERSION,
                  "extras": dict(source.doc.get("asset", {}).get("extras", {}))},
        "scene": 0,
        "scenes": [{"name": name, "nodes": [0]}],
        # IDENTITY: every vertex is already in the Handle's frame, so there is no node matrix left to
        # disagree with it. That is the whole point of this tool.
        "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": [{
            "attributes": {"POSITION": position, "NORMAL": normal, "TEXCOORD_0": texcoord},
            "indices": indices, "material": 0, "mode": 4}]}],
        "materials": [material],
        "textures": textures,
        "images": images,
        "samplers": samplers,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"uri": "scene.bin", "byteLength": len(blob)}],
    }
    for key in ("textures", "images", "samplers"):
        if not doc[key]:
            del doc[key]
    with open(os.path.join(out_dir, "scene.bin"), "wb") as handle:
        handle.write(bytes(blob))
    with open(os.path.join(out_dir, "scene.gltf"), "w", encoding="utf-8") as handle:
        json.dump(doc, handle, indent=1)
    return {"scene.gltf": os.path.getsize(os.path.join(out_dir, "scene.gltf")),
            "scene.bin": len(blob)}


# ---------------------------------------------------------------- the two commands


def check_plan(plan, scene=None):
    for key in ("lengthStuds", "boreUpStuds", "axisFromNode", "upTowardNode", "backTowardNode",
                "anchorSize", "groups"):
        if key not in plan:
            raise Refused("the plan has no '%s'" % key)
    names = [g["name"] for g in plan["groups"]]
    if len(set(names)) != len(names):
        raise Refused("two groups share a name: %s" % names)
    if scene is not None:
        placed = []
        for group in plan["groups"]:
            for node in group["nodes"]:
                if node not in scene.nodes:
                    raise Refused("group '%s' names node '%s', which this file has not (it has: %s)"
                                  % (group["name"], node, ", ".join(sorted(scene.nodes))))
                placed.append(node)
        if len(set(placed)) != len(placed):
            raise Refused("a node is in two groups: %s" % placed)
        dropped = set(plan.get("dropNodes", []))
        orphans = sorted(set(scene.nodes) - set(placed) - dropped)
        if orphans:
            raise Refused("no group places %s, and `dropNodes` does not drop it either: a part "
                          "nobody assigned is a part that vanishes" % ", ".join(orphans))
    return plan


def report_nodes(scene, plan, frame):
    out = []
    for name in sorted(scene.nodes):
        node = scene.nodes[name]
        points = [to_handle(frame, p) for p in node["positions"]]
        lo, hi = bounds(points)
        out.append({"node": name, "triangles": len(node["triangles"]),
                    "vertices": len(node["positions"]), "material": node["material"],
                    "mirrored": node["mirrored"],
                    "minStuds": [round(v, 5) for v in lo], "maxStuds": [round(v, 5) for v in hi]})
    return out


def frames_for(scene, plan, frame):
    """The frame every group is written in: the gun's, or a loose part's own (`ownFrame`)."""
    out = {}
    for group in plan["groups"]:
        if group.get("ownFrame"):
            points = []
            for name in group["nodes"]:
                points.extend(scene.nodes[name]["positions"])
            out[group["name"]] = measure_own_frame(points, frame["studs"])
        else:
            out[group["name"]] = frame
    return out


def cmd_probe(args):
    scene = Scene(find_gltf(args.folder))
    plan = check_plan(load_plan(args.plan))
    frame = measure_frame(scene, plan)
    print("[split] %s" % os.path.basename(scene.path))
    print("[split] right %s" % fmt3(frame["right"]))
    print("[split] up    %s" % fmt3(frame["up"]))
    print("[split] fwd   %s  (the muzzle direction in the file's own axes)" % fmt3(frame["forward"]))
    print("[split] source length %.6f -> %.3f studs (x %.5f)"
          % (frame["lengthSource"], plan["lengthStuds"], frame["studs"]))
    for row in report_nodes(scene, plan, frame):
        print("[split]   %-22s tris %4d  X[%+.4f,%+.4f] Y[%+.4f,%+.4f] Z[%+.4f,%+.4f]%s"
              % (row["node"], row["triangles"], row["minStuds"][0], row["maxStuds"][0],
                 row["minStuds"][1], row["maxStuds"][1], row["minStuds"][2], row["maxStuds"][2],
                 "  mirrored" if row["mirrored"] else ""))
    return 0


def fmt3(v):
    return "(%+.5f, %+.5f, %+.5f)" % v


def load_plan(name):
    if name in PLANS:
        return json.loads(json.dumps(PLANS[name]))
    if os.path.isfile(name):
        with open(name, "r", encoding="utf-8") as handle:
            return json.load(handle)
    raise Refused("no such plan: %s (there are %s, or give a path to a .json)"
                  % (name, ", ".join(sorted(PLANS))))


def digests(folder):
    out = {}
    for root, _dirs, files in os.walk(folder):
        for name in sorted(files):
            path = os.path.join(root, name)
            with open(path, "rb") as handle:
                out[os.path.relpath(path, folder).replace("\\", "/")] = \
                    hashlib.sha256(handle.read()).hexdigest()
    return out


def cmd_split(args):
    out_dir = os.path.abspath(args.out)
    if os.path.commonpath([out_dir, REPO]) == REPO:
        raise Refused("the output is inside the repository (%s); everything this tool writes is "
                      "generated, and some of it is large binary" % out_dir)
    if os.path.isdir(out_dir) and os.listdir(out_dir):
        raise Refused("the output folder exists and is not empty: %s (rule 7: a second run wants a "
                      "second folder)" % out_dir)
    source_dir = os.path.abspath(args.folder)
    before = digests(source_dir)
    scene = Scene(find_gltf(source_dir))
    plan = check_plan(load_plan(args.plan), scene)
    frame = measure_frame(scene, plan)
    frames = frames_for(scene, plan, frame)

    gun_points = []
    for group in plan["groups"]:
        if group.get("ownBox"):
            continue
        for name in group["nodes"]:
            gun_points.extend(to_file(to_handle(frame, p))
                              for p in scene.nodes[name]["positions"])
    whole_lo, whole_hi = bounds(gun_points)

    report = {"tool": TOOL_VERSION, "plan": plan["name"] if "name" in plan else args.plan,
              "source": os.path.basename(scene.path),
              "frame": {"right": [round(v, 8) for v in frame["right"]],
                        "up": [round(v, 8) for v in frame["up"]],
                        "forward": [round(v, 8) for v in frame["forward"]],
                        "sourceLength": frame["lengthSource"],
                        "studsPerSourceUnit": frame["studs"]},
              "nodes": report_nodes(scene, plan, frame),
              "wholeBoxFileAxes": {"min": [round(v, 6) for v in whole_lo],
                                   "max": [round(v, 6) for v in whole_hi],
                                   "size": [round(whole_hi[i] - whole_lo[i], 6) for i in range(3)],
                                   "centre": [round((whole_hi[i] + whole_lo[i]) / 2.0, 6)
                                              for i in range(3)]},
              "groups": []}
    os.makedirs(out_dir, exist_ok=True)
    for group in plan["groups"]:
        mesh = group_mesh(scene, plan, frames, group, whole_lo, whole_hi)
        folder = os.path.join(out_dir, group["name"])
        files = write_group(mesh, scene, folder, group["name"])
        own_lo, own_hi = bounds(mesh["positions"])
        report["groups"].append({
            "name": group["name"], "nodes": list(group["nodes"]),
            "triangles": len(mesh["triangles"]), "vertices": len(mesh["positions"]),
            "anchorTriangles": mesh["anchors"], "ownBox": bool(group.get("ownBox")),
            "ownFrame": bool(group.get("ownFrame")),
            "boxFileAxes": {"min": [round(v, 6) for v in own_lo],
                            "max": [round(v, 6) for v in own_hi],
                            "size": [round(own_hi[i] - own_lo[i], 6) for i in range(3)],
                            "centre": [round((own_hi[i] + own_lo[i]) / 2.0, 6) for i in range(3)]},
            "files": files, "folder": group["name"]})
        print("[split] %-8s %4d tris (+%d anchor) -> %s  size %s"
              % (group["name"], len(mesh["triangles"]), mesh["anchors"], folder,
                 [round(own_hi[i] - own_lo[i], 4) for i in range(3)]))
    after = digests(source_dir)
    if before != after:
        raise RuntimeError("the input folder changed during the run; it is read-only to this tool")
    report["sourceUnchanged"] = True
    report["sourceSha256"] = before
    with open(os.path.join(out_dir, "split-report.json"), "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
    print("[split] report %s" % os.path.join(out_dir, "split-report.json"))
    return 0


# ---------------------------------------------------------------- selftest


def selftest():
    """Offline, no input: every rule this tool rests on, proved on geometry it builds itself."""
    failures = []

    def check(name, ok, detail=""):
        print("[selftest] %-46s %s %s" % (name, "ok" if ok else "FAILED", detail))
        if not ok:
            failures.append(name)

    # 1. Jacobi finds the axes of a known, rotated, anisotropic cloud.
    axis = norm((1.0, 2.0, 3.0))
    other = norm(cross(axis, (0.0, 0.0, 1.0)))
    third = cross(axis, other)
    cloud = []
    for i in range(-10, 11):
        for j in (-1, 0, 1):
            for k in (-1, 0, 1):
                cloud.append(tuple(axis[d] * i * 1.0 + other[d] * j * 0.1 + third[d] * k * 0.01
                                   for d in range(3)))
    values = eigen3(covariance(cloud))
    check("Jacobi: strongest axis is the long one", abs(abs(dot(values[0][1], axis)) - 1.0) < 1e-6,
          "dot %.8f" % dot(values[0][1], axis))
    check("Jacobi: weakest axis is the thin one", abs(abs(dot(values[2][1], third)) - 1.0) < 1e-6,
          "dot %.8f" % dot(values[2][1], third))

    # 2. The inverse transpose is the matrix a NORMAL transforms by, and a SHEAR is the case that
    #    proves it: the plain matrix tilts the normal the wrong way, so a sheared face would be lit
    #    as if it faced somewhere it does not.
    shear = [[1.0, 0.0, 0.0], [0.7, 1.0, 0.0], [0.0, 0.0, 1.0]]
    #    The face y = 0 shears to y = 0.7x, whose true normal leans toward -x.
    right_way = norm(apply3(inverse_transpose3(shear), (0.0, 1.0, 0.0)))
    wrong_way = norm(apply3(shear, (0.0, 1.0, 0.0)))
    check("the inverse transpose leans the normal the right way", right_way[0] < -0.5,
          "%s" % (tuple(round(v, 4) for v in right_way),))
    check("the plain matrix leans it the wrong way", wrong_way[0] > -1e-9,
          "%s" % (tuple(round(v, 4) for v in wrong_way),))

    # 2b. END TO END, on a file this test writes: a MIRRORED node comes back with its winding
    #     reversed, because a mirror turns every triangle inside out and nothing else undoes that.
    import tempfile
    with tempfile.TemporaryDirectory() as temp:
        blob = bytearray()
        for point in ((0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)):
            blob.extend(struct.pack("<3f", *point))
        normals_at = len(blob)
        for _ in range(3):
            blob.extend(struct.pack("<3f", 0.0, 0.0, 1.0))
        indices_at = len(blob)
        blob.extend(struct.pack("<3I", 0, 1, 2))
        with open(os.path.join(temp, "scene.bin"), "wb") as handle:
            handle.write(bytes(blob))
        made = {}
        for name, flip in (("plain", 1.0), ("mirrored", -1.0)):
            doc = {
                "asset": {"version": "2.0"}, "scene": 0,
                "scenes": [{"nodes": [0]}],
                "nodes": [{"name": name, "children": [1]},
                          {"name": name + "_m_0", "mesh": 0,
                           "matrix": [flip, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]}],
                "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1},
                                            "indices": 2, "mode": 4}]}],
                "accessors": [
                    {"bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3"},
                    {"bufferView": 1, "componentType": 5126, "count": 3, "type": "VEC3"},
                    {"bufferView": 2, "componentType": 5125, "count": 3, "type": "SCALAR"}],
                "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": normals_at},
                                {"buffer": 0, "byteOffset": normals_at,
                                 "byteLength": indices_at - normals_at},
                                {"buffer": 0, "byteOffset": indices_at, "byteLength": 12}],
                "buffers": [{"uri": "scene.bin", "byteLength": len(blob)}],
            }
            path = os.path.join(temp, name + ".gltf")
            with open(path, "w", encoding="utf-8") as handle:
                json.dump(doc, handle)
            made[name] = Scene(path).nodes[name]
    check("a plain node keeps its winding", made["plain"]["triangles"] == [(0, 1, 2)]
          and not made["plain"]["mirrored"], "%s" % (made["plain"]["triangles"],))
    check("a mirrored node has its winding reversed", made["mirrored"]["triangles"] == [(0, 2, 1)]
          and made["mirrored"]["mirrored"], "%s" % (made["mirrored"]["triangles"],))

    # 3. The export turn is right-handed, so no winding is lost in it.
    basis = [to_file((1.0, 0.0, 0.0)), to_file((0.0, 1.0, 0.0)), to_file((0.0, 0.0, 1.0))]
    turn = [[basis[j][i] for j in range(3)] for i in range(3)]
    check("the export turn is right-handed (det +1)", abs(det3(turn) - 1.0) < 1e-12,
          "det %.6f" % det3(turn))
    check("the muzzle (handle -Z) comes out at the file's +X", to_file((0.0, 0.0, -1.0))[0] > 0.99)

    # 4. A plan that leaves a node out is REFUSED, and one that names a node twice is too.
    class FakeScene(object):
        def __init__(self, names):
            self.nodes = {n: {} for n in names}

    try:
        check_plan({"lengthStuds": 1, "boreUpStuds": 0, "axisFromNode": "a", "upTowardNode": "a",
                    "backTowardNode": "a", "anchorSize": 1e-4,
                    "groups": [{"name": "g", "nodes": ["a"]}]}, FakeScene(["a", "b"]))
        check("an unassigned node is refused", False)
    except Refused as why:
        check("an unassigned node is refused", "nobody assigned" in str(why))
    try:
        check_plan({"lengthStuds": 1, "boreUpStuds": 0, "axisFromNode": "a", "upTowardNode": "a",
                    "backTowardNode": "a", "anchorSize": 1e-4,
                    "groups": [{"name": "g", "nodes": ["a"]}, {"name": "h", "nodes": ["a"]}]},
                   FakeScene(["a"]))
        check("a node in two groups is refused", False)
    except Refused as why:
        check("a node in two groups is refused", "in two groups" in str(why))
    try:
        check_plan(load_plan("model-b"), FakeScene(["pasted__barrel"]))
        check("a plan whose nodes are missing is refused", False)
    except Refused as why:
        check("a plan whose nodes are missing is refused", "has not" in str(why))

    # 5. The shipped plan is a plan, and it drops exactly the duplicate shell.
    plan = check_plan(load_plan("model-b"))
    check("the model-b plan passes its own check", plan["name"] == "model-b")
    check("the model-b plan drops only the duplicate shell",
          plan["dropNodes"] == ["shell_low.001"], "%s" % (plan["dropNodes"],))
    check("the barrel group carries the forend",
          "pasted__base_upper" in plan["groups"][0]["nodes"])

    # 6. `to_handle` puts the muzzle at -length/2 and the bore line at `boreUpStuds` -- on a synthetic
    #    gun built in a TILTED frame, which is the case the real file is.
    frame = {"right": (0.0, 0.0, 1.0), "up": (1.0, 0.0, 0.0), "forward": (0.0, -1.0, 0.0),
             "studs": 2.0, "origin": (0.0, 0.0, 0.0), "shift": (0.0, 0.12, -2.0)}
    at_muzzle = to_handle(frame, (0.0, 0.0, 0.0))
    check("the muzzle lands at -length/2", abs(at_muzzle[2] + 2.0) < 1e-12, "%s" % (at_muzzle,))
    check("the bore line lands at boreUpStuds", abs(at_muzzle[1] - 0.12) < 1e-12)
    behind = to_handle(frame, (0.0, 1.0, 0.0))
    check("a point behind the muzzle has a greater Z", behind[2] > at_muzzle[2],
          "%.4f > %.4f" % (behind[2], at_muzzle[2]))

    print("[selftest] %s" % ("all ok" if not failures else "FAILED: " + ", ".join(failures)))
    return 0 if not failures else 1


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    probe = sub.add_parser("probe")
    probe.add_argument("--in", dest="folder", required=True)
    probe.add_argument("--plan", default="model-b")
    run = sub.add_parser("split")
    run.add_argument("--in", dest="folder", required=True)
    run.add_argument("--out", required=True)
    run.add_argument("--plan", default="model-b")
    show = sub.add_parser("plan")
    show.add_argument("--plan", default="model-b")
    sub.add_parser("selftest")
    args = parser.parse_args(argv)
    try:
        if args.command == "probe":
            return cmd_probe(args)
        if args.command == "split":
            return cmd_split(args)
        if args.command == "plan":
            print(json.dumps(check_plan(load_plan(args.plan)), indent=2))
            return 0
        return selftest()
    except Refused as why:
        print("[split] REFUSED: %s" % why)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
