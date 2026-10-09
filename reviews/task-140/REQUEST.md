# Task 140 - the rifle with a scope

Task: 140
Round: 2
Base: main (`482a611`)
Code commit: `b5ec4218b8535187b04715f6717527f2b3211803`

```
[harness] PASS: 33/33 checks @ b5ec4218b8535187b04715f6717527f2b3211803 (clean tree) scope=all
```

`test2` is N/A: nothing in this diff touches `TWO_PLAYER_PATHS` (`src/server/Match/`, `MatchBoot`,
`src/client/Match/`, `src/shared/Drive/`, `tests/client/Role.luau` or their specs).

Built to `docs/design/rifle.md` (Architect PASS, `reviews/task-140/ARCH_RESULT.md`). Karen, 2026-10-09:
*"afther this fixes we need to add rifle with scope"*, and she picked the model because *"it's already
with scope"*. Behind the `RIFLE` flag, born OFF.

## Round 2: both blocking findings, and five notes that were real defects

1. **The arming sweep counted a repair on every pass.** `holdsTool` became per weapon and the
   sweep's call was not updated, so the table read answered nil, the call answered false and
   `stats.armingRepairs` rose unconditionally -- which would have destroyed the one instrument this
   repo has for "a player who should be holding a gun and is not" (0 in every run since task 34).
   It counts against the loadout now. **Verify:** the sweep's loop in `Weapon.start`.
2. **Claim 10 was false and is now true.** Version 4's three refusals -- a missing weapon set, one
   carrying both actions, one carrying neither -- were reachable by no test. `viewmodel_poses.spec`
   drives all three through its own `broken()` helper, plus "one flat name set, whichever weapon is
   asked for". **Verify:** "names a weapon set that is missing, and one that carries two actions or
   none".

...and five notes, each a real defect rather than a wording fix: the **dead third copy** of the
rifle's asset keys, in a DIFFERENT order from the two that are read (and the order decides which key
is worn as `Model`); the Validator's **hardcoded shotgun ammo list**; **one warn flag shared by every
mesh key**, so a missing `rifle.scope` was silent once `shotgun.barrels` had warned; the **reticle
laid out from the weapon's target FOV** rather than the frame's own, which is wrong for the 0.2 s of
the raise; and a comment claiming a call to `Mode.segmentAt` the code never made.

Two of the Reviewer's other notes are also closed: the **drive report's detail row names the gun**
(design section 9, which round 1 did not build), and `hitlog.spec` asserts the weapon reaches the dot
and the FATAL dot's weapon reaches the row.

