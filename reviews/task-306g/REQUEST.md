# Task 306 step B7: one animal per OCCUPIED station

Task: 306g
Round: 1
Base: task-306b6-isolation-picture @ b703f92d
Code commit: (filled in below, after the harness)

Design: `docs/design/shooting-range-lobby.md` §7.4, §16 row B7. DEV only; Karen's place is B8.

## PLAN

**CORE-NA** (Director, 2026-10-28): this step changes WHO HAS AN ANIMAL AND WHEN. No shot rule, no
motion rule, no kill zone, no ballistics. Steps 1-3 of the core protocol are therefore scoped to the
occupancy sentence, and the live proof is the DEV click proof the dispatch names.

(a) **REAL LIFE.** A running-boar range runs a target for the bay that is being shot. BSRC's own
page describes a firing hut of bays with **a light per bay** -- the installation is driven per
occupied bay, not all six at once (`docs/research/2026-10-28-the-range-in-the-lobby.md` §2).

(b) **MEASURED NOW.** `tests/server/range.spec.luau` "clears a killed target after CARCASS_SECONDS"
asserts, at b703f92d, `fake.spawns == LAYOUT.SPOT_COUNT` (**6**) after 2 s with **nobody anywhere**,
then `2 * LAYOUT.SPOT_COUNT` (**12**) spawns and `lostTargets == 5` after ONE carcass -- the two
defects B2 wrote in as numbers. Live DEV reading is the click proof below.

(c) **TARGET.** Empty range: **0** spawns. One man at station 2: **exactly 1** target, at station 2.
He leaves: **1** idle clear after `IDLE_CLEAR_SECONDS` = **30 s** (design §7.4) and not before.
One carcass at station 1: **1** clear, **0** lost targets, **7** spawns total (6 + 1), the other five
animals untouched. 30 s because it is the design's number, and it is long enough that a man who
steps off the mat to reload does not lose his animal.

(d) **LEVER.** `src/server/Range/init.luau`'s `scan` -- the unconditional `release(trial)` at the
`trial.targetId == nil` arm -- and the two range-WIDE clears:
```
$ grep -n "boars.clear(" src/server/Range/init.luau
604:			state.boars.clear("range stop")
777:				boars.clear("range carcass")
1489:				boars.clear("range pick")
$ grep -n "function Runtime:clear" src/server/Boar/init.luau
5673:function Runtime:clear(reason: string?)
```
There is **no per-id despawn**, so the lever for must-fix 1 does not exist yet and is built:
`Runtime:clearOne(id, reason)`, through the same `_despawn` path `clear` and the out-of-bounds step
already use (`src/server/Boar/init.luau:7848`). The occupancy lever is a new `players` seam on
`Range.start`, measured through the owner's own `playerSpot` + `Range.spotAt`.

(e) **HOW IT IS MEASURED AFTER.** The same two instruments: `range.spec` group 12 (`fake.spawns`,
`stats.idleClears`, `stats.lostTargets`, `fake.at(n)`), and live `Range.stats()` in DEV Play.

**THE FUNCTIONAL INSTRUMENT IS NAMED (L-152).** The dispatch cites T10/T11, but design §12 defines
T10 as step cost (<= 2 ms/step) and T11 as draw cost (<= 3 ms) **plus** "an empty range costs 0
spawns". Only that last clause is occupancy. The instrument for the *sentence* -- arrival releases,
idle clears, station 4 unaffected -- is **§11.2 group 12** plus `Range.stats().occupied/spawns/
idleClears/targets` read live. T10 and T11 are reported as the cost targets they are.
