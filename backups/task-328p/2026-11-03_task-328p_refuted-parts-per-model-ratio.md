# Archived: the refuted "~7 parts a model" ratio and the `< 3,600 models` bound (task 328p)

Rule 7. Nothing here is deleted; this is the record of what task 328p replaced.

**Why.** Karen, 2026-11-03 ~11:20 UTC, C1 playtest 2 (`PLAYTEST.md`): *"more trees"*. The bound that
said no was `grid.spec` case 14's `capacity < 3600` / `total < 3600`, derived in `grid-map.md` section
8.3 from *"parts per drive < 22,000 -- ~7 descendants per model"*. **Measurement refuted the ratio:**
3.03 parts a model (5,104 parts for 1,687 planted models in C1, task 328m, re-derived by the
Reviewer in `reviews/task-328m/RESULT.md`). The two published bounds never agreed with each other
either: 3,600 x 7 = 25,200, which is 3,200 parts past the same section's own 22,000 ceiling.

**What replaces it.** `Places.PARTS_PER_MODEL` 3.03 with `PART_BUDGET_DRIVE` 22,000 and
`PART_BUDGET_CELL` 8,000, and the two caps COMPUTED from them: `CELL_PLAN_CAP` = 7,260 and
`CELL_PART_CAP` = 2,640. C1's room goes from 184 models to 953. Design:
`docs/design/grid-roads.md` section 8. Note: `docs/research/2026-11-03-curved-grid-roads.md` section 4.

**The rollback** is this file: restore the three blocks below and `grid-map.md` section 8.3 binds again.

---

## 1. `docs/design/grid-map.md` section 8.3 -- the two rows that are superseded (verbatim)

The section itself is NOT edited (it is superseded by the new section 19, exactly as section 18
supersedes 4.5 and 8.1-8.3). These are the two rows that stop binding:

```
| **models per drive** | **≈ 2,400; hard bound < 3,600** | `Places.capacity`, asserted as `#list <= capacity` |
| **parts per drive** | **< 22,000** | ≈ 7 descendants per model (`drive-places.md` §11). **Printed, never assumed** |
```

`PART_BUDGET_DRIVE` keeps the 22,000. Only the ratio and the 3,600 are refuted.

## 2. `src/shared/Places/init.luau` -- `cellCapacity`'s header (verbatim)

```luau
-- THE UPPER BOUND ON WHAT ONE CELL PLANTS, known before anything runs: every grid's cell count, with
-- nothing subtracted for the lane rule or the gap rule. Design 8.3's hard bound is 3,600 models a
-- drive and `grid.spec` case 14 asserts BOTH halves -- `#plantCell(id) <= this` and `this < 3600`.
function Places.cellCapacity(cellId: string): number
```

## 3. `tests/server/grid.spec.luau` -- case 14 as it stood (verbatim)

```luau
	-- ---------------------------------------------------------------- 14. under the declared capacity

	describe("the budget", function()
		it("holds every cell under its own bound and every bound under 3,600 models", function()
			local worstId, worstTotal, worstCap = "", 0, 0
			local lines = {}
			for _, id in ipairs(Grid.cellIds()) do
				local capacity = Plan.cellCapacity(id)
				local total = #woods[id]
				expect(total <= capacity).to.equal(true)
				-- DESIGN 8.3'S HARD BOUND, ON THE BOUND ITSELF and not only on today's draw: a
				-- density tweak that would breach it fails here before anything is cloned.
				expect(capacity < 3600).to.equal(true)
				expect(total < 3600).to.equal(true)
				-- ...AND THE SAME FUNCTION UNDER THE NAME EVERY OTHER CALLER USES.
				expect(Plan.capacity(Grid.layoutFor(id), Plan.cellPlanFor(id))).to.equal(capacity)
				if total > worstTotal then
					worstId, worstTotal, worstCap = id, total, capacity
				end
				local trees, ferns, skirt = 0, 0, 0
				for _, item in ipairs(woods[id]) do
					if item.band == "herb" then
						ferns += 1
					elseif item.side < 0 then
						skirt += 1
					else
						trees += 1
					end
				end
				table.insert(lines, string.format("%s %d(t%d f%d s%d)/%d", id, total, trees, ferns, skirt, capacity))
			end
			TestKit.note(
				string.format(
					"per cell: %s -- worst %s %d of %d",
					table.concat(lines, " "),
					worstId,
					worstTotal,
					worstCap
				)
			)
		end)
	end)
```
