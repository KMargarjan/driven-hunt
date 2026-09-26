--!strict
-- MapGen.Layout: WHERE EVERYTHING GOES, as plain tables of numbers, and PURE. No Instance, no
-- service, no Random, no Terrain. Every other module asks this one where a thing belongs, so the
-- shooter line exists in exactly one place in the repo.
--
-- Design: docs/design/map-generator.md (sections 2.2, 12)
local Layout = {}

export type Marker = { kind: string, name: string, x: number, z: number, size: Vector3, facing: number }

-- The tiles of the slice, in a fixed order, so step 4 is always the same 128 studs. Here rather than
-- in `Ground` because it is a fact about where things are, and a spec must be able to check the tiling
-- covers the slice without touching Terrain.
function Layout.tiles(config): { { tx: number, tz: number, minX: number, minZ: number } }
	local perSide = math.floor(config.SLICE_STUDS / config.TILE_STUDS)
	local half = config.SLICE_STUDS / 2
	local out = {}
	for tz = 0, perSide - 1 do
		for tx = 0, perSide - 1 do
			table.insert(out, {
				tx = tx,
				tz = tz,
				minX = -half + tx * config.TILE_STUDS,
				minZ = -half + tz * config.TILE_STUDS,
			})
		end
	end
	return out
end

-- Every spawn pad the heightfield must flatten: a marker a player or a boar stands on.
function Layout.pads(config): { { x: number, z: number } }
	local slice = config.SLICE
	local pads = {}
	for index = 1, slice.postCount do
		local x = (index - (slice.postCount + 1) / 2) * slice.postSpacing
		table.insert(pads, { x = x, z = slice.lineZ })
	end
	table.insert(pads, { x = 0, z = slice.driverStartZ })
	for _, x in ipairs(slice.boarSpawnX) do
		table.insert(pads, { x = x, z = slice.boarSpawnZ })
	end
	return pads
end

-- The five kinds of marker, in a stable order. `facing` is the yaw in radians the part is built
-- with: the DRIVE LINE is the one that matters, because its LookVector must point at +Z, toward the
-- drivers -- that is the meaning src/server/Weapon/SafetyArc.luau gives the field, and a line facing
-- the other way makes the safety rule fire on exactly the wrong shots.
function Layout.markers(config): { Marker }
	local slice = config.SLICE
	local out: { Marker } = {}
	for index = 1, slice.postCount do
		local x = (index - (slice.postCount + 1) / 2) * slice.postSpacing
		table.insert(out, {
			kind = "shooterPost",
			name = string.format("ShooterPost%d", index),
			x = x,
			z = slice.lineZ,
			size = Vector3.new(4, 6, 4),
			facing = 0,
		})
	end
	table.insert(out, {
		kind = "driveLine",
		name = "DriveLine",
		x = 0,
		z = slice.lineZ,
		size = slice.driveLineSize,
		facing = 0, -- CFrame.lookAt(at, at + +Z): the LookVector points at the drivers
	})
	table.insert(out, {
		kind = "driverStart",
		name = "DriverStart",
		x = 0,
		z = slice.driverStartZ,
		size = slice.driverStartSize,
		facing = 0,
	})
	for index, x in ipairs(slice.boarSpawnX) do
		table.insert(out, {
			kind = "boarSpawn",
			name = string.format("BoarSpawn%d", index),
			x = x,
			z = slice.boarSpawnZ,
			size = Vector3.new(6, 1, 6),
			facing = 0,
		})
	end
	return out
end

-- The hedgerow, as a polyline of segment centres, WITH A GATE cut out of it. One line for M2.1; a
-- network in M2.2.
--
-- `gate` is { x = centre } or nil, and it comes from Scatter (the seeded half of the decision lives
-- there, so this module stays free of Random). Every segment that would overlap the gate is left out,
-- which is what keeps the drive corridor walkable for an agent that cannot jump (design section 1.1
-- item 7; review round 2, finding 2).
function Layout.hedgerow(config, gate: { x: number }?): { { x: number, z: number } }
	local hedge = config.SLICE.hedgerow
	local out = {}
	local span = hedge.toX - hedge.fromX
	local count = math.max(1, math.floor(span / config.HEDGE.segmentStuds))
	local half = config.HEDGE.segmentStuds / 2
	local gateHalf = hedge.gateStuds / 2
	for index = 0, count do
		local x = hedge.fromX + index * config.HEDGE.segmentStuds
		-- Overlap, not centre distance: a segment is 12 studs wide, so one whose EDGE reaches into
		-- the gate would narrow it below the width the spec asserts.
		local blocksGate = gate ~= nil and math.abs(x - gate.x) < gateHalf + half
		if not blocksGate then
			table.insert(out, { x = x, z = hedge.z })
		end
	end
	return out
end

-- The clear span the hedgerow leaves, given its segment centres: the widest x-interval with no hedge
-- in it, as (from, to). A spec asserts this is at least `gateStuds` wide and inside the corridor --
-- the property the boar actually needs, measured from what was placed rather than from the intent.
function Layout.hedgeGap(points: { { x: number, z: number } }, config): (number, number)
	local half = config.HEDGE.segmentStuds / 2
	local xs = {}
	for _, point in ipairs(points) do
		table.insert(xs, point.x)
	end
	table.sort(xs)
	local bestFrom, bestTo = 0, 0
	for index = 1, #xs - 1 do
		local from, to = xs[index] + half, xs[index + 1] - half
		if to - from > bestTo - bestFrom then
			bestFrom, bestTo = from, to
		end
	end
	return bestFrom, bestTo
end

-- Is this point on the dirt track? Material only -- the track's height was already set by the
-- heightfield, so nothing here can disagree with Height about the ground.
function Layout.onTrack(x: number, z: number, config): boolean
	local slice = config.SLICE
	return math.abs(z - slice.trackZ) <= slice.trackHalfWidth and math.abs(x) <= config.SLICE_STUDS / 2
end

-- Is this point inside the drive corridor? Nothing is scattered here: a tree in the corridor is an
-- obstacle in the one place the drive needs to be open.
function Layout.inCorridor(x: number, z: number, config): boolean
	local c = config.SLICE.corridor
	return x >= c.minX and x <= c.maxX and z >= c.minZ and z <= c.maxZ
end

-- The twelve trunks nearest the shooter line, which are the ones tagged DrivenHunt.Tree: a player
-- tied to a spruce 900 studs away is a teleport, not a penalty (design section 4.3).
function Layout.tieTrees(trees: { { x: number, z: number } }, config): { number }
	local order = {}
	for index, tree in ipairs(trees) do
		table.insert(order, { index = index, d = math.abs(tree.z - config.SLICE.lineZ) })
	end
	table.sort(order, function(a, b)
		if a.d ~= b.d then
			return a.d < b.d
		end
		return a.index < b.index -- a total order, so the same seed picks the same twelve
	end)
	local out = {}
	for index = 1, math.min(config.SLICE.tieTrees, #order) do
		table.insert(out, order[index].index)
	end
	table.sort(out)
	return out
end

return Layout
