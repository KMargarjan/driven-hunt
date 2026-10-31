# Task 317 -- the animal crosses on its lane, in a straight line, at every pace

Task: 317
Round: 2
Base: 84754a5a (main, with 313, 315 and 316 merged)
Code commit: `bbe3fe3c3b50e04dbde025ce3faf1076b001b8ca`

## PLAN (core quality protocol step 0)

**(a) REAL LIFE.** ISSF running boar is a target on a cable: it crosses the opening on ONE line at
one distance and goes behind a wall to come back. The shooter is taught a lead computed from that
one distance, so the distance he picked has to be the distance he shoots.

**(b) MEASURED NOW, at main, in KAREN's place** (Forest Test, placeId 130094961655666, synced from
`driven-hunt-karen` :34873 at `84754a5a`; `DHFlag_RANGE_SOLO=true` read live). New probe
`<runs-dir>/317-lane.luau` -- INSTANCE facts only, the live trunk's `Position` and
`AssemblyLinearVelocity` at Heartbeat, never anchored and never teleported. Station 2, 125 lane:

| pace | legs | worst in-span &#124;Z - lane&#124; | distance he actually shoots | crossing | out of sight between crossings | east overshoot past the apron end |
|---|---|---|---|---|---|---|
| WALK | 1 | 3.80 studs | 128.8 (+3.0 %) | 22.34 s | -- | -2.78 |
| TROT | 1 | 9.18 studs | 134.2 (+7.3 %) | 9.17 s | -- | +0.79 |
| RUN | 2 | 19.72 studs | 144.7 (+15.8 %) | 4.23 s | -- | +5.38 |
| RUN | **6** | **19.01 - 19.91 studs, EVERY leg** | **144.9 (+15.9 %)** | 4.22-4.25 s | **2.63 s mean** | **+9.89** |

Two things 316's whole-trace sampler could not say. First, **the worst sample is at the span EDGE
the animal has just entered** -- 0 %, 1 %, 99 %, 100 % across the span on the six legs, never the
middle: the offset is made at the turn and bled off along the leg. Second, **the turn at RUN leaves
the corridor**: 9.89 studs past the apron end against `BANK.beyondStuds` 6, so it reaches **3.89
studs inside the east bank's near face**.

**(b2) THE RAW TRACE NAMES THE ROOT CAUSE** (`<runs-dir>/317-trace.luau`, cycle 3). The pivot leaves
the animal 3.8 studs off the line and it then runs the whole leg **without converging** (z-lane
+3.77, +3.79, +3.81...). Aimed at a lane end 120 studs away, 3.8 studs is a heading error of 1.8
degrees -- inside `Boar.CONFIG.PACE.TURN_DEADBAND_DEG` (4), so the animal never turns at all.

**(c) TARGET.** Z within +-2 studs of the lane line everywhere inside the span, at WALK, TROT and
RUN, both directions, every station. +-2 on the 125 lane is +-1.6 %, under the quantisation of the
lead the board teaches.

