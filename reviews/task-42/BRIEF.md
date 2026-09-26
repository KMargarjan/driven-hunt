# Task 42 — ARCHITECT: regenerate `docs/design/map-generator.md` with the asset research

Written by the Director. `docs/research/2026-09-26-asset-pipeline.md` (Task 39, sources fetched) and the
regenerated `docs/design/asset-pipeline.md` (Task 40) change assumptions the map design rests on:
- D9: `AssetService.AllowInsertFreeAssets` is RobloxScriptSecurity — a free Creator Store model the
  experience owner does not own cannot be loaded by any script route. The map design's §8.2 plan to
  place Creator Store props by id at edit time must be re-examined: what the generator (Edit-time,
  via MCP `execute_luau` / `insert_asset`) can and cannot insert, and how an asset gets into the
  experience owner's inventory first (the asset pipeline's manifest is the one source of asset ids).
- The corrected limits (20,000 triangles first-party; texture sizes) and the licence-basis field.
- The Task 39 note lists four corrections that belong to the map-generator research note and design.
Keep the Director's decisions in reviews/task-33/BRIEF.md (tools/mapgen.py allowed; M2.6 streaming its
own task; spawn pads flattened in terrain). Keep the backup rule (Save to File before a rebuild) —
note that the Director can now press Studio shortcuts (Alt+Shift+S = Save to Roblox) but there is no
shortcut-free route to Save to File yet; say what the generator's refusal should accept.
No local absolute Windows paths in the design (the repo is public).

## Director decisions on the regenerated design (2026-09-26 night, after the Architect's PASS)
- A: accepted. `--backup census` is allowed for M2.1 and M2.2; the `.rbxl` stays mandatory when the
  census is not clean.
- B: accepted. The Director owns the Alt+Shift+S (Save to Roblox) route; the Builder's report ends with
  the reopen + `contract` proof, never a claim that the place was saved.
- C: accepted. Creator Store props withdrawn until M5; ROADMAP speed rule 6 narrowed accordingly.
- D: M2.3 is dispatched as "proxies, real ids to follow" unless Karen's Meshy answer arrives first.
