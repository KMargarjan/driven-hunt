# CLAUDE.md: Driven Hunt

Read docs/PROJECT_CONTEXT.md before your first task in a session.

Roblox game. Code lives on disk and is synced into Studio by Rojo. Place: **Driven Hunt DEV**
(PlaceId 136410205938347, enforced by `servePlaceIds` in `default.project.json`).
Five roles: Director, Builder, Architect, Reviewer, Karen. See **Four-agent workflow** below.

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
3. **ONE OWNER PER SYSTEM.** Anything drawn, the camera, input, state: exactly one writer. The
   Architect decides the owner in `docs/design/<system>.md`. The *System owners* table in
   `GAME_DESIGN.md` mirrors those designs.
4. **ONE TASK PER ROUND.** Small and testable, then stop. Tasks live in `TASKS.md`.
5. **VISUAL CHANGES NEED A SCREENSHOT** that you inspected yourself.
6. **TEST THE PLAYER'S PATH, not the harness.** Harness faults are bugs: report them.
7. **NEVER DELETE.** Archive with a note (see `backups/README.md`).
8. **REPORT HONESTLY** what you could not verify and what you got wrong.
9. **CODE COMMENTS** carry the pattern name, source links and the research note file.
10. **Nothing is merged until the Reviewer has signed it off**: `reviews/task-<N>/RESULT.md`
    line 1 is `PASS` for the PR's code commit. `PASS` with notes under it **is** a pass: since
    Task 21 only a finding that makes the game, a test, an owner boundary or security wrong is
    blocking. The Director merges; the Builder never merges (see **Git workflow** step 4).

## Four-agent workflow

### Roles

