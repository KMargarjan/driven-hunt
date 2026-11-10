# Task 344 -- two animal bugs Karen saw on 2026-11-10

Task: 344
Round: 1
Base: main (8b4d0431)
Code commit: 04243c64e046e6c8dd56959699ee379a4c83282d

`[harness] PASS: 34/34 checks @ 04243c64e046e6c8dd56959699ee379a4c83282d (clean tree) scope=all`

`[harness2]` N/A: nothing here is in `TWO_PLAYER_PATHS`. The change is `src/server/Boar/Brain.luau`,
`src/server/Boar/init.luau`, `tests/server/deer.spec.luau`, `tests/server/boar_move.spec.luau`.

## PLAN (core quality protocol step 0)

**(a) REAL LIFE.** A red deer landing a bound continues on its line -- the bound is the gait where
all four feet leave the ground together to clear an obstacle (Lingle 1993, cited in
`docs/research/2026-10-23-deer-road-leap.md` s8). It cannot translate sideways: at 24 studs/s a
90 deg/s turn is already a 15-stud radius for a 7-stud animal.

**(b) MEASURED NOW** (`<runs-dir>/344-probe.luau`, her Forest Test at main, one C1 drive):
15 stag leaps, angle between the body's FACING and its TRAVEL **22.4 deg at +0.5 s** after
touchdown and **22.5 at +1.0**, worst 103.9. One C1 drive: **8 animals** ordered to move at 3+
studs/s and covering under 1 studs/s for longer than a second, **worst 2.03 s**, 3 of 8 with a
trunk inside 9 studs ahead. A2: 17.9 / 21.9 deg and **16** stuck events, worst 1.78 s.

