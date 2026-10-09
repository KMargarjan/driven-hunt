# Task 136 - the line reads nose-to-tail

Task: 136
Round: 2
Base: main (`58b2565`)
Code commit: `7d1ac3ed2de052eb7c1ca4c31713128136687855`

```
[harness] PASS: 33/33 checks @ 7d1ac3ed2de052eb7c1ca4c31713128136687855 (clean tree) scope=all
```

`test2` is N/A: no path in `TWO_PLAYER_PATHS` is touched (`src/server/ForestTest/`,
`src/shared/ForestTest/` and one server spec).

## ROUND 1'S FINDING WAS REAL, AND IT WAS THE WORST THING IN THE CHANGE

The rejoin-at-the-tail rule had no rank guard, so **the LEADER could be demoted** — reachable by the
central action of this game: shoot at a line and the sow bolts. The step her flight ended she was
moved to the back, `line.trail` follows whoever is `live[1]`, and the next crumb therefore ran
**backwards across the whole gap she had bolted** as one segment; `Line.trim` cut the forward trail
by that same jump, every follower's station leapt onto the backward segment while its hinted `ownS`
stayed on the forward branch, and the file was driven on up the dead flight path. It also handed
`line.route` and `line.leg`, computed for the sow, to a cub.

Rank 1 is now excluded, which is what this request claimed in round 1 and the code did not do. See
the block's own comment in `ForestTest.stepLines`.

## THE TARGETS ARE NOT MET, AND THE HEADLINE ONE CANNOT BE SETTLED BY THIS MEASUREMENT

**Two 150 s traces of the SAME build gave a follower-offset p90 of 1.89 and 4.27 studs.** The
metric's run-to-run spread is larger than the difference this task is trying to measure, so "p90 ≤ 2"
is a bar I can honestly call neither cleared nor missed. Nine traces were run across four builds.

## What changed

1. **`Line.arcAt` remembers where the animal was.** It took the nearest point on the WHOLE polyline,
   and the leader doubles back every time she rounds a trunk — so a follower on the first pass read
   as being on the second. `slack` then went negative (told it had overrun, it stopped) and its aim
   was a point on the far branch (so when it moved it cut across the loop). The search is windowed
   around the last arc position, and falls back to the global one when the hint has fallen off the
   trimmed tail.
2. **`Line.aimFor`**, pure arithmetic: a lookahead along the trail, **never past the one in front**
   (clamped against the arc position measured for the rank ahead, not its station), **never under its
   own feet**, and inside the trail. Round 2: a FLYING animal no longer hands its arc position down
   as "the one in front" — it is declared not to be in the line two dozen lines above.
3. **A follower — never the leader — whose flight has ended rejoins at the TAIL.** It used to keep
   its rank, which is a station up the middle of a file that closed up while it was away.
4. **A wedged LEADER is let go of for 1.5 s**, which was not in the brief and mattered most. A wedged
   follower was already put back on the trail; a wedged leader was handed another route computed from
   the spot she was wedged in, through the trunk she was wedged against. **MEASURED: `Boar6` sat on
   one spot 17 studs north of the road for 110 SECONDS** at an ordered speed of 24 — 464 of that
   run's stuck reports were a handful of animals doing that, each with a file stacked behind it.
   An ordered animal runs no whiskers and no wedge recovery by design (task 127), so dropping the
   order hands her back to `Brain.steerAroundTrunk` and the `stuckTurn` sidestep.

## The table

150 s per run, hunter at his stand, **every wave forced to two lines** by temporary instrumentation
applied identically to every build (removed; the tree at the code commit has none).

**Whole trace**, one column per run:

| build | offset med | offset p90 | gap med | breaks (3×SPACING) | trunk pairs | stuck |
|---|---|---|---|---|---|---|
| baseline, 8.5 | 1.27 / 0.45 / 1.34 | 7.07 / 6.34 / 7.21 | 9.76 / 9.07 / 9.97 | 9.0 / 7.0 / 10.1 % | 50 / 77 / 26 | 15 / 29 / 2 |
| four fixes, 6.5 | 0.69 / 1.99 / 1.13 | 5.83 / 7.93 / 7.01 | 7.82 / 8.00 / 7.86 | 14.1 / 15.5 / 7.5 % | 41 / 55 / 27 | 36 / 9 / 0 |
| **shipped: four fixes, 8.5** | — | — | — | — | 41 / 36 | 20 / 28 |

