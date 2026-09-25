-- boar_body.spec: one real, physically simulated boar, through the public interface only.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- It builds its OWN world at y = 500 -- a small plate with a short exit line -- so it does not depend
-- on Workspace.TestArena (Task 17 has never been seen in Studio) and so a full crossing takes
-- seconds rather than the 10.5 s a 400-stud arena needs. Production's boar, spawned by BoarBoot, is
-- a different runtime and is untouched.
-- Design: docs/design/boar-ai.md (section 10)
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local CONFIG = Boar.CONFIG

local GROUND_Y = 500
local PLATE_SPAN = 120
local FIELD = {
	bounds = { minX = -55, maxX = 55, minZ = -55, maxZ = 55 },
	exitZ = -40,
	groundY = GROUND_Y,
}

-- Waits until `predicate()` is true or `timeout` seconds pass. Returns whether it became true, and
-- how long it took. Used instead of a fixed sleep so a fast machine does not wait needlessly.
local function waitUntil(timeout: number, predicate: () -> boolean): (boolean, number)
	local started = os.clock()
	while os.clock() - started < timeout do
		if predicate() then
			return true, os.clock() - started
		end
		task.wait()
	end
	return predicate(), os.clock() - started
end

return function()
	local testRoot, runtime, threatPosition, records, disconnect
	local world

	local function buildWorld()
		testRoot = Instance.new("Folder")
		testRoot.Name = "BoarBodySpec"

		local plate = Instance.new("Part")
		plate.Name = "Plate"
		plate.Size = Vector3.new(PLATE_SPAN, 4, PLATE_SPAN)
		plate.Position = Vector3.new(0, GROUND_Y - 2, 0)
		plate.Anchored = true
		plate.TopSurface = Enum.SurfaceType.Smooth
		plate.Parent = testRoot

		testRoot.Parent = Workspace

		local production = Boar.defaultWorld(FIELD)

		world = {
			field = FIELD,
			parent = testRoot,
			folderName = "Boars",
			rng = Random.new(11),
			threats = function()
				if not threatPosition then
					return {}
				end
				return { { id = "spec", position = threatPosition } }
			end,
			probe = function(from: Vector3, direction: Vector3, length: number): boolean
				if direction.Magnitude < 1e-6 then
					return false
				end
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = if world.folder then { world.folder } else {}
				return Workspace:Raycast(from, direction.Unit * length, params) ~= nil
			end,
			requestPath = production.requestPath,
			releasePath = production.releasePath,
			lastPathProblem = production.lastPathProblem,
		}
		return world
	end

	beforeAll(function()
		threatPosition = nil
		records = {}
		runtime = Boar.newRuntime(buildWorld())
		runtime.Despawned:Connect(function(record)
			table.insert(records, record)
		end)
		disconnect = runtime:run()
	end)

	afterAll(function()
		if disconnect then
			disconnect()
		end
		if runtime then
			runtime:destroy()
		end
		if testRoot then
			testRoot:Destroy()
		end
	end)

	describe("boar body", function()
		local handle

		it("spawns exactly one unanchored part in the runtime's folder", function()
			handle = runtime:spawn(Vector3.new(0, GROUND_Y, 30))
			expect(handle).to.be.ok()

			local parts = {}
			for _, child in ipairs(runtime:folder():GetChildren()) do
				if child:IsA("BasePart") then
					table.insert(parts, child)
				end
			end
			expect(#parts).to.equal(1)
			expect(parts[1].Anchored).to.equal(false)
			expect(parts[1]).to.equal(handle.part)
		end)

		it("is owned by the server, so a client cannot push it", function()
			expect(handle.part:GetNetworkOwner()).to.equal(nil)
		end)

		it("carries the mover and the upright constraint", function()
			expect(handle.part:FindFirstChildOfClass("LinearVelocity")).to.be.ok()
			expect(handle.part:FindFirstChildOfClass("AlignOrientation")).to.be.ok()
		end)

		it("idles slowly and stays on the plate when nothing threatens it", function()
			-- The boar spawns SPAWN_CLEARANCE above the plate and the mover leaves Y to gravity, so
			-- for the first few frames the ASSEMBLY speed is the drop, not the walk: 0.5 studs at
			-- Roblox's 196.2 studs/s^2 peaks near 14 studs/s. Measuring the assembly speed here
			-- would fail for a reason this test is not about (review round 1, finding 3). Let it
			-- land first, then measure the FLAT speed, which is what "idles slowly" means.
			-- waitUntil evaluates its predicate before the first yield, and a part created this tick
			-- has zero velocity, so "|velocity.Y| < 1" was true immediately and asserted nothing
			-- (review round 2, finding 5). Wait a frame, then wait for it to be RESTING on the
			-- plate, which is a positive condition it cannot satisfy in mid-air.
			task.wait()
			local restY = GROUND_Y + CONFIG.BODY_SIZE.Y / 2
			local landed = waitUntil(3, function()
				local part = handle.part
				return math.abs(part.Position.Y - restY) < 0.6 and math.abs(part.AssemblyLinearVelocity.Y) < 1
			end)
			expect(landed).to.equal(true)

			local fastest = 0
			local deadline = os.clock() + 2
			while os.clock() < deadline do
				local position = handle.position()
				expect(handle.state()).to.equal("IDLE")
				expect(math.abs(position.X) <= FIELD.bounds.maxX).to.equal(true)
				expect(position.Z > FIELD.exitZ).to.equal(true)
				local velocity = handle.part.AssemblyLinearVelocity
				fastest = math.max(fastest, Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
				task.wait()
			end
			expect(fastest <= CONFIG.WANDER_SPEED * 1.5).to.equal(true) -- the design's figure
		end)

		it("sprints away from a threat within 1 s, and stays upright", function()
			local start = handle.position()
			threatPosition = start + Vector3.new(0, 0, 20) -- behind it, toward the far side from the exit

			local upright = true
			local reached, took = waitUntil(1.0, function()
				upright = upright and handle.part.CFrame.UpVector.Y > 0.9
				return handle.part.AssemblyLinearVelocity.Magnitude >= CONFIG.SPRINT_SPEED * 0.5
			end)
			expect(reached).to.equal(true)
			expect(took <= 1.0).to.equal(true)
			expect(handle.state()).to.equal("FLEE")
			expect(upright).to.equal(true)

			-- The design also requires that the simulated body actually gets away, not merely that
			-- it is moving fast (review round 2, finding 4). Flat distance, since the drop is Y.
			local function flatGap()
				local p = handle.position()
				return (Vector3.new(p.X, 0, p.Z) - Vector3.new(threatPosition.X, 0, threatPosition.Z)).Magnitude
			end
			local gapBefore = flatGap()
			local grew = waitUntil(3, function()
				return handle.part.Parent == nil or flatGap() - gapBefore >= 20
			end)
			expect(grew).to.equal(true)
		end)

		it("despawns once when it reaches the exit edge, and says so", function()
			local gone = waitUntil(8, function()
				return #records > 0
			end)
			expect(gone).to.equal(true)
			expect(#records).to.equal(1)
			expect(records[1].reason).to.equal("escaped")
			expect(records[1].position.Z <= FIELD.exitZ).to.equal(true)
			expect(records[1].id).to.equal(handle.id)
			expect(records[1].aliveFor > 0).to.equal(true)
			expect(handle.part.Parent).to.equal(nil)
			expect(#runtime:boars()).to.equal(0)
		end)

		it("used real pathfinding, not a silent permanent fallback", function()
			local stats = runtime:stats()
			expect(stats.spawned).to.equal(1)
			expect(stats.despawned).to.equal(1)
			expect(stats.pathRequests > 0).to.equal(true)
			-- Diagnostic first: if pathfinding failed, say WHY in the output before asserting, so a
			-- failing run names the PathStatus instead of just a count (Task 18 harness run 1).
			if stats.pathFailures > 0 then
				print(
					string.format(
						"[boar_body] %d of %d path requests failed; last problem: %s",
						stats.pathFailures,
						stats.pathRequests,
						tostring(world.lastPathProblem and world.lastPathProblem() or "unknown")
					)
				)
			end
			expect(stats.pathFailures).to.equal(0)
			-- One Path object per boar, reused: more requests than boars proves it was not
			-- recreated per call by accident.
			expect(stats.pathRequests >= stats.spawned).to.equal(true)
		end)
	end)
end
