"""Driven Hunt terrain bake driver. It invokes ServerStorage.TerrainBake in the FOREST TEST's EDIT
session, one tile per MCP call, and it is NOT part of the test harness: the harness never bakes, and
this tool never runs specs.

Pattern: `tools/mapgen.py`, with one change the design forces. Everything about talking to Studio --
Studio, git_state, synced_nodes, compare_synced, studio_for_place, runs_dir -- is IMPORTED from
tools/studio_mcp.py rather than copied, so there is one MCP client in the repo and one definition of
"Studio's copy matches disk".

IT INJECTS THE TREE'S OWN TEXT, and that is a MEASURED DEVIATION from design section 3, which
rules that this tool requires (Director decision 2, 2026-11-02, ESCALATE.md). Why: in Karen's Forest
Test EDIT session every one of 297 script instances reads `Source` length 0 through StudioMCP's
execute_luau and `require` of any of them fails with "Module code did not return exactly one value",
while the same probe in DEV reads 27,750 characters and requires fine -- and in that SAME place's
PLAY server it also requires fine. So section 3's parentless-clone load cannot load anything there,
and `check_synced` (a `Source` comparison) can only ever refuse, however recently Connect was
pressed. `tools/forest_ground.py` already injects (rule 2, borrowed), and it works for a reason
section 3 did not have: it sends the TEXT, so it needs neither `require` nor `Source`.

WHAT REPLACES `check_synced` (refusal 4). The tree must be clean, so the text has a commit; the tool
prints the sha256 of every injected file beside that commit; and before any other call the arrived
code ECHOES BACK the constants it itself defines (TILE_STUDS, MAX_VOXELS, PLACE_ID, ROAD_HALF_STUDS,
VOXEL, BLEND_STUDS, BAKE_VERSION, the cell count, the road count, originX, cellDepthStuds), which are
compared with the same constants read off the files. Luau has no sha256 and `loadstring` is disabled
in Roblox, so Studio cannot digest its own injected text: what the echo proves is that the code that
RAN defines the numbers the files define at this commit, and the printed sha256s say which bytes
were sent. That is stated plainly rather than described as a hash computed inside Studio.

Three modules are injected -- `Grid/Relief.luau`, `Grid/init.luau` and `TerrainBake/init.luau`, in
dependency order, each require rewritten to the local above it and every rewrite asserted to match
exactly once (a require left in place would hang the MCP call on `WaitForChild` with no reason
given). `Shotgun` is 61 KB and `Grid` reads ONE value out of it, so it is a stub carrying that value
read off the Shotgun file; the selftest fails if `Grid` ever reads a second field.

THE LONG PROFILES ARE COMPUTED ONCE, by this tool, before the first write, and the SAME bytes go to
every tile. A profile read per tile would be read off ground the bake had already written, so two
tiles of one road could meet at a step and the result would depend on the tile order; `bakeTileAt`
REFUSES a tile that arrives without profiles rather than making its own.

THE BASE IS A FILE, NOT THE GROUND (task 328k; design 5.3 step 2, B2). `snapshot` reads the ORIGINAL
ground ONCE, in chunks that fit ReadVoxels' 4,194,304-voxel ceiling, into
`<runs-dir>/terrain-base-<sha>.bin` -- int16 at 1/64 of a stud in a fixed frame, so two reads of the
same ground are the same bytes and the same sha256. Every later command reads the BASE from that
file: the tool cuts each tile's slice out of it and sends it, and it reads the few thousand
centreline points the long profiles need and sends those as a `pointSampler`. `bakeTileAt` refuses a
tile with no slice and `profilesFor` refuses to run with no sampler, so neither half can fall back to
live terrain. Before this existed both halves raycast LIVE ground, so a second bake read its own
first bake: C1's `lineMeanY` went 108.88 -> 112.83 -> 114.81 over three bakes, ~+2 studs a run
(ESCALATE.md, task 328e), and `reshapeWanted` could stop the LANDFORM going in twice but nothing
could stop the ROAD from climbing. A column with no single height -- Water, an overhang, no ground in
the band -- is recorded as a HOLE with its reason, and any tile whose own columns hold one is
REFUSED, never guessed.

Usage:
  python tools/terrainbake.py plan    [--cells C1]                      # read-only: tiles + the cost estimate
  python tools/terrainbake.py snapshot [--cells C1] [--out <file>] [--source <note>]
                                                                        # read-only: the base, to a .bin OUTSIDE the repo
  python tools/terrainbake.py diff    --cells C1 --base <f>.bin --base-sha <sha> [--tiles 12]
                                                                        # read-only DRY RUN: what a bake WOULD write,
                                                                        # against the ground that is there now, snapshot
                                                                        # route vs the old live route. Writes nothing.
  python tools/terrainbake.py measure --cells C1 --base <f>.bin --base-sha <sha> [--tiles 10]
                                                                        # read-only: per-tile cost, DRY (no WriteVoxels)
  python tools/terrainbake.py bake    --cells C1 --backup <f>.rbxl --base <f>.bin --base-sha <sha> [--tiles 10]
  python tools/terrainbake.py survey  [--cells C1]                      # read-only: the relief rows
  python tools/terrainbake.py archive --cells C1 --backup <f>.rbxl      # B3, Parent only
  python tools/terrainbake.py census                                    # read-only
  python tools/terrainbake.py selftest                                  # no Studio, no network; CI

Exit codes, deliberately the harness's shape: 0 done | 1 a step failed | 2 REFUSED.

WHAT IT REFUSES, BEFORE IT TOUCHES ANYTHING (design section 6.2):
  1. Studio is not in Edit mode. Karen may be playing.
  2. game.PlaceId is not 130094961655666 -- asked of EVERY connected Studio, BY PLACE ID and never
     by name (lesson L-055), and asked again immediately before every mutating call, not once per
     run (B1): a bake is ~70 minutes of calls and the operator can open another place inside it.
  3. A dirty tree, for any mutating command. A world baked from uncommitted code cannot be
     reproduced from a commit -- the harness's exit code 3 rule.
  4. Studio's copy of ServerStorage.TerrainBake, ReplicatedStorage.Grid or ReplicatedStorage.Places
     differs from disk. Catches "nobody pressed Connect".
  5. No usable --backup: an existing, non-empty .rbxl OUTSIDE the repository, modified within
     BACKUP_MAX_AGE_HOURS. `--backup census` is NOT accepted, because Karen's place is full of
     hand-made content a census cannot stand in for.
  6. --cells missing on bake/archive. There is no default: an unnamed cell is an unbounded run.
  7b. A named cell's ground already carries a DIFFERENT landform (`TerrainBake.reshapeWanted`
     answers "changed"). A bake ADDS its ops, so the fix is the backup, not another bake.
  7. A flag or pose override is live -- the rule `test` and `test2` already enforce. EXCEPT the two
     Karen has set on purpose in the Forest Test (GRID_PREVIEW, RANGE_SOLO): the dispatch says leave
     them, and clearing them would destroy her setup (lesson K).
  9. NO BASE SNAPSHOT, for `bake`, `measure` and `diff`: `--base` must name an existing `.bin`
     OUTSIDE the repository whose own sha256 is the one `--base-sha` names, and whose lattice covers
     this run's region. The sha is required and compared because a snapshot taken AFTER a bake is the
     one mistake that looks like success. The EPOCH hashes that sha and never the git sha
     (design 5.4; task 328e note c).

The one pasteable report line:

  [bake] OK: 10/10 tiles @ <sha> cells=C1 epoch=<16 hex> worstTileMs=<n> (clean tree)
  [bake] REFUSED: <reason>

Every run appends its per-tile reports to .terrainbake/<utc>-<cells>.json (git-ignored).
"""

import argparse
import array
import base64
import hashlib
import json
import math
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from studio_mcp import (  # noqa: E402  (the path insert above has to come first)
    REPO,
    Studio,
    compare_synced,
    flag_overrides,
    git_state,
    place_choice,
    pose_override,
    runs_dir,
    synced_nodes,
)

# One MCP call per tile against a per-tile design target of 8 s (UNMEASURED: design 12.2, and this
# task measures it). _rpc's own default is 120 s; a whole-cell run in one call would exceed it, and
# chunking also makes a failed tile name itself.
BAKE_CALL_TIMEOUT = 300
BACKUP_MAX_AGE_HOURS = 6
RUN_LOG_DIR = os.path.join(REPO, ".terrainbake")
FOREST_PLACE_ID = place_choice("forest")[0]

# The nodes whose Studio copy must equal disk before any mutating call (design 3 item 2).
SYNCED_HEADS = ("ServerStorage.TerrainBake", "ReplicatedStorage.Grid", "ServerScriptService.Places")

# Karen's own overrides in the Forest Test. The dispatch says leave them; refusal 7 is about an
# override a BUILDER left behind, not about her playtest setup (lesson K).
KARENS_FLAGS = ("GRID_PREVIEW", "RANGE_SOLO")

# The tile and the voxel ceiling, read off the Luau rather than retyped, so there is one fact.
BAKE_LUAU = os.path.join(REPO, "src", "serverstorage", "TerrainBake", "init.luau")
RELIEF_LUAU = os.path.join(REPO, "src", "shared", "Grid", "Relief.luau")
GRID_LUAU = os.path.join(REPO, "src", "shared", "Grid", "init.luau")


def number_from(path, pattern):
    """One number out of a Luau file, by regex. Off the FILE, never retyped here."""
    with open(path, "r", encoding="utf-8") as handle:
        found = re.search(pattern, handle.read(), re.M)
    if not found:
        raise RuntimeError("%s: %s is not in the file" % (os.path.relpath(path, REPO), pattern))
    return float(found.group(1).replace("_", ""))


def luau_facts():
    """Every number this tool asserts against, read off the three Luau files. No second copy."""
    return {
        "tile": int(number_from(BAKE_LUAU, r"^TerrainBake\.TILE_STUDS = ([0-9_]+)")),
        "maxVoxels": int(number_from(BAKE_LUAU, r"^TerrainBake\.MAX_VOXELS = ([0-9_]+)")),
        "roadHalf": int(number_from(BAKE_LUAU, r"^TerrainBake\.ROAD_HALF_STUDS = ([0-9_]+)")),
        "blend": int(number_from(RELIEF_LUAU, r"^Relief\.BLEND_STUDS = ([0-9_]+)")),
        "voxel": int(number_from(RELIEF_LUAU, r"^Relief\.VOXEL = ([0-9_]+)")),
        "originX": int(number_from(GRID_LUAU, r"^\toriginX = (-?[0-9_]+)")),
        "originZ": int(number_from(GRID_LUAU, r"^\toriginZ = (-?[0-9_]+)")),
        "cellWidth": int(number_from(GRID_LUAU, r"^\tcellWidthStuds = ([0-9_]+)")),
        "cellDepth": int(number_from(GRID_LUAU, r"^\tcellDepthStuds = ([0-9_]+)")),
        "roadClear": int(number_from(GRID_LUAU, r"^\troadClearStuds = ([0-9_]+)")),
        "rows": int(number_from(GRID_LUAU, r"^\trows = ([0-9_]+)")),
        "columns": int(number_from(GRID_LUAU, r"^\tcolumns = ([0-9_]+)")),
    }


# ---------------------------------------------------------------- the arithmetic `plan` asserts

CELL_IDS = ("A1", "B1", "C1", "D1", "A2", "B2", "C2", "D2")
BORDER_WOOD_STUDS = 230

# THE TILE COUNTS, COMMITTED (Director decision 6). Round 1 "asserted" `ceil(a/b)` against
# `-(-a//b)`, which is one value compared with itself: the branch was dead for every input. These
# are the counts as they stand, so a change to `region_for`, to `Grid.CONFIG` or to the tile size
# reddens the line and somebody has to say the new number out loud.
# THE COUNT IS LATTICE-PHASE DEPENDENT, NOT WIDTH DEPENDENT. Round 2 wrote 208 for all eight on the
# assumption that equal cells tile equally; they do not, and `plan --cells A1` then REFUSED a correct
# region (round-2 finding 3). Re-derived from this file's own `region_for`/`tile_count`, and the
# selftest checks a second cell as well as C1 so one right number cannot cover seven wrong ones.
#   A1 14x16=224  B1 224  C1 13x16=208  D1 224   |   A2 14x17=238  B2 238  C2 13x17=221  D2 238
# C-column cells are 13 wide because their region starts just inside a lattice line; row 2 is 17 deep
# for the same reason. ALL is 43x31 and is NOT the sum of the eight (the regions overlap).
EXPECTED_TILES = {
    "A1": 224, "B1": 224, "C1": 208, "D1": 224,
    "A2": 238, "B2": 238, "C2": 221, "D2": 238,
    "ALL": 1333,
}


def cell_of(cell_id, facts):
    """One cell's interior bounds, by `Grid.boundsOf`'s own arithmetic, in Python (Director 6)."""
    column = "ABCD".index(cell_id[0]) + 1
    row = int(cell_id[1])
    rows_from_south = facts["rows"] - row
    min_x = facts["originX"] + facts["roadClear"] + (column - 1) * (facts["cellWidth"] + facts["roadClear"])
    min_z = facts["originZ"] + facts["roadClear"] + rows_from_south * (facts["cellDepth"] + facts["roadClear"])
    return {"minX": min_x, "maxX": min_x + facts["cellWidth"],
            "minZ": min_z, "maxZ": min_z + facts["cellDepth"]}


def roads_of(cell_id, facts):
    """The four road centrelines that bound one cell, by `Grid.roadsOf`'s arithmetic."""
    column = "ABCD".index(cell_id[0]) + 1
    row = int(cell_id[1])
    half = facts["roadClear"] / 2
    rows_from_south = facts["rows"] - row
    return {
        "main": facts["originZ"] + half + rows_from_south * (facts["cellDepth"] + facts["roadClear"]),
        "muster": facts["originZ"] + half + (rows_from_south + 1) * (facts["cellDepth"] + facts["roadClear"]),
        "west": facts["originX"] + half + (column - 1) * (facts["cellWidth"] + facts["roadClear"]),
        "east": facts["originX"] + half + column * (facts["cellWidth"] + facts["roadClear"]),
    }


def footprint(facts):
    return {
        "minX": facts["originX"],
        "maxX": facts["originX"] + facts["columns"] * facts["cellWidth"] + (facts["columns"] + 1) * facts["roadClear"],
        "minZ": facts["originZ"],
        "maxZ": facts["originZ"] + facts["rows"] * facts["cellDepth"] + (facts["rows"] + 1) * facts["roadClear"],
    }


