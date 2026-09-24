# Tasks

One task per round (rule 4). Status: `todo` → `in progress` → `awaiting review` → `done` (Reviewer signed off).

| # | Task | Status | Notes |
|---|---|---|---|
| 1 | Project setup: Rojo, git, TestEZ, docs skeleton, prove the sync loop | awaiting review | Round 1: Reviewer FAIL. Round 2 (PR #1): fixes plus CI, branch workflow, definition of done, PLAYTEST.md. Reviewer FAIL on PR #1. Round 3: 3 blocking + 2 should-fix items, plus public-repo hygiene |
| 2 | Strip test code at publish (TestRunner, Tests, DevPackages, TestSyncToken) | todo, before first public release | Accepted for now, see CLAUDE.md "Test code ships with the place" |
| 3 | Run `luau-lsp analyze` in CI (type checking) | todo | luau-lsp is pinned but not wired into CI. Needs a sourcemap and Roblox type definitions in CI |
| 4 | Karen: check DEV place Version History around the first Connect | closed: not applicable | Not applicable: the place was empty at the first Connect. It was brand new, a read-only query at ~18:30 found all Rojo-owned containers empty, and Karen added nothing to them before Connect (~18:36). The click path I gave (Studio → File → Version History) was wrong: Studio's File menu has no Version History |

## Review log

### Task 1, round 2 on PR #1 → Reviewer FAIL: disposition (round 3)

| # | Item | Disposition |
|---|---|---|
| 1 | Skipped tests must fail the run (itSKIP/describeSKIP/SKIP/itFOCUS gave PASS) | Fixed in the runner (`skippedCount > 0` gives FAIL) and the harness ("No skipped tests" check). Verified: itSKIP, describeSKIP, SKIP(), itFOCUS, describeFOCUS and FOCUS() each fail the run |
| 2 | Round-1 item 7 dropped: document that Rojo **deletes** Studio-created instances; check Version History around the first Connect | Documented (CLAUDE.md "Rojo DELETES…", with the docs quote and a live-sync probe test). Pre-Connect evidence: all Rojo-owned containers were empty at ~18:30, before the first Connect at ~18:36. Task 4 (Version History) closed as not applicable: the place was empty at the first Connect |
| 3 | CLAUDE.md line 35 falsely said branch protection enforces the Reviewer/merge rules | Reworded: the ruleset enforces PR + CI only. Reviewer sign-off and who merges are policy |
| 4 (should fix) | Find specs anywhere in the repo (`*.spec.*`) | Fixed: `git ls-files` (tracked + untracked, non-ignored). Every spec must be synced and run, matched by name, not count. Archived example renamed so it no longer matches |
| 5 (should fix) | Fail on any synced file the harness cannot compare | Fixed: `rojo sourcemap --include-non-scripts`. Every instance must exist with the right ClassName. Scripts are compared by Source and `.txt` by Value; `.project.json` is structural; anything else fails |
| extra | Public repo: never commit secrets; check `.gitignore` and history | CLAUDE.md section added. `.gitignore` covers env/keys/credentials/cookies (verified with `git check-ignore`). History: gitleaks clean, manual grep clean, noreply identity only |

### Task 1, round 1 → Reviewer FAIL: disposition

**Correction (round 3):** I never had the Reviewer's numbered list. In round 2 I numbered Karen's
bullet list 1-11 in order and called it the Reviewer's items. That was wrong. The Reviewer's item 7
was "Rojo deletes Studio-created instances; document it", and I dropped it. It is fixed in round 3
(see above). The table below is the bullet list as Karen relayed it; its numbers are mine, not the
Reviewer's.

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
