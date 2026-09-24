# Dev toolchain: sync, packages, tests, Studio automation

Date: 2026-09-24 · Author: Builder · Task 1 (round 2 revision after Reviewer FAIL) · Maintenance data from the GitHub API on this date.

## What it must do

1. Keep code on disk, under git, and get it into the Driven Hunt DEV place live while Studio is open.
2. Pin tool versions so every machine and agent runs the same binaries.
3. Install third-party Luau packages without vendoring them into git.
4. Run unit tests inside a real Roblox runtime (Studio Play), with a readable pass/fail line.
5. Let an agent start and stop Play and read Output without a human clicking, so the player's path
   can be checked (rule 6).
6. Prove that the code under test is the code on disk, in the DEV place, and that the test result
   belongs to this run.
7. Lint, format-check and build on every push and PR (CI). Fail on any error.
8. Keep Karen's own playtests free of test runs.

## Sources

| # | Source | Licence | Maintenance (2026-09-24) | Good | Bad |
|---|---|---|---|---|---|
| 1 | [Rojo](https://github.com/rojo-rbx/rojo) | MPL-2.0 | Active. v7.7.0, 2026-07-02 | De facto standard. Official Studio plugin. `build`, `serve` and `sourcemap` for Luau LSP. | Sync is one-way (disk → Studio). Connect is a manual click. |
| 2 | [Argon](https://github.com/argon-rbx/argon) | Apache-2.0 | Active. 2.0.29, 2026-05-19 | Two-way sync. Reads Rojo-style projects. | Smaller community. Two-way sync weakens "disk is the single source". |
| 3 | [Rokit](https://github.com/rojo-rbx/rokit) | MIT | Active. v1.2.0, 2025-09-30 | Fast. Reads Aftman and Foreman manifests. Per-project `rokit.toml`. | Newer than Foreman. Needs a `trust` step per tool. |
| 4 | [Aftman](https://github.com/LPGhatguy/aftman) | MIT | **Archived** | Was the common choice. | Archived; Rokit is its successor. |
| 5 | [Foreman](https://github.com/Roblox/foreman) | MIT | Active. v1.7.0, 2026-05-01 | Maintained by Roblox. | Slower. Global-first config. |
| 6 | [Wally](https://github.com/UpliftGames/wally) | MPL-2.0 | Maintained. Last release v0.3.2, 2023-06. Repo active 2026-01 | Largest Roblox package index. Dev-dependency realm. | Release cadence is slow. |
| 7 | [pesde](https://github.com/pesde-pkg/pesde) | MIT | Active. v0.7.4, 2026-09-09 | Modern. Supports Lune and Luau targets. | Smaller index. TestEZ is not a first-class package there. |
| 8 | [TestEZ](https://github.com/Roblox/testez) ([docs](https://roblox.github.io/testez/)) | Apache-2.0 | **Archived** (read-only). Last release v0.4.1 on Wally | Simple BDD API. Runs anywhere Roblox runs. Stable, needs no changes. | No upstream fixes. Roblox moved to Jest-Lua internally. |
| 9 | [Jest-Lua](https://github.com/jsdotlua/jest-lua) | MIT | Low activity. v3.10.0, 2024-12 | Jest API, mocks, snapshots. | Heavier. Needs FFlag or runner setup. |
| 10 | [run-in-roblox](https://github.com/rojo-rbx/run-in-roblox) | MIT | Stale. v0.3.0, 2020 | Ran a script in Studio from the CLI. | Unmaintained. Runs in Edit mode, not the player's path. |
| 11 | [studio-rust-mcp-server](https://github.com/Roblox/studio-rust-mcp-server) | MIT | **Archived** 2026-04 (final "END" release) | Proved the approach: an MCP bridge to Studio. | Superseded by the MCP server built into Studio. |
| 12 | Roblox Studio built-in MCP server (`StudioMCP.exe`, ships with Studio; Assistant settings → MCP server) | Roblox proprietary (part of Studio) | Current with Studio 0.740 | Real Play mode: `start_stop_play`, `get_console_output`, `execute_luau` per DataModel, `screen_capture`. No plugin install. | Cannot click plugin UI (such as Rojo Connect). The API is not versioned by us. |
| 13 | [StyLua](https://github.com/JohnnyMorganz/StyLua) | MPL-2.0 | Active. v2.5.2, 2026-05-16 | The Luau formatter everyone uses. `--check` for CI. | Opinionated. Few knobs. |
| 14 | [selene](https://github.com/Kampfkarren/selene) | MPL-2.0 | Active. 0.31.0, 2026-05-21 | Roblox std, custom std files (TestEZ globals). Exits non-zero on warnings too. | Downloads the Roblox std at runtime (unpinned). |
| 15 | [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) | MIT | Active. 1.70.0, 2026-09-20 | Type checking and `analyze` for CI. | Needs a sourcemap and type definitions set up (Task 3). |
| 16 | [setup-rokit](https://github.com/CompeyDev/setup-rokit) | MIT | Active. v0.2.1, 2026-05-06 | Installs `rokit.toml` tools in GitHub Actions. | Small project. Installs the latest Rokit itself (not pinned). |

## Pattern adopted and why

- **Sync: Rojo 7.7.0** (source 1). It is the standard, the Rojo plugin was already installed, and
  one-way sync enforces rule 3: disk is the only writer for the Rojo-owned services. Argon was
  rejected because two-way sync lets Studio edits write back, which breaks single ownership.
- **Tool pinning: Rokit** (source 3). Aftman is archived. Foreman works but is slower and global-first.
  Exact versions: Rojo, Wally, StyLua, selene and luau-lsp in `rokit.toml`, TestEZ in `wally.lock`.
  The Rojo plugin is built from the pinned CLI (`rojo plugin install`). **Correction to round 1:** I
  said the toolchain was "pinned in rokit.toml, wally.toml". Not true of Rokit itself, the Creator
  Store Rojo plugin then in use (auto-updating), Studio, or selene's Roblox std. `wally.toml` alone
  allows any 0.4.x. The full table is in CLAUDE.md.
- **Lint/format: selene + StyLua** (sources 13, 14) in CI through setup-rokit (source 16), with the same
  pinned versions as local.
- **Packages: Wally** (source 6). TestEZ is published there and Rojo's docs and examples use it.
  Revisit pesde if Wally stalls.
- **Tests: TestEZ 0.4.1** (source 8), as Karen specified. It is archived, but it is small, feature-complete
  and has no network or runtime dependencies. Its archive status is a known risk. If we need mocks or
  snapshots, the upgrade path is Jest-Lua (source 9), which shares the describe/it/expect vocabulary.
- **Runner:** `ServerScriptService.TestRunner` pcall-requires every `*.spec` (TestEZ's
  `TestBootstrap.lua:57` requires them unprotected), then calls
  `TestBootstrap:run({ServerStorage.Tests}, TextReporter)`, all under pcall. Status: `ERROR` on any
  load or run exception; `FAIL` if failures > 0, `#results.errors` > 0, or passes == 0; else `PASS`.
  It prints `[tests] ...` and writes a JSON report (token, placeId, specCount, counts, status) to the
  `ServerStorage.TestReport` attribute. Tests run in the real Play server: the player's path (rule 6).
- **Gate + provenance (invented; nothing found to borrow):** the harness writes
  `<16 hex>:<unix time>` to git-ignored `tests/sync-token.txt`. Rojo syncs it to
  `ServerStorage.TestSyncToken` (optional path). The runner runs only if the token is under 120 s
  old. The harness then checks:
  - the token reached Studio (so Rojo is live)
  - every script from `rojo sourcemap` has a Studio Source byte-identical to disk
  - the report echoes this run's token and the PlaceId from `servePlaceIds`
  - the runner's spec count equals the spec files on disk

  It clears the token afterwards. Reason for inventing: TestEZ and Rojo have no run-provenance
  mechanism, and the MCP server has no "run tests" tool.
- **Automation: Studio built-in MCP** (source 12), through `tools/studio_mcp.py`, a small stdio
  JSON-RPC client. Chosen over run-in-roblox (stale, Edit mode only) and the archived Rust MCP server.
  **Invented:** the ~280-line client script. Reason: no maintained CLI MCP client existed in the repo's
  toolchain, and pulling in an MCP SDK for 4 calls is heavier than the script. Round 2: it exposes only
  `test`, `state`, `console` and `stop`, and sends only constant read-only Luau queries. It refuses unless
  Studio is in Edit mode.

## Numeric targets

| Target | Value | Measured 2026-09-24 |
|---|---|---|
| Disk save → change visible in Studio (Rojo connected) | ≤ 2 s | New spec file appeared and was removed within the 2 s wait: pass |
| Play → `[tests]` line in Output | ≤ 10 s | Under 5 s: pass |
| `python tools/studio_mcp.py test` total wall time | ≤ 30 s | 9 s (round 2, with all checks): pass |
| Failing spec makes the run exit non-zero | 100% | A deliberate `expect(1).to.equal(2)` gave `[tests] FAIL: 2 passed, 1 failed` and exit 1. Removing it gave PASS and exit 0: pass |
| Back-to-back runs give the correct result | 3/3 | 3/3 after the fix below: pass |
| Negative cases caught (round 2) | 6/6 | All caught: failing assertion (FAIL, exit 1); syntax-error spec (`[tests] ERROR`, exit 1); spec throws on load (`ERROR`, exit 1); Studio in Play (REFUSED, exit 2); normal playtest (no tests ran); stale token (no tests ran) |
| CI fails on lint or format error | 100% | Measured on PR, see TASKS.md / PR |
| Tests executing in live games | 0 | Guarded by `RunService:IsStudio()` (not verified in a live server) |

## Harness bug found and fixed (rule 6)

The first `studio_mcp.py test` read the result from the Output log by diffing it against the log
before Play. Studio **clears Output on each Play**, so the diff was empty whenever two runs printed
identical output, and the second run timed out. The same design could also report the previous
run's result as a false PASS. Fix: TestRunner also writes the summary to the
`ServerStorage` attribute `TestSummary`, and the harness polls it in the **Server** DataModel, which
only exists for the current play session.
