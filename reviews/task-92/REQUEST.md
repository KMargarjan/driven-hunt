# Task 92 — the shotgun's feel: ADS, the bead, the gun's look, recoil, the flash

Task: 92
Round: 1
Base: `main` (`62b20e7`)
Code commit: `b0ff21091a3cc6391a2cd553e09ee2c8b7e25c96`

```
[harness2] PASS: 32/32 checks @ b0ff21091a3cc6391a2cd553e09ee2c8b7e25c96 (clean tree)
[harness]  PASS: 32/32 checks @ b0ff21091a3cc6391a2cd553e09ee2c8b7e25c96 (clean tree)
```

Karen's S2 playtest is verbatim in `PLAYTEST.md`. Everything in the camera is behind `FIRST_PERSON`,
still **default OFF**; the screenshots are a throwaway session with it on, cleared after.

**Two gates failed on the way, each diagnosed before a re-run.** At 20 fps `omega * dt` = 1.13, past
where semi-implicit Euler damps, so the recoil spring was still moving a second after the shot -- the
integrator, not the spring; it is sub-stepped at 1/60 s now. Then `assets_seam.spec` counted two
manifest rows and named v2 as live, which v3 broke.

## Claims

1. **PRESSING RIGHT MOUSE MOVES THE GUN, NOT THE AIM POINT.** `camera_mode.spec` drives blend 0 -> 1
   in first person: the eye, the look vector and the world point 60 studs down the screen centre are
   bit-for-bit equal, while the third-person branch moves the eye 5 studs. MEASURED ON SCREEN, on a
   pair taken without touching the mouse: a post standing at the screen centre keeps its centre at
   **x = 478.5 px before and after**, and its width scales **x1.500** against the field of view's own
   x1.502 -- a pure zoom about the aim point. (The horizon's own offset scales x1.47, 2.4 px off a
   pure zoom, which is the edge detector's step.)
2. **THE BEAD IS A BRASS BALL AND IT IS ON THE SHOT LINE.** `BEAD_MARKER_MATERIAL = Metal` and a
   brass colour, asserted by character and on the drawn marker; the gate's own client measurement is
   `task90 bead: worst 0.00 px from the shot line and the screen centre`, and in the ADS screenshot
   the bead's centroid is **1.44 px (0.09 deg) from the frame centre**.
3. **THE MESH IS SHADED SMOOTH, WHICH IS WHAT "BROKEN" WAS.** Every `asset_prep` run exported
   `mesh_smooth_type="FACE"` -- each of 19,325 triangles lit as its own plane, which an inch from the
   eye is a ring of bright shards with dark seams. The tool now shades smooth and keeps sharp only
   edges over `smoothAngleDeg` = 35, exporting with EDGE smoothing: **9,050 of 28,992 edges stayed
   sharp**. Action metalness 0.70 -> 0.45, roughness 0.35 -> 0.50. Re-uploaded under Karen's existing
   OK as **137252961155547, Approved**; manifest **v3**, v2 kept and `supersededBy = 3` (rule 7), same
   source file and no decimation, so the geometry and `sightOffsetStuds` are unchanged.
4. **THE ADS VIEW LOOKS ALONG THE TOP OF THE BARRELS.** `ADS_CHEEK_DEG` = 7 rotates the gun **about
   the bead**, so the bead stays exactly on the axis (claim 2) and everything behind it swings down --
   an eye above the bore. The spec measures the resulting tilt off the pose and drives 0 degrees as
   the control.
5. **RECOIL RETURNS THE AIM POINT EXACTLY, AND THE FLASH COMES OUT OF THE PIPE THAT FIRED.** Three
   critically damped springs, sub-stepped; the camera CFrame after a kick is bit-for-bit what it was
   before, at 240/60/20 fps, and a doublet is clamped. The payload carries the barrel and that
   barrel's muzzle CFrame (checked against `Shape`'s own barrels, not a second 0.09); the ballistic
   muzzle is untouched; in first person the cosmetics ask the camera for the DRAWN gun's muzzle --
   `task92 flash: 0.30 studs from the drawn muzzle, 42.4 studs from the world one`.

## Not verified

- Karen has not played any of it. Every number is a first pick and a dial.
- No screenshot caught the 0.05 s flash itself; the smoke puff at the muzzle is the visual proof.
