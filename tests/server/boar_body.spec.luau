-- boar_body.spec: one real, physically simulated boar, through the public interface only.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- It builds its OWN world at y = 500 -- a small plate with a short exit line -- so it does not depend
-- on Workspace.TestArena (Task 17 has never been seen in Studio) and so a full crossing takes
-- seconds rather than the 10.5 s a 400-stud arena needs. Production's boar, spawned by BoarBoot, is
-- a different runtime and is untouched.
-- Design: docs/design/boar-ai.md (section 10)
local RunService = game:GetService("RunService")
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

-- WHY THERE IS A SECOND WAITER HERE (Task 36). Everything below is physically simulated, and Studio
-- THROTTLES PHYSICS when its frame rate falls -- so a claim written as "n studs in m seconds of wall
-- clock" is a race against whatever else the machine is doing, not a test of the boar. One did lose
-- that race under harness load on 2026-09-25 and passed on a re-run, which is the worst kind of red.
-- This steps the boar's OWN simulation instead: it counts Heartbeat frames and the distance the body
-- actually travelled, so a slow machine takes longer in seconds and asserts exactly the same thing.
-- The seconds that remain are backstops -- they fire only if nothing moves at all -- and they are
-- generous on purpose.
local function stepUntil(frames: number, predicate: () -> boolean): (boolean, number)
	for used = 1, frames do
		RunService.Heartbeat:Wait()
		if predicate() then
			return true, used
		end
	end
	return predicate(), frames
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
			local landed = waitUntil(6, function()
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

		it("sprints away from a threat, and stays upright", function()
			local start = handle.position()
			threatPosition = start + Vector3.new(0, 0, 20) -- behind it, toward the far side from the exit

			-- FIRST SENSING is the design's own starting line ("body reaches >= 0.5 x SPRINT_SPEED
			-- within 1.0 s of first sensing", boar-ai design section 11), and the state turning FLEE
			-- IS first sensing -- a decision, with no physics in it. Measuring the ramp from the
			-- moment this spec assigned a variable instead put the scheduler's own latency inside the
			-- design's budget (Task 36).
			local sensed = waitUntil(5, function()
				return handle.state() == "FLEE"
			end)
			expect(sensed).to.equal(true)

			local upright = true
			local sinceFlee = os.clock()
			local reached, frames = stepUntil(240, function()
				upright = upright and handle.part.CFrame.UpVector.Y > 0.9
				return handle.part.AssemblyLinearVelocity.Magnitude >= CONFIG.SPRINT_SPEED * 0.5
			end)
			local took = os.clock() - sinceFlee
			print(string.format("[boar_body] reached half sprint in %d frame(s), %.2f s", frames, took))
			expect(reached).to.equal(true)
			-- THE DESIGN'S NUMBER, WITH NO TOLERANCE ADDED, in the unit that makes a tolerance
			-- unnecessary: "within 1.0 s of first sensing" is 60 frames at 60 Hz, and a frame is a
			-- simulation step whether the machine is idle or not. The first version allowed 120 --
			-- twice the design -- which put the spec and the design out of step for no reason once
			-- the clock was out of the measurement. `took` is printed, not asserted: on a stalled
			-- machine it measures the machine.
			expect(frames <= 60).to.equal(true)
			expect(handle.state()).to.equal("FLEE")
			expect(upright).to.equal(true)

			-- AND IT ACTUALLY GETS AWAY (review round 2, finding 4). Measured against the boar's own
			-- travel, not the clock: it must open GAIN_STUDS of flat distance on the threat within
			-- TRAVEL_BUDGET studs of its own path. A boar that ran three times the distance it gained
			-- is not fleeing, whatever the frame rate was; a boar that stood still trips the backstop
			-- below with `travelled` near zero, which says so in the failure.
			local GAIN_STUDS = 20
			local TRAVEL_BUDGET = GAIN_STUDS * 3
			local function flat(p: Vector3): Vector3
				return Vector3.new(p.X, 0, p.Z)
			end
			local function flatGap(): number
				return (flat(handle.position()) - flat(threatPosition)).Magnitude
			end
			local gapBefore, travelled = flatGap(), 0
			local last = handle.position()
			local gained, spent = false, 0
			for _ = 1, 1800 do -- 30 s at 60 Hz: a backstop, never the measurement
				RunService.Heartbeat:Wait()
				spent += 1
				if handle.part.Parent == nil then
					gained = true -- it left the field entirely, which is getting away
					break
				end
				local here = handle.position()
				travelled += (flat(here) - flat(last)).Magnitude
				last = here
				if flatGap() - gapBefore >= GAIN_STUDS then
					gained = true
					break
				end
				if travelled >= TRAVEL_BUDGET then
					break
				end
			end
			print(
				string.format(
					"[boar_body] gained %.1f studs over %.1f studs of travel, %d frame(s)",
					flatGap() - gapBefore,
					travelled,
					spent
				)
			)
			expect(gained).to.equal(true)
		end)

		it("despawns once when it reaches the exit edge, and says so", function()
			-- 8 s was four times what the crossing needs at SPRINT_SPEED and still a wall-clock
			-- budget; under harness load it is not obviously enough, and there is no cost to a
			-- backstop that only fires when the boar never arrives at all (Task 36).
			local gone = waitUntil(30, function()
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
				-- `pathProblems` is the WORLD's tally of every request it could not answer with
				-- usable waypoints - a failed ComputeAsync, OR a Success carrying nothing past where
				-- the boar already stands (review round 5, finding 1: that second class produces the
				-- silent straight-line fallback and used to be recorded nowhere).
				-- `stats.pathFailures` is the RUNTIME's tally of those that reached a LIVE boar, and
				-- Runtime:_requestPath drops a reply whose boar has already despawned (`entry.dead`).
				-- The world therefore records a superset: world >= runtime is the invariant.
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
