# backups/

Rule 7: never delete. Archive here with a note instead.

- Name archived files `YYYY-MM-DD_<what>.<ext>` and add a line to the log below.
- An archived name must not contain `.spec.`, or the test harness will demand that it runs.
- Place-file snapshots (`*.rbxl`, `*.rbxlx`) may be kept here locally, but git ignores them.
  Roblox keeps the live place's own version history, but not under Studio's File menu. Where to find it
  is not verified yet.

## Log

| Date | File | Was | Why archived |
|---|---|---|---|
| 2026-09-24 | `2026-09-24_gitignore-node-template.txt` | Repo-root `.gitignore` (GitHub's Node.js template, from the initial commit) | Replaced by a Roblox/Rojo `.gitignore` in Task 1 |
| 2026-09-24 | `2026-09-24_example-spec-luau.txt` | `tests/specs/example.spec.luau` (placeholder TestEZ spec: `1 + 1 == 2`) | Reviewer: replace with a real sync assertion. Now `tests/specs/sync.spec.luau`. Renamed so nothing loads it. Round 3: `.spec.` removed from the name, because the harness treats any `*.spec.*` file in the repo as a spec that must run. |
