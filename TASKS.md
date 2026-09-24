# Tasks

One task per round (rule 4). Status: `todo` → `in progress` → `awaiting review` → `done` (Reviewer signed off).

| # | Task | Status | Notes |
|---|---|---|---|
| 1 | Project setup: Rojo, git, TestEZ, docs skeleton, prove the sync loop | awaiting review | Round 1: Reviewer FAIL (11 items). Round 2 (PR `task-1-review-fixes`): all 11 fixed, plus CI, branch workflow, definition of done, PLAYTEST.md |
| 2 | Strip test code at publish (TestRunner, Tests, DevPackages, TestSyncToken) | todo, before first public release | Accepted for now, see CLAUDE.md "Test code ships with the place" |
| 3 | Run `luau-lsp analyze` in CI (type checking) | todo | luau-lsp is pinned but not wired into CI. Needs a sourcemap and Roblox type definitions in CI |

## Review log

### Task 1, round 1 → Reviewer FAIL: disposition of items 1-11

The Reviewer's items as Karen relayed them. Items 7 and 8 could be fixed or logged; both were fixed, so
nothing is deferred.

| # | Item | Disposition |
|---|---|---|
| 1 | Fail when `#results.errors > 0` | Fixed: `errorCount` is in the report. The harness requires 0 |
| 2 | Fail when `successCount == 0`; compare against the `*.spec.luau` files on disk | Fixed: the runner counts spec modules. The harness compares with the disk count and requires more than 0 passed |
| 3 | Prove the code under test came from disk (sync token plus PlaceId) | Fixed: a fresh token is written just before each run and echoed back by the runner, the PlaceId is asserted, and Source is compared byte-for-byte for all synced scripts |
| 4 | Refuse to run unless Studio is in Edit mode | Fixed: exit 2 with REFUSED (verified during Play) |
| 5 | Remove or make read-only the Edit-mode luau/call paths | Fixed: the `luau` and `call` commands were removed. Only constant read-only queries remain. Documented in CLAUDE.md |
| 6 | Replace the example test with a real sync assertion | Fixed: `tests/specs/sync.spec.luau`. Old example archived in `backups/` |
| 7 | pcall the spec requires and emit `[tests] ERROR` | Fixed (verified with a syntax-error spec and a spec that throws on load) |
| 8 | Correct the false pinning claims; pin stylua, selene, luau-lsp; `rojo plugin install` | Fixed: the pinning table in CLAUDE.md, tools in rokit.toml, pinned plugin installed and loaded in Studio |
| 9 | DevPackages optional in `default.project.json` | Fixed: `{"optional": ...}`. The build is verified without DevPackages |
| 10 | Gate the runner behind a flag only the harness sets | Fixed: a harness token under 120 s old. Verified that a normal playtest and a stale token run no tests |
| 11 | Write down (or strip at publish) that test code ships with the place | Written down (CLAUDE.md). Stripping logged as Task 2 |
