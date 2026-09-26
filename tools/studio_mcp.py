"""Driven Hunt test harness. THIS DOCSTRING IS THE SINGLE SOURCE OF TRUTH for how the test system works.
CLAUDE.md keeps the commands and points here; the research note keeps decisions and dated measurements.

Pattern: minimal stdio JSON-RPC MCP client (https://modelcontextprotocol.io/specification) talking to
StudioMCP.exe, which ships with Roblox Studio (Assistant settings -> MCP server).
Note: docs/research/2026-09-24-toolchain.md

Requires: Studio open on the DEV place in Edit mode, MCP server enabled, Rojo plugin connected.

Usage:
  python tools/studio_mcp.py test           # full checked run; exit 0 only on a clean-tree PASS
  python tools/studio_mcp.py test2          # the same specs in a 2-player local test (Karen starts it)
  python tools/studio_mcp.py selftest       # NO Studio: prove the concurrency helpers (CI runs this)
  python tools/studio_mcp.py state          # print Studio mode (read-only)
  python tools/studio_mcp.py console        # print Studio Output (read-only)
  python tools/studio_mcp.py stop           # stop a playtest (recovery)
  python tools/studio_mcp.py studios        # list the Studio instances StudioMCP can see (read-only)
  python tools/studio_mcp.py manifest       # after `wally install`: rewrite devpackages.sha256 (commit it)
  python tools/studio_mcp.py capture <name> [x,y,z] [x,y,z]   # save a screenshot as rule-5 evidence

Exit codes of `test` and `test2`: 0 PASS on a clean tree · 1 FAIL · 2 REFUSED (Studio not in Edit
mode) · 3 PASS on a dirty tree (flagged: not valid evidence).

THE SHA IN THE FINAL LINE IS HEAD AT THE MOMENT OF THE RUN, and it is re-checked at the end ("HEAD
unchanged during the run"). That sha is what a review request must write as its `Code commit:`: the
code commit is the commit the harness lines name, which has to be at or after the last commit that
touched src/, tests/ or tools/, with only paperwork after it (CLAUDE.md git workflow step 4).
`tools/agents.py` refuses a request whose `Code commit:` no pasted line names.

WHICH RUN IS EVIDENCE FOR WHAT (Director decision, 2026-09-26). `test` is the default and every
change needs it. `test2` is ALSO part of the merge gate for a change touching `src/` (gameplay),
`tests/client/` or this file: a driver, a tie, a team swap and half the client suite exist only with
two clients, so a one-player run says nothing about them. `tools/agents.py` refuses the review
without the `[harness2]` line for the same code commit. Docs, and the tools that are not this
harness, are exempt -- `test2` costs a human click and about eight minutes.

`selftest` is the exception to "needs Studio": it exercises the pure helpers only -- wait_for_each,
the reply keying, send_input_many, and the scenario file -- so it runs in CI, with no Studio, no
place and no network, in under a second. Exit 0 PASS, 1 FAIL. It exists because the concurrency
Task 50 added is only interesting with SEVERAL subjects, and no run on this machine reaches that
without two clients and a human click.

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
  Drive time under test (Task 41): ServerScriptService.Match.advanceForTests(seconds) moves the
      drive's own clock forward so a spec can watch Running -> Scoring -> the next drive in seconds
      instead of ten minutes. It is gated on Studio AND TestKit.activeToken() -- "a gated test run is
      in progress", which only TestKit.run sets -- so a playtest or a published place can never run a
      shortened drive; the published place has no TestKit at all, and Match reaches it through
      FindFirstChild + pcall so stripping it (TASKS.md row 2) cannot break the owner.
  tests/client/Role.luau -> ReplicatedStorage.ClientTests.Role
      Which team THIS client's player is on, resolved once at require time and shared by every client
      spec. Since Task 36 each spec asserts what is true for its player's ROLE -- a shooter's claims,
      or a driver's own (no Tool, no weapon actions bound, no crosshair, never staged, badge DRIVER)
      -- so a two-player run can require PASS from both clients instead of printing one of them.
      It is resolved BEFORE InputReady publishes the ready attribute, so the replay can never start
      against a client that does not yet know what it is.
  tests/client/input_scenarios.txt -> ReplicatedStorage.ClientTests.input_scenarios (StringValue)
      The input scenarios (Task 6). JSON in a .txt because a .txt is a StringValue this harness already
      compares byte-for-byte, so the scenario the client reads is provably the file on disk, and no new
      Rojo mapping (a default.project.json change needs a Rojo restart and Karen's Connect) is needed.
  Report (JSON): side, token, placeId, specs (full names), notes, successCount, failureCount, skippedCount,
      errorCount, status (PASS | FAIL | ERROR), message, and on the SERVER's report `seamClosed` -- set
      by TestRunner after TestKit.run returns, so the harness can see a module upvalue it cannot query.
      Runner status is PASS only if 0 failed, 0 errors, 0 skipped (any SKIP/FOCUS variant fails) and
      > 0 passed; a spec that fails to load is ERROR.
      TestKit.awaitToken waits up to TOKEN_WAIT for a token instead of reading once, so the gate is
      open for a runner that started up to a minute before the token arrives. The rule is unchanged
      -- Studio, and a token under 120 s old -- and a playtest still runs no tests because nothing
      writes a token during one, which is now what that claim rests on.
      `notes` is whatever the specs handed to TestKit.note: numbers that explain a failure, printed
      by both `test` and `test2` under "----- <side> notes -----". They ride in the report because a
      long session's console comes back truncated and loses everything but its tail (Task 34).

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
  7. Play. Both reports arrive WITHIN REPORT_WINDOW (300 s) of the replay finishing, polled TOGETHER
     against one deadline rather than one after the other -- since Task 41 the server's last spec
     waits for the client's report before it ends the drive, so the server reports last; each carries this run's token
     and the DEV PlaceId; each runner ran exactly the spec files of its side (matched by name); each
     status is PASS with > 0 passed, 0 failed, 0 errors, 0 skipped. (300 s, not 60: a client spec
     waits for its scenario to be staged, so the client suite cannot finish before the replay does,
     and the replay is ~50 s.)
  7a. While Play runs: replay every scenario in tests/client/input_scenarios.txt (see below). Two
     checks per run: the client was ready for it, and every step was sent.
  7b. When the CLIENT's report arrives, the harness sets ServerStorage's `ClientsFinished` attribute
     to this run's token, on the server, through execute_luau. That is the one word the server's specs
     get about the clients: a LocalPlayer attribute written on a client does NOT replicate to the
     server (measured, Task 41), and this game has no inbound remote by design. It exists because
     tests/server/zz_drive_boundary.spec.luau ENDS THE DRIVE -- which clears every boar, frees every
     tie and respawns everybody -- and doing that while a client suite is still asserting would break
     it. `test2` sets the same attribute once BOTH clients have reported.
  8. Stop. The token is cleared, the gate is seen closed in Studio, and the server's own report says
     the drive-clock seam closed with the run (`seamClosed`: TestKit clears `activeToken` when the run
     ends, so `Match.advanceForTests` cannot be reached afterwards). The answer comes from the report
     because a query that requires TestKit through `execute_luau` gets a DIFFERENT module instance,
     out of its own require cache, and can only ever say "closed" (measured, Task 48).
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
    1. Wait (<= 60 s, and for EVERY client in a 2-player run) for LocalPlayer's `readyAttribute` to
       carry THIS run's token. The client spec sets it after it has bound its listeners AND after
       ClientTests.Role has resolved its team, so a replay can never race the bindings and never
       reaches a client that does not yet know its role; a stale attribute from an earlier run is not
       mistaken for this one.
    2. For a scenario with a `stage` block, stage it first (below). In `test2` the STEPS go to BOTH
       clients, in the same order (Task 36), and the `stage` goes to the SHOOTER's client only: it
       pivots the character, and two characters staged onto the same boar is a scrum.
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
  key or button, a non-numeric moveTo, a `wait` outside StudioMCP's 0..10000 ms, a `readyAttribute`
  that is not a plain identifier, or a mouse BUTTON before any `moveTo` in the same scenario -- that
  last one because StudioMCP refuses a click with no established position and the position is carried
  only inside one scenario, which cost Task 35 a run. All of them fail there and then, because a step
  the replay sends but the spec cannot recognise is a hole in the evidence.
  Gated exactly like the specs: replay happens only inside `test`, only during its own Play, and the
  spec only listens when TestKit's token gate is open.
  What a scenario CANNOT express: DIFFERENT input per player (that is `test2`, and it sends the same
  steps to both clients); touch and gamepad input; typing text (StudioMCP has textInput, the
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
  processes and can replay input into the clients, and every input-driven client spec counts its own
  budget (input_driving's ARRIVE_TIMEOUT is 45 s) from where TestEZ reaches it -- run 5 lost 14 specs
  on the shooter exactly that way. A
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

       ALL THREE ARE PROBED TOGETHER, against ONE 60 s deadline, round-robin (Task 50). The three
       processes open their place at the same time and answer when they are ready, so probing them
       one after the other -- each with its own 60 s -- meant waiting the first out before the
       second was asked once. Each process still gets the full 60 s and the same QUERY_ROLE answer
       decides; only the WAITING overlaps.
    3. Each client is asked which team its LocalPlayer is on -- BOTH against one 45 s deadline,
       for the same reason (Task 50): one server event assigns both teams, so they answer within
       milliseconds of each other and asking them in turn simply put the second wait after the
       first. The token's arrival in each client, and each client's input-ready handshake, are
       waited for the same way: one deadline, every client polled in it. THEN the gate is opened
       (above) and
       the input scenarios are replayed into BOTH clients -- in that order, because the client specs
       start the moment the token lands and input_driving.spec gives the replay ARRIVE_TIMEOUT (45 s)
       to arrive; a 45-second team query must not be inside that budget.
       WHY BOTH, SINCE TASK 36: with two players the drive makes one of them a Driver, and a Driver
       carries no gun at all (DRIVERS_MAY_SHOOT is false). Sending him nothing meant 23 of his 67
       specs failed by construction and his whole report had to be printed as an observation. He now
       gets the same steps -- they cost him nothing, because none of the weapon's actions is bound
       without a Tool -- and ClientTests.Role lets each spec assert the driver's half of the rule.
       WHICH CLIENT IS THE SHOOTER still matters for the `stage`, which moves a character.
    4. All three reports (the server, the shooter's client, the driver's client) are polled
       TOGETHER against one deadline of REPORT_WINDOW_2P seconds, and each is announced with how
       long it took. ALL THREE ARE CHECKED since Task 36. Read one after another, a slow client is
       only waited for once the previous
       one's window has run out: in run 5 both clients had in fact reported, and the sequential
       reads had given up first.
    Starting it WITHOUT Karen: the Director has
    driven-hunt-runs/press-f7.ps1 (on Karen's Desktop), which brings the DEV Studio window to
    the front and posts F7 to it (Karen's F7 is bound to Server and Clients with 2 players). This
    mode does not call it -- the Director will wire that up -- but that is how the click can be made
    without a human.

    5. Checks: three NEW studios appeared; the gate was shut again before the copy was taken; one
       server and exactly two clients were found; one client is on the Shooters team; the gate
       token reached the server process and replicated to both clients; each runner reported inside
       the window; each report carries a
       token it minted (the disk one, in case a copy carried it, or the injected one -- nothing
       else) and the DEV PlaceId; ALL THREE reports are PASS with 0 failed/errors/skipped; the server
       ran tests/server/match_teams.spec; and it ran every server spec file in the repo.
    6. It stops each test instance and, if any remain, says to press Cleanup.
    7. It prints a PHASE TABLE: how many seconds each phase of the run took (Task 50), so the next
       person to make this faster -- or to notice it got slower -- reads it out of the same output
       that carries the verdict. `test` prints one too. It comes out on EVERY path, a refusal and a
       half-finished run included, because a run that died waiting is the one whose timing most
       wants explaining.
  Final line: "[harness2] PASS|FAIL: n/m checks @ <full HEAD sha> (clean tree | DIRTY TREE ...)".
  A [harness2] line is NOT a substitute for a [harness] line as PR evidence: this mode runs none of
  `test`'s checks 4-6 (disk-vs-Studio comparison, no-script-outside-Rojo, spec placement). It is an
  extra run, never the merge gate's.

  The 2-player assertion itself is tests/server/match_teams.spec.luau, and it is written to be true
  for WHATEVER number of players is present, so it runs in both modes: with one player it asserts
  Director decision F (the lone player is a Shooter and is armed); with two, that both are assigned,
  that the teams are 1 and 1, and that only the shooter may carry a gun.

How long a run takes, and what it is waiting for (Task 50)
  Both modes end with a phase table, and the replay prints its own split ("N batch call(s) to M
  client(s) took X s; the scenarios' own gaps took Y s"). Measured 2026-09-26 on this PC:

    - an `execute_luau` against the EDIT DataModel costs 0.067 s; an input batch against a PLAY
      client costs about 0.2 s. StudioMCP round trips are NOT what makes a run long.
    - what makes a run long is WAITING: for three processes to open a place, for the drive to
      assign teams, for a client to bind its listeners, for the drive to release a boar, and for
      the scenarios' own gaps.
    - tests/client/input_scenarios.txt contains 34.5 s of `wait` steps. That is the floor of any
      run that replays them, it belongs to the specs that assert against those gaps, and the
      harness does not shorten it.
    - a one-player `test` is about 90 s: ~4 s of Edit-place checks, ~65 s of replay (34 s of
      scenario gaps, ~22 s inside the `stage` query waiting for the drive to release a boar, ~5 s
      of calls), ~19 s waiting for the two reports.

  EVERY PER-PROCESS WAIT IN `test2` IS ROUND-ROBIN against one deadline (wait_for_each), and the
  same batch of input goes to both clients in one round trip (Studio.send_input_many), because more
  than one request may now be in flight: replies are keyed by id and kept (Studio._submit /
  Studio._await). With ONE target both are exactly what the old single-call code did, so the
  one-player `test` neither gains nor loses.

Screenshots as evidence (Task 7)
  `capture <name> [camera x,y,z] [look-at x,y,z] [role]` saves StudioMCP's screen_capture image to
  .screenshots/<UTC stamp>-<name>.png (git-ignored) and prints the path. Studio._call keeps text blocks
  only, which is why captures could not be saved before; Studio.capture() reads the image block.
  It works in Edit and during Play (Tasks 17, 18 and 22 captured Play this way), and it is a separate
  command, not part of `test`: the Builder inspects the image and says what it shows (rule 5).

  WITH MORE THAN ONE STUDIO CONNECTED -- which is every `test2` run -- StudioMCP refuses any call that
  names no studio_id, so this used to be impossible during a two-player session and the one picture
  worth having (a tied player, seen from a window) could not be taken (Task 41). The optional trailing
  `role` picks the window: `edit` (the default), `server`, `client`, or `client:<LocalPlayer name>`
  such as `client:Player2`. The editor is recognised by its mode being Edit and a test process by
  asking it, through the same `probe_role` `test2` classifies with -- never by name.

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
# Opens the gate inside a RUNNING test process: the place those processes start from does not
# reliably carry the token (see the `test2` section), so it is set on the server and replicates.
# The harness's one word to the SERVER's specs: every client of this run has reported, so a spec may
# now disturb the session (Task 41). ServerStorage is where the server's own report already lives, and
# an attribute set through execute_luau is server-side. A client CANNOT tell the server this itself:
# a LocalPlayer attribute set on the client does not replicate to the server (measured, Task 41), and
# this system has no inbound remote by design.
QUERY_SET_CLIENTS_DONE = (
    'local SS = game:GetService("ServerStorage") '
    'SS:SetAttribute("ClientsFinished", %s) '
    'return tostring(SS:GetAttribute("ClientsFinished"))'
)
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
# Which team the drive put this client's player on. Both clients get the input replay since Task 36;
# this picks which one gets the `stage`, which moves a character -- and it is the shooter, because
# the staged scenario is a shot at a boar and a driver carries no gun.
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
        self.replies = {}
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

    def _submit(self, method, params):
        """Send one request and return its id, WITHOUT waiting for the reply (Task 50)."""
        self.next_id += 1
        self._send({"jsonrpc": "2.0", "id": self.next_id, "method": method, "params": params})
        return self.next_id

    def _await(self, request_id, timeout=120):
        """The reply to one submitted request.

        Replies are keyed by id and KEPT (`self.replies`), because more than one request can be in
        flight since Task 50. The old loop dropped every message whose id did not match the one it
        was waiting for, which was safe only while exactly one request existed at a time -- with two
        in flight it would have eaten the other one's answer."""
        while request_id not in self.replies:
            msg = json.loads(self.lines.get(timeout=timeout))
            if msg.get("id") is not None:
                self.replies[msg["id"]] = msg
        msg = self.replies.pop(request_id)
        if "error" in msg:
            raise RuntimeError(msg["error"])
        return msg["result"]

    def _rpc(self, method, params, timeout=120):
        return self._await(self._submit(method, params), timeout=timeout)

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

    def send_input_many(self, device, actions, studio_ids):
        """The same batch to several clients AT ONCE -> {studio_id: None} or {studio_id: error}.

        Task 50. The batches go out back to back and the replies are collected afterwards, so two
        clients cost one round trip rather than two. An input call against a Play client is the
        harness's most expensive call by far (measured 2026-09-26: ~1 s each against a Play client,
        against 0.067 s for an execute_luau in Edit), and `test2` makes ~26 of them per client, so
        sending them one after the other put a whole minute of pure latency on the critical path.

        With ONE target this is exactly one submit and one await -- the same two lines `send_input`
        runs -- so the one-player `test` gains nothing and loses nothing.

        Order within a batch is the tool's to keep and is unchanged: the actions inside one call are
        untouched, and the calls still leave in scenario order. What overlaps is only the WAIT for
        two clients' replies to the SAME batch, which nothing orders against each other."""
        tool = "user_keyboard_input" if device == "keyboard" else "user_mouse_input"
        pending = {}
        for studio_id in studio_ids:
            arguments = {"datamodel_type": "Client", "actions": actions}
            if studio_id:
                arguments["studio_id"] = studio_id
            pending[studio_id] = self._submit("tools/call", {"name": tool, "arguments": arguments})
        out = {}
        for studio_id, request_id in pending.items():
            try:
                result = self._await(request_id)
                text = "\n".join(c.get("text", "") for c in result.get("content", []))
                out[studio_id] = RuntimeError(f"{tool}: {text}") if result.get("isError") else None
            except Exception as e:  # queue.Empty when StudioMCP stops answering, RuntimeError on a fault
                out[studio_id] = e
        return out

    def capture(self, path, camera=None, look_at=None, studio_id=None):
        """Save StudioMCP's screen_capture image to `path`. Returns the path, or None with the text.

        _call() joins text blocks and drops the image, which is why captures could not be saved
        (TASKS.md Task 7). This reads the image block instead."""
        args = {"capture_id": f"DrivenHunt_{os.path.basename(path)}"}
        if camera and look_at:
            args["camera_position"], args["look_at_position"] = list(camera), list(look_at)
        # NAMED, when there is more than one Studio: every tool is refused with "This call is missing
        # the required `studio_id` argument" as soon as a local test adds processes, which is what
        # made a screenshot impossible during a two-player run (Task 41).
        if studio_id:
            args["studio_id"] = studio_id
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


