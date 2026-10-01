#!/usr/bin/env python3
"""The Director's viewmodel tuning instrument: change a pose number in a RUNNING Studio session.

    python tools/pose.py                              every pose number, and what is overridden
    python tools/pose.py show [pose]                  the effective values (one pose, or all)
    python tools/pose.py set <path> <value>           e.g. `set aim.eyeReliefStuds 4.2`
    python tools/pose.py save                         write the effective values into poses.json
    python tools/pose.py clear                        drop every override
    python tools/pose.py compare <pose> [--target <image>] [--assets-dir <dir>]
                                                      hold the pose, capture it, build ONE
                                                      side-by-side with the reference frame, and
                                                      print the measured landmarks
    python tools/pose.py selftest                     NO Studio: prove the merge, the paths and the
                                                      file round trip (CI runs this)

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
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import studio_mcp  # noqa: E402

REPO = studio_mcp.REPO
POSES_FILE = os.path.join(REPO, "src", "shared", "Viewmodel", "poses.json")
REFERENCE_SET = "inspiration-2026-10-01"
HOLD_KEY = "hold"
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
        if path == HOLD_KEY:
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
    for name in ("Bead", "HandRight", "HandLeft"):
        mark = (marks.get("parts") or {}).get(name)
        if not mark:
            print(f"[pose]   {name}: not on the drawn gun")
            continue
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


def run_compare(studio, pose, explicit_target, assets_dir):
    if pose not in HOLDS:
        print(f"[pose] compare takes one of: {', '.join(HOLDS)}")
        return 2
    client_id, client_dm, why = running(studio, "client")
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
    rest = []
    index = 0
    while index < len(args):
        if args[index] == "--assets-dir" and index + 1 < len(args):
            assets_dir = args[index + 1]
            index += 2
        elif args[index] == "--target" and index + 1 < len(args):
            explicit_target = args[index + 1]
            index += 2
        else:
            rest.append(args[index])
            index += 1
    args = rest

    action = args[0] if args else "show"
    if action not in ("show", "set", "save", "clear", "compare"):
        print(__doc__)
        return 2

    data = read_poses()
    studio = studio_mcp.Studio()
    try:
        if action == "compare":
            if len(args) != 2:
                print("[pose] usage: pose.py compare <carry|raise|aim|reload> [--target <image>]")
                return 2
            return run_compare(studio, args[1], explicit_target, assets_dir)

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

    for failure in failures:
        print("[pose] selftest: " + failure)
    if failures:
        print(f"[pose] selftest FAIL: {len(failures)} case(s) wrong")
        return 1
    print("[pose] selftest PASS: every pose in poses.json is reachable by path, every bad override "
          "is refused, a mid keyframe is tunable, and the file is already in `save`'s format")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv))
