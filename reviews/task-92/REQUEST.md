# Task 92 — the shotgun's feel: ADS, the bead, the gun's look, recoil, the flash

Task: 92
Round: 2
Base: `main` (`62b20e7`)
Code commit: `5bc61c3e32bbc122f80c83a875a28c23ccb7bbc6`

```
[harness2] PASS: 32/32 checks @ 5bc61c3e32bbc122f80c83a875a28c23ccb7bbc6 (clean tree)
[harness]  PASS: 32/32 checks @ 5bc61c3e32bbc122f80c83a875a28c23ccb7bbc6 (clean tree)
```

The `[harness]` line is a SECOND one-player run at the same commit: the first failed `hit_marker.spec`
waiting for the tick to disappear, while a real marker from the staged shot arrived at +42.5 s inside
that wait. `test2` passed the same spec at the same commit, and nothing in this round touches the Hud.

## Claims

1. **FINDING 1, FIXED AT THE RULE: only MY shot comes out of MY gun.** `Effects.muzzleFrame` asks the
   viewmodel provider only when `payload.shooterUserId == Players.LocalPlayer.UserId`, and
   `Camera.viewmodelMuzzle` answers nil outside first person. `weapon_client.spec` drives both
   shooters from one payload shape: my shot lands at the drawn muzzle, another player's at the world
   frame, the provider is **not even asked** for theirs (the ask-count is the assertion), and the
   TRACER is measured too -- the defect stretched one from my muzzle to their impacts.
   `task92 flash: my shot 0.30 studs from my drawn muzzle; another player's 0.30 from the world
   muzzle and 41.9 from mine`. **MUTATION:** dropping `mine and` fails that case by name -- a
   non-local payload came back at the drawn muzzle where the world frame was expected. Restored.
   The fixture's "other player" is derived from the local id, not -1: a Studio test client's own
   UserId **is** -1, which is why the first two-player run failed on the shooter and passed on the
   driver.
2. **THE NEW MESH, ON SCREEN** (`.screenshots/...t92r2-ads.png`, `...t92r2-carry.png`, daylight, flag
   on, cleared after). Aimed: two barrels run from the bottom of the frame away to the muzzle as one
   smooth blued surface with a single continuous highlight down the rib -- **no shards and no dark
   seam lines anywhere on them**, where the r4 build showed the action as white angular patches with
   black cracks. The action is now out of the frame entirely. Carried: the same smooth gloss on the
   barrels, warm walnut stock, the brass bead a small gold dot at the muzzle.
3. **THE CHEEK ANGLE, ON SCREEN AND MEASURED.** In the same aimed shot the view runs along the TOP of
   the barrels -- their upper surface is visible and tapers to the bead, and the standing breech that
   filled the lower centre before is gone below the frame edge, which is Karen's own picture's
   composition. The bead's centroid is **1.44 px (0.09 deg)** from the frame centre; the gate's own
   client measurement is `task90 bead: worst 0.00 px from the shot line and the screen centre`.
4. **NO JUMP ON ADS, still.** Bit-for-bit in `camera_mode.spec` (eye, look vector, the point 60 studs
   down the centre), and measured on a pair taken without touching the mouse: a post standing at the
   screen centre keeps its centre at **x = 478.5 px** before and after, and its width scales
   **x1.500** against the field of view's own x1.502 -- a pure zoom about the aim point.
5. **RECOIL RETURNS THE AIM POINT EXACTLY.** Three critically damped springs, sub-stepped at 1/60 s;
   the camera CFrame after a kick is bit-for-bit what it was before, at 240/60/20 fps; a doublet is
   clamped; `Mode.kick` is a no-op in the third-person branch.

## Not verified

- Karen has not played any of it. The cheek angle, the light and the recoil numbers are first picks,
  and the cheek angle changes a picture she had already called good.
- No screenshot caught the 0.05 s flash itself; the smoke puff at the muzzle is the visual proof, and
  only for my own shot -- another player's flash has been measured but not seen.
