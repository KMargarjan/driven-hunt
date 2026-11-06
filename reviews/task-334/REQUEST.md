# Task 334 -- every deer bounds the road twice as high and three times as far

Task: 334
Round: 2
Base: cdc885b7
Code commit: TBD

Gate: TBD
`test2` N/A: the diff touches `src/server/Boar/` and `tests/server/deer.spec.luau` only, no
`TWO_PLAYER_PATHS` path.

## Round 1's two findings, both fixed

**Finding 1 -- the one wire was untested and the case survived its deletion.**
`Boar.kindConfig` to `Boar.leapByKind` to `MOVE.LEAP_AIR_SECONDS` is the only path from the arc
(`Body.leapAir`) to the Brain's `_burstFor`, and the spec wrote that key by hand. New case
*"gives every deer kind its OWN airtime through kindConfig"* asserts
`Boar.kindConfig(kind, CONFIG).MOVE.LEAP_AIR_SECONDS == Body.leapAir(kind, leap)` for stag, hind and
calf, that it is shorter than `LEAP.SECONDS`, that a calf is airborne less than its mother and she
less than the stag, and that a boar still gets the config back **by reference**
(`Boar.kindConfig("male", CONFIG)` `.to.equal(CONFIG)`) and carries no such key.

**Finding 2 -- the burst could be re-armed for a bound `Body` refuses to launch.** Correct and
serious: a bound now covers 45 studs across a 40-stud band, so the animal LEAVES the band in
mid-flight, `_leapArmed` comes back, and a re-entry refreshed `_burstFor` while `leapSpent` was
latched -- a second 0.46 s of 60 studs/s along the GROUND with no arc, which is cycle 2's measured
defect through another door. Both triggers (the road leap in `Brain:step`, the spook bound in
`Brain:spook`) now require `self._leapFor <= 0`. New case *"cannot re-arm the burst inside a bound
it is already flying"* drives two band entries inside one window by **moving the road, not the
animal**, so the observation the Brain is handed is identical tick for tick.

**FAIL FIRST, one run with BOTH producers deleted** (`Boar.leapByKind`'s call dropped from
`kindConfig`, `self._leapFor <= 0` dropped from the trigger): `[harness] FAIL: 32/34 ... 2850
passed, 2 failed`, and the two lines are exactly the two new cases --
`deer.spec:1826` (`expect(move.LEAP_AIR_SECONDS).to.be.near(air, 1e-9)`) and
`deer.spec:2029` (`expect(reentered).to.equal(straight)`, **Expected 28, got 34**: 28 ticks is the
hind's own 0.457 s flight, 34 is the window the re-entry extended it to). Tree restored, clean.

Round 1's six non-blocking notes: `SPEED_SCALE` is now pinned to `3 / math.sqrt(2)` (the number
section 9.2 derives) rather than to itself; the rest are queued in `TASKS.md`.

## PLAN (core quality protocol, step 0)

**(a) REAL LIFE.** A red deer clears a **1.8 m** fence routinely and 2.4 m is the height that
excludes one; reported single-bound spans are **6-10 m** (section 8 of
`docs/research/2026-10-23-deer-road-leap.md`). At `METRES_PER_STUD` 0.28 the stag's new bound is
**1.63 m** high, where today's is 0.81 m -- an obstacle-clearing bound instead of a cruising skip.
**The one number above life, stated plainly:** the in-air horizontal speed becomes 50.91 studs/s =
**51 km/h** against a red deer's ~48 km/h top speed. It lasts under half a second and is the
push-off burst of a bound, but it IS above the species' sustained maximum, and it is forced by
2x apex and 3x length together rather than chosen (see (c)).

**(b) MEASURED NOW** -- her Forest Test (placeId 130094961655666, layout `C1`, `DEER_ROAD_LEAP` on:
read, never written), Edit to Play, 8 staged `herd@120,-140,60,run` releases over 260 s, instrument
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

1. `APEX_STUDS` to `{ stag = 6.0, hind = 5.132, calf = 3.336 }`. The calf's **effective** apex
   before this task is 1.668, not 1.485 -- `Body.leapApex`'s sink floor binds on it -- so its 2x
   is 3.336.
2. `MODEL.LEAP.SPEED_SCALE = 2.12132`, read by the pure `Brain.leapSpeedScale(burst, leap)` and
   applied at `Brain:step`'s scaled `targetVelocity` write. `self._speed` is never scaled, so the
   leap gate, the gait band and the clip rate cannot feed the burst back into the rule that started
   it.
3. `MODEL.LEAP.SECONDS` 0.55 to 0.75: `Body.leapPlan`'s window for the new stag is 0.692 s.
4. The burst runs for the kind's own flight, not the drawing window: `Body.leapAir` to
   `Boar.leapByKind` to `Brain._burstFor`, and it cannot be re-armed while a bound is flying.

**(e) MEASURED AFTER:** the same instrument, place and releases, at the final code commit.

## MEASURED -- four cycles, one filter applied identically to both sides

Rows are the first bound of each animal, inside the road band, entered at a gait (`v0 <= 35`).

