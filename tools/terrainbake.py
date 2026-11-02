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

Usage:
  python tools/terrainbake.py plan    [--cells C1]                      # read-only: tiles + the cost estimate
  python tools/terrainbake.py snapshot --cells C1 [--out <file>]        # read-only: the base, to a file outside the repo
  python tools/terrainbake.py measure --cells C1 [--tiles 10]           # read-only: per-tile cost, DRY (no WriteVoxels)
  python tools/terrainbake.py bake    --cells C1 --backup <f>.rbxl [--tiles 10]
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
  7. A flag or pose override is live -- the rule `test` and `test2` already enforce. EXCEPT the two
     Karen has set on purpose in the Forest Test (GRID_PREVIEW, RANGE_SOLO): the dispatch says leave
     them, and clearing them would destroy her setup (lesson K).

The one pasteable report line:

  [bake] OK: 10/10 tiles @ <sha> cells=C1 epoch=<16 hex> worstTileMs=<n> (clean tree)
  [bake] REFUSED: <reason>

Every run appends its per-tile reports to .terrainbake/<utc>-<cells>.json (git-ignored).
"""

import argparse
import hashlib
import json
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
    import math
    x0 = tile * math.floor(region["minX"] / tile)
    z0 = tile * math.floor(region["minZ"] / tile)
    nx = max(0, math.ceil((region["maxX"] - x0) / tile))
    nz = max(0, math.ceil((region["maxZ"] - z0) / tile))
    return nx * nz, nx, nz, x0, z0


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


def parse_json(body):
    """The JSON value inside StudioMCP's reply text, which may carry a line of its own around it.

    A reply can be a STRING as well as an object or an array -- `epochInputFor` answers one -- and a
    string that holds a brace cannot be found by looking for the brace. So each of `{`, `[` and `"`
    is tried in the order it appears and the first that DECODES wins. Measured: the first wet bake in
    Karen's place wrote all 208 tiles and then died here, because the epoch input string carries the
    landform digest's own braces (2026-11-02 18:12 UTC).
    """
    seen = sorted(i for i in (body.find("{"), body.find("["), body.find('"')) if i >= 0)
    for start in seen:
        try:
            value, _ = json.JSONDecoder().raw_decode(body[start:])
            return value
        except ValueError:
            continue
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


def check_place(studio, studio_id):
    """Refusals 1 and 2, re-run before EVERY mutating call (B1), by place id and never by name."""
    mode = studio.mode(studio_id=studio_id)
    if "Edit" not in mode:
        return "Studio is in %r, not Edit. Karen may be playing; the bake only runs in Edit." % mode
    place = studio.query("Edit", PLACE_QUERY, studio_id=studio_id).strip().strip('"')
    if place != FOREST_PLACE_ID:
        return "that Studio is open on place %s, not the Forest Test %s" % (place, FOREST_PLACE_ID)
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

def log_run(cells, entries):
    os.makedirs(RUN_LOG_DIR, exist_ok=True)
    name = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime()) + "-" + ",".join(cells) + ".json"
    path = os.path.join(RUN_LOG_DIR, name)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(entries, handle, indent=2)
    print("[bake] run log: %s" % os.path.relpath(path, REPO))
    return path


# ---------------------------------------------------------------- the commands

def resolve(studio):
    """(studio_id, why) for the Forest Test. The ONE resolver, by place id (L-055, L-014)."""
    from studio_mcp import studio_for_place
    studio_id, name, why = studio_for_place(studio, FOREST_PLACE_ID)
    if studio_id is None:
        return None, why
    print("[bake] Studio: %s (%s), place %s" % (studio_id[:8], name, FOREST_PLACE_ID))
    return studio_id, None


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


def profiles_once(studio, studio_id, cells, injected):
    """THE LONG PROFILES, COMPUTED ONCE, BEFORE ANY VOXEL IS WRITTEN (round-2 finding 2).

    Round 2 let every tile call `TerrainBake.profilesFor` for itself, whose sampler raycasts LIVE
    terrain: from the second tile on, that reads ground this bake has already written, so two tiles
    of one road could meet at a step and the result would depend on the tile order. Here the tool
    asks for them ONCE, holds the JSON, and sends THE SAME BYTES to every tile -- which is what
    makes the crown at a shared x identical by construction rather than by argument.

    It also prints what design 7.1 obliges: the grade each road was given, whether it had to be
    relaxed, the worst cut-or-fill, the realised grade change, and every breach, in full.
    """
    rows = call(studio, studio_id, 'TerrainBake.profilesFor({%s})'
                % ",".join('"%s"' % c for c in cells), timeout=300, injected=injected)
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


def tile_pass(studio, studio_id, args, facts, sha, dry, injected=None, profiles=None):
    """The tile loop, shared by `measure` (dry) and `bake` (wet). One MCP call per tile."""
    cells = args.cells
    region = region_for(cells, facts)
    count = tile_count(region, facts["tile"])[0]
    limit = min(args.tiles or count, count)
    y_min, y_max = args.y_min, args.y_max
    entries, worst = [], 0
    print("[bake] %s: %d of %d tiles, cells=%s" % ("measure (DRY)" if dry else "bake", limit, count, ",".join(cells)))
    for index in range(1, limit + 1):
        # REFUSAL 2 AGAIN, before every mutating call (B1): the operator can open another place
        # inside a 70-minute run, and a silent fall-back would reshape DEV.
        if not dry:
            problem = check_place(studio, studio_id)
            if problem:
                return refuse(problem), entries
        # THE SAME PROFILE BYTES INTO EVERY TILE. `[==[` quoting, because the payload is JSON and
        # holds double quotes; it is a value, never code.
        expression = (
            'TerrainBake.bakeTileAt(%d, {%s}, %g, %g, %s, HttpService:JSONDecode([==[%s]==]))'
            % (index, ",".join('"%s"' % c for c in cells), y_min, y_max,
               "true" if dry else "false", profiles)
        )
        report = call(studio, studio_id, expression, injected=injected)
        entries.append(report)
        worst = max(worst, report.get("elapsedMs", 0))
        print("  tile %3d/%-3d (%6d,%6d) calls=%d voxels=%-6d band %.0f..%.0f  %d ms%s"
              % (index, limit, report["minX"], report["minZ"], report["calls"], report["voxels"],
                 report["bandMin"], report["bandMax"], report["elapsedMs"],
                 "  " + report["message"] if report.get("message") else ""))
        if report.get("message"):
            log_run(cells, entries)
            print("[bake] FAILED at tile %d: %s" % (index, report["message"]))
            return 1, entries
    log_run(cells, entries)
    # THE EPOCH IS STAMPED AT THE END OF A WET RUN, through TerrainBake.stamp, which design 2 names
    # as its only writer -- and it is printed, because design 6.3 puts it in this line.
    epoch = "dry"
    if not dry:
        epoch = epoch_for(studio, studio_id, args.base_sha or sha, injected)
        call(studio, studio_id, 'TerrainBake.stamp("%s") or "stamped"' % epoch, timeout=60,
             injected=injected)
    print("[bake] %s: %d/%d tiles @ %s cells=%s epoch=%s worstTileMs=%d (clean tree)"
          % ("DRY OK" if dry else "OK", limit, limit, sha, ",".join(cells), epoch, worst))
    return 0, entries


def main(argv):
    parser = argparse.ArgumentParser(prog="terrainbake")
    parser.add_argument("command", choices=("plan", "snapshot", "measure", "bake", "survey",
                                            "archive", "census", "selftest"))
    parser.add_argument("--cells", help="comma list, e.g. C1")
    parser.add_argument("--backup", help="a .rbxl saved by File -> Save to File, outside the repo")
    parser.add_argument("--tiles", type=int, help="stop after this many tiles")
    parser.add_argument("--out", help="where `snapshot` writes, default <runs-dir>")
    parser.add_argument("--base-sha", help="the base snapshot's sha256, which the epoch hashes")
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
            studio_id, _ = resolve(studio)
        except Exception as problem:  # noqa: BLE001 -- a plan must still print with no Studio
            print("[bake] note: no Studio addressed (%s)" % str(problem)[:120])
            studio_id = None
        try:
            return command_plan(args, facts, studio if studio_id else None, studio_id)
        finally:
            if studio is not None:
                studio.close()

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
        studio_id, why = resolve(studio)
        if studio_id is None:
            return refuse(why)
        problem = check_place(studio, studio_id)  # refusals 1 and 2
        if problem:
            return refuse(problem)
        problem = check_echo(studio, studio_id, facts, injected, shas)  # refusal 4
        if problem:
            return refuse(problem)
        if mutating:
            keep = [f.strip().upper() for f in (args.keep_flags or "").split(",") if f.strip()]
            if keep:
                print("  keep   %d declared override(s), left as found: %s"
                      % (len(keep), ",".join(keep)))
            problem = check_overrides(studio, studio_id, keep)  # refusal 7
            if problem:
                return refuse(problem)
            print("  flags  live overrides: %s" % (",".join(override_names(studio, studio_id)) or "none"))
        if args.command == "survey":
            return command_survey(studio, studio_id, args, injected)
        if args.command == "census":
            return command_census(studio, studio_id, args.cells or list(CELL_IDS), injected)
        if args.command == "snapshot":
            if not args.cells:
                return refuse("--cells is missing")
            region = region_for(args.cells, facts)
            out = args.out or os.path.join(runs_dir(), "terrain-base-%s.json" % sha[:12])
            # `snapshot` answers (nil, why) when it refuses -- over ReadVoxels' ceiling, Water, an
            # overhang. JSONEncode of the FIRST value then sends "null" and the reason is lost
            # (measured 2026-11-02 on C1's whole region: 24.6 M voxels against a 4.19 M ceiling), so
            # the refusal is raised instead and the tool prints it.
            result = call(studio, studio_id,
                          "(function() local snap, why = TerrainBake.snapshot("
                          "{minX=%g,maxX=%g,minZ=%g,maxZ=%g}, %g, %g) "
                          "if snap == nil then error(why, 0) end return snap end)()"
                          % (region["minX"], region["maxX"], region["minZ"], region["maxZ"],
                             args.y_min, args.y_max), injected=injected)
            with open(out, "w", encoding="utf-8") as handle:
                json.dump(result, handle)
            digest = hashlib.sha256(open(out, "rb").read()).hexdigest()
            print("[bake] snapshot: %s  sha256=%s" % (out, digest))
            return 0
        if args.command == "archive":
            result = call(studio, studio_id, 'TerrainBake.archive("GridForest", {})', injected=injected)
            print("[bake] archive: %s" % json.dumps(result))
            return 0
        if args.command in ("measure", "bake"):
            if not args.cells:
                return refuse("--cells is missing")
            profiles, _ = profiles_once(studio, studio_id, args.cells, injected)
            code, _ = tile_pass(studio, studio_id, args, facts, sha,
                                dry=args.command == "measure", injected=injected, profiles=profiles)
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
        ok("refusal 7 rejects a stray flag override",
           "GRID_HILLSHADE" in (check_overrides(FakeStudio(flags={"GRID_HILLSHADE": True}), "x") or ""))
        ok("refusal 7 LEAVES Karen's own two alone (lesson K)",
           check_overrides(FakeStudio(flags={"GRID_PREVIEW": True, "RANGE_SOLO": True}), "x") is None)
        ok("refusal 7 names `set <NAME> off` and never `clear`",
           "never `clear`" in (check_overrides(FakeStudio(flags={"X": 1}), "x") or ""))
        ok("refusal 7 rejects a live pose override",
           "pose override" in (check_overrides(FakeStudio(pose="hip"), "x") or ""))
    finally:
        globals()["flag_overrides"], globals()["pose_override"] = saved_flags, saved_pose

    # The reply parser, including the shape mapgen.py's own note is about.
    ok("the reply parser reads a JSON object after a line of text",
       parse_json('some note\n{"a": 1}')["a"] == 1)
    ok("the reply parser reads an ARRAY, not the first brace inside it",
       parse_json('note\n[{"a": 1}]')[0]["a"] == 1)
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
        base_sha = None

    saved_call, saved_log = globals()["call"], globals()["log_run"]
    try:
        def record(studio, studio_id, expression, timeout=None, injected=None):
            sent_tiles.append((expression, injected))
            return {"minX": 0, "minZ": 0, "calls": 1, "voxels": 1, "bandMin": 0, "bandMax": 1,
                    "elapsedMs": 5}

        globals()["call"] = record
        globals()["log_run"] = lambda cells, entries: "<log>"
        code, entries = tile_pass(None, "x", Args(), echo_facts, "abc", True,
                                  injected="<PRELUDE>", profiles='[{"road":{"id":"EW2"}}]')
        ok("the tile pass runs every tile it was asked for", code == 0 and len(entries) == 2)
        ok("EVERY tile call carries the profiles the tool computed once",
           all("JSONDecode([==[" in e and '"EW2"' in e for e, _ in sent_tiles), sent_tiles[0][0][:90])
        ok("every tile of one run carries the SAME profile bytes",
           len({e.split("JSONDecode", 1)[1] for e, _ in sent_tiles}) == 1)
        ok("every tile of one run carries the SAME injected prelude",
           {i for _, i in sent_tiles} == {"<PRELUDE>"})
    finally:
        globals()["call"], globals()["log_run"] = saved_call, saved_log
    ok("the Luau refuses a tile that arrives with no profiles, rather than reading live terrain",
       "no profiles were handed to tile" in open(BAKE_LUAU, encoding="utf-8").read())
    ok("bakeTileAt no longer falls back to profilesFor",
       "profiles or TerrainBake.profilesFor" not in open(BAKE_LUAU, encoding="utf-8").read())

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
