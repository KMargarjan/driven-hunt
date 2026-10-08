# Task 126 - a driven sounder moves like the real thing

Task: 126
Round: 3
Base: main
Code commit: `cced90502fddfbeda8efd3ba74e27779834fe879`

DIRECTOR NOTE (re-review at cced905): the stack's round-3 fix changed this task's owned code (`src/server/ForestTest/init.luau` and/or `src/client/Hud/init.luau`); round 2 PASSed before it, so this re-reviews the same claims at the final code commit cced905.

```
[harness] PASS: 33/33 checks @ cced90502fddfbeda8efd3ba74e27779834fe879 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ cced90502fddfbeda8efd3ba74e27779834fe879 (clean tree)
```

The `[harness2]` line is the Director's: it needs one Studio open, and this round's live proof
needed the Forest Test open beside DEV.

**THIS TASK IS ONE OF NINE IN ONE PR** (122-130, `task-130-spawn-view` -> `main`). Director
decision, recorded in `ESCALATE.md`: no branch below 128 can pass the gate on its own -- DEV's
map could only be rebuilt once 128's bundler existed, and 129 fixed the specs 123-127 broke --
so the evidence for every task in the stack is the gate AT THE HEAD, and every task still gets
its own review.

## What changed

Karen, watching the Forest Test: *"after shoot animals usually run straight when they spook ofc
avoiding opsticals"*, *"they shouldn do circles like I see now"*, *"and not hitting the trees and
hang"*, *"and walking sound sounds like horse we need animal not horse"*.

## What round 1 found, and what round 2 did

**ROUND 2.** #1 a FRIGHT NOW OUTRANKS AN ORDER (`Brain:step` drops the order when `_flightActive()` or a check is running), the drive leaves a flying animal alone (`Runtime:flying`, `leadIfFree`), and the leader is offered the edge check as she comes within `LINE.checkWithinStuds` of the road -- all three were unreachable in the only world that turns `MOVE` on, so the straight flight and the edge stop shipped dormant. #2 the flight is latched from `self._at`, the position the Brain updates every step, not from `_stuckFrom`, which at 24 studs/s is up to 48 studs stale. #3 `tests/server/boar_move.spec.luau` is new: the flight in both flag states, the edge stop in both, and the whisker's `locked` branch. #4 `Body.warmAssets`' comment now says what the code does -- the CLIPS are warmed on the server, the SOUNDS are not warmed on any client, because `PreloadAsync` is a client call; the client-side preload is queued rather than implied.

## Claims

1. **Research first.** `docs/research/2026-10-05-sounder-movement.md` with sources, licences and the
   numeric targets, and its row in `docs/research/INDEX.md`.
2. **Straight flight is a latch, not a steering rule.** `Brain:_latchFlight` / `Brain:_flightActive`
   hold a fleeing animal's heading for a measured window so a shot sends it away in a line rather
   than into a curve. Verify: `src/server/Boar/Brain.luau`.
3. **An animal can stop before the road.** `Runtime:check` / `Brain:check` are the edge stop Karen
   asked for (*"they can stop before entering the road"*), through the same door `urge` and `spook`
   use. Verify: both files.
4. **Everything in `Boar.CONFIG.MOVE` is born OFF** and is turned on by the world that wants it, in
   `ForestTestBoot`, as a full clone with one value flipped -- so the DEV drive Karen signed off is
   unchanged. Verify: `src/server/Boar/init.luau` and `src/server/ForestTestBoot.server.luau`.
5. **`MOVE.FILE` ships off**, by the Director's instruction after the measurements: the file-keeping
   term did not improve the picture and task 127 replaced the idea with a trail.
6. **The footsteps are an animal, not a horse.** Every gait's row points at an engine CC0 file and
   carries its own `pitch`; the row keeps `was = <the old bought id>` so the swap is one line.
   Verify: `SOUND.STEPS` in `src/server/Boar/init.luau`.
7. **The pitch does NOT touch the stride.** Task 129 found this task had multiplied `pitch` into the
   playback rate -- which is the cadence -- so the feet slid; the timbre is now a
   `PitchShiftSoundEffect` built with the loop. Verify: `Body.stepSoundFor` and `makeSound` in
   `src/server/Boar/Body.luau`.
8. **The pre-roll fetches instead of playing.** `Body.warmAssets` calls `ContentProvider:PreloadAsync`
   in a spawned thread; the worst count of playing sounds in a fresh wave went from 88 to 2.
9. **Four of my own changes made the measured metric WORSE and were reverted with the numbers kept in
   the comments** -- the turn budget (4,660 -> 7,728 turning windows), the speed-scaled whisker, the
   home destination and the centroid replacement.

## What could not be verified

- **"They run away until I can't see them"** is partly met: flight is straight and long, but an
  animal that leaves the field is despawned at the exit line, so "out of sight" is the field's edge
  rather than a horizon.
- **The trees.** Trunk contacts were reduced but not closed in this task; see task 127's request for
  the final number and the split.
