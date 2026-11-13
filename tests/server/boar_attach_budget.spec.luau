-- boar_attach_budget.spec: the frame budget on `Body.attachVisual`, behind `BOAR_ATTACH_BUDGET`
-- (task 355). Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- WHAT IT IS FOR. MEASURED in Karen's Forest Test, cell C1, one 340 s drive at `402aec2e`
-- (`<runs-dir>/BEFORE-track.txt`): the boar runtime's worst step was 104.2 ms and 92.1 ms of it was
-- attaching models, because a wave releases ten animals and all ten are built in the same step. The
-- budget stops a step once it has spent `MODEL.ATTACH_BUDGET_MS` on attaching; the animals it did
-- not reach are attached on the NEXT pass, because the step already asks `visual == nil` of every
-- animal every frame. So the thing that has to be proved is **defer, never drop**.
--
-- WHY THE BUDGET IS INFINITESIMAL HERE AND 8 ms IN THE GAME. A spec cannot make an attach cost a
-- known number of milliseconds. It does not have to: the test is made BEFORE the call, so with a
-- budget smaller than any real attach the first animal of a step is always let through (the frame
-- has spent 0 so far) and every later one is always stopped. **One attach per step, exactly**, which
-- is the same rule the game runs with its 8 ms and is deterministic here.
--
-- Note:   docs/research/2026-11-12-frame-budget-for-attaching-models.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Boar = require(ServerScriptService:WaitForChild("Boar"))

local CONFIG = Boar.CONFIG
local MODEL = CONFIG.MODEL

local GROUND_Y = 760 -- its own plate, clear of boar_model.spec's at 620
local PLATE_SPAN = 120
local FIELD = {
	bounds = { minX = -55, maxX = 55, minZ = -55, maxZ = 55 },
	exitZ = -40,
	groundY = GROUND_Y,
}
-- The real model's measured size, the same number `boar_model.spec` builds its fake at.
local MESH_SIZE = Vector3.new(1.4011, 3.2573, 5.5)
local TINY_BUDGET_MS = 1e-6 -- smaller than any real attach: one animal per step, exactly

