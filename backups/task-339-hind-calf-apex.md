# Task 339: the hind's and the calf's road bound, removed

**Removed 2026-11-09**, from `src/server/Boar/init.luau`, `Boar.CONFIG.MODEL.LEAP.APEX_STUDS`:

    APEX_STUDS = { stag = 6.0, hind = 5.132, calf = 3.336 },   -- before
    APEX_STUDS = { stag = 6.0 },                                -- after

**Why.** KAREN, 2026-11-09 ~12:30 UTC: *"btw I mentioned that deer famale and kid doesnt jumt you
need to remove that only male jump"*. Her 2026-11-07 sentence was *"fix deer jump only mail jumping
and does twice high and 3 times longer then now"*; task 334 (#341) read it as "make every kind's
leap bigger" and gave the hind and the calf bigger bounds too. Only the stag jumps over the road.

**What the two numbers were.** Task 325 set them to each kind's own 3.00 studs taken to
`KINDS.<kind>.scale`, floored at `(LIFT_STUDS + CLEARANCE) / leapSinkShare` (the calf bound on its
floor at 1.668); task 334 doubled the EFFECTIVE apex measured in her Forest Test at `cdc885b7`
(hind 2.471 -> 5.132, calf 1.668 -> 3.336). Measured again at main `d91d65e9` on 2026-11-09
(`<runs-dir>/339-BEFORE.txt`, 215 s, 8 staged herds): hind median apex 4.918 over 23 bounds, calf
4.428 over 21.

**What replaced them.** Nothing: the rule is now **no `APEX_STUDS` row, no bound**, and
`Boar.leapByKind` hands a kind with no row a config whose `MODEL.LEAP.ENABLED` is false. The hind's
and the calf's `LIFT_STUDS` rows STAY -- they are a measurement of the leap clip on those two rigs,
not a decision about whether they bound.

**To bring them back**, restore the two keys above and delete the `air <= 0` branch of
`Boar.leapByKind`; without that second half the animals trigger a leap they cannot fly and play the
clip in place with no arc, which is the 2026-11-01 defect (`Body.luau`, "THE BOUND OVER THE ROAD").
