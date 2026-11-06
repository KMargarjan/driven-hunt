# Task 334 -- every deer bounds the road twice as high and three times as far

Task: 334
Round: 1
Base: cdc885b7
Code commit: 1e96adcf5331d297b33e0bfb93aa743bc1d893bd

Gate: `[harness] PASS: 34/34 checks @ 1e96adcf5331d297b33e0bfb93aa743bc1d893bd (clean tree) scope=all`
`test2` N/A: the diff touches `src/server/Boar/` and `tests/server/deer.spec.luau` only, no
`TWO_PLAYER_PATHS` path.

**The code commit is a DOCS commit on purpose.** `9f65b70f` is the last commit that changed `src/`
or `tests/`, and it passed the same gate first time:
`[harness] PASS: 34/34 checks @ 9f65b70f21c47204a3c8e8a7dd0c2c1a000564d2 (clean tree) scope=all`.
`1e96adcf` adds section 9 of the research note, which `is_paperwork` does not cover, so it is named
here instead -- the bound is then strictly tighter and only `reviews/` and the `TASKS.md` row follow
it. **Two unstable specs fired on the first run at `1e96adcf`** -- `weapon_shot.spec:1490` (on the
Director's list) and `weapon_shot.spec:2077` (**not** on it: `Expected nil, got "rate-limited"`) --
and the re-run above is clean. The two harness lines name two different commits carrying byte-
identical `src/` and `tests/`, which is the control: nothing in this change is nearer the weapon
than `src/server/Boar/`.

## PLAN (core quality protocol, step 0)

**(a) REAL LIFE.** A red deer clears a **1.8 m** fence routinely and 2.4 m is the height that
excludes one; reported single-bound spans are **6-10 m** (sources in section 8 of
`docs/research/2026-10-23-deer-road-leap.md`). At `METRES_PER_STUD` 0.28 the stag's new bound is
**1.68 m x 6.84 m**, where today's is 0.81 m x 2.28 m -- an obstacle-clearing bound instead of a
cruising skip. **The one number above life, stated plainly:** the in-air horizontal speed becomes
~50.8 studs/s = **51 km/h** against a red deer's ~48 km/h top speed. It lasts under half a second
and is the push-off burst of a bound, but it IS above the species' sustained maximum, and it is
forced by 2x apex and 3x length together rather than chosen (see (c)).

**(b) MEASURED NOW** -- her Forest Test (placeId 130094961655666, layout `C1`, `DEER_ROAD_LEAP` on:
read, never written), Edit -> Play, 8 staged `herd@120,-140,60,run` releases over 260 s, instrument
`<runs-dir>/334-instrument.luau`, log `334-BEFORE.txt`, read at **cdc885b7**. Take-off is the frame
`AssemblyLinearVelocity.Y` is written, landing is the arrest after the fall, apex is above the
take-off point, length is take-off to landing in XZ.

**(b2) THE DISPATCH'S FIRST PREMISE IS REFUTED, AND THAT IS A FINISHED ITEM.** *"only mail
jumping"* is not what the game does. Per-frame probe `<runs-dir>/334-why.luau`, log `334-why.txt`,
18 animals: of those at or above `MODEL.RUN_FROM` (21 studs/s) **while inside** the road band
(`|dz| <= 18`), **12 of 12 bounded -- stag 1/1, hind 7/7, calf 4/4**; of the 4 that crossed below
it, 0 bounded, and all four were measured crossing at **2.0-2.8 studs/s**, i.e. walking. The gate is
`Brain.leapStarts`' `speed >= runFrom`, and it is Karen's own earlier sentence (*"a deer ambling
over the lane does not bound"*, task 245b), so I have **not** touched it: making a walking deer
bound reverses an accepted rule and is the Director's call. "Once per crossing" is therefore already
met for a running crossing. What Karen is seeing is the SIZE -- a calf rises 1.61 studs in 0.23 s.

**(c) TARGET: 2x the apex and 3x the length, off the measured means.** The two together **force a
forward burst, and that is arithmetic, not a choice.** The arc is ballistic against
`workspace.Gravity` (read live: 196.1999969482422), so `apex = g t^2 / 8`: doubling the apex
multiplies the airtime by `sqrt(2)` and nothing can change that. Length is `horizontal speed x
airtime`, so 3x the length needs the in-air speed at `3 / sqrt(2)` = **2.12132x** -- one number for
all three kinds, because both of Karen's multiples are uniform.

**(d) LEVER** -- the code that WRITES each number, at `cdc885b7`:

    src/server/Boar/init.luau:3572:  APEX_STUDS = { stag = 3.0, hind = 2.566, calf = 1.485 },
    src/server/Boar/init.luau:3518:  SECONDS = 0.55,
    src/server/Boar/Brain.luau:2672:  intent.targetVelocity = self._desired * self._speed

1. `APEX_STUDS` to `{ stag = 6.0, hind = 5.132, calf = 3.336 }`. The calf's **effective** apex today
   is 1.668, not 1.485 -- `Body.leapApex`'s sink floor binds on it -- so its 2x is 3.336.
2. `MODEL.LEAP.SPEED_SCALE = 2.12132`, read by a new pure `Brain.leapSpeedScale(burst, leap)` and
   applied at `Brain:step`'s single `targetVelocity` write. `self._speed` is never scaled, so the
   leap gate, the gait band and the clip rate cannot feed the burst back into the rule that started
   it.
3. `MODEL.LEAP.SECONDS` 0.55 to 0.75: `Body.leapPlan`'s window for the new stag is 0.692 s.
4. **Cycle 2's defect, cycle 3's fix.** `Body.leapAir` is the kind's own airtime, `Boar.leapByKind`
   lays it onto `MOVE` beside the edge and spook deltas, and the Brain counts it down as
   `_burstFor`. See the table below.

**(e) MEASURED AFTER:** the same instrument, place and releases, at the code commit.

## MEASURED -- three cycles, one filter applied identically to both sides

Rows are the first bound of each animal, inside the road band, entered at a gait (`v0 <= 35`).

| cycle | change | measured |
|---|---|---|
| 1 | baseline `cdc885b7` (`334-BEFORE.txt`) | stag apex **2.905** / length **8.14**, hind **2.471** / **7.58**, calf **1.612** / **5.52** |
| 2 | apex x2 + the burst on the drawing window, `f745f948` (`334-AFTER.txt`) | apex right, length WRONG: calf **40.97** against a 16.56 target, herd speeds to **150.7** studs/s. `LEAP.SECONDS` is one size (0.75) and a calf flies 0.516, so the burst drove it along the GROUND at 60 studs/s for 0.23 s after touchdown |
| 3 | the burst ends at touchdown, `9f65b70f` (`334-AFTER2.txt`) | stag **5.685** / **20.22**, hind **4.955** / **21.53**, calf **3.286** / **17.94** |

| kind | apex x (want 2.00) | length x, normalised for entry speed (want 3.00) | airtime x | inside 15 %? |
|---|---|---|---|---|
| stag | **1.96** | **2.83** | 1.51 | YES |
| hind | **2.01** | **2.85** | 1.44 | YES |
| calf | **2.04** | **3.31** | 1.53 | YES |

Length is normalised by the animal's own entry speed (`length / v0`): length IS speed x airtime, and
the gait speed at the band edge is not something this task changed. Raw after-means are in the cycle
table. The residual ~5 % under 3.00 is the instrument -- take-off and landing are sampled at
0.02-0.04 s, which clips ~2 studs off a 21-stud bound at 51 studs/s and only ~0.3 off a 7.6-stud one
at 24.

**FRAME 334-F1** (`<runs-dir>/334-F1.png`, zoom `334-F1-zoom.png`). Taken in her Forest Test at
`9f65b70f`, from the player's own eye (first person, camera at y 112.7, the hind at y 114.71, 16
studs away; the hind was anchored at the top of its bound by `<runs-dir>/334-apex.luau`, which
reported `vxz=50.9` -- `PACE.RUN_SPEED x runScale x SPEED_SCALE` = 50.91, the burst read live).
**What is IN it:** a first-person view over the beater's horn, the forest road running away to the
right; left of centre a red deer **hind entirely off the ground** -- body level, head up, forelegs
folded under the chest, hind legs trailing, grass and the road visible below and behind her hooves
with nothing touching. A beater bot in an orange cap stands on the road beyond her.

## Claims

1. Every kind bounds, and did before this task: 12/12 running in-band crossings, 0/4 walking ones.
   Verify: `334-why.txt` and (b2).
2. The before means are the cycle-1 row, read at `cdc885b7` with `334-instrument.luau`.
3. The after means are the cycle-3 row, read at **`9f65b70f`** with the same instrument (L-162).
   `1e96adcf`, the code commit, differs from it in `docs/research/` alone -- `git diff --stat
   9f65b70f..1e96adcf` touches no `src/` or `tests/` file -- so no number here was read at code
   that is not in the commit under review.
4. Apex x2 and length x3 within 15 % for all three kinds -- the second table.
5. The burst has ONE writer: `Brain:step`'s `targetVelocity`, scaled by the pure
   `Brain.leapSpeedScale`; `self._speed` is unscaled. Verify: `grep -n leapSpeedScale src/`.
6. The burst ends at touchdown, not at the drawing window: `Body.leapAir` to `Boar.leapByKind` to
   `Brain._burstFor`. `deer.spec`'s task-334 case asserts `burstTicks < ticksOn`, and that a world
   with `SPEED_SCALE = 1` has `burstTicks == 0`.
7. The legs still match the arc and the hooves still clear the road: `deer.spec`'s task-325 case
   asserts `(LAND - TAKEOFF) / rate == 2 up / g` and `apex * leapSinkShare >= LIFT + CLEARANCE` for
   all three kinds, and `leap.SECONDS >= longest window`.
8. **It dies if the fix is deleted (L-093):** `deer.spec`'s *"is 2x the measured height and 3x the
   measured length for a hind"* compares `Body.leapPlan("hind", ...)` and `Brain.leapSpeedScale`
   against the measured before-means 2.471 / 7.58 / 0.322. Revert `APEX_STUDS` or `SPEED_SCALE` and
   it fails; so does the burst case above.
9. `SPEED_SCALE` answers 1 for a grounded animal, a switched-off leap, a missing table, a missing
   key and a value at or below 1 -- reachable by parameter with the row at false.
10. Her Forest Test is back on `:34873` from `driven-hunt-karen` at `cdc885b7`, and its 24 flag
    rows are byte-identical before and after (`334-ft-attrs-before.txt` vs `-after.txt`, diff empty).

## Not verified

- **Karen has not seen it run.** 334-F1 is one hind frozen at the top of one bound; nobody has
  watched the new bound at speed, which is what she actually asked to see.
- **A regression, measured and queued, not fixed:** in-band speed went from a max of 39.9 studs/s
  (0 of 68 animals over 45) to **113.8** (45 of 90 over 60). 60.0 is the feature
  (`RUN_SPEED x runScale x SPEED_SCALE`) and 95.1 is the ceiling a sprinting animal reaches; the
  excess is animals shoved by a herd that now covers 20 studs a bound instead of 8.
- `MOVE.BOUND_ON_SPOOK` (`STAG_BOUND_ON_SPOOK`) shares `APEX_STUDS` and is off everywhere, so no
  live build changes -- but turning it on would now launch a near-stationary stag at 48.5 studs/s of
  almost pure up. The queued 245c/325 note, twice as large.
