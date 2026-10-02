# Task 113 — review and test only what changed, plus its blast radius

Task: 113
Round: 3
Base: `0cc60ca`
Code commit: `<round 3's code commit — the Director's gate run names it>`

Tools and docs only: no `src/`, no `tests/`. Karen, 2026-10-02: *"not need start from zero I
mentioned 100 times / it has to test only parts what has been changed and what blast radius could
be."*

```
[harness] PASS: n/n checks @ <code commit> (clean tree) scope=all      <- the Director runs this
```

Rounds 1 and 2 both ran 32/32 on a clean tree (`d82e675`, `d9af20d`). **`test2` is N/A**, and the
Director accepted both judgement calls behind that: nothing here touches the match, the drive,
the tie or the teams (`TWO_PLAYER_PATHS`), with `src/server/Weapon/SafetyArc.luau` out of that list
and `tools/studio_mcp.py` out of it too (claim 7; the gap that leaves is queued as 113a(d)).

## Claims, each with how to verify it

1. **The Reviewer no longer reads CLAUDE.md or PROJECT_CONTEXT.** `docs/REVIEWER_RULES.md` (61
   lines) carries the blocking rule, the owner boundaries, security, rule 5 and how the Reviewer
   works; `docs/REVIEWER_PROMPT.md` and `cmd_review`'s task text in `tools/agents.py` send it there
   and forbid the two long files. Verify: read the digest against the four blocking kinds in the
   prompt, and the "Read, in this order" text in `cmd_review`. Measured at this commit: **629 lines
   / 49,665 bytes** of fixed reading become **61 / 4,330** — 91% less, ~11.3k tokens a round. No line
   count is written into the code any more (rounds 1 and 2 both found a stale one); the code says
   "some 630 lines" and the figure is measured per round, here.
2. **The Reviewer's scope is the change plus its blast radius.** `blast_radius_text` writes
   `.agent-evidence/blast-radius.md`: the changed files, the symbols whose definition the diff added
   **or removed** (`symbols_in_diff`), the names other files `require` (`module_names` — a folder's
   name for an `init.luau`), and **every file in the repo's code that names one, with how many of its
   lines do** (`reference_hits`, rendered by `blast_radius_report`; both pure — no git, no
   filesystem). **Round 1's blocking finding is fixed: no file is cut.**
   `MAX_QUOTED_LINES_PER_SYMBOL` bounds only the quoted sample, the heading prints the true total and
   file count, and the quoted block says "12 of 48 line(s) quoted; the other 36 are in the files
   above". Verify: those two functions, the 9 cases driving 40 hits in 20 files against a cap of 12,
   and the prompt's "What you review". Mutation check: restoring the old early-exit fails 5 of them;
   restored. `references` scans code and config only — `Body` matches English prose in `TASKS.md`.
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

8. **The evidence index belongs to its role — round 2's blocking finding.** `evidence_index` is
   pure and takes the role: the REVIEW index carries "start with `blast-radius.md`, do NOT read
   CLAUDE.md or docs/PROJECT_CONTEXT.md", and the ARCHITECT index carries none of it, because
   `docs/ARCHITECT_PROMPT.md` orders that agent to read exactly those two first and judges its
   findings against them. Verify: `evidence_index`, the `role="reviewer"` / `role="architect"`
   arguments at the two `build_evidence` call sites, and the 5 selftest cases that render both
   indexes. An unknown role is **refused**, not quietly given the plain index, which is how a
   renamed caller would reintroduce the fault. Mutation check: making the block unconditional again
   (`if True:`) fails the two Architect cases; restored.

## Round-2 notes fixed in the same lines (the rest are queued as 113a(b), (e), (f), (g))
- `MAX_SYMBOLS` no longer cuts silently: `symbols_in_diff` returns every name, `blast_radius_text`
  applies the cap, and the report says "N of M symbols are detailed below" and **names every symbol
  it dropped**. Mutation check: restoring `return out[:MAX_SYMBOLS]` fails that case; restored.
- `scope_tag` (new, pure): a `--scope auto` run that resolves to the whole suite is tagged
  `scope=all`, not `auto:all` — it played every spec, so it is full evidence and the merge gate must
  not reject it. 5 cases, including that one.
- `HARNESS2_RE`'s dead `scope=` group is gone, and its selftest case now asserts the line
  `run_test2` actually prints. `harness_gate`'s unreachable viewmodel-exemption print is gone; the
  record of why that exemption exists stays in `WEAPON_VIEWMODEL_PATHS`' comment.
- `docs/REVIEWER_RULES.md` and `docs/REVIEWER_PROMPT.md` no longer contradict themselves: the
  Reviewer may read the design doc for the system under review, which blocking kind 1 is judged
  against. `FAIL_SAFE_PATHS`' comment now says which root build files it does not cover.

## What I could not verify
- **Both runs were `scope=all`, so two paths are still unexercised against Studio**: `--scope auto`'s
  resolution from the changed paths, and the Play-skipping branch it reaches when no spec is in the
  radius. The `scope=` suffix itself is in the pasted line, so that much has been printed by a real
  run, twice. I ran no harness myself — another Builder holds Studio — and the line above is the
  Director's.
- **No Reviewer has read the new `blast-radius.md` yet**, so the round-1 finding is fixed by
  construction and by its selftest cases, not yet by a reader of the document.
- **No review has been replayed yet**, so the after cost/turns are unknown. The baseline is 66
  rounds on record: mean $3.36 / 38 turns, median $3.20 / 36. This task's own review is the first
  measurement.
- Every pure-python selftest passes offline and in CI: `agents.py` (20 → **88**), `studio_mcp.py`,
  `pose.py`, `privacy_scan.py` (+ `scan`, 388 files), `meshy.py`, `roblox_upload.py`.
- The round-1 numbers measured on the real repo after the fix: `studio_mcp` is named on 48 lines in
  **19** files, which is the file count the Reviewer measured, and `tools/pose.py` (19 lines) is in
  the list. The total counts matching LINES, not occurrences, which is why it reads 48 where the
  Reviewer counted 55 occurrences; the heading says "named on 48 line(s)" so the unit is explicit.