def wait_for_each(keys, fn, predicate, timeout, interval=0.5):
    """`wait_for` over SEVERAL subjects against ONE deadline -> {key: (value, ok)}.

    Task 50. Every per-process wait in `test2` used to be a loop of `wait_for` calls, one whole
    timeout each, so two clients that both became ready at t=10 s cost 20 s of waiting and a worst
    case of 2 x timeout. They are independent questions asked of independent processes: asked
    round-robin against one deadline they cost the SLOWEST, not the SUM. The bound each subject gets
    is unchanged (`timeout`), and so is the predicate, so nothing is checked less hard -- a subject
    that never answers still fails after `timeout`, it just no longer delays the next one.

    With one key this is `wait_for`, so the one-player `test` is unaffected."""
    deadline = time.time() + timeout
    values = {key: None for key in keys}
    done = {}
    while True:
        for key in [k for k in keys if k not in done]:
            try:
                values[key] = fn(key)
            except RuntimeError:
                values[key] = None
            if values[key] is not None and predicate(values[key]):
                done[key] = True
        if len(done) == len(keys) or time.time() >= deadline:
            return {key: (values[key], key in done) for key in keys}
        time.sleep(interval)


class Phases:
    """Wall-clock per phase, printed as a table at the end of a run (Task 50).

    The point is that the next person to make this faster does not have to guess: every run says
    where its seconds went, so a regression is visible in the same output that carries the verdict."""

    def __init__(self, label):
        self.label = label
        self.start = time.time()
        self.last = self.start
        self.rows = []

    def mark(self, name):
        now = time.time()
        self.rows.append((name, now - self.last))
        self.last = now

    def report(self):
        total = time.time() - self.start
        print(f"[{self.label}] phases, {total:.0f} s total:")
        for name, seconds in self.rows:
            if seconds >= 0.5:
                print(f"[{self.label}]   {seconds:6.1f} s  {name}")
        counted = sum(s for _, s in self.rows)
        if total - counted >= 0.5:
            print(f"[{self.label}]   {total - counted:6.1f} s  (after the last mark)")


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
    # Here with the other refusals, not at replay time (6a(c)): QUERY_READY templates this straight
    # into Luau, and a value that is not a plain identifier used to raise in the middle of Play, as a
    # harness error rather than as a named refusal before Play starts.
    ready = data.get("readyAttribute", "InputProbeReady")
    if not re.fullmatch(r"[A-Za-z0-9_]{1,100}", ready):
        raise RuntimeError(f"readyAttribute must be a plain identifier; got {ready!r}")
    for scenario in data["scenarios"]:
        if scenario.get("stage") is not None:
            check_stage(f"scenario {scenario.get('name')!r}", scenario["stage"])
        placed = False
        for index, step in enumerate(scenario.get("steps") or [], start=1):
            where = f"scenario {scenario.get('name')!r} step {index}"
            check_step(where, step)
            # A MOUSE BUTTON WITH NO POSITION TO CLICK AT IS REFUSED BY StudioMCP AT RUN TIME
            # ("Either x and y, instance_path, or a prior action that establishes mouse position is
            # required"), and the position is carried only inside one scenario -- so a scenario whose
            # first mouse action is a button sends nothing and the spec waiting for it fails for a
            # reason that has nothing to do with the game. Task 35 lost a run to exactly that. It is
            # a property of the file, so it is refused here, before Play, with the rest (6a(d)).
            if step.get("device") == "mouse":
                if step.get("action") == "moveTo":
                    placed = True
                elif not placed:
                    raise RuntimeError(
                        f"{where}: a mouse button before any moveTo in this scenario; StudioMCP "
                        "refuses a click with no established position")
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


