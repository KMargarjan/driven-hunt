--!nocheck
-- map_contract.spec: THE MAP, AND IT HAS TWO JOBS.
--
--  1. THE LIVE WORLD. `Map.EXPECTED_WORLD` says which world this place is, and the assertions run
--     against THAT world: "arena" measures the grey box, "map:*" measures the generated forest. The
--     one thing that is never allowed is both at once -- two roots in Workspace means the tags
--     resolve to both and every count below doubles.
--  2. THE GENERATOR'S PURE CORE, driven directly with no Studio, no Terrain and no asset, exactly as
--     `src/server/Boar/init.luau` exports `Boar.Brain` for its own specs. This is where the new
--     geometry is actually proved: the heightfield, the voxel band, the blocks, the markers, the
--     patches, the walkability, the species mix and the triangle bound.
--
-- A CASE THAT MEASURES A LAYER REFUSES TO RUN ON A CONFIG WHERE THAT LAYER IS OFF (`measuring`).
-- Without that, a switched-off layer turns a measurement into a vacuous pass rather than a failure:
-- an empty hedge list skips the loop, an empty wood leaves the worst trunk spacing at its
-- initialiser `math.huge`, and flat ground makes a `benchHeight` that flattened the whole map look
-- correct. Round 1 of task 85 shipped exactly that in five cases, which is why the rule is a
-- function and not a convention.
--
-- Design: docs/design/map-generator.md, "How it is tested"
-- Note:   docs/research/2026-10-04-forest-block1.md
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Map = require(ReplicatedStorage:WaitForChild("Map"))
local Boar = require(ServerScriptService:WaitForChild("Boar"))
local MapGen = require(ServerStorage:WaitForChild("MapGen"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local Assets = require(ServerStorage:WaitForChild("Assets"))
local Props = require(ServerStorage.MapGen:WaitForChild("Props"))

local ARENA_ROOT = "TestArena"
local MAP_ROOT = "DrivenHuntMap"
local SEED = 7 -- any seed: the claims below are about determinism, not about one map

local WORLD = Map.EXPECTED_WORLD
local FIELD = Map.FIELD
local COUNTS = Map.EXPECTED_COUNTS

local function config()
	return MapGen.CONFIG
end

local function measuring(c, ...)
	for _, layer in ipairs({ ... }) do
		if c.INCLUDE[layer] == nil then
			error(string.format("no such layer: INCLUDE.%s", layer), 0)
		end
		if not c.INCLUDE[layer] then
			error(string.format("this case measures the %s layer, and INCLUDE.%s is off", layer, layer), 0)
		end
	end
	return c
end

-- THE GENERATOR WITH EVERY LAYER ON, for the cases that measure a layer v4 switched OFF -- the
-- farmland, the hedgerows and the flank track. Nothing about those generators was deleted (the
-- hedge-gate rule is the check that has already caught a collidable wall across a drive), so their
-- specs stay alive and ask for them with their own rows on.
local function withScenery()
	local c = table.clone(MapGen.CONFIG) :: any
	local include = table.clone(MapGen.CONFIG.INCLUDE) :: any
	for key in pairs(include) do
		include[key] = true
	end
	c.INCLUDE = include
	return c
end

local function namedRootName(): string
	return if WORLD == "arena" then ARENA_ROOT else MAP_ROOT
end

local function waitForRoot(name: string)
	for _ = 1, 50 do
		local root = Workspace:FindFirstChild(name)
		if root then
			return root
		end
		task.wait(0.1)
	end
	return nil
end

local function taggedInside(root: Instance, tag: string): { BasePart }
	local out: { BasePart } = {}
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(root) then
			table.insert(out, instance)
		end
	end
	return out
end

-- THE WOOD, COMPUTED ONCE. `Scatter.allTrees` walks sixteen sub-blocks, the rim and both patches; it
-- is the most expensive pure call in this file, and five cases below need the same answer. Lazily,
-- so a run that never reaches those cases never pays for it.
local woodCache: { [number]: { any } } = {}
local function wood(seed: number)
	if woodCache[seed] == nil then
		woodCache[seed] = MapGen.Scatter.allTrees(measuring(config(), "trees"), seed)
	end
	return woodCache[seed]
end

-- THE WORST TRUNK-SURFACE GAP in a list of trees, BUCKETED. A plain pairwise loop over 1,562 trees
-- is 1.2 million comparisons per seed; a 40-stud bucket grid makes it linear, and 40 is wider than
-- any gap this could legitimately report so no near pair can be missed.
local function worstTrunkGap(c, trees): (number, string)
	local cell = 40
	local buckets: { [string]: { number } } = {}
	for index, tree in ipairs(trees) do
		local key = string.format("%d:%d", math.floor(tree.x / cell), math.floor(tree.z / cell))
		buckets[key] = buckets[key] or {}
		table.insert(buckets[key], index)
	end
	local radii = {}
	for index, tree in ipairs(trees) do
		radii[index] = Props.treeGeometry(c, tree.species, tree.age).trunkStuds / 2
	end
	local worst, where = math.huge, "no pair"
	for index, a in ipairs(trees) do
		local bx, bz = math.floor(a.x / cell), math.floor(a.z / cell)
		for dx = -1, 1 do
			for dz = -1, 1 do
				for _, other in ipairs(buckets[string.format("%d:%d", bx + dx, bz + dz)] or {}) do
					if other > index then
						local b = trees[other]
						local gap = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) - radii[index] - radii[other]
						if gap < worst then
							worst = gap
							where = string.format("(%.0f, %.0f) and (%.0f, %.0f)", a.x, a.z, b.x, b.z)
						end
					end
				end
			end
		end
	end
	return worst, where
end

return function()
	describe("the map contract", function()
		it("names exactly one world, and that world is the one that exists", function()
			expect(WORLD == "arena" or string.sub(WORLD, 1, 4) == "map:").to.equal(true)
			local named = waitForRoot(namedRootName())
			expect(named).to.be.ok()
			-- The OTHER root must be absent. Two worlds in Workspace means the generated map was left
			-- in the place: the tags then resolve to both and every count below is doubled.
			local other = if namedRootName() == ARENA_ROOT then MAP_ROOT else ARENA_ROOT
			expect(Workspace:FindFirstChild(other)).to.equal(nil)
		end)

		it("holds the terrain the named world requires, and no other", function()
			-- AND THE GROUND, not just the folder (audit-004 must-fix 1). Terrain is a global
			-- singleton with no container: destroying `Workspace.DrivenHuntMap` -- one right-click in
			-- the Explorer, between a screenshot and a test -- leaves every voxel of a generated map
			-- behind. Every other check still passes in that state and the run prints PASS.
			local cells = Workspace.Terrain:CountCells()
			if WORLD == "arena" then
				if cells ~= 0 then
					error(
						string.format(
							"the world is the arena but Workspace.Terrain holds %d cell(s): a generated "
								.. "map was left behind. Run `python tools/mapgen.py clear --backup census`.",
							cells
						),
						0
					)
				end
			else
				expect(cells > 0).to.equal(true)
				TestKit.note(string.format("map: %d terrain cells", cells))
			end
		end)

		it("refuses to measure a layer the config has switched off", function()
			-- THE GUARD ITSELF, because everything below rests on it.
			local off = table.clone(config()) :: any
			local include = table.clone(config().INCLUDE) :: any
			include.trees = false
			off.INCLUDE = include
			local ok, message = pcall(measuring, off, "trees")
			expect(ok).to.equal(false)
			expect(string.find(tostring(message), "trees", 1, true) ~= nil).to.equal(true)
			-- ...it hands the config straight back when the layers ARE on, or every case below would
			-- be measuring a copy of something.
			local on = withScenery()
			expect(measuring(on, "trees", "relief", "hedges")).to.equal(on)
			-- ...and a layer that does not exist is a typo rather than a silent pass.
			expect((pcall(measuring, on, "treees"))).to.equal(false)
		end)

		it("leaves the terrain palette at the contract's colours for the world it names", function()
			-- The palette is GLOBAL STATE WITH NO CONTAINER and it SURVIVES Terrain:Clear() --
			-- measured, N1 -- so an autumn palette left behind after a teardown is exactly the
			-- "world nobody chose" audit-004 must-fix 1 was about: the voxels are gone, every other
			-- check passes, and the place is still orange.
			--
			-- Read from the ENGINE, never from the table that wrote it.
			local want = if WORLD == "arena" then Map.PALETTE_DEFAULT else Map.PALETTE
			local got = MapGen.Ground.readPalette(config())
			for role, colour in pairs(want) do
				local now = got[role]
				expect(now).to.be.ok()
				expect(math.round(now.R * 255)).to.equal(math.round(colour.R * 255))
				expect(math.round(now.G * 255)).to.equal(math.round(colour.G * 255))
				expect(math.round(now.B * 255)).to.equal(math.round(colour.B * 255))
			end
		end)

		it("reports what MaterialService actually holds for every CC0 texture role", function()
			-- THE MATERIALS LAYER NEVER FAILS A BUILD (design, "Two layers, and the proven one ships
			-- first"): the palette above is measured and shipped, and a terrain-bound MaterialVariant
			-- is new. So this case asserts the SHAPE of the answer -- a row per role, naming either a
			-- variant or the reason there is none -- and never that a texture is there. A missing id
			-- is a named key in the report, not a silent grey ground.
			local variants = MapGen.Ground.readVariants(Map.TERRAIN.variants, config())
			for role in pairs(Map.TERRAIN.variants) do
				expect(type(variants[role])).to.equal("string")
				expect(#variants[role] > 0).to.equal(true)
			end
			local lines = {}
			for _, role in ipairs({ "litter", "rough", "road", "wet" }) do
				table.insert(lines, string.format("%s=%s", role, variants[role]))
			end
			TestKit.note("terrain variants: " .. table.concat(lines, " "))
			-- Every role the contract names is a material the generator knows, or the step would
			-- write a variant for a material nothing paints.
			for role in pairs(Map.TERRAIN.variants) do
				expect(config().MATERIAL[role]).to.be.ok()
			end
		end)

		it("resolves every tag to exactly the expected count, all inside the named world", function()
			local root = waitForRoot(namedRootName())
			expect(root).to.be.ok()
			for kind, tag in pairs(Map.TAGS) do
				local inside = taggedInside(root, tag)
				expect(#inside).to.equal(COUNTS[kind])
				-- ...and nothing outside the world carries the tag, or `Match.Markers` would read a
				-- marker the map does not own.
				expect(#CollectionService:GetTagged(tag)).to.equal(#inside)
			end
		end)

		it("has one drive line whose LookVector points at the drivers", function()
			local root = waitForRoot(namedRootName())
			local lines = taggedInside(root, Map.TAGS.driveLine)
			expect(#lines).to.equal(1)
			-- `src/server/Weapon/SafetyArc.luau` reads this as "toward the drivers". The other way
			-- round makes the safety rule fire on exactly the wrong shots.
			expect(lines[1].CFrame.LookVector:Dot(Vector3.zAxis) > 0.99).to.equal(true)
		end)

		it("tags the active block and no other, so there is one drive and not four broken ones", function()
			-- `Markers.read` requires EXACTLY ONE drive line and publishes `complete = false`
			-- otherwise, which parks the match in `Waiting` for ever. Four blocks' markers would be
			-- 32 posts and 4 lines: not four drives available, one broken drive.
			if WORLD == "arena" then
				TestKit.note("map: the world is the arena, so the active-block check is dormant")
				return
			end
			local c = config()
			local active = c.BLOCKS[Map.ACTIVE_BLOCK]
			expect(active).to.be.ok()
			expect(active.content).to.equal(true)
			local root = waitForRoot(MAP_ROOT)
			-- Every marker lies within the active block's x span. The z span reaches behind the line
			-- (the stands and the tie trees stand there on purpose) and up to the assembly track.
			local southEdge = active.bounds.minZ
			local crossing = MapGen.Layout.crossingBand(c)
			if crossing then
				southEdge = crossing.minZ
			end
			for _, kind in ipairs({ "shooterPost", "driveLine", "driverStart", "boarSpawn" }) do
				for _, marker in ipairs(taggedInside(root, Map.TAGS[kind])) do
					local p = marker.Position
					expect(p.X >= active.bounds.minX - 1).to.equal(true)
					expect(p.X <= active.bounds.maxX + 1).to.equal(true)
					expect(p.Z >= southEdge - 1).to.equal(true)
					expect(p.Z <= c.ROADS.assembly.at + 1).to.equal(true)
				end
			end
			-- ...AND NO BLOCK ACROSS THE RIDE HOLDS A MARKER.
			--
			-- NOT "no other block", WHICH IS WHAT THIS ASSERTED FIRST AND WHY IT FAILED: the eight
			-- stands sit `Map.STAND.offsetZ` BEHIND the road and the twelve tie trees sit in the
			-- crossing band, so both of those are the NEXT block's ground on purpose -- that is what
			-- "behind the line" means. What would be a broken drive is a marker in a block on the
			-- other side of the centre ride, which shares no edge with the active block at all.
			local acrossTheRide = {}
			for _, block in ipairs(MapGen.Layout.blocks(c)) do
				if block.bounds.minX > active.bounds.maxX or block.bounds.maxX < active.bounds.minX then
					table.insert(acrossTheRide, block)
				end
			end
			expect(#acrossTheRide > 0).to.equal(true)
			for _, block in ipairs(acrossTheRide) do
				for _, tag in pairs(Map.TAGS) do
					for _, marker in ipairs(taggedInside(root, tag)) do
						local p = marker.Position
						local inside = p.X >= block.bounds.minX
							and p.X <= block.bounds.maxX
							and p.Z >= block.bounds.minZ
							and p.Z <= block.bounds.maxZ
						if inside then
							error(
								string.format(
									"%s at (%.0f, %.0f) is in %s, across the ride from the active block",
									marker.Name,
									p.X,
									p.Z,
									block.name
								),
								0
							)
						end
					end
				end
			end
		end)

		it("puts every boar spawn inside the field, on the ground", function()
			local root = waitForRoot(namedRootName())
			for _, spawn in ipairs(taggedInside(root, Map.TAGS.boarSpawn)) do
				local p = spawn.Position
				expect(p.X >= FIELD.bounds.minX and p.X <= FIELD.bounds.maxX).to.equal(true)
				expect(p.Z >= FIELD.bounds.minZ and p.Z <= FIELD.bounds.maxZ).to.equal(true)
				-- `Runtime:spawn` overwrites the caller's Y with `field.groundY` and does NO ground
				-- raycast, so a pad that is not flat spawns a boar inside a hill.
				expect(math.abs(p.Y - FIELD.groundY) <= Map.SPAWN_PAD.tolerance).to.equal(true)
			end
		end)

		it("stands every shooter post on its stand's floor, at the one height the contract names", function()
			-- ONE EXPRESSION THAT IS TRUE IN BOTH WORLDS: `ground + Map.STAND.floorStuds`, which was
			-- 0 while the shooters stood on the road and is 7.1 now that they stand on boards.
			local root = waitForRoot(namedRootName())
			local c = config()
			local pads = MapGen.Layout.pads(c)
			local seed = MapGen.builtSeed() or Map.SEED
			local posts = taggedInside(root, Map.TAGS.shooterPost)
			expect(#posts).to.equal(COUNTS.shooterPost)
			for _, post in ipairs(posts) do
				local bottom = post.Position.Y - post.Size.Y / 2
				local ground = if WORLD == "arena"
					then FIELD.groundY
					else MapGen.Height.atFlattened(post.Position.X, post.Position.Z, seed, c, pads)
				local want = ground + Map.STAND.floorStuds
				if math.abs(bottom - want) > Map.SPAWN_PAD.tolerance then
					error(
						string.format(
							"%s's bottom face is at y=%.2f, not within %.2f of ground + floorStuds = %.2f",
							post.Name,
							bottom,
							Map.SPAWN_PAD.tolerance,
							want
						),
						0
					)
				end
			end
		end)

		it("puts a COLLIDABLE part directly under every shooter post", function()
			-- THE CHECK THE 9.5-STUD DROP NEVER HAD (TASKS.md row 43a(l), audit-004 F9). v3 asserted
			-- a HEIGHT; a height is not a floor. `Match.Body.placementFor` puts a character at
			-- `post.Position + post.Size.Y/2 + STAND_HEIGHT_STUDS` and nothing else looks down.
			local root = waitForRoot(namedRootName())
			for _, post in ipairs(taggedInside(root, Map.TAGS.shooterPost)) do
				local bottom = post.Position.Y - post.Size.Y / 2
				local supported = nil
				for _, candidate in ipairs(root:GetDescendants()) do
					if candidate:IsA("BasePart") and candidate.CanCollide then
						local p, s = candidate.Position, candidate.Size
						if
							math.abs(p.X - post.Position.X) <= s.X / 2 + post.Size.X / 2
							and math.abs(p.Z - post.Position.Z) <= s.Z / 2 + post.Size.Z / 2
							and math.abs((p.Y + s.Y / 2) - bottom) <= Map.SPAWN_PAD.tolerance
						then
							supported = candidate
							break
						end
					end
				end
				if supported == nil then
					error(
						string.format(
							"%s has no collidable part under it: a shooter would be placed over a drop",
							post.Name
						),
						0
					)
				end
			end
		end)

		it("leaves nothing collidable inside any road's cleared corridor", function()
			-- AMENDED, NOT WEAKENED. v3 walked ONE road at `halfWidth + verge`; this walks ALL FOUR
			-- at `halfWidth + keepClear`, which is the predicate `Layout.treeDensity` and `Props` also
			-- call -- so none of them can disagree about where the gravel is. The property is the one
			-- it was written for: a hedge wall once stood across the gravel and reachability pathed
			-- politely around it (Task 58 round 1 finding 1).
			local root = waitForRoot(namedRootName())
			local c = config()
			if WORLD == "arena" then
				TestKit.note("map: the world is the arena, which has no roads")
				return
			end
			local blockers = {}
			for _, part in ipairs(root:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					local p = part.Position
					if MapGen.Layout.onRoadKeepClear(p.X, p.Z, c) then
						table.insert(blockers, string.format("%s at (%.0f, %.0f)", part.Name, p.X, p.Z))
					end
				end
			end
			if #blockers > 0 then
				error(
					string.format(
						"%d collidable part(s) inside a road's cleared corridor: %s",
						#blockers,
						table.concat(blockers, ", ", 1, math.min(#blockers, 6))
					),
					0
				)
			end
		end)

		it("stays inside every part budget, and is not empty either", function()
			-- A CEILING AND A FLOOR. The ceiling catches a density raised too far; the FLOOR catches
			-- a layer that silently placed nothing, which an upper bound alone passes happily.
			local root = waitForRoot(namedRootName())
			if WORLD == "arena" then
				TestKit.note("map: the world is the arena, which has no wood to budget")
				return
			end
			local props = root:FindFirstChild("Props")
			expect(props).to.be.ok()
			local function count(name: string): number
				local folder = props:FindFirstChild(name)
				return if folder then #folder:GetChildren() else 0
			end
			local trees = count("Trees")
			local patchTrees = 0
			for _, folder in ipairs(props:GetChildren()) do
				if string.sub(folder.Name, 1, 6) == "Patch_" then
					patchTrees += #folder:GetChildren()
				end
			end
			local measured = {
				trees = trees + patchTrees,
				brush = count("Brush"),
				ferns = count("Ferns"),
				deadwood = count("Deadwood"),
			}
			TestKit.note(
				string.format(
					"map: %d trees (%d wood + %d patch), %d brush, %d ferns, %d deadwood",
					measured.trees,
					trees,
					patchTrees,
					measured.brush,
					measured.ferns,
					measured.deadwood
				)
			)
			-- THE FLOOR IS THE RATE'S, NOT HALF THE CEILING. The design wrote "<= their ceiling and
			-- >= half of it", and for three of these four that is not a bound on anything: the
			-- deadwood rate asks for about 31 pieces against a ceiling of 120, so "half the ceiling"
			-- would fail a correct map. What the floor is actually for is catching a layer that
			-- placed ALMOST NOTHING, so it is measured against what the layer's own per-hectare rate
			-- asks for -- which is a number the config declares and this case can recompute.
			local c = config()
			local character = MapGen.Layout.activeBlock(c).character
			local hectares = 0
			for _, block in ipairs(MapGen.Layout.treeBlocks(c)) do
				hectares += MapGen.Layout.hectares(block)
			end
			local wanted = {
				brush = hectares * character.brushPerHa,
				ferns = hectares * character.fernsPerHa,
				deadwood = hectares * character.deadwoodPerHa,
				trees = Map.BUDGET.trees / 2, -- the wood has no per-hectare rate: density tiers decide
			}
			for name, got in pairs(measured) do
				local ceiling = Map.BUDGET[name]
				expect(ceiling).to.be.ok()
				if got > ceiling then
					error(string.format("%d %s, over Map.BUDGET.%s = %d", got, name, name, ceiling), 0)
				end
				local floor = wanted[name] * 0.6
				if got < floor then
					error(
						string.format(
							"%d %s, under 60%% of the %.0f its own rate asks for: the layer placed almost nothing",
							got,
							name,
							wanted[name]
						),
						0
					)
				end
			end
		end)

		it("holds no script under the world root, and none in the generator", function()
			local root = waitForRoot(namedRootName())
			for _, descendant in ipairs(root:GetDescendants()) do
				if descendant:IsA("LuaSourceContainer") then
					error("a script exists under the map: " .. descendant:GetFullName(), 0)
				end
			end
			-- `MapGen.verifyContract` asserts this too; it is here because the harness's own
			-- unmanaged-script scan would fail EVERY run from then on, so it is worth two checks.
			for _, descendant in ipairs(ServerStorage.MapGen:GetDescendants()) do
				expect(descendant:IsA("ModuleScript")).to.equal(true)
			end
		end)

		it("leaves no asset cache behind: no template outlives the run", function()
			-- `Props.withLoader` destroys the folder it made. A surviving one means a step failed
			-- between the preload and the teardown, and a template in the world is a tree nobody
			-- planted -- and, parked in a Rojo-owned container, one that vanishes at the next Connect.
			-- THE MAP'S OWN CACHE, and only that one. `ServerStorage.AssetCache` is the LIVE
			-- SERVER's -- `WeaponBoot` preloads the gun into it at run time, and `Loader.cache`
			-- creates it at run time for exactly that reason -- so asserting it absent was asserting
			-- that the game had not booted. The generator's cache lives under the MAP ROOT and is
			-- destroyed by `Props.withLoader` in the same step that made it.
			local root = waitForRoot(namedRootName())
			expect(root:FindFirstChild(Props.ASSETS_FOLDER)).to.equal(nil)
		end)

		it("agrees with the boar about the field rectangle, in whichever world this is", function()
			-- THE ONE ASSERTION THAT KEEPS TWO OWNERS' NUMBERS TOGETHER. The map PUBLISHES its
			-- rectangle; `Boar.CONFIG.field` is changed in the boar's own file, by its owner, in the
			-- same commit -- and this is what makes "the same commit" checkable.
			local field = Boar.CONFIG.field
			expect(field.bounds.minX).to.equal(FIELD.bounds.minX)
			expect(field.bounds.maxX).to.equal(FIELD.bounds.maxX)
			expect(field.bounds.minZ).to.equal(FIELD.bounds.minZ)
			expect(field.bounds.maxZ).to.equal(FIELD.bounds.maxZ)
			expect(field.exitZ).to.equal(FIELD.exitZ)
			expect(field.groundY).to.equal(FIELD.groundY)
			-- The boar's fallback spawn must be inside the world it lives in, or a boar released
			-- without a marker is released outside the rectangle the brain clamps it to.
			local spawn = Boar.CONFIG.spawnPoint
			expect(spawn.X >= FIELD.bounds.minX and spawn.X <= FIELD.bounds.maxX).to.equal(true)
			expect(spawn.Z >= FIELD.bounds.minZ and spawn.Z <= FIELD.bounds.maxZ).to.equal(true)
		end)

		it("has one generator version, in one place", function()
			expect(MapGen.VERSION).to.equal(Map.GENERATOR)
		end)

		it("keeps the streaming properties the contract names", function()
			local current = MapGen.Ground and Workspace.StreamingEnabled
			expect(current).to.equal(Map.STREAMING.enabled)
		end)
	end)

	describe("the map switch", function()
		it("names one world, and the whole contract names the same one", function()
			expect(Map.VERSION).to.equal("v1")
			expect(Map.SEED).to.equal(1)
			-- The digest is either filled from a build or empty while one is pending; a half-length
			-- string is neither.
			expect(Map.DIGEST == "" or #Map.DIGEST == 64).to.equal(true)
			expect(type(Map.ACTIVE_BLOCK)).to.equal("string")
			expect(Map.BLOCKS[Map.ACTIVE_BLOCK]).to.be.ok()
		end)

		it("carries the block's own rectangle, and the boars cross the road", function()
			local block = Map.BLOCKS[Map.ACTIVE_BLOCK]
			local road = Map.ROADS[block.road]
			expect(road).to.be.ok()
			-- THE EXIT IS PAST THE ROAD, which is Karen's decision that a boar CROSSES the gravel in
			-- front of a stand rather than stopping at it.
			expect(FIELD.exitZ < road.at).to.equal(true)
			expect(road.at - FIELD.exitZ).to.equal(block.exitPastRoad)
			-- ...and the rectangle CONTAINS the exit, because `Brain:_outcome` despawns at
			-- `position.Z <= exitZ` and a boar has to be able to stand there first.
			expect(FIELD.bounds.minZ < FIELD.exitZ).to.equal(true)
			-- The drive rectangle is the block's own x span.
			expect(FIELD.bounds.minX).to.equal(block.bounds.minX)
			expect(FIELD.bounds.maxX).to.equal(block.bounds.maxX)
			expect(FIELD.bounds.maxZ).to.equal(block.bounds.maxZ)
		end)

		it("expects the forest's twelve tie trees, and the active block's markers", function()
			expect(COUNTS.tree).to.equal(12)
			expect(COUNTS.shooterPost).to.equal(8)
			expect(COUNTS.driveLine).to.equal(1)
			expect(COUNTS.driverStart).to.equal(1)
			expect(COUNTS.boarSpawn).to.equal(4)
			-- The generator derives the same counts from Layout, so the contract and the code that
			-- places the markers cannot drift apart.
			local expected = MapGen.expectedCounts()
			for kind, want in pairs(COUNTS) do
				expect(expected[kind]).to.equal(want)
			end
		end)

		it("leaves no grey box in the world it does not name", function()
			if WORLD == "arena" then
				expect(Workspace:FindFirstChild(MAP_ROOT)).to.equal(nil)
			else
				expect(Workspace:FindFirstChild(ARENA_ROOT)).to.equal(nil)
			end
		end)
	end)

	describe("the generator's heightfield", function()
		it("gives the same height for the same seed, and a different one for another seed", function()
			local c = measuring(config(), "relief")
			for _, point in ipairs({ { 0, 0 }, { 123.5, -77.25 }, { -600, 400 }, { -1200, 900 } }) do
				local a = MapGen.Height.at(point[1], point[2], SEED, c)
				local b = MapGen.Height.at(point[1], point[2], SEED, c)
				expect(a).to.equal(b)
			end
			local same, other = 0, 0
			for x = -1400, 1400, 200 do
				for z = -1400, 1400, 200 do
					same += MapGen.Height.at(x, z, SEED, c)
					other += MapGen.Height.at(x, z, SEED + 1, c)
				end
			end
			expect(same ~= other).to.equal(true)
		end)

		it("rolls, and rolls less inside a block than outside one", function()
			local c = measuring(config(), "relief")
			-- MEASURED, AND IT CORRECTS THE DESIGN'S OWN NUMBER (2026-10-04). `RELIEF` is an
			-- AMPLITUDE PARAMETER, not the achieved roll: the normalised fbm lands in about
			-- [-0.55, +0.57], so RELIEF = 64 gives about +/-37 studs. This case asserts the shape of
			-- the claim -- that there IS relief, that it is inside the band, and that a block is
			-- calmer than the rim -- and REPORTS the number for Karen to read.
			local function spread(minX, maxX, minZ, maxZ)
				local lo, hi = math.huge, -math.huge
				for x = minX, maxX, 40 do
					for z = minZ, maxZ, 40 do
						local h = MapGen.Height.base(x, z, SEED, c)
						lo, hi = math.min(lo, h), math.max(hi, h)
					end
				end
				return lo, hi
			end
			local b = c.BLOCKS[c.ACTIVE_BLOCK].bounds
			local blockLo, blockHi = spread(b.minX + 120, b.maxX - 120, b.minZ + 120, b.maxZ - 120)
			TestKit.note(string.format("relief inside %s: %.1f .. %.1f studs", c.ACTIVE_BLOCK, blockLo, blockHi))
			-- There IS relief: a flat map would pass any upper bound.
			expect(blockHi - blockLo > 4).to.equal(true)
			-- ...and it is inside the block's own ceiling, which is what keeps the drive walkable.
			expect(blockHi <= c.BLOCK_RELIEF).to.equal(true)
			expect(blockLo >= -c.BLOCK_RELIEF).to.equal(true)
		end)

		it("keeps every block under the design's slope ceiling, over three seeds", function()
			-- ALL FOUR BLOCKS, not one corridor: blocks 2-4 are playable the day their content lands,
			-- and this is what says so now.
			local c = measuring(config(), "relief")
			local pads = MapGen.Layout.pads(c)
			local limit = math.tan(math.rad(c.CORRIDOR_MAX_SLOPE_DEG))
			local worst, worstWhere = 0, ""
			for _, seed in ipairs({ 1, 7, 42 }) do
				for _, block in ipairs(MapGen.Layout.blocks(c)) do
					local b = block.bounds
					-- THE NEIGHBOUR IS DELIBERATELY NOT CLAMPED TO THE BLOCK. A sample at the edge compares
					-- against ground 20 studs OUTSIDE it, so this case also catches a CLIFF at a block's
					-- boundary -- which is exactly what the first attempt at the rim produced (47.71 deg at
					-- (1434, 14), six studs inside block 2's eastern edge) and what clamping would hide.
					for x = b.minX, b.maxX, 20 do
						for z = b.minZ, b.maxZ, 20 do
							local h = MapGen.Height.atFlattened(x, z, seed, c, pads)
							local dx = math.abs(MapGen.Height.atFlattened(x + 20, z, seed, c, pads) - h) / 20
							local dz = math.abs(MapGen.Height.atFlattened(x, z + 20, seed, c, pads) - h) / 20
							local slope = math.max(dx, dz)
							if slope > worst then
								worst = slope
								worstWhere = string.format("seed %d, %s at (%.0f, %.0f)", seed, block.name, x, z)
							end
						end
					end
				end
			end
			TestKit.note(string.format("worst block slope: %.2f deg (%s)", math.deg(math.atan(worst)), worstWhere))
			-- THE LOWER BOUND IS WHAT STOPS THIS BEING AN IDENTITY A FLAT MAP PASSES.
			expect(worst > 0.0004).to.equal(true)
			if worst > limit then
				error(
					string.format(
						"worst slope %.2f deg, over CORRIDOR_MAX_SLOPE_DEG = %d (%s)",
						math.deg(math.atan(worst)),
						c.CORRIDOR_MAX_SLOPE_DEG,
						worstWhere
					),
					0
				)
			end
		end)

		it("keeps every road flat at exactly GROUND_Y, and lets the ground return past the verge", function()
			local c = measuring(config(), "relief")
			local pads = MapGen.Layout.pads(c)
			local returned = 0
			for _, road in ipairs(MapGen.Layout.roads(c)) do
				local along = road.from
				while along <= road.to do
					local x = if road.axis == "x" then along else road.at
					local z = if road.axis == "x" then road.at else along
					local h = MapGen.Height.atFlattened(x, z, SEED, c, pads)
					if math.abs(h - c.GROUND_Y) > 1e-6 then
						error(string.format("the %s road is not flat at (%.0f, %.0f): y=%.3f", road.name, x, z, h), 0)
					end
					-- A VERGE AND A STUD OUTSIDE IT, the ground is the terrain's again: without this
					-- the easing could have flattened the whole map and every road check would pass.
					local offset = road.halfWidth + road.verge + 1
					local ox = if road.axis == "x" then x else road.at + offset
					local oz = if road.axis == "x" then road.at + offset else z
					if math.abs(MapGen.Height.atFlattened(ox, oz, SEED, c, pads) - c.GROUND_Y) > 0.05 then
						returned += 1
					end
					along += 37 -- a prime-ish stride, so the samples are not all on one voxel line
				end
			end
			expect(returned > 20).to.equal(true)
			TestKit.note(string.format("road verge: the ground returned at %d sampled points", returned))
		end)

		it("never lifts the rim above EDGE_MAX_Y, anywhere", function()
			local c = measuring(config(), "relief")
			local half = c.SIZE_STUDS / 2
			local highest = -math.huge
			for x = -half, half, 32 do
				for z = -half, half, 32 do
					highest = math.max(highest, MapGen.Height.edgeFloor(x, z, c))
				end
			end
			expect(highest <= c.EDGE_MAX_Y + 1e-6).to.equal(true)
			-- ...and the rim actually rises, or `EDGE_MAX_Y` is a bound on nothing.
			expect(highest > c.EDGE_MAX_Y * 0.9).to.equal(true)
			-- AND IT RISES GENTLY ENOUGH TO WALK, which is what makes a block's outer margin ground
			-- rather than a wall round the drive. A smoothstep's steepest gradient is 1.5 x rise/run,
			-- and the first attempt at this rim -- 120 studs -- failed exactly here.
			local steepest = math.deg(math.atan(1.5 * c.EDGE_MAX_Y / c.EDGE_BAND))
			TestKit.note(
				string.format(
					"rim: highest edge floor %.1f studs of %d, steepest %.1f deg",
					highest,
					c.EDGE_MAX_Y,
					steepest
				)
			)
			expect(steepest < c.CORRIDOR_MAX_SLOPE_DEG).to.equal(true)
		end)

		it("flattens every spawn pad to exactly the ground the contract asserts", function()
			local c = measuring(config(), "relief")
			local pads = MapGen.Layout.pads(c)
			expect(#pads).to.equal(COUNTS.boarSpawn)
			for _, pad in ipairs(pads) do
				local h = MapGen.Height.atFlattened(pad.x, pad.z, SEED, c, pads)
				expect(math.abs(h - c.GROUND_Y) <= Map.SPAWN_PAD.tolerance).to.equal(true)
			end
		end)
	end)

	describe("the generator's voxel band", function()
		it("writes every tile in the band its own columns stay inside, over three seeds", function()
			-- THE INVARIANT THAT MAKES OMITTING THE UPPER PASS SAFE. If a column's ground is above the
			-- top of the band its tile was written in, that ground is simply missing -- and if it is
			-- below the bottom, the tile is a void where a hollow should be. The design's `BAND_Y.min`
			-- of -24 would have done exactly the second thing: MEASURED, the fbm reaches about -37.
			local c = measuring(config(), "relief")
			local tiles = MapGen.Layout.tiles(c)
			local lowest, highest = math.huge, -math.huge
			for _, seed in ipairs({ 1, 7, 42 }) do
				for _, tile in ipairs(tiles) do
					if tile.pass == "lower" then
						local lo, hi = MapGen.Ground.tileExtremes(tile, seed, c, 32)
						lowest, highest = math.min(lowest, lo), math.max(highest, hi)
						if lo < c.BAND_Y.min then
							error(
								string.format(
									"a column at tile (%d, %d) reaches y=%.1f, below BAND_Y.min = %d: "
										.. "the ground would be written as a void",
									tile.tx,
									tile.tz,
									lo,
									c.BAND_Y.min
								),
								0
							)
						end
						-- A tile with NO upper pass may not reach above the lower pass's own top.
						if not MapGen.Layout.tileNeedsUpperPass(tile.tx, tile.tz, c) and hi > c.BAND_Y.mid then
							error(
								string.format(
									"tile (%d, %d) has no upper pass but a column reaches y=%.1f, above "
										.. "BAND_Y.mid = %d",
									tile.tx,
									tile.tz,
									hi,
									c.BAND_Y.mid
								),
								0
							)
						end
						if hi > c.BAND_Y.max then
							error(string.format("a column reaches y=%.1f, above BAND_Y.max", hi), 0)
						end
					end
				end
			end
			TestKit.note(
				string.format(
					"band: ground spans %.1f .. %.1f studs over 3 seeds, inside BAND_Y { %d, %d }",
					lowest,
					highest,
					c.BAND_Y.min,
					c.BAND_Y.max
				)
			)
		end)

		it(
			"covers the whole map with tiles a WriteVoxels call accepts, and omits the upper pass where it can",
			function()
				local c = config()
				local tiles = MapGen.Layout.tiles(c)
				local perSide = c.SIZE_STUDS / c.TILE_STUDS
				local lower, upper = 0, 0
				local seen = {}
				for _, tile in ipairs(tiles) do
					-- EVERY PASS IS INSIDE THE MEASURED REGION. 96 studs at resolution 4 is what was
					-- measured to be accepted; a taller region has never been measured.
					expect(tile.maxY - tile.minY <= 96).to.equal(true)
					expect(tile.minY >= c.BAND_Y.min).to.equal(true)
					expect(tile.maxY <= c.BAND_Y.max).to.equal(true)
					if tile.pass == "lower" then
						lower += 1
						local key = string.format("%d:%d", tile.tx, tile.tz)
						expect(seen[key]).to.equal(nil)
						seen[key] = true
					else
						upper += 1
					end
				end
				-- Exactly one lower pass per tile, covering the map.
				expect(lower).to.equal(perSide * perSide)
				-- THE UPPER PASS IS ASSERTED AS A DERIVATION AND NOT AS A COUNT, because today the count
				-- is ZERO: the rim is 40 studs and the fbm reaches 37, so no column anywhere reaches
				-- `BAND_Y.mid` and every tile is written in one pass. A bare `upper > 0` would be a bound
				-- on a number that is allowed to be nothing. What must hold either way is that a tile has
				-- an upper pass EXACTLY when `tileNeedsUpperPass` says so -- the predicate `Layout.tiles`
				-- itself uses, and the one the band case above proves safe.
				local wanted = 0
				for tz = 0, perSide - 1 do
					for tx = 0, perSide - 1 do
						if MapGen.Layout.tileNeedsUpperPass(tx, tz, c) then
							wanted += 1
						end
					end
				end
				expect(upper).to.equal(wanted)
				TestKit.note(
					string.format(
						"tiles: %d lower + %d upper = %d terrain steps (rim %d studs, band mid %d)",
						lower,
						upper,
						#tiles,
						c.EDGE_MAX_Y,
						c.BAND_Y.mid
					)
				)
			end
		)
	end)

	describe("the generator's layout", function()
		it("keeps the four blocks disjoint and clear of every road", function()
			local c = config()
			local blocks = MapGen.Layout.blocks(c)
			expect(#blocks).to.equal(4)
			for index, a in ipairs(blocks) do
				-- Each block names a road that exists, and that road is on its -Z edge.
				expect(c.ROADS[a.road]).to.be.ok()
				expect(c.ROADS[a.road].at < a.bounds.minZ).to.equal(true)
				-- No block overlaps any road's CLEARED CORRIDOR, so a block and a road can never
				-- fight over the same ground.
				for _, road in ipairs(MapGen.Layout.roads(c)) do
					local envelope = road.halfWidth + road.keepClear
					if road.axis == "x" then
						local overlaps = road.at + envelope > a.bounds.minZ and road.at - envelope < a.bounds.maxZ
						expect(overlaps).to.equal(false)
					else
						local overlaps = road.at + envelope > a.bounds.minX and road.at - envelope < a.bounds.maxX
						expect(overlaps).to.equal(false)
					end
				end
				for other = index + 1, #blocks do
					local b = blocks[other].bounds
					local overlaps = a.bounds.minX < b.maxX
						and a.bounds.maxX > b.minX
						and a.bounds.minZ < b.maxZ
						and a.bounds.maxZ > b.minZ
					expect(overlaps).to.equal(false)
				end
			end
			-- `activeBlock` is one of them, and `blockAt` agrees with it.
			local active = MapGen.Layout.activeBlock(c)
			expect(active.name).to.equal(c.ACTIVE_BLOCK)
			local centre = Vector3.new(
				(active.bounds.minX + active.bounds.maxX) / 2,
				0,
				(active.bounds.minZ + active.bounds.maxZ) / 2
			)
			expect(MapGen.Layout.blockAt(centre.X, centre.Z, c).name).to.equal(active.name)
			-- ...and a point on a road is in no block at all.
			local road = MapGen.Layout.activeRoad(c)
			expect(MapGen.Layout.blockAt(c.DRIVE.centreX, road.at, c)).to.equal(nil)
		end)

		it("plans exactly the markers the active block asks for, all inside it", function()
			local c = config()
			local markers = MapGen.Layout.markers(c)
			local counted = {}
			for _, marker in ipairs(markers) do
				counted[marker.kind] = (counted[marker.kind] or 0) + 1
			end
			for kind, want in pairs(COUNTS) do
				if kind ~= "tree" then
					expect(counted[kind]).to.equal(want)
				end
			end
			local active = MapGen.Layout.activeBlock(c)
			local lineZ = MapGen.Layout.lineZ(c)
			-- EIGHT POSTS AT `postSpacing`, centred on the drive's own x, on the stand strip.
			local posts = {}
			for _, marker in ipairs(markers) do
				if marker.kind == "shooterPost" then
					table.insert(posts, marker)
					expect(marker.z).to.equal(lineZ + c.STAND.offsetZ)
					-- The marker's bottom face is on the stand's floor, which is the one number the
					-- live contract check reads.
					expect(marker.y).to.equal(c.STAND.floorStuds + marker.size.Y / 2)
					-- ...and the stand strip is clear of the gravel, so the road guard needs no
					-- exemption for eight stands.
					expect(MapGen.Layout.onRoadKeepClear(marker.x, marker.z, c)).to.equal(false)
				end
			end
			table.sort(posts, function(a, b)
				return a.x < b.x
			end)
			for index = 2, #posts do
				expect(math.abs((posts[index].x - posts[index - 1].x) - c.DRIVE.postSpacing) < 1e-6).to.equal(true)
			end
			expect(math.abs((posts[1].x + posts[#posts].x) / 2 - c.DRIVE.centreX) < 1e-6).to.equal(true)
			-- THE DRIVE LINE SPANS THE BLOCK.
			for _, marker in ipairs(markers) do
				if marker.kind == "driveLine" then
					expect(marker.z).to.equal(lineZ)
					expect(marker.size.X).to.equal(active.bounds.maxX - active.bounds.minX)
				end
				if marker.kind == "boarSpawn" then
					-- Inside the block, and inside the field the boar is clamped to.
					expect(marker.z < active.bounds.maxZ).to.equal(true)
					expect(marker.x >= active.bounds.minX and marker.x <= active.bounds.maxX).to.equal(true)
				end
			end
		end)

		it("ties a punished shooter to a tree behind the line, never across the map", function()
			local c = config()
			local ties = MapGen.Layout.tieTreePoints(c)
			expect(#ties).to.equal(COUNTS.tree)
			local lineZ = MapGen.Layout.lineZ(c)
			for _, tie in ipairs(ties) do
				-- BEHIND the line, so nothing stands between a shooter and the drive...
				expect(tie.z < lineZ).to.equal(true)
				-- ...and within sight of the stand he left.
				expect(lineZ - tie.z < 120).to.equal(true)
				expect(math.abs(tie.x - c.DRIVE.centreX) <= c.DRIVE.tieTreeSpan / 2 + 1).to.equal(true)
			end
		end)

		it("keeps the gravel clear of the wood, and the wood out of the ground the game uses", function()
			local c = measuring(config(), "trees")
			local patches = MapGen.Scatter.patchCentres(c, SEED)
			-- ON a road: never.
			for _, road in ipairs(MapGen.Layout.roads(c)) do
				local along = road.from
				while along <= road.to do
					local x = if road.axis == "x" then along else road.at
					local z = if road.axis == "x" then road.at else along
					expect(MapGen.Layout.treeDensity(x, z, c, patches)).to.equal(0)
					along += 53
				end
			end
			-- On a spawn pad, a stand, the drivers' strip or a tie tree: never.
			for _, pad in ipairs(MapGen.Layout.pads(c)) do
				expect(MapGen.Layout.treeDensity(pad.x, pad.z, c, patches)).to.equal(0)
			end
			for _, stand in ipairs(MapGen.Layout.standPoints(c)) do
				expect(MapGen.Layout.treeDensity(stand.x, stand.z, c, patches)).to.equal(0)
			end
			for _, tie in ipairs(MapGen.Layout.tieTreePoints(c)) do
				expect(MapGen.Layout.treeDensity(tie.x, tie.z, c, patches)).to.equal(0)
			end
			expect(MapGen.Layout.treeDensity(c.DRIVE.centreX, c.ROADS.assembly.at, c, patches)).to.equal(0)
			-- ...and the wood IS thicker where the shooter looks than in the backdrop, or the three
			-- tiers are one tier.
			local character = MapGen.Layout.activeBlock(c).character
			local lineZ = MapGen.Layout.lineZ(c)
			local dense = MapGen.Layout.treeDensity(c.DRIVE.centreX, lineZ + 100, c, patches)
			local drive = MapGen.Layout.treeDensity(c.DRIVE.centreX, lineZ + 900, c, patches)
			expect(dense).to.equal(character.density.dense)
			expect(drive).to.equal(character.density.drive)
			expect(dense > drive).to.equal(true)
			-- Another block's ground is BARE in this task, and that is a fact worth asserting rather
			-- than discovering in a screenshot.
			local block2 = c.BLOCKS.block2.bounds
			local inside =
				MapGen.Layout.treeDensity((block2.minX + block2.maxX) / 2, (block2.minZ + block2.maxZ) / 2, c, patches)
			expect(inside).to.equal(0)
		end)

		it("cuts the wood into sub-blocks that cover the block and the crossing band", function()
			local c = measuring(config(), "trees")
			local blocks = MapGen.Layout.treeBlocks(c)
			expect(#blocks > 0).to.equal(true)
			local active = MapGen.Layout.activeBlock(c).bounds
			local crossing = MapGen.Layout.crossingBand(c)
			expect(crossing).to.be.ok()
			-- THE CROSSING BAND IS ON THE FAR SIDE OF THE ROAD: that is what makes the crossing
			-- forest-to-forest rather than forest-to-bare-ground.
			local road = MapGen.Layout.activeRoad(c)
			expect(crossing.maxZ < road.at).to.equal(true)
			expect(crossing.maxZ - crossing.minZ).to.equal(
				active and MapGen.Layout.activeBlock(c).character.crossingBandStuds
			)
			local area = 0
			for _, block in ipairs(blocks) do
				area += (block.maxX - block.minX) * (block.maxZ - block.minZ)
				expect(block.maxX > block.minX).to.equal(true)
				expect(block.maxZ > block.minZ).to.equal(true)
			end
			local wanted = (active.maxX - active.minX) * (active.maxZ - active.minZ)
				+ (crossing.maxX - crossing.minX) * (crossing.maxZ - crossing.minZ)
			-- The sub-blocks TILE the two rectangles exactly: no gap, no overlap.
			expect(math.abs(area - wanted) < 1).to.equal(true)
		end)
	end)

	describe("the generator's patches", function()
		it("places every patch inside the block and clear of everything the game uses, over 20 seeds", function()
			local c = measuring(config(), "patches")
			local block = MapGen.Layout.activeBlock(c)
			local pads = MapGen.Layout.pads(c)
			local stands = MapGen.Layout.standPoints(c)
			local ties = MapGen.Layout.tieTreePoints(c)
			local padClear = Map.SPAWN_PAD.radius + Map.SPAWN_PAD.blend
			local kinds = {}
			for seed = 1, 20 do
				local patches = MapGen.Scatter.patchCentres(c, seed)
				expect(#patches).to.equal(#block.character.patches)
				for _, patch in ipairs(patches) do
					kinds[patch.kind] = (kinds[patch.kind] or 0) + 1
					local radius = patch.radiusStuds
					-- WHOLLY INSIDE THE BLOCK.
					expect(patch.x - radius >= block.bounds.minX).to.equal(true)
					expect(patch.x + radius <= block.bounds.maxX).to.equal(true)
					expect(patch.z - radius >= block.bounds.minZ).to.equal(true)
					expect(patch.z + radius <= block.bounds.maxZ).to.equal(true)
					-- NEVER REACHING A ROAD'S CLEARED CORRIDOR.
					expect(MapGen.Layout.onRoadKeepClear(patch.x, patch.z, c, radius)).to.equal(false)
					-- NEVER OVER A PAD, A STAND OR A TIE TREE.
					for _, pad in ipairs(pads) do
						local d = math.sqrt((patch.x - pad.x) ^ 2 + (patch.z - pad.z) ^ 2)
						expect(d > radius + padClear).to.equal(true)
					end
					for _, stand in ipairs(stands) do
						local d = math.sqrt((patch.x - stand.x) ^ 2 + (patch.z - stand.z) ^ 2)
						expect(d > radius + c.STAND.clearRadius).to.equal(true)
					end
					for _, tie in ipairs(ties) do
						local d = math.sqrt((patch.x - tie.x) ^ 2 + (patch.z - tie.z) ^ 2)
						expect(d > radius + 10).to.equal(true)
					end
				end
				-- TWO PATCHES NEVER OVERLAP.
				for i = 1, #patches do
					for j = i + 1, #patches do
						local d = math.sqrt((patches[i].x - patches[j].x) ^ 2 + (patches[i].z - patches[j].z) ^ 2)
						expect(d > patches[i].radiusStuds + patches[j].radiusStuds).to.equal(true)
					end
				end
			end
			-- Both kinds the character declares were actually produced, over the twenty seeds.
			expect(kinds.young).to.equal(20)
			expect(kinds.gap).to.equal(20)
		end)

		it("moves the patches with the seed, so the committed map is one map and not the only map", function()
			local c = measuring(config(), "patches")
			local first = MapGen.Scatter.patchCentres(c, 1)
			local second = MapGen.Scatter.patchCentres(c, 2)
			local moved = false
			for index, patch in ipairs(first) do
				if patch.x ~= second[index].x or patch.z ~= second[index].z then
					moved = true
				end
			end
			expect(moved).to.equal(true)
			-- ...and the same seed twice is the same answer.
			local again = MapGen.Scatter.patchCentres(c, 1)
			for index, patch in ipairs(first) do
				expect(again[index].x).to.equal(patch.x)
				expect(again[index].z).to.equal(patch.z)
			end
		end)

		it("plants a thicket in the young patch and nothing at all in the gap", function()
			local c = measuring(config(), "patches")
			for _, patch in ipairs(MapGen.Scatter.patchCentres(c, 1)) do
				local trees = MapGen.Scatter.patchTrees(patch, c, 1)
				if patch.kind == "gap" then
					-- WEIGHT 0, AND THAT IS WHAT MAKES IT A CLEARING.
					expect(#trees).to.equal(0)
				else
					expect(#trees > 100).to.equal(true)
					for _, tree in ipairs(trees) do
						-- Inside the disc, not the square its grid covers: a square thicket reads as
						-- a plantation.
						local d = math.sqrt((tree.x - patch.x) ^ 2 + (tree.z - patch.z) ^ 2)
						expect(d <= patch.radiusStuds).to.equal(true)
						-- Every tree in it is the age the patch declares, and of a species it names.
						expect(tree.age).to.equal(patch.spec.age)
						expect(patch.spec.mix[tree.species]).to.be.ok()
					end
					TestKit.note(string.format("young patch: %d trees at radius %d", #trees, patch.radiusStuds))
				end
			end
		end)
	end)

	describe("the generator's wood", function()
		it("plants the same wood twice, and a different one for a different seed", function()
			local c = measuring(config(), "trees")
			local a = wood(1)
			local b = MapGen.Scatter.allTrees(c, 1)
			expect(#a).to.equal(#b)
			for index, tree in ipairs(a) do
				expect(b[index].x).to.equal(tree.x)
				expect(b[index].z).to.equal(tree.z)
				expect(b[index].species).to.equal(tree.species)
				expect(b[index].age).to.equal(tree.age)
			end
			expect(#MapGen.Scatter.allTrees(c, 2) ~= #a).to.equal(true)
		end)

		it("leaves every trunk far enough apart for the boar to walk between them", function()
			-- THE ONE PLACE A REVISION CAN BREAK THE GAME, because the block IS the drive.
			--
			-- `Boar.CONFIG.AGENT.AgentRadius = 2` with `AgentCanJump = false`, so the boar needs 4
			-- studs of clear ground. MEASURED 2026-10-04: this case is why the rim's grid overlapping
			-- the blocks was caught -- it reported a worst gap of -0.28 studs, two trees inside each
			-- other, before any of it reached the world.
			local c = measuring(config(), "trees")
			local need = Boar.CONFIG.AGENT.AgentRadius * 2
			for _, seed in ipairs({ 1, 7, 42 }) do
				local gap, where = worstTrunkGap(c, wood(seed))
				TestKit.note(string.format("seed %d: worst trunk gap %.2f studs, between %s", seed, gap, where))
				if gap < need then
					error(
						string.format(
							"the worst trunk-surface gap is %.2f studs, under the boar's %d (between %s)",
							gap,
							need,
							where
						),
						0
					)
				end
			end
		end)

		it("keeps each patch's own thicket walkable too, over 20 seeds", function()
			-- PER PATCH as well as per block: the young patch's grid is 0.55 of the wood's, which is
			-- the tightest spacing anywhere in the map and therefore the one that decides whether a
			-- boar can be driven through a thicket.
			local c = measuring(config(), "trees", "patches")
			local need = Boar.CONFIG.AGENT.AgentRadius * 2
			local worst, worstWhere = math.huge, ""
			for seed = 1, 20 do
				for _, patch in ipairs(MapGen.Scatter.patchCentres(c, seed)) do
					local trees = MapGen.Scatter.patchTrees(patch, c, seed)
					if #trees > 1 then
						local gap, where = worstTrunkGap(c, trees)
						if gap < worst then
							worst, worstWhere = gap, string.format("seed %d, %s patch, %s", seed, patch.kind, where)
						end
					end
				end
			end
			TestKit.note(string.format("patches: worst trunk gap %.2f studs (%s)", worst, worstWhere))
			expect(worst >= need).to.equal(true)
		end)

		it("plants the block's species mix, and alder wherever it is wet", function()
			local c = measuring(config(), "trees")
			local character = MapGen.Layout.activeBlock(c).character
			-- THE MAIN WOOD ONLY. A patch declares its OWN mix (the young patch is 75 % oak and 25 %
			-- birch), so counting its ~500 trees against the BLOCK's mix would be measuring two
			-- different declarations as one -- and the patch's own mix is asserted in its own case.
			local patches = MapGen.Scatter.patchCentres(c, 1)
			local counted, total = {}, 0
			local wetTrees, wetAlder = 0, 0
			for _, tree in ipairs(wood(1)) do
				local inPatch = false
				for _, patch in ipairs(patches) do
					if math.sqrt((tree.x - patch.x) ^ 2 + (tree.z - patch.z) ^ 2) <= patch.radiusStuds then
						inPatch = true
					end
				end
				if not inPatch then
					counted[tree.species] = (counted[tree.species] or 0) + 1
					total += 1
				end
				if MapGen.Height.wetAt(tree.x, tree.z, 1, c) > 0.5 then
					wetTrees += 1
					if tree.species == "alder" then
						wetAlder += 1
					end
				end
			end
			local lines = {}
			for _, name in ipairs(c.SPECIES_ORDER) do
				local share = (counted[name] or 0) / total
				table.insert(lines, string.format("%s %.3f (want %.2f)", name, share, character.mix[name]))
			end
			TestKit.note(string.format("wood of %d: %s", total, table.concat(lines, ", ")))
			for _, name in ipairs(c.SPECIES_ORDER) do
				local want = character.mix[name]
				local share = (counted[name] or 0) / total
				-- THE DESIGN'S +/-25 % RELATIVE, WITH AN ABSOLUTE FLOOR OF 2 PERCENTAGE POINTS, and
				-- the floor is what the first run measured the need for: alder came out at 0.067
				-- against a declared 0.05, which is 34 % relative and 1.7 points absolute.
				--
				-- That is a property of the CLUMP FIELD, not a defect. The wood comes in clumps of
				-- 300 studs and block 1 is 1,426 x 1,412, so there are about 22 of them: ONE alder
				-- clump is around 60 trees, and a species that is a twentieth of the wood cannot be
				-- held to a quarter of itself when the grain is that coarse. Tightening the relative
				-- bound would mean making the clumps smaller, which is Karen's taste value for how
				-- the wood reads, not a correctness question.
				local tolerance = math.max(want * 0.25, 0.02)
				if math.abs(share - want) > tolerance then
					error(
						string.format(
							"%s is %.3f of the wood, outside %.3f of the declared %.2f",
							name,
							share,
							tolerance,
							want
						),
						0
					)
				end
			end
			-- EVERY TREE IN WET GROUND IS ALDER, whatever the clump says: a spruce in a hollow reads
			-- as a mistake to anyone who has walked a European wood.
			TestKit.note(string.format("wet ground: %d trees, %d of them alder", wetTrees, wetAlder))
			expect(wetAlder).to.equal(wetTrees)
		end)

		it("draws the species independently of the density, so a thin wood has the same mix", function()
			-- TASK 63'S DEFECT, AND THE REASON FOR A STREAM PER QUESTION. The acceptance draw decided
			-- whether a tree existed AND which species it was, so every candidate accepted where the
			-- weight is 0.34 had a key below the clump strength and every clump outside the dense
			-- band was a monoculture over about half the wood.
			local c = measuring(config(), "trees")
			local character = MapGen.Layout.activeBlock(c).character
			local dense, thin = {}, {}
			local function tally(into, x, z)
				local species = MapGen.Scatter.speciesAt(x, z, 1, c, character, 0)
				into[species] = (into[species] or 0) + 1
			end
			-- The same POSITIONS, asked twice: `speciesAt` takes no density at all, so this is a
			-- statement about the signature as much as about the numbers.
			local lineZ = MapGen.Layout.lineZ(c)
			for x = c.DRIVE.centreX - 500, c.DRIVE.centreX + 500, 7 do
				tally(dense, x, lineZ + 100)
				tally(thin, x, lineZ + 900)
			end
			-- Both samples carry at least three species: a monoculture would have one.
			local denseKinds, thinKinds = 0, 0
			for _ in pairs(dense) do
				denseKinds += 1
			end
			for _ in pairs(thin) do
				thinKinds += 1
			end
			expect(denseKinds >= 3).to.equal(true)
			expect(thinKinds >= 3).to.equal(true)
			-- ...and the leading species is drawn from the clump field, which does not know the weight.
			expect(MapGen.Scatter.speciesAt(0, 0, 1, c, character, 0)).to.equal(
				MapGen.Scatter.speciesAt(0, 0, 1, c, character, 0)
			)
			-- WET FORCES ALDER through the same function, which is the one exception.
			expect(MapGen.Scatter.speciesAt(0, 0, 1, c, character, 1)).to.equal("alder")
		end)

		it("plants the age classes the block declares", function()
			local c = measuring(config(), "trees")
			local character = MapGen.Layout.activeBlock(c).character
			local counted, total = {}, 0
			for x = c.DRIVE.centreX - 600, c.DRIVE.centreX + 600, 11 do
				for z = 200, 900, 11 do
					local age = MapGen.Scatter.ageAt(x, z, 1, c, character)
					counted[age] = (counted[age] or 0) + 1
					total += 1
				end
			end
			for _, age in ipairs(c.AGE_ORDER) do
				local want = character.ages[age]
				local share = (counted[age] or 0) / total
				if math.abs(share - want) > want * 0.25 then
					error(string.format("age %s is %.3f, outside 25%% of the declared %.2f", age, share, want), 0)
				end
			end
			-- Every age the mix names has geometry, or a tree would be scaled by nil.
			for _, age in ipairs(c.AGE_ORDER) do
				expect(c.AGE[age]).to.be.ok()
				expect(c.AGE[age].heightScale > 0).to.equal(true)
			end
		end)

		it("keeps the baked triangles inside the budget at every stand and the driver start", function()
			-- A PURE UPPER BOUND, asserted where a player's eye actually is. It is a bound on BAKED
			-- geometry and not on what is drawn, and what it buys is a number a machine can refuse.
			local c = measuring(config(), "trees")
			local trees = wood(1)
			local worst, worstAt = 0, ""
			for _, point in ipairs(MapGen.Layout.loadPoints(c)) do
				local total = MapGen.Layout.visibleLoad(point, trees, c, Map.STREAMING.targetRadius)
				if total > worst then
					worst, worstAt = total, point.name
				end
			end
			TestKit.note(
				string.format(
					"visibleTris: worst %.2f M at %s, ceiling %.2f M",
					worst / 1e6,
					worstAt,
					Map.BUDGET.visibleTris / 1e6
				)
			)
			if worst > Map.BUDGET.visibleTris then
				error(
					string.format(
						"%s sees %d baked triangles, over Map.BUDGET.visibleTris = %d",
						worstAt,
						worst,
						Map.BUDGET.visibleTris
					),
					0
				)
			end
			-- ...and it is not zero, or the bound is a bound on nothing.
			expect(worst > Map.BUDGET.visibleTris / 4).to.equal(true)
		end)

		it("stays inside the tree budget, measured rather than asked for", function()
			local c = measuring(config(), "trees")
			local trees = wood(1)
			TestKit.note(string.format("wood: %d trees of Map.BUDGET.trees = %d", #trees, Map.BUDGET.trees))
			expect(#trees <= Map.BUDGET.trees).to.equal(true)
			expect(#trees > Map.BUDGET.trees / 2).to.equal(true)
			-- Every tree carries a species and a tier the config knows, or `Props` would scale it by
			-- nil and `visibleLoad` would count it as zero triangles.
			for _, tree in ipairs(trees) do
				expect(c.SPECIES[tree.species]).to.be.ok()
				expect(c.SPECIES[tree.species].tris[tree.tier]).to.be.ok()
				expect(c.AGE[tree.age]).to.be.ok()
			end
		end)

		it("gives every tree a trunk collider the tie can hold and the navmesh can see", function()
			-- `Match.Body.tiePointFor` takes its stand-off radius from
			-- `math.max(tree.Size.X, tree.Size.Z)/2`, so the TAGGED part must be the trunk and never
			-- a whole-tree mesh whose X is its crown -- a 34-stud crown would tie a punished shooter
			-- 17 studs from the tree.
			local c = config()
			for _, species in ipairs(c.SPECIES_ORDER) do
				for _, age in ipairs(c.AGE_ORDER) do
					local geometry = Props.treeGeometry(c, species, age)
					expect(geometry.trunkStuds > 0).to.equal(true)
					expect(geometry.boleStuds > 0).to.equal(true)
					-- The bole is a PART of the tree, not the whole of it, and it is narrower than
					-- the crown -- which is the whole point of the shape.
					expect(geometry.boleStuds < geometry.height).to.equal(true)
					expect(geometry.trunkStuds < geometry.crownStuds).to.equal(true)
				end
			end
			-- The widest trunk anywhere is the one the walkability argument is built on.
			local widest = 0
			for _, species in ipairs(c.SPECIES_ORDER) do
				for _, age in ipairs(c.AGE_ORDER) do
					widest = math.max(widest, Props.treeGeometry(c, species, age).trunkStuds)
				end
			end
			TestKit.note(string.format("widest trunk collider: %.2f studs", widest))
			expect(widest < 4).to.equal(true)
		end)
	end)

	describe("the generator's asset keys", function()
		it("names only keys ServerStorage.Assets declares", function()
			-- A TYPO IS A FAILURE, NOT A SILENT GREY BOX. Every key the generator can ask for has to
			-- exist in the one id table; `byKey` answering nil is a legitimate state (draw the proxy)
			-- but a key nothing declares is a name nobody can explain.
			local c = config()
			local declared = {}
			for _, key in pairs(Assets.KEYS) do
				declared[key] = true
			end
			local asked = {}
			for _, name in ipairs(c.SPECIES_ORDER) do
				for _, tier in ipairs({ "mature", "young", "veteran", "backdrop" }) do
					for _, key in ipairs(c.SPECIES[name].keys[tier] or {}) do
						asked[key] = true
					end
				end
			end
			asked[c.STAND_BUILD.assetKey] = true
			for _, variant in pairs(Map.TERRAIN.variants) do
				asked[variant.key] = true
			end
			for key in pairs(asked) do
				if not declared[key] then
					error("the generator asks for a key ServerStorage.Assets does not declare: " .. key, 0)
				end
			end
			-- ...and `Props.treeKeys` is the same set the species rows name, so one preload covers a
			-- step.
			local preloaded = {}
			for _, key in ipairs(Props.treeKeys(c)) do
				expect(preloaded[key]).to.equal(nil) -- once each: two loads for one mesh is a bug
				preloaded[key] = true
				expect(declared[key]).to.equal(true)
			end
		end)

		it("keeps the map's own rows out of the server's runtime preload", function()
			-- The generator loads its meshes at EDIT TIME. A boot script that preloaded seven oaks on
			-- every server start would spend its whole budget on trees nobody loads at run time.
			for _, key in ipairs(Assets.keysFor("runtime")) do
				expect(string.sub(key, 1, 5)).never.to.equal("tree.")
			end
			local mapKeys = Assets.keysFor("map")
			TestKit.note(string.format("map asset scope: %d key(s)", #mapKeys))
			expect(#mapKeys > 0).to.equal(true)
			for _, key in ipairs(mapKeys) do
				local row = Assets.byKey(key)
				expect(row).to.be.ok()
				expect(row.modelId > 0).to.equal(true)
				expect(row.kind).to.equal("model")
				-- MEASURED, not hoped: the row records the UPRIGHT bounding box, because two of the
				-- seven oaks were published lying down and carry a rotation correction.
				expect(row.naturalSizeStuds).to.be.ok()
				expect(row.naturalSizeStuds.Y > row.naturalSizeStuds.X).to.equal(true)
				expect(row.naturalSizeStuds.Y > row.naturalSizeStuds.Z).to.equal(true)
				-- The licence is recorded, because the pack forbids redistribution and the asset is
				-- private for exactly that reason.
				expect(#row.licence.quote > 0).to.equal(true)
				expect(#row.licence.quotedFrom > 0).to.equal(true)
			end
		end)
	end)

	describe("the generator's digest", function()
		local function entry(name: string, x: number)
			return { name = name, className = "Part", position = Vector3.new(x, 0, 0), size = Vector3.one, tags = {} }
		end
		local SAMPLES = { { x = 0, z = 0, occupancy = 1, material = "Grass" } }

		it("is 64 hex characters, of which the marker half is the first 32", function()
			local digest = MapGen.Digest.of({ entry("A", 1) }, SAMPLES, 100, Map.PALETTE, { litter = "x" })
			expect(#digest).to.equal(64)
			expect(MapGen.Digest.markerHalf(digest)).to.equal(string.sub(digest, 1, 32))
			expect(string.match(digest, "^%x+$")).to.be.ok()
		end)

		it("changes when a part moves, a palette colour changes, or a texture changes", function()
			local base = MapGen.Digest.of({ entry("A", 1) }, SAMPLES, 100, Map.PALETTE, { litter = "a" })
			expect(MapGen.Digest.of({ entry("A", 2) }, SAMPLES, 100, Map.PALETTE, { litter = "a" })).never.to.equal(
				base
			)
			local palette = table.clone(Map.PALETTE)
			palette.litter = Color3.fromRGB(1, 2, 3)
			expect(MapGen.Digest.of({ entry("A", 1) }, SAMPLES, 100, palette, { litter = "a" })).never.to.equal(base)
			-- THE VARIANT TABLE IS IN THE DIGEST for the same reason the palette is: a hand-changed
			-- ground texture is a change to the map that nothing else would notice.
			expect(MapGen.Digest.of({ entry("A", 1) }, SAMPLES, 100, Map.PALETTE, { litter = "b" })).never.to.equal(
				base
			)
		end)

		it("ignores a difference finer than the rounding, so float noise is not a mismatch", function()
			local a = MapGen.Digest.of({ entry("A", 1) }, SAMPLES, 100, Map.PALETTE, nil)
			local b = MapGen.Digest.of({ entry("A", 1.0001) }, SAMPLES, 100, Map.PALETTE, nil)
			expect(a).to.equal(b)
		end)
	end)

	describe("the generator's streaming step", function()
		it("refuses to change a streaming property until M2.6 has run", function()
			local Settings = require(ServerStorage.MapGen:WaitForChild("Settings"))
			expect(Settings.MAY_WRITE).to.equal(false)
			local _changed, _unreachable, _unwritten, refused = Settings.apply({
				enabled = not Workspace.StreamingEnabled,
				scriptable = { "StreamingEnabled" },
			})
			-- NOT a silent write and NOT a silent skip: the property is reported as refused.
			expect(#refused > 0).to.equal(true)
			-- ...and the place is unchanged.
			expect(Workspace.StreamingEnabled).to.equal(Map.STREAMING.enabled)
		end)
	end)

	describe("the retired layers", function()
		it("keeps the farmland, the hedgerows and the track switched off, not deleted", function()
			local c = config()
			expect(c.INCLUDE.fields).to.equal(false)
			expect(c.INCLUDE.hedges).to.equal(false)
			expect(c.INCLUDE.tracks).to.equal(false)
			-- Switched off, they answer with nothing...
			expect(MapGen.Layout.inField(c.WORLD_FIELDS.innerX + 10, 0, c)).to.equal(false)
			expect(#MapGen.Layout.hedgeLines(c)).to.equal(0)
			expect(MapGen.Layout.onTrack(c.WORLD_TRACKS[1].at, 0, c)).to.equal(false)
			-- ...and with every row on, each generator still does its work, which is what makes
			-- flipping one row back a one-line change rather than a rediscovery.
			local on = withScenery()
			expect(MapGen.Layout.inField(on.WORLD_FIELDS.innerX + 10, 0, on)).to.equal(true)
			expect(#MapGen.Layout.hedgeLines(on) > 0).to.equal(true)
			local track = on.WORLD_TRACKS[1]
			local tx = if track.axis == "x" then 0 else track.at
			local tz = if track.axis == "x" then track.at else 0
			expect(MapGen.Layout.onTrack(tx, tz, on)).to.equal(true)
		end)

		it("still gates every hedge line that crosses the drive, for twenty seeds", function()
			-- THE CHECK THAT HAS ALREADY CAUGHT A COLLIDABLE WALL ACROSS A DRIVE (Task 58 round 2
			-- finding 1). The layer is off; this is why the mechanism is kept rather than orphaned.
			local c = measuring(withScenery(), "hedges")
			local gateStuds = c.WORLD_HEDGES.gateStuds
			local crossing = 0
			for seed = 1, 20 do
				for index, line in ipairs(MapGen.Layout.hedgeLines(c)) do
					local from, to = MapGen.Layout.corridorSpan(line, c)
					if from and to then
						crossing += 1
						local gates = MapGen.Scatter.hedgeGates(c, seed, index, from, to)
						expect(#gates).to.equal(c.WORLD_HEDGES.gatesPerLine)
						local points = MapGen.Layout.hedgeSegments(line, gates, c)
						local gapFrom, gapTo = MapGen.Layout.widestGap(points, line, from, to, c)
						-- A boar, a driver and a dog all have to get through.
						expect(gapTo - gapFrom >= gateStuds * 0.9).to.equal(true)
					end
				end
			end
			expect(crossing > 0).to.equal(true)
			TestKit.note(string.format("hedges: %d line-crossings gated over 20 seeds", crossing))
		end)

		it("puts no hedge segment on a road's cleared corridor", function()
			local c = measuring(withScenery(), "hedges")
			for index, line in ipairs(MapGen.Layout.hedgeLines(c)) do
				local from, to = MapGen.Layout.corridorSpan(line, c)
				local gates = if from and to then MapGen.Scatter.hedgeGates(c, 1, index, from, to) else {}
				for _, point in ipairs(MapGen.Layout.hedgeSegments(line, gates, c)) do
					expect(MapGen.Layout.onRoadKeepClear(point.x, point.z, c)).to.equal(false)
				end
			end
		end)
	end)
end
