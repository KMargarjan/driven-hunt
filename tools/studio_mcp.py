"""Driven Hunt test harness. THIS DOCSTRING IS THE SINGLE SOURCE OF TRUTH for how the test system works.
CLAUDE.md keeps the commands and points here; the research note keeps decisions and dated measurements.

Pattern: minimal stdio JSON-RPC MCP client (https://modelcontextprotocol.io/specification) talking to
StudioMCP.exe, which ships with Roblox Studio (Assistant settings -> MCP server).
Note: docs/research/2026-09-24-toolchain.md

Requires: Studio open on the DEV place in Edit mode, MCP server enabled, Rojo plugin connected.

Usage:
  python tools/studio_mcp.py test      # full checked run; exit 0 only on a clean-tree PASS
  python tools/studio_mcp.py state     # print Studio mode (read-only)
  python tools/studio_mcp.py console   # print Studio Output (read-only)
  python tools/studio_mcp.py stop      # stop a playtest (recovery)
  python tools/studio_mcp.py manifest  # after `wally install`: rewrite devpackages.sha256 (commit it)

Exit codes of `test`: 0 PASS on a clean tree · 1 FAIL · 2 REFUSED (Studio not in Edit mode) ·
3 PASS on a dirty tree (flagged: not valid evidence).

Moving parts
  tests/TestKit.luau -> ReplicatedStorage.TestKit
      The one implementation of the gate, spec loading (pcall), TestEZ run and report.
  tests/TestRunner.server.luau -> ServerScriptService.TestRunner
      Runs server specs (tests/server -> ServerStorage.Tests). Report: ServerStorage attribute "TestReport".
  tests/ClientTestRunner.client.luau -> StarterPlayerScripts.ClientTestRunner
      Runs client specs (tests/client -> ReplicatedStorage.ClientTests) in the player's client.
      Report: LocalPlayer attribute "TestReport" (read from the Client DataModel).
  tests/sync-token.txt (git-ignored) -> ReplicatedStorage.TestSyncToken
      Gate. Runners run only in Studio and only if the token "<16 hex>:<unix time>" is < 120 s old.
      Only this harness writes it, and it clears it after every run, so Karen's playtests run no tests.
  Report (JSON): side, token, placeId, specs (full names), successCount, failureCount, skippedCount,
      errorCount, status (PASS | FAIL | ERROR), message. Runner status is PASS only if 0 failed, 0 errors,
      0 skipped (any SKIP/FOCUS variant fails) and > 0 passed; a spec that fails to load is ERROR.

What `test` checks, in order (each is one "ok"/"FAIL" line)
  1. Git: records HEAD and whether the tree is dirty (`git status --porcelain`), again at the end.
  2. Studio is in Edit mode (else REFUSED, exit 2); the open place's PlaceId is servePlaceIds[0].
  3. A fresh token written to disk reaches Studio (so Rojo is live and caught up).
  4. Every synced instance (`rojo sourcemap --include-non-scripts`) exists in Studio with the right
     ClassName, and has no same-named sibling. Every synced file is compared:
       *.luau / *.lua   script Source, byte-for-byte (line endings normalised)
       *.txt            StringValue.Value
       *.model.json     ClassName, properties, attributes and children, recursively; a Script,
                        LocalScript or ModuleScript inside one is refused (scripts are .luau files)
       *.meta.json      properties and attributes of the instance; "ignoreUnknownInstances" is refused
       default.project.json  structure (instance checks); $properties/$attributes are refused
       nested *.project.json refused, except third-party ones under DevPackages/
       *.rbxm / *.rbxmx BANNED: binary, unreviewable in a PR, cannot be compared
       anything else    "cannot compare" -> FAIL, never skipped
     Properties/attributes are compared when their JSON value is a plain string/number/bool (attributes
     exactly; properties exactly or as their float32 rounding); a typed
     value ({"Vector3": ...}) fails as "cannot compare" until a comparison is added.
     No synced file may be git-ignored or outside the repo (it would be tested but could never make the
     tree dirty).
     DevPackages/ (git-ignored TestEZ, which counts the passes) must match the committed
     devpackages.sha256 (which also pins the wally.lock hash).
  5. No script (LuaSourceContainer) exists anywhere in the DataModel outside the sourcemap: nothing
     script-like may be created in Studio. Every service must be readable by that scan.
  6. Every *.spec.* file in the repo (git ls-files: tracked + untracked, non-ignored) is synced into
     ServerStorage.Tests (server) or ReplicatedStorage.ClientTests (client).
  7. Play. Both reports arrive; each carries this run's token and the DEV PlaceId; each runner ran
     exactly the spec files of its side (matched by name); each status is PASS with > 0 passed,
     0 failed, 0 errors, 0 skipped.
  8. Stop. The token is cleared and the gate is seen closed in Studio.
  9. Final line: "[harness] PASS|FAIL: n/m checks @ <full HEAD sha> (clean tree | DIRTY TREE ...)".
     A PASS is evidence for a PR only if the sha equals the PR head and the tree is clean.

Client-side testing (camera, input, cursor, UI)
  Client specs run inside the real player client and can assert camera, input, cursor and UI state.
  Not yet wired: driving real input (StudioMCP's user_keyboard_input / user_mouse_input exist but the
  harness does not call them), and play-time screenshots (StudioMCP's screen_capture is edit-time
  only). Both are logged in TASKS.md as blocking before input-driven or visual client code.

Safety
  The harness only writes tests/sync-token.txt. Its Luau is read-only: constant queries, or queries
  templated with JSON data (QUERY_*). There is no command for arbitrary Luau or arbitrary MCP tools.
"""