def replay_input(studio, data, token, check, studio_id=None, mirror_ids=()):
    """Replay every scenario into the running Play client(s). Adds two checks per run (three with a
    `stage`). `studio_id` names WHICH client in a 2-player run; None means "the only one".

    `mirror_ids` are the OTHER clients that get the same steps, in the same order, in the same call
    batch -- but no `stage`. Task 36: with two players the driver used to receive no input at all, so
    every input-driven spec on his client failed by construction and `test2` could only print his
    report as an observation. The steps cost him nothing (he holds no Tool, so the weapon keys do
    nothing) and they let his half of the suite assert what IS true of a driver. The STAGE stays on
    one client: it pivots the character, and two characters staged onto the same boar is a scrum."""
    # Validated in load_scenarios, before Play, with the rest of the file's refusals (6a(c)).
    ready_attr = data.get("readyAttribute", "InputProbeReady")
    targets = [studio_id] + [i for i in mirror_ids if i != studio_id]
    # EVERY target must be listening before ANY step is sent: a replay into a client that has not
    # bound its listeners proves nothing there and cannot be repeated. 60 s, not 20: since Task 36 a
    # client resolves its own team (ClientTests.Role) before it publishes this, so the handshake now
    # waits for the drive to assign teams -- which in a one-player `test` happens during Play.
    # ONE deadline for all of them, not one each (Task 50): two clients that both go ready at t=12 s
    # used to cost 24 s, and a client that never went ready delayed the other's first look by a
    # whole minute. Each still gets the same 60 s and the same predicate.
    answers = wait_for_each(targets,
                            lambda target: studio.query("Client", QUERY_READY % ready_attr,
                                                        studio_id=target),
                            lambda v: v == token, 60, 0.5)
    not_ready = [f"{(target or 'client')[:8]}: {answers[target][0]!r}"
                 for target in targets if not answers[target][1]]
    if not check("[input] the client bound its listeners and published this run's token",
                 not not_ready, "; ".join(not_ready) if not_ready else repr(token)):
        return
    sent, problems, staged = 0, [], []
    # Where the replay's seconds go, split into the part this harness controls (calls) and the part
    # the scenarios do (their own `wait` gaps, which are what the specs assert against and are not
    # the harness's to shorten). Task 50: the split is printed so the next person can see at a glance
    # whether a slow replay is latency or the file.
    slept, calls, call_seconds = 0.0, 0, 0.0
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
                slept += payload
                continue
            sent += len(payload)  # steps in the scenario, not calls made: two clients share one step
            # ONE round trip for every target (Task 50). An input call against a Play client costs
            # about a second, so with two clients this batch used to cost two.
            began = time.time()
            results = studio.send_input_many(device, payload, targets)
            call_seconds += time.time() - began
            calls += 1
            for target, failure in results.items():
                if failure is not None:
                    # Not just RuntimeError: the transport raises queue.Empty when StudioMCP stops
                    # answering, and a hung input call must fail this check, not the whole run
                    # (review round 1).
                    problems.append(f"{scenario.get('name')}: {type(failure).__name__}: {failure}")
    names = ", ".join(str(s.get("name")) for s in data["scenarios"])
    print(f"[input] {calls} batch call(s) to {len(targets)} client(s) took {call_seconds:.0f} s; "
          f"the scenarios' own gaps took {slept:.0f} s")
    check(f"[input] replayed every step of {len(data['scenarios'])} scenario(s)", not problems,
          "; ".join(problems) if problems else f"{sent} steps sent to {len(targets)} client(s) ({names})")
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
        phases.report()
        print(f"[harness] {'PASS' if passed else 'FAIL'}: {sum(checks)}/{len(checks)} checks @ {sha} ({tree})")
        if dirty:
            for line in sorted(set(dirty_start + dirty_end))[:10]:
                print("    dirty: " + line)
        if code is not None:
            return code
        return 1 if not passed else (3 if dirty else 0)

    phases = Phases("harness")
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

        phases.mark("checks against the Edit place (sync, scripts, specs)")
        print("[harness] Play")
        studio.set_play(True)
        try:
            if scenarios is None:
                print("[harness] no tests/client/input_scenarios.txt: nothing to replay")
            else:
                replay_input(studio, scenarios, token, check)
            phases.mark("replaying the input scenarios")
            # BOTH SIDES AGAINST ONE DEADLINE, round-robin -- the fix Task 34 already made in `test2`
            # and this loop did not have. Read one after another, the server's whole window has to
            # run out before the client is looked at once, and since Task 41 the server's last spec
            # deliberately WAITS for the client to finish before it ends the drive: the server then
            # reported at ~125 s and the sequential read had given up at 120.
            pending = {"server": "Server", "client": "Client"}
            deadline = time.time() + REPORT_WINDOW
            while pending and time.time() < deadline:
                for side, datamodel in list(pending.items()):
                    # process_call, not a bare query: while a Play session is starting, StudioMCP
                    # answers "place is not open" and the like, and those are what process_call
                    # retries (still_loading; anything else it re-raises). The wait_for this loop
                    # replaced swallowed them, and run_test2's equivalent loop has always used this
                    # (TASKS.md 41a(a)).
                    raw, _why = process_call(
                        lambda: studio.query(datamodel, QUERY_REPORT[side]), timeout=0, default="")
                    if raw:
                        reports[side] = json.loads(raw)
                        print(f"[harness] {side} reported after {int(time.time() - (deadline - REPORT_WINDOW))} s")
                        del pending[side]
                        if side == "client":
                            # The server's last spec waits for this before it ends the drive. Wrapped
                            # like the poll above and like run_test2's equivalent: a loading-class
                            # error here would otherwise end the run with a traceback one second
                            # before the handshake would have landed.
                            process_call(
                                lambda: studio.query("Server", QUERY_SET_CLIENTS_DONE % json.dumps(token)),
                                timeout=10)
                if pending:
                    time.sleep(1)
            phases.mark("reading both reports")
            output = studio.console()
        finally:
            studio.set_play(False)
    finally:
        write_token("")  # close the gate so Karen's playtests do not run tests

    print("----- Studio Output -----")
    print(output)
    print("-------------------------")
    for side in ("server", "client"):
        # NOTES BEFORE CHECKS, and outside the pass/fail branches: a note is a spec explaining
        # itself to whoever reads this output, and it is worth most when the run failed.
        for note in (reports.get(side) or {}).get("notes", []):
            print(f"  note   [{side}] {note}")
        for failure in (reports.get(side) or {}).get("failures", []):
            print(f"  failed [{side}] {describe_failure(failure)}")
    for side in ("server", "client"):
        report = reports.get(side)
        if not check(f"[{side}] runner reported within {REPORT_WINDOW} s", report is not None):
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
    # THE DRIVE-CLOCK SEAM (audit-004 F5). `TestKit.activeToken` is what `Match.advanceForTests` asks
    # "is a gated test run in progress"; left set, the seam stays open for the rest of a Studio session
    # a human is about to play in. The answer comes from the RUNNER'S OWN report, because a query that
    # requires TestKit through execute_luau gets a different instance and can only ever say "closed"
    # (measured; TestKit.finish says so too).
    # `reports.get`, never `reports[...]`: when the server report does not arrive inside REPORT_WINDOW
    # -- the failure that window has been widened for twice (Tasks 34 and 41) -- indexing raises
    # KeyError before `verdict()` runs, and an eight-minute run ends in a traceback with no
    # "[harness] FAIL: n/m checks @ <sha>" line at all. A missing report must FAIL this check, not
    # abort the run (review round 1 of Task 48).
    seam = (reports.get("server") or {}).get("seamClosed")
    check("the drive-clock seam closed when the server run finished", seam is True, repr(seam))
    phases.mark("ending Play, checking the reports")
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


