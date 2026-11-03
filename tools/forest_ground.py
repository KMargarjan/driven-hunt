"""Put `Workspace.OurForest`'s trees back on the ground, in Karen's Forest Test place (task 199).

KAREN, 2026-10-16 ~21:35, with a frame of three birches standing on their root claws in the air by
a forest road: *"look at the trees wtf"*. Task 196 measured the cause and could not fix it there:
of 4,819 objects in `Workspace.OurForest`, hundreds sit well above the terrain -- the worst by 42
studs -- and that forest is STUDIO MAP CONTENT. Nothing under `src/` creates it, no Rojo path owns
it, and it is saved with the place, so no commit can move it. This tool can.

WHAT IT IS. A re-runnable instrument, not a one-off paste: it sends Luau to a Studio in EDIT mode
through StudioMCP, measures every model in `OurForest` against the terrain, and -- only on `apply`
-- moves the floating ones STRAIGHT DOWN. It never moves a model sideways, never rotates or scales
one, never deletes one, and never touches anything outside `Workspace.OurForest`.

THE RULE IS NOT WRITTEN HERE. It is `src/shared/TreeGround/init.luau`, the module task 199 split
out of the lobby's own tree planting (task 196 part 3e), and this tool READS THAT FILE AND INJECTS
ITS SOURCE into every payload it sends. `Lobby.Build` requires the same module in game. So the
lobby's trees and the forest's trees are planted by one function, and the tool cannot drift from
the game -- which is the thing lesson L-031 asks to be verified rather than promised. The injection
exists because Karen's Forest Test place is a DIFFERENT place: `default.project.json` serves only
the DEV place, so `require(ReplicatedStorage.TreeGround)` would be yesterday's copy, or absent.

THE INJECTION'S STATED REASON IS STALE -- the note the design leaves for whoever next touches
this tool, pasted verbatim from `docs/design/grid-terrain.md` section 16 (task 328b, Director
decision 1; queued as section 17 D-3):

  The injection's stated reason is stale: `default.project.json`'s `servePlaceIds` holds the Forest
  Test as well as DEV, so `require(ReplicatedStorage.TreeGround:Clone())` behind
  `compare_synced` is available and is what `tools/terrainbake.py` does
  (`docs/design/grid-terrain.md` §3). This tool is not rewritten here; it works, and rule 7 applies.

THE RULE, IN ONE SENTENCE: plant the tree so the TRUNK/ROOT JUNCTION -- the height at which the
base stops being claws and becomes trunk -- is at or just below the LOWEST terrain anywhere under
the trunk's own footprint, and let the claws bury themselves on the high side. Seating the claw
TIPS on the ground instead is what leaves daylight under every arch, which is the picture Karen
sent.

WHAT ONLY THE WORLD CAN ANSWER, and so is measured here rather than computed:
  * every visible part's axis-aligned box (`Transparency < 0.95`; the birches carry an invisible
    `Basepart` pad that would otherwise define the model's bottom),
  * the TRUNK's footprint -- the part whose name contains "Trunk", lowest one if several, else the
    union of the parts that reach the ground, else the whole model. The footprint is the TRUNK'S
    and never the crown's: a birch's crown is twenty-five studs across and its flare is eight, so a
    grid over the whole bounding box reads the ground under the canopy, twelve studs away and down
    a bank. Task 196 part 3c made that exact mistake and reported zero floating trees,
  * the terrain under a 5 x 5 grid on that footprint, corners included (lesson L-024),
  * `species`: the claw fraction of each distinct model, by firing rays UP from under the tree.

THE CLAW FRACTION IS DATA, MEASURED ONCE, AND ONLY WHEN IT IS STABLE (`tools/forest_claws.json`,
written by `species` and committed). For each of the fifty-one tree models the tool fires upward
rays on a grid over the ground-reaching parts and takes the HIGHEST "first thing you hit" -- under
an arch of claws that is the apex, i.e. the junction; under a flat-cut base it is the base itself.
A number is ACCEPTED only when the model's own instances agree to within 0.01 of the height and it
is under 0.10; everything else is recorded with its reason and treated as ZERO, which just seats
the model's lowest geometry on the ground and is still strictly better than today. The ones that
fail are the spruces and larches, whose skirt branches sweep to the ground and whose "first thing
you hit" is a branch underside fourteen studs up -- sinking those would bury the tree, and a
measurement that cannot be trusted is not used. The birches Karen photographed pass: every one of
the 26 `SilverBirch_Var11_LOD_0` in the forest measures 0.0424-0.0462, and the lobby's own
hand-measured number for that same model is 0.075 by a different method (horizontal rays, "where
the radius falls back to the trunk's"), so the two agree in kind and this one is the more
conservative of the two.

WHAT IT REFUSES, BEFORE IT TOUCHES ANYTHING -- the shape `tools/mapgen.py` already uses here:
  1. The Studio is not in EDIT mode. (Karen may be playing; rule C.)
  2. `game.PlaceId` is not the place asked for. IT ASKS EVERY CONNECTED STUDIO WHICH PLACE IT IS
     and never trusts the name: a Studio that has just finished a Play session reports no name at
     all for several seconds, and a silent fall-back here would move the DEV place's trees instead
     of Karen's (lesson L-055). With no match it stops and lists what it found.
  3. A dirty git tree, for `apply` and `restore`: a forest re-seated by uncommitted code cannot be
     reproduced from a commit.
  4. `apply` with no usable `--backup`: an existing, non-empty JSON written by `backup`, OUTSIDE
     the repository, less than BACKUP_MAX_AGE_HOURS old, covering the same number of models, and
     agreeing with the live place on every model's name and X/Z. Workspace has no other rollback.

Usage:
  python tools/forest_ground.py dims    [--write]                        # read-only unless --write
  python tools/forest_ground.py species [--out tools/forest_claws.json]   # read-only unless --out
  python tools/forest_ground.py backup  --out <path outside the repo>.json
  python tools/forest_ground.py plan    [--worst 10]                     # read-only DRY RUN
  python tools/forest_ground.py apply   --backup <path>.json             # the only command that moves
  python tools/forest_ground.py check   [--worst 10]                     # read-only: measure again
  python tools/forest_ground.py restore --backup <path>.json [--only i,j,k]

`--place <id>` picks the Studio (default: Karen's Forest Test, 130094961655666).

Exit codes, deliberately the harness's shape: 0 done, 1 something failed, 2 REFUSED.

The line worth pasting into a report is `plan`'s and `check`'s own:

  [forest] 4819 models, 584 floating (>0.20), worst 42.07 @ <sha> place=130094961655666

Research note: docs/research/2026-10-17-forest-trees-on-the-ground.md
"""

