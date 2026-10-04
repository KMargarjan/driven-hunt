# Task 120: animal bugs first

Task: 120
Round: 1
Base: 25e84c031b4dd1c1e4a3967ce51fba51eaf92ebe
Code commit: acc1e5c41612e17d40937ebf1215e105ebfec498

[harness] PASS: 33/33 checks @ acc1e5c41612e17d40937ebf1215e105ebfec498 (clean tree) scope=all

## Claims

1. **The shot cub was the DRAWING, not the carcass**: drawn 1.01 studs under the floor on an animal
   1.44 studs tall, while the box stayed anchored with `Carcass = true`. Every kind plays the male's
   clips, a KeyframeSequence's bone translations are absolute studs, and the fall is child-bone
   translations -- so a rig baked smaller is driven too far down (the root bone never moves,
   measured). One write at death, `Body.collapse` -> `Body.liftDrawn`, a weld offset that touches
   nothing a shot reads. Measured at the frozen death frame: male +0.002, sow -0.205, cub -1.009;
   live after the fix a killed cub sits at -0.011. Verify: `Boar.CONFIG.KINDS`' `deathLiftStuds`;
   `boar_kinds.spec` "carries the studs each kind's carcass has to be given back"; `boar_model.spec`
   "a cub's carcass is given back what the male's death clip takes off it". Mutation-checked.
2. **The bullet hit, the body-fall thud and the last breath are OFF, by data**: `enabled = false` is
   the only line `playOneShot` reads, and every row keeps its id, volume and filter (Karen: "I think
   we can remove hit sound for now"). Verify: `boar_shot.spec` "has both impact cues OFF, by data
   and not by deletion", and the live "a REAL shot plays the CRY and NOT the bullet hit".
3. **A death is one short squeal**: the squeal samples rather than the scream, cut at 0.6 s with a
   0.15 s fade (`Body.stepCuts` / `Body.cutVolume`), and nothing after it. Verify: `boar_shot.spec`
   "makes a death ONE SHORT squeal rather than a scream" and the live "a dead boar has no footsteps
   and ONE SHORT squeal, and nothing after it".
4. **A voice per kind**: male 0.80, sow 1.00, cub 1.40 as the pitch centre of the three cues that
   come out of the animal (cry, death, grunts), with the male keeping the one rough scream in the
   verified set. Hooves, breath and the sniff are untouched. No new asset ids -- nothing here can
   audition a library. Verify: `boar_shot.spec` "gives each kind a voice of its own".
5. **A herd is not six animals**: one grunt per sounder per 2.5 s (skipped, never queued), two
   squeals world-wide at once, one set of hooves per sounder (the pure `Boar.isStepEmitter`), and
   voices fading to 0.55 beyond 60 studs. Verify: the four `boar_shot.spec` cases under "six animals
   must not sound like six animals" and the pure ones beside them -- the squeal cap is driven with
   three animals shot in one instant on a real six-boar sounder. Mutation-checked: dropping the
   `enabled` gate, the cut or the squeal cap fails its own case.

Earlier in this task, also under review: the kill record carries `kind` (`Downed`/`Despawned`; no
penalty built), and `camera_client.spec`'s "the shot's kick" waits for `Camera.Mode.recoiling` to go
false before asserting the rest state is exactly zero. Also 118a(a), `match_live.spec`'s kinds case.

## Could not verify

- Nothing in this toolchain can hear a sample: every sound claim is a dial or an instance property,
  and Karen's ears decide. The death lift lands at the moment of death, so a cub starts its 1.2 s
  fall a body-height high.
- The one-emitter cap is proved on the pure gate and by "no follower was ever heard": after the
  silent pre-roll a footstep loop is re-played only when the GAIT changes, so a spec cannot make six
  animals audibly run abreast. That quirk is queued in `TASKS.md` under 120, with
  `tests/client/weapon_client.spec.luau`'s reserve flake (seen twice, passed on every re-run).
