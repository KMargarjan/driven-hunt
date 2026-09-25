"""Driven Hunt test harness. THIS DOCSTRING IS THE SINGLE SOURCE OF TRUTH for how the test system works.
CLAUDE.md keeps the commands and points here; the research note keeps decisions and dated measurements.

Pattern: minimal stdio JSON-RPC MCP client (https://modelcontextprotocol.io/specification) talking to
StudioMCP.exe, which ships with Roblox Studio (Assistant settings -> MCP server).
Note: docs/research/2026-09-24-toolchain.md

Requires: Studio open on the DEV place in Edit mode, MCP server enabled, Rojo plugin connected.

Usage:
  python tools/studio_mcp.py test           # full checked run; exit 0 only on a clean-tree PASS
  python tools/studio_mcp.py test2          # the same specs in a 2-player local test (Karen starts it)
  python tools/studio_mcp.py state          # print Studio mode (read-only)
  python tools/studio_mcp.py console        # print Studio Output (read-only)
  python tools/studio_mcp.py stop           # stop a playtest (recovery)
  python tools/studio_mcp.py studios        # list the Studio instances StudioMCP can see (read-only)
  python tools/studio_mcp.py manifest       # after `wally install`: rewrite devpackages.sha256 (commit it)
  python tools/studio_mcp.py capture <name> [x,y,z] [x,y,z]   # save a screenshot as rule-5 evidence

Exit codes of `test` and `test2`: 0 PASS on a clean tree · 1 FAIL · 2 REFUSED (Studio not in Edit
mode) · 3 PASS on a dirty tree (flagged: not valid evidence).

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
      Both runners call TestKit.awaitToken(), which applies that same gate but WAITS up to
      TestKit.TOKEN_WAIT (60 s) for a token to appear instead of deciding once at startup: a
      two-player run cannot put the token in the place its processes start from (see `test2`), so it
      arrives after they are up. Outside Studio it returns nil immediately. A playtest still runs no
      tests -- nothing writes a token during one.
  tests/client/input_scenarios.txt -> ReplicatedStorage.ClientTests.input_scenarios (StringValue)
      The input scenarios (Task 6). JSON in a .txt because a .txt is a StringValue this harness already
      compares byte-for-byte, so the scenario the client reads is provably the file on disk, and no new
      Rojo mapping (a default.project.json change needs a Rojo restart and Karen's Connect) is needed.
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
     tree dirty). Studio's answers are fetched in batches and a batch whose reply StudioMCP truncated
     (~100 KB) is split and retried, down to a single instance, which then fails loudly.
     DevPackages/ (git-ignored TestEZ, which counts the passes) must match the committed
     devpackages.sha256 (which also pins the wally.lock hash).
  5. No script (LuaSourceContainer) exists anywhere in the DataModel outside the sourcemap: nothing
     script-like may be created in Studio. Every service must be readable by that scan.
  6. Every *.spec.* file in the repo (git ls-files: tracked + untracked, non-ignored) is synced into
     ServerStorage.Tests (server) or ReplicatedStorage.ClientTests (client).
  7. Play. Both reports arrive WITHIN 120 s of the replay finishing; each carries this run's token
     and the DEV PlaceId; each runner ran exactly the spec files of its side (matched by name); each
     status is PASS with > 0 passed, 0 failed, 0 errors, 0 skipped. (120 s, not 60: a client spec
     waits for its scenario to be staged, so the client suite cannot finish before the replay does,
     and the replay is ~50 s.)
  7a. While Play runs: replay every scenario in tests/client/input_scenarios.txt (see below). Two
     checks per run: the client was ready for it, and every step was sent.
  8. Stop. The token is cleared and the gate is seen closed in Studio.
  9. Final line: "[harness] PASS|FAIL: n/m checks @ <full HEAD sha> (clean tree | DIRTY TREE ...)".
     A PASS is evidence for a PR only if the sha equals the PR head and the tree is clean.

Driving real player input (Task 6), step 7a of `test`
  One scenario file, one harness step, one client spec. The file is tests/client/input_scenarios.txt:

    {"version": 1, "readyAttribute": "InputProbeReady", "scenarios": [
       {"name": ..., "spec": ...,
        "stage": {"targetFolder": "<a folder under Workspace>",   -- optional; see "Staging" below
                  "offsetStuds": [x, y, z]},
        "steps": [
          {"device": "keyboard", "action": "keyDown"|"keyUp"|"keyPress", "key": "<Enum.KeyCode name>"},
          {"device": "mouse", "action": "moveTo", "x": <px>, "y": <px>},
          {"device": "mouse", "action": "mouseButtonDown"|"mouseButtonUp"|"mouseButtonClick",
                              "button": "left"|"right"},
          {"device": "wait", "ms": <0..10000>}]}]}

  Replay, during Play, after the runners have started:
    1. Wait (<= 20 s) for LocalPlayer's `readyAttribute` to carry THIS run's token. The client spec
       sets it after it has bound its listeners, so a replay can never race the bindings, and a stale
       attribute from an earlier run is not mistaken for this one.
    2. For a scenario with a `stage` block, stage it first (below). In `test2` the replay goes to
       the SHOOTER's client only, named by its studio_id: a driver carries no gun.
    3. Send the steps in order through StudioMCP's user_keyboard_input / user_mouse_input against the
       Client DataModel. Consecutive steps for the same device go in ONE call, so StudioMCP keeps their
       order and spacing; a `wait` step flushes the batch and is slept in Python, so a gap spans devices.

Staging a scenario (Task 30): putting the player somewhere useful, pointing at something
  A replayed click fires wherever the camera is already looking, and the harness cannot aim: the
  camera's yaw is mouse-driven and under MouseBehavior = LockCenter StudioMCP's moveTo delivers no
  usable InputObject.Delta (docs/design/camera.md 9.3). So a scenario may carry a `stage` block, which
  the replay runs against the Client DataModel immediately before that scenario's steps:
    * it WAITS up to 60 s for the first BasePart inside Workspace.<targetFolder> -- the target.
      It waits rather than failing on the first look because since Milestone 1.7a the boars belong
      to the drive: none exists until the match releases one, about INTERMISSION_SECONDS +
      FIRST_RELEASE_SECONDS (~40 s) into a session, which is a real part of the game's timing and
      not a fault;
    * it moves the player's character to target.Position + offsetStuds (PivotTo: the client owns its
      own character, so this is the character's own writer);
    * it sets the LocalPlayer attribute `StagedTarget` to the target's full name, so a spec can
      tell that its scenario has been staged (tests/client/shoot_boar.spec waits for it before it
      starts tracking the target, so it never fights another spec for the camera);
    * it asks the CAMERA OWNER to aim at the target, by invoking the BindableFunction
      PlayerScripts.Camera.LookAtRequest. It never writes workspace.CurrentCamera: Camera.Rig is the
      only writer of that in the whole repo (docs/design/camera.md 3.1), and Camera.lookAt is the
      owner's own API.
      The invoke exists BECAUSE execute_luau has its own module cache: a require() through it returns
      a FRESH copy of the module, which reports mode=Loading and frames=0 while the live camera is
      Scriptable at FOV 70 (measured 2026-09-25, and again in Task 26). A module function call through
      execute_luau would therefore aim a camera nobody is looking through. An Instance is shared.
  One check per run: every staged scenario reported success. A stage that cannot find its target, its
  character or the camera's request function FAILS the run -- a scenario staged into thin air would
  otherwise send its clicks at nothing and still be reported as replayed.
  Every step is validated when the file is read, before Play: an unknown device or action, a missing
  key or button, a non-numeric moveTo or a `wait` outside StudioMCP's 0..10000 ms fails the run there
  and then, because a step the replay sends but the spec cannot recognise is a hole in the evidence.
  Gated exactly like the specs: replay happens only inside `test`, only during its own Play, and the
  spec only listens when TestKit's token gate is open.
  What a scenario CANNOT express: a second player (that is `test2`, and its replay reaches one
  client only); touch and gamepad input; typing text (StudioMCP has textInput, the
  format does not); a hold measured in frames rather than milliseconds; input aimed at a specific
  instance (StudioMCP's instance_path is not used); and anything after the client report is written.
  A `stage` block cannot follow a moving target: it places and aims ONCE, before the steps. A spec
  that needs to stay on a moving target keeps calling Camera.lookAt itself (tests/client/shoot_boar.spec).

More than one player: what StudioMCP can and cannot do (Task 30, measured 2026-09-25)
  Asked of the server itself, through the MCP tools/list response -- the authoritative description of
  every tool and argument it exposes:
    * start_stop_play takes `is_start` and `studio_id`. There is NO player-count argument, so this
      harness cannot ask for Studio's "Clients and Servers" local test.
    * execute_luau, user_mouse_input, user_keyboard_input and search_game_tree all take
      `datamodel_type` as an enum of exactly "Edit", "Client", "Server". There is no index, so a
      SECOND client inside one Studio is not addressable for a query, an input or a report -- and
      QUERY_REPORT["client"] reads Players.LocalPlayer, which is singular by construction.
    * EVERY tool takes a `studio_id`, and list_roblox_studios returns {id, name} per connected Studio
      ("Several instances are commonly open at once"). That is the one open route to two players: a
      local multi-client test starts extra Studio processes, and IF they register with StudioMCP they
      would be addressable as separate studio_ids.
  So: a 2-player run is NOT possible today, and the open route cannot be evaluated without a human
  starting a 2-client test. `python tools/studio_mcp.py studios` prints the listing, which is the one
  command that answers it; ESCALATE.md carries the NEEDS KAREN entry with the exact clicks.
  A missing scenario file is not a failure: the step is skipped and says so.

Two players: `test2` (Task 34, ROADMAP 1.6)
  What it is: the SAME gate, the SAME runners and the SAME specs as `test`, read from three Studio
  instances instead of one. `test` is untouched and stays the default; nothing in the place, and no
  spec, knows which mode it is running under.

  WHAT STUDIOMCP CANNOT DO, measured from its own tools/list: `start_stop_play` takes `is_start` and
  `studio_id` and nothing else, so there is NO way to ask for a player count. This mode therefore
  cannot start the test; Karen presses Test -> Clients and Servers -> Players: 2 -> Start, and the
  mode prints those clicks and waits up to 180 s for the windows to appear. If nobody presses it,
  the run says so plainly and claims nothing.

  WHAT THE COPIED PLACE CARRIES, and what it does not. Measured on 2026-09-25 with all three
  windows open: every script in the server and both clients was the Rojo-synced one, down to a spec
  file created minutes earlier and never published, and Rojo does not patch those processes
  afterwards (a token written to disk mid-session left all three untouched -- Rojo patches the
  editor only). Whether the token StringValue's VALUE comes across is a coin toss: run 4 found it
  empty in all three while the editor held a fresh token, run 5 found it carried.

  SO THE DISK TOKEN IS CLEARED BEFORE THE CLICK, deliberately. A carried token is worse than none:
  the suites then start the instant the windows open, 20-40 s before this mode has classified the
  processes and can replay input into the shooter, and every input-driven client spec counts its
  own 25 s from where TestEZ reaches it -- run 5 lost 14 specs on the shooter exactly that way. A
  fresh token is still written first and checked (that is the proof Rojo is live and caught up,
  as in `test`), then cleared, then Karen clicks. TestKit.awaitToken keeps both runners waiting.

  THE HARNESS OPENS THE GATE ITSELF, when it is ready to drive the run: it mints a fresh token,
  sets ReplicatedStorage.TestSyncToken.Value on the SERVER through execute_luau, and ordinary
  replication carries the StringValue to both clients. The runners are still listening because
  TestKit.awaitToken waits TOKEN_WAIT (60 s) for it, and the gate they then apply is the same one as
  ever. Both tokens the run minted are accepted in a report; nothing else is.

  What it does after the click:
    1. `list_roblox_studios` before and after, so the test's instances are identified BY IDENTITY --
       the edit Studio, and anything else Karen has open, is excluded because it was there before.
    2. Each new instance is ASKED what it is, by running QUERY_ROLE in it. Every later call names
       its `studio_id`.

       THE REAL PER-PROCESS SHAPE, probed live on 2026-09-25 with a 2-player test running (the
       three windows open, Karen's hands off):
         - the editor        : mode Edit, DataModels "Edit",           focused Edit
         - the server process: mode Play, DataModels "Client, Server", focused Server
         - each client       : mode Play, DataModels "Client, Server", focused Client
       So `get_studio_state`'s "Available DataModels" line does NOT distinguish a test process:
       all three offer both, and classifying on it makes all three servers -- which is exactly how
       Karen's first `test2` run failed ("a SECOND server DataModel" twice, "0 client(s)").
       What IS true per process: only ONE of the two DataModels is reachable -- `execute_luau`
       against the other raises "Target is not reachable" -- and "Focused DataModel in the viewport"
       names the reachable one. The mode uses that line only to choose which to try first, and
       decides on `RunService:IsServer()` from inside the process; a client also returns its
       `Players.LocalPlayer.Name` (Player1, Player2), and the server returns nil for it.
       In Edit mode the Edit DataModel answers IsServer() AND IsClient() true, which is why this
       probe is only ever run against the processes a Start added.

       STILL LOADING IS NOT A FAULT. A Start registers all three processes with StudioMCP before
       they can answer anything, so "Place is not open", "Target is not reachable" and "... is not
       available" are retried against a test process until that step's deadline (60 s to classify,
       15 s for a console) and reported if they outlast it. Run 3 (2026-09-25) crashed the whole
       mode on the first of those; no call against a test process raises now.
    3. Each client is asked which team its LocalPlayer is on. THEN the gate is opened (above) and
       the input scenarios are replayed into the SHOOTER's client -- in that order, because the
       client specs start the moment the token lands and input_driving.spec gives the replay 25 s
       to arrive; a 45-second team query must not be inside that budget.
       WHY THE SHOOTER: with two players the drive makes one of them a Driver, and a Driver carries
       no gun at all (DRIVERS_MAY_SHOOT is false), so the weapon and staged-shot specs cannot pass
       there whatever is replayed -- list order has nothing to do with it. The driver's report is
       printed as an OBSERVATION, never as a passing check.
    4. All three reports (the server, the shooter's client, the driver's client) are polled
       TOGETHER against one deadline of REPORT_WINDOW_2P seconds, and each is announced with how
       long it took. Read one after another, a slow client is only waited for once the previous
       one's window has run out: in run 5 both clients had in fact reported, and the sequential
       reads had given up first. A two-player client suite is slower than a one-player one anyway,
       because the driver carries no gun and its weapon specs spend their timeouts failing.
    5. Checks: three NEW studios appeared; the gate was shut again before the copy was taken; one
       server and exactly two clients were found; one client is on the Shooters team; the gate
       token reached the server process and replicated to both clients; each runner reported inside
       the window; each report carries a
       token it minted (the disk one, in case a copy carried it, or the injected one -- nothing
       else) and the DEV PlaceId; the server and the SHOOTER's client are PASS with 0
       failed/errors/skipped; the server ran tests/server/match_teams.spec; and it ran every server
       spec file in the repo. The driver's report is printed, never checked.
    6. It stops each test instance and, if any remain, says to press Cleanup.
  Final line: "[harness2] PASS|FAIL: n/m checks @ <full HEAD sha> (clean tree | DIRTY TREE ...)".
  A [harness2] line is NOT a substitute for a [harness] line as PR evidence: this mode runs none of
  `test`'s checks 4-6 (disk-vs-Studio comparison, no-script-outside-Rojo, spec placement). It is an
  extra run, never the merge gate's.

  The 2-player assertion itself is tests/server/match_teams.spec.luau, and it is written to be true
  for WHATEVER number of players is present, so it runs in both modes: with one player it asserts
  Director decision F (the lone player is a Shooter and is armed); with two, that both are assigned,
  that the teams are 1 and 1, and that only the shooter may carry a gun.

Screenshots as evidence (Task 7)
  `capture <name> [camera x,y,z] [look-at x,y,z]` saves StudioMCP's screen_capture image to
  .screenshots/<UTC stamp>-<name>.png (git-ignored) and prints the path. Studio._call keeps text blocks
  only, which is why captures could not be saved before; Studio.capture() reads the image block.
  It works in Edit and during Play (Tasks 17, 18 and 22 captured Play this way), and it is a separate
  command, not part of `test`: the Builder inspects the image and says what it shows (rule 5).

Client-side testing (camera, input, cursor, UI)
  Client specs run inside the real player client and can assert camera, input, cursor and UI state,
  and -- since Task 6 -- can be driven by real keyboard and mouse input replayed by the harness.

Safety
  The harness writes tests/sync-token.txt, and .screenshots/ when `capture` is asked for. Its Luau is
  read-only: constant queries, or queries templated with JSON data (QUERY_*). There is no command for
  arbitrary Luau or arbitrary MCP tools. The input replay sends only what the scenario file lists, and
  only into the Play session this harness started.
"""

