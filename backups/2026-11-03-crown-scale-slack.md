# Archived: `Places.CROWN_SCALE_SLACK` (task 328l, 2026-11-03)

Rule 7: nothing is deleted, it is archived with a note. Retired by the Director's decision of
2026-11-03 02:50 UTC (`ESCALATE.md`), whose proof condition is `crownOverRoad` still 0 with the
slack gone.

## What it was

```luau
-- ...AND HOW FAR `TEMPLATE_DIMS.scale` IS FROM THE TEMPLATE THAT IS ACTUALLY STANDING THERE, which
-- is the second thing between the planner's reach and the census's. The planner knows `item.scale`
-- (relative to the template) and the census divides `model:GetScale()` by `dims.scale`, so the two
-- agree only while `dims.scale` IS the template's own `GetScale()`. **IT IS NOT, for 27 of the 35**
-- -- measured in Karen's Forest Test on 2026-11-03 (`driven-hunt-runs/328f-dims.luau`), ratios
-- `live / row` from 0.589 (`Forest_OakTree_Var02_LOD_0`) to **1.371** (`SilverBirch_Var01_LOD_0`).
-- That is `TEMPLATE_DIMS`' defect, not this rule's, and re-measuring the table is task 328b's; until
-- it is, the planner carries the worst ratio so the CENSUS's reach is always the one covered.
-- MEASURED CONSEQUENCE of not carrying it: one `SM_AspenTree_Var04` (live 0.8081, row 0.6135) came
-- out 3.17 studs over a road, planner reach 18.76 against the census's 30.58.
Places.CROWN_SCALE_SLACK = 1.40
```

It multiplied `Places.crownReachStuds`, so every crown set-back carried 40 % of slack.

## Why it is gone

The ratio it covered was never a template being rescaled. `Workspace.OurForest` is the **wood**: each
of the 35 species names has 16 to 125 standing instances whose own scales span **x1.65 to x1.84**
(`tools/forest_ground.py dims`, 2026-11-03: `Old_Spruce_Tree_Var01_LOD_0`, 21 instances, 0.2855 to
0.4703). `FindFirstChild(name)` answered an arbitrary one, so the row described a different tree from
one session to the next. `Places.nearestScale` + `Places.pickTemplate` now choose the instance the
row was measured on and `Places.rescaledReason` quarantines a name whose chosen instance is more than
2 % off it, so `live / row` is 1.000 for all 35 and the planner's reach IS the census's.

## Also corrected here (task 328f note (a))

The archived header's own figure was wrong: with crown 19.60, row scale 0.6135 and the census's reach
30.58, the planted `GetScale()` is 0.957, so `item.scale` was 1.184 and the planner's reach was
**23.2**, not 18.76. The ratio the slack had to cover was `live / row` = 1.317 for that template and
1.371 worst over the 35.

## How to put it back

Restore the constant and the `* Places.CROWN_SCALE_SLACK` factor in `Places.crownReachStuds`. It is
needed only if `TEMPLATE_DIMS` is allowed to describe an instance the planter does not clone again --
i.e. only if `Places.pickTemplate` is deleted, which `tests/server/grid_ground.spec.luau` case 2c
refuses.
