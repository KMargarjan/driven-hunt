# CLAUDE.md: Driven Hunt

Roblox game. Code lives on disk and is synced into Studio by Rojo. Place: **Driven Hunt DEV**
(PlaceId 136410205938347, enforced by `servePlaceIds` in `default.project.json`).
Roles: **Builder** implements, **Reviewer** signs off, **Karen** owns the game and playtests.

## Rules

1. **RESEARCH BEFORE IMPLEMENTATION.** For any non-trivial system, first write a note in
   `docs/research/` covering:
   - what the system must do
   - 3+ external sources, named and linked, with licence and maintenance status
   - what each source does well and badly
   - the pattern adopted and why
   - the numeric targets

   Add it to `docs/research/INDEX.md`. Only then write code.
2. **BORROW BEFORE BUILDING.** Inventing something needs a written reason, kept in the research note.
3. **ONE OWNER PER SYSTEM.** Anything drawn, the camera, input, state: exactly one writer, named in
   the *System owners* table in `GAME_DESIGN.md`.
4. **ONE TASK PER ROUND.** Small and testable, then stop. Tasks live in `TASKS.md`.
5. **VISUAL CHANGES NEED A SCREENSHOT** that you inspected yourself.
6. **TEST THE PLAYER'S PATH, not the harness.** Harness faults are bugs: report them.
7. **NEVER DELETE.** Archive with a note (see `backups/README.md`).
8. **REPORT HONESTLY** what you could not verify and what you got wrong.
9. **CODE COMMENTS** carry the pattern name, source links and the research note file.
10. **Nothing reaches Karen until the Reviewer has signed it off.**

## Git workflow: branch + pull request, never push to main

1. `git switch main && git pull`, then `git switch -c task-<n>-<short-name>`.
2. Commit on the branch. Push the branch: `git push -u origin <branch>`.
3. Open a pull request into `main`. CI (`.github/workflows/ci.yml`) must be green.
4. The Reviewer reviews the PR. Karen merges after sign-off. The Builder never merges and never
   pushes to `main`. GitHub branch protection enforces this.
5. Record Karen's playtest feedback in `PLAYTEST.md` in the same PR round.

## Definition of done

Paste this, filled in, at the end of every task report. Each box is checked, or marked N/A with a reason.

```
- [ ] Tests pass: `python tools/studio_mcp.py test` → "[harness] PASS: n/n checks" (paste the line)
- [ ] CI green on the PR (link to the run)
- [ ] Screenshot inspected (rule 5), or N/A: <reason>
- [ ] Docs updated: TASKS.md, GAME_DESIGN.md owners, research note/INDEX, PLAYTEST.md, CLAUDE.md as needed
- [ ] Reviewer signed off (by whom / where), or "pending"
- [ ] Commit + PR link
```

## Layout

| Disk | Studio | Notes |
|---|---|---|
| `src/server/` | `ServerScriptService` | Rojo-owned. Studio edits here are overwritten. |
| `src/client/` | `StarterPlayer.StarterPlayerScripts` | Rojo-owned |
| `src/shared/` | `ReplicatedStorage` | Rojo-owned |
| `tests/specs/` | `ServerStorage.Tests` | TestEZ specs, `*.spec.luau` |
| `tests/TestRunner.server.luau` | `ServerScriptService.TestRunner` | Runs specs only when the harness opens the gate |
| `tests/sync-token.txt` (git-ignored, optional) | `ServerStorage.TestSyncToken` | Written only by the harness |
| `DevPackages/` (git-ignored, optional) | `ServerStorage.DevPackages` | From `wally install` |
| `assets/source/`, `assets/ready/` | none | Raw vs import-ready art |
| `backups/` | none | Archived files plus notes |
| `docs/research/` | none | Research notes plus `INDEX.md` |
| `tools/` | none | Test harness (Studio MCP client) |

