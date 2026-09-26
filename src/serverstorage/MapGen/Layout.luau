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
-- FOUR PADS, not thirteen (design section 6.4). The eight post pads and the driver-start rectangle
-- are gone: the posts and the driver start now stand on BENCHES, which are flat at GROUND_Y anyway.
--
-- That closes TASKS.md row 45a(d) by construction. At blend 40 the old post pads (radius 10 + blend
-- 40 = 54 against a spacing of 80) merged into one flattened strip along the line -- an artefact
-- nobody chose. There is now a road there deliberately, and the strip IS the feature.
function Layout.pads(config): { Point }
	local world = config.WORLD
	local pads = {}
	for _, x in ipairs(world.boarSpawnX) do
		table.insert(pads, { x = x, z = world.boarSpawnZ })
	end
	return pads
end

-- The benches, as data, so Height, Ground and the specs all read one list (design section 6.3).
function Layout.benches(config)
	return config.WORLD.benches
end

-- True on the gravel of a bench -- not its verge. Ground paints the road material here, and the
-- contract spec asserts the posts stand on it.
function Layout.onRoad(x: number, z: number, config): boolean
	for _, bench in ipairs(config.WORLD.benches) do
		local along, across
		if bench.axis == "x" then
			along, across = x, math.abs(z - bench.at)
		else
			along, across = z, math.abs(x - bench.at)
		end
		if across <= bench.halfWidth and along >= bench.from and along <= bench.to then
			return true
		end
	end
	return false
end

-- TRUE ANYWHERE A BENCH OWNS THE GROUND -- the gravel AND its verge, plus `pad` studs of clearance.
--
-- ROUND 2, FINDING 1, and it is the CLASS rather than the instance. A hedge line at x = +/-760 runs
-- the full depth of the map, the corridor stops at +/-620, so `crossesCorridor` was false, so no gate
-- was cut -- and two collidable 7-stud hedge segments stood across the forest road at each end. The
-- road is 1,800 studs long and the corridor only 1,240, so "is it in the corridor" was never the
-- right question for a bench. Anything that PLACES something asks this instead: `hedgeSegments` skips
-- a segment, `rejectTree` rejects a point, and `map_contract.spec` walks the whole road proving
-- nothing collidable stands on it.
function Layout.onBench(x: number, z: number, config, pad: number?): boolean
	local clearance = pad or 0
	for _, bench in ipairs(config.WORLD.benches) do
		local along, across
		if bench.axis == "x" then
			along, across = x, math.abs(z - bench.at)
		else
			along, across = z, math.abs(x - bench.at)
		end
		local width = bench.halfWidth + bench.verge + clearance
		-- The taper counts: the bench still owns the ground where it runs out.
		if across <= width and along >= bench.from - bench.taper and along <= bench.to + bench.taper then
			return true
		end
	end
	return false
end

-- The flank farmland: outside it, and off the benches, the ground is forest floor. This is what turns
-- "wood everywhere" into "a wood with fields at its edges", which is what Karen's references show.
function Layout.inField(x: number, z: number, config): boolean
	local f = config.WORLD.fields
	return math.abs(x) >= f.innerX and math.abs(x) <= f.outerX and z >= f.minZ and z <= f.maxZ
end

-- HOW THICK THE WOOD IS HERE, as a weight in 0..1 (design section 7.2). A candidate tree is
-- accepted when its own drawn key is below this, which makes the density a property of WHERE rather
-- than of how many cells were rejected before it.
--
-- Three tiers and a zero, and the zero is what used to be the whole rule: until M2.8b nothing could
-- stand inside the drive corridor at all, so the drive was a bare lane through a decorated backdrop.
-- The corridor is the wood now; what stays clear is the ground the game stands things on.
function Layout.treeDensity(x: number, z: number, config): number
	if Layout.inField(x, z, config) then
		return 0 -- a field is a field
	end
	if Layout.onBench(x, z, config) or Layout.onTrack(x, z, config) then
		return 0
	end
	if Layout.bogDepth(x, z, config) > 0 then
		return 0 -- alder stands AROUND a bog, not in it
	end
	if Layout.distanceToHedge(x, z, config) < config.SCATTER_CLEARANCE then
		return 0
	end
	-- A PAD'S SIZE IS THE CONTRACT'S, not the pad list's: `Layout.pads` is four positions, and how
	-- wide the flat ground around one is belongs to Map.SPAWN_PAD (Config.SPAWN_PAD reads it).
	local clear = config.SPAWN_PAD.radius + config.SPAWN_PAD.blend
	for _, pad in ipairs(Layout.pads(config)) do
		if (Vector3.new(x, 0, z) - Vector3.new(pad.x, 0, pad.z)).Magnitude <= clear then
			return 0 -- a boar is released onto flat, clear ground
		end
	end
	-- A HIGH SEAT STANDS IN ITS OWN CLEARING (M2.8c). It sits 40 studs behind the road, which is
	-- inside the DENSE band, so without this a 15-stud tower would be built inside a spruce -- and
	-- the answer "look at the screenshot" is only useful if the thing is not inside a tree.
	local seatClear = config.FURNITURE.highSeat.clearRadius
	for _, seat in ipairs(Layout.highSeats(config)) do
		if (Vector3.new(x, 0, z) - Vector3.new(seat.x, 0, seat.z)).Magnitude <= seatClear then
			return 0
		end
	end

	local density = config.TREE_DENSITY
	if math.abs(z - config.WORLD.lineZ) <= density.denseBandStuds and math.abs(x) <= density.denseHalfWidth then
		return density.dense -- the band the shooter actually looks into
	end
	if Layout.inCorridor(x, z, config) then
		return density.drive
	end
	return density.backdrop
