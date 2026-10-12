# Task 167: the beater line spans the front, and running boars steer round trunks

Task: 167
Round: 1
Base: `9a6f210` (main, #150 merged)
Code commit: `79d4495133f5b41a39562b90075cb3abec4a1397`

```
[harness] PASS: 33/33 checks @ e89847a6bd624f2c0fbbb5efbaa3fb026104dffb (clean tree) scope=all
[harness] PASS: 33/33 checks @ e89847a6bd624f2c0fbbb5efbaa3fb026104dffb (clean tree) scope=all
[harness] PASS: 33/33 checks @ 79d4495133f5b41a39562b90075cb3abec4a1397 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 79d4495133f5b41a39562b90075cb3abec4a1397 (clean tree)
```

**THE TWO-PLAYER LINE IS THE DIRECTOR'S, and this request cannot be reviewed without it.**
`src/server/Match/init.luau` is in `TWO_PLAYER_PATHS` (`src/server/Match/`), because
`Match.botSlotsFor` -- the drive's own translation from its geometry to a bot slot -- is where a
lane's start and goal are now decided. `tools/agents.py` therefore refuses this round until the
`[harness2] PASS ... @ e89847a` line is pasted above. Nothing else here touches that list: the boar,
the bots and the world are all one-player paths.

## What changed

Karen, 2026-10-12 ~16:10, playing the Forest Test as a HUNTER with the bots on (`PLAYTEST.md`):
*"and seem like all bots came to me / also when boars running sometimes hit the tree"*. Two defects,
one in the drive's geometry and one in the animal's steering.

## Claims

1. **A beater line spans the hunters' front instead of queueing at one stand, and the drive's own
   console says so in numbers.** `ForestTest.beaterLaneOffset(index)` deals the beaters out
   alternately across the front -- 0, +150, -150, +300, -300 -- and
   `ForestTest.beaterStartPosition(index)` measures the ground and the trunks at the lane's own x.
   **MEASURED, Forest Test, one drive, `DHFlag_DRIVE_BOTS=true`, `DHForestStartRole=hunter`,
   her stand 5 (x 3030):**
   ```
   [lanes] drive 1, start x -> goal x: 1: 3030 -> 3030, at 3030 (arrived) | 2: 3180 -> 3180, at 3180
   (arrived) | 3: 2890 -> 2880, at 2880 (arrived) | 4: 3300 -> 3330, at 3331 (arrived)
   ```
   The four of them ARRIVE 451 studs apart (2880 to 3331). Before this task all four started within
   36 studs of x 3030 and every goal was that one base goal translated sideways -- 72 studs of total
   front, centred on the stand she was standing on.
   *Verify:* `ForestTest.beaterLaneOffset` and `beaterStartPosition` in
   `src/shared/ForestTest/init.luau` and `src/server/ForestTest/init.luau`; the `placement` closure in
   `src/server/ForestTestBoot.server.luau` now passes `index`; `Bots.laneReport` in
   `src/server/Bots/init.luau`. Specs: `bots_lane.spec` ("deals the beaters across the hunters'
   front", "spans 600 studs of front with four bots, not 72"), `forest_stand.spec` ("puts each lane of
   the line on its own x").

2. **Each lane's goal is straight ahead ON THE ROAD, and arriving at it IS crossing the line.**
   `Match.botSlotsFor` takes each lane's goal from `Match.beaterGoalFor(thatLane'sStart, ...)` -- the
   post nearest that lane laterally, `GOAL_PAST_LINE_STUDS` past the line -- which is the SAME post
   `Match.crossedLine` measures that bot against. **This is the half that was a game bug waiting to
   happen:** the old `Lane.goalFor` kept the base goal's z, the road is a sine 30 studs deep and the
   margin is 20, so at any front worth having a lane's goal lands NORTH of the road, the bot stops
   short, `Match.beaterCrossing` never counts it through and the drive can only ever end on the
   timer. At the old +-18 and +-36 the error was already 8 and 15 studs of that 20.
   *Verify:* `Match.botSlotsFor`; `bots_lane.spec` "puts each lane's goal STRAIGHT AHEAD on a curved
   road, so arriving IS crossing" asserts `Match.crossedLine(goal, ...)` is true for every lane on a
   post set whose z wanders +-30. The lane spacing IS `STAND_SPACING`, which is what makes the two
   functions pick the same post (`bots_lane.spec` asserts that equality).

3. **The world is asked for one placement per lane, by index, and index 1 is the people's.** The
   drive asks `place(markers, "Drivers", realBeaters + lane, cfg)` -- exactly the shape it already
   used for a bot hunter's stand -- so with Karen walking as a beater the bots ask for 2, 3, 4, 5 and
   she keeps the push line. That is the property the archived `Lane.offsetFor` existed for (*"lane 0
   is never issued, so the middle stays the PEOPLE's"*), kept, and moved to the only owner that can
   see how wide a front is. The DEV arena needed **no change at all**: `Match.Body.placementFor`
   already spread drivers across the pad by index.
   *Verify:* `bots_lane.spec` "asks the world for ONE PLACEMENT PER LANE" and "asks for the indices
   AFTER the real beaters, so the people keep the middle".

4. **`Bots` still reads no marker, tag or player, and no longer spreads anything it cannot see.**
   `Bots.laneOf` is the identity and says why; `Lane.offsetFor`, `Lane.startFor`, `Lane.goalFor` and
   `Bots.CONFIG.LANE_SPACING_STUDS` are archived with the two reasons in
   `backups/2026-10-12-bots-lane-offsets.md` (rule 7). What is left in `Bots.Lane` is the WALK: aim,
   side-step, arrive.
   *Verify:* `src/server/Bots/Lane.luau` header and `Bots.laneOf`; `bots_lane.spec` "is the identity
   in `Bots.laneOf`"; `grep -rn "offsetFor\|LANE_SPACING" src tests`.

5. **A running animal now steers round a trunk by the SMALLEST turn that has room for its body,
   measured, instead of a fixed 55 degrees from three 9-stud rays.** `Brain.clearTurnDeg` is pure:
   candidate headings smallest first, the animal's own committed side first at each magnitude, both
   sides before it gives up, `nil` when boxed in (the wedge detector keeps that case).
   `Brain.steerAroundTrunk` deflects by that measured angle when it is present and by the old 55
   degrees when it is not -- so the WALK is byte for byte what task 123 measured and Karen accepted.
   *Verify:* `Brain.clearTurnDeg` and `Brain.steerAroundTrunk` in `src/server/Boar/Brain.luau`;
   `boar_move.spec` "avoidance BEFORE the contact" -- the smallest clear turn, the side that actually
   has room, nil when boxed in, the budget, and "deflects by the MEASURED turn and not by the fixed
   55, and fires with the rays all clear" (the 9-stud rays cannot see a trunk 20 studs out, which is
   the reading that used to turn nothing).

6. **The cast is a SWEPT SPHERE at the animal's own half-width, and the reach is a time.**
   `world.sweep` is a new seam on the boar world -- `Workspace:Spherecast` with the same
   `RaycastParams` the existing `probe` uses, so "solid things only" stays one rule -- and the Runtime
   looks `clamp(speed * 0.9 s, 10, 26)` studs ahead. A ray from the centre of a 2 x 5.5-stud body
   cannot answer *"will my body fit through there"*; this is the one cast that can. **The reach alone
   was already tried and measured useless** (task 126: 24 contacts against 24, with the turning UP,
   `WHISKER_SECONDS` left at 0) -- because a longer whisker fires the same 55 degrees far more often.
   The turn is what changed.
   *Verify:* `Boar.defaultWorld`'s `sweep`, `Runtime:_avoidTurnFor` and `Boar.CONFIG.MOVE.AVOID_*` in
   `src/server/Boar/init.luau`; `boar_move.spec` "names the numbers the fan ships with, and the
   relations between them". With no `sweep` seam there is no fan, so the DEV arena and every pure
   spec pay nothing.

7. **A nearer horizon when nothing is clear at the far one, and it is a measurement rather than a
   refinement.** The fan's first shape left **344 of 1,402 evaluations BOXED IN** -- a quarter of
   them -- because a 26-stud clear corridor does not exist in standing wood, and each of those was an
   animal running on into the trunk it had just seen. A second pass at half the reach took that to
   **81 of 1,144**. It is `Lane.clearAim`'s own fallback shape, borrowed from inside this repo.
   *Verify:* `AVOID_NEAR_SCALE` and the second `Brain.clearTurnDeg` call in `Runtime:_avoidTurnFor`.

8. **The casts are capped per animal per second, which was the Director's condition.** At most
   `AVOID_HZ` 8 evaluations a second per animal, each one forward sweep plus up to `AVOID_CASTS` 6 at
   the far horizon and 6 at the near one -- a ceiling of 104 swept casts a second for an animal
   running at a wall of trunks, against the 180 rays a second the three 9-stud whiskers beside it
   already cost at 60 Hz. The answer is HELD between evaluations, which is both the budget and what
   keeps the deflection steady; `WHISKER_HOLD_SECONDS` commits the side on top of it, and
   `Brain:avoidSide` is what the fan tries first.
   **MEASURED:** 9,987 swept casts in 183 s of Play -- 55 a second for the whole wood -- and the
   step's own cost did not move (`[bots] ... step 0.36 ms avg`).
   *Verify:* the `due` test and the two `clearTurnDeg` budgets in `Runtime:_avoidTurnFor`;
   `boar_move.spec`'s budget case and "commits to the side the fan found".

9. **The number it is judged on, from two independent counters, and the direction is right.**
   `MOVE.COUNT_CONTACTS` counts distinct (animal, solid thing) touches while an animal is going at
   `AVOID_FROM_SPEED` (11 studs/s) or more, with the animal-seconds of running beside it, printed as
   `[trees]` once per drive. The second counter is an outside probe (a `Touched` watcher injected into
   a Play session, which knows nothing about the game's own counter). Three ~180 s sessions in the
   Forest Test, same place, same settings, same length:

   | | contacts | seconds of running | per 100 s | boxed in | wedged | stuck |
   |---|---|---|---|---|---|---|
   | fan OFF (`AVOID_ENABLED = false`) | 77 | 1152.3 | **6.7** | -- | 14 | 6 |
   | fan ON, far horizon only | 55 | 1136.3 | **4.8** | 344 / 1402 | not counted | not counted |
   | fan ON, both horizons (shipped) | 41 | 771.9 | **5.3** | 81 / 1144 | **7** | **2** |

   The outside probe on the same three runs: **6.2**, **4.8**, **5.0** per 100 s. So both counters say
   the same thing: about a **fifth fewer** trunk contacts per second of running, and FEWER
   not-moving events (14 wedged / 6 stuck -> 7 / 2), which is the *"no new stuck events"* condition
   met with room.
   *Verify:* `Runtime:_watchContacts`, the `runSeconds` accumulation in `Runtime:step` and the
   `[trees]` line in `src/server/ForestTestBoot.server.luau`. `intent.stuck` / `intent.wedged` carry
   the two detectors' findings out of the Brain so they can be counted at all.

10. **The flight still never stops and still keeps its heading.** The deflection is applied to the
    LATCHED flight line and to nothing else, exactly as task 150 left it, and it ends the moment the
    sweep comes back clear -- so the animal threads the trees and comes out on the line it set off on.
    Nothing in this task touches `_latchFlight`, `_flightActive`, `FLIGHT_MAX_SECONDS` or
    `Line.crossedOut`.
    *Verify:* `git diff 9a6f210..e89847a -- src/server/Boar/Brain.luau` -- the flight branch is
    untouched; the only changes are `clearTurnDeg`, the `clearDeg` branch of `steerAroundTrunk`,
    `avoidSide`, the committed side, and the two intent fields.

## The Play evidence (standing rule A)

A fresh 90 s Play of the Forest Test on this tree, in the place Karen uses:

```
gun in hand @15s=1 @90s=1 | stacks=0 errorLines=0 | waves=5 | worst playing sounds over 10 s: 2 (boars=10)
SMOKE PASS
```

So: the Tool is in the CHARACTER at 15 s and at the end; the whole server + client console has no
"Stack Begin", no "attempt to", no "invalid argument" and no error line; and the features this task
changed really ran -- the 180 s session above printed both `[lanes]` (four lanes, four different
arrivals) and `[trees]` (1,144 avoid turns, 9,987 casts), which is what those two lines exist to say.

## What I could NOT verify, and one thing I did not change

* **There is no seed.** The dispatch asked for before/after *"on the same seed"*;
  `Boar.defaultWorld` builds `Random.new()` with no seed and the Forest Test's wave schedule runs
  against a live player, so the same seed does not exist in this world. What claim 9 reports is three
  runs of the same length in the same place with the same settings, by two independent counters. The
  run-to-run spread between the two fan-ON runs (4.8 and 5.3) is the size of the noise, and it is
  smaller than the gap to 6.7 but not by a wide margin.
* **The metric counts animals the fix cannot reach.** `AVOID_FROM_SPEED` is a trot, and task 127
  deliberately gives an ORDERED animal no whiskers at all (*"the route was computed by
  `PathfindingService` against the same trunks"*) -- so a line follower walking its leader's trail at
  a trot is counted in `[trees]` and is never offered a deflection. Part of what is measured
  therefore cannot move, and the drop understates the effect on the flying animals Karen was
  describing. Splitting the count by `ordered` is a measurement I did not make.
* **Karen's eye has not seen either fix.** Whether a 450-stud line reads as a drive line from a
  stand, and whether a boar now looks like it is threading the trees, are hers.
* **THE RESTING SOUNDERS ARE STILL CLUSTERED ON HER STAND, and the Director asked me to check and
  say.** All six `REST.SPOTS` rows sit at `offsetX` **-110 to +95** of the stand she locked -- a
  205-stud band -- while the beater line now spans 600. So the two outer lanes have nothing in front
  of them and the middle lane does most of the pushing. Spreading them is a FEEL change against her
  own earlier rule (*"also they has to cross close to me also"*), so it is not made here: it is one
  table of six numbers, and it is the Director's and Karen's call.
* **`docs/design/bots.md` section 9.1 is now stale and it is the Architect's to write.** Its
  pseudocode is the three archived functions (`offsetFor`/`startFor`/`goalFor` with
  `LANE_SPACING_STUDS`), and the second of its "three properties" -- the goal offset by the same
  amount as the start -- is exactly the half that cannot work on a sine road at any real width. The
  design's INTENT (*"arrives abreast instead of converging on one point in front of one stand"*) is
  what this task implements. Queued in `TASKS.md` 167a; the Builder does not write designs.
* **One console oddity, pre-existing and not mine:** in all three Play sessions the `[bots]` line
  rendered as `[bots] drive 3 hunters, 4/4 beaters` -- no drive number and no hunter pair -- and
  **zero bot hunters were built** while the four beaters were. The same line reads the same way with
  this task's code reverted (`AVOID_ENABLED = false` run), nothing in this task touches the hunter
  branch of `Match.botSlotsFor`, and `0 failed, 0 stale` says no build was attempted and failed.
  Reported rather than chased (rule 6/8).
