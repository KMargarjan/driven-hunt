-- test_arena.spec: asserts the grey-box test area the server built at start (ROADMAP.md step 1.1).
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- It checks what a player would meet in Workspace, not the module's own constants, so the numbers
-- below are written out independently of src/server/TestArena.luau (CLAUDE.md rule 6).
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local TestArena = require(ServerScriptService:WaitForChild("TestArena"))

local FOLDER_NAME = "TestArena"
local GROUND_SPAN = 400 -- studs, X and Z
local GROUND_TOP = 0 -- y of the walkable surface
local HALF_SPAN = GROUND_SPAN / 2
local MIN_BLOCKS = 6
local MAX_BLOCKS = 10
local EPSILON = 0.001

-- Script start order is not guaranteed, so give ArenaBoot up to 5 s, as sync.spec does for SyncCheck.
local function waitForArena()
	local deadline = os.clock() + 5
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	while not folder and os.clock() < deadline do
		task.wait(0.1)
		folder = Workspace:FindFirstChild(FOLDER_NAME)
	end
	return folder
end

return function()
	describe("test arena", function()
		it("is built under one Workspace folder", function()
			local folder = waitForArena()
			expect(folder).to.be.ok()
			expect(folder.ClassName).to.equal("Folder")
		end)

		it("has a 400x400 ground plate whose surface is at y = 0", function()
			local ground = waitForArena():FindFirstChild("Ground")
			expect(ground).to.be.ok()
			expect(ground:IsA("BasePart")).to.equal(true)
			expect(ground.Anchored).to.equal(true)
			expect(ground.Size.X).to.equal(GROUND_SPAN)
			expect(ground.Size.Z).to.equal(GROUND_SPAN)
			expect(ground.Size.Y > 0).to.equal(true)
			-- Flat: the top surface sits at y = 0 and the plate is centred on the origin in X/Z.
			expect(math.abs((ground.Position.Y + ground.Size.Y / 2) - GROUND_TOP) < EPSILON).to.equal(true)
			expect(ground.Position.X).to.equal(0)
			expect(ground.Position.Z).to.equal(0)
		end)

		it("has 6 to 10 anchored cover blocks, all inside the ground plate", function()
			local folder = waitForArena()
			local blocks = {}
			for _, child in ipairs(folder:GetChildren()) do
				if child:IsA("BasePart") and child.Name ~= "Ground" and not child:IsA("SpawnLocation") then
					table.insert(blocks, child)
				end
			end
			expect(#blocks >= MIN_BLOCKS).to.equal(true)
			expect(#blocks <= MAX_BLOCKS).to.equal(true)

			for _, block in ipairs(blocks) do
				expect(block.Anchored).to.equal(true)
				-- The whole footprint, not just the centre, must be on the plate.
				local halfX = block.Size.X / 2
				local halfZ = block.Size.Z / 2
				expect(math.abs(block.Position.X) + halfX <= HALF_SPAN).to.equal(true)
				expect(math.abs(block.Position.Z) + halfZ <= HALF_SPAN).to.equal(true)
				-- And it must stand on the ground, not float or sink.
				expect(math.abs((block.Position.Y - block.Size.Y / 2) - GROUND_TOP) < EPSILON).to.equal(true)
			end
		end)

		it("has one SpawnLocation standing on the ground, inside the plate", function()
			local folder = waitForArena()
			local spawns = {}
			for _, child in ipairs(folder:GetChildren()) do
				if child:IsA("SpawnLocation") then
					table.insert(spawns, child)
				end
			end
			expect(#spawns).to.equal(1)

			local spawnPad = spawns[1]
			expect(spawnPad.Anchored).to.equal(true)
			expect(spawnPad.Enabled).to.equal(true)
			expect(math.abs((spawnPad.Position.Y - spawnPad.Size.Y / 2) - GROUND_TOP) < EPSILON).to.equal(true)
			expect(math.abs(spawnPad.Position.X) + spawnPad.Size.X / 2 <= HALF_SPAN).to.equal(true)
			expect(math.abs(spawnPad.Position.Z) + spawnPad.Size.Z / 2 <= HALF_SPAN).to.equal(true)
		end)
	end)

	-- Milestone 1.7a: the drive's gameplay markers. The TAG is the contract -- Match.Markers asks
	-- CollectionService and never looks at a name -- and this repo's harness compares attributes but
	-- NOT tags, so this spec is the only proof they are there at all.
	-- Design: docs/design/drive.md (sections 6.1, 12.5)
	describe("the drive's markers", function()
		local function tagged(tag: string): { BasePart }
			local out = {}
			for _, instance in ipairs(CollectionService:GetTagged(tag)) do
				if instance:IsA("BasePart") and instance:IsDescendantOf(Workspace) then
					table.insert(out, instance)
				end
			end
			return out
		end

		it("places eight posts, one line, one driver start, four boar spawns and four trees", function()
			expect(waitForArena()).to.be.ok()
			expect(#tagged("DrivenHunt.ShooterPost")).to.equal(8)
			expect(#tagged("DrivenHunt.DriveLine")).to.equal(1)
			expect(#tagged("DrivenHunt.DriverStart")).to.equal(1)
			expect(#tagged("DrivenHunt.BoarSpawn")).to.equal(4)
			expect(#tagged("DrivenHunt.Tree")).to.equal(4)
		end)

		it("points the drive line AT THE DRIVERS, which is the direction the safety rule reads", function()
			-- One assertion, and it is the difference between the rule firing on the right shots and
			-- on exactly the wrong ones. A part's LookVector is its -Z face.
			local line = tagged("DrivenHunt.DriveLine")[1]
			expect(line).to.be.ok()
			expect(line.CFrame.LookVector.Z > 0.99).to.equal(true)
			expect(math.abs(line.Position.Z - -150) < EPSILON).to.equal(true)
		end)

		it("spaces the posts 40 studs apart, inside the plate and in front of the exit line", function()
			local posts = tagged("DrivenHunt.ShooterPost")
			table.sort(posts, function(a, b)
				return a.Position.X < b.Position.X
			end)
			for index, post in ipairs(posts) do
				-- inside the ground plate
				expect(math.abs(post.Position.X) + post.Size.X / 2 <= HALF_SPAN).to.equal(true)
				expect(math.abs(post.Position.Z) + post.Size.Z / 2 <= HALF_SPAN).to.equal(true)
				-- strictly between the boar's exit line (-190) and the driver start (+170), so a
				-- boar that beats the line still has room to leave
				expect(post.Position.Z > -190 and post.Position.Z < 170).to.equal(true)
				if index > 1 then
					local gap = post.Position.X - posts[index - 1].Position.X
					expect(math.abs(gap - 40) < EPSILON).to.equal(true)
				end
			end
		end)

		it("puts the boar spawns beyond the posts, where a drive starts from", function()
			local posts = tagged("DrivenHunt.ShooterPost")
			local spawns = tagged("DrivenHunt.BoarSpawn")
			local start = tagged("DrivenHunt.DriverStart")[1]
			for _, spawnPart in ipairs(spawns) do
				expect(spawnPart.Position.Z > posts[1].Position.Z).to.equal(true)
				expect(spawnPart.Position.Z < start.Position.Z).to.equal(true)
			end
		end)

		it("re-uses the corner pillars as trees rather than building more", function()
			local trees = tagged("DrivenHunt.Tree")
			for _, tree in ipairs(trees) do
				expect(string.sub(tree.Name, 1, 6)).to.equal("Pillar")
			end
		end)

		it("tags nothing twice, however often the arena is built", function()
			-- TestArena.build is idempotent by contract (its own header says so); a second call must
			-- not produce a second set of tags, or Markers would see two drive lines and refuse to
			-- start a drive at all.
			local before = #tagged("DrivenHunt.ShooterPost")
			TestArena.build()
			expect(#tagged("DrivenHunt.ShooterPost")).to.equal(before)
		end)
	end)
end
