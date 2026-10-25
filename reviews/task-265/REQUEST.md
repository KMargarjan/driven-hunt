# Task 265 -- round 2: is the 3-stud rearward offset the deer's travel or an aiming error?

Task: 265
Round: 2
Base: 670416e6 (main, which includes 264)
Code commit: 75539a9498dc533f65ceef7214a6c9578f18b798

`[harness] PASS: 34/34 checks @ 75539a9498dc533f65ceef7214a6c9578f18b798 (clean tree) scope=all`
`[harness2]` N/A: the code commit changes `src/server/Weapon/init.luau`,
`src/shared/Ballistics/init.luau` and one research note, none of which is in `TWO_PLAYER_PATHS`
(the weapon is on the exempt list; Director decision 2026-10-03).

## ROUND 1's TWO FINDINGS, AND WHAT THIS ROUND DID WITH THEM

1. *"the range table was config arithmetic"* -- **accepted and dropped as evidence.** It is not
   quoted anywhere below. The replacement metric is built so that the two sides cannot agree by
   construction (claim 1).
2. *"the proof shot's miss was reported as clean"* -- **accepted.** The answer is claims 3 and 4:
   most of that offset is distance ALONG the line, and the aiming error across it is 0.02 studs.

## PLAN (core quality protocol step 0)

- **(a) REAL LIFE.** A scoped rifle puts the bullet on its line of sight; the research note
  (`docs/research/2026-10-24-real-shooting.md`) gives the residual as 1.6 cm inside 60 m, which is
  0.057 studs at 0.28 m/stud.
- **(b) MEASURED NOW.** `265-shotspy.luau`, in the Forest Test, real focused clicks: the
  perpendicular distance from the server's impact to the client's own camera ray at the trigger is
  **0.008 / 0.020 / 0.028 studs** at 36.5 / 86.2 / 319.4 studs, on targets whose measured velocity
  is **0.000**.
- **(c) TARGET.** The dispatch's 0.3 studs for a still target.
- **(d) LEVER.** `Ballistics.launchDirection` / `Ballistics.boreOrigin` /
  `Shotgun.CONFIG.BORE_ON_SIGHT_LINE`, written in `src/server/Weapon/init.luau`'s `onFireRequest`
  (`local origin = Ballistics.boreOrigin(req.origin, req.direction, muzzle,
  CONFIG.BORE_ON_SIGHT_LINE)`, `local bore = Ballistics.launchDirection(aim, ballistic)`).
  **No lever was moved.** (b) is inside (c) by a factor of ten, so there is nothing to change --
  and step 0 says a refuted premise is a finished item, not a failure.
- **(e) HOW IT IS MEASURED AFTER.** The same probe, `265-shotspy.luau`.

**THE ONLY `src/` CHANGE THIS ROUND IS THREE COMMENTS** (claim 8). No expression, no number and no
behaviour changed.

## Claims

1. **The metric can fail, which round 1's could not.** One side is the CLIENT's camera ray, cast on
   `UserInputService.InputBegan` for MouseButton1 -- the event `Weapon.Input.fire` answers -- with
   the same origin and direction the client sends (`src/client/Weapon/Input.luau` `Input.fire`:
   `{ origin = cframe.Position, direction = cframe.LookVector.Unit }`). The other is the point the
   SERVER resolved and broadcast on `ShotLanded`. A client whose crosshair says one thing while the
   server shoots another shows up as a non-zero `ACROSS`. *Verify:* `<runs-dir>/265-shotspy.luau`;
   nothing in `Ballistics` is consulted to produce either side of that comparison.
2. **The animal's velocity and its CFrame are read on the SAME frame as the trigger** (L-021), in
   consecutive lines of the `InputBegan` handler, and every local offset is expressed in that one
   CFrame. *Verify:* the handler; `rec.cf` and `rec.vel`.
3. **CORE -- the answer. On a STILL target (v = 0.000, anchored by the probe) the bullet is
   0.008 / 0.020 / 0.028 studs off the client's own camera ray** at 36.5 / 86.2 / 319.4 studs,
   against a 0.3-stud target. *Verify:* the table in `<runs-dir>/ledgers/265.md` round 2 item 2;
   each row is one `ShotLanded` payload paired with one MouseButton1.