import argparse
import json
import re
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# ONE MCP CLIENT IN THE REPO, AND ONE DEFINITION OF "WHAT STUDIO SAID" (the rule `tools/mapgen.py`
# states in its own header): everything about talking to Studio is imported, never copied.
from studio_mcp import Studio, json_answer, luau_json  # noqa: E402

FOREST_PLACE_ID = "130094961655666"
FOREST_FOLDER = "OurForest"
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODULE_PATH = os.path.join(REPO, "src", "shared", "TreeGround", "init.luau")
CLAWS_PATH = os.path.join(REPO, "tools", "forest_claws.json")
BACKUP_MAX_AGE_HOURS = 24
BATCH = 250

# A CLAW FRACTION IS ACCEPTED ONLY IF THE MODEL'S OWN INSTANCES AGREE THIS CLOSELY (as a fraction of
# height) AND IT IS UNDER THIS MUCH. See the header: the second bound is what keeps a spruce's skirt
# branch out of the table.
CLAW_AGREE = 0.01
CLAW_MAX = 0.10
# How far up the model an upward ray may hit and still be called a junction.
CLAW_BAND = 0.25


def fail(message, code=1):
    print(message)
    sys.exit(code)


def git(*args):
    return subprocess.run(
        ["git", "-C", REPO] + list(args), capture_output=True, text=True, check=False
    ).stdout.strip()


def git_state():
    """(sha, clean). The same pair the harness prints, so a report line can carry it."""
    sha = git("rev-parse", "HEAD")
    return sha, git("status", "--porcelain") == ""


def module_source():
    """`TreeGround`'s own source, ready to be an expression.

    `export type` and `--!` are both module-scope-only in Luau, and this ends up inside a function
    body, so they are rewritten rather than reasoned about. Nothing else is touched: the arithmetic
    that reaches Studio is the arithmetic in the file, character for character.
    """
    with open(MODULE_PATH, encoding="utf-8") as handle:
        text = handle.read()
    lines = [line for line in text.splitlines() if not line.startswith("--!")]
    return "(function()\n" + "\n".join(lines).replace("export type ", "type ") + "\nend)()"


def module_number(name):
    """One of `TreeGround`'s own constants, read out of the module rather than restated here.

    The tool prints "floating (>0.20)" and "varies more than 4.0 studs" in its report; both numbers
    belong to the rule, and a second copy in this file is exactly the drift the shared module
    exists to stop.
    """
    with open(MODULE_PATH, encoding="utf-8") as handle:
        found = re.search(r"^TreeGround\.%s = ([0-9.]+)$" % name, handle.read(), re.M)
    if not found:
        fail("tools/forest_ground.py: TreeGround.%s is gone from %s" % (name, MODULE_PATH))
    return float(found.group(1))


def load_claws():
    if not os.path.exists(CLAWS_PATH):
        return {}
    with open(CLAWS_PATH, encoding="utf-8") as handle:
        return {row["model"]: row["clawFraction"] for row in json.load(handle)["species"]}


def resolve_studio(studio, place):
    """The Studio id for ONE place, by ASKING each instance which place it is (lesson L-055).

    The name is a label and the place id is the fact: StudioMCP returns no name at all for several
    seconds after a Play session ends, and an instance drops out of the listing entirely while it
    re-registers. Nothing here falls back to "the default Studio": moving the wrong place's trees
    is not a thing to risk on a guess.
    """
    seen = []
    for _ in range(12):
        try:
            studios = json.loads(studio._call("list_roblox_studios")).get("studios", [])
        except (ValueError, RuntimeError):
            studios = []
        seen = studios or seen
        for entry in studios:
            try:
                answer = studio.query("Edit", "return tostring(game.PlaceId)", studio_id=entry["id"]).strip()
            except RuntimeError:
                continue
            if answer == place:
                return entry["id"]
        time.sleep(2)
    names = "; ".join((e.get("name") or e.get("id", "?")[:8]) for e in seen) or "nothing"
    fail("REFUSED: no connected Studio answered as place %s. connected: %s" % (place, names), 2)


def require_edit(studio, studio_id, place):
    mode = studio.mode(studio_id=studio_id)
    if mode.strip() != "Edit":
        fail("REFUSED: that Studio is in %r, not Edit. Karen may be playing." % mode, 2)
    answer = studio.query("Edit", "return tostring(game.PlaceId)", studio_id=studio_id).strip()
    if answer != place:
        fail("REFUSED: that Studio is place %s, not %s." % (answer, place), 2)


def require_clean(command):
    sha, clean = git_state()
    if not clean:
        fail("REFUSED: `%s` needs a clean tree; a forest re-seated from uncommitted code cannot be "
             "reproduced from a commit. `git status` is dirty." % command, 2)
    return sha


