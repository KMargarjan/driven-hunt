# Task 334 round 3 -- one bound per crossing: the arm is SPENT, and the case counts every burst

Task: 334
Round: 3
Base: main
Code commit: ea2c0370176c13657477e7df18c76752fa124428

```
[harness] PASS: 34/34 checks @ ea2c0370176c13657477e7df18c76752fa124428 (clean tree) scope=all
```
`test2`: N/A. Nothing in `TWO_PLAYER_PATHS` is touched -- `src/server/Boar/Brain.luau`,
`src/server/Boar/init.luau`, `tests/server/deer.spec.luau`, `docs/research/`. Animal behaviour
needs the one-player line only (Director, 2026-10-03), for the PR to `main` as well.

Scope: the Director's ROUND 3 AUTHORISED decision in `ESCALATE.md` (2026-11-06 ~20:40 UTC), items
1-5. `docs/design/` and `Body.driveForce` are untouched, as that decision says.

## PLAN (core quality protocol, step 0)

- **(a) REAL LIFE.** A bound is the gait where all four feet leave the ground together, used to clear
  an obstacle (Lingle 1993, `docs/research/2026-10-23-deer-road-leap.md` section 8). A deer crossing
  a road makes ONE of them, not two off the same tarmac -- Karen's *"once per crossing"*.
- **(b) MEASURED NOW** (before this commit, the state round 2 left): round 2's guard refuses a
  refresh while `_leapFor > 0`, so the refresh lands on the tick `_leapFor` reaches 0 instead.
  Instrument: `tests/server/deer.spec.luau`'s own sweep, run against round 2's guard -- **2 burst
  runs** in the re-entered crossing (`deer.spec:2039` FAIL, pasted under claim 3).
- **(c) TARGET.** Exactly **1** burst run per crossing, of the kind's own flight
  (hind `Body.leapAir` = 0.4574 s = 27 ticks), and no burst that begins on a tick the animal was
  already leaping on -- that is the exact condition under which `Body` cannot launch what it is
  handed, so a burst there is ground speed with no arc.
- **(d) LEVER.** `self._leapArmed` and `self._burstFor` in `src/server/Boar/Brain.luau`. The writers,
  `grep -n "_leapArmed\|_burstFor = " src/server/Boar/Brain.luau`:
  ```
  634:	self._burstFor = 0
  635:	self._leapArmed = true
  1499:			self._burstFor = (boundMove ~= nil and boundMove.LEAP_AIR_SECONDS) or 0
  1501:		self._leapArmed = false
  2113:		self._leapArmed = true
  2120:		self._leapArmed = false
  2124:		self._leapArmed = false
  2126:		self._burstFor = (config.MOVE ~= nil and config.MOVE.LEAP_AIR_SECONDS) or 0
  ```
  2120 is new (`Brain:step`, the on-road tick inside a bound); 1501 is new (`Brain:spook`).
- **(e) HOW MEASURED AFTER.** The same sweep, plus the same Forest Test instrument as round 2
  (`<runs-dir>/334-instrument.luau`, extended to count burst runs per crossing; every v4 log line
  and reading is unchanged).

## What changed

1. `Brain:step` reads `wasLeaping` **before** the countdown and spends the arm on any on-road tick
   inside a bound. `wasLeaping` IS "`intent.leaping` was true last tick", so the **window edge** --
   the tick `_leapFor` reaches 0 -- is inside the guard. Round 2's literal `self._leapFor > 0` is
   NOT: on that tick `_leapFor` is already 0, the refresh fires, and `leaping` never goes false.
   This is a deliberate strengthening of the decision's wording, and claim 3 shows the literal form
   failing.
2. `Brain:spook` carries the same rule: a bound already running spends the arm instead of renewing.
3. `deer.spec` "cannot re-arm the burst inside a bound it is already flying (task 334 round 3)"
   counts EVERY burst run and sweeps every re-entry offset inside the window.
4. "a calf flies 0.516 s" corrected to **0.369 s** (0.516 is its `Body.leapPlan` window, the flight
   x 1.4) in both `Brain` comments, `Boar.leapByKind`'s header, the spec comment and the research
   note's cycle-2 row.

## Claims

