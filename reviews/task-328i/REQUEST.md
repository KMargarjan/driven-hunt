# Task 328i -- the forest behind the line: the baked cells beyond C1, at C1's accepted density

Task: 328i
Round: 1
Base: 2d28e98a
Code commit: (pending)

## PLAN (Core Quality Protocol step 0, committed before any `src/` edit)

**(a) REAL LIFE.** A managed 40-80 year mixed stand carries 1,000-2,500 stems a hectare at 2-3 m
between them (328s's own cited figure). One stud is ~0.28 m at this world's tree heights
(`Places.SPECIES`), so 2-3 m is **7-11 studs**; C1 ships `minGapStuds` **11** (~3.1 m) and Karen
accepted it on 2026-11-04: *"rest seems ok I think you did good job"*.

**(b) MEASURED NOW** -- Karen's Forest Test (130094961655666) Play server on `main`'s code,
`<runs-dir>/328i-base.luau` -> `328i-base.txt`, and the boot's own line in the console:

* `Workspace.GridPlaces` holds **C1 AND NOTHING ELSE**: 2,275 models / 7,726 parts at the probe,
  and the boot line reads `grid wood C1: 2393 of 2450 planted (8128 parts) ... 22.26s`.
  `Workspace.GridForest` is **absent**.
* The cause is one line: `Places.build` calls `Places.dressCell(Grid.PREVIEW_CELL, ...)` -- **once**,
  for one cell. Seven cells have never had a tree planted in them in any session.
* Planned per cell under `main`'s recipes: C1 **2,450** · C2 **1,689** · A2 **1,431** · B1 **1,754**
  · D1 **1,204** (out of scope: A1 1,704, B2 1,682, D2 1,372).
* So, as a fraction of C1's accepted density -- all eight cells are the same 1,070 x 1,430 size, so
  the planned count IS the density -- **C2 69 %, A2 58 %, B1 72 %, D1 49 %**.

**(c) TARGET.** Each planted cell's PLANNED count **>= 2,300** and **<= `CELL_PART_CAP` 2,640**,
with `cellCapacity` **<= `CELL_PLAN_CAP` 7,260`**. That is **328s's own accepted target for C1**,
quoted unchanged and applied to the cells behind the line -- not a new number.

**(d) LEVER.** `Places.CELL_PLANS.<recipe>` for the four cells, plus the single `dressCell` call.

**(e) HOW IT WILL BE MEASURED AFTER.** The same probe as (b), with the branch's `Places` injected
into the same Play session (328m's route), then the real plant and `GridCensus.survey`.
