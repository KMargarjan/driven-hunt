# Task 33 — design brief for the ARCHITECT: `docs/design/map-generator.md` (ROADMAP Milestone 2)

Written by the Director, run in parallel with the Builder (the drive, Task 32). Nothing is built from
this until Milestone 1 is closed by Karen's two-player playtest.

## Decisions already made
- Karen, 2026-09-24: map option C. The map is built by a map generator: Luau code on disk, run in
  Edit mode through the Studio MCP server, verified by Edit-mode screenshots (they work; save them with
  `python tools/studio_mcp.py capture`) and by Karen walking it. Nobody on the team builds by hand.
- Karen, 2026-09-24: borrow before generating — Creator Store assets first, Karen's Meshy models where
  nothing fits. Karen is preparing Meshy models (boar, shotgun, hunter's stand, spruce/birch/oak) and
  references now; they arrive as files outside the repo and are uploaded by id (Open Cloud key only in
  an environment variable, never in the repo, which is public).
- v1: ONE small map, European farmland and woods: fields, hedgerows, spruce and birch stands, tracks,
  a bog; a drive area and a shooter line along a wood edge.
- Research: `docs/research/2026-09-24-map-generator.md` (noise heightfield + `Terrain:WriteVoxels`;
  heightmap import is UI-only; markers as CollectionService tags; assets by id with a manifest;
  Save to File outside the repo before every rebuild). Start from its "smallest first generator task".

## The design must give
- Owners: the generator (Edit-time only, never at runtime), the asset manifest, the markers the game
  reads (`docs/design/drive.md` posts/drive line tags, boar spawns), and how the grey-box `TestArena`
  is replaced cleanly (it owns `Workspace.TestArena` today).
- How a run is invoked (an MCP command through a harness-like tool), made reproducible (seed), undone
  (backup), and checked (screenshots + a spec that the required tags exist and are reachable by the
  boar's pathfinding).
- The typed-value question (TASKS row 16): which templates live on disk as `.model.json` with typed
  values and what the harness must learn to compare, or why placement by code avoids it.
- Numbers: map size, part/mesh budgets, streaming, and which are Karen's taste values.
- The smallest first build task (the 512 × 512 slice), then the order of the rest.
