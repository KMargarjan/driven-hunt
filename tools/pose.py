#!/usr/bin/env python3
"""The Director's viewmodel tuning instrument: change a pose number in a RUNNING Studio session.

    python tools/pose.py                              every pose number, and what is overridden
    python tools/pose.py show [pose]                  the effective values (one pose, or all)
    python tools/pose.py set <path> <value>           e.g. `set aim.eyeReliefStuds 4.2`
    python tools/pose.py save                         write the effective values into poses.json
    python tools/pose.py clear                        drop every override
    python tools/pose.py inspect <pose> [left-front|below|right-rear] [--client <name>]
                                                      LOOK AT THE HANDS FROM OUTSIDE. The viewmodel
                                                      is drawn at the camera, so it follows the lens
                                                      wherever it goes: this COPIES it into the sky,
                                                      hides the live one for the length of the shot
                                                      and photographs the copy from three fixed angles.
                                                      Nothing about the pose or the player's own
                                                      camera moves, and the copy is destroyed again
    python tools/pose.py compare <pose> [--target <image>] [--assets-dir <dir>]
                                        [--client <name>]
                                                      hold the pose, capture it, build ONE
                                                      side-by-side with the reference frame, and
                                                      print the measured landmarks. `--client` says
                                                      WHICH player to photograph (`--client Player1`):
                                                      with two players one of them is the DRIVER and
                                                      carries no gun, and the default is simply the
                                                      first client that answered
    python tools/pose.py fit <pose> --landmarks <file> [--evals N] [--settle S]
                                        [--target <image>] [--client <name>]
                                                      SOLVE a pose instead of guessing it: given the
                                                      target screen positions of a few landmarks,
                                                      search the gun's six numbers in the RUNNING
                                                      session until what is drawn matches, then
                                                      print the values and capture one side-by-side.
                                                      `<pose>` is the dotted prefix of a pose that
                                                      has a `gun` block: `reload`, `newGun.reload`,
                                                      `carry`, `newGun.carry`
    python tools/pose.py play | stop                   start or end a SOLO Play session, which is the
                                                      one a capture can reach: Studio's two-player
                                                      session leaves its CLIENT processes unconnected
                                                      to StudioMCP (measured, task 103)
    python tools/pose.py selftest                     NO Studio: prove the merge, the paths, the
                                                      file round trip and the search (CI runs this)

WHY IT EXISTS. Karen, 2026-10-01, after task 97 was stopped: tuning the shotgun's poses by editing
Luau, running the gate and asking for a review cost HOURS PER TWEAK, and what is being tuned is a
picture. So every pose number is data -- `src/shared/Viewmodel/poses.json` -- and this writes an
override into a live session that `Camera.Poses` applies on the next frame. Change, look, change.
When a pose is right, `save` writes it back into the file; that commit needs the gate like any other
`src/` change, but the twenty tries before it need nothing at all.

ONE WRITER. The override is a single JSON string in the attribute `DHPose` on
ReplicatedStorage.Viewmodel, and this tool is the only thing that writes it (GAME_DESIGN.md owners).
`tools/studio_mcp.py` holds the Luau and the transport -- the same split `tools/flags.py` has -- and
the one check that belongs to the harness: `test` and `test2` both REFUSE to start while an override
is set in the Edit place, and print this tool's `clear` line.

`set` AND `compare` NEED A PLAY SESSION, and are refused in Edit mode. That is the opposite of
`tools/flags.py` and for the same underlying reason: a flag is resolved once at server boot, so it
must be set BEFORE the session, while a pose is read every frame, so it must be set DURING one. An
override written into the Edit place would also be SAVED WITH THE PLACE and published, which is what
the harness guard exists to catch.

WHY `fit` EXISTS. Karen's bar is "perfect" and the reload is six numbers at once -- where the gun
is and which way it points -- so hand-guessing them is guessing in six dimensions with a screenshot
per try. The Director spent a session on the break-open pose and did not get there. A reference
frame, though, says exactly where the breech and the stock ARE on the screen, and the session can
already measure where ours are (`compare` prints those same numbers). So the tool closes the loop:
write a candidate, measure it, score it, step. No screenshot per step -- the landmark query is a
projection, not a picture -- and the search is bounded, so it cannot answer with the gun behind the
player. One capture at the end, to be looked at (rule 5).

WHAT IT NEVER DOES: send arbitrary Luau (every query is a constant in `tools/studio_mcp.py`,
templated with JSON at most), touch git, or write anything into the repo except `poses.json` on
`save` and a PNG under `.screenshots/` (git-ignored) on `compare`.

THE REFERENCE FRAMES ARE NOT IN THE REPO. They are third-party video stills; `--assets-dir`, or the
environment variable DRIVEN_HUNT_ASSETS, says where they live, and the default target for a pose is
`<assets-dir>/references/inspiration-2026-10-01/TARGET-<pose>.jpg`. No local path is ever written
into a committed file (CLAUDE.md, "Public repository").
"""

import datetime
import json
import math
import os
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import studio_mcp  # noqa: E402

REPO = studio_mcp.REPO
POSES_FILE = os.path.join(REPO, "src", "shared", "Viewmodel", "poses.json")
REFERENCE_SET = "inspiration-2026-10-01"
HOLD_KEY = "hold"
# THE SECOND KEY IN THE OVERRIDE THAT IS NOT A POSE NUMBER (task 102). `fit` bumps it on every
# candidate it writes so it can tell a reading of the pose it just asked for from a reading of the
# one before it. `Viewmodel.SERIAL_KEY` in Luau is the same string, and `Viewmodel.merge` skips it.
SERIAL_KEY = "serial"
HOLDS = ("carry", "raise", "aim", "reload")


# ---------------------------------------------------------------- the file, and the paths in it

def read_poses(path=POSES_FILE):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def write_poses(data, path=POSES_FILE):
    """Pretty, sorted, newline-terminated -- and that is the format the file SHIPS in, so `save` is
    idempotent and a diff after tuning one number is one line rather than a reordered file."""
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(data, indent=2, sort_keys=True) + "\n")


def paths_of(data):
    """Every numeric leaf as dotted path -> value.

    THE SAME RULE AS `Viewmodel.paths` IN LUAU, deliberately duplicated in the one place a duplicate
    is unavoidable: this tool must refuse a typo BEFORE it writes, and it cannot ask the game. The
    selftest below pins the rule to the shipped file, and the Luau side refuses the same paths again
    when it merges -- so a drift between the two shows up as an override the game logs as refused
    rather than as a pose nobody chose.
    """
    out = {}

    def walk(node, prefix):
        if not isinstance(node, dict) and not isinstance(node, list):
            return
        items = node.items() if isinstance(node, dict) else enumerate(node, start=1)
        for key, value in items:
            at = f"{prefix}.{key}" if prefix else str(key)
            if isinstance(value, bool):
                continue
            if isinstance(value, (int, float)):
                out[at] = value
            else:
                walk(value, at)

    for key, value in data.items():
        if key != "version" and isinstance(value, (dict, list)):
            walk(value, key)
    return out


def apply_overrides(data, overrides):
    """(effective data, problems). Refuses a path that is not already a number, exactly as the Luau
    side does: a typo must leave the gun where it was rather than add a field nothing reads."""
    out = json.loads(json.dumps(data))  # a deep copy, through the format the file is in anyway
    known = paths_of(data)
    problems = []
    for path in sorted(overrides):
        if path in (HOLD_KEY, SERIAL_KEY):
            continue
        value = overrides[path]
        if path not in known:
            problems.append(f"{path} is not a pose number")
        elif isinstance(value, bool) or not isinstance(value, (int, float)):
            problems.append(f"{path} = {value!r} is not a number")
        else:
            node = out
            parts = path.split(".")
            for part in parts[:-1]:
                node = node[int(part) - 1] if isinstance(node, list) else node[part]
            last = parts[-1]
            if isinstance(node, list):
                node[int(last) - 1] = value
            else:
                node[last] = value
    return out, problems


# ---------------------------------------------------------------- the running session

def running(studio, role):
    """(studio_id, datamodel, "") for a RUNNING session's server or client, else (None, None, why).

    THE EDIT CHECK IS NOT BELT AND BRACES. With exactly one Studio connected, `studio_for_role`
    answers with that Studio whatever role was asked for -- which is right for a Play-solo session,
    where the editor's own process holds the Server and Client DataModels, and wrong for an idle
    editor. The mode is what tells them apart, so it is asked every time."""
    studio_id, why = studio_mcp.studio_for_role(studio, role)
    if studio_id is None:
        return None, None, why
    try:
        mode = studio.mode(studio_id=studio_id)
    except RuntimeError as problem:
        return None, None, str(problem)
    if mode != "Play":
        return None, None, (
            f"Studio is in {mode} mode. Start a Play session first: the camera reads the override "
            "every frame, so a write with nothing rendering changes nothing -- and an override "
            "written into the EDIT place would be saved with the place and published.")
    return studio_id, ("Server" if role.startswith("server") else "Client"), ""


