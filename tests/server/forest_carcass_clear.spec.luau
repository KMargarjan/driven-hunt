-- forest_carcass_clear.spec: THE PREVIOUS DRIVE'S BODIES ARE GONE WHEN THE NEXT DRIVE STARTS, and
-- a kill inside the current drive is not taken early (task 362). Karen, 2026-11-13: *"dribve
-- started leftover from prebviuos"*.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- IT DRIVES A REAL RUNTIME AND NOT A FAKE, because the thing under test is which ENTRIES go: a
-- stub with a counter would pass with the predicate inverted. One animal is killed and one is left
-- on its feet, and the case asserts both halves.
--
-- Design: docs/design/forest-drive.md section 9.4 (why the drive cannot do this itself)
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Forest = require(ServerScriptService:WaitForChild("ForestTest"))

-- `boar_hit.spec`'s own field, verbatim: the runtime reads `field.groundY` when the world has no
-- `groundAt`, and `bounds`/`exitZ` are what keep a hit animal from running off the edge mid-case.
local GROUND_Y = 500
local FIELD = {
	bounds = { minX = -150, maxX = 150, minZ = -150, maxZ = 150 },
	exitZ = -140,
	groundY = GROUND_Y,
}

-- Two minutes of carcass would be two minutes of suite; the boundary is what is under test, not the
-- lifetime (`boar_hit.spec` makes the same trade for the same reason).
local CARCASS_SECONDS = 30

local function specWound()
	local wound = table.clone(Boar.CONFIG.WOUND)
	wound.CARCASS_SECONDS = CARCASS_SECONDS
	return wound
end

-- The grey box, so no asset has to arrive for a body to exist (`boar_hit.spec`'s own reason).
local function specModel()
	local model = table.clone(Boar.CONFIG.MODEL)
	model.ENABLED = false
	model.ANIMATION_IDS = table.clone(Boar.CONFIG.MODEL.ANIMATION_IDS)
	return model
end

local function waitUntil(timeout: number, predicate: () -> boolean): boolean
	local started = os.clock()
	while os.clock() - started < timeout do
		if predicate() then
			return true
		end
		task.wait()
	end
	return predicate()
end

return function()
	describe("the Forest Test's own drive boundary", function()
		local testRoot, runtime, dead, alive, disconnect

		local function newWorld()
			return {
				field = FIELD,
				parent = testRoot,
				folderName = "Boars",
				rng = Random.new(362),
				config = { WOUND = specWound(), MODEL = specModel() },
				threats = function()
					return {}
				end,
				probe = function()
					return false
				end,
				requestPath = function(_id, _from, _to, done)
					done(nil)
				end,
				releasePath = function() end,
			}
		end

		beforeEach(function()
			testRoot = Instance.new("Folder")
			testRoot.Name = "ForestCarcassClearSpec"
			local plate = Instance.new("Part")
			plate.Name = "Plate"
			plate.Size = Vector3.new(320, 4, 320)
			plate.Position = Vector3.new(0, GROUND_Y - 2, 0)
			plate.Anchored = true
			plate.Parent = testRoot
			testRoot.Parent = Workspace

			runtime = Boar.newRuntime(newWorld())
			dead = runtime:spawn(Vector3.new(-20, GROUND_Y, 60))
			alive = runtime:spawn(Vector3.new(20, GROUND_Y, 60))
			disconnect = runtime:run()

			-- ONE OF THE TWO IS KILLED, through the damage seam and not by setting a flag, so what
			-- the case clears is the same body a player's shot leaves behind.
			runtime:takeHit(dead.part, { zone = "chest", ammo = "Slug", pellets = 1, at = os.clock() })
			expect(waitUntil(2, function()
				return dead.part:GetAttribute("Carcass") == true
			end)).to.equal(true)
			expect(alive.part:GetAttribute("Carcass")).never.to.equal(true)
		end)

		afterEach(function()
			if disconnect then
				disconnect()
				disconnect = nil
			end
			runtime:destroy()
			testRoot:Destroy()
		end)

		-- L-028: delete `Runtime:clearCarcasses` (or the call in
		-- `ForestTest.clearPreviousDriveCarcasses`) and this case fails -- the body is still in the
		-- world at the next drive's start, which is exactly Karen's frame.
		it("takes the previous drive's bodies at the drive's end, and leaves the wood", function()
			expect(Forest.CARCASS_CLEAR_PHASES.Scoring).to.equal(true)
			expect(Forest.clearPreviousDriveCarcasses(runtime, "Scoring")).to.equal(1)

			expect(dead.part.Parent == nil).to.equal(true)
			expect(alive.part.Parent).to.be.ok()
			expect(runtime:count()).to.equal(1)
			expect(runtime:liveCount()).to.equal(1)
		end)

		-- THE BACKSTOP, for a drive that ends any other way: the next drive's own edge takes
		-- whatever is left. It is the same door, so this case only asserts the edge is in the set.
		it("takes them at the next drive's start too", function()
			expect(Forest.CARCASS_CLEAR_PHASES.Assigning).to.equal(true)
			expect(Forest.clearPreviousDriveCarcasses(runtime, "Assigning")).to.equal(1)
			expect(dead.part.Parent == nil).to.equal(true)
			expect(alive.part.Parent).to.be.ok()
		end)

		-- L-093, the other branch: inside the drive the kill stays where it fell. `Running` is the
		-- phase a player is shooting in, and the set is the owner's own, so this case cannot drift
		-- away from the two above.
		it("removes nothing on any other phase -- a kill inside the drive stays where it fell", function()
			for _, phase in ipairs({ "Waiting", "Running" }) do
				expect(Forest.CARCASS_CLEAR_PHASES[phase]).never.to.equal(true)
				expect(Forest.clearPreviousDriveCarcasses(runtime, phase)).to.equal(0)
				expect(dead.part.Parent).to.be.ok()
				expect(dead.part:GetAttribute("Carcass")).to.equal(true)
			end
			expect(runtime:count()).to.equal(2)
		end)

		-- THE OWNER BOUNDARY IS UNMOVED (design section 9.4): the drive's view of this world's
		-- animals still has no door that removes one, the new one included.
		it("does not hand the drive a way to remove an animal here", function()
			local view = Forest.readOnlyBoars(runtime)
			expect(view.clear).to.equal(nil)
			expect(view.clearCarcasses).to.equal(nil)
			expect(view.spawn).to.equal(nil)
			expect(view.spawnSounder).to.equal(nil)
		end)
	end)
end