import base64
import datetime
import glob
import hashlib
import json
import os
import queue
import re
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
SCENARIO_FILE = os.path.join(REPO, "tests", "client", "input_scenarios.txt")
SCREENSHOT_DIR = os.path.join(REPO, ".screenshots")
SPEC_ROOTS = {"server": ("ServerStorage", "Tests"), "client": ("ReplicatedStorage", "ClientTests")}

# Read-only Luau queries. Keep every query here, read-only. Templated ones take JSON via luau_json().
QUERY_PLACE_ID = "return tostring(game.PlaceId)"
QUERY_TOKEN = """
local v = game:GetService("ReplicatedStorage"):FindFirstChild("TestSyncToken")
return if v and v:IsA("StringValue") then v.Value else "<missing>"
"""
# The client spec sets this after binding its listeners, so the replay cannot race them. The attribute
# name is a Luau string literal, not luau_json's JSON-in-a-long-bracket: that would ask Studio for an
# attribute whose name includes the quote characters, and every read would come back empty.
QUERY_READY = 'local p = game:GetService("Players").LocalPlayer return p and p:GetAttribute("%s") or ""'
# Staging (Task 30): place the character in front of a target and ask the CAMERA OWNER to aim at it.
# Templated with the scenario's own `stage` block as JSON. It writes two things and only two: the
# character's pivot (the client owns its own character) and, through the owner's request function,
# the camera's yaw and pitch. workspace.CurrentCamera is never touched here -- Camera.Rig is its only
# writer in the repo, and reaching the live module any other way is impossible because execute_luau
# has its own module cache (a require() through it reports a fresh module: mode=Loading, frames=0).
QUERY_STAGE = """
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local stage = HttpService:JSONDecode(%s)
-- WAIT for a target rather than failing on the first look: since the drive owns the boars
-- (Milestone 1.7a) the folder is empty until the match releases one, which is a real part of the
-- game's timing and not a fault.
local deadline = os.clock() + 60
local target = nil
repeat
    local folder = Workspace:FindFirstChild(stage.targetFolder)
    target = folder and folder:FindFirstChildWhichIsA("BasePart")
    if not target then
        task.wait(0.25)
    end
until target or os.clock() > deadline
if not target then
    return "no BasePart inside Workspace." .. tostring(stage.targetFolder) .. " after 60 s"
end
local player = Players.LocalPlayer
local character = player and player.Character
if not character then
    return "no character to place"
end

local offset = Vector3.new(stage.offsetStuds[1], stage.offsetStuds[2], stage.offsetStuds[3])
character:PivotTo(CFrame.new(target.Position + offset))

local scripts = player:FindFirstChild("PlayerScripts")
local camera = scripts and scripts:FindFirstChild("Camera")
local request = camera and camera:FindFirstChild("LookAtRequest")
if not request then
    return "placed, but PlayerScripts.Camera.LookAtRequest is missing: nothing aimed"
end
if not request:Invoke(target.Position.X, target.Position.Y, target.Position.Z) then
    return "placed, but the camera owner refused to aim (no character root yet?)"
end
-- So a spec knows its scenario has been staged, without guessing from the player's position. The
-- harness is the only writer of this attribute, exactly as the client spec is the only writer of the
-- ready attribute it reads.
player:SetAttribute("StagedTarget", target:GetFullName())
-- Doubled %%: this whole query is templated with the stage block through Python's %% operator, so a
-- lone %%s here is a second placeholder and the format call raises before Studio ever sees it. It
-- did, and the run went green anyway because a stray click from an earlier scenario happened to hit
-- the boar -- the stage check caught it, the spec did not.
return string.format(
    "staged on %%s, %%d studs away",
    target:GetFullName(),
    math.floor((target.Position - character:GetPivot().Position).Magnitude)
)
"""
# Which team the drive put this client's player on. Used to pick WHICH client gets the input
# replay in a 2-player run: the driver carries no gun, so the weapon specs belong to the shooter.
QUERY_SET_TOKEN = """
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local value = ReplicatedStorage:FindFirstChild("TestSyncToken")
if not value or not value:IsA("StringValue") then
	return "MISSING"
end
value.Value = %s
return value.Value
"""
QUERY_ROLE = (
    # WHAT a test process is, MEASURED by running code in it. get_studio_state cannot answer this:
    # every process of a local test advertises "Available DataModels: Client, Server" (Task 34,
    # probed live on 2026-09-25 with all three windows open), so reading that line classifies all
    # three as servers. Only one of the two DataModels is actually reachable per process, and it is
    # the one this query answers from.
    'local RS = game:GetService("RunService") '
    'local Players = game:GetService("Players") '
    "local lp = Players.LocalPlayer "
    'return (if RS:IsServer() then "server" else "client") .. "|" .. tostring(lp and lp.Name)'
)
QUERY_MY_TEAM = (
    'local p = game:GetService("Players").LocalPlayer '
    "local t = p and p.Team "
    'return if t then t.Name else ""'
)
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

    def _call(self, tool, args=None, studio_id=None):
        arguments = dict(args or {})
        if studio_id:
            # Every StudioMCP tool takes a studio_id, and with one Studio connected it may be left
            # out. With a local 2-player test running there are FOUR (Task 34), so every call that
            # must land somewhere particular names it.
            arguments["studio_id"] = studio_id
        result = self._rpc("tools/call", {"name": tool, "arguments": arguments})
        text = "\n".join(c.get("text", "") for c in result.get("content", []))
        if result.get("isError"):
            raise RuntimeError(f"{tool}: {text}")
        return text

    # The only operations this harness exposes.
    def studios(self):
        """Every Studio instance StudioMCP can see, raw. Read-only (Task 30)."""
        return self._call("list_roblox_studios")

    def studio_list(self):
        """[{id, name}], parsed. A local 2-player test adds three (server + two clients)."""
        try:
            return json.loads(self.studios()).get("studios", [])
        except json.JSONDecodeError:
            return []

    def state_of(self, studio_id=None):
        """The raw get_studio_state text for one instance: its mode and its DataModels."""
        return self._call("get_studio_state", studio_id=studio_id)

    def datamodels(self, studio_id=None):
        """The DataModel types one Studio instance offers, e.g. {"Edit"} or {"Client"}."""
        for line in self.state_of(studio_id).splitlines():
            if "Available DataModels:" in line:
                return {p.strip() for p in line.split(":", 1)[1].split(",") if p.strip()}
        return set()

    def mode(self, studio_id=None):
        state = self.state_of(studio_id)
        for line in state.splitlines():
            if "Current Studio Mode:" in line:
                return line.split(":", 1)[1].strip()
        return state

    def console(self, studio_id=None):
        return self._call("get_console_output", studio_id=studio_id)

    def set_play(self, playing, studio_id=None):
        return self._call("start_stop_play", {"is_start": playing}, studio_id=studio_id)

    def query(self, datamodel, code, studio_id=None):
        return self._call("execute_luau", {"datamodel_type": datamodel, "code": code}, studio_id=studio_id)

    def send_input(self, device, actions, studio_id=None):
        """Replay one batch of real input into the Play client. `device` is "keyboard" or "mouse"."""
        tool = "user_keyboard_input" if device == "keyboard" else "user_mouse_input"
        return self._call(tool, {"datamodel_type": "Client", "actions": actions}, studio_id=studio_id)

    def capture(self, path, camera=None, look_at=None):
        """Save StudioMCP's screen_capture image to `path`. Returns the path, or None with the text.

        _call() joins text blocks and drops the image, which is why captures could not be saved
        (TASKS.md Task 7). This reads the image block instead."""
        args = {"capture_id": f"DrivenHunt_{os.path.basename(path)}"}
        if camera and look_at:
            args["camera_position"], args["look_at_position"] = list(camera), list(look_at)
        result = self._rpc("tools/call", {"name": "screen_capture", "arguments": args})
        text = "\n".join(c.get("text", "") for c in result.get("content", []) if c.get("type") == "text")
        if result.get("isError"):
            raise RuntimeError(f"screen_capture: {text}")
        for part in result.get("content", []):
            if part.get("type") == "image" and part.get("data"):
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, "wb") as f:
                    f.write(base64.b64decode(part["data"]))
                return path, text
        return None, text

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
    # so query in small batches. A truncated result is never mistaken for a match: it fails to parse,
    # and then the batch is SPLIT and retried, down to one node -- eight big spec files in one batch
    # blew the limit and failed the whole run as a JSONDecodeError (measured, Task 30).
    def fetch(batch):
        text = studio.query("Edit", QUERY_NODES % luau_json(batch))
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            if len(batch) == 1:
                raise RuntimeError(
                    f"Studio's answer for {'.'.join(batch[0]['path'])} was truncated at {len(text)} chars: "
                    "one instance is too big for a single StudioMCP result")
            half = len(batch) // 2
            return fetch(batch[:half]) + fetch(batch[half:])

    remote = []
    for i in range(0, len(wanted), 8):
        remote += fetch(wanted[i:i + 8])

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


