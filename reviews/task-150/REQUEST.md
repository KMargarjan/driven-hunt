# Task 150 - once they hear a shot they run and don't stop, 100 m, and a carcass that lies down

Task: 150
Round: 1
Base: main (`c114359`); branch `task-149b-boar-shot-reaction`, which also carries task 149b
Code commit: `19c12fdeea2d2ef566e51cd1dc0dd1c76fe55eae`

```
[harness]  PASS: 33/33 checks @ 19c12fdeea2d2ef566e51cd1dc0dd1c76fe55eae (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 19c12fdeea2d2ef566e51cd1dc0dd1c76fe55eae (clean tree)
```

`test2` is **required** here: the branch touches `src/server/MatchBoot.server.luau` (task 149b's one
line, `runtime:hearShot(shot.muzzle, shot.at)`), which is in `TWO_PLAYER_PATHS`.

KAREN, 2026-10-10 ~21:20, verbatim (full text in `PLAYTEST.md`): *"still after animal died it stands
and stay still / after shoot they run then com closer to road and stay / let's make this way / once
they hear shoot they run and don't stop / blast radius 100m around / still can see sometimes boar hit
tree and wal in place so not avoiding tree"*. **No Architect run:** one new precedence row in a table
that already has twelve, one pure predicate, and two dials.

**THIS REQUEST COVERS TASK 149b AS WELL** -- the same branch, never reviewed, because
`tools/review.ps1` refuses a folder named `task-149b` (`ESCALATE.md`, 2026-10-10). 149b's own claims
are in its commits `dc51a3d` and `8468e38`: a shot is heard from the IMPACT as well as the shooter,
and an animal that has crossed keeps going.

## The claims

1. **A HEARD SHOT LATCHES, ONE WAY, AND ONLY THE EXIT ENDS IT.** `Brain:spook` takes a third argument
   saying the fright was a BANG; `_hearSound` and the wave released into a wood that has just been
   shot in pass it. While `_heardShot` is set: `_flightActive` is true (so no order re-captures the
   animal and the line it runs is the one it set off on), `_settle` refuses, `_senseAware`'s new row
   6b holds it in FLEE, and the pace clamp's `spooked` keeps it at `PACE.RUN_SPEED`. **What Karen
   watched was the config doing what it said:** four seconds of bolt, 300 studs of latched line, then
   `WALK_SPEED` and a calm timer that puts the animal back to grazing beside the road.
   **Verify:** `boar_move.spec`, "runs at a RUN until it is off the board, where the flag off slows to
   a walk" -- the same animal and the same bang, with `SENSE.SHOT_FLIGHT_UNTIL_EXIT` on and off.
   Driven through the Brain in the Edit place: **ON slowest 24.000 studs/s, never IDLE, GONE at
   22.0 s; OFF slowest 0.000, IDLE at 8.2 s, still there at 40 s.**

2. **MEASURED IN THE FOREST TEST, THREE SINGLE SHOTS: 94 ANIMALS HEARD IT, 94 LEFT.** Each trace
   snapshots every damageable boar inside the radius at the instant of the shot -- the rule is
   deterministic, so who heard it is known rather than guessed -- and then follows each one:

   ```
   shot at  88 studs   31 heard   31 left   (slowest not yet measured)   0 stuck   1 stepped back
   shot at 113 studs   33 heard   33 left   slowest 1 s average 10.1     0 stuck   0 stepped back
   shot at  72 studs   30 heard   30 left   slowest 1 s average 12.8     0 stuck   1 stepped back
   ```

   **None of 63 ever averaged under 6 studs/s over any second after the shot**, and the mean time to
   leave the field was 7.8-20.0 s.

3. **100 m, BOTH CIRCLES, IN METRES.** `SHOT_HEARD_FROM_SHOOTER_M` and `SHOT_HEARD_FROM_IMPACT_M` are
   both 100, with `SHOT_AUDIBLE_STUDS = SHOT_AUDIBLE_FROM_IMPACT_STUDS = 357` beside them and
   `METRES_PER_STUD = 0.28` above. **Verify:** `boar_behaviour.spec` asserts the two spellings agree
   to half a metre, that the impact circle is never the smaller one, and that both read 100 -- a
   change to either is a change to a number Karen decided, and that line makes somebody say so.

