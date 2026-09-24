# Architecture audit 001

Date: 2026-09-24 · Author: Architect · Repo state: `bc2e8f8` on `task-1-review-fixes` (clean tree)

## Scope

The repo still has no game code. `src/` holds one boot-marker script and two `.gitkeep` files. So this
audit covers the scaffolding every future system will sit on:

- the Rojo project
- the test runner and harness
- CI
- the owner table
- the docs

These findings matter because every game system will inherit them.

Method:
- read every tracked file
- ran `rojo sourcemap --include-non-scripts` on the repo (31 nodes)
- ran one scratch-project experiment outside the repo (M2)

I changed nothing in `src/`, `tests/` or `tools/`.

## Verdict

The toolchain and test gate are unusually well built for a project on day one. Four structural holes
should be closed before the first game task, and each one gets harder to close once code exists.
None of them is a bug in today's code. Each one is a place where the **next** system would get a
second, unseen writer, or where a failure would pass unnoticed.

---

## Must fix now (before the first game task)

### M1. Game code has nowhere on disk to live except three containers

**Evidence**
- `default.project.json:4-31` maps only `ServerScriptService`, `ReplicatedStorage`,
  `StarterPlayer.StarterPlayerScripts` and parts of `ServerStorage`. The sourcemap confirms nothing else.
- `CLAUDE.md:73-74`: "Everything outside those Rojo-owned paths (Workspace, Lighting, and so on) is
  edited in Studio and saved with the place."
- Unmapped script-bearing containers:
  - `StarterGui` (every ScreenGui and its LocalScripts)
  - `StarterPack` (Tools, which a hunting game will almost certainly have)
  - `StarterPlayer.StarterCharacterScripts`
  - `ReplicatedFirst`
  - any Script inside `Workspace`

**Why it matters**
The first weapon Tool, HUD or character script will be built in Studio and saved only in the place
file. It gets:
- no git history
- no PR diff for the Reviewer
- no selene/StyLua (`ci.yml:31,35` lint `src tests` only)
- no harness Source check (`studio_mcp.py:190-221` checks only sourcemap nodes)
- no row in the owner table's *Location* column

A LocalScript inside a Tool that sets the mouse icon, running next to one in `src/client` that does the
same, is exactly the three-cursor-writers failure. Nothing in the repo could see it.

**Fix**
1. Map `StarterGui`, `StarterPack`, `StarterPlayer.StarterCharacterScripts` and `ReplicatedFirst` to
   folders under `src/`.
2. State the rule: *no `LuaSourceContainer` exists outside a Rojo-owned path.*
3. Enforce it with one new constant, read-only harness query that lists every script in the
   DataModel whose path is not in the sourcemap, and fails if it finds any.

This also answers "anything inside a Tool that should be player-scope": Tools become files. A Tool's
scripts are then reviewable and can be required to call a player-scope module, not own state
themselves.

**Cost and precondition**
Once mapped, Rojo deletes Studio-made children of those containers on Connect (`CLAUDE.md:83-102`).
The 18:30 emptiness check (`CLAUDE.md:104-108`) did **not** cover these four containers. Karen, or a
read-only query, must confirm they are empty in the DEV place before the mapping lands.

### M2. The harness rejects the file types CLAUDE.md tells the Builder to use

**Evidence**
- `CLAUDE.md:98-99` says to create non-scripts on disk as "`*.model.json` / `.rbxm`".
- `studio_mcp.py:210-220` compares only `.project.json`, `.luau`/`.lua` and `.txt`. Anything else is
  reported as `cannot compare` and fails the run.
- Scratch experiment (outside the repo, Rojo 7.7.0): a `src/Hit.model.json` (RemoteEvent) and a
  `src/init.meta.json` both appear in the sourcemap's `filePaths`, so both would hit line 220.
- `.rbxm` follows the same code path. I did not test it directly.

**Why it matters**
The first RemoteEvent or folder attribute turns `test` red. The Builder then has three bad choices:
1. create it in Studio, where it is deleted on the next Connect
2. weaken the check
3. stall

**Fix**
Decide the allowed non-script formats before the first remote exists.

- Recommendation: allow `.model.json` and `.meta.json` and add comparisons for them (ClassName plus
  listed properties and attributes).
