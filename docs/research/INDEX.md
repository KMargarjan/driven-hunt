# Research index

One line per note (rule 1). Newest first.

| Date | Note | System | Decision |
|---|---|---|---|
| 2026-09-24 | [map-generator](2026-09-24-map-generator.md) | Map generator (Milestone 2): terrain, vegetation, markers, assets, backups | **Studio's heightmap import cannot be driven from code or MCP**, so a seeded Luau noise heightfield (domain warping) written with `Terrain:WriteVoxels` at edit time; markers are `CollectionService` tags so the map carries no scripts; Creator Store and Meshy assets referenced **by id with a manifest, never committed**; `File -> Save to File` outside the repo before every rebuild. 2048x2048 studs, <=20k parts, <=8k visible |
| 2026-09-24 | [toolchain](2026-09-24-toolchain.md) | Dev toolchain: sync, packages, lint/format/CI, tests, Studio automation | Rokit + Rojo 7.7 + Wally + selene + StyLua + TestEZ; Studio built-in MCP harness with sync-token gate (revised rounds 2–4; current behaviour: `tools/studio_mcp.py` docstring) |
