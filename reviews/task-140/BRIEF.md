# BRIEF for the Architect: the rifle with a scope (task 140)

Design run: `tools/architect.sh design rifle --task 140`. This file is the input and it overrides
anything older in `docs/`, `TASKS.md` or an earlier design.

Read first: `docs/research/2026-10-09-rifle-scope.md` (this task's note, committed before this brief),
then `docs/design/shotgun.md` and `docs/design/camera.md`, which this design extends rather than
replaces.

---

## 1. Why this exists

Karen, 2026-10-09, having accepted task 139 (*"all good / next"*):

> *"afther this fixes we need to add rifle with scope and with aimpoint / should be faster since we
> know ho it works"*
>
> *"https://sketchfab.com/3d-models/dae-rigby-hunting-rifle-game-ready-asset-e77855f0c3ea4340a4d67a4ece4b87ac
> / I think we inaf this one it's already with scope"*

The Director's cut: **the Rigby with its mounted scope. The separate Aimpoint red dot is a later
task.** Karen's *"should be faster since we know how it works"* is a standing instruction to reuse,
not to re-derive (rule 2).

## 2. Decisions ALREADY TAKEN -- do not re-open these

1. **The scope is a field-of-view zoom plus a flat reticle overlay.** Picture-in-picture is
   impossible on this engine, and the research note proves it from Roblox's own `ViewportFrame`
   page. Do not design a render-to-texture scope.
2. **The aim FOV is one number per weapon**, applied through the existing camera machinery:
   `Camera.Config.FOV_AIM_DEG` / `Camera.Mode.fovFor` / `Camera.Mode.sensitivityScale` /
   `Camera.Rig` as the one writer of `cam.FieldOfView`. 4x = 19.87 deg is the first cut.
   **No new camera owner, and no second writer of `FieldOfView`.**
3. **One weapon owner.** `src/server/Weapon` stays the only writer of Tool instances and the only
   validator of a shot. The rifle is a second CONFIG, not a second system.
4. **Hitscan**, with the server validating exactly as it does now. No travel time, no bullet drop
   (the note records FastCast2 as considered and rejected, twice now).
5. **The shotgun's numbers do not move.** Karen approved that gun on 2026-10-09 (*"gun is ok"*).
6. **Poses are data** (`src/shared/Viewmodel/poses.json`, the content lane): carry and aim poses for
   the rifle are rows in that file, tunable live with `tools/pose.py`, not Luau.
7. **No crosshair in the hip view.** Karen's standing rule since 2026-09-27. The reticle exists only
   while scoped.
8. **Switching is `1` = shotgun, `2` = rifle** (the Director's dispatch).
9. The asset is uploaded by the **Director** with Karen's OK; the scope's maker name and logo are
   painted out of the atlas first. Not a design question -- stated so the design does not invent an
   asset route.

## 3. What the design MUST contain

### 3.1 The weapon table and the equipped weapon -- the owner boundary

Today `src/server/Weapon/init.luau` does `local Shotgun = require(...)` and `local CONFIG =
Shotgun.CONFIG` at file scope, and `Weapon.Hardware` builds **one** Tool per player, found by a
single name. Every per-player table already lives behind `Weapon.Registry`, which keys by any value
and has one `forget`.

The design must settle, with the file and symbol named for each:

* **Where the set of weapons lives** -- one shared module listing the rows, or a row per module with
  a registry that collects them -- and which module each weapon's numbers belong to. The shotgun's
  are in `src/shared/Shotgun`; say whether the rifle's go in `src/shared/Rifle`, and what, if
  anything, moves into a shared `src/shared/Gun`-level place. `src/shared/Gun` already exists and is
  the drawn gun's geometry.
* **How "which weapon is this player holding" is represented and where it is written.** It must be
  readable by: the fire path (which numbers to validate against), `Hardware` (which Tool to build),
  the client's viewmodel (which pose set to draw), and `HitLog` (which weapon to record). Name the
  one owner of that fact and the route by which each of those four reads it.
* **Whether a player carries two Tools or one Tool that changes.** Both are real options with real
  consequences: two Tools means the hotbar and `Tool.Equipped` do the switching for us and
  `Hardware`'s "one Tool per player, found by name" assumption and the stray-Tool sweep both change;
  one Tool means `Hardware` rebuilds the gun in place and the Tool-in-the-character invariant
  (standing rule A, checked by the smoke every round) is unaffected. **Pick one and say why.**
* **What the per-weapon state is** -- the shotgun's `WeaponState` carries two barrels, an ammo kind
  and a reserve -- and whether a switch preserves the other weapon's state (a half-cycled bolt, a
  spent shell). State the rule; "the state is dropped on switch" is an acceptable answer if it is
  stated.
* **The rate limits.** `Limits` buckets are per player per name today. Say whether switching is
  itself rate-limited and under which bucket -- an unthrottled switch remote is a free DoS on
  `Hardware`.

### 3.2 The scope view

* **Who owns the reticle** -- it is drawn UI, so it is the Hud's by rule 3, but the thing that knows
  "aiming, with a scoped weapon" is the camera/weapon client. Name the owner and the one signal
  between them.
* **What the reticle is**: UI primitives, no upload, sized in *degrees* rather than pixels so that
  the duplex stays true at any screen size and any magnification. State the geometry as data.
* **Where the magnification lives** so that the camera does not learn what a rifle is: a weapon row
  carries `aimFovDeg`, and the camera is told a number. Name the module that tells it, and the path.
* **The sway**: who applies it (it must not be a second writer of the camera CFrame), whether it is
  a camera offset or a viewmodel offset, and how it is switched off for a spec. The note's numbers
  are 0.25 deg amplitude, 4 s period, figure-eight; they are dials.
* **What happens to the scope when the shot goes off** -- recoil already exists as a spring in the
  viewmodel; say whether the scope view inherits it and whether the reticle moves with it.

### 3.3 The bolt

* **Which state machine**. `Weapon.StateMachine` owns the shotgun's break/load/close. Say whether
  the bolt is states in that machine or a per-weapon sequence table it reads, and what the rifle's
  legal transitions are (fire -> cycling -> ready; can the player aim while cycling?).
* **The drawn handle**: it is a piece of the viewmodel, animated from pose data. Name the data shape
  (a named pose per bolt phase, or one pose plus a parameter) and the owner that plays it.
* **What a second trigger pull during the cycle does** -- refused, queued, or ignored -- and where
  that rule lives, so it is one rule and not three.

### 3.4 The report

`HitLog.recordHit`'s dot carries `zone`, `u`, `v`, `side`, `distance`, `pellets`, `at`, `fatal` --
and no weapon. The Director asks that the report name the weapon. Say **where the weapon name enters
the hit report** (`Weapon.Hits.group` builds the report the signal carries) and what the report panel
does with it, keeping `docs/design/drive-report.md`'s owner boundaries.

### 3.5 What must NOT change

Name these explicitly so a reviewer can check them: the shotgun's ballistics, the safety arc, the
penalty, the boar, the drive, and `Camera.Rig` as the one writer of the camera.

## 4. Open questions the design should answer, or record as the Director's

1. Does the rifle have the **safety arc** rule too? (It is `src/server/Weapon/SafetyArc.luau`, a
   weapon-side geometry rule that triggers `Match.Penalty`.) The honest default is yes, unchanged,
   because pointing any gun down the line is the offence -- but say it.
2. Is the rifle **granted to every hunter from the start**, or is it a pickup/loadout choice? Karen's
   economy ideas (`karen-game-vision-2026-10-04`) have weapons being bought; nothing of that exists
   yet. The cheap answer is both guns from the start, behind a flag if it is feel-critical.
3. **Which flag**, if any. Feel-critical paths are born OFF with an `expires` inside 21 days
   (`src/shared/Flags`). A whole second weapon that nobody can reach is also a weapon nobody can
   test; say whether `RIFLE` is a flag or whether the gate is simply "it is not in the hotbar yet".

## 5. Budget

One design run. The design is for **the new pieces only** -- the weapon table and the switch, the
scope view, the bolt, and the report's weapon field. Everything else in this task is the shotgun's
existing design applied again.