1. **`Brain:step` spends the arm on an on-road tick inside a bound.** `src/server/Boar/Brain.luau`,
   the `wasLeaping` local and the `elseif wasLeaping then self._leapArmed = false` branch above
   `Brain.leapStarts`. Read it: while a bound runs, no on-road tick can leave `_leapArmed` true.
2. **`Brain:spook` carries it.** Same file, the `Brain.boundStarts` block: `_leapFor <= 0` still
   gates the refresh, and `self._leapArmed = false` runs either way.
3. **The case dies when the fix is deleted, AND when round 2's guard is put back** (L-093). Both
   are a FAIL FIRST I ran, dirty tree, same code commit:
   - round 2's guard restored: `ServerStorage.Tests.deer.spec:2039` (`expect(#each).to.equal(1)`),
     `[tests:server] FAIL: 2851 passed, 1 failed, 1 errors, 81 spec files`.
   - the guard deleted entirely: `ServerStorage.Tests.deer.spec:2040`
     (`expect(each[1].to - each[1].from + 1).to.equal(held)`),
     `[harness] FAIL: 30/34 checks @ ea2c0370176c13657477e7df18c76752fa124428 (DIRTY TREE (1 paths)
     - NOT valid evidence) scope=all`. `weapon_shot.spec:1490` and `:2077` also failed in that
     dirty run; the clean run at the SAME commit pasted at the top has them green, and nothing here
     is nearer the weapon than `src/server/Boar/`.
4. **The case counts every burst run** (finding 2). `deer.spec`, the same case: `bursts` is a list
   of `{from,to}` runs, not one contiguous count; the straight run asserts `#bursts == 1` and
   `held` within 2 ticks of `air * 60`; the sweep asserts `#each == 1`, the same length, and `flying[from-1] == false`
   for every offset from 2 to `window - 2`.
5. **The sweep reaches the window edge.** `window = math.floor(LEAP.SECONDS * 60)` = 45;
   `offset = window - 2` = 43 puts the two off-band ticks at 43 and 44, so the animal is back on the
   band on tick 45 -- the tick `_leapFor` reaches 0 (0.75 minus 45 x 1/60 is exactly 0.0 in double
   precision). That offset is what fails under round 2's guard in claim 3.
6. **0.516 is gone.** `grep -rn "0\.516" src/ tests/ docs/research/2026-10-23-deer-road-leap.md`
   returns nothing but the research note's explicit *"0.516 is its `Body.leapPlan` WINDOW"*.
   Arithmetic: calf apex 3.336 (its floor is 1.668, so the row binds), `2*sqrt(2*3.336/196.2)` =
   **0.3688 s**; `LEAP.SECONDS` 0.75 outlasts it by **0.381 s**.
7. **MEASURED NOW in her Forest Test, at the code commit** (L-162). Five drives, 260 s each
   (1300 s), the round-2 instrument with a burst-run counter added and every v4 log line and
   reading unchanged -- `<runs-dir>/334-instrument6.luau`, logs `334r3-AFTER{,2,3,4,5}.txt`, table
   `<runs-dir>/334r3-TABLE.txt`, all at `ea2c0370`:
   | kind | n | apex mean | length mean | airtime | **apex x** | length x | airtime x |
   |---|---|---|---|---|---|---|---|
   | stag | 14 | 5.343 | 20.28 | 0.537 | **1.84** | 2.49 | 1.58 |
   | hind | 5 | 4.737 | 25.36 | 0.444 | **1.92** | 3.35 | 1.38 |
   | calf | 3 | 3.593 | 23.02 | 0.416 | **2.22** | 4.18 | 1.79 |
   divided by round 2's own BEFORE file (cdc885b7, `334-BEFORE.txt`, same instrument, same filter:
   `vy1 >= 20` drops the 12-16 studs/s bumps the `UP_MIN = 12` trigger also catches -- 9 of 31 rows
   after, 5 of 36 before). **Every kind's apex is inside 2x +- 15 % (1.70-2.30).**
   **In-band speed max 110.6 studs/s** over 185 animals (round 2 disclosed 108.4; the Director's
   item 5 keeps it queued, not fixed, and this round did not touch it).
