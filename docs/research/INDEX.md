# Research index

One line per note (rule 1). Newest first.

| Date | Note | System | Decision |
|---|---|---|---|
| 2026-09-24 | [boar-ai](2026-09-24-boar-ai.md) | Boar AI, grey box v1: idle wander, flee, route, despawn | PathfindingService route + Reynolds steering follow + `LinearVelocity` mover on an unanchored, server-owned body; sensing and the pathfinder injected so specs need no physics. SimplePath not adopted (no canonical repo, and we need our own mover) |
| 2026-09-24 | [toolchain](2026-09-24-toolchain.md) | Dev toolchain: sync, packages, lint/format/CI, tests, Studio automation | Rokit + Rojo 7.7 + Wally + selene + StyLua + TestEZ; Studio built-in MCP harness with sync-token gate (revised rounds 2–4; current behaviour: `tools/studio_mcp.py` docstring) |
