# Architecture audit 002

Commit `24fd22a78d69be95484b3e4b0368c5734fd9af3f`, branch `task-10-lint-test-globals`
(`.agent-evidence/head.txt:1-2`). Read-only session; evidence precomputed in `.agent-evidence/`.

Scope: the whole repo against `CLAUDE.md`, `docs/design/` (empty apart from its README) and
`docs/PROJECT_CONTEXT.md`. Audit 001 is **not readable from this commit** — see must-fix 4 and
**Not verified**. Where `TASKS.md` records an audit-001 item as fixed (M1–M4, R2, L1, L3, L5) I took
that at its word and did not re-raise it.

State of the tree: no game code exists. `src/` holds one file, `src/server/SyncCheck.server.luau`, a
test fixture (`.agent-evidence/ls-files.txt:28-35`). Lint, format and build are clean
(`.agent-evidence/lint-selene.txt`, `lint-stylua.txt`, `rojo-build.txt`, all exit 0). Everything below
is about the foundations the first real system will stand on.

---

## Must fix now

### 1. Typed property values are refused, so no positioned geometry can come from disk

**Evidence.** `tools/studio_mcp.py:398-399`: `is_plain` accepts only `str`, `bool`, `int`, `float`.
`tools/studio_mcp.py:504-507`: any expected value that is not plain becomes
`"cannot compare ... (typed value; add a comparison)"`, which fails the check at
`tools/studio_mcp.py:601-602`. Stated as intended behaviour in the docstring
(`tools/studio_mcp.py:50-52`) and in `CLAUDE.md:194-197`. A deliberate typed property is listed among
the caught negative cases at `docs/research/2026-09-24-toolchain.md:160`.

**Why it matters.** The next build step is the grey-box core loop: "one boar AI, shotgun, hit zones,
score, teams, one drive" (`docs/PROJECT_CONTEXT.md:17-18`). A boar model, a shotgun `Tool` and a drive
line all need `Part` instances with `Size`, `CFrame` or `Position`, and the Tool needs `GripPos`. In a
`.model.json` those are arrays or `{"Vector3": [...]}` — neither is plain, so the run fails.
`.rbxm`/`.rbxmx` are banned (`CLAUDE.md:192`), so there is no second route for geometry on disk. The
only thing that passes today is to build the geometry in Studio, which Rojo deletes at the next
Connect (`CLAUDE.md:199-217`). That is the previous project's exact failure: everything living in the
place file, with no diff and no rollback (`docs/PROJECT_CONTEXT.md:40`).

**Fix.** Teach the comparison the types the grey-box needs: `Vector3`, `Vector2`, `CFrame`, `Color3`,
`UDim`, `UDim2` and `EnumItem` (already encoded at `tools/studio_mcp.py:116-117`). Two halves:
extend `encode` in `QUERY_NODES` (`tools/studio_mcp.py:111-119`) to return components as numbers
rather than `tostring`, and extend `same_value` (`tools/studio_mcp.py:402-420`) to compare
component-wise, at float32 for properties, accepting both Rojo's array shorthand (`"Size": [4,1,2]`)
and the explicit `{"Vector3": [...]}` form. Anything still unknown keeps failing as "cannot compare".

**Target.** A `src/serverstorage/Boar/` folder (`init.meta.json` with `"className": "Model"`, child
`.model.json` parts carrying `Size` and `CFrame`) passes the harness; changing one component of one
part in Studio fails it. Both cases run and recorded.

### 2. Only scripts are checked for being unmanaged; Studio-created non-script instances pass

**Evidence.** `QUERY_ALL_SCRIPTS` collects a path only when `d:IsA("LuaSourceContainer")`
(`tools/studio_mcp.py:174`). `unmanaged_scripts` builds its "known" set from sourcemap nodes whose
class is `Script`, `LocalScript` or `ModuleScript` (`tools/studio_mcp.py:519`). The check is named
"No script exists outside Rojo-managed paths" (`tools/studio_mcp.py:613`), and the docstring says the
same (`tools/studio_mcp.py:57-59`), as does `CLAUDE.md:154`. `compare_synced` only asserts that
*expected* instances exist; nothing enumerates the actual children of a Rojo-owned container.

