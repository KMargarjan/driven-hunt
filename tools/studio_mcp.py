"""Test harness: drive a running Roblox Studio via Studio's built-in MCP server.

Pattern: minimal stdio JSON-RPC MCP client (https://modelcontextprotocol.io/specification)
talking to StudioMCP.exe, which ships with Roblox Studio (Assistant settings -> MCP server).
Note: docs/research/2026-09-24-toolchain.md

Requires: Studio open on the DEV place, MCP server enabled, Rojo plugin connected to `rojo serve`.

Usage:
  python tools/studio_mcp.py test      # full checked test run (see run_test); exit 0 only on PASS
  python tools/studio_mcp.py state     # print Studio mode (read-only)
  python tools/studio_mcp.py console   # print Studio Output (read-only)
  python tools/studio_mcp.py stop      # stop a playtest (recovery)

Safety: this tool never writes to the DataModel. It only sends the constant, read-only Luau
queries defined in this file (QUERY_*). There is deliberately no command for arbitrary Luau or
arbitrary MCP tools. The only thing it writes is the git-ignored file tests/sync-token.txt,
which Rojo syncs into ServerStorage.TestSyncToken.
"""

import glob
import json
import os
import queue
import secrets
import shutil
import subprocess
import sys
import threading
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(REPO, "default.project.json")
TOKEN_FILE = os.path.join(REPO, "tests", "sync-token.txt")

# Read-only Luau queries. Keep every query here, as a constant, and read-only.
QUERY_PLACE_ID = "return tostring(game.PlaceId)"
QUERY_TOKEN = """
local v = game:GetService("ServerStorage"):FindFirstChild("TestSyncToken")
return if v and v:IsA("StringValue") then v.Value else "<missing>"
"""
QUERY_REPORT = 'return game:GetService("ServerStorage"):GetAttribute("TestReport") or ""'
QUERY_NODES = """
local HttpService = game:GetService("HttpService")
local paths = HttpService:JSONDecode(%s)
local out = {}
for i, path in paths do
	local inst = game
	for _, name in path do
		inst = inst and inst:FindFirstChild(name)
	end
	out[i] = if inst
		then {
			className = inst.ClassName,
			source = if inst:IsA("LuaSourceContainer") then inst.Source else nil,
			value = if inst:IsA("StringValue") then inst.Value else nil,
		}
		else { missing = true }
end
return HttpService:JSONEncode(out)
"""


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
            "clientInfo": {"name": "driven-hunt-tools", "version": "0.2.0"},
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


def expected_place_id():
    with open(PROJECT, encoding="utf-8") as f:
        ids = json.load(f).get("servePlaceIds") or []
    if len(ids) != 1:
        sys.exit("default.project.json must list exactly one servePlaceIds entry")
    return str(ids[0])


def spec_files_in_repo():
    """Every *.spec.* file anywhere in the repo: tracked files plus untracked, non-ignored ones.

    Git-ignored folders (DevPackages/, Packages/) are third-party code, and their own specs are not ours.
    """
    out = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
        capture_output=True, text=True, check=True, cwd=REPO,
    ).stdout
    return sorted(
        f for f in out.splitlines()
        if ".spec." in os.path.basename(f) and os.path.exists(os.path.join(REPO, f))
    )


def synced_nodes():
    """Every instance Rojo syncs (scripts and non-scripts) from `rojo sourcemap --include-non-scripts`.

    Returns [(instance path list, className, [file paths relative to REPO, forward slashes])].
    """
    rojo = shutil.which("rojo") or os.path.expanduser(r"~\.rokit\bin\rojo.exe")
    out = subprocess.run(
        [rojo, "sourcemap", PROJECT, "--include-non-scripts"],
        capture_output=True, text=True, check=True, cwd=REPO,
    ).stdout
    nodes = []

    def walk(node, path):
        if path:  # skip the DataModel root itself
            files = [f.replace("\\", "/") for f in node.get("filePaths", [])]
            nodes.append((path, node["className"], files))
        for child in node.get("children", []):
            walk(child, path + [child["name"]])

    walk(json.loads(out), [])
    return nodes


def read_disk(rel):
    with open(os.path.join(REPO, rel), encoding="utf-8", newline="") as f:
        return f.read().replace("\r\n", "\n")


