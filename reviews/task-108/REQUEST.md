# Task 108 — an instrument for the hands, and what is actually wrong with them

Task: 108
Round: 1
Base: `content-model-b-aim-1` (`1ee7ba0`)
Code commit: `839da1f46b37ad3f42efb09a3c5826bb9e50925a`

```
[harness] PASS: 32/32 checks @ 839da1f46b37ad3f42efb09a3c5826bb9e50925a (clean tree)
[harness2] PASS: 34/34 checks @ 839da1f46b37ad3f42efb09a3c5826bb9e50925a (clean tree)
```

`test2` was needed: `src/shared/HandAssets.luau` is under `src/` and outside
`WEAPON_VIEWMODEL_PATHS`.

**THE TASK IS NOT FINISHED AND THIS SAYS SO.** The hands are not re-seeded. What ships is the
measurement that explains Karen's bug and the instrument that makes the next pass quick; applying the
alignment re-means every angle in `poses.json`, and of the three poses only `carry` converged in the
hour. The aimed view — the one Karen judges — came out worse, so it is not shipped.

## Claims

1. **The two glove meshes do not share an axis, and that is the bug.** Measured off each prepped mesh
   by classifying every vertex by the colour its own UV samples in the base-colour map (the cuff is
   olive, the glove brown), so one centroid to the other IS wrist→fingers: the RIGHT glove's fingers
   run along its own **−X**, the LEFT glove's along its own **+Y**. No single yaw/pitch/twist can mean
   the same thing on both — which is why the Director's `left.rot.twist 180` moved the glove instead
   of rolling its palm. Verify: `HandAssets.AXES` and the comment above it.
2. **`pose.py inspect <pose>` photographs the drawn viewmodel FROM OUTSIDE.** The viewmodel is drawn
   at the camera, so moving the camera moves it too — and `Camera.update` writes the camera's CFrame
   every frame, so a harness camera is put back before the shutter (measured: the first try came back
   as empty sky). So it COPIES the model, parks it in front of the player's own view turned so the
   lens lands where an outside observer would stand, hides the live one for the shot, and destroys
   the copy. The pose hold is `compare`'s and is always released. Verify: `tools/pose.py run_inspect`.
3. **A spec guards the measurement**, because it is the deliverable: the vectors are unit, each
   glove's palm is not parallel to its own fingers (or the alignment cannot be built), and the two
   FINGER axes really differ — a later change that quietly made them agree would be one that had
   stopped measuring. Verify: `gun.spec` "records that the two gloves do NOT share an axis".
4. **Nothing that is drawn changed.** `poses.json` is the Director's `content-model-b-aim-1` exactly;
   `Camera.Viewmodel` is untouched. The hands look as they did — bad, and no worse.

## What I could not verify

- **The seeding is not done.** `carry` converged and was looked at
  (`.screenshots/20261002T135320Z-inspect-carry-left-front.png`): the left glove's fingers wrapped
  round the barrels at the forend, the right at the grip, both forearms running back out of frame.
  `aim` did not (`...135629Z-pose-aim.png`: the left glove fills the right of the frame, palm-on).
- **The LEFT glove's palm normal is an estimate** — the flattest axis of a cupped C hand, signed
  toward the fingertips. The right glove's is a clean slab. The pose's `twist` is the dial that
  finishes it, and that is part of what did not converge.
- **`pose.py inspect`'s two view angles were tuned by eye** against the carry pose; `below` missed the
  gun entirely at its first numbers and was re-aimed once.
