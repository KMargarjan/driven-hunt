# Task 334 -- every deer bounds the road twice as high and three times as far

Task: 334
Round: 1
Base: cdc885b7
Code commit: TBD

## PLAN (core quality protocol, step 0)

**(a) REAL LIFE.** A red deer clears a **1.8 m** fence routinely and 2.4 m is the height that
excludes one; a bound is the gait where all four feet leave the ground together, used to clear an
obstacle (Lingle 1993; sources in `docs/research/2026-10-23-deer-road-leap.md` section 8). Reported
single-bound spans are **6-10 m**. At `Report.CONFIG.METRES_PER_STUD` 0.28 the bound this task ships
is 1.68 m high and 6.84 m long for the stag -- an obstacle-clearing bound, where today's 0.81 m x
2.28 m is a cruising skip.

**(b) MEASURED NOW.** Her Forest Test (placeId 130094961655666, layout `C1`, `DEER_ROAD_LEAP` on --
read, never written), Edit -> Play, 8 staged `herd@120,-140,60,run` releases over 260 s.
Instrument `<runs-dir>/334-instrument.luau`, log `<runs-dir>/334-BEFORE.txt`, read at **cdc885b7**.
Take-off is the frame `AssemblyLinearVelocity.Y` is written; landing is the arrest after the fall;
apex is above the take-off point, length is take-off -> landing in XZ.

| kind | bounds | apex mean (studs) | length mean (studs) | airtime mean (s) |
|---|---|---|---|---|
| stag | 7 | **2.905** [2.754-2.973] | **8.14** [7.63-8.60] | 0.340 |
| hind | 17 | **2.471** [2.319-2.526] | **7.58** [7.38-7.92] | 0.322 |
| calf | 9 | **1.612** [1.565-1.634] | **5.52** [5.12-5.92] | 0.233 |

**(b2) THE DISPATCH'S FIRST PREMISE IS REFUTED, AND THAT IS A FINISHED ITEM.** *"only mail
jumping"* is not what the game does: **every kind bounds, on every crossing it makes at a run.**
Per-frame probe `<runs-dir>/334-why.luau`, log `334-why.txt`, 18 animals: of those that were at or
above `MODEL.RUN_FROM` (21 studs/s) **while inside** the road band (`|dz| <= 18`), **12 of 12
bounded -- stag 1/1, hind 7/7, calf 4/4**; of the 4 that crossed below it, 0 bounded, and those
four were measured crossing at **2.0-2.8 studs/s**, i.e. walking. The gate is
`Brain.leapStarts`' `speed >= runFrom` in `src/server/Boar/Brain.luau`, and it is Karen's own
earlier sentence (*"a deer ambling over the lane does not bound"*, task 245b). So "once per
crossing" is **already met for a running crossing** and I have not touched the gate -- making a
walking deer bound reverses an accepted rule and is the Director's call, not mine.
What Karen is seeing is the SIZE: the calf rises 1.61 studs in 0.23 s, which reads as no bound at
all beside the stag's 2.91.

**(c) TARGET** (2x apex, 3x length, off the measured means above):

| kind | apex target | length target | airtime it implies |
|---|---|---|---|
| stag | **5.810** | **24.42** | 0.481 |
| hind | **4.942** | **22.74** | 0.455 |
| calf | **3.224** | **16.56** | 0.330 |

**THE TWO TARGETS TOGETHER FORCE A FORWARD BURST, and that is arithmetic, not a choice.** The arc is
ballistic against `workspace.Gravity` (read live: 196.1999969482422), so `apex = g t^2 / 8`: doubling
the apex multiplies the airtime by `sqrt(2)` = 1.4142 and nothing else can change it. Length is
`horizontal speed x airtime`, so 3x length needs the in-air horizontal speed at
`3 / sqrt(2)` = **2.12132x**. One number for all three kinds, because both targets are uniform.
The honest cost: the stag's in-air speed becomes 50.8 studs/s = 51 km/h against a red deer's ~48
km/h top speed. It is a 0.48 s push-off burst, not a cruise, and it is what Karen asked for.

**(d) LEVER** -- the code that WRITES each number:

    src/server/Boar/init.luau:3572:  APEX_STUDS = { stag = 3.0, hind = 2.566, calf = 1.485 },
    src/server/Boar/init.luau:3518:  SECONDS = 0.55,
    src/server/Boar/Body.luau:2031:   handle.part.AssemblyLinearVelocity = Vector3.new(now.X, up, now.Z)
    src/server/Boar/Brain.luau:2672:  intent.targetVelocity = self._desired * self._speed

1. `MODEL.LEAP.APEX_STUDS` -> `{ stag = 6.0, hind = 5.132, calf = 3.336 }`. The calf's **effective**
   apex today is 1.668, not 1.485: `Body.leapApex`'s sink floor binds on it, so 2x is 3.336 and not
   2.97.
2. `MODEL.LEAP.SPEED_SCALE = 2.12132`, new, read by a new pure `Brain.leapSpeedScale(leaping, leap)`
   and applied at `Brain.luau:2672` -- the ONE writer of `targetVelocity`. `self._speed` is left
   alone, so the leap gate, the gait band and the clip rate cannot feed back on it.
3. `MODEL.LEAP.SECONDS` 0.55 -> 0.75. `Body.leapPlan`'s window for the new stag is **0.692 s**; a
   Brain bound shorter than that drops the animal into its gait in mid-air, and
   `deer.spec`'s existing `leap.SECONDS >= longest` case already fails if I forget it.

**(e) HOW IT WILL BE MEASURED AFTER:** `<runs-dir>/334-instrument.luau`, the same instrument,
the same 8 staged `herd@120,-140,60,run` releases, in the same place, at the final code commit.

## Claims

1. Every kind bounds the road, and did before this task -- 12/12 running in-band crossings.
   Verify: `334-why.txt` and the table in (b2).
2. The before means are the table in (b), read at cdc885b7 with `334-instrument.luau`.
3. Apex is 2x and length 3x the before mean for each kind, within 15 %.
   Verify: the after table in `## MEASURED AFTER`, same instrument, same place.
4. The forward burst has ONE writer: `Brain.luau`'s `intent.targetVelocity`, scaled by the pure
   `Brain.leapSpeedScale`. `self._speed` is unscaled. Verify: `grep -n leapSpeedScale src/`.
5. The legs still match the arc and the hooves still clear the road:
   `deer.spec`'s task-325 case asserts `(LAND - TAKEOFF) / rate == 2 up / g` and
   `apex * leapSinkShare >= LIFT_STUDS[kind] + CLEARANCE_STUDS` for all three kinds.
6. The case dies if the fix is deleted (L-093): `deer.spec`'s task-334 case asserts the hind's
   2x/3x against the measured before-means. Verify: revert `APEX_STUDS` or `SPEED_SCALE` and it
   fails.
7. `SPEED_SCALE` is reachable by parameter with the flag off, and answers 1 for a non-leaping
   animal, for a leap table with `ENABLED = false` and for nil.
8. `STAG_BOUND_ON_SPOOK` is OFF everywhere (default false, FT override `none`), so no spooked
   stand-still bound changes in any live build -- but it shares `APEX_STUDS`, so turning it on
   would now launch a near-stationary stag at 48.5 studs/s of pure up. Queued, not fixed here.

## Not verified

- Karen has not watched it at speed. Frame 334-F1 is one hind frozen at its apex; nobody has seen
  the new bound run.
