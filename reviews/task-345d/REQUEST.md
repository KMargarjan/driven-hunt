# Task 345d -- `releaseLine` STOPS SPAWNING; `orderGroup` ORDERS (T4 of animal-placement)

Task: 345d
Round: 1
Base: 85c4aef1 (origin/main, #363)
Code commit: TBD

## PLAN (core quality protocol step 0, written before any `src/` edit)

**(a) REAL LIFE.** A sounder the beater line reaches leaves its bed and moves off in SINGLE FILE
behind the leading sow, nose-to-tail. `docs/research/2026-11-10-animal-placement.md` and the drive
spec Karen OK'd carry it; `docs/design/animal-placement.md` 4.6 puts the number on it: a formed file
within 5 s of the break, median nose-to-nose <= `2 x LINE.spacingStuds` = **17 studs**
(`LINE.spacingStuds` 8.5, `src/shared/ForestTest/init.luau`).

**(b) MEASURED NOW.** On the flag-ON path at `85c4aef1` a woken group gets **no file at all**:
`releaseLine`'s roster branch prints `THE ROSTER'S: N bedded at dz D, the line finds it` and returns,
so nothing is ever put in `state.lines` for it, and `spookNearBeaters` turns it into a FLIGHT (a
panic run away from the nearest beater, no crossing, no exit). Instrument: the ON drives of task
345b -- `<runs-dir>/345b-ON4-C1-console.txt`, `345b-ON4-A2-console.txt` -- whose `SLOT` lines are all
roster lines and carry no `in N of M file(s)` clause. So **files formed from a bed = 0** and the
nose-to-nose median is undefined. The OFF path's files (spawned along their approach) are the
control.

**(c) TARGET.** Median nose-to-nose <= **17 studs** within **5 s** of a break, over **>= 10 breaks**,
flag ON, C1 and A2. Spawns in the lane on the ON path: **0**. A2 ring searches per drive: **< 100**
(was ~2,940 -- `ESCALATE.md` 2026-11-11 ~04:55).

**(d) LEVER.** The file and its seeded trail: `src/server/ForestTest/init.luau:4098`
`table.insert(state.lines, {` with `:4103` `trail = seeded,` -- today reachable only from
`releaseLine`'s spawn half. T4 lifts that half into `ForestTest.orderGroup(row, now)`, which works on
bodies that already exist and seeds the trail from the leader's own position backwards along the
first leg. The searches counter whose cap is being added: `state.placementSearches += 1` in
`ForestTest.bedSpot`.

**(e) HOW IT WILL BE MEASURED AFTER.** The same instrument both sides, published where a probe can
reach it (V293b): `ServerStorage.DHForestPlacement` gains `files=`, `filegap=median/worst` measured
at +5 s after each line's `bornAt`, plus `ordered=`, `flights=`, `caps=`, `reopens=`. One ON drive
per cell (C1, A2) and one OFF drive, same session, same probe.

## What changed

(filled in with the claims when the code is written)
