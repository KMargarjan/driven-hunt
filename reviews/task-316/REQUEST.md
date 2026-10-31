# Task 316 -- the animal holds its pace over the whole wide range

Task: 316
Round: 1
Base: f06f9358 (main, with 313 solo and 315 range-from-shop merged)
Code commit: (filled in below, after the harness line)

## PLAN (core quality protocol step 0)

**(a) REAL LIFE.** Not a real-life question. The lane is ISSF running-boar: a pace is a constant
ground speed and the crossing of a span of known width is that width divided by that speed.

**(b) MEASURED NOW -- THE DISPATCH'S PREMISE IS REFUTED.** In KAREN's place (Forest Test,
placeId 130094961655666, synced from rojo :34873 = `driven-hunt-karen` at `f06f9358` = main),
`DHFlag_RANGE_SOLO=true` read live out of a session booted for this task (L-164). Probe
`<runs-dir>/316-sample2.luau` -- INSTANCE facts only (the live trunk's `Position` and
`AssemblyLinearVelocity` at Heartbeat, ~36-48 Hz), never an anchored or teleported animal (L-147).
Every cell, not only the ones that agree (L-143):

| station | lane | pace | issued | wide span | crossing measured | span/issued | delta | samples >= 95 % of issued |
|---|---|---|---|---|---|---|---|---|
| 2 | 125 | walk | 4.50 | 100.33 | 22.33 s (2) | 22.30 s | **+0.1 %** | 100 % |
| 2 | 125 | trot | 11.00 | 100.33 | 9.14 s (2) | 9.12 s | **+0.2 %** | 100 % |
| 2 | 125 | run | 24.00 | 100.33 | 4.24 s (3) | 4.18 s | **+1.3 %** | 100 % |
| 2 | 125 | run (real E + real menu clicks) | 24.00 | 100.33 | 4.22 s (3) | 4.18 s | **+1.0 %** | 100 % |
| 2 | 125 | fast | 14.40 | 100.33 | 7.00 s (2) | 6.97 s | **+0.5 %** | 100 % |
| 2 | 179 | slow | 7.20 | 133.47 | 18.53 s (1) | 18.54 s | **-0.0 %** | 100 % |
| 1 | 179 | run | 24.00 | 109.47 | 4.60 s (3) | 4.56 s | **+0.9 %** | 97-100 % |
| 1 | 107 | run | 24.00 | 71.07 | 3.01 s (5) | 2.96 s | **+1.5 %** | 100 % |
| 6 | 107 | run | 24.00 | 71.07 | 3.01 s (5) | 2.96 s | **+1.5 %** | 100 % |
| 6 | 179 | run | 24.00 | 109.47 | 4.59 s (3) | 4.56 s | **+0.6 %** | 100 % |

The boar is at its ordered ground speed for **100 %** of the samples inside the span at every cell
but two (station 1 at 179: 97 % and 98 % on two of three crossings, minimum 15.2 studs/s for a few
frames mid-span -- reported, not dropped). It does not accelerate inside the span: the `ACCEL` ramp
is spent in the 20-stud apron.

**INSTRUMENT VALIDATED BEFORE ITS OUTPUT WAS TRUSTED (L-141).** The same trace is timed against two
geometries at once -- the wide solo span and the shipped 36-stud window, the known-good leg. The
sampler separates them correctly in every run (station 2 / 125 / run: 4.24 s over 100.33 studs AND
1.52 s over 36.00 studs, both +1.3-1.5 %), and it arms by being outside first, exactly as
`timeWindow` does -- without that it timed a partial pass as a whole one and read -39 %.

**(b2) AND THE 9.13 s IS REPRODUCED EXACTLY -- AS A TROT.** `100.33 / 11.00 = 9.12 s`, measured
**9.14 s**. Task 313's "before" 3.25 s is the same thing on the narrow window: `36 / 11 = 3.27 s`,
measured **3.27 s**. Both of 313's numbers are the trial's DEFAULT pace (`Range.CONFIG.DEFAULT_PACE`
is `trot`) and neither is a run.

**(c) THE DEFECT THAT IS REAL, found by reproducing the dispatch's own case on her path.** The board
prints a crossing measured under the PREVIOUS pace beside the NEW pace's word and speed. Live, in
her place, through the real remote, at the code commit's parent: after a RUN trial had crossed, one
`{pace = "walk"}` pick answered

    board reply: pace=walk dist=125 issued=4.5 crossing=4.153548300033435

