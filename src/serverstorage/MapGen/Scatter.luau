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
local Scatter = {}

export type Point = { x: number, z: number }
export type Area = { minX: number, maxX: number, minZ: number, maxZ: number }

-- Layer ids. Each layer's generator is Random.new(seed * 1000 + id), so adding a layer never moves
-- an existing layer's points.
Scatter.LAYER = table.freeze({ trees = 1, hedge = 2 })

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

-- The wood: `config.WORLD.treeCount` trees inside `treeArea`, none where `reject` says no -- which for
-- the drive means not in the corridor, not on a track, not in the bog and not in a hedge.
--
-- More cells are generated than trees are wanted, and the subset is chosen BY THE DRAWN KEY rather
-- than by taking the first N: the grid is walked row by row, so the first N would be a stripe along
-- one edge and not a wood.
function Scatter.trees(config, seed: number, reject: ((number, number) -> boolean)?): { Point }
	local world = config.WORLD
	local want = world.treeCount
	local rng = Scatter.generator(seed, Scatter.LAYER.trees)
	local spacing = Scatter.spacingFor(world.treeArea, math.ceil(want * config.SCATTER_OVERSAMPLE))
	local candidates = Scatter.jitteredGrid(world.treeArea, spacing, config.SCATTER_JITTER, rng, reject)
	for index, point in ipairs(candidates) do
		(point :: any).order = index -- a total order, so the sort cannot depend on table.sort's pivot
	end
	table.sort(candidates, function(a, b)
		local ka, kb = (a :: any).key, (b :: any).key
		if ka ~= kb then
			return ka < kb
		end
		return (a :: any).order < (b :: any).order
	end)
	local out: { Point } = {}
	for index = 1, math.min(want, #candidates) do
		local point = candidates[index]
		table.insert(out, { x = point.x, z = point.z }) -- the sort keys do not leave this module
	end
	-- Placed in a stable spatial order, so `Tree007` is the same tree in two runs of the same seed and
	-- a digest diff names a position, not a shuffle.
	table.sort(out, function(a, b)
		if a.x ~= b.x then
			return a.x < b.x
		end
		return a.z < b.z
	end)
	return out
end

return Scatter
