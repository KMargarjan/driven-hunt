# Task 120: animal bugs first

Task: 120
Round: 1
Base: 25e84c031b4dd1c1e4a3967ce51fba51eaf92ebe
Code commit: eaf75b3fdde1cf2c1aff239a632c3af4765d6c57

[harness] PASS: 33/33 checks @ eaf75b3fdde1cf2c1aff239a632c3af4765d6c57 (clean tree) scope=all

## Claims

1. **The shot cub was the DRAWING, not the carcass.** Its body was drawn 1.01 studs under the floor
   on an animal 1.44 studs tall while the box stayed anchored with `Carcass = true`. Cause: every
   kind plays the male's clips, a KeyframeSequence's bone translations are absolute studs, and the
   fall is child-bone translations, so a rig baked smaller is driven too far down (the root bone
   never moves -- measured). Verify: `Boar.CONFIG.KINDS`' `deathLiftStuds` block (method + numbers)
   and `Body.collapse` giving them back in one write through `Body.liftDrawn`.
2. **The numbers are MEASURED, not computed**, at the frame `Body.stepVisual` freezes the death on:
   male +0.002, sow -0.205, cub -1.009. Verify: `boar_kinds.spec` "carries the studs each kind's
   carcass has to be given back" -- all three, `(1 - scale)` shown not to predict the sow's, and 0
   for every kind with `KINDS` off.
3. **The write reaches the drawn body and nothing else.** Verify: `boar_model.spec` "a cub's carcass
   is given back what the male's death clip takes off it" -- the mesh moves straight up in the
   trunk's frame by exactly the kind's lift, stays welded, and the male moves 0. Mutation-checked:
   disabling the lift fails that case.
4. **A kill carries which animal died.** `Wound.killRecord` takes a trailing `kind`, and `Downed`
   and `Despawned` both carry it -- where a later cub penalty reads it. No penalty built.
5. **The flaky kick, at its cause.** `camera_client.spec`'s "the shot's kick" now waits for
   `Camera.Mode.recoiling` to go false before asserting the rest state is exactly zero -- true only
   when all six recoil fields are at exact zero, so "it came home" is not weakened. Also 118a(a):
   `match_live.spec`'s `boarStimuli` kinds case.

## Could not verify

- The lift lands at the moment of death, so a cub starts its 1.2 s fall about a body-height high.
  Better than ending buried; Karen's eyes decide. No spec can load a real clip, so the three numbers
  come from a live kill and a lab rig, not from the suite.
