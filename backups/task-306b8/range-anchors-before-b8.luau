Range.ANCHORS = {
	-- KAREN'S PLACE, MEASURED (step B6, design 4.2's instrument): a raycast grid, 8-stud spacing,
	-- 504 samples over the 160 x 185 footprint, run in Edit and again in Play. Best centre
	-- (2650, -3300): 0 non-terrain hits, 0 misses, ground spread 11.6 studs (the lobby's own
	-- chosen site had 16). The firing line stands at the footprint's NORTH end and the lane runs
	-- SOUTH, 158 studs clear of the Road pad's south edge (`range.spec`'s own measurement), so the line
	-- points away from the lodge, the pads and the gathering yard. `plate = false` and NO TYPED Y: the
	-- the injected `groundAt`'s answer at build time, because a typed one would be a guess that
	-- puts the range in the air or inside the hill. `drawn = true`: the target is the same animal
	-- her drive draws, which in DEV (no row field) is the grey box with its real welded zones.
	["forest-test"] = { x = 2650, z = -3216, plate = false, downrange = -1, drawn = true },
	-- The DEV place, where the harness runs. Its own anchored ground plate (`plate = true`), clear
	-- of the generated map: x = 1200 is outside `Map.FIELD.bounds` (maxX 620) and outside
	-- `Map.SIZE_STUDS / 2` = 1024, so it touches neither the drive corridor nor one generated prop.
	["map:v1"] = { x = 1200, z = 0, y = 0, plate = true },
}
