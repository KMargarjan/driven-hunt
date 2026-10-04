--!strict
-- MapGen.Layout: WHERE EVERYTHING GOES, as plain tables of numbers, and PURE. No Instance, no
-- service, no Random, no Terrain. Every other module asks this one where a thing belongs, so the
-- shooter line exists in exactly one place in the repo.
--
-- The seeded half of a decision (which x a gate sits at, where a tree lands, where a patch centre
-- is) lives in `Scatter` and arrives here as an ARGUMENT, so this file stays a function of the
-- configuration alone. That is why `treeDensity` takes the patch list and `visibleLoad` takes the
-- planted trees rather than computing them: `Scatter` requires `Layout`, so the other direction
-- would be a cycle, and composing them is `MapGen`'s job.
--
-- Design: docs/design/map-generator.md, "Roads, blocks and the ground" and "The mix model"
local Height = require(script.Parent:WaitForChild("Height"))

local Layout = {}

-- No `facing`: every marker had one, always 0, and nothing read it. `Markers.place` builds every
-- CFrame with an explicit `CFrame.lookAt(position, position + Vector3.zAxis)`, which is the fact the
-- drive line depends on, and a second unread way of saying the same thing is the kind of duplicate
-- rule 3 exists to stop (review round 1 of Task 44).
export type Marker = { kind: string, name: string, x: number, z: number, y: number, size: Vector3 }
export type Point = { x: number, z: number }
export type Line = { axis: string, at: number, from: number, to: number, crossesCorridor: boolean }
export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Tile = { tx: number, tz: number, minX: number, minZ: number, pass: string, minY: number, maxY: number }

-- ---------------------------------------------------------------- blocks and roads

-- The four block rectangles, in `BLOCK_ORDER`, each with the name it is known by. Frozen data
-- assembled once in `Config`, not rebuilt here: `treeDensity` calls this twice per candidate tree,
-- which was about 80,000 throwaway tables per build.
function Layout.blocks(config)
	return config.BLOCK_LIST
end

local function inRect(x: number, z: number, r: Rect): boolean
	return x >= r.minX and x <= r.maxX and z >= r.minZ and z <= r.maxZ
end

-- The block a point is in, or nil. Blocks are disjoint (a spec asserts it), so "the" block is well
-- defined and the first match is the only match.
function Layout.blockAt(x: number, z: number, config)
	for _, block in ipairs(Layout.blocks(config)) do
		if inRect(x, z, block.bounds) then
			return block
		end
	end
	return nil
end

-- THE BLOCK THE DRIVE RUNS IN, the one `Map.ACTIVE_BLOCK` names -- read through the contract and
-- never copied, the same rule `Config.SPAWN_PAD = Map.SPAWN_PAD` already follows.
function Layout.activeBlock(config)
	for _, block in ipairs(Layout.blocks(config)) do
		if block.name == config.ACTIVE_BLOCK then
			return block
		end
	end
	error("Map.ACTIVE_BLOCK names no block in Config.BLOCKS: " .. tostring(config.ACTIVE_BLOCK), 0)
end

-- The roads, as data, so Height, Ground and the specs all read one list in one order.
function Layout.roads(config)
	return config.BENCHES
end

-- The road the active block's shooter line stands on.
function Layout.activeRoad(config)
	local block = Layout.activeBlock(config)
	for _, road in ipairs(Layout.roads(config)) do
		if road.name == block.road then
			return road
		end
	end
	error("block " .. block.name .. " names no road in Map.ROADS: " .. tostring(block.road), 0)
end

-- The z of the active block's shooter line: its road's centreline. There is no second concept.
function Layout.lineZ(config): number
	return Layout.activeRoad(config).at
end

local function alongAcross(x: number, z: number, road): (number, number)
	if road.axis == "x" then
		return x, math.abs(z - road.at)
	end
	return z, math.abs(x - road.at)
end

