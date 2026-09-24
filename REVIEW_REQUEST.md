# Review request

Written by the Builder for `tools/review.sh`. The format is below; the script parses the first three lines.

Round: 4 (authorised by the Director; see ESCALATE.md, closed 2026-09-24)
Base: `4fcff0f`
Code commit: `8d0d06b5065882a31fc571f349fda56a5b1e123d`

## Task
Task 11 (`TASKS.md`): run Task 9 (the four-agent workflow) through the loop itself. Task 9 was built
and pushed as PR #4 but never reviewed. This round reviews **the whole Task 9 change** plus the
policy edits Task 11 adds. Task 11's scope is the Director's, transcribed verbatim in `ESCALATE.md`
("Task 11's dispatch, verbatim").

Scope of this review = `git diff 4fcff0f...HEAD` (`.agent-evidence/diff.patch`). That is Task 9's two
commits (`2958ab5`, `0fa7c2b`) plus `145656f` (merge of `main`, which only adds
`docs/architecture/audit-001.md`), `6378a07` (the Task 11 policy edits), `9fe442c` (the round-1
fixes), `e4cadc0` (the round-2 fixes), `b32ac5f` (one refusal message reworded), `de13f58` (the
round-3 fixes), `be9d045` (`ESCALATE.md` added to the merge gate's paperwork list), `bc1f27b` (merge
of `main`, which adds only `ROADMAP.md`) and `8d0d06b` (the Director's round-4 decisions).
Claims 1–17 are round 1's, updated where later fixes moved lines; claims 18–23 are the six round-1
findings; claims 24–25 the two round-2 findings; claims 26–31 the round-4 change.

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

**Task 11, rounds 1–4 (commits `9fe442c`, `e4cadc0`, `b32ac5f`, `de13f58`, `be9d045`, `8d0d06b`):**
- `tools/agents.py` — the round is counted from the committed `REVIEW_RESULT.md` trailer (last match,
  with a git look-back for a deleted trailer); the agent prompt is read from the worktree; the cap is
  `max_rounds()`, which honours the Director's `DIRECTOR_MAX_ROUNDS` override.
- `CLAUDE.md` — the merge gate names the **code commit** and bounds what may follow it; the stop rule
  describes what is and is not enforced, plus the authorised-extra-round rule; loop step 6 is
  audits every ~5 tasks; the Builder may transcribe a Director dispatch into `TASKS.md`; the Layout
  table's `docs/` and `tools/` rows are current; the KAREN row's Never column says she does not merge.
- `ESCALATE.md` — Task 11's dispatch transcribed verbatim; the round-3 escalation and the Director's
  answer, closed.
- `TASKS.md` — rows 11–16 per the Director's decisions.
- Merged `origin/main` twice (`145656f`, `bc1f27b`), bringing `docs/architecture/audit-001.md` and
  `ROADMAP.md`.

## Claims

1. **`tools/agents.py` gives the agent exactly Read, Grep and Glob, and no way to write or run
   commands.** How to verify: `tools/agents.py:169-170` — `cmd = [claude, "-p", prompt, "--restricted",
   "--tools", "Read,Grep,Glob", "--permission-mode", "dontAsk", "--strict-mcp-config",
   "--no-session-persistence", "--output-format", "json"]`. The reason each flag is there is the
   docstring, `tools/agents.py:11-21`.
2. **The agent never writes the verdict files; the script does.** How to verify: the only writes are
   `write(...)` calls in `cmd_review` (`tools/agents.py:327`) and `cmd_architect`
   (`tools/agents.py:365-367`), fed from `block(text, ...)` — text parsed out of the agent's stdout.
   The agent has no Write/Edit tool (claim 1).
3. **The agent reads a throwaway worktree of the committed HEAD, not the working tree.** How to
   verify: `class Worktree` (`tools/agents.py:246-256`) does `git worktree add --detach <tmp> HEAD`,
   and `run_agent` passes `cwd=wt` (`tools/agents.py:172`) and now also reads the prompt from it
   (`tools/agents.py:160-164`). `__exit__` removes it and prunes.
4. **Nothing is written if the repo changed while the agent ran.** How to verify: `guarded`
   (`tools/agents.py:259-265`) snapshots `repo_state()` (HEAD + `git status --porcelain`) before, and
   raises `Refused` if it differs after. Both `cmd_review` and `cmd_architect` call it.
5. **The review is refused on a dirty tree, and refused past the round cap.** How to verify:
   `cmd_review` (`tools/agents.py:278-280`) raises `Refused` when `git status --porcelain` is
   non-empty; `tools/agents.py:311-313` raises when `Round: N` > the cap from `max_rounds()`
   (`MAX_ROUNDS = 3`, `tools/agents.py:52`), pointing at `ESCALATE.md`. This is the stop rule in
   `CLAUDE.md` ("Stop rules", first bullet). Round 4 is over the default cap and runs only because
   the Director authorised it: see claim 26.
6. **The Reviewer is shown, as precomputed evidence, whether anything but `REVIEW_REQUEST.md`
   changed after the harness-tested commit.** How to verify: `build_evidence`
   (`tools/agents.py:134-143`) writes `.agent-evidence/request-only-diff.txt` with the file list
   between `Code commit:` and HEAD and an explicit "OK"/"NOT OK" line;
   `docs/REVIEWER_PROMPT.md` ("What you cannot check") tells the Reviewer to use it.
7. **A `REVIEW_REQUEST.md` without `Round:`, `Base:` or `Code commit:` is refused, and both commits
   must exist.** How to verify: `tools/agents.py:286-314` — the three regexes, the two
   `git rev-parse --verify <sha>^{commit}` calls (which raise `Refused` on failure through
   `run(..., check=True)`).
8. **A verdict file whose line 1 is neither `PASS` nor `1.` is refused, so a vague verdict cannot be
   written.** How to verify: `verdict_of` (`tools/agents.py:193-199`).
9. **Each verdict file carries a trailer naming the commit, the date, the session cost and the turn
   count, and says the script wrote it.** How to verify: `trailer` (`tools/agents.py:268-272`) and
   its two call sites (`tools/agents.py:327`, `tools/agents.py:366-367`).
10. **The lint evidence matches CI.** How to verify: `build_evidence` (`tools/agents.py:124-132`) runs
    `selene src` + `selene --config tests/selene.toml tests` when `tests/selene.toml` exists, else
    `selene src tests`, plus `stylua --check src tests` and `rojo build`. `.github/workflows/ci.yml`
    on this branch runs `selene src tests` and `stylua --check src tests`; this branch has no
    `tests/selene.toml` (that is Task 10, `task-10-lint-test-globals`), so the fallback is what runs,
    and it matches CI exactly.
11. **The audit number is taken from git history as well as the working tree, so a rebuilt branch
    cannot reuse a number.** How to verify: `next_audit_number` (`tools/agents.py:332-336`) unions
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
    verify: the `TASKS.md` table rows 10–16. Row 16 is **unblocked and not next** since `8d0d06b`
    (Karen chose map option C); claim 30 covers rows 11–16 as they now stand.
17. **The change adds no Luau code and no script outside Rojo-managed paths.** How to verify:
    `.agent-evidence/changed-files.txt` — no file under `src/` or `tests/` changes; the only new
    executables are `tools/*.sh`, `tools/*.ps1` and `tools/agents.py`, which `default.project.json`
    does not map.

## Round 2: the six round-1 findings

Fixed in `9fe442c`. The finding numbers are round 1's.

18. **Finding 1 — the merge gate was unsatisfiable.** Agreed, and the Reviewer's reasoning is right:
    loop steps 5 and 6 commit `REVIEW_RESULT.md`, `ARCH_RESULT.md` and the audit document *after* the
    reviewed commit, so the head always moves past it, and `trailer` fixes the verdict to the commit
    reviewed (`tools/agents.py:268-272`, `tools/agents.py:327`). Fix: the gate is written against the
    PR's **code commit**, and bounds what may follow it. How to verify: `CLAUDE.md` git-workflow
    step 4 — the definition of "code commit", the four bullets, and the paragraph after them
    explaining why the head is necessarily ahead. Rule 10 (`CLAUDE.md:30-32`) and the first line of
    the definition of done now say "code commit" too. The gate is satisfiable for this very PR: see
    the Harness section below.
19. **Finding 2 — the 3-round stop rule was self-reported.** Agreed. Fix: the round is now taken from
    the committed `REVIEW_RESULT.md` trailer, which `trailer()` writes, instead of from the
    Builder-written `REVIEW_REQUEST.md`, so it cannot be raised, skipped or reset from the request
    (round 2 added the look-back that also catches deleting the trailer). It is **not** tamper-proof:
    the Builder writes the repo's commits, so a hand-written trailer or a history rewrite still gets
    past it, and the verdict files stay protected by policy alone until audit-002 must-fix #5
    (Task 12). That is exactly what `tools/agents.py:31-34` and `CLAUDE.md:90-91` say; this claim
    said "only this script writes" until round 3's finding 2. How to verify:
    `previous_review` (`tools/agents.py:218-228`) and `parse_trailer` (`tools/agents.py:205-215`)
    read `TRAILER_RE` (`tools/agents.py:202`) and the verdict from the body above it; `cmd_review`
    (`tools/agents.py:296-310`) requires `Round: N` == previous round + 1, or 1 when the previous
    verdict was `PASS` or there is no verdict yet, and refuses otherwise. Reading from the working
    tree is safe because `tools/agents.py:278-280` has already refused a dirty tree. Round 2's two
    findings hardened this further: see claims 24 and 25.
    **This run is the live proof:** the committed `REVIEW_RESULT.md` is round 3 with findings
    (the trailer on commit `c36b22e` says round 3), so `previous_review()` returns `(3, FINDINGS)`
    and `expected` is 4. `expected` is checked against `cap = max_rounds()`
    (`tools/agents.py:311-313`), not against `MAX_ROUNDS`, and this run was accepted because the
    Director's `DIRECTOR_MAX_ROUNDS=4` raised that cap — see claim 26. Under the default cap of 3 it
    would have been refused, which is what produced the escalation whose answer authorised this
    round. Rounds 2 and 3 were each accepted only because the committed verdict named the round
    before them.
    `CLAUDE.md` loop step 5 now tells the Builder to commit `REVIEW_RESULT.md` on findings too,
    which the round count depends on.
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
    (`tools/agents.py:160-164`), so both agents' prompts come from the commit under review. The
    `cmd_architect` dirty-tree note is true as written again.
22. **Finding 5 — the KAREN row said nothing about merging.** Fixed: its Never column reads
    "merges PRs (handed to the Director on 2026-09-24)" (`CLAUDE.md:44`).
23. **Finding 6 — the Layout table was stale.** Fixed: the `docs/` row names `PROJECT_CONTEXT.md`,
    `research/`, `design/`, `architecture/` and the two prompts; the `tools/` row separates
    `studio_mcp.py` (test harness) from `agents.py` plus the four wrappers (the Reviewer and
    Architect gate). `CLAUDE.md:226-227`.

## Round 3: the two round-2 findings

Fixed in `e4cadc0`, with one follow-up wording commit `b32ac5f`. Both findings were about round 1's
fix to the round count, and both were right.

24. **Round-2 finding 1 — the round check was called tamper-proof and was not.** Agreed. A Builder
    could have committed the `NONE` placeholder back over the verdict file, and the check would have
    read "no verdict yet" and accepted `Round: 1`. Two changes:
    - **The hole is closed for that path.** `last_committed_review` (`tools/agents.py:231-243`) walks
      `git log --format=%H -50 -- REVIEW_RESULT.md` and `git show <sha>:REVIEW_RESULT.md` until it
      finds a trailer. `cmd_review` (`tools/agents.py:296-302`) refuses when the working-tree file
      has no trailer but history recorded one, naming the commit.
    - **What remains is stated plainly**, as the Reviewer asked: `tools/agents.py:31-34`
      ("What is still policy, not enforcement": a hand-written trailer, or a history rewrite);
      `CLAUDE.md:87-91` (the stop rule now says "It is **not** tamper-proof"); and a new paragraph in
      "What is enforced and what is policy", `CLAUDE.md:175-179`, which ties the remainder to
      audit-002 must-fix #5 (Task 12).
25. **Round-2 finding 2 — the first trailer-shaped line won, so a quoted trailer set the round.**
    Agreed; this was a real bug introduced in round 1. `TRAILER_RE` is `re.M`-anchored, the Reviewer's
    free text sits above the real trailer, and a Reviewer quoting an older trailer as evidence (which
    is exactly what round 2's own finding did) would have won the `search`. Fix: `parse_trailer`
    (`tools/agents.py:205-215`) takes `list(TRAILER_RE.finditer(text))[-1]` — the last match, which
    is the one `trailer()` appends — and slices the body at that match.

    Checked by hand in a throwaway git repo, with `agents.REPO`, `agents.git.__kwdefaults__` and
    `agents.run.__defaults__` pointed at it:

    | state of REVIEW_RESULT.md | result |
    |---|---|
    | fresh branch (`NONE` placeholder, no history) | next `Round: 1` |
    | round 1, findings | next `Round: 2` |
    | round 3, findings | next `Round: 4` → `MAX_ROUNDS` refuses → escalate |
    | placeholder committed back over round 3 | **refused**, naming the commit that recorded round 3 |
    | `PASS` at round 2 | next `Round: 1` (a new task) |
    | findings body quoting an older trailer at line start, real trailer round 3 | reports round 3 |

## Round 4: the two round-3 findings, and the Director's decision

Round 3's two findings were stale sentences in this file's claim 19; both are fixed in `de13f58`
(claim 19 above now names `tools/agents.py:31-34` and `CLAUDE.md:90-91`, and the "live proof"
sentence names the actual round). Round 3 found **nothing against the code**, so the Director
authorised one extra round and made three decisions, which `8d0d06b` implements.

26. **Round 4 runs only because the Director authorised it, through `DIRECTOR_MAX_ROUNDS`.**
    `MAX_ROUNDS` stays 3 (`tools/agents.py:52`). How to verify: `max_rounds()`
    (`tools/agents.py:61-77`) returns `MAX_ROUNDS` unless `DIRECTOR_MAX_ROUNDS` is set in the
    environment; `cmd_review` uses it at `tools/agents.py:311-313`. The override
    - must be 1-2 digits, else `Refused`;
    - **may only raise** the cap: a value below `MAX_ROUNDS` is `Refused`;
    - prints itself and the authorisation requirement when used;
    - is an environment variable, so it cannot be committed by accident and does not survive the run.

    Checked by hand: unset gives 3; empty gives 3; `4` gives 4 with the notice; `3` gives 3; `2` is
    refused ("may only raise the cap"); `x` is refused; `999` is refused. This run was invoked as
    `DIRECTOR_MAX_ROUNDS=4 powershell -ExecutionPolicy Bypass -File tools/review.ps1`, so the notice
    is in `.agent-logs/`, and `Round: 4` at the top of this file was accepted only because of it.
27. **The rule for using it is written down.** How to verify: `CLAUDE.md` "Stop rules", the indented
    paragraph under the first bullet ("One extra round, by Director authorisation only"):
    `MAX_ROUNDS` stays 3; the Director may authorise **one** extra round when the last round's
    findings were documentation-only; it may be set only when `ESCALATE.md` records that
    authorisation for that task and that round; a failing authorised round is an `ESCALATE.md` entry,
    not a request for another. `tools/agents.py:28-30` says the same in the docstring.
28. **The escalation is answered and closed on this branch.** How to verify: `ESCALATE.md`, entry
    "2026-09-24 CLOSED 2026-09-24 Task 11 reached round 3", section "DIRECTOR's answer 2026-09-24".
    It records option 1, the mechanism, the standing decision (`MAX_ROUNDS` stays 3 and the round
    counting is **not** reworked, tooling being frozen per `ROADMAP.md` speed rule 1, which also
    answers the "Also needed" question I raised in the entry), no Architect audit for Task 11, and
    acceptance of the code-commit merge gate.
29. **Loop step 6 now says audits run every ~5 tasks, and Task 11's is skipped.** How to verify:
    `CLAUDE.md` loop step 6, rewritten so that an item is must-fix only if it blocks the next game
    task and the audit names it (`ROADMAP.md` speed rules 2 and 3), and the "Costs" bullet, which no
    longer says "once per task". `TASKS.md` row 11 records that the step-6 audit is skipped by
    Director decision. **No `tools/architect.sh audit` was run for Task 11.** `ARCH_RESULT.md` has
    not changed since Task 9's commit `2958ab5`, which created it with the Builder-written `NONE`
    placeholder (`.agent-evidence/changed-files.txt` shows it as added against the base, because the
    base is `main`, where the file does not exist). That placeholder is audit-002 must-fix #5,
    Task 12, "before release".
30. **`TASKS.md` matches the Director's queue decisions.** How to verify: rows 12-15 are
    **before release** ("Not next", `ROADMAP.md` speed rule 1: tooling is frozen after Task 11);
    row 16 is "unblocked, not next" and records that Karen chose **map option C** - the map is built
    by a map generator in code, run in Edit mode through Studio MCP, with templates on disk
    (`ROADMAP.md` Milestone 2, and the v1 scope row "One small map ... built by a map generator
    through MCP"), so the harness must compare typed values on those templates, and an Architect
    design comes first. Row 11 is "awaiting review (round 4)".
31a. **The Reviewer is told the cap actually in force.** Round 4's finding 3: the task text said
    "round 4 of max 3" because it used `MAX_ROUNDS` while the check used `cap = max_rounds()`. Fixed:
    `cmd_review`'s `go()` now builds the text from `cap`, and says "(default 3, raised by the
    Director)" when the two differ (`tools/agents.py:317-324`). The `DIRECTOR_MAX_ROUNDS` notice at
    `tools/agents.py:75-76` goes only to stdout and `.agent-logs/`, which the agent never sees, so
    the task text was the only place it could learn the cap. **This claim is unreviewed** — see
    `ESCALATE.md`.
31. **`main` is merged in, so the branch has `ROADMAP.md`.** How to verify: `bc1f27b` is a merge
    commit of `origin/main` (PR #7) and adds only `ROADMAP.md`; `.agent-evidence/log.txt`. No rebase,
    no force push.

## Harness

```
[harness] PASS: 24/24 checks @ 8d0d06b5065882a31fc571f349fda56a5b1e123d (clean tree)
```

Run on this branch at the code commit `8d0d06b` (exit 0). Only `REVIEW_REQUEST.md` changed after it:
see `.agent-evidence/request-only-diff.txt`. Earlier rounds ran the same harness at `6378a07`,
`9fe442c`, `b32ac5f` and `be9d045`, all 24/24.

**This is the authorised final round.** If it returns findings, I fix them, write an `ESCALATE.md`
entry and stop; I do not ask for a round 5 (`ESCALATE.md`, the Director's answer, last bullet).

## Could not verify

- **The merge policy itself is policy, not enforcement.** Nothing in the repo or in GitHub stops the
  Builder merging; `CLAUDE.md` says so explicitly. This change does not add enforcement, and cannot:
  the GitHub ruleset has 0 required approvals and the Reviewer has no GitHub account.
- **`DIRECTOR_MAX_ROUNDS` is not enforced either.** Nothing in the script checks that `ESCALATE.md`
  really holds an authorisation for the task and round: the Builder could set the variable without
  one. It is written as policy (`CLAUDE.md` "Stop rules"), it can only raise the cap, and it
  announces itself in the run log so a reader can see it was used. Making it verifiable would mean
  parsing `ESCALATE.md`, which is more tooling, and tooling is frozen (`ROADMAP.md` speed rule 1).
- **The read-only claims about the `claude` CLI flags (claim 1) were tested by the Task 9 Builder on
  2026-09-24 against Claude Code 2.1.270** and written up in the `tools/agents.py` docstring. I did
  not re-run that experiment. A future CLI version could change the behaviour of `--restricted` or
  `--tools`, and nothing here would notice.
- **`tools/agents.py` has no research note** (CLAUDE.md rules 1, 2, 9). audit-002 must-fix #3,
  **Task 14**, now "before release" by Director decision. Deliberately not fixed here.
- **The `NONE` placeholder in `ARCH_RESULT.md` was written by the Builder**, although only the
  scripts may write that file. audit-002 must-fix #5, **Task 12**, "before release". Not fixed here.
- **The Architect still does not get earlier audits in its evidence.** audit-002 must-fix #4,
  **Task 13**, "before release". `docs/architecture/audit-001.md` is on the branch (from `main`), but
  the evidence index still does not name it.
- **No Architect audit ran for this task at all**, by Director decision recorded in `ESCALATE.md` and
  `TASKS.md` row 11. So nothing in this change has been looked at by the Architect.
- **The round-cap logic (claims 19, 24, 25, 26) is exercised by hand, not by a test.** There is no
  Python test path in this repo: `tests/` is TestEZ Luau running inside Studio. The gap is real and
  not fixed here (tooling frozen). The live path *is* exercised by this PR: rounds 2 and 3 were
  accepted only because the committed verdict named the round before, and round 4 only because the
  Director's override raised the cap.
- **The look-back reads at most 50 commits** (`HISTORY_SCAN`, `tools/agents.py:53`) of
  `REVIEW_RESULT.md`'s history, reachable from HEAD only. A rewritten history defeats it.
- **CI status was not checked**: `gh` is not on PATH on this machine and the Builder has no other
  GitHub client. The Director checks CI before merging.
- **The scope decision in round-1 finding 3 is the Director's, not mine.** I recorded the dispatch
  verbatim in `ESCALATE.md` instead of splitting the task.
- **No screenshot** (CLAUDE.md rule 5): nothing visual changed. No `src/` or `tests/` file changed in
  the whole branch.
