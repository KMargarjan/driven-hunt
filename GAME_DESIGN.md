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
| Source sync (ServerScriptService, ReplicatedStorage, StarterPlayerScripts, ServerStorage.Tests, ServerStorage.DevPackages) | Rojo, from the files on disk | `default.project.json` | [toolchain](docs/research/2026-09-24-toolchain.md) |
| Test execution | `ServerScriptService.TestRunner` | `tests/TestRunner.server.luau` | [toolchain](docs/research/2026-09-24-toolchain.md) |
| Camera | _unassigned_ | | |
| Input | _unassigned_ | | |
| Game state | _unassigned_ | | |
| UI / anything drawn | _unassigned_ | | |
