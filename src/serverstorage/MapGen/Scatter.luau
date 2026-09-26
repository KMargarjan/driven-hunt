--!strict
-- MapGen.Scatter: THE SEEDED HALF OF EVERY PLACEMENT, and PURE. Where the trees land, and where each
-- hedgerow's gates are cut.
--
-- Trees use a jittered grid -- the cheap approximation of Poisson disc sampling: one candidate per
-- cell, displaced inside its own cell, so no two points can be closer than (1 - jitter) * spacing and
-- the result has no visible grid.
--
-- ONE SEEDED GENERATOR PER LAYER, never a shared sequence (design section 5.3): with one shared
-- sequence a step's output would depend on which steps ran before it in the same MCP call, and
-- section 0 item 2 says that is not knowable. `Random.new(seed * 1000 + LAYER)` is deterministic and
-- takes its seed as an argument, which is what the module table's "never Random" row protects
-- against -- unseeded randomness. `Height.luau` needs no discrete choice and so uses none at all.
--
-- It takes `reject` as an ARGUMENT rather than requiring Layout, so this file needs no `script`, no
-- require and no Studio: a server spec drives it directly (design section 2.2's last paragraph).
--
--   Random  https://create.roblox.com/docs/reference/engine/datatypes/Random
--   Jittered grid / Poisson disc: the technique read out of RTerrainGenerator's scatter pass
--   (docs/design/map-generator.md section 11 source 5)
--
-- Design: docs/design/map-generator.md (sections 2.2, 5.3)
local Layout = require(script.Parent.Layout)

local Scatter = {}

-- A block's own offset into the seed, from its rectangle: two blocks of the same map draw different
-- numbers, and the SAME block draws the same numbers whatever order the steps run in.
local function blockSeed(block): number
	return math.floor(block.minX * 7 + block.minZ * 13 + block.maxX * 3 + block.maxZ * 5)
end

export type Point = { x: number, z: number }
export type Area = { minX: number, maxX: number, minZ: number, maxZ: number }

-- Layer ids. Each layer's generator is Random.new(seed * 1000 + id), so adding a layer never moves
-- an existing layer's points.
Scatter.LAYER = table.freeze({ trees = 1, hedge = 2, brush = 3 })

function Scatter.generator(seed: number, layer: number): Random
	return Random.new(seed * 1000 + layer)
end

-- ---------------------------------------------------------------- the hedgerow gates

-- Where one hedgerow line's gates are, as centres along the line's own axis, inside (from, to) --
-- which is the stretch of that line lying in the drive corridor. Evenly divided and then jittered, so
-- two gates never land on top of each other and the drive is never funnelled into one hole.
--
-- The line index enters the generator, so line 2's gates do not move when line 1 gains or loses one.
function Scatter.hedgeGates(config, seed: number, lineIndex: number, from: number, to: number): { number }
	local world = config.WORLD
	local count = world.gatesPerLine
	local rng = Scatter.generator(seed, Scatter.LAYER.hedge + lineIndex * 7)
	local half = world.gateStuds / 2
	local span = to - from
	local out = {}
	-- Each gate owns one slice of the span and sits somewhere inside it, never closer than its own
	-- half-width to the slice's edge, so a gate is always wholly inside the corridor.
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

-- ---------------------------------------------------------------- the wood

-- The candidates, in a FIXED order (row by row, then by the drawn key). `reject(x, z)` drops a cell;
-- nothing is retried, because a retry would make the point count depend on the rejection rate and
-- stop being reproducible from the seed alone.
function Scatter.jitteredGrid(
	area: Area,
	spacing: number,
	jitter: number,
	rng: Random,
	reject: ((number, number) -> boolean)?
): { Point }
	local out: { Point } = {}
	local cols = math.max(1, math.floor((area.maxX - area.minX) / spacing))
	local rows = math.max(1, math.floor((area.maxZ - area.minZ) / spacing))
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			-- All three numbers are drawn for EVERY cell, before the rejection test, so a rejected
			-- cell does not shift the draws of the cells after it.
			local dx = (rng:NextNumber() - 0.5) * spacing * jitter
			local dz = (rng:NextNumber() - 0.5) * spacing * jitter
			local key = rng:NextNumber()
			local x = area.minX + (col + 0.5) * spacing + dx
			local z = area.minZ + (row + 0.5) * spacing + dz
			if not (reject and reject(x, z)) then
				table.insert(out, { x = x, z = z, key = key } :: any)
			end
		end
	end
	return out
end

-- The spacing that fits about `count` cells into `area`, so a caller asks for a NUMBER OF TREES
-- (which is what the budget is written in) instead of for a spacing.
function Scatter.spacingFor(area: Area, count: number): number
	local span = (area.maxX - area.minX) * (area.maxZ - area.minZ)
	return math.sqrt(span / math.max(count, 1))
end

-- WHICH SPECIES STANDS HERE (design section 7.1). Pure, deterministic, and TWO rules rather than one:
--
--  1. a low-frequency noise field picks the band, so the wood comes in clumps a drive crosses --
--     dark blocks of spruce, light stands of birch -- instead of a species salad at every step;
--  2. WET GROUND FORCES ALDER, whatever the field says. Black alder is a wet-ground tree; a spruce
--     standing in a bog reads as a mistake to anyone who has walked a European wood.
--
-- `key` is the candidate's own drawn number, so two trees in one clump can still differ.
function Scatter.speciesAt(x: number, z: number, key: number, seed: number, config, groundY: number?): string
	local species = config.SPECIES
	if groundY ~= nil and groundY < config.SPECIES_WET_DEPTH then
		return "alder"
	end
	local frequency = config.SPECIES_FREQUENCY
	-- The same noise call shape the heightfield uses, with its own seed offset so the species field
	-- is not the ground's shape wearing a different name.
	local field = (math.noise(x * frequency, z * frequency, seed * 0.37 + 11.5) + 1) / 2
	field = math.clamp(field, 0, 0.999999)

	-- The field chooses a BAND of the share table, the key chooses inside it: a clump leans to one
	-- species without being a monoculture.
	local blended = math.clamp(field * 0.75 + key * 0.25, 0, 0.999999)
	local running = 0
	for _, row in ipairs(species) do
		running += row.share
		if blended < running then
			return row.name
		end
	end
	return species[#species].name
end

-- The candidates a WEIGHT accepts: `weight(x, z)` returns 0..1 and a candidate is kept when its own
-- drawn key is below it. Each cell draws all three numbers before any test, so a rejected cell never
-- shifts the draws of the cells after it -- the property `jitteredGrid` already protects, and the
-- reason the density can be a function of position without making the count depend on the order.
function Scatter.weighted(
	area: Area,
	spacing: number,
	jitter: number,
	rng: Random,
	weight: (number, number) -> number,
	reject: ((number, number) -> boolean)?
): { Point }
	local out: { Point } = {}
	local cols = math.max(1, math.floor((area.maxX - area.minX) / spacing))
	local rows = math.max(1, math.floor((area.maxZ - area.minZ) / spacing))
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local dx = (rng:NextNumber() - 0.5) * spacing * jitter
			local dz = (rng:NextNumber() - 0.5) * spacing * jitter
			local key = rng:NextNumber()
			local x = area.minX + (col + 0.5) * spacing + dx
			local z = area.minZ + (row + 0.5) * spacing + dz
			if not (reject and reject(x, z)) and key < weight(x, z) then
				table.insert(out, { x = x, z = z, key = key } :: any)
			end
		end
	end
	return out
end

-- The wood, one BLOCK at a time (design sections 7.2 and 7.3). The grid is fixed at TREE_SPACING and
-- the density decides what survives, so the wood is thick where the shooter looks and thin in the
-- backdrop -- and the count is a MEASUREMENT of the map rather than a number somebody asked for.
--
-- The block's own cells are the block's own draws: a block is a rectangle of the same global grid,
-- so which trees exist does not depend on how the work was cut into steps.
function Scatter.trees(config, seed: number, block, reject: ((number, number) -> boolean)?): { Point }
	local rng = Scatter.generator(seed + blockSeed(block), Scatter.LAYER.trees)
	local points = Scatter.weighted(block, config.TREE_SPACING, config.SCATTER_JITTER, rng, function(x, z)
		return Layout.treeDensity(x, z, config)
	end, reject)
	-- Placed in a stable spatial order, so `Tree007` is the same tree in two runs of the same seed and
	-- a digest diff names a position, not a shuffle.
	table.sort(points, function(a, b)
		if a.x ~= b.x then
			return a.x < b.x
		end
		return a.z < b.z
	end)
	return points
end

-- BRUSH: its own grid, its own layer, the wood only. Count-based, because brush is decoration and
-- Karen asked for a number of bushes rather than for a density.
function Scatter.brush(config, seed: number, block, reject: ((number, number) -> boolean)?): { Point }
	local rng = Scatter.generator(seed + blockSeed(block), Scatter.LAYER.brush)
	local perBlock = math.ceil(config.BRUSH.count / 4)
	local spacing = Scatter.spacingFor(block, math.ceil(perBlock * config.SCATTER_OVERSAMPLE))
	local candidates = Scatter.jitteredGrid(block, spacing, config.SCATTER_JITTER, rng, reject)
	for index, point in ipairs(candidates) do
		(point :: any).order = index
	end
	table.sort(candidates, function(a, b)
		local ka, kb = (a :: any).key, (b :: any).key
		if ka ~= kb then
			return ka < kb
		end
		return (a :: any).order < (b :: any).order
	end)
	local out: { Point } = {}
	for index = 1, math.min(perBlock, #candidates) do
		table.insert(out, { x = candidates[index].x, z = candidates[index].z })
	end
	table.sort(out, function(a, b)
		if a.x ~= b.x then
			return a.x < b.x
		end
		return a.z < b.z
	end)
	return out
end

return Scatter
