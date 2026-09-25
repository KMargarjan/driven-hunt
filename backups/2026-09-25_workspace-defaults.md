# 2026-09-25 — the DEV place's default `Baseplate` and `SpawnLocation`

Archived, not deleted (CLAUDE.md rule 7). Karen's decision, Task 22.

## Why

- `Workspace.Baseplate` top face is at y = 0, exactly coplanar with `Workspace.TestArena.Ground`'s
  top face, so the 400×400 arena plate lost the depth test over half its area and rendered as a
  **triangle** (Task 17 screenshots; stable, not flickering).
- `Workspace.SpawnLocation` at the origin plus the arena's `ArenaSpawn` at z = +170 meant **two**
  spawns, so a player spawned at random on one of them.

## Where they went

Moved in Studio, in Edit mode, through Studio MCP (`execute_luau`, reparent only — no property
changed) into **`ServerStorage.Archive`**, beside a `StringValue` `ArchiveNote` carrying the same
date and reason. Workspace afterwards holds only `Camera` and `Terrain` (plus `TestArena`, which
`ServerScriptService.TestArena` builds at run time).

**`ServerStorage` is Rojo-owned** (`default.project.json` maps it to `src/serverstorage`, and every
`$path` node defaults to `$ignoreUnknownInstances: false`). So Rojo will offer to delete
`ServerStorage.Archive` at the **next Connect**, and Karen should accept: this file, not that
folder, is the lasting record. Nothing in the game reads either instance.

## What they were, exactly (read from the place before the move)

`Workspace.Baseplate` — `Part`

| Property | Value |
|---|---|
| Size | `2048, 16, 2048` |
| Position | `0, -8, 0` (top face at y = 0) |
| Anchored | `true` |
| Locked | `true` |
| Color | `0.356863, 0.356863, 0.356863` = `Color3.fromRGB(91, 91, 91)` |
| Material | `Enum.Material.Plastic` |
| Children | one `Texture` (the Studio default baseplate grid) |

`Workspace.SpawnLocation` — `SpawnLocation`

| Property | Value |
|---|---|
| Size | `12, 1, 12` |
| Position | `0, 0.5, 0` |
| Anchored | `true` |
| Color | `0.639216, 0.635294, 0.647059` = `Color3.fromRGB(163, 162, 165)` |
| Material | `Enum.Material.Plastic` |
| Enabled | `true` |
| Duration | `0` |
| Neutral | `true` |
| Children | one `Decal` (the Studio default spawn decal) |

Both are Studio's stock new-place instances: an identical pair comes with any new Baseplate place,
so restoring them needs no file — recreate a `Part` and a `SpawnLocation` with the values above.
