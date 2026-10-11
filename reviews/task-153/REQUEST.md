# Task 153: START AS A BEATER in the Forest Test

Task: 153
Round: 1
Base: 495542b (main, after #135 merged)
Code commit: 0577dc4e7d3e0e00f4e97b4337189203ed2edc3b

```
[harness] PASS: 33/33 checks @ 0577dc4e7d3e0e00f4e97b4337189203ed2edc3b (clean tree) scope=all
RUN2
```

The gate is pasted **twice**, at the Director's instruction. The second line names the commit that
carries this file: the first run named the code commit itself, and the only thing between them is
this page (git workflow step 4). A third run, made between the two, is NOT pasted because it was
not evidence and says so itself -- `(DIRTY TREE (1 paths) - NOT valid evidence)`, the one path being
this uncommitted request.

## What changed

Karen, 2026-10-11: *"how to start a game as a beter?"*, and then *"you start as a hunter then next
round you are beater ... and yes beater are behind animals and moving towards hunter line (road) like
in real life ... I think we need to focus now to be a beater / we will try walk spook, use horn have
that feeling and improve"*. **There is no start-choice panel in this change**: the rotation between
roles and its anti-cheat memory are the next task. This is the beater EXPERIENCE, in the Forest Test
world only.

Four things, in four files plus two specs:

* **the start.** `ForestTest.beaterStartPosition` puts a beater `LINE.spawnNorthStuds +
  BEATER.behindLineStuds` north of the road, on the terrain, clear of trunks, facing the point on the
  road curve at her own x. `/hunter` puts her back on a stand and reopens the ten-second pick. A
  `DHForestStartRole` attribute on `ServerStorage` lets **Play itself** start her as a beater.
* **the push.** `ForestTest.boarThreats` marks a real beater `kind = "driver"` instead of
  `"shooter"`, and `ForestTest.stepLines` asks `Runtime:spook` for a line member a real beater has
  walked within `PACE.DRIVER_RUN_STUDS` of.
* **the compass** marks the road for a beater and the drive for a hunter (`Hud.driveBearing`).
* **the leash** (`ForestTest.leash`) refuses a beater outright.

`Map.EXPECTED_WORLD ~= "forest-test"` still returns from `ForestTestBoot` before any of it, and
nothing under `src/server/Match/`, `src/client/Match/` or `src/shared/Drive/` is touched.

## Claims, and how to verify each

1. **A beater starts BEHIND THE ANIMALS, on the drive side, and the point is derived rather than
   chosen.** `ForestTest.beaterStart` (shared) is `roadZ(x) + LINE.spawnNorthStuds +
   BEATER.behindLineStuds`: a line is released at `spawnNorthStuds`, so she is behind every animal the
   drive has just put down, by construction. Verify: `tests/server/forest_stand.spec.luau`, "puts her
   behind the line's own spawn, on the push line, north of the road". MEASURED live, three separate
   Play sessions: `[ForestTest] Alhamdulilah824 starts as a beater at (3030, 160, -1857), 240 studs
   from the road`.

2. **She is ON THE GROUND and CLEAR OF TRUNKS, and neither was assumed.** `ForestTest.terrainYAt`
   casts against `Workspace.Terrain` ALONE -- `Data.groundAt` excludes `OurForest`, `Foliage` and
   `Boars`, and that is not every tree in this place: measured today, 831 more trees and bushes live
   in two folders both called `Session`, so a downward ray there can stop on a canopy.
   `ForestTest.roomToStand` is an overlap query with `RespectCanCollide = true`, because this forest
   is mostly ferns with `CanCollide = false` and what she may not stand in is a trunk. MEASURED live:
   `nearestTree=Workspace.OurForest.SM_AspenTree_Var09.SM_Trunk at 33.8 studs`, character y 159 on
   terrain y 155.8. Verify: the two functions, and the spec case "measures the ground and the trunks,
   and always answers a point" (which proves the FALLBACK, because the DEV place has no terrain under
   this world's coordinates).

3. **She faces the road.** `placeFor` in `ForestTestBoot` looks at `Data.roadPointAt(at.X)` flattened
   to her own height, so the character stands up instead of leaning down the hill. MEASURED live:
   `look=(-0.00,-0.00,-1.00)` -- due south, at the road. Screenshot: `.screenshots/t153-beater-start.png`
   (first person, standing in the wood, the road visible in the middle distance, the DRIVE marker on
   the compass at the middle of the strip between SE and SW).

4. **Play itself can start her as a beater, and the default is still a hunter.**
   `ForestTest.startRole` reads the `DHForestStartRole` attribute (bare word or with Karen's slash);
   `PlayerAdded` applies it before the character exists. One command sets it, in Edit:
   `game:GetService("ServerStorage"):SetAttribute("DHForestStartRole", "beater")` (the runs
   directory has it as `t153-setrole-beater.luau` / `t153-setrole-hunter.luau` for
   `python ftplay.py edit <file>`). Verify: the spec case "reads the start switch, with or without
   the slash Karen types", and the live line `[ForestTest] Alhamdulilah824 joins as a beater (start
   switch)`. It is NOT a `DHFlag_*` name, so it is invisible to the harness's override guard and
   cannot defeat it.

5. **A beater is never held to a stand, and a hunter still is.** `ForestTest.leash` returns nil for
   anybody who is not a hunter. Without it the task is dead on arrival: she walks 240 studs south and
   a six-stud leash round the stand she locked would drag her back every heartbeat. Verify: the spec
   case "does not hold a beater to a stand" (the same part, the same position, pulled as a hunter and
   not as a beater), and `startAt`'s pick timer, which refuses to lock a stand for somebody who has
   asked to be a beater while the window ran.

6. **A real beater is a DRIVER in the boar's threat list, and is not a phantom.** `boarThreats` asks
   `ForestTest.threatKind(roleOf(...))`. This matters because the Brain branches on it: a `driver`
   inside a flush radius pushes the animal at a walk or a trot, and anything else inside
   `PACE.SPOOK_STUDS` spooks it into a run. Verify: the spec case "marks a REAL beater as a driver in
   the boar's own threat list", which asks the LIVE `Players` service for a player with a character
   and then reads the same player's entry as `driver` when she is a beater and `shooter` when she is
   a hunter, with no `phantom` mark either way. **It says plainly what it could not do**: with nobody
   in the world it writes a `TestKit.note` and returns rather than passing on nothing. I could not
   confirm from outside which of the two paths the gate run took -- `[note]` goes to the Play
   console, which is gone by the time the run reports -- so take the LIVE half of this claim as
   "asserted when there is a player", and the pure half (`ForestTest.threatKind`) as asserted always.

7. **Her walk flushes animals, and it had to go through the drive to do it.** MEASURED, in her place,
   BEFORE this line was written: she walked to within **8.9 studs** of a file and every member kept
   its ordered **4.5 studs/s** walk -- because an order outranks perception (task 127: an ordered
   animal returns from `Brain:step` before the pace clamp and before every mood), so marking her a
   driver changes nothing for an animal walking a trail. `stepLines` therefore asks `Runtime:spook`
   -- the same door the crossing shove and the horn use -- for a member within
   `PACE.DRIVER_RUN_STUDS` (the boar system's own number, read off the runtime's config). MEASURED
   after: `[ForestTest] a beater flushed Boar3 at 23 studs (3 flushed so far)`, those three running
   at **24.00 studs/s** against the 4.5 they were walking at.

8. **They are pushed AHEAD of her, over the road, and not back past her.** `Brain:_latchFlight` takes
   its heading from the point handed in, so an animal flushed by a beater standing north of it runs
   SOUTH. MEASURED over four traces of a 25-60 s walk, sampling the live server ~2.5 times a second:
   **every one of the 43 animals that came within 50 m of her travelled south, and NOT ONE ended up
   north of where it started.** In the 60 s trace, 8 of the 8 that came within 50 m crossed the road.
   One horn blast mid-walk: `[ForestTest] horn blown at (3032, 133, -2337): 6 boar(s) pushed within
   286 studs (80 m)`, and 14 in another run. The instrument is
   `<runs-dir>/t153-walk.py` + `t153-report.py` (outside the repo).

9. **The compass marks the push for a beater and the drive for a hunter.** `ForestTest.PUSH_BEARING_DEG`
   is derived -- `(DRIVE_BEARING_DEG + 180) % 360` -- and `Hud.driveBearing` is the whole rule, pure.
   The Hud reads `player.Team`, which is the one representation of the team (the same door
   `Match.myTeam` reads), and re-reads it on change because `/beater` switches teams mid-session.
   Verify: `tests/client/compass.spec.luau`, "marks where the drive comes from for a hunter, and the
   road for a beater", and the screenshot in claim 3.

10. **Nothing outside the playtest world moved.** `src/server/Match/`, `src/client/Match/`,
    `src/shared/Drive/`, `tests/client/Role.luau` and the specs that test them are untouched
    (`git diff --stat 495542b..HEAD`), so `TWO_PLAYER_PATHS` is not reached and the one-player gate is
    the gate. The Hud change is `hud`; the rest is the Forest Test, which maps to no scope and
    therefore to `all`.

## What I could NOT verify

* **Whether it FEELS right is Karen's.** The numbers say she is behind the animals and they go over
  the road ahead of her; "walk spook, use horn have that feeling" is a judgement nobody else can make.
  The one dial is `BEATER.behindLineStuds` (60) -- she starts 240 studs out, which at the 15.7
  studs/s she actually makes through this wood is **16 seconds to the road**, and after that she is
  south of everything.
* **A scripted walk cannot STEER.** `VirtualInput` cannot deliver usable mouse deltas under
  `MouseBehavior = LockCenter` (`Camera.lookAt`'s own comment records this, and task 122 round 3
  measured it again), so the traces walk her due south and whether she meets a line at all is the
  wave's own crossing offset (`LINE.crossOffsets`, -70 to +95 from the stand). Two of four traces had
  a line in her path and two had it 70+ studs to the side. Karen, with a mouse, will not have that
  problem.
* **FOUND, NOT MINE, AND NOT FIXED HERE.** `Runtime:_measureMotion` in `src/server/Boar/init.luau`
  rebuilds every stimulus as `{ id, position, kind, speed }` and **drops the `phantom` mark**, so
  `PACE.DRIVER_RUN_STUDS`'s phantom exemption (task 123 round 5) is inert in any world with `SENSE`
  on. It does not affect this task -- a player is genuinely real, and the LINE mode has no phantoms
  at all -- and fixing it changes what the WAVE mode does, which is another task. Queued as 153a.
* **The DEV place's own drive** was not exercised by hand; the gate's match specs are what stands
  behind "nothing there moved".
