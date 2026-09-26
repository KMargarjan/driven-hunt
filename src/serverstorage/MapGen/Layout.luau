--!strict
-- MapGen.Layout: WHERE EVERYTHING GOES, as plain tables of numbers, and PURE. No Instance, no
-- service, no Random, no Terrain. Every other module asks this one where a thing belongs, so the
-- shooter line exists in exactly one place in the repo.
--
-- The seeded half of a decision (which x a gate sits at, where a tree lands) lives in `Scatter` and
-- arrives here as an argument, so this file stays a function of the configuration alone.
--
-- Design: docs/design/map-generator.md (sections 2.2, 12)
local Layout = {}

-- No `facing`: every marker had one, always 0, and nothing read it. `Markers.place` builds every
-- CFrame with an explicit `CFrame.lookAt(position, position + Vector3.zAxis)`, which is the fact the
-- drive line depends on, and a second unread way of saying the same thing is the kind of duplicate
-- rule 3 exists to stop (review round 1 of Task 44).
export type Marker = { kind: string, name: string, x: number, z: number, size: Vector3 }
export type Point = { x: number, z: number }
export type Line = { axis: string, at: number, from: number, to: number, crossesCorridor: boolean }

-- The tiles of the map, in a fixed order, so step 4 is always the same 128 studs. Here rather than in
-- `Ground` because it is a fact about where things are, and a spec must be able to check the tiling
-- covers the map without touching Terrain.
function Layout.tiles(config): { { tx: number, tz: number, minX: number, minZ: number } }
	local perSide = math.floor(config.SIZE_STUDS / config.TILE_STUDS)
	local half = config.SIZE_STUDS / 2
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
function Layout.pads(config): { Point }
	local world = config.WORLD
	local pads = {}
	for index = 1, world.postCount do
		local x = (index - (world.postCount + 1) / 2) * world.postSpacing
		table.insert(pads, { x = x, z = world.lineZ })
	end
	table.insert(pads, { x = 0, z = world.driverStartZ })
	for _, x in ipairs(world.boarSpawnX) do
		table.insert(pads, { x = x, z = world.boarSpawnZ })
	end
	return pads
end

-- The five kinds of marker, in a stable order. Position and size only: how a marker FACES is decided
-- once, in `Markers.place`, with an explicit `CFrame.lookAt` toward +Z. That matters most for the
-- DRIVE LINE, whose LookVector must point at the drivers -- the meaning src/server/Weapon/SafetyArc.luau
-- gives it, where the other way round makes the safety rule fire on exactly the wrong shots.
function Layout.markers(config): { Marker }
	local world = config.WORLD
	local out: { Marker } = {}
	for index = 1, world.postCount do
		local x = (index - (world.postCount + 1) / 2) * world.postSpacing
		table.insert(out, {
			kind = "shooterPost",
			name = string.format("ShooterPost%d", index),
			x = x,
			z = world.lineZ,
			size = Vector3.new(4, 6, 4),
		})
	end
	table.insert(out, {
		kind = "driveLine",
		name = "DriveLine",
		x = 0,
		z = world.lineZ,
		size = world.driveLineSize, -- CFrame.lookAt(at, at + +Z): the LookVector points at the drivers
	})
	table.insert(out, {
		kind = "driverStart",
		name = "DriverStart",
		x = 0,
		z = world.driverStartZ,
		size = world.driverStartSize,
	})
	for index, x in ipairs(world.boarSpawnX) do
		table.insert(out, {
			kind = "boarSpawn",
			name = string.format("BoarSpawn%d", index),
			x = x,
			z = world.boarSpawnZ,
			size = Vector3.new(6, 1, 6),
		})
	end
	return out
end

-- The twelve tie trees, PLACED rather than chosen: evenly along the post span, 45 studs behind the
-- line, so a punished shooter is tied within sight of where they stood (design section 4.3) and
-- nothing stands between a shooter and the drive.
function Layout.tieTreePoints(config): { Point }
	local world = config.WORLD
	local out: { Point } = {}
	for index = 1, world.tieTrees do
		local t = if world.tieTrees == 1 then 0.5 else (index - 1) / (world.tieTrees - 1)
		table.insert(out, { x = -world.tieTreeSpan / 2 + t * world.tieTreeSpan, z = world.tieTreeZ })
	end
	return out
end

-- ---------------------------------------------------------------- the hedgerow network

-- The field boundaries, as lines. `axis = "x"` runs ALONG x at a constant z; `axis = "z"` runs along
-- z at a constant x. A line that crosses the drive corridor is marked, because that is the one that
-- must be gated or the drive stops at it.
function Layout.hedgeLines(config): { Line }
	local world = config.WORLD
	local span = world.hedgeHalfSpan
	local corridor = world.corridor
	local out: { Line } = {}
	for _, z in ipairs(world.hedgeZ) do
		table.insert(out, {
			axis = "x",
			at = z,
			from = -span,
			to = span,
			crossesCorridor = z >= corridor.minZ and z <= corridor.maxZ,
		})
	end
	for _, x in ipairs(world.hedgeX) do
		table.insert(out, {
			axis = "z",
			at = x,
			from = -span,
			to = span,
			crossesCorridor = x >= corridor.minX and x <= corridor.maxX,
		})
	end
	return out
