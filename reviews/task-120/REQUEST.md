# Task 120: animal bugs first

Task: 120
Round: 1
Base: 25e84c031b4dd1c1e4a3967ce51fba51eaf92ebe
Code commit: 7054ce5812db746998f49bae9b6bfd0b00aa90ae

[harness] PASS: 33/33 checks @ 7054ce5812db746998f49bae9b6bfd0b00aa90ae (clean tree) scope=all

## Claims

1. **The shot cub was the DRAWING, not the carcass**: drawn 1.01 studs under the floor on an animal
   1.44 studs tall, while the box stayed anchored with `Carcass = true`. Every kind plays the male's
   clips, a KeyframeSequence's bone translations are absolute studs, and the fall is child-bone
   translations -- so a rig baked smaller is driven too far down (the root bone never moves,
   measured). Fixed in one write at death: `Body.collapse` -> `Body.liftDrawn`, a weld offset that
   touches nothing a shot reads. Live after the fix, a killed cub sits at -0.011 of the ground.
2. **Its numbers are MEASURED**, at the frame `Body.stepVisual` freezes the death on: male +0.002,
   sow -0.205, cub -1.009. Verify: `Boar.CONFIG.KINDS`' `deathLiftStuds` block; `boar_kinds.spec`
   "carries the studs each kind's carcass has to be given back" (all three, `(1 - scale)` shown not
   to predict the sow's, 0 with `KINDS` off); `boar_model.spec` "a cub's carcass is given back what
   the male's death clip takes off it" -- the mesh rises in the trunk's frame by exactly the kind's
   lift, stays welded, the male moves 0. Mutation-checked.
3. **The hit sound is lower and softer** (Karen, 2026-10-04): volume 0.8 -> 0.45, pitch 1.0 -> 0.85,
   highs cut 18 dB. Softer is a filter and not only a volume, so `makeSound` builds an
   `EqualizerSoundEffect` for any row carrying `eq`. Verify: `boar_shot.spec` reads the config and
   the real Sound's effect back.
4. **The sound after a late death is the FALL cue, not a replayed hit -- measured**: `hit@1.18
   cry@1.18 ... death@26.16 fall@26.16 lastBreath@27.16`, counts `hit=1 ... fall=1`. "Body Fall
   Gooshy Mud 2" is a wet impact one id from "Body Hit Wet 7", so `FALL` is retuned to 0.4 / 0.72 /
   -22 dB, quieter and lower than the hit in both numbers. Verify: `boar_shot.spec` "keeps the fall
   from sounding like the hit" and "is still one play after a rump wound finishes the animal later".
   Mutation-checked by making `playDeath` replay the hit.
5. **Two more**: a kill now carries which animal died (`Wound.killRecord`'s trailing `kind`, on
   `Downed` and `Despawned`; no penalty built), and `camera_client.spec`'s "the shot's kick" waits
   for `Camera.Mode.recoiling` to go false before asserting the rest state is exactly zero -- true
   only when all six recoil fields are zero, so "it came home" is not weakened. Also 118a(a):
   `match_live.spec`'s `boarStimuli` kinds case.

## Could not verify

- Nothing here can hear a sample: claims 3 and 4 are dials and instance properties, and Karen's ears
  decide. The lift lands at the moment of death, so a cub starts its 1.2 s fall a body-height high.
- `tests/client/weapon_client.spec.luau`'s reserve check failed twice today (Slug 23 against a
  baseline of 25) and passed on every re-run, both clean-tree runs included. Nothing here touches
  the weapon; queued in `TASKS.md` under 120.
