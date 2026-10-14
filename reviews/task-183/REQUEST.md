# Task 183 -- the rifle: more recoil, a heavy-calibre report, and a hit where the scope points at 200 m

Task: 183
Round: 2
Base: 6a49b6c (main)
Code commit: cb6fa7417d7cb903bcae10fabc165e119f95b251

Harness, FULL, twice, clean tree, at the code commit:

```
[harness] PASS: 33/33 checks @ cb6fa7417d7cb903bcae10fabc165e119f95b251 (clean tree) scope=all
[harness2] N/A
```

`.agent-logs/task183-r2-test1.log` and `.agent-logs/task183-r2-test2.log`.

**`test2` is N/A.** `git diff --name-only 6a49b6c..HEAD` is `src/shared/Rifle/init.luau`,
`src/shared/Viewmodel/poses.json`, `src/client/Camera/init.luau`, `tests/server/rifle.spec.luau`,
`tests/server/weapon_shot.spec.luau`, `tests/client/rifle_client.spec.luau`, plus `TASKS.md`,
`PLAYTEST.md` and one research note. **No path in `TWO_PLAYER_PATHS` is touched** (Director,
2026-10-03): no `src/server/Match/`, no `MatchBoot`, no `src/client/Match/`, no `src/shared/Drive/`,
no `tests/client/Role.luau`, no `match_*.spec`, no `zz_drive_boundary.spec`, no
`match_client.spec`, no `outfit_client.spec`, no `zz_tie_to_a_tree.spec`.

## What changed, and why

Karen, 2026-10-14 ~17:20: *"rifle shooting ... recoil, sound and hit / so recoil has to be more /
sound has to be harder like strong caliber / hit it has to be precist and on 200m acurat"*.

**The hit was measured before anything was changed**, on the player's path: a Play session in DEV,
the real rifle equipped, the real scope up, a plate placed on the reticle centre at 50/100/200 m,
and the server's own impact position read back off the `ShotFired` payload. Two causes, both at
their owner, plus two things that turned out to be right already and are now asserted.

| | 50 m | 100 m | 200 m (714 studs) |
|---|---|---|---|
| **before**, scoped | 2.0 cm | 3.0 cm | **NO IMPACT** |
| **after**, scoped | **0.00 cm** | **0.00 cm** | **0.00 cm** |

(The "before" figures are the perpendicular component derived from the recorded totals; the probe's
first version measured the full 3-D distance and so carried the plate's own 0.1-stud half-thickness,
a constant -2.80 cm along the ray. The "after" figures are measured perpendicular directly.)

## Claims

1. **A rifle shot could not reach 200 m at all, and now can.** `Rifle.CONFIG.RANGE_STUDS.Slug` was
   450 studs -- 126 m at this game's 0.28 m/stud -- and `Hits.resolve` casts exactly that far from
   the muzzle. Now 800 (224 m). *Verify:* `src/shared/Rifle/init.luau`, `RANGE_STUDS`; the boundary
   measurement is in the comment there and in `TASKS.md` row 183 (440 studs hit, 455 and 470 gave no
   impact); `tests/server/rifle.spec.luau` -> "reaches 200 m, which is the distance Karen named",
   which asserts the row against `200 / 0.28` rather than against a literal.

2. **The rifle's random cone is gone.** `SPREAD_FULL_DEG.Slug` was 0.05 degrees FULL -- a
   0.025-degree radius, 8.7 cm at 714 studs against a 5 cm target -- and three scoped shots at 100 m
   measured 4.97, 4.14 and 3.69 cm off the reticle, all of it that cone. Now 0.
   *Verify:* `Rifle.CONFIG.SPREAD_FULL_DEG`; `rifle.spec` -> "has NO random cone", which drives
   `Pattern.directions` over 50 seeds and bounds the worst angle by **the row's own**
   `SPREAD_FULL_DEG / 2`, so a cone that appears when the data says zero fails whatever the data
   says. The datum itself is pinned at zero in exactly ONE place -- round 1's note counted three
   copies, and the other two are gone. `Pattern.directions` needs no branch for zero: `cos(0)` is 1.

