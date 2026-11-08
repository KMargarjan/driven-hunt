# Archived in task 337: `dressCell`'s keep set, `dressCells`/`dressPending`'s `keepIds`,
# `Places.build`'s `report.gridPending`, the plant seam's keep list, and the boot's deferred dress

Rule 7. Nothing here is deleted; this file is the rollback.

**Why.** Karen, 2026-11-08: *"we only load one per game thats it"*. Under one cell at a time the
four cells the deferred dress planted had no next action but to be stored -- 71.8 s of planting with
no product (task 328i's own measurement) -- and the keep set was the mechanism that felled a stored
forest in task 335 (`reviews/task-335/RESULT.md`). `Places.dressCell` now destroys only the cell it
is dressing, so there is no call shape left that can fell a cell the caller did not name, and which
cell STANDS is `Places.Cells`' question -- answered by moving folders, never by destroying them.
Design: `docs/design/cell-loading.md` sections 6.1 and 7.

**Rollback.** Restore the five pieces below and re-add `Cells`-free wiring in `ForestTestBoot`.

---

## 1. `Places.dressCell`'s seventh parameter and its destroy loop (`src/server/Places/init.luau`)

```luau
	breathe: (() -> ())?,
	clock: (() -> number)?,
	-- WHICH OTHER CELLS' WOOD SURVIVES THIS DRESS (task 328i). nil is the one-cell contract this
	-- function was born with: every other cell goes. A set of ids keeps those, so `dressCells` can
	-- stand five woods up without each one felling the last. The cell being dressed is ALWAYS
	-- destroyed first, in the set or not -- that is what re-planting it means.
	keep: { [string]: boolean }?
): { [string]: any }
```

```luau
	for _, folder in ipairs(Places.cellWoodFolders(gridFolder)) do
		if folder.Name == cellId or keep == nil or keep[folder.Name] ~= true then
			table.insert(old, folder)
		end
	end
```

## 2. `Places.dressCells`' `keepIds` (`src/server/Places/init.luau`)

```luau
	-- WHICH CELLS SURVIVE, when that is not the same list as the one being dressed (task 328i,
	-- reviewer round 1). The deferred dress plants four cells and must not fell the fifth, which is
	-- already standing and is the one the player is in. nil keeps exactly what it dresses.
	keepIds: { string }?
): { { [string]: any } }
	local keep: { [string]: boolean } = {}
	for _, id in ipairs(keepIds or cellIds) do
		keep[id] = true
	end
```

## 3. `Places.dressPending`'s `keepIds` and its tail line

```luau
	keepIds: { string }?
...
	return Places.dressCells(cellIds, gridFolder, groundAt, template, breathe, nil, keepIds or cellIds)
```

## 4. `Places.build`'s `report.gridPending`

```luau
	if previewOn and gridFolder ~= nil then
		local list = cells or Grid.PLANTED_CELLS
		local first: { string } = if list[1] ~= nil then { list[1] } else {}
		local rest: { string } = {}
		for index = 2, #list do
			table.insert(rest, list[index])
		end
		report.gridWoods = Places.dressCells(first, gridFolder, reader, template, breathe, nil, list)
		report.gridPending = rest
	end
```

## 5. `tools/terrainbake.py`'s `PLANT_SEAM` keep list, and `command_plant`'s argument

```python
        local keep = {%s}
        local reports = Planter.dressCells({"%s"}, folder, terrainYAt, template, function()
            task.wait()
        end, nil, keep)
```

```python
    keep = ",".join('"%s"' % c for c in cells)
    ...
        row = call(studio, studio_id, PLANT_SEAM % (keep, cell_id), timeout=BAKE_CALL_TIMEOUT,
                   injected=injected)
```

The `selftest` case that asserted it read: *"the plant seam drives Places.dressCells -- the ONE
writer -- with no yield and the whole cell list as keep"*, with `"local keep = {%s}" in PLANT_SEAM`.

## 6. The boot's deferred dress (`src/server/ForestTestBoot.server.luau`), verbatim

```luau
-- THE CELLS BEHIND THE LINE, PLANTED AFTER EVERY OWNER IS UP (task 328i, reviewer round 1).
--
-- **HERE AND NOT IN `Places.build`, AND THAT IS THE WHOLE REASON THE SPLIT EXISTS:** `build` is
-- this file's composition root, so every second it spends planting is a second with no lobby, no
-- shop, no match and no gun. One cell is ~34 s of sliced planting and five are ~172 s. `build`
-- dresses the cell the player stands in and hands the other four back in `gridPending`; they fill
-- in behind him on this thread, which starts only now, below `HitLog.start` and `ForestTest.start`.
-- `Grid.PLANTED_CELLS` is passed as the KEEP list so the cell already standing is not felled.
task.spawn(function()
	for _, wood in
		ipairs(Places.dressPending(planted.gridPending or {}, workspace, ForestTest.terrainYAt, function()
			task.wait()
		end, Grid.PLANTED_CELLS))
	do
		print(
			string.format(
				"[ForestTestBoot] grid wood %s (deferred): %d of %d planted (%d parts), %d on a step, %d skipped, "
					.. "%d missing, %d destroyed, capacity %d, %d slice step(s) avg %.2f ms worst %.2f ms over budget %d, %.2fs",
				tostring(wood.cell),
				wood.planted,
				wood.wanted,
				wood.parts,
				wood.cliff,
				wood.skipped,
				wood.missing,
				wood.destroyed,
				wood.capacity,
				wood.steps,
				wood.stepMsAvg,
				wood.stepMsMax,
				wood.overBudgetStarts,
				wood.seconds
			)
		)
	end
end)
```
