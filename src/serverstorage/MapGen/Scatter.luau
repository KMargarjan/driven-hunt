--!strict
-- MapGen.Scatter: THE SEEDED HALF OF EVERY PLACEMENT, and PURE. Where the trees land, which species
-- and which age class each one is, where a block's patches sit, and where the forest floor goes.
--
-- Trees use a jittered grid -- the cheap approximation of Poisson disc sampling: one candidate per
-- cell, displaced inside its own cell, so no two points can be closer than (1 - jitter) * spacing and
-- the result has no visible grid.
--
-- ONE SEEDED GENERATOR PER LAYER, never a shared sequence: with one shared sequence a step's output
-- would depend on which steps ran before it in the same MCP call, and that is not knowable.
-- `Random.new(seed * 1000 + LAYER)` is deterministic and takes its seed as an argument, which is
-- what the module table's "never Random" row protects against -- unseeded randomness.
--
-- ONE NUMBER ANSWERS ONE QUESTION (Task 63, review round 1). The acceptance draw decides whether a
-- candidate becomes a tree and NOTHING else: it never leaves `weighted`, and the species and age
-- questions draw their own numbers, from the point's position, through `Scatter.pointKey`. Re-using
-- the acceptance key for the species -- which this module once did -- made the species depend on the
-- DENSITY: every candidate accepted where the weight is 0.34 has a key below the clump strength, so
-- every clump outside the dense band was a monoculture over about half the wood. That is the previous
-- project's named killer -- "one predicate answered two unrelated questions"
-- (docs/PROJECT_CONTEXT.md) -- and the fix is a separate number per question, not a wider tolerance.
--
--   Random  https://create.roblox.com/docs/reference/engine/datatypes/Random
--   Jittered grid / Poisson disc: Bridson, "Fast Poisson Disk Sampling in Arbitrary Dimensions"
--   (the design's external sources)
--
-- Design: docs/design/map-generator.md, "The mix model: a block's character as data"
local Height = require(script.Parent:WaitForChild("Height"))
local Layout = require(script.Parent:WaitForChild("Layout"))

local Scatter = {}

export type Point = { x: number, z: number }
export type Area = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Tree = { x: number, z: number, species: string, age: string, tier: string }
export type Patch = {
	kind: string,
	index: number,
	x: number,
	z: number,
	radiusStuds: number,
	spec: any,
}

-- A block's own offset into the seed, from its rectangle: two sub-blocks of the same map draw
-- different numbers, and the SAME sub-block draws the same numbers whatever order the steps run in.
local function blockSeed(block): number
	return math.floor(block.minX * 7 + block.minZ * 13 + block.maxX * 3 + block.maxZ * 5)
end

-- Layer ids. Each layer's generator is Random.new(seed * 1000 + id), so adding a layer never moves
-- an existing layer's points.
Scatter.LAYER = table.freeze({
	trees = 1,
	hedge = 2,
	brush = 3,
	ferns = 4,
	deadwood = 5,
	patch = 6,
	patchTrees = 7,
})

function Scatter.generator(seed: number, layer: number): Random
	return Random.new(seed * 1000 + layer)
end

-- A FLAT HASH OF THREE INTEGERS, uniform in 0..1 and pure. The first build of the species choice used
-- `math.noise` and MEASURED 230 birch to 195 spruce to 3 oak in one quadrant, against Karen's
-- shares -- because a noise field is bell-shaped around its middle, so the middle band of a share
-- table wins. A hash is flat, so the shares below are the shares she asked for. Measured with this
-- map's own inputs (Task 63): 200,000 points land within 0.05 percentage points of uniform in every
-- decile.
local function hash01(a: number, b: number, c: number): number
	local h = (a * 374761393 + b * 668265263 + c * 2654435761) % 2147483647
	h = (h * 1274126177) % 2147483647
	return h / 2147483647
end

-- ONE STREAM PER PER-TREE QUESTION, the same rule as LAYER above and for the same reason: a number
-- drawn for one decision must not decide a second one. A later per-tree question (a lean, a trunk
-- size) gets its own stream id without moving the species or the age.
Scatter.STREAM = table.freeze({ species = 1, age = 2, variant = 3, rotation = 4 })

-- THE POINT'S OWN NUMBER for one question, taken from WHERE IT IS rather than from when it was
-- drawn. Uniform in 0..1, pure, and independent of the acceptance draw -- which is the whole point:
-- how thick the wood is at a spot must not decide which tree stands there. The position enters at
-- 1/16 of a stud and the closest two trunks anywhere are over 7 studs apart, so no two trees share
-- a key.
function Scatter.pointKey(x: number, z: number, seed: number, stream: number): number
	return hash01(math.floor(x * 16), math.floor(z * 16), seed * 31 + stream * 7919)
end

-- Pick from a share table by a uniform draw, walking the species in `SPECIES_ORDER` so the answer
-- cannot depend on `pairs` ordering. Shares that do not sum to 1 are normalised, which is what lets
-- a patch declare `{ oak = 0.75, birch = 0.25 }` and a block declare all five.
local function pickByShare(mix, order: { string }, u: number): string
	local total = 0
	for _, name in ipairs(order) do
		total += mix[name] or 0
	end
	if total <= 0 then
		return order[1]
	end
	local running = 0
	local last = order[1]
	for _, name in ipairs(order) do
		local share = mix[name] or 0
		if share > 0 then
			last = name
			running += share / total
			if u < running then
				return name
			end
		end
	end
	return last
end

-- ---------------------------------------------------------------- the grids

-- THE LATTICE IS GLOBAL, NOT PER-AREA, AND THAT IS WHAT MAKES THE SEPARATION GUARANTEE TRUE.
--
-- A cell index is computed from the ABSOLUTE coordinate, so every area samples the same lattice and
-- a cell belongs to exactly one area -- the one its CENTRE falls in. Anchoring the cells to
-- `area.minX` instead (which this function did until 2026-10-04) offsets two neighbouring areas'
-- lattices from each other whenever the area is not a whole number of cells wide, and 512 studs of
-- sub-block is 17.07 cells of 30. MEASURED consequence: two trees 1.4 studs apart at (-95, 1147),
-- inside each other, against a guarantee of 12.2 studs clear.
local function cellRange(from: number, to: number, spacing: number): (number, number)
	return math.floor(from / spacing), math.ceil(to / spacing)
end

-- The candidates, in a FIXED order (row by row). `reject(x, z)` drops a cell; nothing is retried,
-- because a retry would make the point count depend on the rejection rate and stop being
-- reproducible from the seed alone.
function Scatter.jitteredGrid(
	area: Area,
	spacing: number,
	jitter: number,
	rng: Random,
	reject: ((number, number) -> boolean)?
): { Point }
	local out: { Point } = {}
	local colFrom, colTo = cellRange(area.minX, area.maxX, spacing)
	local rowFrom, rowTo = cellRange(area.minZ, area.maxZ, spacing)
	for row = rowFrom, rowTo do
		for col = colFrom, colTo do
			local cx, cz = (col + 0.5) * spacing, (row + 0.5) * spacing
			-- THE CELL BELONGS TO THE AREA ITS CENTRE IS IN, which is what partitions the global
			-- lattice between neighbouring areas without a gap and without an overlap.
			if cx >= area.minX and cx < area.maxX and cz >= area.minZ and cz < area.maxZ then
				-- All three numbers are drawn for EVERY cell, before the rejection test, so a
				-- rejected cell does not shift the draws of the cells after it.
				local dx = (rng:NextNumber() - 0.5) * spacing * jitter
				local dz = (rng:NextNumber() - 0.5) * spacing * jitter
				local key = rng:NextNumber()
				local x, z = cx + dx, cz + dz
				if not (reject and reject(x, z)) then
					table.insert(out, { x = x, z = z, key = key } :: any)
				end
			end
		end
	end
	return out
end

-- The spacing that fits about `count` cells into `area`, so a caller asks for a NUMBER (which is
-- what a per-hectare rate turns into) instead of for a spacing.
function Scatter.spacingFor(area: Area, count: number): number
	local span = (area.maxX - area.minX) * (area.maxZ - area.minZ)
	return math.sqrt(span / math.max(count, 1))
end

-- The candidates a WEIGHT accepts: `weight(x, z)` returns 0..1 and a candidate is kept when its own
-- drawn key is below it. Each cell draws all three numbers before any test, so a rejected cell never
-- shifts the draws of the cells after it.
--
-- THE KEY DOES NOT LEAVE THIS FUNCTION (Task 63, review round 1). It answered "does this tree
-- exist", it was compared against the weight, and it is finished: a point is a POSITION. Storing it
-- on the point is how the species came to be decided by the density, so the only way to make that
-- mistake unrepeatable is for the number not to be there.
function Scatter.weighted(
	area: Area,
	spacing: number,
	jitter: number,
	rng: Random,
	weight: (number, number) -> number,
	reject: ((number, number) -> boolean)?
): { Point }
	local out: { Point } = {}
	local colFrom, colTo = cellRange(area.minX, area.maxX, spacing)
	local rowFrom, rowTo = cellRange(area.minZ, area.maxZ, spacing)
	for row = rowFrom, rowTo do
		for col = colFrom, colTo do
			local cx, cz = (col + 0.5) * spacing, (row + 0.5) * spacing
			if cx >= area.minX and cx < area.maxX and cz >= area.minZ and cz < area.maxZ then
				local dx = (rng:NextNumber() - 0.5) * spacing * jitter
				local dz = (rng:NextNumber() - 0.5) * spacing * jitter
				local key = rng:NextNumber()
				local x, z = cx + dx, cz + dz
				if not (reject and reject(x, z)) and key < weight(x, z) then
					table.insert(out, { x = x, z = z })
				end
			end
		end
	end
	return out
end

local function sortSpatially(points)
	table.sort(points, function(a, b)
		if a.x ~= b.x then
			return a.x < b.x
		end
		return a.z < b.z
	end)
	return points
end

-- ---------------------------------------------------------------- the patches

-- WHERE A BLOCK'S PATCHES SIT. Patch KINDS and COUNTS are data (`character.patches`); patch CENTRES
-- are seeded here, under constraints a spec asserts over 20 seeds: a patch may not cover a stand, a
-- spawn pad, a tie tree or a marker, may not come within `keepClear + radius` of a road, and two
-- patches may not overlap. A named position would be reviewable but would make every seed the same
-- map; a seeded centre with proved constraints is reproducible AND honest, and the committed seed is
-- the one world Karen looks at.
--
-- THE CANDIDATES ARE A LATTICE, FILTERED, AND THEN ONE IS DRAWN. Drawing first and retrying would
-- make the result depend on how many attempts the loop happened to need; filtering first means the
-- constraints hold BY CONSTRUCTION and the draw only chooses among points that already satisfy them.
function Scatter.patchCentres(config, seed: number): { Patch }
	local out: { Patch } = {}
	if not config.INCLUDE.patches then
		return out
	end
	local block = Layout.activeBlock(config)
	local character = block.character
	if character == nil or character.patches == nil then
		return out
	end
	local pads = Layout.pads(config)
	local stands = Layout.standPoints(config)
	local ties = Layout.tieTreePoints(config)
	local padClear = config.SPAWN_PAD.radius + config.SPAWN_PAD.blend
	local drive = config.DRIVE
	local start = drive.driverStartSize

	local function allows(x: number, z: number, radius: number): boolean
		-- Wholly inside the block, so a patch is never half outside the wood it belongs to.
		local b = block.bounds
		if x - radius < b.minX or x + radius > b.maxX or z - radius < b.minZ or z + radius > b.maxZ then
			return false
		end
		-- Never within `keepClear + radius` of a road: a clearing that eats the gravel is not a
		-- clearing, and a thicket on it is a wall across the drive.
		if Layout.onRoadKeepClear(x, z, config, radius) then
			return false
		end
		for _, pad in ipairs(pads) do
			if (Vector3.new(x, 0, z) - Vector3.new(pad.x, 0, pad.z)).Magnitude <= radius + padClear then
				return false
			end
		end
		for _, stand in ipairs(stands) do
			if
				(Vector3.new(x, 0, z) - Vector3.new(stand.x, 0, stand.z)).Magnitude
				<= radius + config.STAND.clearRadius
			then
				return false
			end
		end
		for _, tie in ipairs(ties) do
			if (Vector3.new(x, 0, z) - Vector3.new(tie.x, 0, tie.z)).Magnitude <= radius + 10 then
				return false
			end
		end
		-- The drivers' strip, which is a marker 1,120 studs wide.
		if
			math.abs(z - config.ROADS.assembly.at) <= radius + start.Z / 2
			and math.abs(x - drive.centreX) <= radius + start.X / 2
		then
			return false
		end
		for _, placed in ipairs(out) do
			if (Vector3.new(x, 0, z) - Vector3.new(placed.x, 0, placed.z)).Magnitude <= radius + placed.radiusStuds then
				return false
			end
		end
		return true
	end

	local lattice = 40 -- studs: fine enough to leave hundreds of legal centres, coarse enough to be cheap
	for specIndex, spec in ipairs(character.patches) do
		for n = 1, (spec.count or 1) do
			local radius = spec.radiusStuds
			local candidates: { Point } = {}
			local b = block.bounds
			local x = b.minX + radius
			while x <= b.maxX - radius do
				local z = b.minZ + radius
				while z <= b.maxZ - radius do
					if allows(x, z, radius) then
						table.insert(candidates, { x = x, z = z })
					end
					z += lattice
				end
				x += lattice
			end
			if #candidates == 0 then
				error(
					string.format(
						"no legal centre for the %s patch (radius %d) in block %s: the constraints and the "
							.. "block's geometry disagree",
						tostring(spec.kind),
						radius,
						block.name
					),
					0
				)
			end
			-- Its own generator per (patch spec, ordinal), so adding a second gap does not move the
			-- young patch.
			local rng = Scatter.generator(seed, Scatter.LAYER.patch + specIndex * 11 + n)
			local pick = candidates[rng:NextInteger(1, #candidates)]
			table.insert(out, {
				kind = spec.kind,
				index = n,
				x = pick.x,
				z = pick.z,
				radiusStuds = radius,
				spec = spec,
			})
		end
	end
	return out
end

-- The trees inside ONE patch: its own grid at `spacingScale` of the wood's, its own weight, its own
-- species mix and a single age class. A `gap` patch has weight 0 and gets none, which is what makes
-- it a clearing rather than a thicket.
function Scatter.patchTrees(patch: Patch, config, seed: number): { Tree }
	local spec = patch.spec
	local weight = spec.weight or 0
	if weight <= 0 then
		return {}
	end
	local radius = patch.radiusStuds
	local area: Area = {
		minX = patch.x - radius,
		maxX = patch.x + radius,
		minZ = patch.z - radius,
		maxZ = patch.z + radius,
	}
	local spacing = config.TREE_SPACING * (spec.spacingScale or 1)
	local rng = Scatter.generator(seed + blockSeed(area), Scatter.LAYER.patchTrees)
	local points = Scatter.weighted(area, spacing, config.SCATTER_JITTER, rng, function()
		return weight
	end, function(x, z)
		-- A DISC, not the square its grid covers: a square thicket reads as a plantation.
		if (Vector3.new(x, 0, z) - Vector3.new(patch.x, 0, patch.z)).Magnitude > radius then
			return true
		end
		-- And every ground rule the wood has, so a patch cannot put a trunk on the gravel or on a
		-- stand even if its centre was legal.
		return Layout.onRoadKeepClear(x, z, config) or Layout.treeDensityBlockers(x, z, config)
	end)
	local age = spec.age or "mature"
	local mix = spec.mix or {}
	local out: { Tree } = {}
	for _, point in ipairs(sortSpatially(points)) do
		local u = Scatter.pointKey(point.x, point.z, seed, Scatter.STREAM.species)
		table.insert(out, {
			x = point.x,
			z = point.z,
			species = pickByShare(mix, config.SPECIES_ORDER, u),
			age = age,
			tier = age,
		})
	end
	return out
end

-- ---------------------------------------------------------------- species, age and variant

-- WHICH SPECIES LEADS THE CLUMP THIS POINT IS IN. Exposed because it is the answer to a question of
-- its own -- "which clump is this" -- and because a spec cannot measure the mix INSIDE a clump
-- without it.
function Scatter.clumpLeaderAt(x: number, z: number, seed: number, config, character): string
	-- The clump is a block of `clumpStuds`, its edges pushed about by a noise field so the wood does
	-- not read as a chessboard. The field decides WHERE the boundary is; the hash decides WHICH
	-- species the clump is, and that is what keeps the shares honest.
	local clump = character.clumpStuds
	local frequency = 1 / clump
	local wobble = math.noise(x * frequency, z * frequency, seed * 0.37 + 11.5) * clump / 2
	local bx = math.floor((x + wobble) / clump)
	local bz = math.floor((z + wobble) / clump)
	return pickByShare(character.mix, config.SPECIES_ORDER, hash01(bx, bz, seed))
end

-- WHICH SPECIES STANDS HERE. Pure, deterministic, and TWO rules rather than one:
--
--  1. a low-frequency clump field picks the band, so the wood comes in stands a drive crosses --
--     dark blocks of spruce, light stands of birch -- instead of a species salad at every step;
--  2. WET GROUND FORCES ALDER, whatever the clump says. Black alder is a wet-ground tree, and a
--     spruce standing in a hollow reads as a mistake to anyone who has walked a European wood.
--
-- NO `key` PARAMETER, deliberately (Task 63, review round 1): the species question draws its own
-- number here, from the point's position, so no caller can hand it a number that was drawn to answer
-- something else. The signature is what makes it stay fixed.
function Scatter.speciesAt(x: number, z: number, seed: number, config, character, wetness: number?): string
	if wetness ~= nil and wetness > 0.5 then
		return "alder"
	end
	local leader = Scatter.clumpLeaderAt(x, z, seed, config, character)
	-- Most of a clump is its leader; the rest is drawn from the same shares, so a stand of spruce
	-- has birch in it and the MARGINAL share of every species is still Karen's number.
	local key = Scatter.pointKey(x, z, seed, Scatter.STREAM.species)
	if key < character.clumpStrength then
		return leader
	end
	local u = (key - character.clumpStrength) / (1 - character.clumpStrength)
	return pickByShare(character.mix, config.SPECIES_ORDER, math.clamp(u, 0, 0.999999))
end

-- WHICH AGE CLASS STANDS HERE, from its own stream, so the age cannot be decided by the number that
-- chose the species or by the one that decided the tree exists.
function Scatter.ageAt(x: number, z: number, seed: number, config, character): string
	local u = Scatter.pointKey(x, z, seed, Scatter.STREAM.age)
	return pickByShare(character.ages, config.AGE_ORDER, u)
end

-- WHICH OF A TIER'S MESHES THIS TREE IS, from its own stream. A species with one mesh names one key
-- and this always returns it; Karen's oak pack has seven, and this is what stops ~1,000 copies of
-- one mesh reading as a colonnade (TASKS.md row 79a(d)).
--
-- A SPECIES WITH NO KEYS FALLS BACK TO OAK'S, with its own geometry and colour, and the caller
-- reports the substitution BY NAME. That is the design's proxy rule one level up: the whole forest
-- is buildable with no asset id at all.
function Scatter.variantKeyFor(
	x: number,
	z: number,
	seed: number,
	config,
	species: string,
	tier: string
): (string?, string?)
	local row = config.SPECIES[species]
	if row == nil then
		return nil, nil
	end
	local keys = row.keys[tier]
	local substituted: string? = nil
	if keys == nil or #keys == 0 then
		local fallback = config.SPECIES.oak
		keys = fallback and fallback.keys[tier]
		substituted = species
	end
	if keys == nil or #keys == 0 then
		return nil, substituted
	end
	local u = Scatter.pointKey(x, z, seed, Scatter.STREAM.variant)
	local index = math.clamp(math.floor(u * #keys) + 1, 1, #keys)
	return keys[index], substituted
end

-- ---------------------------------------------------------------- the wood

-- The wood, ONE SUB-BLOCK at a time. The grid is fixed at TREE_SPACING and the density decides what
-- survives, so the wood is thick where the shooter looks and thin in the backdrop -- and the count is
-- a MEASUREMENT of the map rather than a number somebody asked for.
--
-- The sub-block's own cells are the sub-block's own draws: a sub-block is a rectangle of the same
-- global grid, so which trees exist does not depend on how the work was cut into steps.
function Scatter.trees(
	config,
	seed: number,
	block,
	patches: { Patch },
	reject: ((number, number) -> boolean)?
): { Tree }
	local rng = Scatter.generator(seed + blockSeed(block), Scatter.LAYER.trees)
	local active = Layout.activeBlock(config)
	local character = active.character
	if character == nil then
		return {}
	end
	local points = Scatter.weighted(block, config.TREE_SPACING, config.SCATTER_JITTER, rng, function(x, z)
		return Layout.treeDensity(x, z, config, patches)
	end, reject)
	local out: { Tree } = {}
	for _, point in ipairs(sortSpatially(points)) do
		local wetness = Height.wetAt(point.x, point.z, seed, config)
		local species = Scatter.speciesAt(point.x, point.z, seed, config, character, wetness)
		-- OUTSIDE EVERY BLOCK IS THE BACKDROP TIER: a cheaper mesh at a lower render fidelity, in
		-- the one place no player walks. Inside a block the tier IS the age class.
		local inBlock = Layout.blockAt(point.x, point.z, config) ~= nil
		local age = if inBlock then Scatter.ageAt(point.x, point.z, seed, config, character) else "mature"
		table.insert(out, {
			x = point.x,
			z = point.z,
			species = species,
			age = age,
			tier = if inBlock then age else "backdrop",
		})
	end
	return out
end

-- EVERY TREE THE WHOLE MAP PLANTS, composed from the same functions the steps use, so the triangle
-- bound and the walkability spec measure the wood that actually gets built rather than a second
-- model of it. Pure, and it is the expensive one -- a spec calls it once and reuses the list.
function Scatter.allTrees(config, seed: number): { Tree }
	local patches = Scatter.patchCentres(config, seed)
	local out: { Tree } = {}
	local function append(list)
		for _, tree in ipairs(list) do
			table.insert(out, tree)
		end
	end
	for _, block in ipairs(Layout.treeBlocks(config)) do
		append(Scatter.trees(config, seed, block, patches))
	end
	-- THE RIM REFUSES EVERY BLOCK'S GROUND. `backdropBlocks` expresses a ring as four rectangles
	-- and two of them reach into block 1, so without this a rim candidate inside the block asked
	-- `treeDensity`, got the BLOCK's weight, and was planted on top of a tree the block's own pass
	-- had already put there -- the overlapping pair measured at (-95, 1147).
	for _, block in ipairs(Layout.backdropBlocks(config)) do
		append(Scatter.trees(config, seed, block, patches, Scatter.insideAnyBlock(config)))
	end
	for _, patch in ipairs(patches) do
		append(Scatter.patchTrees(patch, config, seed))
	end
	return out
end

-- "IS THIS INSIDE A DRIVE BLOCK", as a reject function for the rim's own pass. Its own function
-- because `Props` needs the same one, and because a predicate used by two passes must be one
-- predicate.
function Scatter.insideAnyBlock(config): (number, number) -> boolean
	return function(x: number, z: number): boolean
		return Layout.blockAt(x, z, config) ~= nil
	end
end

-- ---------------------------------------------------------------- the forest floor

-- A COUNT-BASED SCATTER over one sub-block, used by brush, ferns and deadwood: the rate is per
-- hectare, so the count comes from the area and the caller asks for a number.
local function countScatter(
	config,
	seed: number,
	block,
	layer: number,
	perHa: number,
	scale: ((number, number) -> number)?
): { Point }
	local rng = Scatter.generator(seed + blockSeed(block), layer)
	local wanted = Layout.countFor(block, perHa)
	if wanted <= 0 then
		return {}
	end
	local spacing = Scatter.spacingFor(block, math.ceil(wanted * config.SCATTER_OVERSAMPLE))
	local candidates = Scatter.jitteredGrid(block, spacing, config.SCATTER_JITTER, rng, function(x, z)
		return Layout.onRoadKeepClear(x, z, config) or Layout.treeDensityBlockers(x, z, config)
	end)
	-- A LOCAL RATE, so the gap carries double ferns and double deadwood without a second scatter:
	-- the candidate's own drawn key is compared against the local multiplier.
	local accepted: { Point } = {}
	for _, point in ipairs(candidates) do
		local multiplier = if scale then scale(point.x, point.z) else 1
		local keep = multiplier >= 1 or (point :: any).key < multiplier
		if keep then
			table.insert(accepted, point)
		end
	end
	-- Order by the drawn key and take the first `wanted`: the count is the rate's, and which
	-- candidates win is the seed's.
	for index, point in ipairs(accepted) do
		(point :: any).order = index
	end
	table.sort(accepted, function(a, b)
		local ka, kb = (a :: any).key, (b :: any).key
		if ka ~= kb then
			return ka < kb
		end
		return (a :: any).order < (b :: any).order
	end)
	local out: { Point } = {}
	for index = 1, math.min(wanted, #accepted) do
		table.insert(out, { x = accepted[index].x, z = accepted[index].z })
	end
	return sortSpatially(out)
end

-- How much more of a floor layer a patch asks for at this point: the `gap` patch doubles its ferns
-- and its deadwood, and a wet hollow doubles its ferns, so a clearing reads as a clearing and a
-- hollow reads as damp.
function Scatter.floorScale(x: number, z: number, patches: { Patch }, field: string): number
	local scale = 1
	for _, patch in ipairs(patches) do
		local factor = patch.spec[field]
		if
			factor ~= nil
			and (Vector3.new(x, 0, z) - Vector3.new(patch.x, 0, patch.z)).Magnitude <= patch.radiusStuds
		then
			scale *= factor
		end
	end
	return scale
end

function Scatter.brush(config, seed: number, block, _patches: { Patch }?): { Point }
	local character = Layout.activeBlock(config).character
	if character == nil or not config.INCLUDE.brush then
		return {}
	end
	return countScatter(config, seed, block, Scatter.LAYER.brush, character.brushPerHa)
end

function Scatter.ferns(config, seed: number, block, patches: { Patch }): { Point }
	local character = Layout.activeBlock(config).character
	if character == nil or not config.INCLUDE.ferns then
		return {}
	end
	-- The rate is the block's; the gap and the wet hollows ask for more of it in their own places.
	return countScatter(config, seed, block, Scatter.LAYER.ferns, character.fernsPerHa * 2, function(x, z)
		local scale = Scatter.floorScale(x, z, patches, "fernsScale")
		if Height.wetAt(x, z, seed, config) > 0.5 then
			scale *= 2
		end
		-- The base rate is doubled above and halved here, so an ordinary square of wood gets the
		-- block's own number and a gap or a hollow gets twice it.
		return scale / 2
	end)
end

function Scatter.deadwood(config, seed: number, block, patches: { Patch }): { Point }
	local character = Layout.activeBlock(config).character
	if character == nil or not config.INCLUDE.deadwood then
		return {}
	end
	return countScatter(config, seed, block, Scatter.LAYER.deadwood, character.deadwoodPerHa * 2, function(x, z)
		return Scatter.floorScale(x, z, patches, "deadwoodScale") / 2
	end)
end

-- ---------------------------------------------------------------- the hedgerow gates (retired layer)

-- Where one hedgerow line's gates are, as centres along the line's own axis, inside (from, to) --
-- the stretch of that line lying in the active block. Evenly divided and then jittered, so two gates
-- never land on top of each other and the drive is never funnelled into one hole.
--
-- The layer is switched off; the mechanism stays because its gate rule is the check that has already
-- caught a collidable wall across a drive (see Layout's note on the retired layers).
function Scatter.hedgeGates(config, seed: number, lineIndex: number, from: number, to: number): { number }
	local count = config.WORLD_HEDGES.gatesPerLine
	local rng = Scatter.generator(seed, Scatter.LAYER.hedge + lineIndex * 7)
	local half = config.WORLD_HEDGES.gateStuds / 2
	local span = to - from
	local out = {}
	-- Each gate owns one slice of the span and sits somewhere inside it, never closer than its own
	-- half-width to the slice's edge, so a gate is always wholly inside the drive.
	local slice = span / count
	for index = 1, count do
		local low = from + (index - 1) * slice + half
		local high = from + index * slice - half
		if high <= low then
			table.insert(out, from + (index - 0.5) * slice)
		else
			table.insert(out, rng:NextNumber(low, high))
		end
	end
	return out
end

return Scatter