def read_override(studio, studio_id, datamodel):
    """The override object the session is carrying, as a dict ({} for none) -> (dict, problem).

    NEVER RAISES ON WHAT STUDIO SAID, which is the rule `studio_mcp.json_answer` exists for: a
    DataModel that is not reachable is an ordinary answer to "is anything overridden", not a
    traceback over the Director's command."""
    try:
        raw = studio.query(datamodel, studio_mcp.QUERY_POSE_OVERRIDE, studio_id=studio_id).strip()
    except RuntimeError as why:
        return {}, str(why)
    if not raw:
        return {}, ""
    try:
        decoded = json.loads(raw)
    except json.JSONDecodeError as why:
        return {}, f"the session is carrying an override that is not JSON ({why}): {raw[:120]!r}"
    if not isinstance(decoded, dict):
        return {}, f"the session is carrying an override that is not an object: {raw[:120]!r}"
    return decoded, ""


def write_override(studio, studio_id, datamodel, overrides):
    """Replace the whole override object (an empty one clears the attribute) -> (text, problem).

    WHOLE, NOT PER PATH. One attribute means one write, so there is no moment at which half of a
    tuning change is live; and clearing is this same call with nothing in it.

    IT NEVER RAISES ON WHAT STUDIO SAID either, and that is MEASURED rather than tidy: `clear` also
    clears the EDIT place -- the one a `test` run would be refused over -- and the Edit DataModel is
    NOT REACHABLE while a Play session runs ("Edit datamodel is not available in Play mode"). So the
    first `pose.py clear` typed during a tuning session ended in a traceback, after it had already
    cleared the session. A tool that half-succeeds and then crashes is worse than one that refuses."""
    text = "" if not overrides else json.dumps(overrides, sort_keys=True)
    try:
        answer, problem = studio_mcp.json_answer(
            studio, studio_mcp.QUERY_SET_POSE % json.dumps(text), studio_id=studio_id, datamodel=datamodel)
    except RuntimeError as why:
        return "", str(why)
    if problem:
        return "", problem
    return answer.get("set", ""), ""


# ---------------------------------------------------------------- printing

def print_table(data, overrides, only=None):
    effective, problems = apply_overrides(data, overrides)
    base = paths_of(data)
    now = paths_of(effective)
    rows = [p for p in sorted(now) if only is None or p == only or p.startswith(only + ".")]
    if not rows:
        print(f"[pose] no pose number matches {only!r}. Try one of: " + ", ".join(sorted(data)))
        return 2
    width = max(len(p) for p in rows)
    print(f"[pose] {'PATH'.ljust(width)}  file        live        ")
    for path in rows:
        changed = abs(now[path] - base[path]) > 1e-12
        print("[pose] {}  {:<10}  {:<10}{}".format(
            path.ljust(width), f"{base[path]:g}", f"{now[path]:g}", "  <- override" if changed else ""))
    held = overrides.get(HOLD_KEY)
    if held:
        print(f"[pose] holding the {held} pose (cleared by `pose.py clear`)")
    for problem in problems:
        print("[pose] REFUSED: " + problem)
    if not overrides:
        print("[pose] no override is set: these are the file's own values")
    return 0


# ---------------------------------------------------------------- compare

def target_for(pose, assets_dir, explicit=None):
    if explicit:
        return explicit
    if not assets_dir:
        return None
    return os.path.join(assets_dir, "references", REFERENCE_SET, f"TARGET-{pose}.jpg")


def side_by_side(target_path, ours_path, out_path, pose, bead=None):
    """ONE image: the reference frame on the left, what we render on the right.

    Pillow only, and imported here rather than at the top of the file: CI runs this module's
    `selftest` and has no Pillow, and a tool that cannot be imported without an optional dependency
    is a tool that cannot be selftested.

    Both halves are scaled to the same HEIGHT, because that is what makes a vertical field of view
    comparable -- Roblox's FOV is vertical, and the two sources have different aspect ratios (the
    video is 16:9, a Studio Play window is nearer 1.24:1). So the same composition reads at a
    different angle ACROSS the two pictures and at the same angle DOWN them, which is written down
    here because task 97 spent a round on it.
    """
    from PIL import Image, ImageDraw  # noqa: PLC0415 -- see the docstring

    target = Image.open(target_path).convert("RGB")
    ours = Image.open(ours_path).convert("RGB")
    height = 720
    target = target.resize((max(1, round(target.width * height / target.height)), height))
    ours = ours.resize((max(1, round(ours.width * height / ours.height)), height))
    gap = 8
    sheet = Image.new("RGB", (target.width + gap + ours.width, height + 24), (24, 24, 24))
    sheet.paste(target, (0, 24))
    sheet.paste(ours, (target.width + gap, 24))
    draw = ImageDraw.Draw(sheet)
    draw.text((4, 6), f"VIDEO TARGET  ({os.path.basename(target_path)})", fill=(235, 235, 235))
    draw.text((target.width + gap + 4, 6), f"OURS  ({pose})", fill=(235, 235, 235))
    if bead and bead.get("onScreen"):
        # A CROSS, NOT A DOT, and only on our half: the measurement is printed as numbers too, and
        # this is so the eye can find the point the numbers are about.
        x = target.width + gap + bead["x"] * ours.width
        y = 24 + bead["y"] * height
        draw.line([(x - 12, y), (x + 12, y)], fill=(80, 255, 120), width=2)
        draw.line([(x, y - 12), (x, y + 12)], fill=(80, 255, 120), width=2)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    sheet.save(out_path)
    return out_path


def print_landmarks(marks):
    """The three readings the carry pose was solved from, as a percentage of the screen."""
    viewport = marks.get("viewport", {})
    print("[pose] viewport {:.0f}x{:.0f}".format(viewport.get("x", 0), viewport.get("y", 0)))
    for name in ("Bead", "Muzzle", "BarrelLeft", "BarrelRight", "StandingBreech", "Action",
                 "Forend", "Stock", "HandRight", "HandLeft"):
        mark = (marks.get("parts") or {}).get(name)
        if not mark:
            continue # not on this gun: the parts gun has no `StandingBreech`, the old one no `Stock`
        print("[pose]   {}: {:.1f} % across, {:.1f} % down, {:.2f} studs from the eye{}".format(
            name, mark["x"] * 100, mark["y"] * 100, mark["studs"],
            "" if mark.get("onScreen") else "  (OFF SCREEN)"))
    gun = marks.get("gun")
    if gun:
        # THE CLIPPED CORNERS ARE SAID, NOT SILENTLY DROPPED. The carry pose puts the stock behind
        # the camera on purpose, so "3 of 8 corners are clipped" is part of what the picture IS --
        # and a box measured from the five that are left is a box of five corners.
        print("[pose]   gun ({}): {} of 8 corners in the picture, {} clipped (behind the eye or "
              "inside the near plane)".format(
                  gun["piece"], gun.get("cornersInPicture"), gun.get("cornersClipped")))
        if gun.get("box"):
            print("[pose]   gun silhouette {:.1f} % of the width; box {:.1f}-{:.1f} % across, "
                  "{:.1f}-{:.1f} % down".format(
                      gun["silhouetteWidth"] * 100,
                      gun["box"]["left"] * 100, gun["box"]["right"] * 100,
                      gun["box"]["top"] * 100, gun["box"]["bottom"] * 100))
        else:
            print("[pose]   the whole piece is behind the eye, so there is no silhouette to measure")
        if gun["cornersInBottomBand"] > 0:
            print("[pose]   gun width at the bottom edge: {:.1f} % of the screen "
                  "({} of 8 corners in the bottom 15 %)".format(
                      gun["bottomEdgeWidth"] * 100, gun["cornersInBottomBand"]))
        else:
            print("[pose]   gun width at the bottom edge: no corner reaches the bottom 15 % of the "
                  "screen, so there is nothing to measure there")