STEP_ACTIONS = {
    "keyboard": {"keyDown", "keyUp", "keyPress"},
    "mouse": {"moveTo", "mouseButtonDown", "mouseButtonUp", "mouseButtonClick"},
}


def check_step(where, step):
    """Refuse a step the replay cannot send faithfully, before Play starts rather than during it."""
    device, action = step.get("device"), step.get("action")
    if device == "wait":
        ms = step.get("ms")
        if not isinstance(ms, (int, float)) or not 0 <= ms <= 10000:
            raise RuntimeError(f"{where}: wait needs `ms` between 0 and 10000 (StudioMCP's range); got {ms!r}")
        return
    if device not in STEP_ACTIONS:
        raise RuntimeError(f"{where}: unknown device {device!r} (keyboard, mouse or wait)")
    if action not in STEP_ACTIONS[device]:
        raise RuntimeError(f"{where}: {device} cannot {action!r} ({', '.join(sorted(STEP_ACTIONS[device]))})")
    if device == "keyboard" and not isinstance(step.get("key"), str):
        raise RuntimeError(f"{where}: {action} needs `key` (an Enum.KeyCode name)")
    if action.startswith("mouseButton") and step.get("button") not in ("left", "right"):
        raise RuntimeError(f"{where}: {action} needs `button` \"left\" or \"right\"; got {step.get('button')!r}")
    if action == "moveTo" and not all(isinstance(step.get(k), (int, float)) for k in ("x", "y")):
        raise RuntimeError(f"{where}: moveTo needs numeric `x` and `y`")


