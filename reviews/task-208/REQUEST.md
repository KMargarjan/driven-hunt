# Task 208 — the bot beaters do not get stuck

Task: 208
Round: 1
Base: main @ `db2822a`
Code commit: `489695bbc812cae0b422eb3469361d7b94270d72`

Harness, clean tree, FULL run (the merge-gate line):

```
[harness] PASS: 33/33 checks @ 489695bbc812cae0b422eb3469361d7b94270d72 (clean tree) scope=all
```

Scoped run at the same tree's code commit, for the record:

```
[harness] PASS: 33/33 checks @ b198758cf5364b1127bd75ded0a8d8355b16b5f0 (clean tree) scope=auto:bots,match
```

`test2`: **N/A.** Nothing this task touches is in `TWO_PLAYER_PATHS`. The change is
`src/server/Bots/`, `src/server/ForestTest/init.luau`, `src/server/ForestTestBoot.server.luau`, two
server specs and two docs; that list is `src/server/Match/`, `MatchBoot`, `src/client/Match/`,
`src/shared/Drive/`, `tests/client/Role.luau` and the named match specs. (`src/server/ForestTest/`
maps to the `match` SCOPE — a different table, which decides which specs a scoped run plays.)

## What changed, and why

Karen, 2026-10-18 ~14:20: *"bot beater stuck we definatly need to fix that they not stuck the can
avoid"* — and, in the same message, *"do not try to fix forest, we will go together ... we will fix
terrai together"*. **No tree, no terrain and no place is touched.**

**Step 1 was a measurement** (`docs/research/2026-10-19-bots-unstuck.md` §4): one full drive in each
of the four places in her own Forest Test, entered through the truck pad the way she enters it, every
rig sampled at 2 Hz. **Four episodes over three seconds, the worst 169.1 s** — which hung the whole
drive, because a drive ends when the beater line is through, so it ran out its clock instead.

**What they were stuck on, measured, not guessed:** two were a beater pressed against an **anchored
bot hunter** standing on the stand its own lane aims 20 studs past (0.3 studs apart in x); the
169-second one was a **planted spruce trunk 3.8 studs in front of it**, named by a live `Blockcast`
at the spot. Not terrain (one stud of rise in twenty), not a slope, not water, not a marker.

**Three defects, one fix each, all borrowed** (§2): the clearance reader cannot see a body *by
design*; it samples the destination rather than the path; and the recovery was computed five times a
second and issued every two, so nine in ten decisions — every stuck nudge among them — were thrown
away before the humanoid saw them.

## Claims

1. **The defect was measured before anything changed, as a position trace read as numbers**, and the
   instrument's own two blind spots were found and fixed first. Verify: note §4.1–4.3; traces
   `<runs-dir>/208-before-{road,edge,ride,track}-trace.json`. §4.1 records that
   `Humanoid.MoveDirection` reads **0.000** on the server for a bot walking under `MoveTo` (so it
   cannot define "en route"), and that a permanent pin at the end of a walk looks exactly like an
   arrival until the distance to the goal is checked.

2. **The 28 new cases FAIL against the pre-fix commit**, and that run is kept:
   `<runs-dir>/208-prefix-harness-FAIL.txt` — `[server] 1638 passed, 27 failed, 27 errors` with
   `src/` stashed and the specs in place (one case was added after that run). Verify: that file
   against the `it(...)` blocks added to `tests/server/bots_lane.spec.luau` and
   `tests/server/bots_live.spec.luau`.

3. **Every branch of the recovery ladder has a case that enters it**: `jump`, `sidestep`, `backoff`,
   `boxed in`, the no-reader (DEV arena) branch, the still-held branch, and the case for a defect
   this task would otherwise have shipped (see claim 10). Verify: `bots_lane.spec` describe *"the
   recovery ladder (task 208)"*; `bots_live.spec` describe *"a bot that is pinned (task 208)"*.

4. **A decision reaches the humanoid the moment it changes.** `stepWalker` issues `MoveTo` when the
   aim moves more than `AIM_EPSILON_STUDS`, and still re-issues on `MOVE_REISSUE_SECONDS` for the
   engine's documented 8-second timeout. Verify: `stepWalker`'s last block; the case *"TELLS THE
   HUMANOID somewhere new as soon as it is pinned, not on the next re-issue"*, which moves the clock
   1.0 s — past the fast stuck window, inside the re-issue interval — so the old cadence could not
   have issued anything.

5. **A recovery is HELD**, and `RECOVER_HOLD_SECONDS` (2.2) is asserted to be at least
   `SIDE_STEP_STUDS / WALK_SPEED` (2.0) as a relation rather than written in a comment. Verify:
   `Bots.CONFIG`; the cases *"HOLDS that decision instead of aiming back into the thing on the next
   step"* and *"holds the recovery for longer than the sidestep it committed to takes to walk"*.