def run_compare(studio, pose, explicit_target, assets_dir, client="client"):
    if pose not in HOLDS:
        print(f"[pose] compare takes one of: {', '.join(HOLDS)}")
        return 2
    client_id, client_dm, why = running(studio, client)
    if client_id is None:
        print("[pose] " + why)
        return 2
    server_id, server_dm, server_why = running(studio, "server")
    if server_id is None:
        # Play solo in one Studio answers as both, so this only bites a shape nobody has yet.
        print("[pose] " + server_why)
        return 2
    held, problem = read_override(studio, server_id, server_dm)
    if problem:
        print("[pose] " + problem)
        return 2
    restore = {key: value for key, value in held.items() if key != HOLD_KEY}
    wanted = dict(restore)
    wanted[HOLD_KEY] = pose
    _, problem = write_override(studio, server_id, server_dm, wanted)
    if problem:
        print("[pose] could not hold the pose: " + problem)
        return 2
    try:
        # THE HOLD HAS TO REACH THE CLIENT AND BE RENDERED. It is one attribute change on the
        # server, so it is a replication hop plus a frame; a second is many frames at any rate a
        # Studio Play window runs at, and the capture below is what would show it had not landed.
        time.sleep(1.0)
        marks, problem = studio_mcp.json_answer(
            studio, studio_mcp.QUERY_POSE_LANDMARKS, studio_id=client_id, datamodel=client_dm)
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        shot = os.path.join(studio_mcp.SCREENSHOT_DIR, f"{stamp}-pose-{pose}.png")
        saved, text = studio.capture(shot, studio_id=client_id)
        if not saved:
            print(f"[pose] no image came back from Studio: {text}")
            return 1
        print(f"[pose] captured {os.path.relpath(saved, REPO)}")
        if problem:
            print("[pose] could not measure the drawn gun: " + problem)
            marks = {}
        else:
            print_landmarks(marks)
        target = target_for(pose, assets_dir, explicit_target)
        if not target:
            print("[pose] no reference frame: pass --target <image>, or --assets-dir <dir> / set "
                  "DRIVEN_HUNT_ASSETS so the default "
                  f"<assets-dir>/references/{REFERENCE_SET}/TARGET-{pose}.jpg can be found. "
                  "The side-by-side was NOT built.")
            return 1
        if not os.path.exists(target):
            print(f"[pose] the reference frame is not there: {target}")
            return 1
        sheet = os.path.join(studio_mcp.SCREENSHOT_DIR, f"{stamp}-compare-{pose}.png")
        bead = (marks.get("parts") or {}).get("Bead")
        side_by_side(target, saved, sheet, pose, bead)
        print(f"[pose] side by side: {os.path.relpath(sheet, REPO)}")
        print("[pose] LOOK AT IT before claiming what it shows (CLAUDE.md rule 5).")
        return 0
    finally:
        # THE HOLD IS ALWAYS PUT BACK, including on a failure: a session left frozen in one pose is a
        # session whose next screenshot is a lie about what the game does.
        _, restore_problem = write_override(studio, server_id, server_dm, restore)
        if restore_problem:
            print("[pose] WARNING: could not release the hold: " + restore_problem)
            print("[pose]   python tools/pose.py clear")
        else:
            print(f"[pose] released the hold ({len(restore)} override(s) still set)")



# ---------------------------------------------------------------- inspect: the hands from outside

# WHERE THE COPY IS PUT, AND THE CAMERA IS NOT MOVED TO IT -- THE COPY IS MOVED TO THE CAMERA.
# MEASURED, 2026-10-02: the first try parked the clone 240 studs up and asked `screen_capture` for a
# camera position beside it, and every frame came back empty sky. `Camera.update` writes
# `CurrentCamera.CFrame` EVERY FRAME, so a camera the harness moves is put back before the shutter.
# So the subject is placed in front of whatever the player is looking at instead, turned so the lens
# ends up where an outside observer would stand.
#
# EACH VIEW IS (DISTANCE, YAW, PITCH, ALONG): the copy is put `distance` studs in front of the eye,
# turned `yaw` about the eye's up axis and `pitch` about its right, then slid `along` studs down its
# OWN axis so the stretch of gun the hands are on -- the forend at z 0 and the grip at z 1.2 -- is
# what fills the frame rather than the whole 4.4 studs.
INSPECT_VIEWS = {
	# Three-quarter from the shooter's LEFT and FRONT, a little below: the side the left palm is on.
	"left-front": (2.3, 62.0, -22.0, 0.55),
	# From UNDERNEATH: the view that shows a palm, and which way the fingers curl round the wood.
	# RE-AIMED (task 108, round 1): at (2.0, 74, -40, 0.45) the copy's own pitch carried it clean out
	# of the frame and every shot came back as empty terrain. The pitch is the sign that was wrong --
	# it has to roll the gun's UNDERSIDE toward the lens -- and the forward step has to stay small,
	# because it runs along the ROTATED axis.
	"below": (2.2, 74.0, 58.0, 0.12),
	# From the shooter's RIGHT and BEHIND: the only view that shows the right fist on the stock's
	# wrist, which is the half of Karen's complaint the other two cameras cannot see at all -- the
	# stock is between them and it.
	"right-rear": (2.3, -118.0, -16.0, 0.35),
}

# THE LIVE VIEWMODEL IS HIDDEN FOR THE SHOT, and it has to be: it is drawn at the camera every frame,
# so it is always between the lens and the copy. Its own transparency is parked on an attribute,
# because `execute_luau` gets a fresh module copy every call and only an Instance survives between
# them.
INSPECT_PLACE = """
local camera = workspace.CurrentCamera
local made = camera:FindFirstChild("DrivenHuntViewmodel")
if made == nil then return {ok = false, why = "no viewmodel is drawn"} end
local copy = workspace:FindFirstChild("DH_Inspect")
if copy then copy:Destroy() end
copy = made:Clone()
copy.Name = "DH_Inspect"
copy.Parent = workspace
local at = camera.CFrame
	* CFrame.new(0, 0, -%f)
	* CFrame.Angles(0, math.rad(%f), 0)
	* CFrame.Angles(math.rad(%f), 0, 0)
	* CFrame.new(0, 0, -%f)
copy:PivotTo(at)
local hidden = 0
for _, part in ipairs(made:GetDescendants()) do
	if part:IsA("BasePart") then
		if part:GetAttribute("DHInspectWas") == nil then
			part:SetAttribute("DHInspectWas", part.Transparency)
		end
		part.Transparency = 1
		hidden += 1
	end
end
local parts = 0
for _, part in ipairs(copy:GetDescendants()) do
	if part:IsA("BasePart") then
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		-- THE HANDLE IS THE ENVELOPE AND IS INVISIBLE ON THE REAL GUN; on the copy it is the one
		-- thing that says where the gun's own frame is, so it is drawn as a faint box.
		if part.Name == "Handle" then
			part.Transparency = 0.85
		end
		parts += 1
	end
end
return {ok = true, hidden = hidden, parts = parts}
"""

INSPECT_RESTORE = """
local copy = workspace:FindFirstChild("DH_Inspect")
if copy then copy:Destroy() end
local shown = 0
local camera = workspace.CurrentCamera
for _, part in ipairs(camera:GetDescendants()) do
	if part:IsA("BasePart") then
		local was = part:GetAttribute("DHInspectWas")
		if was ~= nil then
			part.Transparency = was
			part:SetAttribute("DHInspectWas", nil)
			shown += 1
		end
	end
end
return {ok = true, shown = shown}
"""


def run_inspect(studio, pose, client="client", views=None):
    """Photograph the drawn viewmodel FROM OUTSIDE, without moving what the player is looking at.

    WHY IT EXISTS (task 108). Karen, 2026-10-02: "hands are bad / left hand is oposit180deg need to
    turn or not sure but broken". From the eye the hands are two dark lumps beside a barrel, so three
    rounds of tuning them by `compare` guessed -- and the Director's own live try (`left.rot.twist
    180`) moved the glove to the wrong side of the gun, which says the problem is the CONVENTION and
    not one number. A convention cannot be read off a frame where the thing is edge-on and occluded.

    THE CAMERA CANNOT SIMPLY BE MOVED, and that is the whole difficulty: the viewmodel is drawn at
    `workspace.CurrentCamera` every frame, so it follows the lens wherever it goes. So this COPIES it
    -- one frozen clone, parked in the sky, which is a static object like any other -- hides the live
    one for the length of the shot, and photographs the copy from three fixed angles. Nothing about the
    pose, the player or the camera's own place is changed: the hold is the same one `compare` uses and
    is always put back.
    """
    if pose not in HOLDS:
        print(f"[pose] inspect takes one of: {', '.join(HOLDS)}")
        return 2
    wanted_views = views or list(INSPECT_VIEWS)
    for name in wanted_views:
        if name not in INSPECT_VIEWS:
            print(f"[pose] no such view: {name} (there are {', '.join(INSPECT_VIEWS)})")
            return 2
    client_id, client_dm, why = running(studio, client)
    if client_id is None:
        print("[pose] " + why)
        return 2
    server_id, server_dm, server_why = running(studio, "server")
    if server_id is None:
        print("[pose] " + server_why)
        return 2
    held, problem = read_override(studio, server_id, server_dm)
    if problem:
        print("[pose] " + problem)
        return 2
    restore = {key: value for key, value in held.items() if key != HOLD_KEY}
    wanted = dict(restore)
    wanted[HOLD_KEY] = pose
    _, problem = write_override(studio, server_id, server_dm, wanted)
    if problem:
        print("[pose] could not hold the pose: " + problem)
        return 2
    saved = []
    try:
        time.sleep(1.0)  # the hold is a replication hop plus a frame, as `compare` says
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        for name in wanted_views:
            answer, problem = studio_mcp.json_answer(
                studio, INSPECT_PLACE % INSPECT_VIEWS[name], studio_id=client_id,
                datamodel=client_dm)
            if problem or not (answer or {}).get("ok"):
                print("[pose] could not copy the viewmodel: "
                      + (problem or (answer or {}).get("why", "?")))
                return 1
            shot = os.path.join(studio_mcp.SCREENSHOT_DIR, f"{stamp}-inspect-{pose}-{name}.png")
            path, text = studio.capture(shot, studio_id=client_id)
            if not path:
                print(f"[pose] no image came back from Studio for {name}: {text}")
                return 1
            saved.append(path)
            print(f"[pose] {name}: {os.path.relpath(path, REPO)} "
                  f"({answer.get('parts')} part(s) copied, {answer.get('hidden')} live hidden)")
        print("[pose] LOOK AT THEM before claiming what they show (CLAUDE.md rule 5).")
        return 0
    finally:
        answer, problem = studio_mcp.json_answer(
            studio, INSPECT_RESTORE, studio_id=client_id, datamodel=client_dm)
        if problem:
            print("[pose] WARNING: could not put the live viewmodel back: " + problem)
            print("[pose]   end the session; nothing written here outlives it")
        _, restore_problem = write_override(studio, server_id, server_dm, restore)
        if restore_problem:
            print("[pose] WARNING: could not release the hold: " + restore_problem)
            print("[pose]   python tools/pose.py clear")
        else:
            print(f"[pose] released the hold ({len(restore)} override(s) still set)")