4. **THE RADIUS, MEASURED: 90-93% of animals inside it moving at a flight speed one second later**,
   over 171 shots and 1,426 animals on the shipped build (and 90-92% over 319 shots across the
   evening). **This is short of the 100% the dispatch asked for and I cannot account for all of the
   gap:** animals that are DOWN or CRIPPLED deliberately do not hear, and one still on the ACCEL ramp
   at the one-second mark is not yet at 6 studs/s -- I did not separate those two, so I cannot say
   the remaining 8-10% is all legitimate.

5. **THE STANDING DEAD BOAR WAS TWO BUGS, AND BOTH ARE MEASURED ON WHAT THE CLIENT DRAWS.** Task 149b
   could not see this because a skinned MeshPart's bounding box never moves; its BONES do.
   `Bone.TransformedWorldCFrame` on the drawing client gives a scale-free number: the angle between
   the spine's up vector and world up. **A live standing boar reads 1-18 degrees; a carcass on its
   flank reads 86-104.**
   * **(i)** `Body.collapse` has rolled the box only when there is NO visual since task 120 -- but "a
     model exists" is not "the clip will play". An Animator that never arrived, a `LoadAnimation`
     that failed, an id that is not published: in each the animal has a model, the box stayed upright
     and the rig stood in its bind pose for the whole `CARCASS_SECONDS`. **Measured: one of eight
     kills read tilt 4.9, rise 0.79 -- a live standing boar's own numbers -- with no animation track
     on it at all.**
   * **(ii)** A box that TUMBLED under gravity while the clip played composed two rotations into one
     standing animal. **Measured on a real kill: boxRoll -90.2 degrees with the death paddle playing,
     and the drawn spine 4.4 degrees off world up.**
   **Verify:** `Body.boxFalls(hasVisual, hasDeathTrack)` is the whole decision and `boar_model.spec`
   drives its three rows. The upright `AlignOrientation` now stays enabled whenever the CLIP is doing
   the falling -- so gravity still drops the carcass onto the ground, which
   `boar_model.spec`'s "the box's bottom is still on the ground" waits for, and can no longer roll it.

6. **AND A THIRD CAUSE THAT IS NOT THE BOAR'S, SO IT IS MITIGATED RATHER THAN FIXED.** Over 60 kills
   on four runs, reading the same rig on both sides: **every carcass lies down on the SERVER** -- 0
   standing, the fall and the paddle playing on each -- and **about one in ten stood on the CLIENT,
   with no animation track on it there at all** and its box at the server's own angle. That client
   missed the one `Play` the death ever gets. So the death pose is **stated once more at +6 s**, after
   the fall (1.208 s) and the paddle (4.0 s) have both ended and the track is being held at its last
   frame: on a client that has the pose it is the frame it was already showing, and on one that
   missed everything it is the first time the animal is told to lie down.
   **Verify:** `Body.shouldReassert` and its spec case, which pins it after both clips and well inside
   `CARCASS_SECONDS`.

7. **40 KILLS ON THE SHIPPED BUILD, 0 STANDING DEAD**, both guns, head / chest / rear, on animals
   walking, trotting and running, with the pose read off the client's own bones at +2 s, +8 s and
   +20 s. (Before the fixes, the same probe read 1 of 8, 3 of 29, 1 of 9 and 1 of 22.)

