"""Driven Hunt map generator driver. It invokes ServerStorage.MapGen in Studio's EDIT session, one
step per MCP call, and it is NOT part of the test harness: the harness never generates a map, and this
tool never runs specs.

Pattern: the same minimal StudioMCP client the harness uses. Everything about talking to Studio --
Studio, git_state, expected_place_id, synced_nodes, compare_synced, luau_json -- is IMPORTED from
tools/studio_mcp.py rather than copied, so there is one MCP client in the repo and one definition of
"Studio's copy matches disk".

Design: docs/design/map-generator.md (section 6). Note: docs/research/2026-09-24-map-generator.md

Usage:
  python tools/mapgen.py plan     [--seed N]                       # read-only: print the steps
  python tools/mapgen.py build    --seed N --backup <path|census>  # clear, then every step, in order
  python tools/mapgen.py step  <i,j,k> --seed N --backup <path|census>   # re-run named steps only
  python tools/mapgen.py clear    --backup <path|census>           # Terrain:Clear() + destroy the root
  python tools/mapgen.py verify   --seed N --backup <path|census>  # build, digest, clear, build, compare
  python tools/mapgen.py digest                                    # read-only
  python tools/mapgen.py contract                                  # read-only: MapGen.verifyContract()
  python tools/mapgen.py reach                                     # read-only: pathfind the built map
  python tools/mapgen.py census                                    # read-only: what is in Workspace
  python tools/mapgen.py shots                                     # read-only: the seven named captures

Exit codes, deliberately the harness's shape: 0 done · 1 a step failed · 2 REFUSED.

WHAT IT REFUSES, BEFORE IT TOUCHES ANYTHING (design section 6.2). A generator that runs anyway is how
a place gets destroyed.
  1. Studio not in Edit mode, or game.PlaceId != servePlaceIds[0].
  2. A dirty tree, for any mutating command: a map built from uncommitted code cannot be reproduced
     from a commit, which is the same rule as the harness's exit code 3.
  3. Studio's copy of ServerStorage.MapGen or ReplicatedStorage.Map differs from disk -- byte for byte,
     line endings normalised. Catches "Rojo is not connected" and "nobody pressed Connect since the
     last edit", which would otherwise build yesterday's map from today's seed.
  4. No usable backup. --backup must name an existing file OUTSIDE the repository, suffix .rbxl,
     non-empty, modified within BACKUP_MAX_AGE_HOURS. File -> Save to File is the only rollback
     Workspace has and it is a menu click no tool can make, so this is the one place it can be
     enforced instead of remembered.
  5. --seed missing on build/verify. There is no default seed: an unnamed seed is an unreproducible map.

--backup census, AND WHY IT EXISTS. Milestone 2.1's place holds nothing hand-made: the arena is built
from code at run time, Workspace is empty in Edit, and the generator's own output is reproducible from
its seed. So for M2.1 the Director allowed a census in place of a saved file: the tool asks Studio what
is actually in Workspace, and proceeds ONLY if every child is Terrain, Camera or the map root. If
anything else is there, it stops and prints a NEEDS KAREN block asking for File -> Save to File,
because that thing is something a rebuild would destroy and no tool can save it.

REACHABILITY, and why it lives here. `tests/server/map_contract.spec.luau` can only see the world
`Map.EXPECTED_WORLD` names -- the arena -- so nothing had ever pathfound the GENERATED map, and that is
how an ungated hedgerow wall across the drive corridor survived two review rounds in Task 43
(TASKS.md row 43a(k)). `verify` now ends by asking `MapGen.reachability()` to walk every BoarSpawn and
the DriverStart to the drive line with the BOAR'S OWN agent parameters, in the Edit session, and fails
the run if any of them cannot get there. `reach` runs the same check on its own, read-only.

MEASURED 2026-09-26: `PathfindingService:ComputeAsync` works in Edit through `execute_luau`, and the
navmesh is rebuilt in the BACKGROUND -- a wall thrown across the corridor still answered
PathStatus.Success one second after it appeared, and NoPath after five. `MapGen.reachability` waits
`Config.REACH_SETTLE_SECONDS` before asking, so the answer is about the map as it now is.

The run log: every StepReport is appended to .mapgen/<utc>-<seed>.json (git-ignored). Two lines are
worth pasting into reviews/task-<N>/REQUEST.md, exactly as the harness line is -- `build`'s

  [mapgen] OK: 268/268 steps @ <sha> seed=7 digest=<64 hex> (clean tree)

and, for the evidence the design actually asks for (section 6.4), `verify`'s

  [mapgen] OK: same seed twice, same digest @ <sha> seed=7 digest=<64 hex> (clean tree)
"""