-- `4.15 s` is a RUN crossing of that span (target 4.18), printed under `WALK / 4.5 studs/s`. **That
is the whole of the 9.13 s report**: a crossing measured at one pace survives the pick and is read
as the new pace's.

**(d) LEVER -- the writer, pasted.**

    $ grep -n "lastCrossingSeconds" src/server/Range/init.luau
    124:	lastCrossingSeconds: number?,
    303:		lastCrossingSeconds = nil,
    1054:			trial.lastCrossingSeconds = seconds
    1324:		crossingSeconds = trial.lastCrossingSeconds,
    1638:		record.crossingSeconds = trial.lastCrossingSeconds
    1927:			trial.lastCrossingSeconds = nil

`Range.setPace` already clears `windowEnteredAt`, `windowLeg`, `windowArmed`, `standSeconds`,
`legDrawn` and `drewWord`; `Range.setDistance` clears the first three when the lane changes; the
species/kind respawn at 1927 clears `lastCrossingSeconds`. **The pace change and the lane change do
not**, and `blankRecord` (1324) copies it into the fresh record a pick makes.

**(c2) TARGET.** After a pace change, and after a lane change, the board prints **no** crossing
until one has been measured under the pace and the lane it is labelled with. `RangeBoard.luau`
already omits the clause when `crossingSeconds` is nil, so no client change and no new wording.

**(e) HOW IT IS MEASURED AFTER.** The same probe (`316-sample2.luau`) and the same live board read.

## What changed

Two lines of state, at the root, in the two functions that already disarm the window timer. The
board's arithmetic is untouched, `PACE` is untouched, the geometry is untouched.

Code commit: `089cafed7cb5896a372829fc025d1d76b6d9535d`

- `src/server/Range/init.luau` -- `Range.setPace` and `Range.setDistance` each clear
  `trial.lastCrossingSeconds`, beside the window disarms they already did. Nine lines, seven of
  them comment. Nothing else in `src/` changed.
- `tests/server/range.spec.luau` -- one case, next to task 303's sibling case.

## Harness

    [harness] PASS: 34/34 checks @ 089cafed7cb5896a372829fc025d1d76b6d9535d (clean tree) scope=all

Karen's Forest Test Studio was open beside DEV (Edit, never Play) for that run, as the dispatch
allows; nothing of hers was closed. **No intermittent fired** -- not `weapon_shot.spec:1490`, not
`deer_hitbox.spec:659/:682`, not `weapon_client.spec:1211/:1263`, not the 312(a) boar spec. 2591
server and 664 client assertions, 0 failed, 0 errors.

**`test2` is N/A, measured, not asserted:** `agents.needs_two_player(['reviews/task-316/REQUEST.md',
'src/server/Range/init.luau', 'tests/server/range.spec.luau'])` returns `[]`.

**FAIL FIRST, at a commit that contains the case and not the fix**, covering
`picked.crossingSeconds` after a RUN pick over a trot crossing:

    [harness] FAIL: 32/34 checks @ 694e8188ee1b3b275dd8a7aaee30a9fa51d8ab81 (clean tree) scope=auto:range
    ServerStorage.Tests.range.spec:1646  Expected value "nil" (nil), got "3.2666666666666555" (number)
    [tests:server] FAIL: 2590 passed, 1 failed, 0 skipped, 1 errors, 77 spec files

3.2667 s is `WINDOW_STUDS 36 / 11.03` -- the trot, under RUN. It is also task 313's own "before"
number, 3.25 s.

## Claims

1. **The dispatch's premise is refuted and the measurement is in `## PLAN (b)`.** Ten cells, every
   one reported. Verify: the table, and `<runs-dir>/316-sample2.luau`, which reads only the live
   trunk's `Position` and `AssemblyLinearVelocity` -- no anchored and no teleported animal.
2. **The instrument was validated before its output was trusted.** Every run times the same trace
   against the wide span AND the shipped 36-stud window and separates them correctly (4.24 s / 1.52 s
   at station 2 / 125 / RUN, both +1.3-1.5 %). Verify: any `WIDE`/`NARROW` pair in the table.
