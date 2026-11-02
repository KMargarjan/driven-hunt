"""Driven Hunt terrain bake driver. It invokes ServerStorage.TerrainBake in the FOREST TEST's EDIT
session, one tile per MCP call, and it is NOT part of the test harness: the harness never bakes, and
this tool never runs specs.

Pattern: `tools/mapgen.py`, with one change the design forces. Everything about talking to Studio --
Studio, git_state, synced_nodes, compare_synced, studio_for_place, runs_dir -- is IMPORTED from
tools/studio_mcp.py rather than copied, so there is one MCP client in the repo and one definition of
"Studio's copy matches disk".

IT REQUIRES, IT DOES NOT INJECT (design section 3). `tools/forest_ground.py` sends module source as
text; this tool sends `require(...)` and nothing else, so there is no second copy of the arithmetic
to drift. The Luau lives on disk at src/serverstorage/TerrainBake/init.luau, is linted by
`selene src`, formatted by `stylua --check src`, and is reviewable as a diff.

MEASURED 2026-11-02 AND IT BLOCKS THE LIVE HALF OF THIS ROUTE: in Karen's Forest Test, through
StudioMCP's execute_luau, EVERY script instance reads `Source` length 0 (297 of 297) and `require`
of any of them fails with "Module code did not return exactly one value" -- while the same probe in
DEV reads 27,750 characters and requires fine. So `check_synced` (which compares Source) can only
refuse there, and the parentless-clone load cannot load anything.

IT IS THE EDIT SESSION ONLY, measured the same day: in that SAME place's PLAY server,
`require(ReplicatedStorage.Grid)` answers `grid:v1 cells=8` and `#Grid.Source` is 27,750. The source
is there; the Edit DataModel's MCP context is what cannot reach it. The bake runs in Edit (design
5.3), so it is still blocked -- but the cause is narrowed, and Team Create is on in that place while
it is off in DEV. See ESCALATE.md, 2026-11-02, task 328d: the Director decides between turning Team
Create off, reversing the design's ruling, or baking elsewhere. This tool is written to the design
and says plainly when the route is unavailable, rather than silently falling back to injection.

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


# ---------------------------------------------------------------- the Luau this tool sends

# ONE EXPRESSION PER CALL, and the modules arrive by `require` -- no source in this string (design 3).
CALL_TEMPLATE = """
local HttpService = game:GetService("HttpService")
local ok, result = pcall(function()
    local ServerStorage = game:GetService("ServerStorage")
    local TerrainBake = require(ServerStorage:WaitForChild("TerrainBake"))
    return %s
end)
if not ok then
    return HttpService:JSONEncode({ error = tostring(result) })
end
return HttpService:JSONEncode(result)
"""

PLACE_QUERY = 'return tostring(game.PlaceId)'


def parse_json(body):
    """The JSON value inside StudioMCP's reply text, which may carry a line of its own around it."""
    candidates = [i for i in (body.find("{"), body.find("[")) if i >= 0]
    if not candidates:
        raise RuntimeError("no JSON in Studio's reply: %s" % body[:400])
    value, _ = json.JSONDecoder().raw_decode(body[min(candidates):])
    return value


def call(studio, studio_id, expression, timeout=BAKE_CALL_TIMEOUT):
    """Run one TerrainBake expression in the addressed Edit DataModel and parse its JSON reply."""
    arguments = {"datamodel_type": "Edit", "code": CALL_TEMPLATE % expression, "studio_id": studio_id}
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


def check_place(studio, studio_id):
    """Refusals 1 and 2, re-run before EVERY mutating call (B1), by place id and never by name."""
    mode = studio.mode(studio_id=studio_id)
    if "Edit" not in mode:
        return "Studio is in %r, not Edit. Karen may be playing; the bake only runs in Edit." % mode
    place = studio.query("Edit", PLACE_QUERY, studio_id=studio_id).strip().strip('"')
    if place != FOREST_PLACE_ID:
        return "that Studio is open on place %s, not the Forest Test %s" % (place, FOREST_PLACE_ID)
    return None


