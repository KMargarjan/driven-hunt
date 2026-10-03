# Task 117 -- the calm boar, behind `BOAR_MODEL`

Task: 117
Round: 2
Base: `main` (`e0a02ae`)
Code commit: 707084544ba3a7c4ad186e81c01b54c1f23e19ff

```
[harness] PASS: 33/33 checks @ 707084544ba3a7c4ad186e81c01b54c1f23e19ff (clean tree) scope=all
```

`test2` **N/A**: `needs_two_player` over the branch diff returns `[]` -- boar, assets and tools only,
nothing in `TWO_PLAYER_PATHS`. Everything after the code commit is paperwork (`TASKS.md`,
`PLAYTEST.md`, this file).

Karen, 2026-10-03: *"boar also can move alon and walk and lift head like smell ect"*. This is the
"on easy" half only; being spooked is Task 118. Her look on this branch: *"1. yes it works / 2. yes
it is / 3. probably / 4. yes feets on the ground"*.

## What changed in round 2

All four blocking findings are right.

**1. A boar that bolts stops being calm at once.** `activityClip` tested the exit clip BEFORE it
asked whether the animal was calm at all, and `stepVisual` armed that exit on any change of
`info.activity` -- including the change to nil when the Brain leaves IDLE. A grazing boar that was
startled therefore drew `grazeEnd`, an in-place eating transition with ground speed 0, for its whole
1.083 s while the body accelerated to `SPRINT_SPEED`: about 25 studs of sliding with its head in the
grass. "Not calm, not a calm clip" is now one test at the top of `activityClip`, and leaving IDLE
CANCELS the exit instead of arming it.

**2. The repertoire was not behind the flag, and the comment said it was.** `CALM.ENABLED` is now
`Flags.isOn("BOAR_MODEL")`, read once at the boundary exactly as `MODEL.ENABLED` is. With the flag
off -- its default, and the live game -- `Brain:_stepCalm` and `Body.activityRow` both fall back and
an idle boar wanders as it did before Task 117.

**3 and 4. Two cases could not fail.** The fleeing case put the threat in from the first step, so
`_stepCalm` had never run; it now gets a calm boar with a real activity first and asserts `activity`
goes nil on the tick the state leaves IDLE. The phasing case asserted that two brains with different
seeds disagreed at least once, which is true whatever the phasing does; `Brain.firstPhase` is pure
now and asserted directly, and the live case drives two brains off ONE `Random` -- the shape
`Runtime:spawn` builds them in.

The notes are fixed in the same lines: `_grazeFor` is no longer armed while the repertoire is on (it
latched and made `GRAZE_CHANCE`/`MIN`/`MAX` dead), `_calmPhased` is declared with the rest of the
block, `boar_model.spec`'s dead `AWAITING_AN_ID` is gone, two wrong comments are corrected, and
`playOneShot`'s pitch centre has a case. Four are queued as **117a**.

**The six `clipSeconds` were read back off the live assets this round** (the Reviewer's note that
they were the prep tool's numbers, and that Task 116 found thirteen of those a frame out): 4.1667,
4.1667, 4.1667, 1.0833, 1.0833, 1.5000 -- every one within half a frame of what the manifest
declares.

## Claims

1. **No new Brain state, which is what keeps Task 118 free.** The IDLE branch of `Brain:step`
   alternated "grazing" and "wandering" through one boolean; `Brain:_stepCalm` replaces it and
   returns a speed. Everything else about IDLE -- the heading, the home pull, the probe turn, the
   sounder slot -- is the code it was. *Verify:* `Brain:_stepCalm` and the `if self._state == "IDLE"`
   block; `boar_brain.spec` still passes unchanged.

2. **The repertoire is behind `BOAR_MODEL`, and the draw is pure data.** `CALM.ENABLED` is
   `Flags.isOn("BOAR_MODEL")`; with it off an idle boar's speed is the old wander/graze answer and
   nothing publishes an activity. *Verify:* `boar_calm.spec`, "with the FLAG off, an idle boar is
   exactly the boar it was before task 117" -- 600 steps, no activity ever published and no speed
   above `WANDER_SPEED`.

   **And the draw itself is pure:** `Brain.calmActivity(roll, config)` walks
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

4. **A calm clip is only ever drawn on an animal that is still calm.** `Body.activityClip`'s first
   test is `info.activity == nil or info.crippled or info.collapsed`, and `Body.stepVisual` clears
   the exit when the activity goes nil. *Verify:* `boar_calm.spec`, "DROPS the exit the moment the
   animal stops being calm" (an armed `grazeEnd` plus `activity = nil` answers `run` at
   `SPRINT_SPEED` and `trot` at `TROT_SPEED`), "is beaten by a death, a cripple and a flinch", and
   "stops publishing one on the tick it leaves IDLE".

