# Task 136 - the line reads nose-to-tail

Task: 136
Round: 1
Base: main (`58b2565`)
Code commit: `2a5e9dacd6f01118d9f08e3504e0d1f0c858e32c`

```
[harness] PASS: 33/33 checks @ 2a5e9dacd6f01118d9f08e3504e0d1f0c858e32c (clean tree) scope=all
```

`test2` is N/A: no path in `TWO_PLAYER_PATHS` is touched (`src/server/ForestTest/`,
`src/shared/ForestTest/` and one server spec).

## THE TARGETS ARE NOT MET, AND THE HEADLINE ONE CANNOT BE SETTLED BY THIS MEASUREMENT

Read this before the claims. **Two 150 s traces of the SAME build gave a follower-offset p90 of 1.89
and 4.27 studs.** The metric's run-to-run spread is bigger than the difference this task is trying to
measure, so "p90 ≤ 2 studs" is not a bar I can honestly say was cleared or missed. Nine 150 s traces
were run (three baseline, six across three candidate builds) and the spread is in the table.

What IS stable across every run is in the second table: the worst-case offset, the trunk contacts and
the 110-second frozen leader.

## What changed

Four changes, all in the Forest Test's line drive.

1. **`Line.arcAt` remembers where the animal was.** It took the nearest point on the WHOLE polyline,
   and the leader doubles back every time she rounds a trunk -- so a follower on the first pass read
   as being on the second. `slack` then went negative (it was told it had overrun, and stopped) and
   its aim was a point on the far branch (so when it moved it cut across the loop). The search is now
   windowed around the animal's last arc position, and falls back to the global search when the hint
   has fallen off the trimmed tail.
2. **`Line.aimFor`**, pulled out as pure arithmetic: a lookahead along the trail, **never past the one
   in front** (clamped against the arc position measured for the rank ahead, not its station), and
   **never under its own feet**.
3. **A follower whose flight has ended rejoins at the TAIL of its line.** It used to keep its rank,
   which is a station up the middle of a file that closed up while it was away -- so it walked across
   the line to reach it.
4. **A wedged LEADER is let go of for 1.5 s.** This is the one that mattered most and it was not in
   the brief. A wedged follower was already put back on the trail; a wedged leader was handed another
   route computed from the spot she was wedged in, through the trunk she was wedged against.
   **MEASURED: `Boar6` sat at one point 17 studs north of the road for 110 SECONDS** with an ordered
   speed of 24, and 464 of that run's stuck reports were a handful of animals doing exactly that --
   with a whole file stacked behind each of them, never crossing. An ordered animal runs no whiskers
   and no wedge recovery by design (task 127); dropping the order for a moment hands her back to
   `Brain.steerAroundTrunk` and the `stuckTurn` sidestep, both of which are gated on `not ordered`.

## The table

150 s per run, hunter at his stand, **every wave forced to two lines** by temporary instrumentation
applied identically to every build (removed; the tree at the code commit has none).

**Whole trace**, one row per run:

| build | offset med | offset p90 | gap med | breaks (3xSPACING) | trunk pairs | stuck |
|---|---|---|---|---|---|---|
| baseline, 8.5 | 1.27 / 0.45 / 1.34 | 7.07 / 6.34 / 7.21 | 9.76 / 9.07 / 9.97 | 9.0 / 7.0 / 10.1 % | 50 / 77 / 26 | 15 / 29 / 2 |
| all four fixes, 6.5 | 0.69 / 1.99 / 1.13 | 5.83 / 7.93 / 7.01 | 7.82 / 8.00 / 7.86 | 14.1 / 15.5 / 7.5 % | 41 / 55 / 27 | 36 / 9 / 0 |
| **shipped: all four, 8.5** | — | — | — | — | 41 / 36 | 20 / 28 |

