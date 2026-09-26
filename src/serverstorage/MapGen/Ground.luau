--!strict
-- MapGen.Ground: THE ONLY WRITER OF `Terrain` IN THE REPO (design section 2.2). One tile per call.
-- It reads no Instance and writes none; it asks `Height` where the ground is and `Layout` what is on
-- it, so nothing here can disagree with the props or the markers about the shape of the world.
--
--   Terrain:WriteVoxels  https://create.roblox.com/docs/reference/engine/classes/Terrain#WriteVoxels
--   Terrain:ReadVoxels   https://create.roblox.com/docs/reference/engine/classes/Terrain#ReadVoxels
--   Region3:ExpandToGrid https://create.roblox.com/docs/reference/engine/datatypes/Region3
--
-- MEASURED 2026-09-26 (design section 13.5 measurement A, an Edit-mode execute_luau probe):
--   * a 128 x 128 x 96-stud region at resolution 4 is accepted -- 32 x 24 x 32 = 24,576 voxels;
--   * resolution 8 and resolution 2 are BOTH refused, with "Resolution has to be 4".
-- So the tile size is a choice and the resolution is not one. The occupancy arrays are indexed
-- [x][y][z], 1-based, in the region's own order.
--
-- Design: docs/design/map-generator.md (sections 2.2, 5.2)
local Workspace = game:GetService("Workspace")

local Height = require(script.Parent:WaitForChild("Height"))
local Layout = require(script.Parent:WaitForChild("Layout"))

local Ground = {}

local AIR = Enum.Material.Air

local function regionFor(minX: number, minZ: number, config): Region3
	return Region3.new(
		Vector3.new(minX, config.BAND_Y.min, minZ),
		Vector3.new(minX + config.TILE_STUDS, config.BAND_Y.max, minZ + config.TILE_STUDS)
	):ExpandToGrid(config.VOXEL)
end

-- Leaf litter everywhere in the wood; gravel on the benches and tracks; Grass on the steep columns
-- and on the flank farmland; Mud in the bog. One slope number instead of a second noise field. Called ONCE PER
-- COLUMN, not once per voxel: at 24,576 voxels a tile and ~6 math.noise calls a height, per-voxel
-- would be about 600,000 noise evaluations for a tile that needs 3,000.
local function surfaceMaterial(x: number, z: number, h: number, seed: number, config, pads): Enum.Material
	-- The bog first: where the ground dips, the ground is mud. One function decides both (Layout.bogDepth
	-- is what Height dips by too), so the dip and the mud cannot end up in different places.
	if Layout.bogDepth(x, z, config) > 0.15 then
		return config.MATERIAL.bog
	end
	-- THE BENCHES, in front of the slope test (design section 8.1): a road is gravel whatever the
	-- ground under it was going to be.
	if Layout.onRoad(x, z, config) then
		return config.MATERIAL.track
	end
	if Layout.onTrack(x, z, config) then
		return config.MATERIAL.track
	end
	-- The flank farmland reads as pasture; everything else in the wood is leaf litter.
	if Layout.inField(x, z, config) then
		return config.MATERIAL.rough
	end
	local v = config.VOXEL
	local dx = math.abs(Height.atFlattened(x + v, z, seed, config, pads, Layout.bogDepth) - h) / v
	local dz = math.abs(Height.atFlattened(x, z + v, seed, config, pads, Layout.bogDepth) - h) / v
	if math.max(dx, dz) > config.ROUGH_SLOPE then
		return config.MATERIAL.rough
	end
	-- THE WOOD'S DEFAULT IS LEAF LITTER. Everything that is not bog, bench, track, field or a steep
	-- column is forest floor -- which is what makes the map read as a wood rather than as a meadow
	-- with trees on it (design section 8.1).
	return config.MATERIAL.litter
end

