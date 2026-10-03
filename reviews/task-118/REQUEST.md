# Task 118 — boar behaviour: what a boar does about what it notices

Task: 118
Round: 2
Base: 4cefbc516e0a7eeb3ca4b96506c3e5366aab57fa
Code commit: f21260b0f8540a801882b97444248162955bb855

The base is the head of `task-117-calm-boar`, the branch this PR targets: 118 is stacked on 117.

```
[harness]  PASS: 33/33 checks @ f21260b0f8540a801882b97444248162955bb855 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ f21260b0f8540a801882b97444248162955bb855 (clean tree)
```
Both lines are the Director's run at this sha. Only paperwork follows the last commit that changed
`src/`, `tests/` or `tools/` (`ce299b7`), so the evidence covers the head. Round 2's own diff is
`src/server/Boar/` plus one spec and two docs — **not** `TWO_PLAYER_PATHS` — but the PR's diff
against its base still contains `src/server/Match/` and `src/server/MatchBoot.server.luau` from
round 1, which is why `test2` is in the merge gate at all.

## What changed in round 2

**The one blocking finding is right, and the deadlock is exactly as the Reviewer wrote it.** Row 8 of
`Brain:_senseAware` flushes an alarmed member and `_flush` resets `_sinceCalm`, so an alarmed member
could never become calm; the only clear for `entry.alarmIn` requires EVERY member calm; so the alarm
never cleared and a sounder that panicked once ran until its last member crossed the exit line —
against §5.2 items 3 and 4, §3.2 row 11 and §14's own scene.

**Fixed at the cause, in `Runtime:_stepAlarm`:** the alarm is a PULSE. It is published to a member
from the step its delay runs out until the step that member is itself panicked, and is then spent —
its one job is to START the animal running, and from there §3.2 row 11's calm-down owns the settling,
which is what §5.2 item 4 says. The Brain is untouched: who has been told is the Runtime's
bookkeeping, like membership and the leader.

**And the case that was missing.** `boar_behaviour.spec` now drives a REAL runtime **stepped by
hand** — no Heartbeat, so no physics, so nothing moves, so nobody can escape and nothing is timed
against a wall clock: a sounder of three, one non-lethal hit, then nothing in range for ever.
Measured: all three running **0.43 s** after the hit and all back to `IDLE` **6.72 s** later.
Mutation-checked — put the latch back and `expect(settled)` fails.

**Three notes fixed because they are one-liners**, the rest queued as **118a**: `Runtime:hearShot`
now hears and counts nothing with the flag off; `Brain.sees` casts its ray the length of the RAY and
not of the flat distance (the flat one is no longer a parameter); the calm-margin case's prose said
40 + 30 where the code adds the margin to the NOTICE radius, so 60 + 30. `118a` carries the
`match_*` case for `boarStimuli`'s kinds — **not** done here on purpose, because
`tests/server/match_*.spec.luau` is in `TWO_PLAYER_PATHS` and would cost another two-player click for
something that is not the blocking finding — plus `REQUIRE_SIGHT`'s off-tick inconsistency and the
quick-test phantom's 15-stud flush radius.

**A live case for the settle is not cheap, and here is the arithmetic.** `boar_behaviour_live.spec`'s
field is the design's (`exitZ = -60` on a 170-stud plate); a sounder sprinting at `SPRINT_SPEED` = 38
covers the whole plate in ~3.3 s, which is less than `CALM_TIME` = 4 s, so a panicked sounder there
always crosses the line before it could settle. The hand-stepped runtime case above is the same
mechanism end to end — `_stepAlarm`, `_sounderObs` and the Brain — without that geometry.
CI is red for ONE reason that is **task 117's and must not be fixed here**: `tools/boar_prep.py`'s
selftest still says "ten clips" with sixteen in the tuple.

## Claims