# ---------------------------------------------------------------------------- the Luau payloads

# EVERY PAYLOAD STARTS WITH THE SAME PRELUDE: the shared module, and the two readers only the world
# can answer -- a model's visible boxes, and the terrain under a point.
PRELUDE = """
local H = game:GetService("HttpService")
local CLAW_BAND = %(clawBand)s
local TreeGround = %(module)s
local CLAWS = H:JSONDecode(%(claws)s)
local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { workspace.Terrain }
terrainParams.IgnoreWater = true
local function terrainAt(x, z, top)
	local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -4000, 0), terrainParams)
	return hit and hit.Position.Y or nil
end
-- A PART'S OWN AXIS-ALIGNED REACH. `Model:GetBoundingBox()` returns an ORIENTED box, so treating
-- its position and size as axis-aligned is wrong for anything turned -- and every tree here is
-- turned by its own yaw. This is `Build.worldBoxOf`'s projection, part by part.
local function boxOf(part)
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.CFrame:GetComponents()
	local s = part.Size
	local rx = 0.5 * (math.abs(r00) * s.X + math.abs(r01) * s.Y + math.abs(r02) * s.Z)
	local ry = 0.5 * (math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z)
	local rz = 0.5 * (math.abs(r20) * s.X + math.abs(r21) * s.Y + math.abs(r22) * s.Z)
	local p = part.Position
	return {
		minX = p.X - rx, minY = p.Y - ry, minZ = p.Z - rz,
		maxX = p.X + rx, maxY = p.Y + ry, maxZ = p.Z + rz,
	}
end
local function visible(model)
	local boxes, parts = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.95 then
			table.insert(parts, d)
			table.insert(boxes, boxOf(d))
		end
	end
	return parts, boxes, TreeGround.bounds(boxes)
end
-- WHERE THE TREE MEETS THE GROUND, HORIZONTALLY: the TRUNK's box. Named parts first, because every
-- one of these fifty-one models has one and it is the honest answer even when the crown's lowest
-- leaves hang below the trunk's foot; the parts that reach the ground are the fallback; the whole
-- model is the last resort (a fern is one MeshPart called "MeshPart").
local function trunkBox(parts, boxes, whole)
	local best, bestY = nil, math.huge
	for i, part in ipairs(parts) do
		if string.find(string.lower(part.Name), "trunk") and boxes[i].minY < bestY then
			best, bestY = boxes[i], boxes[i].minY
		end
	end
	if best == nil then
		local near = {}
		for _, i in ipairs(TreeGround.groundReaching(boxes, whole)) do
			table.insert(near, boxes[i])
		end
		best = TreeGround.bounds(near) or whole
	end
	-- ...AND CLAMPED TO THE ROOT FLARE. Some of these "Trunk" meshes are the whole lower tree.
	return TreeGround.flareFootprint(best, whole.maxY - whole.minY)
end
-- THE GROUND UNDER ONE TREE, at every corner and across the grid between them.
local function groundsUnder(foot, top)
	local out = {}
	for _, point in ipairs(TreeGround.samples(foot.minX, foot.minZ, foot.maxX, foot.maxZ, 4)) do
		local y = terrainAt(point.x, point.z, top)
		if y then
			table.insert(out, y)
		end
	end
	return out
end
local forest = workspace:FindFirstChild("%(folder)s")
if not forest then
	return H:JSONEncode({ error = "Workspace has no %(folder)s" })
end
local kids = forest:GetChildren()
"""

# ONE MODEL, MEASURED AND DECIDED. Shared by `plan`, `apply` and `check`, so the dry run and the run
# cannot disagree about which trees move.
MEASURE = """
local function measure(model)
	local parts, boxes, whole = visible(model)
	if whole == nil then
		return nil
	end
	local foot = trunkBox(parts, boxes, whole)
	local grounds = groundsUnder(foot, whole.maxY + 60)
	local claw = CLAWS[model.Name] or 0
	local verdict = TreeGround.decide(whole.minY, whole.maxY, claw, grounds)
	return whole, foot, verdict, claw
end
"""

ROWS = PRELUDE + MEASURE + """
local out = {}
for i = %(from)d, math.min(%(to)d, #kids) do
	local model = kids[i]
	local whole, foot, verdict, claw = measure(model)
	if whole then
		-- THE TRUNK'S OWN x AND z, NEVER THE MODEL'S PIVOT. A free model with no `PrimaryPart` has
		-- its pivot at the bounding-box centre, which for a leaning tree is studs away from the
		-- foot -- and a camera aimed at it photographs the wrong tree. Measured the hard way: the
		-- first close-up taken for this task showed a perfectly seated birch that was not the tree
		-- the row was about.
		table.insert(out, {
			i, model.Name, verdict.move, verdict.lift or 0, verdict.clawGap, verdict.bottomGap,
			verdict.spread, verdict.reason, claw, whole.maxY - whole.minY, whole.minY,
			(foot.minX + foot.maxX) / 2, whole.minY - verdict.bottomGap, (foot.minZ + foot.maxZ) / 2,
			(foot.maxX - foot.minX),
		})
	else
		table.insert(out, { i, model.Name, false, 0, 0, 0, 0, "no-parts", 0, 0, 0, 0, 0, 0, 0 })
	end
end
return H:JSONEncode({ rows = out, total = #kids })
"""

APPLY = PRELUDE + MEASURE + """
local out, moved = {}, 0
for i = %(from)d, math.min(%(to)d, #kids) do
	local model = kids[i]
	local whole, _, verdict = measure(model)
	if whole and verdict.move and verdict.lift then
		-- STRAIGHT DOWN AND NOTHING ELSE. `PivotTo` of the CURRENT pivot plus a Y delta is a pure
		-- translation of every part in the model: no yaw, no scale, no re-parenting, and X and Z
		-- come out bit-identical, which is what `restore` checks the backup against.
		model:PivotTo(model:GetPivot() + Vector3.new(0, verdict.lift, 0))
		moved += 1
		table.insert(out, { i, model.Name, verdict.lift })
	end
end
return H:JSONEncode({ rows = out, moved = moved, total = #kids })
"""

