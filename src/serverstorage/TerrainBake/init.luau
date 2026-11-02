--!strict
-- TerrainBake: THE ONLY WRITER OF **KAREN'S FOREST TEST** `Terrain`, at EDIT time, one tile per
-- call, driven by `tools/terrainbake.py`. It requires `ReplicatedStorage` modules only and takes
-- every other writer as an injected seam, so it never requires `ServerScriptService.Places`.
--
--   Terrain:WriteVoxels  https://create.roblox.com/docs/reference/engine/classes/Terrain#WriteVoxels
--   Terrain:ReadVoxels   https://create.roblox.com/docs/reference/engine/classes/Terrain#ReadVoxels
--   Region3:ExpandToGrid https://create.roblox.com/docs/reference/engine/datatypes/Region3
--
-- MEASURED 2026-09-26 and recorded by `MapGen.Config.VOXEL`: a 128 x 128 x 96-stud region at
-- resolution 4 is accepted (32 x 24 x 32 = 24,576 voxels); resolution 8 and 2 are both refused with
-- "Resolution has to be 4". The tile sits EXACTLY on that ceiling, so `bakeTile` splits its Y band
-- into stacked calls rather than assuming one call is enough.
--
-- Design: docs/design/grid-terrain.md (sections 3, 5, 7.1)
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridFolder = ReplicatedStorage:WaitForChild("Grid")
local Grid = require(GridFolder)
local Relief = require(GridFolder:WaitForChild("Relief"))

local TerrainBake = {}

local AIR = Enum.Material.Air

-- Asserted by the tool before EVERY mutating call (design 6.2 item 2), and kept here so a hand-run
-- expression in the wrong place cannot reshape DEV.
TerrainBake.PLACE_ID = 130094961655666
TerrainBake.TILE_STUDS = 128
TerrainBake.MAX_VOXELS = 24576
TerrainBake.BAND_PAD = table.freeze({ belowStuds = 16, aboveStuds = 32 })
-- How far past a road centreline the bake owns the ground: the design's 34-stud verge plus the
-- 12-stud bank (7.1, last row). A `--cells` region is grown to this on each of the cell's roads.
TerrainBake.ROAD_HALF_STUDS = 46

export type Bounds = Relief.Bounds

-- A SNAPSHOT IS THE BASE AND NOTHING ELSE. `heightAt` never reads live terrain, which is what makes
-- a re-run of the bake a no-op rather than a drift (design 5.3 step 2).
export type Snapshot = {
	pitch: number,
	minX: number,
	minZ: number,
	nx: number,
	nz: number,
	height: { number },
	material: { string },
	minY: number,
	maxY: number,
}

export type Tile = { minX: number, minZ: number }

export type TileReport = {
	minX: number,
	minZ: number,
	calls: number,
	voxels: number,
	bandMin: number,
	bandMax: number,
	elapsedMs: number,
	message: string?,
}

-- ---------------------------------------------------------------- the region