-- True on the GRAVEL of a road -- not its verge. `Ground` paints the road material here.
function Layout.onRoad(x: number, z: number, config): boolean
	for _, road in ipairs(Layout.roads(config)) do
		local along, across = alongAcross(x, z, road)
		if across <= road.halfWidth and along >= road.from and along <= road.to then
			return true
		end
	end
	return false
end

-- TRUE WHERE NOTHING COLLIDABLE MAY STAND: the gravel plus `keepClear`, over the road's whole
-- length including its taper. THE ONE PREDICATE, and that is the point of it existing (design,
-- "`keepClear` is not `verge`").
--
-- v3 used `onBench` -- the gravel PLUS THE WHOLE VERGE -- which cleared 62 studs (17 m) down every
-- ride: a firebreak, not a forest road. `keepClear = 4` makes a ride 22 studs (6.2 m) of cleared
-- corridor, inside the brief's 4.5-7 m, with trunks standing on the eased verge and crowns
-- overhanging the gravel, which is what a European forest road looks like.
--
-- `Layout.treeDensity`, `Props.rejectTree`, `MapGen.verifyContract` and `map_contract.spec` all call
-- THIS, so none of them can disagree about where the gravel is. `extra` is a caller's own clearance
-- (half a hedge segment's length, say), so a PART's edge is kept out and not merely its centre.
function Layout.onRoadKeepClear(x: number, z: number, config, extra: number?): boolean
	local clearance = extra or 0
	for _, road in ipairs(Layout.roads(config)) do
		local along, across = alongAcross(x, z, road)
		local width = road.halfWidth + road.keepClear + clearance
		if across <= width and along >= road.from - road.taper and along <= road.to + road.taper then
			return true
		end
	end
	return false
end

-- TRUE ANYWHERE A ROAD OWNS THE GROUND -- the gravel AND its verge, plus `pad` studs. This is the
-- TERRAIN question ("has the heightfield been eased here"), which is a wider band than the
-- collision question above; keeping the two apart is this revision's point.
function Layout.onBench(x: number, z: number, config, pad: number?): boolean
	local clearance = pad or 0
	for _, road in ipairs(Layout.roads(config)) do
		local along, across = alongAcross(x, z, road)
		local width = road.halfWidth + road.verge + clearance
		if across <= width and along >= road.from - road.taper and along <= road.to + road.taper then
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------- the tiles, in two band passes

-- The tiles of the map, in a fixed order, ONE ENTRY PER (TILE, BAND PASS).
--
-- The band is 168 studs and the measured `WriteVoxels` region is 96, so each tile is written in a
-- LOWER pass ([min, mid], exactly 96 studs) and, where it is needed, an UPPER pass ([mid, max]).
--
-- THE UPPER PASS IS OMITTED WHERE NO COLUMN CAN REACH IT, AND THE TEST IS ANALYTIC RATHER THAN
-- SAMPLED. `Height.at` is `max(shaped, edgeFloor)`; `shaped` is bounded by RELIEF (64, and measured
-- at ~37), which is under `mid`; so only the rim can put ground above `mid`, and `Height.edgeCeiling`
-- is the rim's upper bound as a function of distance to the map edge alone. A tile therefore needs
-- the upper pass exactly when its own CLOSEST-TO-THE-EDGE corner could rise past `mid`. A spec
-- asserts the invariant that makes the omission safe: over three seeds, no column's height leaves
-- the band its tile was written in.
function Layout.tiles(config): { Tile }
	local perSide = math.floor(config.SIZE_STUDS / config.TILE_STUDS)
	local half = config.SIZE_STUDS / 2
	local band = config.BAND_Y
	local out: { Tile } = {}
	local function add(tx: number, tz: number, pass: string, minY: number, maxY: number)
		table.insert(out, {
			tx = tx,
			tz = tz,
			minX = -half + tx * config.TILE_STUDS,
			minZ = -half + tz * config.TILE_STUDS,
			pass = pass,
			minY = minY,
			maxY = maxY,
		})
	end
	-- Every lower pass first, then every upper pass, so inserting a tile into the rim ring cannot
	-- move which region an existing lower pass writes (the `ordinal` defect this ordering avoids).
	for tz = 0, perSide - 1 do
		for tx = 0, perSide - 1 do
			add(tx, tz, "lower", band.min, band.mid)
		end
	end
	for tz = 0, perSide - 1 do
		for tx = 0, perSide - 1 do
			if Layout.tileNeedsUpperPass(tx, tz, config) then
				add(tx, tz, "upper", band.mid, band.max)
			end
		end
	end
	return out
end

-- Could any column in this tile rise above `BAND_Y.mid`? Pure, and an UPPER BOUND: it may say yes
-- where the answer turns out to be no (the bench suppression can only lower the rim), and it can
-- never say no where the answer is yes.
function Layout.tileNeedsUpperPass(tx: number, tz: number, config): boolean
	local half = config.SIZE_STUDS / 2
	local minX = -half + tx * config.TILE_STUDS
	local minZ = -half + tz * config.TILE_STUDS
	local maxX, maxZ = minX + config.TILE_STUDS, minZ + config.TILE_STUDS
	-- The tile's closest approach to the map's edge, which is where the rim is highest.
	local toEdge =
		math.min(half - math.max(math.abs(minX), math.abs(maxX)), half - math.max(math.abs(minZ), math.abs(maxZ)))
	return Height.edgeCeiling(toEdge, config) > config.BAND_Y.mid
end

-- ---------------------------------------------------------------- the drive's geometry

-- Every spawn pad the heightfield must flatten: ground a boar is released onto. FOUR, and not one
-- per marker -- the posts stand on stand floors and the driver start stands on the assembly bench,
-- both of which are flat at GROUND_Y already.
function Layout.pads(config): { Point }
	local block = Layout.activeBlock(config)
	local z = block.bounds.maxZ - config.DRIVE.boarSpawnInset
	local pads = {}
	for _, x in ipairs(config.DRIVE.boarSpawnX) do
		table.insert(pads, { x = x, z = z })
	end
	return pads
end

-- The x of each stand, left to right: `postCount` posts at `postSpacing`, centred on `centreX`.
function Layout.postX(index: number, config): number
	local drive = config.DRIVE
	return drive.centreX + (index - (drive.postCount + 1) / 2) * drive.postSpacing
end

-- WHERE THE EIGHT TIMBER STANDS GO: `Map.STAND.offsetZ` behind the active block's road centreline,
-- which is 10 studs clear of the gravel's edge and 6 studs past `keepClear` -- so the road guard
-- needs no exemption for them, and a spec asserts that rather than trusting it.
--
-- Its own function because `treeDensity` needs it for every candidate in the wood and must not
-- build the whole stand list to find out.
function Layout.standPoints(config): { Point }
	if not config.INCLUDE.stands then
		return {}
	end
	local z = Layout.lineZ(config) + config.STAND.offsetZ
	local out: { Point } = {}
	for index = 1, config.DRIVE.postCount do
		table.insert(out, { x = Layout.postX(index, config), z = z })
	end
	return out
end

-- The five kinds of marker, in a stable order, FOR THE ACTIVE BLOCK ONLY. Position, height and size:
-- how a marker FACES is decided once, in `Markers.place`, with an explicit `CFrame.lookAt` toward
-- +Z. That matters most for the DRIVE LINE, whose LookVector must point at the drivers -- the
-- meaning src/server/Weapon/SafetyArc.luau gives it, where the other way round makes the safety rule
-- fire on exactly the wrong shots.
--
-- `y` is the marker's own HEIGHT ABOVE THE GROUND at its position: 0.5 for anything standing on the
-- ground, and `Map.STAND.floorStuds + 0.5` for a shooter post, whose bottom face sits on the stand's
-- floor. `Match.Body.placementFor` then puts a character at `post.Position + post.Size.Y/2 +
-- STAND_HEIGHT_STUDS`, about a stud above the boards -- SO `Match.Body` IS NOT TOUCHED, `Match.CONFIG`
-- is not touched, and no number crosses an owner boundary.
function Layout.markers(config): { Marker }
	local drive = config.DRIVE
	local block = Layout.activeBlock(config)
	local bounds = block.bounds
	local lineZ = Layout.lineZ(config)
	local out: { Marker } = {}
	for index = 1, drive.postCount do
		table.insert(out, {
			kind = "shooterPost",
			name = string.format("ShooterPost%d", index),
			x = Layout.postX(index, config),
			z = lineZ + config.STAND.offsetZ,
			-- (6, 1, 6), and the 1 is load-bearing: a 6-stud-tall marker put the stand point 9.5
			-- studs over a part that does not collide -- the drop named in TASKS.md row 43a(l) and
			-- audit-004 F9.
			y = config.STAND.floorStuds + 0.5,
			size = Vector3.new(6, 1, 6),
		})
	end
	table.insert(out, {
		kind = "driveLine",
		name = "DriveLine",
		x = (bounds.minX + bounds.maxX) / 2,
		z = lineZ,
		y = 0.5,
		-- THE BLOCK'S FULL WIDTH. CFrame.lookAt(at, at + +Z): the LookVector points at the drivers.
		size = Vector3.new(bounds.maxX - bounds.minX, 1, 1),
	})
	table.insert(out, {
		kind = "driverStart",
		name = "DriverStart",
		x = drive.centreX,
		z = config.ROADS.assembly.at,
		y = 0.5,
		size = drive.driverStartSize,
	})
	local spawnZ = bounds.maxZ - drive.boarSpawnInset
	for index, x in ipairs(drive.boarSpawnX) do
		table.insert(out, {
			kind = "boarSpawn",
			name = string.format("BoarSpawn%d", index),
			x = x,
			z = spawnZ,
			y = 0.5,
			size = Vector3.new(6, 1, 6),
		})
	end
	return out
end

-- The twelve tie trees, PLACED rather than chosen: evenly along the post span, in the crossing band
-- behind the shooter line, so a punished shooter is tied within sight of where they stood and
-- nothing stands between a shooter and the drive.
function Layout.tieTreePoints(config): { Point }
	if not config.INCLUDE.tieTrees then
		return {}
	end
	local drive = config.DRIVE
	local out: { Point } = {}
	for index = 1, drive.tieTrees do
		local t = if drive.tieTrees == 1 then 0.5 else (index - 1) / (drive.tieTrees - 1)
		table.insert(out, {
			x = drive.centreX - drive.tieTreeSpan / 2 + t * drive.tieTreeSpan,
			z = drive.tieTreeZ,
		})
	end
	return out
end

-- ---------------------------------------------------------------- the wood

-- THE WOOD ACROSS THE ROAD (design, "The crossing: a wood on both sides of the road"). The first
-- `crossingBandStuds` of the block BEYOND the active block's road, at the active block's `drive`
-- density, so a boar that beats the line crosses 20 studs of gravel in front of a stand and goes
-- into trees. nil when the active block has no character or no block lies beyond its road.
function Layout.crossingBand(config): Rect?
	local block = Layout.activeBlock(config)
	local character = block.character
	if character == nil or character.crossingBandStuds == nil then
		return nil
	end
	-- The block on the far side of this block's road: same x span, its own -Z side.
	local road = Layout.activeRoad(config)
	for _, other in ipairs(Layout.blocks(config)) do
		if other.name ~= block.name and other.bounds.maxZ <= road.at and other.bounds.minX == block.bounds.minX then
			return {
				minX = other.bounds.minX,
				maxX = other.bounds.maxX,
				minZ = other.bounds.maxZ - character.crossingBandStuds,
				maxZ = other.bounds.maxZ,
			}
		end
	end
	return nil
end

-- HOW THICK THE WOOD IS HERE, as a weight in 0..1. A candidate tree is accepted when its own drawn
-- key is below this, which makes the density a property of WHERE rather than of how many cells were
-- rejected before it.
--
-- `patches` is the ACTIVE BLOCK's seeded patch list and arrives as an argument (see this file's
-- header): a patch has its own grid, its own step and its own folder, so the main wood must return
-- 0 inside one or the same ground would be planted twice.
--
-- THE ZEROES ARE THE GROUND THE GAME STANDS THINGS ON, and they are the whole reason this function
-- is the single source of "may a tree stand here": `Props.rejectTree` is `treeDensity <= 0`, so the
-- placing step and the predicate cannot disagree -- which is what two copies of a rule always end up
-- doing (the hedge wall across the gravel, TASKS.md row 43a(k)).
function Layout.treeDensity(x: number, z: number, config, patches: { any }?): number
	if Layout.onRoadKeepClear(x, z, config) or Layout.treeDensityBlockers(x, z, config) then
		return 0
	end
	-- INSIDE A PATCH -- AND FOR `PATCH_EDGE_MARGIN` STUDS OUTSIDE IT -- the patch's own step
	-- decides. A `gap` patch has weight 0 and plants nothing, which is what makes it a clearing.
	--
	-- THE MARGIN IS WHY THIS IS NOT JUST `<= radiusStuds`. The wood refused to plant inside the
	-- radius and the patch refuses to plant outside it, so without a margin a patch tree and a wood
	-- tree can sit either side of that one line with nothing between them -- which is a hole in the
	-- walkability guarantee at the edge of every patch, and the measurement that caught the rim's
	-- overlap would have caught this next.
	for _, patch in ipairs(patches or {}) do
		local reach = patch.radiusStuds + config.PATCH_EDGE_MARGIN
		if (Vector3.new(x, 0, z) - Vector3.new(patch.x, 0, patch.z)).Magnitude <= reach then
			return 0
		end
	end

	local block = Layout.blockAt(x, z, config)
	local active = Layout.activeBlock(config)
	local character = active.character
	if character == nil then
		return 0
	end
	local density = character.density
	if block ~= nil and block.name == active.name then
		-- THE BAND THE SHOOTER ACTUALLY LOOKS INTO.
		if
			math.abs(z - Layout.lineZ(config)) <= density.denseBandStuds
			and math.abs(x - config.DRIVE.centreX) <= density.denseHalfWidth
		then
			return density.dense
		end
		return density.drive
	end
	local crossing = Layout.crossingBand(config)
	if crossing ~= nil and inRect(x, z, crossing) then
		return density.drive -- the wood on the far side of the road, at the drive's own thickness
	end
	if block ~= nil then
		-- ANOTHER BLOCK, AND ITS CONTENT IS NOT BUILT. Blocks 2-4 are layout only in this task:
		-- their rectangles, roads and relief exist and their ground is bare. That is visible in
		-- `forest-wide`, and the day a block's `character` lands it is one row of data.
		return if block.content then density.drive else 0
	end
	-- OUTSIDE EVERY BLOCK: the rim, where no player walks and no drive runs. Sparse backdrop wood,
	-- so a player on a road does not look at a bare ridge.
	return density.backdrop
