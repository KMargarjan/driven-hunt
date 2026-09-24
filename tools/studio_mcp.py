"""Drive a running Roblox Studio from the command line via Studio's built-in MCP server.

Pattern: minimal stdio JSON-RPC MCP client (https://modelcontextprotocol.io/specification)
talking to StudioMCP.exe, which ships with Roblox Studio (Assistant settings -> MCP server).
Note: docs/research/2026-09-24-toolchain.md

Requires: Studio open with a place, MCP server enabled in Studio's Assistant settings.

Usage:
  python tools/studio_mcp.py state            # edit/play mode
  python tools/studio_mcp.py play | stop      # start/stop a playtest
  python tools/studio_mcp.py console          # print Studio Output
  python tools/studio_mcp.py luau FILE [Edit|Server|Client]  # run Luau, print result
  python tools/studio_mcp.py test             # play, wait for TestRunner summary, stop; exit 1 on FAIL
  python tools/studio_mcp.py call TOOL '{json args}'
"""

import glob
import json
import os
import queue
import subprocess
import sys
import threading
import time


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
            "clientInfo": {"name": "driven-hunt-tools", "version": "0.1.0"},
        })
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        # Studio polls localhost:13469 roughly every 5s, so wait for it to attach.
        for _ in range(20):
            if '"studios":[]' not in self.call("list_roblox_studios"):
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

    def call(self, tool, args=None):
        result = self._rpc("tools/call", {"name": tool, "arguments": args or {}})
        text = "\n".join(c.get("text", "") for c in result.get("content", []))
        if result.get("isError"):
            raise RuntimeError(f"{tool}: {text}")
        return text

    def close(self):
        self.proc.kill()


SUMMARY_LUAU = 'return game:GetService("ServerStorage"):GetAttribute("TestSummary") or ""'


def run_tests(studio, timeout=60):
    """Play, wait for TestRunner's summary, stop. Returns (summary, console output of this run).

    The summary is read from ServerStorage's "TestSummary" attribute in the Server DataModel, which
    only exists for this play session. The Output log is not used for this because Studio clears
    it on Play, so it can still show the previous run's lines.
    """
    studio.call("start_stop_play", {"is_start": True})
    try:
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                summary = studio.call("execute_luau", {"datamodel_type": "Server", "code": SUMMARY_LUAU})
            except RuntimeError:
                summary = ""  # Server DataModel not up yet
            if summary.startswith("[tests] "):
                return summary, studio.call("get_console_output")
            time.sleep(1)
        raise TimeoutError("TestRunner did not report within %ss" % timeout)
    finally:
        studio.call("start_stop_play", {"is_start": False})


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    cmd = argv[1]
    studio = Studio()
    try:
        if cmd == "state":
            print(studio.call("get_studio_state"))
        elif cmd in ("play", "stop"):
            print(studio.call("start_stop_play", {"is_start": cmd == "play"}))
        elif cmd == "console":
            print(studio.call("get_console_output"))
        elif cmd == "luau":
            code = open(argv[2], encoding="utf-8").read()
            dm = argv[3] if len(argv) > 3 else "Edit"
            print(studio.call("execute_luau", {"datamodel_type": dm, "code": code}))
        elif cmd == "test":
            summary, out = run_tests(studio)
            print(out)
            print("summary (from Server DataModel):", summary)
            return 0 if summary.startswith("[tests] PASS") else 1
        elif cmd == "call":
            print(studio.call(argv[2], json.loads(argv[3]) if len(argv) > 3 else {}))
        else:
            sys.exit(__doc__)
    finally:
        studio.close()
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv))
