# CLAUDE.md: Driven Hunt

Roblox game. Code lives on disk and is synced into Studio by Rojo. Place: **Driven Hunt DEV**
(PlaceId 136410205938347, enforced by `servePlaceIds` in `default.project.json`).
Roles: **Builder** implements, **Reviewer** signs off, **Karen** owns the game and playtests.

## Rules

1. **RESEARCH BEFORE IMPLEMENTATION.** For any non-trivial system, first write a note in
   `docs/research/` covering:
   - what the system must do
   - 3+ external sources, named and linked, with licence and maintenance status
   - what each source does well and badly
   - the pattern adopted and why
   - the numeric targets

   Add it to `docs/research/INDEX.md`. Only then write code.
2. **BORROW BEFORE BUILDING.** Inventing something needs a written reason, kept in the research note.
3. **ONE OWNER PER SYSTEM.** Anything drawn, the camera, input, state: exactly one writer, named in
   the *System owners* table in `GAME_DESIGN.md`.
4. **ONE TASK PER ROUND.** Small and testable, then stop. Tasks live in `TASKS.md`.
5. **VISUAL CHANGES NEED A SCREENSHOT** that you inspected yourself.
6. **TEST THE PLAYER'S PATH, not the harness.** Harness faults are bugs: report them.
7. **NEVER DELETE.** Archive with a note (see `backups/README.md`).
8. **REPORT HONESTLY** what you could not verify and what you got wrong.
9. **CODE COMMENTS** carry the pattern name, source links and the research note file.
10. **Nothing reaches Karen until the Reviewer has signed it off.**

## Git workflow: branch + pull request, never push to main

1. `git switch main && git pull`, then `git switch -c task-<n>-<short-name>`. A task that builds on an
   unmerged PR branches from that PR's branch and targets it (a stacked PR).
2. Stage **explicit paths** (`git add <paths>`), then read `git status` and `git diff --cached` before
   every commit. Never commit with a blind `git add -A`: untracked files (another role's docs, for
   example) get swept in. That happened on 2026-09-24 with `docs/architecture/audit-001.md`.
3. Push the branch (`git push -u origin <branch>`) and open a pull request. CI
   (`.github/workflows/ci.yml`) must be green.
4. The Reviewer reviews the PR. Karen merges after sign-off. The Builder never merges and never
   pushes to `main`.
5. Record Karen's playtest feedback in `PLAYTEST.md` in the same PR round.
6. **Stop `rojo serve` before switching branches** (or re-Connect afterwards). A branch switch while
   Rojo is live left Studio out of sync on 2026-09-24 (`ServerStorage.Tests` came out empty). The
   harness catches this, but it wastes a run.

**What is enforced and what is policy.** The GitHub ruleset on `main` *enforces* only two things:
changes arrive through a pull request, and the `Build and lint` CI check passes. It does **not** enforce
Reviewer sign-off (approvals are set to 0, and the Reviewer has no GitHub account), who merges, or
that the Builder never merges. The Builder's credentials could merge a green PR. Those three are
**policy**: rule 10 plus this section. The Builder follows them, and the Reviewer checks them.

## Definition of done

Paste this, filled in, at the end of every task report. Each box is checked, or marked N/A with a reason.

```
- [ ] Tests pass: `python tools/studio_mcp.py test` → paste the final line. It must read
      "[harness] PASS: n/n checks @ <sha> (clean tree)" with <sha> = the PR head commit
- [ ] CI green on the PR (link to the run)
- [ ] Screenshot inspected (rule 5), or N/A: <reason>
- [ ] Docs updated: TASKS.md, GAME_DESIGN.md owners, research note/INDEX, PLAYTEST.md, CLAUDE.md as needed
- [ ] Reviewer signed off (by whom / where), or "pending"
- [ ] Commit + PR link
```

## Layout

Every container **where game scripts belong** is Rojo-owned and fed from disk: the table below,
including all of ServerStorage. Workspace, Lighting and the other services are **not** mapped. They
hold Studio-edited, non-script content, and scripts there are **forbidden**, not mapped.
**Nothing script-like (Script, LocalScript, ModuleScript) is ever created in Studio.** The harness
fails if a script exists anywhere Rojo does not manage.