**Split at the road**, which was not in the brief and is the split that matters. North is the
approach and the crossing — the file Karen watches, and what *"crossing all is spread"* is about.
South is the run-away she asked for in the same breath (*"once they in another side of road they run
away"*), where a file is MEANT to come apart. **54 % of all offset samples are taken south of the
road**, so a whole-trace p90 is half a measurement of something working as designed.

| build | window | offset med | p75 | **p90** | max | gap med | breaks (>25.5 studs) |
|---|---|---|---|---|---|---|---|
| baseline, 8.5 | north | 0.24 | 0.82 | **2.69** | 44.48 | 8.85 | 3.5 % |
| baseline, 8.5 | south | 1.75 | 4.10 | 7.24 | 18.46 | 10.12 | 14.2 % |
| four fixes, 6.5 | north | 0.77 | 1.97 | **4.02** | 16.57 | 7.39 | 4.4 % |
| **shipped, 8.5** | north | 0.23 / 0.42 | 0.65 / 1.72 | **1.89 / 4.27** | 17.07 / 32.55 | 8.79 / 9.15 | 5.5 / 7.7 % |
| **shipped, 8.5** | south | 1.81 / 2.54 | 4.14 / 5.06 | 7.12 / 7.94 | 18.43 / 24.94 | 10.35 / 13.32 | 12.6 / 21.9 % |

## Claims

1. **6.5 SPACING WAS TRIED AND IS NOT SHIPPED.** It closes the gap by a stud and a half and nothing in
   these numbers says the file gets laterally tighter for it; one of the two 8.5 runs says it gets
   looser. 8.5 stays because it is the incumbent and 6.5 did not earn the change — **not** because
   6.5 was shown to be worse, which is what round 1's comment claimed from the better of two runs
   (round 2, the Reviewer's note). The config comment now carries both runs and that reading.
2. **The worst case is what moved.** North-window offset max 44.48 → 17.07 / 32.55. Trunk contact
   pairs: baseline 50 / 77 / 26 / 80 → 41 / 36 / 41 / 55 / 27 across the fixed builds. Circle windows
   (most degrees any animal turned in 10 s) 1338 → 1173 / 1195: not worse.
3. **Stuck is NOT zero and I do not claim it is.** Baseline 15 / 29 / 2 / 18; shipped 20 / 28. The
   110-second frozen leader has not recurred in any traced run since the fix, and neither has the
   464-report run.
4. **Item 1 of the brief was already true, and I claim no credit for it.** `Brain`'s whisker block is
   `if obs.whisker ~= nil and not ordered`, written in task 127 with that reasoning. Every line member
   is ordered every Heartbeat, so no follower whiskers while the line walks. What this task found is
   the hole at the other end: the LEADER is ordered too, so she had no wedge recovery either.
5. **The spec drives the new rules without a world.** `forest_line.spec`: a trail that doubles back,
   where the unhinted search answers with the far branch and the hinted one stays where the animal is;
   a hint that has fallen off the trimmed tail still answers; and `Line.aimFor`'s four rules one at a
   time, including the one whose absence turned 15 stuck into 58.
6. **PLAYTEST.md was not added to.** Karen's two lines quoted in the dispatch are already transcribed
   there, in the 2026-10-05 (5) row that task 127 was dispatched from.

## The frame (rule 5), and it is the honest part

`.screenshots/t136-look-2.png` and `t136-look-3.png`, from the stand, animals at 36–40 studs, the
view turned by the camera's own `LookAtRequest` seam.

**Two frames were wrong first.** `capture`'s camera/look-at arguments do not move the view during
Play, so the first pair pointed wherever the character happened to be facing, with the animals at the
right-hand edge and mostly out of shot.

**It still does not read as a tight nose-to-tail file, and the brief asked me to say so.** In
`t136-look-2.png` three animals are strung out along the road's edge with a fourth well ahead down
the road — a file, but with an obvious break between the leader and the rest. In `t136-look-3.png`,
with ten animals near, four read as a **loose cluster two abreast** on the road. That is a band.

## What could not be verified

- **The headline target.** Two runs of the same build gave 1.89 and 4.27, so neither "met" nor
  "missed" is supportable. A longer trace, or a per-wave rather than per-sample statistic, would
  settle it; this one cannot.
- **Breaks ≤ 5 %** is met on no build in no window except the baseline's north (3.5 %); the shipped
  build's north is 5.5 % and 7.7 %. The bar moves with SPACING by definition, which is why the table
  also carries a fixed 25.5-stud column.
- **The round-2 fix is not separately measured under fire.** No animal flew in any of the nine
  traces — which is exactly why round 1 shipped the bug — so the rank guard is reasoned and reviewed
  rather than measured. What was run instead: an 85 s Forest Test smoke **with seven shots fired at
  the lines through the real `FireRequest` route**, after which all four wave reports still read
  `N of N animal(s) in M of M line(s)` and the console carried no fault. A trace that shoots and then
  measures the trail is the right follow-up and is queued.
- **The "≤ 3 sounds" part of the smoke was not measured.** No voice warning appeared in any run, but
  I counted no simultaneous voices, so I report no number.
- **Standing rule A, Forest Test, 85 s, with shooting:** the Tool in the CHARACTER at 15 s and at the
  end (`tool=true backpack=false` both), **0 fault lines in 24**, and four wave lines released at a
  walk, a trot and a run, 1 and 2 lines per wave — the feature this task changed, running.
