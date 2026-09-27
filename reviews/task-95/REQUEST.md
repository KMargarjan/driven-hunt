# Task 95 — the walk pose, the raise and the aim, from Karen's reference

Task: 95
Round: 1
Base: `main` (`1443cde`)
Code commit: `96cc015b91a78abd6adfca148df229992725eed4`

```
[harness2] PASS: 32/32 checks @ 96cc015b91a78abd6adfca148df229992725eed4 (clean tree)
[harness]  PASS: 32/32 checks @ 96cc015b91a78abd6adfca148df229992725eed4 (clean tree)
```

All of it is behind `FIRST_PERSON`, still **default OFF**; the screenshots are throwaway sessions with
it on, cleared afterwards.

## Claims

1. **THE CARRY IS PANEL A'S POSE, MEASURED ON SCREEN.** The gun lies across the lower left: the action
   low and about a third of the way across, the barrels running up-left and leaving the frame at the
   left edge, the stock out of the picture. The spec asserts the two ends where the picture puts them
   -- muzzle left of -1.5 studs and further away than the action, elevation between 2 and 20 degrees,
   action low, left and clear of the near plane, and the BUTT more than half a field of view below
   the axis. `task95 carry: muzzle 37.5 deg left and 6.9 deg up, action at 1.58 studs`.
2. **FOUR BUILDS OF LOOKING, and each one is recorded in the config where the number lives.** The
   first measured the pose to the BUTT rather than the action and put the whole stock on screen; the
   second filled half the frame; the third stopped the muzzle inside the left edge. The gate then
   found the fourth: "the butt is behind the eye" is a stricter rule than the picture, which only
   asks that it be out of the frame -- it is 0.17 studs in front of the camera and 51 degrees below
   its axis.
3. **THE RAISE IS ONE SWING, AND IT NEVER POINTS AT THE SKY.** `AIM_RAISE_SECONDS` 0.25 up,
   `AIM_LOWER_SECONDS` 0.20 down, both in `Mode.blendSeconds` and measured in simulated seconds by
   the spec; the third-person branch keeps its single number. Sampling the pose across the whole
   blend, `task95 raise: muzzle peaks at 6.9 deg up, at blend 0.00` -- the carry itself is the
   highest it ever gets -- and the pose sweeps toward the aim with no step backwards.
4. **THE AIM'S TWO NUMBERS WERE SOLVED, NOT DIALLED.** Panel C wants the barrels to leave the BOTTOM
   EDGE a quarter of the screen wide with the action out of the picture: the bore's rear end (2.73
   studs behind the bead) must sit on the 25-degree cone at 0.61 studs from the eye, which gives
   `ADS_CHEEK_DEG = 5.4` and `EYE_RELIEF_STUDS = 3.27`. On screen the barrels now cross the bottom
   edge at **25.6 % of the width** and no part of the action or the breech face is in frame.
5. **TASK 92 STILL HOLDS IN THE NEW POSES.** No crosshair; the bead is still exactly on the shot line
   -- the gate's own client measurement is `task90 bead: worst 0.01 px from the shot line and the
   screen centre`; the ADS aim point still does not move (the rotation is about the bead, so the
   camera is untouched); recoil and the muzzle flash are unchanged code and their cases pass.

## Not verified

- Karen has not played it; the Director compares the screenshots.
- The three raise frames were taken with the raise slowed to 12 s in a throwaway working tree, because
  a capture takes about four seconds: the POSES are the shipped ones (the pose is a function of the
  eased blend, not of the clock), the speed is not what they show.
- The sway and bob asked for in the spec are still exactly identity -- nothing moves them yet.
