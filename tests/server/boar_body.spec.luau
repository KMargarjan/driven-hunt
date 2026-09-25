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
			pathProblems = production.pathProblems,
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

		it("asked for real paths, and escaped even though this plate has no navmesh", function()
			local stats = runtime:stats()
			expect(stats.spawned).to.equal(1)
			expect(stats.despawned).to.equal(1)
			expect(stats.pathRequests > 0).to.equal(true)
			-- One Path object per boar, reused: more requests than boars proves it was not
			-- recreated per call by accident.
			expect(stats.pathRequests >= stats.spawned).to.equal(true)

			-- MEASURED, Task 18 harness runs 1-2: on this spec's own plate almost every
			-- ComputeAsync returns Enum.PathStatus.NoPath. That is a fact about Roblox's navmesh on
			-- a small platform floating at y = 500 in an otherwise empty region, NOT about this
			-- code: an Edit-mode probe of the same agent parameters at y = 0 returns Success with
			-- 54 waypoints from CONFIG.spawnPoint to the exit line, and the test below asserts that
			-- in the real field. So asserting pathFailures == 0 here asserted the wrong thing.
			--
			-- What this spec CAN prove, and does, is the property that matters when a path fails:
			-- the boar does not freeze. It sprinted, it got away, and it despawned as "escaped" -
			-- the tests above - on the Reynolds fallback alone. If a failure ever arrives with a
			-- reason other than NoPath, that is new and this fails.
			if stats.pathFailures > 0 then
				-- EVERY distinct reason, not just the last: with 37 failures a single rare pcall
				-- error would otherwise be discarded by the next NoPath (review round 4, finding 2).
				-- NoPath is the one reason this plate is expected to produce; any other is new.
				local counted = 0
				for reason, count in pairs(world.pathProblems()) do
					print(string.format("[boar_body] spec plate: %d x %s", count, reason))
					expect(reason).to.equal(tostring(Enum.PathStatus.NoPath))
					counted += count
				end
				-- MEASURED: 37 world failures against 36 runtime failures. The two counters
				-- deliberately count different things and asserting them equal was wrong.
				-- `pathProblems` is the WORLD's tally of every ComputeAsync that failed;
				-- `stats.pathFailures` is the RUNTIME's tally of failures that reached a live boar,
				-- and Runtime:_requestPath drops a reply whose boar has already despawned
				-- (`entry.dead`). So a request still in flight when the boar escapes is counted once
				-- by the world and not at all by the runtime, and world >= runtime is the invariant.
				expect(counted >= stats.pathFailures).to.equal(true)
			end
		end)

		it("routes AROUND the arena's cover, not straight over the Baseplate", function()
			-- Round 4, finding 1: the first version of this test never waited for the arena and never
			-- checked it was there, so it could pass over the default Baseplate alone - and did. 54
			-- waypoints for a 210-stud route is a straight line, which means WallWest was not in the
			-- navmesh at all, and a route that does not detour proves nothing about routing around
			-- cover - which is the whole reason the boar paths instead of running straight.
			local arena = nil
			local appeared = waitUntil(5, function()
				arena = Workspace:FindFirstChild("TestArena")
				return arena ~= nil
			end)
			expect(appeared).to.equal(true)
			local wall = arena:FindFirstChild("WallWest")
			expect(wall).to.be.ok()

			local production = Boar.defaultWorld()
			local field = CONFIG.field
			local from = CONFIG.spawnPoint + Vector3.new(0, CONFIG.BODY_SIZE.Y / 2, 0)
			local to = Vector3.new(CONFIG.spawnPoint.X, field.groundY, field.exitZ)

			local replied, waypoints = false, nil
			production.requestPath("arena-probe", from, to, function(points)
				replied, waypoints = true, points
			end, function() end)
			local got = waitUntil(10, function()
				return replied
			end)
			expect(got).to.equal(true)
			if not waypoints then
				for reason, count in pairs(production.pathProblems()) do
					print(string.format("[boar_body] arena path failed: %d x %s", count, reason))
				end
			end
			expect(waypoints).to.be.ok()
			expect(#waypoints > 0).to.equal(true)

			-- The route runs from x = spawnPoint.X straight at WallWest (80 studs wide, centred on
			-- x = -60, lying across z = -100), so a real navmesh route has to leave that line to get
			-- past either end of it. A straight line does not.
			local lateral = 0
			for _, point in ipairs(waypoints) do
				lateral = math.max(lateral, math.abs(point.X - from.X))
				local insideX = math.abs(point.X - wall.Position.X) <= wall.Size.X / 2
				local insideZ = math.abs(point.Z - wall.Position.Z) <= wall.Size.Z / 2
				expect(insideX and insideZ).to.equal(false) -- never routed through the wall itself
			end
			print(string.format("[boar_body] arena route: %d waypoints, max lateral %.1f", #waypoints, lateral))
			expect(lateral > 15).to.equal(true)
			production.releasePath("arena-probe")
		end)
	end)
end
