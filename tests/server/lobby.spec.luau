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

-- A FOLDER OF FAKE FREE MODELS (task 180). Plain parts in a Model, one per template name, so the
-- free-model branch is reachable WITHOUT a Creator Store round trip and without the Forest Test
-- place -- which is the whole point of `templates` being an argument. `withScript` plants a Script
-- inside the lodge, because "a free model is the classic place to hide one" is only a checked claim
-- if a spec actually hides one.
local function fakeTemplates(withScript: boolean?): Instance
	local folder = Instance.new("Folder")
	folder.Name = Data.TEMPLATES_NAME
	local function model(name: string, size: Vector3): Model
		local made = Instance.new("Model")
		made.Name = name
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = size
		body.Anchored = false -- the clone must anchor it: a free model ships with whatever it ships
		body.Parent = made
		made.Parent = folder
		return made
	end
	local house = model(Data.TEMPLATE.LODGE, Vector3.new(23, 16, 31))
	model(Data.TEMPLATE.TRUCK, Vector3.new(18, 7, 9))
	model(Data.TEMPLATE.DEER, Vector3.new(5, 5, 3))
	model(Data.TEMPLATE.BOAR, Vector3.new(3, 2, 3))
	local trees = Instance.new("Folder")
	trees.Name = Data.TEMPLATE.TREES
	trees.Parent = folder
	model("Spruce", Vector3.new(6, 30, 6)).Parent = trees
	if withScript then
		local hidden = Instance.new("Script")
		hidden.Name = "Fire_Effect"
		hidden.Parent = house
	end
	return folder
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