8. **BURSTS PER CROSSING: 165 crossings, 32 carried a burst, and 29 of those 32 have exactly
   one.** The other three read `bursts=2`, and the instrument's `BURSTGAP` row settles what they are:
   ```
   BURSTGAP calf Boar25 gap=1 at=87 prevpeak=70.2
   BURSTGAP stag Boar32 gap=2 at=40 prevpeak=47.5
   ```
   A **1- and 2-frame** gap is the measured flat speed dipping under the 46 studs/s counting
   threshold as the animal turns -- one burst, counted twice. The defect's signature is the
   OPPOSITE: the window edge is `LEAP.SECONDS*60 - air*60` = 45 - 27 = **18 frames** after the
   first burst ends for a hind, 23 for a calf. Nothing near 18 was seen. The third row
   (`calf Boar74 bursts=2 leaps=0`, `334r3-AFTER3.txt`) predates the `BURSTGAP` line and so has no
   gap of its own; it is the same shape. Claim 3's FAIL FIRST is what settles the mechanism
   deterministically -- the instrument's +-20 band is read off the Stand markers while
   `Brain.onRoad` reads the road's own geometry, so one instrument crossing can straddle two of
   the Brain's and a burst count alone could never be a proof.

## What I could NOT verify

- **Rule 5 on the ARC.** `<runs-dir>/shots334/334r3-F2-hind-01-1.png` is a hind in MOTION, never
  anchored: the state read in the same loop immediately after the frame is `AIRBORNE hind Boar58
  vy=-25.4 flat=60.1 rise=2.07`, i.e. descending through a bound 2.07 studs above its take-off with
  the forward burst on (60.1 = 28.3 x 2.1213). **What is IN it**: the player's first-person view
  from the stand -- shotgun barrel bottom-left, the yellow stand ring, two hinds, the near one
  head-on at frame centre with its nose up and forelegs tucked under the chest. Head-on, so the
  **arc cannot be judged from it**. The side-on attempt,
  `shots334/334r3-F2-any-00-1.png` (hind broadside at 25.6 studs, zoom `334r3-F2b-zoom.png`), was
  taken ~0.3 s after the take-off read and shows the hind with its hooves at the grass -- after
  touchdown. In Play, `screen_capture`'s camera arguments are ignored (the client Camera owns the
  view), so a bound cannot be framed side-on without moving the player, and the capture round trip
  (~0.65 s) is longer than a hind's 0.457 s flight. **Nobody has yet seen the bound's ARC at speed.**
- The per-kind n is small (14 / 5 / 3 bounds in 1300 s) and the length spread is wide
  (stag 6.13-34.88 studs): a bound measured as the animal turns reads short. Round 2 measured
  2.00 / 1.99 / 1.97 on the same config at `470a75ff` with its own sample; nothing in this commit
  touches `APEX_STUDS` or `SPEED_SCALE`.
- `334r3-AFTER2.txt` and `AFTER3.txt` were taken while a camera-staging script was moving ONE deer
  (`Boar4`, excluded from the table by name) and, for the last 59 s of AFTER3, teleporting the
  PLAYER beside the herd. Neither touches any other animal; AFTER, AFTER4 and AFTER5 are clean.

## ANSWERED

- ANSWERED: L-136 -- `weapon_shot.spec:1490` and `:2077` fired in the guard-deleted FAIL FIRST run
  only; named in claim 3 with the clean run at the same commit beside them. Count: 2. The clean
  gate run passed 34/34 first time.
- ANSWERED: L-127 -- every dispatch item is MET / NOT PROVEN per item in the report's handover block.
- ANSWERED: L-162 -- every live number in claim 7 is from a drive played at `ea2c0370`, named on
  the row; nothing is carried over from round 2 except the BEFORE file it is divided by.
- ANSWERED: L-014 -- no code was ever checked out in `driven-hunt-karen`; the proof worktree is
  `driven-hunt-rev`, and her Forest Test is back on `:34873` from `driven-hunt-karen`.
- ANSWERED: L-101 -- her 24 flag rows are byte-identical before and after
  (`334r3-attrs-before-rows.txt` vs the final read, diff clean).
- ANSWERED: L-093 -- claim 3: the case dies with the producer deleted and with round 2's version.