def check_synced(studio, studio_id):
    """Refusal 4: Studio's copy of the bake, the grid and the places must equal disk, byte for byte.

    IT CANNOT PASS IN THE FOREST TEST TODAY and the failure says why rather than looking like an
    un-pressed Connect: every script there reads Source length 0 through execute_luau (measured
    2026-11-02; ESCALATE.md task 328d), so a Source comparison has nothing to compare.
    """
    wanted = []
    for path, cls, files in synced_nodes():
        if ".".join(path[:2]) in SYNCED_HEADS:
            wanted.append((path, cls, files))
    if not wanted:
        return "the sourcemap has no %s: is default.project.json right?" % " / ".join(SYNCED_HEADS)
    problems = compare_synced(studio, wanted)
    if not problems:
        return None
    unreadable = sum(1 for p in problems if "Source" in p or "source" in p)
    detail = "Studio's copy differs from disk (press Connect in the Rojo plugin):\n  - " + "\n  - ".join(problems[:8])
    if unreadable >= max(1, len(problems) - 1):
        detail += (
            "\n  NOTE, measured 2026-11-02: in the Forest Test EVERY script reads Source length 0\n"
            "  through execute_luau and `require` fails there, so this check cannot pass in that\n"
            "  place however recently Connect was pressed. See ESCALATE.md, task 328d."
        )
    return detail


def check_clean_tree():
    sha, dirty = git_state()
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


def check_overrides(studio, studio_id):
    """Refusal 7, less Karen's own two (lesson K: never clear her Forest Test's overrides)."""
    live = flag_overrides(studio, studio_id=studio_id) or {}
    strays = sorted(name for name in live if name not in KARENS_FLAGS)
    if strays:
        return ("a flag override is live: %s. Run `python tools/flags.py --place forest set <NAME> off`\n"
                "  for THAT flag only -- never `clear`, which would remove Karen's %s too."
                % (", ".join(strays), " and ".join(KARENS_FLAGS)))
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


