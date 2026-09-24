# CLAUDE.md: Driven Hunt

Roblox game. Code lives on disk and is synced into Studio by Rojo. Place: **Driven Hunt DEV**
(PlaceId 136410205938347). Roles: **Builder** implements, **Reviewer** signs off, **Karen** owns the game.

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

## Layout

| Disk | Studio | Notes |
|---|---|---|
| `src/server/` | `ServerScriptService` | Rojo-owned. Studio edits here are overwritten. |
| `src/client/` | `StarterPlayer.StarterPlayerScripts` | Rojo-owned |
| `src/shared/` | `ReplicatedStorage` | Rojo-owned |
| `tests/specs/` | `ServerStorage.Tests` | TestEZ specs, `*.spec.luau` |
| `tests/TestRunner.server.luau` | `ServerScriptService.TestRunner` | Runs specs on Studio Play only |
| `DevPackages/` (git-ignored) | `ServerStorage.DevPackages` | From `wally install` |
| `assets/source/`, `assets/ready/` | none | Raw vs import-ready art |
| `backups/` | none | Archived files plus notes |
| `docs/research/` | none | Research notes plus `INDEX.md` |
| `tools/` | none | Dev tooling (Studio MCP client) |

Everything outside those Rojo-owned paths (Workspace, Lighting, and so on) is edited in Studio and
saved with the place.

File naming (Rojo): `Name.server.luau` = Script, `Name.client.luau` = LocalScript,
`Name.luau` = ModuleScript, folder with `init.luau` = ModuleScript with children.

## Toolchain (pinned in `rokit.toml`, `wally.toml`)

- Rokit 1.2.0 installs the pinned tools: `rokit install`
- Rojo 7.7.0 syncs files: `rojo serve` (port 34872), `rojo build -o build/place.rbxl`
- Wally 0.3.2 installs packages: `wally install` (run after cloning, and after editing `wally.toml`)
- TestEZ 0.4.1 is the test framework (archived upstream, see the research note)

## Run / test

- **In Studio:** `rojo serve`, then Rojo plugin → Connect, then Play. The Output shows `sync ok` and
  `[tests] PASS: n passed, 0 failed, 0 skipped`.
- **From a terminal (agents):** with Studio open and connected to Rojo:
  `python tools/studio_mcp.py test`. It plays, waits for the `[tests]` line, stops, and exits 1 on
  FAIL. Other commands: `state`, `play`, `stop`, `console`, `luau FILE [Edit|Server|Client]`.
  It needs Studio → Assistant settings → MCP server enabled.
- The Rojo plugin's **Connect** button cannot be clicked by tools. A human must press it once per
  Studio session.