def check_stage(where, stage):
    """Refuse a stage block the replay could not run, before Play rather than during it."""
    if not isinstance(stage, dict):
        raise RuntimeError(f"{where}: `stage` must be an object")
    folder = stage.get("targetFolder")
    if not isinstance(folder, str) or not re.fullmatch(r"[A-Za-z0-9_]{1,64}", folder):
        raise RuntimeError(f"{where}: stage.targetFolder must be a plain instance name; got {folder!r}")
    offset = stage.get("offsetStuds")
    if not isinstance(offset, list) or len(offset) != 3 or not all(isinstance(v, (int, float)) for v in offset):
        raise RuntimeError(f"{where}: stage.offsetStuds must be three numbers; got {offset!r}")
    extra = set(stage) - {"targetFolder", "offsetStuds"}
    if extra:
        raise RuntimeError(f"{where}: stage has unknown key(s) {sorted(extra)}")


def load_scenarios():
    """The scenario file, or None if there is none. A bad file is an error, a missing one is not.

    Every step is checked here, at the top of the run: a step the replay would send but the client
    spec could not recognise is a silent hole in the evidence, so it fails loudly and early."""
    if not os.path.exists(SCENARIO_FILE):
        return None
    with open(SCENARIO_FILE, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data.get("scenarios"), list) or not data["scenarios"]:
        raise RuntimeError("input_scenarios.txt has no `scenarios` list")
    for scenario in data["scenarios"]:
        if scenario.get("stage") is not None:
            check_stage(f"scenario {scenario.get('name')!r}", scenario["stage"])
        for index, step in enumerate(scenario.get("steps") or [], start=1):
            check_step(f"scenario {scenario.get('name')!r} step {index}", step)
    return data


