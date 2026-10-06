# Task 129 - a green gate for the forest-test stack

Task: 129
Round: 2
Base: main
Code commit: `b414f4d5c88f0a2bb01cb67c8465c06f3e3f9dd1`

```
[harness] PASS: 33/33 checks @ b414f4d5c88f0a2bb01cb67c8465c06f3e3f9dd1 (clean tree) scope=all
[harness2] <the Director runs this at the code commit and pastes it here>
```

The `[harness2]` line is the Director's: it needs one Studio open, and this round's live proof
needed the Forest Test open beside DEV.

**THIS TASK IS ONE OF NINE IN ONE PR** (122-130, `task-130-spawn-view` -> `main`). Director
decision, recorded in `ESCALATE.md`: no branch below 128 can pass the gate on its own -- DEV's
map could only be rebuilt once 128's bundler existed, and 129 fixed the specs 123-127 broke --
so the evidence for every task in the stack is the gate AT THE HEAD, and every task still gets
its own review.


## What changed

Task 128's bundler let DEV's gate run again and it found **20 failures across tasks 123-127** that
six blocked gates had hidden. Three were real bugs in shipped code; the rest were specs holding a
contract Karen has since changed, or cases that could never have passed either way.

## What round 1 found, and what round 2 did

**ROUND 2.** #1 the same vacuous case as task 123's #1, fixed the same way (the beater is a push again). #2 the claim that the shipped silence is asserted somewhere was false; it is asserted now, in `tests/server/boar_move.spec.luau`, and this request no longer claims otherwise.

## Claims

1. **The compass was half a turn out, and the code was wrong.** Settled against a PHOTOGRAPH, not a
   CFrame: four neon posts 60 studs out, one per world axis -- the blue post (-Z) filled the middle
   of the frame while the strip read N (`.screenshots/t129-turn-A.png`), and two real mouse turns
   moved the camera 180 -> 183 -> 186 while the strip went 0 -> 3 -> 6. The `+ 180` is gone and the
   conversion is `Camera.headingOfLookDeg`, which the spec CALLS instead of copying. Verify:
   `src/client/Camera/init.luau`, `tests/client/compass.spec.luau`.
2. **The footsteps slid.** Task 126 multiplied each gait's `pitch` into the playback rate, which is
   the stride, so the walk rate fell below `MIN_RATE` and the sound no longer kept time with the
   legs. Rate is the stride again; the timbre is a `PitchShiftSoundEffect`. Verify:
   `Body.stepSoundFor` and `makeSound` in `src/server/Boar/Body.luau`, and the two cases in
   `tests/server/boar_shot.spec.luau` that compare the sound rate with the clip rate.
3. **The gun stayed in the Backpack.** `Hardware.equip` called `EquipTool` and never checked:
   measured, all three grants were equipped with a live Humanoid and the client still had the gun in
   the Backpack from +76 s, because during the drive's placement respawn the humanoid exists but will
   not carry anything yet and `EquipTool` fails silently. It now verifies the outcome and retries for
   two seconds. Verify: `src/server/Weapon/Hardware.luau`, and the equip tally in `Weapon.stats`.
4. **A real driver inside `DRIVER_RUN_STUDS` IS a spook now**, and only the drive's phantom beater is
   a pure push -- the spec held the pre-123-round-5 contract. Verify:
   `tests/server/boar_behaviour.spec.luau`.
5. **The ration cases switch the cue on BY PARAMETER.** The ambient voice and the breath are off in
   the config the game ships, so a ration cannot be tested against them; `voicedSound()` enables the
   cue and the shipped silence is asserted separately. Verify: `tests/server/boar_shot.spec.luau`.
6. **Four cases could never have passed either way.** `settledSpeed` held its threat at a fixed world
   point, so "how fast does a pushed animal go" was really asking how fast one goes two seconds after
   outrunning the thing pushing it. `pushedBy` keeps the party behind the animal, like a beater.
7. **A spec world has no physics.** A boar is driven by a `LinearVelocity` constraint, so in a
   one-frame spec no body moves, and the voice ration -- which only feeds an animal that IS moving --
   silenced every animal in the world. The rule is right; the spec now supplies the motion the engine
   would, from the speed the Runtime asked for. `Runtime:statusOf` publishes `want` beside `speed` for
   exactly this reason.
8. **The whisker geometry in the spec was mirrored.** Facing +Z, Roblox's `RightVector` is (-1, 0, 0),
   so steering right is -X; the code had it right and the case had it backwards.

## What could not be verified

- **Why the harness session takes the gun off the shooter.** The camera case now asserts the camera's
  rule -- whenever the Tool is in the character the viewmodel is with it -- and NOTES, on every run,
  that in the gate's own session the character holds nothing for a 25-second window while a Tool
  waits in the Backpack. In a plain DEV Play the Shotgun is in the character and the viewmodel
  parented from 12 s to 95 s, every sample. The server believes it equipped it. Only the harness
  sees it, and I could not find the unequip.
- **The flaky check.** `boar_body.spec`'s "the sounder scatters after its leader dies" failed in 2 of
  9 runs on identical code and passed in the rest. Queued in `TASKS.md` under before-release.
