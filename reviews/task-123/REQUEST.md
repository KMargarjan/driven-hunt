# Task 123 - a group is heard as one or two animals, not twenty

Task: 123
Round: 1
Base: main
Code commit: `831a06fbe759608129b15f1fbfdfb2f5abebfb16`

```
[harness] PASS: 33/33 checks @ 831a06fbe759608129b15f1fbfdfb2f5abebfb16 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 831a06fbe759608129b15f1fbfdfb2f5abebfb16 (clean tree)
```

**THIS TASK IS ONE OF NINE IN ONE PR** (122-130, `task-130-spawn-view` -> `main`). Director
decision, recorded in `ESCALATE.md`: no branch below 128 can pass the gate on its own -- DEV's
map could only be rebuilt once 128's bundler existed, and 129 fixed the specs 123-127 broke --
so the evidence for every task in the stack is the gate AT THE HEAD, and every task still gets
its own review.


## What changed

The sound of a herd. Measured first in Karen's own place with her own waves: **31 playing sounds at
once with 36 boars out**. The final state is a drive whose animals are nearly silent until they are
close, with one voice per flock on the approach.

## Claims

1. **Two rations, in series, all data.** `Boar.CONFIG.SOUND.CROWD` holds both: per sounder
   (`VOICES_PER_SOUNDER = 1`) and world-wide, nearest a listener first (`MAX_STEP_VOICES = 1`). The
   sounder gate runs FIRST and the world ceiling is awarded among its survivors -- ANDed, the two
   keys can select disjoint sets and a whole running herd goes silent. Verify: `Boar.voiceHolders`
   and `Boar.nearestVoices` in `src/server/Boar/init.luau`, and `Runtime:_rationVoices`.
2. **A slot only goes to an animal that would use it**, which was measured: three samples of total
   silence with 40 boars out, because animals standing at the hunter's feet held every footstep slot.
   Candidacy uses `Body.stepSound`'s own bands. Verify: `Runtime:_rationVoices`.
3. **The holder is sticky.** A footstep loop handed between jostling animals stops and restarts,
   which is the chaotic mixing Karen complained of; the world's single step voice is held for
   `CROWD.STEP_HOLD_SECONDS` while its holder is still a candidate. Verify: same function.
4. **The ambient pig voice is OFF**, by data and not by deletion: `SOUND.BREATH.enabled = false`,
   `SOUND.SNIFF.enabled = false`. Karen: *"when they cross road or they close they don't make any pig
   sound besides walking"*.
5. **One grunt per flock, on approach.** `GRUNTS.ON_APPROACH = true` turns the grunt from an interval
   cue into an EVENT: one per group the first time it comes within `CLOSE_STUDS` of a hunter, re-armed
   only past `REARM_STUDS`. Karen: *"we can have one hriu sound per flack when they are close"*.
   Verify: `Runtime:_stepApproachGrunts`.
6. **The two reaches are swapped from task 120's.** The hooves stop at 40 studs and the grunt carries
   160, because a hoof on soil does not carry 130 studs and a pig's voice does. Verify:
   `SOUND.STEPS.*.audibleStuds` and `SOUND.GRUNTS.audibleStuds`.
7. **The pace ladder.** `Boar.CONFIG.PACE` makes a pushed animal walk, a crowded one trot and a
   spooked one run, and a REAL driver inside `DRIVER_RUN_STUDS` runs it while the drive's own phantom
   beater does not. Measured on this commit: beater at 14 studs 4.5, at 11 studs 11.0, real driver 24.0.
   Verify: `Brain.perceive` in `src/server/Boar/Brain.luau`, `tests/server/boar_behaviour.spec.luau`.
8. **The specs that cover all of this were only able to RUN from task 129** (see that request): six
   of them encoded the contract this task replaced, and they now carry Karen's quote beside the
   number they assert.

## What could not be verified

- **How it sounds to Karen.** The ration is counted, not judged: the smoke's worst figure is 4
  playing sounds (3 boar voices plus the world's Ambience), but *"still to noisy"* was her sentence
  twice and only she can close it.
- **The footstep sample is a stand-in.** `rbxasset://sounds/action_footsteps_plastic.mp3` is an engine
  CC0 file chosen because the bought "Goat Footsteps" read as a horse; the row keeps `was = <old id>`
  so the swap is one line when a better sample is bought.