- **Ban `.rbxm`/`.rbxmx` in Rojo-owned paths.** A binary blob cannot be reviewed in a PR or compared
  by the harness. Removing that format is cheaper than supporting it.
- Correct `CLAUDE.md:98-99` to match.

### M3. There is no test path for client code

**Evidence**
- `TestRunner` is a server `Script` (`default.project.json:8-10`).
- The harness only queries the `Edit` and `Server` DataModels (`studio_mcp.py:258, 265, 285, 312`).
- `src/client/` is empty.

**Why it matters**
Camera, input, cursor and UI are all client-side. Those are the systems that killed the previous
project, and today rule 6 ("test the player's path") cannot be met for any of them. The first client
task will either ship untested or invent a client runner under deadline.

**Fix**
Before the first client task, write `docs/design/client-tests.md` (my job) and decide:
- whether StudioMCP's `execute_luau` accepts a client DataModel (unverified, see below)
- whether a gated client runner mirrors `TestRunner`
- how client and server reports are combined into one PASS

### M4. The pasted PASS line is not tied to a commit

**Evidence**
- `studio_mcp.py:316` prints `[harness] PASS: n/n checks` with no commit SHA and no dirty-tree flag.
- `CLAUDE.md:49` makes that pasted line the test evidence for a PR.
- CI cannot run the tests (`ci.yml:4`).

**Why it matters**
A PASS from an older commit, or from a tree with uncommitted edits, looks identical to a real one. The
Reviewer has no way to tell. That is a silent failure in the one place the process relies on.

**Fix**
Print `git rev-parse HEAD` and whether `git status --porcelain` is empty on the PASS/FAIL line. The
Reviewer checks that SHA against the PR head and rejects a dirty tree.

This is about 5 lines, and it changes what a PASS proves.

---

## Fix before release

### R1. Test code and debug hooks ship with the place, and Task 2's list is incomplete

**Evidence**
These ship with the place, as `CLAUDE.md:167-177` accepts and `TASKS.md:8` logs:
- `TestRunner` (`default.project.json:8-10`)
- `Tests`, `DevPackages` and `TestSyncToken` (`:20-30`)
- the `TestReport` attribute (`TestRunner.server.luau:58`)

Task 2's list **misses** `src/server/SyncCheck.server.luau`:
- it runs in every live server
- it prints `sync ok` (`:5`) and sets an attribute (`:4`) forever
- it is a test fixture sitting in the game source tree
- `README.md:16` relies on its print

**Remove a concept**
SyncCheck and the whole of `sync.spec.luau` duplicate checks the harness already makes:

| The spec asserts | The harness already checks |
|---|---|
| PlaceId (`sync.spec.luau:12-14`) | `studio_mcp.py:259`, `:299` |
| Token delivered (`:16-21`) | `:266`, `:298` |
| Script synced and ran (`:23-33`) | Source byte-compare (`:273`); `TestRunner` itself running proves server scripts execute |

**Fix**
When the first real game spec lands, archive `SyncCheck` and `sync.spec.luau` (rule 7). Until then,
add SyncCheck to Task 2's strip list.

### R2. Instance lookup by name can compare the wrong instance without saying so

**Evidence**
`QUERY_NODES` walks the tree with `FindFirstChild(name)` (`studio_mcp.py:49-50`). If two siblings share
a name, for example a Studio-made copy next to the Rojo one before the next Connect deletes it, the
harness compares whichever comes first.

**Why it matters**
The check can pass while the instance that actually runs is the other one.

**Fix**
Have the query also return the number of siblings with each name, and fail when it is more than 1.

### R3. No type checking

**Evidence**
`luau-lsp` is pinned (`rokit.toml:11`) but not run in CI (`TASKS.md:9`, Task 3).

**Fix**
Task 3 already covers it. Land it early. Cross-system interfaces are where types pay off, and they
don't exist yet.

---

## Log only

