# Review request

Written by the Builder for `tools/review.sh`. The format is below; the script parses the first three lines.

Round: 2
Base: `4fcff0f`
Code commit: `9fe442ceba8dc50cc4acb0eda4717a18477a191d`

## Task
Task 11 (`TASKS.md`): run Task 9 (the four-agent workflow) through the loop itself. Task 9 was built
and pushed as PR #4 but never reviewed. This round reviews **the whole Task 9 change** plus the
policy edits Task 11 adds. Task 11's scope is the Director's, transcribed verbatim in `ESCALATE.md`
("Task 11's dispatch, verbatim").

Scope of this review = `git diff 4fcff0f...HEAD` (`.agent-evidence/diff.patch`). That is Task 9's two
commits (`2958ab5`, `0fa7c2b`) plus `145656f` (merge of `main`, which only adds
`docs/architecture/audit-001.md`), `6378a07` (the Task 11 policy edits) and `9fe442c` (the round-1
fixes). Claims 1–17 are round 1's, updated where the fixes moved lines; claims 18–23 are the six
round-1 findings.

## What changed

**Task 9 (already on the branch, never reviewed):**
- `tools/agents.py` — spawns the REVIEWER and ARCHITECT as fresh headless read-only `claude -p`
  sessions; precomputes evidence; parses the agent's block; writes the result files itself.
- `tools/review.sh`, `tools/review.ps1`, `tools/architect.sh`, `tools/architect.ps1` — thin wrappers.
- `docs/REVIEWER_PROMPT.md`, `docs/ARCHITECT_PROMPT.md` — the two prompts.
- `docs/PROJECT_CONTEXT.md` — who, the game, the build order, why the rules exist.
- `docs/design/README.md` — the Architect's design folder, and who may write there.
- `ESCALATE.md`, `REVIEW_REQUEST.md`, `REVIEW_RESULT.md`, `ARCH_RESULT.md` — the communication files.
- `CLAUDE.md` — the "Four-agent workflow" section (roles, files, the loop, stop rules, the scripts,
  costs).
- `.gitignore` — `/.agent-logs/`.
- `TASKS.md` — Task 9 row.

**Task 11 (commit `6378a07`):**
- `CLAUDE.md` — merge policy: the **Director** retargets and merges PRs, and only on Reviewer `PASS`
  for the PR head + green CI + a clean-tree harness PASS naming that commit. Karen no longer merges.
  The Builder still never merges. Rule 10, the DIRECTOR row, the KAREN row, git-workflow step 4 and
  the "what is enforced and what is policy" paragraph all say the same thing.
- `CLAUDE.md` — a fourth stop rule: a human action only Karen can do goes into `ESCALATE.md` headed
  `NEEDS KAREN` with the exact clicks, and the Builder stops.
- `ESCALATE.md` — the 2026-09-24 audit-002 scope entry, the Director's answer, closed 2026-09-24.
- `TASKS.md` — Task 10 `done`, Task 11 `in progress`, Tasks 12–16 queued.

## Claims

1. **`tools/agents.py` gives the agent exactly Read, Grep and Glob, and no way to write or run
   commands.** How to verify: `tools/agents.py:140-141` — `cmd = [claude, "-p", prompt, "--restricted",
   "--tools", "Read,Grep,Glob", "--permission-mode", "dontAsk", "--strict-mcp-config",
   "--no-session-persistence", "--output-format", "json"]`. The reason each flag is there is the
   docstring, `tools/agents.py:11-19`.
2. **The agent never writes the verdict files; the script does.** How to verify: the only writes are
   `write(...)` calls in `cmd_review` (`tools/agents.py:270`) and `cmd_architect`
   (`tools/agents.py:308-310`), fed from `block(text, ...)` — text parsed out of the agent's stdout.
   The agent has no Write/Edit tool (claim 1).
