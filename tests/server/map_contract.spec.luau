-- map_contract.spec: THE WORLD THE COMMITTED CONTRACT NAMES, plus the generator's pure maths.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- TWO JOBS, and the split is the design's (docs/design/map-generator.md sections 13.1 and 2.2):
--
--  1. THE LIVE WORLD. `Map.EXPECTED_WORLD` says which world this place is, and the assertions run
--     against THAT world -- so neither branch is empty and there is no path where this file passes by
--     finding nothing. In Milestone 2.1 it names "arena", because the 512-stud slice is an EDIT-TIME
--     artefact and not yet the world (design section 14). The same assertions hold at the M2.5 switch.
--
--  2. THE GENERATOR'S PURE CORE. `MapGen` never runs in a harness session -- it runs in Edit, driven
--     by `tools/mapgen.py` -- so the only thing a spec can test about it is the part that needs no
--     Terrain, no Studio and no asset: `Height`, `Layout`, `Scatter` and `Digest`. That is what
--     exporting them is for. Determinism is the property under test, because a map that cannot be
--     rebuilt from its seed cannot be reviewed as a diff.
--
--     WHAT THIS FILE CANNOT DO, said plainly: it cannot pathfind the generated map, because the map is
--     not in the place during a harness run. `MapGen.reachability`, driven by
--     `python tools/mapgen.py verify`, is the check that walks it with the boar's own agent; the
--     hedgerow tests below are the pure half -- a gate wide enough, inside the corridor, on every line
--     that crosses it. Both exist because the harness half alone let an ungated wall through
--     (TASKS.md row 43a(k)).
--
-- It asserts the WORLD and the CONTRACT against each other rather than either against itself: the
-- counts come from `Map.EXPECTED_COUNTS`, the tags from `Map.TAGS`, the rectangle from `Map.FIELD`,
-- and the boar's own field from `Boar.CONFIG` (CLAUDE.md rule 6 -- test the player's path).
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Map = require(ReplicatedStorage:WaitForChild("Map"))
local Boar = require(ServerScriptService:WaitForChild("Boar"))
local MapGen = require(ServerStorage:WaitForChild("MapGen"))
-- The placing step's own rejection predicate, so the scatter tests below assert what the generator
-- actually does rather than a copy of it.
local Props = require(ServerStorage.MapGen:WaitForChild("Props"))

local ARENA_ROOT = "TestArena"
local MAP_ROOT = "DrivenHuntMap"
local SEED = 7 -- any seed: the claims below are about determinism, not about one map

-- Script start order is not guaranteed, so give the boot script up to 5 s, as test_arena.spec does.
local function waitForRoot(name: string)
	local deadline = os.clock() + 5
	local root = Workspace:FindFirstChild(name)
	while not root and os.clock() < deadline do
		task.wait(0.1)
		root = Workspace:FindFirstChild(name)
	end
	return root
end

local function namedRootName(): string
	return if Map.EXPECTED_WORLD == "arena" then ARENA_ROOT else MAP_ROOT
end

local function taggedInside(root: Instance, tag: string): { BasePart }
	local out = {}
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(root) then
			table.insert(out, instance)
		end
	end
	return out
end

local function config()
	return MapGen.CONFIG
end

local function driveLinePoint(root: Instance): Vector3
	local lines = taggedInside(root, Map.TAGS.driveLine)
	return lines[1].Position
end