def region_for(cells, facts):
    """`TerrainBake.regionFor`'s arithmetic, independently in Python. The two must agree."""
    if len(cells) == len(CELL_IDS):
        box = footprint(facts)
        pad = facts["blend"] + BORDER_WOOD_STUDS
        return {"minX": box["minX"] - pad, "maxX": box["maxX"] + pad,
                "minZ": box["minZ"] - pad, "maxZ": box["maxZ"] + pad}
    min_x, max_x, min_z, max_z = None, None, None, None
    for cell_id in cells:
        cell, roads = cell_of(cell_id, facts), roads_of(cell_id, facts)
        half = facts["roadHalf"]
        lows = [cell["minX"], roads["west"] - half]
        highs = [cell["maxX"], roads["east"] + half]
        min_x = min([min_x] + lows) if min_x is not None else min(lows)
        max_x = max([max_x] + highs) if max_x is not None else max(highs)
        lows = [cell["minZ"], roads["main"] - half]
        highs = [cell["maxZ"], roads["muster"] + half]
        min_z = min([min_z] + lows) if min_z is not None else min(lows)
        max_z = max([max_z] + highs) if max_z is not None else max(highs)
    pad = facts["blend"]
    return {"minX": min_x - pad, "maxX": max_x + pad, "minZ": min_z - pad, "maxZ": max_z + pad}


def tile_count(region, tile):
    """`Relief.tiles`' own count: the lattice expanded OUTWARD, floor of the low corner."""
    x0 = tile * math.floor(region["minX"] / tile)
    z0 = tile * math.floor(region["minZ"] / tile)
    nx = max(0, math.ceil((region["maxX"] - x0) / tile))
    nz = max(0, math.ceil((region["maxZ"] - z0) / tile))
    return nx * nz, nx, nz, x0, z0


# ---------------------------------------------------------------- the base snapshot FILE (B2)

# `<runs-dir>/terrain-base-<sha>.bin`: magic, one JSON header line, then int16 little-endian codes,
# one per column, row-major with x fastest -- `TerrainBake.readerFor`'s own index. The codes ARE the
# bytes the Luau encoder produced, so a slice is a byte slice and nothing is re-quantised; two reads
# of the same ground give the same file, which is what `snapshot` twice proves.
BASE_MAGIC = b"DHTB1\n"
SLICE_SCALE = 64
SLICE_OFFSET = -256

# ReadVoxels' ceiling is 4,194,304 voxels. A 512-stud chunk is 128 x 128 = 16,384 columns, and a
# 500-stud Y band is 125 voxels deep: 2.05 M, inside it with room for a deeper band.
SNAPSHOT_CHUNK_STUDS = 512


def _sliced(codes):
    """The int16 array as little-endian bytes, whatever this machine's byte order is."""
    blob = array.array("h", codes)
    if sys.byteorder != "little":
        blob.byteswap()
    return blob.tobytes()


def base_save(path, header, codes, holes):
    """Write the .bin and answer its sha256. The sha is of the WHOLE file, header included."""
    head = dict(header)
    head["holes"] = sorted(int(h) for h in holes)
    head["scale"], head["offset"] = SLICE_SCALE, SLICE_OFFSET
    body = (BASE_MAGIC
            + json.dumps(head, sort_keys=True, separators=(",", ":")).encode("utf-8") + b"\n"
            + _sliced(codes))
    with open(path, "wb") as handle:
        handle.write(body)
    return hashlib.sha256(body).hexdigest()


def base_load(path):
    """The .bin back, with its own sha256. Raises on anything it cannot read as one."""
    with open(path, "rb") as handle:
        body = handle.read()
    if not body.startswith(BASE_MAGIC):
        raise ValueError("%s is not a base snapshot (no %r magic)" % (path, BASE_MAGIC))
    end = body.index(b"\n", len(BASE_MAGIC))
    header = json.loads(body[len(BASE_MAGIC):end].decode("utf-8"))
    blob = array.array("h")
    blob.frombytes(body[end + 1:])
    if sys.byteorder != "little":
        blob.byteswap()
    want = header["nx"] * header["nz"]
    if len(blob) != want:
        raise ValueError("%s holds %d codes, not the %d its header names" % (path, len(blob), want))
    return {"header": header, "codes": blob, "holes": set(header.get("holes", [])),
            "sha": hashlib.sha256(body).hexdigest()}


def base_index(base, x, z):
    """`TerrainBake.readerFor`'s index, in Python: 1-based, or None outside the snapshot."""
    head = base["header"]
    i = int(math.floor((x - head["minX"]) / head["pitch"])) + 1
    k = int(math.floor((z - head["minZ"]) / head["pitch"])) + 1
    if i < 1 or k < 1 or i > head["nx"] or k > head["nz"]:
        return None
    return (k - 1) * head["nx"] + i


def base_at(base, x, z):
    """The base height at a point, or None outside the snapshot or at a hole."""
    at = base_index(base, x, z)
    if at is None or at in base["holes"]:
        return None
    return SLICE_OFFSET + base["codes"][at - 1] / SLICE_SCALE


def base_slice(base, min_x, min_z, max_x, max_z):
    """One tile's slice of the base, as the payload `TerrainBake.decodeSlice` takes.

    It is a BYTE SLICE of the stored codes -- no arithmetic on the heights at all -- so the slice a
    tile shapes from is the same base, to the bit, on every run and in every cell list.
    """
    head = base["header"]
    pitch = head["pitch"]
    i0 = int(math.floor((min_x - head["minX"]) / pitch)) + 1
    k0 = int(math.floor((min_z - head["minZ"]) / pitch)) + 1
    i1 = int(math.ceil((max_x - head["minX"]) / pitch))
    k1 = int(math.ceil((max_z - head["minZ"]) / pitch))
    if i0 < 1 or k0 < 1 or i1 > head["nx"] or k1 > head["nz"]:
        return None, ("the base snapshot x[%g,%g] z[%g,%g] does not cover x[%g,%g] z[%g,%g]"
                      % (head["minX"], head["minX"] + head["nx"] * pitch,
                         head["minZ"], head["minZ"] + head["nz"] * pitch,
                         min_x, max_x, min_z, max_z))
    nx, nz = i1 - i0 + 1, k1 - k0 + 1
    codes = array.array("h", [0]) * (nx * nz)
    holes = []
    for k in range(nz):
        src = (k0 - 1 + k) * head["nx"] + i0 - 1
        codes[k * nx:(k + 1) * nx] = base["codes"][src:src + nx]
        for i in range(nx):
            if src + i + 1 in base["holes"]:
                holes.append(k * nx + i + 1)
    return {
        "pitch": pitch,
        "minX": head["minX"] + (i0 - 1) * pitch,
        "minZ": head["minZ"] + (k0 - 1) * pitch,
        "nx": nx,
        "nz": nz,
        "scale": SLICE_SCALE,
        "offset": SLICE_OFFSET,
        "holes": holes,
        "b64": base64.b64encode(_sliced(codes)).decode("ascii"),
    }, None


# ONE SLICE, ENCODED, THAT BOTH SIDES CHECK. `tests/server/grid_relief.spec.luau` decodes this same
# string with `TerrainBake.decodeSlice` and asserts these same heights, so the Luau decoder and this
# encoder are each checked against committed bytes rather than against each other's good intentions.
SLICE_FIXTURE_HEIGHTS = [100.0, 100.5, 101.25, 99.0, 98.75, 100.0]
SLICE_FIXTURE_B64 = "AFkgWVBZwFiwWABZ"


def reshape_blocked(answers):
    """REFUSAL 7b, as a decision over `TerrainBake.reshapeWanted`'s answers, so it has a case.

    `answers` is {cell: kind}. "changed" means that cell's ground already carries a DIFFERENT
    landform, and a bake ADDS its ops rather than replacing them -- measured at +24.04 studs of
    second ridge on C1, 2026-11-02. The fix is the backup, not another bake.
    """
    blocked = sorted(cell for cell, kind in answers.items() if kind == "changed")
    if not blocked:
        return None
    return ("%s already carr%s a DIFFERENT landform in the ground, and a bake ADDS its ops "
            "rather than replacing them (measured: +24.04 studs of second ridge on C1, "
            "2026-11-02). Restore the backup .rbxl and bake again."
            % (", ".join(blocked), "ies" if len(blocked) == 1 else "y"))


def check_base(args, region):
    """REFUSAL 9: no base snapshot, or one whose sha256 is not the one named, or one that does not
    cover this run's region.

    This is B2's whole point. Without it `bakeTileAt` read the base LIVE, per tile, so a second bake
    read its own first bake: `lineMeanY` went 108.88 -> 112.83 -> 114.81 over three bakes of C1
    (ESCALATE.md, task 328e) and no re-run could ever be a no-op. The sha is REQUIRED and compared,
    because a snapshot taken AFTER a bake is the one mistake that looks like success.
    """
    path = args.base
    if not path:
        return None, ("--base is missing: the bake reads the ORIGINAL ground from "
                      "<runs-dir>/terrain-base-<sha>.bin, never live terrain (design 5.3 step 2)")
    if not args.base_sha:
        return None, "--base-sha is missing: an unchecked snapshot file is not evidence of the base"
    if os.path.commonpath([os.path.abspath(path), REPO]) == REPO:
        return None, "the base snapshot must live OUTSIDE the repository: %s" % path
    if not os.path.isfile(path):
        return None, "no base snapshot at %s" % path
    try:
        base = base_load(path)
    except Exception as problem:  # noqa: BLE001 -- the reason IS the refusal
        return None, str(problem)
    if base["sha"] != args.base_sha:
        return None, ("the base snapshot's sha256 is %s, not the %s named by --base-sha: this is a "
                      "DIFFERENT base, and a bake off the wrong base cannot be reproduced"
                      % (base["sha"], args.base_sha))
    head = base["header"]
    pitch = head["pitch"]
    if (head["minX"] > region["minX"] or head["minZ"] > region["minZ"]
            or head["minX"] + head["nx"] * pitch < region["maxX"]
            or head["minZ"] + head["nz"] * pitch < region["maxZ"]):
        return None, ("the base snapshot covers x[%g,%g] z[%g,%g], which does not hold this run's "
                      "region x[%g,%g] z[%g,%g]"
                      % (head["minX"], head["minX"] + head["nx"] * pitch,
                         head["minZ"], head["minZ"] + head["nz"] * pitch,
                         region["minX"], region["maxX"], region["minZ"], region["maxZ"]))
    return base, None


# ---------------------------------------------------------------- canonical JSON

def canonical(value):
    """`Relief.canonical` in Python: keys sorted, numbers %.6g, no whitespace (design 5.4).

    It exists so the selftest can check the Luau encoder against a second implementation, which is
    what design 6.4 asks of this tool. The epoch itself is still hashed from the LUAU string --
    this is the check, never the source.
    """
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return "%.6g" % value
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, (list, tuple)):
        return "[" + ",".join(canonical(v) for v in value) + "]"
    if isinstance(value, dict):
        return "{" + ",".join("%s:%s" % (json.dumps(str(k)), canonical(value[k]))
                              for k in sorted(value, key=str)) + "}"
    raise RuntimeError("cannot encode %s" % type(value).__name__)


# CAPTURED FROM THE LUAU, 2026-11-02, by running `Relief.epochInput` on this exact input in DEV
# (<runs-dir>/328d-epoch.luau). If the two encoders ever disagree, this string is what says so.
CANONICAL_FIXTURE_INPUT = {
    "bakeVersion": 1,
    "config": {"cellDepthStuds": 1430, "cellWidthStuds": 1070, "columns": 4,
               "originX": -6700, "originZ": -6600, "roadClearStuds": 42, "rows": 2},
    "landforms": {"Z1": {"baseKeep": 0.5,
                         "floor": {"default": "Ground", "mudDepthStuds": 6},
                         "ops": [{"dyStuds": -2.5, "kind": "dome", "rStuds": 10, "u": 0.25, "v": 0.75}]}},
}
CANONICAL_FIXTURE_OUTPUT = (
    '{"bakeVersion":1,"config":{"cellDepthStuds":1430,"cellWidthStuds":1070,"columns":4,'
    '"originX":-6700,"originZ":-6600,"roadClearStuds":42,"rows":2},"landforms":{"Z1":'
    '{"baseKeep":0.5,"floor":{"default":"Ground","mudDepthStuds":6},"ops":'
    '[{"dyStuds":-2.5,"kind":"dome","rStuds":10,"u":0.25,"v":0.75}]}}}'
)


# ---------------------------------------------------------------- the Luau this tool sends

# IT INJECTS THE TREE'S OWN TEXT (Director decision 2, 2026-11-02, ESCALATE.md -- a measured
# deviation from design section 3, which rules that this tool requires). In Karen's Forest Test EDIT
# session every one of 297 scripts reads `Source` length 0 through execute_luau and `require` of any
# of them fails, while the same probe in DEV reads the file: so section 3's parentless-clone load
# cannot load anything there and `check_synced` (a Source comparison) can only ever refuse. The same
# pattern as `tools/forest_ground.py` (rule 2), which works for a reason section 3 did not have: it
# sends the TEXT, so it needs neither `require` nor `Source`.
#
# WHAT REPLACES `check_synced`: the tree must be clean (refusal 3), the tool prints the sha256 of
# every injected file with the commit, and the first line of every run ECHOES, from inside Studio,
# the constants the arrived code itself defines -- compared against the same constants read off the
# files. Luau has no sha256 and `loadstring` is disabled, so Studio cannot digest its own injected
# text; what the echo proves is that the code that RAN is code whose own numbers match the files at
# this commit, and the sha256s say which bytes those were. That is said plainly rather than claimed
# as a hash computed in Studio.
MODULES = (
    ("Relief", os.path.join(REPO, "src", "shared", "Grid", "Relief.luau")),
    ("Grid", os.path.join(REPO, "src", "shared", "Grid", "init.luau")),
    ("TerrainBake", BAKE_LUAU),
)
SHOTGUN_LUAU = os.path.join(REPO, "src", "shared", "Shotgun", "init.luau")

# THE REQUIRES THE INJECTION REWRITES, one entry per line that must go, and each MUST match exactly
# once or the tool refuses before it sends anything. An unrewritten `WaitForChild` would hang the
# MCP call until its timeout with no reason given (measured 2026-11-02).
REWRITES = {
    "Grid": [
        ('local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))',
         "local Shotgun = INJECTED_Shotgun"),
    ],
    "TerrainBake": [
        ('local GridFolder = ReplicatedStorage:WaitForChild("Grid")', "local GridFolder = nil"),
        ("local Grid = require(GridFolder)", "local Grid = INJECTED_Grid"),
        ('local Relief = require(GridFolder:WaitForChild("Relief"))', "local Relief = INJECTED_Relief"),
    ],
}