# ---------------------------------------------------------------- fit: solve a pose from a picture

# THE SIX NUMBERS A POSE PUTS THE GUN AT. The aimed pose is NOT one of them and cannot be: it is
# solved from the gun's own sight (task 90), so it has an eye relief and a cheek angle and no x/y/z.
FIT_VARS = ("gun.pos.x", "gun.pos.y", "gun.pos.z", "gun.rot.x", "gun.rot.y", "gun.rot.z")
FIT_BOUNDS = {"posStuds": 1.5, "rotDeg": 60.0}
# A mark the candidate does not draw at all, or draws behind the eye, is not "zero error": it is the
# worst thing a candidate can do, and a search that scored it as 0 would walk straight into it.
FIT_MISSING = 2.0
# ...AND THE FEWEST MARKS THAT CAN PIN SIX NUMBERS. See `read_landmark_file`.
FIT_MIN_MARKS = 3
# THE EDGES A MARK CAN LEAVE THE PICTURE BY (task 104). "Off screen" alone cost task 103 its fit.
FIT_EDGES = ("bottom", "top", "left", "right")
# A STUD OF DEPTH ERROR COUNTS AS A TENTH OF THE SCREEN, so one weight scale covers positions, depth
# and angle and the search needs no second tolerance.
FIT_STUD = 0.1


def read_landmark_file(path):
    """The Director's hand-written target, as (spec, problem).

    THE FORMAT IS WHAT A PERSON CAN READ OFF A REFERENCE FRAME with a ruler and nothing else:

        {
          "note":  "TARGET-reload-open.jpg, read by hand",
          "marks": {
            "StandingBreech": { "x": 0.55, "y": 0.70, "studs": 0.9, "weight": 2 },
            "Action":         { "x": 0.68, "y": 0.84, "nearer": "StandingBreech" },
            "Forend":         { "x": 0.50, "y": 0.93, "farther": "StandingBreech" }
          },
          "offScreen": { "Muzzle": "bottom" },
          "directions": [ { "from": "StandingBreech", "to": "Muzzle", "deg": 105 } ],
          "bounds": { "posStuds": 1.5, "rotDeg": 90 }
        }

    `x` and `y` are FRACTIONS of the screen (0 = left/top, 1 = right/bottom), which is exactly what
    `pose.py compare` already prints for every landmark, so a reading and a target are the same unit.

    THE OTHER THREE ARE TASK 104, AND TASK 103 IS WHY THEY EXIST. A fit against four x/y marks and a
    bare `offScreen` halved the screen error and still drew a gun lying flat across the frame, because
    the thing being copied -- barrels pointing DOWN-AWAY -- is almost entirely depth and edge, and the
    format could say neither:

      * `studs` is the distance from the eye. A flat picture cannot give it, so there is usually one.
      * `nearer` / `farther` name ANOTHER mark, and that a person CAN read off a picture: in a
        broken-open gun the stock is nearer than the breech and the forend is farther. An ORDER needs
        no ruler, and a chain of them pins the recession that one `studs` cannot.
      * `offScreen` may be a list (any edge, as before) or an OBJECT naming the edge --
        `bottom`, `top`, `left`, `right`. "The muzzle is off the bottom" and "the muzzle is off the
        left" are different guns, and task 103's fit chose the wrong one.
      * `directions` are the SCREEN ANGLE from one mark to another, in degrees, measured the way a
        screen is: 0 points right, 90 straight DOWN, 180 left. The barrel axis is one line on the
        picture and this is how to say which way it runs.
    """
    try:
        with open(path, encoding="utf-8") as handle:
            spec = json.load(handle)
    except (OSError, json.JSONDecodeError) as why:
        return None, f"could not read the landmarks file: {why}"
    if not isinstance(spec, dict) or not isinstance(spec.get("marks"), dict) or not spec["marks"]:
        return None, 'the landmarks file needs a non-empty "marks" object'
    for name, mark in spec["marks"].items():
        if not isinstance(mark, dict) or not isinstance(mark.get("x"), (int, float)) \
                or not isinstance(mark.get("y"), (int, float)):
            return None, f"marks.{name} needs numeric x and y (fractions of the screen)"
    off = spec.get("offScreen", [])
    if isinstance(off, dict):
        for name, edge in off.items():
            if edge not in FIT_EDGES:
                return None, (f"offScreen.{name} = {edge!r} is not an edge; use one of "
                              f"{', '.join(sorted(FIT_EDGES))}")
    elif not isinstance(off, list):
        return None, '"offScreen" must be a list of names, or an object of name -> edge'
    for entry in spec.get("directions", []):
        if not isinstance(entry, dict) or entry.get("from") not in spec["marks"] \
                or not isinstance(entry.get("deg"), (int, float)):
            return None, ('each entry in "directions" needs "from" (a mark), "to" (any landmark) '
                          'and "deg", the screen angle: 0 right, 90 down, 180 left')
    for name, mark in spec["marks"].items():
        for key in ("nearer", "farther"):
            other = mark.get(key)
            if other is not None and other == name:
                return None, f"marks.{name}.{key} names itself"
    # AT LEAST THREE MARKS THAT ARE IN THE PICTURE, and task 102 is why (TASKS.md 102a(b)). A fit was
    # run against TWO marks plus one off-screen constraint; the search did exactly what it was asked
    # and answered with the gun lying FLAT across the middle of the frame, breech away from the
    # camera. Two points and an inequality do not determine six numbers -- and a solver that answers
    # anyway is worse than one that refuses, because the answer LOOKS like a result.
    if len(spec["marks"]) < FIT_MIN_MARKS:
        return None, (f"{len(spec['marks'])} mark(s) cannot pin a pose: a fit searches six numbers "
                      f"and needs at least {FIT_MIN_MARKS}, each a DIFFERENT point along the gun "
                      "(task 102 answered two marks with the gun lying flat across the frame). "
                      "Names in \"offScreen\" do not count: they are an inequality, not a position.")
    return spec, ""


