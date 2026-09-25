# Task 26 — the camera

Task: 26
Round: 3
Base: `cf431ba`
Code commit: `ec6c9a9567657ff1ee33220158ce267a212fba71`

```
[harness] PASS: 26/26 checks @ ec6c9a9567657ff1ee33220158ce267a212fba71 (clean tree)
```

96 server and 37 client `it` blocks across 13 spec files (main had 82 and 27).

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

2. **Round 2 found two more, both real, both fixed here.** (i) `Rig.acquire` waited up to 10 s for a
   `PlayerModule` this place does not have, **before** taking the camera — so every boot and every
   respawn spent ten seconds with nothing bound and the view not following the character, hidden
   behind a 20 s wait in the spec. It now sets `CameraType` first and never yields; a module that
   appears later is disabled by a `ChildAdded` watcher. (ii) `setLocalBodyHidden` lived inside the
   "alive" branch and writes only on a change, so a player who died while aiming stayed invisible to
   themselves until respawn. It is now called every frame whatever the mode.

3. **The one-writer claim is measured, not asserted.** `Rig.apply` records what it wrote and compares
   before writing again; `Cursor.apply` does the same for the mouse. Over 121 frames the client spec
   read `foreignCameraWrites == 0` and `cursorReasserts == 0`. That is a detector, so it stays true
   only while it stays zero.

4. **The camera never requires the weapon.** `CameraBoot` is the composition root and installs the
   aim source (`Input.isAiming()` **and** the replicated state says equipped), the idiom `BoarBoot`
   already uses. With no weapon in the place the camera is a working third-person camera that never
   aims — which is why the whole state machine tests on the **server** with no client at all.

5. **The pure core is tested where it can be tested exactly** (`camera_mode.spec`, server): blend
   reaches exactly 1 after `AIM_BLEND_SECONDS` at both 1/30 and 1/240 and does not overshoot; a
   mid-transition release returns from where it was, not from 1; `Dead` ignores aim; pitch clamps and
   yaw stays in (-180, 180] after 100 full turns; `sensitivityScale(70) == 1` and `(50)` is in
   (0.66, 0.67); 10,000 steps under 100 ms.

6. **The fire origin stays inside the shotgun's validator.** `MAX_DISTANCE_STUDS = 14.5` is a hard
   clamp in `Mode.cameraCFrame`; both specs assert it, and the live session measured a maximum of
   **12.57 studs** against the shotgun's `CAMERA_ORIGIN_TOLERANCE = 30`.

7. **The real right mouse button drove the real camera — and round 1 proved that my round-1 claim
   of this was false.** That test ran after the fake-source tests, which never restored the
   production source and had already moved the counters, so it passed with the `aim-hold` scenario
   deleted. It now runs **first**, while `CameraBoot`'s source is the only one installed, records a
   baseline and asserts a **delta**: this run printed `baseline ... enters=0 exits=0 history=2` and
   then `Loading,Third,Aiming,Third`. The `Aiming` in that history came from the replayed button and
   nothing else. The fake-source describe restores the production source in `afterAll`, through a new
   `Camera.getAimSource()`. Round 2 then found that the wait was satisfied by the **weapon**
   scenario's own right-button hold, so `aim-hold` was still not load-bearing; the test now waits for
   **both** holds, and this run's history is `Loading,Third,Aiming,Third,Aiming,Third`.

8. **The viewmodel is proved on screen, not merely existing**: its `Parent` is
   `workspace.CurrentCamera`, every part has `Transparency < 1`, `LocalTransparencyModifier < 1` and
   `CanQuery == false`, and the ancestor chain is walked to the DataModel. Not aiming → unparented,
   and `stats().viewmodelParented` is false.

9. **The weapon's camera assertion was rewritten, because with this task it asserted the opposite
   of aiming.** "The camera did not move across an aim hold" could only pass while the camera was deaf
   to the button. It now asserts what the weapon actually owes — that it never writes the camera —
   through the camera's own detector (`foreignCameraWrites == 0` over **501** frames) plus
   `aimEnters >= 1`, so the zero means something. Two other specs assumed they owned the only aim in
   the run and now assert their own edges.

10. **Three deviations from the design, all measured, all reported here.** (c) **`Dead` now matches
   the design and did not before**: round 1 found that look input was suppressed only for `Loading`
   and the viewmodel waited for the blend, where §4.1 says "no orbit, no input" and an immediate
   clear. Fixed, with a server assertion. (a) **This place has no
   `PlayerScripts.PlayerModule` at all** — Play-time `PlayerScripts` holds only our modules plus
   `RbxCharacterSounds` — so `GetCameras():Disable()` cannot run. `Rig.acquire` now means "the camera
   is ours" and reports the stock-module step separately (`stockCamerasDisabled()` = false, warned
   loudly at boot); the design's own §10.1 says the foreign-write detector is what matters, and it
   reads zero. (b) `setLocalBodyHidden` hides **everything** the character wears or holds, including
   the Tool: sparing parts named `Handle` left the hair across the ADS view, and sparing the Tool put
   the real gun beside the viewmodel clone — two shotguns on screen.

11. **The Hud asks the camera, not the weapon.** The crosshair is visible iff the weapon is equipped
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
- **The `aim-hold` scenario has no equip step**, unlike the design's §9.3 version: the Tool is
  already equipped by then (`AUTO_EQUIP`, and the previous scenario parks and re-equips it), and a
  number-key press reaching the CoreGui backpack is exactly what the design lists as unverified. It
  worked without one.
- **"The first scenario to send `button: right`" was wrong** in the round-1 request: the weapon
  scenario already did. Task 6a note (g) was already closed.
- **`VIEWMODEL_*_OFFSET` are the two values I changed from the design's** after looking at the
  screen, which is what the design says to do with them. They are Karen's to set.
