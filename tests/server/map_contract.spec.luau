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
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
-- The placing step's own rejection predicate, so the scatter tests below assert what the generator
-- actually does rather than a copy of it.
local Props = require(ServerStorage.MapGen:WaitForChild("Props"))

-- ONE SHAPE FOR THE DIGEST'S FIXTURES, at file scope. The palette spec added in round 2 hand-rolled a
-- second entry table (`path`/`class`) and a second sample (`y`), while `Digest` reads `name`/
-- `className` and `occupancy` -- so it threw inside `string.format` instead of asserting anything,
-- and the harness caught it twice. A fixture that names the generator's own fields is worth exactly
-- one copy in this file.
local function digestEntry(name: string, x: number, y: number)
	return {
		name = name,
		className = "Part",
		position = Vector3.new(x, y, 2),
		size = Vector3.new(4, 4, 4),
		tags = { Map.TAGS.tree },
	}
end

local DIGEST_SAMPLES = { { x = 0, z = 0, occupancy = 1, material = "Grass" } }

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
			-- The OTHER root must be absent. Two worlds in Workspace means the generated map was left
			-- in the place: the tags then resolve to both and every count below is doubled.
			local other = if namedRootName() == ARENA_ROOT then MAP_ROOT else ARENA_ROOT
			expect(Workspace:FindFirstChild(other)).to.equal(nil)
		end)

		it("holds the terrain the named world requires, and no other", function()
			-- AND THE GROUND, not just the folder (audit-004 must-fix 1). Terrain is a global singleton
			-- with no container: destroying `Workspace.DrivenHuntMap` -- one right-click in the
			-- Explorer, between a screenshot and a test -- leaves all 6.3 M voxels of a generated map
			-- behind. Every check above still passes in that state, the arena's plate sits buried in a
			-- hillside, and the run prints PASS. A world check that names a folder and ignores the
			-- ground is the audit this project already paid for once.
			local cells = Workspace.Terrain:CountCells()
			if Map.EXPECTED_WORLD == "arena" then
				-- The arena is built from parts on a flat plate at y = 0 and writes no terrain at all.
				if cells ~= 0 then
					error(
						string.format(
							"the world is the arena but Workspace.Terrain holds %d cell(s): a generated map "
								.. "was left behind. Run `python tools/mapgen.py clear --backup census`.",
							cells
						),
						0
					)
				end
			else
				-- The generated map IS terrain; an empty one means the folder outlived its ground.
				expect(cells > 0).to.equal(true)
			end
		end)

		it("leaves the terrain palette at the contract's colours for the world it names", function()
			-- Round 2, finding 3, and design section 16.1 check 5. The palette is GLOBAL STATE WITH
			-- NO CONTAINER and it SURVIVES Terrain:Clear() -- measured, N1 -- so an autumn palette
			-- left behind after a teardown is exactly the "world nobody chose" audit-004 must-fix 1
			-- was about: the voxels are gone, every other check passes, and the place is still orange.
			--
			-- Read from the ENGINE, never from the table that wrote it.
			local want = if Map.EXPECTED_WORLD == "arena" then Map.PALETTE_DEFAULT else Map.PALETTE
			local got = MapGen.Ground.readPalette(MapGen.CONFIG)
			for role, colour in pairs(want) do
				local now = got[role]
				expect(now).to.be.ok()
				local dr = math.abs(math.round(now.R * 255) - math.round(colour.R * 255))
				local dg = math.abs(math.round(now.G * 255) - math.round(colour.G * 255))
				local db = math.abs(math.round(now.B * 255) - math.round(colour.B * 255))
				if math.max(dr, dg, db) > 0 then
					error(
						string.format(
							"the %s material is (%d, %d, %d) but the %s world wants (%d, %d, %d). "
								.. "Run `python tools/mapgen.py clear --backup census`.",
							role,
							math.round(now.R * 255),
							math.round(now.G * 255),
							math.round(now.B * 255),
							Map.EXPECTED_WORLD,
							math.round(colour.R * 255),
							math.round(colour.G * 255),
							math.round(colour.B * 255)
						),
						0
					)
				end
			end
			-- And the two tables are genuinely different, or the assertion above is vacuous.
			expect(MapGen.Digest.paletteText(Map.PALETTE)).never.to.equal(
				MapGen.Digest.paletteText(Map.PALETTE_DEFAULT)
			)
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
				-- The BOAR's agent params, not an imaginary one: this asserts the world is playable for
				-- the animal that actually walks it.
				--
				-- RETRIED, because the navmesh is built in the BACKGROUND and this spec can run before
				-- it is ready. Measured in Edit (research note, measurement G): a change to the world
				-- still answered with the old navmesh one second later and the new one after five. The
				-- arena is built by ArenaBoot at server start, moments before this runs, so the first
				-- attempt can legitimately say NoPath about a world that is walkable.
				--
				-- This is the cause of TASKS.md row 43a(j): twice, on an unchanged tree, a run reported
				-- "[harness] FAIL: 25/27" -- which is exactly the two [server] status checks, i.e. ONE
				-- server spec failing -- and every rerun passed. The check arrived with this file in
				-- Task 43, and the flake arrived with it.
				--
				-- The claim is NOT weakened: a world with no route still fails, it just takes 10 s to
				-- say so instead of one.
				local status, waypoints = "never computed", 0
				local deadline = os.clock() + 10
				repeat
					local path = PathfindingService:CreatePath(Boar.CONFIG.AGENT)
					local ok = pcall(function()
						path:ComputeAsync(from + Vector3.new(0, 2, 0), target)
					end)
					status = if ok then tostring(path.Status) else "ComputeAsync raised"
					waypoints = if ok then #path:GetWaypoints() else 0
					if status ~= "Enum.PathStatus.Success" then
						task.wait(1)
					end
				until status == "Enum.PathStatus.Success" or os.clock() > deadline
				if status ~= "Enum.PathStatus.Success" then
					error(
						string.format("no path from (%d, %d) to the drive line after 10 s: %s", from.X, from.Z, status),
						0
					)
				end
				expect(waypoints >= 2).to.equal(true)
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
			local worst, worstCorridor, worstInland = 0, 0, 0
			-- THE WHOLE MAP, not just the middle: at 2048 studs a +/- 250 sample is entirely inside the
			-- drive corridor, so `worst` and `worstCorridor` were the same number and the whole-map
			-- relief bound could not fail (review round 1 of Task 44).
			--
			-- AND IT NOW SAMPLES TO +/-1024, THE REAL EDGE (round 2, finding 5). At +/-1000 the outer
			-- ring sat 24 studs inside the map, where `edgeFloor` reads 37.6 -- 2.4 studs under
			-- RELIEF = 40 by sampling luck alone. The rim genuinely reaches EDGE_MAX_Y = 44 at the
			-- boundary, so the old assertion was false of the map and true only of the lattice.
			local half = c.SIZE_STUDS / 2
			for x = -half, half, 32 do
				for z = -half, half, 32 do
					local h = math.abs(MapGen.Height.at(x, z, SEED, c) - c.GROUND_Y)
					worst = math.max(worst, h)
					if MapGen.Layout.inCorridor(x, z, c) then
						worstCorridor = math.max(worstCorridor, h)
					end
					-- Away from the rim the noise alone must stay inside RELIEF: that is the number
					-- Karen owns, and the edge floor must not be allowed to hide a change to it.
					if math.min(half - math.abs(x), half - math.abs(z)) > c.EDGE_BAND then
						worstInland = math.max(worstInland, h)
					end
				end
			end
			expect(worstInland <= c.RELIEF).to.equal(true)
			expect(worst <= math.max(c.RELIEF, c.EDGE_MAX_Y)).to.equal(true)
			expect(worstCorridor <= c.CORRIDOR_RELIEF).to.equal(true)
			-- Well inside the boar's fall limit, which is what makes this terrain safe for it.
			expect(worst < 50).to.equal(true)
			-- ...and the rim really is raised, or `worst <= EDGE_MAX_Y` is a bound on nothing.
			expect(worst > c.RELIEF).to.equal(true)
		end)

		it("changes the digest when a palette colour changes", function()
			-- Round 1 claimed "a hand-edited colour changes the digest" and nothing ran the fourth
			-- argument at all: every digest spec passed three, so `paletteText(nil)` returned "".
			-- A recolour is a change to the map that the voxels and the markers cannot see.
			local one = { digestEntry("A", 0, 1) }
			local samples = DIGEST_SAMPLES
			local autumn = MapGen.Digest.of(one, samples, 100, Map.PALETTE)
			local defaults = MapGen.Digest.of(one, samples, 100, Map.PALETTE_DEFAULT)
			expect(autumn).never.to.equal(defaults)
			-- ...the same palette twice is the same digest,
			expect(MapGen.Digest.of(one, samples, 100, Map.PALETTE)).to.equal(autumn)
			-- ...ONE channel of ONE role is enough to move it,
			local nudged = {
				litter = Color3.fromRGB(151, 108, 62),
				rough = Map.PALETTE.rough,
				road = Map.PALETTE.road,
				bog = Map.PALETTE.bog,
			}
			expect(MapGen.Digest.of(one, samples, 100, nudged)).never.to.equal(autumn)
			-- ...and no palette at all is a third, distinct answer rather than a silent match.
			expect(MapGen.Digest.of(one, samples, 100)).never.to.equal(autumn)
			-- The text itself is sorted and 8-bit, so two runs agree.
			expect(MapGen.Digest.paletteText(Map.PALETTE)).to.equal(
				"bog=96,82,62|litter=150,108,62|road=152,146,132|rough=126,122,78"
			)
		end)

		it("has one generator version, in one place", function()
			-- Claim 7 said row 44a(f) was closed by `MapGen.VERSION = Map.GENERATOR`; nothing asserted
			-- it, so a second copy could come back without a failing test (design 16.1 check 10).
			expect(MapGen.VERSION).to.equal(Map.GENERATOR)
			expect(type(Map.GENERATOR)).to.equal("string")
			expect(#Map.GENERATOR > 0).to.equal(true)
		end)

		it("derives every bench from the contract, never from a second copy", function()
			-- Round 2, finding 2: Map.ROAD/Map.ASSEMBLY were added to the contract and read by
			-- nothing, while Config re-declared the same five numbers. This is what makes the
			-- contract the source rather than a comment claiming it is.
			local c = config()
			local byName = {}
			for _, bench in ipairs(c.WORLD.benches) do
				byName[bench.name] = bench
			end
			for name, contract in pairs({ road = Map.ROAD, assembly = Map.ASSEMBLY }) do
				local bench = byName[name]
				expect(bench).to.be.ok()
				expect(bench.at).to.equal(contract.z)
				expect(bench.halfWidth).to.equal(contract.halfWidth)
				expect(bench.verge).to.equal(contract.verge)
				expect(bench.from).to.equal(contract.from)
				expect(bench.to).to.equal(contract.to)
			end
		end)

		it("keeps the drive corridor under the design's slope ceiling", function()
			local c = config()
			local pads = MapGen.Layout.pads(c)
			local corridor = c.WORLD.corridor
			local limit = math.tan(math.rad(c.CORRIDOR_MAX_SLOPE_DEG))
			-- The check `Config.CORRIDOR_MAX_SLOPE_DEG` promised and nothing performed until Task 45.
			-- It measures the SHIPPED ground -- pads flattened, bog dug -- because that is what a boar
			-- walks, and the pad easing, not the noise, is what made this fail when it was first run:
			-- a 16-stud drop eased over 24 studs is a 22.5-degree ring around every post and spawn.
			--
			-- The step is 8 studs, one voxel wider than the terrain's own resolution, so a slope is
			-- measured across ground the engine actually builds rather than between two samples of a
			-- smooth function.
			local step = 8
			local worst, worstAt = 0, ""
			-- THREE seeds since M2.8a (TASKS.md row 45a(e)): 12.94 against a 15 ceiling on two seeds
			-- was ~14% headroom on a seed-dependent number. Measurement N4 read 11.60 / 12.36 / 10.31
			-- degrees on seeds 1-3 with the road benches in.
			for _, seed in ipairs({ SEED, SEED + 1, SEED + 2 }) do
				for x = corridor.minX, corridor.maxX, 20 do
					for z = corridor.minZ, corridor.maxZ, 20 do
						local h = MapGen.Height.atFlattened(x, z, seed, c, pads, MapGen.Layout.bogDepth)
						local dx =
							math.abs(MapGen.Height.atFlattened(x + step, z, seed, c, pads, MapGen.Layout.bogDepth) - h)
						local dz =
							math.abs(MapGen.Height.atFlattened(x, z + step, seed, c, pads, MapGen.Layout.bogDepth) - h)
						local slope = math.max(dx, dz) / step
						if slope > worst then
							worst, worstAt = slope, string.format("seed %d at (%d, %d)", seed, x, z)
						end
					end
				end
			end
			if worst > limit then
				error(
					string.format(
						"the corridor reaches %.2f degrees (%s), over the %d the design allows",
						math.deg(math.atan(worst)),
						worstAt,
						c.CORRIDOR_MAX_SLOPE_DEG
					),
					0
				)
			end
			-- And it is not trivially flat, or the assertion above would be worth nothing.
			expect(worst > 0.02).to.equal(true)
		end)

		it("never lifts the edge floor above EDGE_MAX_Y, anywhere", function()
			-- Design section 16.1's Height row, and the reason EDGE_MAX_Y is 44 rather than 48: the
			-- voxel band BAND_Y is {-48, +48}, and the tile size measurement A proved depends on the
			-- terrain fitting inside it. A floor that overshot would silently change the tiling.
			local c = config()
			local half = c.SIZE_STUDS / 2
			local worst = -math.huge
			for x = -half, half, 16 do
				for z = -half, half, 16 do
					local floor = MapGen.Height.edgeFloor(x, z, c)
					if floor > -math.huge then
						worst = math.max(worst, floor)
					end
				end
			end
			expect(worst <= c.GROUND_Y + c.EDGE_MAX_Y).to.equal(true)
			expect(worst <= c.BAND_Y.max).to.equal(true)
			-- and it does rise, or the bound above is vacuous
			expect(worst > c.GROUND_Y + c.EDGE_MAX_Y * 0.9).to.equal(true)
		end)

		it("keeps the road and the assembly track flat at exactly GROUND_Y", function()
			-- The one thing the whole revision stands on: everything the game puts a player or a boar
			-- on is at GROUND_Y, so Boar.CONFIG.field.groundY needs no change at the M2.5 switch and
			-- Body.placementFor's arithmetic lands on ground rather than in a hole.
			local c = config()
			local pads = MapGen.Layout.pads(c)
			for _, bench in ipairs(c.WORLD.benches) do
				local worst, worstAt = 0, 0
				for along = bench.from, bench.to, 10 do
					local x, z = along, bench.at
					if bench.axis ~= "x" then
						x, z = bench.at, along
					end
					local h = MapGen.Height.atFlattened(x, z, SEED, c, pads, MapGen.Layout.bogDepth)
					local off = math.abs(h - c.GROUND_Y)
					if off > worst then
						worst, worstAt = off, along
					end
				end
				if worst > 1e-6 then
					error(string.format("the %s bench is %.4f studs off GROUND_Y at %d", bench.name, worst, worstAt), 0)
				end
			end
		end)

		it("leaves the ground unflattened a verge away from a bench, so the easing cannot hide a bug", function()
			-- Without this, a benchHeight that flattened the WHOLE map would pass every other check
			-- here: the road would be flat, the pads would be flat, the slope would be zero.
			local c = config()
			local pads = MapGen.Layout.pads(c)
			local bench = c.WORLD.benches[1]
			local outside = bench.halfWidth + bench.verge + 1
			local differences = 0
			for x = -600, 600, 40 do
				local z = bench.at - outside
				local flattened = MapGen.Height.atFlattened(x, z, SEED, c, pads, MapGen.Layout.bogDepth)
				local raw = MapGen.Height.at(x, z, SEED, c, MapGen.Layout.bogDepth)
				if math.abs(flattened - raw) > 1e-6 then
					differences += 1
				end
			end
			expect(differences).to.equal(0)
		end)

		it("raises the map's rim but leaves the road's band flat where it runs off", function()
			-- MEASURED (N4): with the end distance in the suppression, the last 124 studs of the ride
			-- rose to 34.8 studs -- the ridge across the end of the road the design says the
			-- suppression exists to avoid. It is `across` only now, and this is what says so.
			local c = config()
			local pads = MapGen.Layout.pads(c)
			local bench = c.WORLD.benches[1]
			local atRim = MapGen.Height.atFlattened(1000, bench.at, SEED, c, pads, MapGen.Layout.bogDepth)
			expect(math.abs(atRim - c.GROUND_Y) < 0.5).to.equal(true)
			-- And the rim DOES rise away from the road, or the edge floor is doing nothing.
			local away = MapGen.Height.atFlattened(1000, 0, SEED, c, pads, MapGen.Layout.bogDepth)
			expect(away > c.GROUND_Y + 20).to.equal(true)
			-- ...and never past the voxel band the tile size was measured for.
			expect(away <= c.BAND_Y.max).to.equal(true)
		end)

		it("flattens every spawn pad to exactly the ground the contract asserts", function()
			local c = config()
			local pads = MapGen.Layout.pads(c)
			expect(#pads > 0).to.equal(true)
			for _, pad in ipairs(pads) do
				-- WITH `bogDepth`, as `Ground.writeTile` passes it (audit-004 F10). Omitting it asked a
				-- different question from the one the terrain answers, and the argument is optional, so
				-- nothing said so.
				expect(MapGen.Height.atFlattened(pad.x, pad.z, SEED, c, pads, MapGen.Layout.bogDepth)).to.equal(
					c.GROUND_Y
				)
			end
			-- And a pad eases back to the terrain rather than ending in a cliff: at the far edge of the
			-- blend the flattened height IS the raw height. One pad on its own, because the shooter
			-- posts stand `WORLD.postSpacing` studs apart and their pads overlap -- with the real list
			-- the point below is inside the next post's pad, which is intended and not this claim.
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
			-- AGAINST THE CONFIGURATION (audit-004 F2). This used to compare `total` with
			-- `planned + WORLD.tieTrees`, and `expectedCounts()` is built as exactly one per
			-- `Layout.markers` entry plus `tieTrees` -- the same arithmetic on the same data, true for
			-- any layout, right or wrong. It is the twin of the defect Task 44's round 1 caught in the
			-- test above this one, which was converted and this one was not.
			local fromConfig = c.WORLD.postCount -- shooterPost
				+ #c.WORLD.boarSpawnX -- boarSpawn
				+ 1 -- driveLine
				+ 1 -- driverStart
				+ c.WORLD.tieTrees -- tree
			expect(total).to.equal(fromConfig)
			expect(planned).to.equal(fromConfig - c.WORLD.tieTrees)
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
			-- And the map's field is the design's section 15.1 corridor, not whatever the code drifted
			-- to. These are the M2.8a numbers: 1,240 studs wide, to hold a 1,120-stud shooter line at
			-- Karen's 45 m spacing, with the exit 120 studs PAST the road so a boar that beats the
			-- line crosses the gravel and is gone.
			expect(b.minX).to.equal(-620)
			expect(b.maxX).to.equal(620)
			expect(b.minZ).to.equal(-880)
			expect(b.maxZ).to.equal(800)
			expect(c.FIELD.exitZ).to.equal(-820)
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

	describe("the generator's streaming step", function()
		local Settings = require(ServerStorage.MapGen:WaitForChild("Settings"))

		-- audit-004 F4. The build's last step calls `Settings.apply(Map.STREAMING)`, and that is the
		-- one step that changes a place setting for every existing system. It is inert today only
		-- because the contract happens to match the place -- so a one-character edit to the contract
		-- would make M2.6's change, without M2.6's playtest, during an M2.3 build.
		it("refuses to change a streaming property until M2.6 has run", function()
			-- THE BEHAVIOUR FIRST, the constant last. With the assertion on `MAY_WRITE` at the top, a
			-- run with the guard disabled stopped there and never reached the part that proves the
			-- place was not written -- TestEZ abandons an `it` at the first failure, which is this
			-- task's own subject (measured on a dirty-tree run, Task 48).
			local before = Workspace.StreamingEnabled
			-- A contract that DISAGREES with the place, which is the whole hazard.
			local provocation = {
				enabled = not before,
				minRadius = Map.STREAMING.minRadius,
				targetRadius = Map.STREAMING.targetRadius,
				integrityMode = Map.STREAMING.integrityMode,
				modelBehavior = Map.STREAMING.modelBehavior,
			}
			local ok, changed, _unreachable, _unwritten, refused = pcall(Settings.apply, provocation)
			local after = Workspace.StreamingEnabled
			if after ~= before then
				-- Put the place back before failing: a spec that leaves streaming flipped for the rest
				-- of the session is worse than the defect it found.
				Workspace.StreamingEnabled = before
			end
			expect(ok).to.equal(true)
			if after ~= before then
				error("Settings.apply changed Workspace.StreamingEnabled: M2.6 has not run", 0)
			end
			expect(#changed).to.equal(0)
			expect(table.find(refused, "StreamingEnabled")).to.be.ok()
			expect(Settings.MAY_WRITE).to.equal(false) -- and M2.6 has not run
		end)

		it("still writes nothing when the contract and the place agree", function()
			local before = Workspace.StreamingEnabled
			local changed, _unreachable, _unwritten, refused = Settings.apply(Map.STREAMING)
			expect(Workspace.StreamingEnabled).to.equal(before)
			expect(#changed).to.equal(0)
			expect(#refused).to.equal(0)
		end)
	end)

	describe("the generator's bog", function()
		-- audit-004 F10. `Height.atFlattened`'s `bogDepth` is optional, so a caller that forgets it
		-- silently asks a different question from the one `Ground.writeTile` answers. This is what the
		-- argument is worth, in studs, so a spec that omits it is measurably wrong rather than merely
		-- untidy.
		it("digs the bog only when the ground is asked with bogDepth", function()
			local c = config()
			local bog = c.WORLD.bog
			local withBog = MapGen.Height.at(bog.x, bog.z, SEED, c, MapGen.Layout.bogDepth)
			local without = MapGen.Height.at(bog.x, bog.z, SEED, c)
			expect(math.abs((without - withBog) - bog.depth) < 0.001).to.equal(true)
			-- And outside it the argument changes nothing at all.
			local away = MapGen.Layout.bogDepth(bog.x + bog.radius * 2, bog.z, c)
			expect(away).to.equal(0)
			expect(MapGen.Height.at(bog.x + bog.radius * 2, bog.z, SEED, c, MapGen.Layout.bogDepth)).to.equal(
				MapGen.Height.at(bog.x + bog.radius * 2, bog.z, SEED, c)
			)
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

		-- The whole wood, block by block, exactly as MapGen.runStep builds it.
		local function wood(c, seed: number)
			local out = {}
			for _, block in ipairs(MapGen.Layout.treeBlocks(c)) do
				for _, point in ipairs(MapGen.Scatter.trees(c, seed, block, reject)) do
					table.insert(out, point)
				end
			end
			return out
		end

		it("places the same wood twice, and a different one for a different seed", function()
			local c = config()
			local first, second = wood(c, SEED), wood(c, SEED)
			expect(#first > 0).to.equal(true)
			expect(#second).to.equal(#first)
			for index, point in ipairs(first) do
				expect(point.x).to.equal(second[index].x)
				expect(point.z).to.equal(second[index].z)
			end
			local other = wood(c, SEED + 1)
			local same = 0
			for index, point in ipairs(first) do
				if other[index] and point.x == other[index].x and point.z == other[index].z then
					same += 1
				end
			end
			expect(same < #first / 2).to.equal(true)
		end)

		it("fills the drive with wood and still leaves the ground the game uses clear", function()
			local c = config()
			local points = wood(c, SEED)
			local inCorridor = 0
			for _, point in ipairs(points) do
				-- THE CORRIDOR IS THE WOOD NOW (M2.8b): what must stay clear is the ground the game
				-- stands things on, and each of these is a separate error message so a failure says
				-- which rule broke.
				if MapGen.Layout.onBench(point.x, point.z, c) then
					error(string.format("a tree at (%.0f, %.0f) stands on the road", point.x, point.z), 0)
				end
				if MapGen.Layout.onTrack(point.x, point.z, c) then
					error(string.format("a tree at (%.0f, %.0f) is on a track", point.x, point.z), 0)
				end
				if MapGen.Layout.bogDepth(point.x, point.z, c) > 0 then
					error(string.format("a tree at (%.0f, %.0f) is in the bog", point.x, point.z), 0)
				end
				if MapGen.Layout.inField(point.x, point.z, c) then
					error(string.format("a tree at (%.0f, %.0f) is in a field", point.x, point.z), 0)
				end
				if MapGen.Layout.distanceToHedge(point.x, point.z, c) < c.SCATTER_CLEARANCE then
					error(string.format("a tree at (%.0f, %.0f) stands in a hedgerow", point.x, point.z), 0)
				end
				for _, pad in ipairs(MapGen.Layout.pads(c)) do
					local away = (Vector3.new(point.x, 0, point.z) - Vector3.new(pad.x, 0, pad.z)).Magnitude
					if away <= c.SPAWN_PAD.radius then
						error(string.format("a tree at (%.0f, %.0f) is on a boar spawn pad", point.x, point.z), 0)
					end
				end
				expect(point.x >= c.WORLD.treeArea.minX and point.x <= c.WORLD.treeArea.maxX).to.equal(true)
				expect(point.z >= c.WORLD.treeArea.minZ and point.z <= c.WORLD.treeArea.maxZ).to.equal(true)
				if MapGen.Layout.inCorridor(point.x, point.z, c) then
					inCorridor += 1
				end
			end
			-- ...and the drive is not a bare lane: this is the whole point of M2.8b.
			expect(inCorridor > 500).to.equal(true)
			TestKit.note(string.format("wood: %d trees, %d of them inside the drive corridor", #points, inCorridor))
		end)

		it("keeps the wood inside the part budget, measured rather than asked for", function()
			local c = config()
			local points = wood(c, SEED)
			expect(#points <= Map.BUDGET.trees).to.equal(true)
			-- ...and it is a WOOD, not a copse: the estimate in design section 7.2 is ~2,925.
			expect(#points > 1500).to.equal(true)
		end)

		it("is denser where the shooter looks than in the backdrop", function()
			-- The tiers exist to put the wood where the player's eye is (design section 7.2), and a
			-- density function nobody measures is a comment. Counted per 10,000 studs.
			local c = config()
			local dense, backdrop = 0, 0
			for _, point in ipairs(wood(c, SEED)) do
				if
					math.abs(point.z - c.WORLD.lineZ) <= c.TREE_DENSITY.denseBandStuds
					and math.abs(point.x) <= c.TREE_DENSITY.denseHalfWidth
				then
					dense += 1
				elseif not MapGen.Layout.inCorridor(point.x, point.z, c) then
					backdrop += 1
				end
			end
			local denseArea = (2 * c.TREE_DENSITY.denseHalfWidth) * (2 * c.TREE_DENSITY.denseBandStuds)
			local backdropArea = c.SIZE_STUDS * c.SIZE_STUDS - denseArea
			local densePer10k = dense / denseArea * 10000
			local backdropPer10k = backdrop / backdropArea * 10000
			TestKit.note(
				string.format(
					"wood density: %.2f trees/10k studs in the band, %.2f in the backdrop",
					densePer10k,
					backdropPer10k
				)
			)
			expect(densePer10k > backdropPer10k * 2).to.equal(true)
		end)

		it("keeps every trunk far enough apart for the boar to walk between them", function()
			-- DESIGN SECTION 7.3, WHICH IS THE ARGUMENT THIS WHOLE TASK RESTS ON: a jittered grid
			-- guarantees `spacing * (1 - jitter)` between neighbouring cells, so 22 * 0.5 = 11 studs,
			-- minus two half-trunks of the widest species (oak, 5) leaves 6 studs of clear gap against
			-- the boar's AgentRadius = 2, which needs 4. Measured over several seeds, not argued.
			local c = config()
			local guaranteed = c.TREE_SPACING * (1 - c.SCATTER_JITTER)
			local widest = 0
			for _, row in ipairs(c.SPECIES) do
				widest = math.max(widest, row.trunk.X, row.trunk.Z)
			end
			local worst = math.huge
			for seed = SEED, SEED + 4 do
				local points = wood(c, seed)
				-- Bucketed by cell, so this is O(n) rather than O(n^2) over ~3,000 points: two points
				-- closer than `guaranteed` must share a bucket or be in a neighbouring one.
				local buckets = {}
				local function keyOf(x, z)
					return string.format("%d:%d", math.floor(x / guaranteed), math.floor(z / guaranteed))
				end
				for _, point in ipairs(points) do
					local key = keyOf(point.x, point.z)
					buckets[key] = buckets[key] or {}
					table.insert(buckets[key], point)
				end
				for _, point in ipairs(points) do
					local cx, cz = math.floor(point.x / guaranteed), math.floor(point.z / guaranteed)
					for dx = -1, 1 do
						for dz = -1, 1 do
							for _, other in ipairs(buckets[string.format("%d:%d", cx + dx, cz + dz)] or {}) do
								if other ~= point then
									local away = math.sqrt((other.x - point.x) ^ 2 + (other.z - point.z) ^ 2)
									worst = math.min(worst, away)
								end
							end
						end
					end
				end
			end
			TestKit.note(
				string.format(
					"wood: closest two trunks over 5 seeds are %.2f studs apart "
						.. "(guaranteed %.1f, widest trunk %.1f)",
					worst,
					guaranteed,
					widest
				)
			)
			expect(worst >= guaranteed - 1e-6).to.equal(true)
			-- ...and the clear gap really is wider than the boar's agent.
			expect(worst - widest > 2 * 2).to.equal(true) -- AgentRadius = 2
		end)

		it("plants Karen's four species, in her proportions, with alder in the wet", function()
			local c = config()
			local counts = { spruce = 0, birch = 0, oak = 0, alder = 0 }
			local total = 0
			for _, block in ipairs(MapGen.Layout.treeBlocks(c)) do
				for _, point in ipairs(MapGen.Scatter.trees(c, SEED, block, reject)) do
					local y = MapGen.Height.at(point.x, point.z, SEED, c)
					local species = MapGen.Scatter.speciesAt(point.x, point.z, SEED, c, y)
					expect(counts[species]).to.be.ok() -- one of the four, never a fifth
					counts[species] += 1
					total += 1
				end
			end
			TestKit.note(
				string.format(
					"species: spruce %d, birch %d, oak %d, alder %d of %d",
					counts.spruce,
					counts.birch,
					counts.oak,
					counts.alder,
					total
				)
			)
			for _, row in ipairs(c.SPECIES) do
				local share = counts[row.name] / total
				-- A CLUMPED field is not a shuffled bag, so the tolerance is wide on purpose: what is
				-- asserted is that every species is really there in roughly its share, not that the
				-- noise field is uniform.
				expect(share > row.share * 0.4).to.equal(true)
				expect(share < row.share * 1.8).to.equal(true)
			end
			-- WET GROUND IS ALDER, whatever the field says: a spruce in a bog reads as a mistake. Four
			-- points around the bog, because `speciesAt` no longer takes a key to steer it with.
			local bog = c.WORLD.bog
			for _, offset in ipairs({ Vector2.new(10, 0), Vector2.new(-10, 0), Vector2.new(0, 14), Vector2.new(0, -14) }) do
				expect(MapGen.Scatter.speciesAt(bog.x + offset.X, bog.z + offset.Y, SEED, c, -20)).to.equal("alder")
			end
		end)

		-- ONE NUMBER, ONE QUESTION (review round 1, and PROJECT_CONTEXT's "one predicate answered two
		-- unrelated questions"). The species used to be decided by the number that decided whether the
		-- tree exists at all: every candidate accepted where the density is 0.42 (the drive) or 0.14
		-- (the backdrop) has a key below SPECIES_CLUMP_STRENGTH, so `speciesAt` always returned the
		-- clump's leader and every clump outside the dense band was a pure monoculture.
		--
		-- THE MARGINAL SHARES SURVIVE THAT BUG -- the leader is itself drawn by share -- which is why
		-- the share assertion above passed while about half the wood was wrong, and why this spec
		-- measures the mix INSIDE a clump as well as the shares, in EACH density tier.
		it("draws the species independently of the density, so the mix is the same in a thin wood", function()
			local c = config()
			local strength = c.SPECIES_CLUMP_STRENGTH
			-- The share of trees that are NOT their clump's leader, derived rather than guessed: a tree
			-- takes the leader with probability `strength`, and otherwise draws from the same shares --
			-- which returns the leader again with the leader's own share. So the expected share is
			-- (1 - strength) * (1 - sum of share^2) = 0.35 * 0.715 = 0.2503 with Karen's four numbers,
			-- and it is the SAME NUMBER in every tier, because the draw has nothing to do with density.
			local sumSquares = 0
			for _, row in ipairs(c.SPECIES) do
				sumSquares += row.share * row.share
			end
			local expected = (1 - strength) * (1 - sumSquares)

			local tiers =
				{ thin = { total = 0, other = 0, counts = {} }, dense = { total = 0, other = 0, counts = {} } }
			local wet = 0
			for _, block in ipairs(MapGen.Layout.treeBlocks(c)) do
				for _, point in ipairs(MapGen.Scatter.trees(c, SEED, block, reject)) do
					local y = MapGen.Height.at(point.x, point.z, SEED, c)
					if y < c.SPECIES_WET_DEPTH then
						-- The wet rule overrides the clump, so a bog tree says nothing about the mix.
						wet += 1
					else
						local tier = tiers.dense
						if MapGen.Layout.treeDensity(point.x, point.z, c) < strength then
							tier = tiers.thin
						end
						local species = MapGen.Scatter.speciesAt(point.x, point.z, SEED, c, y)
						local leader = MapGen.Scatter.clumpLeaderAt(point.x, point.z, SEED, c)
						tier.total += 1
						tier.counts[species] = (tier.counts[species] or 0) + 1
						if species ~= leader then
							tier.other += 1
						end
					end
				end
			end

			TestKit.note(
				string.format(
					"species mix: thin tier %d trees, %.3f are not their clump's leader; "
						.. "dense tier %d trees, %.3f; expected %.3f; %d wet (forced alder, excluded)",
					tiers.thin.total,
					tiers.thin.other / math.max(tiers.thin.total, 1),
					tiers.dense.total,
					tiers.dense.other / math.max(tiers.dense.total, 1),
					expected,
					wet
				)
			)
			for _, name in ipairs({ "thin", "dense" }) do
				local tier = tiers[name]
				local shares = {}
				for _, row in ipairs(c.SPECIES) do
					table.insert(
						shares,
						string.format("%s %.3f", row.name, (tier.counts[row.name] or 0) / math.max(tier.total, 1))
					)
				end
				TestKit.note(string.format("  %s tier shares: %s", name, table.concat(shares, ", ")))
			end

			for _, name in ipairs({ "thin", "dense" }) do
				local tier = tiers[name]
				-- Both tiers have to exist at all, or "they agree" is a claim about nothing.
				expect(tier.total > 500).to.equal(true)
				-- TOLERANCE, STATED: +/- 0.08 of the derived 0.2503. Each tree's draw is independent,
				-- so with over 1,000 trees a tier the standard error is under 0.015 -- but WHICH
				-- species leads each clump is drawn too, and a wood of about 59 clumps of 260 studs can
				-- be led by spruce (share 0.40, so 0.35 * 0.60 = 0.21 expected) or by alder (0.15, so
				-- 0.2975) more often than its share. 0.08 covers that; the bug this catches makes the
				-- thin tier exactly 0.
				local other = tier.other / tier.total
				expect(other > expected - 0.08).to.equal(true)
				expect(other < expected + 0.08).to.equal(true)
				-- And every species is really there, in roughly its share, in THIS tier -- not only in
				-- the wood as a whole, which is what the assertion above measures. The band is wide for
				-- the same reason: a clumped field of 59 clumps is not a shuffled bag of 2,700 trees.
				for _, row in ipairs(c.SPECIES) do
					local share = (tier.counts[row.name] or 0) / tier.total
					expect(share > row.share * 0.4).to.equal(true)
					expect(share < row.share * 1.8).to.equal(true)
				end
			end
			-- THE INVARIANT THE BUG BROKE, in one line: how thick the wood is does not decide how mixed
			-- it is. With the acceptance key re-used, this is 0.25 against 0.
			local thin = tiers.thin.other / tiers.thin.total
			local dense = tiers.dense.other / tiers.dense.total
			expect(math.abs(thin - dense) < 0.08).to.equal(true)
		end)

		it("puts brush in the wood and nowhere else", function()
			local c = config()
			local total = 0
			for _, block in ipairs(MapGen.Layout.treeBlocks(c)) do
				for _, point in ipairs(MapGen.Scatter.brush(c, SEED, block, reject)) do
					total += 1
					if MapGen.Layout.onBench(point.x, point.z, c) or MapGen.Layout.inField(point.x, point.z, c) then
						error(string.format("brush at (%.0f, %.0f) is on the road or in a field", point.x, point.z), 0)
					end
				end
			end
			expect(total <= Map.BUDGET.brush).to.equal(true)
			expect(total > c.BRUSH.count / 2).to.equal(true)
		end)
	end)

	describe("the generator's digest", function()
		local function entry(name, x)
			return digestEntry(name, x, 1)
		end

		it("is 64 hex characters, of which the marker half is the first 32", function()
			local digest = MapGen.Digest.of({ entry("A", 0) }, DIGEST_SAMPLES, 100)
			expect(#digest).to.equal(64)
			expect(string.match(digest, "^[0-9a-f]+$")).to.be.ok()
			expect(MapGen.Digest.markerHalf(digest)).to.equal(string.sub(digest, 1, 32))
			expect(#MapGen.Digest.markerHalf(digest)).to.equal(32)
		end)

		it("is the same for the same map and different for a moved part", function()
			local samples = DIGEST_SAMPLES
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
			local samples = DIGEST_SAMPLES
			local a = MapGen.Digest.of({ entry("A", 1) }, samples, 100)
			expect(MapGen.Digest.of({ entry("A", 1.000001) }, samples, 100)).to.equal(a)
		end)
	end)
end
