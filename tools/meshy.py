#!/usr/bin/env python3
r"""Meshy: one written brief -> one preview a human looks at, and never a credit spent unwatched.

Design: docs/design/meshy-tool.md  ·  Note: docs/research/2026-09-26-meshy.md
Brief:  reviews/task-53/BRIEF.md   ·  Tasks A and B of the design's section 14: the preview half
(one brief -> one image a human looks at) and the delivery half up to the SECOND stop point
(refine -> remesh -> fetch, a textured model on disk that a human looks at). `promote` -- the
sidecar and the drop dir -- is NOT here: it depends on tools/assets.py, which does not exist yet
(design section 0 item 6). Nothing in this file can upload anything: it contains no Roblox endpoint.

Usage
    python tools/meshy.py key [--check]        is MESHY_API_KEY set? --check makes ONE free call
    python tools/meshy.py brief <key>_v<N>     validate a brief and print what would be sent
    (briefs live in docs/asset-briefs/ IN THE REPO -- one source, reviewed in git; everything this
     tool WRITES still goes outside it)
    python tools/meshy.py preview <key>_v<N> [--dry-run]
    python tools/meshy.py status [<run-id>]    local records, plus one GET per live task
    python tools/meshy.py approve <run-id> --by karen [--note "..."]
    python tools/meshy.py refine <run-id> [--dry-run]     REFUSED without an approval; 2K PBR
    python tools/meshy.py remesh <run-id> [--target N] [--dry-run]  triangles, target_polycount
    python tools/meshy.py fetch <run-id>                  download the FBX and the maps NOW, validate
    python tools/meshy.py resume <run-id>      continue an interrupted poll, or collect a run
                                               a STOPPED line left unresolved
    python tools/meshy.py runs                 every run: state, age, expiry, credits
    python tools/meshy.py selftest             offline: validators, builders, parsers. CI runs this

Exit codes, the shape tools/studio_mcp.py and tools/privacy_scan.py already use:
    0 done  ·  1 failed  ·  2 REFUSED (no key, dirs unset or inside the repo, validation, wrong
    state, a ceiling) -- refused before anything is sent, and never a stack trace.

THE TWO STOP POINTS, and they are the reason there is no one-shot `generate`: after `preview` the
tool stops for a human to LOOK at the image and for Karen's `approve`, and after `fetch` it stops
again for a human to look at the finished, textured model before anything is uploaded anywhere.

THE LAST LINE IS ALWAYS MACHINE-READABLE, prefix `[meshy]`: OK / PENDING / STOPPED / FAILED /
REFUSED. It is what the ASSET agent pastes into its report and what a Reviewer checks, exactly as
`[harness]` is. STOPPED is the one that costs money if it is ignored: the task is paid for and the
run is still collectable, so that line ends with the exact command that collects it -- `resume` when
the task must be re-polled, `fetch` when the bytes must be downloaded again. FAILED is terminal for
the Meshy side of the run -- the task came back FAILED or CANCELED, a ceiling stopped it, or no task
was ever created -- with one exception, which the line always names: a `fetch` whose files landed and
then broke a local check keeps the files and says whether the way out is `remesh --target <lower>` or
a new brief version.

NOTHING IS "DONE" UNTIL IT DELIVERED WHAT WAS PAID FOR (Task 62, review round 1). One guard,
`deliver`, is the only place in this file that writes a "ready" state: it checks what the step OWED
on disk (DELIVERABLES), that nothing which was offered failed to download, and every local check
there is. So no paid step can call itself finished on an empty folder, and a run that is paid for but
incomplete is always left in a state some command takes -- the command its own line names.

THE KEY. Read once, from os.environ, else from HKCU\Environment (a shell started before Karen made
the variable does not have it). NEVER printed, logged, put in an exception, or written to a run
record -- `key` prints an 8-hex fingerprint of its SHA-256, which says "did it change" and is not
invertible. Every header is redacted before any print. tools/privacy_scan.py has a `meshy-key` rule
so a pasted key fails CI instead of being published, and the selftest's REDACTION block renders
every line this tool can emit and asserts the key is in none of them.

WHAT THIS TOOL CANNOT DO, by construction: it contains no Roblox endpoint and reads no Roblox
variable, so an ASSET session cannot publish UGC through it; and Meshy's API has no publish, share
or community endpoint at all (note D10), so there is nothing here that could make a model public.

WHAT IT REFUSES TO GUESS: a status value it does not know is NOT success (the MODERATION_STATE_
lesson in docs/design/asset-pipeline.md 7.4); credits come from the API's `consumed_credits` or are
recorded as "unknown"; the triangle count is DECLARED, never parsed, because the remesh response
carries no polycount (note D5) and a hand-written FBX reader is one of the three named causes of
death of the previous project (docs/PROJECT_CONTEXT.md).

Pattern: a thin stdlib HTTP client over a documented REST API, with the state machine on disk --
the same shape as tools/studio_mcp.py. meshy-dev/meshy-cli (MIT, TypeScript, official) is the
reference for request shapes and is deliberately NOT vendored: it is a Node dependency tree in the
one program here that holds a secret (note, "Borrowed, not invented").
"""

import argparse
import datetime
import fnmatch
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BASE_URL = "https://api.meshy.ai"
# Every path is quoted in docs/research/2026-09-26-meshy.md, read 2026-09-26.
ENDPOINTS = {
    "text-to-3d": "/openapi/v2/text-to-3d",
    "image-to-3d": "/openapi/v1/image-to-3d",
    "multi-image-to-3d": "/openapi/v1/multi-image-to-3d",
    "remesh": "/openapi/v1/remesh",
    "usage": "/openapi/v1/usage/tasks",
}

# "Possible values are one of PENDING, IN_PROGRESS, SUCCEEDED, FAILED, CANCELED" -- note item 2.
# CANCELED is the fifth value the Director's brief never named; it is terminal and it is NOT success.
STATUS_SUCCESS = "SUCCEEDED"
STATUS_TERMINAL_BAD = ("FAILED", "CANCELED")
STATUS_RUNNING = ("PENDING", "IN_PROGRESS")

MIN_REQUEST_GAP_S = 1.0  # 5% of Meshy's documented 20 req/s. Concurrency is the real cap, not rate.
POLL_INTERVAL_S = 5
POLL_DEADLINE_S = {"preview": 600, "refine": 900, "remesh": 300}
# Consecutive non-200 polls before the run is given up on. Three is two more chances than a
# transient 5xx needs and far fewer than the deadline's 120 (Task 55b).
POLL_GIVE_UP_AFTER = 3
HTTP_TIMEOUT_S = 60
DOWNLOAD_TIMEOUT_S = 300
RETRIES = 3
BACKOFF_S = (2, 4, 8)

# "will be deleted three (3) days after it is GENERATED" (Terms, 19 Sept 2026). Note D9: the design
# said finished_at + 3 days; `created_at` is earlier, so this is the safe reading of the same rule.
RETENTION_H = 72
EXPIRY_WARN_H = 24

MAX_TASKS_PER_RUN = 4  # preview, refine, remesh, one replacement. A fifth needs a human and a new run.
MAX_TASKS_PER_DAY = 12  # counted from the run records on disk, so it survives a crashed session
REMESH_CEILING = 18000  # the Director's brief; Meshy accepts 100-300,000, Roblox's hard limit is 20,000
MAX_REFERENCES = 4  # "1 to 4 images" (multi-image endpoint)
REMESH_MIN, REMESH_MAX = 100, 300000  # Meshy's documented range, quoted in the note (source 3)
# Roblox's documented per-call cap for an uploaded file (docs/design/asset-pipeline.md section 12.2).
# The FBX is what gets uploaded, so this is the number that decides whether a run can be delivered.
MAX_FILE_BYTES = 20 * 1024 * 1024
# What `fetch` pulls, in the order it tries them. The FBX is the ONE the pipeline promotes
# (asset-pipeline section 7.3 item 3 accepts .fbx and .png and refuses the rest); the others are
# kept because rule 7 says keep what was produced, and because a GLB is what a human can open.
MODEL_FILES = (("model.fbx", "fbx"), ("model.glb", "glb"), ("model.obj", "obj"))
# Meshy's PBR set (note item 3). `base_color` is the only map v1 promotes -- a SurfaceAppearance
# cannot be assembled at run time -- and the rest are kept beside it in the run folder.
TEXTURE_FILES = ("base_color", "metallic", "normal", "roughness", "emission")
# WHAT MESHY ACCEPTS, and now what this accepts too (Director decision, row 55a(a)). The docs
# say ".jpg, .jpeg, and .png"; Karen's reference photographs are JPEG and WebP, and refusing them
# meant the gun and the trees could not use references at all. WebP is sent as a data URI like
# the rest -- if Meshy refuses it, the task fails loudly with its own message rather than here.
REFERENCE_SUFFIXES = (".png", ".jpg", ".jpeg", ".webp")
DATA_URI_TYPE = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
                 ".webp": "image/webp"}
TEXTURE_PX_DEFAULT = 2048  # refine's `texture_resolution` IS a parameter (note D3)
# The sizes Roblox and the asset pipeline between them make sensible: 1024 is
# `asset-pipeline` 12.2's budget for an ordinary key, 2048 the hero keys' (design 15 Director D),
# and 4096 is Roblox's platform limit -- allowed so a future key can ask for it, but never the
# default. Anything else is a typo, and a typo here is paid for in credits.
TEXTURE_PX_ALLOWED = (1024, 2048, 4096)

# docs/design/asset-pipeline.md 12.1, quoted not restated. A key with no row uses REMESH_CEILING.
REMESH_TARGETS = {
    "boar.body": 6000,
    "shotgun.handle": 4000,
    "prop.highseat": 1500,
    "tree.oak": 1200,
    "tree.birch": 1000,
    "tree.alder": 1000,
    "tree.spruce": 900,
}

KINDS = ("meshpart", "image", "model")  # asset-pipeline 4.1 Kind
# THE LICENCE THIS TOOL CAN PRODUCE, and the only one. On a FREE plan the Terms say the opposite --
# "Meshy owns all right, title, and interest ... in and to the Customer Output" -- so nothing this
# pipeline makes could ship. `evidence` says exactly what the claim rests on, because no API call can
# prove a plan: `usage/tasks` answers 403 for everything below Studio (research note D11), and the
# authentication docs do not say a key requires a paid plan at all (D7). Director decision, row
# 55a(c), 2026-09-26.
LICENCE = {
    "basis": "meshy-paid-owned",
    "quote": "such customers on a paid Meshy plan own their Customer Output.",
    "quotedFrom": "https://www.meshy.ai/terms-of-use",
    "readOn": "2026-09-26",
    "evidence": "Karen's statement 2026-09-26, plus a working API key (no API call can prove a plan)",
}

# WHAT EACH PAID STEP OWES ON DISK, and the ONE table `deliver` reads (Task 62, review round 1
# findings 1 and 2). A step whose money bought bytes is not "done" until the bytes are here: the
# preview is paid for the image Karen's yes is given to, and the REFINE is paid for the PBR maps --
# which is why `fetch` owes a map as well as the FBX. A pattern means AT LEAST ONE match, so
# `texture_*.png` is exactly the check whose absence let a fetch with no texture at all exit 0 and
# invite Karen to look. `refine` and `remesh` owe nothing on disk (the maps are minted by `fetch`,
# from fresh URLs), so their rows are empty and what still stops them is an offered download that
# failed. Each row is (pattern, what to call it in a line a human reads).
DELIVERABLES = {
    "preview": (("preview.png", "preview.png"),),
    "refine": (),
    "remesh": (),
    "fetch": (("model.fbx", "model.fbx"),
              ("texture_*.png", "any PBR map at all (texture_*.png), which the refine paid for")),
}

PHASES = ("preview", "refine", "remesh")

STATES = ("brief-ok", "preview-running", "preview-unresolved", "preview-ready", "approved",
          "refine-running", "refine-unresolved", "refine-ready",
          "remesh-running", "remesh-unresolved", "remesh-ready", "fetched",
          "failed", "expired")

# MONEY ALREADY SPENT STAYS COLLECTABLE (Task 59, review round 1). `failed` is a TERMINAL: a Meshy
# task came back FAILED or CANCELED, a ceiling stopped the run, or the POST never created a task --
# in each of those there is nothing left to collect. Everything else that stops the tool while a
# PAID task may still be running, or while its output could still be re-fetched, is
# `preview-unresolved`, and `resume` takes it: a give-up after three unanswered polls, a 401 whose
# key can be rotated, a SUCCEEDED task whose download failed. Putting those in `failed` made the
# credits unreachable by any command, because `preview` again would pay twice (design section 8).
# ONE RULE, THREE PHASES (Task 62): everything that stops while a PAID task may still be running,
# or while its output can still be re-fetched, is `<phase>-unresolved`, and `resume` takes it --
# whichever phase the run's last task is. Task 59 built this for the preview; a refine costs more
# than a preview, so stranding one would be worse.
RESUMABLE_STATES = tuple(
    state for phase in PHASES for state in (f"{phase}-running", f"{phase}-unresolved")
)


class Refused(Exception):
    """Exit 2: a refusal, decided before anything was sent. Never a stack trace."""


class Failed(Exception):
    """Exit 1: something ran and did not work."""


# ---------------------------------------------------------------- the key


def _registry_key():
    """HKCU\\Environment's MESHY_API_KEY, or None. Read-only; this tool never writes the registry.

    A shell started before Karen created the user variable does not carry it, and telling her to
    reboot is worse than reading the value she already set (design section 6.1)."""
    if os.name != "nt":
        return None, "not Windows, so there is no HKCU\\Environment to read"
    try:
        import winreg  # noqa: PLC0415 -- Windows-only, imported where it is used
    except ImportError:  # pragma: no cover -- winreg ships with CPython on Windows
        return None, "winreg is unavailable"
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as handle:
            value, _kind = winreg.QueryValueEx(handle, "MESHY_API_KEY")
            return (value or None), ""
    except FileNotFoundError:
        return None, "HKCU\\Environment has no MESHY_API_KEY"
    except OSError as error:
        return None, f"HKCU\\Environment could not be read ({type(error).__name__})"


def read_key():
    """(key, source, why) -- key is None when unset. THE VALUE IS NEVER PRINTED BY ANY CALLER."""
    value = os.environ.get("MESHY_API_KEY")
    if value:
        return value, "environment", ""
    value, why = _registry_key()
    if value:
        return value, "registry", ""
    return None, "none", why


def fingerprint(key):
    """The first 8 hex of SHA-256: enough to say "did the key change", not invertible."""
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:8]


def redact(text, key):
    """Every rendering of anything goes through this before it is printed (design section 6.1).

    The selftest's REDACTION block builds every line this tool can emit with a fake key and asserts
    the key appears in none of them -- that is what keeps this true after a future edit.

    Blocks are named, not numbered (Task 55b): three comments carried three different case numbers
    for the same two blocks, because numbering a list that grows is a citation that rots."""
    if not key:
        return text
    return str(text).replace(key, "***")


# ---------------------------------------------------------------- directories


def drop_dir():
    """ASSET_DROP_DIR. Unset, missing, or inside the repo -> refused (asset-pipeline 7.2).

    A source tree that can be uploaded from is a source tree someone commits."""
    raw = os.environ.get("ASSET_DROP_DIR")
    if not raw:
        raise Refused("ASSET_DROP_DIR is not set. It is Karen's drop folder, OUTSIDE the repo "
                      "(docs/design/asset-pipeline.md section 7.2)")
    path = os.path.abspath(raw)
    if not os.path.isdir(path):
        raise Refused("ASSET_DROP_DIR does not exist (printed as <assets-dir>; the path is not "
                      "echoed, because this repo is public)")
    if inside_repo(path):
        raise Refused("ASSET_DROP_DIR resolves INSIDE the repository. A source tree that can be "
                      "uploaded from is a source tree someone commits")
    return path


def inside_repo(path):
    try:
        return os.path.commonpath([os.path.abspath(path), REPO]) == REPO
    except ValueError:  # different drives on Windows
        return False


def runs_dir():
    raw = os.environ.get("MESHY_RUN_DIR")
    path = os.path.abspath(raw) if raw else os.path.join(drop_dir(), "meshy-runs")
    if inside_repo(path):
        raise Refused("MESHY_RUN_DIR resolves INSIDE the repository")
    os.makedirs(path, exist_ok=True)
    return path


def briefs_dir():
    """`docs/asset-briefs/` IN THE REPOSITORY, and there is no second copy (Director decision,
    row 55a(b), 2026-09-26).

    Task 55 kept two: the reviewed record in the repo and a working copy in the drop folder that
    this tool read. Two copies of the file that decides what is generated and what is paid for is
    exactly the drift this project keeps paying for, and the drop-dir copy was the one nobody could
    review. A brief carries no path, no key and no personal data, so there is no reason it cannot
    live in git -- and every reason it should, because it is quoted verbatim into every run record
    as the provenance of record.

    NOTE the asymmetry, and it is deliberate: briefs are READ from the repo, and everything this
    tool WRITES still goes outside it (`runs_dir`, which refuses a path inside the repo)."""
    return os.path.join(REPO, "docs", "asset-briefs")


# ---------------------------------------------------------------- the brief


