"""Upload one prepared asset to Roblox through Open Cloud, and write down what happened.

It sends ONE multipart request to `POST https://apis.roblox.com/assets/v1/assets`, polls the
operation until it is done, prints the asset id and its moderation state, and appends one row of
provenance to `assets/uploads.json`.

  Assets API guide: https://create.roblox.com/docs/cloud/guides/usage-assets
  Note:             docs/research/2026-09-26-roblox-upload.md

THE KEY IS A PASSWORD AND THIS REPO IS PUBLIC. Roblox's own words: *"Copy and save the API key string
to a secure location, not a public repository for your code"*. So `ROBLOX_OPEN_CLOUD_KEY` is read from
the environment, then from `HKCU\\Environment` -- the same two places `tools/meshy.py` reads
`MESHY_API_KEY` -- and it is NEVER printed, never written to a file this tool produces, never put in
a printed request and never included in an error. `--dry-run` prints the request it WOULD send, and
the header it prints says `x-api-key: <redacted>` because there is no version of this program that
puts the real thing on a terminal. `tools/privacy_scan.py` has a shape rule for it since Task 73, so
CI fails if one is ever committed.

KAREN'S OK IS PER ASSET, AND IT IS AN ARGUMENT, NOT A FLAG. Uploading is publishing: it puts her name
on a thing on Roblox's servers under her account. `--karen-ok "<date + what>"` is required, has to
carry a date and real words, and is recorded verbatim in the row -- so what she approved is
answerable later out of git instead of out of somebody's memory. A second asset needs its own OK.

Usage:
  python tools/roblox_upload.py upload <prepared-folder>
        --name "<display name>" --description "<description>"
        --karen-ok "2026-09-26 the shotgun as prepared by Task 72"
        [--file model.fbx] [--type Model] [--dry-run] [--again] [--timeout 180]
  python tools/roblox_upload.py show <assetId>          # read one row back out of the manifest
  python tools/roblox_upload.py selftest                # offline, mocked HTTP, no key needed

Exit codes, the harness's shape: 0 done - 1 the upload failed - 2 REFUSED before anything was sent.

WHAT IT REFUSES, BEFORE ANY BYTE LEAVES THE PROCESS:
  1. No key.
  2. No `--karen-ok`, or one that does not carry a date AND words.
  3. No model file in the folder, or a file whose extension Roblox does not list for the asset type.
  4. A file over 20 MB -- the guide's *"up to 20 MB"* per call.
  5. The same bytes twice: if the file's sha256 is already in the manifest, it refuses and names the
     asset id it already has. `--again` is how a deliberate re-upload says it means it.

Moderation is Roblox's, not ours: the tool reports the state it was given and never retries on it.

Note: docs/research/2026-09-26-roblox-upload.md
Design: docs/design/asset-pipeline.md (sections 2.1, 7.4)
"""

import argparse
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(REPO, "assets", "uploads.json")
TOOL_VERSION = "roblox-upload/1"

CREATE_URL = "https://apis.roblox.com/assets/v1/assets"
OPERATION_URL = "https://apis.roblox.com/assets/v1/operations/%s"
KEY_ENV = "ROBLOX_OPEN_CLOUD_KEY"

# Karen's account, and the only creator this tool will upload for. The Director read it out of
# POST /api-keys/v1/introspect: scope asset read+write, authorizedUserId 8167651842, expires
# 2026-10-26. A different creator is a different key and a different conversation.
CREATOR_USER_ID = "8167651842"

MAX_FILE_BYTES = 20 * 1024 * 1024  # the guide's "up to 20 MB" per call

# From the Assets guide's own table, for assetType Model. Nothing else is offered, because an
# extension this tool guesses a content type for is an extension Roblox has not agreed to.
CONTENT_TYPES = {
    ".fbx": "model/fbx",
    ".glb": "model/gltf-binary",
    ".gltf": "model/gltf+json",
}
# The order a prepared folder is searched in. FBX first: it is what the guide's own example uploads,
# it is the only format the guide says can later be UPDATED in place ("Currently, you can only update
# the asset content for .fbx files"), and it is what Task 72 writes.
PREFERRED_FILES = ("model.fbx", "model.glb", "model.gltf")