| Role | Owns | Writes | Never |
|---|---|---|---|
| **DIRECTOR** | the roadmap; dispatches tasks; **git and GitHub**: retargets and merges PRs | `ROADMAP.md`, `TASKS.md`, `PLAN_NOTES.md` | writes code |
| **BUILDER** (Claude, this file's reader) | implementation | the only writer of code in `src/`, `tests/`, `tools/`. Also `reviews/task-<N>/REQUEST.md`, `ESCALATE.md`, research notes, `CLAUDE.md`, and in `TASKS.md` the status of its current task plus any Director dispatch that arrived outside the repo, transcribed verbatim and marked as the Director's | writes designs or verdicts |
| **ARCHITECT** (`tools/architect.sh`) | structure, system owners, interfaces | `docs/design/`, `docs/architecture/`, `reviews/task-<N>/ARCH_RESULT.md` (through the script) | touches code (read-only) |
| **REVIEWER** (`tools/review.sh`) | verifying claims | `reviews/task-<N>/RESULT.md` (through the script) | touches code (read-only) |
| **KAREN** | the game | plays it, decides anything about feel or design, `PLAYTEST.md` feedback, and does the clicks no tool can do (Rojo **Connect**, the Studio MCP toggle, Studio itself) | merges PRs (handed to the Director on 2026-09-24) |

The Director may be Karen or a Director agent. The Builder accepts tasks from either, in exactly the
same way, and addresses reports to the Director. A report says plainly when something needs Karen's
judgement or a playtest.

Karen handed all git and GitHub work to the Director on 2026-09-24: the Director retargets and merges
PRs. Karen no longer merges. The Builder still never merges and never pushes to `main`.

### Files the roles talk through

| File | Written by | Purpose |
|---|---|---|
| `TASKS.md` | Director (queue, priority); Builder (its current task's status, non-must-fix audit items under the task, and a Director dispatch that arrived outside the repo, transcribed verbatim and marked as the Director's) | the queue and status, one task at a time |
| `docs/design/<system>.md` | Architect | the design, written **before** a new system is built |
| `reviews/task-<N>/REQUEST.md` | Builder | **one page.** What changed, `Task: N`, `Round: N`, `Base:`, `Code commit:`, at most 10 claims with how to verify each, and what could not be verified |
| `reviews/task-<N>/RESULT.md` | Reviewer | `PASS` on line 1, or a numbered list of **blocking** findings. Notes go under `## Notes (non-blocking)` and never block |
| `reviews/task-<N>/ARCH_RESULT.md` | Architect | `PASS`, or a numbered list (design: blocking open decisions; audit: must-fix items) |
| `reviews/task-<N>/BRIEF.md` | Builder, carrying the Director | **optional.** The input to an Architect *design* run: decisions already taken, and what the design must contain. `docs/ARCHITECT_PROMPT.md` tells the Architect to read it first when it exists, and it overrides anything older in `docs/`, `TASKS.md` or an earlier design. Written before the run, committed, then `tools/architect.sh design <system> --task <N>` |
| `ESCALATE.md` | anyone | for the Director and Karen: a disagreement, a 3rd failed round, a decision needed, or a **`NEEDS KAREN`** entry (a click only Karen can make) |
| `PLAYTEST.md` | Builder, transcribing Karen | Karen's feedback after playing |

### The loop, for every task (no questions to Karen)

1. Read `TASKS.md` and the task you were given.
2. **New system?** Run `tools/architect.sh design <system>` and build to that design. If you disagree
   with the design, write `ESCALATE.md` and stop.
3. Build. One task, nothing extra. Commit (this is the **code commit**), then run the harness on the clean
   tree. **Harness before review** (Task 21): a change touching `src/`, `tests/` or `tools/` cannot
   be reviewed until it has run — `tools/review.sh` refuses it unless the request pastes the harness
   PASS line for the code commit. Docs-only tasks are exempt.
   **And the two-player run is part of the gate** (Director decision, 2026-09-26) for a change
   touching `src/` (gameplay), `tests/client/` or `tools/studio_mcp.py`: paste the
   `[harness2] PASS: n/m checks @ <code commit> (clean tree)` line as well. A driver, a tie, a team
   swap and half the client suite exist only with two clients, so a one-player run is not evidence
   for them. `tools/agents.py` refuses the review without it. **Docs, and the tools that are not the
   harness, are exempt**, because `test2` costs a human click and about eight minutes.
4. Write `reviews/task-<N>/REQUEST.md` (increment `Round:`; `Code commit:` = the commit the harness
   line names) and commit it. **One page: `Task: N`, `Round: N`, `Base:`, `Code commit:`, at most 10
   claims, each with how to verify it.** Cite **files and symbols, never line numbers** (every later
   commit moves them; Director decision 2026-09-24, after Task 11 spent rounds 3 and 4 on stale
   citations), and **write it fresh for each task** — the final state, never a round-by-round history.
   **After the code commit, commit nothing but the paperwork the merge gate allows** (git workflow
   step 4: anything under `reviews/`, `ESCALATE.md`, `PLAYTEST.md`, `docs/architecture/audit-NNN.md`
   and the task's status row in `TASKS.md`). `.agent-evidence/paperwork-after-code-commit.txt` lists
   exactly what changed after the tested commit and whether any of it is not paperwork; if something
   is, the harness line does not cover HEAD and that **is** a blocking finding.
5. Run `tools/review.sh` (add the task number if more than one task's request is in the tree).
   **Commit `reviews/task-<N>/RESULT.md` either way**: the next run needs a clean tree, and it counts
   the round from that file's trailer — **this task's file only**, so another task's verdict, merged
   or not, can never block this one. On blocking findings, fix and go back to 4 (the next request
   says `Round: N+1`). On `PASS`, continue: notes under a `PASS` are queued in `TASKS.md`, not fixed
   in another round. **A docs-only task gets one round**, and notes never hold it up.
6. Architect audit — **every ~5 tasks, not every task** (`ROADMAP.md` speed rule 3; Director decision
   2026-09-24). When the Director calls for one, run `tools/architect.sh audit` once, after the
   review passes. An item is must-fix only if it blocks the next game task and the audit names that
   task (speed rule 2); fix those and go back to 4. Everything else goes into `TASKS.md` under
   "before release". When no audit is due, say so in the report.
7. Report to the Director: the definition-of-done checklist, the commit and PR link, and how many
   review rounds it took.

**Stop rules.** Write `ESCALATE.md` and stop when:
- the same item fails 3 rounds. `tools/review.sh` refuses `Round: 4`, counting the round from the
  committed `reviews/task-<N>/RESULT.md` trailer rather than from the request, and refusing when that
  trailer has gone missing from a file whose git history had one. So the count cannot be raised,
  skipped or reset from the request, or by deleting the verdict. The count is **per task** (Task 21):
  every task's first round is `Round: 1` and needs no authorisation, whatever the previous task's
  verdict was — Task 22 could not be reviewed at all because the old global counter had no task
  boundary (`ESCALATE.md`, 2026-09-25). It is **not** tamper-proof: a
  Builder can still commit a hand-written trailer, or rewrite history. See "What is enforced and
  what is policy".

  **One extra round, by Director authorisation only.** `MAX_ROUNDS` stays 3. The Director may
  authorise a single extra round when the last round's findings were documentation-only. The Builder
  then runs that one review with `DIRECTOR_MAX_ROUNDS=<n>` in the environment
  (`DIRECTOR_MAX_ROUNDS=4 powershell -ExecutionPolicy Bypass -File tools/review.ps1`). It may **only**
  be set when `ESCALATE.md` records that authorisation for **that task and that round**, it may only
  raise the cap, and it is never committed. A failing authorised round is an `ESCALATE.md` entry, not
  a request for another one
- you believe a Reviewer or Architect finding is factually wrong (write the evidence)
- a design, feel or taste decision is needed
- **a human action is needed** (Rojo **Connect**, the Studio MCP toggle, Studio not in Edit mode,
  anything only Karen can click) and you cannot do it yourself. Write the entry headed
  **`NEEDS KAREN`**, list the **exact clicks** in order, and stop. Do not work around it, and do not
  report a harness result you could not produce.

### The agent scripts

- `tools/review.sh [N]` and `tools/review.ps1 [N]` spawn the Reviewer. With no argument the task is
  the most recently committed `reviews/task-*/REQUEST.md`, and its `Task: N` line must match its folder.
- `tools/architect.sh design <system> --task <N>`, `tools/architect.sh audit --task <N>` and their
  `.ps1` twins spawn the Architect. `--task` says which `reviews/task-<N>/` the verdict goes in.
- The wrappers are thin. `tools/agents.py` holds the logic, and its docstring describes it.
- On this PC, run the PowerShell versions as `powershell -ExecutionPolicy Bypass -File tools/review.ps1`,
  because the local execution policy blocks unsigned scripts.

Each call spawns a fresh headless `claude -p` session. It is read-only by construction:
- exactly the Read, Grep and Glob tools
- a throwaway git worktree of the commit under review
- precomputed evidence in `.agent-evidence/`
- the script writes the result files, not the agent
- nothing is written if the repo changed during the run

The prompts are `docs/REVIEWER_PROMPT.md` and `docs/ARCHITECT_PROMPT.md`. `tools/review.sh` requires a
clean, committed tree. Raw session output goes to `.agent-logs/` (git-ignored).

### Costs

**Every script call is a separate paid Claude session**: typically several minutes and several
dollars. The script prints each session's cost into the result file's trailer.
- Run `tools/architect.sh audit` only when the Director calls for one (every ~5 tasks), after the
  review passes, never once per round.
- Run `design` only for a new system.
- Batch everything for a round into one `reviews/task-<N>/REQUEST.md`. A round is one review call.

## Git workflow: branch + pull request, never push to main

1. `git switch main && git pull`, then `git switch -c task-<n>-<short-name>`. A task that builds on an
   unmerged PR branches from that PR's branch and targets it (a stacked PR).
2. Stage **explicit paths** (`git add <paths>`), then read `git status` and `git diff --cached` before
   every commit. Never commit with a blind `git add -A`: untracked files (another role's docs, for
   example) get swept in. That happened on 2026-09-24 with `docs/architecture/audit-001.md`.
3. Push the branch (`git push -u origin <branch>`) and open a pull request. CI
   (`.github/workflows/ci.yml`) must be green.
4. The Reviewer reviews the PR. **The Director retargets and merges it**, and only when all four
   hold. The **code commit** is the `Code commit:` of the final `reviews/task-<N>/REQUEST.md`: the
   last commit in the PR that changed anything but the loop's own paperwork.
   - a clean-tree harness PASS names the code commit
     (`[harness] PASS: n/n checks @ <code commit> (clean tree)`), **and a clean-tree
     `[harness2] PASS` for the same commit** when the change touches `src/`, `tests/client/` or
     `tools/studio_mcp.py` (Director decision, 2026-09-26),
   - `reviews/task-<N>/RESULT.md` line 1 is `PASS` (notes under it do not block), and its trailer
     names a commit that differs from the code commit only in paperwork,
   - CI (`.github/workflows/ci.yml`) is green on the PR head,
   - **between the code commit and the PR head, only paperwork changed**: anything under `reviews/`,
     `ESCALATE.md`, `PLAYTEST.md`, `docs/architecture/audit-NNN.md` and the task's status row in
     `TASKS.md`. `git diff --name-only <code commit>..<head>` shows it, and so does
     `.agent-evidence/paperwork-after-code-commit.txt`.

   The head is necessarily ahead of the reviewed commit, because steps 5 and 6 commit the verdict
   files afterwards. That is why the gate is written against the code commit and bounds what may
   follow it. Anything else in that range means the evidence does not cover the head: go back to
   step 3, re-run the harness and review again.

   The Builder never merges and never pushes to `main`. Karen no longer merges.
5. Record Karen's playtest feedback in `PLAYTEST.md` in the same PR round.
6. **Stop `rojo serve` before switching branches** (or re-Connect afterwards). A branch switch while
   Rojo is live left Studio out of sync on 2026-09-24 (`ServerStorage.Tests` came out empty). The
   harness catches this, but it wastes a run. **Worse: on 2026-09-24 (Task 17) a large branch switch
   alone crashed `rojo serve` 7.7.0** — no test, no deletion, just `git switch main && git pull`
   (59 commits) — and recovering it needs Karen's Connect click, so the run stops.

**What is enforced and what is policy.** The GitHub ruleset on `main` *enforces* only two things:
changes arrive through a pull request, and the `Build and lint` CI check passes. It does **not** enforce
Reviewer sign-off (approvals are set to 0, and the Reviewer has no GitHub account), the harness-PASS
condition, who merges, or that the Builder never merges. The Builder's credentials could merge a green
PR. All of those are **policy**: rule 10 plus this section. The Builder follows them, the Director
checks them before merging, and the Reviewer checks them in the review.

The **round count** is in between. `tools/agents.py` takes it from the committed
`reviews/task-<N>/RESULT.md` trailer of that task and refuses a request that raises, skips or resets
it, including by deleting the file. So is **harness before review**: a change touching `src/`,
`tests/` or `tools/` is refused until the request pastes the harness's own PASS line for the code
commit, and one touching `src/`, `tests/client/` or `tools/studio_mcp.py` is refused until it also
pastes the `[harness2]` line. But the Builder writes the repo's commits, so a hand-written trailer, or a history
rewrite, would still get past it. Until audit-002 must-fix #5 (Task 12) makes the verdict files
writable only by the scripts, the last step of the stop rule is policy too.

## Definition of done

Paste this, filled in, at the end of every task report. Each box is checked, or marked N/A with a reason.

```
- [ ] Tests pass: `python tools/studio_mcp.py test` → paste the final line. It must read
      "[harness] PASS: n/n checks @ <sha> (clean tree)" with <sha> = the PR's **code commit**
      (the `Code commit:` of the final reviews/task-<N>/REQUEST.md), and only paperwork after it (git
      workflow step 4)
- [ ] Two players, when the change touches src/, tests/client/ or tools/studio_mcp.py:
      `python tools/studio_mcp.py test2` → paste "[harness2] PASS: n/n checks @ <same sha> (clean
      tree)". Or N/A with the reason (docs, or tools outside the harness)
- [ ] CI green on the PR (link to the run)
- [ ] Screenshot inspected (rule 5), or N/A: <reason>
- [ ] Docs updated: TASKS.md, GAME_DESIGN.md owners, research note/INDEX, PLAYTEST.md, CLAUDE.md as needed
- [ ] Reviewer: reviews/task-<N>/RESULT.md line 1 = PASS for <sha> (notes, if any, queued in
      TASKS.md). Review rounds: N
- [ ] Architect audit: reviews/task-<N>/ARCH_RESULT.md = PASS (or must-fix fixed); other items in TASKS.md
- [ ] Needs Karen: <playtest / feel / design decision / a click only she can make>, or "nothing"
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
| `reviews/task-<N>/` | none | One folder per task: `REQUEST.md` (Builder), `RESULT.md` (Reviewer), `ARCH_RESULT.md` (Architect). Per task so branches never conflict and the round count has a boundary (Task 21) |
| `backups/` | none | Archived files plus notes |
| `docs/` | none | `PROJECT_CONTEXT.md` (who, the game, why the rules exist), `research/` (notes plus INDEX), `design/` (Architect system designs), `architecture/` (Architect audits), `REVIEWER_PROMPT.md` and `ARCHITECT_PROMPT.md` (the two agent prompts) |
| `tools/` | none | `studio_mcp.py` (test harness); `agents.py` plus `review.sh`/`review.ps1`/`architect.sh`/`architect.ps1` (the Reviewer and Architect gate) |

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
| selene | 0.31.0 | `rokit.toml` (exact). Config: `selene.toml` (src, roblox only) and `tests/selene.toml` (tests, roblox + `testez.yml`) |
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

- **Lint and format (also in CI):** `selene src`, `selene --config tests/selene.toml tests` (test globals
  are a lint error in `src/`), and `stylua --check src tests`
  (`stylua src tests` fixes formatting). `mkdir -p build && rojo build -o build/place.rbxl` checks the
  project builds (Rojo does not create `build/`).
- **Tests:** Studio open on the DEV place in **Edit** mode, Rojo connected, work committed:
  `python tools/studio_mcp.py test`, and `python tools/studio_mcp.py test2` (two players, one human
  click) whenever the change touches `src/`, `tests/client/` or `tools/studio_mcp.py`.
  - Exit 0 means PASS on a clean tree. 1 means FAIL. 2 means REFUSED (Studio not in Edit mode).
    3 means PASS on a dirty tree, which is **not valid evidence**.
  - The final line names the commit it tested.
- **Other harness commands:** `state`, `console`, `stop` (read-only / recovery). It needs Studio →
  Assistant settings → MCP server enabled.
- **Karen's playtests do not run tests.** The runners need a harness token under 120 s old.
- **Client code** (camera, input, cursor, UI) is tested by client specs in `tests/client/`, which run
  in the player's client. Since Task 6 the harness also **drives real input**: the scenario file
  `tests/client/input_scenarios.txt` (keys, mouse buttons, mouse moves and gaps) is replayed into the
  Play client through StudioMCP, gated exactly like the specs, and a client spec asserts on what
  `ContextActionService` and `UserInputService` delivered. The format, what it cannot express, and
  the ready handshake are in the `tools/studio_mcp.py` docstring.
- **Screenshots as evidence (rule 5):** `python tools/studio_mcp.py capture <name> [camera x,y,z]
  [look-at x,y,z]` saves the image to `.screenshots/` (git-ignored), in Edit or during Play. Look at
  it before claiming what it shows.
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
