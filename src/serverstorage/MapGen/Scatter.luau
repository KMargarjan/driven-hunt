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
-- ONE NUMBER ANSWERS ONE QUESTION (Task 63, review round 1). The acceptance draw decides whether a
-- candidate becomes a tree and NOTHING else: it never leaves `weighted`, and the species question
-- draws its own number, from the point's position, through `Scatter.pointKey`. Re-using the
-- acceptance key for the species -- which this module did -- made the species depend on the DENSITY:
-- every candidate accepted where the weight is 0.42 (the drive) or 0.14 (the backdrop) has a key
-- below SPECIES_CLUMP_STRENGTH = 0.65, so `speciesAt` always returned the clump's leader there and
-- every clump outside the dense band was a pure monoculture over about half the wood. That is the
-- previous project's named killer -- "one predicate answered two unrelated questions"
-- (docs/PROJECT_CONTEXT.md) -- and the fix is a separate number per question, not a wider tolerance.
--
-- `Scatter.trees` requires Layout for the density weight; every other function takes what it needs as
-- an ARGUMENT (`weight`, `reject`, `rng`), so a server spec drives them directly with no Studio
-- (design section 2.2's last paragraph).
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
-- Which tree stands inside a clump comes from that tree's own `pointKey`, so two trees in one clump
-- can differ -- and NOT from the number that decided the tree exists at all.
local function pickByShare(species, u: number): string
	local running = 0
	for _, row in ipairs(species) do
		running += row.share
		if u < running then
			return row.name
		end
	end
	return species[#species].name
end

-- A FLAT HASH OF THREE INTEGERS, uniform in 0..1 and pure. The first build of the species choice used
-- `math.noise` and MEASURED 230 birch to 195 spruce to 3 oak in one quadrant, against Karen's
-- 0.25 / 0.40 / 0.20 -- because a noise field is bell-shaped around its middle, so the middle band of
-- a share table wins. A hash is flat, so the shares below are the shares she asked for. Measured with
-- this map's own inputs before it was used for a second question (Task 63): 200,000 points land
-- 10.03 / 9.97 / 9.99 / 9.96 / 10.00 / 10.05 / 9.98 / 10.00 / 10.01 / 10.01 per cent in the ten
-- deciles, and pickByShare over them returns 39.95 / 25.08 / 19.96 / 15.02 against 40 / 25 / 20 / 15.
local function hash01(a: number, b: number, c: number): number
	local h = (a * 374761393 + b * 668265263 + c * 2654435761) % 2147483647
	h = (h * 1274126177) % 2147483647
	return h / 2147483647
end

-- ONE STREAM PER PER-TREE QUESTION, the same rule as LAYER above and for the same reason: a number
-- drawn for one decision must not decide a second one. The CLUMP's number is `hash01(clumpX, clumpZ,
-- seed)` -- the clump's own coordinates, so every tree in a clump gets the same one -- and a TREE's
-- number comes from `pointKey`, which folds a stream id into the seed, so a later per-tree question
-- (a lean, a trunk size) can have its own number without moving the species.
Scatter.STREAM = table.freeze({ species = 1 })

-- THE POINT'S OWN NUMBER for one question, taken from WHERE IT IS rather than from when it was drawn.
-- Uniform in 0..1, pure, and independent of the acceptance draw -- which is the whole point: how thick
-- the wood is at a spot must not decide which tree stands there. The position enters at 1/16 of a
-- stud, and the closest two trunks anywhere in this map are over 11 studs apart (`map_contract.spec`
-- measures it over five seeds), so no two trees can share a key.
function Scatter.pointKey(x: number, z: number, seed: number, stream: number): number
	return hash01(math.floor(x * 16), math.floor(z * 16), seed * 31 + stream * 7919)
end

-- WHICH SPECIES LEADS THE CLUMP THIS POINT IS IN. Exposed because it is the answer to a question of
-- its own -- "which clump is this" -- and because a spec cannot measure the mix INSIDE a clump
-- without it (`map_contract.spec`, "the species mix does not depend on how thick the wood is").
function Scatter.clumpLeaderAt(x: number, z: number, seed: number, config): string
	-- The clump is a block of SPECIES_CLUMP_STUDS, its edges pushed about by the noise field so the
	-- wood does not read as a chessboard. The field decides WHERE the boundary is; the hash decides
	-- WHICH species the clump is, and that is what keeps the shares honest.
	local frequency = config.SPECIES_FREQUENCY
	local wobble = math.noise(x * frequency, z * frequency, seed * 0.37 + 11.5) * config.SPECIES_CLUMP_STUDS / 2
	local clump = config.SPECIES_CLUMP_STUDS
	local bx = math.floor((x + wobble) / clump)
	local bz = math.floor((z + wobble) / clump)
	return pickByShare(config.SPECIES, hash01(bx, bz, seed))
end

-- NO `key` PARAMETER, deliberately (Task 63, review round 1): the species question draws its own
-- number here, from the point's position, so no caller can hand it a number that was drawn to answer
-- something else. That is the whole of the fix -- the signature is what makes it stay fixed.
function Scatter.speciesAt(x: number, z: number, seed: number, config, groundY: number?): string
	local species = config.SPECIES
	-- WET GROUND IS ALDER, whatever the clump says: black alder is a wet-ground tree, and a spruce
	-- standing in a bog reads as a mistake to anyone who has walked a European wood.
	if groundY ~= nil and groundY < config.SPECIES_WET_DEPTH then
		return "alder"
	end

	local leader = Scatter.clumpLeaderAt(x, z, seed, config)

	-- Most of a clump is its leader; the rest is drawn from the same shares, so a stand of spruce
	-- has birch in it and the MARGINAL share of every species is still Karen's number.
	local key = Scatter.pointKey(x, z, seed, Scatter.STREAM.species)
	if key < config.SPECIES_CLUMP_STRENGTH then
		return leader
	end
	local u = (key - config.SPECIES_CLUMP_STRENGTH) / (1 - config.SPECIES_CLUMP_STRENGTH)
	return pickByShare(species, math.clamp(u, 0, 0.999999))
end

-- The candidates a WEIGHT accepts: `weight(x, z)` returns 0..1 and a candidate is kept when its own
-- drawn key is below it. Each cell draws all three numbers before any test, so a rejected cell never
-- shifts the draws of the cells after it -- the property `jitteredGrid` already protects, and the
-- reason the density can be a function of position without making the count depend on the order.
--
-- THE KEY DOES NOT LEAVE THIS FUNCTION (Task 63, review round 1). It answered "does this tree exist",
-- it was compared against the weight, and it is finished: a point is a POSITION. Storing it on the
-- point is how the species came to be decided by the density, so the only way to make that mistake
-- unrepeatable is for the number not to be there.
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
				table.insert(out, { x = x, z = z })
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