return function()
	local testRoot: Folder
	local plate: Part
	local runtimes = {}

	local function buildWorld(budgetMs: number, folderName: string)
		return {
			field = FIELD,
			parent = testRoot,
			folderName = folderName,
			rng = Random.new(355),
			threats = function()
				return {}
			end,
			probe = function()
				return false
			end,
			requestPath = function(_agentId, _from, _to, done)
				done(nil)
			end,
			releasePath = function() end,
			config = {
				-- BOTH VALUES ARRIVE AS PARAMETERS, which is what keeps both branches reachable
				-- while `Flags.DEFAULTS.BOAR_ATTACH_BUDGET` sits at one of them (CLAUDE.md, feature
				-- flags). A clone, because the runtime must not be handed the module's own table.
				MODEL = (function()
					local copy = table.clone(MODEL)
					copy.ENABLED = true
					copy.ATTACH_BUDGET_MS = budgetMs
					return copy
				end)(),
			},
		}
	end

	-- Shaped like the real import, for the reason `boar_model.spec`'s own `makeTemplate` gives:
	-- `Model > Model > { MeshPart, InitialPoses, AnimationController }`.
	local function makeTemplate(): Model
		local model = Instance.new("Model")
		model.Name = "FakeBoarTemplate"
		local inner = Instance.new("Model")
		inner.Name = "Boar Male RedDeer v3"
		local mesh = Instance.new("MeshPart")
		mesh.Name = "BoarMale_NoAlpha"
		mesh.Size = MESH_SIZE
		mesh.Anchored = true
		local bone = Instance.new("Bone")
		bone.Name = "root_bone"
		bone.Parent = mesh
		mesh.Parent = inner
		local poses = Instance.new("Folder")
		poses.Name = "InitialPoses"
		poses.Parent = inner
		local theirs = Instance.new("AnimationController")
		theirs.Parent = inner
		inner.Parent = model
		inner.PrimaryPart = mesh
		model.PrimaryPart = mesh
		model.Parent = testRoot
		return model
	end

	local function newRuntime(budgetMs: number, folderName: string)
		local template = makeTemplate()
		local runtime = Boar.newRuntime(buildWorld(budgetMs, folderName))
		runtime:setModelSource(function()
			return template
		end, function()
			return 10001
		end)
		table.insert(runtimes, runtime)
		return runtime
	end

	-- HOW MANY OF THE LIVE ANIMALS ARE DRESSED, off the trunk every handle names: `MODEL.NAME` is
	-- the one child `attachVisual` adds, so this counts what was actually built and not what some
	-- counter says was built.
	local function dressed(runtime): (number, number)
		local total, drawn = 0, 0
		for _, handle in ipairs(runtime:boars()) do
			total += 1
			local part = runtime:rootOf(handle.id)
			if part ~= nil and part:FindFirstChild(MODEL.NAME) ~= nil then
				drawn += 1
			end
		end
		return drawn, total
	end

	local function spawnFour(runtime)
		for index = 1, 4 do
			runtime:spawn(Vector3.new(index * 6 - 15, GROUND_Y + 3, 0))
		end
	end

	beforeAll(function()
		testRoot = Instance.new("Folder")
		testRoot.Name = "BoarAttachBudgetSpec"
		plate = Instance.new("Part")
		plate.Name = "Plate"
		plate.Size = Vector3.new(PLATE_SPAN, 4, PLATE_SPAN)
		plate.Position = Vector3.new(0, GROUND_Y - 2, 0)
		plate.Anchored = true
		plate.TopSurface = Enum.SurfaceType.Smooth
		plate.Parent = testRoot
		testRoot.Parent = Workspace
	end)

	afterAll(function()
		for _, runtime in ipairs(runtimes) do
			runtime:destroy()
		end
		if testRoot then
			testRoot:Destroy()
		end
	end)

	describe("the flag is declared, born OFF, and its owner reads it at one boundary", function()
		it("is a row owned by the boar, born 2026-11-12, default false, expiring within 21 days", function()
			local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
			local row = Flags.DEFAULTS.BOAR_ATTACH_BUDGET
			expect(row).to.be.ok()
			expect(row.default).to.equal(false)
			expect(row.born:find("2026%-11%-12")).to.be.ok()
			expect(row.expires:find("2026%-12%-03")).to.be.ok()
		end)

		it("leaves ATTACH_BUDGET_MS at 0 while the flag is off, and 0 is no budget at all", function()
			-- THE OFF WORLD IS TODAY'S, BYTE FOR BYTE. The boundary is a single `if ... then 8 else
			-- 0`, so the published config says which side it is on, and 0 is the value the step
			-- tests for when it decides there is no budget.
			local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
			if Flags.isOn("BOAR_ATTACH_BUDGET") then
				expect(MODEL.ATTACH_BUDGET_MS).to.equal(8)
			else
				expect(MODEL.ATTACH_BUDGET_MS).to.equal(0)
			end
		end)
	end)

	describe("with no budget, one step dresses every animal -- the world before task 355", function()
		it("attaches all four in a single step", function()
			local runtime = newRuntime(0, "BoarsBudgetOff")
			spawnFour(runtime)
			runtime:step(1 / 60)
			local drawn, total = dressed(runtime)
			expect(total).to.equal(4)
			expect(drawn).to.equal(4)
		end)
	end)

	describe("with a budget, the step dresses what it can afford and DEFERS the rest", function()
		-- FAIL FIRST, AND THIS IS THE CASE THAT CARRIES IT (the first `it` below covers the budget
		-- itself): delete `mayAttach` from the step's `if`, or make it always true, and this reads
		-- 4 instead of 1.
		it("attaches exactly one animal in the first step", function()
			local runtime = newRuntime(TINY_BUDGET_MS, "BoarsBudgetOnFirst")
			spawnFour(runtime)
			runtime:step(1 / 60)
			local drawn, total = dressed(runtime)
			expect(total).to.equal(4)
			expect(drawn).to.equal(1)
		end)

		it("attaches one more on each following step, and leaves NOBODY undressed", function()
			-- DEFER, NEVER DROP. This is the assertion that fails if the budget SKIPS the work
			-- rather than postponing it (L-093): four animals, four steps, four models. The counts
			-- in between are asserted too, so a budget that silently did all four on step 2 would
			-- fail here rather than pass on the total.
			local runtime = newRuntime(TINY_BUDGET_MS, "BoarsBudgetOnAll")
			spawnFour(runtime)
			local seen = {}
			for _ = 1, 4 do
				runtime:step(1 / 60)
				local drawn = dressed(runtime)
				table.insert(seen, drawn)
			end
			expect(table.concat(seen, ",")).to.equal("1,2,3,4")
			local drawn, total = dressed(runtime)
			expect(total).to.equal(4)
			expect(drawn).to.equal(4)
		end)

		it("changes nothing else: the same four animals, alive, in the same folder", function()
			-- SAME ANIMALS, SAME COUNTS (the dispatch's "behaviour identical"). The budget is a rule
			-- about WHEN a model is built and about nothing else, so the population the runtime
			-- reports after the deferred passes is the population it reported before them.
			local runtime = newRuntime(TINY_BUDGET_MS, "BoarsBudgetOnCounts")
			spawnFour(runtime)
			local before = runtime:count()
			runtime:step(1 / 60)
			expect(runtime:count()).to.equal(before)
			for _ = 1, 3 do
				runtime:step(1 / 60)
			end
			expect(runtime:count()).to.equal(4)
			expect(runtime:liveCount()).to.equal(4)
		end)
	end)
end