BACKUP = PRELUDE + """
local out = {}
for i = %(from)d, math.min(%(to)d, #kids) do
	local model = kids[i]
	local c = { model:GetPivot():GetComponents() }
	table.insert(out, { i, model.Name, c })
end
return H:JSONEncode({ rows = out, total = #kids })
"""

RESTORE = PRELUDE + """
local want = H:JSONDecode(%(want)s)
local done, bad = 0, {}
for _, row in ipairs(want) do
	local model = kids[row[1]]
	if model == nil or model.Name ~= row[2] then
		table.insert(bad, { row[1], row[2], model and model.Name or "<missing>", "name" })
	else
		local now = model:GetPivot().Position
		-- X AND Z ARE THE IDENTITY CHECK, and they can be: nothing this tool does moves a model
		-- sideways, so a model that has drifted in X or Z is not the model this row was written for
		-- and is left exactly where it is.
		if math.abs(now.X - row[3][1]) > 0.01 or math.abs(now.Z - row[3][3]) > 0.01 then
			table.insert(bad, { row[1], row[2], string.format("%%.2f,%%.2f", now.X, now.Z), "xz" })
		else
			local c = row[3]
			model:PivotTo(CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12]))
			done += 1
		end
	end
end
return H:JSONEncode({ done = done, bad = bad, total = #kids })
"""

# THE CLAW FRACTION OF ONE MODEL, measured off the mesh by firing rays UP from under it -- see the
# header. It is deliberately a SEPARATE payload from `measure`: this one runs once per model to
# WRITE the data file, and the planting then reads that file and does no mesh analysis at all.
SPECIES = PRELUDE + """
local out = {}
for i = %(from)d, math.min(%(to)d, #kids) do
	local model = kids[i]
	local parts, boxes, whole = visible(model)
	if whole then
		local height = whole.maxY - whole.minY
		local near = {}
		local nearBoxes = {}
		for _, k in ipairs(TreeGround.groundReaching(boxes, whole)) do
			table.insert(near, parts[k])
			table.insert(nearBoxes, boxes[k])
		end
		local foot = TreeGround.bounds(nearBoxes) or whole
		local up = RaycastParams.new()
		up.FilterType = Enum.RaycastFilterType.Include
		up.FilterDescendantsInstances = near
		up.IgnoreWater = true
		local cap = whole.minY + CLAW_BAND * height
		local junction = -math.huge
		for _, point in ipairs(TreeGround.samples(foot.minX, foot.minZ, foot.maxX, foot.maxZ, 6)) do
			local hit = workspace:Raycast(
				Vector3.new(point.x, whole.minY - 30, point.z),
				Vector3.new(0, 30 + CLAW_BAND * height + 1, 0),
				up
			)
			if hit and hit.Position.Y <= cap then
				junction = math.max(junction, hit.Position.Y)
			end
		end
		if junction == -math.huge then
			junction = whole.minY
		end
		table.insert(out, { model.Name, height, (junction - whole.minY) / math.max(height, 0.001) })
	end
end
return H:JSONEncode({ rows = out, total = #kids })
"""


def run_batched(studio, studio_id, template, extra=None, label="forest"):
    """Walk `OurForest` in batches -> the concatenated `rows`, and the total it reported."""
    claws = load_claws()
    fields = {
        "module": module_source(),
        "claws": luau_json(claws),
        "folder": FOREST_FOLDER,
        "clawBand": repr(CLAW_BAND),
    }
    fields.update(extra or {})
    rows, index, total = [], 1, None
    while True:
        payload = template % dict(fields, **{"from": index, "to": index + BATCH - 1})
        data, problem = json_answer(studio, "CLAW_BAND = " + repr(CLAW_BAND) + "\n" + payload, studio_id=studio_id)
        if problem:
            fail("[%s] FAILED: %s" % (label, problem))
        rows += data.get("rows", [])
        total = data.get("total", 0)
        index += BATCH
        if index > total:
            return rows, total


ROW_FIELDS = (
    "i name move lift clawGap bottomGap spread reason claw height minY footX groundY footZ footW"
).split()


def rows_as_dicts(rows):
    return [dict(zip(ROW_FIELDS, row)) for row in rows]


