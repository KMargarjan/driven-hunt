# Task 25 — design brief for the ARCHITECT: `docs/design/camera.md` (ROADMAP 1.4b)

Written by the Director. Run in parallel with the Builder's shotgun build (Task 24, not merged yet):
design only, nothing is built from this until Task 24 is merged and the Director dispatches the build.

## What the system must do (Karen's v1 spec)
- Third-person camera by default while walking and driving.
- Aiming (hold right mouse button) switches to a first-person aim with the shotgun held in view (ADS +
  viewmodel); releasing returns to third person. Karen wants this in v1.
- Exactly ONE camera writer in the game (rule 3). The weapon never writes `workspace.CurrentCamera`;
  `docs/design/shotgun.md` already exposes an aim flag from `PlayerScripts.Weapon` for this system to read.

## Inputs
- `docs/design/shotgun.md` (v2, Task 23) and `docs/research/2026-09-24-shotgun.md`, which already
  researched viewmodel/ADS patterns (EgoMoose FPS framework, spring modules). The previous project was
  fixed for good only by adopting those patterns: prefer them, cite them.
- `docs/PROJECT_CONTEXT.md`: the old project died of three cursor writers, one predicate answering two
  questions (mounting hid both crosshair and weapon), and a visibility audit that ignored parent
  visibility. Design against each of those explicitly.
- Tests available now (Task 6): input scenarios (keyboard, mouse buttons, mouse moves, waits) replayed
  in Play, client specs, and saved play-time screenshots (`python tools/studio_mcp.py capture`).

## The design must give
- Owners: camera (one), viewmodel (one), cursor/mouse lock (one), the aim state (who writes, who reads).
- The camera state machine (third person / aiming / transitions / death / tool unequipped / respawn).
- The seam with the weapon (aim flag, fire origin while aiming vs third person — the server validator's
  camera-origin tolerance must still hold) and with the Hud crosshair (hidden or not while aiming).
- The numbers as one config: FOV normal/aim, transition time (0.2 s is a feel default), sensitivity
  scale while aiming, viewmodel offset, spring constants; which are feel values for Karen.
- Tests: which assertions prove one writer (e.g. nothing but the camera owner sets CurrentCamera props),
  which input scenario proves right-mouse aim in and out, which screenshots are the rule-5 evidence.
- Failure modes and how they are loud. Mobile/gamepad: say what v1 does (PC first is acceptable).