3. **9.13 s is a TROT.** `100.33 / 11 = 9.12 s`, measured 9.14 s, in her place. Verify: the
   `trot` row of the table, and the live line `2 a pick that changes NEITHER pace nor lane:
   pace=trot issued=11.0 studs/s dist=125 crossing=9.13 s` at the code commit.
4. **The real defect: a crossing survived the pick.** Verify: `grep -n lastCrossingSeconds
   src/server/Range/init.luau` -- `blankRecord` (the `crossingSeconds = trial.lastCrossingSeconds`
   line) is fed by a field that `setPace`/`setDistance` did not clear.
5. **The fix is at the root and not in the board's arithmetic.** Verify: the diff is two
   assignments in `Range.setPace` and `Range.setDistance`; `src/client/Hud/RangeBoard.luau`,
   `Range.CONFIG`, `Boar.CONFIG.PACE` and all of the geometry are untouched.
6. **`RangeBoard` already draws nil as nothing.** Verify: `RangeBoard.luau`'s `PACE` line --
   `if record.crossingSeconds ~= nil then ... else ""`. No client change, no new wording.
7. **The case fails on `f06f9358` and passes on the fix, and it is not vacuous.** Its control arm
   (`{weapon = "rifle"}`, a pick that changes neither pace nor lane) asserts the record DOES still
   carry the crossing, so the field is live; delete either new `src` line and the case goes red.
   Verify: the two harness lines above.
8. **Flag-off (`RANGE_SOLO` off) is bit-for-bit.** Verify: neither changed function reads
   `state.solo` or any span; `grep -n solo src/server/Range/init.luau` shows no hit in `setPace`
   or `setDistance`.
9. **Proved live in Karen's place, at the code commit** (Forest Test on the `driven-hunt-294`
   worktree checked out to `089cafed`, rojo :34874, verified by reading
   `ServerScriptService.Range.Source` in the running server: *"Range source carries task 316: true"*).
   Four picks through the real remote: TROT -> `crossing NONE`; neither-pace-nor-lane ->
   `trot 11.0 studs/s crossing 9.13 s`; RUN -> `run 24.0 studs/s crossing NONE`; one RUN crossing
   later -> `run 24.0 studs/s crossing 4.23 s`. On `f06f9358` the third line read the trot's seconds.
10. **Rule 5.** `<runs-dir>/316-after-boards.png`, looked at: the range menu's BOARD panel at the
    code commit reading `PACE RUN  pace 24.0 studs/s  issued 24.0 studs/s  crossing 4.22 s` over
    `DISTANCE 125 studs (35 m)`. The before-frames are `316-click-4s.png` (`crossing 4.21 s`) and
    `316-click-1s.png` (the real E menu with `PACE SLOW ... crossing 18.61 s`).

## What could not be verified

- **A real HIT at RUN was NOT OBTAINED, and the reason is measured, not guessed.** 25 real
  left-click shots resolved through the real weapon path at a RUN target at 125 studs, every one
  scored MISS, gap 0.3-26.4 m and always *ahead*; the aim instrument is `DHTestLook`, which steers
  the CAMERA, and the shot did not follow it to within the animal's 5.5-stud length. Tried, in
  order: `<runs-dir>/clickfast.ps1` at the viewport centre, `316-fire.ps1` (ADS held), `316-fire2.ps1`
  (re-focus per shot), a look tracking the live trunk, a look lagged 0.12 s, and a fixed aim point on
  the measured eastbound pass. `17b-fire.ps1` is the repo's existing single-shot script and is the
  same mechanism. **Nothing in this task's fix is about the shot** -- the board's crossing is the
  claim and it is proved six times on screen -- but the hit card the dispatch asked for is not here.
- **The Z DRIFT, reported and NOT fixed** (new, found by this measurement, out of this task's
  scope): at RUN the target wanders **38.8 studs in Z** about a lane centre of -3215 -- on the
  125-stud lane it is between 106 and 144 studs from the shooter, +-15.5 %, while the board teaches
  a lead computed from 125. At TROT the drift is 19.0 studs, at WALK 8.9. It is the turn-around arc:
  the animal is exactly on the lane at each leg end and furthest off it in the middle of the span,
  so the 20-stud apron is shorter than a RUN reversal needs. It costs the crossing only 1.5 %
  (`|dx|/t` 23.6 against a ground speed of 24.00), which is why every cell above still passes.