**WHICH OF THE THREE IT IS.** `<runs-dir>/344-disc.luau` sampled `Mover.PlaneVelocity` (what
`Body.drive` wrote), `AssemblyLinearVelocity` (where the body went) and `CFrame.LookVector` (where
it is drawn) together -- 50 samples over 10 landings: **want-vs-vel 0.0 deg in every one**. So it
is NOT a slide and NOT a new heading at landing; the motion is exactly the setpoint. It is the
Director's first option, the drawn yaw not following. `<runs-dir>/344-rate.luau` says why: the
setpoint turns at up to **441 deg/s** (`RUN_TURN_DEG` 220 x `LINE.TURN_SCALE` 1.6 = 352, plus the
deadband's stop-start) where the drawn body manages ~140, so the gap opens at the crossing and
stays open -- one stag held 50 deg for 1.5 s, another reached 102.

**(c) TARGET.** Mean angle <= 15 deg and worst <= 30 deg at +0.5 s and +1.0 s. At 15 deg the
forward share of travel is 3.7:1 over the lateral; at 50 deg it is 0.8:1, which is what "sideways"
means. Stuck events over 1 s per drive 0, none over 2 s (the Director's numbers).

**(d) LEVER.** `turnRate`, which feeds the one slew of `_desired`:

```
src/server/Boar/Brain.luau:2790:	self._desired = slew(self._desired, unit(desiredDirection, self._desired), turnRate * dt)
src/server/Boar/Brain.luau:2761:		turnRate = math.min(turnRate, math.rad(landDeg))
```

and for bug 2 `Brain:_updateWedge`'s window `MOVE.WEDGE_SECONDS` plus its `_wedgeFrom` re-base.

**(e) HOW IT IS MEASURED AFTER.** The same `344-probe.luau`, same place, same cells, same drive.

## Iteration (step 2)

| cycle | change | measured | to target |
|---|---|---|---|
| 1 | none (baseline, C1 drive) | 22.4 / 22.5 deg; 8 stuck, worst 2.03 s | mean +7.4 |
| 2 | locate: `344-disc` + `344-rate` | want-vs-vel 0.0 deg; setpoint 441 deg/s vs body ~140 | premise fixed |
| 3 | cap inside the PACE block | DEV probe: both runs 229.2 deg/s, the cap never ran | refuted |
| 4 | cap on `turnRate` itself | DEV probe: 90.0067 capped vs 229.1865 free | reached |
| 5 | re-measure in her place, C1 drive | **11.4 / 11.0 deg**, worst 41.7; **2 stuck**, worst 1.24 s | mean MET, worst +11.7 |
| 6 | re-measure, A2 drive | 15.4 / 18.4 deg, worst 86.1; **2 stuck**, worst 1.47 s | mean MET, worst missed |

## Claims

1. **It is the drawn yaw, not the motion.** `344-disc.luau` reports `want-vel = 0` in all 50
   samples. Verify: read `<runs-dir>/344-disc.luau` and its trace.
2. **`MOVE.LAND_TURN_DEG` 90 / `LAND_SECONDS` 0.8 cap the slew for the bound and 1.055 s past
   touchdown.** The window is refreshed on every tick `intent.leaping` is published and counted
   down after. Verify: the block under `intent.leaping = self._leapFor > 0` in `Brain:step`, and
   the `turnRate` `math.min` above the slew.
3. **The cap can only lower a rate**, and the DEV world never opens the window (no road, so
   `_landFor` is 0 there for ever). Verify: the `math.min`; `Brain.onRoad` answers false for nil.
4. **Bug 1 proof case, dies on revert.** `deer.spec` "LANDS RUNNING STRAIGHT ON": 90 deg/s with the
   hold against 229 without, two runs differing only in `MOVE.LAND_SECONDS`. Delete the `math.min`
   and both read 229. Verify: the harness note `deer 344: worst heading turn in the 0.7 s after the
   bound -- 90 deg/s with the landing hold, 229 deg/s without (cap 90)`.
5. **Bug 2 proof case, dies on either half.** `boar_move.spec` "SIDESTEPS AGAIN INSIDE 1.5 s":
   sidesteps at 0.5, 1.5, 2.03, 2.5 s on an animal pinned and sliding 0.4 studs/s. `WEDGE_SECONDS`
   back to 0.75 puts the second at 2.13 s; deleting the `_wedgeFrom` re-base means no second turn
   ever fires. Verify: the harness note `wedge 344: sidesteps at 0.5, 1.5, ...`.
6. **Live, C1, one drive each side:** 22.4 -> **11.4** deg at +0.5 s, 22.5 -> **11.0** at +1.0;
   8 -> **2** stuck events, worst 2.03 -> **1.24** s. Verify: `<runs-dir>/344-BEFORE-C1.txt` and
   `344-AFTER-C1.txt`. The after build was read live: `344-verify.luau` returned
   `LAND_TURN_DEG=90 LAND_SECONDS=0.8 WEDGE_SECONDS=0.4`.
7. **Live, A2:** 17.9 -> 15.4 and 21.9 -> 18.4 deg; **16 -> 2** stuck events, worst 1.78 -> 1.47 s.
   Verify: `344-BEFORE-A2.txt`, `344-AFTER-A2.txt`.
8. **The picture, one selection rule both sides** (`344-freeze.luau`: freeze the first landing in
   front of the stand whose facing is >= 35 deg off its travel): BEFORE it fired every time, at
   t = 39 s (61.3 deg), 52 s (52.3), 74 s (77.4), 119 s (53.2). AFTER, **5 landings in 170 s and
   not one reached 35 deg, worst 30.8**. Verify: the `[frame] frozen:` lines in `344-F1-before.txt`
   and `344-F1-after.txt`.
9. **Nothing else in the animal changed.** The diff is two numbers in `MOVE`, two new ones, one
   `math.min`, one timer and a two-line re-base. Verify: `git diff 8b4d0431..04243c64 -- src/`.
10. **No flake fired.** 34/34, 2895 server + 684 client passed, 0 failed, 0 errors.

## What I could not verify

- **Worst case NOT MET.** Worst angle at +0.5 s is 41.7 deg (C1) and 86.1 (A2) against a 30 deg
  target. The mean is met in both cells and the >= 35 deg picture rule stopped firing, but single
  landings still read broadside. The uncapped 90-degree wedge/stuck sidestep -- applied to
  `_desired` AFTER the slew, deliberately, so a pinned animal can still step round a trunk -- can
  land inside the window and is the first thing to look at.
- **Stuck events over 1 s are 2 per drive, not 0.** None over 2 s in either cell: that half is met.
- **344-F1 AFTER and 344-F2 NOT OBTAINED.** `344-freeze.luau` + `344-cam.luau` took the BEFORE frame
  (below) but the matching AFTER picture failed three ways, each measured: `screen_capture` ignores
  its camera arguments in a Play session and returns the player's own view; a server `PivotTo` that
  MOVES a hunter is undone by the stand keeper (asked -3828, landed -3893, 46 studs from the
  animal); and with the distance tightened to 48 studs no stag landed in front of the stand in
  240 s. The after side is evidenced by claim 8's numbers instead.
- **344-F1 BEFORE, opened:** a hunter's-eye frame down the dirt road, gun in hand, HUD "stay on
  stand, animals coming", DRIVE 1. A big antlered red stag stands BROADSIDE on the road verge about
  50 studs out, a hind and calf on the grass to its left, a beater in an orange hat at the right
  edge. That stag is Boar15, frozen 0.5 s after landing from a road leap, facing (-0.84, -0.54)
  against travel (-0.94, 0.34) -- **52.3 deg apart**.
