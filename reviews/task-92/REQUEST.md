# Task 92 — the shotgun's feel: ADS, the bead, the gun's light, recoil, the flash

Task: 92
Round: 1
Base: `main` (`62b20e7`)
Code commit: `a7579bacb0f94771e9e55365963950e8f49befc5`

```
[harness2] PASS: 32/32 checks @ a7579bacb0f94771e9e55365963950e8f49befc5 (clean tree)
[harness]  PASS: 32/32 checks @ a7579bacb0f94771e9e55365963950e8f49befc5 (clean tree)
```

Karen's S2 playtest is recorded verbatim in `PLAYTEST.md`. Everything below is behind
`FIRST_PERSON`, still **default OFF**; the screenshots are a throwaway session with it on, cleared
after (`flags.py clear`, and the gate ran with no override).

**One gate failed on the way, diagnosed before anything was re-run** (`28/32`, `30/32`): at 20 fps
`omega * dt` is 1.13, past where semi-implicit Euler damps, so the recoil spring was still moving a
second after the shot -- the integrator, not the spring. It is sub-stepped at 1/60 s now. Beside it:
a hand-made state in a spec that predated the cosmetic terms, two float32 round trips (0.18 and 1.4),
and a clone that now carries a second Attachment.

## Claims

1. **PRESSING RIGHT MOUSE MOVES THE GUN AND NOT THE AIM POINT.** `camera_mode.spec` drives blend
   0 -> 1 in first person: the eye, the look vector and the world point 60 studs down the screen
   centre are **bit-for-bit equal**, while the gun's own pose moves half a stud and the third-person
   branch moves the eye 5. MEASURED ON SCREEN too, from a before/after pair taken without touching
   the mouse: a stake 79 px from the centre went to 119 px, a ratio of **1.506** against the pure-zoom
   1.502 (FOV 70 -> 50), bearing unchanged to 0.29 deg -- so the aim point moved **0.6 px, about
   0.04 degrees**, which is inside the centroid's own noise.
2. **THE BEAD IS A BRASS BALL, NOT A RED DOT.** `BEAD_MARKER_COLOR` is brass and
   `BEAD_MARKER_MATERIAL` is `Metal`; `camera_client.spec` asserts the colour's character (R > G > B,
   blue present, not saturated) and that the drawn marker really wears both -- and it is still drawn
   at the `Sight` attachment the ADS geometry lines up, so the mark and the shot line are one thing
   (the task-90 bead measurement is unchanged: 0.01 px).
3. **THE GUN CARRIES ITS OWN LIGHT.** One PointLight on the clone inside the camera, shadows off,
   range 6, asserted present, once-only across rebuilds, and at the config's brightness. 1.4 blew the
   action out to near-white on screen, so it ships at 1.0 -- measured, not chosen.
4. **RECOIL RETURNS THE AIM POINT EXACTLY.** `Mode.kick` adds an offset to three critically damped
   springs; `Mode.step` integrates them, sub-stepped, and snaps to exact zero. The spec asserts the
   view really lifts, never overshoots, is home inside a second at 240/60/20 fps, that a doublet is
   clamped, and that the camera CFrame afterwards is **bit-for-bit what it was before the shot**.
   `[server] task92 recoil: gun 4.00 deg / 0.140 studs, view 1.10 deg`. In the third-person branch
   `Mode.kick` returns the same state it was given -- task 89's promise, still tested.
5. **THE FLASH COMES OUT OF THE PIPE THAT FIRED.** The payload carries `barrel` and that barrel's own
   muzzle CFrame (`Shotgun.barrelMuzzleOffset`, checked against `Shape`'s own BarrelLeft/BarrelRight
   rather than a second copy of 0.09); the BALLISTIC muzzle is untouched, which `weapon_look.spec`
   asserts. In first person the cosmetics ask the camera for the DRAWN gun's muzzle, because the Tool
   the server knows about is hidden in the character's hand -- the shoulder Karen saw.
   `[client] task92 flash: flash 0.30 studs from the drawn muzzle, 42.4 studs from the world muzzle`.

## Not verified

- **The mesh itself is not re-shaded.** The aimed screenshot shows the action as bright shards with
  dark seam lines -- the mesh's own hard edges and its metalness 0.70 / roughness 0.35, not the light.
  Smoothing it needs a Blender pass and a re-upload, which this bundle does not do.
- Karen has not played any of it. Every number here is a first pick and a dial.