def scenario_batches(steps):
    """Group steps into ("keyboard"|"mouse", actions) batches and ("wait", seconds) pauses.

    Consecutive steps for one device travel in a single StudioMCP call, so their order and spacing are
    the tool's to keep. A `wait` ends the batch and is slept here, so a gap can span two devices.

    The mouse position is per call, not per session: StudioMCP refuses a button action whose call does
    not establish a position ("Either x and y, instance_path, or a prior action that establishes mouse
    position is required"), so the last position seen is carried into every later mouse action. Found
    by running it: putting the scenario's `wait` between the move and the click split them into two
    calls and the second was refused."""
    batches, current, device, last_xy = [], [], None, None

    def flush():
        nonlocal current, device
        if current:
            batches.append((device, current))
        current, device = [], None

    for step in steps:
        kind = step.get("device")
        if kind == "wait":
            flush()
            batches.append(("wait", (step.get("ms") or 0) / 1000.0))
        elif kind == "keyboard":
            if device != "keyboard":
                flush()
            device = "keyboard"
            action = {"action": step["action"]}
            if step.get("key"):
                action["key_code"] = step["key"]
            current.append(action)
        elif kind == "mouse":
            if device != "mouse":
                flush()
            device = "mouse"
            action = {"action": step["action"]}
            if step.get("button") is not None:
                action["mouse_button"] = step["button"]
            if step.get("x") is not None and step.get("y") is not None:
                action["x"], action["y"] = step["x"], step["y"]
                last_xy = (step["x"], step["y"])
            elif last_xy:
                action["x"], action["y"] = last_xy
            current.append(action)
        else:
            raise RuntimeError(f"unknown scenario device {kind!r}")
    flush()
    return batches


def replay_input(studio, data, token, check, studio_id=None):
    """Replay every scenario into the running Play client. Adds two checks per run (three with a
    `stage`). `studio_id` names WHICH client in a 2-player run; None means "the only one"."""
    ready_attr = data.get("readyAttribute", "InputProbeReady")
    if not re.fullmatch(r"[A-Za-z0-9_]{1,100}", ready_attr):
        raise RuntimeError(f"readyAttribute must be a plain identifier; got {ready_attr!r}")
    seen, ok = wait_for(lambda: studio.query("Client", QUERY_READY % ready_attr, studio_id=studio_id),
                        lambda v: v == token, 20, 0.5)
    if not check("[input] the client bound its listeners and published this run's token", ok, repr(seen)):
        return
    sent, problems, staged = 0, [], []
    for scenario in data["scenarios"]:
        stage = scenario.get("stage")
        if stage:
            # Before the steps, never after: a click is only worth sending once the player is standing
            # where the scenario needs them and the camera owner has been asked to look at the target.
            try:
                result = studio.query("Client", QUERY_STAGE % luau_json(stage), studio_id=studio_id).strip()
            except Exception as e:
                result = f"{type(e).__name__}: {e}"
            staged.append(f"{scenario.get('name')}: {result}")
            if not result.startswith("staged on "):
                problems.append(f"{scenario.get('name')}: stage failed ({result})")
        for device, payload in scenario_batches(scenario.get("steps", [])):
            if device == "wait":
                time.sleep(payload)
                continue
            try:
                studio.send_input(device, payload, studio_id=studio_id)
                sent += len(payload)
            except Exception as e:
                # Not just RuntimeError: _rpc raises queue.Empty when StudioMCP stops answering, and a
                # hung input call must fail this check, not the whole run (review round 1).
                problems.append(f"{scenario.get('name')}: {type(e).__name__}: {e}")
    names = ", ".join(str(s.get("name")) for s in data["scenarios"])
    check(f"[input] replayed every step of {len(data['scenarios'])} scenario(s)", not problems,
          "; ".join(problems) if problems else f"{sent} steps sent ({names})")
    if staged:
        # A separate check, because a scenario staged into thin air would still send every step and
        # pass the line above while its spec asserted on nothing.
        failed = [s for s in staged if ": staged on " not in s]
        check(f"[input] staged {len(staged)} scenario(s) (placed + aimed)", not failed,
              "; ".join(failed) if failed else "; ".join(staged))


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

    scenarios = load_scenarios()

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
            if scenarios is None:
                print("[harness] no tests/client/input_scenarios.txt: nothing to replay")
            else:
                replay_input(studio, scenarios, token, check)
            for side in ("server", "client"):
                # 120 s: a client spec waits for its scenario to be STAGED (Task 30), so the client
                # suite cannot finish before the replay does, and since Task 32 the stage itself may
                # wait for the drive to release a boar. Measured: the replay is ~50 s.
                raw, ok = wait_for(lambda: studio.query(side.capitalize(), QUERY_REPORT[side]), lambda v: v != "", 120, 1)
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
        if not check(f"[{side}] runner reported within 120 s", report is not None):
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


