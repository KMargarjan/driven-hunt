# Task 37 — design brief for the ARCHITECT: `docs/design/asset-pipeline.md` (Milestone 2)

Written by the Director at night, in parallel with the Builder (Task 35). Nothing is built from this
until Karen hands over her first models.

## Inputs and decisions
- Karen makes models in Meshy (texture on, remesh inside Meshy to the target triangle count, FBX
  export) — boar, break-action shotgun, hunter's high seat, spruce/birch/oak; she drops the files in
  `C:\Users\karen\Desktop\driven-hunt-assets\` (outside the repo; the repo is public).
- Borrow first: Creator Store assets where they fit (licence: use on Roblox, not redistributable —
  never committed). `docs/research/2026-09-24-map-generator.md` and `docs/design/map-generator.md`
  (assets by id with a manifest, never committed binaries; `.rbxm` is banned).
- Upload via Roblox Open Cloud Assets API with an API key held ONLY in a Windows environment variable
  (never in the repo, logs or reports; the repo is public; CLAUDE.md "never commit secrets").
- The previous project had `tools/upload_asset.py` and a hand-written FBX reader that caused a run of
  normals bugs — invented foundations. Borrow the official Open Cloud endpoints and Roblox's own
  importer behaviour; do not parse FBX ourselves.

## The design must give
- Owners: the asset manifest (ids, source, licence, triangle/texture budget, provenance), the upload
  tool, and how game code / the map generator resolve an asset (by manifest key, never a raw id in code).
- The Open Cloud flow: which endpoint(s), operation polling, what the key needs (scopes), rate limits,
  failure modes and how they are loud; what Karen must click once to create the key (exact Creator Hub
  steps), and how the key is stored (env var name) and never echoed.
- Validation before upload: triangle/texture limits (mark which are first-party vs community figures),
  file naming, a dry-run mode.
- How a mesh becomes a usable in-game model (MeshPart + textures/SurfaceAppearance, scale 1 stud =
  0.28 m, pivot, collision fidelity) and how that template lives on disk (ties to TASKS row 16, typed
  values) or is built by code.
- Tests and screenshots that prove a model looks right (the old project's "measured correct, looked
  wrong": purple untextured legs, a backwards knife) — rule 5 applies.
- The smallest first task (one model end to end).
