# Task 127 - one side to the other, in a line

Task: 127
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

Karen: *"imagine they come from one side in one line and crossing road thats it"*, *"it's simple"*.
The Forest Test's waves now walk one route, nose to tail, and run once they are across.

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

## What could not be verified

- **The line is a loose band, not a file.** Gap median 10.1 studs against an 8.5 station, p90 34.5,
  and 40 % of consecutive pairs are closer than one station along the trail. I looked at four frames
  from the stand and said so: in the best of them the animals are a loose row at one depth.
- **Trunk contacts are not zero**: 12-17 distinct (boar, trunk) pairs per 160-second trace, 11-14 of
  them the LEADER's. The route is not the cause -- the navmesh, asked directly, routes 3.9 studs
  round a trunk of radius 0.9, and widening the agent radius moved nothing -- so they happen when an
  animal is off its route, which is flight, which is what Karen asked for.
- **Karen has not seen it.** Whether "one line crossing" reads right from her stand is hers.