def parse_brief_name(name):
    """`<key>_v<N>` -> (key, version), by asset-pipeline 4.3's grammar, DERIVED and never prompted.

    key ::= segment ("." segment)*   segment ::= [a-z][a-z0-9]*
    "a typo there becomes a manifest row and an asset on Roblox that cannot be renamed."""
    stem = name
    for suffix in (".brief.json", ".json"):
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
    if "_v" not in stem:
        raise Refused(f"{name!r} is not <key>_v<N>: no _v")
    key, _, version = stem.rpartition("_v")
    if not version.isdigit() or version != str(int(version)) or int(version) < 1:
        raise Refused(f"{name!r} is not <key>_v<N>: {version!r} is not a version number")
    if not key:
        raise Refused(f"{name!r} is not <key>_v<N>: the key is empty")
    for segment in key.split("."):
        if not segment or not segment[0].islower() or not segment[0].isalpha() \
                or not all(character.islower() and character.isalnum() for character in segment):
            raise Refused(f"{name!r}: key segment {segment!r} is not [a-z][a-z0-9]*")
    return key, int(version)


def validate_brief(data, name, reference_names=()):
    """Every refusal in design section 4.1, each naming its own reason. Nothing is sent before this."""
    key, version = parse_brief_name(name)
    problems = []
    if data.get("key") != key:
        problems.append(f"`key` is {data.get('key')!r} but the file name derives {key!r}")
    if data.get("version") != version:
        problems.append(f"`version` is {data.get('version')!r} but the file name derives {version}")
    if data.get("kind") not in KINDS:
        problems.append(f"`kind` {data.get('kind')!r} is not one of {', '.join(KINDS)}")
    prompt = data.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip():
        problems.append("`prompt` is empty, and it is recorded forever as the provenance of record")
    references = data.get("references") or []
    if not isinstance(references, list):
        problems.append("`references` must be a list of file NAMES in docs/asset-briefs/, never paths")
        references = []
    if len(references) > MAX_REFERENCES:
        problems.append(f"{len(references)} references, and Meshy accepts 1 to {MAX_REFERENCES}")
    for reference in references:
        if not isinstance(reference, str) or "/" in reference or "\\" in reference:
            problems.append(f"reference {reference!r} must be a file NAME, not a path")
            continue
        if not reference.lower().endswith(REFERENCE_SUFFIXES):
            problems.append(
                f"reference {reference!r} is not one of {', '.join(REFERENCE_SUFFIXES)}")
        elif reference_names and reference not in reference_names:
            problems.append(f"reference {reference!r} is not in docs/asset-briefs/")
    size = data.get("sizeMetres")
    if not (isinstance(size, list) and len(size) == 3
            and all(isinstance(number, (int, float)) and number > 0 for number in size)):
        problems.append("`sizeMetres` must be three positive numbers: the mesh must be the grey "
                        "box's size, so no physics or hit-zone number moves when art lands")
    target = data.get("targetTris", REMESH_TARGETS.get(key, REMESH_CEILING))
    if not isinstance(target, int) or isinstance(target, bool) or target < 100:
        problems.append(f"`targetTris` {target!r} is not an integer >= 100 (Meshy's floor)")
    elif target > REMESH_CEILING:
        problems.append(f"`targetTris` {target} is over REMESH_CEILING {REMESH_CEILING}")
    # CHECKED LIKE EVERY OTHER FIELD (Task 55b). It was read straight out of the brief with no test
    # at all, so a string or a 16384 would have flowed into Task B's `texture_resolution` and been
    # refused by Meshy AFTER the credits were spent -- or worse, accepted.
    texture = data.get("texturePx", TEXTURE_PX_DEFAULT)
    if not isinstance(texture, int) or isinstance(texture, bool):
        problems.append(f"`texturePx` {texture!r} is not an integer")
    elif texture not in TEXTURE_PX_ALLOWED:
        problems.append(
            f"`texturePx` {texture} is not one of {', '.join(str(n) for n in TEXTURE_PX_ALLOWED)}")
    if problems:
        raise Refused("the brief is not usable:\n  - " + "\n  - ".join(problems))
    return {"key": key, "version": version, "targetTris": target, "texturePx": texture}


def choose_endpoint(references):
    """WHICH ENDPOINT IS DATA, NOT A FLAG (design 4.1): 0 -> text, 1 -> image, 2-4 -> multi-image."""
    count = len(references or [])
    if count == 0:
        return "text-to-3d"
    if count == 1:
        return "image-to-3d"
    return "multi-image-to-3d"


def data_uri(blob, name):
    """A local image as Meshy's documented "base64-encoded data URI", so nothing needs public
    hosting. The media type comes from the FILE NAME, because a PNG announced as a JPEG is a
    decode error at the far end and a wasted task (Task 55b)."""
    import base64  # noqa: PLC0415 -- only this one function needs it
    suffix = os.path.splitext(name)[1].lower()
    media = DATA_URI_TYPE.get(suffix)
    if media is None:
        raise Refused(f"{name!r} has no known media type; accepted: {', '.join(REFERENCE_SUFFIXES)}")
    return f"data:{media};base64," + base64.b64encode(blob).decode("ascii")


def build_preview_request(brief, resolved, images):
    """(endpoint, path, body). NOTHING DEPRECATED IS SENT: no art_style, negative_prompt or symmetry,
    and no rigging option (humanoid-only, and the boar is not humanoid).

    Asserted against EXPECTED_TEXT_BODY, a frozen fixture, so a later edit to the builder shows
    up as a diff. (Named, not numbered: Task 55b found three comments citing three different
    case numbers for the same two blocks.)"""
    endpoint = choose_endpoint(brief.get("references"))
    body = {}
    if endpoint == "text-to-3d":
        body = {
            "mode": "preview",
            "prompt": brief["prompt"],
            "should_remesh": True,
            "topology": "triangle",  # Roblox counts triangles
            "target_polycount": resolved["targetTris"],
        }
    elif endpoint == "image-to-3d":
        body = {
            "image_url": images[0],
            "should_remesh": True,
            "topology": "triangle",
            "target_polycount": resolved["targetTris"],
            "should_texture": True,
        }
    else:
        body = {
            "image_urls": images,
            "should_remesh": True,
            "topology": "triangle",
            "target_polycount": resolved["targetTris"],
            "should_texture": True,
        }
    return endpoint, ENDPOINTS[endpoint], body


def build_refine_request(record, texture_px):
    """(path, body) for the refine of THIS run's preview task.

    The same v2 text-to-3d endpoint with `mode: "refine"` and the preview task's id (design section
    7.2). `texture_resolution` IS a parameter -- research note D3 -- so 2K is ASKED FOR rather than
    hoped for, and `enable_pbr` is what makes the maps beside the albedo exist at all."""
    preview = task_of(record, "preview")
    if preview is None:
        raise Refused("this run has no preview task to refine")
    return ENDPOINTS["text-to-3d"], {
        "mode": "refine",
        "preview_task_id": preview["taskId"],
        "enable_pbr": True,
        "texture_resolution": texture_px,
    }


def build_remesh_request(record, target):
    """(path, body) for the remesh of THIS run's newest model task.

    TRIANGLES, because Roblox counts triangles ("Individual meshes can not exceed 20,000
    triangles", docs/design/asset-pipeline.md section 11). The count is DECLARED: the remesh
    response carries no polycount field (research note D5), so this number IS the claim, and
    nothing downstream may pretend it was measured."""
    source = task_of(record, "refine") or task_of(record, "preview")
    if source is None:
        raise Refused("this run has no model task to remesh")
    return ENDPOINTS["remesh"], {
        "input_task_id": source["taskId"],
        "target_polycount": target,
        "topology": "triangle",
    }


def resolve_target(record, asked):
    """The triangle target, and every way it can be refused, BEFORE a request is sent."""
    if asked is not None:
        target = asked
    else:
        target = (record.get("brief") or {}).get("targetTris")
    if target is None:
        target = REMESH_TARGETS.get(record["key"], REMESH_CEILING)
    if not isinstance(target, int) or isinstance(target, bool):
        raise Refused(f"the triangle target {target!r} is not an integer")
    if target < REMESH_MIN or target > REMESH_MAX:
        raise Refused(f"the triangle target {target} is outside Meshy's {REMESH_MIN}-{REMESH_MAX}")
    if target > REMESH_CEILING:
        raise Refused(f"the triangle target {target} is over REMESH_CEILING ({REMESH_CEILING}); "
                      "Roblox's hard limit is 20,000 and this repo does not go near it")
    return target


def task_of(record, phase):
    """The NEWEST task of a phase, or None. Newest, because a replacement task is the one that counts."""
    for entry in reversed(record.get("tasks", [])):
        if entry.get("phase") == phase:
            return entry
    return None


def png_size(blob):
    """(width, height) from a PNG's 8-byte signature plus the IHDR, or Failed.

    24 BYTES AND NO LIBRARY (asset-pipeline section 7.3 item 5): the signature is fixed, the first
    chunk of a PNG must be IHDR, and its width and height are big-endian at offsets 16 and 20."""
    if len(blob) < 24 or blob[:8] != b"\x89PNG\r\n\x1a\n":
        raise Failed("not a PNG (the 8-byte signature is wrong)")
    if blob[12:16] != b"IHDR":
        raise Failed("not a PNG (the first chunk is not IHDR)")
    width = int.from_bytes(blob[16:20], "big")
    height = int.from_bytes(blob[20:24], "big")
    return width, height


# ---------------------------------------------------------------- HTTP


_last_request_at = [0.0]


def request(method, path, key, body=None, timeout=HTTP_TIMEOUT_S):
    """One Meshy call, with the gap, the retries and the redaction. Returns (status, parsed, raw).

    429 is the interesting one: Meshy distinguishes "RateLimitExceeded" (requests) from
    "NoMoreConcurrentTasks" (queue), and the message says WHICH rather than guessing (note D6).
    Retry-After is honoured if present and is NOT assumed to exist -- it is undocumented."""
    gap = MIN_REQUEST_GAP_S - (time.time() - _last_request_at[0])
    if gap > 0:
        time.sleep(gap)
    payload = json.dumps(body).encode("utf-8") if body is not None else None
    last = ""
    for attempt in range(RETRIES + 1):
        req = urllib.request.Request(BASE_URL + path, data=payload, method=method)
        req.add_header("Authorization", "Bearer " + key)
        req.add_header("Content-Type", "application/json")
        _last_request_at[0] = time.time()
        try:
            with urllib.request.urlopen(req, timeout=timeout) as response:
                raw = response.read().decode("utf-8", "replace")
                return response.status, _json_or_none(raw), raw
        except urllib.error.HTTPError as error:
            raw = error.read().decode("utf-8", "replace") if error.fp else ""
            parsed = _json_or_none(raw)
            if error.code == 429 and attempt < RETRIES:
                after = error.headers.get("Retry-After") if error.headers else None
                wait = int(after) if (after or "").isdigit() else BACKOFF_S[min(attempt, 2)]
                which = (parsed or {}).get("message") or raw[:120]
                print(f"[meshy] 429 after {attempt + 1} try/tries ({redact(which, key)}); "
                      f"waiting {wait}s. RateLimitExceeded = 20 req/s; NoMoreConcurrentTasks = the "
                      f"plan's queue cap", flush=True)
                time.sleep(wait)
                last = which
                continue
            return error.code, parsed, raw
        except OSError as error:  # timeouts, DNS, TLS
            if attempt < RETRIES:
                time.sleep(BACKOFF_S[min(attempt, 2)])
                last = f"{type(error).__name__}: {error}"
                continue
            raise Failed(redact(f"the request did not complete after {RETRIES + 1} tries: {error}", key))
    raise Failed(redact(f"429 after {RETRIES + 1} tries: {last}", key))


def _json_or_none(raw):
    try:
        return json.loads(raw)
    except (ValueError, TypeError):
        return None


def describe_http_failure(status, parsed, raw, key):
    """A loud, redacted line for a status that is not 2xx. NEVER includes a header."""
    message = (parsed or {}).get("message") or (raw or "")[:200] or "(no body)"
    causes = {
        401: "the key is wrong, revoked, or not authorised for this endpoint",
        403: "forbidden. On `usage/tasks` this is expected below a Studio plan (note D11); "
             "elsewhere check whether the key's plan still covers the API",
        404: "the path or the task id does not exist",
    }.get(status, "")
    return redact(f"HTTP {status}: {message}" + (f" -- {causes}" if causes else ""), key)


# ---------------------------------------------------------------- status parsing


def read_status(task):
    """(status, done, ok, error_message). AN UNKNOWN VALUE IS NOT SUCCESS.

    docs/design/asset-pipeline.md 7.4 step 5: "hard-coding two strings is how a rejected asset
    quietly reads as fine." A MISSING status fails loudly rather than defaulting to anything."""
    if not isinstance(task, dict) or "status" not in task:
        raise Failed("the task response carries no `status` field; refusing to guess what it means")
    status = task.get("status")
    if status == STATUS_SUCCESS:
        return status, True, True, ""
    message = ""
    error = task.get("task_error")
    if isinstance(error, dict):
        message = error.get("message") or ""
    if status in STATUS_TERMINAL_BAD:
        return status, True, False, message or f"the task ended {status} with no task_error.message"
    if status in STATUS_RUNNING:
        return status, False, False, message
    # Not success, not a known terminal, not a known running value: treat as NOT success and say so.
    return status, False, False, f"unknown status {status!r} -- treated as not-success"


# ---------------------------------------------------------------- run records


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc)


def stamp(moment=None):
    return (moment or utc_now()).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_stamp(text):
    """Meshy returns ISO 8601; run records use the Z form. Returns None rather than raising."""
    if not text:
        return None
    try:
        return datetime.datetime.fromisoformat(str(text).replace("Z", "+00:00"))
    except ValueError:
        return None


def expiry_of(task):
    """created_at + 72 h. FROM `created_at`, because the Terms say "three (3) days after it is
    GENERATED" -- earlier than the design's finished_at, and therefore the safe reading (note D9)."""
    created = parse_stamp(task.get("createdAt"))
    if created is None:
        return None
    return created + datetime.timedelta(hours=RETENTION_H)


def run_path(run_id):
    return os.path.join(runs_dir(), run_id, "run.json")