-- One tile. IDEMPOTENT: it writes every voxel of its region from the heightfield, so re-running it
-- produces the same tile whatever was there before (design section 5.4).
function Ground.writeTile(tile, seed: number, config): number
	local pads = Layout.pads(config)
	local region = regionFor(tile.minX, tile.minZ, config)
	local size = region.Size
	local min = region.CFrame.Position - size / 2
	local v = config.VOXEL
	local nx, ny, nz = size.X / v, size.Y / v, size.Z / v
	local materials, occupancies = {}, {}
	for i = 1, nx do
		materials[i], occupancies[i] = {}, {}
		for j = 1, ny do
			materials[i][j], occupancies[i][j] = {}, {}
		end
	end
	for i = 1, nx do
		local x = min.X + (i - 0.5) * v
		for k = 1, nz do
			local z = min.Z + (k - 0.5) * v
			local h = Height.atFlattened(x, z, seed, config, pads, Layout.bogDepth)
			local material = surfaceMaterial(x, z, h, seed, config, pads)
			for j = 1, ny do
				local bottom = min.Y + (j - 1) * v
				local occupancy = math.clamp((h - bottom) / v, 0, 1)
				materials[i][j][k] = if occupancy > 0 then material else AIR
				occupancies[i][j][k] = occupancy
			end
		end
	end
	Workspace.Terrain:WriteVoxels(region, v, materials, occupancies)
	return nx * ny * nz
end

-- The dirt tracks: MATERIAL ONLY. Their height was already flattened into the heightfield by the
-- terrain step, so this pass can never disagree with the ground it paints (design section 5.2 layer
-- 5). Painting the whole solid column rather than the top voxel keeps the pass a pure read-then-write
-- with no surface search: 14 studs of track is never seen from the side.
--
-- One region per track, because a region covering both would be most of the map and far past the
-- measured 24,576-voxel ceiling.
function Ground.paintTrack(track, config): number
	local half = config.SIZE_STUDS / 2
	local v = config.VOXEL
	local min, max
	if track.axis == "x" then
		min = Vector3.new(-half, config.BAND_Y.min, track.at - track.halfWidth)
		max = Vector3.new(half, config.BAND_Y.max, track.at + track.halfWidth)
	else
		min = Vector3.new(track.at - track.halfWidth, config.BAND_Y.min, -half)
		max = Vector3.new(track.at + track.halfWidth, config.BAND_Y.max, half)
	end
	local painted = 0
	-- Chunked along the long axis, so no single WriteVoxels region exceeds the measured limit.
	local chunk = 512
	local longFrom = if track.axis == "x" then min.X else min.Z
	local longTo = if track.axis == "x" then max.X else max.Z
	local at = longFrom
	while at < longTo do
		local stop = math.min(at + chunk, longTo)
		local region
		if track.axis == "x" then
			region = Region3.new(Vector3.new(at, min.Y, min.Z), Vector3.new(stop, max.Y, max.Z))
		else
			region = Region3.new(Vector3.new(min.X, min.Y, at), Vector3.new(max.X, max.Y, stop))
		end
		region = region:ExpandToGrid(v)
		local materials, occupancies = Workspace.Terrain:ReadVoxels(region, v)
		local rmin = region.CFrame.Position - region.Size / 2
		local nx, ny, nz = region.Size.X / v, region.Size.Y / v, region.Size.Z / v
		for i = 1, nx do
			local x = rmin.X + (i - 0.5) * v
			for k = 1, nz do
				local z = rmin.Z + (k - 0.5) * v
				if Layout.onTrack(x, z, config) and Layout.bogDepth(x, z, config) <= 0.15 then
					for j = 1, ny do
						if occupancies[i][j][k] > 0 and materials[i][j][k] ~= AIR then
							materials[i][j][k] = config.MATERIAL.track
							painted += 1
						end
					end
				end
			end
		end
		Workspace.Terrain:WriteVoxels(region, v, materials, occupancies)
		at = stop
	end
	return painted
end

-- One downward height sample per column, for the digest: occupancy summed through the band plus the
-- material of the topmost solid voxel. One ReadVoxels per row (design section 6.4).
function Ground.sampleRow(
	z: number,
	samplesPerRow: number,
	config
): { { x: number, z: number, occupancy: number, material: string } }
	local half = config.SIZE_STUDS / 2
	local v = config.VOXEL
	local region =
		Region3.new(Vector3.new(-half, config.BAND_Y.min, z - v / 2), Vector3.new(half, config.BAND_Y.max, z + v / 2))
			:ExpandToGrid(v)
	local materials, occupancies = Workspace.Terrain:ReadVoxels(region, v)
	local min = region.CFrame.Position - region.Size / 2
	local nx, ny = region.Size.X / v, region.Size.Y / v
	local stride = math.max(1, math.floor(nx / samplesPerRow))
	local out = {}
	for i = 1, nx, stride do
		local total, top = 0, "Air"
		for j = 1, ny do
			local occupancy = occupancies[i][j][1]
			total += occupancy
			if occupancy > 0 then
				top = materials[i][j][1].Name
			end
		end
		table.insert(out, { x = min.X + (i - 0.5) * v, z = z, occupancy = total, material = top })
	end
	return out
