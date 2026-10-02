# Task 113 — review and test only what changed, plus its blast radius

Task: 113
Round: 2
Base: `0cc60ca`
Code commit: `<round 2's code commit — the Director's gate run names it>`

Tools and docs only: no `src/`, no `tests/`. Karen, 2026-10-02: *"not need start from zero I
mentioned 100 times / it has to test only parts what has been changed and what blast radius could
be."*

```
[harness] PASS: n/n checks @ <code commit> (clean tree) scope=all      <- the Director runs this
```

Round 1 ran `[harness] PASS: 32/32 checks @ d82e675 (clean tree) scope=all`. **`test2` is N/A**, and
the Director accepted both judgement calls behind that: nothing here touches the match, the drive,
the tie or the teams (`TWO_PLAYER_PATHS`), with `src/server/Weapon/SafetyArc.luau` out of that list
and `tools/studio_mcp.py` out of it too (claim 7; the gap that leaves is queued as 113a(d)).

## Claims, each with how to verify it

1. **The Reviewer no longer reads CLAUDE.md or PROJECT_CONTEXT.** `docs/REVIEWER_RULES.md` (61
   lines) carries the blocking rule, the owner boundaries, security, rule 5 and how the Reviewer
   works; `docs/REVIEWER_PROMPT.md` and `cmd_review`'s task text in `tools/agents.py` send it there
   and forbid the two long files. Verify: read the digest against the four blocking kinds in the
   prompt, and the "Read, in this order" text in `cmd_review`. Measured: 605 lines / 47,334 bytes of
   fixed reading become 61 / 4,330 — 91% less, ~10.7k tokens a round.
2. **The Reviewer's scope is the change plus its blast radius.** `blast_radius_text` writes
   `.agent-evidence/blast-radius.md`: the changed files, the symbols whose definition the diff added
   **or removed** (`symbols_in_diff`), the names other files `require` (`module_names` — a folder's
   name for an `init.luau`), and **every file in the repo's code that names one, with how many of its
   lines do** (`reference_hits`, rendered by `blast_radius_report`). **Round 1's blocking finding is
   fixed here: no file is cut.** The cap (`MAX_QUOTED_LINES_PER_SYMBOL`) now bounds only the quoted
   sample; the heading prints the true total and the file count, the file list is complete with
   per-file counts, and the quoted block says "12 of 48 line(s) quoted; the other 36 are in the files
   above". Verify: `reference_hits` (pure — no git, no filesystem) and `blast_radius_report` (pure),
   the 9 selftest cases that drive a symbol with 40 hits in 20 files against a cap of 12, and the
   "What you review" section of the prompt. Mutation check: putting the old early-exit back
   (`if len(info["lines"]) >= MAX_QUOTED_LINES_PER_SYMBOL: continue` before `total += 1`) fails 5 of
   those cases — the heading goes back to "12 reference(s) in 6 file(s)" — and it was restored.
   `references` scans code and config only, because a symbol like `Body` matches English prose in
   `TASKS.md`.
3. **`test --scope auto` decides whether Play happens.** `BLAST_RADIUS` maps a changed path to a
   scope name, `SCOPE_SPECS` maps the name to spec files, and `run_test` skips Play when no spec is
   in the radius — keeping every Edit-place check. Verify: `resolve_scope`, `scope_for`, the
   `if not play:` branch in `run_test`, and that `sides` is empty so no report is checked. It does
   **not** filter the suite: `tests/TestKit.luau` loads every spec and this task may not touch
   `tests/` (queued as 113a, in `TASKS.md`).
4. **An unmapped code path can only mean the whole suite.** `FAIL_SAFE_PATHS` sends anything under
   `src/`, `tests/` or `tools/studio_mcp.py` that the map does not name to `all`, and `all` absorbs
   every narrower scope. Verify: `scope_for`, plus the harness selftest cases for a new `src/`
   folder, `tests/TestKit.luau`, a Windows path, and `all` absorbing `gun`. Delete the
   `names = {SCOPE_ALL}` collapse or the `.replace("\\", "/")` and a selftest case fails.
5. **A scoped line is review evidence, a hand-named one is not.** `HARNESS_RE` now reads an optional
   `scope=`, `scope_verdict` classifies it, and `harness_gate` refuses a hand-named scope, skips the
   `[harness2]` requirement for `scope=auto:…`, and treats `scope=all` and every pre-113 line as
   full evidence. Verify: `scope_verdict`, the `kinds`/`hand`/`scoped` block in `harness_gate`, and
   the selftest cases including the one proving a `DIRTY TREE` line is still refused.
6. **The content lane needs no round, but still needs the run.** `CONTENT_PATHS` =
   `src/shared/Viewmodel/poses.json`; `harness_gate` drops it from the code list and says so.
   Verify: the `content`/`changed` split in `harness_gate`, and that
   `src/shared/Viewmodel/poses.json` still scopes to `viewmodel` in the harness (its spec reads the
   file), so the content lane's own one-player `test` still plays those specs.

7. **`test2` is for the match, the drive, the tie and the teams, and nothing else.**
   `TWO_PLAYER_PATHS` is now that explicit list (`src/server/Match/`, `src/client/Match/`, the two
   `MatchBoot`s, `src/shared/Drive/`, `tests/client/Role.luau` and the match/tie/outfit specs), where
   it used to be "any `src/`, any `tests/client/`, or the harness". Weapon, viewmodel, camera, boar,
   hud and tools changes need the one-player line only, **for the PR to main as well as for a review
   round**. Verify: `TWO_PLAYER_PATHS` and `needs_two_player`, the 25 selftest cases that drive both
   directions (11 paths that must bring the line back, 14 that must not), and that CLAUDE.md says
   the same in the loop step 3, git workflow step 4, "What is enforced", Run / test and the
   definition of done. Two judgement calls are written into the list's comment and into Run / test:
   `src/server/Weapon/SafetyArc.luau` is out (the penalty it triggers, `Match/Penalty.luau`, is in)
   and `tools/studio_mcp.py` is out, which leaves `run_test2` the one thing only a two-player run
   can evidence with nothing asking for it — queued as 113a(d).

## What I could not verify
- **The run was `scope=all`, so two paths are still unexercised against Studio**: `--scope auto`'s
  resolution from the changed paths, and the Play-skipping branch it reaches when no spec is in the
  radius. The `scope=` suffix itself is in the pasted line, so that much has now been printed by a
  real run. I ran no harness myself — another Builder held Studio — and the line above is the
  Director's.
- **No review has been replayed yet**, so the after cost/turns are unknown. The baseline is 66
  rounds on record: mean $3.36 / 38 turns, median $3.20 / 36. This task's own review is the first
  measurement.
- Both selftests pass offline and in CI (`python tools/agents.py selftest`,
  `python tools/studio_mcp.py selftest`): **74 new cases** — `agents.py` goes from 20 to 77, the
  harness gains 17.
- The round-1 numbers measured on the real repo after the fix: `studio_mcp` is named on 48 lines in
  **19** files, which is the file count the Reviewer measured, and `tools/pose.py` (19 lines) is in
  the list. The total counts matching LINES, not occurrences, which is why it reads 48 where the
  Reviewer counted 55 occurrences; the heading says "named on 48 line(s)" so the unit is explicit.