def load_run(run_id):
    path = run_path(run_id)
    if not os.path.exists(path):
        raise Refused(f"no run {run_id}: nothing in <runs-dir> by that name")
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def save_run(record, fresh=False):
    """Write one run record. `fresh` means "this run is new": the directory must NOT already exist.

    WHY (Task 55b). `run_id` is minute-resolution, and this used to overwrite `run.json`
    unconditionally -- so two `preview` runs of the same key inside one minute silently replaced the
    first record and ORPHANED A TASK THAT HAD ALREADY BEEN PAID FOR. Nothing else in the tool would
    ever have mentioned it again: no id, no credits, no expiry. Rule 7 territory, and it is money."""
    path = run_path(record["runId"])
    folder = os.path.dirname(path)
    if fresh and os.path.exists(folder):
        raise Refused(
            f"the run directory {record['runId']} already exists. A run id is minute-resolution, so "
            "this is almost certainly a second `preview` for the same key in the same minute -- and "
            "overwriting it would orphan a task that has already been paid for. Wait a minute, or "
            "use `runs` to see what is there.")
    os.makedirs(folder, exist_ok=True)
    # Write then rename, so an interrupted write never leaves a half-parsed record.
    temporary = path + ".tmp"
    with open(temporary, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(record, handle, indent=2, sort_keys=True)
        handle.write("\n")
    os.replace(temporary, path)


def all_runs():
    try:
        root = runs_dir()
    except Refused:
        return []
    out = []
    for name in sorted(os.listdir(root)):
        path = os.path.join(root, name, "run.json")
        if os.path.exists(path):
            try:
                with open(path, encoding="utf-8") as handle:
                    out.append(json.load(handle))
            except ValueError:
                continue
    return out


def tasks_today(records, now=None):
    """Every task created in the last 24 h, across all runs. The ceiling survives a crashed session."""
    edge = (now or utc_now()) - datetime.timedelta(hours=24)
    count = 0
    for record in records:
        for task in record.get("tasks", []):
            created = parse_stamp(task.get("createdAt"))
            if created and created >= edge:
                count += 1
    return count


def check_ceilings(record, records, now=None):
    """Refused BEFORE any request, naming the ceiling and the count (design section 8)."""
    used = len(record.get("tasks", []))
    if used >= MAX_TASKS_PER_RUN:
        raise Refused(f"this run already has {used} task(s) and MAX_TASKS_PER_RUN is "
                      f"{MAX_TASKS_PER_RUN}. A fifth task needs a new run and a human")
    today = tasks_today(records, now)
    if today >= MAX_TASKS_PER_DAY:
        raise Refused(f"{today} task(s) in the last 24 h and MAX_TASKS_PER_DAY is "
                      f"{MAX_TASKS_PER_DAY}. A runaway session cannot empty the plan")


def require_state(record, wanted):
    if record.get("state") != wanted:
        raise Refused(f"run is {record.get('state')}, not {wanted}")


def require_state_in(record, wanted, extra=""):
    """The same refusal, by name, for a door that has more than one legal state (Task 62)."""
    if record.get("state") not in wanted:
        raise Refused(f"run is {record.get('state')}, not {' or '.join(wanted)}"
                      + (f" ({extra})" if extra else ""))


def phase_of(record):
    """The phase the run's newest task belongs to. `preview` for a record written before Task 62."""
    tasks = record.get("tasks") or []
    if not tasks:
        return "preview"
    return tasks[-1].get("phase") or "preview"


def stop_resumable(record, what, fix, command="resume"):
    """Stop, keep the run collectable, and print the exact command that collects it.

    Exit 1, because something did go wrong -- but the record stays in a state `resume` accepts, so
    the credits are not stranded. The line's last sentence is always the command to run: the ASSET
    agent pastes this into its report and the next session acts on it (design section 8).

    `command` IS THE ROUTE OUT, and it has to be one that works (Task 62, review round 1 finding 2):
    `resume` re-polls the task, and after a `fetch` that landed too little, or landed wrong bytes, it
    is `fetch` itself -- which re-polls AND downloads again. Both are accepted from the state written
    here: it is in RESUMABLE_STATES, and `cmd_fetch` takes `remesh-unresolved` too."""
    record["state"] = f"{phase_of(record)}-unresolved"
    save_run(record)
    expiry = expiry_line(record)
    print(f"[meshy] STOPPED: {record['runId']} {what}. {fix} "
          f"Run: python tools/meshy.py {command} {record['runId']}"
          + (f" ({expiry})" if expiry else ""))
    return 1


def expiry_line(record, now=None):
    """"", "EXPIRES IN 7h" or "EXPIRED" -- the 3-day trap, made visible in `runs` and `status`."""
    now = now or utc_now()
    latest = None
    for task in record.get("tasks", []):
        moment = expiry_of(task)
        if moment and (latest is None or moment > latest):
            latest = moment
    if latest is None:
        return ""
    hours = (latest - now).total_seconds() / 3600.0
    if hours <= 0:
        return "EXPIRED"
    if hours <= EXPIRY_WARN_H:
        return f"EXPIRES IN {int(hours)}h"
    return f"expires {stamp(latest)}"


class Problem:
    """One failed local check, and the ROUTE out of it (Task 62, review round 1 finding 2).

    A check with no route is how a paid run gets stranded: `fetch` used to write `state = "fetched"`
    before it looked at the problems, and then no command in the tool -- not `resume`, not `fetch`,
    not `remesh` -- would take that state, including for the one failure the code itself calls
    re-fetchable. So every problem now says which command answers it:

    - `refetch`: the bytes on disk are missing or wrong. `fetch` re-polls the task ids, mints fresh
      signed URLs and downloads again. The run is left in `<phase>-unresolved`, never `fetched`.
    - `remesh`: the bytes are what Meshy sent and the GEOMETRY is what is wrong. The way out is the
      replacement task MAX_TASKS_PER_RUN budgets: `remesh <run> --target <lower>`.
    - `brief`: everything paid for IS on disk and what it breaks is a number somebody wrote. No
      command can fix that, and the line says so rather than offering one that does nothing."""

    ROUTES = ("refetch", "remesh", "brief")
    __slots__ = ("text", "route")

    def __init__(self, text, route):
        assert route in Problem.ROUTES, route
        self.text, self.route = text, route

    def __repr__(self):
        return f"{self.route}: {self.text}"


def missing_deliverables(names, required):
    """The labels of the required patterns that nothing on disk satisfies (a pattern = at least one)."""
    return [label for pattern, label in required
            if not any(fnmatch.fnmatchcase(name, pattern) for name in names)]


def deliver(record, folder, entry, step, undownloaded, ready_state, fix, command="resume",
            validate=None):
    """THE ONE GUARD BETWEEN A PAID STEP AND THE WORD "DONE" (Task 62, review round 1).

    Every paid step goes through this, and a "ready" state is assigned NOWHERE else in the file, so
    the next command cannot reopen the class the Reviewer found twice in one task: a step that did
    not deliver what was paid for is never "done", and a run that is paid for but incomplete is
    always left in a state some command takes -- the command the printed line names.

    Three things are checked in this order, because a broken download makes every later judgement
    about the model worthless: what the step OWED (DELIVERABLES) is on disk; nothing that was
    offered failed to download (`undownloaded`); and, when `validate` is given, every local check
    passed. Returns None when the run advanced to `ready_state` and the caller may print its own OK
    line, or the exit code of a stop."""
    on_disk = [artefact["name"] for artefact in entry.get("artefacts", [])
               if os.path.isfile(os.path.join(folder, artefact["name"]))]
    missing = missing_deliverables(on_disk, DELIVERABLES[step]) + list(undownloaded)
    credits = entry.get("credits")
    spent = f"credits={credits if credits is not None else 'unknown'}"
    if missing:
        # PAID FOR, NOT COLLECTED (Task 59's class, now the only copy of it). The task SUCCEEDED and
        # the credits are gone; a signed URL, or a response that carried no URL for something this
        # step owed, is what went wrong -- and a re-poll mints new ones until the 3-day expiry.
        return stop_resumable(
            record,
            f"SUCCEEDED and its credits are spent, but {', '.join(sorted(set(missing)))} did not "
            f"reach disk ({spent})",
            fix, command=command)

    problems = list(validate(record, folder, entry)) if validate else []
    if validate is not None:
        record["validation"] = {"ok": not problems, "problems": [p.text for p in problems],
                               "at": stamp()}
        save_run(record)
    if problems:
        for problem in problems:
            print("[meshy]   - " + problem.text)
        routes = {problem.route for problem in problems}
        # ONE ROUTE, THE STRONGEST PRESENT: re-download before anything is concluded about the
        # model, and re-cut the geometry before a human is asked to rewrite a brief.
        if "refetch" in routes:
            return stop_resumable(
                record,
                f"landed {len(on_disk)} file(s) but {len(problems)} local check(s) failed, and at "
                f"least one is a BROKEN DOWNLOAD rather than a bad model ({spent})",
                "The bytes on disk are wrong; fetching again re-polls the same task ids, mints "
                "fresh URLs and downloads them again, until the 3-day expiry.",
                command="fetch")
        record["state"] = ready_state
        save_run(record)
        if "remesh" in routes:
            print(f"[meshy] FAILED: {record['runId']} landed {len(on_disk)} file(s) and "
                  f"{len(problems)} local check(s) failed; the files are kept in "
                  f"<runs-dir>/{record['runId']} and the GEOMETRY is what is wrong -- re-cut it: "
                  f"python tools/meshy.py remesh {record['runId']} --target <below "
                  f"{record.get('trisDeclared')}> (the replacement task MAX_TASKS_PER_RUN budgets)")
        else:
            print(f"[meshy] FAILED: {record['runId']} landed {len(on_disk)} file(s) and "
                  f"{len(problems)} local check(s) failed; everything paid for IS in "
                  f"<runs-dir>/{record['runId']}, and what it breaks is a number somebody wrote -- "
                  "no command can fix that: write a new brief version, or ask Karen to accept it")
        return 1

    record["state"] = ready_state
    save_run(record)
    return None


# ---------------------------------------------------------------- commands


def cmd_key(args):
    key, source, why = read_key()
    if not key:
        print("[meshy] MESHY_API_KEY: not set" + (f" ({why})" if why else ""))
        print("[meshy] REFUSED: set the MESHY_API_KEY user variable "
              "(docs/design/meshy-tool.md section 6). This tool never prompts for it: a typed key "
              "lands in the shell's scrollback")
        return 2
    print(f"[meshy] MESHY_API_KEY: set, fingerprint {fingerprint(key)}, source={source}")
    if not args.check:
        print("[meshy] OK: key present (no network call made; --check makes the one free call)")
        return 0
    # THE ONE CALL THAT COSTS NOTHING (the Director's dispatch allowed exactly one). usage/tasks
    # consumes no credits -- but note D11: it is Studio/Enterprise-only, so a 403 here is EXPECTED
    # on a Pro/Premium/Ultra key and still proves the key reached Meshy and was read.
    status, parsed, raw = request("GET", ENDPOINTS["usage"], key)
    if status == 200:
        records = (parsed or {}).get("result") or (parsed if isinstance(parsed, list) else [])
        print(f"[meshy] OK: the key works; usage/tasks returned {len(records)} record(s), "
              "0 credits spent")
        return 0
    if status == 403:
        print("[meshy] OK: the key was accepted and REFUSED BY PLAN. usage/tasks is "
              "Studio/Enterprise-only (research note D11), so 403 here means the key reached Meshy "
              "and was read -- it does NOT mean the key is wrong. 0 credits spent")
        return 0
    print("[meshy] FAILED: " + describe_http_failure(status, parsed, raw, key))
    return 1


def _load_brief_file(name):
    key, version = parse_brief_name(name)
    folder = briefs_dir()
    if not os.path.isdir(folder):
        raise Refused("there is no docs/asset-briefs/ folder in the repository")
    filename = f"{key}_v{version}.brief.json"
    path = os.path.join(folder, filename)
    if not os.path.exists(path):
        raise Refused(f"no brief named {filename} in docs/asset-briefs")
    with open(path, "rb") as handle:
        raw = handle.read()
    try:
        data = json.loads(raw.decode("utf-8"))
    except ValueError as error:
        raise Refused(f"{filename} is not valid JSON: {error}") from error
    names = {entry for entry in os.listdir(folder) if entry.lower().endswith(REFERENCE_SUFFIXES)}
    resolved = validate_brief(data, filename, names)
    return data, resolved, raw, filename, folder


def cmd_brief(args):
    data, resolved, raw, filename, _folder = _load_brief_file(args.name)
    count = len(data.get("references") or [])
    endpoint, path, body = build_preview_request(data, resolved, ["<data-uri>"] * count)
    print(f"[meshy] brief {filename}: key={resolved['key']} v{resolved['version']} "
          f"kind={data['kind']} briefSha256={hashlib.sha256(raw).hexdigest()[:16]}")
    print(f"[meshy] endpoint: {endpoint} (chosen by {count} reference(s), not by a flag)  "
          f"POST {path}")
    print(f"[meshy] target_polycount={resolved['targetTris']} "
          f"texture_resolution={resolved['texturePx']} (refine, Task B)")
    print("[meshy] body: " + json.dumps(body, sort_keys=True))
    print(f"[meshy] OK: brief {resolved['key']} v{resolved['version']} is usable")
    return 0


def _reference_images(data, folder):
    out = []
    for name in data.get("references") or []:
        with open(os.path.join(folder, name), "rb") as handle:
            out.append(data_uri(handle.read(), name))
    return out


def cmd_preview(args):
    data, resolved, raw, filename, folder = _load_brief_file(args.name)
    key, _source, why = read_key()
    if not key and not args.dry_run:
        raise Refused("MESHY_API_KEY is not set" + (f" ({why})" if why else ""))

    run_id = f"{resolved['key']}_v{resolved['version']}-{utc_now().strftime('%Y%m%dT%H%MZ')}"
    count = len(data.get("references") or [])
    images = ["<data-uri>"] * count if args.dry_run else _reference_images(data, folder)
    endpoint, path, body = build_preview_request(data, resolved, images)

    if args.dry_run:
        shown = dict(body)
        for field in ("image_url", "image_urls"):
            if field in shown:
                shown[field] = f"<base64 data URI x{count}>"
        print(f"[meshy] DRY RUN, nothing sent. POST {BASE_URL}{path}")
        print("[meshy] headers: Authorization: Bearer ***, Content-Type: application/json")
        print("[meshy] body: " + json.dumps(shown, indent=2, sort_keys=True))
        print(f"[meshy] OK: dry-run preview {resolved['key']} v{resolved['version']} credits=0")
        return 0

    records = all_runs()
    record = {
        "runId": run_id,
        "key": resolved["key"], "version": resolved["version"],
        "brief": data,
        "briefSha256": hashlib.sha256(raw).hexdigest(),
        "briefFile": filename,
        "endpoint": endpoint,
        "state": "brief-ok",
        "tasks": [],
        "approval": None,
        "licence": dict(LICENCE),
        "totals": {"tasks": 0, "credits": 0},
    }
    check_ceilings(record, records)
    # FRESH: refuses rather than overwriting an existing run directory (Task 55b).
    save_run(record, fresh=True)

    status, parsed, raw_body = request("POST", path, key, body)
    if status not in (200, 201, 202):
        record["state"] = "failed"
        save_run(record)
        print("[meshy] FAILED: " + describe_http_failure(status, parsed, raw_body, key))
        return 1
    task_id = (parsed or {}).get("result") or (parsed or {}).get("id")
    if isinstance(task_id, dict):
        task_id = task_id.get("id")
    if not task_id:
        record["state"] = "failed"
        save_run(record)
        print(redact(f"[meshy] FAILED: the create response carried no task id: {raw_body[:200]}",
                     key))
        return 1

    # THE ID IS STORED BEFORE THE FIRST POLL. An interruption after the POST must never orphan a
    # task that has already been paid for (asset-pipeline 7.4 step 3: same ordering, same reason).
    record["tasks"].append({"phase": "preview", "taskId": str(task_id), "status": "PENDING",
                            "createdAt": stamp(), "finishedAt": None,
                            "credits": None, "creditsSource": "unknown", "artefacts": []})
    record["state"] = "preview-running"
    record["totals"]["tasks"] = len(record["tasks"])
    save_run(record)
    print(f"[meshy] preview task {task_id} created; polling every {POLL_INTERVAL_S}s "
          f"(deadline {POLL_DEADLINE_S['preview']}s)")
    return poll_and_finish(record, key, "preview")


def poll_and_finish(record, key, phase):
    """Poll one phase to its end.

    PENDING past the deadline is NOT a failure: the task keeps running at Meshy, and a second POST
    would pay twice for the same model (design section 8)."""
    entry = record["tasks"][-1]
    # THE PATH IS THE TASK'S, NOT THE RUN'S (Task 62). A remesh task lives under
    # /openapi/v1/remesh/:id while the preview it came from lives under /openapi/v2/text-to-3d/:id,
    # so polling the run's creation endpoint would ask the wrong service for the wrong id -- a 404
    # that looks exactly like a task that never existed.
    path = ENDPOINTS[entry.get("endpoint") or record["endpoint"]] + "/" + entry["taskId"]
    deadline = time.time() + POLL_DEADLINE_S[phase]
    task = None
    consecutive = 0
    while time.time() < deadline:
        status, parsed, raw_body = request("GET", path, key)
        if status != 200:
            # A PERMANENT ERROR IS NOT "STILL RUNNING" (Task 55b). This used to print and loop to
            # the deadline, then fall out of the loop and report PENDING with exit 0 -- so a revoked
            # key (401) or a bad task id (404) looked to the operator, and to the ASSET agent's
            # report, exactly like a model that was simply taking a while. Design section 8 makes
            # only "the task is still running" a non-failure.
            message = describe_http_failure(status, parsed, raw_body, key)
            print("[meshy] " + message)
            terminal = status in (400, 401, 403, 404)
            consecutive += 1
            if terminal or consecutive >= POLL_GIVE_UP_AFTER:
                # NOT `failed`: the TASK is not what stopped -- the POLL is (Task 59 finding 1).
                # It is still running at Meshy and it is already paid for, so the record stays in a
                # state `resume` accepts. Rotate a revoked key, wait out a 5xx, then resume: the
                # only alternative was a second `preview`, which pays twice (design section 8).
                if status in (401, 403):
                    why = "the key was rejected"
                    fix = ("Rotate MESHY_API_KEY, check it with `python tools/meshy.py key "
                           "--check`, then collect this run.")
                elif terminal:
                    why = f"Meshy answered {status} for this task id"
                    fix = ("Check the id with `python tools/meshy.py runs`; if it is right, the "
                           "task may have been removed at Meshy.")
                else:
                    why = f"{consecutive} polls in a row did not answer 200"
                    fix = "Meshy is unreachable or rate-limiting; wait, then collect this run."
                return stop_resumable(record, f"{phase} cannot be polled -- {why}", fix)
            time.sleep(POLL_INTERVAL_S)
            continue
        consecutive = 0
        inner = (parsed or {}).get("result")
        task = inner if isinstance(inner, dict) else parsed
        state, done, ok, message = read_status(task)
        entry["status"] = state
        if task.get("created_at"):
            entry["createdAt"] = stamp(parse_stamp(task["created_at"]) or utc_now())
        credits = task.get("consumed_credits")
        if isinstance(credits, (int, float)):
            entry["credits"], entry["creditsSource"] = credits, "api"
        save_run(record)
        if done and ok:
            entry["finishedAt"] = stamp(parse_stamp(task.get("finished_at")) or utc_now())
            return finish_task(record, key, task, phase)
        if done and not ok:
            entry["finishedAt"] = stamp()
            record["state"] = "failed"
            record["totals"]["credits"] = sum(t.get("credits") or 0 for t in record["tasks"])
            save_run(record)
            print(redact(f"[meshy] FAILED: {record['runId']} {phase} {state} -- {message}", key))
            return 1
        progress = task.get("progress")
        print(f"[meshy] {state} {progress if progress is not None else '?'}%", flush=True)
        time.sleep(POLL_INTERVAL_S)
    state = (task or {}).get("status", "unknown")
    print(f"[meshy] PENDING: {record['runId']} {phase} {state} "
          f"(re-run: python tools/meshy.py resume {record['runId']})")
    return 0


def finish_task(record, key, task, phase):
    """A phase finished at Meshy. What that means on disk is different for each of the three."""
    if phase == "preview":
        return finish_preview(record, key, task)
    if phase == "refine":
        return finish_refine(record, key, task)
    return finish_remesh(record, key, task)


def store(entry, folder, name, blob):
    """Write one artefact and record it, REPLACING any entry of the same name (Task 59)."""
    with open(os.path.join(folder, name), "wb") as handle:
        handle.write(blob)
    entry["artefacts"] = [a for a in entry.get("artefacts", []) if a.get("name") != name]
    entry["artefacts"].append({"name": name, "sha256": hashlib.sha256(blob).hexdigest(),
                               "bytes": len(blob)})


def finish_refine(record, key, task):
    """The refine is paid for and the textures exist at Meshy; take the thumbnail now.

    The MODEL and the MAPS are collected by `fetch`, after the remesh, because the remesh is what
    decides the geometry that ships -- and `fetch` re-polls to mint fresh URLs, which is the only
    thing that works against a signed URL that has already expired."""
    folder = os.path.join(runs_dir(), record["runId"])
    os.makedirs(folder, exist_ok=True)
    entry = record["tasks"][-1]
    record["totals"]["credits"] = sum(t.get("credits") or 0 for t in record["tasks"])
    record["totals"]["tasks"] = len(record["tasks"])
    credits = entry.get("credits")

    undownloaded = []
    url = task.get("thumbnail_url")
    if url:
        try:
            store(entry, folder, "refine.png", download(url))
        except Failed as error:
            print(redact(f"[meshy] note: refine.png did not download ({error})", key))
            # OFFERED AND FAILED IS THE SAME CLASS AS THE PREVIEW'S GLB (review round 1 finding 1):
            # paid for, not collected, and re-fetchable by a re-poll. A response that carried no
            # thumbnail URL at all is a note, because there is nothing to fetch and the refine owes
            # nothing on disk -- DELIVERABLES["refine"] is empty and says so.
            undownloaded.append("refine.png")
    else:
        print("[meshy] note: the refine response carried no thumbnail URL")

    stopped = deliver(record, folder, entry, "refine", undownloaded, "refine-ready",
                      "The download URLs are signed and short-lived; resuming re-polls the same "
                      "task id and mints new ones, until the 3-day expiry.")
    if stopped is not None:
        return stopped
    print(f"[meshy] OK: refine {record['key']} v{record['version']} run={record['runId']} "
          f"credits={credits if credits is not None else 'unknown'} ({expiry_line(record)}) -- "
          f"next: python tools/meshy.py remesh {record['runId']}")
    return 0


def finish_remesh(record, key, task):
    """Remeshed. Nothing is on disk yet, and the next command is the one that matters."""
    _ = (key, task)
    entry = record["tasks"][-1]
    folder = os.path.join(runs_dir(), record["runId"])
    record["totals"]["credits"] = sum(t.get("credits") or 0 for t in record["tasks"])
    record["totals"]["tasks"] = len(record["tasks"])
    credits = entry.get("credits")
    # THROUGH THE SAME GUARD AS EVERY OTHER PAID STEP, even though this one owes nothing on disk:
    # `remesh-ready` is written in `deliver` or nowhere, so a later edit cannot mark a step done
    # without the check (review round 1). A `resume` of a fetch that stopped comes back through
    # here, and the artefacts the stopped fetch DID land stay on the entry.
    stopped = deliver(record, folder, entry, "remesh", [], "remesh-ready",
                      "The model is still at Meshy until the 3-day expiry.")
    if stopped is not None:
        return stopped
    # THE 3-DAY CLOCK IS THE WHOLE RISK HERE: the model exists only at Meshy until `fetch` runs.
    print(f"[meshy] OK: remesh {record['key']} v{record['version']} run={record['runId']} "
          f"tris={record.get('trisDeclared')} "
          f"credits={credits if credits is not None else 'unknown'} ({expiry_line(record)}) -- "
          f"FETCH IT NOW: python tools/meshy.py fetch {record['runId']}")
    return 0


def finish_preview(record, key, task):
    """Download the thumbnail and the GLB NOW: the 3-day clock started at created_at."""
    folder = os.path.join(runs_dir(), record["runId"])
    os.makedirs(folder, exist_ok=True)
    entry = record["tasks"][-1]
    wanted = [("preview.png", task.get("thumbnail_url"))]
    model_urls = task.get("model_urls") or {}
    if isinstance(model_urls, dict) and model_urls.get("glb"):
        wanted.append(("preview.glb", model_urls["glb"]))
    undownloaded = []
    for name, url in wanted:
        if not url:
            print(f"[meshy] note: the response carried no URL for {name}")
            continue
        try:
            # A RE-DOWNLOAD REPLACES, it does not append: `resume` re-polls a SUCCEEDED task and
            # comes back through here, and two entries for one file would make the record say the
            # run produced two artefacts (Task 59). `store` owns that rule for every step now.
            store(entry, folder, name, download(url))
        except Failed as error:
            print(redact(f"[meshy] note: {name} did not download ({error})", key))
            undownloaded.append(name)
    record["totals"]["credits"] = sum(t.get("credits") or 0 for t in record["tasks"])
    record["totals"]["tasks"] = len(record["tasks"])
    credits = entry.get("credits")

    # THE IMAGE IS THE POINT OF THIS PHASE, so "preview-ready" is claimed only when it is ON DISK
    # (Task 55b). Before that, a missing thumbnail URL or a failed download printed a note and then
    # told the ASSET agent to Read a path that does not exist -- and the agent is instructed to
    # describe what it sees, so the next thing in the chain was either a crash or an invention.
    # AND THE RUN STAYS COLLECTABLE (Task 59 finding 2): the task SUCCEEDED and the credits are
    # spent, a signed URL is the only thing that failed, and `resume` mints fresh ones by polling
    # the same task id. Calling it `failed` locked the operator out of an asset already paid for.
    # BOTH OF THOSE RULES NOW LIVE IN `deliver`, which every paid step goes through (Task 62 review
    # round 1): DELIVERABLES["preview"] is the image, and `undownloaded` covers the GLB -- the
    # artefact Task B needs, so a failed GLB download is the same class.
    stopped = deliver(record, folder, entry, "preview", undownloaded, "preview-ready",
                      "The download URLs are signed and short-lived; resuming re-polls the same "
                      "task id and mints new ones, until the 3-day expiry.")
    if stopped is not None:
        return stopped
    print(f"[meshy] the preview image is <runs-dir>/{record['runId']}/preview.png -- LOOK AT IT "
          "(rule 5), then ask Karen")
    print(f"[meshy] OK: preview {record['key']} v{record['version']} run={record['runId']} "
          f"credits={credits if credits is not None else 'unknown'} ({expiry_line(record)})")
    return 0


def download(url):
    """Bytes, or Failed. NO URL IS EVER PERSISTED: a signed URL expires, a task id does not."""
    try:
        with urllib.request.urlopen(url, timeout=DOWNLOAD_TIMEOUT_S) as response:
            return response.read()
    except (urllib.error.HTTPError, OSError) as error:
        raise Failed(f"{type(error).__name__}: {error}") from error


def cmd_resume(args):
    record = load_run(args.run_id)
    key, _source, why = read_key()
    if not key:
        raise Refused("MESHY_API_KEY is not set" + (f" ({why})" if why else ""))
    if record["state"] not in RESUMABLE_STATES:
        raise Refused(f"run is {record['state']}; only {' or '.join(RESUMABLE_STATES)} can be "
                      "resumed in this task")
    if expiry_line(record) == "EXPIRED":
        record["state"] = "expired"
        save_run(record)
        raise Refused("Meshy deleted the output (three days from generation); it cannot be "
                      "recovered and it cannot be regenerated identically -- there is no seed. "
                      "Write a new brief version")
    # WHICHEVER PHASE STOPPED. `resume` used to say "preview" in three places; a refine costs
    # more than a preview and it is the phase of the run's newest task that has to be continued.
    return poll_and_finish(record, key, phase_of(record))


def cmd_status(args):
    records = [load_run(args.run_id)] if args.run_id else all_runs()
    if not records:
        print("[meshy] OK: no runs recorded")
        return 0
    key, _source, _why = read_key()
    for record in records:
        print(f"[meshy] {record['runId']}: {record['state']}, "
              f"{len(record.get('tasks', []))} task(s), "
              f"credits={record.get('totals', {}).get('credits', 0)} {expiry_line(record)}")
        for task in record.get("tasks", []):
            live = ""
            if key and args.run_id and task.get("status") in STATUS_RUNNING:
                status, parsed, _raw = request(
                    "GET", ENDPOINTS[record["endpoint"]] + "/" + task["taskId"], key)
                if status == 200:
                    inner = (parsed or {}).get("result")
                    body = inner if isinstance(inner, dict) else parsed
                    live = (f" -> now {(body or {}).get('status')} "
                            f"{(body or {}).get('progress', '?')}%")
            print(f"[meshy]   {task['phase']} {task['taskId']} {task['status']} "
                  f"credits={task.get('credits', 'unknown')}({task.get('creditsSource')}){live}")
    print(f"[meshy] OK: {len(records)} run(s)")
    return 0


def cmd_runs(_args):
    records = all_runs()
    if not records:
        print("[meshy] OK: no runs recorded")
        return 0
    now = utc_now()
    for record in sorted(records, key=lambda entry: entry["runId"]):
        first = (record.get("tasks") or [{}])[0]
        created = parse_stamp(first.get("createdAt"))
        age = f"{int((now - created).total_seconds() / 3600)}h" if created else "-"
        credits = record.get("totals", {}).get("credits", 0)
        print(f"[meshy] {record['runId']:<44} {record['state']:<16} age={age:<5} "
              f"credits={credits:<4} {expiry_line(record, now)}")
    print(f"[meshy] OK: {len(records)} run(s), "
          f"{tasks_today(records, now)}/{MAX_TASKS_PER_DAY} task(s) in the last 24 h")
    return 0


def cmd_approve(args):
    record = load_run(args.run_id)
    if record.get("approval"):
        # Idempotent on purpose: approving twice is not an error and does not move the record.
        print(f"[meshy] OK: {args.run_id} was already approved by "
              f"{record['approval'].get('by')} at {record['approval'].get('at')}")
        return 0
    require_state(record, "preview-ready")
    preview_sha = ""
    for task in record.get("tasks", []):
        for artefact in task.get("artefacts", []):
            if artefact.get("name") == "preview.png":
                preview_sha = artefact.get("sha256", "")
    record["approval"] = {"by": args.by, "at": stamp(), "previewSha256": preview_sha,
                          "note": args.note or ""}
    record["state"] = "approved"
    save_run(record)
    # HONEST ABOUT WHAT THIS ENFORCES (design 6.3). The STATE gate is real: refine, when Task B
    # builds it, refuses a run without this record. WHO TYPED IT is not enforced, because the agent
    # has a shell. What is enforced against the real risk -- money -- is the ceilings.
    print(f"[meshy] OK: {args.run_id} approved by {args.by} (the state gate is enforced; who typed "
          "it is recorded, not proved)")
    return 0


# ---------------------------------------------------------------- step 2: refine, remesh, fetch
#
# THE SECOND HALF OF THE FLOW (design section 3): Karen's OK on the preview is behind us, so from
# here every command spends real credits on a model she has already looked at -- and stops at the
# SECOND stop point, a look at the finished, textured model, before anything is uploaded anywhere.
# Nothing in this file has ever contained a Roblox endpoint and nothing here adds one.


def start_task(record, key, phase, path, body, endpoint):
    """POST one phase's task, record its id BEFORE the first poll, then poll it to its end.

    THE ID IS STORED FIRST for the same reason the preview stores it first: an interruption after
    the POST must never orphan a task that has already been paid for."""
    status, parsed, raw_body = request("POST", path, key, body)
    if status not in (200, 201, 202):
        record["state"] = "failed"
        save_run(record)
        print("[meshy] FAILED: " + describe_http_failure(status, parsed, raw_body, key))
        return 1
    task_id = (parsed or {}).get("result") or (parsed or {}).get("id")
    if isinstance(task_id, dict):
        task_id = task_id.get("id")
    if not task_id:
        record["state"] = "failed"
        save_run(record)
        print(redact(f"[meshy] FAILED: the {phase} response carried no task id: {raw_body[:200]}", key))
        return 1

    record["tasks"].append({"phase": phase, "taskId": str(task_id), "status": "PENDING",
                            "endpoint": endpoint, "createdAt": stamp(), "finishedAt": None,
                            "credits": None, "creditsSource": "unknown", "artefacts": []})
    record["state"] = f"{phase}-running"
    record["totals"]["tasks"] = len(record["tasks"])
    save_run(record)
    print(f"[meshy] {phase} task {task_id} created; polling every {POLL_INTERVAL_S}s "
          f"(deadline {POLL_DEADLINE_S[phase]}s)")
    return poll_and_finish(record, key, phase)


def cmd_refine(args):
    record = load_run(args.run_id)
    key, _source, why = read_key()
    if not key and not args.dry_run:
        raise Refused("MESHY_API_KEY is not set" + (f" ({why})" if why else ""))
    # KAREN'S OK IS A STATE, and this is the gate the money needs (design section 6.3). `approve`
    # is what writes it, and it is the only way into this half of the flow.
    require_state(record, "approved")
    if record["endpoint"] != "text-to-3d":
        raise Refused(f"refine is the v2 text-to-3d refine and this run is {record['endpoint']}; "
                      "an image-to-3d run is textured by its own creation call")
    if expiry_line(record) == "EXPIRED":
        record["state"] = "expired"
        save_run(record)
        raise Refused("Meshy deleted the preview (three days from generation), so there is nothing "
                      "left to refine. Write a new brief version")

    texture_px = (record.get("brief") or {}).get("texturePx") or TEXTURE_PX_DEFAULT
    if texture_px not in TEXTURE_PX_ALLOWED:
        raise Refused(f"texturePx {texture_px} is not one of {TEXTURE_PX_ALLOWED}")
    path, body = build_refine_request(record, texture_px)

    if args.dry_run:
        print(f"[meshy] DRY RUN, nothing sent. POST {BASE_URL}{path}")
        print("[meshy] headers: Authorization: Bearer ***, Content-Type: application/json")
        print("[meshy] body: " + json.dumps(body, indent=2, sort_keys=True))
        print(f"[meshy] OK: dry-run refine {record['key']} v{record['version']} credits=0")
        return 0

    check_ceilings(record, all_runs())
    return start_task(record, key, "refine", path, body, "text-to-3d")


def cmd_remesh(args):
    record = load_run(args.run_id)
    key, _source, why = read_key()
    if not key and not args.dry_run:
        raise Refused("MESHY_API_KEY is not set" + (f" ({why})" if why else ""))
    # THE ORDINARY DOOR IS `refine-ready`. A FETCHED RUN WHOSE LOCAL CHECKS FAILED comes back
    # through here too (review round 1 finding 2): when the geometry is what was wrong, the route
    # the FAILED line names is the replacement task MAX_TASKS_PER_RUN was sized for. A fetched run
    # that PASSED its checks is still refused by name -- re-cutting it would spend credits for
    # nothing -- and `check_ceilings` below is what stops this from becoming a loop.
    if not (record.get("state") == "fetched"
            and (record.get("validation") or {}).get("ok") is False):
        require_state(record, "refine-ready")
    if expiry_line(record) == "EXPIRED":
        record["state"] = "expired"
        save_run(record)
        raise Refused("Meshy deleted the refined model (three days from generation). Write a new "
                      "brief version")

    target = resolve_target(record, args.target)
    path, body = build_remesh_request(record, target)

    if args.dry_run:
        print(f"[meshy] DRY RUN, nothing sent. POST {BASE_URL}{path}")
        print("[meshy] headers: Authorization: Bearer ***, Content-Type: application/json")
        print("[meshy] body: " + json.dumps(body, indent=2, sort_keys=True))
        print(f"[meshy] OK: dry-run remesh {record['key']} v{record['version']} tris={target} credits=0")
        return 0

    check_ceilings(record, all_runs())
    # DECLARED, AND WRITTEN DOWN BEFORE THE TASK RUNS. The remesh response carries no polycount
    # (research note D5), so this number is the claim the sidecar will carry, and it has to be the
    # number that was SENT rather than one somebody types later.
    record["trisDeclared"] = target
    save_run(record)
    return start_task(record, key, "remesh", path, body, "remesh")


def validate_fetched(record, folder, entry):
    """Everything that can honestly be checked locally. Returns a list of `Problem`, possibly empty.

    EVERY PROBLEM CARRIES ITS ROUTE OUT (Task 62, review round 1 finding 2), because `deliver` has
    to decide from these whether the run is re-fetchable, re-cuttable, or a human's to judge -- and
    a problem with no route was exactly how a paid run got stranded in `fetched`.

    WHAT IS NOT CHECKED, said plainly (design section 7.3): the triangle count. There is no honest
    local count without an FBX parser, and a hand-written FBX parser is one of the three named
    causes of death of the previous project (docs/PROJECT_CONTEXT.md). Meshy remeshes to the target
    this tool SENT, `trisDeclared` records it, and Roblox's importer is the enforcer."""
    problems = []
    written = {artefact["name"]: artefact for artefact in entry.get("artefacts", [])}

    fbx = written.get("model.fbx")
    if fbx is None:
        problems.append(Problem("model.fbx is missing: it is the one file the pipeline promotes",
                                "refetch"))
    else:
        if fbx["bytes"] <= 0:
            problems.append(Problem("model.fbx is empty", "refetch"))
        if fbx["bytes"] > MAX_FILE_BYTES:
            # THE BYTES ARE WHAT MESHY SENT and the model is too heavy for Roblox: downloading it
            # again produces the same file. Fewer triangles is the only thing that shrinks it.
            problems.append(Problem(f"model.fbx is {fbx['bytes']} bytes, over Roblox's per-call "
                                    f"{MAX_FILE_BYTES}", "remesh"))

    budget = (record.get("brief") or {}).get("texturePx") or TEXTURE_PX_DEFAULT
    for name, artefact in sorted(written.items()):
        path = os.path.join(folder, name)
        if not os.path.isfile(path):
            problems.append(Problem(f"{name} is in the record but not on disk", "refetch"))
            continue
        with open(path, "rb") as handle:
            blob = handle.read()
        # A TRUNCATED DOWNLOAD IS THE 3-DAY TRAP'S CRUELLEST FORM: the file exists, the run looks
        # finished, and the bytes are wrong. The hash is of what was downloaded; this re-reads.
        if hashlib.sha256(blob).hexdigest() != artefact["sha256"]:
            problems.append(Problem(f"{name} on disk does not match the sha256 that was downloaded",
                                    "refetch"))
        if name.endswith(".png"):
            try:
                width, height = png_size(blob)
            except Failed as error:
                # A PNG WHOSE HEADER WILL NOT READ is a half-arrived download far more often than
                # it is a file Meshy got wrong, so the route is the one that downloads it again.
                problems.append(Problem(f"{name}: {error}", "refetch"))
                continue
            if width > budget or height > budget:
                # NOTHING IS BROKEN HERE: the maps arrived and they are bigger than the brief said
                # to ask for. No command changes that -- `texturePx` is a written number.
                problems.append(Problem(f"{name} is {width}x{height}, over the brief's texturePx "
                                        f"{budget}", "brief"))

    if not record.get("trisDeclared"):
        problems.append(Problem("trisDeclared is missing: the remesh target was never recorded",
                                "remesh"))
    return problems


def texture_set(task):
    """The first PBR map set in a task response, whichever of Meshy's two shapes it uses.

    `texture_urls` is a dict in some of Meshy's examples and a LIST of map sets (one per material)
    in others, so both are read rather than assumed. Several materials means only the first set is
    fetched, which is queued as 62a."""
    urls = task.get("texture_urls") or {}
    if isinstance(urls, list):
        urls = urls[0] if urls and isinstance(urls[0], dict) else {}
    return urls if isinstance(urls, dict) else {}


def cmd_fetch(args):
    record = load_run(args.run_id)
    key, _source, why = read_key()
    if not key:
        raise Refused("MESHY_API_KEY is not set" + (f" ({why})" if why else ""))
    # TWO DOORS, BOTH PAID FOR (review round 1 finding 2). `remesh-ready` is the ordinary one;
    # `remesh-unresolved` is a fetch that already ran and landed too little, or landed bytes that
    # did not match their hash -- and re-fetching is exactly what mints fresh URLs and downloads
    # them again. So the command every STOPPED line here names is one this command accepts.
    require_state_in(record, ("remesh-ready", "remesh-unresolved"))
    if expiry_line(record) == "EXPIRED":
        record["state"] = "expired"
        save_run(record)
        raise Refused("Meshy deleted the output (three days from generation); it cannot be "
                      "recovered and it cannot be regenerated identically -- there is no seed. "
                      "Write a new brief version")

    entry = record["tasks"][-1]
    # RE-POLLED, NOT REMEMBERED. No URL is ever persisted: a signed URL expires and a task id does
    # not, so the fresh URLs come from a GET -- which costs no credits.
    path = ENDPOINTS[entry.get("endpoint") or "remesh"] + "/" + entry["taskId"]
    status, parsed, raw_body = request("GET", path, key)
    if status != 200:
        return stop_resumable(
            record,
            "could not be re-polled for fresh download URLs -- "
            + describe_http_failure(status, parsed, raw_body, key),
            "The model is still at Meshy until the 3-day expiry.")
    inner = (parsed or {}).get("result")
    task = inner if isinstance(inner, dict) else (parsed or {})
    # SUCCEEDED, OR THERE IS NOTHING TO DOWNLOAD YET. `remesh-unresolved` also covers a poll that
    # gave up while the task was still running at Meshy, and "no URL in the response" would be the
    # wrong thing to say about a task that has not finished. `resume` is the route for that one.
    state, done, succeeded, message = read_status(task)
    if not (done and succeeded):
        return stop_resumable(
            record,
            f"is {state} at Meshy, so there is nothing to download yet"
            + (f" -- {message}" if message else ""),
            "Poll it to the end first; the credits are already spent and the task keeps running.")

    folder = os.path.join(runs_dir(), record["runId"])
    os.makedirs(folder, exist_ok=True)
    model_urls = task.get("model_urls") or {}
    maps, source = texture_set(task), "remesh"
    if not maps:
        # THE MAPS BELONG TO THE REFINE, WHICH IS WHAT WAS PAID FOR THEM (review round 1 finding 1).
        # docs/research/2026-09-26-meshy.md source 3 records that the remesh response carries
        # `model_urls` and no statistics field; it never quotes `texture_urls` for that endpoint, so
        # an empty set here is the DOCUMENTED case rather than a fault. The refine task's response
        # is the one that documents the maps, and re-polling it is a GET, which costs no credits.
        refine = task_of(record, "refine")
        if refine and refine.get("taskId"):
            refine_path = (ENDPOINTS[refine.get("endpoint") or "text-to-3d"] + "/"
                           + refine["taskId"])
            r_status, r_parsed, r_raw = request("GET", refine_path, key)
            if r_status == 200:
                r_inner = (r_parsed or {}).get("result")
                maps = texture_set(r_inner if isinstance(r_inner, dict) else (r_parsed or {}))
                source = "refine"
            else:
                print(redact("[meshy] note: the refine task could not be re-polled for map URLs -- "
                             + describe_http_failure(r_status, r_parsed, r_raw, key), key))
    if maps:
        print(f"[meshy] note: the PBR maps come from the {source} task's response")

    wanted = []
    for name, field in MODEL_FILES:
        if isinstance(model_urls, dict) and model_urls.get(field):
            wanted.append((name, model_urls[field]))
    for field in TEXTURE_FILES:
        if maps.get(field):
            wanted.append((f"texture_{field}.png", maps[field]))

    undownloaded = []
    for name, url in wanted:
        try:
            store(entry, folder, name, download(url))
        except Failed as error:
            print(redact(f"[meshy] note: {name} did not download ({error})", key))
            undownloaded.append(name)

    record["totals"]["credits"] = sum(t.get("credits") or 0 for t in record["tasks"])
    save_run(record)

    # THE ONE GUARD, and the second stop point is behind it: `fetched` is written only when the FBX
    # and at least one PBR map are on disk, nothing that was offered failed, and every local check
    # passed (review round 1 finding 1 -- a fetch that landed no map at all used to exit 0 and
    # invite Karen to look at a model the refine had just been paid to texture).
    stopped = deliver(record, folder, entry, "fetch", undownloaded, "fetched",
                      "The download URLs are signed and short-lived; fetching again re-polls the "
                      "same task ids and mints new ones, until the 3-day expiry.",
                      command="fetch", validate=validate_fetched)
    if stopped is not None:
        return stopped
    written = {artefact["name"] for artefact in entry.get("artefacts", [])}

    # THE SECOND STOP POINT (design section 3). Everything after this -- a sidecar, an upload, a
    # MeshPart -- waits for a human to look at the model. This tool cannot upload anything: it
    # contains no Roblox endpoint at all.
    print(f"[meshy] the model is <runs-dir>/{record['runId']}/model.fbx with "
          f"{len(written)} file(s) beside it -- OPEN IT AND LOOK AT IT (rule 5), then ask Karen. "
          "Nothing is uploaded until she says yes.")
    print(f"[meshy] OK: fetch {record['key']} v{record['version']} run={record['runId']} "
          f"tris={record.get('trisDeclared')} files={len(written)} "
          f"credits={record['totals']['credits']} ({expiry_line(record)})")
    return 0


# ---------------------------------------------------------------- selftest (offline, no key)


FAKE_KEY = "msy_" + "S3lFt3sTnOtArEaLkEy" + "0123456789abcdef"

GOOD_BRIEF = {
    "key": "boar.body",
    "version": 1,
    "kind": "meshpart",
    "prompt": "An adult male European wild boar, standing.",
    "references": [],
    "sizeMetres": [0.56, 0.84, 1.54],
    "targetTris": 6000,
    "texturePx": 2048,
}

# FROZEN EXPECTED REQUEST (design 13.1 case 2). A later edit to the builder shows up here as a diff,
# which is the whole point: the body is what costs money and what decides the model.
EXPECTED_TEXT_BODY = {
    "mode": "preview",
    "prompt": "An adult male European wild boar, standing.",
    "should_remesh": True,
    "target_polycount": 6000,
    "topology": "triangle",
}
DEPRECATED = ("art_style", "negative_prompt", "symmetry", "seed", "rig", "rigging")


def selftest():
    """Offline: validators, builders, parsers, the state machine, the ceilings, the expiry
    arithmetic, and -- the two that matter most -- key redaction and no-local-path, both asserted
    over the FULL rendered output rather than over one string (design section 13.1)."""
    failures = []

    def ok(name, condition, detail=""):
        if not condition:
            failures.append(f"{name}{': ' + detail if detail else ''}")

    def refusal(callable_, name):
        """The reason, not just the exit code: every case asserts WHY it was refused."""
        try:
            callable_()
        except Refused as error:
            return str(error)
        except Exception as error:  # noqa: BLE001 -- any other exception is itself the failure
            failures.append(f"{name}: raised {type(error).__name__} instead of Refused: {error}")
            return ""
        failures.append(f"{name}: was NOT refused")
        return ""

    # 1. The brief name grammar, derived and never prompted.
    ok("a good name parses", parse_brief_name("boar.body_v1.brief.json") == ("boar.body", 1))
    ok("a bare name parses", parse_brief_name("shotgun.handle_v12") == ("shotgun.handle", 12))
    for bad, why in (("boar.body", "no _v"), ("boar.body_vx", "not a version number"),
                     ("Boar.body_v1", "not [a-z][a-z0-9]*"), ("boar..body_v1", "not [a-z][a-z0-9]*"),
                     ("_v1", "the key is empty"), ("boar.body_v0", "not a version number")):
        said = refusal(lambda name=bad: parse_brief_name(name), f"name {bad!r}")
        ok(f"name {bad!r} is refused for the right reason", why in said, said)

    # 2. The brief validator: every refusal in design 4.1, each naming its own reason.
    ok("a good brief passes",
       validate_brief(dict(GOOD_BRIEF), "boar.body_v1.brief.json")["targetTris"] == 6000)
    cases = [
        ({"key": "other.thing"}, "file name derives"),
        ({"version": 7}, "file name derives"),
        ({"kind": "sculpture"}, "is not one of"),
        ({"prompt": "   "}, "`prompt` is empty"),
        ({"references": ["a.png", "b.png", "c.png", "d.png", "e.png"]}, "Meshy accepts 1 to 4"),
        ({"references": ["sub/dir.png"]}, "must be a file NAME"),
        ({"references": ["notes.pdf"]}, "is not one of"),
        ({"references": ["render.gif"]}, "is not one of"),
        ({"texturePx": "2048"}, "is not an integer"),
        ({"texturePx": True}, "is not an integer"),
        ({"texturePx": 16384}, "is not one of"),
        ({"texturePx": 700}, "is not one of"),
        ({"targetTris": True}, "is not an integer"),
        ({"sizeMetres": [1, 2]}, "three positive numbers"),
        ({"sizeMetres": "big"}, "three positive numbers"),
        ({"targetTris": REMESH_CEILING + 1}, "over REMESH_CEILING"),
        ({"targetTris": 12}, "Meshy's floor"),
    ]
    for patch, why in cases:
        broken = dict(GOOD_BRIEF)
        broken.update(patch)
        said = refusal(lambda data=broken: validate_brief(data, "boar.body_v1.brief.json"),
                       f"brief {list(patch)[0]}")
        ok(f"a bad {list(patch)[0]} is refused for the right reason", why in said, said)
    said = refusal(lambda: validate_brief(dict(GOOD_BRIEF, references=["missing.png"]),
                                          "boar.body_v1.brief.json", {"other.png"}),
                   "a reference not in briefs/")
    ok("a missing reference is named", "is not in docs/asset-briefs" in said, said)

    # THE THREE FORMATS THE DIRECTOR ACCEPTED (row 55a(a)): Karen's photographs are JPEG and WebP.
    for suffix in (".png", ".jpg", ".jpeg", ".webp"):
        name = "ref" + suffix
        brief = dict(GOOD_BRIEF, references=[name])
        resolved_one = validate_brief(brief, "boar.body_v1.brief.json", {name})
        ok(f"a {suffix} reference is accepted", resolved_one["key"] == "boar.body")
        ok(f"a {suffix} data URI announces its own media type",
           data_uri(b"bytes", name).startswith("data:" + DATA_URI_TYPE[suffix] + ";base64,"),
           data_uri(b"bytes", name)[:40])
    said = refusal(lambda: data_uri(b"bytes", "model.fbx"), "an unknown media type")
    ok("an unknown suffix has no data URI", "no known media type" in said, said)

    # And every allowed texture size passes, or the refusals above are only half the rule.
    for size in TEXTURE_PX_ALLOWED:
        got = validate_brief(dict(GOOD_BRIEF, texturePx=size), "boar.body_v1.brief.json")
        ok(f"texturePx {size} is accepted", got["texturePx"] == size, str(got["texturePx"]))
    ok("texturePx defaults when absent",
       validate_brief({k: v for k, v in GOOD_BRIEF.items() if k != "texturePx"},
                      "boar.body_v1.brief.json")["texturePx"] == TEXTURE_PX_DEFAULT)

    # 3. The endpoint is DATA, not a flag, and the body carries nothing deprecated.
    ok("0 references -> text", choose_endpoint([]) == "text-to-3d")
    ok("1 reference -> image", choose_endpoint(["a.png"]) == "image-to-3d")
    ok("3 references -> multi-image", choose_endpoint(["a.png", "b.png", "c.png"])
       == "multi-image-to-3d")
    resolved = validate_brief(dict(GOOD_BRIEF), "boar.body_v1.brief.json")
    endpoint, path, body = build_preview_request(GOOD_BRIEF, resolved, [])
    ok("the text body is exactly the frozen fixture", body == EXPECTED_TEXT_BODY,
       json.dumps(body, sort_keys=True))
    ok("the text path is the documented one", path == "/openapi/v2/text-to-3d", path)
    # EVERY body, collected -- not just the last loop iteration (Task 55b). The old code checked
    # `(body, got_body)`, and `got_body` was whatever the loop happened to leave behind, so the
    # 1-reference image-to-3d body was never checked for a deprecated field at all.
    built = [body]
    for count, wanted_endpoint, field in ((1, "image-to-3d", "image_url"),
                                          (3, "multi-image-to-3d", "image_urls")):
        brief = dict(GOOD_BRIEF, references=[f"r{index}.png" for index in range(count)])
        got_endpoint, got_path, got_body = build_preview_request(
            brief, validate_brief(brief, "boar.body_v1.brief.json",
                                  {f"r{index}.png" for index in range(count)}),
            [f"data:image/png;base64,AAA{index}" for index in range(count)])
        built.append(got_body)
        ok(f"{count} reference(s) -> {wanted_endpoint}", got_endpoint == wanted_endpoint)
        ok(f"{wanted_endpoint} sends {field}", field in got_body, json.dumps(got_body))
        ok(f"{wanted_endpoint} path is documented", got_path == ENDPOINTS[wanted_endpoint])
        ok(f"{wanted_endpoint} asks for triangles", got_body.get("topology") == "triangle")
    ok("all three endpoints were built", len(built) == 3, str(len(built)))
    for index, bodies in enumerate(built):
        for field in DEPRECATED:
            ok(f"no deprecated field {field} in body {index}", field not in bodies,
               json.dumps(bodies))

    # 4. The status parser. An UNKNOWN value is NOT success; a MISSING status fails loudly.
    ok("SUCCEEDED succeeds", read_status({"status": "SUCCEEDED"}) == ("SUCCEEDED", True, True, ""))
    state, done, good, message = read_status(
        {"status": "FAILED", "task_error": {"message": "the prompt was rejected"}})
    ok("FAILED is terminal and not ok", (state, done, good) == ("FAILED", True, False))
    ok("the FAILED message is extracted", message == "the prompt was rejected", message)
    state, done, good, _ = read_status({"status": "CANCELED"})
    ok("CANCELED is terminal and not ok -- the fifth value the brief never named",
       (state, done, good) == ("CANCELED", True, False))
    for running in ("PENDING", "IN_PROGRESS"):
        ok(f"{running} is not done", read_status({"status": running})[1:3] == (False, False))
    state, done, good, message = read_status({"status": "SOMETHING_NEW"})
    ok("an unknown status is NOT success", good is False and done is False)
    ok("an unknown status says so", "unknown status" in message, message)
    try:
        read_status({"progress": 50})
        failures.append("a missing status did not fail loudly")
    except Failed as error:
        ok("a missing status fails loudly", "no `status` field" in str(error), str(error))

    # 5. Key redaction, asserted over EVERY line this tool can render, not over one string.
    rendered = [
        redact(f"Authorization: Bearer {FAKE_KEY}", FAKE_KEY),
        redact(f"the request did not complete: key={FAKE_KEY}", FAKE_KEY),
        describe_http_failure(401, {"message": f"bad key {FAKE_KEY}"}, "", FAKE_KEY),
        describe_http_failure(403, None, f"raw body with {FAKE_KEY} in it", FAKE_KEY),
        describe_http_failure(500, None, "", FAKE_KEY),
        redact(str(Failed(f"boom {FAKE_KEY}")), FAKE_KEY),
        f"[meshy] MESHY_API_KEY: set, fingerprint {fingerprint(FAKE_KEY)}, source=environment",
    ]
    for index, line in enumerate(rendered):
        ok(f"rendered line {index} carries no key", FAKE_KEY not in line, line)
    ok("the fingerprint is 8 hex and not the key",
       len(fingerprint(FAKE_KEY)) == 8 and fingerprint(FAKE_KEY) not in FAKE_KEY)
    ok("redact survives a None key", redact("nothing to hide", None) == "nothing to hide")

    # 6. The ceilings, at the boundary and one past it, from fixture records.
    def record_with(count, hours_ago=0):
        when = stamp(utc_now() - datetime.timedelta(hours=hours_ago))
        return {"runId": "x", "tasks": [{"phase": "preview", "createdAt": when}] * count}

    check_ceilings(record_with(MAX_TASKS_PER_RUN - 1), [])
    said = refusal(lambda: check_ceilings(record_with(MAX_TASKS_PER_RUN), []), "per-run ceiling")
    ok("MAX_TASKS_PER_RUN refuses at the boundary", "MAX_TASKS_PER_RUN" in said, said)
    day = [record_with(MAX_TASKS_PER_DAY)]
    said = refusal(lambda: check_ceilings(record_with(0), day), "per-day ceiling")
    ok("MAX_TASKS_PER_DAY refuses at the boundary", "MAX_TASKS_PER_DAY" in said, said)
    ok("a task from 25 h ago does not count", tasks_today([record_with(5, hours_ago=25)]) == 0)
    ok("a task from 1 h ago counts", tasks_today([record_with(5, hours_ago=1)]) == 5)

    # 7. Expiry arithmetic, from created_at (note D9), at 71 h, 73 h and fresh.
    def aged(hours):
        return {"tasks": [{"createdAt": stamp(utc_now() - datetime.timedelta(hours=hours))}]}

    ok("71 h old warns", expiry_line(aged(71)) == "EXPIRES IN 0h", expiry_line(aged(71)))
    ok("73 h old is EXPIRED", expiry_line(aged(73)) == "EXPIRED", expiry_line(aged(73)))
    ok("50 h old warns", expiry_line(aged(50)).startswith("EXPIRES IN"), expiry_line(aged(50)))
    ok("1 h old does not warn", expiry_line(aged(1)).startswith("expires "), expiry_line(aged(1)))
    ok("a run with no task has no expiry", expiry_line({"tasks": []}) == "")

    # 8. The state machine refuses every wrong state BY NAME.
    for state in STATES:
        if state == "preview-ready":
            continue
        said = refusal(lambda value=state: require_state({"state": value}, "preview-ready"),
                       f"state {state}")
        ok(f"{state} is refused by name", state in said and "preview-ready" in said, said)

    # 9. Nothing this tool prints carries a local path or an email -- checked against CI's own rules
    # by importing them, so the tool's stdout is held to the standard before it can be pasted.
    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import privacy_scan  # noqa: PLC0415 -- imported here so selftest is the only user
    except ImportError as error:  # pragma: no cover
        failures.append(f"could not import privacy_scan to check output: {error}")
        privacy_scan = None
    if privacy_scan is not None:
        surface = "\n".join(rendered + [
            __doc__ or "",
            "[meshy] the preview image is <runs-dir>/boar.body_v1-20260926T1412Z/preview.png",
            "[meshy] OK: preview boar.body v1 run=boar.body_v1-20260926T1412Z credits=5",
            "[meshy] REFUSED: ASSET_DROP_DIR is not set. It is Karen's drop folder, OUTSIDE the repo",
            json.dumps(LICENCE), json.dumps(EXPECTED_TEXT_BODY),
        ])
        found = privacy_scan.findings_in(surface)
        ok("no rule of tools/privacy_scan.py fires on this tool's own output",
           not found, "; ".join(f"{name}:{text}" for name, _line, _why, text in found))
        # And the new rule must actually catch a key, or case 5 is guarding nothing in CI.
        caught = {name for name, _line, _why, _text in privacy_scan.findings_in(FAKE_KEY)}
        ok("privacy_scan catches a msy_ key", "meshy-key" in caught, str(sorted(caught)))

    # THE SECOND HALF'S REQUESTS (Task 62), frozen the same way the preview's body is: this is
    # what costs money and what decides the model, so an edit to a builder shows up here as a diff.
    refineRecord = {
        "runId": "boar.body_v1-20260101T0009Z", "key": "boar.body", "version": 1,
        "brief": dict(GOOD_BRIEF), "endpoint": "text-to-3d", "state": "approved",
        "tasks": [{"phase": "preview", "taskId": "prev-1", "endpoint": "text-to-3d"}],
        "totals": {"tasks": 1, "credits": 5},
    }
    refinePath, refineBody = build_refine_request(refineRecord, GOOD_BRIEF["texturePx"])
    ok("refine posts to the v2 text-to-3d endpoint", refinePath == ENDPOINTS["text-to-3d"], refinePath)
    ok("refine asks for exactly the documented four fields",
       refineBody == {"mode": "refine", "preview_task_id": "prev-1", "enable_pbr": True,
                      "texture_resolution": 2048},
       json.dumps(refineBody, sort_keys=True))
    for field in DEPRECATED:
        ok(f"refine sends no {field}", field not in refineBody)
    said = refusal(lambda: build_refine_request({"tasks": []}, 2048), "refine with no preview")
    ok("refine with no preview task is refused", "no preview task" in said, said)

    remeshRecord = dict(refineRecord)
    remeshRecord["tasks"] = [
        {"phase": "preview", "taskId": "prev-1", "endpoint": "text-to-3d"},
        {"phase": "refine", "taskId": "ref-1", "endpoint": "text-to-3d"},
    ]
    remeshPath, remeshBody = build_remesh_request(remeshRecord, 6000)
    ok("remesh posts to the v1 remesh endpoint", remeshPath == ENDPOINTS["remesh"], remeshPath)
    # THE REFINE'S TASK, NOT THE PREVIEW'S: remeshing the preview would throw away the textures
    # that were just paid for.
    ok("remesh takes the REFINED task as its input",
       remeshBody == {"input_task_id": "ref-1", "target_polycount": 6000, "topology": "triangle"},
       json.dumps(remeshBody, sort_keys=True))

    ok("the target comes from the brief", resolve_target(remeshRecord, None) == 6000)
    ok("--target wins over the brief", resolve_target(remeshRecord, 4000) == 4000)
    noBrief = dict(remeshRecord)
    noBrief["brief"] = {}
    ok("a key with no brief target falls back to REMESH_TARGETS",
       resolve_target(noBrief, None) == REMESH_TARGETS["boar.body"])
    unknown = dict(noBrief)
    unknown["key"] = "not.a.known.key"
    ok("an unknown key falls back to the ceiling", resolve_target(unknown, None) == REMESH_CEILING)
    for bad, why in ((REMESH_MIN - 1, "outside"), (REMESH_MAX + 1, "outside"),
                     (REMESH_CEILING + 1, "REMESH_CEILING"), (True, "not an integer"),
                     ("6000", "not an integer")):
        said = refusal(lambda value=bad: resolve_target(remeshRecord, value), f"target {bad!r}")
        ok(f"the target {bad!r} is refused for the right reason", why in said, said)

    # THE PNG HEADER READER: 24 bytes, no library (asset-pipeline section 7.3 item 5).
    def fake_png(width, height):
        return (b"\x89PNG\r\n\x1a\n" + (13).to_bytes(4, "big") + b"IHDR"
                + width.to_bytes(4, "big") + height.to_bytes(4, "big") + b"\x08\x06\x00\x00\x00"
                + b"0" * 64)

    ok("png_size reads the IHDR", png_size(fake_png(2048, 1024)) == (2048, 1024),
       str(png_size(fake_png(2048, 1024))))
    for blob, why in ((b"not a png at all, really not", "signature"),
                      (b"\x89PNG\r\n\x1a\n" + (13).to_bytes(4, "big") + b"IDAT" + b"0" * 32, "IHDR")):
        try:
            png_size(blob)
            failures.append(f"png_size accepted {blob[:12]!r}")
        except Failed as error:
            ok(f"png_size refuses {blob[:6]!r}", why in str(error), str(error))

    # 10. The licence basis is the only one this tool can produce, and it is quoted, not paraphrased.
    ok("licence basis is meshy-paid-owned", LICENCE["basis"] == "meshy-paid-owned")
    ok("the licence quote is the paid-plan sentence",
       LICENCE["quote"] == "such customers on a paid Meshy plan own their Customer Output.")
    ok("the licence names where it was read", LICENCE["quotedFrom"].startswith("https://"))

    # 11. The remesh target is inside Meshy's documented range and under Roblox's hard limit.
    for key, target in REMESH_TARGETS.items():
        ok(f"{key}'s target is in Meshy's 100-300000 range", 100 <= target <= 300000, str(target))
        ok(f"{key}'s target is under Roblox's 20000", target < 20000, str(target))
    ok("REMESH_CEILING is under Roblox's hard limit", REMESH_CEILING < 20000)

    # ON-DISK BEHAVIOUR, in a temporary run directory -- no key, no network. These three are what
    # Task 55b exists for, and none of them could be tested without a run folder.
    import shutil  # noqa: PLC0415 -- only this block needs them
    import tempfile  # noqa: PLC0415
    sandbox = tempfile.mkdtemp(prefix="meshy-selftest-")
    previous = os.environ.get("MESHY_RUN_DIR")
    previous_key = os.environ.get("MESHY_API_KEY")
    os.environ["MESHY_RUN_DIR"] = sandbox
    try:
        record = {
            "runId": "boar.body_v1-20260101T0000Z", "key": "boar.body", "version": 1,
            "brief": dict(GOOD_BRIEF), "briefSha256": "0" * 64, "briefFile": "x",
            "endpoint": "text-to-3d", "state": "brief-ok", "tasks": [], "approval": None,
            "licence": dict(LICENCE), "totals": {"tasks": 0, "credits": 0},
        }
        save_run(record, fresh=True)
        ok("a fresh run writes its record", os.path.isfile(run_path(record["runId"])))
        # A SECOND fresh save of the same id must REFUSE: run ids are minute-resolution, and
        # overwriting one orphans a task that has already been paid for.
        said = refusal(lambda: save_run(dict(record), fresh=True), "a second fresh run")
        ok("a second fresh run with the same id is refused",
           "already exists" in said and "paid for" in said, said)
        # ...and a plain save (a state transition on a run that exists) still works.
        record["state"] = "preview-running"
        save_run(record)
        ok("a state transition still saves", load_run(record["runId"])["state"] == "preview-running")

        # approve twice is idempotent (design 13.1 item 5), and it refuses a wrong state.
        class Args:
            def __init__(self, **fields):
                self.__dict__.update(fields)

        said = refusal(lambda: cmd_approve(Args(run_id=record["runId"], by="karen", note="")),
                       "approve on preview-running")
        ok("approve refuses a run that is not preview-ready",
           "preview-running" in said and "preview-ready" in said, said)
        record["state"] = "preview-ready"
        save_run(record)
        ok("approve succeeds on preview-ready",
           cmd_approve(Args(run_id=record["runId"], by="karen", note="first")) == 0)
        first = load_run(record["runId"])["approval"]
        ok("approve twice is idempotent",
           cmd_approve(Args(run_id=record["runId"], by="someone-else", note="second")) == 0)
        again = load_run(record["runId"])["approval"]
        ok("the second approve changed nothing", again == first, json.dumps(again))

        # A PERMANENT POLL ERROR STOPS THE RUN -- AND LEAVES IT COLLECTABLE. Task 55b made a 401
        # or a 404 stop instead of looping to the 600 s deadline (a revoked key looked exactly like
        # a model that was taking a while). Task 59's review then found that stopping wrote
        # `failed`, which `resume` refuses -- so a task already paid for could never be collected
        # by the tool again. Both halves are asserted from here down: it stops on the FIRST
        # permanent error, and `resume` still picks the run up afterwards. `request` and `download`
        # are swapped for fakes, so no key, no network and no credits are involved.
        import contextlib  # noqa: PLC0415 -- only this block captures stdout
        import io as stdlib_io  # noqa: PLC0415

        def say(callable_):
            """Run it; return (exit code, everything it printed)."""
            buffer = stdlib_io.StringIO()
            with contextlib.redirect_stdout(buffer):
                code = callable_()
            return code, buffer.getvalue()

        def fake_succeeded(_method, _path, _key, body=None, timeout=HTTP_TIMEOUT_S):
            return 200, {"result": {"status": "SUCCEEDED", "progress": 100,
                                    "consumed_credits": 5,
                                    "thumbnail_url": "https://example.invalid/p.png",
                                    "model_urls": {"glb": "https://example.invalid/p.glb"}}}, ""

        def fake_download(_url):
            return b"\x89PNG\r\n\x1a\n not a real image"

        def fake_download_fails(_url):
            raise Failed("HTTPError: 403 the signed URL expired")

        def collect(run_id, downloader):
            """resume, with a fake Meshy that answers SUCCEEDED. Returns (code, output)."""
            real_download = globals()["download"]
            globals()["request"], globals()["download"] = fake_succeeded, downloader
            try:
                # A REFUSAL IS AN ANSWER HERE, not a crash: if `resume` ever stops accepting the
                # state a stop leaves behind, that must read as a named failing case rather than
                # an exception that ends the selftest before the cases after it run.
                return say(lambda: cmd_resume(Args(run_id=run_id)))
            except Refused as error:
                return 2, f"REFUSED: {error}"
            finally:
                globals()["request"], globals()["download"] = real_request, real_download

        # The fake key is set for the whole block, and RESTORED in the `finally` below rather than
        # dropped: a real key in this process's environment is not the selftest's to discard (the
        # same `previous` dance MESHY_RUN_DIR already does).
        os.environ["MESHY_API_KEY"] = FAKE_KEY
        polled = {"calls": 0}
        real_request = globals()["request"]

        def fake_401(_method, _path, _key, body=None, timeout=HTTP_TIMEOUT_S):
            polled["calls"] += 1
            return 401, {"message": "No valid API key provided"}, ""

        running = dict(record)
        running["runId"] = "boar.body_v1-20260101T0002Z"
        running["state"] = "preview-running"
        running["approval"] = None
        running["tasks"] = [{"phase": "preview", "taskId": "t", "status": "PENDING",
                             "createdAt": stamp(), "finishedAt": None, "credits": None,
                             "creditsSource": "unknown", "artefacts": []}]
        save_run(running, fresh=True)
        globals()["request"] = fake_401
        try:
            code, said_401 = say(lambda: poll_and_finish(running, FAKE_KEY, "preview"))
        finally:
            globals()["request"] = real_request
        ok("a 401 poll exits 1 rather than reporting PENDING", code == 1, str(code))
        ok("it gives up on the FIRST permanent error, not at the deadline",
           polled["calls"] == 1, str(polled["calls"]))
        # NOT `failed`: the key can be rotated and the task is still running, and already paid for.
        ok("a 401 leaves the run resumable rather than failed",
           load_run(running["runId"])["state"] == "preview-unresolved",
           load_run(running["runId"])["state"])
        ok("and the 401 line says exactly what to run",
           f"resume {running['runId']}" in said_401 and "Rotate MESHY_API_KEY" in said_401,
           said_401.strip())
        code, said_after_401 = collect(running["runId"], fake_download)
        ok("resume collects the run after a 401 give-up (the key was rotated)", code == 0,
           said_after_401.strip())
        ok("...and it reaches preview-ready",
           load_run(running["runId"])["state"] == "preview-ready",
           load_run(running["runId"])["state"])

        # A TRANSIENT error is different: it retries, then gives up after POLL_GIVE_UP_AFTER.
        polled["calls"] = 0

        def fake_503(_method, _path, _key, body=None, timeout=HTTP_TIMEOUT_S):
            polled["calls"] += 1
            return 503, None, "upstream is unhappy"

        transient = dict(running)
        transient["runId"] = "boar.body_v1-20260101T0003Z"
        transient["state"] = "preview-running"
        transient["tasks"] = [dict(running["tasks"][0])]
        save_run(transient, fresh=True)
        globals()["request"] = fake_503
        gap = POLL_INTERVAL_S
        globals()["POLL_INTERVAL_S"] = 0  # the sleep is not what is being tested
        try:
            code, said_503 = say(lambda: poll_and_finish(transient, FAKE_KEY, "preview"))
        finally:
            globals()["request"] = real_request
            globals()["POLL_INTERVAL_S"] = gap
        ok("a repeated 5xx also exits 1", code == 1, str(code))
        ok("after exactly POLL_GIVE_UP_AFTER tries", polled["calls"] == POLL_GIVE_UP_AFTER,
           str(polled["calls"]))
        ok("a transient give-up leaves the run resumable rather than failed",
           load_run(transient["runId"])["state"] == "preview-unresolved",
           load_run(transient["runId"])["state"])
        ok("and the give-up line says exactly what to run",
           f"resume {transient['runId']}" in said_503, said_503.strip())
        code, said_after_503 = collect(transient["runId"], fake_download)
        ok("resume collects the run after a poll give-up", code == 0, said_after_503.strip())
        ok("...and it reaches preview-ready",
           load_run(transient["runId"])["state"] == "preview-ready",
           load_run(transient["runId"])["state"])
        ok("...with the preview image actually on disk",
           os.path.isfile(os.path.join(sandbox, transient["runId"], "preview.png")))

        # A DOWNLOAD THAT FAILS IS THE SAME CLASS (Task 59 finding 2): the task SUCCEEDED, the
        # credits are spent, and only a short-lived signed URL went wrong. Re-polling mints a new
        # one, so the run must stay resumable and the printed line must say so.
        broken = dict(record)
        broken["runId"] = "boar.body_v1-20260101T0004Z"
        broken["state"] = "preview-running"
        broken["approval"] = None
        broken["tasks"] = [dict(running["tasks"][0], status="PENDING", artefacts=[])]
        save_run(broken, fresh=True)
        real_download = globals()["download"]
        globals()["request"], globals()["download"] = fake_succeeded, fake_download_fails
        try:
            code, said_dl = say(lambda: poll_and_finish(broken, FAKE_KEY, "preview"))
        finally:
            globals()["request"], globals()["download"] = real_request, real_download
        ok("a failed preview download exits 1", code == 1, str(code))
        ok("...and leaves the run resumable rather than failed",
           load_run(broken["runId"])["state"] == "preview-unresolved",
           load_run(broken["runId"])["state"])
        ok("...and the line says exactly what to run",
           f"resume {broken['runId']}" in said_dl, said_dl.strip())
        code, said_after_dl = collect(broken["runId"], fake_download)
        ok("resume collects a preview whose download failed", code == 0, said_after_dl.strip())
        ok("...and the image is on disk",
           os.path.isfile(os.path.join(sandbox, broken["runId"], "preview.png")))
        artefacts = load_run(broken["runId"])["tasks"][-1]["artefacts"]
        names = [artefact["name"] for artefact in artefacts]
        # BOTH downloads failed on the first pass here, so the record had nothing to double: this
        # says the resume produced one entry per file, and the DEDUP is asserted on `partial`
        # below, which is the run that really does carry a prior preview.png across a resume
        # (round 2 finding 1 -- this case passed with the dedup deleted).
        ok("...and the resume recorded one entry per file",
           len(names) == len(set(names)) == 2, str(names))

        # THE GLB ALONE. The image reaching disk used to be the whole test, so a preview whose GLB
        # download failed was called `preview-ready` with a one-line note -- and the GLB is the
        # artefact Task B needs before the 3-day expiry (Task 59, the Reviewer's fourth note).
        def fake_glb_fails(url):
            if url.endswith(".glb"):
                raise Failed("HTTPError: 403 the signed URL expired")
            return fake_download(url)

        partial = dict(record)
        partial["runId"] = "boar.body_v1-20260101T0005Z"
        partial["state"] = "preview-running"
        partial["approval"] = None
        partial["tasks"] = [dict(running["tasks"][0], status="PENDING", artefacts=[])]
        save_run(partial, fresh=True)
        globals()["request"], globals()["download"] = fake_succeeded, fake_glb_fails
        try:
            code, said_glb = say(lambda: poll_and_finish(partial, FAKE_KEY, "preview"))
        finally:
            globals()["request"], globals()["download"] = real_request, real_download
        ok("a failed GLB download stops instead of claiming preview-ready", code == 1, str(code))
        ok("...and leaves the run resumable",
           load_run(partial["runId"])["state"] == "preview-unresolved",
           load_run(partial["runId"])["state"])
        ok("...and names the GLB in the line", "preview.glb" in said_glb, said_glb.strip())
        # THE RECORD ALREADY CARRIES ONE preview.png HERE -- `fake_glb_fails` let the thumbnail
        # through on the first pass -- so this is the run where a re-download can actually double an
        # entry, and it is the only place the dedup in `finish_preview` can be seen (round 2
        # finding 1). Asserted BEFORE the resume too, or "it did not double" would be a claim about
        # a record that never held the entry in the first place.
        before = [a["name"] for a in load_run(partial["runId"])["tasks"][-1]["artefacts"]]
        ok("the stopped run kept the file that DID download", before == ["preview.png"], str(before))
        code, said_after_glb = collect(partial["runId"], fake_download)
        ok("resume collects the GLB afterwards", code == 0, said_after_glb.strip())
        ok("...and both files are on disk",
           os.path.isfile(os.path.join(sandbox, partial["runId"], "preview.glb"))
           and os.path.isfile(os.path.join(sandbox, partial["runId"], "preview.png")))
        after = [a["name"] for a in load_run(partial["runId"])["tasks"][-1]["artefacts"]]
        ok("...and the re-downloaded preview.png REPLACED its entry rather than doubling it",
           sorted(after) == ["preview.glb", "preview.png"], str(after))

        # ---- STEP 2: REFINE, REMESH, FETCH (Task 62), all offline -------------------------
        #
        # The same shape as the preview's cases: `request` and `download` are swapped for fakes, so
        # no key, no network and no credits are involved. Every failure path below is
        # mutation-checked -- the Task 59 lesson: a test that cannot fail is not a test.

        def fake_post_then_succeed(model_urls=None, texture_urls=None, thumbnail=True):
            """A fake Meshy: a POST returns an id, a GET returns SUCCEEDED with these URLs."""
            seen = {"paths": []}

            def fake(method, path, _key, body=None, timeout=HTTP_TIMEOUT_S):
                seen["paths"].append(f"{method} {path}")
                if method == "POST":
                    seen["body"] = body
                    return 202, {"result": "task-2"}, ""
                result = {"status": "SUCCEEDED", "progress": 100, "consumed_credits": 10}
                if thumbnail:
                    result["thumbnail_url"] = "https://example.invalid/t.png"
                if model_urls is not None:
                    result["model_urls"] = model_urls
                if texture_urls is not None:
                    result["texture_urls"] = texture_urls
                return 200, {"result": result}, ""

            return fake, seen

        def step2(callable_):
            """Run one step-2 command; a refusal is an ANSWER, not the end of the selftest.

            The same class as `collect` above (Task 59, claim 9): an uncaught Refused here would
            end the run before the cases after it, and a state regression would read as a crash
            rather than as the one case that names it."""
            try:
                return say(callable_)
            except Refused as error:
                return 2, f"REFUSED: {error}"

        def approved_run(run_id, state="approved"):
            fresh = dict(record)
            fresh["runId"] = run_id
            fresh["state"] = state
            fresh["approval"] = {"by": "karen", "at": stamp(), "previewSha256": "", "note": ""}
            # YESTERDAY'S PREVIEW, deliberately: MAX_TASKS_PER_DAY counts tasks by createdAt
            # across every run on disk, and a dozen fixtures stamped `now` would trip the ceiling
            # this file is also testing. A preview approved yesterday is the real shape anyway.
            yesterday = stamp(utc_now() - datetime.timedelta(hours=25))
            fresh["tasks"] = [{"phase": "preview", "taskId": "prev-1", "endpoint": "text-to-3d",
                               "status": "SUCCEEDED", "createdAt": yesterday, "finishedAt": yesterday,
                               "credits": 5, "creditsSource": "api", "artefacts": []}]
            fresh["totals"] = {"tasks": 1, "credits": 5}
            save_run(fresh, fresh=True)
            return fresh

        def fetchable_run(run_id):
            """A run previewed, refined AND remeshed: the state `fetch` opens on.

            Every task is stamped yesterday, for `approved_run`'s reason: MAX_TASKS_PER_DAY counts
            tasks by createdAt across every run in the sandbox, and 25 h old is still far inside the
            72 h expiry."""
            fresh = approved_run(run_id, state="remesh-ready")
            yesterday = fresh["tasks"][0]["createdAt"]
            for phase, task_id, endpoint, credits in (("refine", "ref-x", "text-to-3d", 10),
                                                      ("remesh", "rem-x", "remesh", 2)):
                fresh["tasks"].append({"phase": phase, "taskId": task_id, "endpoint": endpoint,
                                       "status": "SUCCEEDED", "createdAt": yesterday,
                                       "finishedAt": yesterday, "credits": credits,
                                       "creditsSource": "api", "artefacts": []})
            fresh["trisDeclared"] = 6000
            fresh["totals"] = {"tasks": 3, "credits": 17}
            save_run(fresh)
            return fresh

        # REFINE IS REFUSED WITHOUT KAREN'S OK, and it says which state it is in.
        waiting = approved_run("boar.body_v1-20260101T0010Z", state="preview-ready")
        # THROUGH --dry-run, deliberately: the state gate is checked BEFORE the request is built,
        # so this case cannot reach the network even if the gate is broken -- and if the gate ever
        # goes, the dry run returns 0 and this reads as a named failing case instead.
        said = refusal(lambda: cmd_refine(Args(run_id=waiting["runId"], dry_run=True)),
                       "refine without an approval")
        ok("refine refuses a run Karen has not approved, by name",
           "preview-ready" in said and "approved" in said, said)

        # ...and a dry run sends nothing at all, with or without a key.
        approved = approved_run("boar.body_v1-20260101T0011Z")
        code, saidDry = step2(lambda: cmd_refine(Args(run_id=approved["runId"], dry_run=True)))
        ok("a dry-run refine exits 0", code == 0, str(code))
        ok("...sends nothing and says so", "DRY RUN, nothing sent" in saidDry, saidDry.strip())
        ok("...shows the 2K texture resolution", '"texture_resolution": 2048' in saidDry, saidDry.strip())
        ok("...and the run has not moved", load_run(approved["runId"])["state"] == "approved")

        # THE WHOLE CHAIN, offline: refine -> remesh -> fetch.
        chain = approved_run("boar.body_v1-20260101T0012Z")
        refineFake, refineSeen = fake_post_then_succeed()
        globals()["request"], globals()["download"] = refineFake, fake_download
        try:
            code, saidRefine = step2(lambda: cmd_refine(Args(run_id=chain["runId"], dry_run=False)))
        finally:
            globals()["request"], globals()["download"] = real_request, real_download
        ok("refine exits 0", code == 0, saidRefine.strip())
        ok("...reaches refine-ready", load_run(chain["runId"])["state"] == "refine-ready",
           load_run(chain["runId"])["state"])
        ok("...records the refine task with its own endpoint",
           load_run(chain["runId"])["tasks"][-1]["phase"] == "refine"
           and load_run(chain["runId"])["tasks"][-1]["endpoint"] == "text-to-3d")
        ok("...logs the credits the API reported",
           load_run(chain["runId"])["tasks"][-1]["credits"] == 10,
           str(load_run(chain["runId"])["tasks"][-1]))
        ok("...keeps the thumbnail it was given",
           os.path.isfile(os.path.join(sandbox, chain["runId"], "refine.png")))
        ok("...and the line names the next command", "remesh " + chain["runId"] in saidRefine,
           saidRefine.strip())

        chain = load_run(chain["runId"])
        remeshFake, remeshSeen = fake_post_then_succeed(
            model_urls={"fbx": "https://example.invalid/m.fbx", "glb": "https://example.invalid/m.glb"},
            texture_urls={"base_color": "https://example.invalid/base.png",
                          "normal": "https://example.invalid/normal.png"})
        globals()["request"], globals()["download"] = remeshFake, fake_download
        try:
            code, saidRemesh = step2(lambda: cmd_remesh(Args(run_id=chain["runId"], target=None,
                                                             dry_run=False)))
        finally:
            globals()["request"], globals()["download"] = real_request, real_download
        ok("remesh exits 0", code == 0, saidRemesh.strip())
        ok("...reaches remesh-ready", load_run(chain["runId"])["state"] == "remesh-ready",
           load_run(chain["runId"])["state"])
        ok("...declares the brief's triangle target",
           load_run(chain["runId"]).get("trisDeclared") == GOOD_BRIEF["targetTris"],
           str(load_run(chain["runId"]).get("trisDeclared")))
        # THE TASK'S OWN ENDPOINT, not the run's: a remesh task is polled under /remesh/:id.
        ok("...polls the remesh endpoint, not the run's creation endpoint",
           any(row.startswith("GET " + ENDPOINTS["remesh"]) for row in remeshSeen["paths"]),
           "; ".join(remeshSeen["paths"]))
        ok("...and tells the operator to fetch it NOW",
           "FETCH IT NOW" in saidRemesh and "fetch " + chain["runId"] in saidRemesh,
           saidRemesh.strip())

        # FETCH: the files land, the record carries their hashes, and the run stops for a human.
        def sized_download(url):
            if url.endswith(".png"):
                return fake_png(1024, 1024)
            return b"FBX-ish bytes " * 16

        fetchFake, _fetchSeen = fake_post_then_succeed(
            model_urls={"fbx": "https://example.invalid/m.fbx", "glb": "https://example.invalid/m.glb"},
            texture_urls={"base_color": "https://example.invalid/base.png",
                          "normal": "https://example.invalid/normal.png"})
        globals()["request"], globals()["download"] = fetchFake, sized_download
        try:
            code, saidFetch = step2(lambda: cmd_fetch(Args(run_id=chain["runId"])))
        finally:
            globals()["request"], globals()["download"] = real_request, real_download
        ok("fetch exits 0", code == 0, saidFetch.strip())
        ok("...reaches fetched", load_run(chain["runId"])["state"] == "fetched",
           load_run(chain["runId"])["state"])
        for name in ("model.fbx", "model.glb", "texture_base_color.png", "texture_normal.png"):
            ok(f"...{name} is on disk", os.path.isfile(os.path.join(sandbox, chain["runId"], name)))
        artefacts = {a["name"]: a for a in (load_run(chain["runId"])["tasks"][-1].get("artefacts") or [])}
        ok("...every file carries its sha256 and its size",
           all(len(a["sha256"]) == 64 and a["bytes"] > 0 for a in artefacts.values()),
           str(sorted(artefacts)))
        ok("...the local validation passed",
           (load_run(chain["runId"]).get("validation") or {}).get("ok") is True,
           str(load_run(chain["runId"]).get("validation")))
        # THE SECOND STOP POINT: a human looks before anything is uploaded.
        ok("...and it stops for a human to look",
           "LOOK AT IT" in saidFetch and "until she says yes" in saidFetch, saidFetch.strip())

        # NO FBX: paid for, not collected -- so the run stays collectable rather than `failed`.
        noFbx = approved_run("boar.body_v1-20260101T0013Z", state="remesh-ready")
        noFbx["tasks"].append({"phase": "remesh", "taskId": "rem-1", "endpoint": "remesh",
                               "status": "SUCCEEDED", "createdAt": stamp(), "finishedAt": stamp(),
                               "credits": 2, "creditsSource": "api", "artefacts": []})
        noFbx["trisDeclared"] = 6000
        save_run(noFbx)
        emptyFake, _ = fake_post_then_succeed(model_urls={"glb": "https://example.invalid/m.glb"})
        globals()["request"], globals()["download"] = emptyFake, sized_download
        try:
            code, saidNoFbx = step2(lambda: cmd_fetch(Args(run_id=noFbx["runId"])))
        finally:
            globals()["request"], globals()["download"] = real_request, real_download
        ok("a fetch with no FBX exits 1", code == 1, str(code))
        ok("...leaves the run resumable rather than failed",
           load_run(noFbx["runId"])["state"] == "remesh-unresolved",
           load_run(noFbx["runId"])["state"])
        ok("...and says exactly what to run -- the command that DOWNLOADS it again",
           "fetch " + noFbx["runId"] in saidNoFbx, saidNoFbx.strip())
        # AND THAT COMMAND IS ACCEPTED FROM THE STATE THE STOP LEFT (round 1 finding 2). A line that
        # names a command the tool then refuses is how a paid run got stranded, so the route is
        # walked here rather than described: `fetch` again, with a response that carries everything.
        globals()["request"], globals()["download"] = fetchFake, sized_download
        try:
            code, saidAgain = step2(lambda: cmd_fetch(Args(run_id=noFbx["runId"])))
        finally:
            globals()["request"], globals()["download"] = real_request, real_download
        ok("fetching again from remesh-unresolved collects the run", code == 0, saidAgain.strip())
        ok("...and it reaches fetched then", load_run(noFbx["runId"])["state"] == "fetched",
           load_run(noFbx["runId"])["state"])

        # NO PBR MAP AT ALL, which is what the refine was paid for: the fetch that used to exit 0,
        # print the second stop point and invite Karen to look (round 1 finding 1).
        noMaps = fetchable_run("boar.body_v1-20260101T0016Z")
        noMapsFake, noMapsSeen = fake_post_then_succeed(
            model_urls={"fbx": "https://example.invalid/m.fbx"})
        globals()["request"], globals()["download"] = noMapsFake, sized_download
        try:
            code, saidNoMaps = step2(lambda: cmd_fetch(Args(run_id=noMaps["runId"])))
        finally:
            globals()["request"], globals()["download"] = real_request, real_download
        ok("a fetch that lands no PBR map at all exits 1", code == 1, saidNoMaps.strip())
        ok("...and is NOT called fetched",
           load_run(noMaps["runId"])["state"] == "remesh-unresolved",
           load_run(noMaps["runId"])["state"])
        ok("...and does NOT invite a human to look at it",
           "LOOK AT IT" not in saidNoMaps, saidNoMaps.strip())
        ok("...and names the maps in the line", "texture_*.png" in saidNoMaps, saidNoMaps.strip())
        # AND IT ASKED THE REFINE FOR THEM FIRST. The research note's source 3 quotes `model_urls`
        # and no statistics for the remesh response and never quotes `texture_urls` there, so the
        # task that was paid for the maps is the one to re-poll -- a GET, which costs nothing.
        ok("...having re-polled the REFINE task for the map URLs",
           f"GET {ENDPOINTS['text-to-3d']}/ref-x" in noMapsSeen["paths"],
           "; ".join(noMapsSeen["paths"]))

        # THE DOCUMENTED SHAPE, end to end: the remesh answers model_urls, the refine answers the
        # maps -- as a LIST of map sets, which is the other shape Meshy's examples show.
        split = fetchable_run("boar.body_v1-20260101T0017Z")
        seenSplit = {"paths": []}

        def fake_split(method, path, _key, body=None, timeout=HTTP_TIMEOUT_S):
            seenSplit["paths"].append(f"{method} {path}")
            if ENDPOINTS["remesh"] in path:
                return 200, {"result": {"status": "SUCCEEDED", "consumed_credits": 2,
                                        "model_urls": {"fbx": "https://example.invalid/m.fbx"}}}, ""
            return 200, {"result": {
                "status": "SUCCEEDED", "consumed_credits": 10,
                "texture_urls": [{"base_color": "https://example.invalid/b.png",
                                  "normal": "https://example.invalid/n.png"}]}}, ""

        globals()["request"], globals()["download"] = fake_split, sized_download
        try:
            code, saidSplit = step2(lambda: cmd_fetch(Args(run_id=split["runId"])))
        finally:
            globals()["request"], globals()["download"] = real_request, real_download
        ok("a remesh response with no texture_urls still lands the maps, from the refine",
           code == 0, saidSplit.strip())
        for name in ("model.fbx", "texture_base_color.png", "texture_normal.png"):
            ok(f"...{name} is on disk", os.path.isfile(os.path.join(sandbox, split["runId"], name)))
        ok("...and the line says which task the maps came from",
           "maps come from the refine" in saidSplit, saidSplit.strip())
        ok("...and only then is it fetched", load_run(split["runId"])["state"] == "fetched",
           load_run(split["runId"])["state"])

        # A TASK THAT HAS NOT FINISHED is not a missing URL. `remesh-unresolved` also covers a poll
        # that gave up while the task was still running, and `fetch` takes that state now.
        unfinished = fetchable_run("boar.body_v1-20260101T0018Z")
        unfinished["state"] = "remesh-unresolved"
        save_run(unfinished)

        def fake_in_progress(_method, _path, _key, body=None, timeout=HTTP_TIMEOUT_S):
            return 200, {"result": {"status": "IN_PROGRESS", "progress": 40}}, ""

        globals()["request"] = fake_in_progress
        try:
            code, saidUnfinished = step2(lambda: cmd_fetch(Args(run_id=unfinished["runId"])))
        finally:
            globals()["request"] = real_request
        ok("fetching a task that has not finished exits 1", code == 1, saidUnfinished.strip())
        ok("...and says it is IN_PROGRESS instead of inventing a missing URL",
           "IN_PROGRESS" in saidUnfinished, saidUnfinished.strip())
        ok("...and names resume, which polls it to the end",
           "resume " + unfinished["runId"] in saidUnfinished, saidUnfinished.strip())

        # THE REFINE'S THUMBNAIL, offered and failed, is the preview GLB's class: paid for, not
        # collected. It used to print a note and call the run refine-ready.
        thumb = approved_run("boar.body_v1-20260101T0019Z")
        thumbFake, _thumbSeen = fake_post_then_succeed()
        globals()["request"], globals()["download"] = thumbFake, fake_download_fails
        try:
            code, saidThumb = step2(lambda: cmd_refine(Args(run_id=thumb["runId"], dry_run=False)))
        finally:
            globals()["request"], globals()["download"] = real_request, real_download
        ok("a refine whose thumbnail download fails exits 1", code == 1, saidThumb.strip())
        ok("...and stays collectable as refine-unresolved",
           load_run(thumb["runId"])["state"] == "refine-unresolved",
           load_run(thumb["runId"])["state"])
        code, saidThumbAgain = collect(thumb["runId"], fake_download)
        ok("resume collects that refine afterwards", code == 0, saidThumbAgain.strip())
        ok("...and only then is it refine-ready",
           load_run(thumb["runId"])["state"] == "refine-ready",
           load_run(thumb["runId"])["state"])

        # THE LOCAL VALIDATION BITES: a 4096 map against a 2048 brief, and an oversized FBX.
        oversize = approved_run("boar.body_v1-20260101T0014Z", state="remesh-ready")
        oversize["tasks"].append({"phase": "remesh", "taskId": "rem-2", "endpoint": "remesh",
                                  "status": "SUCCEEDED", "createdAt": stamp(), "finishedAt": stamp(),
                                  "credits": 2, "creditsSource": "api", "artefacts": []})
        oversize["trisDeclared"] = 6000
        save_run(oversize)

        def big_download(url):
            if url.endswith(".png"):
                return fake_png(4096, 4096)
            return b"x" * (MAX_FILE_BYTES + 1)

        globals()["request"], globals()["download"] = fetchFake, big_download
        try:
            code, saidBig = step2(lambda: cmd_fetch(Args(run_id=oversize["runId"])))
        finally:
            globals()["request"], globals()["download"] = real_request, real_download
        ok("a fetch whose files break the local checks exits 1", code == 1, str(code))
        ok("...records WHY, on the run",
           (load_run(oversize["runId"]).get("validation") or {}).get("ok") is False,
           str(load_run(oversize["runId"]).get("validation")))
        problems = " ".join((load_run(oversize["runId"]).get("validation") or {}).get("problems", []))
        ok("...names the oversized texture", "4096x4096" in problems, problems)
        ok("...names the oversized FBX", "over Roblox's per-call" in problems, problems)
        ok("...and does NOT invite a human to look at it",
           "LOOK AT IT" not in saidBig, saidBig.strip())
        # AND THE ROUTE OUT IS A COMMAND THAT WORKS (round 1 finding 2): the bytes are what Meshy
        # sent and the geometry is what is wrong, so the way out is the replacement task
        # MAX_TASKS_PER_RUN was sized for. Asserted through --dry-run, so the door is proven without
        # anything being sent; a fetched run that PASSED its checks is refused by the loop below.
        ok("...and the line names the remesh that re-cuts it",
           "remesh " + oversize["runId"] in saidBig, saidBig.strip())
        code, saidRecut = step2(lambda: cmd_remesh(Args(run_id=oversize["runId"], target=4000,
                                                       dry_run=True)))
        ok("a fetched run whose local checks failed can be re-cut", code == 0, saidRecut.strip())
        ok("...at the lower target that was asked for", '"target_polycount": 4000' in saidRecut,
           saidRecut.strip())

        # A TRUNCATED FILE ON DISK is the 3-day trap's cruellest form: the run looks finished, and
        # this is the failure the code itself calls re-fetchable while no command took the state it
        # was left in (round 1 finding 2).
        truncated = load_run(chain["runId"])
        folderT = os.path.join(sandbox, truncated["runId"])
        with open(os.path.join(folderT, "model.fbx"), "wb") as handle:
            handle.write(b"half")
        problems = validate_fetched(truncated, folderT, truncated["tasks"][-1])
        ok("a file that does not match its recorded sha256 is caught",
           any("sha256" in problem.text for problem in problems), str(problems))
        ok("...and it is routed to the command that downloads it again",
           all(problem.route == "refetch" for problem in problems), str(problems))
        # THROUGH THE GUARD, over those real bytes on disk: `deliver` is what decides, so the case
        # is the fix rather than a claim about one validator.
        truncated["state"] = "remesh-ready"
        save_run(truncated)
        code, saidTrunc = say(lambda: deliver(truncated, folderT, truncated["tasks"][-1], "fetch",
                                              [], "fetched", "unused", command="fetch",
                                              validate=validate_fetched))
        ok("a truncated download exits 1", code == 1, saidTrunc.strip())
        ok("...and is NOT left in fetched, which no command takes",
           load_run(truncated["runId"])["state"] == "remesh-unresolved",
           load_run(truncated["runId"])["state"])
        ok("...in a state `resume` accepts as well",
           load_run(truncated["runId"])["state"] in RESUMABLE_STATES,
           load_run(truncated["runId"])["state"])
        ok("...and the line names fetch, which re-polls and downloads again",
           "fetch " + truncated["runId"] in saidTrunc, saidTrunc.strip())

        # A REFINE THAT CANNOT BE POLLED stays collectable, and `resume` continues the REFINE.
        stalled = approved_run("boar.body_v1-20260101T0015Z")

        def fake_post_ok_poll_401(method, path, _key, body=None, timeout=HTTP_TIMEOUT_S):
            """The task IS created and IS paid for; the key is rejected on the way back."""
            if method == "POST":
                return 202, {"result": "task-stalled"}, ""
            return 401, {"message": "No valid API key provided"}, ""

        globals()["request"] = fake_post_ok_poll_401
        try:
            code, saidStalled = step2(lambda: cmd_refine(Args(run_id=stalled["runId"], dry_run=False)))
        finally:
            globals()["request"] = real_request
        ok("a refine whose poll is rejected exits 1", code == 1, str(code))
        ok("...leaves the run in refine-unresolved, not preview-unresolved",
           load_run(stalled["runId"])["state"] == "refine-unresolved",
           load_run(stalled["runId"])["state"])
        resumeFake, resumeSeen = fake_post_then_succeed()
        real_download2 = globals()["download"]
        globals()["request"], globals()["download"] = resumeFake, fake_download
        try:
            code, saidResume = say(lambda: cmd_resume(Args(run_id=stalled["runId"])))
        except Refused as error:
            code, saidResume = 2, f"REFUSED: {error}"
        finally:
            globals()["request"], globals()["download"] = real_request, real_download2
        ok("resume collects a stalled REFINE", code == 0, saidResume.strip())
        ok("...and it reaches refine-ready, not preview-ready",
           load_run(stalled["runId"])["state"] == "refine-ready",
           load_run(stalled["runId"])["state"])
        ok("...having polled the text-to-3d endpoint of the refine task",
           any(ENDPOINTS["text-to-3d"] in row for row in resumeSeen["paths"]),
           "; ".join(resumeSeen["paths"]))

        # And the wrong state is refused BY NAME, at every door of this half.
        for command, args, wanted in (
            (cmd_remesh, dict(run_id=chain["runId"], target=None, dry_run=False), "refine-ready"),
            (cmd_fetch, dict(run_id=approved["runId"]), "remesh-ready"),
        ):
            said = refusal(lambda c=command, a=args: c(Args(**a)), f"{command.__name__} wrong state")
            ok(f"{command.__name__} refuses the wrong state by name", wanted in said, said)

        # resume refuses an EXPIRED run and says why -- the 3-day trap, from created_at.
        expired = dict(record)
        expired["runId"] = "boar.body_v1-20260101T0001Z"
        expired["state"] = "preview-running"
        expired["approval"] = None
        expired["tasks"] = [{"phase": "preview", "taskId": "t", "status": "IN_PROGRESS",
                             "createdAt": stamp(utc_now() - datetime.timedelta(hours=80)),
                             "finishedAt": None, "credits": None, "creditsSource": "unknown",
                             "artefacts": []}]
        save_run(expired, fresh=True)
        ok("an 80 h old run reads as EXPIRED", expiry_line(expired) == "EXPIRED", expiry_line(expired))
        said = refusal(lambda: cmd_resume(Args(run_id=expired["runId"])), "resume an expired run")
        ok("resume refuses an expired run, and says it cannot be regenerated",
           "deleted" in said and "no seed" in said, said)
        ok("the refusal moved it to expired", load_run(expired["runId"])["state"] == "expired")
    finally:
        if previous_key is None:
            os.environ.pop("MESHY_API_KEY", None)
        else:
            os.environ["MESHY_API_KEY"] = previous_key
        if previous is None:
            os.environ.pop("MESHY_RUN_DIR", None)
        else:
            os.environ["MESHY_RUN_DIR"] = previous
        shutil.rmtree(sandbox, ignore_errors=True)

    for line in failures:
        print("[meshy] selftest: " + line)
    if failures:
        print(f"[meshy] selftest FAIL: {len(failures)} case(s) wrong")
        return 1
    print("[meshy] selftest PASS: brief grammar and validator refuse by reason; the endpoint is "
          "data not a flag; no deprecated field is sent; an unknown status is not success; the key "
          "appears in none of the rendered lines; ceilings, expiry and states refuse by name")
    return 0


# ---------------------------------------------------------------- main


def build_parser():
    parser = argparse.ArgumentParser(prog="tools/meshy.py", add_help=True,
                                     description=(__doc__ or "").split("\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)

    key_parser = sub.add_parser("key", help="is MESHY_API_KEY set (never prints it)")
    key_parser.add_argument("--check", action="store_true",
                            help="make the ONE call that costs no credits")
    key_parser.set_defaults(run=cmd_key)

    brief_parser = sub.add_parser("brief", help="validate a brief and print what would be sent")
    brief_parser.add_argument("name")
    brief_parser.set_defaults(run=cmd_brief)

    preview_parser = sub.add_parser("preview", help="create, poll and download the preview")
    preview_parser.add_argument("name")
    preview_parser.add_argument("--dry-run", action="store_true",
                                help="print the exact request, send nothing, spend nothing")
    preview_parser.set_defaults(run=cmd_preview)

    status_parser = sub.add_parser("status", help="local records, plus one GET per live task")
    status_parser.add_argument("run_id", nargs="?")
    status_parser.set_defaults(run=cmd_status)

    approve_parser = sub.add_parser("approve", help="record Karen's OK on a preview")
    approve_parser.add_argument("run_id")
    approve_parser.add_argument("--by", required=True)
    approve_parser.add_argument("--note", default="")
    approve_parser.set_defaults(run=cmd_approve)

    refine_parser = sub.add_parser("refine", help="textures and PBR maps; REFUSED without approval")
    refine_parser.add_argument("run_id")
    refine_parser.add_argument("--dry-run", action="store_true",
                               help="print the exact request, send nothing, spend nothing")
    refine_parser.set_defaults(run=cmd_refine)

    remesh_parser = sub.add_parser("remesh", help="triangle topology, to the brief's target")
    remesh_parser.add_argument("run_id")
    remesh_parser.add_argument("--target", type=int, default=None,
                               help="triangles; the brief's targetTris by default")
    remesh_parser.add_argument("--dry-run", action="store_true",
                               help="print the exact request, send nothing, spend nothing")
    remesh_parser.set_defaults(run=cmd_remesh)

    fetch_parser = sub.add_parser("fetch", help="download the FBX and the maps NOW, and validate")
    fetch_parser.add_argument("run_id")
    fetch_parser.set_defaults(run=cmd_fetch)

    resume_parser = sub.add_parser("resume",
                                   help="continue an interrupted poll, or collect a STOPPED run")
    resume_parser.add_argument("run_id")
    resume_parser.set_defaults(run=cmd_resume)

    sub.add_parser("runs", help="every run: state, age, expiry, credits").set_defaults(run=cmd_runs)
    sub.add_parser("selftest", help="offline; CI runs this").set_defaults(
        run=lambda _args: selftest())
    return parser


def main(argv):
    args = build_parser().parse_args(argv[1:])
    try:
        return args.run(args)
    except Refused as error:
        print(f"[meshy] REFUSED: {error}")
        return 2
    except Failed as error:
        print(f"[meshy] FAILED: {error}")
        return 1
    except KeyboardInterrupt:  # pragma: no cover
        print("[meshy] FAILED: interrupted. Any task already created is still running at Meshy; "
              "`runs` will show it and `resume` will pick it up")
        return 1


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
    sys.exit(main(sys.argv))