def studio_for_role(studio, role):
    """The studio_id to address for `role`, or (None, why). `role` is "edit", "server", "client", or
    "client:<LocalPlayer name>"; None means "let StudioMCP decide", which only works with one Studio.

    WHY THIS EXISTS (Task 41): every StudioMCP tool is refused with "This call is missing the required
    `studio_id` argument" as soon as more than one Studio is connected, and `capture` sent none -- so
    no screenshot could be taken during a two-player run at all, and the one picture worth having,
    a tied player seen from another player's window, was unreachable (TASKS.md row 35).

    The EDIT studio is identified the way `test2` identifies everything else: by what it answers, not
    by its name. A test process answers `server` or `client` from RunService:IsServer(); the editor is
    the one whose mode is Edit."""
    entries = studio.studio_list()
    if len(entries) == 1:
        return entries[0]["id"], ""
    wanted, _, wanted_player = (role or "edit").partition(":")
    found = []
    for entry in entries:
        studio_id = entry["id"]
        try:
            mode = studio.mode(studio_id=studio_id)
        except RuntimeError:
            mode = ""
        if mode == "Edit":
            found.append(("edit", "", studio_id))
            continue
        # A Play process: ask it what it is, exactly as classify_studios does.
        got, player, _, _ = probe_role(studio, studio_id, timeout=20)
        found.append((got or "unknown", player, studio_id))
    for got, player, studio_id in found:
        if got != wanted:
            continue
        if wanted_player and player != wanted_player:
            continue
        return studio_id, ""
    shape = ", ".join(f"{got}{'/' + player if player and player != 'nil' else ''}={sid[:8]}"
                      for got, player, sid in found)
    return None, f"no Studio answered as {role!r}; connected: {shape}"