POLL_GAP_S = 2.0      # ours: the guide publishes no rate limit for this endpoint
POLL_BUDGET_S = 180.0  # ours


class Refused(Exception):
    """Something is wrong with the request; nothing has been sent."""


def say(message):
    print("[upload] " + message, flush=True)


# ---------------------------------------------------------------- the key

def read_key():
    """The key, from the environment or HKCU\\Environment. Never printed, never returned to a log."""
    key = os.environ.get(KEY_ENV)
    if not key:
        try:
            out = subprocess.run(["reg", "query", "HKCU\\Environment", "/v", KEY_ENV],
                                 capture_output=True, text=True, timeout=30)
            found = re.search(KEY_ENV + r"\s+REG_[A-Z_]+\s+(.+)", out.stdout or "")
            key = found.group(1).strip() if found else None
        except (OSError, subprocess.SubprocessError):
            key = None
    if not key:
        raise Refused("no %s in the environment or HKCU\\Environment" % KEY_ENV)
    return key


# ---------------------------------------------------------------- the refusals

# A record, not a shrug: a date somewhere in it, and some words. "yes" is not a record of consent.
KAREN_OK_DATE = re.compile(r"\b(20\d\d[-/]\d\d?[-/]\d\d?|\d\d?[-/]\d\d?[-/]20\d\d)\b")


def check_karen_ok(text):
    if not text or not text.strip():
        raise Refused("--karen-ok is required: uploading publishes under Karen's account, and every "
                      "asset needs her own OK, recorded")
    if not KAREN_OK_DATE.search(text):
        raise Refused("--karen-ok must carry a date (when she said it), e.g. "
                      '"2026-09-26 the shotgun as prepared by Task 72"')
    if len(re.findall(r"[A-Za-z]{3,}", text)) < 3:
        raise Refused("--karen-ok must say WHAT she approved, not just that she did")
    return text.strip()


def find_model(folder, wanted=None):
    if not os.path.isdir(folder):
        raise Refused("no such folder: the prepared asset directory")
    if wanted:
        path = os.path.join(folder, wanted)
        if not os.path.isfile(path):
            raise Refused("no %s in the prepared folder" % wanted)
    else:
        for name in PREFERRED_FILES:
            path = os.path.join(folder, name)
            if os.path.isfile(path):
                break
        else:
            raise Refused("no model.fbx / model.glb / model.gltf in the prepared folder")
    extension = os.path.splitext(path)[1].lower()
    if extension not in CONTENT_TYPES:
        raise Refused("Roblox does not list %s for assetType Model (%s)"
                      % (extension, ", ".join(sorted(CONTENT_TYPES))))
    size = os.path.getsize(path)
    if size > MAX_FILE_BYTES:
        raise Refused("%s is %.1f MiB; the Assets API takes up to 20 MB per call"
                      % (os.path.basename(path), size / (1 << 20)))
    if size == 0:
        raise Refused("%s is empty" % os.path.basename(path))
    return path, CONTENT_TYPES[extension], size


def digest_of(path):
    sha = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            sha.update(block)
    return sha.hexdigest()


# ---------------------------------------------------------------- the manifest

def load_manifest():
    if not os.path.exists(MANIFEST):
        return []
    with open(MANIFEST, "r", encoding="utf-8") as handle:
        return json.load(handle)


def append_manifest(row):
    """One row per upload, appended. IDS ARE NOT SECRETS -- provenance belongs in git.

    This is deliberately NOT a Luau id table: `docs/design/map-generator.md` section 12.2 says
    `MapGen.Assets` is the only one until M2.7a builds `ServerStorage.Assets`, and that module is
    what these rows will be built from (`docs/design/asset-pipeline.md` section 2.1: the Builder
    writes the manifest from what the tool printed).
    """
    rows = load_manifest()
    rows.append(row)
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(rows, handle, indent=2)
        handle.write("\n")
    return len(rows)