8. **THE TREE: A 0.75 s WEDGE DETECTOR, AND 0 STUCK-IN-PLACE EVENTS.** `Brain:_updateWedge` is the
   Director's own definition -- a setpoint over `WEDGE_ORDERED_SPEED` (2 studs/s) and under
   `WEDGE_SPEED` (0.5) of ground actually covered, over `WEDGE_SECONDS` -- measured off POSITION,
   because a setpoint cannot know the animal is not moving. It answers true on exactly ONE tick and
   turns `_desired` 90 degrees after the slew, then HOLDS that line for `WEDGE_HOLD_SECONDS`; a turn
   per frame would be a rotation generator, which is the failure task 126's turn budget was abandoned
   for. The old recovery is `STUCK_TIME` 2 s, and the flee branch's sidestep waited for the SECOND
   report -- four seconds. **Verify:** `boar_move.spec`'s two cases (it turns inside
   `WEDGE_SECONDS + 0.5` where the detector off never turns at all; and a running animal turns 0.0
   degrees in three seconds). **Live: 0 events across all three traces** -- no animal under 0.5
   studs/s for over 0.75 s while latched to a run.

9. **THE TWO-PLAYER RUN FAILED FOUR TIMES AND TAUGHT ME TWO THINGS I HAD WRONG.** `[harness2] FAIL:
   31/35` three times running. **(a)** `weapon_equip.spec` was not failing on WHO the player was --
   my first two fixes (prefer a non-Driver, then prefer a player the policy will arm) both failed,
   the second one worse. `Match` decides who may carry through an arming POLICY that `Weapon` reads,
   and its answer depends on the drive's PHASE as well as the roster: it can be true when a case
   starts and false by the time that case tidies up, and `refreshArming` then correctly leaves the
   player with nothing. The file installs the one-player policy around each case and puts back
   whatever was there -- `Weapon.setArmingPolicy` returns the policy it replaces now, which is what
   makes that possible without the spec knowing which place installed it. `zz_drive_boundary.spec` is
   where the policy itself is tested and is untouched. **(b)** `rifle_client.spec`'s
   *"wears a mesh for every piece this client has actually downloaded"* counted a template called
   `Shell` -- which the viewmodel CLONES per barrel during a break-action reload, under its own name
   (`SpentShell1`, `FreshShell2`), and `Viewmodel.clearShells` takes away again. A gun at rest wears
   no part called `Shell`. It passed with one client only because that client had not finished
   downloading the shell, so it was not counted as ready either.

10. **THREE OF MY OWN METRICS WERE WRONG AND THE GATE CAUGHT ALL THREE** (`f7d144d`), which is worth
    writing down because they are the same class of mistake as task 149b's: *"the slowest it ever
    ran"* came out 0.0 studs/s at 22.0 s -- the moment the animal reached the exit, went GONE and
    published a zero velocity, which is the case SUCCEEDING; and the two wedge cases took their
    baseline heading on frame one, when a freshly spooked animal swings up to 179 degrees onto its
    latched flight line, so both worlds "turned" at 0.45 s and the comparison was measuring the
    flight latch.

## Standing rule A, Forest Test, 90 s, on the code commit

* the Tool is in the CHARACTER at 15 s and at 90 s (`gun in hand @15s=1 @90s=1`)
* **0 "Stack Begin" and 0 error lines** in the whole console
* **five waves released**, worst 1 boar sound at once over 10 s with 32 boars alive

## What I could not verify, and what is short of target

* **THE RADIUS IS 90-93%, NOT 100%** (claim 4), and I did not separate the animals that deliberately
  do not hear from the ones still on the ACCEL ramp.
* **ONE IN TEN CARCASSES STOOD ON THE CLIENT WHILE LYING DOWN ON THE SERVER, AND I DID NOT FIND OUT
  WHY** (claim 6). The +6 s re-assert is a mitigation aimed at the symptom: 40 kills since, 0
  standing, but a one-in-ten event over 40 trials is not proof -- it is p = 0.01 against the old rate,
  and the cause is still a client that misses a replicated `Play`.
* **"CAME BACK TOWARD THE ROAD" IS 2 OF 94, NOT 0.** My metric counts any one-second bucket in which
  an animal already 10+ studs clear of the road lost more than 2 studs of that -- which a swerve
  round a trunk does. I did not look at the two individually.
* **ITEM A'S TRACES ARE SINGLE SHOTS INTO A SETTLED WOOD**, not a whole drive: that isolates the
  latch from a beater's push, which was the point, but it is not the same world Karen plays.