def classify_studios(studio, before, timeout=60):
    """Split the studios a local test added into (server_id, [client_ids], [unknown_ids]).

    `before` is the listing from before the test started, so the edit Studio -- and anything else
    Karen happens to have open -- is excluded by identity rather than by name. WHICH of them is the
    server is then asked of each process itself (probe_role), because what they advertise does not
    distinguish them.

    ALL THREE ARE PROBED TOGETHER against one deadline (Task 50). The three processes open their
    place at the same time and answer when they are ready; probing them one after the other, each
    with its own 60 s, meant waiting out the first before the second was asked once -- so three
    processes that all became answerable at t=40 s cost 120 s. Round-robin they cost the slowest.
    Each still gets the full `timeout` to answer, and a process that never answers is still
    unclassified with the same reason, so the classification is no weaker."""
    known = {s["id"] for s in before}
    fresh = [e["id"] for e in studio.studio_list() if e["id"] not in known]
    deadline = time.time() + timeout
    resolved = {}
    while True:
        for studio_id in [i for i in fresh if i not in resolved]:
            # timeout=0 is ONE attempt: the round-robin here owns the waiting.
            role, player, datamodel, why = probe_role(studio, studio_id, timeout=0)
            if role:
                resolved[studio_id] = (role, player, datamodel, why)
        if len(resolved) == len(fresh) or time.time() >= deadline:
            break
        time.sleep(1)

    server, clients, unknown = None, [], []
    for studio_id in fresh:
        role, player, datamodel, why = resolved.get(studio_id) or probe_role(studio, studio_id, timeout=0)
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