5. **With no id, a calm boar draws exactly what it drew before.** `Body.hasClip` is the one test, and
   every calm path runs through it. *Verify:* `boar_calm.spec`, "with no id published..." -- driven
   with an id table holding the two gait clips and nothing else, every calm activity falls back to
   `idle` or `walk`.

6. **Which clip does what was MEASURED, not chosen by name** (the measuring script was a one-off in
   the scratchpad and is NOT in `tools/` -- queued as 117a(a)). Over the package's 74 actions, off the
   head and nose bones in Blender: `Idle_5` is the only clip whose nose rises above horizontal
   (-18.9 to +11.5 deg, a **30.4 deg** lift, hooves not moving); `Idle_4` is its opposite (nose to
   -72 deg); `Idle_2/3/6` are 9-15 deg ground-level fidgets; `Eat_loop_1/2` put the nose at
   -70..-40 deg; `Dig_walk_IP` has the head low AND the hooves travelling. *Verify:*
   `tools/boar_prep.py` `DEFAULT_CLIPS`' comment and each `Assets.ROWS` note. The ground speeds and
   lengths there ARE reproducible with `tools/boar_prep.py prep`; the head and nose angles are not,
   and that is 117a(a).

7. **The six ids are published, their lengths were read back, and all six were `Loop = true`.**
   `Body.play` writes `AnimationTrack.Looped` from `MODEL.CLIPS` immediately before every `Play` --
   that is Task 116's code, asserted by `boar_model.spec`'s own loop cases, not by this task's.
   *Verify:* `boar_calm.spec`, "plays the three one-shots ONCE and the three loops for ever", which
   asserts the six `MODEL.CLIPS[...].looped` values the writer reads; `boar_model.spec`, "has a row
   with a real asset id for every one of them", now nineteen with no skip list; and the live
   read-back in the round-2 section above.

8. **No two boars in step, and the mechanism is pure.** `Brain.firstPhase` shortens the FIRST
   activity by up to `CALM.FIRST_PHASE_SECONDS`, never below `FIRST_PHASE_FLOOR`, and never at all
   for a row whose band is a single value -- `smell` is exactly one clip length, so shortening it
   would cut the 30.4 degree lift off. *Verify:* `boar_calm.spec`, "shortens the FIRST activity, and
   never the one that is a clip length" (the function itself, at rolls 0, 0.5 and 1) and "puts two
   boars out of step in the shape the Runtime builds them" (two brains off ONE `Random`, agreeing on
   39 % of 30 s against a bound of 50).

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

## The drawn change this round (rule 5)

**`boar-117b-bolt.png`** -- a boar that was drawing `GRAZE_START` when it was shot, photographed
0.40 s later: at full gallop, all four feet off the ground mid-stride, head up and level, running
away from the gun. The clip log for that same animal, sampled on the client:

```
+0.00 s  GRAZE_START    0.00 studs/s
+0.13 s  Hit_F         34.60 studs/s
+0.27 s  Hit_F         37.92 studs/s
+0.40 s  run           36.99 studs/s     <- the frame above
+1.05 s  run           32.38 studs/s
+1.85 s  trot          27.58 studs/s     <- the wound slowing it
```

`grazeEnd` appears at no sample. Before this round it would have held from the end of the 0.25 s
flinch window through 1.083 s, in place, while the body ran.

**And the calm-to-calm transition still plays, which is what it is for:** the same session caught a
boar going `GRAZE` (0.00 studs/s) -> `grazeEnd` for 1.07 s at 4.00 studs/s -> `walk`. That is 4.3
studs of travel with a head-raising clip; it is the designed hand-over and nobody has judged it, so
it is 117a(d).

## What I could not verify

- **Nobody has heard the sniff.** It reuses a ProSoundEffects id this project has already verified
  ("Bull Breaths 10", 9113630137) at pitch 1.25, because nothing in this toolchain can search the
  audio library. It is one number in `Boar.CONFIG.SOUND.SNIFF`.
- **`grazeChew` (`Eat_loop_2`) is published, declared and wired, and no activity picks it.** `graze`
  names `grazeLoop`. It is one word in `CALM.ACTIVITIES` to use it, or one row to delete; I have left
  it because a second graze loop is what stops the longest activity repeating, and choosing between
  them is a feel decision nobody has made.
- **Karen's answer on two boars being out of step was *"probably"***, not yes. The spec now measures
  39 % agreement over 30 s in the production shape; her own eye has not settled it.
- **A player is not a threat to a boar -- only a driver is.** Standing 11 studs from a grazing boar
  for 85 s did not move it, so the bolt above had to be caused with the gun. A frightened-by-a-driver
  bolt is the same code path (`activity` goes nil when the state leaves IDLE) but was not captured.
- **At 30-60 studs the head-up lift is a 0.4-stud movement** (about 0.4-0.8 degrees subtended). The
  posture and the sniff are what should read at that range, not the travel. Not tested from a post.
- **No spec can load an animation or an audio asset**, which is why `calmActivity`, `activityRow`,
  `activityClip` and `hasClip` are pure functions with their own cases.