3. **The agent reads a throwaway worktree of the committed HEAD, not the working tree.** How to
   verify: `class Worktree` (`tools/agents.py:197-207`) does `git worktree add --detach <tmp> HEAD`,
   and `run_agent` passes `cwd=wt` (`tools/agents.py:143`) and now also reads the prompt from it
   (`tools/agents.py:131-135`). `__exit__` removes it and prunes.
4. **Nothing is written if the repo changed while the agent ran.** How to verify: `guarded`
   (`tools/agents.py:210-216`) snapshots `repo_state()` (HEAD + `git status --porcelain`) before, and
   raises `Refused` if it differs after. Both `cmd_review` and `cmd_architect` call it.
5. **The review is refused on a dirty tree, and refused past round 3.** How to verify:
   `cmd_review` (`tools/agents.py:229-231`) raises `Refused` when `git status --porcelain` is
   non-empty; `tools/agents.py:255-256` raises when `Round: N` > `MAX_ROUNDS = 3`
   (`tools/agents.py:43`), pointing at `ESCALATE.md`. This is the stop rule in
   `CLAUDE.md` ("Stop rules", first bullet).
6. **The Reviewer is shown, as precomputed evidence, whether anything but `REVIEW_REQUEST.md`
   changed after the harness-tested commit.** How to verify: `build_evidence`
   (`tools/agents.py:105-114`) writes `.agent-evidence/request-only-diff.txt` with the file list
   between `Code commit:` and HEAD and an explicit "OK"/"NOT OK" line;
   `docs/REVIEWER_PROMPT.md` ("What you cannot check") tells the Reviewer to use it.
7. **A `REVIEW_REQUEST.md` without `Round:`, `Base:` or `Code commit:` is refused, and both commits
   must exist.** How to verify: `tools/agents.py:237-258` — the three regexes, the two
   `git rev-parse --verify <sha>^{commit}` calls (which raise `Refused` on failure through
   `run(..., check=True)`).
8. **A verdict file whose line 1 is neither `PASS` nor `1.` is refused, so a vague verdict cannot be
   written.** How to verify: `verdict_of` (`tools/agents.py:164-170`).
9. **Each verdict file carries a trailer naming the commit, the date, the session cost and the turn
   count, and says the script wrote it.** How to verify: `trailer` (`tools/agents.py:219-223`) and
   its two call sites (`tools/agents.py:270`, `tools/agents.py:309-310`).
10. **The lint evidence matches CI.** How to verify: `build_evidence` (`tools/agents.py:95-103`) runs
    `selene src` + `selene --config tests/selene.toml tests` when `tests/selene.toml` exists, else
    `selene src tests`, plus `stylua --check src tests` and `rojo build`. `.github/workflows/ci.yml`
    on this branch runs `selene src tests` and `stylua --check src tests`; this branch has no
    `tests/selene.toml` (that is Task 10, `task-10-lint-test-globals`), so the fallback is what runs,
    and it matches CI exactly.
11. **The audit number is taken from git history as well as the working tree, so a rebuilt branch
    cannot reuse a number.** How to verify: `next_audit_number` (`tools/agents.py:275-279`) unions
    `glob` of `docs/architecture/audit-*.md` with `git log --all --name-only -- docs/architecture`.
12. **Both wrapper pairs are thin and delegate to `tools/agents.py`.** How to verify:
    `tools/review.sh` (5 lines), `tools/review.ps1` (4), `tools/architect.sh` (7),
    `tools/architect.ps1` (6). Each `cd`s to the repo root and execs
    `python tools/agents.py <command>`, and the `.ps1` twins propagate `$LASTEXITCODE`.
13. **CLAUDE.md now says the Director merges, on four conditions, and that Karen does not.** How to
    verify: `CLAUDE.md` rule 10; the DIRECTOR row ("retargets and merges PRs") and the KAREN row
    (Never column: "merges PRs (handed to the Director on 2026-09-24)") in the Roles table; the
    paragraph after that table; git workflow step 4; and the "what is enforced and what is policy"
    paragraph. `grep -n -i "merge" CLAUDE.md` returns 10 lines and none of them says Karen merges.
