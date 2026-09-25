# Research index

One line per note (rule 1). Newest first.

| Date | Note | System | Decision |
|---|---|---|---|
| 2026-09-24 | [boar-ai](2026-09-24-boar-ai.md) | Boar AI, grey box v1: idle wander, flee, route, despawn | PathfindingService route + Reynolds steering follow + `LinearVelocity` mover on an unanchored, server-owned body; sensing and the pathfinder injected so specs need no physics. SimplePath not adopted (no canonical repo, and we need our own mover) |
| 2026-09-24 | [map-generator](2026-09-24-map-generator.md) | Map generator (Milestone 2): terrain, vegetation, markers, assets, backups | **Studio's heightmap import cannot be driven from code or MCP**, so a seeded Luau noise heightfield (domain warping) written with `Terrain:WriteVoxels` at edit time; markers are `CollectionService` tags so the map carries no scripts; Creator Store and Meshy assets referenced **by id with a manifest, never committed**; `File -> Save to File` outside the repo before every rebuild. 2048x2048 studs, <=20k parts, <=8k visible |
| 2026-09-24 | [shotgun](2026-09-24-shotgun.md) | Shotgun: viewmodel, third-to-first-person aim, hit detection, break action | Hitscan rays, client for feedback and server for truth; the server validates and never reproduces, because the Camera is not replicated. FastCast2 not adopted (no travel time at these ranges, split provenance); ACS not adopted (no confirmable licence). Slug 330 studs; buckshot 100 studs / 9 pellets / ~1.6 deg full cone. **The note argues for one camera writer and one viewmodel writer; `docs/design/shotgun.md` defers ADS and the viewmodel to a later camera task, and that cut is an open Director decision (design 13.2)** |
| 2026-09-24 | [toolchain](2026-09-24-toolchain.md) | Dev toolchain: sync, packages, lint/format/CI, tests, Studio automation | Rokit + Rojo 7.7 + Wally + selene + StyLua + TestEZ; Studio built-in MCP harness with sync-token gate (revised rounds 2–4; current behaviour: `tools/studio_mcp.py` docstring) |
