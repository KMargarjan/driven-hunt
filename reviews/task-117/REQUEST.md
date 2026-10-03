# Task 117 -- the calm boar, behind `BOAR_MODEL`

Task: 117
Round: 1
Base: `main` (`e0a02ae`)
Code commit: f7fafd1307fb64ca18ac7b384dcbe4917c43b9a9

```
[harness] PASS: 33/33 checks @ f7fafd1307fb64ca18ac7b384dcbe4917c43b9a9 (clean tree) scope=all
```

`test2` **N/A**: `needs_two_player` over the branch diff returns `[]` -- boar, assets and tools only,
nothing in `TWO_PLAYER_PATHS`. Everything after the code commit is paperwork (`TASKS.md`,
`PLAYTEST.md`, this file).

Karen, 2026-10-03: *"boar also can move alon and walk and lift head like smell ect"*. This is the
"on easy" half only; being spooked is Task 118. Her look on this branch: *"1. yes it works / 2. yes
it is / 3. probably / 4. yes feets on the ground"*.

## Claims

1. **No new Brain state, which is what keeps Task 118 free.** The IDLE branch of `Brain:step`
   alternated "grazing" and "wandering" through one boolean; `Brain:_stepCalm` replaces it and
   returns a speed. Everything else about IDLE -- the heading, the home pull, the probe turn, the
   sounder slot -- is the code it was. *Verify:* `Brain:_stepCalm` and the `if self._state == "IDLE"`
   block; `boar_brain.spec` still passes unchanged.

2. **The repertoire is data, and the draw is pure.** `Brain.calmActivity(roll, config)` walks
   `Boar.CONFIG.CALM.ACTIVITIES` and returns one row in proportion to its `weight`; each row carries
   its own `speed`, `minSeconds`/`maxSeconds` and `clip`. *Verify:* `boar_calm.spec`, "the repertoire
   is data" -- the five names, every one drawn, each within 1 % of its weight's share over 1001
   evenly spaced rolls, and a roll outside [0, 1) clamped instead of answering nil.

3. **One activity at a time, and one clip at a time.** `Body.activityClip` answers the exit clip the
   LAST activity asked for, then the enter clip for exactly its own length, then the activity's loop;
   a row with no `clip` (`walk`) answers nil so the gait bands take it. *Verify:* `boar_calm.spec`,
   "one activity draws one clip, and never two" -- each activity's clip, the enter boundary at
   `grazeStart.seconds`, the exit winning over what the next activity wants, and `digWalk` rated off
   its own 1.901 studs/s so the feet do not slide.

4. **A calm clip never fights a death, a cripple or a flinch.** `Body.clipFor` consults the activity
   only after those three, and `Body.activityClip` refuses outright when `collapsed` or `crippled`.
   *Verify:* `boar_calm.spec`, "is beaten by a death, a cripple and a flinch". That case found the
   hole it now covers: with `crippleDrag` unpublished, a crippled boar fell through to grazing.

5. **With no id, a calm boar draws exactly what it drew before.** `Body.hasClip` is the one test, and
   every calm path runs through it. *Verify:* `boar_calm.spec`, "with no id published..." -- driven
   with an id table holding only what Task 115 published, every calm activity falls back to `idle` or
   `walk`.

6. **Which clip does what was MEASURED, not chosen by name.** Over the package's 74 actions, off the
   head and nose bones in Blender: `Idle_5` is the only clip whose nose rises above horizontal
   (-18.9 to +11.5 deg, a **30.4 deg** lift, hooves not moving); `Idle_4` is its opposite (nose to
   -72 deg); `Idle_2/3/6` are 9-15 deg ground-level fidgets; `Eat_loop_1/2` put the nose at
   -70..-40 deg; `Dig_walk_IP` has the head low AND the hooves travelling. *Verify:*
   `tools/boar_prep.py` `DEFAULT_CLIPS`' comment and each `Assets.ROWS` note; the numbers are
   reproducible with `tools/boar_prep.py prep`.

7. **The six ids are published and all six were `Loop = true`.** `Body.play` writes
   `AnimationTrack.Looped` from `MODEL.CLIPS` immediately before every `Play`. *Verify:*
   `boar_calm.spec`, "plays the three one-shots ONCE and the three loops for ever" -- `smell`,
   `grazeStart` and `grazeEnd` are `looped = false`, the other three true; `boar_model.spec`, "has a
   row with a real asset id for every one of them", now nineteen with an empty `AWAITING_AN_ID`.

8. **No two boars in step.** The first activity starts part-way through its band
   (`CALM.FIRST_PHASE_SECONDS`). *Verify:* `boar_calm.spec`, "puts two boars out of step" -- two
   seeds stepped together for 30 s agreed on 17 % of frames.

## What I looked at (rule 5)

Frames in `.screenshots/`, each inspected, with the head and nose bones measured live in studs above
the box's own floor:

- **`boar-117-graze.png`** -- head down, snout at ground level, tusks showing, standing still. Nose
  **0.39-0.53** over 48 samples, against **1.34-1.90** standing: in the grass, not through it.
- **`boar-117-dig.png`** -- snout pushed into the ground, forelegs splayed, the body moving forward.
  Nose **0.34-0.52** while travelling at 1.90 studs/s.
- **`boar-117-smell.png`** -- square stance, feet still, snout tipped up. Nose **1.78-2.31** over 25
  samples, 0.4 above its own standing maximum.
- **`boar-117-walk.png`**, **`-idle.png`**, **`-graze_start.png`**, **`-graze_end.png`** -- the walk
  cycle, the standing idle, and the two transitions (nose sweeping 0.40 -> 1.76 and 0.47 -> 1.89,
  which is the head coming out of the grass over the clip's 1.08 s).

## What I could not verify

- **Nobody has heard the sniff.** It reuses a ProSoundEffects id this project has already verified
  ("Bull Breaths 10", 9113630137) at pitch 1.25, because nothing in this toolchain can search the
  audio library. It is one number in `Boar.CONFIG.SOUND.SNIFF`.
- **`grazeChew` (`Eat_loop_2`) is published, declared and wired, and no activity picks it.** `graze`
  names `grazeLoop`. It is one word in `CALM.ACTIVITIES` to use it, or one row to delete; I have left
  it because a second graze loop is what stops the longest activity repeating, and choosing between
  them is a feel decision nobody has made.
- **Karen's answer on two boars being out of step was *"probably"***, not yes. The spec measures 17 %
  agreement over 30 s; her own eye has not settled it.
- **At 30-60 studs the head-up lift is a 0.4-stud movement** (about 0.4-0.8 degrees subtended). The
  posture and the sniff are what should read at that range, not the travel. Not tested from a post.
- **No spec can load an animation or an audio asset**, which is why `calmActivity`, `activityRow`,
  `activityClip` and `hasClip` are pure functions with their own cases.
