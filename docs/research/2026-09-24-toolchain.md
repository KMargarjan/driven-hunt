# Dev toolchain: sync, packages, tests, Studio automation

Date: 2026-09-24 · Author: Builder · Task 1 (round 2 revision after Reviewer FAIL) · Maintenance data from the GitHub API on this date.

## What it must do

1. Keep code on disk, under git, and get it into the Driven Hunt DEV place live while Studio is open.
2. Pin tool versions so every machine and agent runs the same binaries.
3. Install third-party Luau packages without vendoring them into git.
4. Run unit tests inside a real Roblox runtime (Studio Play), with a readable pass/fail line.
5. Let an agent start and stop Play and read Output without a human clicking, so the player's path
   can be checked (rule 6).
6. Prove that the code under test is the code on disk, in the DEV place, and that the test result
   belongs to this run.
7. Lint, format-check and build on every push and PR (CI). Fail on any error.
8. Keep Karen's own playtests free of test runs.

## Sources

| # | Source | Licence | Maintenance (2026-09-24) | Good | Bad |
|---|---|---|---|---|---|
| 1 | [Rojo](https://github.com/rojo-rbx/rojo) | MPL-2.0 | Active. v7.7.0, 2026-07-02 | De facto standard. Official Studio plugin. `build`, `serve` and `sourcemap` for Luau LSP. | Sync is one-way (disk → Studio). Connect is a manual click. |
| 2 | [Argon](https://github.com/argon-rbx/argon) | Apache-2.0 | Active. 2.0.29, 2026-05-19 | Two-way sync. Reads Rojo-style projects. | Smaller community. Two-way sync weakens "disk is the single source". |
| 3 | [Rokit](https://github.com/rojo-rbx/rokit) | MIT | Active. v1.2.0, 2025-09-30 | Fast. Reads Aftman and Foreman manifests. Per-project `rokit.toml`. | Newer than Foreman. Needs a `trust` step per tool. |
| 4 | [Aftman](https://github.com/LPGhatguy/aftman) | MIT | **Archived** | Was the common choice. | Archived; Rokit is its successor. |
| 5 | [Foreman](https://github.com/Roblox/foreman) | MIT | Active. v1.7.0, 2026-05-01 | Maintained by Roblox. | Slower. Global-first config. |
| 6 | [Wally](https://github.com/UpliftGames/wally) | MPL-2.0 | Maintained. Last release v0.3.2, 2023-06. Repo active 2026-01 | Largest Roblox package index. Dev-dependency realm. | Release cadence is slow. |
| 7 | [pesde](https://github.com/pesde-pkg/pesde) | MIT | Active. v0.7.4, 2026-09-09 | Modern. Supports Lune and Luau targets. | Smaller index. TestEZ is not a first-class package there. |
| 8 | [TestEZ](https://github.com/Roblox/testez) ([docs](https://roblox.github.io/testez/)) | Apache-2.0 | **Archived** (read-only). Last release v0.4.1 on Wally | Simple BDD API. Runs anywhere Roblox runs. Stable, needs no changes. | No upstream fixes. Roblox moved to Jest-Lua internally. |
| 9 | [Jest-Lua](https://github.com/jsdotlua/jest-lua) | MIT | Low activity. v3.10.0, 2024-12 | Jest API, mocks, snapshots. | Heavier. Needs FFlag or runner setup. |
| 10 | [run-in-roblox](https://github.com/rojo-rbx/run-in-roblox) | MIT | Stale. v0.3.0, 2020 | Ran a script in Studio from the CLI. | Unmaintained. Runs in Edit mode, not the player's path. |
| 11 | [studio-rust-mcp-server](https://github.com/Roblox/studio-rust-mcp-server) | MIT | **Archived** 2026-04 (final "END" release) | Proved the approach: an MCP bridge to Studio. | Superseded by the MCP server built into Studio. |
| 12 | Roblox Studio built-in MCP server (`StudioMCP.exe`, ships with Studio; Assistant settings → MCP server) | Roblox proprietary (part of Studio) | Current with Studio 0.740 | Real Play mode: `start_stop_play`, `get_console_output`, `execute_luau` per DataModel, `screen_capture`. No plugin install. | Cannot click plugin UI (such as Rojo Connect). The API is not versioned by us. |
| 13 | [StyLua](https://github.com/JohnnyMorganz/StyLua) | MPL-2.0 | Active. v2.5.2, 2026-05-16 | The Luau formatter everyone uses. `--check` for CI. | Opinionated. Few knobs. |
| 14 | [selene](https://github.com/Kampfkarren/selene) | MPL-2.0 | Active. 0.31.0, 2026-05-21 | Roblox std, custom std files (TestEZ globals). Exits non-zero on warnings too. | Downloads the Roblox std at runtime (unpinned). |
| 15 | [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) | MIT | Active. 1.70.0, 2026-09-20 | Type checking and `analyze` for CI. | Needs a sourcemap and type definitions set up (Task 3). |
| 16 | [setup-rokit](https://github.com/CompeyDev/setup-rokit) | MIT | Active. v0.2.1, 2026-05-06 | Installs `rokit.toml` tools in GitHub Actions. | Small project. Installs the latest Rokit itself (not pinned). |

## Pattern adopted and why

> **Current behaviour is described only in the `tools/studio_mcp.py` docstring** (single source of truth
> since round 4). The sections below are the decision record, as dated. Lines marked *(superseded)* no
> longer describe the code.


- **Sync: Rojo 7.7.0** (source 1). It is the standard, the Rojo plugin was already installed, and
  one-way sync enforces rule 3: disk is the only writer for the Rojo-owned services. Argon was
  rejected because two-way sync lets Studio edits write back, which breaks single ownership.
- **Tool pinning: Rokit** (source 3). Aftman is archived. Foreman works but is slower and global-first.
  Exact versions: Rojo, Wally, StyLua, selene and luau-lsp in `rokit.toml`, TestEZ in `wally.lock`.
  The Rojo plugin is built from the pinned CLI (`rojo plugin install`). **Correction to round 1:** I
  said the toolchain was "pinned in rokit.toml, wally.toml". Not true of Rokit itself, the Creator
  Store Rojo plugin then in use (auto-updating), Studio, or selene's Roblox std. `wally.toml` alone
  allows any 0.4.x. The full table is in CLAUDE.md.
- **Lint/format: selene + StyLua** (sources 13, 14) in CI through setup-rokit (source 16), with the same
  pinned versions as local.
- **Packages: Wally** (source 6). TestEZ is published there and Rojo's docs and examples use it.
  Revisit pesde if Wally stalls.
- **Tests: TestEZ 0.4.1** (source 8), as Karen specified. It is archived, but it is small, feature-complete
  and has no network or runtime dependencies. Its archive status is a known risk. If we need mocks or
  snapshots, the upgrade path is Jest-Lua (source 9), which shares the describe/it/expect vocabulary.
- **Runner:** `ServerScriptService.TestRunner` pcall-requires every `*.spec` (TestEZ's
  `TestBootstrap.lua:57` requires them unprotected), then calls
  `TestBootstrap:run({ServerStorage.Tests}, TextReporter)`, all under pcall. Status: `ERROR` on any
  load or run exception; `FAIL` if failures > 0, `#results.errors` > 0, or passes == 0; else `PASS`.
  It prints `[tests] ...` and writes a JSON report (token, placeId, specCount, counts, status) to the *(superseded: report fields and location, see the docstring)*
  `ServerStorage.TestReport` attribute. Tests run in the real Play server: the player's path (rule 6).
- **Gate + provenance (invented; nothing found to borrow):** the harness writes
  `<16 hex>:<unix time>` to git-ignored `tests/sync-token.txt`. Rojo syncs it to
  `ServerStorage.TestSyncToken` *(superseded: `ReplicatedStorage.TestSyncToken` since round 4)* (optional path). The runner runs only if the token is under 120 s
  old. The harness then checks:
  - the token reached Studio (so Rojo is live)
  - every script from `rojo sourcemap` has a Studio Source byte-identical to disk *(superseded: every synced instance and file, round 3/4)*
  - the report echoes this run's token and the PlaceId from `servePlaceIds`
  - the runner's spec count equals the spec files on disk *(superseded: matched by name, round 3)*

  It clears the token afterwards. Reason for inventing: TestEZ and Rojo have no run-provenance
  mechanism, and the MCP server has no "run tests" tool.
- **Automation: Studio built-in MCP** (source 12), through `tools/studio_mcp.py`, a small stdio
  JSON-RPC client. Chosen over run-in-roblox (stale, Edit mode only) and the archived Rust MCP server.
  **Invented:** the ~280-line client script *(superseded: ~600 lines after round 4)*. Reason: no maintained CLI MCP client existed in the repo's
  toolchain, and pulling in an MCP SDK for 4 calls is heavier than the script. Round 2: it exposes only
  `test`, `state`, `console` and `stop`, and sends only constant read-only Luau queries. It refuses unless
  Studio is in Edit mode.

## Numeric targets

| Target | Value | Measured 2026-09-24 |
|---|---|---|
| Disk save → change visible in Studio (Rojo connected) | ≤ 2 s | New spec file appeared and was removed within the 2 s wait: pass |
| Play → `[tests]` line in Output | ≤ 10 s | Under 5 s: pass |
| `python tools/studio_mcp.py test` total wall time | ≤ 30 s | 9 s (round 2, with all checks): pass |
| Failing spec makes the run exit non-zero | 100% | A deliberate `expect(1).to.equal(2)` gave `[tests] FAIL: 2 passed, 1 failed` and exit 1. Removing it gave PASS and exit 0: pass |
| Back-to-back runs give the correct result | 3/3 | 3/3 after the fix below: pass |
| Negative cases caught (round 2) | 6/6 | All caught: failing assertion (FAIL, exit 1); syntax-error spec (`[tests] ERROR`, exit 1); spec throws on load (`ERROR`, exit 1); Studio in Play (REFUSED, exit 2); normal playtest (no tests ran); stale token (no tests ran) |
| Negative cases caught (round 3) | 15/15 | 12 harness cases, all exit 1: itSKIP, describeSKIP, SKIP(), itFOCUS, describeFOCUS, FOCUS(), spec in `src/shared` (synced, not run), spec in `tools/` (not synced), `.json` synced file (cannot compare), failing assertion, throws on load, ghost spec only in Studio. Plus 3 gate cases: normal playtest and stale token run no tests; Play refused with exit 2 |
| CI fails on build, lint or format error | 100% | Build: the missing `build/` dir failed [run 36031124887](https://github.com/KMargarjan/driven-hunt/actions/runs/36031124887). Lint + format: probe commit 202e09e failed both steps in [run 36031342566](https://github.com/KMargarjan/driven-hunt/actions/runs/36031342566). The revert went green: pass |
| Tests executing in live games | 0 | Guarded by `RunService:IsStudio()` (not verified in a live server) |

## Harness bug found and fixed (rule 6)

The first `studio_mcp.py test` read the result from the Output log by diffing it against the log
before Play. Studio **clears Output on each Play**, so the diff was empty whenever two runs printed
identical output, and the second run timed out. The same design could also report the previous
run's result as a false PASS. Fix: TestRunner also writes the summary to the
`ServerStorage` attribute `TestSummary` *(superseded: the attribute is now `TestReport`, a JSON report; see the docstring)*, and the harness polls it in the **Server** DataModel, which
only exists for the current play session.

## Round 3 revision (Reviewer FAIL on PR #1)

- **Skips and focus fail the run.** TestEZ counts `SKIP()`, `itSKIP` and `describeSKIP`, and every test
  left out by `FOCUS()`, `itFOCUS` or `describeFOCUS`, in `skippedCount`. The runner reports FAIL when
  `skippedCount > 0`, and the harness checks it again.
- **Specs are found repo-wide and matched by name.** The harness collects every `*.spec.*` file from
  `git ls-files --cached --others --exclude-standard`. That is the repo as git sees it: git-ignored
  `DevPackages/` holds TestEZ's own 29 specs, which are not ours. Each file is mapped to its Studio
  instance through the sourcemap. It must be synced, and the runner's list of spec full names must
  equal that set exactly. A count comparison could hide one missing spec plus one extra.
- **Every synced file is compared, or the run fails.** `rojo sourcemap --include-non-scripts` lists all
  synced instances. Each must exist in Studio with the same ClassName:
  - scripts: Source
  - `.txt`: StringValue.Value
  - `.project.json`: structure only (the instance checks)

  Any other file type fails as "cannot compare" until a comparison is added.
- **Rojo deletes unknown instances on Connect, not during live sync** (probe test, CLAUDE.md). The
  Rojo-owned containers are disk-only by design (rule 3). The deletion must be documented, because a
  Studio-made instance seems safe until the next Connect.

## Round 4 revision (Task 5, architecture audit-001 M1–M4)

- **All script-capable containers are on disk (M1).** Added StarterGui, StarterPack,
  StarterCharacterScripts and ReplicatedFirst. All four were verified empty first. Workspace and
  ServerStorage stay Studio-edited for non-script content. A new harness query lists every
  LuaSourceContainer in the DataModel and fails on any the sourcemap does not account for, including
  extra same-named copies (partly audit R2).
- **Non-script files (M2).** `.model.json` and `.meta.json` are compared: ClassName, plain JSON
  properties and attributes, children. Typed values fail as "cannot compare" until needed.
  `.rbxm`/`.rbxmx` are banned (harness + CI): a binary blob can't be reviewed or compared, and
  dropping it is cheaper than supporting it (audit-001).
- **Client path (M3).** TestKit (one implementation) is shared by a server runner and a client runner.
  Client specs run in the real player client, and the harness reads the client report from the
  Client DataModel (StudioMCP `execute_luau` accepts `Client`, verified 2026-09-24). Real input
  (StudioMCP `user_keyboard_input` / `user_mouse_input`) and play-time screenshots (`screen_capture`
  is edit-time only) are not wired yet. They are blocking Tasks 6 and 7. To reach the client, test
  code moved to ReplicatedStorage and now replicates to clients (accepted; stripped at publish, Task 2).
- **Commit-bound evidence (M4).** The final line carries the full HEAD sha and clean/dirty state. A
  dirty-tree PASS exits 3.
- **Harness faults found and fixed this round (rule 6):**
  - JSON embedded in a Luau long string broke when the JSON ended in `]`. Now wrapped in newlines, and
    non-ASCII names survive (audit L3).
  - StudioMCP truncates tool results at ~100 KB. The Source comparison is now batched (8 instances per
    query), and a truncated result fails loudly.
  - A harness exception printed a traceback. It is now a `[harness] FAIL: harness error` line.
- **Rojo 7.7.0 crash** when a watched folder disappears (open issues rojo-rbx/rojo#1309, #1321).
  The harness now says whether `rojo serve` is down when the token fails to sync.

| Target | Value | Measured 2026-09-24 |
|---|---|---|
| Round-4 cases caught | 8/8 | valid `.model.json` and `.meta.json` pass. Caught: `.rbxm` banned, typed property, `ignoreUnknownInstances`, failing client spec, script in Workspace, attribute changed in Studio |
| Round-3 regression matrix | 12/12 | all still exit 1 after the restructure |
| Dirty tree is flagged, not passed | exit 3 | Both positive cases ran on a dirty tree: `PASS ... (DIRTY TREE (14 paths) - NOT valid evidence)`, exit 3. The clean-tree run at 20e136b gave exit 0 |
| Reviewer-agent findings (review loop) | 8/8 fixed | 2 blocking (ignored files, DevPackages not tied to the commit), 6 should-fix. See the TASKS.md review log |

## Addendum, 2026-09-25 (Task 6): driving real player input, and saving screenshots

An addendum rather than a new note (Director's call): this is more of an already-researched tool,
StudioMCP, not a new system.

### What it must do

Replay a player's real input — a key, a mouse button, a gap between them — into a running Play
session, so a client spec can assert on what the engine delivered. `docs/design/shotgun.md` §13.3
sets the bar: a key down and up, a mouse button down and up, and two inputs in sequence with an
observable gap. Everything the shotgun's client code will do starts as one of those three.

### Sources

1. **StudioMCP's own tool schemas** (`user_keyboard_input`, `user_mouse_input`, `screen_capture`),
   read live from the running server with `tools/list`. Ships with Roblox Studio 0.740.x; no licence
   of its own, and no public documentation of these three tools that I could find — the schema *is*
   the documentation. Good: an ordered `actions` list per call, with `wait` steps in milliseconds, so
   one call keeps its own order and spacing. Bad: `datamodel_type` is `Client`-only, so nothing can
   be driven in Edit mode, and there is no acknowledgement that the game *received* anything — the
   only proof is what the client records.
2. **`ContextActionService`** <https://create.roblox.com/docs/reference/engine/classes/ContextActionService>
   (Roblox, maintained). Good: `BindAction` takes key codes *and* `Enum.UserInputType.MouseButton1`
   in one binding, and the handler is given the `InputObject`, so one listener covers both devices;
   it is also what the shotgun design binds, so the test exercises the production path. Bad: it
   cannot bind mouse movement at all.
3. **`UserInputService`** <https://create.roblox.com/docs/reference/engine/classes/UserInputService>
   (Roblox, maintained). Good: `InputBegan`/`InputEnded`/`InputChanged` see everything, including
   `MouseMovement`. Bad: it sees everything — including the window-focus event that the very first
   run recorded, which is why the spec matches its expected sequence *in order* and ignores the rest.
4. **TestEZ** <https://roblox.github.io/testez/> (Apache-2.0, archived upstream), already adopted.

### Pattern adopted, and why

**Record-then-assert with a ready handshake**, borrowed from the way the harness already gates the
runners with a token rather than inventing a second channel:

- the client spec binds its listeners at *require* time and publishes the run's token on
  `LocalPlayer` as an attribute;
- the harness polls that attribute and replays only when it carries **this** run's token;
- the spec waits for the events and asserts over the recorded log.

The first version had no handshake in mind at all, and the first run proved why it was needed for a
different reason than expected: the replay went out and **nothing** arrived, because the attribute
query asked for an attribute whose name included the JSON quote characters. A handshake that fails
loudly ("the client bound its listeners and published this run's token") turned a silent 0-of-7
match into a one-line diagnosis.

The scenario lives in **one file read by both sides** — `tests/client/input_scenarios.txt`, JSON in a
`.txt` so Rojo makes it a `StringValue` the harness already compares byte-for-byte. So the client
provably reads the file on disk, and no new Rojo mapping is needed (a `default.project.json` change
needs a Rojo restart, which needs Karen's Connect click).

### Numeric targets

| Target | Value | Measured 2026-09-25 |
|---|---|---|
| Steps a scenario can send | the whole file in one pass | 6 steps (2 keyboard batches, 1 mouse batch, 1 gap) sent per run |
| Ready handshake | < 20 s, or the run fails that check | the attribute was there on the first poll (~0.5 s) |
| Replayed gap, as seen by the client | ≥ 0.6 × the scenario's `ms`, and longer than any unwaited gap | 700 ms asked; the spec's gap assertion passes every run |
| Client assertions unlocked | 7 | `input_driving.spec`: 11 client assertions in total with `client_env` |
| Harness checks added | 2 | "[input] the client bound its listeners…", "[input] replayed every step…" |

### What this does **not** do

Touch and gamepad; `textInput`; holds measured in frames; input aimed at an instance
(StudioMCP's `instance_path`); anything after the client's report is written. A scenario also cannot
assert anything itself — it describes input, and the spec owns the expectations it derives from it.

### Screenshots (Task 7)

`Studio._call` joined the text blocks of a tool result and dropped the image, so a capture could
never be saved. `Studio.capture()` reads the image block and writes it to `.screenshots/`
(git-ignored); `python tools/studio_mcp.py capture <name> [camera] [look-at]` is the command.
Verified on 2026-09-25 in **Edit** (empty grey: since Task 22 `Workspace` holds only `Camera` and
`Terrain`, and the arena is built at run time — so that is the correct picture) and during **Play**
(the 400×400 arena plate, rendering as a full square).

## Addendum, 2026-09-25 (Task 30): two players, staging a shot, and two harness bugs

### 1. Can StudioMCP run a test with 2+ players? No — and here is the evidence, not an opinion

`docs/design/drive.md` §12.6 asked for one command's output. I asked the server itself instead: the
MCP `tools/list` response is the authoritative description of every tool StudioMCP exposes, and it
answers the question outright. StudioMCP exposes **28 tools**. The four that matter:

| Tool | What its schema says |
|---|---|
| `start_stop_play` | `{is_start: boolean, studio_id: string}` — **no player count**. Studio's "Clients and Servers" local test cannot be asked for from here |
| `execute_luau` | `datamodel_type` is an enum of exactly `Edit`, `Client`, `Server` — **no index**, so a second client inside one Studio is not addressable |
| `user_mouse_input` / `user_keyboard_input` | the same three-value `datamodel_type` |
| `list_roblox_studios` | returns `{id, name}` per connected Studio: *"Several instances are commonly open at once, so every tool call must include a `studio_id`"* |

So a 2-player run is **not possible today**, exactly as the design predicted. But the design did not
have the last row, and it changes what "closed" means: **every** tool takes a `studio_id`, and a
local multi-client test starts extra Studio *processes*. If those register with StudioMCP, they are
addressable as separate `studio_id`s and a 2-player harness becomes a real possibility rather than a
dead end. Whether they register cannot be answered without a human starting such a test, because
`start_stop_play` cannot start one.

**What was added:** `python tools/studio_mcp.py studios`, one read-only command that prints the
listing. With one Studio open it prints exactly one entry:

```
{"studios":[{"id":"015c8c47-...","name":"Driven Hunt DEV (placeId: 136410205938347)"}]}
```

`ESCALATE.md` carries the **NEEDS KAREN** entry with the exact clicks: start a 2-client local test,
run that one command, and the answer is in the output. Nothing else in this repo depends on it.

### 2. Staging a scenario: placing the player and pointing the camera (hit-zones design §14 D)

A replayed click fires wherever the camera already looks, and the harness cannot aim — the camera's
yaw is mouse-driven and under `MouseBehavior = LockCenter` StudioMCP's `moveTo` delivers no usable
delta. So there had never been an end-to-end "shoot the thing in front of you" test. A scenario may
now carry a `stage` block; the format and the rules are in the `tools/studio_mcp.py` docstring. Two
things are worth keeping here:

- **`execute_luau` has its own module cache, measured twice.** During Play, a `require()` of
  `PlayerScripts.Camera` through `execute_luau` reports `mode=Loading frames=0` while the real camera
  is `Scriptable` at FOV 70 and the live module has run thousands of frames. The harness therefore
  **cannot call a live module's functions at all** — only Instances are shared. That is why the
  camera owner exposes `LookAtRequest`, a `BindableFunction`, and why the stage invokes it rather
  than calling `Camera.lookAt`. The owner still does the writing: `workspace.CurrentCamera` has one
  writer in the repo, and the client spec asserts the foreign-write counter does not move across a
  staged aim.
- **Aiming the pivot is not aiming the camera.** The camera sits 12 studs behind the pivot and 2.2
  to the right, so the angles that point the *character* at a target leave the camera 3.97° off at 20
  studs — wide enough to miss a boar. `Mode.anglesToward` iterates (take the camera position the
  current angles give, aim from there, repeat): six passes land inside 0.02°, and it is pure, so the
  server spec checks it with no client.

### 3. Two harness bugs this task found and fixed (rule 6)

- **A batch of eight big files truncated Studio's reply and failed the whole run** as
  `JSONDecodeError: Unterminated string ... char 94110`. StudioMCP cuts a tool result at roughly
  100 KB, and each node's reply carries the file's whole Source. The comparison now **splits a batch
  whose reply will not parse** and retries, down to a single instance, which then fails loudly with
  its name and the size.
- **A `%` in a templated query is a format placeholder.** `QUERY_STAGE` ended with a `string.format`
  whose `%s` collided with the `%` templating, so every stage raised `TypeError` in Python before
  Studio saw it. What makes this worth writing down is what happened next: **the run went green
  anyway, twice** — a stray click from an earlier scenario hit the wandering boar and produced the
  hit marker the new spec was waiting for. The stage's own check caught it; the spec did not. The
  spec now counts only the markers that arrive **after** the stage, so the shot it asserts is the
  shot it fired.