end

-- THE GROUND THE GAME STANDS THINGS ON, as one predicate: a spawn pad, a stand's clearing, the
-- drivers' strip, a tie tree, and the retired layers' own exclusions. Nothing the generator places
-- may stand here -- not a tree, not a bush, not a fern, not a fallen log.
--
-- IT IS SEPARATE FROM `treeDensity` SO THE FLOOR LAYERS CAN SHARE IT. Brush, ferns and deadwood are
-- not trees and have no density tier, but they must respect exactly the same clear ground: a fern
-- carpet over a boar's spawn pad reads as a mistake, and a log across the drivers' strip is one
-- eight drivers are placed inside. One predicate, four readers, so they cannot disagree.
function Layout.treeDensityBlockers(x: number, z: number, config): boolean
	if Layout.inField(x, z, config) or Layout.onTrack(x, z, config) then
		return true
	end
	if Layout.distanceToHedge(x, z, config) < config.SCATTER_CLEARANCE then
		return true
	end
	-- A PAD'S SIZE IS THE CONTRACT'S, not the pad list's: `Layout.pads` is four positions, and how
	-- wide the flat ground around one is belongs to Map.SPAWN_PAD.
	local clear = config.SPAWN_PAD.radius + config.SPAWN_PAD.blend
	for _, pad in ipairs(Layout.pads(config)) do
		if (Vector3.new(x, 0, z) - Vector3.new(pad.x, 0, pad.z)).Magnitude <= clear then
			return true -- a boar is released onto flat, clear ground
		end
	end
	-- A STAND STANDS IN ITS OWN CLEARING. It sits 20 studs behind the road, inside the DENSE band,
	-- so without this a 7-stud tower would be built inside an oak -- and "look at the screenshot" is
	-- only useful if the thing is not inside a tree.
	for _, stand in ipairs(Layout.standPoints(config)) do
		if (Vector3.new(x, 0, z) - Vector3.new(stand.x, 0, stand.z)).Magnitude <= config.STAND.clearRadius then
			return true
		end
	end
	-- THE DRIVERS' STRIP. The assembly road's keepClear is 9 studs and the DriverStart part is 20
	-- deep, so the part's own footprint reaches past the road guard; anything inside it stands where
	-- eight drivers are placed.
	local start = config.DRIVE.driverStartSize
	if
		math.abs(z - config.ROADS.assembly.at) <= start.Z / 2 + 2
		and math.abs(x - config.DRIVE.centreX) <= start.X / 2 + 2
	then
		return true
	end
	-- A TIE TREE STANDS ON PURPOSE, so the wood keeps off it: two trunks in one place is one trunk a
	-- punished shooter can be tied to and one that reads as a mistake.
	for _, tie in ipairs(Layout.tieTreePoints(config)) do
		if (Vector3.new(x, 0, z) - Vector3.new(tie.x, 0, tie.z)).Magnitude <= 10 then
			return true
		end
	end
	return false
