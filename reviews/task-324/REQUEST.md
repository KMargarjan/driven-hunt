# Task 324 -- on the range, the next animal goes through where the dead one lies

Task: 324
Round: 1
Base: a39e41dd (main)
Code commit: 0f95153ae16830e7f71ca46460a901250ec14d41

```
[harness] PASS: 34/34 checks @ 0f95153ae16830e7f71ca46460a901250ec14d41 (clean tree) scope=all
```
`test2`: N/A -- no path in `TWO_PLAYER_PATHS` is touched (`src/server/Boar/`, `tests/server/`).
An earlier run of the same command at the same commit read `FAIL: 33/34` with both suites green
(2651 server / 676 client, 0 failed); the losing check's line was lost from the captured output and
the re-run above is 34/34. It is named here rather than passed over.

## PLAN (core quality protocol)

(a) REAL LIFE: a boar does not stop at a dead one. Karen, 2026-11-01, after playing the range:
*"when animal died in shooting range another one can go tru now it stuck until dead is gone"*.
(b) MEASURED NOW, in her Forest Test at main (`<runs-dir>/324-pass.luau`, 10 Hz): the live body and
the carcass are both `CanCollide = true` in `CollisionGroup "Default"`, so the animal released after
a kill ran into the body -- it stood still 1.02 s at a 5.2-stud gap (the two half-lengths), was
shoved 4 studs off its lane, and crossed the span in 5.23 s against an unblocked 4.05 s. Four of six
natural kills blocked; the two that did not had the body a lane's width off in Z, which is why Karen
sees it some passes and not others. The range's own logic waits for nothing: the next animal was
released +0.00 s after the kill and moved at once, so the carcass id, the count and the spawn are
all refuted as causes -- including 321a(g), whose refused-despawn path never fired here.
(c) TARGET: the crossing within 5% of an unblocked one, for kills at the span's start, middle and
end, with the carcass still lying where it fell.
(d) LEVER: `Body.useCollisionGroup` is the one writer of a body's collision group --
`src/server/Boar/Body.luau`, called from `Body.create` and now from `Body.collapse`:
`grep -n "useCollisionGroup" src/server/Boar/Body.luau` -> the definition plus both call sites.
(e) MEASURED AFTER with the same probe, in the same place, at the code commit.

## Iteration (measure -> change -> re-measure, all in her place)

| # | change | measured | distance to target |
|---|---|---|---|
| 1 | none (main) | stopped 1.02 s at 5.2 studs; 5.23 s vs 4.05 s unblocked (+29%) | the defect |
| 2 | carcass group written in `Body.collapse` | carcass STILL `cg=DrivenHuntBoars`, stopped 0.70 s at 5.5 studs | not fixed: the call read WOUND, which has no `BOAR_COLLISION` |
| 3 | pass `full` (the whole config) at that site | carcass `cg=DrivenHuntCarcass`, `CollisionGroupsAreCollidable(live, carcass)=false`, no stop | met |

## Claims

1. **The cause is contact, not the range's bookkeeping.** `<runs-dir>/324-pass.luau` at main logs
   `NEXT ... released +0.00s after the kill`, the animal moving at once, and the stop only at a
   5.2-5.6 stud gap. Verify: the trace, and that `src/server/Range/init.luau`'s kill branch calls
   `release(trial)` on the same tick it calls `setCarcass`.
2. **`Body.collisionGroupFor` is pure and both dials are reachable by parameter.** Verify:
   `tests/server/boar_model.spec.luau`, "the rule puts a carcass in its own group" -- it asserts all
   four dial states, including the two the shipped config does not sit at.
3. **A real carcass lands in the carcass group, and that group does not collide with the live one.**
   Verify: the same spec's second case kills a boar through `runtime:takeHit` and reads
   `handle.part.CollisionGroup` plus `PhysicsService:CollisionGroupsAreCollidable`. It bites: at main
   the field `CARCASS_GROUP` does not exist and the carcass reads `Default` (argued by reading, and
   measured live -- cycle 2 above failed exactly this way before the fix).
4. **Nothing else about a carcass changed.** Same spec: `CanCollide` is still true, carcass-Default
   and live-Default are both still collidable, so it lies on the ground and still stops the player.
5. **In her place at the code commit, three kills at the span's start, middle and end cross within
   5%**: carcass at span fraction 0.09 / 0.43 / 0.75 -> 4.08 / 4.11 / 3.96 s against same-session
   unblocked crossings of 4.09, 4.12 / 4.21, 4.14 / 4.07, 4.05 s. No stop at the carcass in any of
   them; the only `v < 3` samples are the spawn instant, 33-100 studs away, present at main too.
   Verify: the three traces in the report.
6. **It passes THROUGH the body, not around it.** Two runs with the body put on the animal's own
   line (`<runs-dir>/324-stage.luau`) measured a minimum 3-D centre distance of 1.3 and 0.8 studs --
   two 5.5-stud bodies interpenetrating -- with speed never leaving 24.0 studs/s and zero stopped
   time. Verify: the server traces in the report.
7. **`BOAR_COLLISION.ENABLED` keeps its own meaning.** Live-vs-live is still what that row decides
   (`registerGroups` sets the pair to `ENABLED ~= true`), so task 127's measured no-op is unchanged
   and the carcass rule cannot be switched off with it. Verify: `registerGroups` in Body.luau.

## What I could not verify

- A frame at the instant of interpenetration. `<runs-dir>/324-freeze.luau` anchors both bodies when
  they are within a set distance; at 6.0 studs it fired and `324-through2.png` is the shooter's-eye
  frame (the next animal upright beside the carcass on its side, at the measured 5.51-stud gap --
  the distance at which it stopped dead on main). At 2.6 studs it did not fire in the one window
  spent on it. A capture cannot be timed to a live pass: the range clears the body 3 s after the
  kill, which is shorter than one capture round trip.
- Real keystrokes: the kills were fired through `Shotgun.Remotes.FireRequest` from a client probe,
  and the station was requested through `Range.remotes().RangeRequest`, not by a real E and real
  clicks. The range's own hit path is unchanged by this task.
