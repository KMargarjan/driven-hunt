# Task 318 -- a range animal dies where it is hit

Task: 318
Round: 1
Base: d817d1b3 (main, with 313/315/316/317 merged)
Code commit: 71e6660f73c2fd7e4b49ce839726add561e027bb

Karen, 2026-10-31, after playing her Forest Test range: *"when hitting in range animal ir go
up and then fall seems like it go on air when died"*.

## PLAN (core quality protocol step 0)

- **(a) REAL LIFE.** A shot animal drops. It does not gain height: the only upward motion in a
  real fall is the body pivoting about a foot, centimetres, not metres.
- **(b) MEASURED NOW** (before any edit), in HER place, at main, one real rifle shot at a range
  target, client-side per-Heartbeat sampling of the trunk's `Position.Y`
  (`<runs-dir>/318-ytrace.luau`, traces `318-trace-main-walk.txt`, `318-trace-main-run.txt`):
  standing root Y **151.477**, floor 150.000. At the kill it goes to **154.476 in one frame**,
  `vy` **0.00** throughout, and `Anchored` turns true in the same frame. **+3.000 studs**, and it
  stays there: box bottom **+2.976 over the floor**, anchored, for the whole carcass life.
  RUN is the same number: **+3.008** (`318-trace-main-run.txt`).
- **(c) TARGET.** Never more than 0.5 stud over the standing root height, and it ends on the
  ground. The dispatch's number.
- **(d) LEVER.** `ForestTest.GROUND_IGNORE` in `src/shared/ForestTest/init.luau` -- the only
  writer of what `ForestTest.groundAt` excludes, and `Body.stepCarcass` (`src/server/Boar/Body.luau`)
  is the only caller that grounds a settled carcass with it.
- **(e) HOW IT IS MEASURED AFTER.** The same probe, same place, same two paces.

## The cause, named with the trace

`Body.stepCarcass` puts a settled carcass on the ground with ONE `CFrame` write, reading the
ground from **just above the body** (`CARCASS_GROUND_FROM_STUDS`). `ForestTest.GROUND_IGNORE`
named `Boars` -- the drive's folder -- but not `RangeTargets`, the folder the range spawns into
(`Range.TARGETS_FOLDER`). So the downward ray hit **the dead animal's own box**, `Boar.groundDrop`
answered "your bottom is `Size.Y` below the ground", and the write lifted it by exactly its own
box height. The box is 2.00 x **3.00** x 5.50 and the lift measured **3.000**. Not physics:
`vy` 0.00, one frame, then anchored.

It is range-only, and that is measured too: at main, a boar-sized box in `Workspace.Boars` at a
forest point changed `ForestTest.groundAt`'s answer by **+0.000** (`318-forestground.luau`),
because `Boars` was already in the list.

## The change

One name added to `ForestTest.GROUND_IGNORE`: `"RangeTargets"`. Nothing else in `src/`.

## Claims

1. **The defect reproduces at main.** `318-trace-main-walk.txt` / `318-trace-main-run.txt`: peak
   **+3.000** / **+3.008** over standing root Y, rest **+2.976** over the floor, anchored.
   Verify: read either file; every frame from t-0.3 to t+6.0 is in it.
2. **It is gone at the code commit.** `318-trace-fix-walk.txt` peak **+0.007**,
   `318-trace-fix-run.txt` peak **+0.000**; both rest at box bottom **-0.023** of the floor
   (on it, not under it, not floating). Two further RUN/WALK kills read +0.008, +0.000, -0.008.
   Verify: the same files, same instrument, same place.
3. **The instrument is not flat.** The same probe read **+3.000** at main and **+0.007** at the
   fix on the same lane, same gun, same station (L-141). Both full traces are in the two files.
4. **The lift equals the box's own height**, which is what names the cause: `Size.Y` 3.00, lift
   3.000. Verify: the `trunk=... size=` line at the head of each trace.
5. **The kills are live and unanchored** (L-147). Every trace fires real `FireRequest`s through
   the shipped server shot path at a walking/running range target; nothing is anchored, frozen or
   teleported on the animal. The shooter is placed on mat 2 (`317-onmat.luau`), the animal never
   touched. Verify: `318-ytrace.luau` -- it only reads the animal.
6. **A forest death is unchanged, and was never affected.** `Boars` was already in the list; at
   main a boar-sized box in `Workspace.Boars` moved `groundAt`'s answer by **+0.000**. Verify:
   `318-forestground.luau` and its output in the report.
7. **A spec fails on main and passes here.** `boar_model.spec`, *"never lets a RANGE carcass be
   its own ground (task 318)"*: it builds a floor whose top is 150 and a boar-sized box inside a
   folder named `Range.TARGETS_FOLDER`, asks `ForestTest.groundAt` from just above the box, and
   requires **150** and `groundDrop` **0**. On main that reads 153 and drops +3. It also asserts
   `Range.TARGETS_FOLDER` is in `GROUND_IGNORE`, so the name cannot drift from the folder --
   the pattern `places.spec` already uses for `Places.FOLDER`.
8. **Only the list grew.** `git diff d817d1b3..71e6660f -- src/` is one line plus its comment.
   No change to `Body.collapse`, `Body.stepCarcass`, `Boar.groundDrop`, the topple, the lift or
   the anchor, and no teleport-to-ground anywhere.
9. **The gate.** `[harness] PASS: 34/34 checks @ 71e6660f73c2fd7e4b49ce839726add561e027bb (clean tree) scope=all`
   `test2` is N/A: `agents.needs_two_player(['src/shared/ForestTest/init.luau','tests/server/boar_model.spec.luau'])`
   returns `[]`.

## What could not be verified

- **A frame of the dead animal (rule 5): NOT OBTAINABLE, with the reason.**
  `Range.CONFIG.CARCASS_SECONDS = 3` -- the range clears its carcass three seconds after the
  kill. A screenshot is a separate process round-trip after the probe returns, so it always lands
  after the body is gone; a 22-frame burst at 1 Hz run alongside the kill
  (`318-burst.sh`, `318-main-sheet.png`, `318-fix-sheet.png`) caught the **live** target on the
  turf and never the carcass. So **no visual claim is made here** -- the claims above are the
  per-frame Y trace, which is the instrument the dispatch named. `ft-open.sh`, `shot.ps1`,
  `DHTestLook` and a camera tracking the animal every frame were all used (V294).
- **A forest KILL was not taken.** What is measured instead is the same reader, in the forest,
  with a body in `Workspace.Boars` (claim 6). Reaching a forest kill needs enrolment and a drive;
  the reader answers the question the dispatch asked -- range-only or the death path -- exactly.

## The failing spec, named, with a control

Two runs at the code commit failed `deer_hitbox.spec` -- `:682` then `:659`, the two lines the
dispatch names as the known intermittent (315a(q), 313). A **control run at the merge-base**
`[harness] PASS: 34/34 checks @ d817d1b3aea41338b7cb83d616c04d319e9f66bb (clean tree) scope=all`
passed, and the **third run at the code commit** passed 34/34 as well -- so the same commit both
failed and passed it. Count: 2 firings in 3 runs at 71e6660f, 0 in 1 run at d817d1b3.