def fit_error(answer, spec):
    """How wrong one candidate is, as (error, one line about it).

    ROOT MEAN SQUARE IN SCREEN FRACTIONS, so the number means something a person can check: 0.05 is
    five per cent of the screen out, averaged over everything asked for. Depth, the depth ORDER, the
    edge a mark leaves by and the angle between two marks are all folded in as fractions too -- a
    stud counts as `FIT_STUD` of the screen and a half-turn as the whole of it -- so one weight scale
    covers them all and the search needs no second tolerance.
    """
    parts = (answer or {}).get("parts") or {}
    total, weight_sum, worst, worst_name = 0.0, 0.0, 0.0, "-"

    def add(weight, term, label):
        nonlocal total, weight_sum, worst, worst_name
        total += weight * term
        weight_sum += weight
        if term > worst:
            worst, worst_name = term, label

    def drawn(name):
        """The reading for a landmark, or None when it is not drawn or is behind the eye.

        BEHIND THE EYE IS NOT A POSITION. WorldToViewportPoint extrapolates a point behind the camera
        to a screen position anyway (measured twice, 2026-10-01, and it is why the gun once read as
        22,425 % of the screen wide), so depth is what says it is in the picture at all."""
        got = parts.get(name)
        return got if got and got["studs"] > 0.1 else None

    for name, mark in spec["marks"].items():
        weight = float(mark.get("weight", 1.0))
        got = parts.get(name)
        if not got:
            add(weight, FIT_MISSING ** 2, name + " (not drawn)")
            continue
        dx = got["x"] - float(mark["x"])
        dy = got["y"] - float(mark["y"])
        term = dx * dx + dy * dy
        if mark.get("studs") is not None:
            term += ((got["studs"] - float(mark["studs"])) * FIT_STUD) ** 2
        if got["studs"] <= 0.1:
            term += FIT_MISSING ** 2
        add(weight, term, name)

    # THE DEPTH ORDER (task 104). A picture cannot give a distance but a person can always read an
    # ORDER off it -- on a broken-open gun the stock is nearer than the breech and the forend is
    # farther -- and a chain of orders pins the recession that one `studs` reading cannot. It is a
    # HINGE: being on the right side of the other mark costs nothing, and being on the wrong side
    # costs by how far, so the search has a gradient to follow back.
    for name, mark in spec["marks"].items():
        for key, wanted_nearer in (("nearer", True), ("farther", False)):
            other = mark.get(key)
            if other is None:
                continue
            here, there = drawn(name), drawn(other)
            if here is None or there is None:
                add(1.0, FIT_MISSING ** 2, f"{name} {key} {other} (one of them is not in the picture)")
                continue
            gap = here["studs"] - there["studs"]
            violation = max(0.0, gap if wanted_nearer else -gap)
            add(1.0, (violation * FIT_STUD) ** 2, f"{name} {key} {other}")

    # OFF SCREEN, AND SINCE TASK 104 OFF WHICH EDGE. A list is still "any edge"; an object is
    # name -> edge. "The muzzle is off the bottom" and "off the left" are different guns, and the
    # fit that had only the first of those drew the second.
    off = spec.get("offScreen", [])
    wanted_edges = off if isinstance(off, dict) else {name: None for name in off}
    for name, edge in wanted_edges.items():
        got = drawn(name)
        if got is None:
            # Not drawn, or behind the eye: it is not in the picture, which is what was asked.
            add(1.0, 0.0, name + " (off screen)")
            continue
        # ON SCREEN WHEN IT SHOULD NOT BE: penalised by how far INSIDE the frame it is, so the search
        # has a gradient to follow out rather than a cliff it cannot see over.
        inside = min(got["x"], 1 - got["x"], got["y"], 1 - got["y"])
        if inside >= 0:
            # THE STEP IS DELIBERATE. A mark in the middle of the picture when it should be out of it
            # must cost MORE than one that is out of the wrong edge -- otherwise the search prefers
            # the frame it can see, which is how task 103's muzzle ended up on screen. `inside` alone
            # could not say that: a wrong-edge excursion already scores up to 0.5, and a dead-centre
            # mark scored 0.25. So the whole constraint carries a floor.
            add(1.0, (inside + 0.25) ** 2, name + " (should be off screen)")
            continue
        if edge is None:
            add(1.0, 0.0, name + " (off screen)")
            continue
        # OUT, BUT WHICH WAY? The excursion past each edge; the one it is really past is the biggest.
        past = {"left": -got["x"], "right": got["x"] - 1, "top": -got["y"], "bottom": got["y"] - 1}
        actual = max(past, key=lambda key: past[key])
        # Wrong edge costs the excursion it has the wrong way PLUS what it is missing the right way,
        # both bounded, so a gun pointing out of the left edge is pulled toward the bottom one.
        term = 0.0 if actual == edge else min(1.0, past[actual]) ** 2 + min(1.0, -past[edge]) ** 2
        add(1.0, term, f"{name} (off the {actual}, wanted {edge})")

    # THE SCREEN ANGLE BETWEEN TWO MARKS (task 104): the one thing that says which way the barrels
    # RUN, which no pair of positions says when both of them are uncertain. Measured the way a screen
    # is -- 0 right, 90 straight down -- and scored as a fraction of a half-turn, so 180 degrees out
    # is a whole screen of error.
    for entry in spec.get("directions", []):
        here, there = drawn(entry["from"]), drawn(entry["to"])
        label = f"{entry['from']}->{entry['to']} angle"
        if here is None or there is None:
            add(float(entry.get("weight", 1.0)), FIT_MISSING ** 2, label + " (not in the picture)")
            continue
        angle = math.degrees(math.atan2(there["y"] - here["y"], there["x"] - here["x"])) % 360
        off_by = abs((angle - float(entry["deg"]) + 180) % 360 - 180)
        add(float(entry.get("weight", 1.0)), (off_by / 180.0) ** 2, label)

    error = math.sqrt(total / max(weight_sum, 1e-9))
    return error, f"worst: {worst_name}"


def search(start, bounds, evaluate, evals):
    """A bounded compass search -> (best point, best score, how many evaluations it used).

    PATTERN SEARCH AND NOT A GRADIENT ONE, because there is no gradient to have: each evaluation is a
    round trip into a running Studio and the objective is a rendered frame. A compass search needs
    only comparisons, is deterministic (so two runs on the same picture give the same answer), and
    cannot step outside the bounds -- which is what keeps a solver from "solving" the reload by
    putting the gun 40 studs behind the player.

    Pattern: Hooke-Jeeves / coordinate search, the standard derivative-free method for a handful of
    variables and an expensive objective (Kolda, Lewis & Torczon, "Optimization by direct search",
    SIAM Review 45(3), 2003).
    """
    point = list(start)
    step = [max(1e-9, b / 3.0) for b in bounds]
    best, used = evaluate(point), 1
    while used < evals and max(step) > 1e-4:
        improved = False
        for index in range(len(point)):
            for direction in (1, -1):
                if used >= evals:
                    break
                trial = list(point)
                low, high = start[index] - bounds[index], start[index] + bounds[index]
                trial[index] = min(high, max(low, point[index] + direction * step[index]))
                if trial[index] == point[index]:
                    continue
                score = evaluate(trial)
                used += 1
                if score < best:
                    point, best, improved = trial, score, True
                    break
        if not improved:
            step = [value / 2.0 for value in step]
    return point, best, used


def run_fit(studio, prefix, landmarks_path, evals, client, assets_dir, explicit_target, settle):
    """`pose.py fit <pose> --landmarks <file>`: search the gun's six numbers to match a picture."""
    data = read_poses()
    known = paths_of(data)
    for leaf in FIT_VARS:
        if f"{prefix}.{leaf}" not in known:
            print(f"[pose] {prefix} has no {leaf}: fit works on a pose with a `gun` block "
                  "(carry, reload, newGun.carry, newGun.reload). The aimed pose is solved from the "
                  "gun's own sight and has no x/y/z to search.")
            return 2
    hold = prefix.split(".")[-1]
    if hold not in HOLDS:
        print(f"[pose] {prefix} does not end in one of: {', '.join(HOLDS)}")
        return 2
    spec, problem = read_landmark_file(landmarks_path)
    if problem:
        print("[pose] " + problem)
        return 2

    client_id, client_dm, why = running(studio, client)
    if client_id is None:
        print("[pose] " + why)
        return 2
    server_id, server_dm, server_why = running(studio, "server")
    if server_id is None:
        print("[pose] " + server_why)
        return 2
    held, problem = read_override(studio, server_id, server_dm)
    if problem:
        print("[pose] " + problem)
        return 2
    restore = {key: value for key, value in held.items()
               if key not in (HOLD_KEY, SERIAL_KEY)}
    effective, _ = apply_overrides(data, restore)
    start = [paths_of(effective)[f"{prefix}.{leaf}"] for leaf in FIT_VARS]
    limits = dict(FIT_BOUNDS)
    limits.update(spec.get("bounds") or {})
    bounds = [float(limits["posStuds"])] * 3 + [float(limits["rotDeg"])] * 3

    serial = [0]
    trail = []

    def evaluate(point):
        serial[0] += 1
        wanted = dict(restore)
        for leaf, value in zip(FIT_VARS, point):
            wanted[f"{prefix}.{leaf}"] = round(float(value), 4)
        wanted[HOLD_KEY] = hold
        wanted[SERIAL_KEY] = serial[0]
        _, problem = write_override(studio, server_id, server_dm, wanted)
        if problem:
            raise RuntimeError("could not write the candidate: " + problem)
        # WAIT FOR THE FRAME THAT IS ABOUT THIS CANDIDATE. The write lands on the server and
        # replicates; reading before it arrives measures the PREVIOUS candidate, and a search over a
        # blurred objective converges on nothing. The client answers with the override text it can
        # see, so the tool can tell the two apart instead of guessing a sleep.
        answer = {}
        for _attempt in range(40):
            time.sleep(settle)
            answer, problem = studio_mcp.json_answer(
                studio, studio_mcp.QUERY_POSE_LANDMARKS, studio_id=client_id, datamodel=client_dm)
            if problem:
                raise RuntimeError("could not measure the drawn gun: " + problem)
            seen = answer.get("override") or ""
            try:
                if json.loads(seen).get(SERIAL_KEY) == serial[0]:
                    break
            except (json.JSONDecodeError, AttributeError, TypeError):
                continue
        else:
            raise RuntimeError("the session never showed the candidate this tool wrote")
        # ...and one more reading, which is at least a round trip of frames after the client first
        # reported it had the candidate.
        answer, problem = studio_mcp.json_answer(
            studio, studio_mcp.QUERY_POSE_LANDMARKS, studio_id=client_id, datamodel=client_dm)
        if problem:
            raise RuntimeError("could not measure the drawn gun: " + problem)
        score, worst = fit_error(answer, spec)
        trail.append((score, worst))
        return score

    print(f"[pose] fitting {prefix} to {os.path.basename(landmarks_path)}: "
          f"{len(spec['marks'])} mark(s), {len(spec.get('offScreen', []))} off-screen, "
          f"up to {evals} evaluations")
    try:
        point, best, used = search(start, bounds, evaluate, evals)
    except RuntimeError as problem:
        print("[pose] " + str(problem))
        write_override(studio, server_id, server_dm, restore)
        return 1
    first = trail[0][0] if trail else float("nan")
    print(f"[pose] {used} evaluation(s): error {first:.4f} -> {best:.4f} "
          f"(screen fractions, RMS over the marks); {trail[-1][1]}")
    print("[pose] the pose it found:")
    for leaf, was, now in zip(FIT_VARS, start, point):
        print(f"[pose]   python tools/pose.py set {prefix}.{leaf} {round(now, 4)}"
              f"      (was {round(was, 4)})")
    print("[pose] it is SET in the session. `python tools/pose.py save` writes it into poses.json; "
          "`python tools/pose.py clear` throws it away.")
    return run_compare(studio, hold, explicit_target, assets_dir, client)