def report(rows, sha, place, worst, title):
    """The counts, the worst N, and the one line a report pastes."""
    models = rows_as_dicts(rows)
    trees = [m for m in models if m["height"] >= 10]
    low = [m for m in models if m["height"] < 10]
    print("\n%s -- %d models (%d trees >= 10 studs, %d low plants)" % (title, len(models), len(trees), len(low)))
    print("%-16s %7s %7s %7s %9s" % ("", "n", ">0.20", ">1.00", "worst"))
    for label, group in (("trees", trees), ("low plants", low), ("ALL", models)):
        if not group:
            continue
        claw = [m["clawGap"] for m in group]
        bottom = [m["bottomGap"] for m in group]
        print("%-16s %7d %7d %7d %9.2f   (junction above terrain)"
              % (label, len(group), sum(1 for v in claw if v > 0.2), sum(1 for v in claw if v > 1.0), max(claw)))
        print("%-16s %7s %7d %7d %9.2f   (lowest geometry above terrain -- task 196's own metric)"
              % ("", "", sum(1 for v in bottom if v > 0.2), sum(1 for v in bottom if v > 1.0), max(bottom)))
    skipped = [m for m in models if m["reason"] == "cliff"]
    if skipped:
        print("\nLISTED, NOT MOVED -- ground under the footprint varies more than %.1f studs:" % 4.0)
        for m in sorted(skipped, key=lambda m: -m["clawGap"])[:worst]:
            print("  #%-5d %-30s gap %6.2f  spread %6.2f  at %.0f, %.0f, %.0f"
                  % (m["i"], m["name"], m["clawGap"], m["spread"], m["footX"], m["groundY"], m["footZ"]))
    tol = module_number("TOLERANCE_STUDS")
    floating = sorted([m for m in models if m["clawGap"] > tol], key=lambda m: -m["clawGap"])
    if floating:
        print("\nWORST %d (junction above the lowest terrain under the trunk):" % min(worst, len(floating)))
        print("  %-6s %-30s %7s %7s %7s  %s" % ("#", "model", "gap", "bottom", "lift", "trunk base x, y, z"))
        for m in floating[:worst]:
            print("  %-6d %-30s %7.2f %7.2f %7.2f  %.1f, %.1f, %.1f"
                  % (m["i"], m["name"], m["clawGap"], m["bottomGap"], m["lift"],
                     m["footX"], m["minY"], m["footZ"]))
    worst_gap = max([m["clawGap"] for m in models] or [0])
    print("\n[forest] %d models, %d floating (>0.20), worst %.2f @ %s place=%s"
          % (len(models), sum(1 for m in models if m["clawGap"] > 0.2), worst_gap, sha[:12], place))
    return models


# ---------------------------------------------------------------------------- the commands


def cmd_species(args, studio, studio_id, sha, place):
    rows, total = run_batched(studio, studio_id, SPECIES, label="species")
    by_model = {}
    for name, height, fraction in rows:
        by_model.setdefault(name, []).append((height, fraction))
    out = []
    for name in sorted(by_model):
        values = [f for _, f in by_model[name]]
        heights = [h for h, _ in by_model[name]]
        spread = max(values) - min(values)
        median = sorted(values)[len(values) // 2]
        if max(heights) < 10:
            reason = "low-plant"
        elif spread > CLAW_AGREE:
            reason = "unstable"
        elif median > CLAW_MAX:
            reason = "over-bound"
        else:
            reason = "accepted"
        out.append({
            "model": name,
            "count": len(values),
            "medianHeight": round(sum(heights) / len(heights), 2),
            "measured": round(median, 4),
            "agreement": round(spread, 4),
            "clawFraction": round(median, 4) if reason == "accepted" else 0.0,
            "reason": reason,
        })
    print("%-32s %5s %8s %8s %9s %10s %s" % ("model", "n", "height", "measured", "agree", "used", "why"))
    for row in out:
        print("%-32s %5d %8.1f %8.4f %9.4f %10.4f %s"
              % (row["model"], row["count"], row["medianHeight"], row["measured"],
                 row["agreement"], row["clawFraction"], row["reason"]))
    used = [r for r in out if r["clawFraction"] > 0]
    print("\n%d models measured, %d carry a claw fraction, %d are seated on their lowest geometry"
          % (len(out), len(used), len(out) - len(used)))
    if args.out:
        with open(args.out, "w", encoding="utf-8") as handle:
            json.dump({
                "measuredAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "measuredAtCommit": sha,
                "place": place,
                "howMeasured": (
                    "forest_ground.py species: upward rays on a 7x7 grid over the ground-reaching "
                    "parts' footprint; the junction is the highest first-hit below 0.25 of the "
                    "model's height. Accepted only when the model's instances agree to %s of "
                    "height and the fraction is under %s; see the tool's docstring."
                    % (CLAW_AGREE, CLAW_MAX)
                ),
                "species": out,
            }, handle, indent=1)
            handle.write("\n")
        print("wrote %s" % args.out)
    return 0


def cmd_backup(args, studio, studio_id, sha, place):
    target = os.path.abspath(args.out)
    if target.startswith(REPO + os.sep):
        fail("REFUSED: the backup must live OUTSIDE the repository; %s is inside it." % target, 2)
    rows, total = run_batched(studio, studio_id, BACKUP, label="backup")
    if len(rows) != total:
        fail("[backup] FAILED: read %d of %d models." % (len(rows), total))
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "w", encoding="utf-8") as handle:
        json.dump({
            "takenAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "commit": sha,
            "place": place,
            "folder": FOREST_FOLDER,
            "count": len(rows),
            "models": [{"i": r[0], "name": r[1], "cframe": r[2]} for r in rows],
        }, handle)
        handle.write("\n")
    print("[backup] %d models -> %s" % (len(rows), target))
    print("Restore with: python tools/forest_ground.py restore --backup %s" % target)
    return 0


def read_backup(path, command):
    if not path:
        fail("REFUSED: `%s` needs --backup <path>. Workspace has no other rollback." % command, 2)
    target = os.path.abspath(path)
    if target.startswith(REPO + os.sep):
        fail("REFUSED: the backup must live OUTSIDE the repository; %s is inside it." % target, 2)
    if not os.path.exists(target) or os.path.getsize(target) == 0:
        fail("REFUSED: %s does not exist or is empty. Run `backup` first." % target, 2)
    age = (time.time() - os.path.getmtime(target)) / 3600.0
    if age > BACKUP_MAX_AGE_HOURS:
        fail("REFUSED: %s is %.1f h old (max %d). Take a fresh one." % (target, age, BACKUP_MAX_AGE_HOURS), 2)
    with open(target, encoding="utf-8") as handle:
        return json.load(handle), target


