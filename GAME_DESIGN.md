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
| World geometry: test arena (`Workspace.TestArena` and everything in it) | `ServerScriptService.TestArena`, booted once by `ServerScriptService.ArenaBoot`. It writes nothing else in Workspace. Since Task 22 the arena is the only thing in Workspace: the place's default `Baseplate` and `SpawnLocation` were moved to `ServerStorage.Archive` by hand in Edit mode (Karen's decision; `backups/2026-09-25_workspace-defaults.md`), so `Workspace.TestArena.ArenaSpawn` is the one spawn and nothing z-fights the plate | `src/server/TestArena.luau`, `src/server/ArenaBoot.server.luau` | none: trivial throwaway grey box, replaced by the map generator in Milestone 2 (Director decision, Task 17) |
| Boar AI: state, movement and lifetime of every boar (`Workspace.Boars` and everything in it) | `ServerScriptService.Boar`, booted once by `ServerScriptService.BoarBoot`. `Boar.Body` (Instances) is private to it. `Boar.Brain` (decisions) is private in production but deliberately exported as `Boar.Brain`, so `tests/server/boar_brain.spec.luau` can drive the pure state machine with no world. It writes nothing else in Workspace. It receives hits through the single seam `Runtime:takeHit(part, hit)` and publishes `Runtime.Hit`; `Boar.Body` publishes the attributes `Damageable` and `HitZone` that the weapon reads. The wiring from `Weapon.HitReported` lives in `BoarBoot`, so neither owner requires the other ([shotgun design](docs/design/shotgun.md) section 6) | `src/server/Boar/`, `src/server/BoarBoot.server.luau` | [boar-ai](docs/research/2026-09-24-boar-ai.md), [design](docs/design/boar-ai.md) |
| Weapon: authoritative state, firing, hit resolution, the safety-arc check, and every granted `Tool` | `ServerScriptService.Weapon`, booted once by `ServerScriptService.WeaponBoot`. `StateMachine`, `Validator`, `Limits`, `Registry`, `Pattern`, `Hits` and `SafetyArc` are pure and private to it; `Cast` is its only caller of `Workspace:Raycast`; `Hardware` is the only writer of `Tool` Instances. It writes no boar state and no camera | `src/server/Weapon/`, `src/server/WeaponBoot.server.luau` | [shotgun](docs/research/2026-09-24-shotgun.md), [design](docs/design/shotgun.md) |
| Weapon client: the state replica, the `DrivenHunt.Weapon.*` input actions and the aim flag | `PlayerScripts.Weapon`, booted once by `PlayerScripts.WeaponBoot`. `Weapon.Input` is the only binder of those actions and the only firer of `FireRequest`/`ActionRequest`; the replica has no setter | `src/client/Weapon/`, `src/client/WeaponBoot.client.luau` | [shotgun](docs/research/2026-09-24-shotgun.md), [design](docs/design/shotgun.md) |
| Shot cosmetics (`Workspace.WeaponEffects`, created at run time on the client) | `PlayerScripts.Weapon.Effects`. Cosmetic only; it writes no state and decides no hit | `src/client/Weapon/Effects.luau` | [design](docs/design/shotgun.md) |
| Shotgun numbers (every ballistic, timing, layout and rate number; deep-frozen, no writer) | `ReplicatedStorage.Shotgun` (`Shotgun.CONFIG`), with `ReplicatedStorage.Shotgun.Remotes` holding the four RemoteEvents | `src/shared/Shotgun/` | [design](docs/design/shotgun.md) |
| Camera | _unassigned_ — `ROADMAP.md` 1.4b fills this, with its own design. The weapon **reads** `workspace.CurrentCamera.CFrame` for its aim ray and writes nothing; the seam that task attaches to is `PlayerScripts.Weapon.Input.AimChanged` | | [design](docs/design/shotgun.md) section 9 |
| Input | _unassigned, deliberately_: there is no global input router. Each system owns its own named `ContextActionService` actions under a reserved prefix and every handler returns `Pass`. Registered so far: `DrivenHunt.Weapon.*` (`PlayerScripts.Weapon.Input`) | | [design](docs/design/shotgun.md) section 5.6 |
| Game state | _unassigned_ | | |
| **UI / anything drawn** (`PlayerGui.HunterHud` and everything in it: the crosshair and the barrel/ammo readout) | `PlayerScripts.Hud`. It **reads** `PlayerScripts.Weapon` and is never called by it, so nothing but the Hud can hide or move anything drawn | `src/client/Hud/` | [design](docs/design/shotgun.md) section 3.4 |