# ---------------------------------------------------------------- two players (Task 34)

START_CLICKS = """
[harness2] NEEDS KAREN, once, in Studio -- StudioMCP CANNOT start this test itself:
[harness2]   start_stop_play takes `is_start` and `studio_id` and NOTHING else, so there is no way
[harness2]   to ask for a player count. Everything after the click is this mode's own work.
[harness2]
[harness2]   1. Test tab -> Clients and Servers -> Players: 2 -> Start.
[harness2]   2. Leave the windows alone; this mode reads them.
[harness2]   3. When it says so, press Cleanup in the Test tab.
[harness2]
[harness2] Take your time: this mode waits {seconds} s for the windows and opens the gate itself once
[harness2] they are up, so the click is not racing a token any more.
"""


LOADING_ERRORS = ("place is not open", "not reachable", "is not available", "no datamodel")


def still_loading(error):
    """True for what a test process answers while it is still opening the place.

    A Start makes three processes register with StudioMCP BEFORE they can answer anything: run 3
    (2026-09-25) crashed with "get_studio_state: Place is not open" the moment the first client was
    asked, because that call sat outside the retry. Against a test process these are not faults,
    they are "not yet" -- and the wrong DataModel of a process answers the same way forever, which
    is why the caller still needs its own deadline."""
    text = str(error).lower()
    return any(hint in text for hint in LOADING_ERRORS)


def process_call(call, timeout=60, interval=1, default=None):
    """Make a StudioMCP call against a TEST PROCESS, waiting out "still loading". -> (value, why).

    `why` is "" on success and the last error otherwise, so every caller reports instead of
    crashing (rule 6). Anything that is NOT a loading error is raised: a real fault must not be
    slept through for a minute."""
    deadline = time.time() + timeout
    last = ""
    while True:
        try:
            return call(), ""
        except RuntimeError as e:
            if not still_loading(e):
                raise
            last = str(e).split("(")[0].strip()
        if time.time() >= deadline:
            return default, last
        time.sleep(interval)


def focused_datamodel(studio, studio_id=None):
    """The DataModel this instance actually hosts, as get_studio_state's last line names it.

    A HINT for which DataModel to try first, never the answer: probe_role decides."""
    for line in studio.state_of(studio_id).splitlines():
        if "Focused DataModel in the viewport:" in line:
            return line.split(":", 1)[1].strip()
    return ""


def probe_role(studio, studio_id, timeout=60):
    """(role, player, datamodel, why) for one test process, MEASURED rather than advertised.

    Task 34, probed live with a 2-player test running: all three processes report
    "Available DataModels: Client, Server", so classifying on that line makes every one of them a
    server (Karen's first test2 run: "a SECOND server DataModel" twice, "0 client(s)"). Exactly ONE
    of the two is reachable per process -- execute_luau against the other raises "Target is not
    reachable" -- so this runs QUERY_ROLE and lets RunService:IsServer() say which it is.

    EVERY call here is inside the retry, including the get_studio_state that reads the focused
    line: a process registers with StudioMCP before it can answer, and run 3 crashed on exactly
    that ("Place is not open", 2026-09-25). Nothing in classification raises."""
    deadline = time.time() + timeout
    while True:
        errors = []
        try:
            focused = focused_datamodel(studio, studio_id)
        except RuntimeError as e:
            focused = ""  # still opening its place; try both DataModels and come back round
            errors.append(f"state: {str(e).split('(')[0].strip()}")
        order = [dm for dm in (focused, "Server", "Client") if dm in ("Server", "Client")]
        for datamodel in dict.fromkeys(order):
            try:
                answer = studio.query(datamodel, QUERY_ROLE, studio_id=studio_id)
            except RuntimeError as e:
                errors.append(f"{datamodel}: {str(e).split('(')[0].strip()}")
                continue
            role, _, player = answer.strip().partition("|")
            if role in ("server", "client"):
                return role, player, datamodel, ""
            errors.append(f"{datamodel}: {answer.strip()[:60]!r}")
        if time.time() >= deadline:
            return None, "", "", "; ".join(errors) or "no DataModel answered"
        time.sleep(1)


def classify_studios(studio, before):
    """Split the studios a local test added into (server_id, [client_ids], [unknown_ids]).

    `before` is the listing from before the test started, so the edit Studio -- and anything else
    Karen happens to have open -- is excluded by identity rather than by name. WHICH of them is the
    server is then asked of each process itself (probe_role), because what they advertise does not
    distinguish them."""
    known = {s["id"] for s in before}
    server, clients, unknown = None, [], []
    for entry in studio.studio_list():
        if entry["id"] in known:
            continue
        studio_id = entry["id"]
        role, player, datamodel, why = probe_role(studio, studio_id)
        named = f", LocalPlayer {player}" if player and player != "nil" else ""
        print(f"[harness2] {studio_id[:8]}: "
              + (f"{role} (DataModel {datamodel}{named})" if role else f"unclassified ({why})"))
        if role == "server":
            if server is None:
                server = studio_id
            else:
                # A second process that answers as a server is not something to shrug off: the mode
                # would be reading reports from whichever it happened to see first.
                unknown.append(f"{studio_id[:8]} (a SECOND server process)")
        elif role == "client":
            clients.append(studio_id)
        else:
            unknown.append(f"{studio_id[:8]} ({why})")
    return server, clients, unknown


def end_session(studio, before):
    """Stop every instance the test added, and say plainly what is left. Called on every path out of
    run_test2 that got as far as starting one, so Karen is never left with three windows and no
    instruction."""
    known = {s["id"] for s in before}
    for entry in studio.studio_list():
        if entry["id"] in known:
            continue
        try:
            studio.set_play(False, studio_id=entry["id"])
        except Exception as e:
            print(f"[harness2] could not stop {entry['id'][:8]}: {type(e).__name__}: {e}")
    left = [s for s in studio.studio_list() if s["id"] not in known]
    if left:
        print(f"[harness2] {len(left)} test Studio(s) still open: press Cleanup in the Test tab.")


# A two-player client suite is slower than a one-player one: the driver carries no gun, so its
# weapon specs spend their own timeouts failing rather than passing. Run 5 measured both clients
# finishing after the old sequential 120 s reads had given up.
REPORT_WINDOW_2P = 300


