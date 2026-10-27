# Task 293b: a dead deer stays down for its whole carcass life

Task: 293b
Round: 2
Base: 5fb54278
Code commit: 10bb9262e9d24ed9c1f43290a87b9a1847462f36

Karen, 2026-10-27: *"deer error remains, after kill stands"* -- after task 293 merged.

## PLAN

(a) **REAL LIFE.** A shot deer that goes down stays down: it does not stand up again, not once in
120 seconds. There is no "real life" number to cite beyond 0 standing carcasses per kill.

(b) **MEASURED NOW** (task 293's own probes on the real rigs, `<runs-dir>/293-lab.luau`,
`293-lab3.luau`, `293-tail.luau`, reading `Bone.TransformedWorldCFrame` -- the probe that tells the
two states apart): a held death draws **1.02-1.33 studs** of rig height, the bind pose
**3.85-4.94**. An overrun past the clip's end stops the non-looped track and the rig snaps to bind
pose. 293's repair puts it back, but `MODEL.REHOLD_LIMIT = 3` repairs per carcass against
`WOUND.CARCASS_SECONDS = 120`, so the 4th overrun in one carcass's life leaves it standing for the
rest of that life.

(c) **TARGET.** 0 standing samples across the whole `CARCASS_SECONDS` 120, with **no repair count a
carcass can exhaust**. Stated in `CARCASS_SECONDS` units: the repair is available on every step of
all 120 s (7200 of 7200 steps), not 3 times.

(d) **LEVER.** Two, both in `src/server/Boar/Body.luau`:
```
1612:			local reach = Body.freezeReach(track.Speed, dt, config.MODEL.HOLD_EPSILON)
2588:	if reholds >= config.MODEL.REHOLD_LIMIT then
3420:	REHOLD_LIMIT = 3,                                   (src/server/Boar/init.luau)
```
`Body.freezeReach` is the cause of the overrun (it predicts the next step from the LAST frame's dt);
`shouldRehold`'s `REHOLD_LIMIT` gate is the cause of the 4th overrun standing the deer.

(e) **HOW IT WILL BE MEASURED after.** The same instrument on both sides: the drawn pose. In the
suite, the restored FRAME, which (b) maps to drawn height on the real rig; in her place, the
Director's `293-pose.luau` bone read at 3 s, 60 s and 115 s, on a deer AND a boar.

## WHAT CHANGED

1. **The overrun's cause: the freeze window no longer depends on the last frame's dt.**
   `Body.freezeReach(speed, dt, epsilon)` is replaced by `Body.freezeWindow(length, config)`, a
   fixed `MODEL.HOLD_MARGIN_SECONDS = 0.05` (clamped to a fifth of a short clip, floored at
   `HOLD_EPSILON`). A window of width W catches every frame whose clip step is <= W, because the
   samples are W apart at worst -- so **no frame up to 50 ms (20 fps) can overrun at all**, where
   today's window is the previous frame's step and a 16 ms frame followed by a 300 ms one has a
   16 ms window. The freeze now also **writes** `TimePosition = Body.holdFrame(nil, length, config)`
   = `length - HOLD_EPSILON`, so the held frame is the one `KINDS.deathLiftStuds` was measured at
   whatever the overshoot was, and the track is parked BELOW its end where it cannot stop again.
   A frame worse than 20 fps can still overrun: it is then harmless, by 2.
2. **The repair has no count.** `REHOLD_LIMIT` and the `reholds` parameter are gone:
   `Body.shouldRehold` is unbounded, asked on every step of the carcass's life. It is cheap and it
   cannot storm, because the state the repair produces -- playing, weight 1, speed 0, at the held
   frame -- is the state `shouldRehold` provably refuses (spec: the first case in the task-293 test).
   `handle.reholds` survives as a DIAGNOSTIC only (`Runtime:animationOf`), read by no gate.
3. The boar's paddle still plays to its end: nothing freezes a clip that is mid-advance. Held by the
   existing case, which this branch does not touch and which passed before it.

## CLAIMS

1. `Body.shouldRehold` takes no count and reads no limit: `grep -rn "REHOLD_LIMIT" src/ tests/`
   finds only comments that say it was removed. It is gone from `Boar.CONFIG.MODEL`, from the
   function's parameters and from the call site in `Body.stepVisual`.
2. `Body.freezeReach` is gone and `Body.freezeWindow` does not take a `dt`
   (`grep -n "freezeReach\|freezeWindow" src/ tests/`).
3. A carcass gets 240 overruns across `CARCASS_SECONDS` 120 and 0 standing samples
   (`tests/server/boar_model.spec.luau`, "holds a carcass down for its WHOLE life").
4. The fixed window freezes a death 0.04 s from its end, where the old dt window let the next
   45 ms frame carry it over: 0 stops, 0 repairs, held at `holdFrame` (same file, "the fixed window
   freezes the death BEFORE its end"). This is the case that bites on item 1; round 1's version of
   it passed at main and has been replaced. The boar's paddle advancing to its end is the existing
   case below it ("the boar paddle advances and is never pinned"), unchanged by this branch.
5. FAIL FIRST: the same spec, with `src/` identical to main, fails. The line is pasted below.
6. `handle.reholds` gates nothing (`grep -rn "reholds" src/`: written in `Body.stepVisual`, read
   only by `Runtime:animationOf`).

## WHAT I COULD NOT VERIFY

The Forest Test proof on Karen's path (a real deer and a real boar killed, bones read at 3 s, 60 s
and 115 s) is the Director's, per the dispatch. Nothing in this branch is proven on her path by me.

## HARNESS

```
[harness] PASS: 34/34 checks @ 10bb9262e9d24ed9c1f43290a87b9a1847462f36 (clean tree) scope=all
```

FAIL FIRST, with `src/` identical to main and only the new spec added (commit a4a5b8e3):

```
  failed [server] boar_model.spec:1355 Expected value "0" (number), got "7110" (number) instead
[harness] FAIL: 32/34 checks @ a4a5b8e3eba4be7ad19134b8a9615b65e794d4b8 (clean tree) scope=auto:assets,boar,flags
```

**7110 of 7200 SERVER STEPS standing** -- the 4th overrun onwards, for the rest of the carcass's
120 seconds, which is Karen's sentence as a number. After the fix: 0 of 7200 server steps. It is a
count of steps, not of drawn frames: a hitch worse than 20 fps still draws one frame of bind pose
before the repair lands on the next step.

`test2` is N/A: nothing here is in `TWO_PLAYER_PATHS` (`src/server/Boar/`, `tests/server/`).

## ANSWERED

- ANSWERED: L-142 -- the new bound is not a bigger number. There is NO count: `REHOLD_LIMIT` and
  the `reholds` parameter are deleted (archived in `backups/2026-10-27-task-293b-freezeReach.md`),
  and the repair is available on every one of the carcass's ~7200 steps. What replaces the count is
  the rule's own fixed point: the state a repair produces is the state `shouldRehold` refuses.
  `handle.reholds` survives only as a diagnostic that gates nothing.
- ANSWERED: ROUTE (deer) -- no DEV kill was attempted. The route that lost two sessions in task 293
  is not needed here: the fail-first and the proof are both on the DRAWN FRAME, driven through
  `Body.stepVisual` itself, and the live proof on Karen's path is the Director's per the dispatch.
- ANSWERED: ROUTE (boar) -- same: the boar half is `Body.stepVisual` driven through a real 4 s
  paddle, asserting it advances and is never pinned. "Boar55" is not relied on by anything here.