import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from studio_mcp import (  # noqa: E402  (the path insert above has to come first)
    REPO,
    Studio,
    compare_synced,
    expected_place_id,
    git_state,
    synced_nodes,
)

# One MCP call per step against a per-step design target of 60 s. _rpc's own default is 120 s, and a
# whole-map run in one call would exceed it; chunking also makes a failed tile name itself.
MAPGEN_CALL_TIMEOUT = 180
BACKUP_MAX_AGE_HOURS = 6
RUN_LOG_DIR = os.path.join(REPO, ".mapgen")

# The generator's own instances, plus the two the engine always puts there.
WORKSPACE_ALLOWED = ("Terrain", "Camera")

# The seven captures (design section 13.3's six, plus map-gate), at the full 2048-stud map's own scale. Milestone 2.1's
# cameras were scaled down for the 512 slice; these are the design's table, with two changes it names
# as the Builder's to make: `map-stand` looks at the tie trees behind the shooter line (the only stand
# M2.2 builds -- real spruce stands are M2.3), and there is a seventh angle on a hedgerow gate, because
# the gate is the fix this task exists for and a screenshot is the only way to see it is really there.
# The design's section 16.3 list. EVERY ONE IS A QUESTION, not a label: the point of a shot is the
# answer a human gives it, and "map-road" is the shot this revision exists for.
SHOTS = (
    ("map-wide", (0, 1100, 1500), (0, 0, -200),
     "is there a map, does it read as wood-with-fields, is the road visible as a line through it"),
    ("map-road", (-500, 6, -700), (500, 6, -700),
     "STANDING ON THE ROAD: do the posts read at 160-stud spacing, is the gravel gravel"),
    ("map-post", (-80, 6, -700), (-80, 4, -300),
     "a shooter's view into the drive: how far can he see, how much of the frame is trunk"),
    ("map-drive", (0, 40, 700), (0, 0, -700),
     "the drive from the drivers' eye height: is it woods they push through"),
    ("map-crossing", (240, 6, -700), (-240, 6, -700),
     "along the road between two posts: is there a gap a boar would cross"),
    ("map-autumn", (-300, 18, -520), (-120, 6, -640),
     "close in the wood: do the crowns read autumn, is the floor litter and not grass"),
    ("map-stand", (0, 16, -640), (0, 6, -745),
     "the tie trees behind the line, in the far wood: woods, or poles"),
    ("map-edge", (600, 8, -700), (1024, 6, -700),
     "does the map's edge read as a void where the road leaves it"),
    # M2.8c's ONE NEW CLOSE VIEW (design section 18), and the answer to TASKS.md row 58a(a): every
    # tagged marker is Transparency = 1, so until the stakes existed no shot could show where a
    # stand is. Stood at the third stand looking along the road at the fourth.
    # CHOSEN BY LOOKING (rule 5): from the stand itself the camera is in front of its own stakes and
    # only the next stand's cap is in frame. 60 studs short of a stand puts the near cap close and
    # the next one at 160 studs in the same picture, which is the question row 58a(a) asks.
    ("map-stand-close", (-305, 6, -698), (-235, 5, -704),
     "the road between two stands: does the near stake read, and the next one at 160 studs"),
)

# ---------------------------------------------------------------- talking to the generator