| Disk | Studio | Notes |
|---|---|---|
| `src/server/` | `ServerScriptService` | Rojo-owned |
| `src/shared/` | `ReplicatedStorage` | Rojo-owned. Modules shared by server and client |
| `src/client/` | `StarterPlayer.StarterPlayerScripts` | Rojo-owned |
| `src/startercharacter/` | `StarterPlayer.StarterCharacterScripts` | Rojo-owned |
| `src/startergui/` | `StarterGui` | Rojo-owned. A ScreenGui is a folder with `init.meta.json` (`"className": "ScreenGui"`) holding `.model.json` UI and `.client.luau` scripts |
| `src/starterpack/` | `StarterPack` | Rojo-owned. A Tool is a folder with `init.meta.json` (`"className": "Tool"`) holding its parts (`.model.json`) and scripts (`.luau`) |
| `src/replicatedfirst/` | `ReplicatedFirst` | Rojo-owned |
| `src/serverstorage/` | `ServerStorage` | Rojo-owned. Server-only templates (for example animal models with AI scripts), never replicated to clients |
| `tests/server/` | `ServerStorage.Tests` | Server TestEZ specs, `*.spec.luau` |
| `tests/client/` | `ReplicatedStorage.ClientTests` | Client TestEZ specs (run in the player's client) |
| `tests/TestKit.luau` | `ReplicatedStorage.TestKit` | The one test gate and runner implementation |
| `tests/TestRunner.server.luau` | `ServerScriptService.TestRunner` | Server runner |
| `tests/ClientTestRunner.client.luau` | `StarterPlayerScripts.ClientTestRunner` | Client runner |
| `tests/sync-token.txt` (git-ignored, optional) | `ReplicatedStorage.TestSyncToken` | Written only by the harness |
| `DevPackages/` (git-ignored, optional) | `ReplicatedStorage.DevPackages` | TestEZ, from `wally install` |
| `assets/source/`, `assets/ready/` | none | Raw vs import-ready art |
| `backups/` | none | Archived files plus notes |
| `docs/` | none | `research/` (notes plus INDEX), `architecture/` (Architect audits) |
| `tools/` | none | Test harness |

Workspace (the map), Lighting, Terrain and other non-script content are edited in Studio and saved
with the place. They must contain no scripts.

### File types in Rojo-owned paths

| File | Becomes | Harness compares |
|---|---|---|
| `Name.server.luau` / `Name.client.luau` / `Name.luau` | Script / LocalScript / ModuleScript | Source |
| folder with `init.luau` (or `init.server.luau` / `init.client.luau`) | that script, with children | Source |
| `Name.model.json` | any non-script instance tree (RemoteEvent, Frame, Part…). **No Script/LocalScript/ModuleScript inside**: refused, because scripts must be linted `.luau` files | ClassName, properties, attributes, children |
| `Name.meta.json` | properties and attributes of the script `Name.*.luau` | properties, attributes |
| `init.meta.json` | properties, attributes and `className` of the folder it sits in | properties, attributes |
| nested `*.project.json`, `$properties`/`$attributes` in `default.project.json` | refused (not compared). Use `.meta.json` | none |
| `Name.txt` | StringValue | Value |
| **`.rbxm` / `.rbxmx`** | **BANNED** | binary, unreviewable in a PR. CI and the harness both fail on it |

Properties and attributes must be plain JSON values (string, number, bool) until the harness learns
typed values (`{"Vector3": [...]}` and so on). Until then it fails such a value as "cannot compare",
and never skips it. `ignoreUnknownInstances` in a meta file is refused: it would let Studio-made
instances survive.

### Rojo DELETES Studio-created instances in Rojo-owned containers

Every project node with a `$path` defaults to `$ignoreUnknownInstances: false`: "whether instances
that Rojo doesn't know about should be deleted" ([Rojo project format](https://rojo.space/docs/v7/project-format/)).
Every container in the Layout table above is therefore **disk-only**. Anything created in Studio inside
one of them that has no file on disk is **deleted, not overwritten**, and not moved anywhere. That
includes ServerStorage (fully mapped since Task 5): a model built there in Studio is deleted at the
next Connect unless it is exported to `src/serverstorage/` as `.model.json`.

**When it happens** (tested 2026-09-24 with a probe Folder in each of three services, Rojo 7.7.0):

- **Not during live sync.** The probes survived 5 s idle, a new file added to the same folder, and
  that file's removal.
- **On the next Connect.** Rojo reconciles the whole tree and removes unknown instances. This is
  per the docs; not tested, because a reconnect needs Karen's click. Rojo's confirmation dialog
  lists the removals before you accept.

So a Studio-made instance can seem safe for a whole session and then vanish at the next Connect.
To keep a Studio-built object, export it as `.model.json` under `src/` (never `.rbxm`).

**Instances outside the Rojo-owned containers are not cleaned up.** When a mapping moves out of a
container Rojo does not own, the old copy stays behind as an orphan. For example, on 2026-09-24
DevPackages moved from ServerStorage to ReplicatedStorage, before ServerStorage was mapped. The harness's "no script outside Rojo-managed paths" check caught exactly that.
The 16 orphan TestEZ scripts were verified identical to disk, then removed (TASKS.md, Task 5).

**DEV place checks.** Before the first Connect (2026-09-24 ~18:36 local), all of ServerScriptService,
ReplicatedStorage, StarterPlayerScripts and ServerStorage were empty. Before mapping them
(2026-09-24 ~19:30), StarterGui, StarterPack, StarterCharacterScripts and ReplicatedFirst were empty,
and no script existed anywhere outside Rojo paths. Karen confirmed she added nothing to them.
Before mapping all of ServerStorage (2026-09-24 ~20:00), its only child was the Rojo-owned `Tests`.

## Toolchain: what is pinned and what is not

| Tool | Version | Pinned by |
|---|---|---|
| Rojo CLI | 7.7.0 | `rokit.toml` (exact) |
| Rojo Studio plugin | 7.7.0 | `rojo plugin install`, built from the pinned CLI, installed to `%LOCALAPPDATA%\Roblox\Plugins\RojoManagedPlugin.rbxm`. The Creator Store Rojo plugin must stay disabled. |
| Wally | 0.3.2 | `rokit.toml` (exact) |
| StyLua | 2.5.2 | `rokit.toml` (exact). Config: `stylua.toml` |
| selene | 0.31.0 | `rokit.toml` (exact). Config: `selene.toml` + `testez.yml` |
| luau-lsp | 1.70.0 | `rokit.toml` (exact). Editor language server, not used in CI yet |
| TestEZ | 0.4.1 | `wally.lock` (exact). `wally.toml` allows any compatible 0.4.x. Archived upstream |
| Rokit itself | 1.2.0 | **Not pinned.** Installed by hand. CI uses the latest via `setup-rokit` |
| Roblox Studio | 0.740.x | **Not pinned.** Studio auto-updates |
| selene's Roblox std | from the Roblox API dump | **Not pinned.** Selene downloads it into its cache |

After cloning: `rokit install`, then `wally install`. After changing the Rojo version: bump
`rokit.toml`, run `rojo plugin install`, and restart Studio.

## Run / test

**The full description of the test system (gate, runners, report format, every check, exit codes)
is the docstring of `tools/studio_mcp.py`.** It is the single source of truth. Update it with any
change to the test system, and don't restate it elsewhere.

- **Lint and format (also in CI):** `selene src tests` and `stylua --check src tests`
  (`stylua src tests` fixes formatting). `mkdir -p build && rojo build -o build/place.rbxl` checks the
  project builds (Rojo does not create `build/`).
- **Tests:** Studio open on the DEV place in **Edit** mode, Rojo connected, work committed:
  `python tools/studio_mcp.py test`.
  - Exit 0 means PASS on a clean tree. 1 means FAIL. 2 means REFUSED (Studio not in Edit mode).
    3 means PASS on a dirty tree, which is **not valid evidence**.
  - The final line names the commit it tested.
- **Other harness commands:** `state`, `console`, `stop` (read-only / recovery). It needs Studio →
  Assistant settings → MCP server enabled.
- **Karen's playtests do not run tests.** The runners need a harness token under 120 s old.
- **Client code** (camera, input, cursor, UI) is tested by client specs in `tests/client/`, which run
  in the player's client. Driving real input and play-time screenshots are **not** wired yet. That is
  a blocking task (TASKS.md) before any input-driven or visual client code.
- The Rojo plugin's **Connect** button cannot be clicked by tools. Karen presses it once per Studio
  session, and again whenever `rojo serve` restarts (for example after `default.project.json` changes,
  which the running server does not reload).
- **Known Rojo 7.7.0 crash.** `rojo serve` panics when a watched file or folder disappears before
  Rojo processes the event ([#1309](https://github.com/rojo-rbx/rojo/issues/1309),
  [#1321](https://github.com/rojo-rbx/rojo/issues/1321); fix PR #1319 open). It crashed on
  2026-09-24 when a test deleted a whole folder at once. Deleting files one at a time, with a
  pause, then the empty folder, did not crash. If the harness says "`rojo serve` is NOT running",
  restart it and have Karen press Connect.

## Test code ships with the place

While Rojo is connected, all test objects are part of the place and **are published with it**:
TestRunner, ClientTestRunner, TestKit, Tests, ClientTests, DevPackages (TestEZ) and TestSyncToken
(empty between runs), plus `SyncCheck`, a test fixture in `src/server`.

**Since Task 5, TestKit, ClientTests, DevPackages and TestSyncToken are in ReplicatedStorage, so
they replicate to every client.** Players can read this test code. It holds no secrets and is inert
outside Studio (`RunService:IsStudio()` plus a fresh token), so this is accepted for now.

Before the first public release, a publish step must strip them (TASKS.md, Task 2).

## Public repository: never commit secrets

The repo is **public**. Never commit:

- secrets, API keys, tokens, passwords or `.env` files
- Roblox `.ROBLOSECURITY` cookies, Open Cloud API keys, or webhook URLs
- private keys (`*.pem`, `*.key`) or credential JSON
- personal data (real emails; use the GitHub noreply address)

- `.gitignore` covers the common file names (`.env*`, keys, certificates, credential files), but it
  is a safety net, not a check. Read `git diff --cached` before every commit.
- Secrets needed at runtime go in Roblox Secrets Store / GitHub Actions secrets, never in the repo.
- If a secret is ever committed: **revoke or rotate it first**, then tell Karen. Removing it from
  history does not un-publish it.
- History check 2026-09-24:
  - gitleaks 8.30.1 over all refs: "no leaks found"
  - a manual grep of every commit's tree for emails, cookies, keys, tokens and local paths: only the
    harness's own "sync token" wording
  - every commit uses the noreply identity
