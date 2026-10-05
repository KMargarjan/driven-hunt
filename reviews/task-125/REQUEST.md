# Task 125 - a compass that shows where the drive comes from

Task: 125
Round: 1
Base: main
Code commit: `54d68f46bb87c98d9e5081b7f17682e7ea463dad`

```
[harness] PASS: 33/33 checks @ 54d68f46bb87c98d9e5081b7f17682e7ea463dad (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 54d68f46bb87c98d9e5081b7f17682e7ea463dad (clean tree)
```

The `[harness2]` line is the Director's, run at the code commit `54d68f4` itself (detached checkout; only these requests differ at the head), 2026-10-06 ~01:30, DEV the only Studio open: server 758 / shooter 146 / driver 140 passed, 0 failed.

**THIS TASK IS ONE OF NINE IN ONE PR** (122-130, `task-130-spawn-view` -> `main`). Director
decision, recorded in `ESCALATE.md`: no branch below 128 can pass the gate on its own -- DEV's
map could only be rebuilt once 128's bundler existed, and 129 fixed the specs 123-127 broke --
so the evidence for every task in the stack is the gate AT THE HEAD, and every task still gets
its own review.


## What changed

Karen: *"we need to indicate from what side drive is comming"*. A scrolling compass strip with the
drive's own bearing marked on it. The countdown and the red rectangle she withdrew are NOT built.

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
