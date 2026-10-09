# Task 139 - Karen's boar complaints

Task: 139
Round: 3
Base: main (`0c7f736`)
Code commit: `ae3f5500b527b33d5a8af6b691606e613d8b00c5`

```
[harness] PASS: 33/33 checks @ ae3f5500b527b33d5a8af6b691606e613d8b00c5 (clean tree) scope=all
```

`test2` is N/A: no path in `TWO_PLAYER_PATHS` is touched.

## The three blocking findings, and all three were right

### 1. The run-away was unreachable, and it is now per animal

`Line.stillInFile` drops a member on `dz < 0` and `line.crossed` tested the SAME inequality on the
leader, one screen later in the same step. The filter runs first, so `line.crossed` could never
become true: Karen's *"and they run away when cross the road"* had no code left, and a calm line was
dropped at its walking pace twenty studs past the road.

The rule moves onto the member being dropped. `Line.crossedOut(gone, flying, hurt, dz)` -- pure,
pinned, the companion to `stillInFile` -- says this animal is leaving BECAUSE it crossed and not for
one of the other three reasons, and `ForestTest.stepLines` then spooks it ONCE from
`LINE.runAwayFromStuds` (40) behind. A fright goes through one door, so the Brain owns everything
after it: the heading (south, `field.exitZ`), the pace, the herd-mates its alarm reaches, and the
despawn at the exit line. The dead line-level block and the `crossed` field are archived in
`backups/2026-10-09-line-crossed-speedup.md`.

**MEASURED, two 150 s runs: 38 animals crossed and 27 ran away (top speed >= 14 in the six seconds
after), 20 crossed and 17 ran.** The nine and three that did not are the hurt ones -- a cripple
crawls at `CRIPPLE_SPEED` and `crossedOut` deliberately does not shove it -- their top speeds being
1.9 to 6.9 against the twenty-two animals sitting at exactly `RUN_SPEED` 24.

### 2. One speed, and both senses read it

`Body.stepVisual` got the measured velocity in round 3 and `Body.stepSound` was left on the
setpoint, which breaks the rule `SOUND.CROWD`'s own header states: "the footstep loop is rated by
`speed / baseSpeed`, which is the same arithmetic that rates the animation". A wedged animal drew
`idle` with its feet still while its hooves ran at `24 / 17.21`, now carrying 70 studs.

`Runtime:step` computes `realSpeed` once and hands it to both. The comment that said the opposite is
gone; `entry.lastWant` is untouched, so `statusOf().want` still publishes what the animal was ASKED
for and the stuck detector still reads it.

### 3. A close pack sounds twice, structurally

`ESCALATE.md` said in round 1 that the range and Karen's *"max 2"* could not both be satisfied by
range alone and that the cap had to become structural. `formSounder` was the prerequisite, not the
cap: the three world ceilings are independent budgets, so one herd could hold the step voice, its
holder's breath and both mutters -- three, measured, after the range went back out.

`Boar.packVoices(rows, cap)` is the cap. Pure, nearest-first, hooves first, then the breath, then
the muttering; `SOUND.CROWD.SOUNDS_PER_SOUNDER = 2`; `_rationVoices` applies it third, after the
sounder gate and the world ceilings, so a pack slot is never awarded to an animal the world has
already silenced.

**MEASURED over four 150 s runs: the worst number of LOOPS sounding in one pack is 1, and in the
world 1.** Counting one-shots as well, the worst in a pack is 2 to 5, and the composition at the
worst moment of the last run was `death, death, grunt, steps_walk` -- two animals dying from the ten
shots I fired, which is an event Karen caused and not the ambient bed her sentence is about. The
one-shots are exempt by design (task 120: a hit animal must be able to cry out over its own herd)
and the config says so.

## The table

Four 150 s Forest Test runs of the shipped build, hunter at a stand, ten shots through the real
`FireRequest` route, reload after two.

