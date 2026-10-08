# Task 127 - one side to the other, in a line

Task: 127
Round: 3
Base: main
Code commit: `cced90502fddfbeda8efd3ba74e27779834fe879`

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

Karen: *"imagine they come from one side in one line and crossing road thats it"*, *"it's simple"*.
The Forest Test's waves now walk one route, nose to tail, and run once they are across.

## What round 2 found, and what round 3 did

**The seeded breadcrumb trail was built on the centreline while the bodies and the route carried the
line's lateral offset.** With two lines that gave BOTH files the same polyline, 2.5 studs from where
either of them stood -- pulling them together into exactly the body overlap `spacingStuds` exists to
prevent -- and it left a 2.5-stud jog at the seam where the leader's real crumbs began. It bit a
one-line wave too whenever the route that survived was not the first. The seed now starts from
`start + Vector3.new(routes[which].lateral, 0, 0)`: bodies, route and seed share one origin.

**Measured live in the Forest Test, two lines forced on every wave** (temporary probe publishing the
line id, rank and flight; removed before the code commit), excluding animals the Brain has latched
into a flight, since a frightened animal has left the file on purpose:

| per line | median | p90 | max |
|---|---|---|---|
| best lines (6-1, 6-2, 2-2) | 0.28-0.36 | 1.07-1.66 | 5.1-9.0 |
| all lines, one run | **1.13** | 4.60 | 18.78 |
| all lines, another run | **1.38** | 7.07 | 26.9 |

## What round 1 found, and what round 2 did

**ROUND 2.** #1 **the file was spawned BACK TO FRONT** -- the leader stood at the tail, so every follower was past the head of her trail, every `slack` was negative and the overrun rule froze the whole line while the sow walked through it. The marching order is now decided before anybody is placed and rank k is laid out k stations BEHIND the head, where the seeded trail already puts its station. #2 the stuck rule reads the ORDER (`statusOf().want > LINE.stuckAskedSpeed`): the followers the overrun rule froze on purpose were being counted as stuck and snapped backwards onto crumbs behind them.

## Claims

1. **The line is a TRAIL, not a formation.** The leader walks a route and drops a breadcrumb every
   stud; follower k rides that polyline at `k * SPACING` measured ALONG it. Task 126 had each
   follower STEER at a point behind the animal ahead and measured the result -- the gap stayed at
   23-35 studs and the turning went up, because steering at a moving point is a chase. Verify:
   `src/server/ForestTest/Line.luau` (`addCrumb`, `pointAt`, `arcAt`, `followerSpeed`, `leaderSpeed`)
   and `tests/server/forest_line.spec.luau`, which drives all of it with no world.
2. **The drive owns the route and the boar owns the walking.** `ForestTest.computeRoute` pathfinds
   two legs through a crossing point chosen relative to the hunter's own stand; `Brain:leadTo` is the
   one new door and in that mode every blend is off -- no whiskers, no route of its own, no cohesion.
3. **Routes are computed BEFORE the animals are spawned.** `ComputeAsync` fails when it starts inside
   a `CanCollide` body, and spawning first made every route fail (`placed=9 routes made=0`).
4. **A follower walks the trail, not a chord across it.** It is told where it is ON the trail
   (`Line.arcAt`) and ordered to a point a lookahead FURTHER ALONG it -- ordering it straight at its
   station cuts the corner the leader went round, which is a trunk. Verify: `ForestTest.stepLines`.
5. **The aim point is never clamped to the station** (round 3). It was, and a follower sitting within
   a lookahead of its station was handed a point under its own feet, inside `LINE.ARRIVE_STUDS`: the
   Brain reported it had arrived and stood there while the line walked on. **Stuck animals 18 -> 12
   in a 160-second trace.** A follower that has overrun now waits at speed 0 instead of being walked
   backwards.
6. **The sow waits for her tail** (`Line.leaderSpeed`), which is what stops a line becoming a
   procession of singletons: measured, the gap p90 had been 142-213 studs.
7. **Nobody comes back from the far side.** 0 of ~40 animals re-crossed northward in the best run,
   2 in the worst; after a shot 17-30 move and 0-4 of them northward. Karen: *"once they in another
   side of road they run away"*.
8. **`Boar.CONFIG.BOAR_COLLISION` ships OFF with its measurement in the comment.** The Director's
   hypothesis -- that boar-to-boar shoving caused the loose gaps -- was tested with a real collision
   group, verified live as applied, and refuted: pairs abreast 36 % -> 34 %, gap median 10.2 -> 10.6,
   stuck 18 -> 19, trunk contacts 12 -> 21.

## What round 2 measured, live, after the fix

* **The file forms.** Seven animals of one line, read off the stand by distance along one bearing:
  **92, 101, 109, 117, 125, 134, 141 studs** -- eight or nine studs apart, nose to tail, against a
  station of 8.5.
* **Stuck: 0** in a 160-second trace, against 12 before this round.
* **The order is the sow's**: `[female>cub>cub>cub>cub>cub>male>male]`, wave after wave.
* **Nobody comes back across**: of the animals that moved north after a shot, **0 had already
  crossed** -- every one was still on the drive side, running from the gun, which is what the flight
  is for.

**WHAT THAT PROVES AND WHAT IT DOES NOT.** The medians are the fix: a follower now walks within a
stud or two of ITS OWN line's trail, where before the two files shared one polyline neither of them
stood on. **The Director's bar was a MAX of 1.5 studs on both lines and the maxima do not meet it**
-- they are 5 to 27 studs, and they are not the seed: they are animals deflected round a trunk by
the whisker, animals rejoining the file after a flight has ended, and the leader's own corners, where
a follower cutting inside the turn is briefly off a trail that doubles back. Saying so is the
honest answer; the number to chase next is the p90, not the max.

## What could not be verified

- **The frames still do not SHOW it.** The four captures from the stand have the animals at 90-141
  studs among birch trunks, in shadow: the distances above are a file and the picture is not legible
  as one. A frame taken from closer, or a line crossing nearer the stand, is what would settle it,
  and I did not get one inside this round.
- **The old gap and offset numbers could not be re-measured.** They came from a temporary probe that
  publishes the line id and rank on each body; that probe is not in the shipped code, so this round's
  trace reports the distances above and the stuck count rather than a gap median.
- **The line is a loose band, not a file.** Gap median 10.1 studs against an 8.5 station, p90 34.5,
  and 40 % of consecutive pairs are closer than one station along the trail. I looked at four frames
  from the stand and said so: in the best of them the animals are a loose row at one depth.
- **Trunk contacts are not zero**: 12-17 distinct (boar, trunk) pairs per 160-second trace, 11-14 of
  them the LEADER's. The route is not the cause -- the navmesh, asked directly, routes 3.9 studs
  round a trunk of radius 0.9, and widening the agent radius moved nothing -- so they happen when an
  animal is off its route, which is flight, which is what Karen asked for.
- **Karen has not seen it.** Whether "one line crossing" reads right from her stand is hers.
