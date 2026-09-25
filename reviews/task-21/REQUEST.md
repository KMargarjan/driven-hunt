# Task 21 — trim the review loop

Task: 21
Round: 1
Base: `f598363`
Code commit: `1bafaa8a10d53598e40d60976a76c560b6b65eb9`

Harness, on the clean tree, on that commit:

```
[harness] PASS: 24/24 checks @ 1bafaa8a10d53598e40d60976a76c560b6b65eb9 (clean tree)
```

## Task

Karen, through the Director: **less Reviewer noise, faster.** Workflow only, no game code. Allowed
past the tooling freeze because it slows every game task. The dispatch is transcribed verbatim in
`TASKS.md` under "Task 21 · 2026-09-25", with one deviation marked there (see claim 4).

Evidence behind it: Tasks 11, 18, 19 and 20 all hit the round cap mostly on prose; Task 18 was
reviewed three rounds before its code had ever run, and the first real run then failed three specs;
every branch conflicted on the same three root files; and Task 22 could not be reviewed at all.

**This request is reviewed under the new rules** (`docs/REVIEWER_PROMPT.md` in this commit): only the
game, a test, an owner boundary, security or a false claim about what was tested blocks. Everything
else is a note, and notes do not hold the change up.

## Claims

1. **The round count is per task, and that is what fixes Task 22's fault.** `previous_review(task)`
   and `last_committed_review(task)` in `tools/agents.py` read `reviews/task-<N>/RESULT.md` and that
   file's own git history. `cmd_review` computes `expected` from them. **Verify:** no path in either
   function is global any more; and the tamper check still fires — a task whose RESULT.md once had a
   trailer and now has none is refused.

2. **Harness before review.** `harness_gate` in `tools/agents.py` lists the files changed between
   `Base` and HEAD, keeps those under `CODE_PATHS`, and refuses unless `HARNESS_RE` finds a line in
   the request whose sha prefixes the resolved `Code commit:`. **Verify:** `HARNESS_RE` requires
   `PASS`, `checks @ <sha>` and `(clean tree)`, so a FAIL line, a dirty-tree line or a line for
   another commit cannot satisfy it. I checked those three rejections and the accept case directly
   against the compiled regex before committing.

3. **Docs-only changes stay exempt**, because the harness says nothing about them: `harness_gate`
   returns early when no changed file is under `CODE_PATHS`, printing that it did.

4. **One deliberate widening of the dispatch:** `CODE_PATHS = ("src/", "tests/", "tools/")` — the
   dispatch named only `src/` and `tests/`. `tools/studio_mcp.py` *is* the harness, and the dispatch's
   own step 5 says this task's tooling change must be harness-tested, so tooling is exactly the kind
   of change that must run before it is judged. Recorded in `TASKS.md` as a Builder's note under the
   dispatch.

5. **The Reviewer prompt separates blocking from notes.** `docs/REVIEWER_PROMPT.md` has a "Blocking,
   or a note" section listing five blocking classes and everything else as notes, says the five
   process files are context and never deliverables, and its output format shows `PASS` on line 1 with
   `## Notes (non-blocking)` under it. `verdict_of` in `tools/agents.py` already reads only line 1, and
   `parse_trailer` records such a verdict as `PASS`; I checked both against a PASS-with-notes body.

6. **One folder per task, and nothing was deleted.** `reviews/task-<N>/{REQUEST,RESULT,ARCH_RESULT}.md`,
   resolved by `resolve_task` (explicit argument, else the most recently committed request, else the
   filesystem) and written by `cmd_review` / `cmd_architect`. The three root files moved to `backups/`
   with `git mv`, so `git log --follow` still reaches their whole history; `backups/README.md` has the
   log line (rule 7).

7. **The Architect now writes into the task's folder**, so `--task N` is required:
   `cmd_architect(mode, task, system)`, with `take_task_flag` accepting `--task N` or `--task=N` in any
   position. Both wrappers pass arguments through unchanged, and their usage comments say so.

8. **The evidence file stopped lying.** `build_evidence` writes
   `paperwork-after-code-commit.txt` instead of `request-only-diff.txt`, classifying each file changed
   after the code commit with `is_paperwork` — the same list CLAUDE.md's merge gate names. It said
   "NOT OK" for paperwork the gate allows, which is what review round 4, finding 9 was about.

9. **CLAUDE.md says all of this**, in rule 10, the two role tables, the loop steps 3–5, the stop
   rules, the agent-script commands, git workflow step 4, "what is enforced and what is policy", the
   definition of done and the layout table. **Verify:** no reference to a root `REVIEW_REQUEST.md`,
   `REVIEW_RESULT.md` or `ARCH_RESULT.md` survives in `CLAUDE.md`, `docs/REVIEWER_PROMPT.md`,
   `docs/ARCHITECT_PROMPT.md` or the four wrapper scripts.

10. **The Director's three extras are in this commit**, all documents: `TASKS.md` row 17's leftover
    Karen question struck through (not deleted) and marked closed; the stale present-tense "is coplanar
    with the default `Workspace.Baseplate`" sentence in `docs/research/2026-09-24-boar-ai.md` §4
    corrected to what Task 22 did; and the `Texture` / `Decal` property rows added to
    `backups/2026-09-25_workspace-defaults.md`, read from the live place before Rojo removes
    `ServerStorage.Archive`.

## What I could not verify

- **This review is the test of the change.** The new gates are exercised by this run itself: round 1
  with no `DIRECTOR_MAX_ROUNDS` (which the old code could not do), the harness gate satisfied by the
  line above, and the verdict written to `reviews/task-21/RESULT.md`. What no run here can show is a
  *later* task inheriting a FINDINGS verdict cleanly; that is claim 1 by construction.
- **No Luau changed**, so the harness PASS above proves only that nothing regressed. There is no
  automated test of `tools/agents.py` itself (Task 14 queues its research note; the repo has no Python
  test harness). My checks of the regex, the paperwork classifier, the trailer parser and the flag
  parser were run by hand against the committed module.
