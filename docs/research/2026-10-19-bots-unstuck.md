# The bot beaters do not get stuck: seeing the way, and recovering from a pin

Task 208. Rule 1 note. Sections 1-3 and 5-7 were written before any code; **section 4 is the
measurement that had to come first**, because this is a new behaviour with no history in this repo
and the dispatch asked for the measurement as step 1.

## 1. What the system must do

Karen, 2026-10-18 ~14:20, verbatim: *"bot beater stuck we definatly need to fix that they not stuck
the can avoid"*. And, in the same message: *"when I am beater forest is broken, do not try to fix
forest, we will go together ... we will fix terrai together"* -- so **the trees, the terrain and the
four places are not touched by this task**. The bots have to cope with the wood as it is.

1. **A bot beater walks its lane through the wood and gets to the road.** The lane is the feature
   (note 2026-10-12 section 3): it is what makes four beaters a LINE rather than four shortest
   paths.
2. **It routes round what is in the way** -- a trunk, a fallen log, a bush, a boulder, another bot --
   rather than walking into it and leaning on it.
3. **If it is pinned anyway it recovers inside ~3 seconds**: back off, sidestep, jump a low step, or
   aim again -- and the choice between those is a MEASUREMENT of what is in front of it, not a
   guess.
4. **It does not leave its lane for long.** A detour is a deflection that returns; the line still
   arrives abreast.
5. **It is cheap enough for 8+ bots**, measured and printed, because the vendor's own performance
   page has no numbers in it (note 2026-10-12 section 2.2).
6. **Nothing about the trees, the terrain, the places or the drive's geometry changes.** The
   measurement, the fix and the proof are all inside `src/server/Bots/` and the one reader the
   forest hands it.

## 2. The sources

### 2.1 ioquake3, `code/botlib/be_ai_move.c` -- `BotCheckBlocked`, the avoid-reach list and the barrier jump

<https://github.com/ioquake/ioq3/blob/main/code/botlib/be_ai_move.c> -- **GPL-2.0**, actively
maintained (`ioquake/ioq3`, commits through 2026). **This repository is already borrowed from three
times in this project** (tasks 159, 160 and 161 all quote it), so it is prior art we have read
before. Read 2026-10-19.

What it holds, and all three parts of it are what this task needs:

* `void BotCheckBlocked(bot_movestate_t *ms, vec3_t dir, int checkbottom, bot_moveresult_t *result)`
  -- a **trace in the direction of travel** that sets `result->blocked`. Not a test of the
  destination: a test of the way there.
* the **avoid-reach list**: `#define AVOIDREACH_TIME 6` ("avoid links for 6 seconds after use"),
  `#define AVOIDREACH_TRIES 4`, and `BotAddToAvoidReach(ms, number, avoidtime)`, which increments
  `ms->avoidreachtries[i]` and stamps `ms->avoidreachtimes[i] = AAS_Time() + avoidtime`. So a route
  element the bot got stuck on is **remembered for a TIME and counted in TRIES** -- the decision is
  held, not re-made every frame.
* `BotCheckBarrierJump` -- a **jump** is what a low obstruction gets, not a detour.

**What it does well.** It is the branches of a recovery routine, already separated by somebody else:
see the way ahead, hold the decision for a time, count the tries, and jump a low thing instead of
walking round it. The TIME and the TRIES are the two numbers this task was missing.

**What it does badly, for us.** It is built on an AAS navmesh with reachability links, which this
project has none of and (note 2026-10-12 section 3) refuses on purpose. `BotCheckBlocked`'s traces
are box traces in Quake units against a BSP; the Roblox equivalent is `Blockcast`, which this repo
already uses for the same job (2.5).

**Adopted:** the branches, the held decision and the try counter. **Not adopted:** the navmesh, the
reachability links and the prediction (`AAS_PredictClientMovement`).

### 2.2 Craig W. Reynolds, "Steering Behaviors For Autonomous Characters" (GDC 1999, SIGGRAPH 97)

<http://www.red3d.com/cwr/steer/gdc99/> -- a paper, freely published, the canonical source. **This
project already borrows from it for the boar** (`docs/research/2026-10-05-sounder-movement.md` and
`Brain.steerAroundTrunk`). Read 2026-10-19.

