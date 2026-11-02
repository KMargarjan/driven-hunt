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
-- ReadVoxels' own documented ceiling, which is far above WriteVoxels' measured one. A snapshot that
-- would pass it is refused with its size, not left to the engine to reject with no location.
-- https://create.roblox.com/docs/reference/engine/classes/Terrain#ReadVoxels
TerrainBake.MAX_READ_VOXELS = 4194304
TerrainBake.BAND_PAD = table.freeze({ belowStuds = 16, aboveStuds = 32 })
-- How far past a road centreline the bake owns the ground: the design's 34-stud verge plus the
-- 12-stud bank (7.1, last row). A `--cells` region is grown to this on each of the cell's roads.
TerrainBake.ROAD_HALF_STUDS = 46
-- HOW FAR PAST A TILE THE SHAPING GRID REACHES so the slope limiter does not depend on the tile
-- lattice (round-1 finding 2). `Relief.limitPass`' window is 16 studs and it makes 8 relaxation
-- passes, so influence travels up to 8 windows; 128 studs is that reach, and the margin is
-- discarded after the limit so only the inner 128-stud tile is written.
TerrainBake.LIMIT_MARGIN_STUDS = 128
-- SWARM 2.2 for B2: "Scree (Ground 70 / Rock 30) where the slope is 30-40 degrees". `materialAt`
-- answers Rock for the whole band; this is the 30 % of columns that keep it.
TerrainBake.SCREE_ROCK_SHARE = 0.3

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
-- bake has no base for is answered nil here. `shapeTile` then KEEPS the ground (`snapshot.minY`,
-- marked exempt) rather than cutting a hole; `bakeTileAt` refuses such a tile before that, so the
-- branch is a floor and not a guess the bake relies on.
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
	local reads = nx * nz * math.ceil((yMax - yMin) / v)
	if reads > TerrainBake.MAX_READ_VOXELS then
		return nil,
			string.format(
				"the snapshot is %d voxels, over ReadVoxels' ceiling %d: narrow the Y band",
				reads,
				TerrainBake.MAX_READ_VOXELS
			)
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
-- studs into its neighbours; the bake REPLACES that `k` with one fade from the baked union.
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

-- ---------------------------------------------------------------- the road (design 7.1)