4. **And the split explains round 1's three studs.** The same rows carry `worldMiss` 0.008 / 2.105 /
   5.646 -- the straight distance from the reticle's hit to the impact. The difference is ALONG the
   line: the client's thin ray stops on the ZONE SHELL (`ZoneRear`) and the bullet stops on the
   TRUNK box behind it (`Boar170(body)`), 2.1 studs further down the same ray. *Verify:* row (b)'s
   `RETICLE ZoneRear` against `SERVER Boar170(body)` with `ACROSS 0.020` and `worldMiss 2.105`.
   **So a chest-aimed shot reported as "rump" is this geometry plus whatever the animal walked, and
   not the gun.**
5. **The negative control is on every row** (L-028): `resid0` is the residual recomputed with the
   velocity taken as zero. On these still rows `resid` and `resid0` are equal because the velocity
   IS zero -- the control saying the two agree only where they must. *Verify:* the rows.
6. **A camera-frame artefact was found, measured and excluded, not assumed away.** The first run
   read `RETICLE Terrain` against `SERVER ZoneChest`, 19.167 studs apart: `click.ps1` does a
   `SetCursorPos` immediately before the button, and under `MouseBehavior = LockCenter` that jump is
   a mouse DELTA. Two independent answers: the cursor is PARKED on the click point before the aim is
   armed (`park.ps1`), and every row carries `RETICLE+1f`, the same ray one frame later. On every
   row quoted above `RETICLE+1f` equals `RETICLE`, so the camera was stable across the trigger.
   *Verify:* the `|| RETICLE+1f` field on each row.
7. **Item 3 (the moving case) is NOT MET.** Two attempts produced no paired row inside the two
   hours. The moving-target residual is unmeasured and is not claimed anywhere. *Verify:* the
   ledger's round 2 item 3.
8. **265a(a) is done, and it was THREE stale sentences, not the two the dispatch named** (L-030, and
   the grep was run before committing): `Ballistics.boreOrigin`'s header,
   `Weapon.onFireRequest`'s inline note and `docs/research/2026-10-24-real-shooting.md` section 12
   all said `BORE_ON_SIGHT_LINE` ships `false`; `src/shared/Shotgun/init.luau` has
   `BORE_ON_SIGHT_LINE = true` since task 260. `tests/server/sights.spec.luau` was already correct
   and is untouched -- it passes `false` explicitly for its rollback cases and says why.
   *Verify:* `git show 75539a94`; `grep -rn "BORE_ON_SIGHT_LINE" src/ tests/ docs/`.
9. **Nothing in the game's behaviour changed.** The three edits are comment lines and one research
   sentence. *Verify:* `git diff 670416e6..75539a94 -- src/`.
10. **The Forest Test's attributes are identical before and after.** Read with
    `<runs-dir>/attrs-id.luau` before anything and again after the restore:
    `DHFlag_BOAR_BEHAVIOUR=true DHFlag_BOAR_MODEL=true DHFlag_COINS=true DHFlag_DEER_ROAD_LEAP=true
    DHFlag_DRIVE_BOTS=true DHFlag_HORN=true DHFlag_LICENCE_POPUP=true DHFlag_LOBBY=true
    DHFlag_SHOP=true DHForestStartRole=hunter DHShopTestGrant=true`. `DHTestOwns` was set for the
    proof only and is cleared; the probe's anchors are released (`265-free.luau` answered
    `freed 0`, because the drive had already retired those animals).

## What could not be verified

- **The moving-target rows (item 3).** Not obtained. One click produced no `ShotLanded`, and a
  drive ended between the placement and the trigger on the other attempt.
- **Only four shots are tabled, not six.** Three still rows plus the tree row.
- **No new frame this round.** The still-target rows are numbers out of the server's own payload,
  not a look claim; round 1's `265-deer38b.png` remains the described frame and nothing here
  supersedes it.
- **The control animal is ANCHORED BY THE PROBE** (`265-hold-still.luau`), which is how `v = 0.000`
  is a fact rather than an aspiration: no animal in a drive ever stands still. The anchoring is the
  probe's, not the game's, and it is undone by `265-free.luau`.