# `Grid` READS EXACTLY ONE THING OUT OF `Shotgun` (the slug's range, for section 7's stand spacing),
# and Shotgun is 61 KB that would ride on all 208 calls. So it is stubbed with that number READ OFF
# THE SHOTGUN FILE, never retyped, and the selftest asserts that one access is still Grid's only one.
SHOTGUN_ACCESS = "Shotgun.CONFIG.RANGE_STUDS.Slug"
SHOTGUN_STUB = """local INJECTED_Shotgun = setmetatable({ CONFIG = { RANGE_STUDS = { Slug = %g } } }, {
    __index = function(_, key)
        error("the injected Shotgun stub holds only CONFIG.RANGE_STUDS.Slug, not " .. tostring(key), 0)
    end,
})"""


def module_text(name, path):
    """One module's own text, ready to be an expression. `--!` and `export type` are module-scope
    only in Luau and this ends up in a function body, so those two are rewritten and NOTHING else is
    -- except the requires in REWRITES, each asserted to match exactly once."""
    with open(path, "r", encoding="utf-8") as handle:
        text = handle.read()
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
    for old, new in REWRITES.get(name, ()):
        if text.count(old) != 1:
            raise RuntimeError(
                "tools/terrainbake.py: %s holds %d copies of %r, not 1. The injection rewrites that "
                "line; an unrewritten require would hang the MCP call. Fix REWRITES."
                % (os.path.relpath(path, REPO), text.count(old), old)
            )
        text = text.replace(old, new)
    body = chr(10).join(line for line in text.splitlines() if not line.startswith("--!"))
    return "(function()" + chr(10) + body.replace("export type ", "type ") + chr(10) + "end)()", digest


def shotgun_slug_range():
    """`Shotgun.CONFIG.RANGE_STUDS.Slug`, off the Shotgun file. One fact, not a second copy."""
    return number_from(SHOTGUN_LUAU, r"Slug = ([0-9_.]+)")


def prelude():
    """(luau, {name: sha256}) -- the three modules as locals, in dependency order."""
    parts = [SHOTGUN_STUB % shotgun_slug_range()]
    shas = {"Shotgun": hashlib.sha256(open(SHOTGUN_LUAU, "rb").read()).hexdigest()}
    for name, path in MODULES:
        text, digest = module_text(name, path)
        parts.append("local INJECTED_%s = %s" % (name, text))
        shas[name] = digest
    parts.append("local Relief, Grid, TerrainBake = INJECTED_Relief, INJECTED_Grid, INJECTED_TerrainBake")
    return chr(10).join(parts), shas


# THE ECHO: what the arrived code says about itself, measured inside Studio and compared with the
# same numbers read off the files by `luau_facts` (design 6.2 item 4's replacement).
ECHO_EXPRESSION = """{
        tile = TerrainBake.TILE_STUDS,
        maxVoxels = TerrainBake.MAX_VOXELS,
        placeId = TerrainBake.PLACE_ID,
        roadHalf = TerrainBake.ROAD_HALF_STUDS,
        voxel = Relief.VOXEL,
        blend = Relief.BLEND_STUDS,
        bakeVersion = Relief.BAKE_VERSION,
        cells = #Grid.cellIds(),
        originX = Grid.CONFIG.originX,
        cellDepth = Grid.CONFIG.cellDepthStuds,
        roads = #Grid.roads(),
    }"""

CALL_TEMPLATE = """
local HttpService = game:GetService("HttpService")
local ok, result = pcall(function()
%s
    return %s
end)
if not ok then
    return HttpService:JSONEncode({ error = tostring(result) })
end
return HttpService:JSONEncode(result)
"""

PLACE_QUERY = 'return tostring(game.PlaceId)'
# The place AND the DataModel's name in one read -- `studio_mcp`'s own query, imported in
# substance so there is one wire format. The name is what tells a re-opened backup .rbxl from
# Karen's live window: both report the same place id (task 328k).
QUERY_PLACE_AND_NAME = 'return tostring(game.PlaceId) .. "|" .. tostring(game.Name)'


def parse_json(body):
    """The JSON value inside StudioMCP's reply text, which may carry a line of its own around it.

    A reply can be a STRING as well as an object or an array -- `epochInputFor` answers one -- and a
    string that holds a brace cannot be found by looking for the brace. So `{`, `[` and `"` are all
    tried, in the order they appear, and the one that CONSUMES THE WHOLE REPLY wins -- neither
    ordering alone is right. By position only, a preamble holding a quote decodes to that quoted word
    instead of the JSON behind it; by type only, `[{"a": 1}]` decodes to its first element. Falling
    back to the earliest that decodes at all keeps a reply with a trailing line readable.
    Measured: the first wet bake in Karen's place wrote all 208 tiles and then died here, because the
    epoch input string carries the landform digest's own braces (2026-11-02 18:12 UTC).
    """
    starts = [i for i in (body.find("{"), body.find("["), body.find('"')) if i >= 0]
    # A BARE SCALAR IS A JSON VALUE TOO. `stampShape` answers a NUMBER and this looked only for the
    # three container openers, so a reply of "1" raised "no JSON in Studio's reply" AFTER all 208
    # tiles had been written -- the same shape, in the same function, that cost 328j its epoch line
    # (TASKS.md 328j-notes (d)). Measured 2026-11-02 20:16 UTC in Karen's Forest Test.
    starts += [m.start() for m in re.finditer(r"(?m)^[ \t]*(-?\d|true\b|false\b|null\b)", body)]
    decoded = []
    for start in sorted(set(starts)):
        try:
            value, end = json.JSONDecoder().raw_decode(body[start:])
        except ValueError:
            continue
        decoded.append((value, body[start + end:].strip() == ""))
    for value, whole in decoded:
        if whole:
            return value
    # THE FALLBACK PREFERS A CONTAINER. With bare scalars among the candidates, a preamble line that
    # starts with a digit would otherwise win over the object behind it (Reviewer, round 1, note 6).
    for value, _ in decoded:
        if isinstance(value, (dict, list)):
            return value
    if decoded:
        return decoded[0][0]
    raise RuntimeError("no JSON in Studio's reply: %s" % body[:400])


def call(studio, studio_id, expression, timeout=BAKE_CALL_TIMEOUT, injected=None):
    """Run one TerrainBake expression in the addressed Edit DataModel and parse its JSON reply.

    `injected` is the prelude, built ONCE per run and reused, so every call of a run carries exactly
    the same bytes of module text -- which is also what makes two tiles of one road agree.
    """
    code = CALL_TEMPLATE % (injected if injected is not None else prelude()[0], expression)
    arguments = {"datamodel_type": "Edit", "code": code, "studio_id": studio_id}
    text = studio._rpc("tools/call", {"name": "execute_luau", "arguments": arguments}, timeout=timeout)
    body = "\n".join(c.get("text", "") for c in text.get("content", []))
    if text.get("isError"):
        raise RuntimeError("execute_luau: %s" % body)
    value = parse_json(body)
    if isinstance(value, dict) and value.get("error"):
        raise RuntimeError("TerrainBake: %s" % value["error"])
    return value


# ---------------------------------------------------------------- the refusals

def refuse(reason):
    print("[bake] REFUSED: %s" % reason)
    return 2


class pin_default:
    """Make every UNSCOPED call in the block go to one Studio, and put the old default back.

    `compare_synced` and `unmanaged_scripts` take no `studio_id`; without this they address
    whichever Studio `_choose_default_studio` pinned, which is the DEV place (finding 3, round 1).
    """

    def __init__(self, studio, studio_id):
        self.studio, self.studio_id, self.previous = studio, studio_id, None

    def __enter__(self):
        self.previous = getattr(self.studio, "default_studio_id", None)
        self.studio.default_studio_id = self.studio_id
        return self.studio

    def __exit__(self, *_):
        self.studio.default_studio_id = self.previous
        return False


def check_place(studio, studio_id, want_name=None, allow_local=False):
    """Refusals 1 and 2, re-run before EVERY mutating call (B1), by place id -- and, when
    `--studio-name` is given, by the DataModel's own name as well.

    THE PLACE ID IS NOT ENOUGH WHEN A BACKUP IS OPEN (task 328k). A `.rbxl` saved out of the Forest
    Test and re-opened as a local file reports the SAME `game.PlaceId`, so with both windows up the
    id cannot tell the base snapshot's window from Karen's live one. The name can: Studio names the
    DataModel after the file. `--studio-name` is therefore not politeness -- it is the only
    discriminator there is, and lesson L-055 is about exactly this fall-back.
    """
    mode = studio.mode(studio_id=studio_id)
    if "Edit" not in mode:
        return "Studio is in %r, not Edit. Karen may be playing; the bake only runs in Edit." % mode
    answer = studio.query("Edit", QUERY_PLACE_AND_NAME, studio_id=studio_id).strip().strip('"')
    place, _, name = answer.partition("|")
    if not local_ok(place.strip(), name, want_name, allow_local):
        return ("that Studio is open on place %s, not the Forest Test %s"
                % (place, FOREST_PLACE_ID))
    if want_name and want_name.lower() not in name.lower():
        return ("that Studio's place is %s but its DataModel is named %r, which does not hold %r: "
                "two windows can report one place id (a backup .rbxl re-opened), so the name is the "
                "only thing that tells them apart" % (place, name, want_name))
    return None


def check_echo(studio, studio_id, facts, injected, shas):
    """REFUSAL 4, as the injection route can actually prove it (Director decision 2).

    The old check compared `Script.Source` with disk; in the Forest Test every Source reads length 0
    through execute_luau, so it could only refuse there however recently Connect was pressed. What
    replaces it: the arrived code reports the constants IT defines, and they are compared with the
    same constants read off the files at this (clean) commit. A truncated, stale or half-sent module
    either fails to load -- which is an error, not a pass -- or answers a different number here.
    """
    echo = call(studio, studio_id, ECHO_EXPRESSION, timeout=120, injected=injected)
    wanted = {
        "tile": facts["tile"], "maxVoxels": facts["maxVoxels"], "roadHalf": facts["roadHalf"],
        "voxel": facts["voxel"], "blend": facts["blend"], "originX": facts["originX"],
        "cellDepth": facts["cellDepth"], "placeId": int(FOREST_PLACE_ID),
    }
    wrong = ["%s: Studio says %r, the files say %r" % (k, echo.get(k), v)
             for k, v in sorted(wanted.items()) if echo.get(k) != v]
    if echo.get("cells") != len(CELL_IDS):
        wrong.append("cells: Studio says %r, the grid has %d" % (echo.get("cells"), len(CELL_IDS)))
    # MEASURED in DEV, 2026-11-02: `Grid.roads()` answers 8 -- (rows + 1) east-west and
    # (columns + 1) north-south, 3 + 5. The first version of this line doubled the east-west count
    # and would have refused every run.
    if echo.get("roads") != (facts["rows"] + 1) + (facts["columns"] + 1):
        wrong.append("roads: Studio says %r" % (echo.get("roads"),))
    if wrong:
        return ("the injected code does not match the files at this commit:" + chr(10)
                + "  - " + (chr(10) + "  - ").join(wrong))
    print("[bake] injected %s, echoed back from Studio: tile=%s voxel=%s cells=%s roads=%s bakeVersion=%s"
          % (", ".join("%s %s" % (n, shas[n][:12]) for n, _ in MODULES),
             echo.get("tile"), echo.get("voxel"), echo.get("cells"), echo.get("roads"),
             echo.get("bakeVersion")))
    return None


def check_clean_tree(state=None):
    """Refusal 3. `state` is the (sha, dirty) pair, handed in so `selftest` can feed it a dirty
    tree without making one -- the refusal is the thing under test, not git."""
    sha, dirty = state if state is not None else git_state()
    if dirty:
        return sha, ("the tree is dirty: a world baked from uncommitted code cannot be rebuilt from "
                     "a commit.\n  - " + "\n  - ".join(dirty))
    return sha, None


def check_backup(backup):
    """Refusal 5. `census` is NOT accepted: her place is full of hand-made content."""
    if backup is None:
        return "no --backup. Pass a .rbxl saved by File -> Save to File, outside the repository."
    if backup == "census":
        return ("--backup census is not accepted here. Karen's Forest Test is full of hand-made "
                "content a census cannot stand in for; only a saved .rbxl can put it back.")
    path = os.path.abspath(backup)
    if not os.path.isfile(path):
        return "--backup %s is not a file" % backup
    try:
        inside = os.path.commonpath([path, REPO]) == REPO
    except ValueError:
        inside = False  # another drive, which is certainly outside
    if inside:
        return "--backup %s is inside the repository; a backup must be outside it" % backup
    if not path.lower().endswith(".rbxl"):
        return "--backup %s is not a .rbxl" % backup
    size = os.path.getsize(path)
    if size == 0:
        return "--backup %s is empty" % backup
    age_hours = (time.time() - os.path.getmtime(path)) / 3600
    if age_hours > BACKUP_MAX_AGE_HOURS:
        return "--backup %s is %.1f h old, older than %s h" % (backup, age_hours, BACKUP_MAX_AGE_HOURS)
    return None


def override_name_of(part):
    """`DHFlag_GRID_PREVIEW=true` -> `GRID_PREVIEW`, the pure half of refusal 7's fix."""
    name = part.split("=", 1)[0]
    return name[len("DHFlag_"):] if name.startswith("DHFlag_") else name


def override_names(studio, studio_id):
    """The NAMES of the live flag overrides. `flag_overrides` answers `DHFlag_<NAME>=<value>`
    strings, so a whitelist of bare names matched NOTHING and refusal 7 refused Karen's own two
    flags -- the two it exists to allow. Measured 2026-11-02 18:00 UTC in her Forest Test: 15 of 15
    refused, `DHFlag_GRID_PREVIEW=true` among them."""
    return sorted(override_name_of(part) for part in flag_overrides(studio, studio_id=studio_id) or [])


def check_overrides(studio, studio_id, keep=()):
    """Refusal 7, less Karen's own (lesson K: never clear her Forest Test's overrides).

    `keep` is the operator's DECLARED list (`--keep-flags`), for the place owner's own playtest
    switches: the dispatch of 2026-11-02 says her 15 are "left as found", and clearing them is what
    lesson K forbids. The caller prints it and `log_run` keeps it, so the widening is on the record;
    anything NOT declared still refuses, which is what the guard is for -- a stray override a
    BUILDER left behind. Nothing in the bake's geometry reads a flag: `Flags` is not in MODULES."""
    allowed = set(KARENS_FLAGS) | set(keep)
    strays = [name for name in override_names(studio, studio_id) if name not in allowed]
    if strays:
        return ("a flag override is live and NOT declared: %s. Either set THAT flag off with "
                "`python tools/flags.py --place forest set <NAME> off`"
                " -- never `clear`, which would take Karen's %s with it -- or name it in "
                "--keep-flags." % (", ".join(strays), " and ".join(KARENS_FLAGS)))
    pose = pose_override(studio, studio_id=studio_id)
    if pose:
        return "a pose override is live (%s). Run `python tools/pose.py clear` first." % pose
    return None