**Why it matters.** `CLAUDE.md:152-153` says every container in the Layout table is disk-only, and
`CLAUDE.md:205-206` says a model built in Studio inside one is deleted at the next Connect. The
harness enforces that for scripts and for nothing else. So a `Frame` added in Studio under
`StarterGui`, a `Part` under `ServerStorage`, or an extra child inside a synced `Model`, is invisible
to a green harness run, can be the reason a spec passes, and then vanishes at the next Connect. This
is the same shape as audit-001 M1 (which closed the script half) with the non-script half still open,
and it lands directly on the next three tasks: animal templates in `src/serverstorage`, the shotgun
`Tool` in `src/starterpack`, HUD in `src/startergui`.

**Fix.** Derive the Rojo-owned roots from the `$path` nodes of `default.project.json` — walk the tree
the way `project_refusals()` already does (`tools/studio_mcp.py:324-340`) — then query every
descendant of each root and fail on any instance whose path is not in the sourcemap. Fold the result
into the existing check, renamed to cover instances, not just scripts, and update the docstring and
`CLAUDE.md:154`.

**Target.** A Folder and a Part created in Studio under each of the eight mapped roots fail the run
(8/8 caught, each with its path named); a clean place still passes with no new failures.

### 3. `tools/agents.py` has no research note (rules 1, 2 and 9)