end

-- THE WOOD IS BUILT IN SUB-BLOCKS, because one step that creates a thousand Models is one step that
-- can time out and tells you nothing about where it was when it did. The active block cut into
-- `TREE_SUBBLOCK_STUDS` squares, then the crossing band cut the same way along x -- each its own
-- step and its own line in the run log.
function Layout.treeBlocks(config): { { name: string, minX: number, maxX: number, minZ: number, maxZ: number } }
	if not (config.INCLUDE.trees or config.INCLUDE.brush or config.INCLUDE.ferns) then
		-- Task 85's mechanism: an empty list is no steps rather than steps that place nothing.
		return {}
	end
	local out = {}
	local span = config.TREE_SUBBLOCK_STUDS
	local function cut(label: string, rect: Rect)
		local cols = math.max(1, math.ceil((rect.maxX - rect.minX) / span))
		local rows = math.max(1, math.ceil((rect.maxZ - rect.minZ) / span))
		for row = 0, rows - 1 do
			for col = 0, cols - 1 do
				table.insert(out, {
					name = string.format("%s%d%d", label, row + 1, col + 1),
					minX = rect.minX + col * span,
					maxX = math.min(rect.minX + (col + 1) * span, rect.maxX),
					minZ = rect.minZ + row * span,
					maxZ = math.min(rect.minZ + (row + 1) * span, rect.maxZ),
				})
			end
		end
	end
	local active = Layout.activeBlock(config)
	cut("Block", active.bounds)
	local crossing = Layout.crossingBand(config)
	if crossing ~= nil then
		cut("Crossing", crossing)
	end
	return out