end

-- THE WOOD IS BUILT IN BLOCKS, because one step that creates ~3,000 Models is one step that can time
-- out and tells you nothing about where it was when it did. Four quadrants of the tree area, in a
-- fixed order, each its own step in the plan and its own line in the run log.
function Layout.treeBlocks(config): { { name: string, minX: number, maxX: number, minZ: number, maxZ: number } }
	local area = config.WORLD.treeArea
	local midX = (area.minX + area.maxX) / 2
	local midZ = (area.minZ + area.maxZ) / 2
	return {
		{ name = "west-far", minX = area.minX, maxX = midX, minZ = midZ, maxZ = area.maxZ },
		{ name = "east-far", minX = midX, maxX = area.maxX, minZ = midZ, maxZ = area.maxZ },
		{ name = "west-near", minX = area.minX, maxX = midX, minZ = area.minZ, maxZ = midZ },
		{ name = "east-near", minX = midX, maxX = area.maxX, minZ = area.minZ, maxZ = midZ },
	}
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
			-- (6, 1, 6) AT GROUND_Y + 0.5, not (4, 6, 4). Body.placementFor stands a character at
			-- post.Position + (0, post.Size.Y/2 + STAND_HEIGHT_STUDS, 0), so a 6-stud-tall marker put
			-- the stand point 9.5 studs over a part that does not collide -- the drop named in
			-- TASKS.md row 43a(l) and audit-004 F9. A 1-stud marker makes it ground + 4.5, and the
			-- bottom face sits exactly on the road bench, which is the one number the contract checks.
			size = Vector3.new(6, 1, 6),
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

-- ---------------------------------------------------------------- the road's furniture (M2.8c)

export type Piece = {
	kind: string, -- what it is, for the counts and for a spec to group by
	name: string, -- unique inside the Furniture folder
	x: number,
	z: number,
	size: Vector3,
	base: number, -- the bottom face, in studs above the ground at (anchorX, anchorZ)
	anchorX: number, -- where the GROUND is sampled: one height per object, so a high seat's four
	anchorZ: number, -- legs and its platform stand on one plane instead of following the terrain
	color: Color3,
	material: Enum.Material,
}

-- WHERE THE FOUR HIGH SEATS STAND. Its own function because `Layout.treeDensity` needs it for every
-- candidate in the wood and must not build the whole furniture list to find out.
function Layout.highSeats(config): { Point }
	local world, seat = config.WORLD, config.FURNITURE.highSeat
	local out: { Point } = {}
	for _, index in ipairs(seat.atPosts) do
		local x = (index - (world.postCount + 1) / 2) * world.postSpacing
		table.insert(out, { x = x, z = world.lineZ + seat.offsetZ })
	end
	return out
end