end

-- HOW MUCH TERRAIN EXISTS, measured rather than assumed.
--
--   Terrain:CountCells https://create.roblox.com/docs/reference/engine/classes/Terrain#CountCells
--     MEASURED 2026-09-26: callable from `execute_luau` in Edit and from a server spec, and 0 on an
--     empty place.
--
-- This is the only number in the repo that can tell a 2048-stud heightfield apart from an empty
-- world. Before it, `MapGen.clear` returned `terrainCleared = true` as a LITERAL, and the contract
-- spec's "exactly one world" check looked at a folder name -- so deleting `Workspace.DrivenHuntMap`
-- in the Explorer left 6.3 M voxels in the place and every check still said PASS, with the arena
-- buried in a hillside (audit-004 must-fix 1).
function Ground.cells(): number
	return Workspace.Terrain:CountCells()
end

-- Clears the terrain and REPORTS WHAT IS LEFT. The caller decides what to do about it; this function
-- never claims success it did not measure.
function Ground.clear(): number
	Workspace.Terrain:Clear()
	return Ground.cells()
end

-- ---------------------------------------------------------------- the palette
--
-- Terrain material colour is GLOBAL STATE WITH NO CONTAINER, exactly like the voxels -- so it belongs
-- to the module that is already the only writer of Terrain in this repo (design section 8.2). No
-- second writer, anywhere, ever.
--
-- MEASURED 2026-09-26 (measurement N1): Get/SetMaterialColor are callable through execute_luau in
-- Edit, the values read back exactly, they SURVIVE Terrain:Clear(), and they replicate to a client.
-- The design's material-choice fallback is therefore not taken and no code for it exists.

-- DERIVED FROM Config.MATERIAL, never re-declared (round 2's note, and the same class as the
-- inversion the screenshot caught): the palette's `road` role is the material Config calls `track`,
-- and two tables naming the same material differently is how they end up disagreeing.
local function paletteMaterials(config)
	return {
		litter = config.MATERIAL.litter,
		rough = config.MATERIAL.rough,
		road = config.MATERIAL.track,
		bog = config.MATERIAL.bog,
	}
end

-- Write one palette table. Returns how many materials were set.
function Ground.applyPalette(palette, config): number
	local written = 0
	for role, material in pairs(paletteMaterials(config)) do
		local colour = palette[role]
		if colour ~= nil then
			workspace.Terrain:SetMaterialColor(material, colour)
			written += 1
		end
	end
	return written
end

-- What the place currently carries, as the same role -> Color3 shape. READ BACK, never assumed:
-- `clear` reports whether the restore worked by comparing this against what it asked for.
function Ground.readPalette(config)
	local out = {}
	for role, material in pairs(paletteMaterials(config)) do
		out[role] = workspace.Terrain:GetMaterialColor(material)
	end
	return out
end

-- Put the place back the way a place nobody has recoloured looks. A palette outlives Terrain:Clear()
-- -- that is measured, not assumed -- so without this an autumn palette would survive every teardown
-- and become "a world nobody chose" (audit-004 must-fix 1).
function Ground.resetPalette(default, config): boolean
	Ground.applyPalette(default, config)
	local got = Ground.readPalette(config)
	for role, colour in pairs(default) do
		local now = got[role]
		if now == nil then
			return false
		end
		-- Colour3 components are floats; compare at 8-bit precision, which is what the engine stores.
		if
			math.round(now.R * 255) ~= math.round(colour.R * 255)
			or math.round(now.G * 255) ~= math.round(colour.G * 255)
			or math.round(now.B * 255) ~= math.round(colour.B * 255)
		then
			return false
		end
	end
	return true
end

return Ground