def cmd_apply(args, studio, studio_id, sha, place):
    saved, path = read_backup(args.backup, "apply")
    if saved.get("place") != place:
        fail("REFUSED: %s was taken on place %s, not %s." % (path, saved.get("place"), place), 2)
    before, total = run_batched(studio, studio_id, ROWS, label="plan")
    if saved.get("count") != total:
        fail("REFUSED: the backup holds %d models and the place has %d. Take a fresh one."
             % (saved.get("count"), total), 2)
    by_index = {m["i"]: m for m in saved["models"]}
    for row in rows_as_dicts(before):
        kept = by_index.get(row["i"])
        if kept is None or kept["name"] != row["name"]:
            fail("REFUSED: model #%d is %r here and %r in the backup. Take a fresh one."
                 % (row["i"], row["name"], kept and kept["name"]), 2)
    print("[apply] backup %s checked against the live place: %d models, every name and index agrees"
          % (path, total))
    report(before, sha, place, args.worst, "BEFORE")
    rows, _ = run_batched(studio, studio_id, APPLY, label="apply")
    print("\n[apply] moved %d models straight down." % len(rows))
    after, _ = run_batched(studio, studio_id, ROWS, label="check")
    report(after, sha, place, args.worst, "AFTER")
    return 0


def cmd_plan(args, studio, studio_id, sha, place):
    rows, _ = run_batched(studio, studio_id, ROWS, label="plan")
    models = report(rows, sha, place, args.worst, "DRY RUN -- nothing was moved")
    movers = [m for m in models if m["move"]]
    print("[forest] would move %d models; %d listed as cliff edges; %d already seated"
          % (len(movers), sum(1 for m in models if m["reason"] == "cliff"),
             sum(1 for m in models if m["reason"] == "seated")))
    if args.out:
        with open(args.out, "w", encoding="utf-8") as handle:
            json.dump(models, handle, indent=1)
        print("wrote %s" % args.out)
    return 0


def cmd_check(args, studio, studio_id, sha, place):
    rows, _ = run_batched(studio, studio_id, ROWS, label="check")
    report(rows, sha, place, args.worst, "MEASURED NOW")
    if args.out:
        with open(args.out, "w", encoding="utf-8") as handle:
            json.dump(rows_as_dicts(rows), handle, indent=1)
        print("wrote %s" % args.out)
    return 0


def cmd_restore(args, studio, studio_id, sha, place):
    saved, path = read_backup(args.backup, "restore")
    if saved.get("place") != place:
        fail("REFUSED: %s was taken on place %s, not %s." % (path, saved.get("place"), place), 2)
    models = saved["models"]
    if args.only:
        wanted = {int(v) for v in args.only.split(",")}
        models = [m for m in models if m["i"] in wanted]
        if not models:
            fail("REFUSED: --only %s matched nothing in the backup." % args.only, 2)
    print("[restore] %d of %d models from %s" % (len(models), saved["count"], path))
    fields = {
        "module": module_source(),
        "claws": luau_json(load_claws()),
        "folder": FOREST_FOLDER,
        "clawBand": repr(CLAW_BAND),
    }
    done, bad = 0, []
    for start in range(0, len(models), BATCH):
        batch = [[m["i"], m["name"], m["cframe"]] for m in models[start:start + BATCH]]
        payload = RESTORE % dict(fields, want=luau_json(batch))
        data, problem = json_answer(studio, payload, studio_id=studio_id)
        if problem:
            fail("[restore] FAILED: %s" % problem)
        done += data.get("done", 0)
        bad += data.get("bad", [])
    for entry in bad:
        print("  SKIPPED #%s %s: now %s (%s mismatch)" % tuple(entry))
    print("[restore] %d restored, %d skipped" % (done, len(bad)))
    return 1 if bad else 0



# ---------------------------------------------------------------------------- `dims` (design 9.2)

PLAN_PATH = os.path.join(REPO, "src", "shared", "Places", "init.luau")
PLANTER_PATH = os.path.join(REPO, "src", "server", "Places", "init.luau")


def luau_table(path, name):
    """The body of one `Places.<name> = table.freeze({ ... })`.

    The tool reads the game's own tables instead of restating them -- a second copy of `SPECIES`
    here is a second thing to drift, which is why `module_number` exists.
    """
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    found = re.search(r"^Places\.%s = table\.freeze\(\{(.*?)^\}\)" % name, text, re.M | re.S)
    if not found:
        fail("tools/forest_ground.py: Places.%s is gone from %s" % (name, path))
    return found.group(1)


def species_names():
    """[(group, name)] for every template `Places.SPECIES` can plant, in file order."""
    out, group = [], None
    for line in luau_table(PLAN_PATH, "SPECIES").splitlines():
        head = re.match(r"\s*(\w+) = table\.freeze\(\{", line)
        if head:
            group = head.group(1)
            line = line[head.end():]
        for name in re.findall(r'"([^"]+)"', line):
            out.append((group, name))
    return out


def plan_strings(name):
    return re.findall(r'"([^"]+)"', luau_table(PLAN_PATH, name))


def planter_sources():
    """`Places.TEMPLATE_SOURCES`, in order: the folders the planter clones from."""
    with open(PLANTER_PATH, encoding="utf-8") as handle:
        found = re.search(r"^Places\.TEMPLATE_SOURCES = table\.freeze\(\{([^}]*)\}\)", handle.read(), re.M)
    if not found:
        fail("tools/forest_ground.py: Places.TEMPLATE_SOURCES is gone from %s" % PLANTER_PATH)
    return re.findall(r'"([^"]+)"', found.group(1))


def planter_number(name):
    """One of the PLANTER's constants, read out of its file rather than restated (`INVISIBLE_AT`)."""
    with open(PLANTER_PATH, encoding="utf-8") as handle:
        found = re.search(r"^Places\.%s = ([0-9.]+)$" % name, handle.read(), re.M)
    if not found:
        fail("tools/forest_ground.py: Places.%s is gone from %s" % (name, PLANTER_PATH))
    return float(found.group(1))