return function()
	describe("the map contract", function()
		it("names exactly one world, and that world is the one that exists", function()
			expect(Map.EXPECTED_WORLD == "arena" or string.sub(Map.EXPECTED_WORLD, 1, 4) == "map:").to.equal(true)
			local named = waitForRoot(namedRootName())
			expect(named).to.be.ok()
			-- The OTHER root must be absent. Two worlds in Workspace means the generated slice was
			-- left in the place: the tags then resolve to both and every count below is doubled.
			local other = if namedRootName() == ARENA_ROOT then MAP_ROOT else ARENA_ROOT
			expect(Workspace:FindFirstChild(other)).to.equal(nil)
		end)

		it("resolves every tag to exactly the expected count, all inside the named world", function()
			local root = waitForRoot(namedRootName())
			for kind, tag in pairs(Map.TAGS) do
				local want = Map.EXPECTED_COUNTS[kind]
				expect(want).to.be.a("number")
				local inside = taggedInside(root, tag)
				if #inside ~= want then
					error(string.format("%s: %d tagged inside %s, %d expected", tag, #inside, root.Name, want), 0)
				end
				-- And nothing carries the tag outside the world: a stray tagged part elsewhere would
				-- be picked up by Match.Markers, which searches by tag and not by folder.
				expect(#CollectionService:GetTagged(tag)).to.equal(want)
			end
		end)

		it("has one drive line whose LookVector points at the drivers", function()
			local root = waitForRoot(namedRootName())
			local lines = taggedInside(root, Map.TAGS.driveLine)
			expect(#lines).to.equal(1)
			-- +Z is the drivers' side. src/server/Weapon/SafetyArc.luau reads this vector as "toward
			-- the drivers"; a line facing the other way makes the safety rule fire on the wrong shots.
			expect(lines[1].CFrame.LookVector:Dot(Vector3.zAxis) > 0.99).to.equal(true)
		end)

		it("puts every boar spawn inside the field, on the ground", function()
			local root = waitForRoot(namedRootName())
			local spawns = taggedInside(root, Map.TAGS.boarSpawn)
			expect(#spawns > 0).to.equal(true)
			local b = Map.FIELD.bounds
			for _, spawn in ipairs(spawns) do
				local p = spawn.Position
				expect(p.X >= b.minX and p.X <= b.maxX).to.equal(true)
				expect(p.Z >= b.minZ and p.Z <= b.maxZ).to.equal(true)
				-- The check that stops a boar being released inside a hill (design section 7.3).
				if math.abs(p.Y - Map.FIELD.groundY) > Map.SPAWN_PAD.tolerance then
					error(string.format("%s sits at y=%.2f, groundY is %.2f", spawn.Name, p.Y, Map.FIELD.groundY), 0)
				end
			end
		end)

		it("is walkable for the boar's own agent, from every spawn and from the driver start", function()
			local root = waitForRoot(namedRootName())
			local target = driveLinePoint(root)
			local froms = {}
			for _, spawn in ipairs(taggedInside(root, Map.TAGS.boarSpawn)) do
				table.insert(froms, spawn.Position)
			end
			for _, start in ipairs(taggedInside(root, Map.TAGS.driverStart)) do
				table.insert(froms, start.Position)
			end
			expect(#froms > 0).to.equal(true)
			for _, from in ipairs(froms) do
				-- The BOAR's agent params, not an imaginary one: this asserts the map is playable for
				-- the animal that actually walks it.
				local path = PathfindingService:CreatePath(Boar.CONFIG.AGENT)
				path:ComputeAsync(from + Vector3.new(0, 2, 0), target)
				if path.Status ~= Enum.PathStatus.Success then
					error(
						string.format(
							"no path from (%d, %d) to the drive line: %s",
							from.X,
							from.Z,
							tostring(path.Status)
						),
						0
					)
				end
				expect(#path:GetWaypoints() >= 2).to.equal(true)
			end
		end)

		it("holds no script under the world root, and none in the generator", function()
			local root = waitForRoot(namedRootName())
			for _, descendant in ipairs(root:GetDescendants()) do
				if descendant:IsA("LuaSourceContainer") then
					error("a script exists under the world: " .. descendant:GetFullName(), 0)
				end
			end
			-- Nothing in the generator can autorun (design section 1.2): every descendant is a module.
			local generator = ServerStorage:FindFirstChild("MapGen")
			expect(generator).to.be.ok()
			for _, descendant in ipairs(generator:GetDescendants()) do
				if not descendant:IsA("ModuleScript") then
					error("ServerStorage.MapGen holds a " .. descendant.ClassName .. ": " .. descendant.Name, 0)
				end
			end
		end)

		it("agrees with the boar about the field rectangle", function()
			local field = Boar.CONFIG.field
			expect(field.bounds.minX).to.equal(Map.FIELD.bounds.minX)
			expect(field.bounds.maxX).to.equal(Map.FIELD.bounds.maxX)
			expect(field.bounds.minZ).to.equal(Map.FIELD.bounds.minZ)
			expect(field.bounds.maxZ).to.equal(Map.FIELD.bounds.maxZ)
			expect(field.exitZ).to.equal(Map.FIELD.exitZ)
			expect(field.groundY).to.equal(Map.FIELD.groundY)
		end)

		it("keeps the streaming properties the contract names", function()
			expect(Workspace.StreamingEnabled).to.equal(Map.STREAMING.enabled)
		end)
	end)

	describe("the generator's heightfield", function()
		it("gives the same height for the same seed, and a different one for another seed", function()
			local c = config()
			for _, point in ipairs({ { 0, 0 }, { 123.5, -77.25 }, { -200, 200 } }) do
				local a = MapGen.Height.at(point[1], point[2], SEED, c)
				local b = MapGen.Height.at(point[1], point[2], SEED, c)
				expect(a).to.equal(b)
			end
			-- Not a claim that every point moves -- noise fields cross -- but that the field as a
			-- whole does: a seed that changed nothing would be a seed that is not read.
			local moved = 0
			for x = -240, 240, 60 do
				for z = -240, 240, 60 do
					if MapGen.Height.at(x, z, SEED, c) ~= MapGen.Height.at(x, z, SEED + 1, c) then
						moved += 1
					end
				end
			end
			expect(moved > 50).to.equal(true)
		end)

		it("stays inside the relief band, and flatter inside the drive corridor", function()
			local c = config()
			local worst, worstCorridor = 0, 0
			for x = -250, 250, 25 do
				for z = -250, 250, 25 do
					local h = math.abs(MapGen.Height.at(x, z, SEED, c) - c.GROUND_Y)
					worst = math.max(worst, h)
					if MapGen.Layout.inCorridor(x, z, c) then
						worstCorridor = math.max(worstCorridor, h)
					end
				end
			end
			expect(worst <= c.RELIEF).to.equal(true)
			expect(worstCorridor <= c.CORRIDOR_RELIEF).to.equal(true)
			-- Well inside the boar's fall limit, which is what makes this terrain safe for it.
			expect(worst < 50).to.equal(true)
		end)

		it("flattens every spawn pad to exactly the ground the contract asserts", function()
			local c = config()
			local pads = MapGen.Layout.pads(c)
			expect(#pads > 0).to.equal(true)
			for _, pad in ipairs(pads) do
				expect(MapGen.Height.atFlattened(pad.x, pad.z, SEED, c, pads)).to.equal(c.GROUND_Y)
			end
			-- And a pad eases back to the terrain rather than ending in a cliff: at the far edge of the
			-- blend the flattened height IS the raw height. One pad on its own, because the shooter
			-- posts stand 46 studs apart and their pads overlap -- with the real list the point below
			-- is inside the next post's pad, which is the intended behaviour and not this claim.
			local lone = { { x = 0, z = 0 } }
			local edge = c.SPAWN_PAD.radius + c.SPAWN_PAD.blend
			expect(MapGen.Height.atFlattened(0, 0, SEED, c, lone)).to.equal(c.GROUND_Y)
			local far = MapGen.Height.atFlattened(edge, 0, SEED, c, lone)
			expect(math.abs(far - MapGen.Height.at(edge, 0, SEED, c)) < 0.001).to.equal(true)
			-- Halfway through the blend it is between the two, so the easing is real.
			local mid = MapGen.Height.atFlattened(c.SPAWN_PAD.radius + c.SPAWN_PAD.blend / 2, 0, SEED, c, lone)
			local raw = MapGen.Height.at(c.SPAWN_PAD.radius + c.SPAWN_PAD.blend / 2, 0, SEED, c)
			expect(math.abs(mid - c.GROUND_Y) <= math.abs(raw - c.GROUND_Y) + 0.001).to.equal(true)
		end)
	end)

	describe("the generator's layout", function()
		it("plans exactly the markers the configuration asks for", function()
			local c = config()
			local counts = {}
			for _, marker in ipairs(MapGen.Layout.markers(c)) do
				counts[marker.kind] = (counts[marker.kind] or 0) + 1
			end
			-- Against the CONFIGURATION, not against MapGen.expectedCounts(): that function is the
			-- same loop over the same data, so comparing the two could not fail for any layout,
			-- right or wrong (review round 1, finding 2).
			expect(counts.shooterPost).to.equal(c.WORLD.postCount)
			expect(counts.boarSpawn).to.equal(#c.WORLD.boarSpawnX)
			expect(counts.driveLine).to.equal(1)
			expect(counts.driverStart).to.equal(1)
			-- Every kind has a tag string in the contract, so nothing can be placed untaggable.
			for _, marker in ipairs(MapGen.Layout.markers(c)) do
				expect(Map.TAGS[marker.kind]).to.be.a("string")
			end
		end)

		it("expects one tagged instance per planned marker, plus the tie trees", function()
			local c = config()
			local expected = MapGen.expectedCounts()
			local planned = 0
			for _, marker in ipairs(MapGen.Layout.markers(c)) do
				planned += 1
				expect(expected[marker.kind]).to.be.a("number")
			end
			local total = 0
			for kind, count in pairs(expected) do
				expect(Map.TAGS[kind]).to.be.a("string")
				total += count
			end
			-- The map's own expectation is every marker it places plus the trunks it tags, and
			-- nothing else: a sixth kind added to Layout without a tag would break this.
			expect(total).to.equal(planned + c.WORLD.tieTrees)
		end)

		it("keeps every marker it plans inside the MAP's own field", function()
			local c = config()
			-- `Config.FIELD`, not `Map.FIELD`: while EXPECTED_WORLD is "arena" the contract's rectangle
			-- is the arena's 400 x 400 (it must equal Boar.CONFIG.field, which another test asserts),
			-- and the generated map is 2048 studs across. At the M2.5 switch Config.FIELD becomes both,
			-- and this test and that one start asserting the same rectangle.
			local b = c.FIELD.bounds
			expect(b).to.equal(c.WORLD.corridor)
			for _, marker in ipairs(MapGen.Layout.markers(c)) do
				if marker.kind ~= "driveLine" then
					if marker.x < b.minX or marker.x > b.maxX or marker.z < b.minZ or marker.z > b.maxZ then
						error(
							string.format(
								"%s at (%.0f, %.0f) is outside the map's field",
								marker.name,
								marker.x,
								marker.z
							),
							0
						)
					end
				end
			end
			-- And the map's field is the design's section 12 corridor, not whatever the code drifted to.
			expect(b.minX).to.equal(-340)
			expect(b.maxX).to.equal(340)
			expect(b.minZ).to.equal(-800)
			expect(b.maxZ).to.equal(800)
			expect(c.FIELD.exitZ).to.equal(-760)
			expect(c.FIELD.exitZ < c.WORLD.lineZ).to.equal(true) -- the exit is BEHIND the shooter line
		end)

		it("ties a punished shooter to a tree near the line, not across the map", function()
			local c = config()
			local points = MapGen.Layout.tieTreePoints(c)
			expect(#points).to.equal(c.WORLD.tieTrees)
			for _, point in ipairs(points) do
				-- Design section 4.3: within 120 studs of the line. These trees are PLACED rather than
				-- chosen out of the wood, because at 2048 studs the wood starts beyond the drive
				-- corridor and the nearest scattered trunk is further away than that.
				expect(math.abs(point.z - c.WORLD.lineZ) <= 120).to.equal(true)
				-- Behind the line, never in front of it: nothing may stand between a shooter and the
				-- drive they are shooting into.
				expect(point.z < c.WORLD.lineZ).to.equal(true)
				expect(math.abs(point.x) <= c.WORLD.tieTreeSpan / 2 + 1).to.equal(true)
			end
		end)

		it("covers the whole map with tiles a WriteVoxels call accepts", function()
			local c = config()
			local tiles = MapGen.Layout.tiles(c)
			local perSide = c.SIZE_STUDS / c.TILE_STUDS
			expect(#tiles).to.equal(perSide * perSide)
			-- MEASURED (design section 13.5 measurement A): a 128 x 128 x 96-stud region at
			-- resolution 4 is accepted, which is 24,576 voxels; resolution 8 and 2 are refused.
			local voxels = (c.TILE_STUDS / c.VOXEL) ^ 2 * ((c.BAND_Y.max - c.BAND_Y.min) / c.VOXEL)
			expect(voxels).to.equal(24576)
			expect(c.VOXEL).to.equal(4)
			local seen = {}
			for _, tile in ipairs(tiles) do
				seen[string.format("%d,%d", tile.minX, tile.minZ)] = true
				expect(tile.minX >= -c.SIZE_STUDS / 2).to.equal(true)
				expect(tile.minX + c.TILE_STUDS <= c.SIZE_STUDS / 2).to.equal(true)
			end
			local distinct = 0
			for _ in pairs(seen) do
				distinct += 1
			end
			expect(distinct).to.equal(#tiles)
		end)
	end)

	describe("the generator's hedgerow network", function()
		it("gates every line that crosses the drive corridor, for twenty seeds", function()
			local c = config()
			local crossings = 0
			for index, line in ipairs(MapGen.Layout.hedgeLines(c)) do
				local from, to = MapGen.Layout.corridorSpan(line, c)
				if from and to then
					crossings += 1
					-- EVERY seed, not one: a gate that lands outside the corridor on some seeds is a
					-- drive that stops at a wall on those seeds, and nobody would see it until a
					-- playtest. This is the pure half of TASKS.md row 43a(k).
					for seed = 1, 20 do
						local gates = MapGen.Scatter.hedgeGates(c, seed, index, from, to)
						expect(#gates).to.equal(c.WORLD.gatesPerLine)
						local points = MapGen.Layout.hedgeSegments(line, gates, c)
						local gapFrom, gapTo = MapGen.Layout.widestGap(points, line, from, to, c)
						if gapTo - gapFrom < c.WORLD.gateStuds then
							error(
								string.format(
									"seed %d, line along %s at %d: widest corridor gap %.1f studs, %d wanted",
									seed,
									line.axis,
									line.at,
									gapTo - gapFrom,
									c.WORLD.gateStuds
								),
								0
							)
						end
						for _, gate in ipairs(gates) do
							-- Wholly inside the corridor, half-width and all.
							expect(gate - c.WORLD.gateStuds / 2 >= from - 0.001).to.equal(true)
							expect(gate + c.WORLD.gateStuds / 2 <= to + 0.001).to.equal(true)
						end
					end
				end
			end
			-- And the network really does cross the drive, or the loop above asserted nothing.
			expect(crossings).to.equal(#c.WORLD.hedgeZ)
		end)

		it("puts no hedge segment inside a gate, and none off its own line", function()
			local c = config()
			local half = c.HEDGE.segmentStuds / 2
			local gateHalf = c.WORLD.gateStuds / 2
			for index, line in ipairs(MapGen.Layout.hedgeLines(c)) do
				local from, to = MapGen.Layout.corridorSpan(line, c)
				local gates = if from and to then MapGen.Scatter.hedgeGates(c, SEED, index, from, to) else {}
				for _, point in ipairs(MapGen.Layout.hedgeSegments(line, gates, c)) do
					local along = if line.axis == "x" then point.x else point.z
					local across = if line.axis == "x" then point.z else point.x
					expect(across).to.equal(line.at)
					expect(along >= line.from and along <= line.to).to.equal(true)
					for _, gate in ipairs(gates) do
						expect(along + half <= gate - gateHalf or along - half >= gate + gateHalf).to.equal(true)
					end
				end
			end
		end)

		it("moves its gates with the seed, and leaves a solid wall without them", function()
			local c = config()
			local line = MapGen.Layout.hedgeLines(c)[1]
			local from, to = MapGen.Layout.corridorSpan(line, c)
			expect(from).to.be.ok()
			local a = MapGen.Scatter.hedgeGates(c, SEED, 1, from, to)
			expect(a[1]).to.equal(MapGen.Scatter.hedgeGates(c, SEED, 1, from, to)[1])
			expect(a[1]).never.to.equal(MapGen.Scatter.hedgeGates(c, SEED + 1, 1, from, to)[1])
			-- Without gates it is a solid wall: that is what the gates buy, stated as a test so nobody
			-- removes them thinking they are decoration.
			local solid = MapGen.Layout.hedgeSegments(line, {}, c)
			local gapFrom, gapTo = MapGen.Layout.widestGap(solid, line, from, to, c)
			expect(gapTo - gapFrom < c.HEDGE.segmentStuds).to.equal(true)
		end)

		it("stays inside the design's hedge part budget", function()
			local c = config()
			local segments = 0
			for index, line in ipairs(MapGen.Layout.hedgeLines(c)) do
				local from, to = MapGen.Layout.corridorSpan(line, c)
				local gates = if from and to then MapGen.Scatter.hedgeGates(c, SEED, index, from, to) else {}
				segments += #MapGen.Layout.hedgeSegments(line, gates, c)
			end
			expect(segments <= 500).to.equal(true) -- design section 12
			expect(segments > 100).to.equal(true) -- and it is a network, not one token line
		end)
	end)

	describe("the generator's scatter", function()
		-- The SAME predicate the placing step uses, so the spec cannot pass while the generator plants
		-- trees somewhere else.
		local function reject(x, z)
			return Props.rejectTree(x, z, config())
		end

		it("places the wood it promises, in the same places twice", function()
			local c = config()
			local first = MapGen.Scatter.trees(c, SEED, reject)
			local second = MapGen.Scatter.trees(c, SEED, reject)
			expect(#first).to.equal(c.WORLD.treeCount)
			expect(#second).to.equal(#first)
			for index, point in ipairs(first) do
				expect(point.x).to.equal(second[index].x)
				expect(point.z).to.equal(second[index].z)
			end
		end)

		it("puts no tree in the corridor, on a track, in the bog or in a hedge", function()
			local c = config()
			for _, point in ipairs(MapGen.Scatter.trees(c, SEED, reject)) do
				if MapGen.Layout.inCorridor(point.x, point.z, c) then
					error(string.format("a tree at (%.0f, %.0f) is in the drive corridor", point.x, point.z), 0)
				end
				if MapGen.Layout.onTrack(point.x, point.z, c) then
					error(string.format("a tree at (%.0f, %.0f) is on a track", point.x, point.z), 0)
				end
				if MapGen.Layout.bogDepth(point.x, point.z, c) > 0 then
					error(string.format("a tree at (%.0f, %.0f) is in the bog", point.x, point.z), 0)
				end
				if MapGen.Layout.distanceToHedge(point.x, point.z, c) < c.SCATTER_CLEARANCE then
					error(string.format("a tree at (%.0f, %.0f) stands in a hedgerow", point.x, point.z), 0)
				end
				expect(point.x >= c.WORLD.treeArea.minX and point.x <= c.WORLD.treeArea.maxX).to.equal(true)
				expect(point.z >= c.WORLD.treeArea.minZ and point.z <= c.WORLD.treeArea.maxZ).to.equal(true)
			end
		end)

		it("makes a different wood for a different seed", function()
			local c = config()
			local a = MapGen.Scatter.trees(c, SEED, reject)
			local b = MapGen.Scatter.trees(c, SEED + 1, reject)
			local same = 0
			for index, point in ipairs(a) do
				if b[index] and point.x == b[index].x and point.z == b[index].z then
					same += 1
				end
			end
			expect(same < #a / 2).to.equal(true)
		end)

		it("spreads the trees instead of stacking them in the first rows", function()
			local c = config()
			local points = MapGen.Scatter.trees(c, SEED, reject)
			local minZ, maxZ = math.huge, -math.huge
			for _, point in ipairs(points) do
				minZ, maxZ = math.min(minZ, point.z), math.max(maxZ, point.z)
			end
			-- The candidates are generated row by row, so taking the first N would give a stripe.
			-- Half the map's depth is a low bar deliberately: it fails a stripe and passes a wood.
			expect(maxZ - minZ > c.SIZE_STUDS / 2).to.equal(true)
		end)
	end)

	describe("the generator's digest", function()
		local function entry(name, x)
			return {
				name = name,
				className = "Part",
				position = Vector3.new(x, 1, 2),
				size = Vector3.new(4, 4, 4),
				tags = { Map.TAGS.tree },
			}
		end

		it("is 64 hex characters, of which the marker half is the first 32", function()
			local digest = MapGen.Digest.of(
				{ entry("A", 0) },
				{ { x = 0, z = 0, occupancy = 1, material = "Grass" } },
				100
			)
			expect(#digest).to.equal(64)
			expect(string.match(digest, "^[0-9a-f]+$")).to.be.ok()
			expect(MapGen.Digest.markerHalf(digest)).to.equal(string.sub(digest, 1, 32))
			expect(#MapGen.Digest.markerHalf(digest)).to.equal(32)
		end)

		it("is the same for the same map and different for a moved part", function()
			local samples = { { x = 0, z = 0, occupancy = 1, material = "Grass" } }
			local a = MapGen.Digest.of({ entry("A", 0), entry("B", 10) }, samples, 100)
			local b = MapGen.Digest.of({ entry("A", 0), entry("B", 10) }, samples, 100)
			expect(a).to.equal(b)
			-- Order must not matter: the lines are sorted, so a rebuild that walks Workspace in
			-- another order still digests the same.
			expect(MapGen.Digest.of({ entry("B", 10), entry("A", 0) }, samples, 100)).to.equal(a)
			-- A hundredth of a stud is the resolution the design asks for, so a tenth must show.
			expect(MapGen.Digest.of({ entry("A", 0), entry("B", 10.1) }, samples, 100)).never.to.equal(a)
			-- And the terrain half is in there too.
			local other = { { x = 0, z = 0, occupancy = 0.5, material = "Grass" } }
			expect(MapGen.Digest.of({ entry("A", 0), entry("B", 10) }, other, 100)).never.to.equal(a)
		end)

		it("ignores a difference finer than the rounding, so float noise is not a mismatch", function()
			local samples = { { x = 0, z = 0, occupancy = 1, material = "Grass" } }
			local a = MapGen.Digest.of({ entry("A", 1) }, samples, 100)
			expect(MapGen.Digest.of({ entry("A", 1.000001) }, samples, 100)).to.equal(a)
		end)
	end)
end
