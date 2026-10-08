# Task 125 - a compass that shows where the drive comes from

Task: 125
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

Karen: *"we need to indicate from what side drive is comming"*. A scrolling compass strip with the
drive's own bearing marked on it. The countdown and the red rectangle she withdrew are NOT built.

## What round 1 found, and what round 2 did

**ROUND 2.** #1 the strip was drawn ON TOP of the drive bar -- 360 of its 520 px, over the clock, the boars left and the team badge -- in every world that has a drive; it was never seen because the frames were taken in the Forest Test, where `MatchBoot` stands aside. `Compass.CONFIG.TOP` moves from 10 to **76**, which clears the bar (8..34) and the tied banner (44..68) with 8 px to spare, and the comment names both.

## Claims

1. **The strip is the Hud's, and the Hud never writes the camera.** `src/client/Hud/Compass.luau`
   draws the marks; `Hud` creates its frame. Verify: `Compass.render`, `Compass.offsetPx`,
   `Compass.deltaDeg`, and `tests/client/compass.spec.luau`.
2. **The heading comes from the owner of the VIEW.** Not `workspace.CurrentCamera.CFrame` (a counted
   foreign writer since task 123) and not the character's `HumanoidRootPart` (in first person the
   camera turns the view without turning the body -- measured with real mouse input, the strip never
   moved a pixel). `Compass.headingFrom` asks the camera system. Verify: that function.
3. **The conversion lives once, in the camera.** `Camera.headingOfLookDeg` turns a look vector into a
   world bearing and `Camera.viewHeadingDeg` applies it to the CFrame `Rig` last wrote. Verify:
   `src/client/Camera/init.luau`.
4. **It was 180 degrees out when this task ended, and task 129 fixed it** -- see that request. The
   bearing is now `atan2(x, z)` with nothing carried on top, settled against a photograph of four
   known posts rather than against another CFrame.
5. **With nothing trustworthy to read, the strip keeps the heading it last had.** The Director's rule
   for round 4: if `CurrentCamera.CFrame` is not what is rendered, do not use it. A compass that lags
   a few frames at spawn is not a compass that lies. Verify: `Compass.headingFrom` and its spec case.
6. **The drive's bearing is the WORLD's statement, not a guess.** `ForestTest.DRIVE_BEARING_DEG` is
   derived in that world's data from where the beaters start; any other world has not said, and then
   the strip is a plain compass with no marker. Verify: `src/shared/ForestTest/init.luau` and the
   compass section of `src/client/Hud/init.luau`.
7. **The published heading is also an attribute on the strip**, because a sandboxed `require` from
   the harness answers a copy with empty state and cannot see a module upvalue.

## What could not be verified

- **Whether the strip reads well while running** -- its width, its tick spacing and the marker's size
  are taste, and Karen has not played it yet.