def run_test2(studio, wait_seconds=180):
    """Run the gated specs in a local 2-player test: one server DataModel, two client DataModels.

    The one-player `test` is untouched and stays the default. This mode adds nothing to the place and
    changes no spec: the same TestKit gate, the same runners, the same reports -- read from three
    Studio instances instead of one."""
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
        print(f"[harness2] {'PASS' if passed else 'FAIL'}: {sum(checks)}/{len(checks)} checks @ {sha} ({tree})")
        if dirty:
            for line in sorted(set(dirty_start + dirty_end))[:10]:
                print("    dirty: " + line)
        return code if code is not None else (1 if not passed else (3 if dirty else 0))

    sha, dirty_start = git_state()
    print(f"[harness2] two-player run @ {sha} ({'clean' if not dirty_start else 'DIRTY'} tree)")

    mode = studio.mode()
    if not check("Studio is in Edit mode before the run", mode == "Edit", mode):
        print("[harness2] REFUSED: stop the playtest first (python tools/studio_mcp.py stop)")
        return verdict(2)

    place = expected_place_id()
    actual_place = studio.query("Edit", QUERY_PLACE_ID)
    if not check("Studio has the DEV place open", actual_place == place, f"{actual_place} vs {place}"):
        return verdict()

    before = studio.studio_list()
    check("One Studio instance before the test starts", len(before) == 1,
          "; ".join(f'{s["name"]}' for s in before))

    scenarios = load_scenarios()
    spec_files = spec_files_in_repo()
    server_specs = {f for f in spec_files if f.startswith("tests/server/")}

    # This token proves Rojo is live and caught up, exactly as in `test`. It does NOT open the gate
    # in the test processes: the place they start from carries the StringValue with an empty value
    # (measured, run 4 -- see the injection below), so the token that actually opens it is minted
    # after they exist and written straight into the server process.
    token = f"{secrets.token_hex(8)}:{int(time.time())}"
    write_token(token)
    reports, consoles = {}, {}
    try:
        seen, ok = wait_for(lambda: studio.query("Edit", QUERY_TOKEN), lambda v: v == token, 15)
        if not check("Rojo synced the fresh token from disk", ok, f"Studio has {seen!r}"):
            return verdict()
        minted = [token]

        # AND NOW THE DISK TOKEN IS CLEARED, BEFORE the click. Whether the copy a local test takes
        # carries the token turned out to be a coin toss (run 4: empty, run 5: carried), and a
        # carried token is WORSE than none: the suites then start the instant the windows open,
        # which is 20-40 s before this mode has classified the processes and can replay input into
        # the shooter -- and every input-driven client spec counts its own 25 s from where TestEZ
        # reaches it. Run 5 lost 14 specs on the shooter that way. With an empty token the copy
        # cannot open the gate, TestKit.awaitToken keeps both runners waiting, and the suites start
        # when this mode injects the real token: one second before the replay, not a minute.
        write_token("")
        seen, ok = wait_for(lambda: studio.query("Edit", QUERY_TOKEN), lambda v: v == "", 15)
        if not check("The gate is shut again before the copy is taken", ok, f"Studio has {seen!r}"):
            return verdict()

        print(START_CLICKS.format(seconds=wait_seconds))
        known = {s["id"] for s in before}

        def new_studios():
            return [s for s in studio.studio_list() if s["id"] not in known]

        # THREE NEW instances, not "three in total": a local test adds a server and two clients, and
        # waiting for a total of three is satisfied by two of them -- the classification would then
        # run against a half-registered test, find one client, and fail a run Karen had started
        # correctly (round 1, finding 1).
        found, ok = wait_for(new_studios, lambda v: len(v) >= 3, wait_seconds, 2)
        if not check(f"A 2-player local test appeared within {wait_seconds} s", ok,
                     f"{len(found)} new studio(s) beside the editor"):
            print("[harness2] NEEDS KAREN: nobody pressed Start. Nothing was run and nothing is claimed.")
            return verdict()

        server, clients, unknown = classify_studios(studio, before)
        check("Found one server DataModel", server is not None, ", ".join(unknown))
        check("Found exactly two client DataModels", len(clients) == 2,
              f"{len(clients)} client(s)" + ("; unclassified: " + ", ".join(unknown) if unknown else ""))
        if server is None or len(clients) != 2:
            end_session(studio, before)
            return verdict()
        print(f"[harness2] server {server[:8]}, clients {', '.join(c[:8] for c in clients)}")

        # WHICH client gets the replay is not a matter of list order. With two players the drive
        # makes one of them a Driver, and a Driver carries no gun at all (DRIVERS_MAY_SHOOT is
        # false), so the weapon and staged-shot specs cannot pass in that client whatever is
        # replayed into it. Ask each client who it is, and drive the SHOOTER's (round 1, finding 2).
        teams = {}
        for studio_id in clients:
            team, _ = wait_for(lambda: studio.query("Client", QUERY_MY_TEAM, studio_id=studio_id),
                               lambda v: v != "", 45, 1)
            teams[studio_id] = team
        print("[harness2] client teams: " + ", ".join(f"{i[:8]}={teams[i] or '?'}" for i in clients))
        shooter = next((i for i in clients if teams[i] == "Shooters"), None)
        check("One client is on the Shooters team", shooter is not None,
              ", ".join(f"{i[:8]}={teams[i] or 'no team'}" for i in clients))
        if shooter is None:
            shooter = clients[0]  # keep going and report what happens, rather than stopping here
        other = next(i for i in clients if i != shooter)

        # THE TOKEN GOES INTO THE PROCESS, because it is not in the place the process started
        # from. Measured on 2026-09-25 with all three windows open (run 4): the editor held a fresh
        # token, the copy the server and both clients were running carried the same StringValue with
        # an EMPTY value, and Rojo does not patch a test process afterwards -- a token written to
        # disk mid-session never reached them. Every script in those processes WAS the Rojo-synced
        # one, so it is the value of a property, not the sync, that the copy leaves behind.
        # So: mint a fresh token now (the disk one is minutes old by this point), set it on the
        # SERVER, and let ordinary replication carry the StringValue to both clients. The runners are
        # waiting for exactly this (TestKit.awaitToken, TOKEN_WAIT = 60 s), and the gate they apply
        # is unchanged -- Studio, and a token under 120 s old.
        token = f"{secrets.token_hex(8)}:{int(time.time())}"
        minted.append(token)
        set_token = studio.query("Server", QUERY_SET_TOKEN % json.dumps(token), studio_id=server)
        if not check("The gate token reached the server process", set_token == token, set_token):
            end_session(studio, before)
            return verdict()
        for studio_id in clients:
            seen, ok = wait_for(lambda: studio.query("Client", QUERY_TOKEN, studio_id=studio_id),
                                lambda v: v == token, 20, 1)
            check(f"[{'shooter' if studio_id == shooter else 'driver'}] the token replicated to the "
                  "client", ok, f"client has {seen!r}")

        if scenarios is None:
            print("[harness2] no tests/client/input_scenarios.txt: nothing to replay")
        else:
            replay_input(studio, scenarios, token, check, studio_id=shooter)

        # ALL THREE AT ONCE, against ONE deadline. Read one after another, each with its own
        # window, a slow client is waited for only after the previous one has run its window out:
        # in run 5 both clients HAD reported -- the reads had simply given up first, one after the
        # other. A two-player client suite is also slower than a one-player one, because the
        # driver's weapon specs spend their timeouts failing, so the window is REPORT_WINDOW_2P.
        pending = {"server": (server, "server"), "shooter": (shooter, "client"),
                   "driver": (other, "client")}
        started_reading = time.time()
        deadline = started_reading + REPORT_WINDOW_2P
        while pending and time.time() < deadline:
            for name, (studio_id, side) in list(pending.items()):
                raw, why = process_call(
                    lambda: studio.query(side.capitalize(), QUERY_REPORT[side], studio_id=studio_id),
                    timeout=0, default="")
                if raw:
                    reports[name] = json.loads(raw)
                    print(f"[harness2] {name} reported after {int(time.time() - started_reading)} s")
                    del pending[name]
            if pending:
                time.sleep(2)

        for name, studio_id in (("server", server), ("shooter", shooter), ("driver", other)):
            # The console is read from the same still-loading (or already closed) process, so it
            # gets the same treatment: a missing console is a note in the output, never a crash
            # that skips end_session.
            console, why = process_call(lambda: studio.console(studio_id=studio_id), timeout=15)
            consoles[name] = console if not why else f"(no console from this process: {why})"

    finally:
        write_token("")  # close the gate so Karen's playtests do not run tests

    for name in ("server", "shooter", "driver"):
        report = reports.get(name)
        if not check(f"[{name}] runner reported within {REPORT_WINDOW_2P} s", report is not None):
            continue
        # EITHER token this run minted: the one written to disk before the click (a copy that
        # carries it opens the gate by itself) or the one injected afterwards. Nothing else -- a
        # token from an earlier run, or from a playtest, still fails.
        check(f"[{name}] report carries a token this run minted", report["token"] in minted,
              report["token"])
        check(f"[{name}] report comes from the DEV place", str(report["placeId"]) == place, str(report["placeId"]))
        summary = (f"{report['successCount']} passed, {report['failureCount']} failed, "
                   f"{report['errorCount']} errors, {report['skippedCount']} skipped")
        if name == "driver":
            # An OBSERVATION, not a check. The driver's client carries no gun and got no replay, so
            # its weapon and staged-shot specs cannot pass -- that is the game's rule, not a defect.
            print(f"  note   [driver] {report['status']}: {summary} (no gun, and no input replayed here)")
        else:
            check(f"[{name}] status PASS", report["status"] == "PASS",
                  report["status"] + " " + report.get("message", ""))
            check(f"[{name}] > 0 passed, 0 failed, 0 errors, 0 skipped",
                  report["successCount"] > 0 and report["failureCount"] == 0
                  and report["errorCount"] == 0 and report["skippedCount"] == 0, summary)

    server_report = reports.get("server")
    if server_report:
        ran = set(server_report.get("specs", []))
        check("The 2-player team spec ran on the server", "ServerStorage.Tests.match_teams.spec" in ran,
              ", ".join(sorted(ran)) if "ServerStorage.Tests.match_teams.spec" not in ran else "")
        # BY NAME, as `test` does: comparing counts lets a renamed spec plus a stale one pass.
        wanted = {"ServerStorage.Tests." + os.path.basename(f)[: -len(".luau")] for f in server_specs}
        not_run = sorted(wanted - ran)
        not_in_repo = sorted(ran - wanted)
        check("The server ran exactly the repo's server spec files", not not_run and not not_in_repo,
              "not run: " + ", ".join(not_run) + "; not in repo: " + ", ".join(not_in_repo)
              if (not_run or not_in_repo) else f"{len(ran)} ran")

    for name in ("server", "shooter", "driver"):
        if consoles.get(name):
            print(f"----- {name} Output -----")
            print(consoles[name])
            print("-" * 25)

    end_session(studio, before)
    return verdict()