# Every call returns JSON, so an MCP reply is machine-readable and lands in the run log verbatim --
# the same discipline tools/studio_mcp.py uses for the test report.
# A FRESH COPY OF THE GENERATOR EVERY CALL. MEASURED 2026-09-26: Studio's require cache survives
# between execute_luau calls, and Rojo replacing a ModuleScript's Source does NOT reload an
# already-required module -- so a Config edit was invisible to `build`, which cheerfully reported a
# number the file no longer said. `require` on a parentless clone loads the CURRENT source, leaves
# nothing in the DataModel (so the harness's "no unmanaged script" check cannot trip over it), and
# costs nothing measurable.
CALL = """
local HttpService = game:GetService("HttpService")
local ok, result = pcall(function()
    local source = game:GetService("ServerStorage"):FindFirstChild("MapGen")
    if not source then
        error("ServerStorage.MapGen is missing: is Rojo connected?", 0)
    end
    local MapGen = require(source:Clone())
    return %s
end)
if not ok then
    return HttpService:JSONEncode({ error = tostring(result) })
end
return HttpService:JSONEncode(result)
"""

# THE SESSION'S CACHED CONTRACT, compared with a freshly required clone of the same script. Since
# MapGen.Contract loads the contract fresh at edit time, a stale cache no longer changes what gets
# built -- so this is a printed NOTE, not a refusal. It is still worth knowing: it tells the operator
# that anything else in this Edit session which already required ReplicatedStorage.Map is holding an
# older copy, and that only reopening the place clears it.
STALE = """
local HttpService = game:GetService("HttpService")
local ok, result = pcall(function()
    local RS = game:GetService("ReplicatedStorage")
    local script = RS:WaitForChild("Map")
    local cached = require(script)
    local fresh = require(script:Clone())
    local differences = {}
    local function compare(path, a, b)
        if type(a) ~= type(b) then
            table.insert(differences, path .. ": " .. type(a) .. " loaded, " .. type(b) .. " on disk")
        elseif type(a) == "table" then
            local keys = {}
            for key in pairs(a) do
                keys[key] = true
            end
            for key in pairs(b) do
                keys[key] = true
            end
            for key in pairs(keys) do
                compare(path .. "." .. tostring(key), a[key], b[key])
            end
        elseif a ~= b then
            table.insert(differences, path .. ": " .. tostring(a) .. " loaded, " .. tostring(b) .. " on disk")
        end
    end
    compare("Map", cached, fresh)
    table.sort(differences)
    return { differences = differences }
end)
if not ok then
    return HttpService:JSONEncode({ error = tostring(result) })
end
return HttpService:JSONEncode(result)
"""

# THE CENSUS ANSWERS ABOUT THE GROUND TOO (audit-004 must-fix 1). Terrain is a global singleton with
# no container, so `Terrain` was unconditionally on the allow-list and the census was structurally
# incapable of mentioning the single biggest thing `clear` destroys -- or of noticing that a map's
# terrain is already in the place.
CENSUS = """
local HttpService = game:GetService("HttpService")
local children = {}
for _, child in ipairs(workspace:GetChildren()) do
    table.insert(children, {
        name = child.Name,
        className = child.ClassName,
        descendants = #child:GetDescendants(),
    })
end
return HttpService:JSONEncode({
    children = children,
    terrainCells = workspace.Terrain:CountCells(),
})
"""


def parse_json(body):
    """The JSON value inside StudioMCP's reply text, which may carry a line of its own around it.

    raw_decode from the FIRST bracket of either kind: taking the first "{" would start inside an
    array's first element and then fail as "extra data", which is what it did on the first run.
    """
    candidates = [i for i in (body.find("{"), body.find("[")) if i >= 0]
    if not candidates:
        raise RuntimeError(f"no JSON in Studio's reply: {body[:400]}")
    value, _ = json.JSONDecoder().raw_decode(body[min(candidates):])
    return value


def call(studio, expression):
    """Run one MapGen expression in the Edit DataModel and parse its JSON reply."""
    text = studio._rpc(
        "tools/call",
        {
            "name": "execute_luau",
            "arguments": {"datamodel_type": "Edit", "code": CALL % expression},
        },
        timeout=MAPGEN_CALL_TIMEOUT,
    )
    body = "\n".join(c.get("text", "") for c in text.get("content", []))
    if text.get("isError"):
        raise RuntimeError(f"execute_luau: {body}")
    return parse_json(body)