-- DESIGN 7.1's CROSS-SECTION, as data. `d` is the distance from the centreline; every band below is
-- NOMINAL and `Relief.columnsFor` realises it as whole voxel columns (correction F-2: the BAND
-- snaps, never the centre, because all eight centres sit at = 1 mod 4).
TerrainBake.ROAD = table.freeze({
	carriagewayStuds = 20, -- 0 to +-20, level
	-- "crossfall <= 0.5 st over 44 st": 0.2 st from the crown to each edge is 0.4 over 44, under it.
	crownFallStuds = 0.2,
	rut = table.freeze({ nearStuds = 6, farStuds = 10 }), -- F-3: +-6..+-10, never +-4 (they merged)
	ditch = table.freeze({ nearStuds = 22, farStuds = 30, depthStuds = 2 }),
	vergeStuds = 34, -- no tree, no fern (the mask is Places.mask's, 328f)
	bankMinStuds = 12, -- at least 12 wide, and never steeper than 1:2
	bankMaxSlope = 0.5,
	-- The long profile's clamps: 8 % east-west, 10 % north-south, <= 2 % change per 50 st,
	-- cut-or-fill <= 12 st. A breach RELAXES the grade on that road and is printed, never hidden.
	gradePercent = table.freeze({ x = 8, z = 10 }),
	gradeChangePercentPer50 = 2,
	cutFillStuds = 12,
	sampleStuds = 20,
	-- Design 7.1's material table. `mid` is 0..+-6, `outer` is +-10..+-20.
	material = table.freeze({
		x = table.freeze({ mid = "Ground", rut = "Mud", outer = "Grass", ditch = "Mud", verge = "Grass" }),
		z = table.freeze({ mid = "Grass", rut = "Mud", outer = "Grass", ditch = "Mud", verge = "Grass" }),
	}),
})

export type Profile = {
	road: Relief.Road,
	from: number,
	to: number,
	step: number,
	y: { number },
	gradePercent: number,
	relaxed: boolean,
	worstCutFill: number,
	realisedGradePercent: number,
	worstGradeChangePercent: number,
	gradeChangeSpanStuds: number,
	breaches: { string },
}

-- HOW MANY SMOOTHING PASSES the grade-change limiter may take. One pass does NOT meet the rule:
-- measured on a 0 -> 10 % kink it leaves 3.80 % per 60 st against a 2.40 % allowance, and it takes
-- ~20 passes to settle at the allowance (round-2 finding 4).
TerrainBake.GRADE_CHANGE_PASSES = 40

-- THE LONG PROFILE of one road: sample the base every 20 st, clamp the grade, limit how fast the
-- grade may change, and cap cut-or-fill at 12 st. A cap that cannot be met RELAXES the grade on
-- THAT road and says so in `breaches` -- design 7.1, "a breach relaxes the grade on that road and
-- is printed, never hidden".
function TerrainBake.longProfile(road: Relief.Road, baseAt: (number, number) -> number?): Profile?
	local step = TerrainBake.ROAD.sampleStuds
	local n = math.floor((road.to - road.from) / step) + 1
	local base = table.create(n, 0)
	for i = 1, n do
		local at = road.from + (i - 1) * step
		local y = if road.axis == "x" then baseAt(at, road.at) else baseAt(road.at, at)
		if y == nil then
			return nil
		end
		base[i] = y
	end
	local ceilingPercent = TerrainBake.ROAD.gradePercent[road.axis]
	local out, relaxed, breaches = table.clone(base), false, {}
	local worst = 0
	-- THE GRADE-CHANGE RULE IS A RATE -- "<= 2 % change per 50 st" (design 7.1). The samples are 20
	-- st apart, so the nearest measurable span is 60 st (3 steps) and the allowance is that SAME
	-- rate over the span actually measured: 2 % x 60/50 = 2.4 %. Re-derived here, not retyped.
	local window = math.max(1, math.floor(50 / step + 0.5))
	local spanStuds = window * step
	local limit = TerrainBake.ROAD.gradeChangePercentPer50 / 100 * (spanStuds / 50)
	local worstChange = 0
	for attempt = 1, 6 do
		out = table.clone(base)
		local rise = ceilingPercent / 100 * step
		-- A FORWARD-THEN-BACKWARD MIN-CONE SWEEP, which is exact on a chain -- the same finishing
		-- sweep `Relief.limitPass` uses, and for the same reason.
		for _ = 1, 2 do
			for i = 1, n - 1 do
				if out[i + 1] - out[i] > rise then
					out[i + 1] = out[i] + rise
				end
			end
			for i = n - 1, 1, -1 do
				if out[i] - out[i + 1] > rise then
					out[i] = out[i + 1] + rise
				end
			end
		end
		-- THE GRADE MAY NOT CHANGE FASTER THAN THE RATE ABOVE: smoothing passes over the slopes,
		-- re-integrated, UNTIL NO WINDOW BREACHES. One pass leaves a kink at 3.80 % against the
		-- 2.40 % allowance -- it is a relaxation, and it has to be iterated (round-2 finding 4).
		local slope = table.create(math.max(1, n - 1), 0)
		for _ = 1, TerrainBake.GRADE_CHANGE_PASSES do
			for i = 1, n - 1 do
				slope[i] = (out[i + 1] - out[i]) / step
			end
			local over = 0
			for i = 1, n - 1 - window do
				local change = slope[i + window] - slope[i]
				if math.abs(change) > limit + 1e-12 then
					over += 1
					local excess = (math.abs(change) - limit) / 2 * (if change > 0 then 1 else -1)
					slope[i] += excess
					slope[i + window] -= excess
				end
			end
			for i = 1, n - 1 do
				out[i + 1] = out[i] + slope[i] * step
			end
			if over == 0 then
				break
			end
		end
		-- RE-CENTRE on the base, so the smoothing cannot drift the whole road up or down.
		local drift = 0
		for i = 1, n do
			drift += base[i] - out[i]
		end
		drift /= n
		worst = 0
		for i = 1, n do
			out[i] += drift
			worst = math.max(worst, math.abs(out[i] - base[i]))
		end
		if worst <= TerrainBake.ROAD.cutFillStuds then
			break
		end
		if attempt < 6 then
			relaxed = true
			ceilingPercent += 2
			table.insert(
				breaches,
				string.format(
					"%s: cut-or-fill %.1f st over the %d-st cap, so the grade is relaxed to %d %%",
					road.id,
					worst,
					TerrainBake.ROAD.cutFillStuds,
					ceilingPercent
				)
			)
		else
			table.insert(
				breaches,
				string.format("%s: cut-or-fill %.1f st STILL over the cap at %d %%", road.id, worst, ceilingPercent)
			)
		end
	end
	-- THE REALISED GRADE CHANGE, off the profile that is actually returned. A breach that the
	-- passes above could not settle is RECORDED, never hidden (design 7.1).
	for i = 1, n - 1 - window do
		local a = (out[i + 1] - out[i]) / step
		local b = (out[i + window + 1] - out[i + window]) / step
		worstChange = math.max(worstChange, math.abs(b - a))
	end
	-- 1e-6 OF A SLOPE, not 1e-9: the convergence loop settles every window to within 1e-12 of the
	-- limit, and re-integrating the heights puts ~1e-10 of float noise back. At 1e-9 the first live
	-- run on C1 printed a "breach" of 2.40 % against a 2.40 % allowance on all four roads, which is
	-- noise wearing a breach's name. 1e-6 is a ten-thousandth of the printed precision.
	if worstChange > limit + 1e-6 then
		table.insert(
			breaches,
			string.format(
				"%s: grade change %.2f %% over %d st, over the %.2f %% allowance",
				road.id,
				worstChange * 100,
				spanStuds,
				limit * 100
			)
		)
	end
	-- WHAT THE ROAD ACTUALLY DOES, not what it was allowed: `gradePercent` is the ceiling the
	-- relaxation arm ended on, and on a base it cannot meet that is 20 % while the realised grade
	-- may be far less. Both are reported so neither can stand in for the other.
	local realised = 0
	for i = 1, n - 1 do
		realised = math.max(realised, math.abs(out[i + 1] - out[i]) / step)
	end
	return {
		road = road,
		from = road.from,
		to = road.to,
		step = step,
		y = out,
		gradePercent = ceilingPercent,
		realisedGradePercent = realised * 100,
		relaxed = relaxed,
		worstCutFill = worst,
		worstGradeChangePercent = worstChange * 100,
		gradeChangeSpanStuds = spanStuds,
		breaches = breaches,
	}
end

-- The profile's own height at one point along the road, linearly between its 20-st samples.
function TerrainBake.profileY(profile: Profile, along: number): number
	local t = (along - profile.from) / profile.step
	local i = math.clamp(math.floor(t) + 1, 1, #profile.y)
	local j = math.clamp(i + 1, 1, #profile.y)
	local f = math.clamp(t - (i - 1), 0, 1)
	return profile.y[i] + (profile.y[j] - profile.y[i]) * f
end

-- THE ONE BAND REALISER, and every road path goes through it (round-2 finding 1, lesson L-031).
-- It answers the band as bounds on |d|, the distance from the centreline, for the side the point is
-- on. `Relief.columnsFor` snaps a band to whole voxel columns on the PLUS side only; every centre
-- sits at = 1 (mod 4) (design 7.1 correction F-2), so the minus side's whole columns are 2 studs off
-- that lattice and a mirrored band would not be whole columns there. Reflecting the centre through
-- the origin turns the minus side into a plus side, so ONE function realises both: each side gets
-- the same number of whole columns, the same width, and midpoints half a voxel apart -- which is the
-- closest to symmetric a centre at = 1 (mod 4) allows.
function TerrainBake.bandFor(centre: number, nearStuds: number, farStuds: number, side: number): (number, number)
	if side >= 0 then
		local first, last = Relief.columnsFor(centre, nearStuds, farStuds)
		return first - centre, last - centre
	end
	local first, last = Relief.columnsFor(-centre, nearStuds, farStuds)
	return first + centre, last + centre
end

-- THE CROSS-SECTION at one point: the height the road wants there, the material, and how strongly
-- the road owns the ground (1 inside the verge, falling to 0 across the bank). Returns nil when the
-- point is outside every road's reach, which is most of a cell.
--
-- The rut and the ditch are realised by `Relief.columnsFor` at the road's own parity, so their
-- WIDTH does not depend on where the centreline happens to fall (correction F-2).
function TerrainBake.roadAt(profiles: { Profile }, naturalY: number, x: number, z: number): (number?, string?, number)
	local best: Profile? = nil
	local bestD, bestAlong = math.huge, 0
	for _, profile in profiles do
		local road = profile.road
		local along = if road.axis == "x" then x else z
		if along >= road.from and along <= road.to then
			local d = math.abs((if road.axis == "x" then z else x) - road.at)
			if d < bestD then
				best, bestD, bestAlong = profile, d, along
			end
		end
	end
	if best == nil then
		return nil, nil, 0
	end
	local profile = best :: Profile
	local road = profile.road
	local spec = TerrainBake.ROAD
	local centre = road.at
	local across = (if road.axis == "x" then z else x)
	local d = math.abs(across - centre)
	local crownY = TerrainBake.profileY(profile, bestAlong)
	local material = spec.material[road.axis]
	-- Which band, measured OUTWARD from the centreline, on THE SIDE THE POINT IS ON. Round 2 built
	-- the far side's bounds as `centre - far`, which is negative and so unreachable by |d|: the ditch
	-- and the ruts were dead on the minus side of every road in the world (round-2 finding 1).
	local side = if across >= centre then 1 else -1
	local lo, hi = TerrainBake.bandFor(centre, spec.rut.nearStuds, spec.rut.farStuds, side)
	local ditchLo, ditchHi = TerrainBake.bandFor(centre, spec.ditch.nearStuds, spec.ditch.farStuds, side)
	if d <= spec.carriagewayStuds then
		local y = crownY - spec.crownFallStuds * (d / spec.carriagewayStuds)
		-- Design 7.1: `mid` 0..+-6, the rut +-6..+-10 as ONE whole column, `outer` +-10..+-20. The
		-- realised column is 4 st wide, so what is left of the nominal rut band keeps the
		-- carriageway's own material. Round 2 wrote this as three arms whose first and last agreed.
		local name = if d < 10 then material.mid else material.outer
		if d >= lo and d <= hi then
			name = material.rut
		end
		return y, name, 1
	end
	if d >= ditchLo and d <= ditchHi then
		return crownY - spec.ditch.depthStuds, material.ditch, 1
	end
	if d < ditchLo then
		-- The shoulder between the carriageway edge and the ditch lip: level with the edge.
		return crownY - spec.crownFallStuds, material.outer, 1
	end
	if d <= spec.vergeStuds then
		return crownY - spec.crownFallStuds, material.verge, 1
	end
	-- THE BANK: back to the natural ground, never steeper than 1:2 and never narrower than 12 st.
	local vergeY = crownY - spec.crownFallStuds
	local drop = math.abs(naturalY - vergeY)
	local width = math.max(spec.bankMinStuds, drop / spec.bankMaxSlope)
	local t = (d - spec.vergeStuds) / width
	if t >= 1 then
		return nil, nil, 0
	end
	local smooth = t * t * (3 - 2 * t)
	return vergeY + (naturalY - vergeY) * smooth, nil, 1 - smooth
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

-- THE SHAPE OF ONE TILE, PURE: heights and material names for the tile's own 32 x 32 columns, and
-- it touches `Terrain` nowhere. Split out of `bakeTile` so the thing that decides the ground can be
-- asserted by a spec over a synthetic snapshot (round-1 finding 7).
--
-- THE GRID IS WIDER THAN THE TILE. The slope limiter reaches `LIMIT_MARGIN_STUDS` past a column, so
-- limiting the tile alone would clamp the same ground to two heights either side of a 128-stud seam
-- (round-1 finding 2). It is shaped and limited over the tile plus that margin; only the inner tile
-- is returned.
function TerrainBake.shapeTile(
	tile: Tile,
	snapshot: Snapshot,
	cellIds: { string },
	plans: { [string]: any },
	profiles: { Profile }?
): ({ number }, { string }, number)
	local v = Relief.VOXEL
	local side = TerrainBake.TILE_STUDS
	local n = math.floor(side / v)
	local margin = math.floor(TerrainBake.LIMIT_MARGIN_STUDS / v)
	local wide = n + 2 * margin
	local union = TerrainBake.unionOf(cellIds)
	local baseAt = TerrainBake.readerFor(snapshot)
	local shaped = table.create(wide * wide, 0)
	local exempt = table.create(wide * wide, false)
	local names: { string } = table.create(wide * wide, "")
	local depth = table.create(wide * wide, 0)
	local roads = Grid.roads()
	-- THE BLUR, ONCE, SEPARABLY, over the whole shaping grid (328c note (c)). Per point it is
	-- 1,369 base reads; over the grid it is 2 x 37, and `grid_relief.spec` measures that the two
	-- agree. With the per-point kernel this task's own spec run passed the harness 300-s cap.
	local blurred =
		Relief.blurredGrid(baseAt, tile.minX + (1 - margin - 0.5) * v, tile.minZ + (1 - margin - 0.5) * v, wide, wide)
	for i = 1, wide do
		local x = tile.minX + (i - margin - 0.5) * v
		for k = 1, wide do
			local z = tile.minZ + (k - margin - 0.5) * v
			local at = (k - 1) * wide + i
			local base = baseAt(x, z)
			local id = TerrainBake.cellAt(cellIds, x, z)
			local form = Relief.LANDFORMS[id]
			if base == nil then
				-- `readerFor` has no answer here. KEEP GROUND rather than invent one: writing 0
				-- would cut a hole from the band floor up to y = 0 (round-1 note).
				shaped[at] = snapshot.minY
				exempt[at] = true
			elseif form == nil then
				shaped[at] = base
			else
				local bounds = Grid.boundsOf(id)
				-- ONE FADE, handed to the arithmetic that owns it (round-1 finding 7). Multiplying
				-- the bake's own fade onto `heightAt`'s cell-edge `k` put two fades in series.
				local here =
					Relief.heightAt(form, bounds, roads, baseAt, x, z, TerrainBake.blendAt(union, x, z), blurred[at])
				shaped[at] = here or base
				exempt[at] = Relief.isExempt(form, bounds, x, z)
				depth[at] = TerrainBake.depthAt(base, here or base)
			end
			-- THE ROAD WINS over the landform inside its verge and blends back across its bank
			-- (design 7.1). Its columns are EXEMPT from the limiter: a limiter free to move a ditch
			-- has not cut a ditch.
			if profiles ~= nil then
				local roadY, roadName, weight = TerrainBake.roadAt(profiles, shaped[at], x, z)
				if roadY ~= nil then
					shaped[at] = roadY
					if roadName ~= nil then
						names[at] = roadName
					end
					if weight >= 1 then
						exempt[at] = true
					end
				end
			end
		end
	end
	shaped = TerrainBake.limitGrid(shaped, wide, wide, v, Relief.LIMIT_DEG.tree, exempt)
	-- MATERIALS IN A SECOND PASS, over the LIMITED grid: `Relief.materialAt`'s scree rule reads the
	-- slope, and the slope is only real once the limiter has finished with it. The road's own name,
	-- set above, wins -- a road is gravel whatever the ground under it was going to be (design 7.1).
	local inner = table.create(n * n, 0)
	local innerNames: { string } = table.create(n * n, "")
	for i = 1, n do
		for k = 1, n do
			local from = (k + margin - 1) * wide + (i + margin)
			local to = (k - 1) * n + i
			inner[to] = shaped[from]
			local name = names[from]
			if name == "" then
				local x = tile.minX + (i - 0.5) * v
				local z = tile.minZ + (k - 0.5) * v
				local id = TerrainBake.cellAt(cellIds, x, z)
				local form = Relief.LANDFORMS[id]
				if form == nil then
					name = "Ground"
				else
					local slope = TerrainBake.slopeAt(shaped, wide, i + margin, k + margin, v)
					name = Relief.materialAt(form, Grid.boundsOf(id), plans[id], slope, depth[from], x, z)
					-- THE 70/30 SCREE MIX is the bake's, not `materialAt`'s -- its own header says
					-- so (design 5.3 step 3). Deterministic in the column, so a re-run is a no-op.
					if name == "Rock" and TerrainBake.mixAt(x, z) >= TerrainBake.SCREE_ROCK_SHARE then
						name = form.floor.default
					end
				end
			end
			innerNames[to] = name
		end
	end
	return inner, innerNames, n
end

-- ONE TILE: shape and material in the SAME WriteVoxels call (design 5.3 step 3). IDEMPOTENT --
-- every voxel of the region is written from the snapshot, so a re-run against the same snapshot is
-- a no-op. `dryRun` builds every array and skips only the write, so its cost is the real cost less
-- one engine call -- not a different measurement wearing the same name.
function TerrainBake.bakeTile(
	tile: Tile,
	snapshot: Snapshot,
	cellIds: { string },
	plans: { [string]: any },
	dryRun: boolean?,
	profiles: { Profile }?
): TileReport
	local started = os.clock()
	local v = Relief.VOXEL
	local side = TerrainBake.TILE_STUDS
	local inner, innerNames, n = TerrainBake.shapeTile(tile, snapshot, cellIds, plans, profiles)
	local lo, hi = math.huge, -math.huge
	for _, h in inner do
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
		local min = region.CFrame.Position - size / 2
		local materials, occupancies = {}, {}
		for i = 1, n do
			materials[i], occupancies[i] = {}, {}
			for j = 1, ny do
				materials[i][j], occupancies[i][j] = {}, {}
			end
		end
		for i = 1, n do
			for k = 1, n do
				local at = (k - 1) * n + i
				local h = inner[at]
				local material = (Enum.Material :: any)[innerNames[at]] or Enum.Material.Ground
				for j = 1, ny do
					local bottom = min.Y + (j - 1) * v
					local occupancy = math.clamp((h - bottom) / v, 0, 1)
					materials[i][j][k] = if occupancy > 0 then material else AIR
					occupancies[i][j][k] = occupancy
				end
			end
		end
		if not dryRun then
			Workspace.Terrain:WriteVoxels(region, v, materials, occupancies)
		end
		report.voxels += voxels
	end
	report.elapsedMs = math.floor((os.clock() - started) * 1000 + 0.5)
	return report
end

-- HOW DEEP A POINT SITS BELOW THE GROUND THE LANDFORM CAME FROM -- what `Relief.materialAt`'s mud
-- rule reads (`A1.floor.mudDepthStuds` 10, `D1` 6). Round 1 passed a literal 0, so the rule could
-- never fire; C1's floor is plain `Ground`, so nothing was wrong for THIS cell, and 328f reads it.
function TerrainBake.depthAt(base: number, shaped: number): number
	return math.max(0, base - shaped)
end

-- HOW FAR OUTSIDE A TILE THE SNAPSHOT MUST REACH: the limiter's margin, plus the blur's own
-- cutoff, plus one voxel so the outermost sample has a neighbour. `Relief.blurredAt` is the only
-- point reader that leaves its point -- except a `bench`, which walks the base across its whole v
-- band (`applyOps`), and `bakeTileAt` refuses that rather than snapshot a slice it does not hold.
function TerrainBake.padFor(): number
	local v = Relief.VOXEL
	return v * math.ceil((TerrainBake.LIMIT_MARGIN_STUDS + Relief.BLUR.cutoffStuds + v) / v)
end

-- THE LONG PROFILES of every road a run touches, computed ONCE from the base before any voxel is
-- written -- a profile read off half-baked ground would depend on the tile order. `sampler`
-- defaults to a terrain raycast, which is the base only while nothing has been written yet.
function TerrainBake.profilesFor(cellIds: { string }, sampler: ((number, number) -> number?)?): { Profile }
	local read = sampler or TerrainBake.terrainReader()
	local wanted: { [string]: Relief.Road } = {}
	for _, id in cellIds do
		for _, key in { "main", "muster", "west", "east" } do
			local road = (Grid.roadsOf(id) :: any)[key]
			wanted[road.id] = road
		end
	end
	local out: { Profile } = {}
	for _, road in wanted do
		local profile = TerrainBake.longProfile(road, read)
		if profile ~= nil then
			table.insert(out, profile)
		end
	end
	table.sort(out, function(a, b)
		return a.road.id < b.road.id
	end)
	return out
end

-- The terrain raycast reader, in one place: the survey and the profiles both use it.
function TerrainBake.terrainReader(): (number, number) -> number?
	return function(x: number, z: number): number?
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { Workspace.Terrain }
		params.IgnoreWater = true
		local hit = Workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -4000, 0), params)
		return if hit then hit.Position.Y else nil
	end
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
	dryRun: boolean,
	profiles: { Profile }?
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
	-- THE PROFILES ARE HANDED IN, ALWAYS. Round 2 fell back to `profilesFor` here, which raycasts
	-- LIVE terrain: from the second tile onwards that reads ground this bake has already written, so
	-- two tiles of one road would meet at a step and the result would depend on the tile order
	-- (round-2 finding 2). `tools/terrainbake.py` computes them ONCE from the base and sends the
	-- same set to every tile; a tile with none is REFUSED rather than given a profile of its own.
	if profiles == nil then
		return {
			minX = tile.minX,
			minZ = tile.minZ,
			calls = 0,
			voxels = 0,
			bandMin = 0,
			bandMax = 0,
			elapsedMs = 0,
			message = "no profiles were handed to tile "
				.. tostring(tileIndex)
				.. ". The long profiles are computed ONCE from the base, before any write, and sent "
				.. "to every tile; a profile read here would be read off half-baked ground.",
		}
	end
	return TerrainBake.bakeTile(tile, slice, cellIds, {}, dryRun, profiles)
end

-- A STABLE 0..1 PER COLUMN, from its own coordinates: the scree mix has to come out the same on
-- every run, so it cannot use `Random`. One integer hash, the shape `Grid.seedFor` already uses.
function TerrainBake.mixAt(x: number, z: number): number
	local h = bit32.bxor(
		bit32.band(math.floor(x / Relief.VOXEL) * 73856093, 0x7FFFFFFF),
		bit32.band(math.floor(z / Relief.VOXEL) * 19349663, 0x7FFFFFFF)
	)
	h = bit32.band(h * 1103515245 + 12345, 0x7FFFFFFF)
	return h / 0x7FFFFFFF
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
	local reader = heightOf or TerrainBake.terrainReader()
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