14. **CLAUDE.md now has the `NEEDS KAREN` stop rule, and `ESCALATE.md` matches it.** How to verify:
    `CLAUDE.md` "Stop rules", fourth bullet; the `ESCALATE.md` row in the "Files the roles talk
    through" table; the fourth bullet of the `ESCALATE.md` header.
15. **The open escalation is answered and closed on this branch.** How to verify: `ESCALATE.md` —
    the entry heading reads `2026-09-24 · CLOSED 2026-09-24`, the "DIRECTOR's answer · 2026-09-24"
    section lists Tasks 11–16, and its standing decision (a must-fix item outside the current task's
    change becomes its own task) is the answer to the conflict the entry raised.
16. **`TASKS.md` carries Tasks 11–16 in the Director's order, and Task 10 is `done`.** How to
    verify: the `TASKS.md` table rows 10–16. Row 16 is marked **blocked** on Karen's map decision.
17. **The change adds no Luau code and no script outside Rojo-managed paths.** How to verify:
    `.agent-evidence/changed-files.txt` — no file under `src/` or `tests/` changes; the only new
    executables are `tools/*.sh`, `tools/*.ps1` and `tools/agents.py`, which `default.project.json`
    does not map.

## Round 2: the six round-1 findings

Fixed in `9fe442c`. The finding numbers are round 1's.

18. **Finding 1 — the merge gate was unsatisfiable.** Agreed, and the Reviewer's reasoning is right:
    loop steps 5 and 6 commit `REVIEW_RESULT.md`, `ARCH_RESULT.md` and the audit document *after* the
    reviewed commit, so the head always moves past it, and `trailer` fixes the verdict to the commit
    reviewed (`tools/agents.py:219-223`, `tools/agents.py:270`). Fix: the gate is written against the
    PR's **code commit**, and bounds what may follow it. How to verify: `CLAUDE.md` git-workflow
    step 4 — the definition of "code commit", the four bullets, and the paragraph after them
    explaining why the head is necessarily ahead. Rule 10 (`CLAUDE.md:30-32`) and the first line of
    the definition of done now say "code commit" too. The gate is satisfiable for this very PR: see
    the Harness section below.
19. **Finding 2 — the 3-round stop rule was self-reported.** Agreed. Fix: the round is now taken from
    the committed `REVIEW_RESULT.md` trailer, which only this script writes. How to verify:
    `previous_review` (`tools/agents.py:176-192`) parses `TRAILER_RE` (`tools/agents.py:173`) and the
    verdict from the body above it; `cmd_review` (`tools/agents.py:247-254`) requires
    `Round: N` == previous round + 1, or 1 when the previous verdict was `PASS` or there is no
    verdict yet, and refuses otherwise. Reading from the working tree is safe because
    `tools/agents.py:229-231` has already refused a dirty tree. The docstring
    (`tools/agents.py:23-25`) and `CLAUDE.md` "Stop rules" first bullet say what is enforced.
    **This run is the live proof:** the committed `REVIEW_RESULT.md` is round 1 with findings, so the
    script accepts only `Round: 2`. `CLAUDE.md` loop step 5 now tells the Builder to commit
    `REVIEW_RESULT.md` on findings too, which the round count depends on.
