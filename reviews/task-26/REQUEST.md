# Task 26 — the camera

Task: 26
Round: 1
Base: `cf431ba`
Code commit: `630b4a98212c4dc8de1e4c303a85ee54e1a51f3a`

```
[harness] PASS: 26/26 checks @ 630b4a98212c4dc8de1e4c303a85ee54e1a51f3a (clean tree)
```

95 server and 37 client `it` blocks across 13 spec files (main had 82 and 27).

## Task

ROADMAP 1.4b, built to `docs/design/camera.md` (Architect `PASS`). Karen's option A, 2026-09-25:
mouse-locked over-the-shoulder third person, the stock camera module disabled and the stock movement
module kept, hold right mouse for first-person ADS with a viewmodel, cursor visible only in menus.
Feel values stay the design's defaults. **Feel-critical: not mergeable until Karen has played it.**

## Claims

1. **One writer each, as designed.** `PlayerScripts.Camera` owns the mode state, the one
   `BindToRenderStep` and the one mouse-movement connection; `Camera.Mode` is pure; `Camera.Rig` is
   the only assignment to `workspace.CurrentCamera` in the repo; `Camera.Cursor` the only writer of
   `MouseBehavior`/`MouseIconEnabled`; `Camera.Viewmodel` the only writer of the first-person model.
   Owner rows are in `GAME_DESIGN.md` (Camera filled, three added, UI and Input amended).

2. **The one-writer claim is measured, not asserted.** `Rig.apply` records what it wrote and compares
   before writing again; `Cursor.apply` does the same for the mouse. Over 121 frames the client spec
   read `foreignCameraWrites == 0` and `cursorReasserts == 0`. That is a detector, so it stays true
   only while it stays zero.

3. **The camera never requires the weapon.** `CameraBoot` is the composition root and installs the
   aim source (`Input.isAiming()` **and** the replicated state says equipped), the idiom `BoarBoot`
   already uses. With no weapon in the place the camera is a working third-person camera that never
   aims — which is why the whole state machine tests on the **server** with no client at all.

4. **The pure core is tested where it can be tested exactly** (`camera_mode.spec`, server): blend
   reaches exactly 1 after `AIM_BLEND_SECONDS` at both 1/30 and 1/240 and does not overshoot; a
   mid-transition release returns from where it was, not from 1; `Dead` ignores aim; pitch clamps and
   yaw stays in (-180, 180] after 100 full turns; `sensitivityScale(70) == 1` and `(50)` is in
   (0.66, 0.67); 10,000 steps under 100 ms.

5. **The fire origin stays inside the shotgun's validator.** `MAX_DISTANCE_STUDS = 14.5` is a hard
   clamp in `Mode.cameraCFrame`; both specs assert it, and the live session measured a maximum of
   **12.57 studs** against the shotgun's `CAMERA_ORIGIN_TOLERANCE = 30`.

6. **The real right mouse button drove the real camera.** A new `aim-hold` input scenario (the first
   to send `"button": "right"`, which closes Task 6a note (g)) produced the mode history
   `Loading,Third,Aiming,Third,Aiming,Third`; the spec asserts `aimEnters >= 1` and `aimExits >= 1`
   from the owner's own counters, recorded from boot.

7. **The viewmodel is proved on screen, not merely existing**: its `Parent` is
   `workspace.CurrentCamera`, every part has `Transparency < 1`, `LocalTransparencyModifier < 1` and
   `CanQuery == false`, and the ancestor chain is walked to the DataModel. Not aiming → unparented,
   and `stats().viewmodelParented` is false.

8. **The weapon's own camera assertion still passes** (`weapon_client.spec`, "never touched the
   camera while aiming"): `CameraType`, `FieldOfView` and `CameraSubject` identical across the aim
   hold, drift 0.000 studs. Nothing in `src/client/Weapon/` or `src/client/Hud/` assigns the camera.

9. **Two deviations from the design, both measured, both reported here.** (a) **This place has no
   `PlayerScripts.PlayerModule` at all** — Play-time `PlayerScripts` holds only our modules plus
   `RbxCharacterSounds` — so `GetCameras():Disable()` cannot run. `Rig.acquire` now means "the camera
   is ours" and reports the stock-module step separately (`stockCamerasDisabled()` = false, warned
   loudly at boot); the design's own §10.1 says the foreign-write detector is what matters, and it
   reads zero. (b) `setLocalBodyHidden` hides **everything** the character wears or holds, including
   the Tool: sparing parts named `Handle` left the hair across the ADS view, and sparing the Tool put
   the real gun beside the viewmodel clone — two shotguns on screen.

10. **The Hud asks the camera, not the weapon.** The crosshair is visible iff the weapon is equipped
    **and** `Camera.getMode() ~= "Aiming"`; the Hud still works with no camera present. The camera has
    no reference to the Hud.

## What I could not verify

- **Karen has not played it.** Every feel value is the design's default.
- **The fourth screenshot (camera against cover) could not be staged.** The camera's yaw is mouse-
  driven and the harness cannot deliver usable deltas under `MouseBehavior = LockCenter`, so I cannot
  put a wall behind the camera on demand. Occlusion is asserted numerically instead (injected cast:
  the camera sat at **3.50** studs for a hit at 4.0 with a 0.5 pad) and I have a third-person shot
  standing beside a cover block with no clipping.
- **Rotation by replayed mouse input is untested**, for the same reason; the rotation maths is covered
  by the server spec.
- **`execute_luau` has its own module cache**, so reading `Camera.getMode()` through it returns a
  fresh module's `Loading`. Every screenshot reading above came from real Instances (FOV,
  `CameraType`, crosshair `Visible`, the viewmodel's presence under the camera).
- **`VIEWMODEL_*_OFFSET` are the two values I changed from the design's** after looking at the
  screen, which is what the design says to do with them. They are Karen's to set.