**Split at the road**, which is the split that matters and was not in the brief. North of it is the
approach and the crossing -- the file Karen watches, and what *"crossing all is spread"* is about.
South of it is the run-away she asked for in the same breath (*"once they in another side of road
they run away"*), where a file is MEANT to come apart. **54 % of all offset samples are taken south
of the road**, so a whole-trace p90 is half a measurement of a thing that is working as designed.

| build | window | offset med | p75 | **p90** | max | gap med | breaks (>25.5 studs) |
|---|---|---|---|---|---|---|---|
| baseline, 8.5 | north | 0.24 | 0.82 | **2.69** | 44.48 | 8.85 | 3.5 % |
| baseline, 8.5 | south | 1.75 | 4.10 | 7.24 | 18.46 | 10.12 | 14.2 % |
| four fixes, 6.5 | north | 0.77 | 1.97 | **4.02** | 16.57 | 7.39 | 4.4 % |
| **shipped, 8.5** | north | 0.23 / 0.42 | 0.65 / 1.72 | **1.89 / 4.27** | 17.07 / 32.55 | 8.79 / 9.15 | 5.5 / 7.7 % |
| **shipped, 8.5** | south | 1.81 / 2.54 | 4.14 / 5.06 | 7.12 / 7.94 | 18.43 / 24.94 | 10.35 / 13.32 | 12.6 / 21.9 % |

## Claims

1. **6.5 SPACING WAS TRIED AND MEASURED WORSE, so it is not shipped.** On the north window it took the
   offset p90 from 2.69 to 4.02 and the p75 from 0.82 to 1.97 -- more than twice as loose laterally --
   while closing the gap by a stud and a half. Thirteen animals in two thirds of the length have two
   thirds of the room to settle in. The number stays 8.5 and `LINE.spacingStuds`' comment carries that
   table, so nobody tries it a third time without a reason.
2. **The worst case is what moved, and it moved a lot.** North-window offset max: baseline 44.48 ->
   17.07 and 32.55. Trunk contact pairs: baseline 50 / 77 / 26 / 80 -> 41 / 36 / 41 / 55 / 27 across
   the fixed builds. Circle windows (most degrees any animal turned in 10 s): 1338 -> 1173 / 1195,
   not worse.
3. **Stuck is NOT zero and I will not claim it is.** Baseline 15 / 29 / 2 / 18; shipped 20 / 28. The
   110-second frozen leader is gone from every traced run since the fix, and the 464-report run has
   not recurred, but the counter still fires.
4. **Item 1 of the brief was already true before this task, and I am not claiming it.** `Brain`'s
   whisker block is `if obs.whisker ~= nil and not ordered`, written in task 127 with that reasoning in
   its comment. Every line member is ordered every Heartbeat, so no follower runs whiskers while the
   line is walking. What this task found instead is that the rule has a hole at the other end: the
   LEADER is ordered too, so she has no wedge recovery either -- claim 4 of "what changed".
5. **The spec drives the new rules without a world.** `forest_line.spec`: a trail that doubles back,
   where the unhinted search answers with the far branch (> 40) and the hinted one stays where the
   animal is (within 2 of 10); a hint that has fallen off the trimmed tail still answers; and
   `Line.aimFor`'s four rules one at a time, including the one whose absence turned 15 stuck into 58.
6. **PLAYTEST.md was not added to.** Karen's two lines quoted in the dispatch are already transcribed
   there, in the 2026-10-05 (5) row that task 127 was dispatched from. A second copy would be a second
   record of one thing.

## The frame (rule 5), and it is the honest part

`.screenshots/t136-look-2.png` and `t136-look-3.png`, from the stand, animals at 36-40 studs, the
view turned by the camera's own `LookAtRequest` seam.

**Two frames were wrong first.** `capture`'s camera/look-at arguments do not move the view during
Play, so the first pair came out pointing wherever the character happened to be facing with the
animals at the right-hand edge, mostly out of shot.

**It still does not read as a tight nose-to-tail file, and the Director asked me to say so.**
In `t136-look-2.png` three animals are strung out along the road's edge with a fourth well ahead down
the road -- a file, but with an obvious break between the leader and the rest. In `t136-look-3.png`,
with ten animals near, four of them read as a **loose cluster two abreast** on the road, not a line.
That is a band.

## What could not be verified

- **The headline target.** See the top: two runs of the same build gave 1.89 and 4.27, so neither
  "met" nor "missed" is a statement I can support. A longer trace, or a trace that reports per-wave
  rather than per-sample, would settle it; this one cannot.
- **Breaks ≤ 5 %** is not met on any build in any window except the baseline's north (3.5 %), and the
  shipped build's north is 5.5 % and 7.7 %. Note the bar moves with SPACING by its own definition,
  which is why the table also carries a fixed 25.5-stud column.
- **The "≤ 3 sounds" part of the smoke was not measured.** The console carried no voice warning in any
  run, but I did not count simultaneous voices, so I am not reporting a number for it.
- **Standing rule A, Forest Test, 85 s:** the Tool in the CHARACTER at 15 s and at the end
  (`tool=true backpack=false` both), **0 fault lines in 24**, and four wave lines released -- 1 and 2
  lines per wave, walk, trot and run, which is the feature this task changed running.