def census(studio):
    """{"children": [...], "terrainCells": n} -- what is in Workspace, ground included."""
    return parse_json(studio.query("Edit", CENSUS))


def print_census(result):
    for row in result.get("children") or []:
        print(f"  {row['name']} ({row['className']}, {row['descendants']} descendants)")
    print(f"  Terrain: {result.get('terrainCells', '?')} cell(s)")


# ---------------------------------------------------------------- the refusals

def refuse(reason):
    print(f"[mapgen] REFUSED: {reason}")
    return 2


def check_place(studio):
    mode = studio.mode()
    if "Edit" not in mode:
        return f"Studio is in {mode!r}, not Edit. The generator only runs in Edit."
    place = studio.query("Edit", "return tostring(game.PlaceId)").strip().strip('"')
    if expected_place_id() not in place:
        return f"Studio is open on place {place}, not {expected_place_id()} (default.project.json)"
    return None


def check_synced(studio):
    """Refusal 3: Studio's copy of the generator and the contract must equal disk."""
    wanted = []
    for path, cls, files in synced_nodes():
        head = ".".join(path[:2])
        if head in ("ServerStorage.MapGen", "ReplicatedStorage.Map"):
            wanted.append((path, cls, files))
    if not wanted:
        return "the sourcemap has no ServerStorage.MapGen or ReplicatedStorage.Map: is default.project.json right?"
    problems = compare_synced(studio, wanted)
    if problems:
        return "Studio's copy differs from disk (press Connect in the Rojo plugin):\n  - " + "\n  - ".join(problems)
    return None


def note_contract_cache(studio):
    """Prints a note when Studio's require cache holds an older contract than the file says."""
    result = parse_json(studio.query("Edit", STALE))
    if result.get("error"):
        print(f"[mapgen] note: could not compare the cached contract: {result['error']}")
        return
    differences = result.get("differences") or []
    if not differences:
        return
    print("[mapgen] note: this Edit session has an OLDER ReplicatedStorage.Map in its require cache")
    for difference in differences:
        print(f"  - {difference}")
    print("  MapGen.Contract loads the contract fresh, so the build below uses the file on disk.")
    print("  Reopen the place when you want the session itself current (a Rojo sync cannot).")

def check_backup(studio, backup, command):
    """Refusal 4, or the M2.1 census in its place."""
    if backup is None:
        return "no --backup. Pass a .rbxl saved by File -> Save to File, or `census` (M2.1 only)."
    # The census path only. A REAL --backup is a saved .rbxl: whatever is in the place, the operator
    # can put it back, which is the whole point of the file -- so the orphan refusal below does not
    # apply to it (review round 1 note).
    if backup == "census":
        result = census(studio)
        rows = result.get("children") or []
        cells = result.get("terrainCells") or 0
        allowed = set(WORKSPACE_ALLOWED) | {root_name()}
        strays = [r for r in rows if r["name"] not in allowed]
        print("[mapgen] census of Workspace:")
        for row in rows:
            mark = " " if row["name"] in allowed else "!"
            print(f"  {mark} {row['name']} ({row['className']}, {row['descendants']} descendants)")
        print(f"    Terrain: {cells} cell(s)")
        # ORPHANED TERRAIN. A map root with no terrain is a half-finished build; TERRAIN WITH NO ROOT
        # is somebody deleting Workspace.DrivenHuntMap in the Explorer, which leaves the whole
        # heightfield behind and which every other check in this project is blind to (audit-004
        # must-fix 1). A FRESH build must not start from it silently: the operator has to say `clear`.
        #
        # ONLY `build` AND `verify` ARE REFUSED, and the other two are legitimate in exactly this
        # state (review round 1 of Task 47):
        #   * `step` IS the retry, and a build reaches `ensureRoot()` for the first time in the
        #     hedgerow step -- so through all 256 terrain steps Workspace holds terrain and no root.
        #     Refusing `step` would block the documented way to resume a build, and would tell the
        #     operator to `clear` the partial build it was resuming.
        #   * `clear` is the cure the refusal itself names.
        if command in ("build", "verify") and cells > 0 and not any(r["name"] == root_name() for r in rows):
            return (
                f"Workspace holds {cells} terrain cell(s) and no {root_name()}: a generated map's ground "
                "was left behind when its folder went away.\n"
                "  Nothing here can tell that terrain from a map you meant to keep, so this stops.\n"
                "  Run `python tools/mapgen.py clear --backup census` to remove it, or save the place "
                "first and pass that .rbxl as --backup."
            )
        if strays:
            names = ", ".join(f"{r['name']} ({r['className']})" for r in strays)
            return (
                f"the census is NOT clean: Workspace holds {names}.\n"
                "  Nothing hand-made may be in Workspace when the generator runs, because a rebuild\n"
                "  destroys it and no tool can save the place.\n"
                "  NEEDS KAREN: in Studio, File -> Save to File..., save a .rbxl OUTSIDE the repo,\n"
                "  then re-run with --backup <that file>."
            )
        return None
    path = os.path.abspath(backup)
    if not os.path.isfile(path):
        return f"--backup {backup} is not a file"
    try:
        inside = os.path.commonpath([path, REPO]) == REPO
    except ValueError:
        inside = False  # another drive: commonpath refuses, and a different drive is certainly outside
    if inside:
        return f"--backup {backup} is inside the repository; a backup must be outside it"
    if not path.lower().endswith(".rbxl"):
        return f"--backup {backup} is not a .rbxl"
    if os.path.getsize(path) == 0:
        return f"--backup {backup} is empty"
    age_hours = (time.time() - os.path.getmtime(path)) / 3600
    if age_hours > BACKUP_MAX_AGE_HOURS:
        return f"--backup {backup} is {age_hours:.1f} h old, older than {BACKUP_MAX_AGE_HOURS} h"
    return None


