# Research index

One line per note (rule 1). Newest first.

| Date | Note | System | Decision |
|---|---|---|---|
| 2026-09-24 | [shotgun](2026-09-24-shotgun.md) | Shotgun: viewmodel, third-to-first-person aim, hit detection, break action | One camera writer and one viewmodel writer on the client (character clone under the Camera, EgoMoose MIT spring); hitscan rays, client for feedback and server for truth. FastCast2 not adopted (no travel time at these ranges, split provenance); ACS not adopted (no confirmable licence). Slug 330 studs, buckshot 100 studs / 9 pellets / ~1.6 deg cone |
| 2026-09-24 | [toolchain](2026-09-24-toolchain.md) | Dev toolchain: sync, packages, lint/format/CI, tests, Studio automation | Rokit + Rojo 7.7 + Wally + selene + StyLua + TestEZ; Studio built-in MCP harness with sync-token gate (revised rounds 2–4; current behaviour: `tools/studio_mcp.py` docstring) |