# One deadline for BOTH reports of a one-player run. 120 s was the old per-side window, and it was
# sequential: since Task 41 the server's last spec waits for the client to finish before it ends the
# drive, so the server legitimately reports after the client does, and reading the server first burned
# the whole window before the client was looked at once.
REPORT_WINDOW = 300


# A two-player client suite is slower than a one-player one: the same replay is sent to two clients,
# so every step costs two calls. Run 5 measured both clients finishing after the old sequential
# 120 s reads had given up; this window is one deadline for all three reports.
REPORT_WINDOW_2P = 420


def describe_failure(text):
    """One line naming the spec and the line, and what went wrong.

    A TestEZ failure is a message plus a stack, and the only part that says WHICH spec broke is the
    first frame inside tests/ -- so both are kept and everything between them is dropped."""
    lines = [line.strip() for line in str(text).splitlines() if line.strip()]
    message = lines[0] if lines else str(text)
    message = re.sub(r"^.*?TestRunner:\d+: ", "", message)
    where = next((line for line in lines[1:]
                  if ".spec:" in line and ("ClientTests" in line or "Tests." in line)), "")
    if where:
        where = re.sub(r"^.*?(ClientTests|Tests)\.", "", where)
    return (f"{where} " if where else "") + message[:200]


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
        # BEFORE the verdict line and on EVERY path out, including a refusal and a half-finished run:
        # a run that died waiting is the one whose timing most wants explaining (Task 50).
        phases.report()
        print(f"[harness2] {'PASS' if passed else 'FAIL'}: {sum(checks)}/{len(checks)} checks @ {sha} ({tree})")
        if dirty:
            for line in sorted(set(dirty_start + dirty_end))[:10]:
                print("    dirty: " + line)
        return code if code is not None else (1 if not passed else (3 if dirty else 0))

    phases = Phases("harness2")
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

        phases.mark("checks, token sync, gate shut")
        print(START_CLICKS.format(seconds=wait_seconds))
        known = {s["id"] for s in before}

        def new_studios():
            return [s for s in studio.studio_list() if s["id"] not in known]

        # THREE NEW instances, not "three in total": a local test adds a server and two clients, and
        # waiting for a total of three is satisfied by two of them -- the classification would then
        # run against a half-registered test, find one client, and fail a run Karen had started
        # correctly (round 1, finding 1).
        found, ok = wait_for(new_studios, lambda v: len(v) >= 3, wait_seconds, 1)
        phases.mark("waiting for the Start click and three processes")
        if not check(f"A 2-player local test appeared within {wait_seconds} s", ok,
                     f"{len(found)} new studio(s) beside the editor"):
            print("[harness2] NEEDS KAREN: nobody pressed Start. Nothing was run and nothing is claimed.")
            return verdict()

        server, clients, unknown = classify_studios(studio, before)
        phases.mark("classifying the three processes")
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
        # BOTH clients against ONE 45 s deadline (Task 50). They are assigned their teams by the same
        # server event, so they answer at about the same moment; asking them one after the other,
        # each with its own 45 s, put the second client's whole wait after the first's.
        answers = wait_for_each(clients,
                                lambda studio_id: studio.query("Client", QUERY_MY_TEAM,
                                                               studio_id=studio_id),
                                lambda v: v != "", 45, 1)
        teams = {studio_id: answers[studio_id][0] for studio_id in clients}
        phases.mark("asking both clients their team")
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
        # ONE 20 s deadline for both (Task 50): one StringValue replicates to both clients from the
        # same server write, so they see it within milliseconds of each other.
        arrived = wait_for_each(clients,
                                lambda studio_id: studio.query("Client", QUERY_TOKEN,
                                                               studio_id=studio_id),
                                lambda v: v == token, 20, 0.5)
        for studio_id in clients:
            seen, ok = arrived[studio_id]
            check(f"[{'shooter' if studio_id == shooter else 'driver'}] the token replicated to the "
                  "client", ok, f"client has {seen!r}")

        phases.mark("injecting the gate token and replicating it")
        if scenarios is None:
            print("[harness2] no tests/client/input_scenarios.txt: nothing to replay")
        else:
            # BOTH clients, one stage. See replay_input: the driver's half of the suite is only
            # assertable if his client receives the same input the shooter's does.
            replay_input(studio, scenarios, token, check, studio_id=shooter, mirror_ids=[other])

        # ALL THREE AT ONCE, against ONE deadline. Read one after another, each with its own
        # window, a slow client is waited for only after the previous one has run its window out:
        # (both clients get the replay since Task 36, and input_driving's own budget is 45 s)
        # in run 5 both clients HAD reported -- the reads had simply given up first, one after the
        # other. A two-player client suite is also slower than a one-player one, because the same
        # replay is sent to two clients, so the window is REPORT_WINDOW_2P.
        phases.mark("replaying the input scenarios into both clients")
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
                    if name in ("shooter", "driver") and "shooter" not in pending and "driver" not in pending:
                        # BOTH clients are finished: the server's last spec may end the drive now.
                        process_call(
                            lambda: studio.query("Server", QUERY_SET_CLIENTS_DONE % json.dumps(token),
                                                 studio_id=server),
                            timeout=10, default="")
            if pending:
                time.sleep(1)

        phases.mark("reading all three reports")
        for name, studio_id in (("server", server), ("shooter", shooter), ("driver", other)):
            # The console is read from the same still-loading (or already closed) process, so it
            # gets the same treatment: a missing console is a note in the output, never a crash
            # that skips end_session.
            console, why = process_call(lambda: studio.console(studio_id=studio_id), timeout=15)
            consoles[name] = console if not why else f"(no console from this process: {why})"

    finally:
        write_token("")  # close the gate so Karen's playtests do not run tests

    for name in ("server", "shooter", "driver"):
        for note in (reports.get(name) or {}).get("notes", []):
            print(f"  note   [{name}] {note}")
        for failure in (reports.get(name) or {}).get("failures", []):
            print(f"  failed [{name}] {describe_failure(failure)}")

    for name in ("server", "shooter", "driver"):
        report = reports.get(name)
        if report is None:
            # ALL THREE ARE CHECKED SINCE TASK 36. The driver's used to be an observation because his
            # client got no replay and no gun, so 23 of his 67 specs failed by construction; the
            # specs are role-aware now (ClientTests.Role) and he receives the same input the shooter
            # does, so his report is evidence like any other -- and a missing one is a failure.
            check(f"[{name}] runner reported within {REPORT_WINDOW_2P} s", False)
            continue
        # EITHER token this run minted: the one written to disk before the click (a copy that
        # carries it opens the gate by itself) or the one injected afterwards. Nothing else -- a
        # token from an earlier run, or from a playtest, still fails.
        check(f"[{name}] report carries a token this run minted", report["token"] in minted,
              report["token"])
        check(f"[{name}] report comes from the DEV place", str(report["placeId"]) == place, str(report["placeId"]))
        summary = (f"{report['successCount']} passed, {report['failureCount']} failed, "
                   f"{report['errorCount']} errors, {report['skippedCount']} skipped")
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
    phases.mark("reading consoles, checking reports, ending the session")
    return verdict()