import glob
import hashlib
import json
import os
import queue
import secrets
import shutil
import struct
import subprocess
import sys
import threading
import time
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(REPO, "default.project.json")
TOKEN_FILE = os.path.join(REPO, "tests", "sync-token.txt")
SPEC_ROOTS = {"server": ("ServerStorage", "Tests"), "client": ("ReplicatedStorage", "ClientTests")}

# Read-only Luau queries. Keep every query here, read-only. Templated ones take JSON via luau_json().
QUERY_PLACE_ID = "return tostring(game.PlaceId)"
QUERY_TOKEN = """
local v = game:GetService("ReplicatedStorage"):FindFirstChild("TestSyncToken")
return if v and v:IsA("StringValue") then v.Value else "<missing>"
"""
QUERY_REPORT = {
    "server": 'return game:GetService("ServerStorage"):GetAttribute("TestReport") or ""',
    "client": 'local p = game:GetService("Players").LocalPlayer return p and p:GetAttribute("TestReport") or ""',
}
QUERY_NODES = """
local HttpService = game:GetService("HttpService")
local wanted = HttpService:JSONDecode(%s)
local function encode(v)
	local t = typeof(v)
	if t == "string" or t == "number" or t == "boolean" then
		return { t = t, v = v }
	elseif t == "EnumItem" then
		return { t = t, v = v.Name }
	end
	return { t = t, v = tostring(v) }
end
local out = {}
for i, w in wanted do
	local inst, dup = game, 0
	for _, name in w.path do
		local nextInst, count = nil, 0
		if inst then
			for _, child in inst:GetChildren() do
				if child.Name == name then
					count += 1
					nextInst = nextInst or child
				end
			end
		end
		dup = math.max(dup, count)
		inst = nextInst
	end
	if not inst then
		out[i] = { missing = true }
	else
		local props, attrs = {}, {}
		for _, p in w.props do
			local ok, v = pcall(function()
				return (inst :: any)[p]
			end)
			props[p] = if ok then encode(v) else { t = "error", v = tostring(v) }
		end
		for _, a in w.attrs do
			local v = inst:GetAttribute(a)
			attrs[a] = if v == nil then { t = "nil", v = "" } else encode(v)
		end
		out[i] = {
			className = inst.ClassName,
			dup = dup,
			source = if inst:IsA("LuaSourceContainer") then (inst :: any).Source else nil,
			value = if inst:IsA("StringValue") then (inst :: any).Value else nil,
			props = props,
			attrs = attrs,
		}
	end
end
return HttpService:JSONEncode(out)
"""
QUERY_ALL_SCRIPTS = """
local HttpService = game:GetService("HttpService")
local out, unreadable = {}, {}
for _, service in game:GetChildren() do
	local ok, descendants = pcall(function()
		return service:GetDescendants()
	end)
	if not ok then
		table.insert(unreadable, service.Name)
		continue
	end
	for _, d in descendants do
		if d:IsA("LuaSourceContainer") then
			local path, node = {}, d
			while node and node ~= game do
				table.insert(path, 1, node.Name)
				node = node.Parent
			end
			table.insert(out, path)
		end
	end
end
return HttpService:JSONEncode({ scripts = out, unreadable = unreadable })
"""