def current_rows():
    """`Places.TEMPLATE_DIMS` as it stands in the repo: {name: {field: number}}."""
    out = {}
    for name, fields in re.findall(
        r"(\w+) = table\.freeze\(\{(.*?)\}\)", luau_table(PLAN_PATH, "TEMPLATE_DIMS"), re.S
    ):
        out[name] = {k: float(v) for k, v in re.findall(r"(\w+) = (-?[0-9.]+)", fields)}
    return out


# ONE TEMPLATE, MEASURED THE WAY `Places.measureFor` MEASURES A CLONE (design 9.2 and 9.3): the
# visible parts, split by `Places.isFoliageName` into trunk and crown, at the template's OWN
# `GetScale()`, which is recorded because `plantOne`'s `item.scale` is relative to it.
#
# WHICH INSTANCE IS "THE TEMPLATE": the MEDIAN by scale, over every instance of that name in the
# first `TEMPLATE_SOURCES` folder that has any. `Workspace.OurForest` is the wood and not a folder of
# 35 models -- each name has 16 to 125 instances whose scales span x1.8 -- so `FindFirstChild`'s
# answer is arbitrary and moves with the child order. The median is a measurement; one tree added or
# removed does not move it; and `Places.pickTemplate` in game then finds it again by the row's scale.
# The first child's scale is reported beside it, which is the number the old lookup would have used.
DIMS = """
local H = game:GetService("HttpService")
local TreeGround = %(module)s
local SOURCES = H:JSONDecode(%(sources)s)
local NAMES = H:JSONDecode(%(names)s)
local WORDS = H:JSONDecode(%(words)s)
local INVISIBLE_AT = %(invisible)s
local function isFoliage(name)
	local lower = string.lower(name)
	for _, word in ipairs(WORDS) do
		if string.find(lower, word, 1, true) then
			return true
		end
	end
	return false
end
local function boxOf(part)
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.CFrame:GetComponents()
	local s = part.Size
	local rx = 0.5 * (math.abs(r00) * s.X + math.abs(r01) * s.Y + math.abs(r02) * s.Z)
	local ry = 0.5 * (math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z)
	local rz = 0.5 * (math.abs(r20) * s.X + math.abs(r21) * s.Y + math.abs(r22) * s.Z)
	local p = part.Position
	return {
		minX = p.X - rx, minY = p.Y - ry, minZ = p.Z - rz,
		maxX = p.X + rx, maxY = p.Y + ry, maxZ = p.Z + rz,
	}
end
local roots = {}
for _, path in ipairs(SOURCES) do
	local at = workspace
	for piece in string.gmatch(path, "[^%%.]+") do
		at = if at then at:FindFirstChild(piece) else nil
	end
	if at ~= nil then
		table.insert(roots, { path, at })
	end
end
local function pathOf(thing)
	local out, at = {}, thing
	while at ~= nil and at ~= workspace do
		table.insert(out, 1, at.Name)
		at = at.Parent
	end
	return table.concat(out, ".")
end
local function measure(model)
	local all, trunks, crowns, parts = {}, {}, {}, 0
	for _, thing in ipairs(model:GetDescendants()) do
		if thing:IsA("BasePart") and thing.Transparency < INVISIBLE_AT then
			local box = boxOf(thing)
			parts += 1
			table.insert(all, box)
			if isFoliage(thing.Name) then
				table.insert(crowns, box)
			else
				table.insert(trunks, box)
			end
		end
	end
	local whole = TreeGround.bounds(all)
	if whole == nil then
		return nil
	end
	local trunk = TreeGround.bounds(trunks) or whole
	local crown = TreeGround.bounds(crowns)
	return {
		scale = model:GetScale(),
		parts = parts,
		heightStuds = whole.maxY - whole.minY,
		trunkHalfWidthStuds = math.max(trunk.maxX - trunk.minX, trunk.maxZ - trunk.minZ) / 2,
		crownHalfWidthStuds = if crown
			then math.max(crown.maxX - crown.minX, crown.maxZ - crown.minZ) / 2
			else 0,
		-- HOW FAR THE CROWN HANGS BELOW THE TRUNK BOX'S FOOT. Positive means the seat has to make
		-- room for it or the leaves finish under the grass (`GridCensus.foliageInGround`).
		foliageDropStuds = if crown then math.max(0, trunk.minY - crown.minY) else 0,
		trunkTallerThanWide = (trunk.maxY - trunk.minY) >= (trunk.maxX - trunk.minX)
			and (trunk.maxY - trunk.minY) >= (trunk.maxZ - trunk.minZ),
	}
end
local out = {}
for _, row in ipairs(NAMES) do
	local group, name = row[1], row[2]
	local found, source, first, kept = nil, "-", nil, {}
	for _, pair in ipairs(roots) do
		if found == nil then
			local models = {}
			for _, child in ipairs(pair[2]:GetChildren()) do
				if child.Name == name and child:IsA("Model") then
					table.insert(models, child)
				end
			end
			if #models > 0 then
				first, source = models[1]:GetScale(), pair[1]
				table.sort(models, function(a, b)
					return a:GetScale() < b:GetScale()
				end)
				found, kept = models[math.ceil(#models / 2)], models
			end
		end
	end
	local entry = {
		group = group,
		name = name,
		source = source,
		instances = #kept,
		firstScale = first or 0,
		lowScale = if #kept > 0 then kept[1]:GetScale() else 0,
		highScale = if #kept > 0 then kept[#kept]:GetScale() else 0,
	}
	if found == nil then
		entry.missing = true
	else
		entry.path = pathOf(found)
		local m = measure(found)
		if m == nil then
			entry.missing = true
			entry.note = "no-visible-part"
		else
			for key, value in pairs(m) do
				entry[key] = value
			end
		end
	end
	table.insert(out, entry)
end
return H:JSONEncode({ rows = out, count = #out })
"""