# ---------------------------------------------------------------- selftest (Task 50)

def selftest():
    """Prove the concurrency Task 50 added, WITHOUT Studio. Runs in CI.

    A one-player `test` exercises wait_for_each and send_input_many with exactly one subject, which
    is the case where they are trivially the old code. The case that makes `test2` fast -- several
    subjects waited for at once -- no run on this machine can reach without two clients and a human
    click, so it is proved here instead, against fakes, in under a second."""
    failures = []

    def ok(name, condition, detail=""):
        if not condition:
            failures.append(f"{name}{': ' + detail if detail else ''}")

    # 1. Several subjects that answer at different times cost the SLOWEST, not the SUM.
    answers = {"a": 3, "b": 4, "c": 1}   # how many looks each needs
    looks = {key: 0 for key in answers}

    def look(key):
        looks[key] += 1
        return "yes" if looks[key] >= answers[key] else "not yet"

    began = time.time()
    got = wait_for_each(list(answers), look, lambda v: v == "yes", 5, 0.05)
    elapsed = time.time() - began
    ok("every subject succeeds", all(got[key][1] for key in answers), repr(got))
    ok("each subject was looked at until IT answered",
       all(looks[key] == answers[key] for key in answers), repr(looks))
    # The slowest needs 4 looks = 3 sleeps = 0.15 s. One-at-a-time would be 3+4+1 = 8 looks
    # = 5 sleeps of its own each, i.e. 0.25 s or more. The bound is deliberately loose: this
    # asserts the SHAPE (overlapped, not serial), not a wall-clock budget on a busy PC.
    ok("the waits overlapped", elapsed < 0.25, f"{elapsed:.3f} s")

    # 2. A subject that NEVER answers still fails, after the deadline, and does not stop the others.
    began = time.time()
    got = wait_for_each(["good", "never"],
                        lambda key: "yes" if key == "good" else "no",
                        lambda v: v == "yes", 0.3, 0.05)
    elapsed = time.time() - began
    ok("the good subject succeeds beside a hopeless one", got["good"][1], repr(got))
    ok("the hopeless subject fails", not got["never"][1], repr(got))
    ok("it failed at the deadline, not before or long after", 0.3 <= elapsed < 1.0, f"{elapsed:.3f} s")
    ok("the failing subject's last value is reported", got["never"][0] == "no", repr(got["never"]))

    # 3. A RuntimeError from one subject is "not yet", exactly as in wait_for.
    tries = {"n": 0}

    def raises_once(_key):
        tries["n"] += 1
        if tries["n"] == 1:
            raise RuntimeError("place is not open")
        return "yes"

    got = wait_for_each(["x"], raises_once, lambda v: v == "yes", 2, 0.05)
    ok("a RuntimeError is retried, not raised", got["x"][1], repr(got))

    # 4. ONE subject behaves exactly like wait_for -- the one-player `test` path.
    counted = {"n": 0}

    def third_time(_key=None):
        counted["n"] += 1
        return "yes" if counted["n"] >= 3 else "no"

    got = wait_for_each(["only"], third_time, lambda v: v == "yes", 2, 0.01)
    many = counted["n"]
    counted["n"] = 0
    value, single = wait_for(third_time, lambda v: v == "yes", 2, 0.01)
    ok("one subject matches wait_for", got["only"] == (value, single) and many == counted["n"],
       f"{got['only']!r} vs {(value, single)!r}, {many} vs {counted['n']} looks")

    # 5. Replies are keyed by id, so two requests in flight cannot eat each other's answer. This is
    # the transport change send_input_many needs; the old loop dropped every non-matching message.
    class FakeStudio(Studio):
        def __init__(self):  # no subprocess, no Studio
            self.lines = queue.Queue()
            self.next_id = 0
            self.replies = {}
            self.sent = []

        def _send(self, msg):
            self.sent.append(msg)

    fake = FakeStudio()
    first = fake._submit("tools/call", {"name": "a"})
    second = fake._submit("tools/call", {"name": "b"})
    ok("two submits get two ids", first != second, f"{first} vs {second}")
    # OUT OF ORDER on purpose: the second request answers first.
    fake.lines.put(json.dumps({"jsonrpc": "2.0", "id": second, "result": {"content": [{"text": "B"}]}}))
    fake.lines.put(json.dumps({"jsonrpc": "2.0", "id": first, "result": {"content": [{"text": "A"}]}}))
    # queue.Empty, not an assertion, is how a transport that DROPS the other reply fails here
    # (that is what the pre-Task-50 loop did), so it is caught and named rather than left to end
    # the selftest in a traceback -- a harness fault is a reported failure, never a stack (rule 6).
    try:
        got_first = fake._await(first, timeout=1)
        got_second = fake._await(second, timeout=1)
    except queue.Empty:
        ok("a reply is never dropped while another request is in flight", False,
           "one of the two replies was thrown away")
        got_first = got_second = {"content": [{"text": "<lost>"}]}
    ok("the first request gets its own reply", got_first["content"][0]["text"] == "A", repr(got_first))
    ok("the second request gets its own reply, delivered first",
       got_second["content"][0]["text"] == "B", repr(got_second))
    ok("nothing is left behind", not fake.replies, repr(fake.replies))

    # 6. An error reply raises for THAT request only.
    fake = FakeStudio()
    bad = fake._submit("tools/call", {"name": "boom"})
    good = fake._submit("tools/call", {"name": "fine"})
    fake.lines.put(json.dumps({"jsonrpc": "2.0", "id": bad, "error": {"message": "no"}}))
    fake.lines.put(json.dumps({"jsonrpc": "2.0", "id": good, "result": {"content": []}}))
    try:
        fake._await(bad, timeout=1)
        ok("an error reply raises", False)
    except RuntimeError:
        ok("an error reply raises", True)
    fake._await(good, timeout=1)  # raises if the error ate this one

    # 7. send_input_many submits one call per target, keeps target order, and reports per target.
    class InputStudio(FakeStudio):
        def __init__(self, fail_for=()):
            FakeStudio.__init__(self)
            self.fail_for = set(fail_for)

        def _await(self, request_id, timeout=120):
            name = self.sent[request_id - 1]["params"]["arguments"].get("studio_id")
            if name in self.fail_for:
                return {"isError": True, "content": [{"text": "refused"}]}
            return {"content": [{"text": "ok"}]}

    inputs = InputStudio()
    out = inputs.send_input_many("keyboard", [{"action": "keyPress", "key_code": "R"}], ["one", "two"])
    ok("one call per target", len(inputs.sent) == 2, str(len(inputs.sent)))
    ok("every target is reported", list(out) == ["one", "two"], repr(list(out)))
    ok("no failure is invented", all(v is None for v in out.values()), repr(out))
    ok("the keyboard tool is used for keyboard",
       all(m["params"]["name"] == "user_keyboard_input" for m in inputs.sent),
       repr([m["params"]["name"] for m in inputs.sent]))
    ok("the batch reaches every target unchanged",
       all(m["params"]["arguments"]["actions"] == [{"action": "keyPress", "key_code": "R"}]
           for m in inputs.sent), repr(inputs.sent))

    inputs = InputStudio(fail_for=["two"])
    out = inputs.send_input_many("mouse", [{"action": "moveTo", "x": 1, "y": 2}], ["one", "two"])
    ok("a refusal is reported against ITS target and nothing else",
       out["one"] is None and isinstance(out["two"], RuntimeError), repr(out))
    ok("the mouse tool is used for mouse",
       all(m["params"]["name"] == "user_mouse_input" for m in inputs.sent),
       repr([m["params"]["name"] for m in inputs.sent]))

    # 8. A single target is one submit and one await -- the one-player `test` path.
    inputs = InputStudio()
    out = inputs.send_input_many("keyboard", [{"action": "keyPress", "key_code": "R"}], [None])
    ok("one target means one call", len(inputs.sent) == 1, str(len(inputs.sent)))
    ok("a target of None names no studio_id",
       "studio_id" not in inputs.sent[0]["params"]["arguments"], repr(inputs.sent[0]))
    ok("a single target is reported like any other", out == {None: None}, repr(out))

    # 9. The scenario file the replay is made of still parses and still refuses what it refused.
    if os.path.exists(SCENARIO_FILE):
        data = load_scenarios()
        gaps = sum((step.get("ms") or 0) for scenario in data["scenarios"]
                   for step in scenario.get("steps", []) if step.get("device") == "wait") / 1000.0
        batches = sum(len([b for b in scenario_batches(scenario.get("steps", [])) if b[0] != "wait"])
                      for scenario in data["scenarios"])
        print(f"[harness] selftest: the scenario file replays {batches} batch(es) "
              f"and {gaps:.1f} s of its own gaps")

    for line in failures:
        print("[harness] selftest: " + line)
    if failures:
        print(f"[harness] selftest FAIL: {len(failures)} case(s) wrong")
        return 1
    print("[harness] selftest PASS: wait_for_each overlaps and still bounds every subject; "
          "replies are keyed by id; send_input_many is one call per target")
    return 0


