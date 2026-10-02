# Task 113 — review and test only what changed, plus its blast radius

Task: 113
Round: 1
Base: `0cc60ca`
Code commit: `<HEAD of this branch — the Director's gate run names it>`

Tools and docs only: no `src/`, no `tests/`. Karen, 2026-10-02: *"not need start from zero I
mentioned 100 times / it has to test only parts what has been changed and what blast radius could
be."*

```
[harness]  PASS: n/n checks @ <code commit> (clean tree) scope=all      <- the Director runs this
[harness2] PASS: n/n checks @ <code commit> (clean tree)                <- and this
```

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
   name for an `init.luau`), and every place in the repo's code that names one (`references`).
   Verify: the three functions, their selftest cases, and the "What you review" section of the
   prompt. `references` scans code and config only, because a symbol like `Body` matches English
   prose in `TASKS.md`.
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

## What I could not verify
- **No harness run at all.** Another Builder holds Studio; the Director runs `test` and `test2` for
  this branch. Nothing here was exercised against Studio: `--scope auto`'s Play-skipping branch has
  never run, and the `scope=` suffix in the final line has never been printed by a real run.
- **No review has been replayed yet**, so the after cost/turns are unknown. The baseline is 66
  rounds on record: mean $3.36 / 38 turns, median $3.20 / 36. This task's own review is the first
  measurement.
- Both selftests pass offline and in CI (`python tools/agents.py selftest`,
  `python tools/studio_mcp.py selftest`): 41 new cases.
