--!strict
-- Lobby.Field: THE ONE WRITER OF THE LOBBY'S TERRAIN, and the only thing in this system that touches
-- `Terrain` at all. Three kinds of `FillBlock` inside one rectangle, in this order: air from the
-- voxel boundary below the shelf upwards, grass up to the shelf, then the blade-free pads.
--
--   Terrain:FillBlock https://create.roblox.com/docs/reference/engine/classes/Terrain#FillBlock
--   Enum.Material     https://create.roblox.com/docs/reference/engine/enums/Material
--
-- WHY TERRAIN AND NOT A SLAB OF PARTS (research note section 6). The measured ground over this
-- footprint spans 16 studs, so a flat slab's downhill edge would FLOAT 16 studs in the air -- which
-- is precisely the failure this project was built to stop ("Things measured correct and looked
-- wrong", docs/PROJECT_CONTEXT.md). A cut-and-filled shelf meets the hillside in a STEP instead, and
-- a step in a grass bank is what a farmyard terrace on a slope actually looks like.
--
-- THE OWNER BOUNDARY, WRITTEN OUT BECAUSE IT MOVED (design section 3.1). `MapGen.Ground`'s header
-- says it is *"THE ONLY WRITER OF `Terrain` IN THE REPO"*, and since this task that sentence needs a
-- qualifier -- so this module and that one cannot meet, by three independent facts:
--   * A DIFFERENT WORLD. `Lobby.anchorFor` has a row for `forest-test` and none for `map:v1`, so
--     nothing here runs in the DEV place at all.
--   * A DIFFERENT MODE. `MapGen` runs at EDIT time, driven step by step by `tools/mapgen.py`; this
--     runs only inside a running session, and a Play-session terrain write does not persist.
--   * A BOUNDED RECTANGLE. Every region this module computes is inside `CONFIG.FIELD`, and
--     `lobby.spec` asserts every corner of both blocks against it.
--
-- `terrain` IS AN ARGUMENT AND NEVER `Workspace.Terrain`, which is what keeps the harness out of it:
-- a spec hands in a fake with a recording `FillBlock`, so no spec in the DEV place can write DEV's
-- terrain, ever (design section 16.1 case 6).
--
-- Design: docs/design/lobby.md (sections 9, 9.1)
-- Note:   docs/research/2026-10-13-lobby-and-the-truck.md (section 6)
local Field = {}

-- THE ENGINE'S TERRAIN VOXEL, and the only value `Terrain:ReplaceMaterial` accepts (task 244).
--
-- NAMED TWICE IN THIS REPOSITORY ON PURPOSE: `Places.Ground.RESOLUTION` is the same engine fact,
-- and the two systems must not require each other -- a lobby that pulled in a drive place would be
-- a require edge between two owners that have nothing to say to one another. `lobby.spec` asserts
-- the two agree, so the duplication is CHECKED rather than trusted.
Field.RESOLUTION = 4

-- PURE. The CFrame and Size of the GRASS block: a solid slab whose TOP IS THE SHELF and whose bottom
-- reaches `DEPTH_STUDS` below it, so it meets undisturbed ground even on the lowest corner.
function Field.grassBlock(anchor: Vector3, shelfY: number, cfg): (CFrame, Vector3)
	local span = cfg.FIELD.SPAN_STUDS
	local depth = cfg.FIELD.DEPTH_STUDS
	return CFrame.new(anchor.X, shelfY - depth / 2, anchor.Z), Vector3.new(span, depth, span)
end

-- PURE. THE 4-STUD VOXEL BOUNDARY AT OR BELOW A HEIGHT, which is where the air block has to start
-- (task 311). `FillBlock` writes 4-stud voxels; a box whose face lands INSIDE a voxel writes that
-- voxel only partly, and for an AIR box that means the hill's own occupancy survives in it.
--   Terrain:FillBlock https://create.roblox.com/docs/reference/engine/classes/Terrain#FillBlock
function Field.cutBottomY(shelfY: number): number
	return math.floor(shelfY / Field.RESOLUTION) * Field.RESOLUTION
end

-- PURE. THE SHELF ITSELF, SNAPPED TO THE VOXEL GRID -- and this is the whole of the flatness fix
-- (task 311, cycle 2). Cutting on the boundary alone was MEASURED in Karen's place and it did make
-- all four bays identical (relief 1.27 -> 0.00), but it settled the surface at 151.27 instead of at
-- the shelf's 149.248 and buried the road slabs, which sit at shelfY + THICK/2 = 149.50: the yard
-- came back flat and the road came back invisible, which is task 180's photographed defect again.
--
-- A SHELF ON THE GRID HAS NO PARTIAL VOXEL AT ALL. The grass block's top, the pads' tops and the
-- air block's bottom then all land on a voxel face, every `FillBlock` covers whole voxels, and the
-- surface the engine draws is the number we asked for rather than whatever its interpolation makes
-- of a 0.31-occupancy layer. `Lobby.tryBuild` snaps the measured ground through this before it
-- becomes the anchor, so every part in the lobby is laid on the same snapped number.
--
-- FLOOR AND NOT NEAREST, AND THAT IS A FIXED POINT RATHER THAN A TASTE (review round 1, finding 1).
-- `tryBuild` can run more than once -- `Build.defaultRigSource` yields, a build can throw and is
-- retried -- and the second run reads the ground the FIRST fill produced, which is two studs above
-- the cut. With `math.round`, a cut of 148 produces 150, `round(150 / 4) = 38` cuts the second run
-- at 152, the third at 156, and every retry lifts the whole lobby a voxel. Flooring is stable:
-- `floor(150 / 4) * 4 = 148`, the cut it already made, however many times it runs. It is
-- `Field.cutBottomY`'s own arithmetic, which is the point -- the cut and the air box's bottom are
-- one number, and `lobby.spec` runs the snap twice to prove the second run does not move it.
-- Note: docs/research/2026-10-29-lobby-flagpole-and-birch-avenue.md (sections 2, 3.1)
function Field.shelfFor(measured: number): number
	return Field.cutBottomY(measured)
end

-- PURE. The AIR block that cuts the hill off. Its bottom is `cutBottomY(shelfY)` -- the voxel
-- boundary at or below the shelf -- so the band the shelf falls inside is covered WHOLE and comes
-- out empty; the grass and pad blocks are then filled back up to the shelf over a flat, empty
-- plane. It rises `CLEAR_STUDS` above the shelf, well over the worst measured ground spread and
-- the lodge's own ridge.
--
-- IT USED TO START AT THE SHELF, AND THAT WAS THE MOUND (task 311, measured in Karen's place:
-- relief 1.27 studs under bays 2 and 3, Truck4's body 1.27 studs higher than Truck1's). The shelf
-- is 149.248 and the band is 148..152, so the old box wrote 0.688 of that voxel and left the hill's
-- contour standing in it. Task 244 scrubbed the band's MATERIAL, which is all `ReplaceMaterial`
-- does, so the grass went away and the height did not.
-- Note: docs/research/2026-10-29-lobby-flagpole-and-birch-avenue.md (sections 2, 3.1)
function Field.airBlock(anchor: Vector3, shelfY: number, cfg): (CFrame, Vector3)
	local span = cfg.FIELD.SPAN_STUDS
	local clear = cfg.FIELD.CLEAR_STUDS
	local bottom = Field.cutBottomY(shelfY)
	local height = clear + (shelfY - bottom)
	return CFrame.new(anchor.X, bottom + height / 2, anchor.Z), Vector3.new(span, height, span)
end

-- PURE. The YARD'S PAD: a block of a material with no grass blades, under the buildings, whose TOP
-- IS ALSO THE SHELF. It is a LOOK fix and it was photographed rather than guessed -- the first
-- build's inside shot came back with terrain grass growing through the lodge's floorboards, because
-- a grass material draws its blades on the terrain surface and a part laid over them does not hide
-- them.
--
-- SINCE TASK 180 THERE ARE TWO OF THEM AND THIS TAKES THE ROW, because the road needed exactly the
-- same fix for exactly the same reason: its slabs were laid flush on the grass shelf and the
-- screenshot came back with a field and no road, with the player standing on it.
function Field.padBlock(anchor: Vector3, shelfY: number, pad): (CFrame, Vector3)
	local centre = anchor + pad.OFFSET
	return CFrame.new(centre.X, shelfY - pad.SIZE.Y / 2, centre.Z), pad.SIZE
end

-- PURE. THE PAD'S OWN RECTANGLE AS A `Region3`, ON THE 4-STUD VOXEL GRID -- the box whose grass is
-- scrubbed back to the pad's material after the hill has been cut off (task 244).
--
-- IT IS THE PAD'S FOOTPRINT AND NOT A NEW ONE: the same x and z the block above is laid on, so
-- "where is the yard" keeps one answer. Only the Y differs, and it is the one thing this box is
-- for -- `pad.SIZE.Y` below the shelf, which is the block itself, and `PAD_SKIN_ABOVE_STUDS` above
-- it, which is the voxel band the shelf falls inside and the hill therefore survives in.
--
-- `ExpandToGrid(4)` IS THE ENGINE'S OWN REQUIREMENT, not a rounding of ours: `Terrain:ReplaceMaterial`
-- takes a region aligned to its voxel grid, and expanding OUTWARD is the only direction that cannot
-- leave a sliver of the pad unscrubbed.
--   Terrain:ReplaceMaterial https://create.roblox.com/docs/reference/engine/classes/Terrain#ReplaceMaterial
--   Region3:ExpandToGrid    https://create.roblox.com/docs/reference/engine/datatypes/Region3#ExpandToGrid
function Field.padRegion(anchor: Vector3, shelfY: number, pad, cfg): Region3
	local centre = anchor + pad.OFFSET
	local above = cfg.FIELD.PAD_SKIN_ABOVE_STUDS
	local min = Vector3.new(centre.X - pad.SIZE.X / 2, shelfY - pad.SIZE.Y, centre.Z - pad.SIZE.Z / 2)
	local max = Vector3.new(centre.X + pad.SIZE.X / 2, shelfY + above, centre.Z + pad.SIZE.Z / 2)
	return Region3.new(min, max):ExpandToGrid(Field.RESOLUTION)
end

-- IS EVERY CORNER OF THIS BOX INSIDE THE FIELD'S OWN RECTANGLE? PURE, and it is the rule
-- *"it writes nothing outside `FIELD`"* made checkable rather than promised. The y is not bounded:
-- the rectangle is a footprint.
function Field.insideField(anchor: Vector3, at: CFrame, size: Vector3, cfg): boolean
	local half = cfg.FIELD.SPAN_STUDS / 2
	local centre = at.Position
	local dx, dz = size.X / 2, size.Z / 2
	return math.abs(centre.X - anchor.X) + dx <= half + 1e-6 and math.abs(centre.Z - anchor.Z) + dz <= half + 1e-6
end

-- THE BOX SPLIT INTO CHUNKS ALONG X. PURE, and it exists because `MapGen.Ground`'s header records a
-- MEASURED per-region voxel ceiling in this Studio version (24,576 for `WriteVoxels`). `FillBlock`
-- is a different API and its own ceiling is not measured here, so the fill is chunked the way
-- `Ground.paintTrack` already chunks its regions: one shape, whatever the ceiling turns out to be.
-- A chunk width at or over the span returns the single box unchanged.
function Field.chunks(at: CFrame, size: Vector3, chunkStuds: number): { { at: CFrame, size: Vector3 } }
	local out = {}
	local width = math.max(1, chunkStuds)
	if size.X <= width then
		table.insert(out, { at = at, size = size })
		return out
	end
	local centre = at.Position
	local minX = centre.X - size.X / 2
	local left = size.X
	local x = minX
	while left > 1e-6 do
		local take = math.min(width, left)
		table.insert(out, {
			at = CFrame.new(x + take / 2, centre.Y, centre.Z),
			size = Vector3.new(take, size.Y, size.Z),
		})
		x += take
		left -= take
	end
	return out
end

-- THE ONLY TERRAIN WRITE IN THIS SYSTEM. AIR FIRST, then grass, then the pads (task 311): the air
-- box now reaches BELOW the shelf, down to the voxel boundary, so it has to run before the grass it
-- would otherwise eat. Grass and pads then fill that empty, boundary-aligned plane back up to the
-- shelf, each writing one uniform partial voxel -- which is what makes the surface flat.
--
-- IT WAS GRASS -> PAD -> AIR UNTIL THIS TASK, with the air starting AT the shelf, and in that order
-- the shelf's own voxel band was never cut: see `Field.airBlock` for the 1.27 studs that left under
-- the trucks. Order and bottom are one change; either alone is wrong.
--
-- Returns how many `FillBlock` calls it made and how many of them were grass, so "which path it
-- took" is a number in `Lobby.stats()` and not a belief (design section 18 item 1).
function Field.fill(terrain: any, anchor: Vector3, shelfY: number, cfg): (number, number, number)
	local chunk = cfg.FIELD.CHUNK_STUDS
	local calls, grassCalls = 0, 0
	local airAt, airSize = Field.airBlock(anchor, shelfY, cfg)
	for _, piece in ipairs(Field.chunks(airAt, airSize, chunk)) do
		terrain:FillBlock(piece.at, piece.size, Enum.Material.Air)
		calls += 1
	end
	local grassAt, grassSize = Field.grassBlock(anchor, shelfY, cfg)
	for _, piece in ipairs(Field.chunks(grassAt, grassSize, chunk)) do
		terrain:FillBlock(piece.at, piece.size, cfg.FIELD.MATERIAL)
		calls += 1
		grassCalls += 1
	end
	-- THE PAD LAST OF THE THREE FILLS: it replaces the top of the grass shelf under the buildings,
	-- on the same boundary-aligned plane the grass was just laid on.
	for _, pad in ipairs(cfg.FIELD.PADS) do
		local padAt, padSize = Field.padBlock(anchor, shelfY, pad)
		for _, piece in ipairs(Field.chunks(padAt, padSize, chunk)) do
			terrain:FillBlock(piece.at, piece.size, pad.MATERIAL)
			calls += 1
		end
	end
	-- ...AND LAST, THE MATERIAL THE FILL COULD NOT REACH (task 244, Karen: *"move all trucks to
	-- right so it not going to be on grass"*). Every pad above declares itself blade-free, and
	-- until this line three of the four truck bays were not: the shelf falls INSIDE a 4-stud voxel
	-- band, so a pad block whose top is the shelf writes only part of that voxel and the hill's
	-- grass keeps its MATERIAL; the air block then trims the height and leaves the material alone.
	-- `PAD_SKIN_ABOVE_STUDS`' own comment carries the measurement and why filling higher is the
	-- wrong fix (it lifts the yard and buries the road).
	--
	-- AFTER ALL THREE FILLS AND NOT BEFORE THEM: the air is what decides which voxels are there at
	-- all, and scrubbing first would scrub a hill that is about to be cut away. Since task 311 the
	-- air box cuts the shelf's own band too, so this call has little left to do -- it is KEPT, not
	-- trusted, because a material is cheap to correct and `lobby.spec` counts the calls.
	--
	-- IT CHANGES A MATERIAL AND NOTHING ELSE -- no occupancy, no height, no part -- and only
	-- `FIELD.MATERIAL` is replaced, so a rock or a path laid in this rectangle by anything else is
	-- untouched.
	--
	-- UNGUARDED, exactly as the three `FillBlock` loops above are: `terrain` is injected so that no
	-- spec can write the DEV place's terrain, not so that a fake may answer half the contract. A
	-- stand-in without this method is a stand-in that would hide the defect this line fixes, and it
	-- fails loudly on the first build instead.
	local replaced = 0
	for _, pad in ipairs(cfg.FIELD.PADS) do
		terrain:ReplaceMaterial(
			Field.padRegion(anchor, shelfY, pad, cfg),
			Field.RESOLUTION,
			cfg.FIELD.MATERIAL,
			pad.MATERIAL
		)
		replaced += 1
	end
	return calls, grassCalls, replaced
end

return Field