20. **Finding 3 — more than one task in the round, with no record of the Director's instruction.**
    The Reviewer is right that the repo held no record. The two policy edits *were* dispatched by the
    Director as part of Task 11. Fix: the dispatch is transcribed verbatim in `ESCALATE.md`
    ("Task 11's dispatch, verbatim"), `TASKS.md` row 11 names it as the scope's source, and
    `CLAUDE.md` now grants the Builder exactly that right (the BUILDER row and the `TASKS.md` row of
    the "Files the roles talk through" table: "a Director dispatch that arrived outside the repo,
    transcribed verbatim and marked as the Director's"). I did not split the task, because the
    Director set its scope; that choice and the finding are both in the Task 11 report.
21. **Finding 4 — the prompt was read from the working tree while the script said otherwise.**
    Agreed. Fix: `run_agent` now opens `os.path.join(wt, prompt_file)`
    (`tools/agents.py:131-135`), so both agents' prompts come from the commit under review. The
    `cmd_architect` dirty-tree note is true as written again.
22. **Finding 5 — the KAREN row said nothing about merging.** Fixed: its Never column reads
    "merges PRs (handed to the Director on 2026-09-24)" (`CLAUDE.md:44`).
23. **Finding 6 — the Layout table was stale.** Fixed: the `docs/` row names `PROJECT_CONTEXT.md`,
    `research/`, `design/`, `architecture/` and the two prompts; the `tools/` row separates
    `studio_mcp.py` (test harness) from `agents.py` plus the four wrappers (the Reviewer and
    Architect gate). `CLAUDE.md:205-206`.

## Harness

```
[harness] PASS: 24/24 checks @ 9fe442ceba8dc50cc4acb0eda4717a18477a191d (clean tree)
```

Run on this branch at the code commit `9fe442c` (exit 0). Only `REVIEW_REQUEST.md` changed after it —
see `.agent-evidence/request-only-diff.txt`. Round 1 ran the same harness at `6378a07`, also 24/24.

## Could not verify

- **The merge policy itself is policy, not enforcement.** Nothing in the repo or in GitHub stops the
  Builder merging; `CLAUDE.md` says so explicitly. This change does not add enforcement, and cannot:
  the GitHub ruleset has 0 required approvals and the Reviewer has no GitHub account.
- **The read-only claims about the `claude` CLI flags (claim 1) were tested by the Task 9 Builder on
  2026-09-24 against Claude Code 2.1.270** and written up in the `tools/agents.py` docstring. I did
  not re-run that experiment this round. A future CLI version could change the behaviour of
  `--restricted` or `--tools`, and nothing here would notice.
- **`tools/agents.py` has no research note** (CLAUDE.md rules 1, 2, 9). That is audit-002 must-fix #3,
  queued as **Task 14** by the Director's standing decision (`ESCALATE.md`, 2026-09-24). It is
  deliberately not fixed here.
- **The `NONE` placeholders in `REVIEW_RESULT.md` and `ARCH_RESULT.md` were written by the Builder,
  although only the scripts may write those files.** That is audit-002 must-fix #5, queued as
  **Task 12**. Deliberately not fixed here. (`REVIEW_RESULT.md` is overwritten by this very run.)
- **The Architect still does not get earlier audits in its evidence.** audit-002 must-fix #4, queued
  as **Task 13**. The merge of `main` in `145656f` does put `docs/architecture/audit-001.md` on this
  branch, so the file is at least visible in the worktree now; the evidence index still does not name
  it.
- **No screenshot** (CLAUDE.md rule 5): nothing visual changed. No `src/` or `tests/` file changed.
- **The new round check (claim 19) was exercised by hand, not by a test.** `previous_review` was run
  against five synthetic `REVIEW_RESULT.md` bodies (missing file, the `NONE` placeholder, a `PASS`
  at round 2, findings at round 3, and an ARCHITECT trailer); they gave next-round 1, 1, 1, 4 and 1.
  There is no automated test for it: `tests/` is TestEZ Luau running inside Studio, and
  `tools/agents.py` is Python, so the harness cannot reach it. That gap is real and is not fixed
  here. The live path *is* exercised by this round: round 2 was accepted only because the committed
  verdict says round 1.
- **The scope decision in finding 3 is the Director's, not mine.** I recorded the dispatch instead
  of splitting the task. If the Director wants the merge-policy edits in their own task, this PR has
  to be split; the Task 11 report says so.
