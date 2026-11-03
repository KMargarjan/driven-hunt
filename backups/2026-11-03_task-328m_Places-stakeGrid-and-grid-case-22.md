# Archived 2026-11-03, task 328m: the grid preview's 32 corner stakes

## Why

Karen played C1 in her Forest Test on 2026-11-03 and said of a frame from a road junction, two tall
yellow-orange pillars either side of the road: **"those gates shouldnt be"**. They are the corner
stakes task 327a planted behind `GRID_PREVIEW` to show where the eight cells are while the grid was
being built. The grid is built; the stakes are a scaffold standing in the game she plays.

Removed: `Places.STAKE`, `Places.gridStakes`, `Places.stakeGrid` (`src/server/Places/init.luau`), the
`gridStakes` / `gridMissing` report fields, their `[ForestTestBoot] grid:` print, and
`tests/server/grid.spec.luau` case 22's stake half. `Places.GRID_FOLDER` (`GridPlaces`) STAYS: the
cell's wood is dressed into it, and `ForestTest.GROUND_IGNORE` names it.

## The code, as it stood at 056f085c

```luau
-- src/server/Places/init.luau

-- A CORNER STAKE: a tall thin orange pillar at each of the eight cells' four corners, 32 in all.
--
-- `CanCollide` AND `CanQuery` ARE BOTH FALSE, and that is not tidiness: a queryable stake standing
-- inside the footprint would answer `ForestTest.groundAt` as "the ground" and would stop a bullet.
-- `Neon` so it reads from the far end of a 1070-stud cell.
Places.STAKE = table.freeze({
	sizeStuds = Vector3.new(3, 60, 3),
	colour = Color3.fromRGB(255, 132, 0),
	material = Enum.Material.Neon,
	-- HOW MANY GO IN BEFORE THE FRAME IS GIVEN BACK. 32 parts is nothing, but the slice is the
	-- pattern this system uses everywhere and a later task plants 2,400 models through it.
	perStep = 8,
})

-- THE FOUR CORNERS OF EVERY CELL, as a flat list. PURE -- no world, no terrain. The name carries the
-- cell id and the corner, so a frame of a stake says which cell it belongs to.
function Places.gridStakes(): { { name: string, x: number, z: number } }
	local out: { { name: string, x: number, z: number } } = {}
	for _, id in ipairs(Grid.cellIds()) do
		local box = Grid.boundsOf(id)
		-- NORTH IS THE LARGER z in this world (`ForestTest.EXIT_SOUTH_STUDS`: a boar is gone to the
		-- south), so NW/NE are at maxZ.
		for _, corner in ipairs({
			{ "SW", box.minX, box.minZ },
			{ "SE", box.maxX, box.minZ },
			{ "NW", box.minX, box.maxZ },
			{ "NE", box.maxX, box.maxZ },
		}) do
			table.insert(out, {
				name = string.format("Stake_%s_%s", id, corner[1] :: string),
				x = corner[2] :: number,
				z = corner[3] :: number,
			})
		end
	end
	return out
end

-- STAKE THE EIGHT CELLS' CORNERS. Returns how many went in and how many had no ground under them.
--
-- `enabled`, `folder` AND `terrainYAt` ARE ALL ARGUMENTS: a spec drives this into a fake folder with
-- a fake hillside, and `enabled = false` parents nothing at all. `breathe` is the slice.
function Places.stakeGrid(
	folder: Instance?,
	terrainYAt: (number, number) -> number?,
	enabled: boolean,
	breathe: (() -> ())?
): (number, number)
	if not enabled or folder == nil then
		return 0, 0
	end
	local made, missing, since = 0, 0, 0
	for _, stake in ipairs(Places.gridStakes()) do
		local y = terrainYAt(stake.x, stake.z)
		if y == nil then
			missing += 1
		else
			local part = Instance.new("Part")
			part.Name = stake.name
			part.Size = Places.STAKE.sizeStuds
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Material = Places.STAKE.material
			part.Color = Places.STAKE.colour
			part.Position = Vector3.new(stake.x, y + Places.STAKE.sizeStuds.Y / 2, stake.z)
			part.Parent = folder
			made += 1
			since += 1
			if breathe ~= nil and since >= Places.STAKE.perStep then
				since = 0
				breathe()
			end
		end
	end
	return made, missing
end
```

```luau
-- src/server/Places/init.luau, inside Places.build, under `if previewOn then`
		local made, missing = Places.stakeGrid(folder, reader, true, breathe)
		report.gridStakes, report.gridMissing = made, missing
```

```lua
-- src/server/ForestTestBoot.server.luau
print(
	string.format(
		"[ForestTestBoot] grid: preview=%s, %d corner stake(s), %d without ground, %.2fs",
		tostring(gridPreviewOn),
		planted.gridStakes,
		planted.gridMissing,
		planted.gridSeconds
	)
)
```

`tests/server/grid.spec.luau` case 22's stake assertions (`report.gridStakes == 32`,
`report.gridMissing == 0`, `#folder:GetChildren() == 32`, the per-child `Stake_` / `CanQuery` /
`CanCollide` / `Anchored` / no-tag loop, and `off.gridStakes == 0`) are archived with them. The case
itself SURVIVES, asserting what the preview still is: the folder exists with the flag on, holds no
part of its own, tags nothing, builds no stand or seat, moves no layout, and is destroyed with the
flag off.

## Rollback

Paste `Places.STAKE`, `Places.gridStakes` and `Places.stakeGrid` back into `src/server/Places/init.luau`
(`Grid` is already required there), put the two lines back under `if previewOn then`, restore the
three report fields (`gridStakes`, `gridMissing` in both the `no-ground-reader` early return and the
`report` table), restore the boot print, and restore case 22's stake assertions.
