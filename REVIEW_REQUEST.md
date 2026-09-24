# Review request

Written by the Builder for `tools/review.sh`. The format is below; the script parses the first three lines.

Round: 1
Base: `0fa7c2b390c0ec9579a1cb55b35861a1dc0a949b`
Code commit: `f00c61efb0b8d9617309db5ffe75d10aecaf5709`

## Task
TASKS.md #10: audit-001 L5. Test-only globals (`describe`, `it`, `expect`, `SKIP`, `FOCUS`…) must be a
lint error in game code (`src/`), while `tests/` keeps them. This is also the first run of the
four-agent loop (Task 9).

## What changed
- `selene.toml`: `std = "roblox"`, was `roblox+testez`. It now applies to `src/`.
- `tests/selene.toml` (new): `std = "roblox+testez"` for `tests/`, run with
  `selene --config tests/selene.toml tests` from the repo root.
- `.github/workflows/ci.yml`: the selene step runs both invocations.
- `CLAUDE.md`: the lint command and the pinning-table row are updated to match.

## Claims
1. Game code may no longer reference TestEZ globals. How to verify: `selene.toml:4` is `std = "roblox"`,
   and `testez.yml` (which defines `describe`, `expect`…) is included only by `tests/selene.toml:3`.
2. Tests still lint clean with the TestEZ globals. How to verify: `.agent-evidence/lint-selene.txt`
   shows `selene --config tests/selene.toml tests` with exit 0 and 0 errors.
3. Game code lints clean under the stricter std. How to verify: the same file shows `selene src` with
   exit 0 and 0 errors.
4. CI runs both lint invocations and fails if either fails. How to verify: `.github/workflows/ci.yml`
   selene step, `selene src && selene --config tests/selene.toml tests` (bash `-e`, `&&`).
5. The docs match the code. How to verify: the `CLAUDE.md` "Run / test" lint line and the toolchain
   table row name both configs. No other doc tells anyone to run `selene src tests` with one config
   (grep).
6. No behaviour change in the game or tests: no synced file changed. How to verify:
   `.agent-evidence/changed-files.txt` lists only `.github/workflows/ci.yml`, `CLAUDE.md`,
   `selene.toml`, `tests/selene.toml` (plus this request). `tests/selene.toml` is not in the Rojo
   sourcemap.

## Harness
`[harness] PASS: 24/24 checks @ f00c61efb0b8d9617309db5ffe75d10aecaf5709 (clean tree)`

## Could not verify
- **That `src/` now actually fails on a TestEZ global**, by a committed test. I checked it by hand:
  I temporarily added `src/shared/zz_probe.luau` containing `describe(...)` and `expect`. `selene src`
  failed with 2 `undefined_variable` errors (exit 1), and the file was removed. There is no committed
  regression test for lint config, and the Reviewer can't re-run selene.
- **CI result for this commit.** It isn't known when this request is written, and will be linked in
  the report.
- **Path resolution.** `testez.yml` is resolved relative to the working directory (repo root), not
  relative to `tests/selene.toml`. Both CI and the documented command run from the root. Running
  `selene` from inside `tests/` would not find the std.
