-- test_arena.spec: asserts the grey-box test area the server built at start (ROADMAP.md step 1.1).
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- It checks what a player would meet in Workspace, not the module's own constants, so the numbers
-- below are written out independently of src/server/TestArena.luau (CLAUDE.md rule 6).
local Workspace = game:GetService("Workspace")

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
end
