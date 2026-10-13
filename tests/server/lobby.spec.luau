-- lobby.spec: THE LOBBY'S ARITHMETIC AND ITS GEOMETRY -- no world, no terrain, no player and no
-- clock. `Lobby.Join` and `Lobby.Field` are pure for exactly this reason: Karen's rule is *"step
-- into a marked spot by the truck"*, and "what happens when he steps out at 4.9 seconds" is a table
-- of cases a spec can state rather than a thing somebody watches in a playtest.
--
-- `Lobby.Build` IS DRIVEN INTO A FOLDER OF THIS SPEC'S OWN, which is what makes the part budget, the
-- collision set and *"no Script anywhere in the tree"* CHECKED claims rather than promises -- and
-- what lets this spec run safely in the DEV place, where there is no lobby at all.
--
-- `Field.fill` IS DRIVEN AGAINST A FAKE TERRAIN. That is not convenience: it is the reason `terrain`
-- is an argument at all, and it is what guarantees that no spec in the harness's own place can write
-- the DEV place's terrain, ever.
--
-- THE SWITCH-OFF CASE IS THE ONE THAT MATTERS MOST (CLAUDE.md "Feature flags"): `anchorFor("map:v1")`
-- is nil, which is what makes "off means today's game bit for bit" a checked claim -- `Lobby.start`
-- returns false on a nil anchor and builds nothing.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/lobby.md (section 16.1)
-- Note:   docs/research/2026-10-13-lobby-and-the-truck.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Data = require(ReplicatedStorage:WaitForChild("Lobby"))
local Lobby = require(ServerScriptService:WaitForChild("Lobby"))
local Join = Lobby.Join
local Field = Lobby.Field
local Build = Lobby.Build

local CFG = Data.CONFIG

-- A TERRAIN THAT RECORDS AND WRITES NOTHING. One method, because `Field.fill` calls exactly one.
local function fakeTerrain()
	local calls = {}
	return {
		calls = calls,
		FillBlock = function(_self, at: CFrame, size: Vector3, material: Enum.Material)
			table.insert(calls, { at = at, size = size, material = material })
		end,
	}
end

local function corners(at: CFrame, size: Vector3): { Vector3 }
	local out = {}
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				table.insert(out, at.Position + Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2))
			end
		end
	end
	return out
end