**(d) LEVER -- the writer, pasted.**

    $ grep -n "leadTo\|laneEndsFor\|lookahead" src/server/Range/init.luau
    6:-- `Runtime:leadTo(id, point, speed)` door -- *"WALK TO THIS POINT AT THIS SPEED ...
    1119:		point = RangeData.laneEndsFor(
    1144:			point = RangeData.laneEndsFor(
    1207:		local lookahead = math.max(Range.CONFIG.TURN_AIM_STUDS, speed * Range.CONFIG.AIM_SECONDS)
    1211:	if boars.leadTo(trial.targetId :: string, point, speed) then

`order()` is the one writer of the point and the speed; `Boar.Brain` still decides and `Boar.Body`
still writes. No `.CFrame =`, no anchor, no teleport.

**(e) HOW IT IS MEASURED AFTER.** The same probe, the same place, the same stations.

## STEP 2 -- ITERATE (eight cycles, worst in-span &#124;Z - lane&#124; at RUN, station 2 / 125)

| cycle | change | measured | to target (2.0) |
|---|---|---|---|
| 0 | main | 19.72 | +17.72 |
| 1 | the reversal is walked after the flip | 5.01 | +3.01 |
| 2 | + the exit must be straight, not only on the line | 4.12 | +2.12 |
| 3 | + brake BEFORE the flip, so the arc never starts at 24 studs/s | 3.76 | +1.76 |
| 4 | + a lane-line point a lookahead ahead, in the apron | 2.25 | +0.25 |
| 5 | tighter exit (align 0.3, straight 0.04) | 2.11 | +0.11 |
| 6 | pivot at 2.5 studs/s instead of 4.5 | 1.47 | MET |
| 7 | straightness as an ANGLE, not a per-step distance | 2.19 | +0.19 |
| 8 | **the lane LINE is followed for the whole leg, not just the turn** | **0.77** | **MET** |

Cycle 7 shows the run-to-run spread (+-0.7 studs) that made chasing the exit angle the wrong lever;
cycle 8 removes the cause instead.

## AFTER, at the code commit, in Karen's place (worktree `driven-hunt-294` on rojo :34874)

| station / lane | pace | worst in-span &#124;Z - lane&#124; | distance | crossing (main) | at pace inside |
|---|---|---|---|---|---|
| 2 / 125 | WALK | 0.35 (was 3.80) | 125.4 (+0.3 %) | 22.31 / 22.32 s (22.34) | 100 % |
| 2 / 125 | TROT | 0.40 (was 9.18) | 125.4 (+0.3 %) | 9.13 s (9.17) | 100 % |
| 2 / 125 | RUN | **0.77** (was 19.72) | 125.8 (+0.6 %) | 4.19 / 4.17 s (4.23) | 100 % |
| 2 / 125 | RUN, by REAL E and REAL clicks | **0.89** | 125.9 (+0.7 %) | 4.19 / 4.19 s | 99-100 % |
| 1 / 179 | RUN | 0.84 | 179.8 (+0.5 %) | 4.56 s (4.60) | 100 % |
| 6 / 107 | RUN | 0.77 | 107.8 (+0.7 %) | 2.98 / 2.98 s (3.01) | 100 % |

Every crossing is within **1.1 %** of main's, well inside the 10 % the task allows. Both directions
appear in every multi-leg row. A separate 40 s RUN trace at the code commit gave three legs at
0.56 / 0.75 / 0.88 studs with crossings 4.19 / 4.18 / 4.20 s.

**AND THE COST, MEASURED, BECAUSE NOBODY HAD (review round 1, note 3).** The animal is now **out of
sight for 7.10 s mean (worst 7.19)** between RUN crossings, against **2.63 s** on main -- same
probe, same station, same place. The brake, the pivot and the run-up are all spent in the apron.
The crossing he shoots at is unchanged; the wait between them is 4.5 s longer. **That is a feel
decision and it is Karen's**, and the dial is `TURN_STUDS_PER_SECOND`: cycle 6 measured 4.5 studs/s
at 2.11 studs off the lane -- quicker, and outside this task's +-2.

**T6 AND THE BANKS, as a number and not a claim (L-145). The turn space did not grow, it SHRANK.**
`src/shared/Range/init.luau` is untouched -- `git diff --name-only 84754a5a..HEAD` is two files and
neither is it -- so every T6 input is bit-identical and the sweep case runs green inside the 34/34
PASS. Measured live, as the furthest point past the east apron end against `BANK.beyondStuds` 6:
main's six-leg RUN run reached **+9.89 studs -- 3.89 studs INSIDE the bank's near face**; its
two-leg run reached +5.38 (0.62 studs of clearance). At the fix, RUN reached **-3.26** (**9.26
studs** of clearance), and the worst of every after-row is station 6 / 107 at +0.75, which is
**5.25 studs** of clearance. The turn is further from the bank at every pace and every station.

## What changed

- `src/server/Range/init.luau` -- one `order()` branch and one new local, `turnDone`. The issued
  point is a point ON the lane line one `AIM_SECONDS` ahead, **clamped at the leg's end** so the
  flip and the crossing are untouched; the reversal brakes to `TURN_STUDS_PER_SECOND` and is
  **never honoured inside the span**. Six `CONFIG` numbers, each with its measurement beside it.
- `tests/server/range.spec.luau` -- three new cases, and two existing cases that counted order
  speeds now count the reversal walk instead of refusing it.

Nothing else in `src/` changed. `Range.CONFIG.WAYPOINT_STUDS`, `timeWindow`, `RangeBoard`, the
board's arithmetic, `PACE` and all of the geometry are untouched.

## Harness

    [harness] PASS: 34/34 checks @ bbe3fe3c3b50e04dbde025ce3faf1076b001b8ca (clean tree) scope=all

Karen's Forest Test Studio was open beside DEV for that run, in Edit, never closed, as the dispatch
allows. No intermittent fired in this run at all.

**ONE INTERMITTENT FIRED EARLIER IN THE TASK AND IS NAMED.** A scoped run at the round-1 code commit
(`[harness] FAIL: 32/34 checks @ 20f916093565a5247b165455d13901a63e73b1a1 (clean tree)
scope=auto:range`) failed `deer_hitbox.spec:659`, which the dispatch lists as a known intermittent
(315a(q), 313). It did not recur in the full run at that same commit, nor in the round-2 run above.
**I did not run a merge-base control**: re-running at the same commit is what separates an
intermittent from a regression, and it came back green twice. No range spec failed in any run.

**FAIL FIRST, at a commit that carries the cases and not the whole fix:**

    [harness] FAIL: 32/34 checks @ e5fcaff5363fb3b03ae760f55cd1d7e7d8643257 (clean tree) scope=auto:range
    range.spec:1552, 1612, 1667 -- three failures

That commit is mid-iteration, so its three red lines are not one-to-one with the final cases. What
each case costs when its own half is deleted is argued by READING, in claim 7, and said so there --
including the one round 1 got wrong.

**`test2` is N/A, measured:** `agents.needs_two_player(['src/server/Range/init.luau',
'tests/server/range.spec.luau', 'reviews/task-317/REQUEST.md'])` returns `[]`. No match path.

## Claims

1. **The premise is confirmed and sharpened, measured at main in her place.** Verify: the (b) table
   and `<runs-dir>/317-lane.luau`. The dispatch said the worst is in the MIDDLE of the span; it is
   at the EDGE the animal enters (99 % / 0 % across), and the per-leg instrument is what shows it.
2. **The instrument was validated known-bad before its output was trusted (L-141).** It reproduces
   316's whole-trace numbers on the same runs (drift 39.5 / 18.0 / 10.1 against 316's 38.8 / 19.0 /
   8.9) and reads 19.72 / 9.18 / 3.80 at main, 0.77 / 0.40 / 0.35 at the fix. Verify: both tables.
3. **The root cause is the 4-degree turn deadband, not the apron's length.** Verify:
   `grep -n TURN_DEADBAND_DEG src/server/Boar/init.luau` (4), and the raw trace in (b2) where
   z-lane holds at +3.8 and does not converge.
4. **The fix is at the root and the geometry is untouched.** Verify: `git diff --name-only
   84754a5a..HEAD` is exactly two files; `src/shared/Range/init.luau`, `LAYOUT`, `APRON_STUDS`,
   `WAYPOINT_STUDS` and `timeWindow` are not among the changes.
5. **The turn is outside the span by construction, not by measurement.** Verify: in `order()`,
   `if (trial.turning or braking) and not inSpan(trial, position)` -- the reversal walk cannot be
   issued inside the span, so the crossing cannot be slowed by it. `turnDone`'s first branch after
   the `turning` test is `inSpan` returning true.
6. **The crossings are unchanged.** Verify: the after-table's crossing column against main's, worst
   -1.1 %.
7. **The three cases bite, each on its own half, and round 1's reasoning for two of them was
   wrong.** (a) "issues a point ON the lane line a lookahead ahead" goes red if the lookahead block
   is deleted: the issued point becomes the lane end, and the case asserts `ahead < toEnd`. (b)
   "never orders the animal PAST the lane end, and does order it TO the end" goes red if the CLAMP
   alone is deleted: `past` counts issued points beyond either end and becomes non-zero, because an
   unclamped carrot is `AIM_SECONDS` of run past it. **Round 1's version of this case asked for
   `flips >= 2` and `crossings >= 1`, and the Reviewer was right that both stay true with the whole
   block deleted** -- the flip is tested against `laneEndsFor`, recomputed each scan, never against
   the issued point. (c) "walks the reversal only OUTSIDE the span" goes red if the turn speed is
   deleted (`outsideAtTurn > 0` becomes 0). **Its `insideAtTurn == 0` line convicts nothing** and is
   not claimed to: `turnDone`'s own `inSpan` branch is THE guard, and the code now says so.
8. **Flag-off works the same way and is reached by parameter.** Verify: every span the change reads
   comes from `RangeData.sightSpanFor(..., state.solo)`, so with `RANGE_SOLO` off the same rule
   applies to the 36-stud window. All three new cases pass `solo = true` explicitly; the two edited
   cases run with it off, and they pass.
9. **Proved live in Karen's place at the code commit**, verified by reading the running server's
   `ServerScriptService.Range.Source` (`has turning fix=true`, 89 721 bytes). Real E at station 2
   opened the panel; the RUN chip and RELEASE were real clicks; the board then read **`PACE RUN
   pace 24.0 studs/s issued 24.0 studs/s crossing 4.19 s`** -- the same 4.19 s the sampler measured
   on that trial -- and the label followed a second, different selection (`shotgun / SLUG` ->
   `rifle / .416`).
10. **Rule 5.** `<runs-dir>/317-three-frames.png`, looked at: one camera pinned on the lane centre,
    the boar at the right edge, the middle and the left of the span, same apparent size, same height
    in the frame, broadside. Measured off those pixels: screen height **578.1 / 574.6 / 575.3 px**
    over 292 px of travel -- **3.5 px** of variation. Also `317-cp-7c.png` (the board),
    `317-afterE-c.png` (the panel opened by the real E), `ft-rojo-crop.png` (the FT on :34874).

## What could not be verified

- **A real HIT at RUN was NOT OBTAINED, and the dispatch says it is not required**: 316 measured
  that the aim rig (`DHTestLook`) steers the CAMERA and the shot does not follow it. I did not
  re-spend the window on it.
- **A pre-existing behaviour, not mine, found while proving claim 9 and reported rather than
  fixed:** a pick that changes nothing (`{weapon = "shotgun"}` when the gun is already a shotgun)
  pushes no new board record, so the board can sit on an older one. The first `{weapon = "rifle"}`
  refreshed it at once. Nothing in this task touches `blankRecord`.
- **No merge-base control run for `deer_hitbox.spec:659`** -- see the Harness section.
- **Round 1's non-blocking notes that are NOT addressed here** are queued in `TASKS.md` as 317a:
  the braked 2.5 reaching `RangeBoard`'s `issued` line through `onShotResolved`; the two edited
  cases' counters being decoration; and printing which of `turnDone`'s three exits fired.
- **Karen has played none of this.** Every number above is a probe or a real click of mine.