def luau_json(obj):
    """Embed JSON in Luau as a long-bracket string (no escape rules, so non-ASCII names survive)."""
    text = json.dumps(obj, ensure_ascii=False)
    level = 0
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    # Newlines keep the text's own first/last bracket from fusing with the delimiters; Luau drops the
    # first newline and JSON ignores whitespace.
    return "[" + eq + "[\n" + text + "\n]" + eq + "]"


def find_exe():
    pattern = os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\StudioMCP.exe")
    exes = sorted(glob.glob(pattern), key=os.path.getmtime)
    if not exes:
        sys.exit("StudioMCP.exe not found under %LOCALAPPDATA%\\Roblox\\Versions")
    return exes[-1]


class Studio:
    def __init__(self):
        self.proc = subprocess.Popen(
            [find_exe()], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
        )
        self.lines = queue.Queue()
        threading.Thread(target=self._pump, daemon=True).start()
        self.next_id = 0
        self._rpc("initialize", {
            "protocolVersion": "2025-03-26",
            "capabilities": {},
            "clientInfo": {"name": "driven-hunt-tools", "version": "0.3.0"},
        })
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        # Studio polls localhost:13469 roughly every 5s, so wait for it to attach.
        for _ in range(20):
            if '"studios":[]' not in self._call("list_roblox_studios"):
                return
            time.sleep(1)
        sys.exit("No Studio connected. Is a place open and the MCP server enabled in Assistant settings?")

    def _pump(self):
        for line in self.proc.stdout:
            self.lines.put(line)

    def _send(self, msg):
        self.proc.stdin.write((json.dumps(msg) + "\n").encode())
        self.proc.stdin.flush()

    def _rpc(self, method, params, timeout=120):
        self.next_id += 1
        self._send({"jsonrpc": "2.0", "id": self.next_id, "method": method, "params": params})
        while True:
            msg = json.loads(self.lines.get(timeout=timeout))
            if msg.get("id") == self.next_id:
                if "error" in msg:
                    raise RuntimeError(msg["error"])
                return msg["result"]

    def _call(self, tool, args=None):
        result = self._rpc("tools/call", {"name": tool, "arguments": args or {}})
        text = "\n".join(c.get("text", "") for c in result.get("content", []))
        if result.get("isError"):
            raise RuntimeError(f"{tool}: {text}")
        return text

    # The only operations this harness exposes.
    def mode(self):
        state = self._call("get_studio_state")
        for line in state.splitlines():
            if "Current Studio Mode:" in line:
                return line.split(":", 1)[1].strip()
        return state

    def console(self):
        return self._call("get_console_output")

    def set_play(self, playing):
        return self._call("start_stop_play", {"is_start": playing})

    def query(self, datamodel, code):
        return self._call("execute_luau", {"datamodel_type": datamodel, "code": code})

    def close(self):
        self.proc.kill()