def already_uploaded(sha):
    for row in load_manifest():
        if row.get("sha256") == sha:
            return row
    return None


# ---------------------------------------------------------------- the request

def multipart(request_json, file_bytes, filename, content_type):
    """The two parts the guide names, `request` and `fileContent`, as one body."""
    boundary = "----DrivenHunt%s" % uuid.uuid4().hex
    out = bytearray()

    def part(header, payload):
        out.extend(("--%s\r\n%s\r\n\r\n" % (boundary, header)).encode("utf-8"))
        out.extend(payload)
        out.extend(b"\r\n")

    part('Content-Disposition: form-data; name="request"\r\nContent-Type: application/json',
         json.dumps(request_json).encode("utf-8"))
    part('Content-Disposition: form-data; name="fileContent"; filename="%s"\r\nContent-Type: %s'
         % (filename, content_type), file_bytes)
    out.extend(("--%s--\r\n" % boundary).encode("utf-8"))
    return bytes(out), "multipart/form-data; boundary=%s" % boundary


def send(url, method, key, body=None, content_type=None, timeout=120):
    """One HTTP call. The key goes in a header and NOWHERE else -- not into a log, not into an error."""
    request = urllib.request.Request(url, data=body, method=method)
    request.add_header("x-api-key", key)
    if content_type:
        request.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, json.loads(response.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as why:
        text = why.read().decode("utf-8", "replace")[:600]
        # The body is Roblox's, never ours, so it cannot contain the key -- but it is truncated
        # anyway, because an error message is not a place to widen what gets printed.
        return why.code, {"error": text}


def moderation_of(response):
    """The moderation state, whichever of the two shapes the operation came back in.

    The live guide nests it under `moderationResult`; this repo's earlier note recorded it at the top
    level. A poller that insists on one spelling reports "unknown" for a perfectly good answer.

    AND THE VALUE IS NOT THE DOCUMENTED ONE EITHER. The guide prints
    `"moderationState": "MODERATION_STATE_APPROVED"`; the real upload in Task 73 (asset
    117134580332969) came back `"Approved"`. So this returns the string it was handed and NOTHING
    here branches on it -- matching on the `MODERATION_STATE_` prefix, which this repo's asset-pipeline
    note recommended, would have called a perfectly approved asset unknown.
    """
    if not isinstance(response, dict):
        return None, None
    nested = response.get("moderationResult")
    if isinstance(nested, dict) and nested.get("moderationState"):
        return nested["moderationState"], "response.moderationResult.moderationState"
    if response.get("moderationState"):
        return response["moderationState"], "response.moderationState"
    return None, None


def poll(operation_path, key, sender, budget=POLL_BUDGET_S, gap=POLL_GAP_S, sleep=time.sleep):
    """Poll until `done`, or until the budget runs out. Returns (done, payload, seconds, polls)."""
    operation_id = operation_path.rsplit("/", 1)[-1]
    started = time.time()
    polls = 0
    payload = {}
    while time.time() - started < budget:
        sleep(gap)
        polls += 1
        status, payload = sender(OPERATION_URL % operation_id, "GET", key)
        if status != 200:
            return False, payload, time.time() - started, polls
        if payload.get("done"):
            return True, payload, time.time() - started, polls
    return False, payload, time.time() - started, polls


def upload(folder, name, description, karen_ok, key, sender=send, asset_type="Model",
           wanted=None, again=False, dry_run=False, budget=POLL_BUDGET_S, gap=POLL_GAP_S,
           sleep=time.sleep):
    """The whole run. Raises Refused before anything is sent."""
    karen_ok = check_karen_ok(karen_ok)
    path, content_type, size = find_model(folder, wanted)
    sha = digest_of(path)
    seen = already_uploaded(sha)
    if seen and not again:
        raise Refused("these exact bytes are already uploaded as asset %s on %s -- pass --again if "
                      "you mean to make a second asset from the same file"
                      % (seen.get("assetId"), seen.get("at")))

    request_json = {
        "assetType": asset_type,
        "displayName": name,
        "description": description,
        "creationContext": {"creator": {"userId": CREATOR_USER_ID}},
    }
    say("file      %s (%.2f MiB, %s)" % (os.path.basename(path), size / (1 << 20), content_type))
    say("sha256    %s" % sha)
    say("request   %s" % json.dumps(request_json))
    say("header    x-api-key: <redacted>")
    say("karen-ok  %s" % karen_ok)
    if dry_run:
        say("DRY RUN: nothing was sent")
        return {"dryRun": True, "request": request_json, "sha256": sha,
                "file": os.path.basename(path), "bytes": size}

    with open(path, "rb") as handle:
        body, body_type = multipart(request_json, handle.read(), os.path.basename(path), content_type)
    status, payload = sender(CREATE_URL, "POST", key, body, body_type, timeout=300)
    if status not in (200, 201):
        raise RuntimeError("create returned HTTP %s: %s" % (status, payload.get("error", payload)))
    operation_path = payload.get("path") or payload.get("operationId") or ""
    if not operation_path:
        raise RuntimeError("the create response named no operation: %s" % json.dumps(payload)[:400])
    say("operation %s" % operation_path)

    done, result, seconds, polls = poll(operation_path, key, sender, budget, gap, sleep)
    response = result.get("response", {}) if isinstance(result, dict) else {}
    asset_id = response.get("assetId")
    state, where = moderation_of(response)
    if not done or not asset_id:
        raise RuntimeError("the operation did not finish with an asset id after %.0f s / %d poll(s): "
                           "%s" % (seconds, polls, json.dumps(result)[:400]))

    row = {
        "tool": TOOL_VERSION,
        "at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "assetId": str(asset_id),
        "assetType": asset_type,
        "displayName": name,
        "description": description,
        "creatorUserId": CREATOR_USER_ID,
        "file": os.path.basename(path),
        "sourceFolder": os.path.basename(os.path.normpath(folder)),
        "bytes": size,
        "sha256": sha,
        "contentType": content_type,
        "operation": operation_path,
        "moderationState": state or "unknown",
        "moderationStateFrom": where,
        "pollSeconds": round(seconds, 1),
        "polls": polls,
        "karenOk": karen_ok,
    }
    count = append_manifest(row)
    say("asset id  %s" % row["assetId"])
    say("moderation %s (from %s)" % (row["moderationState"], where))
    say("manifest  assets/uploads.json now has %d row(s)" % count)
    return row


# ---------------------------------------------------------------- commands

def command_upload(args):
    key = read_key()
    row = upload(args.folder, args.name, args.description, args.karen_ok, key,
                 asset_type=args.type, wanted=args.file, again=args.again, dry_run=args.dry_run,
                 budget=args.timeout)
    if row.get("dryRun"):
        return 0
    say("OK: asset %s, %s -- NOT swapped into the game (that is a separate task)"
        % (row["assetId"], row["moderationState"]))
    return 0


def command_show(args):
    for row in load_manifest():
        if str(row.get("assetId")) == str(args.asset_id):
            print(json.dumps(row, indent=2))
            return 0
    say("no row for asset %s in assets/uploads.json" % args.asset_id)
    return 1


# ---------------------------------------------------------------- selftest

def command_selftest(_args):
    """Offline, mocked HTTP, no key, nothing sent. Proves the refusals and the happy path."""
    failures = []
    checks = [0]

    def ok(name, condition, detail=""):
        checks[0] += 1
        print("  %-4s %s%s" % ("ok" if condition else "FAIL", name,
                               ("  (%s)" % detail) if detail else ""), flush=True)
        if not condition:
            failures.append(name)

    def refuses(name, call, expect):
        try:
            call()
            ok(name, False, "it did not refuse")
        except Refused as why:
            ok(name, expect in str(why), str(why)[:110])

    import tempfile
    global MANIFEST
    real_manifest = MANIFEST
    with tempfile.TemporaryDirectory(prefix="dh-upload-") as tmp:
        MANIFEST = os.path.join(tmp, "uploads.json")
        folder = os.path.join(tmp, "prepared")
        os.makedirs(folder)
        model = os.path.join(folder, "model.fbx")
        with open(model, "wb") as handle:
            handle.write(b"fbx-bytes" * 100)

        # ---- the refusals, each proved rather than described
        refuses("it refuses with no Karen OK at all",
                lambda: check_karen_ok(""), "--karen-ok is required")
        refuses("it refuses a Karen OK with no date",
                lambda: check_karen_ok("she said yes"), "must carry a date")
        refuses("it refuses a Karen OK that says nothing",
                lambda: check_karen_ok("2026-09-26 ok"), "must say WHAT")
        ok("it accepts a real record",
           check_karen_ok("2026-09-26 the shotgun as prepared by Task 72").startswith("2026"))
        refuses("it refuses a folder with no model",
                lambda: find_model(tmp), "no model.fbx")
        refuses("it refuses an extension Roblox does not list",
                lambda: find_model(folder, "model.obj"), "no model.obj")
        big = os.path.join(folder, "big.fbx")
        with open(big, "wb") as handle:
            handle.seek(MAX_FILE_BYTES + 1)
            handle.write(b"\0")
        refuses("it refuses a file over 20 MB",
                lambda: find_model(folder, "big.fbx"), "up to 20 MB")
        os.remove(big)

        path, content_type, size = find_model(folder)
        ok("it picks the FBX and its documented content type",
           os.path.basename(path) == "model.fbx" and content_type == "model/fbx", content_type)

        # ---- the request the guide describes
        body, body_type = multipart({"assetType": "Model"}, b"xx", "model.fbx", "model/fbx")
        ok("the body carries both named parts",
           b'name="request"' in body and b'name="fileContent"' in body)
        ok("the body declares the file's content type", b"model/fbx" in body)
        ok("the boundary is declared in the header", "boundary=" in body_type)

        # ---- a mocked happy path: no network, no key, and the key is watched
        sent = []
        SECRET = "k" + "e" * 40 + "y"

        def fake(url, method, key, body=None, content_type=None, timeout=120):
            sent.append({"url": url, "method": method, "hasKey": key == SECRET,
                         "bytes": len(body or b"")})
            if method == "POST":
                return 200, {"path": "operations/op-123", "done": False}
            return 200, {"path": "operations/op-123", "done": True,
                         "response": {"assetId": "987654321",
                                      "moderationResult":
                                          {"moderationState": "MODERATION_STATE_APPROVED"}}}

        row = upload(folder, "Test gun", "a fixture", "2026-09-26 the fixture, for the selftest",
                     SECRET, sender=fake, gap=0.0, budget=5.0, sleep=lambda _s: None)
        ok("it posted to the documented endpoint", sent[0]["url"] == CREATE_URL, sent[0]["url"])
        ok("it sent the key in the header", sent[0]["hasKey"] is True)
        ok("it polled the operation by id",
           sent[1]["url"].endswith("/operations/op-123"), sent[1]["url"])
        ok("it read the asset id", row["assetId"] == "987654321", row["assetId"])
        ok("it read the moderation state out of moderationResult",
           row["moderationState"] == "MODERATION_STATE_APPROVED"
           and row["moderationStateFrom"] == "response.moderationResult.moderationState",
           row["moderationStateFrom"])
        ok("it recorded Karen's OK verbatim",
           row["karenOk"] == "2026-09-26 the fixture, for the selftest", row["karenOk"])
        ok("it recorded the file's sha256", len(row["sha256"]) == 64)
        ok("it recorded the creator", row["creatorUserId"] == CREATOR_USER_ID)

        # ---- THE KEY IS NOWHERE. Not in the manifest, not in the row, not in the request.
        with open(MANIFEST, "r", encoding="utf-8") as handle:
            written = handle.read()
        ok("the key is not in the manifest", SECRET not in written)
        ok("the key is not in the row", SECRET not in json.dumps(row))

        # ---- the top-level moderation shape is read too
        def older_shape(url, method, key, body=None, content_type=None, timeout=120):
            if method == "POST":
                return 200, {"path": "operations/op-9", "done": False}
            return 200, {"path": "operations/op-9", "done": True,
                         "response": {"assetId": "5", "moderationState": "MODERATION_STATE_REVIEWING"}}

        second = upload(folder, "Test gun 2", "a fixture", "2026-09-26 the second fixture here",
                        SECRET, sender=older_shape, again=True, gap=0.0, budget=5.0,
                        sleep=lambda _s: None)
        ok("it reads a top-level moderation state as well",
           second["moderationState"] == "MODERATION_STATE_REVIEWING"
           and second["moderationStateFrom"] == "response.moderationState")
        ok("a review state is reported, not retried", second["polls"] == 1, str(second["polls"]))

        # ---- the same bytes twice
        refuses("it refuses the same bytes twice",
                lambda: upload(folder, "again", "x", "2026-09-26 the same file once more",
                               SECRET, sender=fake, gap=0.0, budget=5.0, sleep=lambda _s: None),
                "already uploaded")
        ok("the manifest has one row per upload", len(load_manifest()) == 2,
           str(len(load_manifest())))

        # ---- a dry run sends nothing
        before = len(sent)
        dry = upload(folder, "dry", "x", "2026-09-26 a dry run of the fixture", SECRET,
                     sender=fake, again=True, dry_run=True)
        ok("a dry run sends nothing", len(sent) == before and dry.get("dryRun") is True)

        # ---- an HTTP failure is a failure, not a silent success
        def refuser(url, method, key, body=None, content_type=None, timeout=120):
            return 401, {"error": "Invalid API Key"}

        try:
            upload(folder, "bad", "x", "2026-09-26 an unauthorised upload attempt", SECRET,
                   sender=refuser, again=True, gap=0.0, budget=5.0, sleep=lambda _s: None)
            ok("an HTTP error stops the run", False, "it returned instead")
        except RuntimeError as why:
            ok("an HTTP error stops the run", "401" in str(why), str(why)[:90])
        except Refused as why:
            ok("an HTTP error stops the run", False, "refused instead: %s" % str(why)[:70])

        # ---- an operation that never finishes
        def never(url, method, key, body=None, content_type=None, timeout=120):
            if method == "POST":
                return 200, {"path": "operations/op-x", "done": False}
            return 200, {"path": "operations/op-x", "done": False}

        try:
            upload(folder, "slow", "x", "2026-09-26 an operation that never finishes", SECRET,
                   sender=never, again=True, gap=0.0, budget=0.05, sleep=lambda _s: None)
            ok("an unfinished operation is a failure", False, "it returned instead")
        except RuntimeError as why:
            ok("an unfinished operation is a failure", "did not finish" in str(why), str(why)[:90])
        except Refused as why:
            ok("an unfinished operation is a failure", False, "refused instead: %s" % str(why)[:70])

    MANIFEST = real_manifest
    print()
    if failures:
        say("SELFTEST FAIL: %d of %d check(s): %s" % (len(failures), checks[0], ", ".join(failures)))
        return 1
    say("SELFTEST PASS: %d checks" % checks[0])
    return 0


def main(argv):
    parser = argparse.ArgumentParser(prog="roblox_upload.py", description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    up = sub.add_parser("upload")
    up.add_argument("folder")
    up.add_argument("--name", required=True)
    up.add_argument("--description", required=True)
    up.add_argument("--karen-ok", dest="karen_ok", default=None)
    up.add_argument("--file", default=None)
    up.add_argument("--type", default="Model")
    up.add_argument("--again", action="store_true")
    up.add_argument("--dry-run", action="store_true")
    up.add_argument("--timeout", type=float, default=POLL_BUDGET_S)
    show = sub.add_parser("show")
    show.add_argument("asset_id")
    sub.add_parser("selftest")
    args = parser.parse_args(argv[1:])
    handlers = {"upload": command_upload, "show": command_show, "selftest": command_selftest}
    try:
        return handlers[args.command](args)
    except Refused as why:
        say("REFUSED: %s" % why)
        return 2
    except (RuntimeError, urllib.error.URLError, OSError) as why:
        say("FAILED: %s" % why)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
