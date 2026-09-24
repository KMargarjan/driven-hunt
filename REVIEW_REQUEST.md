# Review request

Written by the Builder for `tools/review.sh`. The format is below; the script parses the first three lines.

Round: 1
Base: `4fcff0f`
Code commit: `6378a0787671b4a0622caee2dc0627c397fb8eae`

## Task
Task 11 (`TASKS.md`): run Task 9 (the four-agent workflow) through the loop itself. Task 9 was built
and pushed as PR #4 but never reviewed. This round reviews **the whole Task 9 change** plus the
policy edits Task 11 adds.

Scope of this review = `git diff 4fcff0f...HEAD` (`.agent-evidence/diff.patch`). That is Task 9's two
commits (`2958ab5`, `0fa7c2b`) plus `145656f` (merge of `main`, which only adds
`docs/architecture/audit-001.md`) plus `6378a07` (the Task 11 policy edits).

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
   commands.** How to verify: `tools/agents.py:134-135` — `cmd = [claude, "-p", prompt, "--restricted",
   "--tools", "Read,Grep,Glob", "--permission-mode", "dontAsk", "--strict-mcp-config",
   "--no-session-persistence", "--output-format", "json"]`. The reason each flag is there is the
   docstring, `tools/agents.py:11-19`.
2. **The agent never writes the verdict files; the script does.** How to verify: the only writes are
   `write(...)` calls in `cmd_review` (`tools/agents.py:234`) and `cmd_architect`
   (`tools/agents.py:272-274`), fed from `block(text, ...)` — text parsed out of the agent's stdout.
   The agent has no Write/Edit tool (claim 1).
3. **The agent reads a throwaway worktree of the committed HEAD, not the working tree.** How to
   verify: `class Worktree` (`tools/agents.py:169-179`) does `git worktree add --detach <tmp> HEAD`,
   and `run_agent` passes `cwd=wt` (`tools/agents.py:137`). `__exit__` removes it and prunes.
4. **Nothing is written if the repo changed while the agent ran.** How to verify: `guarded`
   (`tools/agents.py:182-188`) snapshots `repo_state()` (HEAD + `git status --porcelain`) before, and
   raises `Refused` if it differs after. Both `cmd_review` and `cmd_architect` call it.
5. **The review is refused on a dirty tree, and refused past round 3.** How to verify:
   `cmd_review` (`tools/agents.py:201-203`) raises `Refused` when `git status --porcelain` is
   non-empty; `tools/agents.py:219-220` raises when `Round: N` > `MAX_ROUNDS = 3`
   (`tools/agents.py:39`), pointing at `ESCALATE.md`. This is the stop rule in
   `CLAUDE.md` ("Stop rules", first bullet).
6. **The Reviewer is shown, as precomputed evidence, whether anything but `REVIEW_REQUEST.md`
   changed after the harness-tested commit.** How to verify: `build_evidence`
   (`tools/agents.py:101-110`) writes `.agent-evidence/request-only-diff.txt` with the file list
   between `Code commit:` and HEAD and an explicit "OK"/"NOT OK" line;
   `docs/REVIEWER_PROMPT.md` ("What you cannot check") tells the Reviewer to use it.
7. **A `REVIEW_REQUEST.md` without `Round:`, `Base:` or `Code commit:` is refused, and both commits
   must exist.** How to verify: `tools/agents.py:209-222` — the three regexes, the two
   `git rev-parse --verify <sha>^{commit}` calls (which raise `Refused` on failure through
   `run(..., check=True)`).
8. **A verdict file whose line 1 is neither `PASS` nor `1.` is refused, so a vague verdict cannot be
   written.** How to verify: `verdict_of` (`tools/agents.py:158-164`).
9. **Each verdict file carries a trailer naming the commit, the date, the session cost and the turn
   count, and says the script wrote it.** How to verify: `trailer` (`tools/agents.py:191-195`) and
   its two call sites (`tools/agents.py:234`, `tools/agents.py:273-274`).
10. **The lint evidence matches CI.** How to verify: `build_evidence` (`tools/agents.py:91-99`) runs
    `selene src` + `selene --config tests/selene.toml tests` when `tests/selene.toml` exists, else
    `selene src tests`, plus `stylua --check src tests` and `rojo build`. `.github/workflows/ci.yml`
    on this branch runs `selene src tests` and `stylua --check src tests`; this branch has no
    `tests/selene.toml` (that is Task 10, `task-10-lint-test-globals`), so the fallback is what runs,
    and it matches CI exactly.
11. **The audit number is taken from git history as well as the working tree, so a rebuilt branch
    cannot reuse a number.** How to verify: `next_audit_number` (`tools/agents.py:239-243`) unions
    `glob` of `docs/architecture/audit-*.md` with `git log --all --name-only -- docs/architecture`.
12. **Both wrapper pairs are thin and delegate to `tools/agents.py`.** How to verify:
    `tools/review.sh` (5 lines), `tools/review.ps1` (4), `tools/architect.sh` (7),
    `tools/architect.ps1` (6). Each `cd`s to the repo root and execs
    `python tools/agents.py <command>`, and the `.ps1` twins propagate `$LASTEXITCODE`.
13. **CLAUDE.md now says the Director merges, on three conditions, and that Karen does not.** How to
    verify: `CLAUDE.md` rule 10; the DIRECTOR row and the KAREN row in the Roles table; the paragraph
    after that table ("Karen handed all git and GitHub work to the Director on 2026-09-24"); git
    workflow step 4 (the three bullets: Reviewer `PASS` on the PR head, green CI, clean-tree harness
    PASS naming the same commit); and the "what is enforced and what is policy" paragraph. No
    sentence anywhere in `CLAUDE.md` still says Karen merges — `grep -n "merge" CLAUDE.md`.
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

## Harness

```
[harness] PASS: 24/24 checks @ 6378a0787671b4a0622caee2dc0627c397fb8eae (clean tree)
```

Run on this branch at commit `6378a07` (exit 0). Only `REVIEW_REQUEST.md` changed after it — see
`.agent-evidence/request-only-diff.txt`.

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