def parse_vector(text):
    """x,y,z as three floats. A bad argument exits with the usage line like its neighbours in main,
    rather than raising a ValueError AFTER Studio has already been spawned (6a(f))."""
    try:
        parts = [float(v) for v in text.replace(" ", "").split(",")]
    except ValueError:
        parts = []
    if len(parts) != 3:
        sys.exit(f"expected a position as x,y,z; got {text!r}")
    return parts


def main(argv):
    if len(argv) < 2 or argv[1] not in (
            "test", "test2", "selftest", "state", "console", "stop", "manifest", "capture",
            "studios"):
        sys.exit(__doc__)
    if argv[1] != "capture" and len(argv) != 2:
        sys.exit(__doc__)
    if argv[1] == "capture" and not 3 <= len(argv) <= 6:
        sys.exit("usage: python tools/studio_mcp.py capture <name> [camera x,y,z] [look-at x,y,z] "
                 "[edit|server|client|client:<PlayerName>]")
    if argv[1] == "selftest":
        # No Studio, no network, no place: pure helpers only, so CI can run it.
        return selftest()
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
            # The trailing argument is a ROLE, not a position: "capture tied client:Player2".
            rest = list(argv[3:])
            role = None
            if rest and not re.fullmatch(r"[-0-9eE., ]+", rest[-1]):
                role = rest.pop()
            camera = parse_vector(rest[0]) if len(rest) > 0 else None
            look_at = parse_vector(rest[1]) if len(rest) > 1 else None
            if (camera is None) != (look_at is None):
                sys.exit("give both a camera and a look-at position, or neither")
            studio_id, why = studio_for_role(studio, role)
            if studio_id is None:
                print(f"[capture] {why}")
                return 1
            saved, text = studio.capture(path, camera, look_at, studio_id=studio_id)
            if not saved:
                print(f"[capture] no image came back: {text}")
                return 1
            print(f"[capture] wrote {os.path.relpath(saved, REPO)} "
                  f"(mode: {studio.mode(studio_id=studio_id)}, studio {studio_id[:8]}"
                  f"{', role ' + role if role else ''}). "
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
