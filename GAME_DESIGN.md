# Driven Hunt: Game Design

> Status: skeleton. Nothing is designed yet. Sections get filled in as tasks land (see `TASKS.md`).

## Pitch

_TBD._

## Core loop

_TBD._

## System owners

Rule 3: every system has exactly one writer. A system not listed here has no owner yet, and nobody
may write to it until it has one.

| System | Owner (the only writer) | Location | Research note |
|---|---|---|---|
| Source delivery, not a runtime owner (every script container: ServerScriptService, ReplicatedStorage, ReplicatedFirst, StarterGui, StarterPack, StarterPlayerScripts, StarterCharacterScripts, ServerStorage) | Rojo, from the files on disk. Runtime systems inside these containers get their own rows | `default.project.json` | [toolchain](docs/research/2026-09-24-toolchain.md) |
| Test run: gate check (reads the token), spec loading, TestEZ run, report | `ReplicatedStorage.TestKit`, called by `ServerScriptService.TestRunner` (server report: `ServerStorage` attribute `TestReport`) and `StarterPlayerScripts.ClientTestRunner` (client report: `LocalPlayer` attribute `TestReport`) | `tests/TestKit.luau`, `tests/*Runner*.luau` | [toolchain](docs/research/2026-09-24-toolchain.md) |
| Test gate / sync token (`tests/sync-token.txt` → `ReplicatedStorage.TestSyncToken`) | `tools/studio_mcp.py` (the harness) | `tools/studio_mcp.py` | [toolchain](docs/research/2026-09-24-toolchain.md) |
| `ServerScriptService.SyncCheck` "Ran" attribute | `SyncCheck` itself | `src/server/SyncCheck.server.luau` | [toolchain](docs/research/2026-09-24-toolchain.md) |
| World geometry: test arena (`Workspace.TestArena` and everything in it) | `ServerScriptService.TestArena`, booted once by `ServerScriptService.ArenaBoot`. It writes nothing else in Workspace, and the place's default `Baseplate` / `SpawnLocation` are Studio content it never touches | `src/server/TestArena.luau`, `src/server/ArenaBoot.server.luau` | none: trivial throwaway grey box, replaced by the map generator in Milestone 2 (Director decision, Task 17) |
| Camera | _unassigned_ | | |
| Input | _unassigned_ | | |
| Game state | _unassigned_ | | |
| UI / anything drawn | _unassigned_ | | |