def parse_vector(text):
    parts = [float(v) for v in text.replace(" ", "").split(",")]
    if len(parts) != 3:
        raise ValueError(f"expected x,y,z; got {text!r}")
    return parts


def main(argv):
    if len(argv) < 2 or argv[1] not in (
            "test", "test2", "state", "console", "stop", "manifest", "capture", "studios"):
        sys.exit(__doc__)
    if argv[1] != "capture" and len(argv) != 2:
        sys.exit(__doc__)
    if argv[1] == "capture" and not 3 <= len(argv) <= 5:
        sys.exit("usage: python tools/studio_mcp.py capture <name> [camera x,y,z] [look-at x,y,z]")
    if argv[1] == "manifest":
        with open(DEVPACKAGES_MANIFEST, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(devpackages_manifest()) + "\n")
        print(f"wrote {DEVPACKAGES_MANIFEST}")
        return 0
    studio = Studio()
    try:
        cmd = argv[1]
        if cmd == "test2":
            try:
                return run_test2(studio)
            except Exception as e:  # a harness fault is a FAIL, never a silent traceback (rule 6)
                print(f"[harness2] FAIL: {type(e).__name__}: {e}")
                return 1
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
        if cmd == "capture":
            name = re.sub(r"[^A-Za-z0-9_.-]", "-", argv[2])
            stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            path = os.path.join(SCREENSHOT_DIR, f"{stamp}-{name}.png")
            camera = parse_vector(argv[3]) if len(argv) > 3 else None
            look_at = parse_vector(argv[4]) if len(argv) > 4 else None
            if (camera is None) != (look_at is None):
                sys.exit("give both a camera and a look-at position, or neither")
            saved, text = studio.capture(path, camera, look_at)
            if not saved:
                print(f"[capture] no image came back: {text}")
                return 1
            print(f"[capture] wrote {os.path.relpath(saved, REPO)} (mode: {studio.mode()}). "
                  "Look at it before you claim what it shows (rule 5).")
            return 0
        if cmd == "studios":
            # The one command that answers "can this harness ever drive two players?" (Task 30).
            # A 2-client local test starts extra Studio processes; if they register with StudioMCP
            # they appear here with their own ids, and every tool takes a studio_id.
            print(studio.studios())
        elif cmd == "state":
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