# ---------------------------------------------------------------- git, project, disk

def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True, cwd=REPO).stdout


def git_state():
    """(HEAD sha, list of dirty paths). sync-token.txt is git-ignored, so the harness never dirties the tree."""
    return git("rev-parse", "HEAD").strip(), [l for l in git("status", "--porcelain").splitlines() if l.strip()]


def expected_place_id():
    with open(PROJECT, encoding="utf-8") as f:
        ids = json.load(f).get("servePlaceIds") or []
    if len(ids) != 1:
        raise RuntimeError("default.project.json must list exactly one servePlaceIds entry")
    return str(ids[0])


def spec_files_in_repo():
    """Every *.spec.* file in the repo: tracked plus untracked, non-ignored files.

    Git-ignored folders (DevPackages/, Packages/) are third-party code; their own specs are not ours.
    """
    return sorted(
        f for f in git("ls-files", "--cached", "--others", "--exclude-standard").splitlines()
        if ".spec." in os.path.basename(f) and os.path.exists(os.path.join(REPO, f))
    )


def synced_nodes():
    """[(instance path list, className, [file paths relative to REPO])] from the sourcemap, root excluded."""
    rojo = shutil.which("rojo") or os.path.expanduser(r"~\.rokit\bin\rojo.exe")
    out = subprocess.run(
        [rojo, "sourcemap", PROJECT, "--include-non-scripts"],
        capture_output=True, text=True, check=True, cwd=REPO,
    ).stdout
    nodes = []

    def walk(node, path):
        if path:
            nodes.append((path, node["className"], [f.replace("\\", "/") for f in node.get("filePaths", [])]))
        for child in node.get("children", []):
            walk(child, path + [child["name"]])

    walk(json.loads(out), [])
    return nodes


def project_refusals():
    """$properties/$attributes in default.project.json are not compared, so they are refused."""
    with open(PROJECT, encoding="utf-8") as f:
        tree = json.load(f)["tree"]
    problems = []

    def walk(node, path):
        for key in ("$properties", "$attributes"):
            if key in node:
                problems.append(f"{'.'.join(path) or 'DataModel'}: {key} in default.project.json is not compared "
                                "(put it in a .meta.json instead)")
        for name, child in node.items():
            if not name.startswith("$") and isinstance(child, dict):
                walk(child, path + [name])

    walk(tree, [])
    return problems


def ignored_synced_files(nodes):
    """Synced files outside git's view: git-ignored, or outside the repo. Either would be tested but could
    never make the tree dirty (and would escape lint), so each one fails the run."""
    files = sorted({f for _, _, fs in nodes for f in fs
                    if f != "tests/sync-token.txt" and not f.startswith("DevPackages/")})
    root = os.path.realpath(REPO) + os.sep
    outside = [f for f in files if os.path.isabs(f) or not os.path.realpath(os.path.join(REPO, f)).startswith(root)]
    inside = [f for f in files if f not in outside]
    # NUL-separated bytes: text mode on Windows turns "\n" into "\r\n", which breaks name patterns like *.key
    r = subprocess.run(["git", "check-ignore", "-z", "--stdin"], input="\0".join(inside).encode("utf-8"),
                       capture_output=True, cwd=REPO)
    if r.returncode not in (0, 1):  # 0 = some ignored, 1 = none ignored, anything else = git failed
        raise RuntimeError(f"git check-ignore failed ({r.returncode}): {r.stderr.decode(errors='replace').strip()}")
    return [f + " (outside the repo)" for f in outside] + [p for p in r.stdout.decode("utf-8").split("\0") if p]


DEVPACKAGES_MANIFEST = os.path.join(REPO, "devpackages.sha256")