-- EVERY PIECE OF FURNITURE, AS DATA (design 18, the M2.8c row). Pure, so a spec can assert what the
-- road carries without building a map, and so `Props.furniture` decides nothing -- it is handed a
-- list and it builds it, the same division `Props.hedge` already has.
--
-- DETERMINISTIC WITHOUT A SEED. The reeds' jitter is modular arithmetic on the clump index rather
-- than a draw, because the one flat hash in this project lives in `Scatter`, `Scatter` requires
-- `Layout`, and a second require the other way is a cycle. Scenery on a bog rim does not need a
-- statistically good hash; it needs to be the same every build, and this is.
function Layout.furniture(config): { Piece }
	local world = config.WORLD
	local f = config.FURNITURE
	local out: { Piece } = {}
	local function add(piece: Piece)
		table.insert(out, piece)
	end

	-- 1. TWO STAKES PER STAND, and the orange cap on top of each (row 58a(a): the posts have to be
	-- visible from the road, and every tagged marker is Transparency = 1 by design).
	for index = 1, world.postCount do
		local postX = (index - (world.postCount + 1) / 2) * world.postSpacing
		local z = world.lineZ + f.stake.offsetZ
		for _, side in ipairs({ -1, 1 }) do
			local x = postX + side * f.stake.offsetX
			local suffix = if side < 0 then "L" else "R"
			add({
				kind = "stake",
				name = string.format("Stake%d%s", index, suffix),
				x = x,
				z = z,
				size = f.stake.size,
				base = 0,
				anchorX = x,
				anchorZ = z,
				color = f.stake.color,
				material = Enum.Material.Wood,
			})
			add({
				kind = "stakeCap",
				name = string.format("Stake%d%sCap", index, suffix),
				x = x,
				z = z,
				size = f.stake.capSize,
				base = f.stake.size.Y,
				anchorX = x,
				anchorZ = z,
				color = f.stake.capColor,
				material = Enum.Material.SmoothPlastic,
			})
		end
	end

	-- 2. FOUR HIGH SEATS: four legs, a deck, a rail across the back and a roof. Scenery: nobody
	-- stands on it in v1, and nothing here is collidable.
	for seatIndex, seat in ipairs(Layout.highSeats(config)) do
		local half = f.highSeat.legSpan / 2
		local legTop = f.highSeat.legSize.Y
		for legIndex, corner in ipairs({
			{ dx = -half, dz = -half },
			{ dx = half, dz = -half },
			{ dx = -half, dz = half },
			{ dx = half, dz = half },
		}) do
			add({
				kind = "highSeatLeg",
				name = string.format("HighSeat%dLeg%d", seatIndex, legIndex),
				x = seat.x + corner.dx,
				z = seat.z + corner.dz,
				size = f.highSeat.legSize,
				base = 0,
				anchorX = seat.x,
				anchorZ = seat.z,
				color = f.highSeat.color,
				material = Enum.Material.Wood,
			})
		end
		add({
			kind = "highSeatDeck",
			name = string.format("HighSeat%dDeck", seatIndex),
			x = seat.x,
			z = seat.z,
			size = f.highSeat.platform,
			base = legTop,
			anchorX = seat.x,
			anchorZ = seat.z,
			color = f.highSeat.deckColor,
			material = Enum.Material.WoodPlanks,
		})
		add({
			kind = "highSeatRail",
			name = string.format("HighSeat%dRail", seatIndex),
			x = seat.x,
			-- The rail is across the DRIVE side, so the seat reads as facing the wood it watches.
			z = seat.z + f.highSeat.platform.Z / 2,
			size = f.highSeat.rail,
			base = legTop + f.highSeat.platform.Y,
			anchorX = seat.x,
			anchorZ = seat.z,
			color = f.highSeat.color,
			material = Enum.Material.Wood,
		})
		add({
			kind = "highSeatRoof",
			name = string.format("HighSeat%dRoof", seatIndex),
			x = seat.x,
			z = seat.z,
			size = f.highSeat.roof,
			base = legTop + f.highSeat.platform.Y + f.highSeat.rail.Y,
			anchorX = seat.x,
			anchorZ = seat.z,
			color = f.highSeat.color,
			material = Enum.Material.WoodPlanks,
		})
	end

	-- 3. A BARRIER ACROSS EACH END OF THE ROAD: two uprights and a boom, on the flat bench inside
	-- the road's own ends, so it stands on gravel rather than among trunks.
	local road = Layout.benches(config)[1]
	for endIndex, endX in ipairs({ road.from + f.barrier.inset, road.to - f.barrier.inset }) do
		for _, side in ipairs({ -1, 1 }) do
			add({
				kind = "barrierPost",
				name = string.format("Barrier%dPost%s", endIndex, if side < 0 then "L" else "R"),
				x = endX,
				z = world.lineZ + side * f.barrier.postOffsetZ,
				size = f.barrier.post,
				base = 0,
				anchorX = endX,
				anchorZ = world.lineZ,
				color = f.barrier.color,
				material = Enum.Material.Metal,
			})
		end
		add({
			kind = "barrierBoom",
			name = string.format("Barrier%dBoom", endIndex),
			x = endX,
			z = world.lineZ,
			size = f.barrier.boom,
			base = f.barrier.boomBase,
			anchorX = endX,
			anchorZ = world.lineZ,
			color = f.barrier.bandColor,
			material = Enum.Material.SmoothPlastic,
		})
	end

	-- 4. TWO LOG PILES ON THE VERGE, stacked 3 + 2, their long axis along the road.
	for pileIndex, pile in ipairs(f.logPile.at) do
		local z = world.lineZ + pile.side * f.logPile.offsetZ
		local log = f.logPile.log
		-- 3 + 2 + 1, the way a forester stacks them, and 6.6 studs tall so it reads from the road.
		local rows = { { -log.Z, 0, log.Z }, { -log.Z / 2, log.Z / 2 }, { 0 } }
		local logIndex = 0
		for row, offsets in ipairs(rows) do
			for _, dz in ipairs(offsets) do
				logIndex += 1
				add({
					kind = "log",
					name = string.format("LogPile%d_%d", pileIndex, logIndex),
					x = pile.x,
					z = z + dz,
					size = log,
					base = (row - 1) * log.Y,
					anchorX = pile.x,
					anchorZ = z,
					color = if row == 1 then f.logPile.color else f.logPile.endColor,
					material = Enum.Material.Wood,
				})
			end
		end
	end

	-- 5. A FENCE ALONG A FIELD BOUNDARY, WITH A GATE where the farm track passes through it. The
	-- gate stands OPEN, swung back on its hinge post along +z, because a closed gate across the
	-- track would say the track goes nowhere.
	local fence = f.fence
	local x = fence.fromX
	while x <= fence.toX + 1e-6 do
		if not (x > fence.gateFromX and x < fence.gateToX) then
			add({
				kind = "fencePost",
				name = string.format("FencePost%d", math.floor((x - fence.fromX) / fence.spacing) + 1),
				x = x,
				z = fence.z,
				size = fence.post,
				base = 0,
				anchorX = x,
				anchorZ = fence.z,
				color = fence.color,
				material = Enum.Material.Wood,
			})
		end
		x += fence.spacing
	end
	local span = fence.fromX
	local railIndex = 0
	while span + fence.spacing <= fence.toX + 1e-6 do
		local middle = span + fence.spacing / 2
		if not (middle > fence.gateFromX and middle < fence.gateToX) then
			for heightIndex, height in ipairs(fence.railHeights) do
				railIndex += 1
				add({
					kind = "fenceRail",
					name = string.format("FenceRail%d_%d", railIndex, heightIndex),
					x = middle,
					z = fence.z,
					size = fence.rail,
					base = height - fence.rail.Y / 2,
					anchorX = middle,
					anchorZ = fence.z,
					color = fence.color,
					material = Enum.Material.Wood,
				})
			end
		end
		span += fence.spacing
	end
	add({
		kind = "gate",
		name = "FieldGate",
		x = fence.gateFromX + 1,
		z = fence.z + fence.gate.Z / 2,
		size = fence.gate,
		base = 0.4,
		anchorX = fence.gateFromX,
		anchorZ = fence.z,
		color = fence.gateColor,
		material = Enum.Material.Wood,
	})

	-- 6. REEDS ON THE BOG'S RIM.
	local bog, reeds = world.bog, f.reeds
	for index = 1, reeds.count do
		local angle = (index - 1) / reeds.count * math.pi * 2
		-- Deterministic, and it is arithmetic rather than a draw: see the note above the function.
		local wobble = ((index * 37) % (reeds.jitter * 2 + 1)) - reeds.jitter
		local radius = bog.radius - reeds.inset + wobble
		local rx = bog.x + math.cos(angle) * radius
		local rz = bog.z + math.sin(angle) * radius
		add({
			kind = "reed",
			name = string.format("Reeds%02d", index),
			x = rx,
			z = rz,
			size = reeds.size,
			base = -reeds.sink,
			anchorX = rx,
			anchorZ = rz,
			color = reeds.color,
			material = Enum.Material.Grass,
		})
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
		local x, z
		if line.axis == "x" then
			x, z = along, line.at
		else
			x, z = line.at, along
		end
		-- A BENCH IS A GATE NOBODY HAS TO CUT (round 2, finding 1). A hedge segment on the road is a
		-- collidable wall across the one strip the whole revision exists to keep open; half a
		-- segment's length of clearance keeps the part itself off the verge, not just its centre.
		if Layout.onBench(x, z, config, config.HEDGE.segmentStuds / 2) then
			blocked = true
		end
		if not blocked then
			table.insert(out, { x = x, z = z })
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