1. **With `BOAR_BEHAVIOUR` off, this is Milestone 1.2's world.** Every radius is `DETECT_RADIUS`,
   only `kind == "driver"` is a stimulus, nothing hears anything, and the leader-panic rule is the
   one that runs. *Verify:* `boar_behaviour.spec`, "with the flag OFF…" (three cases); every
   existing boar spec passes **unchanged**; the one existing spec this branch edits is
   `tests/server/match_teams.spec.luau`, for a reason that is not 118's and is set out below.
   Mutation-checked: deleting the kind filter fails "cannot see a shooter at all", and deleting
   `_hearSound`'s flag gate fails "hears nothing past SHOT_AUDIBLE_STUDS, and nothing at all with the
   flag off" (which lives in the "a shot is a sound" block, not under "with the flag OFF").
2. **One pure function decides what a boar perceives.** `Brain.perceive` replaces `_threatInfo`; a
   notice radius and a flush radius per stimulus, standing 25/15 and moving 60/40, strongest wins,
   ties to the nearest, and `CALM_RADIUS - DETECT_RADIUS == SENSE.CALM_MARGIN` is asserted so the OFF
   branch cannot drift. *Verify:* `boar_behaviour.spec`, the five `perceive` cases.
3. **ALERT and AVOID, with a dwell and a refractory, and neither asks for a route.** *Verify:* the
   ALERT and AVOID cases (entered inside 0.25 s, faced the cause in 0.03 s at ≤ `TURN_RATE`, held
   2.52 s, then 8.10 s of grazing; AVOID opened 38.3 studs in 3 s with `pathRequest` nil on all 600
   steps). Mutation-checked: zeroing the refractory and flipping `avoidTarget`'s angle each fail
   their own case.
4. **A shot is a sound, and panic spreads member to member — and then STOPS.** `Weapon.ShotFired` → `MatchBoot` →
   `Runtime:hearShot` → `obs.sounds`, reusing the existing bolt; the sounder's alarm REPLACES the
   leader-panic rule. *Verify:* the shot cases (sprint held 3.72 s, nothing past 350 studs, carcass /
   crippled / wounded unaffected) and `boar_behaviour_live.spec` (a sounder of 3 all running after 25
   frames, with sampled steps where one ran and another did not), and "releases the alarm, so a
   sounder that panicked settles instead of running off the map" (round 2's own case).
5. **Shooters are perceivable now, and the composition root keeps no conditional.**
   `Match.Body.boarStimuli` is a NEW function beside `driverPositions`, which is untouched;
   `MatchBoot` wires `Match.boarThreats` unconditionally and the Brain drops non-drivers when the
   flag is off. `MODEL.ALERT_CLIP = "smell"` is one string. *Verify:* `boar_behaviour.spec`'s
   flag-OFF case and its two `clipFor` cases; `match_*` specs unchanged.

## The two `test2` failures at `dbb2419` — both older than 118, both fixed at their cause

Neither failure is in code this task wrote. Neither assertion was weakened in the sense that each
still fails on the thing it exists for — though the Reviewer is right that in a `test2` run, where
the shooter is tied by design, `match_teams`'s equality reduces to "both roles false" and the role
difference then rests on the driver-is-never-tied half; in a one-player `test` it still fails if
`mayCarryWeapon` stopped telling the roles apart.

1. **`match_teams.spec:106` — Task 34 meeting Task 35.** "A shooter carries a gun and a driver does
   not" was written in Task 34 (`7f4f1e3`, 2026-09-25), **one task before** Task 35 (`ed9fb0a`) added
   `tie-the-driver`, the LAST scenario of every `test2` run. It exists FOR
   `zz_tie_to_a_tree.spec`, it ties the SHOOTER on purpose, `TIE_UNTIL_DRIVE_END` keeps him tied, and
   `mayCarryWeapon` refuses a tied player whatever his team is — so the case only passes while the
   server suite reaches it BEFORE the tie lands (~55 s; the log's own `zz_drive_boundary` note says
   "1 tied"). **This is the fourth appearance of that creep**: `ESCALATE.md`'s Task 112 entry fixed
   two CLIENT cases for it and predicted *"the next task pushes it further whatever it changes"*.
   118's push is real and now **measured at 13.3 s** — `boar_behaviour_live.spec` prints its own cost
   to the server suite, so the next case to reach that edge is visible before it costs a round.
   *Fixed:* the case reads `Match.isTied` — the same fact `mayCarryWeapon` reads — and keeps the role
   difference by asserting a DRIVER is never tied, so his `false` can never be explained away.