def sha256(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def devpackages_manifest():
    """Lines: 'wally.lock <sha>' then '<sha>  <path>' for every file under DevPackages/, sorted."""
    lines = [f"wally.lock {sha256(os.path.join(REPO, 'wally.lock'))}"]
    root = os.path.join(REPO, "DevPackages")
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            lines.append(f"{sha256(full)}  {os.path.relpath(full, REPO).replace(os.sep, '/')}")
    return [lines[0]] + sorted(lines[1:])


def devpackages_problems():
    """DevPackages (TestEZ, which counts passes) is git-ignored; tie it to the commit via devpackages.sha256."""
    if not os.path.exists(DEVPACKAGES_MANIFEST):
        return ["devpackages.sha256 missing (run `python tools/studio_mcp.py manifest` after `wally install`)"]
    with open(DEVPACKAGES_MANIFEST, encoding="utf-8") as f:
        committed = [l for l in f.read().splitlines() if l.strip()]
    current = devpackages_manifest()
    if committed[:1] != current[:1]:
        return ["wally.lock changed since devpackages.sha256 was written (run `wally install`, then `manifest`)"]
    diff = sorted(set(committed) ^ set(current))
    return [f"DevPackages differ from devpackages.sha256: {len(diff)} line(s), e.g. {diff[0][-80:]}"] if diff else []


def read_disk(rel):
    with open(os.path.join(REPO, rel), encoding="utf-8", newline="") as f:
        return f.read().replace("\r\n", "\n")


# ---------------------------------------------------------------- comparison

def is_plain(v):
    return isinstance(v, (str, bool, int, float))


def same_value(expected, got, float32=False):
    """Compare a plain JSON value from disk with an encoded Studio value {t, v}.

    Numbers: attributes are doubles, so they must be equal exactly. Properties may be float32, so they
    match if Studio holds the value exactly or holds its float32 rounding (nothing looser).
    """
    if got["t"] in ("error", "nil"):
        return False
    if isinstance(expected, bool) or got["t"] == "boolean":
        return isinstance(expected, bool) and got["t"] == "boolean" and expected == got["v"]
    if isinstance(expected, (int, float)) and got["t"] == "number":
        value = float(got["v"])
        if value == float(expected):
            return True
        try:
            return float32 and value == struct.unpack("f", struct.pack("f", float(expected)))[0]
        except OverflowError:  # beyond float32 range: cannot be a float32 rounding, so it is a mismatch
            return False
    return isinstance(expected, str) and str(got["v"]) == expected


def expectations_for(path, files, problems):
    """Turn one node's files into [(path, spec)] comparison requests; problems collects refusals."""
    requests = []
    for rel in files:
        name = ".".join(path)
        low = rel.lower()
        if low.endswith((".rbxm", ".rbxmx")):
            problems.append(f"{name}: {rel} is BANNED (binary model; use .model.json)")
        elif low.endswith(".project.json"):
            if rel.startswith("DevPackages/"):
                pass  # third-party package project; DevPackages are checked against devpackages.sha256
            elif rel != "default.project.json":
                problems.append(f"{name}: nested project file {rel} is not supported (not compared)")
        elif low.endswith((".luau", ".lua")):
            requests.append((path, {"kind": "source", "file": rel}))
        elif low.endswith(".txt"):
            requests.append((path, {"kind": "value", "file": rel}))
        elif low.endswith(".meta.json"):
            data = json.loads(read_disk(rel))
            if "ignoreUnknownInstances" in data:
                problems.append(f"{name}: {rel} sets ignoreUnknownInstances (refused: Studio-made instances "
                                "must not survive in Rojo-owned paths)")
            requests.append((path, {"kind": "props", "file": rel,
                                    "props": data.get("properties", {}), "attrs": data.get("attributes", {})}))
        elif low.endswith(".model.json"):
            def walk_model(model, mpath):
                props = model.get("properties", model.get("Properties", {}))
                attrs = model.get("attributes", model.get("Attributes", {}))
                cls = model.get("className", model.get("ClassName"))
                if cls in ("Script", "LocalScript", "ModuleScript"):
                    problems.append(f"{'.'.join(mpath)}: {rel} defines a {cls}; scripts must be .luau files "
                                    "(linted, formatted, reviewable), never Source inside .model.json")
                requests.append((mpath, {"kind": "props", "file": rel, "className": cls,
                                         "props": props, "attrs": attrs}))
                for child in model.get("children", model.get("Children", [])):
                    walk_model(child, mpath + [child.get("name", child.get("Name"))])
            walk_model(json.loads(read_disk(rel)), path)
        else:
            problems.append(f"{name}: cannot compare {rel} (unsupported file type; add a comparison)")
    return requests


def compare_synced(studio, nodes):
    """Compare every synced instance and file with Studio. Returns a list of problems (empty = match)."""
    problems = []
    requests = [(path, {"kind": "node", "className": cls}) for path, cls, _ in nodes]
    for path, _, files in nodes:
        requests += expectations_for(path, files, problems)

    wanted = []
    for path, spec in requests:
        props = [p for p, v in spec.get("props", {}).items() if is_plain(v)]
        attrs = [a for a, v in spec.get("attrs", {}).items() if is_plain(v)]
        wanted.append({"path": path, "props": props, "attrs": attrs})
    # StudioMCP truncates tool results at roughly 100 KB, and each result carries full script Sources,
    # so query in small batches. A truncated result fails loudly as a JSON error, never passes.
    remote = []
    for i in range(0, len(wanted), 8):
        remote += json.loads(studio.query("Edit", QUERY_NODES % luau_json(wanted[i:i + 8])))

    if len(remote) != len(requests):
        raise RuntimeError(f"Studio answered {len(remote)} of {len(requests)} node queries")
    for (path, spec), got in zip(requests, remote):
        name = ".".join(path)
        if got.get("missing"):
            problems.append(f"{name}: missing in Studio")
            continue
        if got["dup"] > 1:
            problems.append(f"{name}: {got['dup']} same-named siblings on its path (ambiguous)")
        cls = spec.get("className")
        if cls and got["className"] != cls:
            problems.append(f"{name}: ClassName {got['className']} in Studio, {cls} expected")
        kind = spec["kind"]
        if kind == "source":
            if got.get("source") is None or got["source"].replace("\r\n", "\n") != read_disk(spec["file"]):
                problems.append(f"{name}: Source differs from {spec['file']}")
        elif kind == "value":
            if got.get("value") is None or got["value"].replace("\r\n", "\n") != read_disk(spec["file"]):
                problems.append(f"{name}: Value differs from {spec['file']}")
        elif kind == "props":
            for group, values in (("props", spec["props"]), ("attrs", spec["attrs"])):
                for key, expected in values.items():
                    if not is_plain(expected):
                        problems.append(f"{name}: cannot compare {group[:-1]} {key} in {spec['file']} "
                                        "(typed value; add a comparison)")
                    elif not same_value(expected, got[group][key], float32=(group == "props")):
                        problems.append(f"{name}: {group[:-1]} {key} is {got[group][key]['v']!r} in Studio, "
                                        f"{expected!r} in {spec['file']}")
    return problems


def unmanaged_scripts(studio, nodes):
    """Scripts in Studio that the sourcemap does not account for (including extra same-named copies)."""
    result = json.loads(studio.query("Edit", QUERY_ALL_SCRIPTS))
    known = {}
    for path, cls, _ in nodes:
        if cls in ("Script", "LocalScript", "ModuleScript"):
            known[tuple(path)] = known.get(tuple(path), 0) + 1
    seen = {}
    for path in result["scripts"]:
        seen[tuple(path)] = seen.get(tuple(path), 0) + 1
    extra = [".".join(p) + (f" (x{n})" if n > 1 else "") for p, n in seen.items() if n > known.get(p, 0)]
    return sorted(extra), result["unreadable"]


# ---------------------------------------------------------------- run

def write_token(value):
    with open(TOKEN_FILE, "w", encoding="utf-8", newline="") as f:
        f.write(value)


def wait_for(fn, predicate, timeout, interval=0.5):
    deadline = time.time() + timeout
    value = None
    while time.time() < deadline:
        try:
            value = fn()
        except RuntimeError:
            value = None
        if value is not None and predicate(value):
            return value, True
        time.sleep(interval)
    return value, False


def run_test(studio):
    checks = []

    def check(name, ok, detail=""):
        checks.append(ok)
        print(("  ok   " if ok else "  FAIL ") + name + (f"  ({detail})" if detail else ""))
        return ok

    def verdict(code=None):
        sha_end, dirty_end = git_state()
        check("HEAD unchanged during the run", sha_end == sha, f"{sha[:12]} -> {sha_end[:12]}")
        dirty = dirty_start or dirty_end
        passed = all(checks) and code is None
        tree = "clean tree" if not dirty else f"DIRTY TREE ({len(set(dirty_start + dirty_end))} paths) - NOT valid evidence"
        print(f"[harness] {'PASS' if passed else 'FAIL'}: {sum(checks)}/{len(checks)} checks @ {sha} ({tree})")
        if dirty:
            for line in sorted(set(dirty_start + dirty_end))[:10]:
                print("    dirty: " + line)
        if code is not None:
            return code
        return 1 if not passed else (3 if dirty else 0)

    sha, dirty_start = git_state()
    print(f"[harness] testing {sha} ({'clean' if not dirty_start else 'DIRTY'} tree)")

    mode = studio.mode()
    if not check("Studio is in Edit mode before the run", mode == "Edit", mode):
        print("[harness] REFUSED: stop the playtest first (python tools/studio_mcp.py stop)")
        return verdict(2)

    place = expected_place_id()
    actual_place = studio.query("Edit", QUERY_PLACE_ID)
    if not check("Studio has the DEV place open", actual_place == place, f"{actual_place} vs {place}"):
        return verdict()

    token = f"{secrets.token_hex(8)}:{int(time.time())}"
    write_token(token)
    reports, output = {}, ""
    try:
        seen, ok = wait_for(lambda: studio.query("Edit", QUERY_TOKEN), lambda v: v == token, 15)
        if not check("Rojo synced the fresh token from disk", ok, f"Studio has {seen!r}"):
            try:
                urllib.request.urlopen("http://localhost:34872/api/rojo", timeout=3).read()
                print("[harness] `rojo serve` answers, so the Rojo plugin is probably not connected: press Connect.")
            except OSError:
                print("[harness] `rojo serve` is NOT running (crashed?). Known Rojo 7.7.0 bug: it panics when a "
                      "watched file/folder disappears (rojo-rbx/rojo#1309, #1321). Restart it, then press Connect.")
            return verdict()

        nodes = synced_nodes()
        n_files = sum(len(f) for _, _, f in nodes)
        problems = compare_synced(studio, nodes)
        check(f"All {len(nodes)} synced instances and {n_files} files match disk", not problems,
              "; ".join(problems[:5]) + (f" (+{len(problems) - 5} more)" if len(problems) > 5 else ""))

        problems = project_refusals()
        check("default.project.json has no uncompared $properties/$attributes", not problems, "; ".join(problems))
        ignored = ignored_synced_files(nodes)
        check("No synced file is git-ignored or outside the repo (all tested code is in the commit or shows as dirty)", not ignored,
              ", ".join(ignored[:8]))
        problems = devpackages_problems()
        check("DevPackages (TestEZ) match the committed devpackages.sha256", not problems, "; ".join(problems))

        extra, unreadable = unmanaged_scripts(studio, nodes)
        check("No script exists outside Rojo-managed paths", not extra, ", ".join(extra[:8]))
        check("Every service was readable by the script scan", not unreadable, ", ".join(unreadable))

        spec_files = spec_files_in_repo()
        file_to_path = {f: tuple(p) for p, _, files in nodes for f in files}
        expected = {"server": {}, "client": {}}
        misplaced = []
        for f in spec_files:
            path = file_to_path.get(f)
            side = next((s for s, root in SPEC_ROOTS.items() if path and path[:2] == root), None)
            if side:
                expected[side][".".join(path)] = f
            else:
                misplaced.append(f + (" (not synced)" if not path else f" (synced to {'.'.join(path)})"))
        print(f"[harness] {len(spec_files)} *.spec.* file(s) in repo: {', '.join(spec_files)}")
        check("Every *.spec.* file is synced into ServerStorage.Tests or ReplicatedStorage.ClientTests",
              not misplaced, ", ".join(misplaced))

        print("[harness] Play")
        studio.set_play(True)
        try:
            for side in ("server", "client"):
                raw, ok = wait_for(lambda: studio.query(side.capitalize(), QUERY_REPORT[side]), lambda v: v != "", 60, 1)
                if ok:
                    reports[side] = json.loads(raw)
            output = studio.console()
        finally:
            studio.set_play(False)
    finally:
        write_token("")  # close the gate so Karen's playtests do not run tests

    print("----- Studio Output -----")
    print(output)
    print("-------------------------")
    for side in ("server", "client"):
        report = reports.get(side)
        if not check(f"[{side}] runner reported within 60 s", report is not None):
            continue
        check(f"[{side}] report carries this run's token", report["token"] == token, report["token"])
        check(f"[{side}] report comes from the DEV place", str(report["placeId"]) == place, str(report["placeId"]))
        ran = set(report.get("specs", []))
        not_run = sorted(f for inst, f in expected[side].items() if inst not in ran)
        not_in_repo = sorted(ran - set(expected[side]))
        check(f"[{side}] ran exactly the repo's {side} spec files", not not_run and not not_in_repo,
              "not run: " + ", ".join(not_run) + "; not in repo: " + ", ".join(not_in_repo)
              if (not_run or not_in_repo) else f"{len(ran)} ran")
        check(f"[{side}] status PASS", report["status"] == "PASS", report["status"] + " " + report.get("message", ""))
        check(f"[{side}] > 0 passed, 0 failed, 0 errors, 0 skipped",
              report["successCount"] > 0 and report["failureCount"] == 0
              and report["errorCount"] == 0 and report["skippedCount"] == 0,
              f"{report['successCount']} passed, {report['failureCount']} failed, "
              f"{report['errorCount']} errors, {report['skippedCount']} skipped")

    closed, ok = wait_for(lambda: studio.query("Edit", QUERY_TOKEN), lambda v: v == "", 15)
    check("Gate closed afterwards (token cleared in Studio)", ok, repr(closed))
    return verdict()


def main(argv):
    if len(argv) != 2 or argv[1] not in ("test", "state", "console", "stop", "manifest"):
        sys.exit(__doc__)
    if argv[1] == "manifest":
        with open(DEVPACKAGES_MANIFEST, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(devpackages_manifest()) + "\n")
        print(f"wrote {DEVPACKAGES_MANIFEST}")
        return 0
    studio = Studio()
    try:
        cmd = argv[1]
        if cmd == "test":
            try:
                return run_test(studio)
            except Exception as e:  # a harness fault is a FAIL, never a silent traceback (rule 6)
                try:
                    sha = git_state()[0]
                except Exception:
                    sha = "<unknown sha>"
                print(f"[harness] FAIL: harness error @ {sha}: {type(e).__name__}: {e}")
                return 1
        if cmd == "state":
            print(studio.mode())
        elif cmd == "console":
            print(studio.console())
        elif cmd == "stop":
            print(studio.set_play(False))
        return 0
    finally:
        studio.close()


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv))
