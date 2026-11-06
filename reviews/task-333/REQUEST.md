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

---

## What changed (round 1)

**Code commit: `781221c63b1e3192e8f074f406f5a3ad4911690b`**

    [harness] PASS: 34/34 checks @ 781221c63b1e3192e8f074f406f5a3ad4911690b (clean tree) scope=all

`test2` is N/A: nothing here is in `TWO_PLAYER_PATHS` (the change is `src/server/Boar/Brain.luau`,
`src/server/Range/init.luau` and two server specs -- boar and range, which one player evidences
completely).

Two lines of behaviour, one defect:

1. **`Brain` publishes no activity while the animal is under an order.** The order branch already
   outranks every mood, but it leaves `_state` at `"IDLE"`, so the last line of `_step` kept
   publishing the calm activity of an animal that was being led.
2. **`Range.release` issues the pass's first order on the tick it spawns the animal** (forward
   declaration of `order`), so no range animal ever takes a Brain step as a free boar.

## Claims

1. **It is reproduced, on the player's path, as a number.** 49 range passes in DEV Play, Mat1
   occupied, pace `trot` (11.00 studs/s), no shots: 65 samples in which an animal moving faster than
   0.5 studs/s played a head-down clip; 7 animals played `digWalk` for their WHOLE pass at 11.00
   studs/s. *Verify:* `<runs-dir>/333-before.txt`, and the table in the PLAN above.
2. **The after is the same instrument.** Same probe (`<runs-dir>/333-start.luau`), same place, same
   pace, 53 passes: **head-down while moving 65 -> 0**, and 0 over the first 20 passes as well.
   *Verify:* `<runs-dir>/333-after.txt`.
3. **The producer is named and pasted.** `intent.activity` in `Brain._step` is the only assignment
   of that field in the repository, and `Body.activityClip` / `Body.clipFor` is the only reader.
   *Verify:* `grep -rn "intent.activity" src/`.
4. **The case dies if the Brain fix is deleted.** `boar_calm.spec.luau`, *"publishes NO activity
   while it is under an order..."*: twelve seeds, each stepped until it really is doing something,
   then led the way `Range.order` leads one -- `activity` and `activityDraw` must be nil on every
   tick while the animal is moving, and the drawn clip `trot`. Revert the one `Brain` line and the
   first `expect(intent.activity).to.equal(nil)` fails.
5. **...and it is not a deletion.** The same case stops issuing the order and asserts all twelve
   boars take an activity up again inside `LINE.ORDER_SECONDS + 0.5 s`. A fix that simply stopped
   publishing activities would fail this half.
6. **...and it states the chain.** The same case asserts `clipFor({activity = "root", speed = 11})`
   is `digWalk` and `clipFor({activity = nil, speed = 11})` is `trot` -- the picture Karen sent, and
   what replaces it.
7. **The case dies if the Range fix is deleted.** `range.spec.luau`, *"orders the new animal on the
   very tick it releases it"*: 30 s at a trot, and every release must already have a `fake.leads`
   entry for its own id on the tick `targetId` changed. Remove `order(trial, from, 0)` from
   `release` and `orderedAtBirth` falls short of `releases`.
8. **331 is intact.** `UNSTEERED_PASS_SECONDS` is untouched; `order` still reads `boars.leadTo`'s
   answer and still adds to `trial.unsteeredFor` when it is refused -- the release-tick call goes
   through the same function, so a CRIPPLED animal's refusal is counted there too. *Verify:*
   `range.spec.luau`, *"ends the pass of an animal it can no longer steer"*, which passes.
9. **319 and 321's timing is intact.** No clock, no `NEXT_PASS_SECONDS`, no `PASS_MAX_SECONDS` and
   no `trial.ended` changed. *Verify:* the whole `range.spec` suite is green (81 server spec files,
   2847 assertions, 0 failed).
10. **Frames, opened and described.** `<runs-dir>/333-frames/333-before-zoom.png` and
    `333-F1-zoom.png`, the same camera (the shooter on Mat1), the same 124 studs, the same 70x40
    crop at 10x. BEFORE: the boar's snout is DOWN at knee height, nose in the grass, the back
    sloping up to the rump. AFTER (`333-F1`, `Boar67`, `clip=trot w=1.00 spd=11.00` read off the
    animal at that moment): the snout is level with the shoulder, the back line horizontal, legs in
    a trot stride.

## What I could not verify

- **Karen's own Forest Test.** Every number and both frames are from **DEV**. Her place syncs from
  `driven-hunt-karen`, which I may not check code out in (L-014), so the AFTER in HER world is
  unproven until the merge.
- **The dispatch's literal "0 non-gait samples" is not reached, and this is measured, not waived.**
  After the fix 24 of 409 samples are `idle` while moving (up to 11.00 studs/s) -- exactly one per
  pass, always that pass's FIRST sample. That is `MODEL.MIN_CLIP_SECONDS` (0.18 s) holding the
  standing spawn's clip while `ACCEL` takes the body to pace; `idle` is HEAD UP, it is in every
  world since task 139, and the dwell is what stops the crossfade shake. Queued in `TASKS.md` under
  this task rather than changed here.