2. **`camera_client.spec:559` — Task 114 meeting Task 112.** `visible == parts - 2` came in with Task
   114 (`696ed88`, 2026-10-03), tightened from Task 71's `parts - 1` for the gun's two named
   envelopes. Task 112 (`a991446`, 2026-10-02) had already added a THIRD invisible part:
   `Viewmodel.flash` creates `MuzzleFlash`, a 0.05-stud transparent Part under the clone carrying a
   PointLight and two emitters, which `Debris` removes **1.835 s** (smoke 1.6 + flash 0.035 + 0.2)
   after EVERY shot. `test2` has not run since Task 112 — before 114 existed — so the two had never
   met. 118 changed no client file and nothing the viewmodel reads. *Fixed:* the holder is skipped by
   NAME; it is not a piece of the gun, and a blank viewmodel still fails the claim.

## Two deviations from the design, both measured, both commented in the code

- **`Brain.avoidTarget` measures `AVOID_TURN_DEG` from the line TOWARD the cause**, not from the line
  away from it as §4.4's pseudocode writes it: 120° off AWAY is 60° off TOWARD, whose radial
  component is +0.5 — the animal would CLOSE with the man, against §7.1 ("past 90°, a refusal") and
  §12 case 6 ("the distance grows"). §12 case 5's "moving at 30 studs → AVOID" is likewise
  arithmetically impossible against §4.2 (a moving person's flush radius is 40); that case drives 45.
- **The sounder's physical formation is measured into a note, not asserted.** The expression that
  reads `formation` is asserted purely instead. Three unanchored bodies 3.2 s after a standing start
  measured 4.2 studs across for a column against the wedge's 9.4 — and over 7 on a later run. A
  verdict that inverts on a slow frame is worse than no verdict.

## Screenshots (rule 5), flag-ON Play session, 2026-10-04, `.screenshots/` (git-ignored)

- `118-alert-turn.png` — first person, the shotgun low-left: a boar at 25 studs, **head-on, facing
  the hunter, standing still** on the arena floor. Dropped facing directly AWAY, it turned to within
  **4.9° of the line to him inside ~1 s** and never moved (< 0.002 studs/s).
- `118-avoid.png` — the same boar after the hunter started walking: **side-on, mid-stride, trotting
  away at an angle**, ~75 studs out with the shooter posts on the horizon. Measured: exactly
  **18.000 studs/s** on a heading **113° → 148°** off the man, gap **47.9 → 75.5 studs**.
- `118-shot.png` — one shot fired at three boars: the hit marker reads "BOAR head", a carcass lies
  mid-frame, and **two boars are at full gallop**, one close and one far. Both measured **38.0
  studs/s**; neither was hit, and with the flag off neither would have moved.

## What I could not verify

- **Nobody has judged the feel.** 15 / 25 / 60, 2.5 s, 8 s, 120°, 350 studs are Karen's dials.
- **The alert frames do not show the head raised.** At 25 studs I cannot judge the posture in
  `118-alert-turn.png`, and the Director looked at the closer one: `118-alert-close.png` is the boar
  from behind at arm's length, which shows no head at all. That an alert boar DRAWS `ALERT_CLIP` is
  asserted by spec; that the clip READS as a raised head is still unseen by anybody.
- **Dogs** (`kind = "dog"`, `DOG_NOTICE_SCALE`) have no producer, and **`REQUIRE_SIGHT = true`** has
  never run in a real world; both are spec-only.
- **The LOOK's hunter had to be anchored to stand still** — something walks that character at ~5
  studs/s and survived `WalkSpeed = 0` and a keyUp. Not diagnosed; not this task's.