6. **The walk can now SEE a body, and that is the half no cast can do.** `ForestTest.laneAhead`
   sweeps a body-sized `Blockcast` down the lane AND measures the players' characters and
   `Workspace.DriveBots`' rigs by distance — because `Bots.Rig.prepare` sets `CanQuery = false` on
   every rig part, so every spatial query in the engine skips exactly the obstacle the measurement
   found most of. A body's reported step height is above `JUMP_OVER_STUDS`, so a person is always
   gone round and never jumped over. Verify: `ForestTest.laneAhead`, `Rig.prepare`'s `CanQuery` line,
   note §4.2.

7. **The owner boundary is unchanged.** `Bots` still reads no marker, tag, Player or flag; the new
   reader is INJECTED by `ForestTestBoot` beside `groundAt` and `roomToStand`; `Bots.Lane` stays
   pure; `src/server/Match/` is not touched at all. The DEV arena injects no `laneAhead` and behaves
   as it did. Verify: `ForestTestBoot`'s `Bots.start({...})`, `Bots.step`'s `seeing` local, the case
   *"spends NO cast at all in a world with no reader, which is the DEV arena"*.

8. **The line is still the feature.** A detour is a DEFLECTION of the lane that keeps the aim
   `AHEAD_STUDS` out and never past the goal, held 1.2 s and then resumed; `PathfindingService` is
   refused again with the measurement as the reason. Verify: `Lane.turnedAim`, `Lane.detourAim` and
   their cases; note §2.4.

9. **AFTER: zero stuck episodes of ANY length, in all four places, over sixteen beater walks** —
   against four over three seconds totalling 224.6 s before. Every bot reached its goal (1.3–15.4
   studs out; the track's pinned bot had ended **238.8 studs short**). It works mostly by NOT getting
   stuck: **100 detours across the four drives against TWO recoveries**, and those two fired two
   different rungs in the field (a sidestep on the ride, a **jump** on the track). Verify: note §8
   and §8.1; traces `<runs-dir>/208-after-{road,edge,ride,track}-trace.json`; the four `[bots]` lines
   in `<runs-dir>/208-after-*.log`.

10. **Two defects of my own, found by the first gate run and fixed in `b198758`.** (a) the point test
    could THROW THE DETOUR AWAY — `Lane.clearAim` recomputes from the plain lane point, so letting it
    speak after a deflection aimed the bot back at the trunk it had just decided to go round; it is
    now skipped on a step that deflected, with its own case. (b) the four-second window no longer
    nudges and the comment that said it did was false — the fast window is strictly more sensitive
    (3 studs in 4 s is 0.75 studs/s, below `STUCK_SLOW_SPEED` 1.0), so `STUCK_SECONDS` is now purely
    the number `[bots]` prints. Verify: that commit; the case *"does NOT let the point test throw the
    detour away"*; the re-pointed round-2 case *"MOVES a bot that has stopped, WITH A READER THAT
    SAYS THE WAY IS CLEAR"*.

## What could not be verified, and what is left

* **The AFTER frame is not the same trunk as the 169-second pin.** Lanes are dealt from whichever
  stand the drive aims at, so no beater walked that spruce's x again. The frames
  (`<runs-dir>/208-after-track-trunk-{1,2,3}.png`, camera at the player's eye y 178.0 against the
  bot's root 177.0) show two bot beaters standing clear in the open 11.6 studs from a larch trunk on
  the same planted ground; the closest any beater came to a planted trunk in that drive was 10.7
  studs. The before/after claim rests on the TRACE, not on the picture — said plainly in note §8.3.
* **The 8-walker cost is scaled from a measured 4-walker delta**, not measured at 8: the shipped
  targets are 4 + 4 and a solo player leaves four walkers. +0.023 ms per walker per step measured
  (note §8.2), so ~0.19 ms for eight against the 200 ms a step is allowed.
* **`docs/design/bots.md` §9.1 now describes the old walk.** The Builder does not write designs
  (CLAUDE.md role table), so the delta is the Architect's. Queued as TASKS.md 208a.
* **The hunters' stands sit exactly in the beaters' lanes, by construction** — measured, note §8.4.
  The walker now steps round them, which also covers Karen standing there; moving the LANES is
  `src/server/Match/` and `src/shared/ForestTest/` (`TWO_PLAYER_PATHS`) and a question about what a
  drive should look like, which is hers. Queued as TASKS.md 208b, not taken here.
* **Not Karen's eye.** Whether a beater stepping round a hunter READS right is hers.
