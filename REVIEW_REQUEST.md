# Review request

Written by the Builder for `tools/review.sh`. The format is below; the script parses the first three lines.

Round: 2
Base: `0fa7c2b390c0ec9579a1cb55b35861a1dc0a949b`
Code commit: `13a19425c78e96110bce08cd9467fbd33ffb3eea`

## Task
TASKS.md #10: audit-001 L5. Test-only globals (`describe`, `it`, `expect`, `SKIP`, `FOCUS`…) must be a
lint error in game code (`src/`), while `tests/` keeps them. This is also the first run of the
four-agent loop (Task 9).

## Round 1 findings and what I did
1. *TASKS.md:14 still listed L5 as open.* Fixed: Task 8's note now says "L5 is fixed by Task 10", and
   L5 is gone from its "Open:" list.
2. *`selene src && selene --config …` hid `tests/` errors behind `src/` errors.* Fixed: two separate CI
   steps, each with `if: success() || failure()`, the same pattern as the other lint steps.
3. *Task 10 was on Task 9's branch.* Fixed. None of these commits had been pushed, so I made a new branch
   `task-10-lint-test-globals` at the Task 10 commits and moved `task-9-agent-workflow` back to
   `0fa7c2b` (its last Task 9 commit). Task 10 is now its own branch, stacked on Task 9. Nothing
   published was rewritten. The TASKS.md Task 10 row names the branch.

## What changed (all of Task 10, base..HEAD)
- `selene.toml`: `std = "roblox"`, was `roblox+testez`. It now applies to `src/`.
- `tests/selene.toml` (new): `std = "roblox+testez"` for `tests/`, run with
  `selene --config tests/selene.toml tests` from the repo root.
- `.github/workflows/ci.yml`: two selene steps (`src`, then `tests`), both always run.
- `CLAUDE.md`: the lint command and the pinning-table row are updated.
- `TASKS.md`: L5 is recorded as fixed, and the Task 10 row names its branch.
- `REVIEW_REQUEST.md` and `REVIEW_RESULT.md`: loop records.

## Claims
1. Game code may no longer reference TestEZ globals. How to verify: `selene.toml:4` is `std = "roblox"`;
   `testez.yml` is included only by `tests/selene.toml:3`.
2. Tests still lint clean with the TestEZ globals. How to verify: `.agent-evidence/lint-selene.txt`,
   `selene --config tests/selene.toml tests` with exit 0 and 0 errors.
3. Game code lints clean under the stricter std. How to verify: the same file, `selene src` with exit 0.
4. CI runs **both** lint invocations on every run, even when the first one fails. How to verify:
   `.github/workflows/ci.yml` has two selene steps, each with `if: success() || failure()`.
5. No doc still describes the old combined lint or lists L5 as open. How to verify: grep the repo for
   `selene src tests` (only historical research-note text, if any) and for `L5` (only "fixed by
   Task 10" and the Task 10 row).
6. No behaviour change in the game or tests: no synced file changed. How to verify:
   `.agent-evidence/changed-files.txt`. `tests/selene.toml` is not in `.agent-evidence/sourcemap.json`.
7. Task 10 is on its own branch. How to verify: `.agent-evidence/head.txt` names
   `task-10-lint-test-globals`.

## Harness
`[harness] PASS: 24/24 checks @ 13a19425c78e96110bce08cd9467fbd33ffb3eea (clean tree)`

## Could not verify
- **That `src/` now fails on a TestEZ global**, by a committed test. I checked it by hand: a temporary
  `src/shared/zz_probe.luau` with `describe(...)`/`expect` made `selene src` exit 1 with 2
  `undefined_variable` errors, and the file was removed. There is no committed regression test for
  lint config.
- **CI result for this commit.** It isn't known when this request is written, and will be linked in
  the report.
- **Path resolution.** `testez.yml` resolves relative to the working directory (repo root). Running
  selene from inside `tests/` would not find it. CI and the documented command both run from the root.
