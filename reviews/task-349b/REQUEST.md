# Task 349b: the three proofs for 349, and one review of the whole branch

Task: 349b
Round: 1
Base: 6fa59255 (origin/main, #365)
Code commit: PENDING

This review covers the WHOLE branch diff against `main` -- task 349's code included -- so the
merge gate's `PASS` is for everything that would merge.

## PLAN (core protocol step 0, committed before any `src/` edit)

**(a) REAL LIFE.** Not applicable as a field figure: all three items are about whether a test binds
the code it claims to bind. The behaviour they pin was measured live in 349 round 3 and is not
reopened here.

**(b) MEASURED NOW** (349 round 3, `reviews/task-349/RESULT.md`, three findings; her Forest Test
attributes read at 01:27 UTC tonight, `<runs-dir>/349b-attrs-start.txt`:
`DHFlag_DRIVE_AIMS_AT_PICKED_STAND=false`, `DHFlag_PLACEMENT_IN_PLACE=false`):
1. `restSpot` creates and publishes the refusal counters and **never increments one** -- the line a
   refused bed prints always reads `swept=0 band=0 lane=0 zone=0 unseen=0`, measured in `X11d`'s
   console with 85 refusals behind it.
2. The latch case asserts `settleAim(false)`'s boolean on the SECOND consecutive call, where
   `settleAim`'s own first line returns `false` for any already-settled drive -- so it cannot fail.
3. The bed case calls only the pure `Data.restPoint` and re-writes the gate's arithmetic by hand;
   no spec calls `ForestTest.restSpot`/`bedSpot` with a shift.

**(c) TARGET.** Each of the three gets a case that FAILS when its producer is deleted, and the
failing line is shown (L-093). That is the only target: a proof that does not bite is not a proof.

**(d) LEVER.**
```
src/server/ForestTest/init.luau  restSpot: local refusals = { swept = 0, band = 0, ... }  (never written)
src/server/ForestTest/init.luau  settleAim: if state.aimSettled then return state.aim, false end
tests/server/forest_stand.spec.luau  "generates a bed in the same frame it judges it in" (pure only)
```

**(e) HOW IT WILL BE MEASURED after.** The harness itself: three delete-the-producer runs, one per
finding, each naming the spec line that failed, then reverted.

## Not in scope, by the Director's decision (2026-11-12)
- **The corner stand's worst gap, 46 s against the 40 s target, is NOT a blocker.** The flag stays
  OFF. Three stand-11 flag-ON drives are measured below and their max gaps reported, nothing more.
- **Cell C1 bedding 0 with `PLACEMENT_IN_PLACE` ON is not this task** -- it goes to 345e/f. The
  control is on the record: `X11d` (both flags ON) lays 0 beds and `P11` (placement ON, aim OFF)
  also lays 0, so this cell beds nothing with or without the aim.
- **One number from round 3 is carried by neither this dispatch nor the not-in-scope list:** the
  corner stand's `peak live` is -21% against the main line (26 against 33) with `stepAvg` -19%
  (2.888 against 3.577) -- i.e. less load, not more. I flag it here rather than let it drop; it
  needs the Director to say deferred-and-where, or accepted.
