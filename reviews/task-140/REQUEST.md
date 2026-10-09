# Task 140 - the rifle with a scope

Task: 140
Round: 3
Base: main (`482a611`)
Code commit: `02a8927d9a4c1c4edd3f90e94c4b646105c6552c`

```
[harness] PASS: 33/33 checks @ 02a8927d9a4c1c4edd3f90e94c4b646105c6552c (clean tree) scope=all
```

`test2` is N/A: nothing in this diff touches `TWO_PLAYER_PATHS` (`src/server/Match/`, `MatchBoot`,
`src/client/Match/`, `src/shared/Drive/`, `tests/client/Role.luau` or their specs).

Built to `docs/design/rifle.md` (Architect PASS, `reviews/task-140/ARCH_RESULT.md`). Karen, 2026-10-09:
*"afther this fixes we need to add rifle with scope"*, and she picked the model because *"it's already
with scope"*. Behind the `RIFLE` flag, born OFF.

## Round 3: the one blocking finding, and six notes

**The blocking one was a real defect and the Reviewer is right about every step of it.**
`Poses.config` grew an early return this task -- `if raw == nil and wanted == DEFAULT_WEAPON then
return base end` -- and it answered BEFORE the cache was written. `tools/pose.py clear`, and
`pose.py compare`'s own release path, both clear by REMOVING the attribute, so the next frame reads
nil, took that return, and `cachedHold` went on holding whatever the last override said.
`Camera.update` applies `Poses.holdState` every frame, so the camera and the drawn gun stayed pinned
at `mode = "Aiming"`, `blend = 1` for the rest of the session -- and the path WORKED before this
task. The early return is gone: the `(raw, weaponId)` cache below it is the fast path on its own
(nil and the default weapon resolve to `base` itself once, then cost one string compare and one
table read). **Verify:** `camera_client.spec`, "releases a held pose when the attribute is removed,
not just when it changes" -- it sets `{"hold": "aim"}`, REMOVES the attribute, and expects
`Poses.hold()` nil and `Poses.config` back to the base table. MEASURED LIVE in the Forest Test:
`hold set=aim after the attribute was REMOVED=nil`.

**Six notes, each a real defect:** `setTemplateProvider` reset the old single warn flag but not the
per-key table this task added, so a second borrow of the seam was silent; the detail row's GUN column
sat after HITS and design section 9 says after the DISTANCE; `holdState` zeroed `blend` and
`openTilt` but not `scopeSwayDeg`/`scopePhase`, so a held frame was photographed mid-wander (design
7.3, the Reviewer's note in rounds 1 and 2 -- closed now); a comment claimed `viewmodel_poses.spec`
asserts `weapons.shotgun` against the archived v3 file, which no spec can do (`backups/` is a path on
disk that nothing syncs) and it now says so; BOTH sway cases started from `Camera.getState()`, so
"the sway is zero in the hip view" held only because the live blend happened to be 0, and they start
from a fabricated at-rest state now; and the hitlog case's name claimed a row it never built.

**MEASURED LIVE in Karen's own place**, one probe through the running client, which is the half a
spec cannot show -- the header and the row as the panel prints them, and the release:

```
holdState sway=(0.000, 0.000) phase=0.000
header='ANIMAL   RESULT   ZONE     RANGE  GUN       HITS'
row='FEMALE   DOWN     chest     13 m RIFLE        1'
hold set=aim after the attribute was REMOVED=nil
```

**Two new cases failed the first gate run of this round, and both were my test's fault rather than
the code's** (reported per rule 8): `Data.view` rebuilds its table-valued names on every call, so
comparing the second weapon's whole view by identity was the wrong question -- it compares by value
for every scalar now, and asserts at least one differs from the shotgun's; and the detail row's
`distance` is in STUDS while the column prints METRES (45 studs is 13 m), so the range field is
matched as a pattern. Second run: 33/33.

**`boar_body.spec:663` PASSED both gate runs of this round.** It failed one of round 2's on the
identical commit and passed the next; it is a physics scatter-spread assertion that flips, and it is
not this task's.

## The ten claims

1. **A second weapon lives behind the SAME owner, and the shotgun's numbers did not move.**
   `src/shared/Weapons/init.luau` is one frozen row per gun with no writer; the shotgun's row is
   BUILT from `Shotgun.CONFIG`, never copied out of it. **Verify:** `tests/server/rifle.spec.luau`
   asserts the row field by field against that config, including the four `RELOAD_*` numbers as the
   `CYCLE` list and `CYCLE_TOTAL == RELOAD_TOTAL`; `git diff` on `src/shared/Shotgun/init.luau`
   touches only the two type blocks, one new system number (`EQUIP_RATE_LIMIT`) and `snapshot`'s new
   `weapon: string?` parameter -- **no shotgun NUMBER moved**, which is the substance of the claim.

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
   `hitlog.spec` asserts the FATAL dot carries it; `rifle_client.spec` asserts the panel's own
   `detailRowText` prints the gun's WORD after the distance and prints nothing at all (not "nil") for
   a record from before the rifle. MEASURED live, the kill line read
   `Alhamdulilah824 FEMALE BOAR chest 45 m RIFLE` at 161 studs.

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

## Standing rule A, Forest Test, 85 s, with the flag OFF (how it ships) -- re-run this round

* the Tool is in the CHARACTER at 15 s and at 85 s (`gun in hand @15s=1 @85s=1`)
* **0 "Stack Begin" and 0 error lines** in the whole console, and 0 again in the separate probe run
* **five waves released**, worst 2 boar sounds at once over 10 s with 29 boars alive
* the changed feature ran: the probe above is that session's own client

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
* **`weapons.rifle.cycle.shells.feedSeconds` still ships, against design 8.2**, and this is the
  disclosure the Reviewer asked for rather than a fix. `Viewmodel.validate` REQUIRES all four shell
  keys and `Viewmodel.view` reads `feedSeconds` into `SHELL_FEED_SECONDS`, so removing it from the
  rifle's block is a schema change plus a branch in the drawn feed -- engineering, in the last round
  this task has, to change a shell nobody has complained about. Queued as 140a.
* **`detailPayload`'s own copy of the weapon onto the row is asserted by no spec.** It is a `local`
  function reachable only through `onRequest`'s remote, which a server spec cannot read back. The
  SCREEN half is a spec (`rifle_client.spec`, above) and the wire half rests on the live kill.
* **`weapon_state.spec` and `camera_mode.spec` still have none of design 13.1's named cases** --
  `Registry:forget` dropping both weapons' states, a switch leaving the other weapon's state identical
  by value, the view pitch inside its clamp with sway and recoil both at full, `cycleProgress` at
  three frame rates. Noted in rounds 1 and 2, queued as 140a, not fixed here.
* **`Poses.resolve`'s `weaponId` argument now has a spec** (`viewmodel_poses.spec`, the
  second-weapon-no-override branch a published server takes), which was a round-2 note.
* **The carry pose and the eye relief are seeds, not measurements.** They are content-lane data
  (`weapons.rifle.*` in `poses.json`) and the Director tunes them live with `tools/pose.py`.