3. **There was no muzzle parallax to fix, and now something says so.** `Weapon.onFireRequest` casts
   the client's ray to find the aim point and then aims the pellet ray **from the muzzle at that
   point** -- so sight-over-bore cancels at every range, with no zero and no convergence distance.
   That was untested. *Verify:* `tests/server/weapon_shot.spec.luau` -> describe "the sight line".
   It drives the real handler through `Weapon.setCast`, puts the eye 0.6 across and 2.4 above the
   root so the muzzle cannot be on that ray by accident, and asserts: the first cast is the client's
   ray unaltered and as long as the ammo's range; every later cast starts at the muzzle; and no
   pellet is further off the muzzle-to-aim-point line than **the held weapon's own declared
   half-cone**. Measured live with the shotgun, both round-2 runs: eye 5.87-5.90 studs from the
   muzzle, worst pellet 0.0713 and 0.0766 degrees against the 0.080 its data allows -- i.e. the
   whole deviation is the declared cone and none of it is parallax. Its two fallback branches no
   longer assert tautologies (round 1's note): both now assert the rifle's own row, which can be
   false.

4. **The drawn reticle centre is the pixel the shot ray goes through.** The server shoots along
   `camera.CFrame.LookVector`, which passes through the viewport centre, so the mark is only honest
   if it is drawn there. *Verify:* `tests/client/rifle_client.spec.luau` -> describe "the reticle
   centre is the camera centre". It projects a world point that lies **on** the look vector back to
   the screen and requires the dot's own centre and the cross's crossing to be within 2 px of it,
   and requires `IgnoreGuiInset` on the ScreenGui by name. Measured in the run: ray at
   (484.5, 334.0), dot at (484.5, 334.0) -- **0.00 px off**.

5. **`AbsolutePosition` is in SCREEN space, and that is written down because it cost a round.**
   The first version of claim 4 used `WorldToViewportPoint` and failed by exactly the 58-px topbar
   inset while the reticle was perfectly placed. A ScreenGui with `IgnoreGuiInset = true` reports
   `AbsolutePosition = (0, -58)`: it covers the whole viewport, and its origin is still quoted
   relative to the inset-adjusted one. *Verify:* the comment above
   `camera:WorldToScreenPoint` in that case carries both measured coordinate pairs.

6. **The kick is bigger than the shotgun's on all three terms, and fits under its own ceilings.**
   `weapons.rifle.fire` in `src/shared/Viewmodel/poses.json`: gun pitch 12 -> **19** deg, gun back
   0.42 -> **0.68** studs, view 3.15 -> **5.6** deg (the shotgun's are 8 / 0.28 / 2.1), with the
   ceilings raised to 22 / 0.80 / 6.5 -- **the old `maxGunPitchDeg` 12.5 would have clamped a
   19-degree kick to 12.5**, which is the one way this change could have been silently inert.
   *Verify:* `rifle.spec` -> "kicks harder than the shotgun, and comes home inside half a second",
   which asserts the three relations and the three ceilings, both against `Viewmodel.view` rather
   than against literals.

7. **It recovers in the 0.3-0.5 s the Director asked for, and does not overshoot the aim point.**
   2.8 -> **2.0 Hz** at damping 0.78 -> **0.90**. Simulated against the real integrator
   (`Mode.spring`, semi-implicit Euler at 1/60 substeps): 10 % of the kick left at 0.28 s, 1 % at
   0.48 s, overshoot 0.15 % of the kick. *Verify:* the same case bounds `ln(100) / (zeta * omega)`
   to (0.25, 0.6) and requires `dampingRatio >= 0.8`. `camera_mode.spec` is unaffected -- it drives
   `Camera.Config`, which carries the **shotgun's** merged numbers, and the shotgun's row is
   untouched.

8. **The rifle has a new, heavier, longer and louder voice.** `Rifle.CONFIG.SOUND.shot` is
   `rbxassetid://9114725315` -- "Gun Retort 1 (SFX)", ProSoundEffects, *"Gun Retort, Weapon, Sharp
   Gun Shots, Reverberant Blasts"* -- at `pitch = 0.88`, `cut = 2.0`, `fade = 0.8`, with
   `weapons.rifle.fire.volume.shot` 0.95 -> **1.5** against the shotgun's 0.95. Measured in Play:
   `loaded=true 4.95 s`, against the Barrett it replaces at 3.36 s and the shotgun at 0.92 s.
   *Verify:* `docs/research/2026-10-10-rifle-bolt-magazine-sound.md` section **4b** -- the whole
   licensed ProSoundEffects Guns family swept, eight candidates measured with their TimeLengths, and
   one line per rejection. `rifle.spec` -> "speaks with its own heavy-calibre voice, louder than the
   shotgun" asserts the shape (an `rbxassetid://` id, a cut, a fade inside it, a pitch below 1) and
   the one comparison her sentence makes.

9. **Only the rifle moved, and only paperwork follows the code commit.** `git diff 6a49b6c..HEAD -- src/shared/Viewmodel/poses.json` touches
   nine numbers, all under `weapons.rifle.fire`. `Shotgun.CONFIG` is untouched;
   `rifle.spec`'s existing field-by-field assertion of the shotgun's row against `Shotgun.CONFIG`
   still passes. The code commit `cb6fa74` is the one both harness lines name and is the last
   commit that touched `src/`, `tests/` or `tools/`; everything after it is this file, `TASKS.md`'s
   row 183 and `reviews/task-183/RESULT.md`. *Verify:* the diff, `git diff --name-only
   cb6fa74..HEAD`, `.agent-evidence/paperwork-after-code-commit.txt`, and the 33/33 runs.

10. **ROUND 1's BLOCKING FINDING: the rifle's kick never reached the player, and the Reviewer was
    right.** `Camera.kick` read `Poses.config(Config)` -- no weapon id -- which answers for
    `Viewmodel.DEFAULT_WEAPON`, the SHOTGUN, and `Mode.kick` is the only reader of the six RECOIL_*
    numbers in the repo. So `weapons.rifle.fire` reached nothing: claim 6's 19 degrees arrived as
    the shotgun's 8, clamped by the shotgun's own 12.5. `Camera.fire` had the same omission, so the
    rifle's `fire.flash` and `fire.smoke` were the shotgun's too; it is the same line and is fixed
    with it. Both now go through one named `Camera.fireConfig()`, beside `Camera.poseConfig()`.
    *Verify:* `src/client/Camera/init.luau`, `Camera.fireConfig` and its two callers, and
    `tests/client/rifle_client.spec.luau` -> describe "the kick belongs to the gun on screen",
    which EQUIPS the rifle, waits for `Viewmodel.weaponId()`, waits for the springs to rest, kicks
    once and reads the three numbers against `Viewmodel.view(DATA, "rifle")` -- and explicitly not
    against the shotgun's -- restoring the held Tool before it asserts anything. Measured in both
    runs: `drawn=rifle applied view 5.60 deg / gun 19.00 deg / back 0.680 studs (shotgun wants
    2.10 / 8.00 / 0.280)`. `rifle.spec`'s "kicks harder than the shotgun" could not see this: it
    asserts data relations, and the data was always right.

## What could NOT be verified

* **The sound.** Nobody in this toolchain can play audio. What is verified is that the id exists, is
  Roblox-provided licensed catalogue audio by name and creator, says on its own store record what it
  is, and **loads in this place at 4.95 s**. Whether it reads as a big calibre is Karen's ears, and
  every number in that line is one line to change; the Barrett is `9118173739`.
* **The feel of the kick.** The numbers, the relations and the settle are asserted; whether 19
  degrees is "more" in the sense she meant is hers.
* **The 200 m hit against a BOAR**, as opposed to a test plate. The dispatch asked for a boar in the
  reticle at 200 m to be hit in the vital zone where aimed. The impact point is now exact, so what
  remains is whether the boar's hitbox matches its drawn model at that range -- that is the animal's
  owner and was not measured here.
* **Other players hearing the shot.** Not built, and not attempted: every gun sound is parented to
  `SoundService` with no part (`Weapon.Sound`'s own header: *"local only, and at the ear"*), so the
  dispatch's "3D with a long rolloff" needs a server broadcast and a positional `Sound` -- a new
  system, a new owner, and nothing a one-player test can show. Queued as **183a(b)**.
* **The safety penalty past 330 studs.** `Match.CONFIG.SAFETY_RANGE_STUDS` still clamps the
  penalty's reach to the shotgun's slug range while this gun now reaches 800. Not changed, because
  `src/server/Match/` is a `TWO_PLAYER_PATH`. Queued as **183a(a)**.
* **The smoke was run in DEV, not in the Forest Test.** With Karen's flags the Forest Test issues no
  gun at all until somebody boards a truck pad (`Match.mayCarryWeapon` is false while the phase is
  `Waiting`): measured over 95 s -- hunter on his stand, 14 boar lines released, **0 error lines**,
  and no Tool in the character or the backpack. The 85-second DEV smoke is the one with a gun in it:
  `CHAR:Rifle` at 16 s and at 85 s, **0 error lines**, and three scoped 200 m shots each 0.00 cm off
  the reticle centre. Queued as **183a(d)**.
* **`tools/pose.py` could not write the recoil numbers.** `studio_for_role` probes a solo Play
  session and gets `client`, because the editor's own Studio hosts both datamodels under one id, so
  `pose.py set` answered *"no Studio answered as 'server'"* nine times. `poses.json` was edited
  directly instead, which is a reviewable diff of nine numbers. Harness fault, reported as
  **183a(c)** (rule 6).

## Screenshot (rule 5)

`.screenshots/20261014T164956Z-t183-scope-200m-target.png` -- inspected. The sight picture with the
cross spanning the glass and the red dot at its centre, sitting on a 30-stud target placed at exactly
714 studs (200 m) on the reticle centre; the target measures 94 px wide at that range and FOV, and
the readout reads `3/3 .416 9`.