# ---------------------------------------------------------------- the session itself

def run_play(studio, wanting):
    """`pose.py play` / `pose.py stop`: start or end a SOLO Play session, from Edit.

    WHY IT IS HERE AND NOT A HUMAN'S KEYPRESS (task 103, measured). `studio-key.ps1 F7` starts
    Studio's "Server and Clients" session, which is what the two-player harness needs -- and its two
    CLIENT processes never registered with StudioMCP: `studios` listed the Edit window and the Play
    SERVER only, through three attempts over about ninety seconds. The viewmodel lives on a client,
    so there was nothing to photograph. A SOLO session puts both DataModels in the one process that
    is already connected, which is how the harness has always run `test`, and that one answers.

    IT IS THE SAME CALL THE HARNESS MAKES -- `Studio.set_play` -- so there is no second way to start
    a session in this repo, and nothing here sends Luau.

    EDIT IN, EDIT OUT. `play` is refused unless Studio is in Edit, so it can never be the thing that
    restarts a session the Director is already tuning; `stop` is refused unless one is running, so a
    stray `stop` cannot be the reason a harness run found no Studio.
    """
    try:
        state = studio.mode()
    except RuntimeError as why:
        print("[pose] " + str(why))
        return 2
    running_now = state != "Edit"
    if wanting and running_now:
        print(f"[pose] a session is already running ({state}); `pose.py stop` ends it")
        return 2
    if not wanting and not running_now:
        print("[pose] Studio is in Edit: there is no session to stop")
        return 2
    answer = studio.set_play(wanting)
    print(f"[pose] {'started' if wanting else 'stopped'} a solo Play session ({answer})")
    if wanting:
        print("[pose] `pose.py compare <pose>` and `pose.py fit` can reach it now; end it with "
              "`pose.py stop`, then `pose.py clear` and `flags.py clear` before any harness run.")
    return 0


# ---------------------------------------------------------------- the commands

def main(argv):
    args = list(argv[1:])
    if args[:1] in (["-h"], ["--help"], ["help"]):
        print(__doc__)
        return 0
    if args[:1] == ["selftest"]:
        return selftest()

    assets_dir = os.environ.get("DRIVEN_HUNT_ASSETS")
    explicit_target = None
    landmarks = None
    evals = 240
    settle = 0.05
    # WHICH PLAYER TO PHOTOGRAPH. `studio_for_role` already understands "client:Player1"; this is
    # the way to say it, and it exists because a two-player session makes one of them the DRIVER,
    # who carries no gun at all -- so the default (the first client that answered) photographs an
    # empty screen half the time. Measured 2026-10-02 on the task 99 break-open capture.
    client = "client"
    rest = []
    index = 0
    while index < len(args):
        if args[index] == "--assets-dir" and index + 1 < len(args):
            assets_dir = args[index + 1]
            index += 2
        elif args[index] == "--target" and index + 1 < len(args):
            explicit_target = args[index + 1]
            index += 2
        elif args[index] == "--client" and index + 1 < len(args):
            client = "client:" + args[index + 1]
            index += 2
        elif args[index] == "--landmarks" and index + 1 < len(args):
            landmarks = args[index + 1]
            index += 2
        elif args[index] == "--evals" and index + 1 < len(args):
            evals = max(2, int(args[index + 1]))
            index += 2
        elif args[index] == "--settle" and index + 1 < len(args):
            settle = max(0.0, float(args[index + 1]))
            index += 2
        else:
            rest.append(args[index])
            index += 1
    args = rest

    action = args[0] if args else "show"
    if action not in ("show", "set", "save", "clear", "compare", "inspect", "fit", "play", "stop"):
        print(__doc__)
        return 2

    data = read_poses()
    studio = studio_mcp.Studio()
    try:
        if action == "compare":
            if len(args) != 2:
                print("[pose] usage: pose.py compare <carry|raise|aim|reload> [--target <image>] "
                      "[--client <name>]")
                return 2
            return run_compare(studio, args[1], explicit_target, assets_dir, client)
        if action == "inspect":
            if not 2 <= len(args) <= 3:
                print("[pose] usage: pose.py inspect <carry|raise|aim|reload> "
                      f"[{'|'.join(INSPECT_VIEWS)}] [--client <name>]")
                return 2
            return run_inspect(studio, args[1], client, [args[2]] if len(args) == 3 else None)
        if action in ("play", "stop"):
            if len(args) != 1:
                print(f"[pose] usage: pose.py {action}")
                return 2
            return run_play(studio, action == "play")
        if action == "fit":
            if len(args) != 2 or not landmarks:
                print("[pose] usage: pose.py fit <pose> --landmarks <file> [--evals N] "
                      "[--settle S] [--target <image>] [--client <name>]")
                return 2
            return run_fit(studio, args[1], landmarks, evals, client, assets_dir,
                           explicit_target, settle)

        # Everything else reads, and may write, the SERVER of the running session: an attribute set
        # there replicates to every client, so a two-player test tunes both guns at once.
        server_id, datamodel, why = running(studio, "server")
        if action == "clear":
            # CLEAR IS THE ONE COMMAND THAT ALSO WORKS WITH NO SESSION, because the thing the
            # harness refuses to start over is an override in the EDIT place -- and that is exactly
            # the case where there is no Play session to talk to.
            cleared = []
            if server_id is not None:
                _, problem = write_override(studio, server_id, datamodel, {})
                cleared.append("the running session" if not problem else f"session FAILED: {problem}")
            edit_id, edit_why = studio_mcp.studio_for_role(studio, "edit")
            if edit_id is None:
                cleared.append(f"edit place SKIPPED: {edit_why}")
            else:
                _, problem = write_override(studio, edit_id, "Edit", {})
                if not problem:
                    cleared.append("the edit place")
                elif "not available in Play mode" in problem:
                    # NOT A FAILURE, and it is the usual case: Studio does not expose the Edit
                    # DataModel while a Play session runs, and the override being cleared was never
                    # in the edit place to begin with (`set` refuses Edit mode outright).
                    cleared.append("edit place SKIPPED: it is not reachable while Play runs; "
                                   "run `pose.py clear` again after the session ends")
                else:
                    cleared.append(f"edit place FAILED: {problem}")
            print("[pose] cleared: " + ", ".join(cleared))
            return 0 if not any("FAILED" in part for part in cleared) else 1

        if server_id is None:
            if action in ("set",):
                print("[pose] " + why)
                return 2
            # `show` and `save` are still useful with no session: they are about the file.
            print("[pose] no running session (" + why + "), so these are the file's own values")
            overrides = {}
        else:
            overrides, problem = read_override(studio, server_id, datamodel)
            if problem:
                print("[pose] " + problem)
                return 2

        if action == "show":
            return print_table(data, overrides, args[1] if len(args) > 1 else None)

        if action == "set":
            if len(args) != 3:
                print("[pose] usage: pose.py set <path> <value>   e.g. set aim.eyeReliefStuds 4.2")
                return 2
            path, raw = args[1], args[2]
            try:
                value = float(raw)
            except ValueError:
                print(f"[pose] {raw!r} is not a number")
                return 2
            known = paths_of(data)
            if path not in known:
                near = sorted(p for p in known if path.split(".")[0] == p.split(".")[0])
                print(f"[pose] {path} is not a pose number. "
                      + (f"Paths under {path.split('.')[0]!r}: " + ", ".join(near[:12]) if near
                         else "Run `pose.py show` for the list."))
                return 2
            wanted = dict(overrides)
            wanted[path] = value
            _, problem = write_override(studio, server_id, datamodel, wanted)
            if problem:
                print("[pose] " + problem)
                return 2
            print(f"[pose] {path} = {value:g} (was {known[path]:g} in the file). The git tree is "
                  "untouched; the gun changes on the next frame.")
            print("[pose]   python tools/pose.py save    to keep it")
            print("[pose]   python tools/pose.py clear   to drop it (and before the next harness run)")
            return 0

        # save
        if not overrides:
            print("[pose] nothing is overridden, so there is nothing to save")
            return 0
        effective, problems = apply_overrides(data, overrides)
        if problems:
            for problem in problems:
                print("[pose] REFUSED: " + problem)
            print("[pose] nothing was written: a half-saved pose is a pose nobody chose")
            return 2
        write_poses(effective)
        changed = [p for p, v in paths_of(effective).items() if abs(v - paths_of(data)[p]) > 1e-12]
        _, problem = write_override(studio, server_id, datamodel, {})
        print(f"[pose] wrote {os.path.relpath(POSES_FILE, REPO)}: "
              + ", ".join(f"{p} = {paths_of(effective)[p]:g}" for p in sorted(changed)))
        print("[pose] overrides cleared" if not problem else "[pose] overrides NOT cleared: " + problem)
        print("[pose] it is a src/ change now: it needs `test`, `test2` and a review like any other.")
        return 0
    finally:
        studio.close()