def compare_synced(studio, nodes):
    """Compare every synced instance and file with Studio. Returns a list of problems (empty = match).

    Every instance must exist with the same ClassName. Every file must be comparable:
      *.project.json      structure only, covered by the instance/ClassName check of every node
      *.luau / *.lua      script Source, byte-for-byte (line endings normalised)
      *.txt               StringValue.Value, byte-for-byte
    Any other file type is a problem ("cannot compare"), never silently skipped.
    """
    payload = json.dumps(json.dumps([p for p, _, _ in nodes]))
    remote = json.loads(studio.query("Edit", QUERY_NODES % payload))
    problems = []
    for (path, class_name, files), got in zip(nodes, remote):
        name = ".".join(path)
        if got.get("missing"):
            problems.append(f"{name}: missing in Studio")
            continue
        if got["className"] != class_name:
            problems.append(f"{name}: ClassName {got['className']} in Studio, {class_name} expected")
            continue
        for rel in files:
            if rel.endswith(".project.json"):
                continue
            if rel.endswith((".luau", ".lua")) and got.get("source") is not None:
                if got["source"].replace("\r\n", "\n") != read_disk(rel):
                    problems.append(f"{name}: Source differs from {rel}")
            elif rel.endswith(".txt") and got.get("value") is not None:
                if got["value"].replace("\r\n", "\n") != read_disk(rel):
                    problems.append(f"{name}: Value differs from {rel}")
            else:
                problems.append(f"{name}: cannot compare {rel} (unsupported file type; add a comparison)")
    return problems


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

    print("[harness] preflight")
    mode = studio.mode()
    if not check("Studio is in Edit mode before the run", mode == "Edit", mode):
        print("[harness] REFUSED: stop the playtest first (python tools/studio_mcp.py stop)")
        return 2

    place = expected_place_id()
    actual_place = studio.query("Edit", QUERY_PLACE_ID)
    if not check("Studio has the DEV place open", actual_place == place, f"{actual_place} vs {place}"):
        return 1

    token = f"{secrets.token_hex(8)}:{int(time.time())}"
    write_token(token)
    try:
        seen, ok = wait_for(lambda: studio.query("Edit", QUERY_TOKEN), lambda v: v == token, 15)
        if not check("Rojo synced the fresh token from disk", ok, f"Studio has {seen!r}"):
            print("[harness] is `rojo serve` running and the Rojo plugin connected?")
            return 1

        nodes = synced_nodes()
        n_files = sum(len(f) for _, _, f in nodes)
        problems = compare_synced(studio, nodes)
        check(f"All {len(nodes)} synced instances and {n_files} files match disk", not problems, "; ".join(problems[:5]))

        spec_files = spec_files_in_repo()
        file_to_instance = {f: ".".join(p) for p, _, files in nodes for f in files}
        expected_specs = {file_to_instance[f]: f for f in spec_files if f in file_to_instance}
        unsynced = [f for f in spec_files if f not in file_to_instance]
        print(f"[harness] {len(spec_files)} *.spec.* file(s) in repo: {', '.join(spec_files)}")
        check("Every *.spec.* file in the repo is synced into Studio", not unsynced, ", ".join(unsynced))

        print("[harness] Play")
        studio.set_play(True)
        try:
            raw, ok = wait_for(lambda: studio.query("Server", QUERY_REPORT), lambda v: v != "", 60, 1)
            output = studio.console()
        finally:
            studio.set_play(False)
    finally:
        write_token("")  # close the gate so Karen's playtests do not run tests

    print("----- Studio Output -----")
    print(output)
    print("-------------------------")
    if not check("TestRunner reported within 60 s", ok):
        return 1
    report = json.loads(raw)
    check("Report carries this run's token", report["token"] == token, report["token"])
    check("Report comes from the DEV place", str(report["placeId"]) == place, str(report["placeId"]))
    ran = set(report.get("specs", []))
    not_run = sorted(f for inst, f in expected_specs.items() if inst not in ran)
    not_in_repo = sorted(ran - set(expected_specs))
    check("Runner ran every *.spec.* file in the repo", not not_run and not unsynced,
          ", ".join(not_run + unsynced) or f"{len(ran)} ran")
    check("Runner ran nothing that is not a *.spec.* file in the repo", not not_in_repo, ", ".join(not_in_repo))
    check("Runner status is PASS", report["status"] == "PASS", report["status"] + " " + report.get("message", ""))
    check("At least one test passed", report["successCount"] > 0, str(report["successCount"]))
    check("No failures", report["failureCount"] == 0, str(report["failureCount"]))
    check("No TestEZ errors", report["errorCount"] == 0, str(report["errorCount"]))
    check("No skipped tests (SKIP/FOCUS)", report["skippedCount"] == 0, str(report["skippedCount"]))

    closed, ok = wait_for(lambda: studio.query("Edit", QUERY_TOKEN), lambda v: v == "", 15)
    check("Gate closed afterwards (token cleared in Studio)", ok, repr(closed))

    passed = all(checks)
    print(f"[harness] {'PASS' if passed else 'FAIL'}: {sum(checks)}/{len(checks)} checks")
    return 0 if passed else 1


def main(argv):
    if len(argv) != 2 or argv[1] not in ("test", "state", "console", "stop"):
        sys.exit(__doc__)
    studio = Studio()
    try:
        cmd = argv[1]
        if cmd == "test":
            return run_test(studio)
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