**`boar_body.spec:663` is flaky and it is not mine.** It failed once at this exact commit (the
sounder's scatter-spread assertion) and passed on the next run of the SAME commit with nothing
changed; it flipped the same way during task 139. Reported rather than hidden: the PASS line above
is the second run.

## The ten claims

1. **A second weapon lives behind the SAME owner, and the shotgun's numbers did not move.**
   `src/shared/Weapons/init.luau` is one frozen row per gun with no writer; the shotgun's row is
   BUILT from `Shotgun.CONFIG`, never copied out of it. **Verify:** `tests/server/rifle.spec.luau`
   asserts the row field by field against that config, including the four `RELOAD_*` numbers as the
   `CYCLE` list and `CYCLE_TOTAL == RELOAD_TOTAL`; `git diff` on `src/shared/Shotgun/init.luau`
   touches only the two type blocks and one new system number (`EQUIP_RATE_LIMIT`).

2. **No row may carry a rule of the drive or of the protocol.** The safety arc, the camera-origin
   tolerance, the rate limits, `AUTO_EQUIP` and `shouldArm` stay in `Shotgun.CONFIG`. **Verify:**
   `rifle.spec`'s "carries NO rule that belongs to the drive or to the protocol" walks every row
   and asserts each is absent; grep `SAFETY_ARC_HALF_DEG` in `src/shared/Weapons/`.

3. **Two Tools, and the switch costs nothing on the server.** The engine's own hotbar moves
   `Tool.Parent`, which `watchEquipped`'s `sync()` already watches; `Weapon.heldId(player)` is
   written by that same function in the same frame as `equipped`, so the two cannot disagree.
   **Verify:** grep for a new remote or `ContextActionService` binding -- there is none;
   `Hardware.equip`'s callers are still `Weapon.grant` and `Weapon.upgradeLook` only. MEASURED in a
   live session: `held=Shotgun bag=Rifle` at the spawn, `held=Rifle bag=Shotgun` after a switch,
   and back.

4. **The scope is ONE NUMBER handed to the camera.** `Camera.setOpticsSource` is the third injected
   source beside the aim and break sources; `Mode.fovFor(blend, config, aimFovDeg)` and
   `Camera.Rig` is still the one writer of `FieldOfView`. **Verify:** `rifle_client.spec` asserts
   `fovFor(1, config, nil) == FOV_AIM_DEG` (the shotgun's 50) and `== 19.87` with the rifle's;
   `rifle.spec` asserts `tan(35)/tan(aimFovDeg/2)` IS the stated magnification. MEASURED live:
   `fov=19.87` with the rifle aimed, `fov=70.00` in the hip view and with the shotgun.

5. **The mouse slows with the zoom with no new code**, because the sensitivity already derives from
   the blended FOV. **Verify:** `rifle_client.spec` asserts `sensitivityScale(19.87)` is 1/4 within
   1e-2.

6. **The reticle is the Hud's, in DEGREES, and is a sibling of the crosshair.**
   `Hud.reticleVisible(mode, optics)` is pure and public and asks a different question from
   `Hud.crosshairVisible`. **Verify:** `rifle_client.spec` drives four cases of the predicate,
   measures the ring against `reticleDegToPx` and the LIVE viewport (± 2 px), and asserts the
   crosshair is false in first person with either gun. `.screenshots/t140-rifle-scoped.png`.

7. **The sway moves the VIEW, never the player's aim, and is exactly zero in the hip view.**
   **Verify:** `rifle_client.spec` steps 10 s of sway at full blend -- the wander stays inside
   `ampDeg` and `pitchDeg`/`yawDeg` never move -- and asserts `Vector2.zero` at blend 0 and that
   the phase does not advance for a weapon with no scope.

8. **The bolt is the sequence the state machine already runs, as data.** `StateMachine.apply` takes
   the row and has no default; `runCycle` is one runner for both weapons. **Verify:** `rifle.spec`
   walks ready → spent → open → fed → ready with the rifle's row and asserts `"is-open"` for a
   second trigger pull. MEASURED live: the drawn bolt sits at (0, 0, 0.515) roll 0 at rest and at
   (-0.095, 0.055, 0.935) roll -60 mid-cycle -- exactly `drawStuds` 0.42 and `liftDeg` 60.

9. **The report names the gun.** The weapon enters at `Hits.group` -- the one constructor of a
   `HitReport` -- and `HitLog` copies it as it copies `zone`. **Verify:** `rifle.spec` asserts the
   report carries it and that a caller naming no weapon still works (nil on the wire is legal);
   MEASURED live, the kill line read `Alhamdulilah824 FEMALE BOAR chest 45 m RIFLE` at 161 studs.

10. **`poses.json` is version 4 and every shotgun number moved a LEVEL, not a digit.** One set per
    weapon under `weapons.<id>`; `look` stays at the top because it is a light. **Verify:**
    `backups/2026-10-09_task-140_poses-v3.json` is the v3 file; `viewmodel_poses.spec` drives
    `validate` for both weapons and refuses a set with both `reload` and `cycle`; `rifle.spec`
    asserts `view(data, "rifle")` publishes the same flat name set as the shotgun's.

## The frames, looked at (rule 5)

| frame | what it shows, wrong first |
|---|---|
| `t140-rifle-carry.png` | The gun is large in frame and seen from behind-right, the ocular bell pointing at the camera; the stock's figure is very red and a pale blue turret sits on the action. It IS unmistakably a scoped bolt rifle: barrel away to the upper left, scope with two turrets, bolt handle below, walnut stock, a gloved hand on the fore-end, `[*] .416 10` in the readout, no crosshair |
| `t140-rifle-scoped.png` | The hole you see the world through is small -- the model's tube is narrow and the eye sits 0.9 studs back -- and the glove and butt crowd the bottom third. It reads correctly as looking THROUGH a scope: dark tube, concentric lens rings, the world and the grass visible in the middle, the duplex centred on it, FOV 19.87 |
| `t140-bolt-mid.png` | The bolt is hard to identify by eye: its underside is unlit, so it reads as a pale wedge over the action rather than a cylinder with a handle. The gun has NOT swung anywhere (the identity-lerp claim, as a picture) and the bolt group is measurably displaced; the readout says `.416 9 R` |
| `t140-report-weapon.png` | The kill line with the weapon's word in it, which is the claim; the detail view of the report panel is NOT in this frame |

## Standing rule A, Forest Test, 85 s, with the flag OFF (how it ships)

* the Tool is in the CHARACTER at 15 s and at the end -- `tool=true backpack=false` both times
* **0 fault lines in 28**
* four waves released, and `[ViewmodelAssets] published 4 of 4 rifle piece(s)`

## What I could not verify, and what I changed outside the design

* **The hotbar keys `1`/`2` were NOT driven through the harness.** They are the stock Backpack's
  CoreGui bindings and the design (§16.1) says plainly that a replayed `key 2` may not reach CoreGui.
  Every switch in this task was made with `Humanoid:EquipTool`, which is a test-only path. **The
  switch is a Karen playtest item**, and the two-Tool half of it IS evidenced: both Tools exist, each
  carries its own `DrivenHunt.Weapon` attribute, and the drawn gun and the readout follow whichever
  is in the character.
* **`HANDLE_SIZE.Z` is 4.4 and not the design's 4.1.** The four groups were prepped, uploaded and
  moderated at 4.4 before the design existed; a handle shorter than its own mesh puts the muzzle
  attachment inside the barrel, and re-prepping four uploads to move a drawn gun 0.3 studs is not a
  trade worth making. Written down in `Rifle.CONFIG`.
* **The drawn bolt returns home when the round is FED, not when the action closes** -- measured: full
  draw at +0.32 s, back at rest by +0.48 s, against a 0.90 s server cycle. It still reads as working
  a bolt; which replica edge drives `openTilt` is a dial for the look pass.
* **One capture caught the camera behind the character's head** with the reticle over the avatar --
  a respawn mid-capture. It did not reproduce in the next run and I have not chased it.
* **`Gun.Piece` grew a `transparency` field** (not in the design): a scope is the first piece in this
  game meant to be looked THROUGH, and an opaque lens filled the sight picture. Honoured by both the
  viewmodel and `Hardware.addPiece`.
* **`Weapon.upgradeLook` now re-equips only the weapon the player was already holding.** With two
  Tools the old sweep put the RIFLE in the hand at a spawn, against `AUTO_EQUIP`'s own rule. Found by
  the first live session, not by a spec.
* **The carry pose and the eye relief are seeds, not measurements.** They are content-lane data
  (`weapons.rifle.*` in `poses.json`) and the Director tunes them live with `tools/pose.py`.
