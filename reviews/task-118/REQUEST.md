# Task 118 — boar behaviour: what a boar does about what it notices

Task: 118 · Round: 1 · Base: `task-117-calm-boar` (stacked; the PR targets that branch)
Code commit: 8dc18054fe86b429bf8bd6afff1c5eeb50203e15

```
[harness] PASS: 33/33 checks @ 8dc18054fe86b429bf8bd6afff1c5eeb50203e15 (clean tree) scope=all
```
`[harness2]`: **PENDING — the Director runs it.** This task touches `src/server/Match/` and
`src/server/MatchBoot.server.luau`, so the merge gate needs `test2` at this same sha.
CI is red for ONE reason that is **task 117's and must not be fixed here**: `tools/boar_prep.py`'s
selftest still says "ten clips" with sixteen in the tuple.

## Claims

1. **With `BOAR_BEHAVIOUR` off, this is Milestone 1.2's world.** Every radius is `DETECT_RADIUS`,
   only `kind == "driver"` is a stimulus, nothing hears anything, and the leader-panic rule is the
   one that runs. *Verify:* `boar_behaviour.spec`, "with the flag OFF…" (three cases); every
   existing boar/match spec passes **unchanged**. Mutation-checked: deleting the kind filter makes
   the first case fail (a shooter at 24 studs bolts the flag-OFF boar), deleting `_hearSound`'s flag
   gate makes the third fail.
2. **One pure function decides what a boar perceives.** `Brain.perceive` replaces `_threatInfo`; a
   notice radius and a flush radius per stimulus, standing 25/15 and moving 60/40, strongest wins,
   ties to the nearest, and `CALM_RADIUS - DETECT_RADIUS == SENSE.CALM_MARGIN` is asserted so the OFF
   branch cannot drift. *Verify:* `boar_behaviour.spec`, the five `perceive` cases.
3. **ALERT and AVOID, with a dwell and a refractory, and neither asks for a route.** *Verify:* the
   ALERT and AVOID cases (entered inside 0.25 s, faced the cause in 0.03 s at ≤ `TURN_RATE`, held
   2.52 s, then 8.10 s of grazing; AVOID opened 38.3 studs in 3 s with `pathRequest` nil on all 600
   steps). Mutation-checked: zeroing the refractory and flipping `avoidTarget`'s angle each fail
   their own case.
4. **A shot is a sound, and panic spreads member to member.** `Weapon.ShotFired` → `MatchBoot` →
   `Runtime:hearShot` → `obs.sounds`, reusing the existing bolt; the sounder's alarm REPLACES the
   leader-panic rule. *Verify:* the shot cases (sprint held 3.72 s, nothing past 350 studs, carcass /
   crippled / wounded unaffected) and `boar_behaviour_live.spec` (a sounder of 3 all running after 25
   frames, with sampled steps where one ran and another did not).
5. **Shooters are perceivable now, and the composition root keeps no conditional.**
   `Match.Body.boarStimuli` is a NEW function beside `driverPositions`, which is untouched;
   `MatchBoot` wires `Match.boarThreats` unconditionally and the Brain drops non-drivers when the
   flag is off. `MODEL.ALERT_CLIP = "smell"` is one string. *Verify:* `boar_behaviour.spec`'s
   flag-OFF case and its two `clipFor` cases; `match_*` specs unchanged.

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
- **Whether the head is RAISED in `118-alert-turn.png`** — at 25 studs I cannot judge the posture
  from the frame. That the alert boar DRAWS `ALERT_CLIP` is asserted by spec, not by eye.
- **Dogs** (`kind = "dog"`, `DOG_NOTICE_SCALE`) have no producer, and **`REQUIRE_SIGHT = true`** has
  never run in a real world; both are spec-only.
- **The LOOK's hunter had to be anchored to stand still** — something walks that character at ~5
  studs/s and survived `WalkSpeed = 0` and a keyUp. Not diagnosed; not this task's.