return function()
	describe("where the lobby lives", function()
		it("has a row for the world Karen plays in and none for the harness's", function()
			local forest = Data.anchorFor("forest-test")
			expect(forest).to.be.ok()
			-- The MEASURED flattest open ground south of `OurForest`'s southern edge (z = -2896).
			expect((forest :: any).x).to.equal(2850)
			expect((forest :: any).z).to.equal(-2950)

			-- THE DEV PLACE HAS NO LOBBY IN THIS TASK, so the harness reads exactly what it read
			-- before it: no anchor, no build, no terrain write.
			expect(Data.anchorFor("map:v1")).to.equal(nil)
			expect(Data.anchorFor("arena")).to.equal(nil)
			expect(Data.anchorFor("not-a-world")).to.equal(nil)
			expect(Data.anchorFor(nil)).to.equal(nil)
		end)

		it("carries no Y, because nobody measured one", function()
			-- The anchor is x and z only: the shelf's height comes from the world's own ground reader
			-- at build time. A typed Y would be a guess that puts the lodge in the air.
			local forest = Data.anchorFor("forest-test") :: any
			expect(forest.y).to.equal(nil)
		end)

		it("is 570 studs clear of the drive, so it cannot interact with it", function()
			local forest = Data.anchorFor("forest-test") :: any
			local ForestTest = require(ReplicatedStorage:WaitForChild("ForestTest"))
			-- South of the road, south of where the boars leave the world, and outside the field the
			-- drive releases animals into.
			expect(forest.z < ForestTest.EXIT_Z).to.equal(true)
			expect(ForestTest.CENTRE.Z - forest.z > 500).to.equal(true)
		end)
	end)

	describe("the circle (Valve's trigger_multiple, read as arithmetic)", function()
		local spot = Vector3.new(100, 50, -200)

		it("is in at the radius and out past it", function()
			expect(Join.within(spot, spot, 8)).to.equal(true)
			expect(Join.within(spot + Vector3.new(7.9, 0, 0), spot, 8)).to.equal(true)
			-- ON the circle is IN it: `<=`, the same comparison `ForestTest.withinStand` makes, so
			-- the screen's chevron and the rule cannot disagree about the edge.
			expect(Join.within(spot + Vector3.new(8, 0, 0), spot, 8)).to.equal(true)
			expect(Join.within(spot + Vector3.new(8.1, 0, 0), spot, 8)).to.equal(false)
			-- The diagonal, so it is a circle and not a square.
			expect(Join.within(spot + Vector3.new(6, 0, 6), spot, 8)).to.equal(false)
		end)

		it("is FLAT: fifty studs above the spot is still inside", function()
			-- A player on the truck's running board is a stud above the ground and has not left.
			expect(Join.within(spot + Vector3.new(0, 50, 0), spot, 8)).to.equal(true)
			expect(Join.within(spot + Vector3.new(0, -50, 0), spot, 8)).to.equal(true)
		end)

		it("is the radius the config states", function()
			expect(CFG.SPOT.RADIUS_STUDS).to.equal(8)
		end)
	end)

	describe("the countdown", function()
		it("goes idle -> counting -> enrol at exactly COUNTDOWN_SECONDS", function()
			local entry, verdict = Join.decide(nil, false, 0, CFG)
			expect(entry).to.equal(nil)
			expect(verdict).to.equal(Join.IDLE)

			entry, verdict = Join.decide(nil, true, 10, CFG)
			expect(verdict).to.equal(Join.COUNTING)
			expect((entry :: any).leaveAt).to.equal(10 + CFG.COUNTDOWN_SECONDS)

			-- A tenth of a second short is still counting.
			local _, still = Join.decide(entry, true, 10 + CFG.COUNTDOWN_SECONDS - 0.1, CFG)
			expect(still).to.equal(Join.COUNTING)

			-- And five seconds means five.
			local gone, done = Join.decide(entry, true, 10 + CFG.COUNTDOWN_SECONDS, CFG)
			expect(done).to.equal(Join.ENROL)
			-- THE ENTRY IS DROPPED WITH THE VERDICT, so one walk into the circle cannot enrol twice.
			expect(gone).to.equal(nil)
		end)

		it("cancels when he steps out, and a re-entry starts a new clock", function()
			local entry = (Join.decide(nil, true, 0, CFG))
			local out, cancelled = Join.decide(entry, false, 3, CFG)
			expect(cancelled).to.equal(Join.CANCELLED)
			expect(out).to.equal(nil)

			-- RE-ENTRY DOES NOT INHERIT THE OLD DEADLINE. Karen's rule is that stepping out cancels
			-- it; a kept clock would make stepping out and back in enrol him instantly.
			local again, verdict = Join.decide(nil, true, 4, CFG)
			expect(verdict).to.equal(Join.COUNTING)
			expect((again :: any).leaveAt).to.equal(4 + CFG.COUNTDOWN_SECONDS)
		end)

		it("is five seconds", function()
			expect(CFG.COUNTDOWN_SECONDS).to.equal(5)
		end)
	end)

	describe("who belongs back at the lodge", function()
		it("answers for all eight combinations", function()
			-- In the drive: never, whatever else is true -- the drive owns where he stands.
			expect(Join.needsReturn(true, true, true)).to.equal(false)
			expect(Join.needsReturn(true, true, false)).to.equal(false)
			expect(Join.needsReturn(true, false, true)).to.equal(false)
			expect(Join.needsReturn(true, false, false)).to.equal(false)
			-- HELD: never. During the results scene a dismissed player is 570 studs from the lodge,
			-- and without this the lobby would respawn him out of Karen's results scene.
			expect(Join.needsReturn(false, true, false)).to.equal(false)
			expect(Join.needsReturn(false, true, true)).to.equal(false)
			-- Out of the drive, not held, and standing on the field already: leave him alone.
			expect(Join.needsReturn(false, false, true)).to.equal(false)
			-- The one case that returns him.
			expect(Join.needsReturn(false, false, false)).to.equal(true)
		end)

		it("does nothing at all when there is no position: absent is not outside", function()
			expect(Join.needsReturn(false, false, nil)).to.equal(false)
			expect(Join.needsReturn(true, false, nil)).to.equal(false)
		end)

		it("reads the field as a rectangle and not as a circle", function()
			local anchor = Vector3.new(2850, 153, -2950)
			local half = CFG.FIELD.SPAN_STUDS / 2
			expect(Join.insideField(anchor, anchor, CFG)).to.equal(true)
			-- The corner of the yard is still the yard.
			expect(Join.insideField(anchor + Vector3.new(half - 1, 0, half - 1), anchor, CFG)).to.equal(true)
			expect(Join.insideField(anchor + Vector3.new(half + 1, 0, 0), anchor, CFG)).to.equal(false)
			expect(Join.insideField(anchor + Vector3.new(0, 0, -half - 1), anchor, CFG)).to.equal(false)
			-- Height is not bounded: the field is a footprint.
			expect(Join.insideField(anchor + Vector3.new(0, 400, 0), anchor, CFG)).to.equal(true)
		end)
	end)

	describe("the field, cut and filled", function()
		local anchor = Vector3.new(2850, 0, -2950)
		local shelf = 153

		it("puts the grass block's top AT the shelf and its bottom below the lowest ground", function()
			local at, size = Field.grassBlock(anchor, shelf, CFG)
			expect(size.X).to.equal(CFG.FIELD.SPAN_STUDS)
			expect(size.Z).to.equal(CFG.FIELD.SPAN_STUDS)
			expect(size.Y).to.equal(CFG.FIELD.DEPTH_STUDS)
			expect(at.Position.Y + size.Y / 2).to.equal(shelf)
			-- 48 studs reaches below the worst of the fifteen sampled footprints (44 studs of spread),
			-- so the slab meets undisturbed ground on every corner rather than floating.
			expect(CFG.FIELD.DEPTH_STUDS > 44).to.equal(true)
		end)

		it("starts the air block AT the shelf and clears the lodge's ridge", function()
			local at, size = Field.airBlock(anchor, shelf, CFG)
			expect(at.Position.Y - size.Y / 2).to.equal(shelf)
			expect(size.Y).to.equal(CFG.FIELD.CLEAR_STUDS)
			-- Above the ridge, so the lodge is never built inside the hill it just cut.
			expect(CFG.FIELD.CLEAR_STUDS > CFG.LODGE.RIDGE_STUDS).to.equal(true)
		end)

		it("lays a pad of a material with no grass blades under the buildings", function()
			-- A LOOK FIX THAT WAS PHOTOGRAPHED: the first build's inside shot came back with terrain
			-- grass growing through the lodge's floorboards.
			local at, size = Field.padBlock(anchor, shelf, CFG)
			expect(at.Position.Y + size.Y / 2).to.equal(shelf)
			expect(CFG.FIELD.PAD.MATERIAL).never.to.equal(CFG.FIELD.MATERIAL)
			-- It covers the lodge's whole footprint, its porch and the circle beside the truck.
			local half = Vector3.new(size.X / 2, 0, size.Z / 2)
			local centre = at.Position
			for _, point in ipairs({
				anchor + CFG.LODGE.OFFSET,
				anchor + CFG.LODGE.OFFSET - Vector3.new(0, 0, CFG.LODGE.SIZE.Z / 2 + CFG.LODGE.PORCH_DEPTH),
				anchor + CFG.SPOT.OFFSET,
				anchor + CFG.SPAWN.OFFSET,
			}) do
				expect(math.abs(point.X - centre.X) <= half.X).to.equal(true)
				expect(math.abs(point.Z - centre.Z) <= half.Z).to.equal(true)
			end
		end)

		it("writes nothing outside the field's own rectangle", function()
			for _, block in ipairs({
				{ Field.grassBlock(anchor, shelf, CFG) },
				{ Field.airBlock(anchor, shelf, CFG) },
				{ Field.padBlock(anchor, shelf, CFG) },
			}) do
				local at, size = block[1] :: CFrame, block[2] :: Vector3
				expect(Field.insideField(anchor, at, size, CFG)).to.equal(true)
				for _, point in ipairs(corners(at, size)) do
					local half = CFG.FIELD.SPAN_STUDS / 2
					expect(math.abs(point.X - anchor.X) <= half + 1e-6).to.equal(true)
					expect(math.abs(point.Z - anchor.Z) <= half + 1e-6).to.equal(true)
				end
			end
		end)

		it("chunks a wide box and leaves a narrow one alone", function()
			local at, size = Field.grassBlock(anchor, shelf, CFG)
			local whole = Field.chunks(at, size, 1000)
			expect(#whole).to.equal(1)
			expect(whole[1].size.X).to.equal(size.X)

			local pieces = Field.chunks(at, size, CFG.FIELD.CHUNK_STUDS)
			expect(#pieces > 1).to.equal(true)
			-- Every chunk is inside the rectangle, and together they cover it exactly.
			local total = 0
			for _, piece in ipairs(pieces) do
				total += piece.size.X
				expect(piece.size.X <= CFG.FIELD.CHUNK_STUDS + 1e-6).to.equal(true)
				expect(Field.insideField(anchor, piece.at, piece.size, CFG)).to.equal(true)
			end
			expect(math.abs(total - size.X) < 1e-6).to.equal(true)
		end)

		it("fills grass and THEN air, through the argument and never through Workspace", function()
			local fake = fakeTerrain()
			local calls, grassCalls = Field.fill(fake, anchor, shelf, CFG)
			expect(calls).to.equal(#fake.calls)
			expect(grassCalls > 0).to.equal(true)
			expect(calls > grassCalls).to.equal(true)
			-- Grass first: the other order would fill the hole the air had just made. Then the pad
			-- under the buildings, then the air that cuts the hill off.
			expect(fake.calls[1].material).to.equal(CFG.FIELD.MATERIAL)
			expect(fake.calls[#fake.calls].material).to.equal(Enum.Material.Air)
			local seen = { grass = 0, pad = 0, air = 0 }
			for _, call in ipairs(fake.calls) do
				if call.material == CFG.FIELD.MATERIAL then
					seen.grass += 1
					expect(seen.pad + seen.air).to.equal(0) -- all the grass goes down first
				elseif call.material == CFG.FIELD.PAD.MATERIAL then
					seen.pad += 1
					expect(seen.air).to.equal(0) -- ...and the pad before the air
				else
					expect(call.material).to.equal(Enum.Material.Air)
					seen.air += 1
				end
			end
			expect(seen.grass).to.equal(grassCalls)
			expect(seen.pad > 0).to.equal(true)
			expect(seen.air > 0).to.equal(true)
		end)
	end)

	describe("the parts build", function()
		local anchor = Vector3.new(0, 100, 0)
		local container, folder, count

		beforeEach(function()
			container = Instance.new("Folder")
			container.Name = "LobbySpecWorld"
			-- WORKSPACE AND NEVER A ROJO-OWNED CONTAINER: `ReplicatedStorage` is fully Rojo-owned with
			-- `$ignoreUnknownInstances: false`, so a folder parked there is DELETED at Karen's next
			-- Connect; `Workspace` is not mapped at all, which is the property `Workspace.Boars`,
			-- `Workspace.ForestMarkers` and `Workspace.WeaponEffects` already rely on. It is destroyed
			-- in `afterEach` either way.
			container.Parent = Workspace
			local made, _marker, _spawn, parts = Build.build(container, anchor, CFG)
			folder = made
			count = parts
		end)

		afterEach(function()
			container:Destroy()
		end)

		it("stays inside the part budget", function()
			expect(count <= CFG.MAX_PARTS).to.equal(true)
			expect(count > 50).to.equal(true) -- a lodge, a truck, a ring and a track is not five parts
		end)

		it("anchors everything, and the only things that collide are the shell", function()
			local collidable = {}
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("BasePart") then
					expect(descendant.Anchored).to.equal(true)
					if descendant.CanCollide then
						table.insert(collidable, descendant.Name)
					else
						-- `CanQuery = false` IS LOAD-BEARING: a slab that stops a pellet changes what
						-- the shot hit.
						expect(descendant.CanQuery).to.equal(false)
					end
				end
			end
			expect(#collidable > 0).to.equal(true)
			for _, name in ipairs(collidable) do
				local shell = string.match(name, "^Wall")
					or string.match(name, "^Roof")
					or string.match(name, "^Gable")
					or string.match(name, "^Floor")
					or string.match(name, "^Deck")
					or string.match(name, "^Porch")
					or string.match(name, "^DoorPost")
					or string.match(name, "^Fireplace")
					or string.match(name, "^Counter")
					or string.match(name, "^TableLeg")
					or string.match(name, "^SignPost")
					or string.match(name, "^Bed")
					or string.match(name, "^Cab")
					or string.match(name, "^Bonnet")
					or name == Data.SPAWN_NAME
				if shell == nil then
					error(string.format("a collidable part nothing meant to be solid: %s", name), 0)
				end
			end
		end)

		it("names the truck spot, puts it where the config says, and makes it unqueryable", function()
			local marker = folder:FindFirstChild(Data.SPOT_NAME, true)
			expect(marker).to.be.ok()
			local at = (marker :: BasePart).Position
			local wanted = anchor + CFG.SPOT.OFFSET
			expect(math.abs(at.X - wanted.X) < 1e-4).to.equal(true)
			expect(math.abs(at.Z - wanted.Z) < 1e-4).to.equal(true)
			-- It is the ONE definition of where the truck is, and a shot must pass straight through it.
			expect((marker :: BasePart).CanQuery).to.equal(false)
			expect((marker :: BasePart).Transparency).to.equal(1)
		end)

		it("builds a neutral lodge spawn that writes no team and grants no force field", function()
			local spawn = folder:FindFirstChild(Data.SPAWN_NAME, true)
			expect(spawn).to.be.ok()
			expect((spawn :: any):IsA("SpawnLocation")).to.equal(true)
			expect((spawn :: any).Neutral).to.equal(true)
			expect((spawn :: any).Enabled).to.equal(true)
			-- THE ENGINE MUST NEVER WRITE A TEAM: `Match.Body.setTeam` is the one writer of
			-- `Player.Team`, and a pad that changed it would be a second one.
			expect((spawn :: any).AllowTeamChangeOnTouch).to.equal(false)
			-- A `SpawnLocation` grants a 10-second ForceField by default; Karen did not ask for a
			-- bubble round every player at the lodge.
			expect((spawn :: any).Duration).to.equal(0)
		end)

		it("leaves the doorway a GAP: nothing stands in it", function()
			-- Karen asked for a *"door you walk through"*, so the door is the absence of parts.
			local origin = anchor + CFG.LODGE.OFFSET
			local frontZ = origin.Z - CFG.LODGE.SIZE.Z / 2
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant.CanCollide then
					local at = descendant.Position
					local inDoorX = math.abs(at.X - origin.X) < CFG.LODGE.DOOR.X / 2
					local inDoorZ = math.abs(at.Z - frontZ) < 1.5
					local inDoorY = at.Y > origin.Y + 1 and at.Y < origin.Y + CFG.LODGE.DOOR.Y
					if inDoorX and inDoorZ and inDoorY then
						error(string.format("%s stands in the doorway", descendant.Name), 0)
					end
				end
			end
		end)

		it("has a warm inside: one light, and the shop counter task 178 fills", function()
			local inside = folder:FindFirstChild("Inside", true)
			expect(inside).to.be.ok()
			local lights = 0
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("PointLight") then
					lights += 1
				end
			end
			-- ONE light and nothing animated: a fire that flickers would be a second writer of it.
			expect(lights).to.equal(1)
			expect(folder:FindFirstChild("Counter", true)).to.be.ok()
			local shopSign = folder:FindFirstChild("ShopSign", true)
			expect(shopSign).to.be.ok()
			local label = (shopSign :: Instance):FindFirstChild("Text", true)
			expect(label).to.be.ok()
			expect((label :: TextLabel).Text).to.equal(CFG.LODGE.SIGN_TEXT)
		end)

		it("puts a sign on the circle saying what it is for", function()
			local board = folder:FindFirstChild("SpotSign", true)
			expect(board).to.be.ok()
			local label = (board :: Instance):FindFirstChild("Text", true)
			expect((label :: TextLabel).Text).to.equal(CFG.SPOT.SIGN_TEXT)
		end)

		it("holds no Script, LocalScript or ModuleScript anywhere in the tree", function()
			-- CLAUDE.md: nothing script-like is ever created outside a Rojo-owned path, and the
			-- harness fails if one exists. A world builder is the one place that could break it.
			for _, descendant in ipairs(folder:GetDescendants()) do
				expect(descendant:IsA("LuaSourceContainer")).to.equal(false)
			end
		end)

		it("rebuilds in place rather than leaving two lodges standing", function()
			local again = Build.build(container, anchor, CFG)
			expect(again).to.be.ok()
			local found = 0
			for _, child in ipairs(container:GetChildren()) do
				if child.Name == Data.FOLDER_NAME then
					found += 1
				end
			end
			expect(found).to.equal(1)
		end)
	end)

	describe("where he stands when he arrives", function()
		local anchor = Vector3.new(0, 100, 0)

		it("spreads two players more than a body apart, and faces them north", function()
			local first = Lobby.spawnCFrame(anchor, 0, CFG)
			local second = Lobby.spawnCFrame(anchor, 1, CFG)
			expect((first.Position - second.Position).Magnitude >= 4).to.equal(true)
			-- +Z: he looks at the lodge with the forest behind its roof, and the truck is to his
			-- right. Karen's *"house is in fields next to forrest"* read as a camera angle.
			expect(first.LookVector.Z > 0.99).to.equal(true)
			-- Centre-out, so a solo player gets the middle of the porch.
			expect(math.abs(first.Position.X - (anchor.X + CFG.SPAWN.OFFSET.X)) < 1e-4).to.equal(true)
		end)
	end)

	describe("the countdown the client reads", function()
		it("is nil in, nil out, and floors at zero", function()
			expect(Data.secondsLeft(nil, 100)).to.equal(nil)
			expect(Data.secondsLeft(105, 100)).to.equal(5)
			-- A past deadline is "now", never a negative number counting the wrong way.
			expect(Data.secondsLeft(90, 100)).to.equal(0)
		end)
	end)
end