| cycle | change | measured |
|---|---|---|
| 1 | baseline `cdc885b7` (`334-BEFORE.txt`) | stag apex **2.905** / length **8.14**, hind **2.471** / **7.58**, calf **1.612** / **5.52** |
| 2 | apex x2 + the burst on the drawing window, `f745f948` (`334-AFTER.txt`) | apex right, length WRONG: calf **40.97** against a 16.56 target, herd speeds to **150.7** studs/s. `LEAP.SECONDS` is one size (0.75), a calf flies 0.516, so the burst drove it along the GROUND for 0.23 s after touchdown |
| 3 | the burst ends at touchdown, `9f65b70f` (`334-AFTER2.txt`) | stag **5.685** / **20.22**, hind **4.955** / **21.53**, calf **3.286** / **17.94**; herd max 113.8 |
| 4 | no re-arm while flying, `470a75ff` (`334-AFTER3.txt`) | stag **5.803** / **21.17**, hind **4.922** / **21.12**, calf **3.181** / **22.94**; herd max 108.4 |

| kind | apex x (want 2.00) | length x, normalised for entry speed (want 3.00) | airtime x | inside 15 %? |
|---|---|---|---|---|
| stag | **2.00** | 2.40 | 1.47 | apex YES, **length NO (20 % under)** |
| hind | **1.99** | **2.79** | 1.40 | YES |
| calf | **1.97** | **3.08** | 1.56 | YES |

Length is normalised by the animal's own entry speed (`length / v0`): length IS speed x airtime, and
the gait speed at the band edge is not something this task changed. **The stag's shortfall is
measured, not estimated:** at `v0` 24 a hind holds 50.91 studs/s (= `RUN_SPEED x runScale x
SPEED_SCALE`, and `334-AFTER3.txt`'s `vmax` column reads exactly 50.9 on every clean hind row) for
93 % of its flight, while the stag reaches the same speed but averages **66 %** of it. The burst is
published identically for both; the difference is how fast the `LinearVelocity` mover gets the
heavier body there -- `Body.driveForce`, not this task's dial. **Queued in `TASKS.md`, not fixed.**

**FRAME 334-F1** (`<runs-dir>/334-F1.png`, zoom `334-F1-zoom.png`), taken in her Forest Test at
`9f65b70f`, from the player's own eye (first person, camera y 112.7, the hind at y 114.71, 16 studs
away; the hind was anchored at the top of its bound by `<runs-dir>/334-apex.luau`, which reported
`vxz=50.9` -- the burst, read live). **What is IN it:** a first-person view over the beater's horn,
the forest road running away to the right; left of centre a red deer **hind entirely off the
ground** -- body level, head up, forelegs folded under the chest, hind legs trailing, grass and the
road visible below and behind her hooves with nothing touching. A beater bot in an orange cap
stands on the road beyond her. The frame is from cycle 3; cycle 4 changed no apex, and the apex is
what the frame shows.

## Claims

1. Every kind bounds, and did before this task: 12/12 running in-band crossings, 0/4 walking ones.
   Verify: `334-why.txt` and (b2).
2. The before means are the cycle-1 row, read at `cdc885b7` with `334-instrument.luau`.
3. The after means are the cycle-4 row, read at **`470a75ff`** with the same instrument (L-162).
4. Apex is 2x within 15 % for all three kinds; length is 3x within 15 % for the **hind** (2.79) and
   the **calf** (3.08) and is **20 % under for the stag** (2.40), with the measured cause above.
5. The burst is applied at one place, `Brain:step`'s scaled `targetVelocity`, through the pure
   `Brain.leapSpeedScale`; `self._speed` is unscaled. (`Brain:step` also writes `targetVelocity` in
   the DOWN and CRIPPLED branches, which both `return intent` before this line -- round 1's note.)
6. The burst lasts the kind's own flight and cannot be re-armed inside one: `deer.spec:1826` and
   `deer.spec:2029`, both proven to bite by the FAIL FIRST run above.
7. The legs still match the arc and the hooves still clear the road: `deer.spec`'s task-325 case
   asserts `(LAND - TAKEOFF) / rate == 2 up / g` and `apex * leapSinkShare >= LIFT + CLEARANCE` for
   all three kinds, and `leap.SECONDS >= longest window`.
8. `SPEED_SCALE` answers 1 for a grounded animal, a switched-off leap, a missing table, a missing
   key and a value at or below 1, and is pinned to `3 / math.sqrt(2)`.
9. Her Forest Test is back on `:34873` from `driven-hunt-karen` at `cdc885b7`, Connected, and its 24
   flag rows are byte-identical before and after (`334-ft-attrs-before.txt` vs `-final.txt`, diff
   empty). The branch was never checked out in `driven-hunt-karen` (L-014): the proof worktree was
   `driven-hunt-rev`, now back at `8ae8c627`.

## Not verified

- **Karen has not seen it run.** 334-F1 is one hind anchored at the top of one bound; nobody has
  watched the new bound at speed, which is what she actually asked to see. Rule 5 is NOT met on
  motion.
- **The stag's 3x length is NOT MET** (2.40), cause measured, queued.
- **A regression, measured and queued, not fixed:** in-band speed went from a max of 39.9 studs/s
  (0 of 68 animals over 45) to **108.4** (40 of 86 over 60). 60.0 is the feature; 95.1 is the
  ceiling a sprinting animal reaches; above that is animals shoved by a herd that now covers 21
  studs a bound instead of 8. The two burst guards took the count above 95.1 from 37 to 13 to 8.
- `MOVE.BOUND_ON_SPOOK` (`STAG_BOUND_ON_SPOOK`) shares `APEX_STUDS` and is off everywhere, so no
  live build changes -- but turning it on would now launch a near-stationary stag at 48.5 studs/s of
  almost pure up. The queued 245c/325 note, twice as large.