- **L1. Docs have already drifted, because the harness is described in four places.** The four places
  are `CLAUDE.md:139-165`, the research note, the harness docstring (`studio_mcp.py:1-19`) and the
  `TASKS.md` review log. Stale lines in `docs/research/2026-09-24-toolchain.md`:
  - `:100-102` names the attribute `TestSummary`. The code uses `TestReport`
    (`TestRunner.server.luau:58`, `studio_mcp.py:42`).
  - `:70` says spec *count*. The code matches by name (`studio_mcp.py:300-305`).
  - `:68` says every *script*. The code checks every instance.
  - `:76` says "~280-line". The file has 341 lines.
  - `docs/research/INDEX.md:7` says "revised round 2". The note has a round-3 section.

  Fix: the docstring becomes the one full description. CLAUDE.md keeps the commands and a pointer. The
  research note keeps decisions and dated measurements, and marks superseded text as superseded.
- **L2. Duplicated constants.**
  - The DEV PlaceId is in `default.project.json:3` and `sync.spec.luau:8`.
  - The token format is in `studio_mcp.py:262`, `TestRunner.server.luau:23` and `sync.spec.luau:20`.

  A change would fail loudly, so this is log only. It goes away with R1.
- **L3. "Constant queries" is not quite true.**
  - `QUERY_NODES` is a template filled with sourcemap names (`studio_mcp.py:199-200`). It is still
    read-only, so the safety claim holds, but `CLAUDE.md:160` should say "constant, or templated with
    JSON-encoded data".
  - `json.dumps` escapes non-ASCII as `\uXXXX`, which Luau string literals do not accept (Luau uses
    `\u{…}`). A non-ASCII file name should break the harness loudly. This is expected behaviour, not
    tested.
- **L4. `ServerScriptService` is fed from two disk roots:** `src/server` and `tests/TestRunner`
  (`default.project.json:7-10`). A game script named `TestRunner` would collide. This goes away if
  Task 2 moves test code out.
- **L5. Test-only globals are allowed in game code.** `selene.toml:2` applies `roblox+testez` to
  `src/` as well as `tests/`, so game code may reference `describe`, `expect` or `SKIP` without a lint
  error. Low risk. A separate std for `tests/` fixes it.
- **L6. The test gate is a 120 s window, not a lock** (`TestRunner.server.luau:15,24`). If the harness
  is hard-killed between `studio_mcp.py:263` and `:290`, the token stays live. A Karen playtest within
  120 s would then run the suite. The risk is bounded and Studio-only.
- **L7. The harness may launch the wrong StudioMCP.exe.** It picks the newest one by mtime
  (`studio_mcp.py:65-69`), not the one belonging to the running Studio. It would fail loudly if they
  mismatch.
- **L8. CI runs twice per PR push**, because it triggers on both `push` and `pull_request`
  (`ci.yml:8-9`). This is noise, not a fault.
- **L9. The owner table mixes delivery with ownership.** `GAME_DESIGN.md:20` lists Rojo as "the only
  writer" of all of ServerScriptService, ReplicatedStorage and StarterPlayerScripts. When Camera gets
  an owner in `src/client`, two rows will claim it.
  - Rename that row "Source delivery (not a runtime owner)".
  - Add `_unassigned_` rows for the systems a hunting game needs before its first line of code:
    Networking/remotes, Persistence (DataStore), Character/movement, Map (Workspace).

## Not verified

- **What is in the DEV place outside Rojo paths.** This covers Workspace, and whether any scripts or
  free-model scripts exist there. The harness has no query for it, and I am read-only. This is the
  most important unknown, and M1's query would answer it.
- **Whether StarterGui, StarterPack, StarterCharacterScripts and ReplicatedFirst are empty** in the
  DEV place (the precondition for M1).
- **Whether StudioMCP's `execute_luau` supports a client DataModel** (M3).
- **`.rbxm` handling in the harness.** I tested `.model.json` and `.meta.json` only (M2).
- **Luau's handling of `\uXXXX`** (L3).
- **PR and CI state.** `gh` is not installed in this shell.
- **The harness itself.** I did not run it. That needs Studio, Rojo Connect, and it is not my role.

## One change before any game code

Map every script-bearing container to disk and make "no script outside a Rojo-owned path" a
harness-enforced check. Today the first Tool, GUI or character script would live only in the place
file: no git, no lint, no review and no owner. That is how the last project ended up with three
cursor writers.
