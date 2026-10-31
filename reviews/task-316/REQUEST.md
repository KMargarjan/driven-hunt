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
