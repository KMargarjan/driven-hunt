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
| 2026-09-24 | (nothing kept: see note) | 16 TestEZ ModuleScripts + a StringValue left in the DEV place under `ServerStorage.DevPackages` / `ServerStorage.TestSyncToken` after Task 5 moved those mappings to ReplicatedStorage | Orphans, not project content: Rojo copies of git-ignored `DevPackages/` (verified byte-identical to the live copy) and an empty token. Removed from the place by the Builder via a Studio query. No file to archive; the source is `wally.lock` + `devpackages.sha256` |
| 2026-09-24 | `2026-09-24_example-spec-luau.txt` | `tests/specs/example.spec.luau` (placeholder TestEZ spec: `1 + 1 == 2`) | Reviewer: replace with a real sync assertion. Now `tests/specs/sync.spec.luau` (since Task 5: `tests/server/sync.spec.luau`). Renamed so nothing loads it. Round 3: `.spec.` removed from the name, because the harness treats any `*.spec.*` file in the repo as a spec that must run. |
| 2026-09-25 | `2026-09-25_workspace-defaults.md` | The DEV place's default `Workspace.Baseplate` and `Workspace.SpawnLocation` | Task 22, Karen's decision: the Baseplate's top face was coplanar with the arena plate's and z-fought (the 400x400 square rendered as a triangle), and a second spawn made spawning random. Moved in Edit mode into `ServerStorage.Archive` with a `StringValue` note; that folder is Rojo-owned, so the file here is the lasting record |
| 2026-09-25 | `2026-09-25_root-REVIEW_REQUEST.md`, `2026-09-25_root-REVIEW_RESULT.md`, `2026-09-25_root-ARCH_RESULT.md` | The three root loop files, in their last state (Task 22's request and verdict; the boar-ai design verdict) | Task 21: the loop moved to one folder per task, `reviews/task-<N>/{REQUEST,RESULT,ARCH_RESULT}.md`, so branches stop conflicting on the same root files and the round count has a task boundary. Moved with `git mv`, so their whole history follows them |
