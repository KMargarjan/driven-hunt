--!strict
-- MapGen.Ground: THE ONLY WRITER OF `Terrain` IN THE REPO, voxels, material colour AND material
-- variants. One tile pass per call. It reads no Instance it did not make and writes none; it asks
-- `Height` where the ground is and `Layout` what is on it, so nothing here can disagree with the
-- props or the markers about the shape of the world.
--
--   Terrain:WriteVoxels  https://create.roblox.com/docs/reference/engine/classes/Terrain#WriteVoxels
--   Terrain:ReadVoxels   https://create.roblox.com/docs/reference/engine/classes/Terrain#ReadVoxels
--   Region3:ExpandToGrid https://create.roblox.com/docs/reference/engine/datatypes/Region3
--   MaterialService      https://create.roblox.com/docs/reference/engine/classes/MaterialService
--   MaterialVariant      https://create.roblox.com/docs/reference/engine/classes/MaterialVariant
--
-- MEASURED 2026-09-26 (measurement A, an Edit-mode execute_luau probe):
--   * a 128 x 128 x 96-stud region at resolution 4 is accepted -- 32 x 24 x 32 = 24,576 voxels;
--   * resolution 8 and resolution 2 are BOTH refused, with "Resolution has to be 4".
-- So the tile size is a choice and the resolution is not one. The occupancy arrays are indexed
-- [x][y][z], 1-based, in the region's own order.
--
-- THE BAND IS WRITTEN IN TWO PASSES OF THAT MEASURED SIZE (design, "The heightfield: hills, and a
-- band written in two measured passes"). A tile carries its own `minY`/`maxY`, so this file does not
-- know or care which pass it is doing -- it writes the slab it is handed, from the one heightfield.
--
-- Design: docs/design/map-generator.md, "Ownership" and "Terrain materials: the CC0 textures"
local MaterialService = game:GetService("MaterialService")
local Workspace = game:GetService("Workspace")

local Height = require(script.Parent:WaitForChild("Height"))
local Layout = require(script.Parent:WaitForChild("Layout"))

local Ground = {}

local AIR = Enum.Material.Air

-- The name every MaterialVariant this module makes carries, so `clearVariants` can find exactly its
-- own and never something a human put in MaterialService by hand.
local VARIANT_PREFIX = "DrivenHunt_"

local function regionFor(tile, config): Region3
	return Region3.new(
		Vector3.new(tile.minX, tile.minY, tile.minZ),
		Vector3.new(tile.minX + config.TILE_STUDS, tile.maxY, tile.minZ + config.TILE_STUDS)
	):ExpandToGrid(config.VOXEL)
end

-- Leaf litter everywhere in the wood; gravel on the roads; Mud in the wet hollows; Grass on the
-- steep columns and in a `gap` patch. One slope number instead of a second noise field. Called ONCE
-- PER COLUMN, not once per voxel: at 24,576 voxels a tile and ~6 math.noise calls a height,
-- per-voxel would be about 600,000 noise evaluations for a tile that needs 1,024.
local function surfaceMaterial(x: number, z: number, slope: number, wetness: number, config, patches): Enum.Material
	-- THE ROADS, in front of everything else: a road is gravel whatever the ground under it was
	-- going to be.
	if Layout.onRoad(x, z, config) then
		return config.MATERIAL.road
	end
	if Layout.onTrack(x, z, config) then
		return config.MATERIAL.road
	end
	-- WET GROUND IS MUD, and the wetness arrives from the SAME expression that dug the dip
	-- (`Height.wetFor` on the column's own base height), so the mud and the hollow cannot end up in
	-- different places.
	if wetness > 0.5 then
		return config.MATERIAL.wet
	end
	-- A PATCH MAY NAME ITS OWN GROUND. The gap asks for `rough`, which is what makes a clearing
	-- read as grass and brambles rather than as a hole in the canopy with leaf litter under it.
	for _, patch in ipairs(patches or {}) do
		if
			patch.spec.ground ~= nil
			and (Vector3.new(x, 0, z) - Vector3.new(patch.x, 0, patch.z)).Magnitude <= patch.radiusStuds
		then
			return config.MATERIAL[patch.spec.ground] or config.MATERIAL.litter
		end
	end
	if Layout.inField(x, z, config) then
		return config.MATERIAL.rough
	end
	if slope > config.ROUGH_SLOPE then
		return config.MATERIAL.rough
	end
	-- THE WOOD'S DEFAULT IS LEAF LITTER. Everything that is not road, wet, gap or a steep column is
	-- forest floor -- which is what makes the map read as a wood rather than as a meadow with trees
	-- on it. M2.8a had litter and rough INVERTED and a screenshot is what caught it: the autumn
	-- palette painted the whole floor olive and put the orange litter on the steep rim.
	return config.MATERIAL.litter
end

-- One tile pass. IDEMPOTENT: it writes every voxel of its region from the heightfield, so
-- re-running it produces the same slab whatever was there before.
function Ground.writeTile(tile, seed: number, config, patches): number
	local pads = Layout.pads(config)
	local region = regionFor(tile, config)
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
	-- ONE HEIGHT GRID, WITH A ONE-VOXEL BORDER, AND THE SLOPE READ OUT OF IT.
	--
	-- This loop used to ask `Height.atFlattened` THREE times per column -- once for the height and
	-- twice more for the two neighbours the slope test needs -- and each of those evaluates a
	-- domain-warped four-octave fbm. That is 36 noise evaluations per column, 37,000 per tile and
	-- 28 million over a build. Computing the column once and reading its neighbour out of the grid
	-- is the same arithmetic done once, and it is what brings the build inside its 40-minute target.
	local heights, wetness = {}, {}
	for i = 1, nx + 1 do
		local x = min.X + (i - 0.5) * v
		heights[i], wetness[i] = {}, {}
		for k = 1, nz + 1 do
			local z = min.Z + (k - 0.5) * v
			heights[i][k] = Height.atFlattened(x, z, seed, config, pads)
			-- The wetness of the column, from its own base height. Only the tile's own columns need
			-- it -- the border exists for the slope -- but computing it for the border too keeps the
			-- two grids the same shape, and it is one smoothstep.
			wetness[i][k] = Height.wetAt(x, z, seed, config)
		end
	end
	for i = 1, nx do
		local x = min.X + (i - 0.5) * v
		for k = 1, nz do
			local z = min.Z + (k - 0.5) * v
			local h = heights[i][k]
			local slope = math.max(math.abs(heights[i + 1][k] - h), math.abs(heights[i][k + 1] - h)) / v
			local material = surfaceMaterial(x, z, slope, wetness[i][k], config, patches)
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

-- THE HIGHEST AND LOWEST GROUND IN ONE TILE, sampled on a lattice. This is what the band spec
-- measures: no column may leave the band its tile was written in, which is the invariant that makes
-- omitting the upper pass safe. Pure -- no Terrain -- so a server spec can run it.
function Ground.tileExtremes(tile, seed: number, config, step: number): (number, number)
	local pads = Layout.pads(config)
	local lo, hi = math.huge, -math.huge
	local x = tile.minX
	while x <= tile.minX + config.TILE_STUDS do
		local z = tile.minZ
		while z <= tile.minZ + config.TILE_STUDS do
			local h = Height.atFlattened(x, z, seed, config, pads)
			lo, hi = math.min(lo, h), math.max(hi, h)
			z += step
		end
		x += step
	end
	return lo, hi
end

-- The dirt tracks: MATERIAL ONLY. Their height was already flattened into the heightfield by the
-- terrain pass, so this pass can never disagree with the ground it paints. The layer is switched
-- off; the mechanism stays with its caller (see Layout's note on the retired layers).
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
				if Layout.onTrack(x, z, config) then
					for j = 1, ny do
						if occupancies[i][j][k] > 0 and materials[i][j][k] ~= AIR then
							materials[i][j][k] = config.MATERIAL.road
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
-- material of the topmost solid voxel. One ReadVoxels per row.
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
-- This is the only number in the repo that can tell a heightfield apart from an empty world. Before
-- it, `MapGen.clear` returned `terrainCleared = true` as a LITERAL, and the contract spec's "exactly
-- one world" check looked at a folder name -- so deleting `Workspace.DrivenHuntMap` in the Explorer
-- left 6.3 M voxels in the place and every check still said PASS, with the arena buried in a
-- hillside (audit-004 must-fix 1).
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
-- to the module that is already the only writer of Terrain in this repo. No second writer, anywhere.
--
-- MEASURED 2026-09-26 (measurement N1): Get/SetMaterialColor are callable through execute_luau in
-- Edit, the values read back exactly, they SURVIVE Terrain:Clear(), and they replicate to a client.

-- DERIVED FROM Config.MATERIAL, never re-declared (round 2's note, and the same class as the
-- inversion the screenshot caught): the palette's four roles ARE the four materials, and two tables
-- naming the same material differently is how they end up disagreeing.
local function paletteMaterials(config)
	return {
		litter = config.MATERIAL.litter,
		rough = config.MATERIAL.rough,
		road = config.MATERIAL.road,
		wet = config.MATERIAL.wet,
	}
end

-- Write one palette table. Returns how many materials were set.
function Ground.applyPalette(palette, config): number
	local written = 0
	for role, material in pairs(paletteMaterials(config)) do
		local colour = palette[role]
		if colour ~= nil then
			Workspace.Terrain:SetMaterialColor(material, colour)
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
		out[role] = Workspace.Terrain:GetMaterialColor(material)
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
		-- Color3 components are floats; compare at 8-bit precision, which is what the engine stores.
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

-- ---------------------------------------------------------------- the CC0 material variants
--
-- A `MaterialVariant` puts a photo texture on a base material. For TERRAIN the override is a
-- property on `MaterialService` named after the base material, holding the variant's NAME -- so
-- applying one is two writes: make the variant, then name it in the override.
--
-- IT NEVER FAILS THE BUILD, AND THAT IS THE DESIGN'S RULE FOR THIS STEP (design, "Two layers, and
-- the proven one ships first"). The palette above is MEASURED and already shipped; this layer is
-- new, and whether a terrain-bound variant can be created from `execute_luau` in Edit, whether it
-- persists with the place and whether it replicates is measurement M3. So every write is in its own
-- `pcall` and the step REPORTS what it could not reach. If none of it works, the forest ships on the
-- palette and the report says so -- which is why block 1 is lookable at before a texture exists.
--
-- `textureFor` is injected rather than required, so this module keeps no dependency on the asset
-- manifest and a spec can drive both branches with no network and no id.
function Ground.applyVariants(variants, config, textureFor: (string) -> string?): { [string]: string }
	local report: { [string]: string } = {}
	for role, spec in pairs(variants) do
		local material = config.MATERIAL[role]
		if material == nil then
			report[role] = "no such material role in Config.MATERIAL"
			continue
		end
		local texture = textureFor(spec.key)
		if texture == nil then
			-- No id yet. NOT a failure: the role keeps the measured palette colour and the row says
			-- which key is missing, which is the one thing a human needs in order to fix it.
			report[role] = "no asset row for " .. spec.key .. ": the palette colour stands"
			continue
		end
		local name = VARIANT_PREFIX .. role
		local existing = MaterialService:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
		local made: Instance? = nil
		local ok, why = pcall(function()
			local variant = Instance.new("MaterialVariant")
			variant.Name = name
			variant.BaseMaterial = material
			variant.StudsPerTile = spec.studsPerTile
			variant.ColorMap = texture
			variant.Parent = MaterialService
			made = variant
		end)
		if not ok then
			report[role] = "MaterialVariant refused: " .. tostring(why)
			continue
		end
		-- THE OVERRIDE. `MaterialService` carries one property per base material holding the name of
		-- the variant terrain should use. It is set by name rather than by reference, which is why
		-- the variant has to exist first.
		local bound, boundWhy = pcall(function()
			(MaterialService :: any)[material.Name] = name
		end)
		if not bound then
			if made then
				(made :: Instance):Destroy()
			end
			report[role] = "MaterialService." .. material.Name .. " not writable: " .. tostring(boundWhy)
			continue
		end
		report[role] = name .. " <- " .. texture
	end
	return report
end

-- WHAT MATERIALSERVICE ACTUALLY HOLDS, read back. Never what was asked for: a variant that did not
-- take is exactly the "world nobody chose" this project has already paid for once.
function Ground.readVariants(variants, config): { [string]: string }
	local out: { [string]: string } = {}
	for role, _spec in pairs(variants) do
		local material = config.MATERIAL[role]
		if material == nil then
			out[role] = "no such material role"
			continue
		end
		local ok, value = pcall(function()
			return (MaterialService :: any)[material.Name]
		end)
		if not ok then
			out[role] = "MaterialService." .. material.Name .. " not readable"
			continue
		end
		if value == nil or value == "" then
			out[role] = "none"
			continue
		end
		local variant = MaterialService:FindFirstChild(tostring(value))
		if variant == nil then
			out[role] = tostring(value) .. " (named, but no such variant)"
			continue
		end
		-- The ColorMap needs a plugin context to read (measured 2026-10-01 on SurfaceAppearance:
		-- "The current thread cannot read 'ColorMap' (lacking capability Plugin)"). `execute_luau` IS
		-- one; a server spec is not, so this answers honestly in both.
		local readable, map = pcall(function()
			return (variant :: any).ColorMap
		end)
		out[role] = tostring(value) .. " <- " .. (if readable then tostring(map) else "ColorMap unreadable here")
	end
	return out
end

-- REMOVES ONLY WHAT THIS MODULE MADE: variants whose name carries the prefix, and the overrides that
-- name them. MEASURED by reading back, never asserted -- a variant left behind after a `clear` is
-- audit-004's "a world nobody chose" again. Returns how many were actually gone afterwards.
function Ground.clearVariants(config): number
	local function ours(): number
		local n = 0
		for _, child in ipairs(MaterialService:GetChildren()) do
			if string.sub(child.Name, 1, #VARIANT_PREFIX) == VARIANT_PREFIX then
				n += 1
			end
		end
		return n
	end
	local before = ours()
	-- The overrides first: a MaterialService property still naming a variant we are about to
	-- destroy would leave the service pointing at nothing.
	for role, _spec in pairs(config.TERRAIN_VARIANTS) do
		local material = config.MATERIAL[role]
		if material ~= nil then
			pcall(function()
				if (MaterialService :: any)[material.Name] == VARIANT_PREFIX .. role then
					(MaterialService :: any)[material.Name] = ""
				end
			end)
		end
	end
	for _, child in ipairs(MaterialService:GetChildren()) do
		if string.sub(child.Name, 1, #VARIANT_PREFIX) == VARIANT_PREFIX then
			child:Destroy()
		end
	end
	-- COUNTED FROM WHAT IS GONE, not from what was asked to go: if one would not be destroyed, this
	-- is smaller than `before` and the caller can see it.
	return before - ours()
end

return Ground
