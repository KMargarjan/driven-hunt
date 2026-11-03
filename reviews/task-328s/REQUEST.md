# Task 328s -- C1's forest, re-planted denser on the bent ground

Task: 328s
Round: 1
Base: 14581cc7
Code commit: (pending)

## PLAN (Core Quality Protocol step 0, committed before any `src/` edit)

**(a) REAL LIFE.** A managed mixed wood carries 1,000-2,500 stems a hectare at 2-3 m between stems
(FAO/European yield-table range for a 40-80 year spruce/birch stand). One Roblox stud is ~0.28 m at
this world's tree heights (`Places.SPECIES`: 56-156 studs for a mature spruce = 16-44 m), so 2-3 m
is **7-11 studs** between trunks and a mature wood has TWO storeys, not one. Karen, 2026-11-03:
*"it's not broken trees it's good has to be a bit more realistic more trees but rest is good"*.

**(b) MEASURED NOW**, in a fresh DEV Play server at base `14581cc7` (`<runs-dir>/328s-yield.luau`,
run through `ftplay.py server` with `SMOKE_PLACE` = DEV; an **Edit**-session probe answers with the
stale `require` cache -- it read `bend 0/0` while `Grid`'s Source read 45 -- so every reading here is
from a Play DataModel):

```
TOTAL offeredCentres=3416 maskFree=2654 planted=1789 capacity=3416 PLAN_CAP=7260 PART_CAP=2640 minGap=12
bend={"nsStuds":60,"harmonic":1,"ewStuds":45}
```

So at the grid centres the **mask** refuses 762 of 3,416 (22.3 %) -- ditch 225, corridor 150, ride
149, verge 132, clearing 90, field 16, **road 0** -- and the planter then loses a further **865** of
the 2,654 the mask allowed (32.6 %) to the gap rule, the crown term and the jitter. **The second
loss is larger than the whole mask**, which is 328p's measured hypothesis (*"what limits more trees
first is the GAP RULE and `Places.mask`, not the new bound"*) re-derived at this commit and at the
bend. 328p's own figures (1,823 planned, 1,823->2,109 at `minGapStuds` 4) were read at `bend 0/0`;
the bent planner plans **1,789**, so they are a hypothesis, not a given (L-167).

**(c) TARGET.** C1's PLANNED count **>= 2,300** and **<= `Places.CELL_PART_CAP` 2,640**, with
`cellCapacity` <= `CELL_PLAN_CAP` 7,260 (`grid.spec` case 14's three assertions, unchanged). 2,300 is
the dispatch's floor (+28.6 % on 1,789); the cap is the part budget and is what stops it going
further.

**(d) LEVER.** The writers, by `grep`, all in `src/shared/Places/init.luau`:
* `scatter`'s gap test -- `if rowsFor ~= nil and band ~= nil and #rowsFor > 0 and not tooClose(grid, jx, jz, gap) then`
  -- fed by `plan.minGapStuds` at the four `scatter(...)` call sites in `plantCell`;
* `tooClose` itself -- `grid[key] = grid[key] or {}` / `table.insert(grid[key], { x = x, z = z })`:
  it RESERVES the site before the crown term has had its say, so a crown-refused site still blocks
  its neighbours;
* the per-zone `spacingStuds` and `under.spacingStuds` rows of `Places.CELL_PLANS.mixedRolling`.

**(e) HOW IT WILL BE MEASURED AFTER.** The same probe, same place, same command -- plus the
per-rule tally this task adds to `scatter`, so the split between gap, crown and mask is counted
where it happens instead of inferred from two totals.