**Evidence.** `tools/agents.py:1-25` names a pattern ("headless `claude -p` agents with a hard
read-only sandbox") and points at `CLAUDE.md`, with no `docs/research/` file and no external source.
`docs/research/INDEX.md:5-7` holds exactly one note; that note covers sync, packages, lint, tests and
Studio automation, and its 16 sources (`docs/research/2026-09-24-toolchain.md:20-37`) contain nothing
about headless agents, sandboxing or review automation. A grep for `agents.py`, `architect.sh` and
`review.sh` across `docs/research/*.md` returns no match. Every other component does carry the
citation rule 9 asks for: `tests/TestKit.luau:5`, `tools/studio_mcp.py:6`,
`.github/workflows/ci.yml:3`, `tests/server/sync.spec.luau:3`. The wrappers cite only the docstring
(`tools/architect.sh:4`, `tools/review.sh:2`, `tools/architect.ps1:3`, `tools/review.ps1:1`).

**Why it matters.** Rule 10 makes this script the only thing between the Builder and Karen. Its
read-only guarantee rests on flag behaviour that was found by trial and error, recorded only as a code
comment: `tools/agents.py:11-21` states that a plain `--allowedTools` allow-list was *not* enforced
and that without `--restricted` a session could reach other live sessions. That is exactly the kind of
finding rule 1 exists to keep. It is also the largest invented foundation in the repo, and rule 2
requires the reason in writing. Invented foundations are what killed the previous project
(`docs/PROJECT_CONTEXT.md:36-38`).

**Fix.** Write `docs/research/<date>-agent-workflow.md` covering: what the system must do; 3+ named,
linked sources with licence and maintenance status (the Claude Code headless/`-p` and permission-mode
documentation, `git worktree`, and at least one existing automated-review harness to compare the
design against); what was borrowed and what was invented with the reason — the block-marker transport
(`tools/agents.py:151-155`), the write guard (`tools/agents.py:182-188`), the round cap
(`tools/agents.py:39`), the precomputed-evidence directory (`tools/agents.py:83-122`); numeric targets
(session cost, `AGENT_TIMEOUT_S`, rounds, turns); and the negative cases that demonstrate read-only.
Add it to `docs/research/INDEX.md` and cite it from `tools/agents.py` and all four wrappers.

### 4. The Architect audits blind: earlier audits are neither on the branch nor in the evidence

**Evidence.** `docs/architecture/` does not exist at this commit: no such entry in
`.agent-evidence/ls-files.txt`, and a glob of `docs/**/*.md` returns six files, none an audit.
`audit-001.md` was committed alone on a separate branch, PR #2 (`TASKS.md:32`), which is not an
ancestor of this one. Meanwhile `tools/agents.py:259-260` hands the Architect the instruction
"Earlier audits live in `docs/architecture/` or git history; do not repeat items already fixed", and
`tools/agents.py:264-267` calls `build_evidence(wt)` with no `base` and no `code_commit`, so audit
mode receives no `log.txt`, no diff and no prior-audit text; the agent has three tools and no git
(`tools/agents.py:134`). `TASKS.md:14` tracks the remaining backlog as the bare labels "L2, L4, L6,
L7, L8, L9 (owner table rows)".

**Why it matters.** A rule-6 harness fault: the instruction cannot be followed with the tools given.
This audit could not check what audit-001 already raised, so it may duplicate or silently drop items,
and every future audit inherits the same blindness. The Builder's own backlog row is equally
unreadable: five of the six open labels have no text anywhere on this branch. The previous project
burned rounds on a harness that was wrong as often as the game
(`docs/PROJECT_CONTEXT.md:29-31`).

**Fix.** Two parts.
(a) In `cmd_architect`, precompute the prior audits into the worktree:
`next_audit_number()` already scans `git log --all --name-only -- docs/architecture`
(`tools/agents.py:239-243`); reuse that list to write each audit's content to
`.agent-evidence/prior-audits/audit-NNN.md`, and add `log.txt` for audit mode. List them in
`INDEX.md` so the prompt's instruction is satisfiable.
(b) Land `docs/architecture/audit-001.md` on the branch chain so the tree being audited contains its
own architecture record, and expand `TASKS.md:14` to state each open item in one line instead of a
label.

### 5. Verdict files have a second writer and nothing checks them

**Evidence.** `ARCH_RESULT.md:1` is `NONE`, written by hand by the Builder, while `ARCH_RESULT.md:4`
of the same file states "This file is written only by `tools/architect.sh` (the ARCHITECT)".
`CLAUDE.md:41` and `CLAUDE.md:57` name the Architect, through the script, as its only writer, and the
script is the only thing that can produce the trailer (`tools/agents.py:191-195`, `:272-274`). `NONE`
is not a verdict the script can emit: `verdict_of` accepts only `PASS` or a line starting `1.`
(`tools/agents.py:158-164`). The same contradiction sits in `docs/design/README.md:7` ("Only the
Architect writes here (through the script)") — a file the script has no way to write. Nothing
machine-checks either verdict: the definition of done leaves it to a human ticking boxes
(`CLAUDE.md:132-146`), and `.github/workflows/ci.yml` has no verdict step. Separately,
`tools/agents.py:247-249` lets an audit run against a dirty tree with only a printed note, and the
trailer records the commit but not the dirty state — unlike the test harness, which prints
"DIRTY TREE ... NOT valid evidence" and exits 3 (`tools/studio_mcp.py:562`, `:569`).

**Why it matters.** Rule 10 is the only gate before Karen, and it is a Markdown file any role can
write, with no tie to the commit being merged. Branch protection enforces neither
(`CLAUDE.md:126-131`). A stale or hand-written `PASS` is indistinguishable from a real one without
reading the trailer by eye. This is the same false-PASS shape that audit-001 M4 closed for the
harness, still open for the two files that decide whether work ships. Rule 3, applied to a verdict
file, means one writer.

**Fix.**
(a) Remove the hand-written `ARCH_RESULT.md` placeholder (archive it per rule 7) and let the script
create the file on first run. Narrow `docs/design/README.md:7` to the files the script actually
writes, or move that sentence into `docs/ARCHITECT_PROMPT.md`.
(b) Put the clean/dirty state of the real repo into `trailer()` (`tools/agents.py:191-195`), and make
`cmd_architect` either refuse a dirty tree like `cmd_review` (`tools/agents.py:201-203`) or mark the
verdict as not valid evidence.
(c) Add one checked step — a small `tools/verdicts.py check`, run in CI — asserting for each of
`REVIEW_RESULT.md` and `ARCH_RESULT.md` that line 1 is `PASS`, that the trailer sha is an ancestor of
HEAD, and that nothing outside the verdict and status files differs between that sha and HEAD. That is
the rule `request-only-diff.txt` already applies to review requests
(`tools/agents.py:101-110`), generalised to the merge decision.

---

## Fix before release

**F1. Every negative case is hand-run and then deleted.** The 6/6, 15/15 and 8/8 negative-case
matrices (`docs/research/2026-09-24-toolchain.md:95-96`, `:160-163`) and Task 10's own lint probe
(`REVIEW_REQUEST.md:53-56`: a temporary `src/shared/zz_probe.luau`, checked by hand, "There is no
committed regression test for lint config") exist only as prose. Nothing re-runs them, so the guards
can regress silently. The guard is currently correct — `selene.toml:4` is `std = "roblox"` and
`testez.yml` is referenced only by `tests/selene.toml:3` — which is why this is not must-fix today.
Fix: a committed negative-case suite, e.g. fixture files under `tools/lint-fixtures/` (outside every
`$path`, so nothing is synced) plus a CI step asserting a non-zero selene exit, and harness negative
cases driven from a checked-in scenario list rather than a table in a note.

**F2. `init.meta.json` `className` is never compared by the harness.** The `.meta.json` branch reads
only `properties` and `attributes` (`tools/studio_mcp.py:440-446`), and `CLAUDE.md:189` claims only
those two are compared — while `CLAUDE.md:162-163` tells the Builder to declare a `ScreenGui` and a
`Tool` through `init.meta.json`'s `className`. The class is checked only through the sourcemap node
(`tools/studio_mcp.py:492-494`), and whether Rojo's sourcemap reports the meta-file class is not
verified (no `init.meta.json` exists in the repo). Worst case is a false failure, not a false pass, so
it is not must-fix — but the first `init.meta.json` must confirm it live, and if the sourcemap reports
`Folder`, compare `className` from the meta file directly.

**F3. `.gitignore` does not ignore `/.agent-evidence/`.** `.gitignore:58-59` ignores `/.agent-logs/`
but nothing ignores the evidence directory the agent scripts create inside a worktree
(`tools/agents.py:83-122`), which shows as untracked there. `CLAUDE.md:114-116` records a blind
`git add -A` sweeping `docs/architecture/audit-001.md` into PR #1 on 2026-09-24; this is the same
trap, one directory over. Fix: add `/.agent-evidence/`.

**F4. `CLAUDE.md:73-74` contradicts rule 4.** Step 6 says must-fix audit items are fixed inside the
current task's round; rule 4 (`CLAUDE.md:24`) says one small task per round. The actual practice
contradicts step 6 and follows rule 4: audit-001's M1–M4 became their own task
(`TASKS.md:11`, "Architecture audit-001 must-fix M1–M4 plus doc drift"). Fix: reword step 6 to match
what is done — must-fix items become a single new task at the head of the queue, and the current task
is not reported done until that task lands. The five items above should be handled that way; they are
architecture-level and do not belong inside a lint-config task.

**F5. The DEV PlaceId is duplicated in a spec.** `tests/server/sync.spec.luau:8` hard-codes
`136410205938347`, duplicating `default.project.json:3`. The harness already asserts the PlaceId from
`servePlaceIds` twice (`tools/studio_mcp.py:579-581`, `:652`), so the literal adds no coverage and
becomes a wrong assertion the moment a second place exists (a PROD place at publish, Task 2). Fix:
drop the assertion, or read the id from one shared module.

---

## Log only

- **L1.** `CLAUDE.md:175` describes `docs/` as `research/` plus `architecture/` and omits `design/`,
  which exists (`docs/design/README.md`) and is a named role output (`CLAUDE.md:41`, `:54`).
- **L2.** `GAME_DESIGN.md:3` is still a skeleton; `GAME_DESIGN.md:24-27` holds four `_unassigned_`
  rows and no row for any system in the build order. The guardrail is working (an unlisted system has
  no owner and may not be written), but the queue needs design runs before code. Order I would take
  them in: `weapon`, `animal`, `match-state`, `camera`, `input` — `weapon` and `animal` first because
  they are what must-fix 1 unblocks, and because hit zones are the first thing Karen can judge by
  feel. No file in `src/` for a system before its `docs/design/<system>.md` exists.
- **L3.** Three tasks sit `awaiting review` at once (`TASKS.md:7`, `:11`, `:15`) in a four-deep stack
  of PR branches. The root verdict files carry only the newest round: `REVIEW_RESULT.md:4` names
  `7cc16ff`, Task 10's. Each earlier PR's verdict lives at its own branch head, so nothing is lost,
  but the verdict for a PR must be read at that PR's head, not from a descendant branch. Must-fix 5(c)
  makes that checkable instead of conventional.
- **L4.** `tools/agents.py:93-94` falls back to `selene src tests` when `tests/selene.toml` is absent.
  For a commit before Task 10 that lints `tests/` with the `src` std and reports undefined-variable
  errors that CI never saw at the time. Harmless now; misleading if an old commit is ever audited.
- **L5.** `tools/agents.py:102` uses `git diff --name-only code..HEAD`, a tree diff, so a file changed
  and reverted between the tested commit and HEAD reads as "no change".
- **L6.** `src/server/SyncCheck.server.luau:4-5` runs in every live server. Already on the strip list
  (`TASKS.md:8`).
- **L7.** `selene --config tests/selene.toml` resolves `testez.yml` by working directory
  (`REVIEW_REQUEST.md:60`). Running from elsewhere makes selene fail loudly rather than silently drop
  the std, so it needs no guard; CI runs from the root (`.github/workflows/ci.yml:47`).
- **L8.** `TASKS.md` has two writers by documented partition (`CLAUDE.md:53`): the Director owns the
  queue, the Builder the status of its current task. Accepted, but it is the one file in the workflow
  where rule 3 is satisfied by convention rather than structure.
- **L9.** The `24/24` figure in `REVIEW_REQUEST.md:50` is internally consistent with the code: 10
  pre-play checks (`tools/studio_mcp.py:575`–`:629`), 6 per side × 2 (`:649`–`:664`), the gate-closed
  check (`:667`) and "HEAD unchanged during the run" (`:559`).

---

## Not verified

- **Anything requiring Roblox Studio.** No Studio here (`.agent-evidence/INDEX.md:14`). The harness
  line `[harness] PASS: 24/24 checks @ 13a19425... (clean tree)` (`REVIEW_REQUEST.md:50`) was checked
  only for internal consistency with the code (L9), not re-run. Every claim in must-fix 1 and 2 about
  what the harness *would* do is read from the source, not observed.
- **`docs/architecture/audit-001.md`.** Not in this tree and not in the evidence; I have no git tool.
  Items it raised that `TASKS.md:14` lists only as L2, L4, L6, L7, L8 are unknown to me, so I cannot
  guarantee I have not restated one of them. That is must-fix 4.
- **Whether Rojo's sourcemap reports the class declared in an `init.meta.json`** (F2). No such file
  exists in the repo, so the interaction is untested.
- **Whether Rojo deletes unknown instances at Connect.** `CLAUDE.md:213-215` says this is per the docs
  and "not tested, because a reconnect needs Karen's click". Must-fix 2 rests on that documented
  behaviour.
- **Whether Rojo accepts the `.model.json` shapes must-fix 1 requires** (array and typed forms for
  `Size`/`CFrame`). The refusal path on the harness side is certain from the code
  (`tools/studio_mcp.py:398`, `:504`); Rojo's acceptance is from its documented format only.
- **CI status for this commit.** No CI output in `.agent-evidence/`; `REVIEW_REQUEST.md:57-58` says it
  was unknown when the request was written.
- **DevPackages / TestEZ integrity.** `DevPackages/` is absent from the worktree
  (`.agent-evidence/INDEX.md:13`), so the `devpackages.sha256` comparison
  (`tools/studio_mcp.py:378-388`) could not be exercised. I read only the first 240 of 344 manifest
  lines.
- **Secret-history claims** (`CLAUDE.md:305-310`, gitleaks and a manual grep over all refs). Not
  re-runnable here.
- **`.gitignore` effectiveness.** No `git check-ignore`; the patterns were read, not tested.