# ---------------------------------------------------------------- selftest (no Studio, CI runs it)

def selftest():
    """Prove the merge, the path rule and the file round trip, with no Studio and no Pillow.

    These are the rules that decide what a tuning session can do, and two of them are duplicated in
    Luau (`Viewmodel.paths`, `Viewmodel.merge`), so they are pinned HERE against the shipped file --
    which is the one thing both sides agree about."""
    failures = []

    def ok(name, condition, detail=""):
        if not condition:
            failures.append(f"{name}{': ' + detail if detail else ''}")

    data = read_poses()
    paths = paths_of(data)

    # 1. THE SHIPPED FILE'S OWN SHAPE. If a pose stops being reachable by path, live tuning silently
    # stops covering it -- which is the whole feature going missing without a single failure.
    for wanted in ("carry.gun.pos.x", "carry.gun.rot.y", "carry.right.rot.twist", "carry.left.pos.z",
                   "aim.eyeReliefStuds", "aim.cheekDeg", "aim.right.rot.yaw",
                   "raise.raiseSeconds", "raise.lowerSeconds",
                   "fire.gunPitchDeg", "fire.frequencyHz", "fire.maxCamPitchDeg",
                   "reload.openSeconds", "reload.openDeg", "reload.hingeStuds.z",
                   "reload.gun.rot.z", "reload.shells.feedFromStuds"):
        ok(f"{wanted} is a tunable path", wanted in paths, "missing from poses.json")
    # THE SECOND GUN'S OWN SET (task 99): the Director tunes it live exactly like the first one, so
    # every one of its paths has to be reachable or the whole point of the flag is lost.
    for wanted in ("newGun.carry.gun.pos.x", "newGun.carry.left.pos.z", "newGun.aim.eyeReliefStuds",
                   "newGun.reload.gun.rot.y", "newGun.aim.right.rot.twist"):
        ok(f"{wanted} is a tunable path", wanted in paths, "missing from poses.json")
    ok("the two guns are tuned apart", data["newGun"]["carry"]["left"]["pos"] != data["carry"]["left"]["pos"],
       "the new gun's hands must sit on the new gun's own wood")
    ok("version is NOT tunable", "version" not in paths, "version must not be settable")
    ok("raise.easing is NOT tunable", "raise.easing" not in paths, "a string is not a number")
    ok("the file ships with no mid keyframes", data["raise"]["keyframes"] == [],
       repr(data["raise"]["keyframes"]))

    # 2. A GOOD OVERRIDE APPLIES, and nothing else moves.
    effective, problems = apply_overrides(data, {"aim.eyeReliefStuds": 4.25})
    ok("a good override applies", problems == [] and effective["aim"]["eyeReliefStuds"] == 4.25,
       f"{problems} / {effective['aim']['eyeReliefStuds']}")
    untouched = [p for p, v in paths_of(effective).items()
                 if p != "aim.eyeReliefStuds" and abs(v - paths[p]) > 1e-12]
    ok("it moves exactly one number", untouched == [], repr(untouched))
    ok("the source data is not mutated", data["aim"]["eyeReliefStuds"] == paths["aim.eyeReliefStuds"],
       repr(data["aim"]["eyeReliefStuds"]))

    # 3. EVERY REFUSAL. A typo must leave the gun where it was: the Director would otherwise be
    # looking at an unchanged picture wondering which of the two of them was wrong.
    for bad, why in (({"aim.cheeckDeg": 1.0}, "a typo'd path"),
                     ({"aim": 1.0}, "a path that is a whole pose"),
                     ({"raise.easing": 1.0}, "a path whose value is a string"),
                     ({"version": 2}, "version"),
                     ({"aim.eyeReliefStuds": "4.2"}, "a string value"),
                     ({"aim.eyeReliefStuds": True}, "a boolean value")):
        _, problems = apply_overrides(data, bad)
        ok(f"{why} is refused", len(problems) == 1, repr(problems))
    ok("the hold key is not treated as a path", apply_overrides(data, {HOLD_KEY: "aim"})[1] == [],
       repr(apply_overrides(data, {HOLD_KEY: "aim"})[1]))

    # 4. A MID KEYFRAME IS REACHABLE BY PATH, which is what makes the raise tunable at all once the
    # Director adds one. Indexed from 1, like Luau.
    with_frame = json.loads(json.dumps(data))
    with_frame["raise"]["keyframes"] = [
        {"t": 0.5, "gun": {"pos": {"x": 0.0, "y": 0.0, "z": -1.0}, "rot": {"x": 0.0, "y": 0.0, "z": 0.0}}}
    ]
    framed = paths_of(with_frame)
    ok("a mid keyframe's time is a path", "raise.keyframes.1.t" in framed, repr(sorted(framed)[:4]))
    ok("a mid keyframe's gun position is a path", "raise.keyframes.1.gun.pos.z" in framed)
    moved, problems = apply_overrides(with_frame, {"raise.keyframes.1.gun.pos.z": -2.0})
    ok("a mid keyframe can be overridden",
       problems == [] and moved["raise"]["keyframes"][0]["gun"]["pos"]["z"] == -2.0,
       f"{problems} / {moved['raise']['keyframes'][0]['gun']['pos']['z']}")

    # 5. THE FILE ROUND TRIP IS IDEMPOTENT, which is what makes `save` a one-line diff rather than a
    # reordered file nobody can review.
    import io as _io
    buffer = _io.StringIO()
    buffer.write(json.dumps(data, indent=2, sort_keys=True) + "\n")
    with open(POSES_FILE, encoding="utf-8", newline="") as handle:
        on_disk = handle.read()
    ok("poses.json is already in `save`'s own format", buffer.getvalue() == on_disk,
       "re-saving it would rewrite the whole file")

    # 6. NEITHER CALL RAISES ON WHAT STUDIO SAID. MEASURED, on the first tuning session: `clear`
    # cleared the running session and then died with a traceback on "Edit datamodel is not available
    # in Play mode" -- Studio does not expose the Edit DataModel while a Play session runs, and
    # `clear` deliberately reaches for both. A tool that half-succeeds and then crashes is worse than
    # one that refuses, so a Studio fault is an ordinary problem string here.
    class RaisingStudio:
        def __init__(self, why):
            self.why = why
            self.default_studio_id = None

        def query(self, datamodel, code, studio_id=None):
            raise RuntimeError(self.why)

    PLAY = "execute_luau: Edit datamodel is not available in Play mode"
    got, problem = read_override(RaisingStudio(PLAY), "X", "Edit")
    ok("read_override reports a Studio fault instead of raising", got == {} and PLAY in problem,
       f"{got!r} / {problem!r}")
    text, problem = write_override(RaisingStudio(PLAY), "X", "Edit", {})
    ok("write_override reports a Studio fault instead of raising", text == "" and PLAY in problem,
       f"{text!r} / {problem!r}")

    # 7. THE TARGET PATH IS BUILT, NEVER BAKED IN. The reference frames are third-party and outside
    # the repo (CLAUDE.md, "Public repository": no local absolute path in a committed file).
    ok("no reference path without an assets dir", target_for("aim", None) is None)
    built = target_for("aim", os.path.join("X", "Y"))
    ok("the default target is the pose's own frame",
       built.endswith(os.path.join("references", REFERENCE_SET, "TARGET-aim.jpg")), repr(built))
    ok("--target wins", target_for("aim", "X", "given.png") == "given.png")

    # 5. THE SOLVER (task 102), driven with NO STUDIO at all -- which is the only way a search can be
    # tested, because what it has to be right about is the SEARCH and not the engine. A synthetic
    # projector stands in for the session: a known pose, a known answer, and the question is whether
    # the compass search walks from a wrong start to it inside its budget and its bounds.
    truth = [0.4, -0.3, -1.6, 12.0, -20.0, 5.0]

    def synthetic(point):
        # Each mark's screen position is some smooth function of the six numbers; what matters for
        # the search is that the objective is a bowl with its floor at `truth`.
        return math.sqrt(sum(((a - b) * (0.4 if index < 3 else 0.01)) ** 2
                             for index, (a, b) in enumerate(zip(point, truth))) / 6.0)

    start = [0.0, 0.0, -1.0, 0.0, 0.0, 0.0]
    found, best, used = search(start, [1.5] * 3 + [60.0] * 3, synthetic, 240)
    ok("the search finds a pose it cannot see", best < 0.004, f"error {best:.5f} after {used}")
    ok("the search lands on the right numbers",
       max(abs(a - b) for a, b in zip(found, truth[:3])) < 0.05, repr([round(v, 3) for v in found]))
    ok("the search stays inside its budget", used <= 240, str(used))
    # BOUNDED MEANS BOUNDED: with the truth outside the box, the answer is the box's own edge and not
    # a gun forty studs behind the player.
    far = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    boxed, _, _ = search(far, [0.2] * 3 + [5.0] * 3, synthetic, 240)
    ok("the search cannot leave its bounds",
       all(abs(value - origin) <= limit + 1e-9
           for value, origin, limit in zip(boxed, far, [0.2] * 3 + [5.0] * 3)),
       repr([round(v, 3) for v in boxed]))

    # ...and the scoring, which is what the search is minimising.
    spec = {"marks": {"StandingBreech": {"x": 0.5, "y": 0.5}}, "offScreen": ["Muzzle"]}
    exact = {"parts": {"StandingBreech": {"x": 0.5, "y": 0.5, "studs": 1.0, "onScreen": True}}}
    error, _ = fit_error(exact, spec)
    ok("a landmark that is where it should be scores 0", error < 1e-9, f"{error}")
    missing = {"parts": {}}
    ok("a landmark that is not drawn is the worst case", fit_error(missing, spec)[0] > 1.0,
       f"{fit_error(missing, spec)[0]}")
    behind = {"parts": {"StandingBreech": {"x": 0.5, "y": 0.5, "studs": -3.0, "onScreen": False}}}
    ok("a landmark behind the eye is not scored as a hit", fit_error(behind, spec)[0] > 1.0,
       f"{fit_error(behind, spec)[0]}")
    intruder = dict(exact)
    intruder = {"parts": dict(exact["parts"],
                              Muzzle={"x": 0.5, "y": 0.5, "studs": 2.0, "onScreen": True})}
    ok("a mark that should be off screen is penalised for being in the middle",
       fit_error(intruder, spec)[0] > error, f"{fit_error(intruder, spec)[0]} vs {error}")
    bad, problem = read_landmark_file(os.path.join(REPO, "tools", "pose.py"))
    ok("a landmarks file that is not JSON is refused", bad is None and problem != "")
    # TOO FEW MARKS IS REFUSED, NOT ANSWERED (task 103, from 102a(b)). Written to a real file,
    # because that is the path the Director's own file takes.
    with tempfile.TemporaryDirectory() as folder:
        thin = os.path.join(folder, "thin.json")
        with open(thin, "w", encoding="utf-8") as handle:
            json.dump({"marks": {"StandingBreech": {"x": 0.5, "y": 0.5},
                                 "Action": {"x": 0.5, "y": 0.6}},
                       "offScreen": ["Muzzle", "Stock", "Forend"]}, handle)
        thin_spec, thin_problem = read_landmark_file(thin)
        ok("two marks cannot pin six numbers, and are refused",
           thin_spec is None and "cannot pin a pose" in thin_problem, repr(thin_problem))
        enough = os.path.join(folder, "enough.json")
        with open(enough, "w", encoding="utf-8") as handle:
            json.dump({"marks": {"StandingBreech": {"x": 0.5, "y": 0.5},
                                 "Action": {"x": 0.5, "y": 0.6},
                                 "Stock": {"x": 0.6, "y": 0.8}}}, handle)
        ok("three marks are enough to try", read_landmark_file(enough)[0] is not None)
    # ---- TASK 104: the three things task 103's format could not say, each scored and each pinned.
    def reading(x, y, studs=1.0):
        return {"x": x, "y": y, "studs": studs, "onScreen": 0 <= x <= 1 and 0 <= y <= 1}

    # (i) DEPTH ORDER. A picture gives no distance but it always gives an order.
    order = {"marks": {"Stock": {"x": 0.5, "y": 0.5, "nearer": "Forend"},
                       "Forend": {"x": 0.5, "y": 0.5}}}
    right_way = {"parts": {"Stock": reading(0.5, 0.5, 0.8), "Forend": reading(0.5, 0.5, 2.0)}}
    wrong_way = {"parts": {"Stock": reading(0.5, 0.5, 2.0), "Forend": reading(0.5, 0.5, 0.8)}}
    ok("the right depth order costs nothing", fit_error(right_way, order)[0] < 1e-9,
       f"{fit_error(right_way, order)[0]}")
    ok("the wrong depth order costs, by how far it is wrong",
       fit_error(wrong_way, order)[0] > fit_error(right_way, order)[0], f"{fit_error(wrong_way, order)[0]}")
    worse = {"parts": {"Stock": reading(0.5, 0.5, 5.0), "Forend": reading(0.5, 0.5, 0.8)}}
    ok("...and more when it is more wrong", fit_error(worse, order)[0] > fit_error(wrong_way, order)[0])
    ok("`farther` is the same rule the other way up",
       fit_error(right_way, {"marks": {"Forend": {"x": 0.5, "y": 0.5, "farther": "Stock"},
                                       "Stock": {"x": 0.5, "y": 0.5}}})[0] < 1e-9)

    # (ii) WHICH EDGE. "Off the bottom" and "off the left" are different guns, and task 103's fit
    # chose the second while scoring the first as satisfied.
    edged = {"marks": {"Stock": {"x": 0.5, "y": 0.5}}, "offScreen": {"Muzzle": "bottom"}}
    base = {"Stock": reading(0.5, 0.5)}
    out_bottom = {"parts": dict(base, Muzzle=reading(0.5, 1.4))}
    out_left = {"parts": dict(base, Muzzle=reading(-0.4, 0.5))}
    on_screen = {"parts": dict(base, Muzzle=reading(0.5, 0.5))}
    ok("off the edge it was asked for costs nothing", fit_error(out_bottom, edged)[0] < 1e-9,
       f"{fit_error(out_bottom, edged)[0]}")
    ok("off the WRONG edge costs", fit_error(out_left, edged)[0] > 0.1, f"{fit_error(out_left, edged)[0]}")
    ok("on screen when it should be off costs most",
       fit_error(on_screen, edged)[0] > fit_error(out_left, edged)[0],
       f"{fit_error(on_screen, edged)[0]} vs {fit_error(out_left, edged)[0]}")
    ok("a bare list is still any edge",
       fit_error(out_left, {"marks": {"Stock": {"x": 0.5, "y": 0.5}}, "offScreen": ["Muzzle"]})[0] < 1e-9)

    # (iii) THE SCREEN ANGLE: which way the barrels RUN, which no pair of uncertain positions says.
    # 0 points right, 90 straight DOWN.
    angled = {"marks": {"StandingBreech": {"x": 0.5, "y": 0.5}},
              "directions": [{"from": "StandingBreech", "to": "Muzzle", "deg": 90}]}
    down = {"parts": {"StandingBreech": reading(0.5, 0.5), "Muzzle": reading(0.5, 0.9)}}
    right = {"parts": {"StandingBreech": reading(0.5, 0.5), "Muzzle": reading(0.9, 0.5)}}
    up = {"parts": {"StandingBreech": reading(0.5, 0.5), "Muzzle": reading(0.5, 0.1)}}
    ok("the angle it was asked for costs nothing", fit_error(down, angled)[0] < 1e-9,
       f"{fit_error(down, angled)[0]}")
    # The score is an RMS over every term, and these two specs carry one exact mark beside the
    # angle: a quarter turn out is sqrt(0.25 / 2) = 0.354, a half turn sqrt(1 / 2) = 0.707.
    ok("a quarter turn out costs a quarter of the angle scale",
       abs(fit_error(right, angled)[0] - 0.3536) < 0.01, f"{fit_error(right, angled)[0]}")
    ok("a half turn out costs the whole of it",
       abs(fit_error(up, angled)[0] - 0.7071) < 0.01, f"{fit_error(up, angled)[0]}")

    # ...and the three new shapes are REFUSED when they are written wrong, so a typo in the
    # Director's file is a message rather than a constraint that silently scores nothing.
    def refused(spec_body, why):
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "x.json")
            with open(path, "w", encoding="utf-8") as handle:
                json.dump(spec_body, handle)
            got, problem = read_landmark_file(path)
            ok(why, got is None and problem != "", repr(problem))

    three = {"A": {"x": 0.1, "y": 0.1}, "B": {"x": 0.2, "y": 0.2}, "C": {"x": 0.3, "y": 0.3}}
    refused({"marks": three, "offScreen": {"Muzzle": "sideways"}}, "an edge nobody has is refused")
    refused({"marks": three, "directions": [{"from": "nope", "to": "Muzzle", "deg": 90}]},
            "a direction from a mark that is not there is refused")
    refused({"marks": three, "directions": [{"from": "A", "to": "Muzzle"}]},
            "a direction with no angle is refused")
    refused({"marks": dict(three, A={"x": 0.1, "y": 0.1, "nearer": "A"})},
            "a mark that is nearer than itself is refused")

    # ...and the file the Director actually runs has more than the minimum.
    shipped, shipped_problem = read_landmark_file(
        os.path.join(REPO, "tools", "landmarks", "newGun-reload.json"))
    ok("the shipped reload landmarks are usable", shipped is not None, repr(shipped_problem))
    ok("the shipped reload landmarks carry four on-screen marks",
       shipped is not None and len(shipped["marks"]) >= 4,
       str(len(shipped["marks"]) if shipped else 0))

    for failure in failures:
        print("[pose] selftest: " + failure)
    if failures:
        print(f"[pose] selftest FAIL: {len(failures)} case(s) wrong")
        return 1
    print("[pose] selftest PASS: the search walks to a pose it cannot see and stays in its bounds; "
          "every pose in poses.json is reachable by path, every bad override "
          "is refused, a mid keyframe is tunable, and the file is already in `save`'s format")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv))
