# Escalations

For the Director and Karen. The Builder (or any agent) writes here and stops when:
- the same item has failed 3 review rounds
- it believes the Reviewer or Architect is factually wrong
- a design, feel or scope decision is needed
- **a human action is needed** (Rojo **Connect**, the Studio MCP toggle, Studio not in Edit mode,
  anything only Karen can click). Head that entry **`NEEDS KAREN`** and list the exact clicks.

Newest first. The Director or Karen answers under each entry, and the entry is closed with a date.

---

## 2026-09-24 · OPEN · NEEDS KAREN · `rojo serve` is down; no task can be harness-tested

**Raised by:** Builder, during Task 19 (branch `task-19-shotgun-design`).

`rojo serve` crashed on 2026-09-24 during Task 17 and has not run since: no `rojo.exe`, nothing
listening on port 34872. It is the known Rojo 7.7.0 watched-file panic, and on that occasion **a large
branch switch alone was enough** — `git switch main && git pull` across 59 commits, no test, no
deletion. Studio itself is still open on the DEV place in **Edit** mode and its MCP server still
answers; only Rojo is down.

Per the overnight rules I have not restarted it, and restarting alone would not be enough: the Rojo
plugin's **Connect** button cannot be clicked by any tool.

**This entry exists on this branch because it was missing here.** Tasks 17 and 18 carry the same
entry, but they are on unmerged branches, so on `main` and on anything cut from it there was no record
of why no task has a harness line — which review round 1 of this task caught (finding 1). The harness
claim and the record must live in the same place.

### Exact clicks for Karen, in order

1. Open a terminal (PowerShell or Git Bash) in `C:\Users\karen\Desktop\driven-hunt`.
2. Run, and leave the window open:

   ```
   rojo serve default.project.json
   ```

   It should print that it is serving on `localhost:34872`. If `rojo` is not found, run
   `rokit install` first.
3. In Roblox Studio, with **Driven Hunt DEV** open in **Edit** mode: the **Plugins** tab → **Rojo**
   → **Connect**.
4. Rojo may show a confirmation dialog listing instances it will remove. It should name nothing
   outside the Rojo-owned containers. **Do not accept anything that names `Workspace.Baseplate` or
   `Workspace.SpawnLocation`** — those are yours and must stay (rule 7).
5. Nothing else.

**What is waiting on those clicks.** Task 17 (test arena) and Task 18 (boar AI) have never been
executed at all — no harness run, no screenshot. Task 19 is documents only and needs nothing from
Studio, but it cannot cite a harness line either, which is why it says N/A and points here.

**Needs:** Karen's clicks. Nothing here needs the Director.

---

## 2026-09-24 · OPEN · Task 11 round 4 (authorised) returned 5 findings