end

-- The stretch of a line that lies inside the corridor, as (from, to) along the line's own axis, or
-- nil when it never enters it. This is where a gate has to be: a gate outside the corridor is a gate
-- the drive never reaches.
function Layout.corridorSpan(line: Line, config): (number?, number?)
	if not line.crossesCorridor then
		return nil, nil
	end
	local corridor = config.WORLD.corridor
	local low = if line.axis == "x" then corridor.minX else corridor.minZ
	local high = if line.axis == "x" then corridor.maxX else corridor.maxZ
	local from, to = math.max(line.from, low), math.min(line.to, high)
	if to <= from then
		return nil, nil
	end
	return from, to
end

-- One hedgerow line, as segment centres, with the gates cut out of it. `gates` is a list of centres
-- along the line's own axis and comes from Scatter, so this module stays free of Random.
--
-- A segment is dropped when its EDGE would reach into a gate, not merely its centre: a 24-stud
-- segment whose centre clears the gate can still narrow it below the width the spec asserts.
function Layout.hedgeSegments(line: Line, gates: { number }, config): { Point }
	local half = config.HEDGE.segmentStuds / 2
	local gateHalf = config.WORLD.gateStuds / 2
	local out: { Point } = {}
	local count = math.max(1, math.floor((line.to - line.from) / config.HEDGE.segmentStuds))
	for index = 0, count do
		local along = line.from + index * config.HEDGE.segmentStuds
		local blocked = false
		for _, gate in ipairs(gates) do
			if math.abs(along - gate) < gateHalf + half then
				blocked = true
				break
			end
		end
		if not blocked then
			if line.axis == "x" then
				table.insert(out, { x = along, z = line.at })
			else
				table.insert(out, { x = line.at, z = along })
			end
		end
	end
	return out
end

-- The widest clear stretch a line's placed segments leave inside a given span: the property a boar
-- actually needs, measured from what was placed rather than from the intent.
function Layout.widestGap(points: { Point }, line: Line, from: number, to: number, config): (number, number)
	local half = config.HEDGE.segmentStuds / 2
	local alongs = { from - half }
	for _, point in ipairs(points) do
		local along = if line.axis == "x" then point.x else point.z
		if along >= from - config.HEDGE.segmentStuds and along <= to + config.HEDGE.segmentStuds then
			table.insert(alongs, along)
		end
	end
	table.insert(alongs, to + half)
	table.sort(alongs)
	local bestFrom, bestTo = 0, 0
	for index = 1, #alongs - 1 do
		local gapFrom, gapTo = alongs[index] + half, alongs[index + 1] - half
		if gapTo - gapFrom > bestTo - bestFrom then
			bestFrom, bestTo = gapFrom, gapTo
		end
	end
	return bestFrom, bestTo
end

-- How close a point is to any hedgerow line, so the scatter can keep trees out of the hedges.
function Layout.distanceToHedge(x: number, z: number, config): number
	local best = math.huge
	for _, line in ipairs(Layout.hedgeLines(config)) do
		local along = if line.axis == "x" then x else z
		if along >= line.from and along <= line.to then
			local across = if line.axis == "x" then z else x
			best = math.min(best, math.abs(across - line.at))
		end
	end
	return best
end

-- ---------------------------------------------------------------- tracks, bog, corridor

-- Is this point on a dirt track? Material only -- the track's height was already set by the
-- heightfield, so nothing here can disagree with Height about the ground.
function Layout.onTrack(x: number, z: number, config): boolean
	for _, track in ipairs(config.WORLD.tracks) do
		local across = if track.axis == "x" then z else x
		if math.abs(across - track.at) <= track.halfWidth then
			return true
		end
	end
	return false
end

-- How far into the bog a point is, 0 outside it and 1 at its centre, eased. Both the heightfield (a
-- shallow depression) and the material ask this one function, so the mud and the dip cannot disagree.
function Layout.bogDepth(x: number, z: number, config): number
	local bog = config.WORLD.bog
	local d = math.sqrt((x - bog.x) ^ 2 + (z - bog.z) ^ 2)
	if d >= bog.radius then
		return 0
	end
	local t = 1 - d / bog.radius
	return t * t * (3 - 2 * t)
end

-- Is this point inside the drive corridor? Nothing is scattered here: a tree in the corridor is an
-- obstacle in the one place the drive needs to be open.
function Layout.inCorridor(x: number, z: number, config): boolean
	local c = config.WORLD.corridor
	return x >= c.minX and x <= c.maxX and z >= c.minZ and z <= c.maxZ
end

return Layout
