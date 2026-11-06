# Task 333 -- a fresh boar sometimes walks its range pass head down

Task: 333
Round: 1
Base: b1a32a89
Code commit: (filled in below, after the harness)

## PLAN (core quality protocol, step 0)

**(a) REAL LIFE.** A wild boar roots with its nose in the soil at a walking pace -- the package's own
`Dig_walk_IP` clip carries the animal at **1.901 studs/s**, measured off the clip by
`tools/boar_prep.py` (`CLIPS.digWalk`, `src/server/Boar/init.luau`). A boar crossing open ground at a
**trot** does it head up: the trot clip's own ground speed is 10.244 studs/s, 5.4x the rooting walk.
Nothing in life roots while trotting.

**(b) MEASURED NOW** (DEV, Play, range on, Mat1 occupied, pace `trot` = 11.00 studs/s, no shots;
probe `<runs-dir>/333-start.luau`, log `<runs-dir>/333-before.txt`):

| run | passes | samples | moving (>0.5) | non-gait while moving | head-down while moving | passes head-down |
|---|---|---|---|---|---|---|
| first 20 passes | 20 | 159 | 159 | 33 (digWalk 24, idle 4, grazeStart 3, smell 2) | **27** | **6 / 20** |
| the whole run | 49 | 387 | 385 | 76 (digWalk 57, idle 9, grazeStart 8, smell 2) | **65** | **15 / 49** |

Two distinct producers, both read off the raw log:

1. **The whole pass, head down.** 7 of 49 animals played `digWalk` for every sample of their pass at
   **11.00 studs/s**, e.g. `Boar12`: `t=44.48 spd=2.86 clip=digWalk` ... `t=48.05 spd=11.00
   clip=digWalk`, eight consecutive samples. 7/49 = 14.3% = the `root` row's own draw weight
   (2 of 14 in `CONFIG.CALM.ACTIVITIES`), which is Karen's *"sometimes"*.
2. **One sample at the release.** 8 animals showed a single `grazeStart`/`smell` sample at 1-9
   studs/s and then trotted, e.g. `Boar5`: `t=16.40 spd=8.99 clip=grazeStart w=0.58`, then `trot`.

**Cause, by file and function.** `Brain:_step` (`src/server/Boar/Brain.luau`) tests the ORDER first
and leaves `self._state` at `"IDLE"`, so the last line of the function,
`intent.activity = if self._state == "IDLE" and self._calm then self._calm.name else nil`, publishes
the calm activity of an animal that is under an order and being led across the lane. `Body.clipFor`
then takes the `walks` branch -- `digWalk` carries its own ground, so it is allowed at ANY speed --
and draws the rooting clip at 11 studs/s. Producer 2 is the same fact one step earlier: the animal
takes ~0.1 s of Brain steps BEFORE the range's first order (the order is issued on the next 10 Hz
`scan`, not on the release), picks a calm clip at rest, and `MODEL.MIN_CLIP_SECONDS` (0.18 s) holds
it while `ACCEL` takes the body to 11 studs/s.

**(c) TARGET.** 0 samples in which an animal moving faster than 0.5 studs/s plays a **head-down**
clip (`digWalk`, `grazeLoop`, `grazeStart`, `grazeChew`, `grazeEnd`), over 20 passes and over the
whole run. That number and not another because Karen's sentence is about the HEAD: an animal that is
moving is walking, trotting or running, and every one of those clips is head up.

**(d) LEVER.** Two writers, both pasted:

    src/server/Boar/Brain.luau:2665:	intent.activity = if self._state == "IDLE" and self._calm then self._calm.name else nil
    src/server/Range/init.luau:1144:local function release(trial: Trial)
    src/server/Range/init.luau:1236:local function order(trial: Trial, position: Vector3, dt: number)

`intent.activity` is the ONE writer of the fact `Body` turns into a calm clip (`grep` above: the
only assignment in the repository). `release` is the ONE place a range animal is born, and `order`
the ONE place it is steered.

**(e) HOW IT WILL BE MEASURED AFTER.** The same probe, the same place, the same pace, the same two
tallies: `<runs-dir>/333-start.luau` -> `<runs-dir>/333-after.txt`.