| | main | round 2 build | **round 3 build (4 runs)** |
|---|---|---|---|
| slide, median gap | 56.2 | 0.0 | **0.0 / 0.0 / 0.0 / 0.0** (p90 1.2-1.8) |
| moving with NO locomotion clip | 22-27 % | 2.5 % | **1.7 / 2.0 / 2.1 / 3.0 %** |
| ran NORTH after a shot | 6.0 | 0 | **0 / 0 / 0 / 0** |
| stood after a shot | 0.7 | 1 | **0 / 0 / 0 / 2** |
| came back north over the road | 0 | 1 | **0 / 0 / 1 / 3** |
| crossed, and ran away | -- | -- | **27 of 38, 17 of 20** |
| worst LOOPS, one pack / world | -- | -- | **1 / 1** |
| worst sounds incl. one-shots, one pack | 2 | 3 | **2 / 2 / 4 / 5** |
| running in place | -- | 41 | **28 / 33 / 40 / 86** |

## The rest

4. **The swerve keeps its own geometry.** The Reviewer's note was right that `sideways.Unit` changed
   EVERY flight to 45 degrees off the exit line. It is normalised only in the degenerate fallback
   now, so a flush from nearly due north runs nearly straight down the exit line again and only a
   shooter square on it gets the full break. `boar_move.spec`'s round-3 case still passes.
5. **`clipScale` has one route** (`info.clipScale or handle.geometry...`), and five paragraphs that
   said something untrue are corrected: "40 -> 80" against a shipped 70, the MEASURED paragraph
   written out twice in `clipFor`, `formSounder`'s "the ORDER is the file's order" and "a group of
   one is still a group" (both now state what actually happens, with the Reviewer's reasoning), and
   `stepLines`' prose about an animal rejoining the file. `ESCALATE.md`'s opening says which round it
   describes.
6. **The suite caught my own bug.** `looseSound()` -- the "no ration at all" half of the crowd A/B --
   clones `CROWD` and lifts every ceiling to `math.huge`; the new key arrived at its shipped 2 and
   rationed the loose herd too, so six fleeing boars breathed "2 against 2" and two preconditions
   failed. Lifted, the same note reads **2 rationed against 12 loose**.

## What could not be verified, and one correction

- **MY FIRST ROUND-4 MEASUREMENT WAS WRONG AND I CAUGHT IT BY NOT BELIEVING IT.** The trace
  instrument multiplied the clip's ground speed by `entry.body.clipScale`, which does not exist --
  the field is `entry.body.geometry.clipScale` -- so it read the slide as 128.5 % on a build that
  measures 0.0. Fixed in the instrument (not in `src/`), and every number above is from the fixed
  one. The instrument is temporary and is not in this commit.
- **"Running in place" is 28 to 86 and is NOT Karen's case.** It is `MODEL.MIN_RATE`, the 0.4 floor
  that stops a clip reading as slow motion: an animal below about 1.1 studs/s has its walk floored
  there and shuffles. Her case -- a wedged animal at a full gallop -- is gone with the `realSpeed`
  fix. Whether to trade the floor for a hard stop is a feel question I am not deciding here.
- **One animal came back north in two of the four runs (1 and 3).** Not zero. The flight is latched
  south and `line.gone` is permanent, so what is left is the Brain's own wander after a flight ends.
- **My per-shot reaction count is still broken** (it keys on `(id, distance)`), so item 8 of the last
  round still has no number. What is evidenced is the config change and the two specs that read
  `SENSE.SHOT_AUDIBLE_STUDS` instead of typing it.
- **Standing rule A, Forest Test, 85 s, after the gate:** the Tool in the CHARACTER at 15 s and at
  the end (`tool=true backpack=false` both), **0 fault lines in 24**, four waves released and all
  four at a trot -- item 9 of the last round still running.
- **Studio:** DEV was opened from the Forest Test window, Connected (the sync dialog listed edits
  only), gated, then closed with **Save**, and the empty window closed. Karen has one Studio, the
  Forest Test, in Edit and connected.