def check_clean_tree():
    sha, dirty = git_state()
    if dirty:
        return sha, "the tree is dirty: a map built from uncommitted code cannot be rebuilt from a commit.\n  - " + "\n  - ".join(dirty)
    return sha, None


def root_name():
    """Config.ROOT_NAME, read from disk so this tool has no second copy of it."""
    with open(os.path.join(REPO, "src", "serverstorage", "MapGen", "Config.luau"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("Config.ROOT_NAME"):
                return line.split('"')[1]
    raise RuntimeError("Config.ROOT_NAME is not in src/serverstorage/MapGen/Config.luau")


# ---------------------------------------------------------------- the run log

def log_run(seed, entries):
    os.makedirs(RUN_LOG_DIR, exist_ok=True)
    name = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime()) + f"-{seed}.json"
    path = os.path.join(RUN_LOG_DIR, name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(entries, f, indent=2)
    print(f"[mapgen] run log: {os.path.relpath(path, REPO)}")


# ---------------------------------------------------------------- the commands

def print_step(report):
    bits = [f"step {report.get('index')}/{report.get('total', '?')}", str(report.get("label", ""))]
    for key in ("voxelsWritten", "partsCreated"):
        if report.get(key) is not None:
            bits.append(f"{key}={report[key]}")
    if report.get("message"):
        bits.append(str(report["message"]))
    bits.append(f"{report.get('elapsedMs', 0)} ms")
    print(("[mapgen] OK  " if report.get("ok") else "[mapgen] FAIL ") + " · ".join(b for b in bits if b))


def run_steps(studio, seed, indexes, plan_size, entries):
    """Runs the named steps in order. Returns the number that succeeded."""
    done = 0
    for index in indexes:
        report = call(studio, f"MapGen.runStep({index}, {seed})")
        if report.get("error"):
            report = {"index": index, "ok": False, "message": report["error"], "elapsedMs": 0}
        report["total"] = plan_size
        entries.append(report)
        print_step(report)
        if not report.get("ok"):
            return done
        done += 1
    return done


def command_plan(studio, args):
    plan = call(studio, f"MapGen.steps({args.seed or 0})")
    for step in plan:
        print(f"  {step['index']:>3}  {step['kind']:<9} {step['label']}  (~{step['estimatedMs']} ms)")
    print(f"[mapgen] {len(plan)} steps, seed {args.seed or 0} (nothing was written)")
    return 0


def command_build(studio, args, sha, indexes=None):
    plan = call(studio, f"MapGen.steps({args.seed})")
    wanted = indexes or list(range(1, len(plan) + 1))
    entries = []
    done = run_steps(studio, args.seed, wanted, len(plan), entries)
    log_run(args.seed, entries)
    if done != len(wanted):
        print(f"[mapgen] FAILED after {done}/{len(wanted)} steps @ {sha} seed={args.seed}")
        return 1
    digest = call(studio, "MapGen.digest()")
    print(
        f"[mapgen] OK: {done}/{len(wanted)} steps @ {sha} seed={args.seed} "
        f"digest={digest.get('digest', '')} (clean tree)"
    )
    print(f"[mapgen] {digest.get('parts')} parts, {digest.get('samples')} terrain samples")
    return 0


def command_verify(studio, args, sha):
    """Build, digest, clear, build again, compare. The answer to "is math.noise reproducible"."""
    first, second = None, None
    for attempt in (1, 2):
        plan = call(studio, f"MapGen.steps({args.seed})")
        entries = []
        done = run_steps(studio, args.seed, list(range(1, len(plan) + 1)), len(plan), entries)
        log_run(args.seed, entries)
        if done != len(plan):
            print(f"[mapgen] FAILED on build {attempt} after {done}/{len(plan)} steps")
            return 1
        digest = call(studio, "MapGen.digest()")
        print(f"[mapgen] build {attempt}: digest={digest.get('digest')} parts={digest.get('parts')}")
        if attempt == 1:
            first = digest
        else:
            second = digest
    if first.get("digest") and first["digest"] == second["digest"]:
        # The map is reproducible. Now the other half of the question: is it WALKABLE? A hedgerow with
        # no gate builds and digests perfectly and stops the drive dead (TASKS.md row 43a(k)).
        reach = call(studio, "MapGen.reachability()")
        if reach.get("error"):
            print(f"[mapgen] FAILED: reachability could not run: {reach['error']}")
            return 1
        if not print_reach(reach):
            print(f"[mapgen] FAILED: the map is reproducible but not walkable @ {sha} seed={args.seed}")
            return 1
        # AND IS THE ROAD CLEAR, END TO END? (round 2, finding 1.) Reachability pathfinds to the
        # line and a 7-stud hedge wall across the gravel at x = +/-760 did not stop a single route --
        # the navmesh simply went round it. Only a check that walks the road itself sees it.
        contract = call(studio, "MapGen.verifyContract()")
        if contract.get("error"):
            print(f"[mapgen] FAILED: the contract check could not run: {contract['error']}")
            return 1
        if not contract.get("ok"):
            print("[mapgen] FAILED: the map is reproducible and walkable but breaks its contract:")
            for finding in contract.get("findings", []):
                print("  - " + finding)
            return 1
        print(f"[mapgen] OK: same seed twice, same digest @ {sha} seed={args.seed} digest={first['digest']} (clean tree)")
        return 0
    print("[mapgen] MISMATCH: the same seed produced two different maps.")
    print(f"  build 1: {first.get('digest')}")
    print(f"  build 2: {second.get('digest')}")
    print("  This is the design's open question about math.noise answered NO (section 6.4). The named")
    print("  fallback is a seeded value-noise implementation inside Height.luau.")
    return 1


def print_reach(result):
    """Prints one reachability result and returns True when every route was walkable."""
    for row in result.get("results") or []:
        print(f"  {row['from']}: {row['status']} ({row['waypoints']} waypoints)")
    for finding in result.get("findings") or []:
        print(f"  ! {finding}")
    ok = bool(result.get("ok"))
    print("[mapgen] reachability " + ("OK" if ok else "FAILED"))
    return ok


def command_reach(studio):
    result = call(studio, "MapGen.reachability()")
    if result.get("error"):
        print(f"[mapgen] reachability could not run: {result['error']}")
        return 1
    return 0 if print_reach(result) else 1


def command_contract(studio):
    result = call(studio, "MapGen.verifyContract()")
    counts = result.get("counts") or {}
    for key in sorted(counts):
        print(f"  {key}: {counts[key]}")
    for key, value in sorted((result.get("streaming") or {}).items()):
        print(f"  {key} = {value}")
    if result.get("markerDigest"):
        print(f"  marker digest: {result['markerDigest']}")
    for finding in result.get("findings") or []:
        print(f"  ! {finding}")
    print("[mapgen] contract " + ("OK" if result.get("ok") else "FAILED"))
    return 0 if result.get("ok") else 1


def command_shots(studio):
    if not call(studio, "MapGen.verifyContract()").get("counts"):
        return refuse("there is no map in Workspace to photograph. Run `build` first.")
    failed = 0
    for name, camera, look_at, answers in SHOTS:
        path = os.path.join(REPO, ".screenshots", f"{name}.png")
        saved, text = studio.capture(path, camera, look_at)
        if saved:
            print(f"[mapgen] shot {name}: {os.path.relpath(saved, REPO)}  ({answers})")
        else:
            failed += 1
            print(f"[mapgen] shot {name} FAILED: {text}")
    print("[mapgen] look at every one of them before claiming what they show (rule 5).")
    return 1 if failed else 0


def parse_indexes(text):
    out = []
    for piece in text.split(","):
        piece = piece.strip()
        if piece:
            out.append(int(piece))
    if not out:
        raise ValueError("no step numbers")
    return out


def main(argv):
    parser = argparse.ArgumentParser(prog="mapgen.py", description=__doc__.splitlines()[0])
    parser.add_argument(
        "command",
        choices=("plan", "build", "step", "clear", "verify", "digest", "contract", "reach", "census", "shots"),
    )
    parser.add_argument("steps", nargs="?", help="for `step`: comma-separated step numbers")
    parser.add_argument("--seed", type=int)
    parser.add_argument("--backup", help="a .rbxl outside the repo, or `census` (M2.1 only)")
    args = parser.parse_args(argv[1:])

    mutating = args.command in ("build", "step", "clear", "verify")
    if args.command in ("build", "verify") and args.seed is None:
        return refuse("--seed is required: an unnamed seed is an unreproducible map")
    if args.command == "step":
        if args.steps is None:
            return refuse("`step` needs step numbers, e.g. `step 2,3,4 --seed 7`")
        if args.seed is None:
            return refuse("--seed is required for `step`")

    sha = None
    if mutating:
        sha, why = check_clean_tree()
        if why:
            return refuse(why)

    studio = Studio()
    try:
        why = check_place(studio)
        if why:
            return refuse(why)
        why = check_synced(studio)
        if why:
            return refuse(why)
        note_contract_cache(studio)
        if mutating:
            why = check_backup(studio, args.backup, args.command)
            if why:
                return refuse(why)

        if args.command == "plan":
            return command_plan(studio, args)
        if args.command == "census":
            print_census(census(studio))
            return 0
        if args.command == "digest":
            print(json.dumps(call(studio, "MapGen.digest()"), indent=2))
            return 0
        if args.command == "contract":
            return command_contract(studio)
        if args.command == "reach":
            return command_reach(studio)
        if args.command == "shots":
            return command_shots(studio)
        if args.command == "clear":
            # BRANCH ON THE MEASUREMENT. Printing "cleared" and exiting 0 while cells remain is the
            # same shape this task set out to close, in the very command its refusal points at
            # (review round 1 note).
            result = call(studio, "MapGen.clear()")
            print(json.dumps(result, indent=2))
            if not result.get("terrainCleared"):
                print(f"[mapgen] FAILED: Terrain:Clear() left {result.get('cellsAfter')} cell(s) @ {sha}")
                return 1
            print(f"[mapgen] cleared @ {sha} (clean tree)")
            return 0
        if args.command == "build":
            return command_build(studio, args, sha)
        if args.command == "step":
            return command_build(studio, args, sha, indexes=parse_indexes(args.steps))
        if args.command == "verify":
            return command_verify(studio, args, sha)
        return refuse(f"unknown command {args.command}")
    finally:
        studio.close()


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv))
