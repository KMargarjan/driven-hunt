# Task 40 — ARCHITECT: regenerate `docs/design/asset-pipeline.md` with the research deltas

Written by the Director. Task 39's research note `docs/research/2026-09-26-asset-pipeline.md` fetched
every source and found 17 deltas against the Task 37 design, three of which change what M2.7a builds:
- D5: Open Cloud never mints a Mesh asset; an FBX upload yields a Model id; `CreateMeshPartAsync` is a
  derived second step, not a route chosen by a measurement.
- D6: `MeshPart.RenderFidelity` is PluginSecurity to write and `CollisionFidelity` cannot change at run
  time — set at import, asserted by a spec; the Loader cannot apply them.
- D9: `AssetService.AllowInsertFreeAssets` is RobloxScriptSecurity: a free Creator Store model nobody
  owns cannot be loaded by any script route (contradicts map-generator design §8.2).
Also: mesh limit 20,000 triangles and first-party; TEXTURE_MAX_PX 1024 is ours; 20 MB is Roblox's;
Highlight limit 255; `CreateMeshPartAsync` signature; `MODERATION_STATE_*` strings; key-page labels.
The research note is the source of truth where it conflicts with the old design. Keep the Director's
decisions from reviews/task-37/BRIEF.md (two tasks 7a/7b; tools/assets.py and CI steps allowed).
Karen's Meshy licence question stays open (free plan: Meshy owns output under CC BY 4.0, which is not
sublicensable as Roblox's Creator Terms require) — design the manifest so every asset records its
licence basis and the CI refuses a shipping asset whose basis is unresolved.
Do not use local absolute Windows paths in the design (the repo is public); write <assets-dir>.