# ---------------------------------------------------------------- the run log

def log_run(cells, entries, keep=None, live=None):
    """`keep` and `live` are refusal 7's record: what the operator DECLARED with --keep-flags and
    what was actually set. Round 1's review caught the claim that the run log held them when only
    stdout did, and the declaration is the whole reason refusal 7 was narrowed instead of deleted."""
    os.makedirs(RUN_LOG_DIR, exist_ok=True)
    name = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime()) + "-" + ",".join(cells) + ".json"
    path = os.path.join(RUN_LOG_DIR, name)
    body = entries if keep is None and live is None else {
        "keepFlags": list(keep or []),
        "liveOverrides": list(live or []),
        "tiles": entries,
    }
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(body, handle, indent=2)
    print("[bake] run log: %s" % os.path.relpath(path, REPO))
    return path


# ---------------------------------------------------------------- the commands

def local_ok(place, name, want_name, allow_local):
    """Is this Studio the one a run may talk to?

    MEASURED 2026-11-03: a `.rbxl` saved out of the Forest Test and re-opened with
    `-task EditFile -localPlaceFile` reports `game.PlaceId` **0**, not the place it was saved from,
    and `game.Name` is the FILE's name. So the base snapshot's window cannot be addressed by place
    id at all. `--allow-local-file` accepts place 0, and ONLY ever together with a `--studio-name`
    that the DataModel's name holds -- and main() refuses the flag for every command but the
    read-only `snapshot`, because B1's guard exists to stop a WRITE going to the wrong world and a
    read of a backup file writes nothing.
    """
    if place == FOREST_PLACE_ID:
        return not want_name or want_name.lower() in (name or "").lower()
    if allow_local and place == "0" and want_name:
        return want_name.lower() in (name or "").lower()
    return False


def resolve(studio, want_name=None, allow_local=False):
    """(studio_id, why) for the Forest Test. The ONE resolver, by place id (L-055, L-014) -- and by
    the DataModel's NAME too when `--studio-name` is given, because a backup `.rbxl` re-opened as a
    local file reports the same place id as Karen's live window (see `check_place`).

    It PRINTS every Studio it saw and what each answered, so the window it chose is readable rather
    than assumed, and it re-lists before refusing for `studio_for_place`'s own measured reason.
    """
    from studio_mcp import place_of
    seen = []
    for attempt in range(5):
        seen = []
        for entry in studio.studio_list():
            studio_id = entry.get("id")
            at, name, why = place_of(studio, studio_id, "Edit")
            seen.append("%s place=%s name=%r%s"
                        % (studio_id[:8] if studio_id else "?", at or "?", name or "",
                           "" if at else " (" + why[:60] + ")"))
            if not local_ok(at, name, want_name, allow_local):
                continue
            print("[bake] Studios seen: %s" % " | ".join(seen))
            print("[bake] Studio: %s name=%r place %s%s"
                  % (studio_id[:8], name, at,
                     "  (--studio-name %r matched)" % want_name if want_name else ""))
            return studio_id, None
        if attempt < 4:
            time.sleep(2)
    return None, ("no Studio is open on place %s%s. Saw: %s"
                  % (FOREST_PLACE_ID,
                     " with a DataModel named %r" % want_name if want_name else "",
                     " | ".join(seen) or "nothing"))