Everything outside those Rojo-owned paths (Workspace, Lighting, and so on) is edited in Studio and
saved with the place.

File naming (Rojo): `Name.server.luau` = Script, `Name.client.luau` = LocalScript,
`Name.luau` = ModuleScript, folder with `init.luau` = ModuleScript with children.

## Toolchain: what is pinned and what is not

| Tool | Version | Pinned by |
|---|---|---|
| Rojo CLI | 7.7.0 | `rokit.toml` (exact) |
| Rojo Studio plugin | 7.7.0 | `rojo plugin install`, built from the pinned CLI, installed to `%LOCALAPPDATA%\Roblox\Plugins\RojoManagedPlugin.rbxm`. The Creator Store Rojo plugin must stay disabled. |
| Wally | 0.3.2 | `rokit.toml` (exact) |
| StyLua | 2.5.2 | `rokit.toml` (exact). Config: `stylua.toml` |
| selene | 0.31.0 | `rokit.toml` (exact). Config: `selene.toml` + `testez.yml` |
| luau-lsp | 1.70.0 | `rokit.toml` (exact). Editor language server, not used in CI yet |
| TestEZ | 0.4.1 | `wally.lock` (exact). `wally.toml` allows any compatible 0.4.x. Archived upstream |
| Rokit itself | 1.2.0 | **Not pinned.** Installed by hand. CI uses the latest via `setup-rokit` |
| Roblox Studio | 0.740.x | **Not pinned.** Studio auto-updates |
| selene's Roblox std | from the Roblox API dump | **Not pinned.** Selene downloads it into its cache |

After cloning: `rokit install`, then `wally install`. After changing the Rojo version: bump
`rokit.toml`, run `rojo plugin install`, and restart Studio.

## Run / test

- **Lint and format (also in CI):** `selene src tests` and `stylua --check src tests`
  (`stylua src tests` fixes formatting). `rojo build -o build/place.rbxl` checks the project builds.
- **Tests:** with Studio open on the DEV place in **Edit** mode and Rojo connected:
  `python tools/studio_mcp.py test`. It:
  1. refuses unless Studio is in Edit mode (exit 2)
  2. asserts the open place's PlaceId
  3. writes a fresh token to `tests/sync-token.txt` and waits for Rojo to sync it
  4. checks every synced script's Source in Studio matches disk byte-for-byte
  5. presses Play and reads the runner's JSON report from the Server DataModel
  6. asserts the token, the PlaceId, spec count equal to the `*.spec.luau` files on disk, PASS, more
     than 0 passed, 0 failed and 0 errors
  7. stops Play, clears the token, and checks the gate closed

  Exit 0 only on PASS.
- **Karen's playtests do not run tests.** TestRunner runs only in Studio, and only with a token under
  120 s old. Only the harness writes one, and it clears it afterwards.
- **Harness safety:** `tools/studio_mcp.py` exposes only `test`, `state`, `console` and `stop`. It has
  no arbitrary-Luau or arbitrary-tool command. Its only `execute_luau` calls are constant, read-only
  queries defined in the file (`QUERY_*`). New queries must stay read-only.
  It needs Studio → Assistant settings → MCP server enabled.
- The Rojo plugin's **Connect** button cannot be clicked by tools. Karen presses it once per Studio
  session, and again whenever `rojo serve` restarts (for example after `default.project.json` changes,
  which the running server does not reload).

## Test code ships with the place

While Rojo is connected, `ServerScriptService.TestRunner`, `ServerStorage.Tests`,
`ServerStorage.DevPackages` and (between runs, empty) `ServerStorage.TestSyncToken` are part of the
place, and **they are published with it**. This is accepted for now:

- all of them live in server-only containers and never replicate to clients
- the runner returns immediately outside Studio (`RunService:IsStudio()`)
- inside Studio it also needs a fresh harness token

Before the first public release, add a publish step that strips them. That is logged in `TASKS.md`.