-- A BODY THAT IS NOT AN AVATAR (task 181). `Build` takes its rig source as a seam for exactly this
-- reason: the real one is `Players:CreateHumanoidModelFromDescription`, which reaches the avatar
-- service and may yield, and no spec in this harness may do either. It ships UNANCHORED and
-- COLLIDING, so "the keeper collides with nothing and his root is anchored" is a thing the builder
-- is proved to DO rather than a property the fake handed it.
local function fakeRig(): Model
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Anchored = false
	root.CanCollide = true
	root.CanQuery = true
	root.CanTouch = true
	root.Parent = model
	for _, name in ipairs({ "Head", "UpperTorso", "LeftHand" }) do
		local limb = Instance.new("Part")
		limb.Name = name
		limb.Size = Vector3.new(1, 1, 1)
		limb.Anchored = false
		limb.CanCollide = true
		limb.CanQuery = true
		limb.CanTouch = true
		limb.Parent = model
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
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

		-- IT IS A DISTANCE BETWEEN TWO RECTANGLES NOW, AND NOT A z COMPARISON (task 179).
		--
		-- This case used to read `forest.z < ForestTest.EXIT_Z` and `CENTRE.Z - forest.z > 500`, and
		-- BOTH became false: `EXIT_Z` is gone, and the `edge` layout's exit is z -3250 -- which is
		-- SOUTH of the lodge at -2950. A z comparison was only ever a proxy for *"the lodge is not
		-- in the way"*, and with three layouts in three different parts of the wood it is the wrong
		-- question: the edge drive is 255 studs EAST of the lodge, not north of it.
		--
		-- EACH OWNER STATES ITS OWN RECTANGLE and this spec is the only place the two meet --
		-- `ForestTest.corridorOf` is the forest's, `Lobby.anchorFor` plus `Lobby.CONFIG.FIELD` is
		-- the lobby's. Making either module require the other for one assertion would be new
		-- coupling for nothing.
		local function gapStuds(a, b): number
			local dx = math.max(a.minX - b.maxX, b.minX - a.maxX, 0)
			local dz = math.max(a.minZ - b.maxZ, b.minZ - a.maxZ, 0)
			-- 0 on either axis with the other positive is a side-on gap; both positive is a corner.
			return if dx > 0 and dz > 0 then math.sqrt(dx * dx + dz * dz) else math.max(dx, dz)
		end

		it("is clear of EVERY drive layout's ground, so it cannot interact with the drive", function()
			local forest = Data.anchorFor("forest-test") :: any
			local ForestTest = require(ReplicatedStorage:WaitForChild("ForestTest"))
			local Boar = require(ServerScriptService:WaitForChild("Boar"))
			local half = Data.CONFIG.FIELD.SPAN_STUDS / 2
			local lodge = {
				minX = forest.x - half,
				maxX = forest.x + half,
				minZ = forest.z - half,
				maxZ = forest.z + half,
			}
			expect(#ForestTest.LAYOUT_ORDER > 0).to.equal(true)
			for _, name in ipairs(ForestTest.LAYOUT_ORDER) do
				local layout = ForestTest.layoutNamed(name)
				-- The ground a drive happens on: the stands' span, from the exit to the beaters'
				-- start. Nobody stands, walks or is placed outside it.
				local corridor = ForestTest.corridorOf(layout)
				local corridorGap = gapStuds(corridor, lodge)
				expect(corridorGap >= 100).to.equal(
					true,
					string.format("layout %s: corridor is only %.0f studs from the lodge", name, corridorGap)
				)
				-- ...and the rectangle a boar may be clamped into, which is wider than the corridor.
				local boundsGap = gapStuds(ForestTest.boundsOf(layout), lodge)
				expect(boundsGap >= Boar.CONFIG.BOUNDS_SLACK + 40).to.equal(
					true,
					string.format("layout %s: boar bounds are only %.0f studs from the lodge", name, boundsGap)
				)
			end
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

		it("lays pads of a material with no grass blades under the buildings AND the road", function()
			-- BOTH OF THESE WERE PHOTOGRAPHED RATHER THAN GUESSED. Task 177's inside shot came back
			-- with terrain grass growing through the lodge's floorboards; task 180's first road shot
			-- came back with a field and NO ROAD, with the player standing on it. One cause: a grass
			-- material draws its blades on the terrain surface and a part laid over them does not
			-- hide them.
			local covered = {
				anchor + CFG.LODGE.OFFSET,
				anchor + CFG.LODGE.OFFSET - Vector3.new(0, 0, CFG.LODGE.SIZE.Z / 2 + CFG.LODGE.PORCH_DEPTH),
				anchor + CFG.SPOT.OFFSET,
				anchor + CFG.SPAWN.OFFSET,
				-- the far truck bay, which the 80 x 60 yard of task 177 did not reach
				anchor + CFG.TRUCK.OFFSET + Vector3.new((CFG.TRUCK.COUNT - 1) * CFG.TRUCK.BAY_GAP_STUDS, 0, 0),
				-- both ends of the road, on its centre line
				Vector3.new(anchor.X + CFG.ROAD.CENTRE_X, 0, anchor.Z + CFG.ROAD.FROM_Z - 1),
				Vector3.new(anchor.X + CFG.ROAD.CENTRE_X, 0, anchor.Z + CFG.ROAD.TO_Z + 1),
				-- and its outer verge, which is the edge the blades came through
				Vector3.new(
					anchor.X + CFG.ROAD.CENTRE_X + CFG.ROAD.WIDTH_STUDS / 2 + CFG.ROAD.VERGE_STUDS,
					0,
					anchor.Z
				),
			}
			for _, point in ipairs(covered) do
				local found = false
				for _, pad in ipairs(CFG.FIELD.PADS) do
					local at, size = Field.padBlock(anchor, shelf, pad)
					expect(at.Position.Y + size.Y / 2).to.equal(shelf)
					expect(pad.MATERIAL).never.to.equal(CFG.FIELD.MATERIAL)
					if
						math.abs(point.X - at.Position.X) <= size.X / 2
						and math.abs(point.Z - at.Position.Z) <= size.Z / 2
					then
						found = true
					end
				end
				expect(found).to.equal(true)
			end
		end)

		it("writes nothing outside the field's own rectangle", function()
			for _, block in ipairs({
				{ Field.grassBlock(anchor, shelf, CFG) },
				{ Field.airBlock(anchor, shelf, CFG) },
				{ Field.padBlock(anchor, shelf, CFG.FIELD.PADS[1]) },
				{ Field.padBlock(anchor, shelf, CFG.FIELD.PADS[2]) },
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
				elseif call.material == CFG.FIELD.PADS[1].MATERIAL then
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

	-- ------------------------------------------------ the free models, and the fallback (task 180)
	--
	-- KAREN, 2026-10-14 ~09:30: *"we need better house we can use free models / we need car truck
	-- model or hunting bus also use free model / ... and then on walls we can make trophys like head
	-- of deer head of boar"*.
	--
	-- THE CLAIM THAT MATTERS MOST HERE IS THE FALLBACK. The models live in `Workspace.LobbyAssets`,
	-- which is Studio content in ONE place; the lobby still has to build in the other one, and in a
	-- place where somebody renamed the folder, and in this spec. So the model build and the parts
	-- build are both driven here, and they must agree about everything except which lodge it is.
	describe("the free models, and what happens without them", function()
		local anchor = Vector3.new(0, 100, 0)
		local container

		beforeEach(function()
			container = Instance.new("Folder")
			container.Name = "LobbyModelSpecWorld"
			container.Parent = Workspace
		end)

		afterEach(function()
			container:Destroy()
		end)

		it("builds the lodge, the four trucks and the three trophies out of the templates", function()
			local templates = fakeTemplates()
			local folder, _marker, _spawn, count = Build.build(container, anchor, CFG, templates)
			local stats = Build.stats()
			expect(folder:FindFirstChild("House", true)).to.be.ok()
			-- the parts lodge's own log wall is NOT there: one lodge, never two.
			-- `WallN` AND NOT `WallS`: the front wall's lower courses are split round the doorway and
			-- are named `WallS1W`/`WallS1E`, so "WallS1" is absent from the parts build too and would
			-- pass this line for the wrong reason. The back wall has no door and no such trap.
			expect(folder:FindFirstChild("WallN1", true)).to.never.be.ok()
			for index = 1, CFG.TRUCK.COUNT do
				expect(folder:FindFirstChild(string.format("Truck%d", index), true)).to.be.ok()
			end
			expect(folder:FindFirstChild("DeerHead1", true)).to.be.ok()
			expect(folder:FindFirstChild("BoarHead2", true)).to.be.ok()
			expect(folder:FindFirstChild("TreeLine")).to.be.ok()
			-- ONE LODGE, FOUR TRUCKS, THREE HEADS -- exactly eight -- AND MOST OF THE TREE LINE.
			-- It is a BOUND and not an equality on purpose: the arc crosses the road's corridor and
			-- a tree that would stand in the road is skipped, so `TREELINE.COUNT` is how many are
			-- ATTEMPTED and never how many are placed. Pinning the exact number would make moving
			-- the road by a stud a failing test about trees.
			local trees = stats.models - 8
			expect(trees > 0).to.equal(true)
			expect(trees <= CFG.TREELINE.COUNT).to.equal(true)
			expect(trees >= CFG.TREELINE.COUNT - 6).to.equal(true)
			expect(stats.fallbacks).to.equal(0)
			expect(count <= CFG.MAX_PARTS).to.equal(true)
			templates:Destroy()
		end)

		it("falls back to task 177's parts build when the folder is not there at all", function()
			local folder, _marker, _spawn, count = Build.build(container, anchor, CFG, nil)
			local stats = Build.stats()
			expect(folder:FindFirstChild("House", true)).to.never.be.ok()
			expect(folder:FindFirstChild("WallN1", true)).to.be.ok() -- the back wall's lowest log
			expect(folder:FindFirstChild("Floor", true)).to.be.ok()
			for index = 1, CFG.TRUCK.COUNT do
				local made = folder:FindFirstChild(string.format("Truck%d", index), true)
				expect(made).to.be.ok()
				expect((made :: Instance):FindFirstChild("Cab")).to.be.ok() -- the parts truck
			end
			expect(folder:FindFirstChild("TreeLine")).to.never.be.ok()
			expect(stats.models).to.equal(0)
			expect(count <= CFG.MAX_PARTS).to.equal(true)
			expect(count > 50).to.equal(true)
		end)

		it("falls back one piece at a time when only some of the templates are there", function()
			local templates = fakeTemplates()
			local truckTemplate = templates:FindFirstChild(Data.TEMPLATE.TRUCK) :: Instance
			truckTemplate:Destroy()
			local folder = Build.build(container, anchor, CFG, templates)
			expect(folder:FindFirstChild("House", true)).to.be.ok() -- the model lodge still
			local first = folder:FindFirstChild("Truck1", true)
			expect(first).to.be.ok()
			expect((first :: Instance):FindFirstChild("Cab")).to.be.ok() -- ...and parts trucks
			expect(Build.stats().fallbacks >= CFG.TRUCK.COUNT).to.equal(true)
			templates:Destroy()
		end)

		it("strips a script a free model smuggled in, and says how many", function()
			local templates = fakeTemplates(true)
			local folder = Build.build(container, anchor, CFG, templates)
			expect(Build.stats().strippedScripts).to.equal(1)
			for _, descendant in ipairs(folder:GetDescendants()) do
				expect(descendant:IsA("LuaSourceContainer")).to.equal(false)
			end
			-- and the TEMPLATE is untouched: the clone was stripped, never the original
			expect(templates:FindFirstChild("Fire_Effect", true)).to.be.ok()
			templates:Destroy()
		end)

		it("anchors every cloned part, however the free model shipped it", function()
			local templates = fakeTemplates()
			local folder = Build.build(container, anchor, CFG, templates)
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("BasePart") then
					expect(descendant.Anchored).to.equal(true)
				end
			end
			templates:Destroy()
		end)

		it("parks the trucks in a row, a bay apart, starting where 177's one truck stood", function()
			local templates = fakeTemplates()
			local folder = Build.build(container, anchor, CFG, templates)
			local previous = 0
			for index = 1, CFG.TRUCK.COUNT do
				local made = folder:FindFirstChild(string.format("Truck%d", index), true) :: Model
				local x = made:GetPivot().Position.X
				if index == 1 then
					expect(math.abs(x - (anchor.X + CFG.TRUCK.OFFSET.X)) < 0.01).to.equal(true)
				else
					expect(math.abs((x - previous) - CFG.TRUCK.BAY_GAP_STUDS) < 0.01).to.equal(true)
				end
				previous = x
			end
			templates:Destroy()
		end)

		it("stands every free model ON the shelf, not in it and not over it", function()
			local templates = fakeTemplates()
			local folder = Build.build(container, anchor, CFG, templates)
			for _, name in ipairs({ "House", "Truck1", "Truck4" }) do
				local made = folder:FindFirstChild(name, true) :: Model
				local box, size = made:GetBoundingBox()
				expect(math.abs((box.Position.Y - size.Y / 2) - anchor.Y) < 0.05).to.equal(true)
			end
			templates:Destroy()
		end)

		it("keeps the road, the fences and the trees inside the field's own rectangle", function()
			-- THE SAME BOUND `Field.fill` IS HELD TO. The shelf is 220 x 220 and nothing else is
			-- flat: a verge or a fence post laid past its edge would float over the fall the raycast
			-- grid measured, which is the failure this project is named after.
			local templates = fakeTemplates()
			local folder = Build.build(container, anchor, CFG, templates)
			local half = CFG.FIELD.SPAN_STUDS / 2
			for _, group in ipairs({ "Road", "Fences", "TreeLine" }) do
				local made = folder:FindFirstChild(group)
				expect(made).to.be.ok()
				for _, descendant in ipairs((made :: Instance):GetDescendants()) do
					if descendant:IsA("BasePart") then
						local at = descendant.Position
						expect(math.abs(at.X - anchor.X) <= half).to.equal(true)
						expect(math.abs(at.Z - anchor.Z) <= half).to.equal(true)
					end
				end
			end
			templates:Destroy()
		end)

		it("hangs every trophy INSIDE the room it is in, under its ceiling, in BOTH builds", function()
			-- THE ROOM IS A DIFFERENT RECTANGLE IN THE TWO BUILDS (19.6 x 19.6 x 7.4 against
			-- 38 x 26 x 9), which is exactly why a mount names a WALL and not an offset -- and why
			-- the bound here is the ROOM and not the lodge's footprint. Round 1 bounded these against
			-- `LODGE.SIZE`, ten studs outside the wall, and so could not see the bug it was written
			-- for: an inverted yaw puts a plaque only `PLAQUE.Z / 2` = 0.25 studs past its wall.
			-- `Build.roomFor` is the same rectangle the mount itself used.
			for _, withModels in ipairs({ true, false }) do
				local templates = if withModels then fakeTemplates() else nil
				local folder = Build.build(container, anchor, CFG, templates)
				local room = Build.roomFor(anchor, CFG, withModels)
				local heads = folder:FindFirstChild("Trophies", true)
				expect(heads).to.be.ok()
				local plaques, mounted, tines = 0, 0, 0
				for _, descendant in ipairs((heads :: Instance):GetChildren()) do
					local isPlaque = string.sub(descendant.Name, 1, 6) == "Plaque"
					-- A HEAD IS A MODEL WITH THE TEMPLATES AND A PAIR OF TINE CYLINDERS WITHOUT THEM.
					-- Both are bounded, because both are the thing hanging on the wall.
					local isHead = descendant:IsA("Model")
						and (string.sub(descendant.Name, 1, 4) == "Deer" or string.sub(descendant.Name, 1, 4) == "Boar")
					local isTine = string.sub(descendant.Name, 1, 4) == "Tine"
					if isPlaque or isHead or isTine then
						-- THE HEADS ARE CHECKED TOO, and in round 1 they were not: they land a
						-- stud further out than the plaque, so they are the louder half of the bug.
						local middle, size
						if isPlaque then
							plaques += 1
							middle = (descendant :: BasePart).Position
							size = (descendant :: BasePart).Size
						elseif isHead then
							mounted += 1
							local box, extent = (descendant :: Model):GetBoundingBox()
							middle = box.Position
							size = extent
						else
							tines += 1
							middle = (descendant :: BasePart).Position
							size = (descendant :: BasePart).Size
						end
						local at = middle
						expect(at.X <= room.centre.X + room.halfX).to.equal(true)
						expect(at.X >= room.centre.X - room.halfX).to.equal(true)
						expect(at.Z <= room.centre.Z + room.halfZ).to.equal(true)
						expect(at.Z >= room.centre.Z - room.halfZ).to.equal(true)
						-- ...and off the floor, and NOT THROUGH THE CEILING, which is the other half
						-- of round 1: a 5.4-stud deer seated at its mount height stood 2.4 studs
						-- through a 7.4-stud room's roof.
						expect(middle.Y - size.Y / 2 > room.centre.Y).to.equal(true)
						expect(middle.Y + size.Y / 2 <= room.centre.Y + room.height).to.equal(true)
					end
				end
				expect(plaques).to.equal(#CFG.TROPHIES.MOUNTS)
				-- WITH the templates every mount is a head model and nothing falls back; WITHOUT
				-- them every mount is the pair of tines task 177's antlers are made of. The wall is
				-- never bare either way, which is the point of the fallback.
				if withModels then
					expect(mounted).to.equal(#CFG.TROPHIES.MOUNTS)
					expect(tines).to.equal(0)
				else
					expect(mounted).to.equal(0)
					expect(tines).to.equal(#CFG.TROPHIES.MOUNTS * 2)
				end
				if templates then
					(templates :: Instance):Destroy()
				end
			end
		end)

		it("keeps the fence line OUT of the yard, the porch, the spawn and the lodge, in BOTH builds", function()
			-- ROUND 2'S BLOCKING FINDING, as a case that fails without the fix. `POSTS_PER_SIDE = 9`
			-- from z -98 at 18 studs ran the WEST line (x +2, two studs off the lodge's centre line)
			-- to z +46 -- the lodge's own centre. One post stood inside the cabin through its
			-- floorboards, one in the middle of the porch beside the doorway, and a rail lay across
			-- the spawn pad at knee height. Nothing bounded it: the field rectangle is 110 studs away.
			--
			-- The bound is the YARD'S southern edge, because everything the fence must not reach --
			-- the yard, the circle, the porch, the spawn, the lodge -- is north of it.
			for _, withModels in ipairs({ true, false }) do
				local templates = if withModels then fakeTemplates() else nil
				local folder = Build.build(container, anchor, CFG, templates)
				local room = Build.roomFor(anchor, CFG, withModels)
				local yardSouth = anchor.Z + CFG.TRUCK.OFFSET.Z - 22
				local fences = folder:FindFirstChild("Fences")
				expect(fences).to.be.ok()
				local pieces = 0
				for _, descendant in ipairs((fences :: Instance):GetDescendants()) do
					if descendant:IsA("BasePart") then
						pieces += 1
						local piece = descendant :: BasePart
						local north = piece.Position.Z + piece.Size.Z / 2
						expect(north <= yardSouth).to.equal(true)
						-- ...and, said the other way round, never in the room a player shops in.
						local insideX = math.abs(piece.Position.X - room.centre.X) < room.halfX
						local insideZ = math.abs(piece.Position.Z - room.centre.Z) < room.halfZ
						expect(insideX and insideZ).to.equal(false)
					end
				end
				expect(pieces > 0).to.equal(true)
				if templates then
					(templates :: Instance):Destroy()
				end
			end
		end)

		it("leaves the marked circle standing CLEAR of the road surface it is drawn on", function()
			-- ROUND 1 BURIED IT. `road` lays its slabs on the shelf and the yard covers the whole
			-- circle, so a ring lifted 0.08 studs off the SHELF sat 0.42 studs inside an opaque
			-- slab: a sign reading "STAND HERE TO HUNT" with nothing to stand in. The ring's floor
			-- is the ROAD surface, so that is what this measures against.
			local folder = Build.build(container, anchor, CFG, fakeTemplates())
			local yard = folder:FindFirstChild("Yard", true) :: BasePart
			local ring = folder:FindFirstChild("Spot") :: Instance
			expect(yard).to.be.ok()
			expect(ring).to.be.ok()
			local surface = yard.Position.Y + yard.Size.Y / 2
			local segments = 0
			for _, descendant in ipairs(ring:GetChildren()) do
				if string.sub(descendant.Name, 1, 3) == "Seg" then
					segments += 1
					local piece = descendant :: BasePart
					expect(piece.Position.Y - piece.Size.Y / 2 >= surface).to.equal(true)
				end
			end
			expect(segments).to.equal(CFG.SPOT.RING.SEGMENTS)
		end)
	end)

	describe("where he stands when he arrives", function()
		local anchor = Vector3.new(0, 100, 0)

		it("can never put a player off the lobby's own field, however high the index climbs", function()
			-- REVIEW ROUND 1, FINDING 3, AND IT IS THE CASE THAT FAILS ON THE OLD CODE. The caller's
			-- index is a counter that only ever goes up -- one per player who has ever joined -- and
			-- unwrapped it is `floor((index + 1) / 2) * SPREAD_STUDS` studs off the middle with no
			-- bound at all: index 37 is 114 studs, outside `FIELD.SPAN_STUDS`'s half-span of 110. The
			-- man then stands exactly where `world.place` put him, `Join.insideField` answers FALSE,
			-- `Join.needsReturn` answers true, and the lobby re-places him at the same off-shelf point
			-- every `RETURN_COOLDOWN_SECONDS` for ever.
			local half = CFG.LODGE.SIZE.X / 2
			for index = 0, 200 do
				local at = Lobby.spawnCFrame(anchor, index, CFG).Position
				-- Inside the field, which is the rule that closes the respawn loop...
				expect(Join.insideField(at, anchor, CFG)).to.equal(true)
				-- ...and inside the lodge's own front, which is the porch the design names.
				expect(math.abs(at.X - (anchor.X + CFG.SPAWN.OFFSET.X)) < half).to.equal(true)
			end
			-- The slots WRAP rather than widen: index 0 and index SLOTS are the same place.
			local first = Lobby.spawnCFrame(anchor, 0, CFG).Position
			local wrapped = Lobby.spawnCFrame(anchor, CFG.SPAWN.SLOTS, CFG).Position
			expect((first - wrapped).Magnitude < 1e-4).to.equal(true)
		end)

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

	-- ---------------------------------------------------------------- the shopkeeper (task 181)
	--
	-- KAREN, 2026-10-14: *"in lobby has to be a person bot who you need to click E to get access to
	-- shop"*. Since this task took task 178's auto-open away, the prompt on this body is THE ONLY
	-- WAY INTO THE SHOP -- so "is there a man there, and has he got a prompt on him" is the one
	-- assertion in this file whose missing answer makes the shop unopenable.
	describe("the shopkeeper behind the counter", function()
		local container, folder
		local seen: { model: Model?, team: string?, look: any } = { model = nil, team = nil, look = nil }

		beforeEach(function()
			seen = { model = nil, team = nil, look = nil }
			container = Instance.new("Folder")
			container.Name = "LobbyKeeperSpecWorld"
			container.Parent = Workspace
			local made = Build.build(container, Vector3.new(0, 100, 0), CFG, nil, {
				rig = fakeRig,
				dress = function(model: Model, team: string, _config, look): boolean
					seen.model = model
					seen.team = team
					seen.look = look
					return true
				end,
				dressConfig = { fake = true },
			})
			folder = made
		end)

		afterEach(function()
			container:Destroy()
		end)

		it("stands one man behind the till, and counts him", function()
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true)
			expect(body).to.be.ok()
			expect((body :: Instance):IsA("Model")).to.equal(true)
			expect(Build.stats().keepers).to.equal(1)
			-- UNDER THE SHOP, with the counter and the sign: one place in the tree to look for the
			-- whole shop, which is what `Lobby.counterPart` and `Lobby.shopPrompt` rest on.
			local shop = folder:FindFirstChild("Shop", true)
			expect(shop).to.be.ok()
			expect((body :: Instance):IsDescendantOf(shop :: Instance)).to.equal(true)
			-- BEHIND the counter and not in it: further from the room by `BEHIND_STUDS`, and
			-- standing on the same floor.
			local counter = folder:FindFirstChild(Data.COUNTER_NAME, true) :: BasePart
			local root = (body :: Model).PrimaryPart :: BasePart
			expect(math.abs(root.Position.X - counter.Position.X) < 1e-3).to.equal(true)
			local behind = root.Position.Z - counter.Position.Z
			expect(math.abs(behind - CFG.LODGE.KEEPER.BEHIND_STUDS) < 1e-3).to.equal(true)
			expect(root.Position.Y > counter.Position.Y).to.equal(true)
		end)

		it("cannot be pushed, cannot be walked into, and cannot stop a pellet", function()
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true) :: Model
			local root = body.PrimaryPart :: BasePart
			-- THE ROOT IS ANCHORED AND THE LIMBS ARE NOT: `Bots.Rig.place(.., anchored = true)`'s
			-- arrangement. The anchor is what stops anything nudging him off his spot; the limbs
			-- stay on their joints so the idle clip can move them.
			expect(root.Anchored).to.equal(true)
			local parts = 0
			for _, descendant in ipairs(body:GetDescendants()) do
				if descendant:IsA("BasePart") then
					parts += 1
					expect(descendant.CanCollide).to.equal(false)
					-- `CanQuery = false` IS LOAD-BEARING and is this file's own rule everywhere else
					-- in the lobby: a body that stops a pellet changes what the shot hit.
					expect(descendant.CanQuery).to.equal(false)
					expect(descendant.CanTouch).to.equal(false)
					if descendant ~= root then
						expect(descendant.Anchored).to.equal(false)
					end
				end
			end
			expect(parts >= 4).to.equal(true)
		end)

		it("carries the prompt, with Karen's key, 8 studs and line of sight", function()
			local prompt = folder:FindFirstChild(Data.PROMPT_NAME, true)
			expect(prompt).to.be.ok()
			expect((prompt :: Instance):IsA("ProximityPrompt")).to.equal(true)
			local p = prompt :: ProximityPrompt
			local want = CFG.LODGE.KEEPER.PROMPT
			expect(p.KeyboardKeyCode).to.equal(want.KEYBOARD_KEY)
			expect(p.KeyboardKeyCode).to.equal(Enum.KeyCode.E) -- Karen's word, written twice on purpose
			expect(p.GamepadKeyCode).to.equal(want.GAMEPAD_KEY)
			expect(p.MaxActivationDistance).to.equal(want.MAX_DISTANCE)
			expect(p.MaxActivationDistance).to.equal(8)
			expect(p.HoldDuration).to.equal(0) -- a tap, not a hold
			expect(p.RequiresLineOfSight).to.equal(true)
			expect(p.ActionText).to.equal("Shop")
			expect(p.ObjectText).to.equal("Press E")
			expect(p.Enabled).to.equal(true)
			-- ON AN ATTACHMENT AT HEAD HEIGHT, AND THAT IS GEOMETRY: the counter is 3.5 studs tall
			-- and queryable, so a sight line to a root 3 studs up is stopped by the till and the
			-- prompt never appears for the one person standing where he is meant to stand.
			local at = p.Parent
			expect(at).to.be.ok()
			expect((at :: Instance):IsA("Attachment")).to.equal(true)
			-- A TOLERANCE AND NOT AN EQUALITY: `Attachment.Position` is three float32s, so 2.2 comes
			-- back out of the engine as 2.200000047683716 (measured, this spec's first run).
			local lift = (at :: Attachment).Position.Y
			expect(math.abs(lift - CFG.LODGE.KEEPER.PROMPT_HEIGHT) < 1e-5).to.equal(true)
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true) :: Model
			local root = body.PrimaryPart :: BasePart
			local promptY = root.Position.Y + (at :: Attachment).Position.Y
			-- The floor is y = 100 here (the anchor's own), so the till's top is 100 + 3.5.
			expect(promptY > 100 + CFG.LODGE.COUNTER.Y).to.equal(true)
		end)

		it("is dressed by the outfit owner and by nothing else", function()
			-- ONE DRESSING PATH IN THIS REPOSITORY: `Build` hands a MODEL and a TEAM to the seam the
			-- composition root filled with `Match.Body.dress`, and learns nothing about outfits.
			expect(seen.model).to.be.ok()
			expect(seen.team).to.equal(CFG.LODGE.KEEPER.TEAM)
			expect(seen.look.hatColor).to.equal(CFG.LODGE.KEEPER.HAT_COLOR)
			expect(Build.stats().keeperDressed).to.equal(1)
		end)

		it("builds the lodge anyway when no body comes back", function()
			-- A SPEC THAT HAS NOT ASKED FOR A BODY DOES NOT GET ONE, which is what keeps the avatar
			-- service out of this harness -- and a source that answers nil is a lodge with nobody in
			-- it, never a lobby that failed to build.
			local bare = Instance.new("Folder")
			bare.Name = "LobbyNoKeeperSpecWorld"
			bare.Parent = Workspace
			local made = Build.build(bare, Vector3.new(0, 100, 0), CFG)
			expect(made:FindFirstChild(Data.KEEPER_NAME, true)).to.equal(nil)
			expect(made:FindFirstChild(Data.COUNTER_NAME, true)).to.be.ok()
			expect(Build.stats().keepers).to.equal(0)
			local nilled = Build.build(bare, Vector3.new(0, 100, 0), CFG, nil, {
				rig = function(): Model?
					return nil
				end,
			})
			expect(nilled:FindFirstChild(Data.KEEPER_NAME, true)).to.equal(nil)
			expect(Build.stats().keepers).to.equal(0)
			bare:Destroy()
		end)

		-- THE FLAG, READ AT THE ROOT AND PASSED INWARD, decides one thing here: whether the prompt is
		-- live. With `SHOP` off the panel is dead, and a "Press E" over a man who answers nothing is
		-- worse than no prompt.
		it("hangs a DEAD prompt on him when the shop is not in this build", function()
			local off = Instance.new("Folder")
			off.Name = "LobbyShopOffSpecWorld"
			off.Parent = Workspace
			local made = Build.build(off, Vector3.new(0, 100, 0), CFG, nil, { rig = fakeRig, shopOn = false })
			local prompt = made:FindFirstChild(Data.PROMPT_NAME, true) :: ProximityPrompt
			expect(prompt).to.be.ok()
			expect(prompt.Enabled).to.equal(false)
			-- ...and the MAN is still there. He is scenery as well as a door, and a lodge that
			-- empties itself when a flag goes off is a second thing for Karen to notice.
			expect(made:FindFirstChild(Data.KEEPER_NAME, true)).to.be.ok()
			off:Destroy()
		end)

		it("holds no script anywhere in his body", function()
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true) :: Model
			for _, descendant in ipairs(body:GetDescendants()) do
				expect(descendant:IsA("LuaSourceContainer")).to.equal(false)
			end
		end)

		-- THE HEAD TURN, AND THE EPSILON IS THE POINT. The owner decides who he looks at on the scan
		-- it already runs; this writes it -- and a write per scan for a man standing still would be
		-- the bug `Lobby.stats().keeperTurns` exists to show.
		it("turns to the nearest man, and writes nothing when he has not moved", function()
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true) :: Model
			local here = (body.PrimaryPart :: BasePart).Position
			-- Somebody standing well off to one side: that is a turn.
			local side = here + Vector3.new(10, 0, -4)
			expect(Build.faceKeeper(side, CFG)).to.equal(true)
			expect((body.PrimaryPart :: BasePart).CFrame.LookVector.X > 0.5).to.equal(true)
			-- ...and asking again for the same man writes nothing.
			expect(Build.faceKeeper(side, CFG)).to.equal(false)
			-- A man beyond `FACE_STUDS` is not a man he turns to: he goes back to facing the room.
			local far = here + Vector3.new(CFG.LODGE.KEEPER.FACE_STUDS + 20, 0, 0)
			expect(Build.faceKeeper(far, CFG)).to.equal(true)
			expect((body.PrimaryPart :: BasePart).CFrame.LookVector.Z < -0.99).to.equal(true)
			expect(Build.faceKeeper(nil, CFG)).to.equal(false)
		end)

		-- THE CLIENT'S OWN READER, against a lobby built where it actually looks. It is the only
		-- route the panel has to the prompt, so a renamed part or a prompt on the wrong instance is
		-- a shop nobody can open -- and `Workspace.Lobby` is where the live server builds it.
		it("is found by `Lobby.shopPrompt`, the one reader the client has", function()
			local live = Build.build(Workspace, Vector3.new(0, 100, 0), CFG, nil, { rig = fakeRig })
			local prompt = Data.shopPrompt()
			expect(prompt).to.be.ok()
			expect((prompt :: Instance):IsDescendantOf(live)).to.equal(true)
			live:Destroy()
			-- AND THE CACHE DIES WITH THE INSTANCE (`Lobby.counterPart`'s own rule): a stale prompt
			-- would be a panel listening to a lodge that is not there any more.
			expect(Data.shopPrompt()).to.equal(nil)
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