-- THE REGION A RUN COVERS. All eight cells: the footprint plus `BLEND_STUDS` 200 and the border
-- wood's 230 (design 5.2). A subset: those cells and their roads plus `BLEND_STUDS`, so the result
-- returns to the base at the edge of what was actually baked and nowhere else.
function TerrainBake.regionFor(cellIds: { string }): Bounds
	assert(#cellIds > 0, "TerrainBake.regionFor: no cells")
	if #cellIds == #Grid.cellIds() then
		local box = Grid.footprint()
		local pad = Relief.BLEND_STUDS + 230
		return { minX = box.minX - pad, maxX = box.maxX + pad, minZ = box.minZ - pad, maxZ = box.maxZ + pad }
	end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, id in cellIds do
		local cell = Grid.boundsOf(id)
		local roads = Grid.roadsOf(id)
		minX = math.min(minX, cell.minX, roads.west.at - TerrainBake.ROAD_HALF_STUDS)
		maxX = math.max(maxX, cell.maxX, roads.east.at + TerrainBake.ROAD_HALF_STUDS)
		minZ = math.min(minZ, cell.minZ, roads.main.at - TerrainBake.ROAD_HALF_STUDS)
		maxZ = math.max(maxZ, cell.maxZ, roads.muster.at + TerrainBake.ROAD_HALF_STUDS)
	end
	local pad = Relief.BLEND_STUDS
	return { minX = minX - pad, maxX = maxX + pad, minZ = minZ - pad, maxZ = maxZ + pad }
end

-- Pure, and it delegates: the tile lattice is `Relief.tiles`' arithmetic, never a second copy.
function TerrainBake.tilePlan(region: Bounds): { Tile }
	return Relief.tiles(region, TerrainBake.TILE_STUDS)
end

-- ---------------------------------------------------------------- the base snapshot

local function index(snapshot: Snapshot, i: number, k: number): number
	return (k - 1) * snapshot.nx + i
end

-- THE BASE READER a snapshot hands to `Relief.heightAt`: nil outside the snapshot, so a point the
-- bake has no base for is skipped instead of guessed.
function TerrainBake.readerFor(snapshot: Snapshot): (number, number) -> number?
	return function(x: number, z: number): number?
		local i = math.floor((x - snapshot.minX) / snapshot.pitch) + 1
		local k = math.floor((z - snapshot.minZ) / snapshot.pitch) + 1
		if i < 1 or k < 1 or i > snapshot.nx or k > snapshot.nz then
			return nil
		end
		return snapshot.height[index(snapshot, i, k)]
	end
end

-- ONE REGION OF BASE TERRAIN, through `ReadVoxels`. REFUSES Water and REFUSES an overhang (two
-- separated solid runs in one column): neither has a single height, and guessing one is how a bake
-- silently fills a cave (design 5.3 step 2; note 4 item 5).
function TerrainBake.snapshot(region: Bounds, yMin: number, yMax: number): (Snapshot?, string?)
	local v = Relief.VOXEL
	local nx = math.floor((region.maxX - region.minX) / v + 0.5)
	local nz = math.floor((region.maxZ - region.minZ) / v + 0.5)
	if nx < 1 or nz < 1 then
		return nil, "the region is smaller than one voxel"
	end
	local snapshot: Snapshot = {
		pitch = v,
		minX = region.minX,
		minZ = region.minZ,
		nx = nx,
		nz = nz,
		height = table.create(nx * nz, 0),
		material = table.create(nx * nz, "Air"),
		minY = math.huge,
		maxY = -math.huge,
	}
	local box = Region3.new(Vector3.new(region.minX, yMin, region.minZ), Vector3.new(region.maxX, yMax, region.maxZ))
		:ExpandToGrid(v)
	local materials, occupancies = Workspace.Terrain:ReadVoxels(box, v)
	local size = box.Size
	local min = box.CFrame.Position - size / 2
	local ny = math.floor(size.Y / v + 0.5)
	for i = 1, nx do
		local x = min.X + (i - 0.5) * v
		for k = 1, nz do
			local z = min.Z + (k - 0.5) * v
			-- WALK THE COLUMN DOWN: the first solid voxel is the surface. Count the solid RUNS --
			-- more than one, with air between, is an overhang and has no single height.
			local top: number? = nil
			local runs, inRun, material = 0, false, "Air"
			for j = ny, 1, -1 do
				local occupancy = occupancies[i][j][k]
				if occupancy > 0 then
					if materials[i][j][k] == Enum.Material.Water then
						return nil, string.format("Water at (%.0f, %.0f) has no single height", x, z)
					end
					if not inRun then
						runs += 1
						inRun = true
						if top == nil then
							top = min.Y + (j - 1) * v + occupancy * v
							material = materials[i][j][k].Name
						end
					end
				else
					inRun = false
				end
			end
			if runs > 1 then
				return nil, string.format("an overhang at (%.0f, %.0f): %d solid runs in one column", x, z, runs)
			end
			if top == nil then
				return nil, string.format("no ground at (%.0f, %.0f) in the Y band %.0f..%.0f", x, z, yMin, yMax)
			end
			local at = index(snapshot, i, k)
			snapshot.height[at] = top
			snapshot.material[at] = material
			snapshot.minY = math.min(snapshot.minY, top)
			snapshot.maxY = math.max(snapshot.maxY, top)
		end
	end
	return snapshot, nil
end

-- ---------------------------------------------------------------- which cell, and one blend

-- WHICH CELL OWNS A POINT: the one whose bounds contain it, else the nearest. There is no per-cell
-- fade here, because the ROAD FADE is the blend between cells -- `Relief.roadFadeAt` is 0 for 51
-- studs either side of a centreline and cells only ever meet at a road.
function TerrainBake.cellAt(cellIds: { string }, x: number, z: number): string
	local best, bestD = cellIds[1], math.huge
	for _, id in cellIds do
		local b = Grid.boundsOf(id)
		local dx = math.max(b.minX - x, x - b.maxX, 0)
		local dz = math.max(b.minZ - z, z - b.maxZ, 0)
		local d = dx * dx + dz * dz
		if d < bestD then
			best, bestD = id, d
		end
	end
	return best
end

-- THE UNION OF THE CELLS BEING BAKED, which is what `blendAt` fades from.
function TerrainBake.unionOf(cellIds: { string }): Bounds
	local out = { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
	for _, id in cellIds do
		local b = Grid.boundsOf(id)
		out.minX = math.min(out.minX, b.minX)
		out.maxX = math.max(out.maxX, b.maxX)
		out.minZ = math.min(out.minZ, b.minZ)
		out.maxZ = math.max(out.maxZ, b.maxZ)
	end
	return out
end

-- ONE BLEND, AT THE EDGE OF WHAT WAS BAKED -- the 328d decision the 328c note asks for.
-- `Relief.heightAt` fades `k` from ONE CELL's bounds, which bleeds every cell's delta up to 200
-- studs into its neighbours; the bake divides that out and fades once, from the baked union.
function TerrainBake.blendAt(union: Bounds, x: number, z: number): number
	local dx = math.max(union.minX - x, x - union.maxX, 0)
	local dz = math.max(union.minZ - z, z - union.maxZ, 0)
	local outside = math.sqrt(dx * dx + dz * dz)
	if outside >= Relief.BLEND_STUDS then
		return 0
	end
	local t = outside / Relief.BLEND_STUDS
	return 1 - t * t * (3 - 2 * t)
end

-- ---------------------------------------------------------------- the slope limiter, BOTH axes

-- BOTH AXES -- the 328d decision the 328c note asks for. `Relief.limitPass` runs along one axis at a
-- time and 328c asserted only z; a tree ceiling is a slope in ANY direction, and the note measured
-- B2's scarp climbing back to ~22 degrees in x where nothing pinned it.
function TerrainBake.limitGrid(
	grid: { number },
	nx: number,
	nz: number,
	pitch: number,
	ceilingDeg: number,
	exempt: { boolean }?
): { number }
	local out = table.clone(grid)
	for k = 1, nz do
		local column, mask = table.create(nx, 0), table.create(nx, false)
		for i = 1, nx do
			column[i] = out[(k - 1) * nx + i]
			mask[i] = exempt ~= nil and exempt[(k - 1) * nx + i] == true
		end
		local limited = Relief.limitPass(column, pitch, ceilingDeg, mask)
		for i = 1, nx do
			out[(k - 1) * nx + i] = limited[i]
		end
	end
	for i = 1, nx do
		local column, mask = table.create(nz, 0), table.create(nz, false)
		for k = 1, nz do
			column[k] = out[(k - 1) * nx + i]
			mask[k] = exempt ~= nil and exempt[(k - 1) * nx + i] == true
		end
		local limited = Relief.limitPass(column, pitch, ceilingDeg, mask)
		for k = 1, nz do
			out[(k - 1) * nx + i] = limited[k]
		end
	end
	return out
end

-- ---------------------------------------------------------------- one tile

-- THE Y BAND of one tile, from the shaped heights it will write: min - 16 to max + 32, split into
-- stacked calls whenever that band exceeds the measured 96-stud ceiling (design 5.1).
function TerrainBake.bandsFor(lo: number, hi: number): { { min: number, max: number } }
	local v = Relief.VOXEL
	local min = v * math.floor((lo - TerrainBake.BAND_PAD.belowStuds) / v)
	local max = v * math.ceil((hi + TerrainBake.BAND_PAD.aboveStuds) / v)
	local columns = (TerrainBake.TILE_STUDS / v) * (TerrainBake.TILE_STUDS / v)
	local perCall = v * math.floor(TerrainBake.MAX_VOXELS / columns)
	local out = {}
	local at = min
	while at < max do
		local top = math.min(at + perCall, max)
		table.insert(out, { min = at, max = top })
		at = top
	end
	return out
end

-- ONE TILE: shape and material in the SAME WriteVoxels call (design 5.3 step 3). IDEMPOTENT -- every
-- voxel of the region is written from the snapshot, so a re-run against the same snapshot is a no-op.
-- `dryRun` computes and measures everything and writes nothing, which is what the ten-tile cost
-- measurement uses before any backup exists.
function TerrainBake.bakeTile(
	tile: Tile,
	snapshot: Snapshot,
	cellIds: { string },
	plans: { [string]: any },
	dryRun: boolean?
): TileReport
	local started = os.clock()
	local v = Relief.VOXEL
	local side = TerrainBake.TILE_STUDS
	local n = math.floor(side / v)
	local roads = Grid.roads()
	local union = TerrainBake.unionOf(cellIds)
	local baseAt = TerrainBake.readerFor(snapshot)
	local shaped, exempt = table.create(n * n, 0), table.create(n * n, false)
	for i = 1, n do
		local x = tile.minX + (i - 0.5) * v
		for k = 1, n do
			local z = tile.minZ + (k - 0.5) * v
			local at = (k - 1) * n + i
			local base = baseAt(x, z)
			local id = TerrainBake.cellAt(cellIds, x, z)
			local form = Relief.LANDFORMS[id]
			if base == nil then
				shaped[at] = 0
			elseif form == nil then
				shaped[at] = base
			else
				local bounds = Grid.boundsOf(id)
				local here = Relief.heightAt(form, bounds, roads, baseAt, x, z)
				shaped[at] = base + TerrainBake.blendAt(union, x, z) * ((here or base) - base)
				exempt[at] = Relief.isExempt(form, bounds, x, z)
			end
		end
	end
	shaped = TerrainBake.limitGrid(shaped, n, n, v, Relief.LIMIT_DEG.tree, exempt)
	local lo, hi = math.huge, -math.huge
	for _, h in shaped do
		lo = math.min(lo, h)
		hi = math.max(hi, h)
	end
	local bands = TerrainBake.bandsFor(lo, hi)
	local report: TileReport = {
		minX = tile.minX,
		minZ = tile.minZ,
		calls = #bands,
		voxels = 0,
		bandMin = bands[1].min,
		bandMax = bands[#bands].max,
		elapsedMs = 0,
	}
	for _, band in bands do
		local region = Region3.new(
			Vector3.new(tile.minX, band.min, tile.minZ),
			Vector3.new(tile.minX + side, band.max, tile.minZ + side)
		):ExpandToGrid(v)
		local size = region.Size
		local ny = math.floor(size.Y / v + 0.5)
		local voxels = n * ny * n
		if voxels > TerrainBake.MAX_VOXELS then
			report.message = string.format(
				"tile (%d, %d) band %.0f..%.0f is %d voxels, over the measured ceiling %d",
				tile.minX,
				tile.minZ,
				band.min,
				band.max,
				voxels,
				TerrainBake.MAX_VOXELS
			)
			report.elapsedMs = math.floor((os.clock() - started) * 1000 + 0.5)
			return report
		end
		do
			local min = region.CFrame.Position - size / 2
			local materials, occupancies = {}, {}
			for i = 1, n do
				materials[i], occupancies[i] = {}, {}
				for j = 1, ny do
					materials[i][j], occupancies[i][j] = {}, {}
				end
			end
			for i = 1, n do
				local x = min.X + (i - 0.5) * v
				for k = 1, n do
					local z = min.Z + (k - 0.5) * v
					local at = (k - 1) * n + i
					local h = shaped[at]
					local id = TerrainBake.cellAt(cellIds, x, z)
					local form = Relief.LANDFORMS[id]
					local name = "Ground"
					if form ~= nil then
						local slope = TerrainBake.slopeAt(shaped, n, i, k, v)
						name = Relief.materialAt(form, Grid.boundsOf(id), plans[id], slope, 0, x, z)
					end
					local material = (Enum.Material :: any)[name] or Enum.Material.Ground
					for j = 1, ny do
						local bottom = min.Y + (j - 1) * v
						local occupancy = math.clamp((h - bottom) / v, 0, 1)
						materials[i][j][k] = if occupancy > 0 then material else AIR
						occupancies[i][j][k] = occupancy
					end
				end
			end
			-- A DRY RUN BUILDS EVERY ARRAY AND SKIPS ONLY THE WRITE, so its per-tile cost is the
			-- real cost less one engine call -- not a different measurement wearing the same name.
			if not dryRun then
				Workspace.Terrain:WriteVoxels(region, v, materials, occupancies)
			end
		end
		report.voxels += voxels
	end
	report.elapsedMs = math.floor((os.clock() - started) * 1000 + 0.5)
	return report
end

-- HOW FAR OUTSIDE A TILE THE SHAPING READS THE BASE: the blur's own cutoff, plus one voxel so the
-- edge sample has a neighbour. `Relief.blurredAt` is the only reader that leaves the point -- except
-- a `bench`, which walks the base across its whole v band (`applyOps`), and `bakeTileAt` refuses
-- that rather than snapshot a slice it does not hold.
function TerrainBake.padFor(): number
	local v = Relief.VOXEL
	return v * math.ceil((Relief.BLUR.cutoffStuds + v) / v)
end

function TerrainBake.readsWholeCell(form: any): boolean
	for _, op in form.ops do
		if op.kind == "bench" then
			return true
		end
	end
	return false
end

-- ONE TILE BY ITS INDEX IN THE PLAN -- what `tools/terrainbake.py` calls, so the tool sends one
-- expression and no geometry. It snapshots only what this tile's shaping reads.
function TerrainBake.bakeTileAt(
	tileIndex: number,
	cellIds: { string },
	yMin: number,
	yMax: number,
	dryRun: boolean
): TileReport
	local plan = TerrainBake.tilePlan(TerrainBake.regionFor(cellIds))
	assert(tileIndex >= 1 and tileIndex <= #plan, string.format("tile %d is not in a plan of %d", tileIndex, #plan))
	local tile = plan[tileIndex]
	for _, id in cellIds do
		local form = Relief.LANDFORMS[id]
		if form ~= nil and TerrainBake.readsWholeCell(form) then
			return {
				minX = tile.minX,
				minZ = tile.minZ,
				calls = 0,
				voxels = 0,
				bandMin = 0,
				bandMax = 0,
				elapsedMs = 0,
				message = string.format(
					"%s's landform has a bench, which reads the base across the whole cell; one tile's "
						.. "snapshot does not hold that. The whole-cell snapshot route is design 5.3 step 2 "
						.. "and is not built in 328d.",
					id
				),
			}
		end
	end
	local pad = TerrainBake.padFor()
	local side = TerrainBake.TILE_STUDS
	local slice, problem = TerrainBake.snapshot({
		minX = tile.minX - pad,
		maxX = tile.minX + side + pad,
		minZ = tile.minZ - pad,
		maxZ = tile.minZ + side + pad,
	}, yMin, yMax)
	if slice == nil then
		return {
			minX = tile.minX,
			minZ = tile.minZ,
			calls = 0,
			voxels = 0,
			bandMin = 0,
			bandMax = 0,
			elapsedMs = 0,
			message = problem,
		}
	end
	return TerrainBake.bakeTile(tile, slice, cellIds, {}, dryRun)
end

-- The slope at one grid point, in degrees, from its neighbours. One number for `Relief.materialAt`,
-- which is what decides scree -- never a second noise field.
function TerrainBake.slopeAt(grid: { number }, n: number, i: number, k: number, pitch: number): number
	local function at(a: number, b: number): number
		return grid[(math.clamp(b, 1, n) - 1) * n + math.clamp(a, 1, n)]
	end
	local dx = (at(i + 1, k) - at(i - 1, k)) / (2 * pitch)
	local dz = (at(i, k + 1) - at(i, k - 1)) / (2 * pitch)
	return math.deg(math.atan(math.sqrt(dx * dx + dz * dz)))
end

-- ---------------------------------------------------------------- the survey, read-only

-- 327a's own four fields plus `lineMeanY`, per cell, on the same 20-stud lattice. READ-ONLY: a
-- commit writes the numbers into `Grid.CELLS[*].relief`, never this function (design 5.5).
-- `heightOf` is the seam, so a spec can survey a synthetic world with no terrain in it.
function TerrainBake.survey(cellId: string, heightOf: ((number, number) -> number?)?): any
	local bounds = Grid.boundsOf(cellId)
	local reader = heightOf
		or function(x: number, z: number): number?
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { Workspace.Terrain }
			params.IgnoreWater = true
			local hit = Workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -4000, 0), params)
			return if hit then hit.Position.Y else nil
		end
	local lo, hi, sum, n = math.huge, -math.huge, 0, 0
	for x = bounds.minX, bounds.maxX, 20 do
		for z = bounds.minZ, bounds.maxZ, 20 do
			local y = reader(x, z)
			if y ~= nil then
				n += 1
				sum += y
				lo = math.min(lo, y)
				hi = math.max(hi, y)
			end
		end
	end
	local road = Grid.roadsOf(cellId).main
	local lineSum, lineN = 0, 0
	for x = bounds.minX, bounds.maxX, 20 do
		local y = reader(x, road.at)
		if y ~= nil then
			lineN += 1
			lineSum += y
		end
	end
	local spread = if n > 0 then hi - lo else 0
	return {
		cell = cellId,
		samples = n,
		minY = if n > 0 then lo else 0,
		maxY = if n > 0 then hi else 0,
		meanY = if n > 0 then sum / n else 0,
		spreadStuds = spread,
		lineMeanY = if lineN > 0 then lineSum / lineN else 0,
		-- 327a's classifier, unchanged, so a baked ridge classifies by the same rule that classified
		-- the base as a slope and `grid.spec`'s assertions do not move (design 5.5).
		character = if spread < 20 then "flat" elseif spread < 60 then "slope" else "ridge",
	}
end

-- ---------------------------------------------------------------- the epoch

-- NO CODE COMMIT IN IT: a commit-based epoch fails the census after every paperwork commit, which
-- makes the census a liar on every review round (design 5.4). The digest itself is the tool's --
-- this is the input string, which has to be one definition.
function TerrainBake.epochInputFor(baseSnapshotSha: string): string
	local config = Grid.CONFIG
	local geometry = {
		originX = config.originX,
		originZ = config.originZ,
		cellWidthStuds = config.cellWidthStuds,
		cellDepthStuds = config.cellDepthStuds,
		roadClearStuds = config.roadClearStuds,
		rows = config.rows,
		columns = config.columns,
	}
	return baseSnapshotSha .. Relief.epochInput(Relief.LANDFORMS, geometry) .. tostring(Relief.BAKE_VERSION)
end

-- THE ONE WRITER of `TerrainEpoch`.
function TerrainBake.stamp(epoch: string, where: Instance?): ()
	local target = where or Workspace.Terrain
	target:SetAttribute("TerrainEpoch", epoch)
end

-- ---------------------------------------------------------------- the archive, and the census

-- B3: REPARENT ONLY, never Destroy (rule 7). `seams.archiveParent` is handed in, so nothing here
-- requires a server script.
function TerrainBake.archive(folderName: string, seams: any): any
	local source = Workspace:FindFirstChild(folderName)
	if source == nil then
		return { moved = 0, message = folderName .. " is not in Workspace" }
	end
	local into = (seams ~= nil and seams.archiveParent) or game:GetService("ServerStorage")
	local moved = #source:GetChildren()
	source.Name = folderName .. "-archived-" .. os.date("!%Y%m%dT%H%M%SZ")
	source.Parent = into
	return { moved = moved, name = source.Name, into = into:GetFullName() }
end

-- Delegates to `ServerStorage.GridCensus`, handed in as a seam so this module requires no server
-- script (design 5.1).
function TerrainBake.census(seams: any): any
	assert(seams ~= nil and seams.census ~= nil, "TerrainBake.census: no census seam")
	return seams.census()
end

return TerrainBake