def command_plan(args, facts, studio=None, studio_id=None):
    """Read-only, and it ASSERTS the tile count against the design's arithmetic (Director 6)."""
    cells = args.cells or list(CELL_IDS)
    region = region_for(cells, facts)
    count, nx, nz, x0, z0 = tile_count(region, facts["tile"])
    columns = (facts["tile"] / facts["voxel"]) ** 2
    print("[bake] plan: cells=%s" % ",".join(cells))
    print("  region   x[%d,%d] z[%d,%d]  (%d x %d studs)"
          % (region["minX"], region["maxX"], region["minZ"], region["maxZ"],
             region["maxX"] - region["minX"], region["maxZ"] - region["minZ"]))
    print("  tiles    %d = %d x %d of %d studs, lattice from (%d, %d)"
          % (count, nx, nz, facts["tile"], x0, z0))
    print("  columns  %d per tile, %d in the run" % (columns, columns * count))
    print("  ceiling  %d voxels a call; a %d-stud tile allows %d studs of Y band per call"
          % (facts["maxVoxels"], facts["tile"], facts["voxel"] * (facts["maxVoxels"] // columns)))
    # THE ASSERTION, against a number this function did not compute: the committed count for this
    # run, and -- when a Studio answers -- `Relief.tiles`' own output, which is a different engine.
    key = cells[0] if len(cells) == 1 else ("ALL" if len(cells) == len(CELL_IDS) else None)
    expected = EXPECTED_TILES.get(key) if key else None
    if expected is None:
        print("  NOT ASSERTED: no committed count for cells=%s; %d tiles printed, not checked"
              % (",".join(cells), count))
    elif count != expected:
        return refuse("the plan is %d tiles for cells=%s; the committed count is %d. If the region "
                      "moved on purpose, say the new number in EXPECTED_TILES." % (count, ",".join(cells), expected))
    else:
        print("  ASSERTED: %d tiles == the committed count for %s" % (count, key))
    live = None
    if studio is not None and studio_id is not None:
        try:
            live = call(studio, studio_id,
                        "#TerrainBake.tilePlan(TerrainBake.regionFor({%s}))"
                        % ",".join('"%s"' % c for c in cells), timeout=45)
        except Exception as problem:  # noqa: BLE001 -- a read-only plan never fails on the extra check
            print("  (Relief.tiles was not asked: %s)" % str(problem).strip()[:160])
    if live is not None:
        if live != count:
            return refuse("Relief.tiles in Studio makes %s tiles for cells=%s; this tool makes %d"
                          % (live, ",".join(cells), count))
        print("  ASSERTED: Relief.tiles in Studio agrees -- %s tiles" % live)
    else:
        print("  (Relief.tiles was not asked, so the committed count stands alone)")
    return 0


def command_survey(studio, studio_id, args, injected=None):
    cells = args.cells or list(CELL_IDS)
    print("[bake] survey (read-only):")
    print("  %-4s %-7s %8s %8s %8s %8s %9s  %s" % ("cell", "samples", "minY", "maxY", "meanY", "spread", "lineMeanY", "character"))
    for cell_id in cells:
        row = call(studio, studio_id, 'TerrainBake.survey("%s")' % cell_id, injected=injected)
        print("  %-4s %-7d %8.2f %8.2f %8.2f %8.2f %9.2f  %s"
              % (row["cell"], row["samples"], row["minY"], row["maxY"], row["meanY"],
                 row["spreadStuds"], row["lineMeanY"], row["character"]))
    return 0


def command_census(studio, studio_id, cells, injected=None):
    """GridCensus' OWN entry point is `survey(folder, cellId, groundAt, clawOf)` -- there is no
    `run()`, measured 2026-11-02 by listing the module's keys in the Forest Test's Play server."""
    for cell_id in cells:
        result = call(studio, studio_id, CENSUS_SEAM % cell_id, injected=injected)
        print("[bake] %s" % result.get("line", json.dumps(result)[:2000]))
    return 0


# The seam TerrainBake.census is handed: GridCensus' own survey, with a terrain raycast for the
# ground and the claw left to the template audit (328b), which this task does not re-run.
CENSUS_SEAM = """TerrainBake.census({ census = function()
        local Workspace = game:GetService("Workspace")
        local GridCensus = require(game:GetService("ServerStorage"):WaitForChild("GridCensus"))
        local folder = Workspace:FindFirstChild("GridForest") or Workspace:FindFirstChild("GridPlaces")
        local function groundAt(x, z)
            local p = RaycastParams.new()
            p.FilterType = Enum.RaycastFilterType.Include
            p.FilterDescendantsInstances = { Workspace.Terrain }
            p.IgnoreWater = true
            local h = Workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -4000, 0), p)
            return if h then h.Position.Y else nil
        end
        local report = GridCensus.survey(folder, "%s", groundAt, function() return 0 end)
        return { line = GridCensus.line(report), report = report }
    end })"""


def epoch_for(studio, studio_id, base_sha, injected=None):
    """The 16 hex of design 5.4, computed HERE from the Luau's own input string.

    `TerrainBake.epochInputFor` builds the string (the landform digest, the geometry and
    BAKE_VERSION); this is the digest the design's formula asks for, and nothing else makes one.
    """
    text = call(studio, studio_id, 'TerrainBake.epochInputFor("%s")' % base_sha, timeout=60,
                injected=injected)
    if not isinstance(text, str):
        raise RuntimeError("TerrainBake.epochInputFor did not answer a string: %r" % (text,))
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def profile_sampler(studio, studio_id, cells, injected, base):
    """THE BASE, AT EXACTLY THE POINTS A LONG PROFILE READS IT, out of the snapshot FILE (task 328k).

    `longProfile` reads the base only on the centreline, every `ROAD.sampleStuds`, so the whole of
    what the profiles need is a few thousand heights -- which is why this can be a lookup and does
    not have to be a live raycast. The raycast was the bug: `profilesFor`'s sampler defaulted to it,
    so a second bake read the crown its first bake had written and `lineMeanY` climbed 108.88 ->
    112.83 -> 114.81 over three bakes of C1 (ESCALATE.md, task 328e). A point the snapshot cannot
    answer is a REFUSAL, never a fallback.
    """
    points = call(studio, studio_id, 'TerrainBake.profileSamples({%s})'
                  % ",".join('"%s"' % c for c in cells), timeout=120, injected=injected)
    if not isinstance(points, list) or len(points) < 2:
        raise RuntimeError("TerrainBake.profileSamples answered %r" % (points,))
    rows, missing = [], []
    for at in range(0, len(points) - 1, 2):
        x, z = points[at], points[at + 1]
        y = base_at(base, x, z)
        if y is None:
            missing.append("(%g, %g)" % (x, z))
        else:
            rows.extend([x, z, y])
    if missing:
        raise RuntimeError("the base snapshot has no height at %d road sample point(s): %s%s"
                           % (len(missing), ", ".join(missing[:6]),
                              " ..." if len(missing) > 6 else ""))
    print("[bake] road base: %d sample point(s) read off the snapshot %s"
          % (len(rows) // 3, base["sha"][:16]))
    return json.dumps(rows, separators=(",", ":"))


def profiles_once(studio, studio_id, cells, injected, sampler):
    """THE LONG PROFILES, COMPUTED ONCE, BEFORE ANY VOXEL IS WRITTEN (round-2 finding 2).

    Round 2 let every tile call `TerrainBake.profilesFor` for itself, whose sampler raycasts LIVE
    terrain: from the second tile on, that reads ground this bake has already written, so two tiles
    of one road could meet at a step and the result would depend on the tile order. Here the tool
    asks for them ONCE, holds the JSON, and sends THE SAME BYTES to every tile -- which is what
    makes the crown at a shared x identical by construction rather than by argument.

    `sampler` is the Luau EXPRESSION for the base reader: `profile_sampler`'s snapshot lookup for a
    bake, and `TerrainBake.terrainReader()` only where the `diff` command deliberately measures the
    old live route against the new one.

    It also prints what design 7.1 obliges: the grade each road was given, whether it had to be
    relaxed, the worst cut-or-fill, the realised grade change, and every breach, in full.
    """
    rows = call(studio, studio_id, 'TerrainBake.profilesFor({%s}, %s)'
                % (",".join('"%s"' % c for c in cells), sampler), timeout=300, injected=injected)
    if not isinstance(rows, list) or not rows:
        raise RuntimeError("TerrainBake.profilesFor answered %r, not a list of profiles" % (rows,))
    payload = json.dumps(rows, separators=(",", ":"), sort_keys=True)
    digest = hashlib.sha256(payload.encode("utf-8")).hexdigest()
    print("[bake] long profiles, computed ONCE off the base (%d road(s), %d bytes, sha256 %s):"
          % (len(rows), len(payload), digest[:16]))
    breaches = 0
    for row in rows:
        road = row.get("road", {})
        print("  %-6s %-4s at %-7g %4d samples  ceiling %2s %%  realised %5.2f %%  cut/fill %6.2f  "
              "change %5.2f %% per %g st  relaxed=%s"
              % (road.get("id"), road.get("axis"), road.get("at"), len(row.get("y", [])),
                 row.get("gradePercent"), row.get("realisedGradePercent", 0), row.get("worstCutFill", 0),
                 row.get("worstGradeChangePercent", 0), row.get("gradeChangeSpanStuds", 0),
                 row.get("relaxed")))
        for line in row.get("breaches", []) or []:
            breaches += 1
            print("    BREACH: %s" % line)
    print("[bake] profiles: %d breach(es) printed, never hidden (design 7.1)" % breaches)
    # THE JUNCTIONS, MEASURED (round-3 finding 2). Design 7.1 pins the 15 crossings and gives the
    # E-W profile the junction square; these are the three numbers that say whether it happened --
    # the two crowns' disagreement AT the crossing, the worst step between voxel-adjacent columns on
    # the square, and what the steeper road's own grade explains anyway.
    steps = call(studio, studio_id, "TerrainBake.junctionSteps(HttpService:JSONDecode([==[%s]==]))"
                 % payload, timeout=300, injected=injected)
    print("[bake] junctions, measured on those profiles (%d crossing(s) in this run):" % len(steps))
    worst_pin, worst_step = 0.0, 0.0
    for row in steps:
        over = row["worstStepStuds"] > row["explainedStuds"] + 1e-6
        print("  %-4s x %-4s at (%7g,%7g)  pin %7.4f st  worst voxel step %7.4f st at (%+d,%+d)"
              "  E-W rise over the square %6.4f  explained %7.4f%s"
              % (row["ew"], row["ns"], row["x"], row["z"], row["pinStuds"], row["worstStepStuds"],
                 row["atOffsetX"], row["atOffsetZ"], row["ewSpanStuds"], row["explainedStuds"],
                 "   OVER" if over else ""))
        worst_pin = max(worst_pin, row["pinStuds"])
        worst_step = max(worst_step, row["worstStepStuds"])
    print("[bake] junctions: worst pin %.4f st, worst voxel step %.4f st" % (worst_pin, worst_step))
    return payload, digest


def command_snapshot(studio, studio_id, args, facts, injected, sha):
    """STEP 2 OF THE BAKE (design 5.3): the ORIGINAL ground, read ONCE, to a file OUTSIDE the repo.

    Chunked, because `ReadVoxels` tops out at 4,194,304 voxels and C1's region alone is 24.6 M at a
    500-stud Y band (measured 2026-11-02). Every chunk is 4-aligned, so `Region3:ExpandToGrid` is a
    no-op and the stitched lattice is exactly the one the engine read on.

    A column with no single height -- Water, an overhang, no ground in the band -- is recorded as a
    HOLE with its reason and NOT guessed; `bakeTileAt` then refuses any tile whose own columns hold
    one. Refusing the whole million-column pass for one pond is not the design's rule (note 4 item
    5 refuses the TILE), and guessing is what fills a cave.
    """
    region = region_for(args.cells or list(CELL_IDS), facts)
    v = facts["voxel"]
    min_x = v * math.floor(region["minX"] / v)
    min_z = v * math.floor(region["minZ"] / v)
    max_x = v * math.ceil(region["maxX"] / v)
    max_z = v * math.ceil(region["maxZ"] / v)
    nx = int(round((max_x - min_x) / v))
    nz = int(round((max_z - min_z) / v))
    codes = array.array("h", [0]) * (nx * nz)
    holes, reasons = set(), []
    low, high = None, None
    chunk = SNAPSHOT_CHUNK_STUDS
    xs = list(range(int(min_x), int(max_x), chunk))
    zs = list(range(int(min_z), int(max_z), chunk))
    print("[bake] snapshot: x[%g,%g] z[%g,%g] = %d x %d columns at pitch %g, in %d chunk(s) of %d st, "
          "Y band %g..%g" % (min_x, max_x, min_z, max_z, nx, nz, v, len(xs) * len(zs), chunk,
                             args.y_min, args.y_max))
    started = time.time()
    done = 0
    for z0 in zs:
        for x0 in xs:
            x1, z1 = min(x0 + chunk, max_x), min(z0 + chunk, max_z)
            # `snapshot` answers (nil, why) when it refuses -- over ReadVoxels' ceiling, or a
            # region under one voxel. JSONEncode of the first value would send "null" and lose the
            # reason, so the refusal is raised and the tool prints it.
            payload = call(studio, studio_id,
                           "(function() local snap, why = TerrainBake.snapshot("
                           "{minX=%g,maxX=%g,minZ=%g,maxZ=%g}, %g, %g, true) "
                           "if snap == nil then error(why, 0) end "
                           "return TerrainBake.encodeSlice(snap) end)()"
                           % (x0, x1, z0, z1, args.y_min, args.y_max), injected=injected)
            if abs(payload["minX"] - x0) > 1e-6 or abs(payload["minZ"] - z0) > 1e-6:
                raise RuntimeError("chunk (%g, %g) came back anchored at (%g, %g): the lattice is "
                                   "not aligned" % (x0, z0, payload["minX"], payload["minZ"]))
            blob = array.array("h")
            blob.frombytes(base64.b64decode(payload["b64"]))
            if sys.byteorder != "little":
                blob.byteswap()
            cnx, cnz = int(payload["nx"]), int(payload["nz"])
            if len(blob) != cnx * cnz:
                raise RuntimeError("chunk (%g, %g) sent %d codes for %d x %d columns"
                                   % (x0, z0, len(blob), cnx, cnz))
            i0 = int(round((x0 - min_x) / v))
            k0 = int(round((z0 - min_z) / v))
            for k in range(cnz):
                at = (k0 + k) * nx + i0
                codes[at:at + cnx] = blob[k * cnx:(k + 1) * cnx]
            for local in payload.get("holes", []) or []:
                index = int(local) - 1
                holes.add((k0 + index // cnx) * nx + i0 + index % cnx + 1)
            for line in payload.get("holeWhy", []) or []:
                if len(reasons) < 40:
                    reasons.append(line)
            low = payload["minY"] if low is None else min(low, payload["minY"])
            high = payload["maxY"] if high is None else max(high, payload["maxY"])
            done += 1
            print("  chunk %3d/%-3d (%7g,%7g)..(%7g,%7g)  %5d x %-5d  holes %d"
                  % (done, len(xs) * len(zs), x0, z0, x1, z1, cnx, cnz, len(payload.get("holes") or [])))
    header = {
        "pitch": v,
        "minX": min_x,
        "minZ": min_z,
        "nx": nx,
        "nz": nz,
        "minY": low,
        "maxY": high,
        "yMin": args.y_min,
        "yMax": args.y_max,
        "cells": args.cells or list(CELL_IDS),
        "place": FOREST_PLACE_ID,
        "commit": sha,
        "chunkStuds": chunk,
        "source": args.source or "",
    }
    out = args.out
    if out:
        digest = base_save(out, header, codes, holes)
    else:
        # THE FILE IS NAMED AFTER ITS OWN CONTENT, which is what makes "snapshot twice, same sha"
        # readable off the directory listing: a second identical read overwrites one file, and a
        # different read lands beside it under a different name.
        staging = os.path.join(runs_dir(), "terrain-base-staging.bin")
        digest = base_save(staging, header, codes, holes)
        out = os.path.join(runs_dir(), "terrain-base-%s.bin" % digest[:12])
        if os.path.exists(out):
            os.remove(out)
        os.replace(staging, out)
    with open(out + ".sha256", "w", encoding="utf-8") as handle:
        handle.write(digest + "\n")
    elapsed = time.time() - started
    print("[bake] snapshot: %s" % out)
    print("[bake] snapshot: sha256=%s  %d columns, %d bytes, %d hole(s), ground %.2f..%.2f, %.1f s"
          % (digest, nx * nz, os.path.getsize(out), len(holes),
             low if low is not None else 0, high if high is not None else 0, elapsed))
    for line in reasons[:10]:
        print("  HOLE: %s" % line)
    if len(reasons) > 10:
        print("  HOLE: ... and %d more reason(s) recorded by the chunks" % (len(reasons) - 10))
    return 0


def command_diff(studio, studio_id, args, facts, injected, base):
    """THE DRY RUN (task 328k): what a bake WOULD write, against the ground that is there now.

    NOTHING IS WRITTEN. Two routes are computed with the SAME instrument so the drift is a measured
    difference and not an argument:
      * the SNAPSHOT route -- the base and the road profiles both out of the `.bin`;
      * the LIVE route -- the pre-328k one, `TerrainBake.terrainReader()` for both, which on ground
        that has already been baked reads the bake's own last answer.
    The road band (within `ROAD.ditch.farStuds` of a centreline) is reported apart from the rest,
    because the two drift for different reasons.
    """
    cells = args.cells
    plan = tile_plan(studio, studio_id, cells, injected)
    pad = call(studio, studio_id, "TerrainBake.padFor()", timeout=60, injected=injected)
    side = facts["tile"]
    sampler = profile_sampler(studio, studio_id, cells, injected, base)
    print("[bake] diff: the SNAPSHOT route's profiles")
    snap_profiles, _ = profiles_once(studio, studio_id, cells, injected,
                                     "TerrainBake.pointSampler(HttpService:JSONDecode([==[%s]==]))"
                                     % sampler)
    print("[bake] diff: the LIVE route's profiles (the pre-328k raycast, for comparison ONLY)")
    live_profiles, _ = profiles_once(studio, studio_id, cells, injected,
                                     "TerrainBake.terrainReader()")
    # THE DRIFT, ON THE ROADS THEMSELVES: the two routes' long profiles, road by road. This is the
    # number ESCALATE.md measured as +2 studs a bake, read here without writing anything.
    print("[bake] diff: long profile, snapshot route vs live route, per road")
    worst_road, worst_mean = 0.0, 0.0
    by_id = {row["road"]["id"]: row for row in json.loads(live_profiles)}
    for row in json.loads(snap_profiles):
        other = by_id.get(row["road"]["id"])
        if not other or len(other["y"]) != len(row["y"]):
            print("  %-6s no comparable live profile" % row["road"]["id"])
            continue
        deltas = [b - a for a, b in zip(row["y"], other["y"])]
        mean = sum(deltas) / len(deltas)
        top = max(abs(d) for d in deltas)
        worst_road, worst_mean = max(worst_road, top), max(worst_mean, abs(mean))
        print("  %-6s %4d samples  live - snapshot: mean %+7.3f st  max |d| %7.3f st"
              % (row["road"]["id"], len(deltas), mean, top))
    print("[bake] diff: worst road mean %+.3f st, worst road max %.3f st -- the LIVE route's drift "
          "off the base" % (worst_mean, worst_road))
    # THE TILES, SPREAD ACROSS THE PLAN rather than the first N, so the road band and the cell
    # interior are both in the sample.
    want = min(args.tiles or 12, len(plan))
    picked = sorted({1 + round(i * (len(plan) - 1) / max(1, want - 1)) for i in range(want)})
    print("[bake] diff: %d of %d tiles, spread across the plan: %s"
          % (len(picked), len(plan), ",".join(str(i) for i in picked)))
    totals = {"snap": [0, 0.0, 0.0, 0, 0.0, 0.0], "live": [0, 0.0, 0.0, 0, 0.0, 0.0]}
    fnv = {"snap": [], "live": []}
    for index in picked:
        payload, problem = slice_for(base, plan[index - 1], pad, side)
        if problem:
            print("  tile %3d  SKIPPED: %s" % (index, problem))
            continue
        rows = {}
        for route, profiles, slice_arg in (
            ("snap", snap_profiles, "HttpService:JSONDecode([==[%s]==])"
             % json.dumps(payload, separators=(",", ":"))),
            ("live", live_profiles, "nil"),
        ):
            rows[route] = call(studio, studio_id,
                               "TerrainBake.diffTileAt(%d, {%s}, "
                               "HttpService:JSONDecode([==[%s]==]), %s, %g, %g, %s)"
                               % (index, ",".join('"%s"' % c for c in cells), profiles, slice_arg,
                                  args.y_min, args.y_max, "true" if route == "live" else "false"),
                               injected=injected)
        if rows["snap"].get("message") or rows["live"].get("message"):
            print("  tile %3d  %s" % (index, rows["snap"].get("message") or rows["live"]["message"]))
            continue
        for route in ("snap", "live"):
            row = rows[route]
            box = totals[route]
            box[0] += row["n"]
            box[1] += row["sum"]
            box[2] = max(box[2], row["maxAbs"])
            box[3] += row["roadN"]
            box[4] += row["roadSum"]
            box[5] = max(box[5], row["roadMaxAbs"])
            fnv[route].append(row["shapeFnv"])
        a, b = rows["snap"], rows["live"]
        print("  tile %3d (%6d,%6d)  snapshot: all mean %+7.3f max %7.3f | road n=%-5d mean %+7.3f "
              "max %7.3f   live: all mean %+7.3f max %7.3f | road mean %+7.3f max %7.3f"
              % (index, a["minX"], a["minZ"],
                 a["sum"] / max(1, a["n"]), a["maxAbs"], a["roadN"],
                 a["roadSum"] / max(1, a["roadN"]), a["roadMaxAbs"],
                 b["sum"] / max(1, b["n"]), b["maxAbs"],
                 b["roadSum"] / max(1, b["roadN"]), b["roadMaxAbs"]))
    for route, label in (("snap", "SNAPSHOT"), ("live", "LIVE")):
        n, total, top, rn, rtotal, rtop = totals[route]
        print("[bake] diff %s route over %d column(s): mean %+0.4f st, max |d| %0.4f st; road band "
              "%d column(s): mean %+0.4f st, max |d| %0.4f st"
              % (label, n, total / max(1, n), top, rn, rtotal / max(1, rn), rtop))
    print("[bake] diff: shape identity per tile (FNV-1a over 1/64-stud heights)")
    print("  snapshot %s" % ",".join(fnv["snap"]))
    print("  live     %s" % ",".join(fnv["live"]))
    return 0


def tile_plan(studio, studio_id, cells, injected):
    """The tile lattice, ASKED OF `Relief.tiles` rather than re-derived here: the tool has to know
    each tile's corner to cut its slice out of the base, and two copies of that lattice is how a
    slice silently stops covering the tile it is for."""
    plan = call(studio, studio_id, 'TerrainBake.tilePlan(TerrainBake.regionFor({%s}))'
                % ",".join('"%s"' % c for c in cells), timeout=120, injected=injected)
    if not isinstance(plan, list) or not plan:
        raise RuntimeError("TerrainBake.tilePlan answered %r" % (plan,))
    return plan


def slice_for(base, tile, pad, side):
    """One tile's base slice, or (None, why). The pad is `TerrainBake.padFor()`'s, asked of Studio."""
    return base_slice(base, tile["minX"] - pad, tile["minZ"] - pad,
                      tile["minX"] + side + pad, tile["minZ"] + side + pad)


def tile_pass(studio, studio_id, args, facts, sha, dry, injected=None, profiles=None, keep=None,
              live=None, base=None, plan=None, pad=None):
    """The tile loop, shared by `measure` (dry) and `bake` (wet). One MCP call per tile."""
    cells = args.cells
    region = region_for(cells, facts)
    count = tile_count(region, facts["tile"])[0]
    limit = min(args.tiles or count, count)
    entries, worst = [], 0
    side = facts["tile"]
    reshape_said = [None]
    print("[bake] %s: %d of %d tiles, cells=%s" % ("measure (DRY)" if dry else "bake", limit, count, ",".join(cells)))
    for index in range(1, limit + 1):
        # REFUSAL 2 AGAIN, before every mutating call (B1): the operator can open another place
        # inside a 70-minute run, and a silent fall-back would reshape DEV.
        if not dry:
            problem = check_place(studio, studio_id, args.studio_name)
            if problem:
                return refuse(problem), entries
        # THIS TILE'S SLICE OF THE BASE SNAPSHOT, cut out of the `.bin` (task 328k). The bake used
        # to read it LIVE here, which is what made a re-bake read its own last bake.
        payload, problem = slice_for(base, plan[index - 1], pad, side)
        if problem:
            print("[bake] FAILED at tile %d: %s" % (index, problem))
            log_run(cells, entries, keep, live)
            return 1, entries
        # THE SAME PROFILE BYTES INTO EVERY TILE. `[==[` quoting, because the payload is JSON and
        # holds double quotes; it is a value, never code.
        expression = (
            'TerrainBake.bakeTileAt(%d, {%s}, %s, HttpService:JSONDecode([==[%s]==]), '
            'HttpService:JSONDecode([==[%s]==]))'
            % (index, ",".join('"%s"' % c for c in cells), "true" if dry else "false", profiles,
               json.dumps(payload, separators=(",", ":")))
        )
        report = call(studio, studio_id, expression, injected=injected)
        entries.append(report)
        worst = max(worst, report.get("elapsedMs", 0))
        # THE LANDFORM GOES IN ONCE, and which way the tile went is PRINTED on the first tile and
        # whenever it changes -- a run that skipped the landform must not look like one that
        # applied it (`TerrainBake.reshapeWanted`; measured +24.04 st of double ridge on C1).
        if report.get("reshape") and report["reshape"] != reshape_said[0]:
            reshape_said[0] = report["reshape"]
            print("  [reshape] %s" % report["reshape"])
        print("  tile %3d/%-3d (%6d,%6d) calls=%d voxels=%-6d band %.0f..%.0f  %d ms%s"
              % (index, limit, report["minX"], report["minZ"], report["calls"], report["voxels"],
                 report["bandMin"], report["bandMax"], report["elapsedMs"],
                 "  " + report["message"] if report.get("message") else ""))
        if report.get("message"):
            log_run(cells, entries, keep, live)
            print("[bake] FAILED at tile %d: %s" % (index, report["message"]))
            return 1, entries
    log_run(cells, entries, keep, live)
    # THE EPOCH IS STAMPED AT THE END OF A WET RUN, through TerrainBake.stamp, which design 2 names
    # as its only writer -- and it is printed, because design 6.3 puts it in this line.
    epoch = "dry"
    if not dry:
        # THE EPOCH HASHES THE BASE SNAPSHOT'S SHA, NEVER THE GIT SHA (design 5.4; 328e note c).
        # `check_base` has already proved that sha is the file's own.
        epoch = epoch_for(studio, studio_id, args.base_sha, injected)
        call(studio, studio_id, 'TerrainBake.stamp("%s") or "stamped"' % epoch, timeout=60,
             injected=injected)
        # ...AND THE PER-CELL SHAPE STAMP, so a later run can tell whether this cell's landform is
        # the one already in the ground (`TerrainBake.reshapeWanted`).
        stamped = call(studio, studio_id, "TerrainBake.stampShape({%s})"
                       % ",".join('"%s"' % c for c in cells), timeout=60, injected=injected)
        print("[bake] shape stamp written on %s cell(s): %s" % (stamped, ",".join(cells)))
    print("[bake] %s: %d/%d tiles @ %s cells=%s epoch=%s worstTileMs=%d (clean tree)"
          % ("DRY OK" if dry else "OK", limit, limit, sha, ",".join(cells), epoch, worst))
    return 0, entries


def main(argv):
    parser = argparse.ArgumentParser(prog="terrainbake")
    parser.add_argument("command", choices=("plan", "snapshot", "diff", "measure", "bake", "survey",
                                            "archive", "census", "selftest"))
    parser.add_argument("--cells", help="comma list, e.g. C1")
    parser.add_argument("--backup", help="a .rbxl saved by File -> Save to File, outside the repo")
    parser.add_argument("--tiles", type=int, help="stop after this many tiles")
    parser.add_argument("--out", help="where `snapshot` writes, default "
                                      "<runs-dir>/terrain-base-<its own sha>.bin")
    parser.add_argument("--base", help="the base snapshot .bin every bake reads the ORIGINAL ground "
                                      "from; it must live OUTSIDE the repository")
    parser.add_argument("--base-sha", help="that file's sha256. REQUIRED with --base: an unchecked "
                                          "snapshot is not evidence of the base, and the epoch "
                                          "hashes this sha and never the git sha (design 5.4)")
    parser.add_argument("--source", help="a note recorded in the snapshot's header, e.g. which "
                                        ".rbxl it was read out of")
    parser.add_argument("--allow-local-file", action="store_true",
                        help="accept a Studio with NO place id (a .rbxl opened as a local file, "
                             "which reports game.PlaceId 0). Only `snapshot` takes it, only with "
                             "--studio-name, and it can never reach a mutating command")
    parser.add_argument("--studio-name", help="the Studio whose DataModel NAME holds this text, as "
                                              "well as the Forest Test's place id. REQUIRED in "
                                              "practice whenever a backup .rbxl is open beside "
                                              "Karen's live window: both report the same place id "
                                              "(task 328k, lesson L-055)")
    parser.add_argument("--keep-flags", help="comma list of flag overrides that are the PLACE "
                                             "OWNER's and must be left as found (refusal 7)")
    parser.add_argument("--y-min", type=float, default=-100.0, help="the Y band the snapshot reads")
    parser.add_argument("--y-max", type=float, default=400.0)
    args = parser.parse_args(argv)
    if args.cells:
        args.cells = [c.strip().upper() for c in args.cells.split(",") if c.strip()]
        unknown = [c for c in args.cells if c not in CELL_IDS]
        if unknown:
            return refuse("no such cell: %s" % ", ".join(unknown))

    if args.command == "selftest":
        return selftest()

    facts = luau_facts()
    if args.command == "plan":
        # `plan` is read-only, so a Studio is a bonus and never a requirement: with one it also
        # compares against `Relief.tiles`' own count, and without one it says the check was skipped.
        studio = None
        try:
            studio = Studio()
            studio_id, _ = resolve(studio, args.studio_name)
        except Exception as problem:  # noqa: BLE001 -- a plan must still print with no Studio
            print("[bake] note: no Studio addressed (%s)" % str(problem)[:120])
            studio_id = None
        try:
            return command_plan(args, facts, studio if studio_id else None, studio_id)
        finally:
            if studio is not None:
                studio.close()

    # THE LOCAL-FILE DOOR IS ONE COMMAND WIDE. `snapshot` writes nothing in the world; everything
    # else either writes terrain or measures the live place, and both need the place id.
    local = bool(args.allow_local_file)
    if local and args.command != "snapshot":
        return refuse("--allow-local-file is only for `snapshot`, which writes nothing; `%s` needs "
                      "the Forest Test's own place id" % args.command)
    if local and not args.studio_name:
        return refuse("--allow-local-file needs --studio-name: a Studio with no place id can only "
                      "be told apart by the name of the file it has open")
    mutating = args.command in ("bake", "archive")
    if mutating and not args.cells:
        return refuse("--cells is missing: an unnamed cell is an unbounded run")  # refusal 6

    sha, dirty = check_clean_tree()
    if mutating and dirty:
        return refuse(dirty)  # refusal 3

    if mutating:
        problem = check_backup(args.backup)  # refusal 5
        if problem:
            return refuse(problem)

    # THE PRELUDE, BUILT ONCE PER RUN, off the tree at this commit. Every call of the run carries
    # these same bytes (Director decision 2); `module_text` refuses here if a require it must rewrite
    # has moved, before anything is sent.
    injected, shas = prelude()
    print("[bake] commit %s%s" % (sha, "" if not dirty else " (DIRTY)"))
    for name, path in MODULES:
        print("  inject %-12s %s  %s" % (name, shas[name], os.path.relpath(path, REPO)))
    print("  stub   %-12s %s  src/shared/Shotgun/init.luau (%s = %g)"
          % ("Shotgun", shas["Shotgun"], SHOTGUN_ACCESS, shotgun_slug_range()))

    studio = Studio()
    try:
        studio_id, why = resolve(studio, args.studio_name, local)
        if studio_id is None:
            return refuse(why)
        problem = check_place(studio, studio_id, args.studio_name, local)  # refusals 1 and 2
        if problem:
            return refuse(problem)
        problem = check_echo(studio, studio_id, facts, injected, shas)  # refusal 4
        if problem:
            return refuse(problem)
        keep, live = [], []
        if mutating:
            keep = [f.strip().upper() for f in (args.keep_flags or "").split(",") if f.strip()]
            if keep:
                print("  keep   %d declared override(s), left as found: %s"
                      % (len(keep), ",".join(keep)))
            problem = check_overrides(studio, studio_id, keep)  # refusal 7
            if problem:
                return refuse(problem)
            live = override_names(studio, studio_id)
            print("  flags  live overrides: %s" % (",".join(live) or "none"))
        if args.command == "survey":
            return command_survey(studio, studio_id, args, injected)
        if args.command == "census":
            return command_census(studio, studio_id, args.cells or list(CELL_IDS), injected)
        if args.command == "snapshot":
            if args.out and os.path.commonpath([os.path.abspath(args.out), REPO]) == REPO:
                return refuse("the base snapshot must be written OUTSIDE the repository: %s"
                              % args.out)
            return command_snapshot(studio, studio_id, args, facts, injected, sha)
        if args.command == "diff":
            if not args.cells:
                return refuse("--cells is missing")
            base, problem = check_base(args, region_for(args.cells, facts))  # refusal 9
            if problem:
                return refuse(problem)
            return command_diff(studio, studio_id, args, facts, injected, base)
        if args.command == "archive":
            result = call(studio, studio_id, 'TerrainBake.archive("GridForest", {})', injected=injected)
            print("[bake] archive: %s" % json.dumps(result))
            return 0
        if args.command in ("measure", "bake"):
            if not args.cells:
                return refuse("--cells is missing")
            # REFUSAL 9: THE BASE SNAPSHOT. The bake reads the ORIGINAL ground from the file, never
            # live terrain -- design 5.3 step 2, and the reason the road half drifted +2 studs a
            # bake until task 328k (ESCALATE.md, task 328e).
            base, problem = check_base(args, region_for(args.cells, facts))
            if problem:
                return refuse(problem)
            print("[bake] base snapshot %s  sha256=%s  x[%g,%g] z[%g,%g] %d x %d  %d hole(s)"
                  % (args.base, base["sha"], base["header"]["minX"],
                     base["header"]["minX"] + base["header"]["nx"] * base["header"]["pitch"],
                     base["header"]["minZ"],
                     base["header"]["minZ"] + base["header"]["nz"] * base["header"]["pitch"],
                     base["header"]["nx"], base["header"]["nz"], len(base["holes"])))
            plan = tile_plan(studio, studio_id, args.cells, injected)
            pad = call(studio, studio_id, "TerrainBake.padFor()", timeout=60, injected=injected)
            # REFUSAL 8: A LANDFORM MAY NOT GO INTO THE SAME GROUND TWICE. `reshapeWanted` answers
            # "changed" when a cell's stamp names a landform that is not the one on disk; re-baking
            # then ADDS the new ops on top of the old ones, which is the +24.04-stud double ridge
            # this task measured in Karen's place before writing (ESCALATE.md 2026-11-02 ~20:35).
            # The fix is the backup, not another bake, so the tool says so instead of printing it.
            if args.command == "bake":
                answers = {}
                for cell in args.cells:
                    answer = call(studio, studio_id,
                                  "(function() local wanted, why, kind = TerrainBake.reshapeWanted(\"%s\") "
                                  "return { wanted = wanted, why = why, kind = kind } end)()" % cell,
                                  timeout=60, injected=injected)
                    print("  reshape %-3s %-7s %s" % (cell, answer["kind"], answer["why"]))
                    answers[cell] = answer["kind"]
                problem = reshape_blocked(answers)  # refusal 7b
                if problem:
                    return refuse(problem)
            sampler = profile_sampler(studio, studio_id, args.cells, injected, base)
            profiles, _ = profiles_once(
                studio, studio_id, args.cells, injected,
                "TerrainBake.pointSampler(HttpService:JSONDecode([==[%s]==]))" % sampler)
            code, _ = tile_pass(studio, studio_id, args, facts, sha,
                                dry=args.command == "measure", injected=injected, profiles=profiles,
                                keep=keep, live=live, base=base, plan=plan, pad=pad)
            return code
    finally:
        studio.close()
    return 1


# ---------------------------------------------------------------- selftest (CI; no Studio, no network)

def _raises(fn):
    try:
        fn()
    except Exception:  # noqa: BLE001 -- "it refuses" IS the assertion
        return True
    return False


def selftest():
    """Every refusal above against a scripted Studio, plus the arithmetic `plan` asserts."""
    failures = []

    def ok(name, condition, detail=""):
        print("  %s %s%s" % ("PASS" if condition else "FAIL", name, ("  " + detail) if detail else ""))
        if not condition:
            failures.append(name)

    print("[bake] selftest")
    facts = luau_facts()
    ok("the Luau's own numbers are readable",
       facts["tile"] == 128 and facts["maxVoxels"] == 24576 and facts["voxel"] == 4,
       "tile=%d maxVoxels=%d voxel=%d" % (facts["tile"], facts["maxVoxels"], facts["voxel"]))
    ok("the tile is a whole number of voxels", facts["tile"] % facts["voxel"] == 0)

    # The footprint, re-derived, against the number 327a measured and grid.spec asserts.
    box = footprint(facts)
    ok("the footprint is 4490 x 2986 at (-6700, -6600)",
       (box["minX"], box["minZ"], box["maxX"] - box["minX"], box["maxZ"] - box["minZ"]) == (-6700, -6600, 4490, 2986),
       "x[%d,%d] z[%d,%d]" % (box["minX"], box["maxX"], box["minZ"], box["maxZ"]))

    c1 = cell_of("C1", facts)
    ok("C1's interior is Grid.boundsOf's",
       (c1["minX"], c1["maxX"], c1["minZ"], c1["maxZ"]) == (-4434, -3364, -5086, -3656),
       "x[%d,%d] z[%d,%d]" % (c1["minX"], c1["maxX"], c1["minZ"], c1["maxZ"]))
    roads = roads_of("C1", facts)
    ok("C1's four road centrelines are Grid.roadsOf's",
       (roads["main"], roads["muster"], roads["west"], roads["east"]) == (-5107, -3635, -4455, -3343),
       "main=%g muster=%g west=%g east=%g" % (roads["main"], roads["muster"], roads["west"], roads["east"]))

    # THE TILE COUNT, both ways round (Director decision 6).
    whole = region_for(list(CELL_IDS), facts)
    count, nx, nz = tile_count(whole, facts["tile"])[:3]
    ok("the whole-world region is the footprint + 430",
       (whole["maxX"] - whole["minX"], whole["maxZ"] - whole["minZ"]) == (4490 + 860, 2986 + 860),
       "%d x %d" % (whole["maxX"] - whole["minX"], whole["maxZ"] - whole["minZ"]))
    ok("the whole world is 43 x 31 = 1333 tiles", (nx, nz, count) == (43, 31, 1333),
       "%d x %d = %d" % (nx, nz, count))
    c1region = region_for(["C1"], facts)
    count1, nx1, nz1 = tile_count(c1region, facts["tile"])[:3]
    ok("C1 + its roads + 200 is 13 x 16 = 208 tiles", (nx1, nz1, count1) == (13, 16, 208),
       "%d x %d = %d" % (nx1, nz1, count1))
    # THE COUNT IS PHASE DEPENDENT, so one right cell proves nothing about the other seven
    # (round-2 finding 3): every committed count is re-derived here, and A1 and C2 are named.
    for cell_id in CELL_IDS:
        n_cell, nxc, nzc = tile_count(region_for([cell_id], facts), facts["tile"])[:3]
        ok("the committed count for %s is the arithmetic's (%d x %d)" % (cell_id, nxc, nzc),
           n_cell == EXPECTED_TILES[cell_id], "%d vs %d" % (n_cell, EXPECTED_TILES[cell_id]))
    ok("A1 is 224, NOT C1's 208 -- equal cells do not tile equally",
       EXPECTED_TILES["A1"] == 224 and EXPECTED_TILES["C2"] == 221
       and EXPECTED_TILES["A1"] != EXPECTED_TILES["C1"])
    # ROUND-3 FINDING 1: this case used to go through `main(["plan", ...])`, which constructs
    # `Studio()`, whose miss path is `sys.exit` -- and `SystemExit` is not an `Exception`, so CI's
    # ubuntu runner aborted the selftest here and ~45 later checks never ran. `command_plan` takes
    # the transport as two arguments, so it is called with NONE and the step is hermetic as its name
    # claims. What is asserted is the arithmetic and the committed count, which need no Studio.
    plan_args = argparse.Namespace(cells=["A1"])
    ok("`plan` ACCEPTS a second cell, which round 2 would have refused (NO transport: command_plan,"
       " never Studio())", command_plan(plan_args, facts, None, None) == 0)
    # AND THE COUNT IS ASSERTED, not just printed: a wrong committed number REFUSES. Without this
    # the case above passes with the whole assertion arm deleted.
    kept = EXPECTED_TILES["A1"]
    EXPECTED_TILES["A1"] = kept + 1
    try:
        ok("`plan` REFUSES when the arithmetic and the committed count disagree",
           command_plan(plan_args, facts, None, None) == 2)
    finally:
        EXPECTED_TILES["A1"] = kept
    # REFUSAL 7's whitelist never matched: `flag_overrides` answers `DHFlag_<NAME>=<value>` and the
    # check compared the WHOLE string with bare names, so the bake was refused in Karen's place over
    # the two flags the list exists to allow (measured 2026-11-02 18:00 UTC, 15 of 15 refused).
    # THE FIRST WET BAKE wrote all 208 tiles and then died in `parse_json`: `epochInputFor` answers a
    # STRING, and the landform digest inside it carries braces, so looking for the first `{` decoded
    # from the middle of the string. Each opener is tried in order now and the first that DECODES wins.
    braced = json.dumps(chr(123) + chr(34) + "x" + chr(34) + ": 1" + chr(125))
    ok("a STRING reply parses, even when the string itself holds a brace",
       parse_json(braced) == chr(123) + chr(34) + "x" + chr(34) + ": 1" + chr(125))
    ok("a quote in Studio's own preamble does not win over the JSON behind it",
       parse_json('[bake] ' + chr(34) + 'x' + chr(34) + chr(10) + '{"a": 1}') == {"a": 1})
    ok("an object reply still parses, and a line of Studio's own text in front of it is ignored",
       parse_json('Executed: {"a": [1, 2]}') == {"a": [1, 2]}
       and parse_json('[1, "{"]') == [1, "{"])
    ok("refusal 7 reads the NAME out of a DHFlag_<NAME>=<value> override, which its whitelist needs",
       override_name_of("DHFlag_GRID_PREVIEW=true") == "GRID_PREVIEW"
       and override_name_of("DHFlag_GRID_PREVIEW=true") in KARENS_FLAGS
       and "DHFlag_GRID_PREVIEW=true" not in KARENS_FLAGS
       and override_name_of("RANGE_SOLO") == "RANGE_SOLO")
    ok("every tile origin is voxel-aligned, so ExpandToGrid has nothing to do",
       tile_count(c1region, facts["tile"])[3] % facts["voxel"] == 0
       and tile_count(c1region, facts["tile"])[4] % facts["voxel"] == 0)
    ok("a one-cell region is smaller than the whole world's", count1 < count)

    # The Y-band split: a 128-stud tile at resolution 4 is 1024 columns, so the ceiling allows 24
    # voxels = 96 studs a call -- the measured number, arrived at rather than retyped.
    columns = (facts["tile"] // facts["voxel"]) ** 2
    ok("the ceiling allows 96 studs of Y band per call",
       facts["voxel"] * (facts["maxVoxels"] // columns) == 96,
       "%d columns, %d studs" % (columns, facts["voxel"] * (facts["maxVoxels"] // columns)))

    # ---- the refusals, each against the state it is about
    ok("refusal 5 rejects a missing --backup", check_backup(None) is not None)
    ok("refusal 5 rejects --backup census", "census is not accepted" in (check_backup("census") or ""))
    ok("refusal 5 rejects a file that is not there", check_backup("no-such-file.rbxl") is not None)
    inside = os.path.join(REPO, "selftest-backup.rbxl")
    try:
        with open(inside, "wb") as handle:
            handle.write(b"x")
        ok("refusal 5 rejects a backup inside the repository",
           "inside the repository" in (check_backup(inside) or ""))
    finally:
        if os.path.exists(inside):
            os.remove(inside)
    outside = os.path.join(runs_dir(), "selftest-backup.rbxl")
    try:
        with open(outside, "wb") as handle:
            handle.write(b"x")
        ok("refusal 5 ACCEPTS a fresh, non-empty .rbxl outside the repository",
           check_backup(outside) is None, str(check_backup(outside)))
        old = time.time() - (BACKUP_MAX_AGE_HOURS + 1) * 3600
        os.utime(outside, (old, old))
        ok("refusal 5 rejects a stale backup", "older than" in (check_backup(outside) or ""))
        empty = outside.replace(".rbxl", "-empty.rbxl")
        with open(empty, "wb"):
            pass
        ok("refusal 5 rejects an empty backup", "is empty" in (check_backup(empty) or ""))
        # A REAL FILE with the wrong suffix, so the suffix rule is what refuses it and not the
        # "is not a file" rule above it -- the first version of this case passed for the wrong reason.
        wrong = outside.replace(".rbxl", ".txt")
        with open(wrong, "wb") as handle:
            handle.write(b"x")
        ok("refusal 5 rejects a real file that is not a .rbxl",
           "not a .rbxl" in (check_backup(wrong) or ""), str(check_backup(wrong)))
        for path in (outside, empty, wrong):
            if os.path.exists(path):
                os.remove(path)
    finally:
        pass

    class FakeStudio:
        """No subprocess and no Studio: the refusals are the thing under test, not the transport."""

        def __init__(self, mode="Edit", place=FOREST_PLACE_ID, flags=None, pose=None):
            self._mode, self._place = mode, place
            self._flags, self._pose = flags or {}, pose

        def mode(self, studio_id=None):
            return self._mode

        def query(self, _datamodel, _code, studio_id=None):
            return self._place

    import studio_mcp
    saved_flags, saved_pose = studio_mcp.flag_overrides, studio_mcp.pose_override
    globals()["flag_overrides"] = lambda s, studio_id=None: s._flags
    globals()["pose_override"] = lambda s, studio_id=None: s._pose
    try:
        ok("refusal 1 rejects Play mode",
           "not Edit" in (check_place(FakeStudio(mode="Play"), "x") or ""))
        ok("refusal 2 rejects the DEV place",
           "not the Forest Test" in (check_place(FakeStudio(place="136410205938347"), "x") or ""))
        ok("refusals 1 and 2 ACCEPT Edit on the Forest Test", check_place(FakeStudio(), "x") is None)
        # ROUND-1 FINDING 1: these four fed the fake transport BARE names, which is not the shape
        # `flag_overrides` answers, so reverting `override_names` left every one of them green --
        # the gate testing its own harness instead of the tool's input, which is how a bug visible
        # on the first real call shipped. Every case below now carries the real shape,
        # `DHFlag_<NAME>=<value>`, exactly as `QUERY_FLAG_OVERRIDES` builds it.
        ok("refusal 7 rejects a stray flag override, in the shape the transport answers",
           "GRID_HILLSHADE" in (check_overrides(FakeStudio(flags=["DHFlag_GRID_HILLSHADE=true"]), "x") or ""))
        ok("refusal 7 LEAVES Karen's own two alone (lesson K), in that same shape",
           check_overrides(FakeStudio(flags=["DHFlag_GRID_PREVIEW=true", "DHFlag_RANGE_SOLO=true"]), "x")
           is None)
        ok("refusal 7 accepts an override the operator DECLARES with --keep-flags, and only that one",
           check_overrides(FakeStudio(flags=["DHFlag_LOBBY=true"]), "x", ("LOBBY",)) is None
           and "SHOP" in (check_overrides(FakeStudio(flags=["DHFlag_SHOP=true"]), "x", ("LOBBY",)) or ""))
        ok("refusal 7 names `set <NAME> off` and never `clear`",
           "never `clear`" in (check_overrides(FakeStudio(flags=["DHFlag_X=true"]), "x") or ""))
        ok("refusal 7 rejects a live pose override",
           "pose override" in (check_overrides(FakeStudio(pose="hip"), "x") or ""))
    finally:
        globals()["flag_overrides"], globals()["pose_override"] = saved_flags, saved_pose

    # The reply parser, including the shape mapgen.py's own note is about.
    ok("the reply parser reads a JSON object after a line of text",
       parse_json('some note\n{"a": 1}')["a"] == 1)
    ok("the reply parser reads an ARRAY, not the first brace inside it",
       parse_json('note\n[{"a": 1}]')[0]["a"] == 1)
    # THE BARE SCALAR, which killed the first 328e bake's report line AFTER all 208 tiles had been
    # written: `stampShape` answers a number and the parser looked only for the three containers.
    ok("the reply parser reads a bare number, which stampShape answers",
       parse_json("1") == 1 and parse_json("[bake] note\n17") == 17 and parse_json("0") == 0)
    ok("the reply parser reads a bare boolean and still prefers JSON that consumes the reply",
       parse_json("true") is True and parse_json('1\n{"a": 2}')["a"] == 2)
    try:
        parse_json("no json here")
        ok("the reply parser refuses a reply with no JSON", False)
    except RuntimeError:
        ok("the reply parser refuses a reply with no JSON", True)

    # ---- THE INJECTION (Director decision 2): the text of the tree, and no require of a module.
    injected, shas = prelude()
    sent = CALL_TEMPLATE % (injected, 'TerrainBake.survey("C1")')
    ok("the sent Luau carries the modules' own TEXT, not a require of them",
       "Relief.LANDFORMS" in sent and "TerrainBake.WriteVoxels" not in sent
       and 'require(ReplicatedStorage:WaitForChild("Shotgun"))' not in sent,
       "%d bytes" % len(sent))
    ok("no module require survives the rewrite, so nothing can hang on WaitForChild",
       "require(GridFolder)" not in sent and 'WaitForChild("Grid")' not in sent
       and 'require(module)' not in sent)
    ok("the three injected modules are all there, in dependency order",
       sent.index("INJECTED_Relief =") < sent.index("INJECTED_Grid =")
       < sent.index("INJECTED_TerrainBake ="))
    for name, _ in MODULES:
        ok("the sha256 of the injected %s is 64 hex" % name, len(shas[name]) == 64, shas[name][:16])
    ok("the Shotgun stub carries the number off the Shotgun FILE, not a retyped one",
       ("Slug = %g" % shotgun_slug_range()) in sent and shotgun_slug_range() > 0,
       "Slug = %g" % shotgun_slug_range())
    # IF GRID EVER READS A SECOND FIELD OF SHOTGUN the stub is wrong, and this is what says so.
    with open(os.path.join(REPO, "src", "shared", "Grid", "init.luau"), encoding="utf-8") as handle:
        grid_text = handle.read()
    accesses = sorted(set(re.findall(r"Shotgun[.][A-Za-z0-9_.]+", grid_text)))
    ok("Grid reads exactly one thing out of Shotgun, so the stub is enough",
       accesses == [SHOTGUN_ACCESS], ", ".join(accesses) or "none")
    # A REWRITE THAT NO LONGER MATCHES IS A REFUSAL, not a silent send that hangs in Studio.
    saved = REWRITES["TerrainBake"]
    try:
        REWRITES["TerrainBake"] = [("local Grid = require(NoSuchThing)", "local Grid = nil")]
        ok("a require the injection cannot find refuses BEFORE anything is sent",
           _raises(lambda: module_text("TerrainBake", BAKE_LUAU)))
    finally:
        REWRITES["TerrainBake"] = saved
    ok("the place id in the tool is the Forest Test's", FOREST_PLACE_ID == "130094961655666")
    # MEASURED 2026-11-02 in the Forest Test's Play server: GridCensus has measure/survey/line/
    # publish and NO `run`. The first version of this seam called `run()`.
    seam = CENSUS_SEAM % "C1"
    ok("the census seam calls GridCensus.survey and GridCensus.line, not a run() that is not there",
       "GridCensus.survey(" in seam and "GridCensus.line(" in seam and ".run()" not in seam)

    # The place id in the tool and the one in the Luau are one fact.
    ok("the tool and the Luau name the same place",
       str(int(number_from(BAKE_LUAU, r"^TerrainBake\.PLACE_ID = ([0-9_]+)"))) == FOREST_PLACE_ID)

    # ---- the three refusals round 1 shipped with no case, and the two other items design 6.4 names
    ok("refusal 3 ACCEPTS a clean tree", check_clean_tree(("abc123", []))[1] is None)
    ok("refusal 3 rejects a dirty tree, and names the files",
       "src/x.luau" in (check_clean_tree(("abc123", ["src/x.luau"]))[1] or ""))
    ok("refusal 6 refuses `bake` with no --cells, before any Studio is opened", main(["bake"]) == 2)
    ok("refusal 6 refuses `archive` with no --cells", main(["archive"]) == 2)
    ok("an unknown cell is refused", main(["plan", "--cells", "Z9"]) == 2)

    # ---- REFUSAL 4, AS THE ECHO (Director decision 2). The old check compared Script.Source,
    # which reads length 0 for all 297 scripts in the Forest Test, so it could only ever refuse
    # there. This one compares the constants the ARRIVED code defines with the files' own.
    echo_facts = luau_facts()
    good = {"tile": echo_facts["tile"], "maxVoxels": echo_facts["maxVoxels"],
            "roadHalf": echo_facts["roadHalf"], "voxel": echo_facts["voxel"],
            "blend": echo_facts["blend"], "originX": echo_facts["originX"],
            "cellDepth": echo_facts["cellDepth"], "placeId": int(FOREST_PLACE_ID),
            "cells": len(CELL_IDS), "roads": (echo_facts["rows"] + 1) + (echo_facts["columns"] + 1),
            "bakeVersion": 1}
    saved_call = globals()["call"]
    try:
        globals()["call"] = lambda *a, **k: dict(good)
        ok("refusal 4 PASSES when the arrived code's own numbers match the files",
           check_echo(FakeStudio(), "x", echo_facts, "<injected>", shas) is None)
        globals()["call"] = lambda *a, **k: dict(good, tile=64)
        said = check_echo(FakeStudio(), "x", echo_facts, "<injected>", shas) or ""
        ok("refusal 4 refuses a stale or truncated module, and names the field",
           "tile: Studio says 64" in said, said.splitlines()[-1] if said else "")
        globals()["call"] = lambda *a, **k: dict(good, cells=7)
        ok("refusal 4 refuses when the grid that arrived has the wrong number of cells",
           "cells: Studio says 7" in (check_echo(FakeStudio(), "x", echo_facts, "<i>", shas) or ""))
        globals()["call"] = lambda *a, **k: dict(good, placeId=136410205938347)
        ok("refusal 4 refuses a TerrainBake pinned to another place",
           "placeId" in (check_echo(FakeStudio(), "x", echo_facts, "<i>", shas) or ""))
        # THE NUMBER STUDIO ACTUALLY ANSWERED, 2026-11-02, with this prelude injected into DEV.
        ok("the expected road count is the 8 Studio answered, not a formula nobody ran",
           good["roads"] == 8, "roads=%d" % good["roads"])
        globals()["call"] = lambda *a, **k: dict(good, roads=11)
        ok("refusal 4 refuses a grid whose road count is not 8",
           "roads: Studio says 11" in (check_echo(FakeStudio(), "x", echo_facts, "<i>", shas) or ""))
    finally:
        globals()["call"] = saved_call

    # ---- THE PROFILES GO IN FROM THE TOOL, ONCE (round-2 finding 2). The tile expression carries
    # them; `bakeTileAt` refuses a tile that arrives without them, so neither half can drift.
    sent_tiles = []

    class Args:
        cells = ["C1"]
        tiles = 2
        y_min, y_max = -100.0, 400.0
        base = None
        base_sha = None
        out = None
        source = None
        studio_name = None
        allow_local_file = False

    # A SYNTHETIC BASE covering the first two tiles plus their pad, so the tile pass can cut real
    # slices out of it with no Studio.
    fake_plan = [{"minX": -4736, "minZ": -5376}, {"minX": -4608, "minZ": -5376}]
    fake_pad = 204
    fake_header = {"pitch": 4, "minX": -5120, "minZ": -5760, "nx": 320, "nz": 240,
                   "minY": 100.0, "maxY": 100.0, "yMin": -100.0, "yMax": 400.0}
    fake_codes = array.array("h", [round((100.0 - SLICE_OFFSET) * SLICE_SCALE)]) * (320 * 240)
    fake_base = {"header": fake_header, "codes": fake_codes, "holes": set(), "sha": "f" * 64}

    saved_call, saved_log = globals()["call"], globals()["log_run"]
    try:
        def record(studio, studio_id, expression, timeout=None, injected=None):
            sent_tiles.append((expression, injected))
            return {"minX": 0, "minZ": 0, "calls": 1, "voxels": 1, "bandMin": 0, "bandMax": 1,
                    "elapsedMs": 5}

        globals()["call"] = record
        globals()["log_run"] = lambda cells, entries, keep=None, live=None: "<log>"
        code, entries = tile_pass(None, "x", Args(), echo_facts, "abc", True,
                                  injected="<PRELUDE>", profiles='[{"road":{"id":"EW2"}}]',
                                  base=fake_base, plan=fake_plan, pad=fake_pad)
        ok("the tile pass runs every tile it was asked for", code == 0 and len(entries) == 2)
        ok("EVERY tile call carries the profiles the tool computed once",
           all("JSONDecode([==[" in e and '"EW2"' in e for e, _ in sent_tiles), sent_tiles[0][0][:90])
        ok("every tile of one run carries the SAME profile bytes",
           len({e.split("JSONDecode([==[", 2)[1] for e, _ in sent_tiles}) == 1)
        ok("every tile carries a DIFFERENT slice -- its own, not a shared one",
           len({e.split("JSONDecode([==[", 2)[2] for e, _ in sent_tiles}) == len(sent_tiles))
        ok("every tile of one run carries the SAME injected prelude",
           {i for _, i in sent_tiles} == {"<PRELUDE>"})
    finally:
        globals()["call"], globals()["log_run"] = saved_call, saved_log
    ok("the Luau refuses a tile that arrives with no profiles, rather than reading live terrain",
       "no profiles were handed to tile" in open(BAKE_LUAU, encoding="utf-8").read())
    ok("bakeTileAt no longer falls back to profilesFor",
       "profiles or TerrainBake.profilesFor" not in open(BAKE_LUAU, encoding="utf-8").read())
    bake_text = open(BAKE_LUAU, encoding="utf-8").read()
    ok("EVERY tile call carries its own slice of the base snapshot",
       all("decodeSlice" not in e or True for e, _ in sent_tiles)
       and all(e.count("JSONDecode([==[") == 2 for e, _ in sent_tiles),
       sent_tiles[0][0][:60])
    ok("the Luau refuses a tile that arrives with no base snapshot slice",
       "no base snapshot slice was handed to tile" in bake_text)
    ok("profilesFor refuses to run with no sampler, so it can never raycast live terrain",
       "TerrainBake.profilesFor: no sampler" in bake_text)
    tool_text = open(os.path.join(REPO, "tools", "terrainbake.py"), encoding="utf-8").read()
    # THE EPOCH'S ONE CALL SITE, by regex rather than by quoting the wrong text -- a check that
    # quotes the string it forbids matches its own source and can never fail.
    ok("the bake's epoch hashes the SNAPSHOT sha and never the git sha (design 5.4, 328e note c)",
       re.findall(r"epoch = epoch_for\(studio, studio_id, ([A-Za-z_.]+)", tool_text) == ["args.base_sha"],
       str(re.findall(r"epoch = epoch_for\(studio, studio_id, ([A-Za-z_.]+)", tool_text)))
    ok("bakeTileAt reads no terrain of its own: the slice comes from the tool",
       "TerrainBake.snapshot(" not in bake_text.split("function TerrainBake.bakeTileAt")[1]
       .split("function TerrainBake.roadDistance")[0])

    # ---- THE BASE SNAPSHOT FILE (B2): it round-trips, it is DETERMINISTIC, and a slice of it is a
    # byte slice of the stored codes.
    import tempfile
    scratch = tempfile.mkdtemp(prefix="dh-base-")
    try:
        header = {"pitch": 4, "minX": -40, "minZ": -20, "nx": 3, "nz": 2,
                  "minY": 98.75, "maxY": 101.25, "yMin": -100.0, "yMax": 400.0}
        codes = [round((h - SLICE_OFFSET) * SLICE_SCALE) for h in SLICE_FIXTURE_HEIGHTS]
        one = os.path.join(scratch, "a.bin")
        two = os.path.join(scratch, "b.bin")
        sha_one = base_save(one, header, codes, [2])
        sha_two = base_save(two, header, codes, [2])
        ok("two snapshots of the same ground are the same bytes and the same sha256",
           sha_one == sha_two and open(one, "rb").read() == open(two, "rb").read(), sha_one[:16])
        back = base_load(one)
        ok("the .bin round-trips its lattice, its codes and its holes",
           back["header"]["nx"] == 3 and back["holes"] == {2}
           and list(back["codes"]) == codes and back["sha"] == sha_one)
        ok("base_at reads a height, and nil at a hole and outside the snapshot",
           base_at(back, -38, -18) == 100.0 and base_at(back, -34, -18) is None
           and base_at(back, -30, -18) == 101.25 and base_at(back, -60, -18) is None,
           "%r %r" % (base_at(back, -38, -18), base_at(back, -30, -18)))
        ok("the Python encoder's bytes are the fixture the Luau spec decodes",
           base64.b64encode(_sliced(codes)).decode("ascii") == SLICE_FIXTURE_B64,
           base64.b64encode(_sliced(codes)).decode("ascii"))
        cut, why = base_slice(back, -40, -20, -32, -12)
        ok("a slice is a byte slice of the stored codes, with its own hole index",
           why is None and cut["nx"] == 2 and cut["nz"] == 2 and cut["minX"] == -40
           and base64.b64decode(cut["b64"]) == _sliced([codes[0], codes[1], codes[3], codes[4]])
           and cut["holes"] == [2], "%r %r" % (cut and cut["holes"], why))
        _, why = base_slice(back, -400, -20, -32, -12)
        ok("a slice the snapshot does not cover is refused, with both rectangles named",
           why is not None and "does not cover" in why, why)
        # bad magic
        broken = os.path.join(scratch, "c.bin")
        with open(broken, "wb") as handle:
            handle.write(b"not a snapshot\n{}\n")
        ok("a file that is not a base snapshot is refused by its magic",
           _raises(lambda: base_load(broken)))
        # truncated payload
        short = os.path.join(scratch, "d.bin")
        body = open(one, "rb").read()
        with open(short, "wb") as handle:
            handle.write(body[:-2])
        ok("a truncated .bin is refused, and says how many codes it holds",
           _raises(lambda: base_load(short)))

        class BaseArgs:
            def __init__(self, path=None, sha=None):
                self.base, self.base_sha = path, sha

        region = {"minX": -40, "maxX": -28, "minZ": -20, "maxZ": -12}
        ok("refusal 9 refuses a bake with no --base",
           check_base(BaseArgs(None, sha_one), region)[1].startswith("--base is missing"))
        ok("refusal 9 refuses a --base with no --base-sha",
           "--base-sha is missing" in check_base(BaseArgs(one, None), region)[1])
        ok("refusal 9 refuses a base snapshot inside the repository",
           "OUTSIDE the repository" in check_base(
               BaseArgs(os.path.join(REPO, "x.bin"), sha_one), region)[1])
        ok("refusal 9 refuses a base snapshot that is not there",
           "no base snapshot at" in check_base(
               BaseArgs(os.path.join(scratch, "nope.bin"), sha_one), region)[1])
        ok("refusal 9 refuses a STALE sha -- the one mistake that looks like success",
           "DIFFERENT base" in check_base(BaseArgs(one, "0" * 64), region)[1])
        ok("refusal 9 ACCEPTS the file whose sha256 is the one named, and covers the region",
           check_base(BaseArgs(one, sha_one), region)[1] is None)
        ok("refusal 9 refuses a base that does not cover the run's region",
           "does not hold this run's region" in check_base(
               BaseArgs(one, sha_one), {"minX": -40, "maxX": 900, "minZ": -20, "maxZ": -12})[1])
    finally:
        for name in os.listdir(scratch):
            os.remove(os.path.join(scratch, name))
        os.rmdir(scratch)

    # ---- REFUSAL 7b, which had no case at all until now (328e note h).
    ok("refusal 7b refuses a cell whose ground already carries a DIFFERENT landform",
       "already carries a DIFFERENT landform" in (reshape_blocked({"C1": "changed"}) or ""),
       reshape_blocked({"C1": "changed"}))
    ok("refusal 7b names EVERY blocked cell, in order",
       (reshape_blocked({"D1": "changed", "A1": "changed", "C1": "same"}) or "").startswith("A1, D1"))
    ok("refusal 7b lets a cell whose stamp is the same landform through",
       reshape_blocked({"C1": "same"}) is None and reshape_blocked({"C1": "virgin"}) is None)

    # ---- WHICH WINDOW (L-055). A backup .rbxl re-opened reports place 0 and the FILE's name;
    # Karen's live window reports the Forest Test's place id and 'Driven Hunt Forest Test'. Both
    # were read off this machine on 2026-11-03 with all three windows open.
    ok("the live Forest Test is accepted by its place id, with or without a name",
       local_ok(FOREST_PLACE_ID, "Driven Hunt Forest Test", None, False)
       and local_ok(FOREST_PLACE_ID, "Driven Hunt Forest Test", "Forest Test", False))
    ok("a name that does not match is refused even on the right place id",
       not local_ok(FOREST_PLACE_ID, "Driven Hunt Forest Test", "FT-base-328k", False))
    ok("a local file (place 0) is refused unless --allow-local-file AND the name match",
       not local_ok("0", "FT-base-328k.rbxl", "FT-base-328k", False)
       and not local_ok("0", "FT-base-328k.rbxl", None, True)
       and local_ok("0", "FT-base-328k.rbxl", "FT-base-328k", True))
    ok("DEV is refused however the flags are set -- the one thing L-014 is about",
       not local_ok("136410205938347", "Driven Hunt DEV", None, True)
       and not local_ok("136410205938347", "Driven Hunt DEV", "DEV", True))
    ok("--allow-local-file cannot reach a mutating command",
       main(["bake", "--cells", "C1", "--allow-local-file", "--studio-name", "x"]) == 2)
    ok("--allow-local-file without --studio-name is refused",
       main(["snapshot", "--allow-local-file"]) == 2)

    # THE RUN-LOG WRITER (design 6.3).
    rows = [{"minX": -4736, "minZ": -5376, "elapsedMs": 7}]
    path = log_run(["C1"], rows)
    try:
        with open(path, encoding="utf-8") as handle:
            back = json.load(handle)
        ok("the run log round-trips its per-tile reports", back == rows)
        ok("the run log is named for the cells and sits in .terrainbake",
           path.endswith("-C1.json") and os.path.dirname(path) == RUN_LOG_DIR)
    finally:
        if os.path.exists(path):
            os.remove(path)

    # THE CANONICAL ENCODER against the Luau own output (design 6.4).
    ok("the Python canonical encoder matches the Luau, byte for byte",
       canonical(CANONICAL_FIXTURE_INPUT) == CANONICAL_FIXTURE_OUTPUT,
       canonical(CANONICAL_FIXTURE_INPUT)[:120])
    ok("canonical sorts keys, so table order cannot change the epoch",
       canonical({"b": 1, "a": 2}) == canonical({"a": 2, "b": 1}) == '{"a":2,"b":1}')
    ok("canonical formats numbers %.6g, as the Luau does",
       canonical(0.1 + 0.2) == "0.3" and canonical(1430) == "1430")
    ok("canonical refuses what it cannot encode", _raises(lambda: canonical(object())))

    # THE EPOCH IS A DIGEST OF THAT STRING, and 16 hex of it (design 5.4).
    def digest(text):
        return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]

    ok("the epoch is 16 hex of sha256 over the input string, and two inputs differ",
       len(digest(CANONICAL_FIXTURE_OUTPUT)) == 16
       and digest(CANONICAL_FIXTURE_OUTPUT) != digest(CANONICAL_FIXTURE_OUTPUT + "x"),
       digest(CANONICAL_FIXTURE_OUTPUT))
    ok("a BAKE_VERSION bump changes the epoch",
       digest(canonical(CANONICAL_FIXTURE_INPUT))
       != digest(canonical(dict(CANONICAL_FIXTURE_INPUT, bakeVersion=2))))

    print("[bake] selftest: %d check(s) failed" % len(failures) if failures else "[bake] selftest: PASS")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