end

-- THE RIM'S BACKDROP WOOD, as its own area list: everything outside every block, cut the same way.
-- It is separate from `treeBlocks` because the rim is a ring and cutting a ring into squares that
-- happen to be mostly empty would be dozens of steps that place nothing.
function Layout.backdropBlocks(config): { { name: string, minX: number, maxX: number, minZ: number, maxZ: number } }
	if not config.INCLUDE.trees then
		return {}
	end
	local half = config.SIZE_STUDS / 2
	local band = config.EDGE_BAND
	return {
		{ name = "RimWest", minX = -half, maxX = -half + band, minZ = -half, maxZ = half },
		{ name = "RimEast", minX = half - band, maxX = half, minZ = -half, maxZ = half },
		{ name = "RimSouth", minX = -half + band, maxX = half - band, minZ = -half, maxZ = -half + band },
		{ name = "RimNorth", minX = -half + band, maxX = half - band, minZ = half - band, maxZ = half },
	}
end

-- ---------------------------------------------------------------- the triangle bound

-- A PURE UPPER BOUND ON BAKED GEOMETRY INSIDE ONE STREAMING RADIUS (design, "A pure upper bound,
-- asserted"). Sum, over every tree whose planted position lies within `Map.STREAMING.targetRadius`
-- of `point`, the triangles its (species, age, tier) declares.
--
-- It is PURE -- no world, no Studio -- so a server spec asserts it at all eight stands and the
-- driver start, and the trees step fails the build if a sub-block pushes it over. It is a bound on
-- BAKED geometry and not on what is drawn: `RenderFidelity = Automatic` reduces distant meshes and
-- identical meshes instance. What it does is turn "hundreds of trees, LOD, streaming" into a number
-- a machine can refuse, which is the only kind of budget this project has found to work.
--
-- The trees arrive as an argument, each `{ x, z, species, age, tier }` -- see this file's header.
function Layout.visibleLoad(point: Point, trees: { any }, config, radius: number): number
	local total = 0
	local limit = radius * radius
	for _, tree in ipairs(trees) do
		local dx, dz = tree.x - point.x, tree.z - point.z
		if dx * dx + dz * dz <= limit then
			local species = config.SPECIES[tree.species]
			local tier = tree.tier or tree.age
			total += (species and species.tris[tier]) or 0
		end
	end
	return total
end

-- Every point the triangle bound is asserted at: the eight stands a shooter stands on and the
-- driver start. Those are where a player's eye actually is.
function Layout.loadPoints(config): { { name: string, x: number, z: number } }
	local out = {}
	for index, stand in ipairs(Layout.standPoints(config)) do
		table.insert(out, { name = string.format("Stand%d", index), x = stand.x, z = stand.z })
	end
	table.insert(out, { name = "DriverStart", x = config.DRIVE.centreX, z = config.ROADS.assembly.at })
	return out
end

-- ---------------------------------------------------------------- the forest floor's counts

-- ONE HECTARE IS 127,551 STUDS SQUARED at 1 stud = 0.28 m, and the rates are per hectare because
-- that is the unit forestry uses and the unit the design's arithmetic is written in.
Layout.STUDS2_PER_HECTARE = 127551

function Layout.hectares(rect: Rect): number
	return ((rect.maxX - rect.minX) * (rect.maxZ - rect.minZ)) / Layout.STUDS2_PER_HECTARE
end

-- How many of a per-hectare thing belong in one area, as a whole number.
function Layout.countFor(rect: Rect, perHa: number): number
	return math.max(0, math.floor(Layout.hectares(rect) * perHa + 0.5))
end

-- ---------------------------------------------------------------- the stakes

export type Piece = {
	kind: string,
	name: string,
	x: number,
	z: number,
	size: Vector3,
	base: number, -- the bottom face, in studs above the ground at (anchorX, anchorZ)
	anchorX: number, -- where the GROUND is sampled: one height per object, so a stand's four legs
	anchorZ: number, -- and its floor stand on one plane instead of following the terrain
	color: Color3,
	material: Enum.Material,
}

-- TWO STAKES PER STAND, and the orange cap on top of each. With every tagged marker at
-- `Transparency = 1` (TASKS.md row 58a(a)), the stakes are the only thing that says where a stand is
-- from 160 studs away -- and the stand itself is the other, now that there is one.
--
-- IN FRONT of the stand, between it and the road, so nothing here ever stands between a shooter on
-- the boards and what he is shooting at: the shooter is at z = line - 20 and the drive is at +Z, so
-- "in front" is +Z of the stand and still short of the gravel.
function Layout.furniture(config): { Piece }
	local f = config.FURNITURE
	local out: { Piece } = {}
	local function add(piece: Piece)
		table.insert(out, piece)
	end
	if not config.INCLUDE.stakes then
		return out
	end
	for index, stand in ipairs(Layout.standPoints(config)) do
		local z = stand.z + f.stake.offsetZ
		for _, side in ipairs({ -1, 1 }) do
			local x = stand.x + side * f.stake.offsetX
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
	return out
end

-- ---------------------------------------------------------------- the retired layers
--
-- THE HEDGEROW AND FARMLAND MECHANISMS, SWITCHED OFF AND NOT DELETED (design, "Fields, hedges and
-- the old flank track"). `Config.INCLUDE.fields`, `.hedges` and `.tracks` are false, because there
-- is no room for farmland inside a forest that fills the map. They keep their callers and their
-- specs for one specific reason: the hedge-gate mechanism is the one that has already caught a
-- collidable wall standing across a drive, and orphaning it would throw that check away (TASKS.md
-- row 43a(m) is the opposite smell -- a function with no reader -- and this is the answer to it).

function Layout.inField(x: number, z: number, config): boolean
	if not config.INCLUDE.fields then
		return false
	end
	local f = config.WORLD_FIELDS
	return math.abs(x) >= f.innerX and math.abs(x) <= f.outerX and z >= f.minZ and z <= f.maxZ
end

function Layout.onTrack(x: number, z: number, config): boolean
	if not config.INCLUDE.tracks then
		return false
	end
	for _, track in ipairs(config.WORLD_TRACKS) do
		local across = if track.axis == "x" then z else x
		if math.abs(across - track.at) <= track.halfWidth then
			return true
		end
	end
	return false
end

-- The field boundaries, as lines. `axis = "x"` runs ALONG x at a constant z. A line that crosses the
-- ACTIVE BLOCK is marked, because that is the one that must be gated or the drive stops at it.
function Layout.hedgeLines(config): { Line }
	if not config.INCLUDE.hedges then
		return {}
	end
	local world = config.WORLD_HEDGES
	local span = world.halfSpan
	local bounds = Layout.activeBlock(config).bounds
	local out: { Line } = {}
	for _, z in ipairs(world.alongX) do
		table.insert(out, {
			axis = "x",
			at = z,
			from = -span,
			to = span,
			crossesCorridor = z >= bounds.minZ and z <= bounds.maxZ,
		})
	end
	for _, x in ipairs(world.alongZ) do
		table.insert(out, {
			axis = "z",
			at = x,
			from = -span,
			to = span,
			crossesCorridor = x >= bounds.minX and x <= bounds.maxX,
		})
	end
	return out
end

-- The stretch of a line that lies inside the ACTIVE BLOCK, as (from, to) along the line's own axis,
-- or nil when it never enters it. This is where a gate has to be: a gate outside the drive is a gate
-- the drive never reaches.
function Layout.corridorSpan(line: Line, config): (number?, number?)
	if not line.crossesCorridor then
		return nil, nil
	end
	local bounds = Layout.activeBlock(config).bounds
	local low = if line.axis == "x" then bounds.minX else bounds.minZ
	local high = if line.axis == "x" then bounds.maxX else bounds.maxZ
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
	local gateHalf = config.WORLD_HEDGES.gateStuds / 2
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
		-- A ROAD IS A GATE NOBODY HAS TO CUT (Task 58 round 2, finding 1). A hedge segment on the
		-- gravel is a collidable wall across the one strip the whole revision exists to keep open;
		-- half a segment's length of clearance keeps the PART off it, not just its centre.
		if Layout.onRoadKeepClear(x, z, config, config.HEDGE.segmentStuds / 2) then
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

return Layout
