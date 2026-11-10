PASS (item 3 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the VISUAL half has been seen in
Karen's place — `MEASUREMENTS.md` section 10 opens and describes `346b-afterW-F3.png`,
`346b-afterW-F2.png` and `346b-afterY-F1.png` at her own cameras, each against its `at360d` pair,
and says honestly that F3 is "a scatter and not a wall" and that F2's left quarter is still bare
hill. What has NOT been seen in her place is the CONSEQUENCE of item 3: no shot was fired at the
cheap band and no animal was driven into it. The four cleared properties are proven by a counting
case on a clone (`grid_ground.spec`), which proves the properties and not the shot path — a trunk
230-420 studs out now stops no pellet and no body, and nobody has watched that happen.

Round 1's finding is fixed, and fixed properly: the near-band line is now
`expect(band.spacing).to.equal(if band.deep then plan.deepSpacingStuds else plan.spacingStuds)`.
Delete-the-producer, by reading, on every case offered as proof:
- `grid.spec` case 16b, deepest arm — drop `cheap = cheap` from `Places.skirtBands` and
  `expect(band.cheap).to.equal(true)` goes red; drop
  `spacing = if cheap then Places.SKIRT_CHEAP_SPACING_STUDS else band.spacing` and
  `expect(band.spacing).to.equal(Plan.SKIRT_CHEAP_SPACING_STUDS)` goes red (52 ~= 34).
- `grid.spec` case 16b, near arm — hand 34 studs to every band and the new line goes red against
  `plan.spacingStuds` (26 or 24 on all eight recipes, line 1133-1482) / `plan.deepSpacingStuds`
  (52 or 60). `band.deep` separates band 1 (`near = 0`) from band 2 (`near = skirtFullStuds` 80)
  correctly. No surviving line.
- `grid.spec` case 16b, the feed — `cheap` is counted off `woods[id]` (`Plan.plantCell`), so
  deleting `cheap = if opts ~= nil and opts.cheap then true else nil` in `scatter`, or
  `cheap = band.cheap` in `plantCell`'s skirt call, reddens `expect(cheap > 0)`. That call is the
  ONLY one of the five `scatter` calls that passes `cheap`, so `expect(stray).to.equal(0)` is
  meaningful.
- `grid_ground.spec` "a cheap far-band clone casts no shadow..." — the control is the SAME template
  planted without the flag, two distinct clones, not one identity under two names. `Places.quieten`
  / `unblockFoliage` touch `CanQuery` and `CanCollide` on foliage-named parts only and never
  `CastShadow`, so with the `item.cheap` block in `plantOne` deleted the cheap clone's `Trunk` and
  `SM_Leaves` both keep `CastShadow` and `shadows` reads 2, not 0 — red. `DrivePlaceCheap` goes nil
  there too.
- Claim 1 — `Places.SKIRT_CHEAP_FROM_STUDS = 150`, `cheap = band.near >= 150`, and the three band
  `near` values are 0 / 80 / 230, so exactly one qualifies and `deepest = band.near >= 230` picks
  the same one. True as stated.
- Claim 9 arithmetic — 32000/3.76 = 8510.6 -> 8510, 16000/3.76 = 4255.3 -> 4255, and case 14
  recomputes both from the budgets before pinning them. `cellCapacity` sums `band.spacing` off
  `skirtBands`, so the 34-stud grid moves the bound it is checked against.
- Claims 4/6 arithmetic — 30/37 = 81.1 %, 8/37 = 21.6 %, 15/37 = 40.5 %, 11/37 = 29.7 %; all six
  p95 figures are the correct medians of the three samples printed beside them; +82.3 / +89.8 MB
  are the stated differences.
- Harness/paperwork — `[harness] PASS: 34/34 checks @ 2487dddb... (clean tree) scope=all` names the
  request's `Code commit:`, `paperwork-after-code-commit.txt` says only `TASKS.md`, `REQUEST.md` and
  `MEASUREMENTS.md` followed it, `log.txt` confirms the last `src`/`tests` commit is `db197aea`
  (before the tested commit), selene 0/0 on both trees, stylua clean, rojo builds.

## Notes (non-blocking)
- `reviews/task-346b/REQUEST.md` claim 8 and `MEASUREMENTS.md` 8 — both cite `grid.spec:2687` as
  `expect(band.cheap).to.equal(true)`. After round 2's edit 2687 is `deepBands += 1` and the
  assertion is at 2690. The run itself predates the round-2 spec, which is strictly stronger (it
  adds the near-arm `cheap == false` and the plan-side spacing), so the conclusion still holds by
  reading — but say the deletion run was made at `1d2bc385`/`b397aa41`, not at the code commit.
- `src/shared/Places/init.luau` / `Places.SKIRT_CHEAP_FROM_STUDS` header — "Today exactly one band
  qualifies, the deepest (230 to 420) -- band 2 starts at 80, where a player can still walk" reads
  as a claim that nobody walks at 230+. That is true only at an OUTER edge, where the band is
  measured from `Grid.footprint()`. On an INTERIOR side `skirtBands` sets
  `clipLow, clipHigh = theirs.minX, theirs.maxX`, so the cheap band stands 230-420 studs INSIDE the
  neighbouring cell's own ground, on walkable land across one road, and nothing stops a hunter
  crossing it. One sentence in the header would say which case the rationale covers.
- `src/server/Places/init.luau` / `Places.build`'s header — "a planted trunk keeps `CanQuery = true`
  (it has to stop a bullet)" is now false for 825 of C1's models. The conclusion it supports (the
  ground reader must be terrain-only) is unaffected, but the sentence is a changed file's own
  comment made untrue by the change beside it.
- Round 1's shot-path note was neither fixed nor queued. `TASKS.md` has one `346b` row and no
  `346b-notes` row, so the measurement it asked for is now recorded nowhere: on an interior side the
  cheap band's near edge sits roughly 272 studs from a stand near the cell edge (half road + inset +
  230) and `Shotgun.RANGE_STUDS.Slug` is 330, so a slug can reach the band and pass through every
  trunk in it. Queue it before Karen reports a tree that does not stop a bullet.
- `tests/server/grid.spec.luau` / case 16b — `expect(cheap > 0)` is still a floor of ONE against a
  measured 825 (C1) and 731 (A2). The gate is not open, because `BENT_C1`/`STRAIGHT_C1` 4,020/4,036
  pin the exact plan total and move with the cheap grid; a per-cell floor (`cheap >= 300`) would pin
  the band itself. Same shape as 346a note (e).
- `reviews/task-346b/REQUEST.md` claim 3 — "counts all four properties against a control that keeps
  them". The cheap side counts four; the control's own assertions are `keptShadow > 0` and
  `keptQuery > 0` only, so `CanCollide` and `CanTouch` are asserted on the cheap clone and on
  nothing else.
- `src/shared/Places/init.luau` — no flag and no dial. `SKIRT_CHEAP_FROM_STUDS` and
  `SKIRT_CHEAP_SPACING_STUDS` are plain constants, consistent with task 346's own
  `SKIRT_DEEPEST_STUDS`/`SKIRT_WIDEN_STUDS`, so if Karen dislikes shadowless scenery behind the road
  there is nothing to switch off without a code change.

---
REVIEWER verdict on commit `e3729595848602b665775dbcd811e303228561b5` (round 2) · 2026-11-10 22:38 UTC · session cost $2.51, 30 turns · written by tools/agents.py