def cmd_dims(args, studio, studio_id, sha, place):
    """Design 9.2: re-derive `Places.TEMPLATE_DIMS` from the live templates. Read-only until --write."""
    rows_in = species_names()
    payload = DIMS % {
        "module": module_source(),
        "sources": luau_json(planter_sources()),
        "names": luau_json([[group, name] for group, name in rows_in]),
        "words": luau_json(plan_strings("FOLIAGE_WORDS")),
        "invisible": repr(planter_number("INVISIBLE_AT")),
    }
    data, problem = json_answer(studio, payload, studio_id=studio_id)
    if problem:
        fail("[dims] FAILED: %s" % problem)
    rows = data.get("rows", [])
    was = current_rows()
    print("\n%-30s %5s %8s %8s %8s %8s %7s %6s %6s %5s"
          % ("template", "n", "median", "row", "med/row", "first", "height", "crown", "drop", "parts"))
    worst, missing, moved = 1.0, [], []
    for row in rows:
        if row.get("missing"):
            missing.append(row["name"])
            print("%-30s %5d %8s  %s" % (row["name"], row["instances"], "MISSING", row.get("note", "")))
            continue
        old = was.get(row["name"], {})
        ratio = row["scale"] / max(old.get("scale") or 1e-9, 1e-9)
        worst = max(worst, ratio, 1.0 / ratio)
        print("%-30s %5d %8.4f %8.4f %8.3f %8.4f %7.1f %6.2f %6.2f %5d"
              % (row["name"], row["instances"], row["scale"], old.get("scale", 0), ratio,
                 row["firstScale"], row["heightStuds"], row["crownHalfWidthStuds"],
                 row["foliageDropStuds"], row["parts"]))
        if abs(ratio - 1) > 0.001:
            moved.append(row["name"])
    spread = max((r["highScale"] / max(r["lowScale"], 1e-9)) for r in rows if r.get("instances"))
    print("  one name's instances span up to x%.2f in scale, which is why the median is the row" % spread)
    for drop, name in sorted(
        ((r["foliageDropStuds"], r["name"]) for r in rows if not r.get("missing")), reverse=True
    ):
        if drop > 0:
            print("  crown below the trunk box: %-30s %6.3f studs" % (name, drop))
    print("\n[dims] %d templates, %d missing, %d off their row (worst ratio %.3f) @ %s place=%s"
          % (len(rows), len(missing), len(moved), worst, sha[:12], place))
    if args.write:
        if missing:
            fail("[dims] REFUSED --write: %d of the templates are not in this place: %s"
                 % (len(missing), ", ".join(missing)), 2)
        print("[dims] wrote %d rows into %s" % (len(rows), write_dims(rows)))
    return 0


def dims_block(rows):
    """The `TEMPLATE_DIMS` body, generated: a group comment, then one frozen row per template."""
    out, group = [], None
    for row in rows:
        if row["group"] != group:
            group = row["group"]
            out.append("\t-- %s" % group)
        out.append("\t%s = table.freeze({" % row["name"])
        out.append("\t\tscale = %.4f," % row["scale"])
        out.append("\t\theightStuds = %.1f," % row["heightStuds"])
        out.append("\t\ttrunkHalfWidthStuds = %.2f," % row["trunkHalfWidthStuds"])
        out.append("\t\tcrownHalfWidthStuds = %.2f," % row["crownHalfWidthStuds"])
        out.append("\t\tfoliageDropStuds = %.2f," % row["foliageDropStuds"])
        out.append("\t\tparts = %d," % row["parts"])
        out.append("\t}),")
    return "\n".join(out)


def write_dims(rows):
    """Replace the generated body in place. The header above it is a person's and is not touched."""
    with open(PLAN_PATH, encoding="utf-8") as handle:
        text = handle.read()
    begin = "Places.TEMPLATE_DIMS = table.freeze({\n"
    at = text.find(begin)
    end = text.find("\n})\n", at)
    if at < 0 or end < 0:
        fail("tools/forest_ground.py: cannot find Places.TEMPLATE_DIMS's block in %s" % PLAN_PATH)
    with open(PLAN_PATH, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text[: at + len(begin)] + dims_block(rows) + text[end:])
    return PLAN_PATH


COMMANDS = {
    "dims": (cmd_dims, False),
    "species": (cmd_species, False),
    "backup": (cmd_backup, False),
    "plan": (cmd_plan, False),
    "apply": (cmd_apply, True),
    "check": (cmd_check, False),
    "restore": (cmd_restore, True),
}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("command", choices=sorted(COMMANDS))
    parser.add_argument("--place", default=FOREST_PLACE_ID)
    parser.add_argument("--backup", default=None)
    parser.add_argument("--out", default=None)
    parser.add_argument("--only", default=None)
    parser.add_argument("--worst", type=int, default=10)
    parser.add_argument("--write", action="store_true",
                        help="`dims` only: rewrite Places.TEMPLATE_DIMS from the measurement")
    args = parser.parse_args(argv)
    handler, mutates = COMMANDS[args.command]
    sha = require_clean(args.command) if mutates else git_state()[0]
    studio = Studio()
    try:
        studio_id = resolve_studio(studio, args.place)
        require_edit(studio, studio_id, args.place)
        print("[forest] place %s, Studio %s, Edit" % (args.place, studio_id[:8]))
        return handler(args, studio, studio_id, sha, args.place)
    finally:
        studio.close()


if __name__ == "__main__":
    sys.exit(main())