def command_plan(args, facts):
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
    # THE ASSERTION. A plan whose count disagrees with the arithmetic is a refusal, not a warning:
    # the count is what every cost estimate and every "n/m tiles" line is measured against.
    expect_nx = -(-(region["maxX"] - x0) // facts["tile"])
    expect_nz = -(-(region["maxZ"] - z0) // facts["tile"])
    if (nx, nz) != (expect_nx, expect_nz):
        return refuse("the tile plan is %dx%d but the arithmetic gives %dx%d" % (nx, nz, expect_nx, expect_nz))
    print("  ASSERTED: %d tiles, re-derived from Grid.CONFIG on disk" % count)
    return 0


def command_survey(studio, studio_id, args):
    cells = args.cells or list(CELL_IDS)
    print("[bake] survey (read-only):")
    print("  %-4s %-7s %8s %8s %8s %8s %9s  %s" % ("cell", "samples", "minY", "maxY", "meanY", "spread", "lineMeanY", "character"))
    for cell_id in cells:
        row = call(studio, studio_id, 'TerrainBake.survey("%s")' % cell_id)
        print("  %-4s %-7d %8.2f %8.2f %8.2f %8.2f %9.2f  %s"
              % (row["cell"], row["samples"], row["minY"], row["maxY"], row["meanY"],
                 row["spreadStuds"], row["lineMeanY"], row["character"]))
    return 0


def command_census(studio, studio_id, cells):
    """GridCensus' OWN entry point is `survey(folder, cellId, groundAt, clawOf)` -- there is no
    `run()`, measured 2026-11-02 by listing the module's keys in the Forest Test's Play server."""
    for cell_id in cells:
        result = call(studio, studio_id, CENSUS_SEAM % cell_id)
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


def tile_pass(studio, studio_id, args, facts, sha, dry):
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
        expression = (
            'TerrainBake.bakeTileAt(%d, {%s}, %g, %g, %s)'
            % (index, ",".join('"%s"' % c for c in cells), y_min, y_max, "true" if dry else "false")
        )
        report = call(studio, studio_id, expression)
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
    print("[bake] %s: %d/%d tiles @ %s cells=%s worstTileMs=%d (clean tree)"
          % ("DRY OK" if dry else "OK", limit, limit, sha, ",".join(cells), worst))
    return 0, entries


def main(argv):
    parser = argparse.ArgumentParser(prog="terrainbake")
    parser.add_argument("command", choices=("plan", "snapshot", "measure", "bake", "survey",
                                            "archive", "census", "selftest"))
    parser.add_argument("--cells", help="comma list, e.g. C1")
    parser.add_argument("--backup", help="a .rbxl saved by File -> Save to File, outside the repo")
    parser.add_argument("--tiles", type=int, help="stop after this many tiles")
    parser.add_argument("--out", help="where `snapshot` writes, default <runs-dir>")
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
        return command_plan(args, facts)

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

    studio = Studio()
    try:
        studio_id, why = resolve(studio)
        if studio_id is None:
            return refuse(why)
        problem = check_place(studio, studio_id)  # refusals 1 and 2
        if problem:
            return refuse(problem)
        if mutating:
            problem = check_overrides(studio, studio_id)  # refusal 7
            if problem:
                return refuse(problem)
            problem = check_synced(studio, studio_id)  # refusal 4
            if problem:
                return refuse(problem)
        if args.command == "survey":
            return command_survey(studio, studio_id, args)
        if args.command == "census":
            return command_census(studio, studio_id, args.cells or list(CELL_IDS))
        if args.command == "snapshot":
            if not args.cells:
                return refuse("--cells is missing")
            region = region_for(args.cells, facts)
            out = args.out or os.path.join(runs_dir(), "terrain-base-%s.json" % sha[:12])
            result = call(studio, studio_id,
                          "TerrainBake.snapshot({minX=%g,maxX=%g,minZ=%g,maxZ=%g}, %g, %g)"
                          % (region["minX"], region["maxX"], region["minZ"], region["maxZ"],
                             args.y_min, args.y_max))
            with open(out, "w", encoding="utf-8") as handle:
                json.dump(result, handle)
            digest = hashlib.sha256(open(out, "rb").read()).hexdigest()
            print("[bake] snapshot: %s  sha256=%s" % (out, digest))
            return 0
        if args.command == "archive":
            result = call(studio, studio_id, 'TerrainBake.archive("GridForest", {})')
            print("[bake] archive: %s" % json.dumps(result))
            return 0
        if args.command in ("measure", "bake"):
            if not args.cells:
                return refuse("--cells is missing")
            code, _ = tile_pass(studio, studio_id, args, facts, sha, dry=args.command == "measure")
            return code
    finally:
        studio.close()
    return 1


# ---------------------------------------------------------------- selftest (CI; no Studio, no network)

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

    # The Luau this tool sends carries no module source -- the design's whole point (section 3).
    sent = CALL_TEMPLATE % 'TerrainBake.survey("C1")'
    ok("the sent Luau REQUIRES and injects nothing", "require(" in sent and "Relief.LANDFORMS" not in sent)
    ok("the sent Luau names ServerStorage.TerrainBake", 'WaitForChild("TerrainBake")' in sent)
    ok("the place id in the tool is the Forest Test's", FOREST_PLACE_ID == "130094961655666")
    # MEASURED 2026-11-02 in the Forest Test's Play server: GridCensus has measure/survey/line/
    # publish and NO `run`. The first version of this seam called `run()`.
    seam = CENSUS_SEAM % "C1"
    ok("the census seam calls GridCensus.survey and GridCensus.line, not a run() that is not there",
       "GridCensus.survey(" in seam and "GridCensus.line(" in seam and ".run()" not in seam)

    # The place id in the tool and the one in the Luau are one fact.
    ok("the tool and the Luau name the same place",
       str(int(number_from(BAKE_LUAU, r"^TerrainBake\.PLACE_ID = ([0-9_]+)"))) == FOREST_PLACE_ID)

    print("[bake] selftest: %d check(s) failed" % len(failures) if failures else "[bake] selftest: PASS")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