**Raised by:** Builder, at loop step 5 of Task 11 (branch `task-9-agent-workflow`, PR #4). The
Director's answer to the previous entry says: if round 4 fails, fix it, write an entry and stop. Do
not ask for round 5. That is what this is.

**Result.** Round 4 ran with `DIRECTOR_MAX_ROUNDS=4` (the notice is in the run log and in
`.agent-logs/`), reviewed `d624930`, and returned **5 findings**. All five are fixed in the commit
that carries this entry. **None of them is unreviewed policy or design; four are stale text.**

| # | Finding | Fix |
|---|---|---|
| 1 | Claim 19's "live proof" still described round 3's outcome ("`MAX_ROUNDS` refuses it ... escalated rather than reviewed a fourth time") while this *was* the fourth review | Rewritten: `expected` is 4, checked against `cap = max_rounds()`, and the run was accepted because `DIRECTOR_MAX_ROUNDS=4` raised the cap |
| 2 | Claim 16 still said `TASKS.md` row 16 is "blocked on Karen's map decision"; `8d0d06b` had unblocked it and claim 30 said so | Claim 16 corrected to "unblocked and not next" |
| 3 | **A real bug in `8d0d06b`.** `cmd_review` checked `cap = max_rounds()` but told the agent "round 4 of max `MAX_ROUNDS`" — so this session was told "round 4 of max 3". The `DIRECTOR_MAX_ROUNDS` notice goes only to stdout, which the agent never sees | `go()` now builds the task text from `cap`, and says "(default 3, raised by the Director)" when they differ (`tools/agents.py:317-324`) |
| 4 | `ESCALATE.md:28` still pointed at `tools/agents.py:28-31` and `CLAUDE.md:87-88`; `8d0d06b` moved both, and updated the identical references in `REVIEW_REQUEST.md` but not here | Updated to `tools/agents.py:31-34` and `CLAUDE.md:90-91` |
| 5 | Claim 29 said `ARCH_RESULT.md` is "untouched on this branch"; the evidence shows Task 9's `2958ab5` created it with the Builder-written `NONE` placeholder | Reworded to what is checkable: no audit ran for Task 11, and the file has not changed since `2958ab5` |

**What is now unreviewed.** The fixes above, and only them. Four are text in `REVIEW_REQUEST.md` and
`ESCALATE.md`. One is five lines of `tools/agents.py` (finding 3), added as claim 31a in
`REVIEW_REQUEST.md` and marked there as unreviewed.

**My own record, honestly.** Four of the five findings are the same class of mistake I made in
round 3: I edited some copies of a cross-reference or a claim and missed others. Rounds 3 and 4 have
now both been spent almost entirely on that. The mechanical cause is that `REVIEW_REQUEST.md`
accumulates claims across rounds, each carrying line numbers that every later commit invalidates.

**Options for the Director.**
1. **Merge on the record.** Rounds 1–4 found 15 items; all 15 are fixed. The only unreviewed code is
   finding 3's five lines, which make the Reviewer's own prompt honest and cannot affect the game.
   This breaks rule 10, so it needs a written Director decision.
2. **One more authorised round** (`DIRECTOR_MAX_ROUNDS=5`). Your answer to the last entry says not to
   ask for this, so I am not asking; I list it only because it is the option that ends with a real
   `PASS`. Cost: about $1.50–$2.00.
3. **Drop the accumulated claims.** Rewrite `REVIEW_REQUEST.md` for the final commit only — no
   round-by-round history, no line numbers that a later commit can invalidate — and review that.
   This removes the cause of rounds 3 and 4 but is still a review round.

**Builder's recommendation: option 1.** The residual risk is five lines that only change what the
Reviewer is told about its own round cap. Option 3 is the right shape for future tasks: if you want
it as a standing rule, `REVIEW_REQUEST.md` should describe the final state and cite symbols, not line
numbers. That is a `CLAUDE.md` change and tooling is frozen, so it is yours to decide, not mine.

**Also for the record:** `tools/architect.sh audit` was **not** run for Task 11, per your decision.
Nothing on this branch has been seen by the Architect.

**State.** Code commit `3da8fb8`, clean-tree harness PASS:
`[harness] PASS: 24/24 checks @ 3da8fb89100d8d7357e58ea73df1317051ff9d20 (clean tree)`.
Lint, format and `rojo build` clean. `task-9-agent-workflow` is pushed so PR #4 shows this state.
**`task-9` was NOT merged into `task-10-lint-test-globals`**: your dispatch gated that on a round-4
`PASS`, and there is none. PR #5 therefore still sits on the round-3 state of its base. Say the word
and it is one merge commit.

**Needs:** a Director decision. Nothing here needs Karen.

---

## 2026-09-24 · CLOSED 2026-09-24 · Task 11 reached round 3; the script refuses a fourth

**Raised by:** Builder, at loop step 5 of Task 11 (branch `task-9-agent-workflow`, PR #4).

**Situation.** Three review rounds ran. Nothing failed three times; each round found different
things, and every finding was fixed.

| Round | Commit reviewed | Verdict | What it found |
|---|---|---|---|
| 1 | `0362ee0` | 6 findings | the merge gate was unsatisfiable; the 3-round rule was self-reported; Task 11's extra scope had no record in the repo; the agent prompt was read from the working tree; the KAREN row never said she does not merge; the Layout table was stale |
| 2 | `20334d5` | 2 findings | both on round 1's fix to the round count: it was called tamper-proof but restoring the `NONE` placeholder would reset it; and `parse_trailer` took the **first** trailer-shaped line, so a Reviewer quoting an older trailer would set the round (a real bug I introduced) |
| 3 | `c36b22e` | 2 findings | both stale sentences in `REVIEW_REQUEST.md` claim 19, which I failed to update when I updated claims 24–25: it still said "the committed `REVIEW_RESULT.md` is round 1" and "which only this script writes". **No finding against the code.** |

All ten findings are fixed and committed. The round-3 two are fixed in the commit that carries this
entry; claim 19 now matches `tools/agents.py:31-34` and `CLAUDE.md:90-91`.

**Why I stopped.** `tools/review.sh` refuses `Round: 4` (`MAX_ROUNDS = 3`, `tools/agents.py:52`), and
the round is now counted from the committed `REVIEW_RESULT.md` trailer, so I cannot reset it — that is
the hardening round 2 asked for, and going around it is exactly what `CLAUDE.md` "What is enforced and
what is policy" forbids. So there is no way for me to obtain a `PASS` on the fixed commit. Per the
stop rule I wrote `ESCALATE.md` and stopped: **no Architect audit was run** (loop step 6 needs a PASS),
and nothing was merged.

**What is and is not verified.**
- Verified: the harness passes 24/24 on a clean tree at every code commit
  (`6378a07`, `9fe442c`, `b32ac5f`, and the final `be9d045`:
  `[harness] PASS: 24/24 checks @ be9d0453ac84a48b5f8c759901e95d239c0c34b6 (clean tree)`); lint,
  format and `rojo build` are clean; the round-count logic was exercised by hand across six states
  (see `REVIEW_REQUEST.md` claim 25).
- `be9d045` is after round 3's review. It adds `ESCALATE.md` to the merge gate's paperwork list in
  `CLAUDE.md` git-workflow step 4, which had omitted it — so this PR would have failed the gate it
  introduces. One line, unreviewed, and listed here because it is.
- Not verified: **there is no Reviewer `PASS` for this branch.** The last verdict is round 3 with two
  findings, and the fix for them is unreviewed.

**Options for the Director.**
1. **Authorise one more round** for this task, and record it. That means either raising `MAX_ROUNDS`
   for this run or accepting a reset, both of which are Director decisions, not mine. Cost: one more
   paid Reviewer session (rounds 1–3 cost $1.63, $2.16, $1.91).
2. **Accept the branch without a round-4 PASS**, on the record above: round 3 found nothing against
   the code, and its two findings were documentation errors in `REVIEW_REQUEST.md` that are now fixed.
   This breaks rule 10, so it has to be a written Director decision.
3. **Split Task 11** as round-1 finding 3 suggested: the Task 9 review in one PR, the merge-policy
   and `NEEDS KAREN` edits in another. A smaller change would review faster, but it re-runs all three
   rounds on two branches.

**Builder's recommendation: option 1.** The change is small and the outstanding delta is two sentences
in a review request. A fourth round confirms them and gives the branch a real `PASS`, which options 2
and 3 do not (2 skips it; 3 pays for six rounds).

**Also needed:** a standing decision on `MAX_ROUNDS`. Round 3 spent a whole paid session on stale text
in the Builder's own document. If the rule is meant to stop *repeated failure on the same item*, the
script should count that, not total rounds — but changing it is a workflow change and belongs in a
task of its own, not here.

**Needs:** a Director decision. Nothing here needs Karen.

### DIRECTOR's answer · 2026-09-24

**Option 1: one more review round (round 4) is authorised, for Task 11 only.**

- **Mechanism, kept minimal.** `tools/agents.py` reads an optional environment variable
  `DIRECTOR_MAX_ROUNDS` (integer, default `MAX_ROUNDS` = 3). It may be set **only** when this file
  records a Director authorisation for that task and that round. Round 4 of Task 11 is that
  authorisation. The change itself goes into the round-4 review.
- **Standing decision.** `MAX_ROUNDS` stays 3. The Director may authorise **one** extra round when the
  last round's findings were documentation-only; otherwise escalate as now. The round counting is
  **not** to be reworked — tooling is frozen (`ROADMAP.md` speed rule 1). This closes the Builder's
  "Also needed" question at the end of the entry: no, the script keeps counting total rounds.
- **No Architect audit for Task 11.** New speed rule (`ROADMAP.md` on `main`, PR #7): audits run every
  ~5 tasks, not per task. Loop step 6 is skipped for this task by Director decision, and `TASKS.md`
  row 11 records that.
- **Accepted:** the merge gate naming the reviewed **code commit** and allowing only loop paperwork
  after it. Good call.
- If round 4 fails: fix it, write an `ESCALATE.md` entry and stop. Do **not** ask for round 5.

**Closed** 2026-09-24 by the Director.

---

## 2026-09-24 · CLOSED 2026-09-24 · Audit-002 must-fix items are outside Task 10's scope

**Raised by:** Builder, at loop step 6 of Task 10 (branch `task-10-lint-test-globals`, head
`24fd22a` + the audit commit).

**Situation.** Task 10 (audit-001 L5) passed review in 2 rounds (`REVIEW_RESULT.md`: PASS on round 2).
The one-per-task Architect audit (`docs/architecture/audit-002.md`) returned 5 must-fix items
(`ARCH_RESULT.md`). I checked the evidence for each and believe all 5 are **valid**, but **none is in
Task 10's change**:

| # | Must-fix (audit-002) | Where it belongs | Decision needed? |
|---|---|---|---|
| 1 | Typed property values (Vector3, CFrame, Color3…) fail as "cannot compare", so no positioned geometry can come from disk | harness (`tools/studio_mcp.py`), before the first grey-box geometry | **Yes, partly design.** Either support typed values in the harness, or decide that geometry lives elsewhere (Workspace built in Studio; templates as `.model.json` with typed values). The Architect owns the structure; this probably needs `tools/architect.sh design geometry-on-disk` first |
| 2 | The unmanaged scan checks only scripts, so a Studio-made non-script instance in a Rojo-owned container passes, then vanishes at the next Connect | harness | No: Builder work |
| 3 | `tools/agents.py` (the four-agent gate) has no research note (rules 1, 2, 9) | Task 9 | No: Builder work |
| 4 | The Architect audits blind: earlier audits are not on this branch (audit-001 is only on PR #2) and are not in its evidence | Task 9 (`tools/agents.py` evidence), and PR #2's merge order | No: Builder work, plus merge order |
| 5 | `ARCH_RESULT.md`/`REVIEW_RESULT.md` got a Builder-written `NONE` placeholder, although only the scripts may write them; nothing ties a verdict to the merged commit; a dirty-tree audit writes an unqualified verdict | Task 9 | No: Builder work |

**The conflict.** CLAUDE.md's loop says "must-fix → fix, back to 4". Rule 4 says "one task per round, nothing
extra", and PROJECT_CONTEXT.md warns that big multi-item rounds hid failures. Folding 5 unrelated fixes
into Task 10 would make it a multi-item round about the harness and the workflow, not about L5. Choosing
between those two rules is a scope decision, so it is the Director's.

**Builder's proposal.**
- Close Task 10 as done (its own change passed review).
- Queue audit-002 must-fix items as five separate small tasks, 11–15 in `TASKS.md`, each through the full
  loop, **all before any game code**. Suggested order: 5, 4, 3 (they fix the workflow itself), then
  2, then 1 (after an Architect design for geometry on disk).
- Merge order suggestion: PR #2 (audit-001) early, so every later branch has `docs/architecture/`.

**Needs:** a Director decision (and Karen, if item 1's geometry question touches how she wants to
build the map).

### DIRECTOR's answer · 2026-09-24

Accepted as proposed, with one task added in front. Task 10 is **closed as done**: its own change
passed review. The five must-fix items become their own tasks, each through the full loop, all before
any game code, in this order (see `TASKS.md`):

| # | Task |
|---|---|
| 11 | Review Task 9 itself through the loop, and fix the findings |
| 12 | audit-002 #5: only the scripts write the verdict files; each verdict is tied to a commit; a dirty-tree audit verdict is marked as such |
| 13 | audit-002 #4: the Architect sees earlier audits |
| 14 | audit-002 #3: research note for `tools/agents.py` |
| 15 | audit-002 #2: detect Studio-made **non-script** instances in Rojo-owned containers |
| 16 | audit-002 #1: typed property values. **BLOCKED** on Karen's map decision (build the map in Studio, or everything on disk). Architect design first |

**Standing decision for every future audit.** A must-fix item **outside** the current task's change is
queued as its own task in `TASKS.md` and listed in the Builder's report. It is not an escalation, and it
is not fixed in the current task. Must-fix items **inside** the change are fixed as the loop says.

**Closed** 2026-09-24 by the Director. No open escalations remain.

#### Task 11's dispatch, verbatim (transcribed by the Builder, 2026-09-24)

The Director dispatched Task 11 in the same message, outside the repo. Its scope is more than
"review Task 9", so it is recorded here rather than inferred from a Builder-written `TASKS.md` row
(review round 1, finding 3):

> TASK 11: Task 9 (the four-agent workflow, PR #4) never went through the loop itself. Do that now.
> 1. Work on branch task-9-agent-workflow (PR #4). First merge origin/main into it (a merge, not a
>    rebase; no force pushes) so it is current with main.
> 2. Also in this task, update CLAUDE.md to the new policy: the Director (agent) retargets and merges
>    PRs after Reviewer PASS on the PR head, green CI and a clean-tree harness PASS naming that
>    commit; Karen no longer merges; the Builder still never merges. Update the KAREN and DIRECTOR
>    rows and the git-workflow section to match. Also add the stop case "a human action is needed
>    (Rojo Connect, Studio MCP toggle, anything only Karen can click)": write it in ESCALATE.md headed
>    "NEEDS KAREN" with the exact clicks, then stop.
> 3. Run the loop on the whole Task 9 change (git diff origin/main...HEAD) plus the edits above:
>    REVIEW_REQUEST.md, tools/review.sh, fix, repeat until PASS. Then one Architect audit; handle its
>    items per the standing decision above.
> 4. Push task-9-agent-workflow. Then merge task-9-agent-workflow into task-10-lint-test-globals
>    (merge, no rebase) and push, so PR #5 stays current. Put the ESCALATE.md answer and TASKS.md rows
>    on whichever branch lands first (task-9), not only on task-10.
> 5. If Studio is not in Edit mode, Rojo is not connected, or the MCP server is off, and you cannot
>    fix it yourself: NEEDS KAREN entry, stop.

**Builder's note on item 2.** "Reviewer PASS on the PR head" as written cannot hold: loop steps 5 and
6 commit `REVIEW_RESULT.md`, `ARCH_RESULT.md` and the audit document *after* the reviewed commit, so
the head always moves past it (review round 1, finding 1). The gate in `CLAUDE.md` git-workflow step 4
therefore names the **code commit** and bounds what may follow it (paperwork only). Same intent,
satisfiable. Flagged to the Director in the Task 11 report.