Its obstacle avoidance, verbatim: the character maintains *"an imaginary cylinder of free space in
front of the character. The cylinder lies along the character's forward axis, has a diameter equal to
the character's bounding sphere, and extends from the character's center for a distance based on the
character's speed and agility."* It *"takes action only when a nearby obstacle lies directly in front
of the character"*, and returns either the steering to avoid the most threatening obstacle *"or (b)
if no collision is imminent, a special value (a null value, or the zero vector) to indicate that no
corrective steering is required at this moment."*

**What it does well.** It is the exact shape of the forward test this task adds, and it states the
property that makes a LINE survive obstacle avoidance: steer only when something is actually in
front, and only as much as the intrusion needs. A lane with a small deflection round a trunk is
still a lane; a shortest path is not.

**What it does badly, for us.** It is a force-based model over a velocity the author owns. A Roblox
`Humanoid` is steered by a POINT (`MoveTo`) and the engine owns the velocity, so the steering force
has to be expressed as a deflected aim point. That translation is already made once in this repo
(`Brain.clearTurnDeg`, 2.5), which is what is re-pointed rather than re-derived.

### 2.3 Roblox, `Humanoid:MoveTo` / `MoveDirection` / `ChangeState` and `WorldRoot:Blockcast`

<https://create.roblox.com/docs/reference/engine/classes/Humanoid> and
<https://create.roblox.com/docs/reference/engine/classes/WorldRoot> -- vendor docs, **CC BY 4.0**
([Roblox/creator-docs](https://github.com/Roblox/creator-docs)), actively maintained. Read
2026-10-19.

Four facts this task rests on:

* **`MoveTo` is a point and it times out.** The vendor's own sample is titled "Humanoid MoveTo
  Without Time out" and refreshes the timeout by calling `MoveTo` again; the 8-second window is the
  documented reason the walk re-issues at all (`MOVE_REISSUE_SECONDS` 2, task 161).
* **`MoveDirection` is the engine saying "this humanoid is trying to walk"**, and the vendor's own
  "Walking Camera Bobble Effect" sample tests exactly `humanoid.MoveDirection.Magnitude > 0` for it.
  That is the definition of EN ROUTE this task's measurement uses, read on the SERVER, where a
  server-owned rig's value is the authority (the property is marked Not Replicated, which is about
  the client's copy of a player's character).
* **`Blockcast(cframe, size, direction, params)`** *"casts a block-shaped volume in a specified
  direction"* -- a swept box, which is what a body walking down a lane is.
* **`ChangeState(Enum.HumanoidStateType.Jumping)`** is how a jump is asked for in code; the vendor's
  Double Jump sample is the usage. `JumpHeight` is what it is worth.

**What it does well.** `Blockcast` is the one cast that can answer "will my body fit between here and
there"; `MoveDirection` makes "it is trying and not moving" measurable with no second bookkeeping
system; and the `MoveTo` timeout is a documented number rather than an opinion.

**What it does badly, for us.** `MoveTo` has no concept of a route, a detour or a failure: the only
feedback is `MoveToFinished(reached)` after up to 8 seconds, which is far too late for a walk Karen
is watching. Everything between "the aim point" and "it got there" is ours to write -- which is this
task. The docs also never state the 8 seconds in prose, only in a sample's comment.

### 2.4 SimplePath, `ahmicy/simplepath` -- and why `PathfindingService` is STILL not adopted

<https://github.com/ahmicy/simplepath> -- **MIT**, 70 stars, created 2021-04-29, **last pushed
2026-06-12**, not archived (re-checked 2026-10-19 through the GitHub API). The community's standard
wrapper round the vendor's pathfinding loop, and the named escape hatch in task 161's note: *"It
stays the named escape hatch if the straight walk is ever measured getting stuck"* (TASKS.md 161a).

**That escape hatch is now open by a measurement** (section 4), so it is answered here rather than
deferred again. It is NOT taken, for three reasons, and the first has not changed:

1. **The line is the feature.** Karen, 2026-10-11: *"beater are behind animals and moving towards
   hunter line (road) like in real life"*. A shortest path is per agent, so eight shortest paths are
   eight different detours and the line is gone. The dispatch says the same thing: *"never leave the
   beater line's order for long"*.
2. **What was measured is not a routing failure.** Section 4 says what it is: the recovery the bots
   already have is thrown away before it reaches the humanoid. A pathfinder answers "which way
   round"; it cannot answer "the decision was discarded 0.2 s later".
3. **The cost is still undocumented.** Neither vendor page states a limit, a yield cost or a throttle
   for `ComputeAsync`; SimplePath's own `TIME_VARIANCE = 0.07` exists because the community found it
   needed one. A swept `Blockcast` is a measured fraction of a millisecond (section 7), and this task
   has to hold 8 bots.

**Adopted:** its two structural lessons -- the expensive operation gets a **declared minimum
interval**, and the decision is **held between evaluations**. **Not adopted:** the module, the
per-agent `ComputeAsync`, and the one-object-with-its-own-clock-per-agent shape.

### 2.5 In-repo prior art (rule 2 points here FIRST, and it is most of the pattern)

Three things in this repo already solve pieces of this, measured in this very wood, and every one is
re-pointed rather than re-invented:

* **`Boar.CONFIG.MOVE`'s wedge detector and its HELD sidestep** (`Brain:_updateWedge`, task 150).
  Karen then: *"still can see sometimes boar hit tree and wal in place so not avoiding tree"* -- the
  same complaint as *"bot beater stuck"*, about the other species. Its header states the reason the
  hold exists: *"the next frame's steering blend starts pulling it back toward the trunk at once, and
  `WHISKER_HOLD_SECONDS` (0.6) is how long the whiskers found an animal needs to actually get past
  the thing it committed to going round."* It counts tries and **alternates the side** on each one
  (`_wedgeCount % 2`), which is ioquake3's `avoidreachtries` in this repo's own hand. Its fast test
  is *told to move faster than `WEDGE_ORDERED_SPEED` (2), actually covering less than `WEDGE_SPEED`
  (0.5 studs/s), for `WEDGE_SECONDS` (0.75)*.
* **`ForestTest.clearRoute`'s swept `Blockcast`** (task 127), with its own stated reason: *"a raycast
  down the centreline would miss a trunk its shoulder hits"*, and the finding that drove it -- the
  navmesh *"guarantees the WAYPOINTS are reachable for an agent of the given radius, not that the
  straight line between two of them is clear"*. The forward test, already written, already reviewed,
  against these trees.
* **`Brain.clearTurnDeg`** (task 167): the smallest deflection that has room, out of a fan of
  candidate angles, nearest-side first, with a cast budget -- Reynolds' "only as much as the
  intrusion needs", already translated into a point-steered world.

## 3. The pattern adopted, and why

**STEERING WITH A SWEPT FORWARD TEST, PLUS A HELD RECOVERY -- not `PathfindingService`.** The
decision of task 161 stands, and section 2.4 answers the escape hatch that the measurement opens.
Three reasons in order: the line is the feature; what was measured is not a routing failure; the
cost of `ComputeAsync` is still undocumented while a swept cast is measured (section 7).

What changes is the three things the measurement names (section 4), and every one of them is a
borrow:

1. **The test looks down the LANE, not at the destination.** `ForestTest.laneAhead` sweeps a
   body-sized box from the bot to its aim point (`Blockcast`) and answers how far ahead the first
   solid thing is and how high its top stands above the bot's feet. That is
   `ForestTest.clearRoute`'s own cast (2.5) and Reynolds' cylinder of free space (2.2). Today's
   `roomToStand(aim, 6)` is a point test AT the aim point: it cannot see a trunk between the bot and
   that point, which is exactly where the thing that stops a bot is.
2. **A decision is HELD and it reaches the humanoid at once.** `MoveTo` is re-issued when the aim
   MOVES, not only every `MOVE_REISSUE_SECONDS`; and a recovery is committed for a hold. That is
   the boar's `WEDGE_HOLD_SECONDS` with its own stated reason (2.5), SimplePath's `TIME_VARIANCE`
   (2.4) and ioquake3's `AVOIDREACH_TIME` (2.1) -- three sources, one idea.
3. **The recovery is a ladder with a try counter**, ioquake3's `avoidreachtries` (2.1) and the
   boar's `_wedgeCount % 2` alternation (2.5): sidestep, the other side, wider, back off -- and a
   JUMP where the obstruction is low, which is `BotCheckBarrierJump`.

**ONE OWNER.** `Bots` stays the owner of a bot's movement and of its clock (design `bots.md` 3.1);
`Bots.Lane` stays pure; the world's `laneAhead` is injected exactly as `groundAt` and `roomToStand`
already are, and the DEV arena passes none -- so the arena behaves as it does today, bit for bit.
`ForestTest` stays the one place that knows how to measure this wood.

## 4. The measurement, BEFORE anything was changed

The dispatch's step 1, and the Learning Agent's L-022: an actual position trace, read as numbers.

**How.** Karen's own **Driven Hunt Forest Test** (placeId 130094961655666), one full drive in each of
the four places, entered **the way she enters it** -- the player stands on truck pad 1 and the
lobby's own 8 s pick + 5 s leave enrols him (task 182), so nothing about the drive is faked. Every
rig under `Workspace.DriveBots` was sampled at **2 Hz** through the whole drive: position, humanoid
state and `WalkSpeed`. `DHForestLayout` forced the place; **its prior value (absent) was written to
`<runs-dir>/208-attrs-before.txt` BEFORE the first write** and restored from that file afterwards
(L-056). Karen's other attributes were not touched.

Traces: `<runs-dir>/208-before-{road,edge,ride,track}-trace.json`, consoles beside them.

### 4.1 Two things the instrument had to learn first, because both would have been lies

* **`Humanoid.MoveDirection` is 0.000 on the server for a bot walking under `MoveTo`.** The first
  definition of EN ROUTE used it -- the vendor's own "Walking Camera Bobble" sample tests exactly
  `MoveDirection.Magnitude > 0` -- and every bot read as never walking. Measured: a rig covering
  2.4 studs every 0.5 s, state `Running`, `WalkSpeed` 5, `MoveDirection.Magnitude` **0.000** on every
  one of 334 samples. The property is documented Not Replicated and is evidently not filled in for a
  server-driven humanoid. So "it is trying to walk" is read off the POSITION it makes -- which is the
  decision `Boar.CONFIG.MOVE`'s wedge detector already made, for its own stated reason.
* **A permanent pin at the end of a walk looks exactly like an arrival.** The first pass trimmed the
  trailing stationary samples as "it got there" and read the track layout's **169-second** pin as a
  76-second walk. The tail is now only trimmed when the body is within 10 studs of its lane's own
  goal, and the report prints **how far from its goal each bot ended** so the question cannot be
  hidden again.

### 4.2 What it found, per place

| place | drive | beaters | episodes over 3 s | worst | total stuck | reached its goal |
|---|---|---|---|---|---|---|
| **road** | 1 | 4 | **0** | -- | 0.0 s | 4 of 4 (0.9-10.4 studs out) |
| **edge** | 1 | 4 | **2** | **34.0 s** | 40.0 s | 3 of 4 |
| **ride** | 1 | 4 | **1** | **15.5 s** | 15.5 s | 3 of 4 |
| **track** | 1 | 4 | **1** | **169.1 s** | 169.1 s | 3 of 4 |

STUCK is the dispatch's own definition, applied to the trace: **moved less than 2 studs over 4
seconds while en route**. The four episodes, with where:

| place | bot | from -> to | seconds | x, z | what it was on |
|---|---|---|---|---|---|
| track | `bot-beater-1` | 127.1 -> 296.2 s | **169.1** | 4773.9, -3679.7 | **a planted spruce trunk**, 3.8 studs ahead |
| edge | `bot-beater-3` | 176.1 -> 210.1 s | **34.0** | 3270.3, -3247.6 | **`bot-hunter-1`**, anchored on the stand at 3270.0, -3250.0 |
| ride | `bot-beater-3` | 60.9 -> 76.4 s | **15.5** | 4753.5, -4004.0 | the planted wood (same class as the track's) |
| edge | `bot-beater-2` | 174.1 -> 180.1 s | **6.0** | 3529.7, -3247.2 | **`bot-hunter-2`**, anchored on the stand at 3530.0, -3250.0 |

**The 169-second pin hung the whole drive.** A drive ends when the line is through
(`Match.beaterCrossing`), so that bot never arriving meant no `[bots]` report in 300 seconds: the
drive ran out the clock instead. That is the shape of Karen's complaint from the other side.

### 4.3 WHAT they were stuck on, measured and not guessed

**Not the terrain, and not a slope.** The ground under all four points reads 3.2 studs below the
root (a character standing normally), and the profile 20 studs down the lane from the worst one
climbs **131.7 -> 132.7** -- one stud in twenty. Materials: Grass, Limestone, Asphalt. No water, no
step, no cliff.

**Not a static part either, and that took two probes to say honestly.** An Edit-mode enumeration of
all **11,830** BaseParts in Workspace found **nothing within 10 studs** of any of the four points --
which is true and nearly useless, because three of the four places are **planted at runtime** into
`Workspace.DrivePlaces` and do not exist in Edit at all. So the probe was re-run **live, during the
drive, by enumeration rather than by a spatial query** -- and at the 169-second pin, reproduced in a
second run:

```
bot-beater-1 at 4774.3,135.0,-3680.1
terrain south 0:131.7 2:131.7 4:131.8 ... 20:132.7
Blockcast south 12 studs HITS Workspace.DrivePlaces.track.Old_Spruce_Tree_Var02_LOD_0.Trunk
  (MeshPart) at 4772.3,136.5,-3683.9
```

A **spruce trunk 3.8 studs in front of it**, for 169 seconds, while the stuck counter ticked.

**And for the two edge pins the thing in the way was a BODY**, which is the finding that changes the
design. Their numbers: `bot-beater-3` pinned at (3270.3, -3247.6) against `bot-hunter-1` anchored at
(3270.0, **-3250.0**) -- **0.3 studs apart in x**; `bot-beater-2` at (3529.7, -3247.2) against
`bot-hunter-2` at (3530.0, -3250.0) -- **0.3 studs apart in x**. That is not a coincidence, it is
the geometry: `ForestTest.beaterLaneOffset` deals the lanes out in multiples of the layout's own
stand spacing, so **every beater lane lands exactly on a stand's x**, and `Match.beaterGoalFor` puts
the goal 20 studs PAST that stand -- straight through whoever is standing on it. The edge layout has
5 stands and 3 bot hunters, so most lanes aim through an occupied one.

**Why the road, with the same geometry, had none.** The road is the one place made of real trees:
its drive spent **889 side-steps** against the edge's 199, because `roomToStand` finds something
within 6 studs of almost every lane point in that wood. All that nudging walked the bots in off-axis
and they slid past the stands. In the OPEN field of the edge layout the walk is dead straight into
the body. An open place is the worst case here, not the easiest.

### 4.4 The three defects, named

1. **The clearance test cannot see a body, by design.** `ForestTest.roomToStand` says in so many
   words that *a person is not an obstacle* (and `nearestSolid` and `Data.groundAt` say it too) --
   right for "may she stand here", wrong for "may he walk there". 40 of the 224.6 stuck seconds are
   this.
2. **The clearance test samples the DESTINATION, not the path.** `roomToStand(aim, 6)` asks about a
   point 12 studs ahead. The spruce was 3.8 studs ahead -- between the bot and that point, where the
   thing that stops a bot actually is. 184.6 of the 224.6 seconds are this.
3. **The recovery never reached the humanoid.** `stepWalker` computed the aim every step
   (`STEP_HZ` 5) and called `MoveTo` only every `MOVE_REISSUE_SECONDS` (2), so **nine out of ten
   decisions were discarded** -- and the forced stuck nudge fires once per `STUCK_SECONDS` (4), so
   its chance of landing on a re-issue step is about one in ten. The edge drive's own console says
   it: **`9 stuck, 199 side-steps`** while one bot stood still for 34 seconds. The counter knew. The
   humanoid was never told.

A pathfinder answers none of those three. That is why section 2.4 still refuses `PathfindingService`
after opening the escape hatch task 161 left.

## 5. The numeric targets

| Number | Value | Where | Why |
|---|---|---|---|
| `STUCK_FAST_SECONDS` | 0.8 | `Bots.CONFIG` | the boar's `WEDGE_SECONDS` is 0.75 at a 4.5-studs/s walk; this walk is 5 studs/s and the step clock is `STEP_HZ` 5, so 0.8 s is four steps -- the shortest window that cannot be a single sample's noise. The dispatch asks for a recovery inside ~3 s and a four-second detector cannot start one |
| `STUCK_SLOW_SPEED` | 1.0 studs/s | " | a FIFTH of the pace it was told to walk. The boar uses 0.5 against a 4.5 setpoint (a ninth); 1.0 here is deliberately looser, because section 4 measured a pinned bot creeping at **0.05 studs/s** and a bot genuinely walking at 4.7 -- there is two decimal orders of room between them, so the threshold is not a tuning question |
| `STUCK_ORDERED_SPEED` | 2 | " | the boar's `WEDGE_ORDERED_SPEED`, unchanged: "it was TOLD to move" is what makes slow mean stuck. A gathered or arrived bot has `WalkSpeed` 0 or no goal and can never trip it |
| `RECOVER_HOLD_SECONDS` | 2.2 | " | `SIDE_STEP_STUDS` (10) at `WALK_SPEED` (5) is 2.0 s: the hold has to be at least as long as the sidestep it committed to, or the bot turns back into the thing before it is past it -- the boar's `WEDGE_HOLD_SECONDS` reasoning with this walk's own arithmetic. 0.2 s of margin for the turn |
| `DETOUR_HOLD_SECONDS` | 1.2 | " | a detour is a DEFLECTION, not a recovery: shorter, so the lane is resumed as soon as the trunk is passed. It is above `1 / SEE_HZ` so the held answer is never re-decided inside its own hold |
| `SEE_HZ` | 2.5 | " | the declared floor on the expensive call (SimplePath's `TIME_VARIANCE`, 2.4). Every other step; at `WALK_SPEED` 5 that is 2 studs of travel between looks, against a 12-stud lookahead |
| `LANE_BODY_SIZE` | (4, 5, 1) | " | A Roblox character is 2 studs across and about 5 tall. 4 is its width plus a body's clearance either side -- the same reasoning `Boar.CONFIG.MOVE.AVOID_RADIUS_STUDS` gives for 1.6 against a 2-stud animal -- and `ForestTest.clearRoute` sweeps (3, 3, 1) for the boar for the same reason |
| `DETOUR_ANGLES_DEG` | 18, 32, 50, 70, 88 | " | smallest first: Reynolds' "only as much as the intrusion needs" (2.2). A 6-stud-wide stand rig 12 studs ahead needs ~27 degrees to pass with a body's clearance and one 6 studs ahead needs ~50, so the fan is dense where the answers are. The last is a right angle, where a sidestep begins. Five, against the boar's six, because this is a 12-stud lookahead and not a 26-stud one |
| `DETOUR_CASTS` | 5 | " | one per angle, one side only per evaluation (the bot's own side first), so the ceiling is `SEE_HZ * (1 + DETOUR_CASTS)` = **15 swept casts per bot per second** and 120 for eight bots. Measured cost in section 7 |
| `BACK_OFF_AFTER_TRIES` | 3 | " | ioquake3's `AVOIDREACH_TRIES` is 4; three sidesteps at 2.2 s each is 6.6 s, and the dispatch's bar is 3 s per episode -- so the ladder has to reach its last rung sooner than ioquake3's does |
| `BACK_OFF_STUDS` | 8 | " | far enough to be clear of a body (2 studs) or a trunk flare, short enough that a beater stepping back reads as a man taking a step back and not as a retreat |
| `RECOVERED_STUDS` | 12 | " | the try count resets once the bot has actually got `AHEAD_STUDS` away from where the recovery began: PROOF rather than a timer, which is what ioquake3's avoid list does with its own clock |
| `AIM_EPSILON_STUDS` | 2 | " | a re-issue costs one property write, but an aim that jitters by centimetres every step would re-issue every step and make the gait stutter. 2 studs is less than half a sidestep and more than any rounding |
| `JUMP_OVER_STUDS` | 4 | " | what a man steps over rather than walks round: a log, a bank, a root. Above it is a trunk or a body, and that is gone round |
| `JUMP_HEIGHT_STUDS` | 5.2 | " | one stud clear of `JUMP_OVER_STUDS`. Roblox's own default is 7.2, which is a leap; this is a man getting over a log. **Walkers only** -- a stander keeps `JumpHeight = 0` and its whole state machine off (`Rig.prepare`) |
| the target | **0 bots stuck longer than 3 s, in every place** | -- | the dispatch's own bar, measured the same way before and after (section 4 and section 8) |
| the cost | **printed, not asserted** | -- | `[bots]` gains the cast count and the recovery counts, because the vendor's performance page still has no numbers in it (note 2026-10-12 section 2.2) |

## 6. Owner

Nothing moves (design `bots.md` section 3):

| Thing | Owner |
|---|---|
| a bot rig's movement, and the clock that steps it | `ServerScriptService.Bots` |
| the lane's geometry, the detour and the recovery AIM | `Bots.Lane`, pure |
| a bot rig's Instances | `Bots.Rig` |
| **how to measure THIS wood** | `ServerScriptService.ForestTest` -- `laneAhead` joins `groundAt`, `roomToStand`, `terrainYAt` and `nearestSolid` there, and is injected into `Bots.start` by `ForestTestBoot` exactly as the other two are |
| where a lane starts and where it ends | `ServerScriptService.Match` (`botSlotsFor`), **untouched by this task** |

`Bots` still reads no marker, no tag, no Player and no flag. The DEV arena injects no `laneAhead`, so
it behaves exactly as it does today -- which is also what makes the `laneAhead == nil` branch a
tested one rather than a theoretical one.

## 7. What a cast costs, measured

The vendor's performance page has no numbers in it (note 2026-10-12 section 2.2) and neither
pathfinding page states a cost, so this one was measured rather than claimed. **2,000 `Blockcast`s**
of the body this walk sweeps (4 x 5 x 1) over a 12-stud lane step, spread across the beaters' own
ground in Karen's Forest Test (x 2850..3350, z -1600..-2100, read 2026-10-19 in Edit), and 2,000
`GetPartBoundsInRadius(6)` beside them because that is what the walk already pays:

```
Blockcast(4x5x1 over 12 studs): 0.0606 ms each, 123/2000 hit
GetPartBoundsInRadius(6):       0.0035 ms each, 482 parts found
```

**What that buys.** The budget is `SEE_HZ` (2.5) x (1 forward cast + `DETOUR_CASTS` 5) = **15 casts
per second per bot**, which is the ceiling and only reached by a bot boxed in continuously:

| | per second | per 0.2 s step |
|---|---|---|
| one bot, worst case | 15 casts = **0.91 ms** | 3 casts = 0.18 ms |
| **eight bots, worst case** | 120 casts = **7.3 ms** | 24 casts = **1.45 ms** |
| eight bots walking a clear lane | 20 casts = 1.2 ms | 4 casts = 0.24 ms |

Against the step's own measured cost today -- `step 0.20 ms avg` (edge), `0.24` (ride), `0.27`
(road) -- the worst case is about 1.7 ms a step and the ordinary case about half a millisecond. A
swept cast is **17x** the point test the walk already makes, which is why it is rationed by `SEE_HZ`
and its answer held, and why the recovery ladder spends casts only when a bot is actually pinned.

**Honest limit:** this is the cost in the road layout's real wood, measured in Edit. The three
planted places are built at runtime and could not be measured the same way; they hold ~3,000 trees
against this wood's ~800, so a cast there may cost more. The per-drive `[bots]` line now prints the
cast count and the step cost, so the question is answered by the next drive rather than by this
paragraph.

## 8. What is NOT in this task

* **The trees, the terrain and the four places are not touched.** Karen: *"do not try to fix forest,
  we will go together"*.
* **`Match.beaterGoalFor` is not changed.** A lane's goal is 20 studs past the nearest stand, which
  is straight through whoever is standing on it -- and that is the first cause in section 4. Moving
  the goal aside would be the other fix, and it is `src/server/Match/`'s, which is in
  `TWO_PLAYER_PATHS`: a human click per round. The walker steering round a body is the smaller
  change and the more general one (it also steps round KAREN standing there, which a goal offset
  would not).
* **No new feature flag.** `DRIVE_BOTS` already gates every bot in this game; this is a defect fix
  inside it, which is how tasks 164, 166 and 206 were taken too.
* **`PathfindingService` is still not adopted** (2.4).
